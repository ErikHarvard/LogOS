# -*- coding: utf-8 -*-
"""§12 textcoherence derivation (2026-09-26, F20). Recomputes textcoherence.la's three captured witnesses WITHOUT the LA
code, from the definitions its header states (textcoherence.la:9-22) and the two relations it borrows:
  referents  a proposition's compound sub-glyphs, the proposition first, then each operand's (pre-order, duplicates kept);
             a bare primitive proposition refers to itself; a primitive LEAF inside a compound is not a referent ([A])
  key        NORMK (lacore.normk — an independent model); ¬key = NORMK of ¬g; oppkey = NORMK of OPP(g), "" when no pole
  ¬g         ⊂(g, VOID) — complement.la NEG_MODE = CONT, the 2026-08-23 ruling (its import comment "⊕(VOID,g)" is stale)
  OPP(g)     ▷(b,a) when g = ▷(a,b) with NORMK(a) ≠ NORMK(b); no pole otherwise (opposite.la header: primitives, ⊕, ⊗, ⊂,
             ↻ and a symmetric ▷ have none)
  store      referents walked in text order; a key already stored is GIVEN, else NEW and stored with its proposition index
  edge i-j   (j < i) labelled by every relation that fires between SOME referent of i and SOME referent of j, in the order
             share (keys equal) · contrast:¬ (¬key of one = key of the other, either way) · contrast:opp (oppkey of i's
             referent = key of j's — one direction suffices, OPP is an involution); "+"-joined; no label, no edge
  reading    components = connected components (computed here by union-find, NOT the module's label propagation, so a
             propagation that stopped early would disagree); maxdist = max(i-j) over edges; orphans = untouched vertices
The vector is the module's text(a) (I▷you, you▷past, we▷future, question▷we, ongoing▷future over the codex glyphs
tex:5160-5175) and its shuffle [3,1,5,4,2].
RED PATHS, run on this script (2026-09-26): no opp relation → 1 of 3 pins; leaf primitives counted as referents → 1 of 3;
no share relation → 2 of 3. ★ Two mutants SURVIVE, and what that says about the pins is stated, not hidden: ¬ built with
the wrong mode (⊕ for ⊂) — ¬ never links anything in text(a), exactly as the module's header says (¬ is witnessed by its
fixture alone, a red-pathed line); raw κ for NORMK — text(a) holds no ⊕ node and no ↻(BEING), so the two agree on this
vector. These three pins cannot see ¬ or the equivalence theory."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lacore import P, SYN, DIR, CONT, MC, normk

def refs(n):
    if n[0] == "P": return [n]
    out = [n]
    for c in n[1:]:
        out += subs(c)
    return out
def subs(n):
    if n[0] == "P": return []
    out = [n]
    for c in n[1:]: out += subs(c)
    return out
def keyed(n):
    k = normk(n); nk = normk(CONT(n, P("VOID")))
    ok = normk(DIR(n[2], n[1])) if n[0] == "DIR" and normk(n[1]) != normk(n[2]) else ""
    return (k, nk, ok)

YOU, WE = DIR(P("SELF"), P("RECOGNITION")), SYN(P("SELF"), P("RELATION"))
QUESTION, PAST, FUTURE, ONGOING = DIR(P("RECOGNITION"), P("VOID")), DIR(P("BECOMING"), P("VOID")), DIR(P("VOID"), P("BECOMING")), MC(P("BECOMING"))
P1, P2, P3, P4, P5 = DIR(P("SELF"), YOU), DIR(YOU, PAST), DIR(WE, FUTURE), DIR(QUESTION, WE), DIR(ONGOING, FUTURE)
TEXT_A = [P1, P2, P3, P4, P5]
TEXT_S = [P3, P1, P5, P4, P2]

def label(ri, rj):
    labs = []
    if any(a[0] == b[0] for a in ri for b in rj): labs.append("share")
    if any(a[1] == b[0] or b[1] == a[0] for a in ri for b in rj): labs.append("contrast:¬")
    if any(a[2] != "" and a[2] == b[0] for a in ri for b in rj): labs.append("contrast:opp")
    return "+".join(labs)
def edges(text):
    kr = [[keyed(r) for r in refs(p)] for p in text]
    out = []
    for i in range(1, len(text) + 1):
        for j in range(1, i):
            lab = label(kr[i - 1], kr[j - 1])
            if lab: out.append((i, j, lab))
    return out
def ncomp(n, es):
    par = list(range(n + 1))
    def f(x):
        while par[x] != x: par[x] = par[par[x]]; x = par[x]
        return x
    for i, j, _ in es: par[f(i)] = f(j)
    return len({f(k) for k in range(1, n + 1)})
def read(tag, text):
    es = edges(text); n = len(text); nc = ncomp(n, es)
    touched = {i for i, j, _ in es} | {j for i, j, _ in es}
    orph = [k for k in range(1, n + 1) if k not in touched]
    return "%s n=%d edges=[%s] components=%d coherent:%s maxdist=%d orphans:%s" % (
        tag, n, " ".join("%d-%d:%s" % e for e in es), nc, "T" if nc == 1 else "F",
        max([i - j for i, j, _ in es] or [0]), "none" if not orph else "OFFENDER=?")

print("WANT tc " + read("TEXTCOHERENCE text(a)", TEXT_A))
store, given, new = [], 0, 0
for i, p in enumerate(TEXT_A, 1):
    for r in refs(p):
        k = keyed(r)[0]
        if k in store: given += 1
        else: store.append(k); new += 1
print("WANT tc referents=%d mentions=%d given=%d new=%d" % (len(store), given + new, given, new))
ea, es = edges(TEXT_A), edges(TEXT_S)
print("WANT tc components order-independent:%s maxdist original=%d shuffled=%d" % (
    "T" if ncomp(5, ea) == ncomp(5, es) else "F", max(i - j for i, j, _ in ea), max(i - j for i, j, _ in es)))
