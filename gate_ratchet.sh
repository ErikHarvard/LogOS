#!/bin/sh
# ── STAGE 3: THE RATCHET GATE ──────────────────────────────────────────────
#  The ledger's condition on any coinage: it may never COLLAPSE two previously
#  κ-distinct forms, and must STRICTLY ADD a new κ-class.
#
#  ★ WHAT THIS CATCHES THAT NOTHING ELSE DOES. SYNTH composes glyphs the organ
#  already has, so an extension can be α-equivalent to one already present --
#  and every other gate in the chain passes it. It verifies (it works). It is
#  its own derivation. The parent capabilities survive. Stage 2b's begotten
#  child prints 12 for it quite happily. A renamed copy satisfies stages 1, 2
#  and 2b completely. Only a κ-class count sees that nothing was gained.
#
#  Five arms, because one PASS proves only that the instrument can say yes:
#     A  genuine extension   -> PASS   (κ-classes strictly increase)
#     B  rename-only         -> FAIL   (α-equivalent copy: no new class)
#     C  collapse            -> FAIL   (a parent κ-class lost)
#     D  malformed glyph     -> FAIL   (the well-formedness check, and nothing else)
#     E  paren in a string   -> PASS   (the control: D counts tokens, not characters)
#  B is the failure mode the stage exists for. C is the ratchet's other pawl.
#  D is input ratchet.py must refuse before it counts anything; E keeps D from
#  being a character count that would refuse legitimate text.
set -u
cd "$(dirname "$0")" || exit 1
ok=1

# the α-normaliser is an instrument; a broken one makes every verdict below
# meaningless, so it proves itself before anything is judged
python3 ratchet.py --selftest || { echo "FAIL  ratchet: the α-normaliser failed its own self-test"; exit 1; }

rm -f sx2_parent.la sx2_child.la .rat_rename.la .rat_collapse.la .rat_malformed.la .rat_strparen.la
printf 'ok' > .sx2mode
timeout 900 ./tiny_host selfext2.la >/dev/null 2>&1
[ -f sx2_parent.la ] && [ -f sx2_child.la ] \
  || { echo "FAIL  ratchet: the organ did not emit the parent/child pair to judge"; exit 1; }

# ── ARM A: the genuine extension ──────────────────────────────────────────
python3 ratchet.py sx2_parent.la sx2_child.la || { echo "FAIL  ratchet(A): a genuine extension was rejected"; ok=0; }

# ── ARM B: RENAME-ONLY. A copy of TRIPLEN under a new name and a new bound
#    variable. Everything about it is legal; it simply adds no κ-class.
cp sx2_parent.la .rat_rename.la
echo 'glyph TRIPLEN2 = la y. mul(y)(3)' >> .rat_rename.la
if python3 ratchet.py sx2_parent.la .rat_rename.la >/dev/null 2>&1; then
    echo "FAIL  ratchet(B): a RENAME-ONLY extension was ACCEPTED — an α-equivalent copy of a capability the organ already had counts as growth, so the ratchet is not ratcheting"
    ok=0
fi

# ── ARM C: COLLAPSE, AND IT MUST ISOLATE THE COLLAPSE CONDITION.
#    ★ The first version of this arm rewrote DEC to duplicate TRIPLEN and
#    stopped there. That collapses a class AND drops the count, so the
#    STRICT-INCREASE check caught it and the collapse check was never
#    exercised -- mutation testing removed the collapse check entirely and
#    this arm stayed green. Two conditions that always fail together are one
#    condition wearing two names, which is the discipline stage 1 applies to
#    its four conjuncts and this arm had quietly skipped.
#    So the fixture now collapses a class AND adds a fresh one, leaving the
#    count STRICTLY HIGHER than the parent's. The strict-increase check is
#    satisfied; only the collapse check can refuse it.
sed 's/^glyph DEC = la x. sub(x)(1)$/glyph DEC = la x. mul(x)(3)/' sx2_child.la > .rat_collapse.la
echo 'glyph FRESH = la q. add(q)(7)' >> .rat_collapse.la
if python3 ratchet.py sx2_parent.la .rat_collapse.la >/dev/null 2>&1; then
    echo "FAIL  ratchet(C): a COLLAPSE was ACCEPTED — two previously κ-distinct forms became one and the gate did not notice"
    ok=0
fi

# ── ARM D: MALFORMED. The parent plus ONE glyph whose parens do not balance,
#    and nothing else. It adds one κ-class and loses none, so it satisfies BOTH
#    conditions above: only the well-formedness check can refuse it, which is
#    the isolation arm C's comment demands. And the refusal must be THAT check's:
#    a refusal for any other reason is a red for the wrong reason
#    (verdict-without-reason, named 2026-09-11), so the arm asserts the line.
cp sx2_parent.la .rat_malformed.la
echo 'glyph BROKEN = la y. mul(y)(3' >> .rat_malformed.la
if D_OUT="$(python3 ratchet.py sx2_parent.la .rat_malformed.la 2>&1)"; then
    echo "FAIL  ratchet(D): a MALFORMED extension was ACCEPTED — a glyph with an unclosed ( was counted as a new κ-class"
    ok=0
else
    case "$D_OUT" in
        *'glyph BROKEN is MALFORMED (1 unclosed ('*) : ;;
        *) echo "FAIL  ratchet(D): the malformed extension was refused, but not by the well-formedness check — a red for the wrong reason (got: $D_OUT)"; ok=0 ;;
    esac
fi

# ── ARM E: THE CONTROL FOR D. A well-formed glyph whose string literal holds an
#    unbalanced paren. A check counting CHARACTERS would refuse it; one counting
#    TOKENS (a string literal is one token) must accept it, since it adds a class.
cp sx2_parent.la .rat_strparen.la
echo 'glyph PAREN = print("(")' >> .rat_strparen.la
python3 ratchet.py sx2_parent.la .rat_strparen.la >/dev/null 2>&1 || { echo "FAIL  ratchet(E): a well-formed glyph with a paren INSIDE a string literal was refused — the well-formedness check is counting characters, not tokens"; ok=0; }

rm -f .rat_rename.la .rat_collapse.la .rat_malformed.la .rat_strparen.la sx2_parent.la sx2_child.la .sx2mode

if [ "$ok" -eq 1 ]; then
  echo "PASS  ratchet: κ-classes strictly increase on a genuine extension (3 -> 4); a RENAME-ONLY extension (α-equivalent copy under a fresh name and fresh bound variable) is REJECTED, and so is a COLLAPSE that destroys a previously κ-distinct parent form. A MALFORMED extension (a glyph with an unclosed paren, which adds a class and loses none) is refused by the well-formedness check and by nothing else, while a paren inside a string literal is not refused: that check counts tokens, not characters. The α-normaliser self-tests on four pairs first, including same-names/different-binding, because a normaliser that only stripped names would call every rebinding a rename. BOUND: α-equivalence is decidable, behavioural equivalence is not — a non-literal restatement of an existing capability still passes here, and that is stage 4's job"
  exit 0
fi
exit 1
