# -*- coding: utf-8 -*-
"""F20 derivation, gate §48 (divergent). divergent.la's STATED six compressions over one parent pair (a, b) — inputs
DV_A = κ, DV_P = 𝓡 (REVAL). NOTE: the module's header says "κ and 𝓜"; its input is 𝓡 — a doc mismatch, recorded.
Iteration x(k+1) = OP(x(k), b) from x(0) = a, bounded at 8 steps (the header's stated bound); a fixed point is
x(k+1) NORMK-equal to x(k)."""
import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lacore import *
T = "dv"
a, b = KAPPA, REVAL
OPS = [("SEALER", lambda x, y: SYN(x, y)), ("DELETION", lambda x, y: x), ("SWAP", lambda x, y: SYN(y, x)),
       ("NEST", lambda x, y: CONT(x, y)), ("FOLD", lambda x, y: MC(SYN(x, y))), ("FUSE", lambda x, y: CON(x, y))]
outs = [normk(f(a, b)) for _, f in OPS]
def rests(f, steps=8):
    x = a
    for _ in range(steps):
        y = f(x, b)
        if normk(y) == normk(x): return True
        x = y
    return False
stable = [n for n, f in OPS if rests(f)]
print("WANT %s DIVERGENT six constructed compressions over one parent pair — distinct κ-outputs: %d of 6 — NO agreement at the output level:%s"
      % (T, len(set(outs)), B(len(set(outs)) == 6)))
print("WANT %s reach a FIXED POINT: %d of 6 | the ONLY one that comes to rest is DELETION ★ and it rests by THROWING THE SECOND PARENT AWAY:%s"
      % (T, len(stable), B(stable == ["DELETION"] and normk(b) not in normk(OPS[1][1](a, b)))))
print("WANT %s CONTROL — the sealer is NOT fixed-point-free: ⊗(∃,∃)→∃ rests at the Archē:%s" % (T, B(normk(SYN(P("∃"), P("∃"))) == "∃")))
