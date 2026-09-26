# -*- coding: utf-8 -*-
"""§15 ontoargument derivation (2026-09-26, F20). The captured GLYPHS line, derived from what the module SAYS it is:
ontoargument.la's header — "GLYPHS [A] from the lexicon … The four above are USES of published lexicon entries, not
declarations". So each glyph is looked up BY NAME in the published tables (lexicon.la LEX + RULED, opgrammar.la GRAM +
GRULED — the same reader as s16/s23) and decoded; ¬ is opgrammar.la's RULED R_NEG, ⊂(X,VOID) (Erik 2026-08-23).
  □ Must · ◇ Can · ∀ All · ∃ Some            (digit n = the n-th primitive; * = ⊗, first operand first)
★ FINDING F46 (2026-09-26), which this derivation exists to surface: Can was RULED ⊗(BECOMING,FORM) → ⊗(FORM,BECOMING)
(opgrammar.la GRULED, a9e27e8 2026-08-27 — the old form is CHANGE's). ontoargument.la's ◇ still carries the pre-ruling
⊗(BECOMING,FORM), i.e. the glyph for Change. So this line MISMATCHES the gate's pin until the module follows the ruling
(or the ruling is reversed) — a red here is the defect made visible, not a derivation error."""
import os, re, sys
ROOT = os.environ.get('LA_ROOT') or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NINE = ["BEING", "RECOGNITION", "LOVE", "SELF", "RELATION", "VOID", "BECOMING", "FORM", "DEPTH"]
def table(path, name):
    s = open(os.path.join(ROOT, path), encoding='utf-8').read()
    i = s.index('glyph %s =' % name); j = s.index('\nglyph ', i + 1)
    blk = '\n'.join(l if l.lstrip().startswith('"') else l.split('#', 1)[0] for l in s[i:j].split('\n'))
    return [r.split('|') for r in ''.join(re.findall(r'"((?:[^"\\]|\\.)*)"', blk)).split(';') if r]
SYM = {'*': '⊗', '+': '⊕', '>': '▷', 'c': '⊂'}
def dec(code):
    pos = [0]
    def go():
        c = code[pos[0]]; pos[0] += 1
        if c.isdigit(): return NINE[int(c) - 1]
        if c == 'm': return '↻(%s)' % go()
        a = go(); b = go(); return '%s(%s,%s)' % (SYM[c], a, b)
    t = go(); assert pos[0] == len(code), code
    return t
rows = {}
for f, t in (('lexicon.la', 'LEX'), ('lexicon.la', 'RULED'), ('opgrammar.la', 'GRAM'), ('opgrammar.la', 'GRULED')):
    for r in table(f, t): rows.setdefault(r[0], r[1])
g = {k: dec(rows[k]) for k in ('Must', 'Can', 'All', 'Some')}
print("WANT oa OA GLYPHS □=%s ◇=%s ¬=⊂(·,VOID) ∀=%s ∃=%s" % (g['Must'], g['Can'], g['All'], g['Some']))
print("NOTE §15: ◇ from the published table is Can=%s (Change=%s) — ontoargument.la OA_DIA must be compared against it (F46)" % (
    g['Can'], dec(rows['Change'])))
