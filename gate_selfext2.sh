#!/bin/sh
# ── STAGE 2: THE ADOPTED ARTIFACT BECOMES EXECUTABLE ────────────────────────
#  Stage 0 measured that adopted artifacts were only ever READ. Stage 1 built
#  the criterion separating a revision from a copy and from a corruption.
#  Neither made the changed thing RUN. This does.
#
#  ★ THE DISCRIMINATING PAIR. One MAIN, two organs:
#      sx2_child.la  = grown organ + MAIN using TRIPLEDEC  -> prints 12, exit 0
#      sx2_parent.la = base  organ + IDENTICAL MAIN        -> FAILS
#  A child printing 12 proves only that something printed 12. The parent
#  failing on the SAME MAIN is what isolates the capability as the thing that
#  changed -- without it, a MAIN that hardcoded the answer would pass.
#
#  ★★ AND THE PARENT MUST FAIL OF THE INTENDED CAUSE. A parent that died of a
#  missing file, a syntax error or a timeout would satisfy "the parent fails"
#  while proving nothing about the capability. So its diagnostic must NAME the
#  absent glyph. This is the same discipline mutate.py applies to mutants: a
#  red for the wrong reason is not evidence.
#
#  ★★★ AND THE RED PATH OF THE STAGE: an UNVERIFIED extension must not reach
#  execution at all. In "bad" mode the extension carries a test it fails and
#  the organ must write NO child program -- nothing to run is the only refusal
#  that cannot be mistaken for a run that went badly.
set -u
ok=1
cd "$(dirname "$0")" || exit 1

rm -f sx2_child.la sx2_parent.la .sx2mode

# ── ACCEPT ARM ─────────────────────────────────────────────────────────────
printf 'ok' > .sx2mode
SX="$(timeout 900 ./tiny_host selfext2.la 2>&1 || true)"
case "$SX" in
  *"verified=T"*"emitted"*) : ;;
  *) echo "FAIL  selfext2: the honest extension did not verify/emit — got: $SX"; ok=0 ;;
esac
[ -f sx2_child.la ]  || { echo "FAIL  selfext2: no child program was emitted"; ok=0; }
[ -f sx2_parent.la ] || { echo "FAIL  selfext2: the parent CONTROL was not emitted — a control written only when convenient is not a control"; ok=0; }

# the child: a SEPARATE PROCESS demonstrates the capability
CH_OUT="$(timeout 300 ./tiny_host sx2_child.la 2>&1)"; CH_RC=$?
[ "$CH_RC" -eq 0 ] || { echo "FAIL  selfext2: the child process did not exit 0 (rc=$CH_RC) — got: $CH_OUT"; ok=0; }
case "$CH_OUT" in
  *12*) : ;;
  *) echo "FAIL  selfext2: the child did not demonstrate TRIPLEDEC(5)=12 — got: $CH_OUT"; ok=0 ;;
esac

# the parent: the SAME MAIN must fail, AND for the right reason
PA_OUT="$(timeout 300 ./tiny_host sx2_parent.la 2>&1)"; PA_RC=$?
[ "$PA_RC" -ne 0 ] || { echo "FAIL  selfext2: the parent SUCCEEDED on the same MAIN — the capability is not new, so nothing was gained"; ok=0; }
case "$PA_OUT" in
  *TRIPLEDEC*) : ;;
  *) echo "FAIL  selfext2: the parent failed but NOT of the intended cause (its diagnostic does not name the absent glyph) — a red for the wrong reason is not evidence — got: $PA_OUT"; ok=0 ;;
esac
case "$PA_OUT" in
  *12*) echo "FAIL  selfext2: the parent printed 12 — the MAIN is not exercising the extension"; ok=0 ;;
  *) : ;;
esac

# ── REFUSE ARM: an unverified extension must not reach execution ───────────
rm -f sx2_child.la
printf 'bad' > .sx2mode
SXB="$(timeout 900 ./tiny_host selfext2.la 2>&1 || true)"
case "$SXB" in
  *"verified=F"*REFUSED*) : ;;
  *) echo "FAIL  selfext2: the failing extension was not refused — got: $SXB"; ok=0 ;;
esac
[ -f sx2_child.la ] && { echo "FAIL  selfext2: a child program was written for an UNVERIFIED extension — verification does not gate execution"; ok=0; }

rm -f sx2_child.la sx2_parent.la .sx2mode

if [ "$ok" -eq 1 ]; then
    echo "PASS  selfext2: the adopted artifact is EXECUTABLE — a separate process runs the grown organ and demonstrates TRIPLEDEC(5)=12 (exit 0), while the parent organ under the IDENTICAL MAIN fails AND fails by naming the absent glyph, so the capability is isolated as the thing that changed rather than merely present; an UNVERIFIED extension causes NO child program to be written at all. SCOPE: this witnesses that a separate process runs the extension, NOT yet that the organ itself begets and execve's that process (the bundled VM-side form, stage 2b)"
    exit 0
fi
exit 1
