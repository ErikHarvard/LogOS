# -*- coding: utf-8 -*-
"""F20 derivation, gate §9 (complement + opposite). complement.la's STATED rules: ¬X = ⊂(X,VOID) (ruling 2026-08-23,
opgrammar R_NEG = CONT(x)(VOID)); GLYPH_ID = NORMK; TRUTH_ID = NORMK(CANCEL(etym)), CANCEL rewriting ⊂(⊂(x,VOID),VOID) → x.
opposite.la's STATED rule: a glyph has a dyadic opposite iff its head is ▷ with two DISTINCT operands; the opposite is
the reversed direction; otherwise OPP refuses. Inputs: C = κ; G_NOT = ⊂(FORM,VOID); Past = ▷(BECOMING,VOID);
Future = ▷(VOID,BECOMING); G_OPP = ▷(RELATION,VOID)."""
import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lacore import *
V = P("VOID")
def NEG(x): return CONT(x, V)
def cancel(t):
    if t[0] == "P": return t
    t = (t[0],) + tuple(cancel(c) for c in t[1:])
    if t[0] == "CONT" and t[2] == V and t[1][0] == "CONT" and t[1][2] == V: return t[1][1]
    return t
G = lambda t: normk(t)
TR = lambda t: normk(cancel(t))
C = KAPPA; nC, nnC, nnnC = NEG(C), NEG(NEG(C)), NEG(NEG(NEG(C)))
T = "cmp"
print("WANT %s COMPLEMENT ¬X = ⊂(X,VOID) (ruling 2026-08-23) shape==opgrammar NEG_SHAPE:%s" % (T, B(canon(NEG(P("x"))) == canon(CONT(P("x"), V)))))
print("WANT %s sealed+VOID-parent:%s | ¬C≠C glyph:%s truth:%s | ¬¬C≠¬C glyph:%s truth:%s | ¬¬C≠C glyph:%s ¬¬C≡C truth:%s ¬¬¬C≡¬C truth:%s"
      % (T, B(nC[2] == V), B(G(nC) != G(C)), B(TR(nC) != TR(C)), B(G(nnC) != G(nC)), B(TR(nnC) != TR(nC)), B(G(nnC) != G(C)), B(TR(nnC) == TR(C)), B(TR(nnnC) == TR(nC))))
print("WANT %s two registers explicit: differ on ¬¬C:%s coincide on C:%s | conflated system would read ¬¬C≡C as:%s"
      % (T, B(G(nnC) != TR(nnC)), B(G(C) == TR(C)), B(G(nnC) == G(C))))
A = CONT(P("FORM"), V); AA = NEG(A)
print("WANT %s G_NOT=%s A(A)=%s" % (T, canon(A), canon(AA)))
print("WANT %s A(A)≠A glyph:%s | A(A)≡id truth (cancels to the hole FORM):%s" % (T, B(G(AA) != G(A)), B(TR(AA) == "FORM")))
def OPP(g):
    return DIR(g[2], g[1]) if g[0] == "DIR" and normk(g[1]) != normk(g[2]) else None
PAST, FUTURE = DIR(P("BECOMING"), V), DIR(V, P("BECOMING"))
T = "opp"
op = OPP(PAST)
refuse = OPP(P("BEING")) is None, OPP(CON(P("BEING"), P("LOVE"))) is None, OPP(DIR(P("LOVE"), P("LOVE"))) is None
has_pole = OPP(PAST) is not None and OPP(P("BEING")) is None
print("WANT %s OPP(Past)=%s ≡Future:%s | involution OPP(OPP(Past))=Past:%s OPP(Past)≠Past:%s | refuses primitive(Being):%s ⊕:%s ▷(x,x):%s | HAS_POLE Past:T Being:F ->%s"
      % (T, canon(op), B(normk(op) == normk(FUTURE)), B(normk(OPP(op)) == normk(PAST)), B(normk(op) != normk(PAST)), *(B(x) for x in refuse), B(has_pole)))
print("NOTE %s 'HAS_POLE Past:T Being:F' is LITERAL text in opposite.la:74; only the '->T' is computed — if a case flipped, the output would still print the two per-case values unchanged (F24)" % T)
GO = DIR(P("RELATION"), V); GOO = OPP(GO)
print("WANT %s A(A)=%s exists:%s A(A)≠A:%s A(A(A))=A:%s" % (T, canon(GOO), B(GOO is not None), B(normk(GOO) != normk(GO)), B(normk(OPP(GOO)) == normk(GO))))
