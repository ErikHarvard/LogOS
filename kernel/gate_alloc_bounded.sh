#!/usr/bin/env bash
# LogOS allocation-boundedness gate — DOES MEMORY SCALE WITH WORK WHEN NOTHING
# IS LIVE? It must not. In July it did, and this gate was RED on purpose (table
# below). Since the rt_gc fix it does not, and the gate is GREEN and wired.
#
# ── THE CRITERION ───────────────────────────────────────────────────────────
# kernel/alloc_churn.la is a tail-recursive countdown. `sub(n)(1)` and
# `int_eq(n)(0)` each box an int and every box is dead immediately, so AT ANY
# INSTANT THE LIVE SET IS ONE INTEGER. The recursion is in tail position and the
# runtime does TCO, so the stack does not grow. Peak RSS must therefore be FLAT
# in the iteration count.
#
# The test TRIPLES the work and requires memory not to follow. Measured
# 2026-07-19, the defect this gate was written to catch:
#     N=1,000       0.75 MB   <- baseline: startup costs essentially nothing
#     N=5,000,000     170 MB
#     N=15,000,000    300 MB
#     N=45,000,000    519 MB
#     N=135,000,000   905 MB
# ~1.74x memory per 3x work. The GC reclaims SOMETHING (the 135M run allocates
# ~3.2 GB of boxes yet peaks at 905 MB) but never plateaus.
#
# Measured 2026-09-10, same program, current runtime, each run printing `done`
# and exiting 0:
#     N=15,000,000    4.0 MB    1.15 s
#     N=135,000,000   4.0 MB   10.11 s
# Time linear in work, memory FLAT at July's worst point. Most plausibly
# f9096e0 (2026-08-22, "rt_gc: trigger on allocation volume, not frontier
# position"), the only runtime change on track-d since July — not bisected.
#
# ── WHY A RATIO AND NOT A BYTE BUDGET ───────────────────────────────────────
# An absolute bar ("must stay under 32 MB") would encode MY guess about what a
# repaired collector ought to use, and would then be a check on my guess rather
# than on the system. The ratio tests the PROPERTY the program actually claims:
# memory does not scale with work. It also cannot be satisfied by a collector
# that is merely tuned to a smaller constant — only by one that stops growing.
# Baseline is reported alongside so a reader can see the absolute cost too.
#
# ── WHY THIS GATE EXISTS ────────────────────────────────────────────────────
# It is the companion to kernel/gate_hal_idle.sh. That one shows the SYMPTOM on
# bare metal (every HAL.4x compositor dies in ~6 s when the heap overruns the LA
# stack at 128 MiB); this one shows the CAUSE on Linux in seconds, with no QEMU
# and no kernel build. Whoever repairs the allocator/collector
# (native_codegen3_rt.asm — track A) can run this to see the fix land, and it
# turns green the moment memory stops scaling.
#
# ── ★ 2026-09-10 — THE GREEN COULD NOT SAY NO, AND I WIRED IT ANYWAY ────────
# rss() was `/usr/bin/time -v "$BIN" 2>&1 >/dev/null | awk '/Maximum resident/…'`.
# /usr/bin/time reports a max-RSS for a program that died at its FIRST
# INSTRUCTION; >/dev/null threw away the program's own `done`; the pipe threw
# away its exit status. So a program that did NOTHING peaked at ~1 MB, walked
# through the 64 MB floor door below, and PASSED — "15000000 iterations peaked
# at 1 MB", the count being the one the harness ASKED for. Red-tested with a
# stand-in that `exit 3`s: PASS, rc 0. It was wired (da04585) on a green that
# happened to be true, with no red path stated.
# ⇒ Now every run must exit 0 AND print the program's own completion witness
# before its RSS is read at all. The wrapper's report describes a PROCESS; only
# the subject's witness says the WORK was done.
#
# ★ And it rebuilt only when alloc_churn.la was newer than the binary — keyed to
# the SOURCE, while what this gate tests is the compiler's RUNTIME. A runtime
# regression would have been judged on a stale binary: the stale-artifact hole
# gate_hal4g and gate_hal4f had. Through kernel/ncc3.sh the build is seconds,
# so it always rebuilds.
#
# Usage: kernel/gate_alloc_bounded.sh [N]     (default 5000000; also runs 3N)
set -uo pipefail
cd "$(dirname "$0")/.."

N="${1:-5000000}"
N3=$((N * 3))
BUILT=kernel/alloc_churn.bin
BIN="$BUILT"

if ! command -v /usr/bin/time >/dev/null 2>&1; then
    echo "SKIP  alloc-boundedness gate: /usr/bin/time not available (need max-RSS)"
    exit 0
fi

# ALWAYS build. It writes the SHARED fixed paths native_input.la /
# native_codegen3_out, so the old output is removed first (a stale one must not
# pass for this compile's) and the result is copied to a dedicated name at once.
# ★ 2026-09-08, kept: ENVIRONMENT vs ARTIFACT. Skipping on an absent
# /usr/bin/time above is legitimate — the machine cannot measure RSS. The
# compiler is a thing THIS REPO BUILDS, so a failed build means the gate could
# not test its subject, and that must not be spelled like "everything passed".
rm -f native_codegen3_out
cp kernel/alloc_churn.la native_input.la
if ! bash kernel/ncc3.sh >/dev/null 2>&1 || [ ! -f native_codegen3_out ]; then
    echo "FAIL  alloc-boundedness gate: could not compile alloc_churn.la through kernel/ncc3.sh,"
    echo "      so this gate tested NOTHING. The compiler is an artifact this repo builds,"
    echo "      not environment — run ./build.sh first."
    exit 1
fi
cp native_codegen3_out "$BUILT" && chmod +x "$BUILT"

TF=$(mktemp); EF=$(mktemp)
trap 'rm -f "$TF" "$EF" churn.n' EXIT

rss() {  # rss <iterations> -> peak RSS in KB; returns 1 unless the PROGRAM says it finished
    printf '%s' "$1" > churn.n
    local out rc
    out=$(/usr/bin/time -o "$TF" -f '%M' "$BIN" 2>"$EF"); rc=$?
    if [ "$rc" -ne 0 ] || [ "$out" != "done" ]; then
        echo "FAIL  alloc-boundedness gate: alloc_churn N=$1 did not finish — rc=$rc, stdout='${out:0:60}', stderr='$(head -c 120 "$EF")'." >&2
        echo "      Its max-RSS would describe a process that did not do the work, so it is not read." >&2
        return 1
    fi
    tail -n 1 "$TF"
}

BASE=$(rss 1000) || exit 1
R1=$(rss "$N") || exit 1
R3=$(rss "$N3") || exit 1

if [ -z "$BASE" ] || [ -z "$R1" ] || [ -z "$R3" ]; then
    echo "FAIL  alloc-boundedness gate: could not measure RSS (time -o wrote nothing)"; exit 1
fi

printf '      baseline (N=1000): %d MB | N=%s: %d MB | N=%s: %d MB\n' \
       "$((BASE/1024))" "$N" "$((R1/1024))" "$N3" "$((R3/1024))"

# Ratio in tenths, integer arithmetic (no bc dependency).
RATIO10=$(( R3 * 10 / (R1 > 0 ? R1 : 1) ))
BAR10=12        # 1.2x — tripling the work may cost a little noise, not half again
FLOOR_KB=65536  # 64 MB

# TWO DOORS, because the ratio ALONE has a false-FAIL mode and this gate was
# caught in it. Run at N=1000 the measurements are 0.75 MB and 2 MB — page
# granularity, not allocation — and the ratio reads 3.0x, failing a system that
# is behaving perfectly. Found by testing the gate's GREEN path, which is the
# half of "gate the red path" that is easy to skip: a check that cannot pass is
# as useless as one that cannot fail.
#
# The claim is "memory does not grow with work", and that is satisfied EITHER by
# not scaling OR by staying small in absolute terms. So: under the floor, the
# workload is trivially bounded and the ratio is not consulted at all; over it,
# the numbers are big enough for the ratio to mean something.
# ★ The floor door is only sound because rss() now refuses a run that did not
# finish: before 2026-09-10 it was also the door a DEAD program walked through.
if [ "$R3" -lt "$FLOOR_KB" ]; then
    echo "PASS  alloc-boundedness: alloc_churn counted down ${N3} iterations and said so; peak $((R3/1024)) MB, under the $((FLOOR_KB/1024)) MB floor — memory is bounded regardless of ratio."
    exit 0
fi

if [ "$RATIO10" -lt "$BAR10" ]; then
    echo "PASS  alloc-boundedness: 3x the work cost ${RATIO10}/10 x the memory — memory does not scale with work."
    exit 0
fi

echo "FAIL  alloc-boundedness: 3x the work cost ${RATIO10}/10 x the memory (bar: <${BAR10}/10)."
echo "      A loop whose live set never exceeds ONE INTEGER is consuming memory in"
echo "      proportion to the work it does. The collector reclaims something but never"
echo "      plateaus, so a long-running LA program exhausts any bound."
echo "      On bare metal the first bound it meets is not HEAP_END (16.07 GiB, unreachable"
echo "      on a 512 MiB machine) but the LA STACK at 128 MiB — so instead of halting it"
echo "      overwrites the live frames and control lands in garbage. That is the ~6 second"
echo "      death in kernel/gate_hal_idle.sh. Fix lives in native_codegen3_rt.asm (track A)."
exit 1
