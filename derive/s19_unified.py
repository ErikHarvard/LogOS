# -*- coding: utf-8 -*-
"""F20 derivation, gate §19 (unified) — PARTIAL: the no-glyphic-entropy line (2026-09-18, with F28c). Inputs as unified.la
STATES them: C0 = seal(κ), RV = seal(𝓡), C1 = ⊗(C0,RV), Cn = ⊗(Cn-1,Cn-1); SZ = 32 (sigil.la's one grid). Durations from
prosody.la's STATED table and mode rules (DUR9; ⊗ max · ⊕ a+960+b · ▷ a+b · ⊂ 2b+a · ↻ 2a), the same model as s21."""
import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lacore import *
T = "un"
DUR9 = {"BEING": 6080, "RECOGNITION": 6720, "LOVE": 6560, "SELF": 6560, "RELATION": 6720, "VOID": 6880, "BECOMING": 6400, "FORM": 6160, "DEPTH": 6000}
def dur(u):
    if u[0] == "P": return DUR9[u[1]]
    if u[0] == "MC": return 2 * dur(u[1])
    a, b = dur(u[1]), dur(u[2])
    return {"SYN": max(a, b), "CON": a + 960 + b, "DIR": a + b, "CONT": 2 * b + a}[u[0]]
C0, RV = KAPPA, REVAL
C = [C0, SYN(C0, RV)]
for _ in range(3): C.append(SYN(C[-1], C[-1]))
per = "⊗=%d ⊕=%d ▷=%d ⊂=%d ↻=%d " % (dur(SYN(C0, RV)), dur(CON(C0, RV)), dur(DIR(C0, RV)), dur(CONT(C0, RV)), dur(MC(C0)))
print("WANT %s raster SZ=32 at every depth fixed [A: by construction — every SIGIL is a predicate sampled on the one SZ grid; no per-glyph size exists to grow] | phonym ⊗-chain PDUR(C4)=PDUR(C0):%s | phonym per mode over (κ,𝓡): %s| sound grows under ⊕ (finding, codex Operator Phonology):%s"
      % (T, B(dur(C[4]) == dur(C0)), per, B(dur(C0) < dur(CON(C0, RV)))))
