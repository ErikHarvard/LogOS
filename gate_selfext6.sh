#!/bin/sh
# ── STAGE 6: THE UNATTENDED RUN ────────────────────────────────────────────
#  The organ is told a NAME, a TYPE and ONE acceptance test. No source, no
#  implementation, no decomposition -- because the scope's failure mode 7 is
#  "the seed is the answer", which autoloop.la says about itself: its GOAL
#  hands each step the implementation, so it ASSEMBLES rather than extends.
#
#  SIX ARMS, and the last three are what keep this from being a demo:
#    A  budget 4  -> the want is met and a module is emitted
#    B  budget 1  -> BUDGET EXHAUSTED, no module, clean exit -- never a silent
#                    partial success
#    C  the found extension answers stage 4's HELD-OUT probes, so what the
#       search produced is a capability rather than a memorised answer
#    D  a SECOND ENGINE (the native SECD VM, which did not synthesise it)
#       independently agrees -- stage 5's discipline applied to an artifact
#       nobody chose by hand
#    E  the composition SOURCE must not appear literally in the synthesiser:
#       if it did, the want would contain its own answer
#    F  the emitted extension must clear the RATCHET -- a search that returned
#       something the organ already had is not extension
set -u
cd "$(dirname "$0")" || exit 1
ok=1
HELD_OUT="27 297 99"

run6() { printf '%s' "$1" > .sx6budget; rm -f sx6_organ.la
         timeout 900 ./tiny_host selfext6.la 2>&1; }

# ── ARM A ────────────────────────────────────────────────────────────────
A="$(run6 4)"
case "$A" in
  *"tried=2 found=2"*"verified=T"*) : ;;
  *) echo "FAIL  selfext6(A): the unattended search did not find the want as expected — got: $A"; ok=0 ;;
esac
[ -f sx6_organ.la ] || { echo "FAIL  selfext6(A): no module emitted on success"; ok=0; }
grep -q 'glyph TRIPLEDEC = la x. TRIPLEN(DEC(x))' sx6_organ.la \
  || { echo "FAIL  selfext6(A): the emitted glyph is not the composition the search reported"; ok=0; }

# ── ARM C: the held-out probes, on what the SEARCH produced ─────────────
cat > sx6_audit.la <<'AUD'
import("sx6_organ.la")
glyph SP = la a. la b. concat(a)(concat(" ")(b))
glyph MAIN = print(SP(int_to_str(TRIPLEDEC(10)))(SP(int_to_str(TRIPLEDEC(100)))(int_to_str(TRIPLEDEC(34)))))
AUD
CH="$(timeout 300 ./tiny_host sx6_audit.la 2>&1)"
[ "$CH" = "$HELD_OUT" ] || { echo "FAIL  selfext6(C): the unattended result failed the HELD-OUT probes — expected '$HELD_OUT', got '$CH'. The search satisfied its own probe and nothing more"; ok=0; }

# ── ARM D: a second engine agrees ───────────────────────────────────────
# ★ BUILD THE VM RATHER THAN INHERIT ONE. This arm runs ./logos_secd but nothing
#   here built it: it relied on an earlier build.sh section leaving one behind,
#   and the section that last touches it DELETES it. gate_selfext5.sh had the
#   identical defect and went red the first time a build ever reached that far —
#   "No such file or directory" standing in for a verdict. Found here BEFORE it
#   could fail, by scanning every gate for a use of an artifact it does not
#   create. A gate may not depend on who ran before it.
[ -x ./logos_secd ] || ./tiny_host secd.la >/dev/null 2>&1
[ -x ./logos_secd ] || { echo "FAIL  selfext6: the native VM could not be built from secd.la — arm D has no second engine, so it would compare the host with itself"; ok=0; }
rm -f logos_program.bin logos_source.la
cp sx6_audit.la logos_source.la
timeout 900 ./tiny_host codegen.la >/dev/null 2>&1
CV="$(timeout 300 ./logos_secd 2>&1)"
# ★ RE-POINTED (III-5): CH=E and CV=E and CV=CH is a triangle whose third line is
#   implied. Compare the VM TO THE HOST — same strength, both lines live.
[ "$CV" = "$CH" ] || { echo "FAIL  selfext6(D): host and VM DISAGREE on the unattended result — host '$CH' vs VM '$CV'"; ok=0; }

# ── ARM F: it must clear the ratchet ────────────────────────────────────
grep -v '^glyph TRIPLEDEC' sx6_organ.la > .sx6_parent.la
python3 ratchet.py .sx6_parent.la sx6_organ.la >/dev/null 2>&1 \
  || { echo "FAIL  selfext6(F): the unattended result does not STRICTLY ADD a κ-class — the search returned something the organ already had"; ok=0; }

# ── ARM B: BUDGET EXHAUSTION IS A CLEAN, REPORTED STOP ──────────────────
B="$(run6 1)"; BRC=$?
case "$B" in
  *"BUDGET EXHAUSTED"*"NO module emitted"*) : ;;
  *) echo "FAIL  selfext6(B): exhaustion was not reported as such — got: $B"; ok=0 ;;
esac
[ "$BRC" -eq 0 ] || { echo "FAIL  selfext6(B): exhaustion exited $BRC — a bounded search running out is a CLEAN stop, not a crash"; ok=0; }
[ -f sx6_organ.la ] && { echo "FAIL  selfext6(B): a module was emitted on an EXHAUSTED search — a best-effort artifact is a silent partial success, and a reader seeing an artifact assumes the want was met"; ok=0; }
case "$B" in
  *"tried=1"*) : ;;
  *) echo "FAIL  selfext6(B): the budget did not bound the search — got: $B"; ok=0 ;;
esac

# ── ARM E: the want must not contain its own answer ─────────────────────
if grep -v '^#' selfext6.la | grep -q 'TRIPLEN(DEC('; then
  echo "FAIL  selfext6(E): the composition source appears LITERALLY in the synthesiser — the want contains its own answer, so the search assembles rather than extends"
  ok=0
fi

rm -f sx6_audit.la sx6_organ.la .sx6_parent.la .sx6budget logos_program.bin logos_source.la

if [ "$ok" -eq 1 ]; then
  echo "PASS  selfext6: UNATTENDED — told only a name, a type and one probe (f(5)=12), with no source and no implementation, the organ searched its own capability space and CONSTRUCTED 'la x. TRIPLEN(DEC(x))' from its component names. BUDGET 4, SPACE 4 (every ordered composition of its two glyphs), TRIED 2. The result answers held-out probes it never saw (10/100/34 -> 27/297/99), a second engine that did not synthesise it agrees, and it strictly adds a κ-class. On BUDGET 1 the search stops CLEANLY at tried=1 with NO module emitted. SCOPE: this closes the item for ONE extension, under a stated budget, over a stated space of four — 'the system extends itself' does not follow from it"
  exit 0
fi
exit 1
