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

# ── #142 lexer malloc(strlen(rest of source)) per string literal ────────────
# Lex cost of 100k vs 400k string literals: quadratic before (x16 for 4x the
# literals), linear after (x4). The gate takes the ratio, not a wall-clock bound.
case_host_lexlit() {
    local K
    for K in 100000 400000; do
        python3 -c "import sys; K=$K; sys.stdout.write('glyph BIG = la f. f' + ''.join('(\"s%d\")' % i for i in range(K)) + '\nglyph MAIN = print(\"parsed\")\n')" > lexlit$K.la
    done
    local r; r=$(python3 - <<'PY'
import subprocess, time
t = {}
for K in (100000, 400000):
    s = time.perf_counter()
    out = subprocess.run(["timeout", "120", "./tiny_host", "lexlit%d.la" % K], capture_output=True, text=True).stdout
    t[K] = time.perf_counter() - s
    if out.strip() != "parsed": print("BADOUT %d %r" % (K, out[:80])); raise SystemExit
print("%.2f %.2f %.1f" % (t[100000], t[400000], t[400000] / t[100000]))
PY
)
    set -- $r
    if [ "$1" != BADOUT ] && awk -v x="$3" 'BEGIN{exit !(x < 8)}'; then pass "host_lexlit: 4x literals cost x$3 (${1}s -> ${2}s) — linear"
    else fail "host_lexlit: 4x literals cost x${3:-?} (${1}s -> ${2:-?}s) — quadratic (want < x8)"; fi
}

# ── #84 read_file of a size-0 /proc file returned "" ────────────────────────
case_host_procread() {
    printf 'glyph MAIN = print(concat("[")(concat(read_file("/proc/self/stat"))("]")))\n' > proc.la
    local got; got=$(timeout 5 ./tiny_host proc.la 2>&1 | head -c 200)
    case "$got" in
        "["[0-9]*" (tiny_host) "*) pass "host_procread: /proc/self/stat read in full ('$(printf '%s' "$got" | cut -c1-30)…')" ;;
        *) fail "host_procread: got '$got'" ;;
    esac
}

# ── #148 imports resolve against the cwd — the failure must say so ──────────
case_host_importcwd() {
    mkdir -p sub
    printf 'export Q\nglyph Q = "q"\n' > sub/qmod.la
    printf 'import("qmod.la")\nglyph MAIN = print(Q)\n' > sub/qapp.la
    timeout 5 ./tiny_host sub/qapp.la > ic.out 2>&1
    if grep -q "imported by 'sub/qapp.la'" ic.out && grep -q 'current directory' ic.out; then
        pass "host_importcwd: a failed import names its importer and the cwd rule"
    else fail "host_importcwd: got '$(oneline ic.out)'"; fi
}

# ── #80 non-tail recursion depth capped at ~50k by the 8 MiB C stack ─────────
# Unfixed: SUM(100000) (Z-combinator, non-tail) halts with the C stack guard,
# rc 1, while the VM prints the sum. Fixed: eval runs on a 256 MiB lazily-
# committed thread stack, so it prints 100000*100001/2 (python-derived, not
# captured). The guard must still halt LOUDLY (rc 1 + 'C stack guard', not
# SIGSEGV 139) on nesting deep enough to exhaust even that stack: 60M nested
# parens (~0.6 s, ~1.2 GB). SUM(100000) costs ~10 s and ~2.5 GB RSS.
case_host_deeprec() {
    cat > deep.la <<'LA'
glyph TRUE = la t. la f. t
glyph FALSE = la t. la f. f
glyph IF = la c. la t. la f. c(t)(f)("!")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph SUM = Z(la self. la n. IF(int_eq(n)(0))(la _. 0)(la _. add(n)(self(sub(n)(1)))))
glyph MAIN = print(int_to_str(SUM(100000)))
LA
    python3 -c "import sys;N=60000000;sys.stdout.write('glyph MAIN = print('+'('*N+'\"x\"'+')'*N+')\n')" > nest.la
    local want got rc rc2
    want=$(python3 -c 'print(100000*100001//2)')
    rc=0; got=$(timeout 60 ./tiny_host deep.la 2>&1) || rc=$?
    rc2=0; timeout 60 ./tiny_host nest.la > nest.out 2>&1 || rc2=$?
    if [ "$rc" = 0 ] && [ "$got" = "$want" ] && [ "$rc2" = 1 ] && grep -q 'C stack guard' nest.out; then
        pass "host_deeprec: SUM(100000) non-tail = $want; 60M-deep nesting still halts loudly (rc 1)"
    else fail "host_deeprec: SUM(100000) rc=$rc got '$(printf '%s' "$got" | tr '\n' '|' | cut -c1-120)' (want $want); nest rc=$rc2 '$(oneline nest.out)'"; fi
    rm -f nest.la
}

CASES="${*:-host_selfref host_order host_caps host_diag host_lexlit host_procread host_importcwd host_deeprec}"
for c in $CASES; do "case_$c"; done
[ "$FAILS" -eq 0 ] && { echo "gate_audit2_host: all passed"; exit 0; } || { echo "gate_audit2_host: $FAILS failed"; exit 1; }
