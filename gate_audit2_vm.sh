#!/bin/bash
# gate_audit2_vm.sh — regression gates for the LogOS_bug_audit_2.md fixes to the
# native SECD VM (secd.asm → secd.la) and the process/IPC modules. Each case
# FAILS on the unfixed tree and PASSES with its fix. Runs in a private temp dir
# (no fixed /tmp paths); needs gcc. Not wired into build.sh (one line hooks it in).
#   usage: ./gate_audit2_vm.sh [case ...]     (no args = every case)
set -u
REPO=$(cd "$(dirname "$0")" && pwd)
W=$(mktemp -d "${TMPDIR:-/tmp}/gate_audit2_vm.XXXXXX")
trap 'rm -rf "$W"' EXIT
cd "$W"
gcc -O2 -o tiny_host "$REPO/tiny_host.c" || { echo "FAIL  gate: cannot build tiny_host"; exit 1; }
cp "$REPO"/*.la .
./tiny_host secd.la >/dev/null 2>&1 || { echo "FAIL  gate: cannot emit logos_secd"; exit 1; }
FAILS=0
pass() { echo "PASS  $*"; }
fail() { echo "FAIL  $*"; FAILS=$((FAILS+1)); }
# vmc <prog.la> — compile a program for the SECD VM with codegen.la on the host
vmc() { cp "$1" logos_source.la && timeout 600 ./tiny_host codegen.la >/dev/null 2>&1; }
# vmrun <prog.la> — compile + run on the VM; sets OUT (stdout+stderr, '|'-joined) and RC
vmrun() {
    OUT=""; RC=0
    vmc "$1" || { OUT="codegen failed"; RC=255; return; }
    timeout 20 ./logos_secd >vm.out 2>&1 </dev/null || RC=$?
    OUT=$(tr '\n' '|' < vm.out)
}

# ── #129 VM-created fds are close-on-exec ─────────────────────────────────────
# signalfd / socket / pipe / accept fds leaked into every execve'd child (a
# shell spawned by logosinit inherited init's signalfd; an IPC worker inherited
# the listening socket). The child lists its own fds by target. Unfixed: the
# listing shows anon_inode:[signalfd], socket:, pipe:. Fixed: none of them.
# dup2 still hands a child a fd on purpose (dup2's target is never CLOEXEC).
case_vm_cloexec() {
    printf '#!/bin/sh\nfor f in /proc/$$/fd/*; do readlink "$f"; done | grep -E "signalfd|socket:|pipe:" | sed "s/[0-9]*]$/]/" | sort -u | tr "\\n" " "; echo END\n' > showfds.sh
    chmod +x showfds.sh
    cat > t_cloexec.la <<'LAEOF'
glyph SEQ = la a. la b. b
glyph IF  = la c. la t. la f. c(t)(f)("!")
glyph P = "gate_cloexec.sock"
glyph MAIN = (la sfd. (la srv. SEQ(unlink(P))(SEQ(bind(srv)(P))(SEQ(listen(srv))(
  (la cli. SEQ(connect(cli)(P))((la conn. (la pp. (la pid.
     IF(str_eq(pid)("0"))(la _. SEQ(execve("./showfds.sh"))(exit("127")))
       (la _. SEQ(waitpid(pid))(unlink(P))))(fork("!")))(pipe("!")))(accept(srv))))(socket("!"))))))(socket("!")))(signalfd("1024"))
LAEOF
    vmrun t_cloexec.la
    if [ "$RC" = 0 ] && [ "$OUT" = "END|" ]; then pass "VM: signalfd/socket/accept/pipe fds are not inherited across execve"
    else fail "VM: fds leak into an execve'd child — rc=$RC child sees [$OUT] (want END| only)"; fi
    # control: dup2 onto a low fd still hands the child that fd (pipe -> fd 5)
    printf '#!/bin/sh\nreadlink /proc/$$/fd/5 | sed "s/[0-9]*]$/]/"\n' > showfd5.sh; chmod +x showfd5.sh
    cat > t_dup2.la <<'LAEOF'
glyph SEQ = la a. la b. b
glyph IF  = la c. la t. la f. c(t)(f)("!")
glyph MAIN = (la pp. SEQ(dup2(str_head(pp))("5"))((la pid.
     IF(str_eq(pid)("0"))(la _. SEQ(execve("./showfd5.sh"))(exit("127")))
       (la _. waitpid(pid)))(fork("!"))))(pipe("!"))
LAEOF
    vmrun t_dup2.la
    if [ "$RC" = 0 ] && [ "$OUT" = "pipe:[]|" ]; then pass "VM: dup2 still passes a chosen fd to an execve'd child"
    else fail "VM: dup2 control — rc=$RC out=[$OUT] (want pipe:[]|)"; fi
}

# ── #131 secd.asm: no stale "no tail-call optimisation" claim ──────────────────
# The VM HAS tail calls (.apply_clo: APPLY followed by RET reuses the frame;
# gate_audit2.sh tail_loops runs 5M iterations), but the stack-sizing comment
# said "this SECD machine does no tail-call optimisation". Source check.
case_vm_tco_comment() {
    if grep -n 'does no tail-call optimisation\|Without tail-call optimisation' "$REPO/secd.asm" > tco.hits; then
        fail "secd.asm still denies its own TCO: $(tr '\n' '|' < tco.hits)"
    elif grep -q 'tail call' "$REPO/secd.asm"; then pass "secd.asm comments describe the TCO rule instead of denying it"
    else fail "secd.asm: no TCO description found (proved-looked check)"; fi
}

# ── #114 SANITIZE: mangled module names use only host-lexable bytes ───────────
# SANITIZE (eval.la, bytecode.la, parser.la, codegen.la) kept every byte the .la
# lexer calls an identifier char, so "fz/m-1.la" mangled to __mod_fz/m-1_la__g —
# a lex error on the C host (identifiers are [A-Za-z0-9_]) once unparsed.
# Unfixed: __mod_fz/m-1_la__g in all four. Fixed: the injective escape
# __mod_fz_47_m_45_1_46_la__g (native_codegen3.la's rule), and the C host
# lexes it.
case_vm_sanitize() {
    local f want='__mod_fz_47_m_45_1_46_la__g' out rc
    for f in eval.la bytecode.la parser.la codegen.la; do
        { sed '/^glyph MAIN/,$d' "$f"; echo 'glyph MAIN = print(MANGLE("fz/m-1.la")("g"))'; } > t_san.la
        rc=0; out=$(timeout 120 ./tiny_host t_san.la 2>&1) || rc=$?
        if [ "$rc" = 0 ] && [ "$out" = "$want" ]; then pass "$f: MANGLE(fz/m-1.la) = $want"
        else fail "$f: MANGLE(fz/m-1.la) — rc=$rc out=[$out] (want $want)"; fi
    done
    printf 'glyph %s = "lexed"\nglyph MAIN = print(%s)\n' "$want" "$want" > t_lex.la
    rc=0; out=$(timeout 20 ./tiny_host t_lex.la 2>&1) || rc=$?
    [ "$rc" = 0 ] && [ "$out" = lexed ] && pass "host lexes the mangled name" || fail "host cannot lex $want: rc=$rc [$out]"
    # control: a real import still runs on the VM (codegen.la's mangling) as on the host
    local h; h=$(timeout 60 ./tiny_host greetapp.la 2>&1)
    vmrun greetapp.la
    if [ "$RC" = 0 ] && [ "$OUT" = "$h|" ]; then pass "greetapp import: VM == host ($h)"
    else fail "greetapp import: VM rc=$RC [$OUT] vs host [$h]"; fi
}

#CASES-BELOW

CASES="${*:-vm_cloexec vm_tco_comment vm_sanitize}"
for c in $CASES; do "case_$c"; done
[ "$FAILS" -eq 0 ] && { echo "gate_audit2_vm: all passed"; exit 0; } || { echo "gate_audit2_vm: $FAILS failed"; exit 1; }
