# -*- coding: utf-8 -*-
"""F20 derivation, gate §7 (modegenesis, Δ_M). modegenesis.la's STATED admission test over a mode set S and candidate c:
IRR — c's action not pointwise equal (over the probes, up to NORMK) to any single existing mode's action; NOV — c's κ
(NORMK of its etymology) not already in S; AUT — c names itself truly (ren == CANON(etym)); CON — c's action depends on its
operands AND the κ-classes reachable from the probes in one step strictly grow. Inputs: the base set (the five modes with
their REAL actions), probes (A,B),(B,A),(A,A),(κ,B), ν* = ⊗(⊗-glyph, ↻-glyph), fixtures F1–F4. Actions of minted glyphs
by the written APPLYOP rule (lacore)."""
import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lacore import *
T = "mg"
A, Bp = P("A"), P("B")
PROBES = [(A, Bp), (Bp, A), (A, A), (KAPPA, Bp)]
def mode(name, op, act): return {"ren": canon(MODE_GLYPH[op]), "etym": MODE_GLYPH[op], "act": act}
BASE = [mode("⊗", "SYN", SYN), mode("⊕", "CON", CON), mode("▷", "DIR", DIR), mode("⊂", "CONT", CONT), mode("↻", "MC", lambda a, b: MC(a))]
def cand(ren, etym): return {"ren": ren, "etym": etym, "act": lambda a, b, e=etym: applyop(e, a, b)}
def acts(m): return [normk(m["act"](a, b)) for a, b in PROBES]
def classes(S): return {x for m in S for x in acts(m)}
def verdict(S, c):
    irr = all(acts(c) != acts(m) for m in S)
    nov = all(normk(c["etym"]) != normk(m["etym"]) for m in S)
    aut = c["ren"] == canon(c["etym"])
    con = len(set(acts(c))) > 1 and len(classes(S + [c])) > len(classes(S))
    return "".join(B(x) for x in (irr, nov, aut, con))
def admit(S, c): return S + [c] if verdict(S, c) == "TTTT" else S
NU = SYN(MODE_GLYPH["SYN"], MODE_GLYPH["MC"]); C_NU = cand(canon(NU), NU)
F1 = cand(canon(SYN(P("VOID"), P("FORM"))), SYN(P("VOID"), P("FORM")))
F2 = cand(canon(MODE_GLYPH["SYN"]), MODE_GLYPH["SYN"])
F3 = cand("LIE", NU)
F4 = cand("VOID", P("VOID"))
S6 = admit(BASE, C_NU)
v = [verdict(BASE, f) for f in (F1, F2, F3, F4)]
print("WANT %s ν* IRR/NOV/AUT/CON=%s admitted:%s set=%d | F1 action≡⊗ =%s refused:%s | F2 α-copy =%s refused:%s | F3 false ren =%s refused:%s | F4 constant =%s refused:%s"
      % (T, verdict(BASE, C_NU), B(len(S6) == 6), len(S6), v[0], B(v[0] != "TTTT"), v[1], B(v[1] != "TTTT"), v[2], B(v[2] != "TTTT"), v[3], B(v[3] != "TTTT")))
print("WANT %s re-admit ν* verdict=%s Δ_M(Δ_M)≡Δ_M idempotent:%s" % (T, verdict(S6, C_NU), B(len(admit(S6, C_NU)) == len(S6))))
print("WANT %s ν* action on (A,B): %s" % (T, canon(C_NU["act"](A, Bp))))
