# -*- coding: utf-8 -*-
"""§13 derive_closure derivation (2026-09-26, F20) — the "nine→lexicon" witness, WITHOUT the LA code.
The "lexicon" here is familytree.la's CAT (the catalogue of named operations: KAPPA, REVAL, the eight SR_*, the five
MODE_*, the five OP_*, NU_STAR), not the 79-row word tables. Each entry names a glyph; this script resolves every name to
its κ-tree FROM SOURCE TEXT — parsing the `glyph NAME = …` definitions of canon.la, metaglyph.la and familytree.la (the
modules familytree imports, in its import order) — and counts an entry grounded when every leaf is PRIM(one of the nine),
as G1GO/BADLEAF define it. A name that resolves to nothing, or an expression this parser cannot read, is an ERROR (rc 2),
never a silent pass.
Not derived: the dyad-stratum line (VOID=0, BECOMING=succ, …) — those are Church-numeral evaluations of dyadseed.la, and
restating them in python would be a second implementation of the same arithmetic, not an independent reading."""
import os, re, sys
ROOT = os.environ.get('LA_ROOT') or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NINE = {"BEING", "RECOGNITION", "LOVE", "SELF", "RELATION", "VOID", "BECOMING", "FORM", "DEPTH"}
BIN = {'SYN', 'CON', 'DIR', 'CONT'}

def defs(path):
    """name → body text of every top-level glyph (FIRST binding kept, as tiny_host does), comments stripped"""
    out = {}; cur = None
    for line in open(os.path.join(ROOT, path), encoding='utf-8'):
        line = re.sub(r'#.*', '', line.rstrip('\n')) if '"' not in line.split('#', 1)[0] or line.count('"') % 2 == 0 else line
        m = re.match(r'glyph\s+(\S+)\s*=(.*)', line)
        if m: cur = m.group(1); out.setdefault(cur, ''); out[cur] += m.group(2) if out[cur] == '' else ''
        elif cur and re.match(r'\s', line) and line.strip(): out[cur] += ' ' + line.strip()
        elif line.strip(): cur = None
    return out
TABLE = {}
for f in ('canon.la', 'metaglyph.la', 'familytree.la'):          # familytree imports canon, then metaglyph; first wins
    for k, v in defs(f).items(): TABLE.setdefault(k, v)

def tokens(s): return re.findall(r'"(?:[^"\\]|\\.)*"|[A-Za-z_][A-Za-z0-9_]*|[()]', s)
def parse(s, depth=0):
    """expr := atom ('(' expr ')')* — application chains over PRIM/SYN/CON/DIR/CONT/MC and glyph names"""
    if depth > 50: raise ValueError('reference cycle')
    toks = tokens(s); pos = [0]
    def expr():
        t = toks[pos[0]]; pos[0] += 1
        head = t; args = []
        while pos[0] < len(toks) and toks[pos[0]] == '(':
            pos[0] += 1; args.append(expr())
            if toks[pos[0]] != ')': raise ValueError('unbalanced in %r' % s)
            pos[0] += 1
        if head == 'PRIM' and len(args) == 1 and isinstance(args[0], str): return ('P', args[0])
        if head in BIN and len(args) == 2: return (head, args[0], args[1])
        if head == 'MC' and len(args) == 1: return ('MC', args[0])
        if head.startswith('"') and not args: return head[1:-1]
        if not args and head in TABLE: return parse(TABLE[head], depth + 1)
        raise ValueError('cannot read %s%s' % (head, '(…)' * len(args)))
    t = expr()
    if pos[0] != len(toks): raise ValueError('trailing tokens in %r' % s)
    return t
def badleaf(t):
    if t[0] == 'P': return '' if t[1] in NINE else t[1]
    for x in t[1:]:
        b = badleaf(x)
        if b: return b
    return ''

cat = TABLE.get('CAT', '')
entries = re.findall(r'PAIR\("([^"]+)"\)\(((?:[^()]|\((?:[^()]|\((?:[^()]|\([^()]*\))*\))*\))*)\)\)\(', cat)
try:
    trees = [(nm, parse(ex)) for nm, ex in entries]
except (ValueError, IndexError) as e:
    print('ERROR %s' % e); sys.exit(2)
n = len(trees); cnt = sum(1 for _, t in trees if badleaf(t) == '')
if __name__ == '__main__':
    if n != cat.count('PAIR('): print('ERROR read %d entries but CAT holds %d PAIR(' % (n, cat.count('PAIR('))); sys.exit(2)
    for nm, t in trees:
        if badleaf(t): print('NOTE ungrounded: %s/%s' % (nm, badleaf(t)))
    print('WANT dcl nine→lexicon: grounded=%d/%d:%s' % (cnt, n, 'T' if cnt == n else 'F'))
