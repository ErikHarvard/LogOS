# -*- coding: utf-8 -*-
"""Lexicon extension, step 1 (Erik 2026-09-18: "Unentered LA.tex tables — inventory them first"). Every named derived glyph in
LINGUA_ADAMICA.tex's derivation TABLES, decoded from its written formula into a κ-form, against the published LA corpus
(lexicon.la LEX + RULED, opgrammar.la GRAM + GRULED — the 79 rows ontomorph reads — plus the nine primitives).
Nothing typed in: the formulas are read from the tex, the corpus from the .la files (derive/overloads.py's reader).
Each concept is classed:  ENTERED (same κ) · ENTERED-DIFFERENT (the corpus carries it under another κ — a ruling moved it,
or a divergence) · NOT ENTERED · UNPARSED (a formula this reader cannot decode — listed, never guessed).
  usage: python3 derive/lexinv.py [--list]
"""
import os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lacore import P, SYN, CON, DIR, CONT, MC, normk
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NINE = ["BEING", "RECOGNITION", "LOVE", "SELF", "RELATION", "VOID", "BECOMING", "FORM", "DEPTH"]
NAMED = {"Rec": "RECOGNITION", "Self": "SELF", "Rel": "RELATION", "Void": "VOID", "Becoming": "BECOMING", "Form": "FORM", "Love": "LOVE",
         "Depth": "DEPTH", "E": "BEING", "Being": "BEING", "Recognition": "RECOGNITION", "Relation": "RELATION"}

# ── the corpus (same reader as derive/overloads.py) ──
SYM = {'*': SYN, '+': CON, '>': DIR, 'c': CONT}
def table_lits(path, name):
    s = open(os.path.join(ROOT, path), encoding='utf-8').read()
    i = s.index('glyph %s =' % name); j = s.index('\nglyph ', i + 1)
    blk = '\n'.join(l if l.lstrip().startswith('"') else l.split('#', 1)[0] for l in s[i:j].split('\n'))
    return [r.split('|') for r in ''.join(re.findall(r'"((?:[^"\\]|\\.)*)"', blk)).split(';') if r]
def dec(code):
    pos = [0]
    def go():
        c = code[pos[0]]; pos[0] += 1
        if c.isdigit(): return P(NINE[int(c) - 1])
        if c == 'm': return MC(go())
        a = go(); b = go(); return SYM[c](a, b)
    return go()
corpus = {}
for p, n in (('lexicon.la', 'LEX'), ('lexicon.la', 'RULED'), ('opgrammar.la', 'GRAM'), ('opgrammar.la', 'GRULED')):
    for r in table_lits(p, n): corpus.setdefault(r[0].lower(), (normk(dec(r[1])), n))
for nm in NINE: corpus.setdefault(nm.lower(), (nm, 'PRIMITIVE'))
corpus_tree = {}
for p, n in (('lexicon.la', 'LEX'), ('lexicon.la', 'RULED'), ('opgrammar.la', 'GRAM'), ('opgrammar.la', 'GRULED')):
    for r in table_lits(p, n): corpus_tree.setdefault(r[0].lower(), dec(r[1]))
USED_NAMES = set()
by_kappa = {}
for nm, (k, _) in corpus.items(): by_kappa.setdefault(k, []).append(nm)

# ── the tex tables ──
tex = open(os.path.join(ROOT, 'LINGUA_ADAMICA.tex'), encoding='utf-8').read().split('\n')
def g(tok):
    m = re.fullmatch(r'\\mathfrak\{g\}_(?:\{)?\\?([A-Za-z0-9]+)\}?', tok.strip())
    if not m: return None
    v = m.group(1)
    if v.isdigit() and 1 <= int(v) <= 9: return P(NINE[int(v) - 1])
    return P(NAMED[v]) if v in NAMED else None
OPS = [(r'\otimes', SYN), (r'\oplus', CON), (r'\triangleright', DIR), (r'\subset', CONT)]
def formula(f):
    """a written derivation → a κ tree, or None. Binary chains of ONE operator are read LEFT-nested (written order)."""
    f = f.strip().strip('$').strip()
    m = re.fullmatch(r'\\circlearrow(?:left|right)\((.*)\)', f)
    if m:
        inner = formula(m.group(1)); return MC(inner) if inner else None
    if f.startswith('(') and f.endswith(')') and f.count('(') == 1: f = f[1:-1]
    for tex_op, ctor in OPS:
        parts = [x for x in re.split(r'\s*' + re.escape(tex_op) + r'\s*', f)]
        if len(parts) > 1:
            if any(re.search(r'\\(otimes|oplus|triangleright|subset)', x) for x in parts): return None   # mixed operators: not guessed
            ts = [formula(x) for x in parts]
            if None in ts: return None
            t = ts[0]
            for u in ts[1:]: t = ctor(t, u)
            return t
    t = g(f)
    if t is None:                                   # a NAMED operand: a concept the corpus already carries (Substance, Life, Bond…)
        nm = re.sub(r'\\mathrm\{([^}]*)\}', r'\1', f).strip().lower()
        if nm in corpus_tree: USED_NAMES.add(nm); return corpus_tree[nm]
    return t
rows = []
for i, l in enumerate(tex, 1):
    if '&' not in l or '\\textbf' in l or 'multicolumn' in l: continue
    cells = [c.strip() for c in l.split('&')]
    fi = next((k for k, c in enumerate(cells) if '\\mathfrak{g}' in c), None)
    if fi is None: continue
    # the concept is the first NON-formula, non-phonym cell (tables put it before or after the formula)
    ci = next((k for k, c in enumerate(cells) if k != fi and c and '\\mathfrak' not in c and not c.startswith('/')), None)
    if ci is None: continue
    concept = re.sub(r'\\\\.*$', '', cells[ci]); concept = re.sub(r'\$[^$]*\$|\\[a-z]+\{|[{}]|\(.*?\)', '', concept).strip()
    rows.append((i, concept, cells[fi], formula(cells[fi])))
B = lambda x: "T" if x else "F"
cls = {"ENTERED": [], "ENTERED-DIFFERENT": [], "NOT ENTERED": [], "UNPARSED": []}
for i, concept, f, t in rows:
    names = [n.strip().lower() for n in concept.split('/') if n.strip()]
    if t is None: cls["UNPARSED"].append((i, concept, f, "")); continue
    k = normk(t)
    hit = [(n, corpus[n]) for n in names if n in corpus]
    if not hit: cls["NOT ENTERED"].append((i, concept, k, " κ already names: " + "/".join(by_kappa[k]) if k in by_kappa else "")); continue
    same = [n for n, (ck, _) in hit if ck == k]
    if same: cls["ENTERED"].append((i, concept, k, ""))
    else: cls["ENTERED-DIFFERENT"].append((i, concept, k, " corpus: " + ", ".join("%s=%s (%s)" % (n, ck, src) for n, (ck, src) in hit)))
print("LEXINV named operands resolved from the CORPUS (their κ as published, rulings included): %s" % (", ".join(sorted(USED_NAMES)) or "none"))
print("LEXINV tex derivation rows=%d | corpus names=%d | ENTERED=%d ENTERED-DIFFERENT=%d NOT ENTERED=%d UNPARSED=%d"
      % (len(rows), len(corpus), *(len(cls[c]) for c in ("ENTERED", "ENTERED-DIFFERENT", "NOT ENTERED", "UNPARSED"))))
for c in ("NOT ENTERED", "ENTERED-DIFFERENT", "UNPARSED") + (("ENTERED",) if "--list" in sys.argv else ()):
    for i, concept, k, note in cls[c]:
        print("  %-17s L%-5d %-26s %s%s" % (c, i, concept[:26], k, note))
