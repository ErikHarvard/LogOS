#!/bin/sh
# gate_rss.sh — the rt_gc frontier-drift acceptance test, executable.
#
# Commits the sqrt(allocs) leak as a RED baseline and flips GREEN when the
# allocation-volume GC trigger (GCfix2b) bounds it.  A writes the asm; this
# gate reads only the number heapscope reports -- they meet on that number,
# never on a shared file (the coordination rule).
#
# WHY A PEAK-HEAP GATE AND NOT total RSS: the arena shares one giant PT_LOAD
# with worklist+bitmap, so process RSS conflates them; heapscope's per-region
# pagemap read isolates the heap, which is the region that drifts.  And it
# measures a LIVE process with heapscope's liveness rule, so it can never again
# read a crashing run as a plateau -- the exact failure that voided D's
# retracted conclusions today.
#
# ISOLATION: builds its workload in a private scratch dir (mktemp -d), so it
# touches no tracked file and no /tmp path build.sh hardcodes -- no collision
# with a concurrent A build.  Needs: tiny_host, native_codegen3.la, heapscope.py
# (paths via env or the defaults below).
set -e

# ★ THE DEFAULT USED TO BE $HOME/logos, WHICH IS NOT NECESSARILY THIS TREE.
# Five worktrees share this script. A gate that measures ~/logos while being
# run from ~/logos-d reports on someone else's binaries and calls it a verdict
# -- and it does so SILENTLY, since ~/logos always exists and always has the
# prerequisites. Default to the directory the script itself lives in, the same
# discipline as build.sh's `cd "$(dirname "$0")"`, so the gate measures the
# tree it was invoked from. An explicit LOGOS= still overrides.
LOGOS="${LOGOS:-$(cd "$(dirname "$0")" && pwd)}"
HEAPSCOPE="${HEAPSCOPE:-$LOGOS/heapscope.py}"
BOUND_MIB="${BOUND_MIB:-64}"     # GREEN if peak heap <= this. Leak drives it to 100s-1000s.
N="${N:-4000000000}"             # big enough to outlive sampling and expose the drift

# ★ THIS SKIPPED TO GREEN, AND THE FILE 40 LINES AWAY SAID IT SHOULD NOT.
# It used to `echo "SKIP ..."; exit 0` on a missing prerequisite, while this
# gate's own call site (build.sh, Stage 3b (a'')) declares the opposite rule:
# "a gate file missing means a broken checkout, not an optional check". Same
# principle, same commit, opposite verdicts.
# What settles it is not style but a measurement: ALL THREE prerequisites are
# either TRACKED (native_codegen3.la, heapscope.py) or BUILT BY build.sh itself
# (tiny_host). So in any valid checkout they are always present, and this branch
# can ONLY fire when something is already broken -- whereupon it converted that
# broken state into exit 0. A SKIP standing in for a verdict is the skip-to-green
# shape; a gate whose own input is absent must go RED, not quietly pass.
# An explicit LOGOS=/HEAPSCOPE= pointing somewhere real remains the way to run
# this against another tree; it is absence that is now fatal, not relocation.
for f in "$LOGOS/tiny_host" "$LOGOS/native_codegen3.la" "$HEAPSCOPE"; do
    [ -e "$f" ] || { echo "FAIL  gate_rss: missing prerequisite $f -- it is tracked or built by build.sh, so its absence is a broken checkout, not a reason to pass"; exit 1; }
done

WD=$(mktemp -d)
# `kill` fails on the PASS path (the workload has already exited), and under
# `set -e` that aborted the trap: the script exited 1 on a PASS and never
# reached the `rm`, leaking the scratch dir.  `|| :` keeps the trap alive so
# the exit status stays the verdict's and the cleanup actually runs.
trap 'kill "$LAPID" 2>/dev/null || :; rm -rf "$WD"' EXIT
cp "$LOGOS/tiny_host" "$LOGOS/native_codegen3.la" "$WD/"

cat > "$WD/native_input.la" <<LA
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph IF = la c. la t. la f. c(t)(f)("!")
glyph COUNT = Z(la self. la n. la acc. IF(int_eq(n)(0))(la _. acc)(la _. self(sub(n)(1))(add(acc)(1))))
glyph MAIN = print(COUNT($N)(0))
LA

( cd "$WD" && ./tiny_host native_codegen3.la >/dev/null 2>&1 ) \
    || { echo "FAIL  gate_rss: could not build the workload binary"; exit 1; }

# launch, then find the REAL pid by exe match -- never $! (catches a wrapper sh)
( cd "$WD" && exec ./native_codegen3_out >/dev/null 2>&1 ) &
sleep 1
LAPID=""
for d in /proc/[0-9]*; do
    [ "$(readlink "$d/exe" 2>/dev/null)" = "$WD/native_codegen3_out" ] || continue
    LAPID="${d#/proc/}"; break
done
[ -n "$LAPID" ] || { echo "FAIL  gate_rss: workload process not found (exited too fast?)"; exit 1; }

# heapscope --peak samples heap until the workload exits, then gates on peak.
# `set -e` is on, so a bare call here ABORTED THE SCRIPT the moment heapscope
# exited non-zero -- `RC=$?` never ran and the whole verdict block below was
# dead code on every failing path.  The gate could print its PASS line and no
# other.  `|| RC=$?` keeps the status without tripping `set -e`.
RC=0
python3 "$HEAPSCOPE" "$LAPID" --peak --interval 2 --max-heap-mib "$BOUND_MIB" || RC=$?

# heapscope prints PASS/FAIL + the number; mirror its verdict as the gate's.
if [ "$RC" = 0 ]; then
    echo "PASS  gate_rss: heap bounded <= ${BOUND_MIB} MiB (frontier drift fixed)"
elif [ "$RC" = 1 ]; then
    # GCfix2b HAS landed (native_codegen3_rt.asm) and this gate measured GREEN
    # at 4.0 MiB peak against the 64 MiB bound on 2026-09-08, which is when it
    # was wired into build.sh. So a red here is no longer an expected baseline
    # -- it is a REGRESSION. The old wording said "expected RED until GCfix2b
    # lands" and would have told a reader to dismiss exactly that.
    echo "FAIL  gate_rss: heap UNBOUNDED -- frontier drift is BACK. GCfix2b landed and this gate measured 4.0 MiB peak when wired; this is a REGRESSION, not the old baseline"
else
    echo "FAIL  gate_rss: measurement error (rc=$RC) -- NOT a plateau, a broken run"
fi
exit "$RC"
