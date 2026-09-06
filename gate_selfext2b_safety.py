#!/usr/bin/env python3
"""
gate_selfext2b_safety.py — THE PRECONDITION FOR STAGE 2b, CHECKED MECHANICALLY.

Stage 2b requires the exec to originate INSIDE the organ: fork + execve, which
are VM-only builtins. So the organ runs on the VM, which means the organ lives
in `logos_program.bin` -- and CLAUDE.md rule 2 is about exactly that file:

    "Never run ./logos_secd while logos_program.bin holds an orchestrator.
     The VM re-executes whatever is at that one fixed path, so the orchestrator
     runs the orchestrator, forking at every level. This has happened for real:
     148,121 processes, load 27."

An organ that execve's `./logos_secd` IS that bomb, because the organ is what
`logos_program.bin` holds. And `execve(path)` takes NO arguments (argv=[path]),
so the organ cannot ask a tool to read some other file -- every exec target must
already read fixed paths.

★ THE STRUCTURAL FIX, not a promise to be careful: the organ may execve ONLY
self-contained BUNDLES and argument-free TOOLS, never the generic VM loader. A
bundle carries its program embedded and never reads `logos_program.bin`, which
is exactly why autopoiesis.la "must run as a bundle" -- the child's code is
fixed at bundle time, so no re-entry is possible.

★★ AND A CAP, because a structural argument is still an argument. The organ must
carry a generation cap read from a medium, so even a mistaken chain terminates.

This gate asserts both, and self-tests: an injected forbidden exec must turn it
red, or a scan that finds nothing is indistinguishable from a scan whose
patterns match nothing.
"""
import re, os, sys, glob

REPO = os.path.dirname(os.path.abspath(__file__))
ORGANS = ['selfext2b.la']

FORBIDDEN = ('logos_secd',)                  # the generic VM loader: re-entry
ALLOWED   = ('compiler.bin', 'bundler.bin', 'sx2b_app', 'logos_app')
CAP_MARK  = '.sx2b_gen'                      # the medium the cap is read from

def scan(src_of):
    bad, targets, caps = [], [], []
    for name in ORGANS:
        s = src_of.get(name)
        if s is None:
            continue
        for i, line in enumerate(s.split('\n'), 1):
            if line.lstrip().startswith('#'):
                continue
            for m in re.finditer(r'execve\(\s*"([^"]*)"\s*\)', line):
                t = m.group(1)
                targets.append((name, i, t))
                if any(f in t for f in FORBIDDEN):
                    bad.append((name, i, t, 'FORBIDDEN: the generic VM loader — '
                                'this is CLAUDE.md rule 2, the 148,121-process bomb'))
                elif not any(a in t for a in ALLOWED):
                    bad.append((name, i, t, 'not in the allowlist of self-contained '
                                'bundles / argument-free tools'))
            for m in re.finditer(r'execve\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)', line):
                targets.append((name, i, '<var:%s>' % m.group(1)))
                bad.append((name, i, m.group(1), 'exec target is a VARIABLE — it cannot '
                            'be checked statically, so it cannot be permitted'))
        if CAP_MARK in s:
            caps.append(name)
    return bad, targets, caps

def load():
    d = {}
    for p in glob.glob(os.path.join(REPO, '*.la')):
        d[os.path.basename(p)] = open(p, encoding='utf-8', errors='replace').read()
    return d

def selftest(src_of):
    probe = dict(src_of)
    probe['selfext2b.la'] = (probe.get('selfext2b.la', '') +
                             '\nglyph BOOM = execve("./logos_secd")\n')
    bad, _, _ = scan(probe)
    if not any('FORBIDDEN' in b[3] for b in bad):
        print('FAIL  gate_selfext2b_safety: an INJECTED execve of the generic VM '
              'loader was NOT detected. The scan cannot go red and is asserting '
              'nothing — which is the worst possible state for a bomb guard.')
        return False
    return True

def main():
    src_of = load()
    if not selftest(src_of):
        return 1
    present = [o for o in ORGANS if o in src_of]
    if not present:
        print('PASS  gate_selfext2b_safety: stage 2b is not built yet (%s absent), so '
              'there is no exec surface to guard. Red path exercised — the guard is '
              'armed and will fire the moment an organ execs the VM loader.'
              % ', '.join(ORGANS))
        return 0
    bad, targets, caps = scan(src_of)
    if bad:
        print('FAIL  gate_selfext2b_safety: forbidden or uncheckable exec target(s):')
        for n, i, t, why in bad:
            print('  %s:%d  execve(%s)  — %s' % (n, i, t, why))
        return 1
    missing = [o for o in present if o not in caps]
    if missing:
        print('FAIL  gate_selfext2b_safety: %s carries no generation cap (%s). A '
              'structural argument is still an argument; without a cap a mistaken '
              'chain does not terminate.' % (', '.join(missing), CAP_MARK))
        return 1
    print('PASS  gate_selfext2b_safety: %d exec target(s) in %s, all self-contained '
          'bundles or argument-free tools (%s); NONE is the generic VM loader, so the '
          'organ cannot re-enter itself; every organ carries a generation cap read '
          'from %s. Red path exercised.'
          % (len(targets), ', '.join(present),
             ', '.join(sorted({t for _, _, t in targets})), CAP_MARK))
    return 0

if __name__ == '__main__':
    sys.exit(main())
