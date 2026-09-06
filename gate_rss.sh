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

LOGOS="${LOGOS:-$HOME/logos}"
HEAPSCOPE="${HEAPSCOPE:-$LOGOS/heapscope.py}"
BOUND_MIB="${BOUND_MIB:-64}"     # GREEN if peak heap <= this. Leak drives it to 100s-1000s.
N="${N:-4000000000}"             # big enough to outlive sampling and expose the drift

for f in "$LOGOS/tiny_host" "$LOGOS/native_codegen3.la" "$HEAPSCOPE"; do
    [ -e "$f" ] || { echo "SKIP  gate_rss: missing $f"; exit 0; }
done

WD=$(mktemp -d)
trap 'kill "$LAPID" 2>/dev/null; rm -rf "$WD"' EXIT
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
python3 "$HEAPSCOPE" "$LAPID" --peak --interval 2 --max-heap-mib "$BOUND_MIB"
RC=$?

# heapscope prints PASS/FAIL + the number; mirror its verdict as the gate's.
if [ "$RC" = 0 ]; then
    echo "PASS  gate_rss: heap bounded <= ${BOUND_MIB} MiB (frontier drift fixed)"
elif [ "$RC" = 1 ]; then
    echo "FAIL  gate_rss: heap UNBOUNDED -- the sqrt-leak is present (expected RED until GCfix2b lands)"
else
    echo "FAIL  gate_rss: measurement error (rc=$RC) -- NOT a plateau, a broken run"
fi
exit "$RC"
