# -*- coding: utf-8 -*-
"""lacore — an INDEPENDENT python model of the LA notions the F20 derivations need (FREEZE-TRACKF.md F20).
Written from the DOCUMENTED definitions — CLAUDE.md (κ/CANON/NORMK, the glyph-DAG format), canon_spec.la's rule
comments, REGISTERS.md (the registers' readings) — never by running or reading the module under test. A derivation
that imports a module's own code is not independent; this file imports nothing from the repo.
"""
NINE = ("BEING", "RECOGNITION", "LOVE", "SELF", "RELATION", "VOID", "BECOMING", "FORM", "DEPTH")
SYM = {"SYN": "⊗", "CON": "⊕", "DIR": "▷", "CONT": "⊂", "MC": "↻"}
def P(n): return ("P", n)
def SYN(a, b): return ("SYN", a, b)
def CON(a, b): return ("CON", a, b)
def DIR(a, b): return ("DIR", a, b)
def CONT(a, b): return ("CONT", a, b)
def MC(a): return ("MC", a)
KAPPA = DIR(P("RECOGNITION"), P("FORM"))        # CLAUDE.md: κ is RECOGNITION ▷ FORM
REVAL = DIR(P("DEPTH"), P("RECOGNITION"))       # CLAUDE.md: 𝓡 = ▷(DEPTH,RECOGNITION)

def canon(t):
    """plain κ: order-preserving prefix notation (CLAUDE.md 'v1 is order-preserving')"""
    if t[0] == "P": return t[1]
    if t[0] == "MC": return "↻(" + canon(t[1]) + ")"
    return "%s(%s,%s)" % (SYM[t[0]], canon(t[1]), canon(t[2]))

def normk(t, rewrite_being=True):
    """NORMK per canon_spec.la's rule comments: ⊕ operands sorted bytewise (co-presence is symmetric); ⊗ is NOT sorted —
    ontosynthesis is NON-commutative (LA.tex:2837, ruling E1, the white paper's 09-18 text: ⊗ keeps its operands' order).
    ★ CLAUDE.md still says "⊗/⊕ are symmetric, so their operands are sorted" — STALE; this model first copied it and
    was caught at §48, where ⊗(a,b) and ⊗(b,a) must stay distinct. ⊗-idempotence for ∃ ALONE;
    ↻: ↻(BEING)→SELF (the declared rewrite; rewrite_being=False models Erik's F4 ruling (c)), ↻(↻Y)→↻Y by shape,
    𝓡 and ⊕(SELF,SELF) fixed; ▷/⊂ keep order. Bottom-up (children first)."""
    if t[0] == "P": return t[1]
    if t[0] == "MC":
        x = normk(t[1], rewrite_being)
        if rewrite_being and x == "BEING": return "SELF"
        if x.startswith("↻(") or x in ("▷(DEPTH,RECOGNITION)", "⊕(SELF,SELF)"): return x
        return "↻(" + x + ")"
    a, b = normk(t[1], rewrite_being), normk(t[2], rewrite_being)
    if t[0] == "SYN" and a == b == "∃": return a
    if t[0] == "CON" and a.encode() > b.encode(): a, b = b, a
    return "%s(%s,%s)" % (SYM[t[0]], a, b)

def dag(t):
    """the canonical glyph as ONE hash-consed DAG (CLAUDE.md, glyphdag): defs 'name' | '<sym><i>.<j>' | '↻<i>',
    structurally identical nodes interned ONCE, root LAST; returned as the ';'-joined string."""
    defs, index = [], {}
    def go(u):
        if u[0] == "P": d = u[1]
        elif u[0] == "MC": d = "↻%d" % go(u[1])
        else: d = "%s%d.%d" % (SYM[u[0]], go(u[1]), go(u[2]))
        if d not in index: index[d] = len(defs); defs.append(d)
        return index[d]
    go(t)
    return ";".join(defs)

def parse_defs(form):
    """-> list of (arity, children) or None if the form is not a valid DAG (a child must be an EARLIER index)"""
    out = []
    for i, d in enumerate(form.split(";")):
        if not d: return None
        head = d[0]
        if head in "⊗⊕▷⊂" and len(d) > 1 and d[1].isdigit():
            try: a, b = (int(x) for x in d[1:].split("."))
            except ValueError: return None
            if not (0 <= a < i and 0 <= b < i): return None
            out.append((2, (a, b)))
        elif head == "↻" and d[1:].isdigit():
            a = int(d[1:])
            if not 0 <= a < i: return None
            out.append((1, (a,)))
        else:
            out.append((0, (), d))
    return out

def topo(form):
    """REGISTERS.md's topological reading: V, E, b0 (connectedness from the root), b1 = E−V+1 (cycle rank),
    depth, leaves (arity 0), anchors (leaves among the nine), grounded; ⊥ on an invalid DAG, validity FIRST."""
    ds = parse_defs(form)
    if ds is None: return "⊥"
    V = len(ds); E = sum(d[0] for d in ds)
    seen, stack = set(), [V - 1]
    while stack:
        i = stack.pop()
        if i in seen: continue
        seen.add(i); stack.extend(ds[i][1])
    conn = len(seen) == V
    memo = {}
    def depth(i):
        if i not in memo: memo[i] = 0 if not ds[i][1] else 1 + max(depth(c) for c in ds[i][1])
        return memo[i]
    leaves = [d for d in ds if d[0] == 0]
    anchors = [d for d in leaves if d[2] in NINE]
    return "V=%d E=%d b0=%s b1=%s depth=%d leaves=%d anchors=%d grounded=%s" % (
        V, E, "1" if conn else ">1", str(E - V + 1) if conn else "⊥", depth(V - 1),
        len(leaves), len(anchors), "T" if len(leaves) == len(anchors) else "F")

def B(x): return "T" if x else "F"

# ── helpers added for sections 1, 41, 42, 43 ──
def tsize(t):
    """unfolded tree node count"""
    return 1 if t[0] == "P" else 1 + sum(tsize(c) for c in t[1:])

def dag_decomp(form):
    """the exact inverse of dag(): rebuild the tree from the ONE form (CLAUDE.md: DECOMP recovers the etymology)"""
    ds = form.split(";"); built = []
    for d in ds:
        if d[0] in "⊗⊕▷⊂" and d[1:2].isdigit():
            a, b = (int(x) for x in d[1:].split(".")); op = {v: k for k, v in SYM.items()}[d[0]]
            built.append((op, built[a], built[b]))
        elif d[0] == "↻" and d[1:].isdigit(): built.append(("MC", built[int(d[1:])]))
        else: built.append(("P", d))
    return built[-1]

def first_invalid(form):
    """the first def that names a parent not EARLIER in the list ('' if none) — the lineage validity rule"""
    for i, d in enumerate(form.split(";")):
        if d[0] in "⊗⊕▷⊂" and d[1:2].isdigit():
            if any(not 0 <= int(x) < i for x in d[1:].split(".")): return d
        elif d[0] == "↻" and d[1:].isdigit():
            if not 0 <= int(d[1:]) < i: return d
    return ""

def proper_subterms(t):
    """every subterm strictly below the root"""
    out = []
    def go(u, top):
        if not top: out.append(u)
        for c in u[1:]:
            if isinstance(c, tuple): go(c, False)
    go(t, True); return out

# the eight self-relations (CLAUDE.md, canon.la section): seven ↻(anchor) + SR_WITH = ⊕(SELF,SELF)
SR = {"SR_TO": MC(P("DEPTH")), "SR_ABOUT": MC(P("RECOGNITION")), "SR_AS": MC(P("FORM")), "SR_BY": MC(P("BECOMING")),
      "SR_FROM": MC(P("VOID")), "SR_THROUGH": MC(P("RELATION")), "SR_FOR": MC(P("LOVE")), "SR_WITH": CON(P("SELF"), P("SELF"))}

# ── operator glyphs as usable combinators (metaglyph.la:91-99, the WRITTEN rule) ──
# "read the minted operator's ETYMOLOGY as a TEMPLATE. Its base-mode structure is scaffolding; its primitive slots are
#  OPERAND-HOLES. SHAPE pours one operand into every primitive slot of a sub-template, preserving the mode skeleton;
#  APPLYOP pours operand a down the left sub-template and b down the right (unary top ↻ takes only a)."
# A bare primitive has no sub-template to pour into: its action is CONSTANT (modegenesis F4's stated purpose).
MODE_GLYPH = {"SYN": DIR(P("LOVE"), P("RELATION")), "CON": CONT(P("RELATION"), P("FORM")), "DIR": SYN(P("BECOMING"), P("RELATION")),
              "CONT": DIR(P("DEPTH"), P("FORM")), "MC": MC(P("SELF"))}          # CLAUDE.md / metaglyph.la: the five mode glyphs
def shape(x, tpl):
    if tpl[0] == "P": return x
    return (tpl[0],) + tuple(shape(x, c) for c in tpl[1:])
def applyop(etym, a, b):
    if etym[0] == "P": return etym
    if etym[0] == "MC": return MC(shape(a, etym[1]))
    return (etym[0], shape(a, etym[1]), shape(b, etym[2]))
