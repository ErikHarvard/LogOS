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

  D  THE STANDING RULE (F33) — every `want` carries `#@ turns-red: <clauses>`; a red: must be TIED to its witness.
  G  IGNORED PARAMETERS — the F25 shape (a function handed an argument it never uses); every hit must be reviewed.

  python3 freezeck.py --selftest   plants one error of every class in a temp copy and requires each to FAIL (rc 1)
                                   and the unmodified copy to PASS — the checker's own red path, standing.

  Exit status: 1 if M, S (divergent), D or G finds anything, else 0. H, V and R are reports, not verdicts.

VALIDATED BOTH WAYS before it was trusted (2026-09-18): M flags a fixture mutant whose pattern matches
nothing (changed=0) and passes a real one; S flags a fixture that redefines an imported NORMK and is
silent on lineage.la. An instrument that has only ever said OK has not been shown to be able to say
anything else.
"""
import re, os, sys, subprocess, tempfile, shutil
HERE = os.path.dirname(os.path.abspath(__file__)); os.chdir(HERE)

if '--selftest' in sys.argv:
    # THE CHECKER'S OWN RED PATH, standing (F33 self-audit): plant one error of every class in a temp copy; each must FAIL.
    CASES = [
        ('control: unmodified', None, None, 0, ''),
        ('missing declaration', '  #@ turns-red: red:lin_m1', '', 1, 'NO DECLARATION'),
        ('red: another module\'s mutant', 'turns-red: red:lin_m1', 'turns-red: red:top_m1', 1, 'is not a mutant of lin'),
        ('red: a mutant that does not exist', 'turns-red: red:lin_m1', 'turns-red: red:lin_m9', 1, 'lin_m9 has no host line'),
        ('red: real mutant, NOT TIED to this witness', '(DAG<tree, 4 defs):T" lineage  #@ turns-red: exact:s01', '(DAG<tree, 4 defs):T" lineage  #@ turns-red: red:lin_m1', 1, 'NOT TIED'),
        ('cannot-fail citing a CLOSED item', 'cannot-fail:F28', 'cannot-fail:F6', 1, 'F6 is not an OPEN ledger item'),
        ('cannot-fail citing an unknown item', 'cannot-fail:F28', 'cannot-fail:F999', 1, 'F999 is not an OPEN ledger item'),
        ('unknown clause kind', 'turns-red: red:lin_m1', 'turns-red: maybe:lin_m1', 1, 'unknown clause kind'),
        ('entailed pointing at no witness', 'entailed:ti.1', 'entailed:ti.9', 1, 'points at no witness'),
        ('exact: a derivation that does not exist', 'exact:s01', 'exact:s99', 1, 'has no derive/s99_'),
        ('an UNREVIEWED ignored parameter', None, 'GLYPH:glyph ZZ_IGN = la q. la w. concat(w)(w)', 1, 'ZZ_IGN ignores its parameter'),
    ]
    _g = open('gate_registers.sh', encoding='utf-8').read()
    need = set(re.findall(r'^host ([A-Za-z_0-9]+\.la) ', _g, re.M))
    need |= set(re.findall(r"' ([A-Za-z_0-9]+\.la) > ", _g))                       # every file a mutant sed reads (F26: primitives.la)
    need |= set(re.findall(r'^static \S+ \S+ ([A-Za-z_0-9]+\.la)', _g, re.M))     # every static witness's root
    for m in list(need):
        for i in re.findall(r'import\("([^"]+)"\)', open(m, encoding='utf-8').read()): need.add(i)
    fails = 0
    for label, a, b, want, expect in CASES:
        d = tempfile.mkdtemp(prefix='freezeck_selftest_')
        for f in list(need) + ['gate_registers.sh', 'FREEZE-TRACKF.md', 'freezeck.py']:
            if os.path.exists(f): shutil.copy(f, d)
        shutil.copytree('derive', os.path.join(d, 'derive'), ignore=shutil.ignore_patterns('__pycache__'))
        if b and b.startswith('GLYPH:'):
            with open(os.path.join(d, 'lineage.la'), 'a', encoding='utf-8') as fh: fh.write('\n' + b[6:] + '\n')
        elif a is not None:
            g = open(os.path.join(d, 'gate_registers.sh'), encoding='utf-8').read()
            if a not in g: print('  SELFTEST FIXTURE BROKEN (anchor missing): %s' % label); fails += 1; shutil.rmtree(d); continue
            open(os.path.join(d, 'gate_registers.sh'), 'w', encoding='utf-8').write(g.replace(a, b, 1))
        r = subprocess.run([sys.executable, os.path.join(d, 'freezeck.py')], capture_output=True, text=True); rc = r.returncode
        ok = (rc != 0) == (want == 1) and (expect in r.stdout)   # failed for the RIGHT reason, not merely failed
        print('  %-44s rc=%d want %s  %s' % (label, rc, 'FAIL' if want else 'PASS', 'ok' if ok else '<== SELFTEST FAILED'))
        fails += 0 if ok else 1
        shutil.rmtree(d)
    print('selftest: %d of %d cases behaved' % (len(CASES) - fails, len(CASES)))
    sys.exit(1 if fails else 0)
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

print('== D  THE STANDING RULE (F33): every pinned witness declares how it turns red  (#@ turns-red: …)')
#  clause kinds — red:<mutant,…> (a RED line on a mutant of THIS module) · exact:<sNN|captured|…> (a pinned exact value:
#  any change to the computation turns it red; sNN = independently derived in derive/) · fixture:<what> (an in-file bad
#  input the module must refuse) · construction:<constructor> (true by construction: witnesses the constructor, not the
#  claim) · entailed:<tag>.<k>,… (follows from other witnesses) · cannot-fail:<Fnn> / unproven:<Fnn> (a known defect,
#  tracked by an OPEN ledger item). A witness with no declaration, or a declaration that points at nothing, FAILS.
import glob as _glob
_ledger = open('FREEZE-TRACKF.md', encoding='utf-8').read() if os.path.exists('FREEZE-TRACKF.md') else ''
def _open_fid(f):
    m = re.search(r'^\| %s \| (.*)$' % re.escape(f), _ledger, re.M)
    return bool(m) and 'CLOSED' not in m.group(1).split('|')[-2]
_hosttags = set(re.findall(r'(?:^|; )(?:host \S+|static) ([a-z_0-9]+)', GATE, re.M))   # static: F25's source-level witnesses
_redtags = set(re.findall(r'^red ([a-z_0-9]+) ', GATE, re.M))
_wants_by_tag = {}
for _t in re.findall(r'^want ([a-z_0-9]+) ', GATE, re.M): _wants_by_tag[_t] = _wants_by_tag.get(_t, 0) + 1
dflag = 0; counts = {}; weak = []; defect = []
# THE TIE (F33 self-audit, 2026-09-18): a declared red path must be ABOUT this witness. Its red token, with digits and the
# T/F verdict normalised, must appear in the witness (up to its verdict) or share >=18 characters with it — else a red
# line on some OTHER property of the same module could be cited, which is how the rule first shipped (gap found by
# Directive 2: red:lin_m1, a recovery mutant, was accepted for the sharing witness).
from difflib import SequenceMatcher as _SM
_redtoks = {}
for _m in re.finditer(r'^red ([a-z_0-9]+) "((?:[^"\\]|\\.)*)"', GATE, re.M): _redtoks.setdefault(_m.group(1), []).append(_m.group(2))
_wlines = GATE.split('\n')
def _wtok(i):
    m = re.match(r'^want [a-z_0-9]+ "((?:[^"\\]|\\.)*)"', _wlines[i-1]); return m.group(1) if m else ''
def _norm(x): return re.sub(r':[TF]\b', ':?', re.sub(r'\d+', '#', x))
def _tied(w, r):
    nw, nr = _norm(w), _norm(r)
    ks = [k for k in (nr.find(':?'),) if k >= 0]
    stem = nr[:ks[0] + 2] if ks else nr
    if len(stem) >= 6 and stem in nw: return True
    return _SM(None, nw, nr).find_longest_match(0, len(nw), 0, len(nr)).size >= 18
for i, l in enumerate(GATE.split('\n'), 1):
    m = re.match(r'^want ([a-z_0-9]+) "(?:[^"\\]|\\.)*" [A-Za-z_0-9]+(.*)$', l)
    if not m: continue
    tag, tail = m.group(1), m.group(2)
    d = re.search(r'#@ turns-red: (.+)$', tail)
    if not d: print('  L%-4d %-5s NO DECLARATION  <== CHECK' % (i, tag)); dflag += 1; continue
    kinds = set()
    for cl in [c.strip() for c in d.group(1).split('; ') if c.strip()]:
        k, _, v = cl.partition(':'); k = k.strip(); v = v.strip(); kinds.add(k)
        err = ''
        if k == 'red':
            for rt in v.split(','):
                if re.sub(r'_m\d+$', '', rt) != tag: err = 'red:%s is not a mutant of %s' % (rt, tag)
                elif rt not in _hosttags: err = 'red:%s has no host line (nor static line)' % rt
                elif rt not in _redtags: err = 'red:%s has no red line' % rt
                elif not any(_tied(_wtok(i), r) for r in _redtoks.get(rt, [])):
                    err = 'red:%s is NOT TIED to this witness — none of its red tokens overlaps the witness text' % rt
        elif k == 'exact':
            if re.match(r'^s\d\d$', v) and not _glob.glob(os.path.join('derive', v + '_*.py')): err = 'exact:%s has no derive/%s_*.py' % (v, v)
            if not v: err = 'exact: empty'
        elif k == 'entailed':
            for e in v.split(','):
                t2, _, kk = e.partition('.')
                if not kk.isdigit() or _wants_by_tag.get(t2, 0) < int(kk): err = 'entailed:%s points at no witness' % e
        elif k in ('cannot-fail', 'unproven'):
            f = v.split()[0] if v else ''
            if not _open_fid(f): err = '%s:%s is not an OPEN ledger item' % (k, f)
            else: defect.append((i, tag, cl))
        elif k in ('fixture', 'construction'):
            if not v: err = '%s: empty' % k
        else: err = 'unknown clause kind "%s"' % k
        if err: print('  L%-4d %-5s %s  <== CHECK' % (i, tag, err)); dflag += 1
        counts[k] = counts.get(k, 0) + 1
    if not (kinds & {'red', 'fixture'}) and not any(c.startswith('exact:s') for c in d.group(1).split('; ')):
        weak.append((i, tag))
print('  clauses: ' + '  '.join('%s=%d' % kv for kv in sorted(counts.items())))
print('  witnesses carrying a KNOWN DEFECT clause (cannot-fail / unproven): %d' % len(defect))
print('  witnesses with NO red path, NO fixture and NO independent derivation (exact:captured / construction / entailed only): %d' % len(weak))
print('  declaration errors: %d' % dflag); bad += dflag

print('== G  IGNORED PARAMETERS — a glyph that takes an argument and never uses it (the F25 shape: LR_SIG)')
#  Multi-line bodies are read whole; thunks (`la _.`), bare-parameter bodies (Church TRUE/FALSE/K/SEQ) and Scott-case
#  selectors (>=3 handlers, one applied) are excluded. Every remaining hit must be REVIEWED below — citing an OPEN ledger
#  item, or `harmless:` with the reason. An unreviewed hit fails the check. Validated: catches LR_SIG (F25).
REVIEWED_IGNORED = {
    ('lawroot.la', 'LR_SIG', 'g'): 'harmless: the INDEPENDENCE witness it feeds is declared construction-true; the claim is witnessed statically by lrs (F25, 2026-09-18)',
    ('certify.la', 'VERIFY_C', 'g'): 'F36',
    ('syllabus.la', 'SY_NAMES', 'n'): 'harmless: a dead limit parameter — the same 12 is passed again as k',
}
_ID = re.compile(r'[A-Za-z_][A-Za-z0-9_]*')
def _glyph_bodies(src):
    cur = None; buf = []
    for l in src.split('\n'):
        m = re.match(r'^glyph ([A-Za-z0-9_]+)\s*=\s*(.*)$', l)
        if m:
            if cur: yield cur, ' '.join(buf)
            cur, buf = m.group(1), [m.group(2)]
        elif cur and l.startswith((' ', '\t')) and not l.lstrip().startswith('#'): buf.append(l)
        elif cur: yield cur, ' '.join(buf); cur, buf = None, []
    if cur: yield cur, ' '.join(buf)
gflag = 0; ghits = 0
for mod in mods:
    for name, body in _glyph_bodies(open(mod, encoding='utf-8').read()):
        code = re.sub(r'#[^\n]*', '', re.sub(r'"(?:[^"\\]|\\.)*"', '""', body))
        ps = []; rest = code
        while True:
            mm = re.match(r'\s*la\s+([A-Za-z_][A-Za-z0-9_]*)\s*\.\s*(.*)$', rest, re.S)
            if not mm: break
            ps.append(mm.group(1)); rest = mm.group(2)
        if not ps or re.fullmatch(r'\s*[A-Za-z_][A-Za-z0-9_]*\s*', rest): continue
        head = re.match(r'\s*\(?\s*([A-Za-z_][A-Za-z0-9_]*)', rest)
        if head and head.group(1) in ps and len(ps) >= 3: continue
        used = set(_ID.findall(rest))
        for prm in ps:
            if prm == '_' or prm in used: continue
            ghits += 1; rv = REVIEWED_IGNORED.get((mod, name, prm))
            if rv is None: print('  %s: %s ignores its parameter %r — UNREVIEWED  <== CHECK' % (mod, name, prm)); gflag += 1
            elif not rv.startswith('harmless:') and not _open_fid(rv): print('  %s: %s cites %s, which is not OPEN  <== CHECK' % (mod, name, rv)); gflag += 1
            else: print('  %s: %s ignores %r — reviewed: %s' % (mod, name, prm, rv))
print('  hits: %d, unreviewed: %d' % (ghits, gflag)); bad += gflag

print('== R  short red tokens (<10 chars) — prove ABSENT from green output after a run')
for t, k in re.findall(r'^red ([a-z_0-9]+) "((?:[^"\\]|\\.)*)"', GATE, re.M):
    if len(k) < 10: print('  %-8s %r' % (t, k))
sys.exit(1 if bad else 0)
