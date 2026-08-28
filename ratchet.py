#!/usr/bin/env python3
"""
ratchet.py — STAGE 3: THE RATCHET GATE.

The ledger's condition on any coinage:

    a coinage may never collapse two previously κ-distinct forms,
    and must STRICTLY ADD a new κ-class.

Two conditions, and both are needed. The first is the ratchet -- it can only
turn one way. The second is what separates growth from relabelling.

★ THE FAILURE THIS EXISTS TO CATCH. `SYNTH` composes glyphs the organ already
has. A "new" capability that is α-equivalent to an existing one adds NOTHING,
and every other gate in the chain passes it: it verifies (it works), it is its
own derivation, the parent capabilities survive, and a begotten child will
happily demonstrate it. Stage 2b's child would print 12 for a TRIPLEDEC that
was a renamed copy of something already there. Only a κ-class count can see it.

── THE NORMALISER IS AN INSTRUMENT, SO IT IS TESTED FIRST ──────────────────
κ-class here is the α-canonical form of a glyph's body: bound variables are
replaced by the position of their binder, so renaming a variable changes
nothing and rebinding one changes everything. That is a claim about the
normaliser, not about the organ, so `--selftest` checks it on four pairs
INCLUDING the one that matters most:

    la x. la y. x   vs   la x. la y. y      SAME NAMES, DIFFERENT BINDING

A normaliser that merely stripped names would call those equal and would then
report every rebinding as a rename. If any pair comes out wrong the gate
refuses to run, because a broken normaliser makes every verdict below
meaningless.

── HONEST BOUND ────────────────────────────────────────────────────────────
This is α-equivalence, which is DECIDABLE. It is not behavioural equivalence,
which is not. Two glyphs with different α-canonical forms may still compute the
same function, so the ratchet can be fooled by a rename that is not literal --
`la x. mul(x)(3)` versus `la x. add(mul(x)(2))(x)`. It catches the rename, not
every redundancy. Stage 4's held-out acceptance is the answer to the rest, and
saying which is which is the point of stating this.
"""
import re, sys, os

TOK = re.compile(r'"(?:[^"\\]|\\.)*"|[A-Za-z_][A-Za-z0-9_]*|[().]|\S')

def alpha(body):
    """α-canonical form: each binder numbered by order of appearance; every
    bound occurrence replaced by its binder's number. Free names untouched."""
    toks = TOK.findall(body)
    out, scopes, n, depth, i = [], [], 0, 0, 0
    while i < len(toks):
        t = toks[i]
        if t == 'la' and i + 2 < len(toks) and toks[i+2] == '.':
            name = toks[i+1]
            scopes.append((name, '#%d' % n, depth)); n += 1
            out.append('la'); out.append('#%d' % (n-1)); out.append('.')
            i += 3; continue
        if t == '(':
            depth += 1
        elif t == ')':
            depth -= 1
            while scopes and scopes[-1][2] > depth:
                scopes.pop()
        if re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', t):
            rep = None
            for nm, idx, d in reversed(scopes):
                if nm == t:
                    rep = idx; break
            out.append(rep if rep else t)
        else:
            out.append(t)
        i += 1
    return ' '.join(out)

def glyphs(path):
    """name -> body, joining continuation lines (a line-based split truncates)."""
    lines = open(path, encoding='utf-8').read().split('\n')
    d, i = {}, 0
    while i < len(lines):
        m = re.match(r'^glyph\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$', lines[i])
        if not m:
            i += 1; continue
        name, body = m.group(1), [m.group(2)]
        i += 1
        while i < len(lines) and not re.match(r'^(glyph\s|export\s|import\s|#|\s*$)', lines[i]):
            body.append(lines[i]); i += 1
        d[name] = ' '.join(x.strip() for x in body).strip()
    return d

def kclasses(path):
    return {alpha(b) for b in glyphs(path).values()}

def selftest():
    cases = [
        ('la x. mul(x)(3)',   'la y. mul(y)(3)',   True,  'a pure rename'),
        ('la x. mul(x)(3)',   'la x. mul(x)(4)',   False, 'a changed constant'),
        ('la x. la y. x',     'la a. la b. a',     True,  'renamed, same binding'),
        ('la x. la y. x',     'la x. la y. y',     False, 'SAME NAMES, DIFFERENT BINDING'),
    ]
    ok = True
    for a, b, want_same, why in cases:
        got = (alpha(a) == alpha(b))
        if got != want_same:
            print('FAIL  ratchet: the α-normaliser is wrong on %r vs %r (%s): '
                  'expected %s, got %s' % (a, b, why,
                  'SAME' if want_same else 'DIFFERENT', 'SAME' if got else 'DIFFERENT'))
            ok = False
    return ok

def main():
    if '--selftest' in sys.argv:
        return 0 if selftest() else 1
    if len(sys.argv) < 3:
        print('usage: ratchet.py PARENT.la CHILD.la'); return 2
    if not selftest():
        print('FAIL  ratchet: refusing to judge with a broken normaliser')
        return 1
    p, c = sys.argv[1], sys.argv[2]
    for f in (p, c):
        if not os.path.exists(f):
            print('FAIL  ratchet: %s absent — an empty comparison is not a verdict' % f)
            return 1
    kp, kc = kclasses(p), kclasses(c)
    if not kp:
        print('FAIL  ratchet: the parent has no κ-classes — the scan matched nothing')
        return 1
    lost = kp - kc
    added = kc - kp
    bad = 0
    if lost:
        print('FAIL  ratchet: %d parent κ-class(es) COLLAPSED or disappeared — a '
              'coinage may never collapse two previously κ-distinct forms.' % len(lost))
        for l in sorted(lost)[:3]:
            print('    lost: %s' % l[:100])
        bad = 1
    if len(kc) <= len(kp):
        print('FAIL  ratchet: κ-class count did not STRICTLY increase (%d -> %d). '
              'The extension adds no new class: it is a RENAME or a duplicate of '
              'something the organ already had. Every other gate in the chain '
              'passes such an extension — it verifies, it is its own derivation, '
              'the parents survive, and a begotten child demonstrates it. Only '
              'this count can see it.' % (len(kp), len(kc)))
        bad = 1
    if bad:
        return 1
    print('PASS  ratchet: κ-classes %d -> %d, strictly increasing; %d new class(es) '
          'and NO parent class lost or collapsed. The extension adds a genuinely '
          'α-distinct capability rather than relabelling one the organ already had. '
          'Normaliser self-tested on 4 pairs including same-names/different-binding. '
          'BOUND: α-equivalence is decidable; behavioural equivalence is not, so a '
          'non-literal restatement is not caught here — that is stage 4.'
          % (len(kp), len(kc), len(added)))
    return 0

if __name__ == '__main__':
    sys.exit(main())
