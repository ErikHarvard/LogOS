# -*- coding: utf-8 -*-
"""§37 substitution derivation (2026-09-26, F20). Recomputes the captured structural-search witness WITHOUT the LA code:
  probes   the live catalogue (recdepth.la RD_CAT, 35 entries — resolved from source text by derive/s31_recdepth.py, reused
           here, not re-implemented) plus the module's four constructed near-synonyms FX_BOND ⊕(BEING,LOVE), FX_BOND2
           ⊕(LOVE,BEING), FX_MCX ↻(RECOGNITION), FX_MCXX ↻(↻(RECOGNITION)) (substitution.la's fixtures, transcribed)
  μ(g)     NORMK (lacore.normk — the independent model)
  I(g)     the set of distinct NORMK strings over EVERY subterm, leaves included (substitution.la INV = UNIQ(ALLSTR))
  scan     every unordered pair of probes (i<j); count pairs with μ equal, and of those, pairs whose I sets differ
           (clause (ii) firing alone). The claim "(ii) never fires independently" is printed from the count, not asserted.
Red path run on this script: I(g) reduced to the root alone would still agree (I ⊆ μ-class trivially), so the one that
bites is μ taken as plain κ — the ⊕-commuted and ↻↻ pairs stop being μ-equal and the count falls."""
import os, sys, io, runpy, contextlib
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
from lacore import P, CON, MC, normk

with contextlib.redirect_stdout(io.StringIO()):
    g = runpy.run_path(os.path.join(HERE, 's31_recdepth.py'), run_name='s31_as_library')
cat = [t for _, t in g['cat']]
assert len(cat) == 35, len(cat)
FX = [CON(P("BEING"), P("LOVE")), CON(P("LOVE"), P("BEING")), MC(P("RECOGNITION")), MC(MC(P("RECOGNITION")))]
probes = FX + cat
def inv(t, acc):
    acc.add(normk(t))
    for c in t[1:]:
        if isinstance(c, tuple): inv(c, acc)
    return acc
recs = [(normk(t), frozenset(inv(t, set()))) for t in probes]
eq = incong = 0
for i in range(len(recs)):
    for j in range(i + 1, len(recs)):
        if recs[i][0] == recs[j][0]:
            eq += 1; incong += recs[i][1] != recs[j][1]
print("WANT sb structural search over %d probes: pairs with μ EQUAL=%d of those with invariants INCONGRUENT (clause ii alone)=%d | clause (ii) never fires independently of (i):%s" % (
    len(probes), eq, incong, "T" if incong == 0 else "F"))
