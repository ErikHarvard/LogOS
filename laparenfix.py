#!/usr/bin/env python3
"""Adjust trailing ')' runs of unbalanced glyph definitions by the checker's delta (strings/comments ignored)."""
import sys,re,subprocess
p=sys.argv[1]
out=subprocess.run(['python3',sys.argv[0].replace('laparenfix','laparen'),p],capture_output=True,text=True).stdout
src=open(p,encoding='utf-8').read()
for m in re.finditer(r'UNBALANCED ([+-]\d+): glyph (\w+)',out):
    delta=int(m.group(1)); name=m.group(2)
    # find the definition block
    i=src.index('\nglyph '+name+' =')+1
    j=re.search(r'\n(?=glyph |import\(|export |#|$)', src[i:]+'\n')
    block=src[i:i+j.start()] if j else src[i:]
    stripped=block.rstrip()
    if delta<0:   # too many ')': remove -delta trailing ')'
        n=-delta; assert stripped.endswith(')'*n), name
        newblock=stripped[:-n]+block[len(stripped):]
    else:
        newblock=stripped+')'*delta+block[len(stripped):]
    src=src[:i]+newblock+src[i+len(block):]
    print(f"{name}: adjusted {delta:+d}")
open(p,'w',encoding='utf-8').write(src)
