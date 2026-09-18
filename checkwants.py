# -*- coding: utf-8 -*-
"""Compare every `want <tag> "<token>"` in gate_registers.sh against the captured module output.
This is the gate's own assertion set, checked without re-running the suite.
A module with NO captured output is a FAILURE (its witnesses count as unchecked), never a pass: rc 0 with nothing
checked was possible before 2026-09-18 (FREEZE-TRACKF.md F17).

  usage:  python3 checkwants.py --dir KEEPDIR [module ...]   # a REGS_KEEP dir: files named by tag
          python3 checkwants.py [module ...]                 # legacy: .runout/<module>.out
"""
import re, io, os, sys
gate = io.open('gate_registers.sh', encoding='utf-8').read()
args = sys.argv[1:]; kdir = None
if args[:1] == ['--dir']: kdir = args[1]; args = args[2:]
only = set(args) or None
# tag -> module, from the `host <module>.la <tag>` lines
host = dict((m.group(2), m.group(1)) for m in re.finditer(r'^host\s+(\S+?)\.la\s+(\w+)\s*$', gate, re.M))
wants = {}
for m in re.finditer(r'^want\s+(\w+)\s+"((?:[^"\\]|\\.)*)"', gate, re.M):
    tag, tok = m.group(1), m.group(2).replace('\\"', '"').replace('\\\\', '\\')
    wants.setdefault(tag, []).append(tok)
fails = 0; checked = 0; unread = 0
for tag, toks in sorted(wants.items()):
    mod = host.get(tag)
    if not mod: fails += len(toks); print('  %-18s want tag %s has no host line' % ('?', tag)); continue
    if only and mod not in only: continue
    p = os.path.join(kdir, tag) if kdir else '.runout/%s.out' % mod
    if not os.path.exists(p) or os.path.getsize(p) == 0:
        unread += len(toks); print('  %-18s NO OUTPUT at %s — %d witnesses UNCHECKED' % (mod, p, len(toks))); continue
    out = io.open(p, encoding='utf-8', errors='replace').read()
    bad = [t for t in toks if t not in out]
    checked += len(toks)
    if bad:
        fails += len(bad)
        print('  %-18s %d/%d MISSING:' % (mod, len(bad), len(toks)))
        for t in bad: print('      - %s' % t[:150])
    else:
        print('  %-18s %d/%d witnesses PRESENT' % (mod, len(toks), len(toks)))
print('\n%d witness tokens checked, %d missing, %d UNCHECKED (no output)' % (checked, fails, unread))
sys.exit(1 if (fails or unread or not checked) else 0)
