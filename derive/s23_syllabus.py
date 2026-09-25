# -*- coding: utf-8 -*-
"""§23 syllabus derivation (2026-09-25). Recomputes syllabus.la's two pinned witnesses WITHOUT the LA code: reads the
four published tables (lexicon.la LEX + RULED, opgrammar.la GRAM + GRULED) straight from source, decodes each row's digit
code, and rebuilds the teaching order the way the module DEFINES it (not the way it is written):
  rows      each table folded left with cons (so each table REVERSED), tables concatenated LEX, RULED, GRAM, GRULED
  key       100·depth + leaves; a STABLE sort (equal keys keep row order) — SY_INSERT places x before the first h
            with key(h) ≥ key(x), applied from the tail, so the earlier row wins a tie
  subs(t)   every proper sub-derivation's κ, with multiplicity: binary → κa, κb, subs a, subs b; ↻ → κa, subs a
  violation an entry h whose sub-derivation k IS an entry (by κ) not yet seen, counted along an order
Found stale on 2026-09-25: the pinned `reversed order violations=72` dates from cc906b3 (09-15); ec12042 (09-17) re-derived
five forms and §23 was not re-run. This derivation is what re-pins it."""
import os, re, sys
ROOT = os.environ.get('LA_ROOT') or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))   # LA_ROOT: derive an older tree
NINE = ["BEING", "RECOGNITION", "LOVE", "SELF", "RELATION", "VOID", "BECOMING", "FORM", "DEPTH"]
def table(path, name):                                 # same reader as overloads.py, inlined (that module prints on import)
    s = open(os.path.join(ROOT, path), encoding='utf-8').read()
    i = s.index('glyph %s =' % name); j = s.index('\nglyph ', i + 1)
    blk = '\n'.join(l if l.lstrip().startswith('"') else l.split('#', 1)[0] for l in s[i:j].split('\n'))
    return [r.split('|') for r in ''.join(re.findall(r'"((?:[^"\\]|\\.)*)"', blk)).split(';') if r]

SYM = {'*': 'SYN', '+': 'CON', '>': 'DIR', 'c': 'CONT', 'm': 'MC'}
def dec(code):
    pos = [0]
    def go():
        c = code[pos[0]]; pos[0] += 1
        if c.isdigit(): return ('P', NINE[int(c) - 1])
        if c == 'm': return ('MC', go())
        a = go(); b = go(); return (SYM[c], a, b)
    t = go(); assert pos[0] == len(code), code
    return t
def kan(t): return t[1] if t[0] == 'P' else '%s(%s)' % (t[0], ','.join(kan(x) for x in t[1:]))
def depth(t): return 0 if t[0] == 'P' else 1 + max(depth(x) for x in t[1:])
def leaves(t): return 1 if t[0] == 'P' else sum(leaves(x) for x in t[1:])
def subs(t):
    if t[0] == 'P': return []
    out = [kan(x) for x in t[1:]]
    for x in t[1:]: out += subs(x)
    return out

rows = []
for p, n in (('lexicon.la', 'LEX'), ('lexicon.la', 'RULED'), ('opgrammar.la', 'GRAM'), ('opgrammar.la', 'GRULED')):
    rows += list(reversed([(r[0], dec(r[1])) for r in table(p, n)]))
key = lambda r: 100 * depth(r[1]) + leaves(r[1])
order = sorted(rows, key=key)                            # Python's sort is stable: ties keep row order
entries = set(kan(t) for _, t in rows)
def viol(seq):
    seen, n = set(), 0
    for _, t in seq:
        n += sum(1 for k in subs(t) if k in entries and k not in seen)
        seen.add(kan(t))
    return n
bd = lambda d: sum(1 for _, t in order if depth(t) == d)
mono = all(depth(a[1]) <= depth(b[1]) for a, b in zip(order, order[1:]))
print('WANT sy SYLLABUS lessons=%d by depth d0=%d d1=%d d2=%d d3=%d | depth non-decreasing:%s | constituent-first violations=%d (0 required):%s | reversed order violations=%d (red path, must be >0)'
      % (len(order), bd(0), bd(1), bd(2), bd(3), 'T' if mono else 'F', viol(order), 'T' if viol(order) == 0 else 'F', viol(list(reversed(order)))))
print('WANT sy SYLLABUS first lessons: ' + ' '.join(n for n, _ in order[:12]))
