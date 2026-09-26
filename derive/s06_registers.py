# -*- coding: utf-8 -*-
"""§6 registers derivation (2026-09-26, F20). Recomputes registers.la's two captured witnesses WITHOUT the LA code:
  stack      the twelve registers IN ORDER, read from REGISTERS.md §1's table (rows 1–12, "Register" column, lowercased)
             — the documentation, not registers.la's STACK, so a module that reordered, dropped or renamed a register
             disagrees with the paper that describes it.
  evidential the register's reading of κ = ▷(RECOGNITION,FORM): the tag of the FIRST evidential.la catalogue entry whose
             glyph is κ (the catalogue is a policy table — data, like the lexicon tables s16/s23 read). ★ The derivation
             adds what the pin alone cannot: a W tag CLAIMS a build.sh gate asserts it (evidential.la header), so W is
             printed only if the entry's cite is a substring of a build.sh `say "…"` line; otherwise "W-UNCITED", which
             mismatches the pin and turns check.py red.
RED PATHS (LA_ROOT copies, 2026-09-26): REGISTERS.md rows 9/10 swapped → the stack line reads evidential before
prosodic (MISMATCH); the cited say-line altered in build.sh → "evidential: W-UNCITED" (MISMATCH)."""
import os, re, sys
ROOT = os.environ.get('LA_ROOT') or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rd = lambda f: open(os.path.join(ROOT, f), encoding='utf-8').read()

md = rd('REGISTERS.md')
sec1 = md[md.index('## §1'):md.index('## §2')]
rows = {int(m.group(1)): m.group(2).strip() for m in re.finditer(r'^\| (\d+) \| ([^|]+)\|', sec1, re.M)}
assert sorted(rows) == list(range(1, 13)), sorted(rows)
names = [rows[i].lower() for i in range(1, 13)]
print('WANT reg REGISTERS stack=%d [%s]' % (len(names), ' '.join(names)))

ev = rd('evidential.la')
cat = ev[ev.index('glyph EV_CAT ='):ev.index('glyph EVID_IN')]
ents = re.findall(r'EVG\("([^"]*)"\)\("([^"]*)"\)\((.+?)\)\)\($', cat, re.M)
assert ents, 'no catalogue entries parsed'
kappa = [e for e in ents if e[2].strip() == 'SEALc(KAPPA)']
assert kappa, 'κ has no catalogue entry'
first = ents.index(kappa[0])
# κ must be the FIRST entry with its form: every earlier entry is checked to be a different glyph (none precede it today)
assert first == 0 or all(e[2] != 'SEALc(KAPPA)' for e in ents[:first])
tag, cite = kappa[0][0], kappa[0][1]
says = re.findall(r'^say "(.*)"', rd('build.sh'), re.M)
if tag == 'W' and not any(cite in s for s in says): tag = 'W-UNCITED'
print('WANT reg   evidential: %s' % tag)
print('NOTE §6 evidential: κ tagged %s citing "%s" — found in %d build.sh say-line(s)' % (kappa[0][0], cite, sum(cite in s for s in says)))
