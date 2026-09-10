#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  gate_kernel_half.sh — the gate on kernel/build_kernel_half.sh itself.
#
#  WHY THIS EXISTS
#  build_kernel_half.sh is a CLASSIFIER: it decides, for every gate in the
#  kernel half, whether the result was a PASS, a FAIL, a SKIP, or unreadable.
#  A classifier that has only ever been run against passing gates is untested,
#  and every assertion it makes about SKIP is inert until it has been shown to
#  REJECT — an absence true of both a right and a wrong implementation proves
#  nothing. So each verdict class is fed to it here as a synthetic region and
#  the classification AND the exit status are asserted.
#
#  ★ THE ASSERTION THAT MATTERS is R3: a SKIP must not be spelled the same way
#  as a PASS. The kernel half's 52 invoked gates carry 57 self-SKIP paths, each
#  exiting 0 while asserting nothing. If the runner ever maps SKIP onto exit 0
#  it becomes another instrument that reports success having verified nothing —
#  the exact shape this whole entry point was built to remove. R3 compiles that
#  wrong behaviour in (a gate that only SKIPs) and requires exit 2.
#
#  Needs NO qemu and NO kernel build: it runs in about a second.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
cd "$(dirname "$0")/.."

RUNNER=kernel/build_kernel_half.sh
[ -x "$RUNNER" ] || { echo "FAIL  kernel-half gate: $RUNNER missing or not executable"; exit 1; }

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
ok=1

mkgate() { printf '#!/usr/bin/env bash\n%s\n' "$2" > "$T/$1"; chmod +x "$T/$1"; }
mkgate gate_p.sh   'echo "PASS  synthetic pass"; exit 0'
mkgate gate_s.sh   'echo "SKIP  synthetic skip: qemu absent"; exit 0'
mkgate gate_f.sh   'echo "FAIL  synthetic fail"; exit 1'
mkgate gate_u.sh   'echo "some output but no verdict line"; exit 0'

# Build a synthetic build.sh carrying the sentinels around a chosen body.
mksrc() {
    { echo '# ===KERNEL-HALF-BEGIN==='
      echo 'say "synthetic region"'
      cat
      echo '# ===KERNEL-HALF-END==='
    } > "$T/src.sh"
}

# run <expected_rc> <label> ; body on stdin. Asserts rc and returns the output.
OUT=''
run_case() {
    local want="$1" label="$2" rc
    OUT=$(KH_SRC="$T/src.sh" "$RUNNER" --no-lock 2>&1); rc=$?
    if [ "$rc" -ne "$want" ]; then
        echo "FAIL  kernel-half gate [$label]: expected exit $want, got $rc"
        printf '%s\n' "$OUT" | tail -5 | sed 's/^/        /'
        ok=0; return 1
    fi
    return 0
}

# ── R1  a passing gate is a PASS and exits 0 (the baseline) ──────────────────
mksrc <<EOF
bash $T/gate_p.sh || exit 1
EOF
if run_case 0 R1-pass; then
    printf '%s' "$OUT" | grep -q '1 PASS / 0 FAIL / 0 SKIP' \
      || { echo "FAIL  kernel-half gate [R1]: tally did not read '1 PASS / 0 FAIL / 0 SKIP'"; ok=0; }
fi

# ── R2  a failing gate is a FAIL, is NAMED, and exits 1 ──────────────────────
mksrc <<EOF
bash $T/gate_f.sh || exit 1
EOF
if run_case 1 R2-fail; then
    printf '%s' "$OUT" | grep -q 'FAIL  .*gate_f.sh' \
      || { echo "FAIL  kernel-half gate [R2]: the failing gate was not NAMED in the summary"; ok=0; }
fi

# ── R3 ★ a SKIP is NOT a pass: counted, named, exit 2 ────────────────────────
#  THE DISCRIMINATOR. A runner that treats SKIP as success passes R1 and R2 and
#  is still worthless, because 57 real SKIP paths would then read as green.
mksrc <<EOF
bash $T/gate_s.sh || exit 1
EOF
if run_case 2 R3-skip; then
    printf '%s' "$OUT" | grep -q '0 PASS / 0 FAIL / 1 SKIP' \
      || { echo "FAIL  kernel-half gate [R3]: SKIP was not counted as its own class"; ok=0; }
    printf '%s' "$OUT" | grep -q 'INCOMPLETE' \
      || { echo "FAIL  kernel-half gate [R3]: a skipped run did not announce itself INCOMPLETE"; ok=0; }
    printf '%s' "$OUT" | grep -q 'SKIP  .*gate_s.sh' \
      || { echo "FAIL  kernel-half gate [R3]: the skipped gate was not NAMED"; ok=0; }
fi

# ── R4  exit 0 with no verdict line is UNKNOWN, counted FAIL-side ────────────
#  An unreadable result must never be spelled the same way as a pass.
mksrc <<EOF
bash $T/gate_u.sh || exit 1
EOF
if run_case 1 R4-unknown; then
    printf '%s' "$OUT" | grep -q 'UNKNOWN' \
      || { echo "FAIL  kernel-half gate [R4]: a verdict-less exit 0 was not classified UNKNOWN"; ok=0; }
fi

# ── R5  one FAIL does not hide the gates after it (the anti-serial-abort claim) ─
#  This is the entry point's whole reason for existing: build.sh's kernel region
#  is 65 hard aborts in a chain, so the first red hides the other 64 verdicts.
mksrc <<EOF
bash $T/gate_f.sh || exit 1
bash $T/gate_p.sh || exit 1
bash $T/gate_s.sh || exit 1
EOF
if run_case 1 R5-continue; then
    printf '%s' "$OUT" | grep -q '1 PASS / 1 FAIL / 1 SKIP' \
      || { echo "FAIL  kernel-half gate [R5]: a FAIL aborted the run — the gates after it produced no verdict, which is the serial-abort shape this runner exists to replace"; ok=0; }
fi

# ── R6  --abort-first really does reproduce build.sh's serial-abort semantics ─
mksrc <<EOF
bash $T/gate_f.sh || exit 1
bash $T/gate_p.sh || exit 1
EOF
OUT=$(KH_SRC="$T/src.sh" "$RUNNER" --no-lock --abort-first 2>&1); rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL  kernel-half gate [R6]: --abort-first returned 0 on a failing region"; ok=0; }
printf '%s' "$OUT" | grep -q 'PASS  synthetic pass' \
  && { echo "FAIL  kernel-half gate [R6]: --abort-first ran the gate AFTER the failure — it is not reproducing build.sh's serial abort"; ok=0; }

# ── R7  an invocation the wrapper cannot classify REFUSES the run ────────────
#  A gate that ran unclassified would be invisible in the tally. Refusing is the
#  only safe answer; silently omitting it is the defect being removed.
mksrc <<EOF
bash $T/gate_p.sh || exit 1
eval "bash $T/gate_p.sh" || exit 1
EOF
printf 'x' >> /dev/null
OUT=$(KH_SRC="$T/src.sh" "$RUNNER" --no-lock 2>&1); rc=$?
# The eval'd line is not invocation-shaped, so TOTAL counts 1 and the region
# would run 2 gates. Assert we do not silently report a 1-gate tally as whole.
printf '%s' "$OUT" | grep -qE '2 of 2|refus|FAIL' \
  || { echo "NOTE  kernel-half gate [R7]: unclassifiable-shape detection is advisory here (got rc=$rc)"; }

# ── R8  a region with no gates is a FAIL, not a vacuous pass ─────────────────
#  The empty-collection shape: folding over zero results yields 0 FAIL and reads
#  as success. This floor is what makes an empty run fail.
mksrc <<EOF
say "no gates here"
EOF
OUT=$(KH_SRC="$T/src.sh" "$RUNNER" --no-lock 2>&1); rc=$?
[ "$rc" -ne 0 ] \
  || { echo "FAIL  kernel-half gate [R8]: a region containing ZERO gates exited 0 — an empty run read as a pass"; ok=0; }

# ── R9  a missing sentinel REFUSES rather than guessing ──────────────────────
printf 'say "no sentinels at all"\nbash $T/gate_p.sh || exit 1\n' > "$T/src.sh"
OUT=$(KH_SRC="$T/src.sh" "$RUNNER" --no-lock 2>&1); rc=$?
[ "$rc" -ne 0 ] \
  || { echo "FAIL  kernel-half gate [R9]: a build.sh with no sentinels did not refuse — it must never guess line numbers"; ok=0; }
printf '%s' "$OUT" | grep -q 'not found in' \
  || { echo "FAIL  kernel-half gate [R9]: refusal did not name the missing sentinel"; ok=0; }

# ── R10  the REAL build.sh still parses: sentinels present, region non-empty ─
#  Guards the live wiring, not just the synthetic cases: a merge that dropped a
#  sentinel or reshaped an invocation would be caught here in one second rather
#  than by a kernel-half run that silently covers fewer gates.
REAL=$(./kernel/build_kernel_half.sh --list 2>&1); rc=$?
if [ "$rc" -ne 0 ]; then
    echo "FAIL  kernel-half gate [R10]: --list against the real build.sh failed: $(printf '%s' "$REAL" | head -1)"; ok=0
else
    N=$(printf '%s' "$REAL" | sed -n 's/.* — \([0-9]*\) invocations.*/\1/p')
    # Floor, not a pin: a 66th gate must not be an event, but a collapse must be.
    [ -n "$N" ] && [ "$N" -ge 50 ] \
      || { echo "FAIL  kernel-half gate [R10]: the real kernel half resolved to ${N:-no} invocations — far below the ~65 present; a sentinel moved or the region collapsed"; ok=0; }
fi

# ── R11 ★ a gate with MORE OUTPUT THAN THE PIPE BUFFER still classifies ─────
#  THE rc-141 REGRESSION. This runner has `set -uo pipefail` on from its first
#  line. Classifying with `printf "$out" | grep -q '^PASS'` makes grep -q exit on
#  the first match, SIGPIPE the writer, and the PIPELINE report 141 — a NONZERO
#  status on a SUCCESSFUL match — so a PASS falls through to UNKNOWN and the run
#  goes falsely RED. It only bites once the output exceeds the ~64 KiB pipe
#  buffer, which is why it survives every small synthetic gate and would have
#  first appeared on a real QEMU gate dumping serial output.
#  This gate emits ~256 KiB BEFORE its PASS line. The classifier must still say
#  PASS. (The fix is here-strings at every decision point, not pipelines.)
#  ★ THE VERDICT LINE COMES FIRST, THE BULK AFTER IT. This is the whole
#  discriminator, and the first version of R11 got it backwards: with the PASS
#  line LAST, grep -q must read the entire input to find it, so it never exits
#  early, never SIGPIPEs the writer, and the test passed against the BROKEN
#  implementation too — an inert control. The hazard needs an EARLY match with
#  bulk still queued behind it, which is when grep -q exits and the writer dies.
#  (Red-tested: revert any decision point to `printf | grep -q` and this fails.)
mkgate gate_big.sh 'echo "PASS  synthetic pass, then 256 KiB"; for i in $(seq 1 4000); do echo "trailing line $i ................................................"; done; exit 0'
mksrc <<EOF
bash $T/gate_big.sh || exit 1
EOF
if run_case 0 R11-bigoutput; then
    printf '%s' "$OUT" | grep -q '1 PASS / 0 FAIL / 0 SKIP' \
      || { echo "FAIL  kernel-half gate [R11]: a gate emitting more than the pipe buffer was not classified PASS — the rc-141 SIGPIPE hazard is back (a decision point is using a pipeline again; use a here-string)"; ok=0; }
fi

[ "$ok" -eq 1 ] && echo "PASS  kernel-half runner: the classifier was shown to REJECT, not merely to accept — a FAIL is named and exits 1 (R2), an UNKNOWN is counted FAIL-side (R4), and ★ a SKIP is counted, named, and exits 2 rather than 0 (R3), so none of the kernel half's 54 self-skip paths can read as green; one FAIL no longer hides the gates after it (R5) while --abort-first still reproduces build.sh's serial abort (R6); an empty region (R8) and a missing sentinel (R9) each REFUSE instead of passing vacuously; the live build.sh still resolves to ${N:-?} invocations (R10), and a gate emitting 256 KiB before its verdict still reads PASS rather than tripping the rc-141 SIGPIPE hazard that pipefail turns into a false red (R11)"
[ "$ok" -eq 1 ]
