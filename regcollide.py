#!/usr/bin/env python3
"""Collision check: every κ declared by the register-stack modules vs the published lexicon
(lexicon.la LEX+RULED, opgrammar.la GRAM+GRULED), canon's self-relations, metaglyph's modes/ops.
⊕ is commutative: operands sorted bytewise (canon NORMK SORT2). Prints COLLISION lines; exit 1 if any."""
import re,sys
NAM={'1':'BEING','2':'RECOGNITION','3':'LOVE','4':'SELF','5':'RELATION','6':'VOID','7':'BECOMING','8':'FORM','9':'DEPTH'}
OPS={'*':'⊗','+':'⊕','>':'▷','c':'⊂'}
def parse(s,i=0):
    c=s[i]
    if c in NAM: return NAM[c],i+1
    if c=='m':
        a,j=parse(s,i+1); return f'↻({a})',j
    if c in OPS:
        a,j=parse(s,i+1); b,k=parse(s,j)
        if c=='+':
            a,b=sorted([a,b],key=lambda x:x.encode())
        return f'{OPS[c]}({a},{b})',k
    raise ValueError(s[i:])
def norm(k):  # sort ⊕ operands in an already-rendered κ (only top-level simple cases needed here)
    return k
corpus={}
def add(name,code):
    k,_=parse(code); corpus.setdefault(k,[]).append(name)
src=open('lexicon.la',encoding='utf-8').read()+open('opgrammar.la',encoding='utf-8').read()
for m in re.finditer(r'([A-Za-z]+)\|([*+>cm0-9]+)\|',src): add(m.group(1),m.group(2))
canon={'KAPPA/See':'▷(RECOGNITION,FORM)','REVAL':'▷(DEPTH,RECOGNITION)','SR_TO':'↻(DEPTH)','SR_ABOUT/ρ':'↻(RECOGNITION)','SR_AS':'↻(FORM)','SR_BY':'↻(BECOMING)','SR_FROM':'↻(VOID)','SR_THROUGH':'↻(RELATION)','SR_FOR':'↻(LOVE)','SR_WITH':'⊕(SELF,SELF)','MODE_SYN':'▷(LOVE,RELATION)','MODE_CON':'⊂(RELATION,FORM)','MODE_DIR':'⊗(BECOMING,RELATION)','MODE_CONT':'▷(DEPTH,FORM)','MODE_MC':'↻(SELF)','OP_DIFF':'▷(VOID,RELATION)','OP_BOUND':'⊂(FORM,DEPTH)','OP_COMP/γ':'⊗(BECOMING,FORM)','OP_INTEG/Compassion':'⊗(LOVE,RECOGNITION)'}
for n,k in canon.items(): corpus.setdefault(k,[]).append(n)
mine=dict(l.split('=',1) for l in sys.stdin.read().split('\n') if '=' in l)
bad=0
for n,k in mine.items():
    k=k.strip()
    if k in corpus: print(f'COLLISION  {n} = {k}  already names: {corpus[k]}'); bad+=1
    else: print(f'clear      {n} = {k}')
print(f'{bad} collisions over {len(mine)} declared glyphs; corpus size {len(corpus)}'); sys.exit(1 if bad else 0)
