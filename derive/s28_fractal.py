# -*- coding: utf-8 -*-
"""F20 derivation, gate §28 (fractal). fractal.la's STATED chain: C1 = ⊗(κ,𝓡), Cn = ⊗(Cn-1,Cn-1), reported for C1..C4;
surface = byte length of the ren (κ string), fractal = defs of the hash-consed DAG."""
import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lacore import *
T = "fr"
C = [SYN(KAPPA, REVAL)]
for _ in range(3): C.append(SYN(C[-1], C[-1]))
s = [len(canon(c).encode()) for c in C]; f = [len(dag(c).split(";")) for c in C]
parts = " | ".join("surface=%d fractal=%d" % x for x in zip(s, f))
print("WANT %s FRACTAL chain: %s | surface doubles while the fractal form grows by one:%s | tree recoverable from the DAG alone at every depth:%s"
      % (T, parts, B(all(s[i+1] >= 2*s[i] and f[i+1] == f[i] + 1 for i in range(3))), B(all(dag_decomp(dag(c)) == c for c in C))))
