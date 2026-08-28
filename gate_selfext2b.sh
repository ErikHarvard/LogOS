#!/bin/sh
# ── STAGE 2b: THE ORGAN BEGETS ITS OWN SUCCESSOR ───────────────────────────
#  Stage 2 made the adopted artifact executable -- but the GATE compiled it and
#  the GATE ran it. A child that runs because a shell script compiled it is not
#  the organ begetting anything.
#
#  ★ SO THIS GATE COMPILES NOTHING AND RUNS NOTHING BUT THE ORGAN. It invokes
#  ./sx2b_app once. Everything after that -- writing the grown source, invoking
#  the compiler, fusing the vessel, exec'ing it -- happens inside the organ.
#  The discriminator is mechanical, not rhetorical:
#     BEFORE the run, ./logos_app must NOT exist.
#     AFTER  the run, ./logos_app must exist, and the organ's own output stream
#            must carry the child's "12" (the child inherits stdout).
#  If logos_app existed beforehand, the vessel could have been anyone's; if the
#  gate had compiled it, the origin claim would be false.
#
#  ★★ SAFETY IS A PRECONDITION, NOT A HOPE. The organ runs on the VM, so the
#  organ IS what logos_program.bin holds, and an organ that execve'd
#  ./logos_secd would re-enter itself -- CLAUDE.md rule 2, 148,121 processes.
#  gate_selfext2b_safety.py enforces statically that every exec target is a
#  literal self-contained bundle, and refuses a variable target it cannot read.
#  That gate runs FIRST here, and a red there aborts before anything forks.
#  A generation cap in .sx2b_gen terminates the chain even if that is wrong.
set -u
cd "$(dirname "$0")" || exit 1
ok=1

# (0) the bomb guard, before anything forks
python3 gate_selfext2b_safety.py >/dev/null 2>&1 \
  || { echo "FAIL  selfext2b: the exec-surface safety gate is RED — refusing to fork"; exit 1; }

for V in sx2b_app compiler.bin bundler.bin logos_secd; do
  [ -x "$V" ] || [ -f "$V" ] || { echo "SKIP  selfext2b: prerequisite vessel $V absent"; exit 0; }
done

# (1) the discriminator's precondition: the organ must CREATE the vessel
rm -f logos_app logos_program.bin logos_embed.bin logos_source.la
[ -e logos_app ] && { echo "FAIL  selfext2b: logos_app exists before the run — its origin cannot be attributed to the organ"; ok=0; }

printf '0' > .sx2b_gen
OUT="$(timeout 600 ./sx2b_app 2>&1)"; RC=$?
printf '%s\n' "$OUT" | sed 's/^/    /'

[ "$RC" -eq 0 ] || { echo "FAIL  selfext2b: the organ exited $RC"; ok=0; }
case "$OUT" in
  *"[organ] wrote grown source"*) : ;;
  *) echo "FAIL  selfext2b: the organ did not write the grown source"; ok=0 ;;
esac
# ★ the vessel must now exist, and the organ must be the only thing that made it
[ -f logos_app ] || { echo "FAIL  selfext2b: no vessel was begotten — the organ did not produce logos_app"; ok=0; }
# ★ the begotten child's output must appear in the organ's own stream
case "$OUT" in
  *"BEGOTTEN child exit"*) : ;;
  *) echo "FAIL  selfext2b: the organ never reported exec'ing its child"; ok=0 ;;
esac
case "$OUT" in
  *12*) : ;;
  *) echo "FAIL  selfext2b: the begotten child did not demonstrate TRIPLEDEC(5)=12 — the capability was not exercised by a process the organ started"; ok=0 ;;
esac

# (2) the cap arm: a second run must beget nothing
OUT2="$(timeout 600 ./sx2b_app 2>&1)"
case "$OUT2" in
  *"at cap"*) : ;;
  *) echo "FAIL  selfext2b: the generation cap did not hold on a second run — the chain does not terminate"; ok=0 ;;
esac

# (3) process hygiene: nothing may be left running
LEFT="$(pgrep -x logos_app 2>/dev/null | wc -l)"
[ "$LEFT" -eq 0 ] || { echo "FAIL  selfext2b: $LEFT logos_app process(es) still running after the run"; ok=0; }

rm -f logos_app logos_program.bin logos_embed.bin logos_source.la .sx2b_gen

if [ "$ok" -eq 1 ]; then
  echo "PASS  selfext2b: the organ BEGETS its own successor — this gate compiled nothing and ran nothing but ./sx2b_app; the organ wrote the grown source, invoked the compiler, fused a self-contained vessel that did NOT exist before the run, execve'd it, and the child demonstrated TRIPLEDEC(5)=12 in the organ's own output stream. Every exec target is a literal bundle (never the VM loader, which would re-enter the organ per CLAUDE.md rule 2) and the generation cap terminates the chain on a second run"
  exit 0
fi
exit 1
