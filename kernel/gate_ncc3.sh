#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  gate_ncc3.sh — the gate on kernel/ncc3.sh and on the conversion it enabled.
#
#  WHAT WAS CONVERTED, AND WHY IT NEEDED A GUARD
#  35 kernel builders compiled their driver with `./tiny_host native_codegen3.la`
#  — the compiler's SOURCE, interpreted — while 34 others already ran the
#  COMMITTED native binary native_codegen3_selfhost.bin. Same compiler, ~100x
#  apart: build.sh's own annotations measure gate_mouse at 883 s and gate_wheel
#  at 1255 s against gate_comp_term_hal4e at 16 s, and say the cost is
#  "dominated by the LA COMPILE, not the QEMU run". The 35 now call
#  kernel/ncc3.sh.
#
#  ★ THE CENSUS BELOW IS THE POINT. A conversion with no guard is undone by the
#  next builder someone writes in the old shape — silently, because the slow
#  path is CORRECT, just 100x slower. Nothing would ever go red; the kernel half
#  would just quietly get expensive again. So this gate fails on any builder
#  that calls the slow compiler directly, and it names the one deliberate
#  exclusion rather than pattern-matching around it.
#
#  ★ THE EXCLUSION IS LOAD-BEARING, NOT AN EXEMPTION. kernel/build_hh1b.sh
#  compiles with native_codegen3_hh.la — a DIFFERENT compiler.
#  native_codegen3_selfhost.bin is the fixed point of native_codegen3.la ONLY
#  (build.sh Stage 4), so routing hh1b through ncc3.sh would silently build the
#  higher-half kernel with the wrong compiler and it would probably still pass.
#  That is why the exclusion is asserted BY NAME here: if hh1b ever stops using
#  the hh compiler, this gate says so instead of leaving a stale carve-out.
#
#  Costs ~1 s. No QEMU, no compile.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
cd "$(dirname "$0")/.."

ok=1
SLOW='./tiny_host native_codegen3.la'
EXCLUDED=kernel/build_hh1b.sh

[ -x kernel/ncc3.sh ] || { echo "FAIL  ncc3: kernel/ncc3.sh missing or not executable"; exit 1; }

# ── 1. the census: no builder may call the slow compiler outside a fast path ──
slow_files=""
for b in kernel/build_*.sh; do
    # ★ BOTH SIDES MUST STRIP COMMENTS, AND I FIXED ONLY ONE. When the exemption
    # below was raw, three builders that merely MENTIONED the image in a comment
    # were skipped while running the slow path. I fixed that line and left THIS
    # one raw — so two builders that now mention the SLOW compiler only in a
    # comment were wrongly flagged. Same defect, same file, one line apart, in
    # opposite directions: a raw detector false-POSITIVES, a raw exemption
    # false-NEGATIVES. Comments are not execution paths on either side of a test.
    sed -e 's/[[:space:]]*#.*$//' "$b" | grep -qF "$SLOW" || continue
    # A match inside a builder that ALSO knows the fast path is that path's own
    # `else` fallback, which is correct and must not be flagged.
    # ★ A COMMENT IS NOT AN EXECUTION PATH — 041631a's defect, committed in the
    # gate written to catch drift back to the slow path. This exemption used a
    # RAW grep, so three builders that merely MENTION the image in a comment
    # while executing `./tiny_host native_codegen3.la` were skipped, and this
    # gate reported PASS over them: build_nic5q_ctrl, build_nic5r_ctrl,
    # build_nic5r. Strip comments before deciding a file has a fast path.
    sed -e 's/[[:space:]]*#.*$//' "$b" | grep -q 'native_codegen3_selfhost' && continue
    slow_files="$slow_files $b"
done
if [ -n "$slow_files" ]; then
    echo "FAIL  ncc3 census: these builders still call the SLOW compiler directly and will cost ~15 min per run instead of ~2 s —$slow_files"
    echo "      Fix: replace \`$SLOW\` with \`bash kernel/ncc3.sh\`. If the builder needs a DIFFERENT compiler, it must not use ncc3.sh — add it to this gate's exclusion list with the reason, as build_hh1b.sh is."
    ok=0
fi

# ── 2. the exclusion is still real, and still needed ─────────────────────────
#  Red-tested by construction: if hh1b were converted, or stopped using the hh
#  compiler, this fails rather than silently keeping a carve-out no longer earned.
if [ ! -f "$EXCLUDED" ]; then
    echo "FAIL  ncc3: $EXCLUDED is gone — remove its exclusion from this gate too"; ok=0
elif ! grep -qE '\./tiny_host +native_codegen3_hh\.la' "$EXCLUDED"; then
    echo "FAIL  ncc3: $EXCLUDED no longer compiles with native_codegen3_hh.la, so its exclusion from the fast path is stale — re-check whether it should now use kernel/ncc3.sh"; ok=0
elif grep -q 'ncc3.sh' "$EXCLUDED"; then
    echo "FAIL  ncc3: $EXCLUDED was routed through kernel/ncc3.sh, but selfhost.bin is the fixed point of native_codegen3.la, NOT native_codegen3_hh.la — this would build the higher-half kernel with the WRONG COMPILER"; ok=0
fi

# ── 3. conversion actually happened (anti-vacuity floor) ─────────────────────
#  Checks 1 and 2 are both satisfied by a tree where nothing was converted at
#  all. This floor is what makes that case fail. A floor, not a pin: adding a
#  36th caller must not be an event, a collapse must be.
CALLERS=$(grep -lF 'bash kernel/ncc3.sh' kernel/build_*.sh 2>/dev/null | grep -c .)
[ "$CALLERS" -ge 30 ] \
  || { echo "FAIL  ncc3: only $CALLERS builders call kernel/ncc3.sh — 35 were converted, so the conversion has been reverted or the helper renamed. Checks 1 and 2 above both PASS on a tree where nothing was converted, which is why this floor exists"; ok=0; }

# ── 4. the helper fails LOUDLY, and falls back rather than skipping ──────────
#  ⚠ THIS CHECK MUTATES native_input.la AND native_codegen3_out — the fixed
#  paths every builder uses. ncc3.sh reads native_input.la by contract, so a
#  red-test of a failing compile cannot avoid writing it. It saves and restores,
#  but a build running CONCURRENTLY in this worktree can still be corrupted mid
#  compile. Measured the hard way: this check ran during a 15-minute reference
#  compile and made that measurement undefendable, so it was discarded and
#  redone. Do not run this gate alongside a build in the same worktree.
#  Red-tested against a broken input: a compiler failure must propagate non-zero
#  so a caller's `set -e` still aborts. A helper that swallowed rc would make
#  every builder report success on a failed compile.
# ★ REFUSE rather than corrupt. A comment saying "do not run this alongside a
# build" is not a guard, and I proved that twice in ten minutes: I documented
# the hazard, then ran this gate during a 15-minute reference compile, twice,
# destroying the measurement both times. So the constraint is now enforced. A
# tiny_host or ncc3 compile in flight in THIS worktree means the mutation below
# would corrupt it, and a corrupted compile is worse than an unrun gate.
# ⚠ SCOPED BY WORKING DIRECTORY, not by process name. Five tracks share this
# machine and the other four run tiny_host almost continuously — a bare
# `pgrep -x tiny_host` refuses on THEIR compiles, which would make this gate
# unusable and teach people to skip it. Only a compile whose cwd is THIS
# worktree can touch this worktree's native_input.la.
HERE=$(pwd -P)
for pid in $(pgrep -x tiny_host 2>/dev/null); do
    [ "$(readlink -f "/proc/$pid/cwd" 2>/dev/null)" = "$HERE" ] || continue
    echo "FAIL  ncc3: a tiny_host compile (pid $pid) is in flight in THIS worktree. Check 4 below MUTATES native_input.la and would corrupt it. Re-run when the build is idle — a refusal, not a skip, because a silently corrupted compile is worse than an unrun check."
    exit 1
done
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
cp native_input.la "$T/saved_input.la" 2>/dev/null || true
printf 'glyph MAIN = (((( unclosed\n' > native_input.la
if bash kernel/ncc3.sh >/dev/null 2>&1; then
    echo "FAIL  ncc3: a malformed native_input.la compiled with exit 0 — the helper is swallowing the compiler's status, so every builder would report success on a failed compile"; ok=0
fi
cp "$T/saved_input.la" native_input.la 2>/dev/null || rm -f native_input.la

# ── 5. the fallback path exists and is ANNOUNCED, never silent ───────────────
grep -q 'NOTE  ncc3' kernel/ncc3.sh \
  || { echo "FAIL  ncc3: the tiny_host fallback is not announced — a build that silently got 100x slower would be indistinguishable from one that did not"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  ncc3: the second toll is wired shut — $CALLERS kernel builders compile through the COMMITTED native_codegen3_selfhost.bin via one shared helper instead of ~15 min of interpreted tiny_host each, and NO builder calls the slow compiler outside a fast path's own fallback; build_hh1b.sh stays excluded BY NAME because it compiles with native_codegen3_hh.la and selfhost.bin is not its fixed point (asserted, so the carve-out cannot go stale); a failed compile still propagates non-zero (red-tested with malformed input, not assumed) and the fallback is announced rather than silent"
[ "$ok" -eq 1 ]
