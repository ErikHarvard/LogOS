# -*- coding: utf-8 -*-
"""§33 certify derivation (2026-09-26, F20). Recomputes the captured κ-spine witness WITHOUT the LA code:
  spine    field (a), the arity spine (certify.la:21-23, ruling E3): the constructor arity of every node of the κ traversal,
           pre-order, one digit each — 0 a leaf, 1 metacursive ↻, 2 binary
  replay   field (b): the glyph's lineage — its ONE hash-consed DAG form (lacore.dag, the glyphdag format) — decomposed
           back into a tree (lacore.dag_decomp) and normalised; it must equal NORMK of the glyph itself
The subject is κ = ▷(RECOGNITION,FORM) (canon_spec.la KAPPA). Red paths run on this script: a spine that gives ↻ arity 2
(or a leaf 1) changes "200" only when the form has such a node — for κ it has none, so the arity-of-leaf mutant is the
one that bites (→ "211"); a replay that drops the ▷ operand order (⊂ for ▷) → matches NORMK:F."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lacore import P, DIR, canon, normk, dag, dag_decomp

def spine(t):
    if t[0] == "P": return "0"
    if t[0] == "MC": return "1" + spine(t[1])
    return "2" + spine(t[1]) + spine(t[2])
K = DIR(P("RECOGNITION"), P("FORM"))
replayed = dag_decomp(dag(K))
print("WANT ce CERTIFY κ spine of %s=%s | replayed lineage → ONF %s matches NORMK:%s" % (
    canon(K), spine(K), normk(replayed), "T" if normk(replayed) == normk(K) else "F"))
