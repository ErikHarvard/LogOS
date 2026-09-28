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

CASES="${*:-logosinit_forkfail sigpipe}"
for c in $CASES; do "case_$c"; done
[ "$FAILS" -eq 0 ] && { echo "gate_audit2: all passed"; exit 0; } || { echo "gate_audit2: $FAILS failed"; exit 1; }
