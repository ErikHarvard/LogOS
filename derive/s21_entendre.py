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
# "four readings pairwise distinct" — by CONTENT since F23 (2026-09-18): each reading's payload without labels.
# IV's payload is the prosodic reading, from prosody.la's STATED table and mode rules (F09 contour, DUR9 duration;
# ⊗ {a+b}~64 dur max · ⊕ (a)·ʔ·(b) dur a+960+b · ▷ (a)´-(b)~128 dur a+b · ⊂ (b)[a](b) dur 2b+a · ↻ (a)(a) dur 2a).
F09 = {"RECOGNITION": "140", "FORM": "120", "DEPTH": "90,135→50"}
DUR9 = {"RECOGNITION": 6720, "FORM": 6160, "DEPTH": 6000}
def pros(u):
    if u[0] == "P": return u[1] + "/" + F09[u[1]], DUR9[u[1]]
    if u[0] == "MC": a, da = pros(u[1]); return "(%s)(%s)" % (a, a), 2 * da
    (a, da), (b, db) = pros(u[1]), pros(u[2])
    return {"SYN": ("{%s+%s}~64" % (a, b), max(da, db)), "CON": ("(%s)·ʔ·(%s)" % (a, b), da + 960 + db),
            "DIR": ("(%s)´-(%s)~128" % (a, b), da + db), "CONT": ("(%s)[%s](%s)" % (b, a, b), 2 * db + da)}[u[0]]
def allleaves(u): return [u] if u[0] == "P" else [g for c in u[1:] for g in allleaves(c)]   # EN_LEAVES: every primitive leaf, left to right
leafs = allleaves(C)
pay_i = "%s / %s / %s / %s" % (canon(C), ", ".join(first), ", ".join(canon(g) for g in leafs), " ".join(ops))
pay_ii = form
pay_iii = " ".join(str(x) for x in [len(marks)] + [marks.count(s_) for s_ in "⊗⊕▷⊂↻"] + [leaves])
ct, du = pros(C); pay_iv = "%s %d" % (ct, du)
pays = [pay_i, pay_ii, pay_iii, pay_iv]
print("WANT %s four readings pairwise distinct by CONTENT (labels stripped), all derived from the DAG:%s | primitive LOVE: I=⊥" % (T, B(len(set(pays)) == 4)))
print("NOTE %s the four payloads: I=[%s] II=[%s] III=[%s] IV=[%s]" % (T, pay_i, pay_ii, pay_iii, pay_iv))
print("WANT %s primitive has no vertical reading (red path):%s" % (T, B(tsize(P("LOVE")) == 1)))
