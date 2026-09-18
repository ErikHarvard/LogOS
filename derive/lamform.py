# -*- coding: utf-8 -*-
"""F26's FORM half: are BEING and ONE the same FORM? A pure λ-normalizer over the definitions in primitives.la.

09-17 correction 6 said "BEING is not ONE" and §47 printed it as text (FREEZE-TRACKF.md F26). Erik's F5 ruling fixes
the two registers: η-equivalence is identity in the TRUTH register only. So:
  FORM register  — terms identified up to α and β, NOT η: compare the β-normal forms up to α.
  TRUTH register — terms identified up to α, β AND η: compare the βη-normal forms up to α.
BEING, VOID (zero) and BECOMING (successor) are READ from the given file, and ONE is COMPUTED as the β-normal form of
BECOMING(VOID) — nothing is typed in. Worked by hand first (the expected values, derived before this ran):
    BECOMING(VOID) = (λn.λf.λx.f(n f x))(λa.λb.b) →β λf.λx.f((λa.λb.b) f x) →β λf.λx.f x         = ONE
    FORM:  λself.self vs λf.λx.f x — one binder vs two: NOT α-equal                                  → :F
    TRUTH: λf.λx.f x →η λf.f ≡α λself.self                                                           → :T

  usage:  python3 derive/lamform.py primitives.la
  exit:   0 on a verdict (either way — the gate judges the tokens); 2 if a definition is missing, does not parse, uses a
          string literal (not a pure λ-term), or normalization runs out of fuel — never a silent verdict.
Gate §47 `lf`: two mutants of primitives.la (BEING made Church one; BECOMING made to add two) must flip FORM and TRUTH.
"""
import re, sys
TOK = re.compile(r'\s*(la\b|\(|\)|\.|"|[^\s().,"#]+)')

def die(msg): print("ERROR: " + msg); sys.exit(2)

def lex(src):
    out, i = [], 0
    while i < len(src):
        m = TOK.match(src, i)
        if not m or m.end() == i:
            if src[i:].strip() == "": break
            die("cannot lex at: %r" % src[i:i + 30])
        t = m.group(1); i = m.end()
        if t == '"': die("a string literal — not a pure λ-term: %r" % src[:60])
        out.append(t)
    return out

# terms, de Bruijn with name hints: ('v', i) | ('g', name) | ('lam', hint, body) | ('app', f, a)
def parse(src):
    toks = lex(src); pos = [0]
    def peek(): return toks[pos[0]] if pos[0] < len(toks) else None
    def eat(t=None):
        x = peek()
        if x is None or (t and x != t): die("parse: expected %r, got %r in %r" % (t, x, src[:60]))
        pos[0] += 1; return x
    def expr(env):
        if peek() == "la":
            eat("la"); name = eat(); eat(".")
            return ("lam", name, expr([name] + env))
        f = atom(env)
        while peek() == "(":
            eat("("); a = expr(env); eat(")"); f = ("app", f, a)
        return f
    def atom(env):
        x = peek()
        if x == "(":
            eat("("); e = expr(env); eat(")"); return e
        if x in (None, ")", ".", "la"): die("parse: unexpected %r in %r" % (x, src[:60]))
        eat(); return ("v", env.index(x)) if x in env else ("g", x)
    e = expr([])
    if peek() is not None: die("parse: trailing %r in %r" % (peek(), src[:60]))
    return e

def shift(t, d, c=0):
    k = t[0]
    if k == "v": return ("v", t[1] + d) if t[1] >= c else t
    if k == "g": return t
    if k == "lam": return ("lam", t[1], shift(t[2], d, c + 1))
    return ("app", shift(t[1], d, c), shift(t[2], d, c))
def subst(t, j, s):
    k = t[0]
    if k == "v": return s if t[1] == j else t
    if k == "g": return t
    if k == "lam": return ("lam", t[1], subst(t[2], j + 1, shift(s, 1)))
    return ("app", subst(t[1], j, s), subst(t[2], j, s))
def beta(body, arg): return shift(subst(body, 0, shift(arg, 1)), -1)

FUEL = [100000]
def nf(t):                                   # normal-order β-normalization (finds the normal form if one exists)
    while True:                              # a head redex LOOPS here, so a divergent term exhausts FUEL, not the stack
        FUEL[0] -= 1
        if FUEL[0] < 0: die("normalization ran out of fuel (no β-normal form within budget)")
        k = t[0]
        if k in ("v", "g"): return t
        if k == "lam": return ("lam", t[1], nf(t[2]))
        f = whnf(t[1])
        if f[0] != "lam": return ("app", nf(f), nf(t[2]))
        t = beta(f[2], t[2])
def whnf(t):
    while t[0] == "app":
        FUEL[0] -= 1
        if FUEL[0] < 0: die("normalization ran out of fuel")
        f = whnf(t[1])
        if f[0] != "lam": return ("app", f, t[2])
        t = beta(f[2], t[2])
    return t
def free0(t, c=0):
    k = t[0]
    if k == "v": return t[1] == c
    if k == "g": return False
    if k == "lam": return free0(t[2], c + 1)
    return free0(t[1], c) or free0(t[2], c)
def eta(t):                                  # η-normalize a β-normal term (η-reduction keeps it β-normal)
    k = t[0]
    if k in ("v", "g"): return t
    if k == "app": return ("app", eta(t[1]), eta(t[2]))
    b = eta(t[2])
    if b[0] == "app" and b[2] == ("v", 0) and not free0(b[1]): return shift(b[1], -1)
    return ("lam", t[1], b)
def alpha_eq(a, b):                          # de Bruijn: structural equality ignoring the name hints
    if a[0] != b[0]: return False
    if a[0] in ("v", "g"): return a[1] == b[1]
    if a[0] == "lam": return alpha_eq(a[2], b[2])
    return alpha_eq(a[1], b[1]) and alpha_eq(a[2], b[2])
def show(t, env=()):
    k = t[0]
    if k == "v": return env[t[1]]
    if k == "g": return t[1]
    if k == "lam":
        n = t[1]
        while n in env: n += "'"
        return "la %s. %s" % (n, show(t[2], (n,) + tuple(env)))
    f = show(t[1], env); f = "(%s)" % f if t[1][0] == "lam" else f
    return "%s(%s)" % (f, show(t[2], env))
def binders(t):
    n = 0
    while t[0] == "lam": n += 1; t = t[2]
    return n

if len(sys.argv) != 2: die("usage: lamform.py primitives.la")
src = open(sys.argv[1], encoding="utf-8").read()
def define(name):
    m = re.search(r'^glyph %s\s*=\s*(.*)$' % re.escape(name), src, re.M)
    if not m: die("%s is not defined in %s" % (name, sys.argv[1]))
    body = m.group(1).split("#", 1)[0].strip()
    return body, parse(body)
(bs, BEING), (vs, VOID), (cs, BECOMING) = define("BEING"), define("VOID"), define("BECOMING")
for n, t in (("BEING", BEING), ("VOID", VOID), ("BECOMING", BECOMING)):
    if re.search(r"\('g'", repr(t)): die("%s has a free name — it is not a closed λ-term here" % n)
try:
    b_nf, one = nf(BEING), nf(("app", BECOMING, VOID))
except RecursionError:
    die("normalization recursed too deep (a term growing without a normal form?) — no verdict")
form_same = alpha_eq(b_nf, one)
truth_same = alpha_eq(eta(b_nf), eta(one))
B = lambda x: "T" if x else "F"
print("LAMFORM read from %s: BEING = %s | VOID = %s | BECOMING = %s" % (sys.argv[1], bs, vs, cs))
print("LAMFORM ONE = the β-normal form of BECOMING(VOID) = %s" % show(one))
print("LAMFORM FORM register (β-normal, up to α; η NOT applied) — BEING and ONE are the same term:%s (binders %d vs %d)"
      % (B(form_same), binders(b_nf), binders(one)))
print("LAMFORM TRUTH register (βη-normal, up to α) — BEING and ONE are the same term:%s (η-normal: BEING = %s, ONE = %s)"
      % (B(truth_same), show(eta(b_nf)), show(eta(one))))
