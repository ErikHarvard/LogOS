# -*- coding: utf-8 -*-
"""§38 ontosemiosyntax derivation (2026-09-26, F20). Recomputes the captured self-application witness WITHOUT the LA code,
from the definition the module's header states (ontosemiosyntax.la, "THE THREE ASPECTS"):
  BEING(g) = CANON(ETYM(g))  ·  FORM(g) = REN(g)  ·  MEANING(g) = NORMK(ETYM(g))  ·  OSS(g) ⇔ BEING = FORM ∧ BEING = MEANING
  G_OSS     = ⊗(BEING,⊗(RECOGNITION,FORM)), sealed: REN := CANON(etym) (MONO(CANON(et))(et) — how every seal is made)
★ What this can and cannot see, stated: the Form clause is true BY SEALING (construction); the Meaning clause is the
computed part — CANON = NORMK holds because ⊗ is NOT reordered (lacore.normk: ruling E1, ⊗ non-commutative) and the
form has no ⊕ and no ↻(BEING). A NORMK that sorted ⊗ would still agree HERE ("BEING" < "⊗(…)" bytewise already), so
this pin cannot tell the E1 ruling apart from its reversal; a sealed ⊕(LOVE,BEING) (the module's own non-normal
fixture) is where that shows. The derivation's red path: the seal made with a literal surface (the liar) → OSS F."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lacore import P, SYN, canon, normk

def seal(et): return (canon(et), et)          # MONO(CANON(et))(et)
def oss(g):
    ren, et = g
    return canon(et) == ren and canon(et) == normk(et)
G_OSS = seal(SYN(P("BEING"), SYN(P("RECOGNITION"), P("FORM"))))
print("WANT os self-application: G_OSS=%s OSS(G_OSS):%s" % (canon(G_OSS[1]), "T" if oss(G_OSS) else "F"))
