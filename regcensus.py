#!/usr/bin/env python3
"""Glyph-table census: glyphs loaded into tiny_host's fixed 1024-entry table for a .la file.
Every import OCCURRENCE loads the imported module's whole tree again (tiny_host.c do_import)."""
import re, sys, os
IMP = re.compile(r'import\("([^"]+)"\)')
GLY = re.compile(r'^glyph\s+[A-Za-z0-9_]+', re.M)
def count(path, seen_stack=()):
    src = open(path, encoding='utf-8').read()
    own = len(GLY.findall(src))
    # strip comments for import detection
    code = '\n'.join(l.split('#',1)[0] for l in src.splitlines())
    total = own
    parts = []
    for m in IMP.finditer(code):
        dep = m.group(1)
        if dep in seen_stack: continue
        sub, _ = count(dep, seen_stack + (path,))
        total += sub; parts.append(f"{dep}={sub}")
    return total, f"{os.path.basename(path)} own={own} imports[{' '.join(parts)}] TOTAL={total}"
for f in sys.argv[1:]:
    t, desc = count(f); print(desc, "OVER-1024" if t > 1024 else "")
