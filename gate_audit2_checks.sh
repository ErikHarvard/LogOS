#!/bin/bash
# gate_audit2_checks.sh — witnesses for the audit-2 "checks that cannot fail"
# fixes (batch E). Each chk_ case PLANTS the defect its check exists to catch (a
# mutant, built here in the temp dir, never in the tree) and requires the check
# to go RED on it, then requires the same check GREEN on the real code. Run on
# the unfixed tree, the mutant half FAILS (the old check stayed green).
#   usage: ./gate_audit2_checks.sh [case ...]     (no args = every case)
set -u
REPO=$(cd "$(dirname "$0")" && pwd)
W=$(mktemp -d "${TMPDIR:-/tmp}/gate_audit2_checks.XXXXXX")
trap 'rm -rf "$W"' EXIT
cd "$W"
gcc -O2 -o tiny_host "$REPO/tiny_host.c" || { echo "FAIL  gate: cannot build tiny_host"; exit 1; }
cp "$REPO"/*.la .
FAILS=0
pass() { echo "PASS  $*"; }
fail() { echo "FAIL  $*"; FAILS=$((FAILS+1)); }
# has <file> <exact line> — grep -x on a fixed string
has() { grep -qxF "$2" "$1"; }

# ── #37 glyphdag_spec: INTERNB/INTERNU tests must call the glyph ──────────────
# Mutant: the INTERNB/INTERNU spec entries carry a wrong implementation (returns
# the table untouched, index 0). Unfixed, the probes `la g. "ib"` never call g:
# both rows PASS and the module is VERIFIED.
chk_glyphdag_intern() {
    sed -e 's/(SRC_INTERNB)(INTERNB)/(SRC_INTERNB)(la self. la sym. la a. la b. la tbl. PAIRc(tbl)(0))/' \
        -e 's/(SRC_INTERNU)(INTERNU)/(SRC_INTERNU)(la self. la sym. la a. la tbl. PAIRc(tbl)(0))/' \
        -e 's/("glyphdag.la")/("t_gd_mut.la")/' glyphdag_spec.la > t_gd_mut_spec.la
    sed -e 's/("glyphdag.la")/("t_gd_real.la")/' glyphdag_spec.la > t_gd_real_spec.la
    timeout 120 ./tiny_host t_gd_mut_spec.la > gd_mut.out 2>&1
    timeout 120 ./tiny_host t_gd_real_spec.la > gd_real.out 2>&1
    if ! has gd_mut.out "  INTERNB: FAIL" || ! has gd_mut.out "  INTERNU: FAIL"; then
        fail "glyphdag #37: mutant INTERNB/INTERNU not caught — $(grep -E '^  INTERN[BU]: |^RESULT' gd_mut.out | tr '\n' '|')"
    elif has gd_real.out "  INTERNB: PASS" && has gd_real.out "  INTERNU: PASS" && grep -q 'module VERIFIED' gd_real.out; then
        pass "glyphdag #37: INTERNB/INTERNU tests call the glyph — mutant FAILs, real PASSes"
    else fail "glyphdag #37: real spec not verified — $(grep -E '^  INTERN[BU]: |^RESULT' gd_real.out | tr '\n' '|')"; fi
}

# ── #126 psc_spec: SYN_DUR's second test must discriminate ────────────────────
# Mutant: SYN_DUR = "the second argument" (equals max on (6560,6720) only).
# Unfixed, test 2 is lt(g(a)(b))(a+b), true for max/min/either/mean: PASS.
chk_psc_syndur() {
    sed -e 's/(SRC_SYNDUR)(SYN_DUR)/(SRC_SYNDUR)(la da. la db. db)/' -e 's/("psc.la")/("t_psc_mut.la")/' psc_spec.la > t_psc_mut_spec.la
    sed -e 's/("psc.la")/("t_psc_real.la")/' psc_spec.la > t_psc_real_spec.la
    timeout 120 ./tiny_host t_psc_mut_spec.la > psc_mut.out 2>&1
    timeout 120 ./tiny_host t_psc_real_spec.la > psc_real.out 2>&1
    if ! has psc_mut.out "  SYN_DUR: FAIL"; then fail "psc #126: SYN_DUR=second-arg mutant not caught — $(grep -E '^  SYN_DUR: |^RESULT' psc_mut.out | tr '\n' '|')"
    elif has psc_real.out "  SYN_DUR: PASS" && grep -q 'module VERIFIED' psc_real.out; then pass "psc #126: SYN_DUR tests reject a non-max implementation; real SYN_DUR PASSes"
    else fail "psc #126: real spec not verified — $(grep -E '^  SYN_DUR: |^RESULT' psc_real.out | tr '\n' '|')"; fi
}

CASES="${*:-glyphdag_intern psc_syndur}"
for c in $CASES; do "chk_$c"; done
[ "$FAILS" -eq 0 ] && { echo "gate_audit2_checks: all passed"; exit 0; } || { echo "gate_audit2_checks: $FAILS failed"; exit 1; }
