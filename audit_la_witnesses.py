#!/usr/bin/env python3
"""audit_la_witnesses — Freeze-Day Audit IV: the SELF-ASSERTING Lingua Adamica witnesses.

THE SURFACE, AND WHY IT IS THE LAST ONE
---------------------------------------
Audit II triaged build.sh. Audit III triaged the standalone gate_*.sh scripts.
Both are shell. The assertions inside .la modules were covered by neither.

That surface splits in two, and only half of it is new:

  * EXTERNALLY ASSERTED — canon.la, metalogic.la, aatc.la and friends print a
    witness string and build.sh greps it. Those assertions live in build.sh and
    were ALREADY Audit II's surface. Not re-audited here.
  * SELF-ASSERTING — 20 modules judge themselves with the MARK idiom,
    `MARK(<bool>)("name")` rendering "name OK" / "name WRONG", and the gate
    compares the whole printed line to an expected constant. 96 checks.

The second is this audit. A MARK that goes WRONG changes the printed line and the
gate goes red — so these checks ARE wired. What no tool has ever asked is whether
any of them CAN go WRONG.

THE DEFECT THIS IS BUILT FOR — established by hand 2026-08-27
-------------------------------------------------------------
`wotsp.la` asserts, four lines apart:

    MARK(str_eq(pkA)(pk))("genuine verifies")
    MARK(NEQ(pkA)(FLIPS(pk)))("wrong-PK rejected")

Given the first, the second reduces to `pk != FLIPS(pk)` — true by construction,
since FLIPS XORs one bit. It exercises `bxor` and `str_eq`, never the verifier.
Same line in wotsp_prod.la and xmss.la.

THE DETECTOR
------------
Union-find over the equalities the POSITIVE MARKs establish, then ask of every
NEGATIVE MARK whether its two operands are the same value modulo a pure local
transform:

    positive MARK(str_eq(a)(b))  =>  union(a, b)
    negative MARK(NEQ(u)(F(w)))  =>  if find(u) == find(w), the check reduces to
                                     `w != F(w)` and CANNOT FAIL

★ It must not flag the honest negatives, and the file is full of them.
`NEQ(pkC)(pk)` — the tampered-signature control — looks identical in shape, but
`pkC` is bound by a lambda to a real recomputation and NO positive MARK unions it
with anything, so no path exists and it is correctly left alone. That separation
is the whole design: shape alone would condemn every negative control in the
codebase.

HONEST BOUND
------------
Equalities come only from MARKs, not from `la` bindings, so a value made equal by
a binding rather than asserted equal is invisible here — this UNDER-reports, and
that is the safe direction for a tool whose false positives would get it ignored.
Nested MARK expressions are parsed by balanced parens, not by a real LA parser.
★ A clean report is NOT evidence a witness can fail.

USAGE
    audit_la_witnesses.py --selftest        # calibrate FIRST
    audit_la_witnesses.py *.la
"""
import argparse, os, re, sys


def balanced(s, i):
    """s[i] == '('; return (inner_text, index_after_close)."""
    d, j = 0, i
    while j < len(s):
        if s[j] == '(':
            d += 1
        elif s[j] == ')':
            d -= 1
            if d == 0:
                return s[i + 1:j], j + 1
        j += 1
    return None, len(s)


CALL = re.compile(r'^\s*([A-Za-z_][\w]*)\s*\((.*)\)\s*$', re.S)
SYM = re.compile(r'^\s*([A-Za-z_][\w]*)\s*$')


def operands(expr):
    """`str_eq(A)(B)` / `NEQ(A)(B)` -> (op, A, B); else None."""
    m = re.match(r'^\s*(str_eq|int_eq|NEQ)\s*\(', expr)
    if not m:
        m2 = re.match(r'^\s*NOT\s*\(', expr)
        if not m2:
            return None
        inner, _ = balanced(expr, expr.index('('))
        r = operands(inner)
        if not r:
            return None
        op, a, b = r
        return ('NEQ' if op in ('str_eq', 'int_eq') else 'str_eq', a, b)
    op = m.group(1)
    i = expr.index('(', m.start(1) + len(op) - 1)
    a, k = balanced(expr, i)
    while k < len(expr) and expr[k] not in '(':
        if not expr[k].isspace():
            return None
        k += 1
    if k >= len(expr):
        return None
    b, _ = balanced(expr, k)
    return (op, a, b)


def peel(t):
    """`FLIPS(pk)` -> ('FLIPS', 'pk'); `pk` -> (None, 'pk'); else (None, None)."""
    t = t.strip()
    if SYM.match(t):
        return None, t
    m = CALL.match(t)
    if m and SYM.match(m.group(2) or ''):
        return m.group(1), m.group(2).strip()
    return None, None


class UF:
    def __init__(self):
        self.p = {}

    def find(self, x):
        self.p.setdefault(x, x)
        while self.p[x] != x:
            self.p[x] = self.p[self.p[x]]
            x = self.p[x]
        return x

    def union(self, a, b):
        ra, rb = self.find(a), self.find(b)
        if ra != rb:
            self.p[ra] = rb


GLYPHDEF = re.compile(r'^glyph\s+([A-Za-z_][\w]*)\s*=\s*(.+)$', re.M)


def glyphdefs(text):
    """One-line `glyph NAME = expr` definitions, so idiom B's MARK(T1) resolves."""
    return {m.group(1): m.group(2).strip() for m in GLYPHDEF.finditer(text)}


def marks(text):
    """Yield (lineno, bool_expr, name) for BOTH MARK idioms.

    ★ THE SECOND IDIOM WAS MISSED ON THE FIRST PASS AND THE TOOL REPORTED CLEAN.
    Idiom A  MARK = la ok. la name. ...   called  MARK(<bool>)("name")
    Idiom B  MARK = la c. IF(c)(...)      called  MARK(SYM)   -- name is the
             preceding string literal in the concat, and the boolean is a SYMBOL
             defined by its own `glyph`, so it must be resolved to be analysed.
    Seven modules and 45 checks use idiom B. A parser that sees only idiom A
    covers 51 of 96 and says nothing about the rest -- so `--selftest` now
    ACCOUNTS FOR EVERY OCCURRENCE per file and fails if any is unparsed.
    """
    defs = glyphdefs(text)
    for m in re.finditer(r'\bMARK\s*\(', text):
        i = m.end() - 1
        expr, k = balanced(text, i)
        if expr is None:
            continue
        ln = text[:m.start()].count('\n') + 1
        j = k
        while j < len(text) and text[j].isspace():
            j += 1
        if j < len(text) and text[j] == '(':          # idiom A
            name, _ = balanced(text, j)
            yield ln, expr, name.strip().strip('"')
        else:                                          # idiom B
            sym = expr.strip()
            body = defs.get(sym, sym) if SYM.match(sym) else sym
            lits = re.findall(r'"([^"]*)"', text[max(0, m.start() - 120):m.start()])
            yield ln, body, (lits[-1].strip() if lits else sym)


LAMBIND = re.compile(r'\(\s*la\s+([A-Za-z_][\w]*)\s*\.')


def bindings(text):
    """NAME -> defining expression, for the `(la NAME. BODY)(ARG)` idiom.

    ★ THE SECOND DEFEAT MECHANISM. Audit III found gate_selfext2b.sh:38 asserting
    `[ -e logos_app ]` on the line after `rm -f logos_app` -- a check DEFEATED by
    an adjacent line rather than IMPLIED by a neighbouring assertion. The LA
    analogue is a binding that makes a comparison true by construction, and the
    MARK-equality union-find cannot see it: it only learns equalities that some
    positive MARK asserts, never ones a `la` binding creates.
    """
    out = {}
    for m in LAMBIND.finditer(text):
        i = m.start()
        _, k = balanced(text, i)                 # the (la NAME. BODY) group
        while k < len(text) and text[k].isspace():
            k += 1
        if k < len(text) and text[k] == '(':     # ... applied to (ARG)
            arg, _ = balanced(text, k)
            if arg is not None:
                out.setdefault(m.group(1), arg.strip())
    return out


def resolve(t, binds, depth=0, seen=None):
    """Follow a symbol through the binding chain to its defining expression."""
    seen = seen or set()
    t = re.sub(r'\s+', ' ', t.strip())
    if depth > 8 or t in seen:
        return t
    if SYM.match(t) and t in binds:
        seen = seen | {t}
        return resolve(binds[t], binds, depth + 1, seen)
    return t


def binding_defeats(path_text, ms):
    """D1: a POSITIVE MARK whose operands resolve to the SAME expression.
       D2: a NEGATIVE MARK NEQ(u)(F(w)) where u and w resolve to the same
           expression -- the wrong-PK shape reached through bindings, which the
           MARK-only union-find misses."""
    binds = bindings(path_text)
    hits = []
    for ln, expr, name in ms:
        r = operands(expr)
        if not r:
            continue
        op, a, b = r
        ra, rb = resolve(a, binds), resolve(b, binds)
        if op in ('str_eq', 'int_eq') and ra == rb and ra:
            hits.append((ln, name, f"both operands resolve through `la` bindings to the SAME "
                                   f"expression `{ra[:60]}` — the check compares a value to "
                                   f"itself and is vacuously TRUE"))
            continue
        if op == 'NEQ':
            fa, sa = peel(a); fb, sb = peel(b)
            for (f1, s1), (f2, s2) in (((fa, sa), (fb, sb)), ((fb, sb), (fa, sa))):
                if f1 is None and s1 and f2 is not None and s2:
                    if resolve(s1, binds) == resolve(s2, binds) and resolve(s1, binds):
                        hits.append((ln, name, f"{s1} and {s2} resolve through `la` bindings to "
                                               f"the same expression, so this reduces to "
                                               f"x != {f2}(x) — true by construction"))
                        break
    return hits


def audit(path, quiet=False):
    text = open(path, encoding='utf-8', errors='replace').read()
    ms = list(marks(text))
    uf = UF()
    for _, expr, _ in ms:
        r = operands(expr)
        if not r:
            continue
        op, a, b = r
        if op in ('str_eq', 'int_eq'):
            fa, sa = peel(a)
            fb, sb = peel(b)
            if fa is None and fb is None and sa and sb:
                uf.union(sa, sb)
    hits = []
    for ln, expr, name in ms:
        r = operands(expr)
        if not r:
            continue
        op, a, b = r
        if op != 'NEQ':
            continue
        fa, sa = peel(a)
        fb, sb = peel(b)
        # one side a bare symbol, the other that same value under a transform
        for (f1, s1), (f2, s2) in ((( fa, sa), (fb, sb)), ((fb, sb), (fa, sa))):
            if f1 is None and s1 and f2 is not None and s2 and uf.find(s1) == uf.find(s2):
                hits.append((ln, name, f"{s1} and {s2} are the SAME value (united by a positive "
                                       f"MARK), so this reduces to {s2} != {f2}({s2}) — true by "
                                       f"construction of {f2}"))
                break
    hits += binding_defeats(text, ms)
    if not quiet:
        for ln, name, why in hits:
            print(f"!!! {path}:{ln}  MARK({name!r})")
            print(f"      -> {why}\n")
    return ms, hits


# ── CALIBRATION ─────────────────────────────────────────────────────────────
# Established BY HAND on 2026-08-27, before this tool existed, so the tool is
# tested against them rather than defining them.
KNOWN_DEAD = {"wotsp.la": "wrong-PK", "wotsp_prod.la": "wrong-PK", "xmss.la": "wrong root"}
# honest negatives in the SAME files that must survive untouched, or shape alone
# would condemn every negative control in the codebase
KNOWN_LIVE = ["tampered-sig rejected", "wrong-msg rejected", "sig(m1)!=sig(m2)",
              "corrupt auth path rejected", "wrong msg rejected", "wrong leaf idx rejected"]


def selftest(root):
    ok = True
    print("CALIBRATION — the detector must reproduce what is already known.\n")
    for fn, want in KNOWN_DEAD.items():
        p = os.path.join(root, fn)
        if not os.path.exists(p):
            print(f"  MISS  {fn}: absent — cannot calibrate"); ok = False; continue
        ms, hits = audit(p, quiet=True)
        got = [h[1] for h in hits]
        if any(want in g for g in got):
            print(f"  ok    {fn}: {want!r} flagged  (of {len(ms)} MARKs)")
        else:
            print(f"  FAIL  {fn}: expected {want!r} flagged, got {got or 'none'}"); ok = False
        bad = [g for g in got if any(k in g for k in KNOWN_LIVE)]
        if bad:
            print(f"  FAIL  {fn}: flagged honest negative control(s) {bad} — false positive"); ok = False
        else:
            print(f"  ok    {fn}: honest negative controls NOT flagged")
    # ★ COVERAGE: every MARK occurrence must be accounted for, or the sweep
    #   silently covers part of the surface and reports clean on the rest.
    print()
    for fn in sorted(os.listdir(root)):
        if not fn.endswith('.la'):
            continue
        t = open(os.path.join(root, fn), encoding='utf-8', errors='replace').read()
        occ = len(re.findall(r'\bMARK\s*\(', t))
        if not occ:
            continue
        par = len(list(marks(t)))
        if par != occ:
            print(f"  FAIL  {fn}: {occ} MARK( occurrences, {par} parsed — {occ-par} INVISIBLE"); ok = False
    print("  ok    every MARK occurrence in every .la is parsed" if ok else
          "  ★ coverage gap: the sweep would report clean on assertions it never read")
    print("\n" + ("CALIBRATION PASSED — clean reports from this tool mean something."
                  if ok else "★ CALIBRATION FAILED — do NOT believe any report from this tool."))
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("files", nargs="*")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--root", default=".")
    a = ap.parse_args()
    if a.selftest:
        return selftest(a.root)
    if not a.files:
        ap.error("give .la files, or --selftest")
    tm = th = 0
    for f in a.files:
        if not os.path.exists(f):
            continue
        ms, hits = audit(f)
        tm += len(ms); th += len(hits)
    print("=" * 78)
    print(f"modules audited : {len(a.files)}")
    print(f"MARK checks     : {tm}")
    print(f"cannot-fail     : {th}")
    print("\n★ A clean report is NOT evidence a witness can fail. Equalities come from")
    print("positive MARKs AND from `la` bindings; what is still invisible is an equality")
    print("created by neither — so this UNDER-reports, which is the safe direction.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
