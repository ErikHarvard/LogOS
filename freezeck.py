# -*- coding: utf-8 -*-
"""freezeck.py — the STATIC half of the Track F freeze audit (FREEZE-TRACKF.md). No tiny_host, no VM:
it answers the questions that need no lease, so the lease is spent only on what needs a run.

  usage:  python3 freezeck.py [MODULE.la ...]     # default: every .la named by a `host` line in gate_registers.sh
          python3 freezeck.py --table              # FREEZE-TRACKF.md §2's module table, from the gate + git

  M  MUTANTS MUTATE — runs every mutant's `sed` into a temp dir (never the worktree) and requires it to
     change >=1 line of its source. A sed that matches nothing yields a copy of the green module, so its
     RED path could only "fire" by accident.
  S  NO SHADOWED LOCALS — a local `glyph X` whose name an import also exports is DEAD under tiny_host
     (lookup returns the FIRST definition; imports are entered first). A mutant aimed at it never fires;
     a local fix to it never takes effect. Reports identical-body duplicates separately from divergent ones.
  H  HEADER CLAIMS — status words (NOT RUN / NOT GATED / drafted / REGS_DRAFT …) in a module's first 60
     lines, for a human to check against the gate. Advisory: it cannot tell a stale claim from a true one.
  V  VM COVERAGE — gated modules absent from every vmlist in gate_registers.sh.
  R  SHORT RED TOKENS — red tokens under 10 chars; each must be proven ABSENT from the green output
     (needs a run: see checkreds.py), or the RED path can pass without the mutant changing anything.

  Exit status: 1 if M or S (divergent) finds anything, else 0. H, V and R are reports, not verdicts.

VALIDATED BOTH WAYS before it was trusted (2026-09-18): M flags a fixture mutant whose pattern matches
nothing (changed=0) and passes a real one; S flags a fixture that redefines an imported NORMK and is
silent on lineage.la. An instrument that has only ever said OK has not been shown to be able to say
anything else.
"""
import re, os, sys, subprocess, tempfile
HERE = os.path.dirname(os.path.abspath(__file__)); os.chdir(HERE)
GATE = open('gate_registers.sh', encoding='utf-8').read()
IMP = re.compile(r'import\("([^"]+)"\)'); EXP = re.compile(r'^export\s+(.*)$', re.M)
GLY = re.compile(r'^glyph\s+([A-Za-z0-9_]+)\s*=\s*(.*)$')
def code(s): return '\n'.join(l.split('#', 1)[0] for l in s.split('\n'))
def exports_of_imports(mod):
    out = {}
    for m in IMP.finditer(code(open(mod, encoding='utf-8').read())):
        p = m.group(1)
        if os.path.exists(p):
            for e in EXP.finditer(code(open(p, encoding='utf-8').read())):
                for n in e.group(1).split(): out.setdefault(n, p)
    return out
def local_defs(mod):
    d = {}
    for l in open(mod, encoding='utf-8').read().split('\n'):
        m = GLY.match(l)
        if m: d.setdefault(m.group(1), m.group(2).strip())
    return d
def enclosing_glyph(lines, j):
    for k in range(j, -1, -1):
        m = GLY.match(lines[k])
        if m: return m.group(1)
    return '?'

hosted = sorted(set(re.findall(r'^host ([A-Za-z_0-9]+\.la) ', GATE, re.M)))

if '--table' in sys.argv:   # FREEZE-TRACKF.md §2, regenerated from the gate + git (never hand-edit its counts)
    sec = None; secof = {}
    for l in GATE.split('\n'):
        m = re.match(r'^# ═══ (\d+)\.', l)
        if m: sec = int(m.group(1))
        h = re.match(r'^host ([A-Za-z_0-9]+\.la) ([a-z_0-9]+)', l)
        if h: secof.setdefault(h.group(1), (sec, h.group(2)))
    vm = set(re.findall(r'([A-Za-z_0-9]+\.la)', ' '.join(re.findall(r'vmlist="([^"]*)"', GATE))))
    git = lambda *a: subprocess.run(['git'] + list(a), capture_output=True, text=True).stdout.split()
    base = '801f006'; first = {}
    for c in git('log', '--reverse', '--format=%h', base + '..HEAD'):
        for f in git('show', '--name-only', '--format=', c):
            if f.endswith('.la'): first.setdefault(f, c)
    print('| § | module | born | wants | reds | gated here | VM list |')
    print('|---|---|---|---|---|---|---|')
    rows = []
    for m in git('diff', '--name-only', base, 'HEAD', '--', '*.la'):
        s_, t = secof.get(m, (None, None))
        w = len(re.findall(r'^want %s ' % t, GATE, re.M)) if t else 0
        r = len(re.findall(r'^red %s_m\d+ ' % t, GATE, re.M)) if t else 0
        rows.append((s_ if s_ is not None else 999, '| %s | `%s` | %s | %d | %d | %s | %s |' % (
            s_ if s_ is not None else '—', m, first.get(m, '?'), w, r, 'yes' if t else '**no**', 'yes' if m in vm else '**no**')))
    for _, row in sorted(rows): print(row)
    sys.exit(0)
mods = sys.argv[1:] or hosted
bad = 0

print('== M  mutants mutate')
reds = {}
for t in re.findall(r'^red ([a-z_0-9]+) ', GATE, re.M): reds[t] = reds.get(t, 0) + 1
tmp = tempfile.mkdtemp(prefix='freezeck_')
n = 0; mflag = 0
for i, l in enumerate(GATE.split('\n'), 1):
    for m in re.finditer(r"(sed (?:-e )?'[^']*'(?: -e '[^']*')*) (\S+\.la) > \"?(?:\$T/)?([A-Za-z_0-9]+)\.la\"?", l):
        sedexpr, src, tag = m.groups(); n += 1
        if sys.argv[1:] and src not in mods: continue
        if not os.path.exists(src): print('  L%d %s: SOURCE MISSING %s' % (i, tag, src)); mflag += 1; continue
        out = os.path.join(tmp, tag + '.la')
        subprocess.run(sedexpr + ' ' + src + ' > ' + out, shell=True)
        a = open(src, encoding='utf-8').read().split('\n'); b = open(out, encoding='utf-8').read().split('\n')
        ch = [j for j in range(min(len(a), len(b))) if a[j] != b[j]]
        if len(a) != len(b): ch.append(min(len(a), len(b)))
        names = sorted({enclosing_glyph(a, j) for j in ch if j < len(a)})
        sh = [x for x in names if x in exports_of_imports(src)]
        feeds = reds.get(tag, 0) or ('(feeds an import-mutant)' if re.search(r'import\("%s\.la"\)' % re.escape(tag), GATE) or tag.endswith('_mut') else 0)
        if not ch or sh or not feeds:
            mflag += 1
            print('  L%-4d %-10s %-18s changed=%d glyphs=%s %s reds=%s  <== CHECK' % (i, tag, src, len(ch), ','.join(names), 'SHADOWED:' + ','.join(sh) if sh else '', feeds))
print('  %d mutant sed commands, %d flagged' % (n, mflag)); bad += mflag

print('== S  shadowed locals (dead under tiny_host)')
sflag = 0
for mod in mods:
    ex = exports_of_imports(mod); loc = local_defs(mod)
    for name in sorted(set(loc) & set(ex)):
        theirs = local_defs(ex[name]).get(name)
        same = theirs is not None and theirs == loc[name]
        print('  %-20s %-12s from %-14s %s' % (mod, name, ex[name], 'identical body (dead, harmless today)' if same else 'DIVERGENT BODY  <== CHECK'))
        if not same: sflag += 1
print('  divergent shadows: %d' % sflag); bad += sflag

print('== H  header status claims (advisory)')
pat = re.compile(r'NOT (RUN|VERIFIED|GATED|EXECUTED)|NEVER RUN|REGS_DRAFT|WRITTEN, NOT|\(drafted|UNVERIFIED|TODO|FIXME', re.I)
for mod in mods:
    for i, l in enumerate(open(mod, encoding='utf-8').read().split('\n')[:60], 1):
        if l.startswith('#') and pat.search(l): print('  %s:%d: %s' % (mod, i, l.strip()[:140]))

print('== V  gated modules in no vmlist')
vm = set(re.findall(r'([A-Za-z_0-9]+\.la)', ' '.join(re.findall(r'vmlist="([^"]*)"', GATE))))
print('  ' + (' '.join(m for m in mods if m not in vm) or 'none'))

print('== R  short red tokens (<10 chars) — prove ABSENT from green output after a run')
for t, k in re.findall(r'^red ([a-z_0-9]+) "((?:[^"\\]|\\.)*)"', GATE, re.M):
    if len(k) < 10: print('  %-8s %r' % (t, k))
sys.exit(1 if bad else 0)
