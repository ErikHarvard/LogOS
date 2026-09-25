# -*- coding: utf-8 -*-
"""L1/L2 ripple census (2026-09-25) — Erik RATIFIED onecollapse.la's two laws into the language:
     L1  Λ(Λx) ≡ Λx          L2  Λ(a⊕b) ≡ Λa ⊕ Λb          Λ = λx.⊂(RELATION,x)
Before they move from a layer into NORMK (canon_spec.la, after the freeze — the F4(c) precedent), derive what moves:
every named glyph whose identity key CHANGES, and every pair of distinct names that would COLLIDE (a new synonymy the
monosemy gates would see). Corpus: the four published tables (lexicon LEX/RULED, opgrammar GRAM/GRULED), the 18 base
branch interfaces (branchgenesis.la's ratified table), the five mode glyphs (metaglyph.la:65–69), κ, 𝓡 and the eight
self-relations (CLAUDE.md). Independent of onecollapse.la: the laws are re-implemented here from their statement.
Report only; rc 0."""
import os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
from lacore import P, SYN, CON, DIR, CONT, MC, KAPPA, REVAL, normk, NINE
ROOT = os.path.dirname(HERE)

def table(path, name):
    s = open(os.path.join(ROOT, path), encoding='utf-8').read()
    i = s.index('glyph %s =' % name); j = s.index('\nglyph ', i + 1)
    blk = '\n'.join(l if l.lstrip().startswith('"') else l.split('#', 1)[0] for l in s[i:j].split('\n'))
    return [r.split('|') for r in ''.join(re.findall(r'"((?:[^"\\]|\\.)*)"', blk)).split(';') if r]
OPS = {'*': SYN, '+': CON, '>': DIR, 'c': CONT}
def dec(code):
    pos = [0]
    def go():
        c = code[pos[0]]; pos[0] += 1
        if c.isdigit(): return P(NINE[int(c) - 1])
        if c == 'm': return MC(go())
        return OPS[c](go(), go())
    t = go(); assert pos[0] == len(code), code; return t

REL = P("RELATION")
L = lambda x: CONT(REL, x)
isL = lambda t: t[0] == "CONT" and t[1] == REL
def lnf(t):
    """the distributed normal form under L1+L2: children first, then Λ pushed through ⊕ and absorbed by Λ"""
    if t[0] == "P": return t
    if t[0] == "MC": return MC(lnf(t[1]))
    a, b = lnf(t[1]), lnf(t[2])
    if t[0] == "CONT" and a == REL: return lam(b)
    return (t[0], a, b)
def lam(b):
    if isL(b): return b                                   # L1
    if b[0] == "CON": return CON(lam(b[1]), lam(b[2]))    # L2 (operands already normal)
    return L(b)

corpus = []
for p, n in (('lexicon.la', 'LEX'), ('lexicon.la', 'RULED'), ('opgrammar.la', 'GRAM'), ('opgrammar.la', 'GRULED')):
    corpus += [(r[0], dec(r[1])) for r in table(p, n)]
B = lambda n: P(n)
IFACES = [("phonetics", B("BECOMING")), ("phonology", MC(B("BECOMING"))), ("morphology", DIR(B("BECOMING"), B("FORM"))),
          ("syntax", CONT(REL, B("FORM"))), ("semantics", B("BEING")), ("pragmatics", B("LOVE")),
          ("discourse", SYN(B("FORM"), B("LOVE"))), ("etymology", MC(B("VOID"))), ("semiotics", MC(B("FORM"))),
          ("historical", DIR(B("BECOMING"), B("VOID"))), ("sociolinguistics", CON(B("SELF"), B("SELF"))),
          ("psycholinguistics", B("SELF")), ("computational", B("DEPTH")), ("grammatology", DIR(B("FORM"), B("DEPTH"))),
          ("grapholinguistics", CONT(B("FORM"), B("FORM"))), ("hermeneutics", DIR(B("RECOGNITION"), B("DEPTH"))),
          ("poetics", SYN(B("LOVE"), B("BECOMING"))), ("ethics", DIR(B("LOVE"), B("BEING")))]
corpus += [("branch:" + n, L(x)) for n, x in IFACES]
corpus += [("MODE_SYN", DIR(B("LOVE"), REL)), ("MODE_CON", CONT(REL, B("FORM"))), ("MODE_DIR", SYN(B("BECOMING"), REL)),
           ("MODE_CONT", DIR(B("DEPTH"), B("FORM"))), ("MODE_MC", MC(B("SELF"))), ("KAPPA", KAPPA), ("REVAL", REVAL)]
corpus += [("SR_" + n, MC(B(x))) for n, x in (("TO", "DEPTH"), ("ABOUT", "RECOGNITION"), ("AS", "FORM"), ("BY", "BECOMING"),
                                               ("FROM", "VOID"), ("THROUGH", "RELATION"), ("FOR", "LOVE"))]
corpus += [("SR_WITH", CON(B("SELF"), B("SELF")))]

old = {n: normk(t) for n, t in corpus}
new = {n: normk(lnf(t)) for n, t in corpus}
moved = [n for n, _ in corpus if old[n] != new[n]]
print("L1L2 corpus=%d named glyphs | identity key CHANGES for %d: %s" % (len(corpus), len(moved), " ".join(moved) or "(none)"))
for n in moved: print("  MOVES %-26s %s  →  %s" % (n, old[n], new[n]))
def pairs(key):
    by = {}
    for n, _ in corpus: by.setdefault(key[n], []).append(n)
    return {frozenset(v) for v in by.values() if len(v) > 1}
fresh = pairs(new) - pairs(old)
print("L1L2 NEW collisions (distinct before, one glyph after): %d" % len(fresh))
for g in sorted(fresh, key=sorted): print("  COLLIDES " + " = ".join(sorted(g)) + "   (" + new[sorted(g)[0]] + ")")
