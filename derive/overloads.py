# -*- coding: utf-8 -*-
"""F28(d) derivation (2026-09-18): the LIVE entry-overload census of the published tables, and whether adequacy.la's
eight rulings are already APPLIED in them. Reads lexicon.la's LEX + RULED and opgrammar.la's GRAM + GRULED (the corpus
ontomorph.la reads), decodes each row's digit code (1..9 = the nine in NINE order; * ⊗ · + ⊕ · > ▷ · c ⊂ · m ↻, prefix),
and counts κ-forms carrying two or more names. rc 0 always (a report); every row it cannot decode is an ERROR (rc 2)."""
import os, re, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NINE = ["BEING", "RECOGNITION", "LOVE", "SELF", "RELATION", "VOID", "BECOMING", "FORM", "DEPTH"]
SYM = {'*': '⊗', '+': '⊕', '>': '▷', 'c': '⊂', 'm': '↻'}
def table(path, name):
    s = open(os.path.join(ROOT, path), encoding='utf-8').read()
    i = s.index('glyph %s =' % name); j = s.index('\nglyph ', i + 1)
    blk = '\n'.join(l if l.lstrip().startswith('"') else l.split('#', 1)[0] for l in s[i:j].split('\n'))   # drop comments (they quote text too)
    lits = ''.join(re.findall(r'"((?:[^"\\]|\\.)*)"', blk))
    return [r.split('|') for r in lits.split(';') if r]
def dec(code):
    pos = [0]
    def go():
        c = code[pos[0]]; pos[0] += 1
        if c.isdigit(): return NINE[int(c) - 1]
        if c == 'm': return '↻(%s)' % go()
        a = go(); b = go(); return '%s(%s,%s)' % (SYM[c], a, b)
    try:
        t = go()
    except (IndexError, KeyError):
        print("ERROR: cannot decode %r" % code); sys.exit(2)
    if pos[0] != len(code): print("ERROR: trailing code in %r" % code); sys.exit(2)
    return t
rows = [(n, r[0], dec(r[1])) for p, n in (('lexicon.la', 'LEX'), ('lexicon.la', 'RULED'), ('opgrammar.la', 'GRAM'), ('opgrammar.la', 'GRULED')) for r in table(p, n)]
by = {}
for _, nm, k in rows: by.setdefault(k, []).append(nm)
over = {k: v for k, v in by.items() if len(set(v)) > 1}
print("OVERLOADS corpus rows=%d | live entry overloads (one κ, two names)=%d: %s" % (len(rows), len(over), " ".join("%s:%s" % (k, "/".join(v)) for k, v in over.items())))
kappa = {nm: k for _, nm, k in rows}
RULINGS = [("⊗(BEING,DEPTH)", "Totality", "All", "DECLARE", ""), ("⊗(FORM,BEING)", "Substance", "Large", "REDERIVE", "⊗(DEPTH,FORM)"),
           ("⊗(FORM,LOVE)", "Beauty", "Good", "REDERIVE", "⊗(BEING,LOVE)"), ("⊗(LOVE,RELATION)", "Friendship", "Bond", "REDERIVE", "⊂(RELATION,BEING)"),
           ("⊗(VOID,DEPTH)", "Mystery", "Sky", "REDERIVE", "⊂(VOID,FORM)"), ("▷(FORM,BEING)", "This", "Here", "REDERIVE", "▷(FORM,RELATION)"),
           ("▷(FORM,VOID)", "That", "There", "REDERIVE", "⊂(VOID,RELATION)"), ("▷(SELF,BECOMING)", "Agency", "Move", "REDERIVE", "▷(BECOMING,FORM)")]   # adequacy.la AD_RULINGS, transcribed
applied = [r for r in RULINGS if r[3] == "REDERIVE" and kappa.get(r[2]) == r[4] and kappa.get(r[1]) == r[0]]
declared = {r[0] for r in RULINGS if r[3] == "DECLARE"}
print("OVERLOADS re-derivations APPLIED in source (moved name carries its new form, kept name its original): %d/%d"
      % (len(applied), sum(1 for r in RULINGS if r[3] == "REDERIVE")))
print("OVERLOADS every live overload is a DECLARED one-concept synonym:%s" % ("T" if set(over) <= declared else "F"))
