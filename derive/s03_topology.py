# -*- coding: utf-8 -*-
"""F20 derivation for gate §3 (topology). Every value from the DEFINITIONS in lacore (REGISTERS.md's topological
reading over CLAUDE.md's glyph-DAG), not from topology.la. Prints `WANT <tag> <token>` lines for check.py, and
`NOTE` lines for what a derivation found that the pinned witness does not say."""
import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lacore import *
T = "top"
tree, shared = topo(dag(KAPPA)), topo(dag(SYN(KAPPA, KAPPA)))
corrupt = topo("BEING;⊗0.7")                                   # REGISTERS.md: the RED fixture BEING;⊗0.7
swap = topo(dag(CON(KAPPA, REVAL))) == topo(dag(CON(REVAL, KAPPA)))
G = DIR(P("RECOGNITION"), CONT(P("FORM"), P("DEPTH")))         # topology.la:44 G_TOP's decomposition (an INPUT)
truth = normk(MC(MC(G))) == normk(MC(G)); glyph = canon(MC(MC(G))) == canon(MC(G))
# "every lineage computes (no ⊥)": DAG() of ANY decomposition is valid BY CONSTRUCTION (each def is appended after
# its children, so every reference is to an EARLIER index) — checked here over the witnessed forms.
by_construction = all(parse_defs(dag(x)) is not None for x in (KAPPA, REVAL, G, SYN(KAPPA, KAPPA), MC(MC(G))))
print("WANT %s every lineage computes (no ⊥):%s | corrupted DAG reads ⊥:%s | ⊕-order invariant:%s" % (T, B(by_construction), B(corrupt == "⊥"), B(swap)))
print("WANT %s κ tree: %s" % (T, tree))
print("WANT %s ⊗(κ,κ) shared: %s" % (T, shared))
print("WANT %s MetaTop(MetaTop)≡MetaTop truth:%s glyph:%s" % (T, B(truth), B(glyph)))
# ★ does "⊕-order invariant:T" DISCRIMINATE? The reading's numbers are symmetric in a node's two children, so the
#   same swap under the DIRECTIONAL ▷ must be checked too: if it is ALSO invariant, the witness cannot tell ⊕ from ▷.
dswap = topo(dag(DIR(KAPPA, REVAL))) == topo(dag(DIR(REVAL, KAPPA)))
print("WANT %s (▷-order ALSO invariant:%s — the reading is ORDER-BLIND, so this is no ⊕ property; [B] topology cannot see direction)" % (T, B(dswap)))
print("NOTE %s F21: the ⊕ line holds because the reading forgets child order under every mode (▷ swap invariant: %s) — it witnesses that topology never splits ⊕-synonyms, not ⊕'s commutativity" % (T, B(dswap)))
