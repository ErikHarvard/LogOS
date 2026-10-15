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

# ── #69 VM write_file/write_exec: a failed open/write halts loudly ────────────
# Unfixed: open's -errno jumps straight to the epilogue that returns the content,
# so the program prints "after" and exits 0 while the host halts rc 1 with
# "cannot open". The write(2) result was never checked either (/dev/full: ENOSPC).
# Fixed: "secd: write_file: cannot open|write <path>" on stderr, rc 1, no "after".
wf_case() {   # <builtin> <path> <expected stderr fragment>
    printf 'glyph SEQ = la a. la b. b\nglyph MAIN = SEQ(print("before"))(SEQ(%s("%s")("payload"))(print("after")))\n' "$1" "$2" > t_wf.la
    vmrun t_wf.la
    if [ "$RC" = 1 ] && [ "$OUT" = "before|$3|" ]; then pass "VM: $1($2) halts loudly (rc 1)"
    else fail "VM: $1($2) — rc=$RC out=[$OUT] (want before|$3| rc 1)"; fi
}
case_vm_writefail() {
    wf_case write_file /nonexistent_dir_zz/x.txt "secd: write_file: cannot open /nonexistent_dir_zz/x.txt"
    wf_case write_exec /nonexistent_dir_zz/x.bin "secd: write_exec: cannot open /nonexistent_dir_zz/x.bin"
    wf_case write_file /dev/full "secd: write_file: cannot write /dev/full"
    wf_case write_exec /dev/full "secd: write_exec: cannot write /dev/full"
    # the host is the reference: its /dev/full write must halt too (was silent)
    printf 'glyph SEQ = la a. la b. b\nglyph MAIN = SEQ(write_file("/dev/full")("payload"))(print("after"))\n' > t_wfh.la
    local hrc=0 hout; hout=$(timeout 20 ./tiny_host t_wfh.la 2>&1) || hrc=$?
    if [ "$hrc" = 1 ] && [ "$hout" = "write_file: cannot write '/dev/full': No space left on device" ]; then pass "host: write_file(/dev/full) halts loudly (rc 1)"
    else fail "host: write_file(/dev/full) — rc=$hrc out=[$(echo "$hout" | tr '\n' '|')]"; fi
    # control: a writable path still works and returns the content
    printf 'glyph SEQ = la a. la b. b\nglyph MAIN = SEQ(print(write_file("wf_ok.txt")("payload")))(print(read_file("wf_ok.txt")))\n' > t_wfok.la
    vmrun t_wfok.la
    if [ "$RC" = 0 ] && [ "$OUT" = "payload|payload|" ]; then pass "VM: write_file to a writable path still writes and returns the content"
    else fail "VM: write_file control — rc=$RC out=[$OUT]"; fi
}

# ── #128 VM pipe/clock_gettime return -errno like every other syscall builtin ──
# Unfixed: .pipe_fail / .clockgettime_fail hard-code "-1", discarding errno.
# pipe under `ulimit -n 4` (fds 0-2 open → no room for two more) must be -24
# (EMFILE); clock_gettime with a bad clockid must be -22 (EINVAL).
case_vm_errno() {
    printf 'glyph SEQ = la a. la b. b\nglyph MAIN = SEQ(print(concat("pipe=")(pipe("!"))))(print(concat("clock=")(clock_gettime("99"))))\n' > t_errno.la
    vmc t_errno.la || { fail "vm_errno: codegen"; return; }
    # run with ONLY fds 0-2 open (close whatever the harness inherited) and room for one more
    local out; out=$(timeout 20 bash -c 'exec </dev/null 2>&1; for f in /proc/$$/fd/*; do n=${f##*/}; [ "$n" -gt 2 ] && eval "exec $n>&-" 2>/dev/null; done; ulimit -n 4; exec ./logos_secd' | tr '\n' '|')
    if [ "$out" = "pipe=-24|clock=-22|" ]; then pass "VM: pipe/clock_gettime failures return -errno (-24, -22)"
    else fail "VM: pipe/clock_gettime failure values — out=[$out] (want pipe=-24|clock=-22|)"; fi
}

# ── #115 logoscap MINT: an entropy failure must not brand the EMPTY secret ─────
# `random` yields "" when getrandom fails (#70, deliberately not changed here),
# and BRAND("") makes box("") — a probe anyone can supply — open every box.
# random is shadowed to the failure value ("") and to a short read (31 bytes).
# Unfixed: MINT brands it and the forged probe opens the box (rc 0). Fixed: MINT
# halts loudly naming the byte count; the real 32-byte path is unchanged.
mint_case() {   # <label> <random shadow> <expected stderr fragment>
    { echo "$2"; sed '/^glyph MAIN/,$d' logoscap.la
      echo 'glyph MAIN = (la realm. (la box. SEQ(SHOW_OPEN("authorized = ")(CAP_RECV(GRANT_RECV(realm))(box))(la w. MSG_TYPE(w)))(SHOW_OPEN("forged probe = ")(box(""))(la w. concat("FORGED-OPEN ")(MSG_TYPE(w)))))(CAP_SEND(GRANT_SEND(realm))("ping")("hello")))(MINT("!"))'; } > t_mint.la
    local rc=0 out; out=$(timeout 60 ./tiny_host t_mint.la 2>&1) || rc=$?
    if [ "$rc" != 0 ] && echo "$out" | grep -qF "$3" && ! echo "$out" | grep -q FORGED-OPEN; then pass "logoscap MINT ($1): halts loudly (rc $rc), nothing branded"
    else fail "logoscap MINT ($1): rc=$rc out=[$(echo "$out" | tr '\n' '|')]"; fi
}
case_vm_mint() {
    mint_case 'random -> ""' 'glyph random = la n. ""' 'logoscap: MINT got 0 bytes of entropy, not 32'
    mint_case 'random -> 31 bytes' 'glyph random = la n. "0123456789012345678901234567890"' 'logoscap: MINT got 31 bytes of entropy, not 32'
    # control: a full 32-byte nonce still brands a working realm, forged probe denied
    { echo 'glyph random = la n. "01234567890123456789012345678901"'; sed '/^glyph MAIN/,$d' logoscap.la
      echo 'glyph MAIN = (la realm. (la box. SEQ(SHOW_OPEN("authorized = ")(CAP_RECV(GRANT_RECV(realm))(box))(la w. MSG_TYPE(w)))(SHOW_OPEN("forged probe = ")(box(""))(la w. concat("FORGED-OPEN ")(MSG_TYPE(w)))))(CAP_SEND(GRANT_SEND(realm))("ping")("hello")))(MINT("!"))'; } > t_mintok.la
    local rc=0 out; out=$(timeout 60 ./tiny_host t_mintok.la 2>&1) || rc=$?
    if [ "$rc" = 0 ] && [ "$out" = "$(printf 'authorized = ping\nforged probe = denied')" ]; then pass "logoscap MINT control: a 32-byte nonce brands a working realm"
    else fail "logoscap MINT control: rc=$rc out=[$(echo "$out" | tr '\n' '|')]"; fi
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

# ── #40 LogosIPC CHANNEL: a failed bind/listen halts instead of "listening" ────
# CHANNEL discarded unlink/bind/listen results and returned the socket anyway, so
# when the rendezvous path could not be cleared (another uid's socket in sticky
# /tmp — the squat vector; here, as one uid: a DIRECTORY at the path, which
# unlink cannot remove) bind failed EADDRINUSE silently and the server "listened"
# on an unbound socket while clients reached whoever held the name.
# Unfixed: chan=<fd>, after, rc 0. Fixed: loud halt naming bind's -errno (-98).
case_vm_ipc_bind() {
    local nm="gate40-$$-$RANDOM" d
    d="/tmp/logosipc-$nm"; mkdir "$d" || { fail "vm_ipc_bind: cannot create $d"; return; }
    printf 'import("logosipc.la")\nglyph SEQ2 = la a. la b. b\nglyph MAIN = SEQ2(print(concat("chan=")(CHANNEL("%s"))))(print("after"))\n' "$nm" > t_ipc.la
    vmrun t_ipc.la; rmdir "$d"
    if [ "$RC" = 1 ] && [ "$OUT" = "logosipc: CHANNEL $nm: bind failed (-98) — name taken; refusing to listen on an unbound socket|" ]; then pass "logosipc: CHANNEL halts loudly when bind fails (EADDRINUSE)"
    else fail "logosipc: CHANNEL on a taken name — rc=$RC out=[$OUT]"; fi
    # control: a free name still yields a listening fd
    nm="gate40ok-$$-$RANDOM"
    printf 'import("logosipc.la")\nglyph SEQ2 = la a. la b. b\nglyph MAIN = SEQ2(print(concat("chan=")(CHANNEL("%s"))))(print("after"))\n' "$nm" > t_ipcok.la
    vmrun t_ipcok.la; rm -f "/tmp/logosipc-$nm"
    if [ "$RC" = 0 ] && [[ "$OUT" =~ ^chan=[0-9]+\|after\|$ ]]; then pass "logosipc: CHANNEL on a free name still listens ($OUT)"
    else fail "logosipc: CHANNEL control — rc=$RC out=[$OUT]"; fi
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

CASES="${*:-vm_writefail vm_errno vm_mint vm_tco_comment vm_cloexec vm_ipc_bind vm_sanitize}"
for c in $CASES; do "case_$c"; done
[ "$FAILS" -eq 0 ] && { echo "gate_audit2_vm: all passed"; exit 0; } || { echo "gate_audit2_vm: $FAILS failed"; exit 1; }
