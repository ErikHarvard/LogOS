# -*- coding: utf-8 -*-
"""Check every `red <mutant-tag> "<token>"` in gate_registers.sh against captured outputs, BOTH halves:
  (1) the token IS in the mutant's output  — a RED path that does not fire is a gate that cannot fail;
  (2) the token is NOT in the GREEN output of the same module (base tag = mutant tag minus _mN) — a token the
      green run already prints fires whether or not the mutant changed anything: a VACUOUS RED.
A missing capture is a FAILURE (MISSING), never a skip: an instrument that reports "0 dead" over outputs it never
read has not looked. (Both halves and the missing-is-failure rule added 2026-09-18, FREEZE-TRACKF.md F16.)

  usage:  python3 checkreds.py --dir KEEPDIR [tag-prefix ...]   # a REGS_KEEP dir: files named by tag
          python3 checkreds.py [tag-prefix ...]                 # legacy: .mut/<tag>.out + .runout/<module>.out
"""
import re, io, os, sys
gate = io.open('gate_registers.sh', encoding='utf-8').read()
args = sys.argv[1:]; kdir = None
if args[:1] == ['--dir']: kdir = args[1]; args = args[2:]
only = set(args) or None
host = dict((m.group(2), m.group(1)) for m in re.finditer(r'^host\s+(\S+?)\.la\s+(\w+)\s*$', gate, re.M))
host.update((m.group(1), m.group(2)) for m in re.finditer(r'^static\s+(\w+)\s+\S+\s+(\S+?)\.la\b', gate, re.M))   # static witnesses (F25)
def path_for(tag, green):
    if kdir: return os.path.join(kdir, tag)
    return ('.runout/%s.out' % host.get(tag, tag)) if green else ('.mut/%s.out' % tag)
def read(p):
    return io.open(p, encoding='utf-8', errors='replace').read() if os.path.exists(p) and os.path.getsize(p) > 0 else None
reds = []
for m in re.finditer(r'^red\s+(\w+)\s+"((?:[^"\\]|\\.)*)"\s+"((?:[^"\\]|\\.)*)"', gate, re.M):
    reds.append((m.group(1), m.group(2).replace('\\"', '"').replace('\\\\', '\\'), m.group(3)))
fired = dead = vacuous = missing = 0
for tag, tok, label in reds:
    if only and not any(tag.startswith(o) for o in only): continue
    base = re.sub(r'_m\d+$', '', tag)
    mut, green = read(path_for(tag, False)), read(path_for(base, True))
    if mut is None:   missing += 1; print('  !! MISSING  %-9s no mutant output at %s' % (tag, path_for(tag, False))); continue
    if green is None: missing += 1; print('  !! MISSING  %-9s no GREEN output for %s at %s' % (tag, base, path_for(base, True))); continue
    if tok not in mut:
        dead += 1; print('  !! DEAD     %-9s token not in mutant output: %s' % (tag, tok[:70]))
    elif tok in green:
        vacuous += 1; print('  !! VACUOUS  %-9s token already in GREEN output of %s: %s' % (tag, base, tok[:70]))
    else:
        fired += 1; print('  FIRED      %-9s %s' % (tag, label[:88]))
print('\n%d RED paths fired and discriminate; %d DID NOT FIRE; %d VACUOUS (in green too); %d MISSING an output'
      % (fired, dead, vacuous, missing))
sys.exit(1 if (dead or vacuous or missing or not fired) else 0)
