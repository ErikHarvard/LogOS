#!/usr/bin/env python3
"""Per-definition paren balance for .la files, ignoring comments and string contents."""
import sys,re
src=open(sys.argv[1],encoding='utf-8').read()
out=[];i=0;n=len(src);instr=False
while i<n:
    c=src[i]
    if instr:
        if c=='\\': i+=2; continue
        if c=='"': instr=False
        i+=1; continue
    if c=='"': instr=True; out.append(' '); i+=1; continue
    if c=='#':
        while i<n and src[i]!='\n': i+=1
        continue
    out.append(c); i+=1
clean=''.join(out)
# split into top-level definitions
defs=re.split(r'(?m)^(?=glyph |import\(|export )',clean)
bad=0
for d in defs:
    if not d.strip(): continue
    b=d.count('(')-d.count(')')
    if b!=0:
        bad+=1; print(f"UNBALANCED {b:+d}: {d.strip().splitlines()[0][:90]}")
print("all balanced" if not bad else f"{bad} unbalanced")
