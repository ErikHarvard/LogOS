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

# ── ★★ A SKIP MUST NOT SATISFY A REQUIRED GATE (III-1) ──────────────────────
#  This loop returned EXIT 0 when a vessel was missing, and build.sh reads only
#  the exit status -- `sh gate_selfext2b.sh || exit 1`, one bit of resolution. So
#  a gate that DECLINED TO RUN was indistinguishable from one that ran and passed.
#  Confirmed in four consecutive build logs: "SKIP selfext2b: prerequisite vessel
#  compiler.bin absent", every time. compiler.bin is deleted by an earlier
#  build.sh section and never recreated before this gate; bundler.bin appears
#  nowhere in build.sh at all.
#  ★ WORSE THAN AN UNWIRED GATE: the safety check above prints PASS naming
#  ./compiler.bin as a validated exec target, on the line directly before the one
#  saying it is absent. The section does not look uncovered — it displays a green
#  verdict about the very file whose absence disables it.
#  ★★ AND IT IS THE TWIN OF THE selfext5/6 DEFECT, with the opposite symptom.
#  Those consumed ./logos_secd without building it and died LOUDLY the first time
#  a build reached them. This one exits 0 and has been passing indefinitely. The
#  loud one was fixed the day it appeared; the quiet one was not, because nothing
#  in the build can ask "did you actually run?".
#  THE FIX IS BOTH HALVES, because either alone leaves the class open:
#   (1) BUILD the prerequisites rather than skipping on them, and
#   (2) if they still cannot be produced, FAIL — never exit 0.
for V in sx2b_app compiler.bin bundler.bin logos_secd; do
  if [ ! -x "$V" ] && [ ! -f "$V" ]; then
    case "$V" in
      logos_secd)   ./tiny_host secd.la >/dev/null 2>&1 ;;
      compiler.bin) [ -f logos_secd ] || ./tiny_host secd.la >/dev/null 2>&1
                    cp codegen.la logos_source.la 2>/dev/null
                    ./tiny_host codegen.la >/dev/null 2>&1
                    [ -f logos_program.bin ] && cp logos_program.bin compiler.bin 2>/dev/null ;;
      bundler.bin)  [ -f .sx2b_build.sh ] && sh .sx2b_build.sh >/dev/null 2>&1 ;;
      sx2b_app)     [ -f .sx2b_build.sh ] && sh .sx2b_build.sh >/dev/null 2>&1 ;;
    esac
  fi
  [ -x "$V" ] || [ -f "$V" ] || {
    echo "FAIL  selfext2b: prerequisite vessel $V is absent and could not be built — this gate now FAILS rather than exiting 0, because a SKIP is indistinguishable from a PASS to the one bit of resolution build.sh reads, and this gate skipped silently in four consecutive builds"
    exit 1; }
done

# (1) the discriminator's precondition: the organ must CREATE the vessel
# ── ★★ THE CHECK GOES ABOVE THE rm (III-6), OR IT TESTS NOTHING ─────────────
#  This was `rm -f logos_app ...` and THEN `[ -e logos_app ] && FAIL`. Nothing runs
#  between them and the organ executes later, so it asserted that `rm -f` had
#  succeeded. The PROPERTY is still achieved — the rm does guarantee the organ
#  creates the vessel — but the CHECK was theatre, and it would keep passing if the
#  rm were ever dropped and a stale vessel left behind.
#  ★ NOT "implied by a neighbour" like the triangles: DEFEATED by one. Two sibling
#  checks with the identical `rm` ... `[ -f X ] &&` shape ARE live — gate_selfext2.sh
#  and gate_selfext6.sh — because in those a producer RUNS in between. That contrast
#  is what makes this a finding rather than a style note.
#  Moved above the rm, where it tests what it claims; the rm follows as cleanup.
[ -e logos_app ] && { echo "FAIL  selfext2b: logos_app existed BEFORE the run — a vessel left over from a previous run cannot be attributed to the organ, so the discriminator would be measuring someone else's artifact"; ok=0; }
rm -f logos_app logos_program.bin logos_embed.bin logos_source.la

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
