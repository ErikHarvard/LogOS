# -*- coding: utf-8 -*-
"""§40 phonometa derivation (2026-09-26, F20). The "pinned witness" line was declared `exact:cross-checked against
build.sh psc pin` — two pins agreeing with each other, neither derived. Here it is derived from the RENDERER, phonym.la:
  formants   each vowel's F1,F2,F3 = the first three arguments of the LAST VSAMP/VDYN call in its PH_<NAME> body (the
             sustained vowel after the onset): Love /u/, Recognition /i/, Depth /ɔ/ — not psc.la's LOVE_F/REC_F/DEPTH_F
  Θ_P        a peak list deduplicated, first occurrence kept (psc: THETA_P = LDEDUP) ; SYN_INV(a,b) = Θ_P(a ++ b)
  L / R / d  PRESERVES = set containment: "L" iff Love ⊆ SYN_INV(Love,Rec), "R" likewise, "d" iff Depth is NOT contained
  union      rendered "n," per peak ; dur = max(n_Love, n_Rec) from phonym.la PHON_PRIM (⊗ compresses to the longer
             parent, spec 4233) ; "i" iff Θ_P(Θ_P(x)) = Θ_P(x) on Love++Rec
  matches    the derived string equals build.sh's PSC_EXPECT — the cross-check the old declaration named, now against a
             derivation rather than against a second copy
Red path run on this script: a phonym copy with Recognition's vowel F2 moved (2300→2310) changes the union (LA_ROOT)."""
import os, re
ROOT = os.environ.get('LA_ROOT') or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ph = open(os.path.join(ROOT, 'phonym.la'), encoding='utf-8').read()
def formants(g):
    i = ph.index('glyph %s =' % g); j = ph.index('\nglyph ', i + 1)
    calls = re.findall(r'(?:VSAMP|VDYN)\((\d+)\)\((\d+)\)\((\d+)\)', ph[i:j])
    return [int(x) for x in calls[-1]]
body = ph[ph.index('glyph PHON_PRIM ='):]
n = {m.group(1): int(m.group(2)) for m in re.finditer(r'str_eq\(nm\)\("([A-Z]+)"\)\)\s*\(la _\. PAIR\((\d+)\)', body)}
def dedup(l):
    out = []
    for x in l:
        if x not in out: out.append(x)
    return out
L, R, D = formants('PH_LOVE'), formants('PH_RECOGNITION'), formants('PH_DEPTH')
u = dedup(L + R)
w = "%s%s%s|%s|dur=%d|%s" % ("L" if set(L) <= set(u) else "x", "R" if set(R) <= set(u) else "x",
                             "x" if set(D) <= set(u) else "d", "".join("%d," % x for x in u),
                             max(n["LOVE"], n["RECOGNITION"]), "i" if dedup(dedup(L + R)) == dedup(L + R) else "x")
exp = re.search(r'^PSC_EXPECT="([^"]*)"', open(os.path.join(ROOT, 'build.sh'), encoding='utf-8').read(), re.M).group(1)
print("WANT pm pinned witness: %s matches:%s" % (w, "T" if w == exp else "F"))
