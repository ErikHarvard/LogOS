# -*- coding: utf-8 -*-
"""whatreruns.py — which gates must re-run after an edit (meta-architecture B2, 2026-09-26).

  python3 whatreruns.py lexicon.la opgrammar.la      # every gate section + build.sh block downstream
  python3 whatreruns.py --since <commit>             # the files changed since <commit>, then the same
  python3 whatreruns.py --selftest                   # the known-defect case + the edge classes, red-capable
  python3 whatreruns.py --stale <build_run.log> <sha> # which blocks GREEN in that audit are STALE at HEAD (report only)

Why: ec12042 (09-17) edited lexicon.la and opgrammar.la; four downstream gates went red and nobody
re-ran them for eight days (opgrammar collset, the build.sh grammar gate, the appendix LDIV arm, §23).

A UNIT is a gate_registers.sh section (`# ═══ N.` to the next header) or a build.sh block (`say "…"`
to the next `say`). A unit USES every file its non-comment lines name (*.la, *.py, *.sh, *.tex, …).
A file DEPENDS ON, transitively:
  · import("x")  and  read_file("x")  string literals in its non-comment source (a .la reading a file
    is as much a dependency as importing one: closure.la reads gate_registers.sh);
  · the parts of a concatenation `cat a.la b.la > c.la` in build.sh/gate_registers.sh (nameck's known
    blind spot: those fragments import nothing and resolve names from what is prepended);
  · X_spec.la for a generated X.la (the spec writes the module; see the never-hand-edit rule).
A unit must re-run when any file it uses reaches a changed file through those edges. Each hit prints
the path that reached it, so a listing can be checked by reading, not trusted.

★ FALSE-NEGATIVE CLASSES (what this CANNOT see, stated so nobody reads silence as safety): a path
built at run time (concat("x", y) passed to read_file), a file named only inside a helper function
defined outside the unit, and a dependency through the environment (REGS_* variables, /tmp artifacts
another block wrote). Editing gate_registers.sh's preamble (above §1) or build.sh's preamble, or
tiny_host.c, changes every unit of that suite; those are reported as ALL, not enumerated.
"""
import re, os, sys, subprocess

GATE, BUILD = 'gate_registers.sh', 'build.sh'
FILE = re.compile(r'(?<![A-Za-z0-9_./-])(\.?[A-Za-z0-9_][A-Za-z0-9_./-]*\.(?:la|py|sh|tex|txt|md|json|c|asm))(?![A-Za-z0-9_])')
LIT = re.compile(r'(?:import|read_file)\("([^"]+)"\)')
CAT = re.compile(r'\bcat\s+([^|>]*?)\s*>\s*([A-Za-z0-9_./-]+\.la)')

def nocomment(src):
    """strip # comments but KEEP string contents (same scanner as nameck.py's nocomment, which cannot be
    imported: it runs its CLI at import time)"""
    out = []; i = 0; n = len(src); instr = False
    while i < n:
        c = src[i]
        if instr:
            out.append(c)
            if c == '\\' and i + 1 < n: out.append(src[i + 1]); i += 2; continue
            if c == '"': instr = False
            i += 1; continue
        if c == '"': instr = True; out.append(c); i += 1; continue
        if c == '#':
            while i < n and src[i] != '\n': i += 1
            continue
        out.append(c); i += 1
    return ''.join(out)

def shcode(line):
    """a shell line without its trailing comment (a # inside quotes is kept — crude but conservative)"""
    s = line.lstrip()
    if s.startswith('#'): return ''
    return line

def norm(p):
    return os.path.normpath(p[2:] if p.startswith('./') else p)

def edges(root='.'):
    """file -> set of files it depends on (one step)"""
    dep = {}
    for f in sorted(os.listdir(root)):
        if f.endswith('.la'):
            try: code = nocomment(open(os.path.join(root, f), encoding='utf-8', errors='replace').read())
            except OSError: continue
            dep.setdefault(f, set()).update(norm(m) for m in LIT.findall(code))
            if f.endswith('_spec.la') and os.path.exists(os.path.join(root, f[:-8] + '.la')):
                dep.setdefault(f[:-8] + '.la', set()).add(f)
    for sh in (GATE, BUILD):
        p = os.path.join(root, sh)
        if not os.path.exists(p): continue
        for line in open(p, encoding='utf-8', errors='replace'):
            for m in CAT.finditer(shcode(line)):
                parts = [norm(x) for x in m.group(1).split() if x.endswith('.la')]
                dep.setdefault(norm(m.group(2)), set()).update(parts)
    return dep

def units(root='.'):
    """[(suite, id, title, first_line, set_of_files_used)] + the preamble file sets"""
    out = []; pre = {}
    p = os.path.join(root, GATE)
    if os.path.exists(p):
        cur = None; body = []; start = 0
        def flush():
            if cur: out.append(('gate', '§' + cur[0], cur[1], start, used(body)))
        for i, line in enumerate(open(p, encoding='utf-8', errors='replace'), 1):
            m = re.match(r'^# ═══ (\d+)\.\s*(.*?)\s*═*\s*$', line)
            if m:
                flush(); cur = (m.group(1), m.group(2)); body = []; start = i; continue
            if cur is None: pre.setdefault('gate', []).append(line)
            elif re.match(r'^\[ "\$ok" -eq 1 \] && echo "PASS  registers:', line): flush(); cur = None
            else: body.append(line)
        flush()
    p = os.path.join(root, BUILD)
    if os.path.exists(p):
        cur = None; body = []; start = 0
        def flushb():
            if cur: out.append(('build', 'build.sh:%d' % start, cur, start, used(body)))
        for i, line in enumerate(open(p, encoding='utf-8', errors='replace'), 1):
            m = re.match(r'^say "(.*)"', line)
            if m:
                flushb(); cur = m.group(1); body = [line]; start = i; continue
            if cur is None: pre.setdefault('build', []).append(line)
            else: body.append(line)
        flushb()
    return out, {k: used(v) for k, v in pre.items()}

def used(lines):
    s = set()
    for line in lines:
        s.update(norm(f) for f in FILE.findall(shcode(line)))
    return s

def reach(dep, start, changed):
    """a path start -> … -> changed file, or None (BFS, so the path printed is a shortest one)"""
    seen = {start: None}; q = [start]
    while q:
        f = q.pop(0)
        if f in changed:
            path = []
            while f is not None: path.append(f); f = seen[f]
            return path[::-1]
        for g in sorted(dep.get(f, ())):
            if g not in seen: seen[g] = f; q.append(g)
    return None

def whatreruns(changed, root='.'):
    changed = {norm(c) for c in changed}
    dep = edges(root); us, pre = units(root)
    hits = []; alls = []
    if 'tiny_host.c' in changed: alls += ['gate', 'build']
    if GATE in changed: alls.append('gate (gate_registers.sh itself changed — any section may have)')
    if BUILD in changed: alls.append('build (build.sh itself changed — any block may have)')
    for suite, uid, title, ln, files in us:
        best = None
        for f in sorted(files):
            p = reach(dep, f, changed)
            if p and (best is None or len(p) < len(best)): best = p
        if best: hits.append((suite, uid, title, best))
    return hits, alls, len(us), sum(len(v) for v in dep.values())

def report(changed, root='.'):
    hits, alls, nu, ne = whatreruns(changed, root)
    print('whatreruns: changed = %s · scanned %d units, %d dependency edges' % (' '.join(sorted(changed)), nu, ne))
    for a in alls: print('ALL  %s' % a)
    for suite, uid, title, path in hits:
        print('%-5s %-15s %-60.60s  ← %s' % (suite, uid, title, ' → '.join(path)))
    g = sorted({int(u[1:]) for s, u, t, p in hits if s == 'gate'})
    if g: print('re-run:  sh gate_section.sh %s' % ' '.join(map(str, g)))
    nb = sum(1 for h in hits if h[0] == 'build')
    print('%d gate sections, %d build.sh blocks' % (len(g), nb))
    return hits

ANSI = re.compile(r'\x1b\[[0-9;]*m')

def audit_blocks(lines):
    """title -> PASS | FAIL | EMPTY for each `== title ==` block of a build.sh run log (a FAIL line anywhere in it wins)"""
    st = {}; cur = None
    for line in lines:
        l = ANSI.sub('', line).rstrip('\n')
        m = re.match(r'^== (.*) ==$', l)
        if m: cur = m.group(1); st.setdefault(cur, 'EMPTY'); continue
        if cur is None: continue
        if l.startswith('FAIL'): st[cur] = 'FAIL'
        elif l.startswith('PASS') and st[cur] == 'EMPTY': st[cur] = 'PASS'
    return st

def block_bodies(text):
    """title -> [bodies] of build.sh's `say` blocks (a list: a title may repeat, and a repeated one is never judged)"""
    out = {}; cur = None; body = []
    for line in text.splitlines() + ['say "\0end"']:
        m = re.match(r'^say "(.*)"', line)
        if m:
            if cur is not None: out.setdefault(cur, []).append('\n'.join(body))
            cur = m.group(1); body = []
        elif cur is not None: body.append(line)
    return out

def stale(log, sha, root='.'):
    """★ E1 (Erik 09-28, ruling A: REPORT ONLY). A block GREEN in the audit of <sha> is STALE at HEAD when a file it
    reaches changed since <sha> (the whatreruns map), when its own build.sh text changed, or when tiny_host.c changed
    (every block). rc 0 none stale · 1 some stale · 2 NOT MEASURED (no log, no blocks in it, or <sha> unknown)."""
    try: blocks = audit_blocks(open(log, encoding='utf-8', errors='replace'))
    except OSError as e: print('stale: NOT MEASURED — %s' % e); return 2
    if not blocks: print('stale: NOT MEASURED — no `== title ==` block in %s' % log); return 2
    g = lambda *a: subprocess.run(['git', '-C', root] + list(a), capture_output=True, text=True)
    r = g('diff', '--name-only', sha, 'HEAD')
    if r.returncode: print('stale: NOT MEASURED — git diff %s HEAD: %s' % (sha, r.stderr.strip())); return 2
    changed = set(r.stdout.split())
    old = g('show', '%s:%s' % (sha, BUILD)).stdout; new = open(os.path.join(root, BUILD), encoding='utf-8', errors='replace').read()
    ob, nb = block_bodies(old), block_bodies(new)
    hits = {h[2]: h[3] for h in whatreruns(changed, root)[0] if h[0] == 'build'}
    allb = 'tiny_host.c' in changed
    green = [t for t, v in blocks.items() if v == 'PASS']
    rows = []; amb = 0
    for t in green:
        if len(nb.get(t, [])) != 1 or len(ob.get(t, [])) != 1:
            amb += 1; rows.append(('UNJUDGED', t, 'title %s in build.sh at HEAD / %s at %s — not judged' % (len(nb.get(t, [])), len(ob.get(t, [])), sha))); continue
        why = []
        if allb: why.append('tiny_host.c changed')
        if nb[t][0] != ob[t][0]: why.append('its build.sh text changed')
        if t in hits: why.append(' → '.join(hits[t]))
        if why: rows.append(('STALE', t, ' · '.join(why)))
    ns = sum(1 for r in rows if r[0] == 'STALE')
    print('stale: audit %s · %d blocks in the log, %d GREEN · %d files changed %s..HEAD · %d STALE · %d UNJUDGED'
          % (sha, len(blocks), len(green), len(changed), sha, ns, amb))
    for k, t, why in rows: print('  %-8s %-60.60s ← %s' % (k, t, why))
    return 1 if ns else 0

def selftest():
    """★ the RED is the defect that motivated the tool: an edit to lexicon.la must list §16 §17 §23 §49,
    the build.sh grammar gate (Core Lexicon + Operative Grammar) and the lexappendix block. Then each edge
    class on a fixture, where removing the edge must make the listing miss."""
    import tempfile, shutil
    bad = 0
    def t(ok, what):
        nonlocal bad
        print('  %s  %s' % ('ok  ' if ok else 'BAD ', what)); bad += 0 if ok else 1
    print('selftest (real tree, lexicon.la):')
    hits, alls, nu, ne = whatreruns({'lexicon.la'})
    t(nu > 100 and ne > 50, 'it looked: %d units, %d edges' % (nu, ne))
    ids = {h[1] for h in hits}; titles = ' | '.join(h[2] for h in hits)
    if os.path.exists(GATE):
        for s in ('§16', '§17', '§23', '§49'): t(s in ids, s + ' listed')
    else: print('  n/a   §16 §17 §23 §49: no %s in this tree (kernel-k1 has none; Track F does) — NOT MEASURED, never a pass' % GATE)
    t('Core Lexicon and the Operative Grammar' in titles, 'build.sh grammar gate listed')
    t(any('lexappendix' in h[2] or 'lexappendix.la' in h[3] for h in hits if h[0] == 'build'), 'build.sh lexappendix block listed')
    t(len(ids) < nu, 'not everything listed (%d of %d) — a tool that lists all units cannot fail this test' % (len(ids), nu))
    print('selftest (fixture, one edge class each):')
    d = tempfile.mkdtemp()
    try:
        W = lambda f, s: open(os.path.join(d, f), 'w', encoding='utf-8').write(s)
        W('base.la', 'glyph B = "b"\n')
        W('mid.la', 'import("base.la")\nglyph M = B\n')
        W('rd.la', 'glyph R = read_file("data.txt")\n')
        W('data.txt', 'x\n')
        W('gen_spec.la', 'glyph S = "s"\n'); W('gen.la', 'glyph G = "g"\n')
        W('frag.la', 'glyph F = B\n')
        W('cmt.la', '# import("base.la")\nglyph C = "c"\n')
        W('top.la', 'import("mid.la")\nglyph T = M\n')   # TWO hops to base.la: the transitive case
        W(GATE, 'pre\n# ═══ 1. imp ═══\nhost mid.la a\n# ═══ 2. rd ═══\nhost rd.la b\n# ═══ 3. gen ═══\nhost gen.la c\n'
                '# ═══ 4. none ═══\nhost cmt.la d\n# ═══ 5. cat ═══\nhost .run.la e\n# ═══ 6. two-hop ═══\nhost top.la f\n[ "$ok" -eq 1 ] && echo "PASS  registers: x"\n')
        W(BUILD, 'pre\ncat base.la frag.la > .run.la\nsay "blk"\nX="$(./tiny_host mid.la)"\nsay "other"\n# mid.la in a comment only\n')
        ids = lambda ch: {h[1] for h in whatreruns(ch, d)[0]}
        t(ids({'base.la'}) == {'§1', '§5', '§6', 'build.sh:3'}, 'import edge (1 and 2 hops) + cat edge reach base.la: %s' % sorted(ids({'base.la'})))
        t(ids({'data.txt'}) == {'§2'}, 'read_file edge: %s' % sorted(ids({'data.txt'})))
        t(ids({'gen_spec.la'}) == {'§3'}, 'spec → generated edge: %s' % sorted(ids({'gen_spec.la'})))
        t('§4' not in ids({'base.la'}), 'an import inside a # comment is NOT an edge')
        t('build.sh:5' not in ids({'mid.la'}), 'a file named only in a comment is NOT used')
        t(whatreruns({'tiny_host.c'}, d)[1][:2] == ['gate', 'build'], 'tiny_host.c → ALL')
        t(ids({'nosuch.la'}) == set(), 'an unrelated file lists nothing')
        # --stale: a fixture repo; an audit at c1 with 3 green blocks; c2 edits base.la (reached by "blk" only) and
        # rewrites "third"'s body. STALE must be exactly blk (reach) + third (text); "other" stays fresh.
        W(BUILD, 'pre\nsay "blk"\nX="$(./tiny_host mid.la)"\nsay "other"\necho hi\nsay "third"\necho one\n')
        G = lambda *a: subprocess.run(['git', '-C', d, '-c', 'user.email=t@t', '-c', 'user.name=t'] + list(a), capture_output=True, text=True, env={k: v for k, v in os.environ.items() if not k.startswith('GIT_')})
        G('init', '-q'); G('add', '-A'); G('commit', '-qm', 'c1'); c1 = G('rev-parse', 'HEAD').stdout.strip()
        W('base.la', 'glyph B = "b2"\n'); s0 = open(os.path.join(d, BUILD)).read(); W(BUILD, s0.replace('echo one', 'echo two'))
        G('commit', '-qam', 'c2')
        W('run.log', '\x1b[1m== blk ==\x1b[0m\nPASS  a\n== other ==\nPASS  b\n== third ==\nPASS  c\n')
        import io, contextlib
        def S(log, sha):
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf): rc = stale(log, sha, d)
            return rc, buf.getvalue()
        rc, o = S(os.path.join(d, 'run.log'), c1)
        st = {l.split()[1] for l in o.splitlines() if l.strip().startswith('STALE')}
        t(rc == 1 and st == {'blk', 'third'}, 'RED PATH: --stale names exactly the reached block and the rewritten block: rc %s %s' % (rc, sorted(st)))
        W('run2.log', '== blk ==\nFAIL  a\n== other ==\nPASS  b\n')
        rc, o = S(os.path.join(d, 'run2.log'), c1)
        t(rc == 0 and 'STALE' not in o.replace('0 STALE', ''), 'a block RED in the audit is not called stale (it was never green): rc %s' % rc)
        rc, o = S(os.path.join(d, 'absent.log'), c1)
        t(rc == 2 and 'NOT MEASURED' in o, 'RED PATH: a missing log is NOT MEASURED, rc 2 — never "nothing stale"')
    finally: shutil.rmtree(d)
    print('selftest: %s' % ('PASS' if not bad else '%d BAD' % bad)); return 1 if bad else 0

if __name__ == '__main__':
    a = sys.argv[1:]
    if not a or a[0] in ('-h', '--help'): print(__doc__.split('\n\n')[1]); sys.exit(2)
    if a[0] == '--selftest': sys.exit(selftest())
    if a[0] == '--stale' and len(a) == 3: sys.exit(stale(a[1], a[2]))
    if a[0] == '--since':
        ch = subprocess.run(['git', 'diff', '--name-only', a[1], '--'] + a[2:], capture_output=True, text=True, check=True).stdout.split()
        if not ch: print('whatreruns: nothing changed since %s' % a[1]); sys.exit(0)
        a = ch
    report(set(a))
