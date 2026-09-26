# -*- coding: utf-8 -*-
"""§32 selfevo derivation (2026-09-26, F20). Recomputes the captured seed/Ops witness WITHOUT the LA code:
  seed    L_0 = the nine primitives; ρ = 0 (a primitive has recursion order 0 — recdepth's definition); rules R_0 = ∅;
          D = 1000·σ/|G| with σ = Σ|I(g)|, |I(g)| = the DISTINCT κ-sub-forms of g (selfevo.la:29-31) — a primitive's is
          itself, so σ = |G| = 9 and D = 1000, computed here, not asserted
  Ops     the eighteen named operators. Their forms are read from their ORIGINS, not from recdepth.la's copies (a copy
          that drifted from its origin would then disagree): the five modes and ∂ δ γ ρ 𝔄 parsed out of metaglyph.la;
          κ, 𝓡, SR_ABOUT out of canon_spec.la / canon.la; the genesis operators Δ_E (lineage.la G_ETYM), Δ_M = ν* =
          ⊗(⊗'s form, ↻'s form) (metaglyph.la NU_STAR: COLLAPSE(SYN) of MODE_SYN and MODE_MC), Δ_R, Δ_B, ρ(L_t) from the
          module that owns each (regenesis.la, branchgenesis.la, recdepth.la G_RHO)
  κ-distinct  distinct NORMK over the eighteen: ρ and SR_ABOUT are both ↻(RECOGNITION), so 17 (checked, then printed)"""
import os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lacore import P, SYN, CON, DIR, CONT, MC, normk
ROOT = os.environ.get('LA_ROOT') or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CTOR = {"SYN": SYN, "CON": CON, "DIR": DIR, "CONT": CONT}

def parse(expr):
    """PRIM("X") | Px("X") | P("X") | MC(e) | SYN(e)(e) … — the constructor calls the modules write, nothing else"""
    s = expr.strip(); pos = [0]
    def arg():
        assert s[pos[0]] == "(", (s, pos[0]); pos[0] += 1; v = term(); assert s[pos[0]] == ")"; pos[0] += 1; return v
    def term():
        m = re.compile(r'\s*(PRIM|Px|P)\("([A-Z]+)"\)').match(s, pos[0])
        if m: pos[0] = m.end(); return P(m.group(2))
        m = re.compile(r'\s*(CONT|CON|SYN|DIR|MC)').match(s, pos[0]); assert m, s[pos[0]:]
        pos[0] = m.end()
        if m.group(1) == "MC": return MC(arg())
        a = arg(); b = arg(); return CTOR[m.group(1)](a, b)
    t = term(); return t
def glyph(path, name):
    src = open(os.path.join(ROOT, path), encoding='utf-8').read()
    m = re.search(r'^glyph %s\s*=\s*(.*)$' % re.escape(name), src, re.M); assert m, (path, name)
    return m.group(1).split('#', 1)[0].strip()
def form(path, name):
    body = glyph(path, name)
    m = re.fullmatch(r'SEALc\((.*)\)', body)
    return parse(m.group(1) if m else body)

MG = "metaglyph.la"
modes = {k: form(MG, k) for k in ("MODE_SYN", "MODE_CON", "MODE_DIR", "MODE_CONT", "MODE_MC")}
ops5 = {k: form(MG, k) for k in ("OP_DIFF", "OP_BOUND", "OP_COMP", "OP_RECOG", "OP_INTEG")}
assert re.fullmatch(r'COLLAPSE\(SYN\)\(GLYPHOF\(MODE_SYN\)\)\(GLYPHOF\(MODE_MC\)\)', glyph(MG, "NU_STAR")), glyph(MG, "NU_STAR")
OPS = [modes["MODE_SYN"], modes["MODE_CON"], modes["MODE_DIR"], modes["MODE_CONT"], modes["MODE_MC"],
       ops5["OP_DIFF"], ops5["OP_BOUND"], ops5["OP_COMP"], ops5["OP_RECOG"], form("canon.la", "SR_ABOUT"), ops5["OP_INTEG"],
       form("canon_spec.la", "KAPPA"), form("canon_spec.la", "REVAL"), form("lineage.la", "G_ETYM"),
       SYN(modes["MODE_SYN"], modes["MODE_MC"]),
       form("regenesis.la", "G_DR"), form("branchgenesis.la", "G_DB"), form("recdepth.la", "G_RHO")]
kd = len({normk(o) for o in OPS})
assert normk(ops5["OP_RECOG"]) == normk(form("canon.la", "SR_ABOUT")), "ρ and SR_ABOUT are no longer one κ-form"
seed = [P(n) for n in ("BEING", "RECOGNITION", "LOVE", "SELF", "RELATION", "VOID", "BECOMING", "FORM", "DEPTH")]
def inv(t, acc):
    acc.add(normk(t))
    for c in t[1:]:
        if isinstance(c, tuple): inv(c, acc)
    return acc
sigma = sum(len(inv(g, set())) for g in seed)
print("WANT se SELFEVO seed |L_0|=%d ρ=0 D=%d rules=0 | Ops named=%d κ-distinct=%d (ρ and SR_ABOUT are one κ-form: κ-keyed; a name-keyed census would read %d)" % (
    len(seed), 1000 * sigma // len(seed), len(OPS), kd, len(OPS)))
