# -*- coding: utf-8 -*-
"""Compare every `want <tag> "<token>"` in gate_registers.sh against the captured module output.
This is the gate's own assertion set, checked without re-running the suite."""
import re,io,os,sys
gate=io.open('gate_registers.sh',encoding='utf-8').read()
# tag -> module, from the `host <module>.la <tag>` lines
host=dict((m.group(2),m.group(1)) for m in re.finditer(r'^host\s+(\S+?)\.la\s+(\w+)\s*$',gate,re.M))
wants={}
for m in re.finditer(r'^want\s+(\w+)\s+"((?:[^"\\]|\\.)*)"',gate,re.M):
    tag,tok=m.group(1),m.group(2).replace('\\"','"').replace('\\\\','\\')
    wants.setdefault(tag,[]).append(tok)
only=set(sys.argv[1:]) if len(sys.argv)>1 else None
fails=0; checked=0
for tag,toks in sorted(wants.items()):
    mod=host.get(tag)
    if not mod: continue
    if only and mod not in only: continue
    p='.runout/%s.out'%mod
    if not os.path.exists(p) or os.path.getsize(p)==0:
        print('  %-18s NO OUTPUT (still running or never run)'%mod); continue
    out=io.open(p,encoding='utf-8',errors='replace').read()
    bad=[t for t in toks if t not in out]
    checked+=len(toks)
    if bad:
        fails+=len(bad)
        print('  %-18s %d/%d MISSING:'%(mod,len(bad),len(toks)))
        for t in bad: print('      - %s'%t[:150])
    else:
        print('  %-18s %d/%d witnesses PRESENT'%(mod,len(toks),len(toks)))
print('\n%d witness tokens checked, %d missing'%(checked,fails))
sys.exit(1 if fails else 0)
