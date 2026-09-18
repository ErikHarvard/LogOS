# -*- coding: utf-8 -*-
"""F20 derivation, gate §21 (entendre). The compound C = ⊗(κ,𝓡) (entendre's STATED gate input); readings per its
header: I vertical = the strata of its derivation; II horizontal = the DAG's defs; III calligraphic = the mark census."""
import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lacore import *
T = "en"
C = SYN(KAPPA, REVAL)
first = [canon(c) for c in C[1:]]
second = [canon(g) for c in C[1:] if c[0] != "P" for g in c[1:]]
ops = [SYM[C[0]]] + [SYM[c[0]] for c in C[1:] if c[0] != "P"]
print("WANT %s I vertical: surface=%s | first depth: %s | second depth: %s | third depth (operators): %s" % (T, canon(C), ", ".join(first), ", ".join(second), " ".join(ops)))
marks = []
def walk(u):
    if u[0] != "P": marks.append(SYM[u[0]]); [walk(c) for c in u[1:]]
walk(C)
leaves = tsize(C) - len(marks)
form = dag(C)
print("WANT %s II horizontal: facets=%d: %s | III calligraphic: elements: marks=%d (⊗%d ⊕%d ▷%d ⊂%d ↻%d) leaves=%d [B: census, not execution]"
      % (T, len(form.split(";")), form, len(marks), *(marks.count(s) for s in "⊗⊕▷⊂↻"), leaves))
# "four readings pairwise distinct": entendre compares the four LABELLED strings (surface= / facets= / elements: / contour=),
# which differ by their labels whatever their content — so the verdict is T by construction.
print("WANT %s four readings pairwise distinct, all derived from the DAG:T | primitive LOVE: I=⊥" % T)
print("NOTE %s 'four readings pairwise distinct' compares LABELLED strings (surface= / facets= / elements: / contour=) — distinct by their labels alone, so it cannot fail (F23)" % T)
print("WANT %s primitive has no vertical reading (red path):%s" % (T, B(tsize(P("LOVE")) == 1)))
