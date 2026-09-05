#!/usr/bin/env python3
"""
gate_srcdrift.py — THE SPEC PIPELINE TESTS ONE ARTIFACT AND DEPLOYS ANOTHER.

Every entry in a `*_spec.la` module carries two things:

    E("NAME")(sig)(SRC_NAME)(NAME)(tests)
                   ^^^^^^^^  ^^^^
                   the TEXT   the VALUE

`GENERATE` writes SRC_NAME into the deployed `.la` file. `META_DEBUG` runs the
test cases against NAME, the live glyph. **Nothing compared them.** So a
correction applied to the live glyph and not to its SRC string is verified
green and shipped absent — and the pipeline's own "on-disk file == generated
source" check cannot see it, because that compares the deployed file against
the SRC string, i.e. the wrong one against the wrong one.

★ THAT IS NOT HYPOTHETICAL. It is how it was found (2026-08-23):

    canon_spec.la  live NORMK : WRAP2("⊗")   non-commutative, per LA.tex:2837
                   SRC_NORMK  : SORT2("⊗")   commutative, the pre-correction form

The ⊗ non-commutativity correction (commit 91fc923) reached the tested glyph
and not the deployed string. `canon.la` at HEAD still held the correct form
only because nobody had re-run the pipeline; the next run silently reverted it,
and the run after that would have verified the reverted file as correct. The
correction was not durable, and no standing gate could have told anyone.

★ WHY THE OBVIOUS GATE IS THE WRONG ONE. Comparing the deployed `.la` against
the SRC string is what DEPLOY already does, and it passes in exactly this
failure — both sides are the same wrong text. The comparison that discriminates
is SRC-vs-LIVE, because those are the two objects that were allowed to diverge.

── THE ONE LEGITIMATE DIVERGENCE, HANDLED BY RULE AND NOT BY ALLOWLIST ──
A deployed module must be SELF-CONTAINED, but a spec runs inside specpipe's
environment and may alias something it imports:

    aatc_spec.la:163   glyph Zc = Z          <- live: an alias
                       SRC_Zc  = "la f. ..." <- deployed: the body, inlined

The SRC *must* inline what the live definition gets for free. So a live body
that is a BARE IDENTIFIER is reported as INHERITED, not as drift. That is a
structural rule with a stated reason, not a list of names someone waived — an
allowlist is where this class comes back.

── RED PATH ──
`--selftest` mutates a known-good SRC string in memory and asserts this checker
reports it. If the mutation does not turn the gate red, the gate is vacuous and
--selftest exits non-zero. Run by the gate itself before it reports PASS, so
the gate proves it can fail every time it claims to pass.
"""
import re
import sys
import glob
import os

REPO = os.path.dirname(os.path.abspath(__file__))


def unesc(s):
    """Mirror tiny_host.c's string lexer: \\n \\t \\\\ \\" are special; every
    other escape DROPS THE BACKSLASH and keeps the character (`default: c = e`).
    Getting this wrong invents drift that is not there — it did, on first run."""
    out, i = [], 0
    while i < len(s):
        if s[i] == '\\' and i + 1 < len(s):
            out.append({'n': '\n', 't': '\t', '\\': '\\', '"': '"'}.get(s[i + 1], s[i + 1]))
            i += 2
        else:
            out.append(s[i])
            i += 1
    return ''.join(out)


def strip_comment(line):
    """Drop a trailing `#` comment, but not a `#` inside a string literal."""
    q, i = False, 0
    while i < len(line):
        c = line[i]
        if c == '\\' and q:
            i += 2
            continue
        if c == '"':
            q = not q
        elif c == '#' and not q:
            return line[:i]
        i += 1
    return line


def defs(txt):
    """name -> definition text, joining continuation lines. LA definitions run
    until the next top-level form, so a line-based regex truncates them — which
    also invents drift. It did, on first run."""
    lines, d, i = txt.split('\n'), {}, 0
    while i < len(lines):
        m = re.match(r'^glyph\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$', lines[i])
        if not m:
            i += 1
            continue
        name, body = m.group(1), [strip_comment(m.group(2))]
        i += 1
        while i < len(lines) and not re.match(r'^(glyph\s|export\s|import\s|#|\s*$)', lines[i]):
            body.append(strip_comment(lines[i]))
            i += 1
        d.setdefault(name, ' '.join(x.strip() for x in body).strip())
    return d


def norm(s):
    """Whitespace is not semantic between LA tokens, and GENERATE joins lines.
    Both sides get identical treatment, so a real difference still differs."""
    return re.sub(r'\s+', '', s)


def scan(sources):
    """sources: {filename: text}. -> (compared, drift, inherited)
    `compared` is the list of (file, SRC-glyph-name) pairs actually reached, so
    --selftest can mutate one that the scan really looks at. Mutating a string
    the scan skips proves nothing and silently passes — it did, on first run."""
    compared, drift, inherited = [], [], []
    for f, txt in sorted(sources.items()):
        live = defs(txt)
        for name, body in live.items():
            if not name.startswith('SRC_'):
                continue
            m = re.match(r'^"(.*)"$', body, re.S)
            if not m:
                continue
            ent = re.search(r'E\("[A-Za-z0-9_]+"\)\(.*?\)\(' + re.escape(name) + r'\)\(([A-Za-z0-9_]+)\)',
                            txt, re.S)
            target = ent.group(1) if ent else name[4:]
            if target not in live:
                continue
            compared.append((f, name))
            deployed, tested = norm(unesc(m.group(1))), norm(live[target])
            if deployed == tested:
                continue
            if re.match(r'^[A-Za-z_][A-Za-z0-9_]*$', live[target].strip()):
                inherited.append((f, target, live[target].strip()))   # bare alias: SRC must inline
            else:
                drift.append((f, target, deployed, tested))
    return compared, drift, inherited


def load():
    return {os.path.basename(f): open(f, encoding='utf-8').read()
            for f in glob.glob(os.path.join(REPO, '*_spec.la'))}


def selftest(sources):
    """Inject a divergence and require the checker to catch it."""
    compared, _, _ = scan(sources)
    target_file, mutated = None, None
    for f, srcname in compared:
        txt = sources[f]
        m = re.search(r'^glyph ' + re.escape(srcname) + r'\s*=\s*"(.*)"\s*$', txt, re.M)
        if m:
            target_file = f
            mutated = txt[:m.start(1)] + 'ZZ_INJECTED_DIVERGENCE_ZZ' + txt[m.end(1):]
            break
    if not target_file:
        print('FAIL  gate_srcdrift: --selftest found no SRC string to mutate; '
              'the red path could not be exercised')
        return False
    probe = dict(sources)
    probe[target_file] = mutated
    _, drift, _ = scan(probe)
    if not drift:
        print('FAIL  gate_srcdrift: an INJECTED divergence in %s was NOT reported. '
              'The gate cannot go red and is asserting nothing.' % target_file)
        return False
    return True


def main():
    sources = load()
    if not sources:
        print('FAIL  gate_srcdrift: no *_spec.la found — an empty scan is not a verdict')
        return 1

    if not selftest(sources):
        return 1

    compared, drift, inherited = scan(sources)
    pairs = len(compared)

    if pairs == 0:
        print('FAIL  gate_srcdrift: 0 SRC/live pairs compared — the scan matched '
              'nothing, which is not the same as finding nothing')
        return 1

    if drift:
        print('FAIL  gate_srcdrift: %d entr%s DEPLOY text that differs from the '
              'implementation the spec TESTS' % (len(drift), 'y has' if len(drift) == 1 else 'ies have'))
        for f, name, dep, tes in drift:
            print('  ★ %s :: %s' % (f, name))
            print('      DEPLOYED (SRC string -> the .la file): %s' % dep[:160])
            print('      TESTED   (live glyph -> META_DEBUG)  : %s' % tes[:160])
        return 1

    print('PASS  gate_srcdrift: %d SRC/live pairs agree across %d spec modules '
          '(%d inherited alias%s inlined by rule); red path exercised'
          % (pairs, len(sources), len(inherited), '' if len(inherited) == 1 else 'es'))
    return 0


if __name__ == '__main__':
    if '--selftest' in sys.argv:
        sys.exit(0 if selftest(load()) else 1)
    sys.exit(main())
