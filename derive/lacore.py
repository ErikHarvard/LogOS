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
    """NORMK per CLAUDE.md + canon_spec.la's rule comments: ⊗/⊕ operands sorted bytewise; ⊗-idempotence for ∃ ALONE;
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
    if t[0] in ("SYN", "CON") and a.encode() > b.encode(): a, b = b, a
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
