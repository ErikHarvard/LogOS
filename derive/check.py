# -*- coding: utf-8 -*-
"""F20 checker: run every derive/sNN_*.py, and compare each `WANT <tag> <token>` it prints with the gate's pinned
`want <tag> "<token>"` lines. Every pinned token of a derived section must be REPRODUCED EXACTLY by its derivation.
Reports MATCH / MISMATCH / NOT-DERIVED per pinned line; rc 1 on any mismatch, or if nothing was compared.
  usage: python3 derive/check.py [sNN ...]"""
import re, os, sys, subprocess, glob, io
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(HERE)
gate = io.open(os.path.join(ROOT, 'gate_registers.sh'), encoding='utf-8').read()
pinned = {}
for m in re.finditer(r'^want (\w+) "((?:[^"\\]|\\.)*)"', gate, re.M):
    pinned.setdefault(m.group(1), []).append(m.group(2).replace('\\"', '"'))
scripts = sorted(glob.glob(os.path.join(HERE, 's[0-9][0-9]_*.py')))
if sys.argv[1:]: scripts = [s for s in scripts if any(os.path.basename(s).startswith(a) for a in sys.argv[1:])]
match = mism = notd = 0
for s in scripts:
    out = subprocess.run([sys.executable, s], capture_output=True, text=True)
    if out.returncode != 0: print('  !! %s crashed: %s' % (os.path.basename(s), out.stderr.strip()[-200:])); mism += 1; continue
    derived = {}
    for line in out.stdout.split('\n'):
        if line.startswith('WANT '):
            _, tag, tok = line.split(' ', 2); derived.setdefault(tag, []).append(tok)
        elif line.startswith('NOTE '): print('  NOTE   %s' % line[5:])
    for tag, toks in derived.items():
        for p in pinned.get(tag, []):
            if p in toks: match += 1; print('  MATCH     %-5s %s' % (tag, p[:100]))
            elif any(p in t or t in p for t in toks): mism += 1; print('  !! MISMATCH %-5s pinned : %s\n                  derived: %s' % (tag, p[:100], [t for t in toks if p in t or t in p][0][:100]))
            else: notd += 1; print('  NOT-DERIVED %-5s %s' % (tag, p[:100]))
        for t in toks:
            if t not in pinned.get(tag, []) and not any(t in p or p in t for p in pinned.get(tag, [])):
                mism += 1; print('  !! DERIVED BUT NOT PINNED %-5s %s' % (tag, t[:100]))
print('\n%d pinned tokens reproduced by an independent derivation; %d MISMATCH; %d not yet derived (in derived sections)' % (match, mism, notd))
sys.exit(1 if (mism or not match) else 0)
