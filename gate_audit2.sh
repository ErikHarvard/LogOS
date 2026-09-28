#!/bin/bash
# gate_audit2.sh — regression gates for the LogOS_bug_audit_2.md fixes on this
# branch. Each case FAILS on the unfixed tree and PASSES with its fix. Runs in a
# private temp dir (no fixed /tmp paths); needs gcc, and nasm only where noted.
# Not wired into build.sh (local tracks edit it) — one line to hook it in.
#   usage: ./gate_audit2.sh [case ...]     (no args = every case)
set -u
REPO=$(cd "$(dirname "$0")" && pwd)
W=$(mktemp -d "${TMPDIR:-/tmp}/gate_audit2.XXXXXX")
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

# ── #4 logosinit: a failed fork() is not a pid ────────────────────────────────
# fork is shadowed to return -EAGAIN ("-11"). Unfixed: SPAWN returns "-11" as the
# shell pid, nothing ever retries, and SIGTERM runs kill(-11, SIGTERM) — a
# process-GROUP kill. Fixed: init reports the failure, retries after BACKOFF,
# still answers SIGTERM, and signals no one.
case_logosinit_forkfail() {
    { echo 'glyph fork = la _. "-11"'; cat logosinit.la; } > t_forkfail.la
    vmc t_forkfail.la || { fail "logosinit fork-fail: codegen"; return; }
    sleep 10 | ./logos_secd > init.out 2>&1 &
    local p=$!; sleep 2.5; kill -TERM "$(pgrep -P $p -x logos_secd 2>/dev/null || echo $p)" 2>/dev/null
    local rc=0; wait $p || rc=$?
    if grep -q 'logosinit: fork failed (-11) — retrying' init.out \
       && grep -qxF 'LogOS received SIGTERM — terminating session.' init.out; then
        pass "logosinit: failed fork reported + retried, SIGTERM still honoured (no kill of a non-positive pid)"
    else
        fail "logosinit: failed fork not handled — got: $(tr '\n' '|' < init.out)"
    fi
}

# ── #17 VM: a write/send to a dead peer returns -EPIPE instead of killing the VM ──
# Unfixed: SIGPIPE's default action kills the VM (rc 141) before the builtin can
# return -32, so no program can recognise a dead peer. Fixed: -32, execution
# continues. Covers send (socket, MSG_NOSIGNAL) and write (pipe, SIG_IGN).
case_sigpipe() {
    cat > t_sigpipe.la <<'LAEOF'
glyph SEQ = la a. la b. b
glyph P = "gate_sigpipe.sock"
glyph MAIN =
  (la srv. SEQ(unlink(P))(SEQ(bind(srv)(P))(SEQ(listen(srv))(
  (la cli. SEQ(connect(cli)(P))(
  (la conn. SEQ(close(conn))(
    SEQ(print(concat("send=")(send(cli)("hello"))))(
    (la p. (la rfd. (la wfd. SEQ(close(rfd))(SEQ(print(concat("write=")(write(wfd)("x"))))(print("survived"))))(str_tail(str_tail(p))))(str_head(p)))(pipe("!"))))
  )(accept(srv)))
  )(socket("!"))))))(socket("!"))
LAEOF
    vmc t_sigpipe.la || { fail "sigpipe: codegen"; return; }
    local out rc=0; out=$(timeout 20 ./logos_secd 2>&1) || rc=$?
    if [ "$rc" = 0 ] && [ "$out" = "$(printf 'send=-32\nwrite=-32\nsurvived')" ]; then
        pass "VM: send/write to a dead peer return -32 (EPIPE) and the program continues"
    else
        fail "VM: dead-peer send/write — rc=$rc out=[$(echo "$out" | tr '\n' '|')] (want -32/-32/survived, rc 0)"
    fi
}

# ── #21 live loops: every "forever" loop's self-call is a TAIL call ──────────
# The VM's TCO fires only when APPLY is followed by RET. `SEQ(work)(self(...))`
# puts self(...) in ARGUMENT position (its APPLY is followed by SEQ's APPLY), so
# each iteration leaked a dump frame + its env; the loop halted `secd: heap
# exhausted` after ~800k iterations. The binder form `(la _. self(...))(work)`
# (logosinit's shape) runs forever. Checked on the SOURCE of each loop glyph
# (tailpos.py: a self-call is tail only through applied-lambda bodies and IF
# thunks), plus a VM control: the binder form reaches 1.2M iterations.
case_tail_loops() {
    local bad=0 fg
    for fg in theourgia_poll_live.la:MULTIPLEX theourgia_poll.la:MULTIPLEX \
              theourgia_mux_session.la:LIVE theourgia_mux_session_live.la:LIVE \
              theourgia_text_session_live.la:LIVE theourgia_text_live.la:HOLD \
              sigil_live.la:HOLD sigil_seal_live.la:CYCLE; do
        python3 "$REPO/tailpos.py" "${fg%%:*}" "${fg##*:}" >tp.out 2>&1 || { fail "tail loops: $(tr '\n' ' ' < tp.out)"; bad=1; }
    done
    cat > t_bind.la <<'LAEOF'
glyph Z   = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph IF  = la c. la t. la f. c(t)(f)("!")
glyph LOOP = Z(la self. la n. IF(int_eq(n)(1200000))(la _. print("reached"))(la _. (la _. self(add(n)(1)))(n)))
glyph MAIN = LOOP(0)
LAEOF
    vmc t_bind.la && [ "$(timeout 120 ./logos_secd 2>&1)" = reached ] || { fail "tail loops: binder-form control loop did not reach 1.2M on the VM"; bad=1; }
    [ $bad = 0 ] && pass "live loops: all eight forever-loops recurse in tail (binder) position; binder control reaches 1.2M iterations"
}

# ── #20 live input: a hung-up device halts loudly instead of busy-spinning ───
# poll reports a closed peer ready (POLLHUP) on every call and read() returns
# ""; decoded, "" is a zero event, so MULTIPLEX spun at 100% CPU forever. The
# pipe here carries one real 24-byte KEY_A event, then its writer closes.
case_pollhup() {
    sed '/^glyph MAIN =/,$d' theourgia_poll.la > t_hup.la
    cat >> t_hup.la <<'LAEOF'
glyph EV24 = concat("0123456789abcdef")(concat(chr("1"))(concat(chr("0"))(concat(chr("30"))(concat(chr("0"))(concat(chr("1"))(concat(chr("0"))(concat(chr("0"))(chr("0")))))))))
glyph MAIN = (la p. (la rfd. (la wfd. SEQ(write(wfd)(EV24))(SEQ(close(wfd))(MULTIPLEX(CONS(rfd)(NIL)))))(str_tail(str_tail(p))))(str_head(p)))(pipe("!"))
LAEOF
    vmc t_hup.la || { fail "pollhup: codegen"; return; }
    local out rc=0; out=$(timeout 20 ./logos_secd 2>&1) || rc=$?
    if [ "$rc" = 1 ] && [ "$(sed -n 1p <<< "$out")" = "fd 3: type=1 code=30 value=1" ] \
       && grep -q 'hung up or failed (read gave 0 bytes' <<< "$out" && [ "$(wc -l <<< "$out")" = 2 ]; then
        pass "live input: the real event decodes, then the hung-up fd halts loudly (no busy-spin)"
    else
        fail "live input POLLHUP: rc=$rc, $(wc -l <<< "$out") lines, first: $(head -2 <<< "$out" | tr '\n' '|')"
    fi
}

# ── native_codegen3 cases (#9 #11 #12): compile with the host, run natively ──
# The emitted binaries carry native_codegen3.la's HEAP_SIZE in p_memsz; on a box
# that cannot map it the exec itself fails (rc 139) — reported as SKIP, not PASS.
nc3() {   # nc3 <prog.la> -> sets NOUT NERR NRC (compile+run natively)
    cp "$1" native_input.la; rm -f native_codegen3_out
    timeout 900 ./tiny_host native_codegen3.la >/dev/null 2>nc3.err || { NRC=COMPILE; NERR=$(tail -c 200 nc3.err); return; }
    NOUT=$(timeout 30 ./native_codegen3_out 2>nc3.run); NRC=$?; NERR=$(cat nc3.run)
}
case_nc3_shadow() {      # #9: a user glyph shadows a builtin of the same name
    printf 'glyph concat = la a. la b. "SHADOW"\nglyph MAIN = print(concat("a")("b"))\n' > t_shadow.la
    nc3 t_shadow.la
    if [ "$NRC" = 0 ] && [ "$NOUT" = SHADOW ]; then pass "native_codegen3: a glyph named like a builtin shadows it (native SHADOW == host)"
    elif [ "$NRC" = 139 ] && [ -z "$NOUT" ]; then echo "SKIP  nc3_shadow: native binary cannot exec here (p_memsz > RAM+swap)"
    else fail "native_codegen3 shadow: native rc=$NRC out=[$NOUT] (host prints SHADOW)"; fi
}
CASES="${*:-logosinit_forkfail sigpipe tail_loops pollhup nc3_shadow}"
for c in $CASES; do "case_$c"; done
[ "$FAILS" -eq 0 ] && { echo "gate_audit2: all passed"; exit 0; } || { echo "gate_audit2: $FAILS failed"; exit 1; }
