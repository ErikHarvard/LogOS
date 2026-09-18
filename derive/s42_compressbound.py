# -*- coding: utf-8 -*-
"""F20 derivation, gate §42 (compressbound). The κ chain g0=κ, g(n+1)=⊗(gn,gn), n=0..5; the ∃ chain likewise from ∃.
Sizes: unfolded tree nodes, retained hash-consed defs, and meaning-string length in BYTES (compressbound's stated unit)."""
import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lacore import *
T = "cb"
def chain(g0, n=6):
    out = [g0]
    for _ in range(n - 1): out.append(SYN(out[-1], out[-1]))
    return out
K = chain(KAPPA); E = chain(P("∃"))
tree = [tsize(g) for g in K]; kept = [len(dag(g).split(";")) for g in K]
j = lambda xs: " ".join(str(x) for x in xs)
print("WANT %s COMPRESSBOUND κ chain ⊗(g,g)×5 | UNFOLDED tree: %s | RETAINED hash-consed: %s | tree DOUBLES:%s retained grows by EXACTLY +1:%s"
      % (T, j(tree), j(kept), B(all(tree[i+1] == 2*tree[i] + 1 for i in range(5))), B(all(kept[i+1] == kept[i] + 1 for i in range(5)))))
print("WANT %s NO NOISE: etymology recovers EXACTLY at every depth:%s | every depth κ-distinct (normalisation loses nothing either):%s"
      % (T, B(all(normk(dag_decomp(dag(g))) == normk(g) for g in K)), B(len({normk(g) for g in K}) == len(K))))
el = [len(normk(g).encode()) for g in E]; kl = [len(normk(g).encode()) for g in K]
print("WANT %s THE ARCHĒ IS THE TERMINATOR: ⊗(∃,∃)→∃ (⊗-idempotence for the Archē ALONE). meaning-string length — ∃ chain: %s (constant:%s) vs κ chain: %s (constant:%s)"
      % (T, j(el), B(len(set(el)) == 1), j(kl), B(len(set(kl)) == 1)))
