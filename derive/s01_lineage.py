# -*- coding: utf-8 -*-
"""F20 derivation, gate §1 (lineage — the etymological register). Inputs read as INPUTS from lineage.la: the catalogue
(κ, 𝓡, the eight self-relations, ⊗(κ,κ), G_ETYM), the fixture BEING;⊗0.7, G_ETYM's decomposition. Values from lacore."""
import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lacore import *
T = "lin"
G_ETYM = DIR(P("RECOGNITION"), CONT(P("BECOMING"), P("DEPTH")))
cat = [KAPPA, REVAL] + list(SR.values()) + [SYN(KAPPA, KAPPA), G_ETYM]
recover = all(normk(dag_decomp(dag(x))) == normk(x) for x in cat)          # the form alone recovers the etymology
precede = all(first_invalid(dag(x)) == "" for x in cat)                     # every parent precedes its def
off = first_invalid("BEING;⊗0.7")
shared = SYN(KAPPA, KAPPA); nd = len(dag(shared).split(";"))
print("WANT %s recoverable from lineage alone:%s" % (T, B(recover)))
print("WANT %s every parent precedes its def:%s" % (T, B(precede)))
print("WANT %s broken-parent fixture refused:%s OFFENDER=%s" % (T, B(off != ""), off))
print("WANT %s sharing visible (DAG<tree, %d defs):%s" % (T, nd, B(nd < tsize(shared) and nd == 4)))
print("WANT %s Δ_E(Δ_E)≡Δ_E truth:%s glyph:%s" % (T, B(normk(MC(MC(G_ETYM))) == normk(MC(G_ETYM))), B(canon(MC(MC(G_ETYM))) == canon(MC(G_ETYM)))))
