# -*- coding: utf-8 -*-
"""§34 migrate derivation (2026-09-26, F20). Recomputes migrate.la's captured witness WITHOUT the LA code, from the law
its header states (migrate.la:19-35) and lacore's independent κ/NORMK:
  registry   the four entries BOND=⊕(BEING,LOVE) HOLD=⊂(BEING,LOVE) KAPPA=▷(RECOGNITION,FORM) G_MIG=⊂(BECOMING,↻(RECOGNITION))
             (data: the module's MG_REG table, transcribed)
  cosmetic   the revision BOND → ⊕(LOVE,BEING): "form changed" = the plain κ routes differ (CANON is order-preserving);
             "ONF held" = NORMK of the old form, printed; admitted = the law's (i): NORMK(new) == NORMK(old) (the ratchet (ii)
             is not consulted for a revision — the module's own note)
A mutant law (ONF by plain κ instead of NORMK) makes "admitted" F, and a registry of 3 or 5 mismatches the count."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lacore import P, CON, CONT, DIR, MC, canon, normk

REG = [("BOND", CON(P("BEING"), P("LOVE"))), ("HOLD", CONT(P("BEING"), P("LOVE"))),
       ("KAPPA", DIR(P("RECOGNITION"), P("FORM"))), ("G_MIG", CONT(P("BECOMING"), MC(P("RECOGNITION"))))]
old = dict(REG)["BOND"]; new = CON(P("LOVE"), P("BEING"))
B = lambda x: "T" if x else "F"
print("WANT mig MIGRATE registry=%d | cosmetic %s→%s form changed:%s ONF held %s admitted:%s" % (
    len(REG), canon(old), canon(new), B(canon(old) != canon(new)), normk(old), B(normk(old) == normk(new))))
