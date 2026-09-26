# -*- coding: utf-8 -*-
"""§4 evidential derivation (2026-09-26, F20). Recomputes the captured self-reading witness WITHOUT the LA code:
  G_EV       the register's own glyph ▷(RECOGNITION,↻(RECOGNITION)) (evidential.la header: DECLARED [A])
  EVID(g)    the tag of the FIRST catalogue entry whose NORMK equals NORMK(g) — found BY MONOSEMIC IDENTITY, never by name
             (evidential.la header). Every EV_CAT entry's glyph is resolved FROM SOURCE TEXT (the named glyphs SR_*,
             modes, operators, COLLAPSE(SYN)(…)) with derive/s31_recdepth.py's resolver, reused, so "first" is checked
             against every earlier entry, not assumed.
  truth/glyph Δ_Ev(Δ_Ev) is ↻(↻G) against ↻G: truth = NORMK equal (↻↻≡↻ at the identity level), glyph = plain κ equal.
  ★ The truth:T glyph:F half is the F4 construction (↻↻ ≡ ↻, true of every glyph but BEING) — derived here, and still
  declared construction in the gate; the self-reading "B" is the part a derivation adds.
Red path run on this script: an entry EARLIER than G_EV's with the same κ and another tag → the reading changes."""
import os, re, sys, io, runpy, contextlib
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
from lacore import P, DIR, MC, canon, normk
ROOT = os.environ.get('LA_ROOT') or os.path.dirname(HERE)

with contextlib.redirect_stdout(io.StringIO()):
    g = runpy.run_path(os.path.join(HERE, 's31_recdepth.py'), run_name='s31_as_library')
table, parse = g['table'], g['parse']
cwd = os.getcwd(); os.chdir(ROOT)
try:
    T = table(['evidential.la', 'canon.la', 'metaglyph.la', 'recdepth.la', 'lineage.la'])
finally: os.chdir(cwd)
ev = open(os.path.join(ROOT, 'evidential.la'), encoding='utf-8').read()
cat = ev[ev.index('glyph EV_CAT ='):ev.index('glyph EVID_IN')]
ents = []
for m in re.finditer(r'EVG\("([^"]*)"\)\("((?:[^"\\]|\\.)*)"\)\(', cat):
    i = m.end(); d = 1; j = i
    while d: d += {'(': 1, ')': -1}.get(cat[j], 0); j += 1
    ents.append((m.group(1), parse(cat[i:j - 1], T)))
assert len(ents) >= 20, len(ents)
G_EV = parse(T['G_EV'], T)
assert canon(G_EV) == canon(DIR(P("RECOGNITION"), MC(P("RECOGNITION")))), canon(G_EV)
tag = next((t for t, f in ents if normk(f) == normk(G_EV)), "")
mcg = MC(G_EV)
print("WANT evd reads itself as:%s | Δ_Ev(Δ_Ev)≡Δ_Ev truth:%s glyph:%s" % (
    tag or "⊥", "T" if normk(MC(mcg)) == normk(mcg) else "F", "T" if canon(MC(mcg)) == canon(mcg) else "F"))
print("NOTE §4 evidential: %d catalogue entries resolved from source; G_EV matched at entry %d" % (
    len(ents), 1 + next(k for k, (t, f) in enumerate(ents) if normk(f) == normk(G_EV))))
