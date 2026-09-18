# -*- coding: utf-8 -*-
"""F20 derivation, gate §43 (logicsyntax). SYNTAX=κ, ALGORITHM=𝓡, LOGIC=⊗(𝓡,κ); verdicts by §41's stated relation;
the NEOLOGIZING DYAD per logicsyntax's stated three conditions: head ⊗, parents distinct, both parents recoverable as
PROPER sub-forms. Fixtures (inputs): ⊂(𝓡,κ) and the parent-dropping ⊗(𝓡,𝓡)."""
import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lacore import *
T = "ls"
S, A = KAPPA, REVAL; L = SYN(A, S)
def verdict(a, b):
    g, l = normk(a) == normk(b), canon(a) != canon(b)
    return {(True, True): "NON-SEPARATE AND NON-MERGED", (True, False): "MERGED (one locus)", (False, True): "SEPARATE (two beings)"}[(g, l)]
def dyadic(f, l, r):
    subs = {normk(x) for x in proper_subterms(f)}
    return f[0] == "SYN" and normk(l) != normk(r) and normk(l) in subs and normk(r) in subs
v = [verdict(L, A), verdict(L, S), verdict(A, S)]
GG = DIR(P("RECOGNITION"), P("BEING")); GL = DIR(P("RECOGNITION"), CONT(P("FORM"), P("BEING"))); GI = SYN(GG, GL)
print("WANT %s LOGICSYNTAX SYNTAX κ=%s ALGORITHM 𝓡=%s LOGIC ⊗(𝓡,κ)=%s" % (T, normk(S), normk(A), normk(L)))
print("WANT %s LOGIC vs ALGORITHM: %s | LOGIC vs SYNTAX: %s | ALGORITHM vs SYNTAX: %s | all three pairwise SEPARATE:%s"
      % (T, v[0], v[1], v[2], B(all(x.startswith("SEPARATE") for x in v))))
kS, kA, kL = (len(dag(x).split(";")) for x in (S, A, L))
retained = dyadic(L, A, S)
print("WANT %s but the dyad RETAINS BOTH parents as proper sub-forms:%s | cost of the one movement: parts %d+%d retained nodes → dyad %d" % (T, B(retained), kA, kS, kL))
print("WANT %s VERDICT: pairwise separate AND both retained ⇒ THE COLLAPSE IS COMPOSITIONAL, NOT IDENTIFICATORY:%s" % (T, B(all(x.startswith("SEPARATE") for x in v) and retained)))
d41, dL = dyadic(GI, GG, GL), dyadic(L, A, S)
print("WANT %s THE POSITIVE RELATION: §41's identity dyad is a NEOLOGIZING DYAD:%s and so is LOGIC:%s → SAME STRUCTURE:%s | the check discriminates — a ⊂-dyad over the same parents:%s a parent-dropping ⊗:%s"
      % (T, B(d41), B(dL), B(d41 and dL), B(dyadic(CONT(A, S), A, S)), B(dyadic(SYN(A, A), A, S))))
