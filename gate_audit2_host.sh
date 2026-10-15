#!/bin/bash
# gate_audit2_host.sh — regression gates for the C-host (tiny_host.c) fixes of
# LogOS_bug_audit_2.md. Each case FAILS on the unfixed tree and PASSES with its
# fix. Runs in a private temp dir (no fixed /tmp paths); needs gcc only (the
# cases run the host alone, so no VM is emitted).
# Not wired into build.sh (local tracks edit it) — one line to hook it in.
#   usage: ./gate_audit2_host.sh [case ...]     (no args = every case)
set -u
REPO=$(cd "$(dirname "$0")" && pwd)
W=$(mktemp -d "${TMPDIR:-/tmp}/gate_audit2_host.XXXXXX")
trap 'rm -rf "$W"' EXIT
cd "$W"
gcc -O2 -o tiny_host "$REPO/tiny_host.c" || { echo "FAIL  gate: cannot build tiny_host"; exit 1; }
FAILS=0
pass() { echo "PASS  $*"; }
fail() { echo "FAIL  $*"; FAILS=$((FAILS+1)); }
oneline() { tr '\n' '|' < "$1" | cut -c1-200; }

# ── #147 a glyph whose body is (transitively) a bare reference to itself ─────
# Unfixed: eval(N_VAR) tail-jumps to eval(body) forever — silent 100% CPU hang
# (rc 124 under timeout). Fixed: a loud halt naming the cycle.
case_host_selfref() {
    printf 'glyph A = A\nglyph MAIN = print(A)\n' > sr1.la
    printf 'glyph B = C\nglyph C = B\nglyph MAIN = print(B)\n' > sr2.la
    local ok=1 f rc
    for f in sr1 sr2; do
        rc=0; timeout 5 ./tiny_host $f.la > $f.out 2>&1 || rc=$?
        { [ "$rc" = 1 ] && grep -q 'glyph cycle' $f.out; } || { ok=0; fail "host_selfref $f: rc=$rc — got: $(oneline $f.out)"; }
    done
    [ $ok = 1 ] && pass "host_selfref: glyph A = A and a two-glyph cycle halt loudly (rc 1), no hang"
}

CASES="${*:-host_selfref}"
for c in $CASES; do "case_$c"; done
[ "$FAILS" -eq 0 ] && { echo "gate_audit2_host: all passed"; exit 0; } || { echo "gate_audit2_host: $FAILS failed"; exit 1; }
