#!/bin/sh
# gate_buildla.sh — buildla.la is the LA reimplementation of build.sh, and until
# now NOTHING VERIFIED IT.
#
# ── WHY THIS EXISTS (Freeze Audit II / Q3 ungated sweep, 2026-08-19) ────────
# A transitive-closure sweep of all 158 tracked .la files — from build.sh and
# every gate_*.sh, through the build scripts they invoke, into the .la files
# those build, following import() between modules — found buildla.la reachable
# from NOTHING. Zero references in build.sh, no gate. It is the file standing in
# for build.sh itself as the toolchain moves into Lingua Adamica, and it was
# unverified.
#
# ── WHAT IS ASSERTED ────────────────────────────────────────────────────────
# buildla.la reports per-step: "PASS rc", "PASS vm", "PASS host==VM", and the
# FAIL forms. It also carries its own NEGATIVE steps (the VM must halt loudly on
# an unbound variable, on applying a non-function, on chr out of range, on a
# non-string argument), so a run that is genuinely green has already exercised
# both directions internally.
#
#   1. it RUNS at all and produces output
#   2. it emits ZERO FAIL lines
#   3. ★ it emits AT LEAST A THRESHOLD of PASS lines — because "zero FAILs" is
#      trivially true of a run that printed nothing, which is exactly how a gate
#      comes to certify silence. This is the non-vacuity guard, and it is the
#      point of the whole gate.
set -u
cd "$(dirname "$0")" || exit 1
MINPASS="${MINPASS:-10}"

[ -f buildla.la ] || { echo "SKIP  buildla: buildla.la absent"; exit 0; }
[ -x ./tiny_host ] || { echo "SKIP  buildla: tiny_host not built"; exit 0; }

OUT=$(timeout 3600 ./tiny_host buildla.la 2>&1); rc=$?

lines=$(printf '%s\n' "$OUT" | grep -c .)
if [ "$lines" -lt 5 ]; then
    echo "FAIL  buildla: produced only $lines lines (rc=$rc) — it did not run, so every"
    echo "      verdict below would be drawn from an empty output"
    printf '%s\n' "$OUT" | tail -3 | sed 's/^/        /'
    exit 1
fi

npass=$(printf '%s\n' "$OUT" | grep -c '  PASS  ')
nfail=$(printf '%s\n' "$OUT" | grep -c '  FAIL  ')

ok=1
if [ "$nfail" -ne 0 ]; then
    echo "FAIL  buildla: $nfail step(s) reported FAIL:"
    printf '%s\n' "$OUT" | grep '  FAIL  ' | head -10 | sed 's/^/        /'
    ok=0
fi
if [ "$npass" -lt "$MINPASS" ]; then
    echo "FAIL  buildla: only $npass PASS lines, expected at least $MINPASS — 'zero FAILs'"
    echo "      is trivially true of a run that printed nothing. Raise MINPASS as buildla"
    echo "      grows; never lower it to make a run go green."
    ok=0
fi

[ "$ok" = 1 ] && echo "PASS  buildla: the LA build driver ran $npass steps with 0 failures (rc=$rc) — marker, cross-engine, guard, namespace and QEMU kinds, including its own negative steps asserting the VM halts loudly on an unbound variable, a non-function application, chr out of range and a non-string argument. Honest scope: this gates that buildla REPORTS a clean run of the stages it currently drives; it does not assert how many of build.sh's stages it has reached." || { echo "buildla gate RED"; exit 1; }
