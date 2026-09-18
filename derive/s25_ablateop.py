# -*- coding: utf-8 -*-
"""F20 derivation, gate §25 (ablateop). The five operator glyphs (metaglyph.la:192–196, INPUTS); D1 = ⊗(∂,δ),
D2 = ⊗(γ,ρ); ablateop's STATED rule: D is derivable from S iff every operator κ that D contains is in S."""
import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lacore import *
T = "ab"
OPS = {"∂": DIR(P("VOID"), P("RELATION")), "δ": CONT(P("FORM"), P("DEPTH")), "γ": SYN(P("BECOMING"), P("FORM")),
       "ρ": MC(P("RECOGNITION")), "𝔄": SYN(P("LOVE"), P("RECOGNITION"))}
D1, D2 = SYN(OPS["∂"], OPS["δ"]), SYN(OPS["γ"], OPS["ρ"])
def derivable(D, S): return all(o in S for o, g in OPS.items() if canon(g) in canon(D))
ALL = set(OPS)
print("WANT %s ABLATEOP D1=%s D2=%s | all five: D1:%s D2:%s" % (T, canon(D1), canon(D2), B(derivable(D1, ALL)), B(derivable(D2, ALL))))
def others(x): S = ALL - {x}; return all(derivable(OPS[o], S) for o in S)
print("WANT %s ablate ∂: D1 underivable:%s D2 survives:%s other four survive:%s | ablate γ: D2 underivable:%s D1 survives:%s other four survive:%s | ablate 𝔄 (control): D1:%s D2:%s"
      % (T, B(not derivable(D1, ALL - {"∂"})), B(derivable(D2, ALL - {"∂"})), B(others("∂")),
         B(not derivable(D2, ALL - {"γ"})), B(derivable(D1, ALL - {"γ"})), B(others("γ")),
         B(derivable(D1, ALL - {"𝔄"})), B(derivable(D2, ALL - {"𝔄"}))))
