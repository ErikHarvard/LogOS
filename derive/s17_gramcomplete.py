# -*- coding: utf-8 -*-
"""§17 gramcomplete derivation (2026-09-26, F20). Recomputes gramcomplete.la's first two pinned lines WITHOUT the LA code.
  line 1   the corpus is the four published tables (lexicon.la LEX + RULED, opgrammar.la GRAM + GRULED); a row is DERIVED
           when its code parses as a complete prefix derivation over the nine and ⊗ ⊕ ▷ ⊂ ↻ (a real recursive parse here,
           not the module's demand counter). R1 = leaves, R2 = binary nodes, R3 = ↻ nodes, summed over all rows — counted
           from the parsed trees, not from characters.
  line 2   the four traces (Water, Question, Ongoing, Bad), each CODE looked up BY NAME in the published tables — the module
           writes the four codes into LINE2 literally, so its gate cannot notice a table re-derivation; this one can, and
           says so with a NOTE when the module's literal and the table disagree. Trace = R1(digit) · R2(op,a,b) · R3(a).
Line 3 (the R4 seal) is not derived: its "sealed self-naming:T" is AUTO_OK of a seal — construction-true (F32) — and an
outside derivation could only restate it."""
import os, re, sys
ROOT = os.environ.get('LA_ROOT') or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def table(path, name):                                 # same reader as overloads.py / s23_syllabus.py, inlined
    s = open(os.path.join(ROOT, path), encoding='utf-8').read()
    i = s.index('glyph %s =' % name); j = s.index('\nglyph ', i + 1)
    blk = '\n'.join(l if l.lstrip().startswith('"') else l.split('#', 1)[0] for l in s[i:j].split('\n'))
    return [r.split('|') for r in ''.join(re.findall(r'"((?:[^"\\]|\\.)*)"', blk)).split(';') if r]

def parse(code):
    """complete prefix parse → tree, or None when the code is not a derivation"""
    pos = [0]
    def go():
        if pos[0] >= len(code): raise ValueError
        c = code[pos[0]]; pos[0] += 1
        if c in '123456789': return ('R1', c)
        if c == 'm': return ('R3', go())
        if c in '*+>c': return ('R2', c, go(), go())
        raise ValueError
    try:
        t = go()
        return t if pos[0] == len(code) else None
    except ValueError: return None
def count(t, k): return (t[0] == k) + sum(count(x, k) for x in t[1:] if isinstance(x, tuple))
def trace(t):
    if t is None: return 'UNREACHABLE'
    if t[0] == 'R1': return 'R1(%s)' % t[1]
    if t[0] == 'R3': return 'R3(%s)' % trace(t[1])
    return 'R2(%s,%s,%s)' % (t[1], trace(t[2]), trace(t[3]))

tabs = [('lexicon.la', 'LEX'), ('lexicon.la', 'RULED'), ('opgrammar.la', 'GRAM'), ('opgrammar.la', 'GRULED')]
rows = [(r[0], r[1]) for p, n in tabs for r in table(p, n)]
trees = [parse(dv) for _, dv in rows]
ok = [t for t in trees if t is not None]
bad = [nm for (nm, _), t in zip(rows, trees) if t is None]
line1 = ('GRAMCOMPLETE corpus=%d derived by R1-R3=%d/%d:%s%s | rules used R1=%d R2=%d R3=%d'
         % (len(rows), len(ok), len(rows), 'T' if len(ok) == len(rows) else 'F', (' OFFENDER=' + bad[0]) if bad else '',
            sum(count(t, 'R1') for t in ok), sum(count(t, 'R2') for t in ok), sum(count(t, 'R3') for t in ok)))

code_of = {}
for nm, dv in rows: code_of.setdefault(nm, dv)
TRACED = [('Water', 'Water'), ('Question', 'Question'), ('Ongoing', 'Ongoing'), ('Bad', 'Bad(ruled)')]
line2 = 'traces: ' + ' | '.join('%s %s' % (label, trace(parse(code_of[nm]))) for nm, label in TRACED)

if __name__ == '__main__':
    mod = open(os.path.join(ROOT, 'gramcomplete.la'), encoding='utf-8').read()
    lits = dict(re.findall(r'concat\("[^"]*?(\w+)(?:\(ruled\))? "\)\((?:concat\()?GC_DERIVE\("([^"]+)"\)', mod))
    for nm, _ in TRACED:
        if nm not in lits: print('NOTE gramcomplete.la LINE2 has no literal for %s — the module changed shape' % nm)
        elif lits[nm] != code_of[nm]: print('NOTE gramcomplete.la LINE2 traces %s as %r but the table now says %r' % (nm, lits[nm], code_of[nm]))
    print('WANT gc %s' % line1)
    print('WANT gc %s' % line2)
