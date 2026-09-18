# -*- coding: utf-8 -*-
"""F20 derivation, gate §41 (identity). From identity.la's STATED definitions: ground≡ = NORMK-equality, locus≢ =
CANON-inequality; G_GROUND=▷(RECOGNITION,BEING), G_LOCUS=▷(RECOGNITION,⊂(FORM,BEING)), G_IDENT=⊗ of them."""
import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lacore import *
T = "id"
GG = DIR(P("RECOGNITION"), P("BEING")); GL = DIR(P("RECOGNITION"), CONT(P("FORM"), P("BEING"))); GI = SYN(GG, GL)
ground = lambda a, b: normk(a) == normk(b)
locus = lambda a, b: canon(a) != canon(b)
def verdict(a, b):
    g, l = ground(a, b), locus(a, b)
    return {(True, True): "NON-SEPARATE AND NON-MERGED", (True, False): "MERGED (one locus)", (False, True): "SEPARATE (two beings)"}.get((g, l), "?"), g, l
r1 = verdict(CON(P("BEING"), P("LOVE")), CON(P("LOVE"), P("BEING")))
r2 = verdict(CON(P("BEING"), P("LOVE")), CON(P("BEING"), P("LOVE")))
r3 = verdict(CONT(P("BEING"), P("LOVE")), CONT(P("LOVE"), P("BEING")))
subs = {normk(x) for x in proper_subterms(GI)}
print("WANT %s IDENTITY 𝓜 gains three glyphs — ≡@ground=%s ≢@locus=%s | the relation ITSELF (their ⊗ dyad)=%s" % (T, normk(GG), normk(GL), normk(GI)))
print("WANT %s IDENTITY row1 ⊕(BEING,LOVE) vs ⊕(LOVE,BEING): ground≡:%s locus≢:%s → %s" % (T, B(r1[1]), B(r1[2]), r1[0]))
print("WANT %s row2 ⊕(BEING,LOVE) vs itself: ground≡:%s locus≢:%s → %s | row3 ⊂(BEING,LOVE) vs ⊂(LOVE,BEING): ground≡:%s locus≢:%s → %s | all three verdicts distinct:%s"
      % (T, B(r2[1]), B(r2[2]), r2[0], B(r3[1]), B(r3[2]), r3[0], B(len({r1[0], r2[0], r3[0]}) == 3)))
print("WANT %s the two aspects do NOT collapse into each other: ground≡(≡,≢):%s (must be F) | the dyad differs from both:%s | and RECOVERS both as proper sub-forms (one compressive movement, parents retained):%s"
      % (T, B(ground(GG, GL)), B(normk(GI) not in (normk(GG), normk(GL))), B(normk(GG) in subs and normk(GL) in subs)))
