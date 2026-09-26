# -*- coding: utf-8 -*-
"""§16 ontomorph derivation (2026-09-26, F20). Recomputes ontomorph.la's three pinned lines WITHOUT the LA code: reads the
four published tables (lexicon.la LEX + RULED, opgrammar.la GRAM + GRULED) straight from source and rebuilds each reading
the way the module DEFINES it:
  rows       each table folded left with cons (OM_ROWS_OF — so each table REVERSED), concatenated LEX, RULED, GRAM, GRULED
  skeleton   the raw derivation with every leaf erased to "·", operand order kept (OM_SKEL)
  census     (key, count) in FIRST-APPEARANCE order along the rows (OM_BUMP appends a new key at the end);
             rendered "k=n" each followed by a space (OM_RENDER — hence the double space before " | operator uses")
  op uses    occurrences of * > + c m in the raw digit codes of all rows (OM_OPS), duplicates included
  combos     distinct raw codes, κ-images distinct KAN_N — both collected by cons, so in REVERSE first-appearance order
  KAN_N      KAN after NORMT: ⊕ operands swapped when KAN(b) < KAN(a) byte-wise (STR_LT); nothing else commutes
  clash      for each combo, the first LATER combo with the same κ → "c/c2" (OM_CLASH); fixture rows +36, +63
  overloads  per κ (in κ-list order), the names of rows with that κ in row order, each + "/"; reported when > 1 name
The §16 header (09-17) says its numbers were "re-derived by an independent python census" — that census was never saved,
so freezeck counted the lines exact:captured. This is it, on disk.
The gate pins line 3 from "entry overloads" to the last name's "/": the module prefixes "ONTOMORPH REPORT " and OM_JOIN
puts a space after each entry, neither of which the want covers."""
import os, re, sys
ROOT = os.environ.get('LA_ROOT') or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NINE = ["BEING", "RECOGNITION", "LOVE", "SELF", "RELATION", "VOID", "BECOMING", "FORM", "DEPTH"]
def table(path, name):                                 # same reader as overloads.py / s23_syllabus.py, inlined
    s = open(os.path.join(ROOT, path), encoding='utf-8').read()
    i = s.index('glyph %s =' % name); j = s.index('\nglyph ', i + 1)
    blk = '\n'.join(l if l.lstrip().startswith('"') else l.split('#', 1)[0] for l in s[i:j].split('\n'))
    return [r.split('|') for r in ''.join(re.findall(r'"((?:[^"\\]|\\.)*)"', blk)).split(';') if r]

def dec(code):
    pos = [0]
    def go():
        c = code[pos[0]]; pos[0] += 1
        if c.isdigit(): return ('P', NINE[int(c) - 1])
        if c == 'm': return ('m', go())
        if c not in '*+>c': raise ValueError('malformed derivation %r' % code)
        a = go(); b = go(); return (c, a, b)
    t = go(); assert pos[0] == len(code), code
    return t
def kan(t): return t[1] if t[0] == 'P' else '%s(%s)' % (t[0], ','.join(kan(x) for x in t[1:]))
def skel(t): return '·' if t[0] == 'P' else '%s(%s)' % (t[0], ','.join(skel(x) for x in t[1:]))
def normt(t):
    if t[0] == 'P': return t
    if t[0] == 'm': return ('m', normt(t[1]))
    a, b = normt(t[1]), normt(t[2])
    if t[0] == '+' and kan(b).encode() < kan(a).encode(): a, b = b, a
    return (t[0], a, b)
def kan_n(code): return kan(normt(dec(code)))

def rows_of(tab): return [(r[0], r[1]) for r in reversed(tab)]
def distinct_rev(keys):                                # OM_DISTINCT: cons onto acc when unseen → reverse first-appearance
    acc = []
    for k in keys:
        if k not in acc: acc.insert(0, k)
    return acc
def clash(combos):
    for i, c in enumerate(combos):
        for c2 in combos[i + 1:]:
            if kan_n(c2) == kan_n(c): return '%s/%s' % (c, c2)
    return ''
def T(b): return 'T' if b else 'F'

rows = (rows_of(table('lexicon.la', 'LEX')) + rows_of(table('lexicon.la', 'RULED'))
        + rows_of(table('opgrammar.la', 'GRAM')) + rows_of(table('opgrammar.la', 'GRULED')))

census = {}                                            # dicts keep insertion order = OM_BUMP's first appearance
for _, dv in rows: k = skel(dec(dv)); census[k] = census.get(k, 0) + 1
render = ''.join('%s=%d ' % kv for kv in census.items())
ops = ' '.join('%s=%d' % (ch.replace('*', '*'), sum(dv.count(ch) for _, dv in rows)) for ch in '*>+cm')
line1 = ('ONTOMORPH corpus rows=%d (LEX+RULED+GRAM+GRULED) | skeletons=%d: %s | operator uses %s'
         % (len(rows), len(census), render, ops))

combos = distinct_rev([dv for _, dv in rows])
kappas = distinct_rev([kan_n(dv) for _, dv in rows])
cl = clash(combos)
fix = clash(distinct_rev([dv for _, dv in rows_of([['Grief', '+36', 'x'], ['Ghost', '+63', 'y']])]))
line2 = ('ONTOMORPH combinations=%d κ-images=%d | injective (distinct combinations → distinct κ):%s%s | fixture +36/+63 refused:%s OFFENDER=%s'
         % (len(combos), len(kappas), T(cl == ''), '' if cl == '' else ' OFFENDER=' + cl, T(fix != ''), fix))

tagged = [(nm, kan_n(dv)) for nm, dv in rows]
ov = []
for k in kappas:
    names = ''.join(nm + '/' for nm, kk in tagged if kk == k)
    if names.count('/') > 1: ov.append('%s:%s' % (k, names))
line3 = "entry overloads (one κ, two names; the architect's to rule)=%d: %s" % (len(ov), ' '.join(ov))

if __name__ == '__main__':
    for l in (line1, line2, line3): print('WANT om %s' % l)
