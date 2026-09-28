#!/usr/bin/env python3
"""tailpos.py <file.la> <GLYPH> — are all of a Z-loop glyph's self-calls TAIL calls?

The SECD VM's TCO fires only when an APPLY is immediately followed by RET, so a
loop `Z(la self. la p... . BODY)` runs in bounded dump only if every self(...)
call is reached through tail contexts alone:
  * BODY itself;
  * the body of a directly-applied lambda literal `(la x. b)(a)` (b runs, then
    RETs, after `a` is evaluated — logosinit's binder form);
  * a branch thunk of IF(c)(la _. t)(la _. e) (IF's own body ends
    c(t)(f)("!"), a tail APPLY, so the chosen thunk's body is in tail position).
Anything else — an argument (e.g. the second argument of SEQ), a function
position that is not a lambda literal — is NOT tail.  Prints one line per
self-call and exits 1 if any is non-tail (or no self-call is found).
"""
import re, sys

def lex(src):
    toks, i = [], 0
    while i < len(src):
        c = src[i]
        if c.isspace(): i += 1
        elif c == '#':
            while i < len(src) and src[i] != '\n': i += 1
        elif c in '().': toks.append(c); i += 1
        elif c == '"':
            j = i + 1
            while src[j] != '"': j += 2 if src[j] == '\\' else 1
            toks.append(('STR', src[i+1:j])); i = j + 1
        else:
            j = i
            while j < len(src) and not src[j].isspace() and src[j] not in '().#"': j += 1
            toks.append(('ID', src[i:j])); i = j
    return toks

class P:
    def __init__(s, t): s.t, s.i = t, 0
    def peek(s): return s.t[s.i] if s.i < len(s.t) else None
    def take(s, x=None):
        v = s.peek()
        if x is not None and v != x: raise SyntaxError(f"expected {x!r}, got {v!r}")
        s.i += 1; return v
    def expr(s):
        if s.peek() == ('ID', 'la'):
            s.take(); p = s.take()[1]; s.take('.'); return ('lam', p, s.expr())
        h = s.prim(); args = []
        while s.peek() == '(':
            s.take(); args.append(s.expr()); s.take(')')
        return ('app', h, args) if args else h
    def prim(s):
        v = s.take()
        if v == '(':
            e = s.expr(); s.take(')'); return e
        return ('var', v[1]) if v[0] == 'ID' else ('str', v[1])

def walk(e, tail, out):
    k = e[0]
    if k == 'lam':                      # a lambda VALUE: its body is not run here
        walk(e[2], False, out)
    elif k == 'app':
        h, args = e[1], e[2]
        if h == ('var', 'self'):
            out.append(tail)
            for a in args: walk(a, False, out)
        elif h[0] == 'lam' and len(args) == 1:       # (la x. b)(a)
            walk(args[0], False, out); walk(h[2], tail, out)
        elif h == ('var', 'IF') and len(args) == 3 and all(a[0] == 'lam' for a in args[1:]):
            walk(args[0], False, out)
            for a in args[1:]: walk(a[2], tail, out)
        else:
            walk(h, False, out)
            for a in args: walk(a, False, out)

def main():
    f, g = sys.argv[1], sys.argv[2]
    src = open(f).read()
    m = re.search(r'^glyph\s+' + re.escape(g) + r'\s*=(.*?)(?=^glyph\s|\Z)', src, re.S | re.M)
    if not m: print(f"{f}: no glyph {g}"); sys.exit(1)
    e = P(lex(m.group(1))).expr()
    # Z(la self. la p1 ... la pn. BODY)
    if not (e[0] == 'app' and e[1] == ('var', 'Z') and e[2][0][0] == 'lam' and e[2][0][1] == 'self'):
        print(f"{f} {g}: not a Z(la self. ...) loop"); sys.exit(1)
    body = e[2][0][2]
    while body[0] == 'lam': body = body[2]
    out = []; walk(body, True, out)
    for n, t in enumerate(out):
        print(f"{f} {g}: self-call #{n+1}: {'TAIL' if t else 'NON-TAIL'}")
    sys.exit(0 if out and all(out) else 1)

main()
