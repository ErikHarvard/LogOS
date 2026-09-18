# -*- coding: utf-8 -*-
"""Check every `red <mutfile> "<token>"` in gate_registers.sh against the captured mutant output.
A RED path that does not fire is a gate that cannot fail."""
import re,io,os,sys
gate=io.open('gate_registers.sh',encoding='utf-8').read()
reds={}
for m in re.finditer(r'^red\s+(\w+)\s+"((?:[^"\\]|\\.)*)"\s+"((?:[^"\\]|\\.)*)"',gate,re.M):
    tag,tok,label=m.group(1),m.group(2).replace('\\"','"'),m.group(3)
    reds.setdefault(tag,[]).append((tok,label))
only=set(sys.argv[1:]) if len(sys.argv)>1 else None
fired=0; dead=0
for tag,items in sorted(reds.items()):
    p='.mut/%s.out'%tag
    if not os.path.exists(p): continue
    if only and not any(tag.startswith(o) for o in only): continue
    out=io.open(p,encoding='utf-8',errors='replace').read()
    for tok,label in items:
        if tok in out:
            fired+=1; print('  FIRED  %-10s %s' % (tag, label[:88]))
        else:
            dead+=1; print('  !! DEAD %-10s token not found: %s' % (tag, tok[:70]))
            print('           output was: %s' % out[:160].replace('\n',' / '))
print('\n%d RED paths fired, %d DID NOT FIRE'%(fired,dead))
sys.exit(1 if dead else 0)
