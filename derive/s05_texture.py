# -*- coding: utf-8 -*-
"""F20 derivation, gate §5 (texture) — PARTIAL: the F21 order-blindness token only (2026-09-18). texture.la's STATED
reading over a lineage's defs: m = 100 if V = 1 else 100·E/(V−1) · a = 100·leaves/V · r = 100/(1+depth), integer
division, depth from the ROOT (the last def). Every quantity is symmetric in a node's two children (E and leaves are
sums, depth takes a max), so swapping operands cannot change it under ANY mode — computed here for ▷, the directional
mode, where a reading that saw order would have to differ."""
import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lacore import *
T = "tex"
def texture(form):
    ds = parse_defs(form)
    if ds is None: return "⊥"
    V = len(ds); E = sum(d[0] for d in ds); L = sum(1 for d in ds if d[0] == 0)
    memo = {}
    def depth(i):
        if i not in memo: memo[i] = 0 if not ds[i][1] else 1 + max(depth(c) for c in ds[i][1])
        return memo[i]
    m = 100 if V == 1 else (100 * E) // (V - 1)
    return "m=%d a=%d r=%d" % (m, (100 * L) // V, 100 // (1 + depth(V - 1)))
d1, d2 = texture(dag(DIR(KAPPA, REVAL))), texture(dag(DIR(REVAL, KAPPA)))
print("WANT %s ▷-order ALSO invariant:%s — the reading is ORDER-BLIND, so ⊕-order invariance is no ⊕ property; [B] texture cannot see direction"
      % (T, B(d1 == d2)))
print("NOTE %s ▷(κ,𝓡) reads %s, ▷(𝓡,κ) reads %s; κ reads %s and ⊗(κ,κ) %s (the pinned values, cross-checked, not pinned from here)"
      % (T, d1, d2, texture(dag(KAPPA)), texture(dag(SYN(KAPPA, KAPPA)))))
