# -*- coding: utf-8 -*-
"""Static unbound-name check for a .la module: every identifier it uses must be defined locally,
be a host/VM builtin, or be EXPORTED by a module it imports (transitively). Catches the
"the module I import does not actually export this" class WITHOUT running tiny_host, which matters
because a single host run of a register-stack module costs 1-9 minutes.

  usage:  python3 nameck.py *.la          # prints one line per module; OK or the unbound names
          python3 nameck.py --bind *.la   # every name bound twice, and which binding tiny_host ignores

VALIDATED BOTH WAYS before it was trusted (2026-09-17): green on lineage/registers/wants/gapcensus,
and RED on a copy of lineage.la with one name deliberately broken. An instrument that has only ever
said OK has not been shown to be able to say anything else.

★ KNOWN LIMITATION, so nobody chases a false defect with it: build.sh assembles some modules by
CONCATENATION rather than import --- `cat grammar_l3.la grammar.la .l3_parserlib.la > .l3_run.la`
(build.sh:6262) and `cat canon.la monosemy_test.la > mono_combined.la` (build.sh:7016). Those files
import nothing and resolve their names from whatever is prepended, so this checker reports them as
full of unbound names and IS WRONG ABOUT THEM. Check the combined file, not the fragment.

★ WHAT IT FOUND ON ITS FIRST RUN, which is why it exists: closure.la used HAS_PREFIX, which neither
aatc.la nor glyphdag.la exports (aatc exports STARTS_WITH); and selfevo.la exported SE_RUN, a name
nothing defines. Both were fixed before either module was ever run.
"""
import re,sys,os
# ── THE TWO BUILTIN SETS ARE DERIVED FROM THE SOURCES, not hand-listed: a hand-listed set rots and
# then reports a real name as unbound (or, worse, stops reporting a fake one). HOST = tiny_host.c's
# is_builtin table; VM = secd.asm's name table. The VM set is a SUPERSET in the syscall direction:
# fork/execve/open/... exist on the VM and NOT on the C host, which is why autopoiesis.la and the
# driver modules cannot run under tiny_host at all. Pass --host to check only against the C host,
# --vm to check only against the VM (see the exit-status note at the bottom).
def _from_source(path, pat):
    import re, io, os
    if not os.path.exists(path): return set()
    return set(re.findall(pat, io.open(path, encoding='utf-8', errors='replace').read()))
HOST_BUILTIN = _from_source('tiny_host.c', r'strcmp\(name, "([a-z_0-9]+)"\)')
VM_BUILTIN   = _from_source('secd.asm',    r'db\s*"([a-z_0-9]+)"')
BUILTIN = (HOST_BUILTIN | VM_BUILTIN) or set("""add sub mul div mod lt int_eq str_eq concat print
read_file write_file int_to_str str_to_int str_head str_tail str_len str_at ord chr typeof error""".split())
ID=re.compile(r'[A-Za-z_][A-Za-z0-9_]*')
IMP=re.compile(r'import\("([^"]+)"\)')
GLY=re.compile(r'^glyph\s+([A-Za-z0-9_]+)',re.M)
EXP=re.compile(r'^export\s+(.*)$',re.M)
def strip(src):
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
    return ''.join(out)
def nocomment(src):
    """strip comments but KEEP string contents, so import("x.la") paths survive"""
    out=[];i=0;n=len(src);instr=False
    while i<n:
        c=src[i]
        if instr:
            out.append(c)
            if c=='\\': out.append(src[i+1]); i+=2; continue
            if c=='"': instr=False
            i+=1; continue
        if c=='"': instr=True; out.append(c); i+=1; continue
        if c=='#':
            while i<n and src[i]!='\n': i+=1
            continue
        out.append(c); i+=1
    return ''.join(out)
def exports(path,seen=()):
    if path in seen or not os.path.exists(path): return set()
    src=open(path,encoding='utf-8').read(); code=nocomment(src)
    e=set()
    for m in EXP.finditer(code): e |= set(m.group(1).split())
    return e
def check(path):
    src=open(path,encoding='utf-8').read()
    code=strip(src); paths=nocomment(src)
    local=set(GLY.findall(code))
    avail=set(BUILTIN)|local
    for m in IMP.finditer(paths): avail |= exports(m.group(1))
    # lambda-bound names
    bound=set(re.findall(r'\bla\s+([A-Za-z_][A-Za-z0-9_]*)',code))
    avail |= bound
    bad={}
    for ln,line in enumerate(code.split('\n'),1):
        for tok in ID.findall(line):
            if tok in ('la','glyph','import','export'): continue
            if tok not in avail: bad.setdefault(tok,ln)
    return bad
# ── --bind: THE IDENTITY LAW AT CODE LEVEL (FP:311 "a variable holds one value at a time"; S19 §2) ──
# tiny_host keeps the FIRST binding of a name, in FILE ORDER, imports included — MEASURED 2026-09-25 by running:
#   dup in one file → the first wins;  local glyph AFTER an import exporting it → the IMPORT wins (the local is dead);
#   local glyph BEFORE that import → the LOCAL wins (the import's export is dead here).
# None of these errors. A mutant that redefines an imported glyph therefore NEVER FIRES — the trap that already cost
# vacuous mutants. --bind reports every name bound twice and which binding is dead; rc 1 if a dead binding is a
# DIFFERENT term (α-equal and REVIEWED ones are reported, not failed).
def _defn(path, name, seen=()):
    """(defining module, normalised body) of an EXPORTED/defined name, following re-exports to their origin"""
    if path in seen or not os.path.exists(path): return (path, None)
    code = nocomment(open(path, encoding='utf-8').read())
    m = re.search(r'^glyph\s+%s\s*=(.*?)(?=^\S)' % re.escape(name), code + '\nEND', re.M | re.S)
    if m: return (path, ' '.join(m.group(1).split()))
    for im in IMP.finditer(code):
        if name in exports(im.group(1)): return _defn(im.group(1), name, seen + (path,))
    return (path, None)
def _local(path, name, line):
    """the body of the glyph defined at a given line of this file"""
    lines = nocomment(open(path, encoding='utf-8').read()).split('\n')
    body = [lines[line - 1].split('=', 1)[1]]
    for l in lines[line:]:
        if re.match(r'\S', l): break
        body.append(l)
    return (path, ' '.join(' '.join(body).split()))
def _alpha(body):
    """α-normalise a body: each `la X.` binder, in order of appearance, becomes v0, v1, … (a flat renaming —
    sound for the constructor/helper definitions it is used on, which never re-bind a name)"""
    names = re.findall(r'\bla\s+([A-Za-z_][A-Za-z0-9_]*)\s*\.', body); ren = {}
    for n in names: ren.setdefault(n, 'v%d' % len(ren))
    return re.sub(r'\b[A-Za-z_][A-Za-z0-9_]*\b', lambda m: ren.get(m.group(0), m.group(0)), body)
# REVIEWED: pairs whose two definitions differ in TEXT but are the same term, each with the reason it was checked.
REVIEWED = {
    ('COLLAPSE', 'canon.la', 'metaglyph.la'): 'metaglyph.la:79 SEAL = la et. MONO(CANON(et))(et), which canon.la inlines (checked 2026-09-25)',
}
def _same(a, b):
    if a[1] is None or b[1] is None: return False
    return a[1] == b[1] or _alpha(a[1]) == _alpha(b[1])
def bindings(path):
    src=open(path,encoding='utf-8').read(); code=nocomment(src)
    first={}; first_src={}; out=[]
    for ln,line in enumerate(code.split('\n'),1):
        m=re.match(r'\s*glyph\s+([A-Za-z0-9_]+)',line)
        if m:
            n=m.group(1)
            if n in first:
                live = _defn(first_src[n][0], n) if first_src[n][0] else _local(path, n, first_src[n][1])
                dead = _local(path, n, ln)
                out.append('%s(line %d) DEAD — %s — %s' % (n, ln, first[n], 'same text as the live one' if _same(live, dead) else '★ DIFFERENT from the live one'))
            else: first[n]='bound first at line %d' % ln; first_src[n]=(None, ln)
            continue
        for im in IMP.finditer(line):
            for n in sorted(exports(im.group(1))):
                if n in first:
                    if first[n].startswith('imported from %s' % im.group(1)): continue   # the same module twice: identical
                    live = _defn(first_src[n][0], n) if first_src[n][0] else _local(path, n, first_src[n][1])
                    dead = _defn(im.group(1), n)
                    out.append('%s DEAD from import("%s") at line %d — %s — %s' % (n, im.group(1), ln, first[n], 'same definition (%s)' % live[0] if (_same(live, dead) or live[0] == dead[0]) else ('reviewed: ' + REVIEWED[(n, live[0], dead[0])]) if (n, live[0], dead[0]) in REVIEWED else '★ DIFFERENT definition (%s vs %s)' % (live[0], dead[0])))
                else: first[n]='imported from %s at line %d' % (im.group(1), ln); first_src[n]=(im.group(1), ln)
    return out

# --host / --vm check against ONE side's builtins only. --vm is the pre-flight for a VM leg: a module
# that uses a host-only builtin (typeof) passes the default check and then fails on the SECD VM.
# ★ EXIT STATUS: 1 if any module has an unbound name, else 0. Until 2026-09-18 it exited 0 always, so
# `nameck.py f.la || echo FAIL` could never fire and a sweep reported clean over five flagged files.
args=sys.argv[1:]
if '--host' in args: BUILTIN=HOST_BUILTIN
if '--vm' in args:   BUILTIN=VM_BUILTIN
rc=0
if '--bind' in args:
    for f in [a for a in args if not a.startswith('--')]:
        b=bindings(f)
        if any('★' in x for x in b): rc=1      # rc 1 only for a DIFFERENT term: same / α-equal / reviewed is dead but harmless
        print('%-16s %s' % (f, 'OK' if not b else 'DOUBLE-BOUND: '+'; '.join(b)))
    sys.exit(rc)
for f in [a for a in args if a not in ('--host','--vm')]:
    bad=check(f)
    if bad: rc=1
    print('%-16s %s' % (f, 'OK' if not bad else 'UNBOUND: '+', '.join('%s(line %d)'%(k,v) for k,v in sorted(bad.items()))))
sys.exit(rc)
