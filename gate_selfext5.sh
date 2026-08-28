#!/bin/sh
# ── STAGE 5: CROSS-ENGINE AUDIT ────────────────────────────────────────────
#  The scope's failure mode 4: "the audit runs on the engine that built it. A
#  synthesis artefact and its auditor sharing an evaluator share its bugs."
#  Synthesis happens on the C HOST (tiny_host runs selfext4.la), so the audit
#  must run somewhere else. This repo has five engines; the native SECD VM did
#  not perform the synthesis, so it is the independent witness.
#
#  ★ THE POINT IS NOT THAT TWO ENGINES AGREE. It is that DISAGREEMENT IS A
#  FAILURE rather than a note. Arm B proves the comparison can detect
#  disagreement at all, by deliberately giving the two engines DIFFERENT
#  modules and requiring the gate to refuse. Without arm B, "host == VM" is
#  satisfied by a comparison that always says yes.
#
#  ★★ AND ARM C PROVES THE SECOND ENGINE ACTUALLY RAN. A cross-engine gate that
#  silently fell back to the host when the VM was missing would report agreement
#  between an engine and itself -- absence of a witness presented as a witness,
#  which is the failure this project keeps finding. So the VM is removed and the
#  leg is required to FAIL rather than degrade.
set -u
cd "$(dirname "$0")" || exit 1
ok=1

HELD_OUT="27 297 99"

# ── ★★ THE VM MUST EXIST, AND THIS GATE MUST NOT DEPEND ON WHO RAN BEFORE IT ──
#  run_vm executes ./logos_secd, but nothing here ever built it: the gate
#  silently inherited a VM left behind by some earlier build.sh section. The
#  section that last touches it before this one (theourgia text) DELETES it, so
#  the VM leg died with "No such file or directory" -- and ARM C's mv/mv-back
#  quietly did nothing. That went unnoticed because no build had ever reached
#  this far: the runs before it aborted at an earlier gate.
#  ★ A gate whose oracle is a LEFTOVER ARTIFACT is not a gate. It is also exactly
#  the failure arm C exists to catch, arriving through the door arm C does not
#  watch -- C proves the VM leg fails when the VM is REMOVED, and said nothing
#  about the VM never having been BUILT. So build our own, and refuse loudly if
#  we cannot, rather than reporting a missing engine as a wrong answer.
[ -x ./logos_secd ] || ./tiny_host secd.la >/dev/null 2>&1
[ -x ./logos_secd ] || { echo "FAIL  selfext5: the native VM could not be built from secd.la — the cross-engine arms have no second engine, so they would compare the host with itself"; ok=0; }

emit() { printf '%s' "$1" > .sx4mode; rm -f sx4_organ.la
         timeout 900 ./tiny_host selfext4.la >/dev/null 2>&1
         [ -f sx4_organ.la ] || { echo "FAIL  selfext5: organ emitted nothing in mode $1"; ok=0; return 1; }; }

mkaudit() {
  cat > sx5_audit.la <<'AUD'
import("sx4_organ.la")
glyph SP = la a. la b. concat(a)(concat(" ")(b))
glyph MAIN = print(SP(int_to_str(TRIPLEDEC(10)))(SP(int_to_str(TRIPLEDEC(100)))(int_to_str(TRIPLEDEC(34)))))
AUD
}

run_host() { timeout 300 ./tiny_host sx5_audit.la 2>&1; }
run_vm()  {  # compile with codegen, then execute on the native SECD VM
  rm -f logos_program.bin logos_source.la
  cp sx5_audit.la logos_source.la
  timeout 900 ./tiny_host codegen.la >/dev/null 2>&1 || { echo "<CODEGEN-FAILED>"; return 1; }
  [ -s logos_program.bin ] || { echo "<NO-STREAM>"; return 1; }
  timeout 300 ./logos_secd 2>&1
}

# ── ARM A: one artifact, two engines, and they must agree WITH each other
#    and WITH the held-out expectation.
emit honest && {
  mkaudit
  H="$(run_host)"; V="$(run_vm)"
  [ "$H" = "$HELD_OUT" ] || { echo "FAIL  selfext5(A): host leg gave '$H', expected '$HELD_OUT'"; ok=0; }
  [ "$V" = "$HELD_OUT" ] || { echo "FAIL  selfext5(A): VM leg gave '$V', expected '$HELD_OUT'"; ok=0; }
  [ "$H" = "$V" ] || { echo "FAIL  selfext5(A): host and VM DISAGREE — host '$H' vs VM '$V'. This is a failure, not a note"; ok=0; }
  [ -s logos_program.bin ] || { echo "FAIL  selfext5(A): no compiled stream — the VM leg cannot have run"; ok=0; }
}

# ── ARM B: RED PATH. Give the engines DIFFERENT modules and require refusal.
#    Host audits the honest organ; the VM audits the overfit one. If the
#    comparison still reports agreement, it is not comparing.
emit honest && { mkaudit; HB="$(run_host)"; }
emit overfit && { mkaudit; VB="$(run_vm)"; }
if [ "$HB" = "$VB" ]; then
  echo "FAIL  selfext5(B): the host ran the HONEST module and the VM ran the OVERFIT one, and the comparison found them EQUAL ('$HB' vs '$VB') — a cross-engine check that cannot see two different programs is asserting nothing"
  ok=0
fi

# ── ARM C: RED PATH. The second engine must actually run, or fail loudly.
mv logos_secd .logos_secd.hidden
emit honest && { mkaudit; VC="$(run_vm 2>&1)"; }
mv .logos_secd.hidden logos_secd
if [ "$VC" = "$HELD_OUT" ]; then
  echo "FAIL  selfext5(C): the VM leg produced the right answer with the VM REMOVED — it silently fell back to the host, so 'cross-engine' compared an engine with itself"
  ok=0
fi

rm -f sx5_audit.la sx4_organ.la logos_program.bin logos_source.la .sx4mode

if [ "$ok" -eq 1 ]; then
  echo "PASS  selfext5: the extension is witnessed on an engine that did NOT synthesise it — the C host performs the synthesis, the native SECD VM independently answers the held-out probes (10/100/34 -> 27/297/99), and the two agree. Disagreement is a FAILURE, not a note: arm B feeds the two engines different modules and requires refusal, so the comparison is shown to discriminate; arm C removes the VM and requires the leg to fail rather than silently fall back to the host, so agreement is between two engines rather than one engine and itself"
  exit 0
fi
exit 1
