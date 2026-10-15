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

# ── #146 print then error: merged stream must keep program order ────────────
case_host_order() {
    printf 'glyph MAIN = (la _. error("ERR"))(print("OUT"))\n' > ord.la
    local got; got=$(timeout 5 ./tiny_host ord.la 2>&1 | cat | tr '\n' '|')
    if [ "$got" = "OUT|ERR|" ]; then pass "host_order: print before error appears first in a 2>&1 pipe"
    else fail "host_order: merged stream out of program order — got: $got"; fi
}

# ── #144 glyph table (1024) and export list (256) caps ──────────────────────
case_host_caps() {
    { for i in $(seq 1 3000); do echo "glyph G$i = \"g$i\""; done; echo 'glyph MAIN = print(G3000)'; } > caps1.la
    { printf 'export'; for i in $(seq 1 400); do printf ' E%d' $i; done; echo
      for i in $(seq 1 400); do echo "glyph E$i = \"e$i\""; done; } > capsmod.la
    printf 'import("capsmod.la")\nglyph MAIN = print(concat(E1)(E400))\n' > caps2.la
    local a b; a=$(timeout 20 ./tiny_host caps1.la 2>&1); b=$(timeout 20 ./tiny_host caps2.la 2>&1)
    if [ "$a" = "g3000" ] && [ "$b" = "e1e400" ]; then pass "host_caps: 3000 glyphs and 400 exports load"
    else fail "host_caps: got '$a' / '$b'"; fi
}

# ── #143 lexer/parser diagnostics carry file and line ───────────────────────
case_host_diag() {
    printf 'export G\nglyph G = (concat("a")("b")\n' > badmod.la
    printf 'import("badmod.la")\nglyph MAIN = print(G)\n' > badapp.la
    printf 'glyph A = "a"\nglyph B = $\nglyph MAIN = print(A)\n' > badlex.la
    timeout 5 ./tiny_host badapp.la > d1.out 2>&1; timeout 5 ./tiny_host badlex.la > d2.out 2>&1
    if grep -q '^badmod.la:3: parse error' d1.out && grep -q '^badlex.la:2: lex error' d2.out; then
        pass "host_diag: diagnostics name file:line (imported module and main file)"
    else fail "host_diag: got '$(oneline d1.out)' / '$(oneline d2.out)'"; fi
}

CASES="${*:-host_selfref host_order host_caps host_diag}"
for c in $CASES; do "case_$c"; done
[ "$FAILS" -eq 0 ] && { echo "gate_audit2_host: all passed"; exit 0; } || { echo "gate_audit2_host: $FAILS failed"; exit 1; }
