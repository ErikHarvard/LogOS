import re,sys
def check(f,name,buf,ln):
    t=re.sub(r'"[^"]*"','""','\n'.join(buf))
    t=re.sub(r'#.*','',t)
    d=t.count('(')-t.count(')')
    if d: print("%s:%d  glyph %-12s balance %+d" % (f,ln,name,d))
    return d
for f in sys.argv[1:]:
    s=open(f).read(); cur=None; buf=[]; ln=0; bad=0
    for i,l in enumerate(s.split('\n'),1):
        if l.startswith('glyph '):
            if cur: bad+=abs(check(f,cur,buf,ln))
            cur=l.split()[1]; buf=[l]; ln=i
        elif cur is not None: buf.append(l)
    if cur: bad+=abs(check(f,cur,buf,ln))
    print("%s: %s" % (f, "BALANCED" if bad==0 else "UNBALANCED"))
