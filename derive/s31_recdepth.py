# -*- coding: utf-8 -*-
"""§31 recdepth derivation (2026-09-26, F20): the catalogue census and the "existing level" probe, WITHOUT the LA code.
recdepth.la's gate header says its witnesses were "derived independently (a python re-implementation of the tex definition
over the same catalogue) BEFORE this gate was written" — that script was never saved, so freezeck counts the two lines
exact:captured. This is one, on disk.
  catalogue  RD_CAT's 35 entries, each resolved FROM SOURCE TEXT (recdepth.la, lineage.la, canon.la, metaglyph.la):
             GLYPH("X") and P/Px/PRIM("X") are leaves, SEALc(t) carries t, names resolve to their first binding
  κ          lacore.normk (the independent NORMK model); κ-distinct = entries with distinct κ-strings (N_DISTINCT)
  order      0 for a leaf; otherwise 1 + the max order of catalogue entries whose κ is a PROPER sub-form of it (every
             sub-tree below the root, each normalised) — by RD_PASSES=4 relaxation passes from all-zero, as RELAX does
  ρ(L_t)     the max order; the probe adds ⊕(BEING,LOVE) as a new entry and recomputes ρ
  cited      STRICTER than the module's line read-back: every *_F form recdepth.la cites (the five MODE_*, five OP_*,
             NU_STAR, G_DR, G_DB) is compared as a TREE with the definition in its own module"""
import os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lacore import normk
ROOT = os.environ.get('LA_ROOT') or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BIN = {'SYN', 'CON', 'DIR', 'CONT'}
LEAF = {'P', 'Px', 'PRIM', 'GLYPH'}

def defs(path):
    """name → body of every top-level glyph (FIRST binding kept), trailing # comments outside strings removed"""
    out, cur = {}, None
    for line in open(os.path.join(ROOT, path), encoding='utf-8'):
        line = line.rstrip('\n'); code, q = '', False
        for ch in line:
            if ch == '"': q = not q
            if ch == '#' and not q: break
            code += ch
        m = re.match(r'glyph\s+(\S+)\s*=(.*)', code)
        if m:
            cur = m.group(1) if m.group(1) not in out else None
            if cur: out[cur] = m.group(2)
        elif cur and re.match(r'\s', code) and code.strip(): out[cur] += ' ' + code.strip()
        elif code.strip(): cur = None
    return out
def table(files):
    t = {}
    for f in files:
        for k, v in defs(f).items(): t.setdefault(k, v)
    return t

def tokens(s): return re.findall(r'"(?:[^"\\]|\\.)*"|[A-Za-z_][A-Za-z0-9_]*|[()]', s)
def parse(s, T, depth=0):
    if depth > 60: raise ValueError('reference cycle')
    toks = tokens(s); pos = [0]
    def expr():
        head = toks[pos[0]]; pos[0] += 1; args = []
        while pos[0] < len(toks) and toks[pos[0]] == '(':
            pos[0] += 1; args.append(expr())
            if toks[pos[0]] != ')': raise ValueError('unbalanced in %r' % s)
            pos[0] += 1
        if head.startswith('"') and not args: return head[1:-1]
        if head in LEAF and len(args) == 1 and isinstance(args[0], str): return ('P', args[0])
        if head in BIN and len(args) == 2: return (head, args[0], args[1])
        if head == 'MC' and len(args) == 1: return ('MC', args[0])
        if head in ('SEALc', 'GLYPHOF') and len(args) == 1: return args[0]
        if head == 'COLLAPSE' and len(args) == 3 and args[0] in BIN: return (args[0], args[1], args[2])
        if head in BIN and not args: return head                       # an operator passed as a value (COLLAPSE(SYN))
        if not args and head in T: return parse(T[head], T, depth + 1)
        raise ValueError('cannot read %s%s' % (head, '(…)' * len(args)))
    t = expr()
    if pos[0] != len(toks): raise ValueError('trailing tokens in %r' % s)
    return t

def subforms(t):                                       # every sub-tree strictly below the root
    out = []
    for x in t[1:]:
        if isinstance(x, tuple): out.append(x); out += subforms(x)
    return out
def census(cat):
    ent = [(nm, normk(f), f[0] == 'P', {normk(s) for s in subforms(f)}) for nm, f in cat]
    distinct = {}
    for e in ent: distinct[e[1]] = e                   # κ-keyed; which duplicate survives does not change any order
    c0 = list(distinct.values())
    ords = {k: 0 for k in distinct}
    for _ in range(4):                                 # RD_PASSES
        ords = {k: 0 if leaf else 1 + max([ords[k2] for k2 in ords if k2 in subs] + [0])
                for k, (_, _, leaf, subs) in ((e[1], e) for e in c0)}
    return len(ent), len(c0), ords

T = table(['recdepth.la', 'lineage.la', 'canon.la', 'metaglyph.la'])
body = T.get('RD_CAT', '')
items = re.findall(r'PAIRc\("([^"]+)"\)\(', body)
try:
    cat = []
    for nm in items:                                   # each entry's expression: the balanced group after PAIRc("nm")
        i = body.index('PAIRc("%s")(' % nm) + len('PAIRc("%s")(' % nm); d = 1; j = i
        while d: d += {'(': 1, ')': -1}.get(body[j], 0); j += 1
        cat.append((nm, parse(body[i:j - 1], T)))
except (ValueError, IndexError) as e:
    print('ERROR %s' % e); sys.exit(2)

n, nd, ords = census(cat)
rho = max(ords.values())
cnt = [sum(1 for v in ords.values() if v == k) for k in range(4)]
_, _, ords_s = census([('SAME', ('CON', ('P', 'BEING'), ('P', 'LOVE')))] + cat)
rho_s = max(ords_s.values())

CITED = [('MODE_SYN_F', 'metaglyph.la', 'MODE_SYN'), ('MODE_CON_F', 'metaglyph.la', 'MODE_CON'),
         ('MODE_DIR_F', 'metaglyph.la', 'MODE_DIR'), ('MODE_CONT_F', 'metaglyph.la', 'MODE_CONT'),
         ('MODE_MC_F', 'metaglyph.la', 'MODE_MC'), ('OP_DIFF_F', 'metaglyph.la', 'OP_DIFF'),
         ('OP_BOUND_F', 'metaglyph.la', 'OP_BOUND'), ('OP_COMP_F', 'metaglyph.la', 'OP_COMP'),
         ('OP_RECOG_F', 'metaglyph.la', 'OP_RECOG'), ('OP_INTEG_F', 'metaglyph.la', 'OP_INTEG'),
         ('NU_STAR_F', 'modegenesis.la', 'NU_STAR_C'), ('G_DR_F', 'regenesis.la', 'G_DR'), ('G_DB_F', 'branchgenesis.la', 'G_DB')]
bad = []
for local, mod, name in CITED:
    try:
        MT = table([mod, 'metaglyph.la', 'canon.la', 'lineage.la'])
        if parse(T[local], T) != parse(MT[name], MT): bad.append('%s≠%s:%s' % (local, mod, name))
    except (ValueError, KeyError, IndexError) as e: bad.append('%s: %s' % (local, e))

if __name__ == '__main__':
    for b in bad: print('NOTE cited form does not read back: %s' % b)
    print('WANT rd RECDEPTH catalogue entries=%d κ-distinct=%d | orders n0=%d n1=%d n2=%d n3=%d | ρ(L_t)=%d | cited forms read back from their modules:%s'
          % (n, nd, cnt[0], cnt[1], cnt[2], cnt[3], rho, 'T' if not bad else 'F'))
    print('WANT rd add ⊕(BEING,LOVE) at an existing level: ρ→%d unmoved:%s' % (rho_s, 'T' if rho_s == rho else 'F'))
