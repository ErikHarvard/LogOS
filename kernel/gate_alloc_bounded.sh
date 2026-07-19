#!/usr/bin/env bash
# LogOS allocation-boundedness gate — DOES MEMORY SCALE WITH WORK WHEN NOTHING
# IS LIVE? It must not. Today it does, so this gate is RED on purpose.
#
# ── THE CRITERION ───────────────────────────────────────────────────────────
# kernel/alloc_churn.la is a tail-recursive countdown. `sub(n)(1)` and
# `int_eq(n)(0)` each box an int and every box is dead immediately, so AT ANY
# INSTANT THE LIVE SET IS ONE INTEGER. The recursion is in tail position and the
# runtime does TCO, so the stack does not grow. Peak RSS must therefore be FLAT
# in the iteration count.
#
# The test TRIPLES the work and requires memory not to follow. Measured today:
#     N=1,000       0.75 MB   <- baseline: startup costs essentially nothing
#     N=5,000,000     170 MB
#     N=15,000,000    300 MB
#     N=45,000,000    519 MB
#     N=135,000,000   905 MB
# ~1.74x memory per 3x work. The GC reclaims SOMETHING (the 135M run allocates
# ~3.2 GB of boxes yet peaks at 905 MB) but never plateaus.
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
# Usage: kernel/gate_alloc_bounded.sh [N]     (default 5000000; also runs 3N)
set -uo pipefail
cd "$(dirname "$0")/.."

N="${1:-5000000}"
N3=$((N * 3))
BIN=kernel/alloc_churn.bin

if ! command -v /usr/bin/time >/dev/null 2>&1; then
    echo "SKIP  alloc-boundedness gate: /usr/bin/time not available (need max-RSS)"
    exit 0
fi

# Build only when stale. The codegen is ~25 s even for a program this small, and
# it writes the SHARED fixed paths native_input.la / native_codegen3_out, so the
# result is copied to a dedicated name immediately and the gate runs that —
# a concurrent build in this worktree cannot then be mistaken for ours.
if [ ! -x "$BIN" ] || [ kernel/alloc_churn.la -nt "$BIN" ]; then
    if [ ! -x ./tiny_host ] || [ ! -f native_codegen3.la ]; then
        echo "SKIP  alloc-boundedness gate: tiny_host/native_codegen3.la absent"
        exit 0
    fi
    echo "      building alloc_churn (~25 s, codegen is superlinear)"
    cp kernel/alloc_churn.la native_input.la
    ./tiny_host native_codegen3.la >/dev/null 2>&1 || {
        echo "FAIL  alloc-boundedness gate: could not compile alloc_churn.la"; exit 1; }
    cp native_codegen3_out "$BIN"
fi

rss() {  # rss <iterations> -> peak RSS in KB, or empty on failure
    printf '%s' "$1" > churn.n
    /usr/bin/time -v "$BIN" 2>&1 >/dev/null | awk '/Maximum resident/{print $6}'
}

BASE=$(rss 1000)
R1=$(rss "$N")
R3=$(rss "$N3")
rm -f churn.n

if [ -z "$BASE" ] || [ -z "$R1" ] || [ -z "$R3" ]; then
    echo "FAIL  alloc-boundedness gate: could not measure RSS (run failed)"; exit 1
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
if [ "$R3" -lt "$FLOOR_KB" ]; then
    echo "PASS  alloc-boundedness: ${N3} iterations peaked at $((R3/1024)) MB, under the $((FLOOR_KB/1024)) MB floor — memory is bounded regardless of ratio."
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
