# -*- coding: utf-8 -*-
"""F20 derivation, gate §46 (crossbranch). crossbranch.la's STATED rule: a branch's compression operation g extracts to
NORMK(ETYM(g)) iff g is self-naming (AUTO_OK: its ren == CANON of its etymology), else "" (named). Inputs: the 18 built
branches, EVERY ONE assigned the same operation (the ⊗ mode glyph, metaglyph's ⊗ = ▷(LOVE,RELATION)); fixture PATH A =
the ⊗ glyph under the stipulated ren "by-convention"; PATH B = the ▷ mode glyph ⊗(BECOMING,RELATION) (compression by
deletion)."""
import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lacore import *
T = "xb"
MERGE, DELETE = DIR(P("LOVE"), P("RELATION")), SYN(P("BECOMING"), P("RELATION"))
def extract(ren, etym): return normk(etym) if ren == canon(etym) else ""
built = [(n, canon(MERGE), MERGE) for n in "phonetics phonology morphology syntax semantics pragmatics discourse etymology semiotics historical sociolinguistics psycholinguistics computational grammatology grapholinguistics hermeneutics poetics ethics".split()]
ex = [extract(r, e) for _, r, e in built]
pairs = [(i, j) for i in range(len(ex)) for j in range(i + 1, len(ex))]
same = sum(1 for i, j in pairs if ex[i] and ex[i] == ex[j])
print("WANT %s CROSSBRANCH branches BUILT=%d" % (T, len(built)))
print("WANT %s κ-IDENTICAL pairs: %d DIFFERING pairs: %d | all pairs collapse:%s" % (T, same, len(pairs) - same, B(same == len(pairs))))
print("WANT %s PATH A (compression by CONVENTION — a stipulated ren, not a structural operation): extractable:%s (must be F) OFFENDER=FIXTURE-convention"
      % (T, B(extract("by-convention", MERGE) != "")))
print("WANT %s PATH B (compression by DELETION — ▷ drops a parent instead of ⊗ merging): κ form=%s vs merging branches’ %s differs:%s"
      % (T, extract(canon(DELETE), DELETE), ex[0], B(extract(canon(DELETE), DELETE) != ex[0])))
print("NOTE %s the 153 'κ-identical' pairs compare ONE glyph with itself: all 18 branches are assigned the same operation in the input — the collapse is by construction (09-17 correction 4), not a convergence" % T)
