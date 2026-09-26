# -*- coding: utf-8 -*-
"""§39 autocompress derivation (2026-09-26, F20). Recomputes the captured node-cost witness WITHOUT the LA code:
  the run    the five genesis operators, forms as documented at their sources: Δ_E = ▷(RECOGNITION,⊂(BECOMING,DEPTH))
             (lineage.la G_ETYM) · ν* = ⊗(▷(LOVE,RELATION),↻(SELF)) (CLAUDE.md metaglyph: ⊗ and ↻'s decompositions) ·
             Δ_R = ▷(RECOGNITION,↻(VOID)) · Δ_B = ▷(RECOGNITION,↻(RELATION)) · ρ(L_t) = ▷(DEPTH,↻(RECOGNITION))
  Δ_ν        the run folded LEFT by ⊗ into one form (autocompress.la header: "folds the run into ONE form by the tensor
             mode"), ((((a⊗b)⊗c)⊗d)⊗e)
  DAG size   distinct NORMK strings over every subterm, leaves included, pooled across the forms (the hash-consed node set)
  the law    delta = |run| - 1: one NEW join node per collapse (unified.la's "+1 DAG node per collapse")
The derivation checks the law rather than printing it: "one join per collapse:T" only if delta == len(run)-1."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lacore import P, SYN, DIR, CONT, MC, normk

def nodes(t, acc):
    acc.add(normk(t))
    for c in t[1:]:
        if isinstance(c, tuple): nodes(c, acc)
    return acc
RUN = [DIR(P("RECOGNITION"), CONT(P("BECOMING"), P("DEPTH"))),
       SYN(DIR(P("LOVE"), P("RELATION")), MC(P("SELF"))),
       DIR(P("RECOGNITION"), MC(P("VOID"))),
       DIR(P("RECOGNITION"), MC(P("RELATION"))),
       DIR(P("DEPTH"), MC(P("RECOGNITION")))]
one = RUN[0]
for f in RUN[1:]: one = SYN(one, f)
before = set()
for f in RUN: nodes(f, before)
after = nodes(one, set())
d = len(after) - len(before)
print("WANT dn node cost: run DAG=%d → compressed DAG=%d delta=%d = one join per collapse:%s" % (
    len(before), len(after), d, "T" if d == len(RUN) - 1 else "F"))
