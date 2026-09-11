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
#
# ── ★ A SKIP IS NOT A PASS (METANOĒ, 2026-09-11; owed since POROS's board :20988 and :21193) ──
# buildla.la used to print a skipped stage as "  PASS  vm  (skipped) <reason>", and this gate
# counted every "  PASS  " line toward MINPASS. In a fresh export, with no pre-built ELFs, the
# 8 QEMU stages that skip were counted as passes, so "110 steps" overstated coverage by 8 and a
# run whose stages mostly skipped could still clear the non-vacuity guard. buildla.la now prints
# "  SKIP  <kind>  <reason>". This gate counts only REAL passes toward MINPASS and reports skips
# as their own number, with their reasons. It still counts the old "(skipped)" spelling as a
# skip, so a stale buildla.la cannot fold skips back into passes.
# The PASS line keeps "ran N steps with M failures", with N = passed + skipped as before, because
# kernel/buildla_verdict.sh parses exactly that phrase; the split follows it.
# ── OFFLINE MODE, for this gate's own red paths: GATE_BUILDLA_OUT=<file> judges a recorded buildla
#    output (with GATE_BUILDLA_RC, default 0) and builds and runs nothing.
set -u
cd "$(dirname "$0")" || exit 1
# ★ 91 IS MEASURED, NOT GUESSED. The first passing run reported exactly 91 steps,
#  matching ROADMAP's "buildla at 91/103". The initial threshold here was 10 -- a
#  placeholder written before anything had ever run this file -- and 10 would not
#  have noticed buildla silently dropping EIGHTY steps while still reporting zero
#  failures. A non-vacuity guard set far below the true value is barely a guard.
#  Raise this as buildla grows. A DROP must be explained, not accommodated: if a
#  legitimate refactor merges steps, change the number in the same commit that
#  merges them, so the reduction is a stated decision rather than a silent one.
#  Since 2026-09-11 it is compared with REAL passes only (skips excluded): 102 in a fresh export.
MINPASS="${MINPASS:-91}"

if [ -n "${GATE_BUILDLA_OUT:-}" ]; then
    [ -r "$GATE_BUILDLA_OUT" ] || { echo "FAIL  buildla: GATE_BUILDLA_OUT=$GATE_BUILDLA_OUT is not readable"; exit 1; }
    OUT=$(cat "$GATE_BUILDLA_OUT"); rc="${GATE_BUILDLA_RC:-0}"
else
    [ -f buildla.la ] || { echo "SKIP  buildla: buildla.la absent"; exit 0; }
    [ -x ./tiny_host ] || { echo "SKIP  buildla: tiny_host not built"; exit 0; }

    # ── ★ IT MUST RUN ON THE VM, NOT tiny_host ─────────────────────────────────
    # The first version of this gate ran `./tiny_host buildla.la` and got
    # `eval error: unbound variable 'fork'` in 11 milliseconds. That was MY error,
    # not a defect in buildla.la: it orchestrates a build, so it needs fork/execv/
    # dup2/waitpid, and those live in the SECD VM (secd.asm has all four) while
    # tiny_host has NONE of them. An orchestrator cannot run on an interpreter that
    # cannot spawn a process.
    #   The non-vacuity guard below is what caught it: 3 lines of output, so the gate
    #   refused to draw any verdict rather than reporting "0 FAILs". That is exactly
    #   what it was written for, and it earned its place on the first run.
    rm -f logos_secd logos_program.bin logos_source.la
    ./tiny_host secd.la >/dev/null 2>&1
    [ -x ./logos_secd ] || { echo "SKIP  buildla: could not build logos_secd from secd.la"; exit 0; }
    cp buildla.la logos_source.la
    ./tiny_host codegen.la >/dev/null 2>&1
    [ -s logos_program.bin ] || { echo "FAIL  buildla: codegen produced no program from buildla.la"; exit 1; }
    OUT=$(timeout 3600 ./logos_secd 2>&1); rc=$?
    rm -f logos_secd logos_program.bin logos_source.la
fi

lines=$(printf '%s\n' "$OUT" | grep -c .)
if [ "$lines" -lt 5 ]; then
    echo "FAIL  buildla: produced only $lines lines (rc=$rc) — it did not run, so every"
    echo "      verdict below would be drawn from an empty output"
    printf '%s\n' "$OUT" | tail -3 | sed 's/^/        /'
    exit 1
fi

npass_all=$(printf '%s\n' "$OUT" | grep -c '  PASS  ')
nskip_old=$(printf '%s\n' "$OUT" | grep '  PASS  ' | grep -c '(skipped)')
nskip_new=$(printf '%s\n' "$OUT" | grep -c '^  SKIP  ')
npass=$((npass_all - nskip_old))
nskip=$((nskip_new + nskip_old))
nfail=$(printf '%s\n' "$OUT" | grep -c '  FAIL  ')

ok=1
if [ "$nfail" -ne 0 ]; then
    echo "FAIL  buildla: $nfail step(s) reported FAIL:"
    printf '%s\n' "$OUT" | grep '  FAIL  ' | head -10 | sed 's/^/        /'
    ok=0
fi
if [ "$npass" -lt "$MINPASS" ]; then
    echo "FAIL  buildla: only $npass REAL PASS lines ($nskip skipped, which do not count), expected at"
    echo "      least $MINPASS — 'zero FAILs' is trivially true of a run that printed nothing, and"
    echo "      a skip is not a pass. Raise MINPASS as buildla grows; never lower it to make a run go green."
    ok=0
fi
if [ "$nskip" -gt 0 ]; then
    echo "      skipped, not passed ($nskip):"
    printf '%s\n' "$OUT" | grep -e '^  SKIP  ' -e '  PASS  .*(skipped)' | head -20 | sed 's/^ */        /'
fi

[ "$ok" = 1 ] && echo "PASS  buildla: the LA build driver ran $((npass + nskip)) steps with 0 failures (rc=$rc): $npass passed, $nskip skipped (a skip is not a pass) — marker, cross-engine, guard, namespace and QEMU kinds, including its own negative steps asserting the VM halts loudly on an unbound variable, a non-function application, chr out of range and a non-string argument. Honest scope: this gates that buildla REPORTS a clean run of the stages it currently drives; it does not assert how many of build.sh's stages it has reached." || { echo "buildla gate RED"; exit 1; }
