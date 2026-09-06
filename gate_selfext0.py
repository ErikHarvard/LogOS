#!/usr/bin/env python3
"""
gate_selfext0.py — STAGE 0 OF THE SELF-EXTENSION LOOP: THE BASELINE, AS A GATE.

The ledger's most consequential [A] is "the changed thing must become the
running thing". Before building toward it, the starting point has to be a
MEASUREMENT rather than a memory, because "we think nothing runs the adopted
artifact" is exactly the kind of belief that turns out to be false after
somebody wires a convenience.

WHAT THIS ASSERTS. The self-* organs write adopted artifacts (`grown.la` and
friends) via DEPLOY/write_file. Today those artifacts are only ever READ --
read_file'd, grep'd, rm'd. Nothing compiles one, bundles one, imports one, or
execve's one. So the new capability is verified inside the parent process and
never demonstrated by any successor.

★ THIS IS A TRIPWIRE, NOT A PROPERTY WORTH KEEPING. When stage 2 lands -- the
adopted artifact becomes executable -- this gate MUST go red, and the correct
response is to CONVERT it (assert the execution path exists and is verified),
never to delete it. A deleted tripwire loses the only record of what changed.

★ AND IT SELF-TESTS BEFORE IT REPORTS. A checker that scans for execution
references and finds none is indistinguishable from a checker whose patterns
match nothing. So it injects a synthetic execution reference and refuses to
report PASS unless that turns it red. The four instruments this project caught
reporting absence from a dead harness are the reason.
"""
import re, os, sys, glob

REPO = os.path.dirname(os.path.abspath(__file__))

# An artifact is "adopted" if a self-* organ WRITES it.
ORGANS = ['selfmod.la', 'selfopt.la', 'selfprog.la', 'selfrepair.la', 'autoloop.la',
          'selfext2.la', 'selfext2b.la']
# ★ selfext2b.la was MISSING from this list when stage 2b landed, so the gate
# reported PASS while never scanning the organ that begets successors. A green
# from a scan that did not look is the precise failure this gate exists to
# prevent, occurring inside it. Adding an organ here is part of building one.

# A reference is an EXECUTION reference if it would make the artifact RUN:
# compiled, bundled, imported, exec'd, or fed to an engine.
EXEC_MARKERS = ('import(', 'logos_source', 'codegen', 'bundle', 'execve',
                'logos_secd', 'write_exec', 'tiny_host', 'logos_program')

def adopted_artifacts(src_of):
    arts = set()
    for organ in ORGANS:
        s = src_of.get(organ)
        if s is None: continue
        arts |= set(re.findall(r'DEPLOY\([A-Za-z_0-9]+\)\("([^"]+\.la)"\)', s))
        arts |= set(re.findall(r'write_file\("([^"]+\.la)"\)', s))
        arts |= set(re.findall(r'write_exec\("([^"]+)"\)', s))
    return arts

def exec_refs(arts, src_of):
    hits = []
    for name, s in src_of.items():
        if name in ORGANS:           # an organ naming its own output is not execution
            continue
        for i, line in enumerate(s.split('\n'), 1):
            for a in arts:
                # ★ WORD-BOUNDARY, NOT SUBSTRING. `selfopt.la` CONTAINS `opt.la`,
                # so a substring test reported the organ's own gate as an
                # execution path -- a tripwire firing on a name collision rather
                # than on a fact. Caught on this gate's first run.
                if re.search(r'(?<![A-Za-z0-9_./-])' + re.escape(a), line) \
                   and any(m in line for m in EXEC_MARKERS):
                    hits.append((name, i, a, line.strip()[:110]))
    return hits

def load():
    d = {}
    for p in glob.glob(os.path.join(REPO, '*.la')) + glob.glob(os.path.join(REPO, '*.sh')):
        try: d[os.path.basename(p)] = open(p, encoding='utf-8', errors='replace').read()
        except OSError: pass
    return d

def selftest(src_of, arts):
    """Inject an execution reference and require the scan to catch it."""
    if not arts:
        print('FAIL  gate_selfext0: no adopted artifacts found — the scan has nothing '
              'to range over, so an empty result is not a verdict')
        return False
    a = sorted(arts)[0]
    probe = dict(src_of)
    probe['__selftest__.sh'] = 'cp %s logos_source.la && ./tiny_host codegen.la\n' % a
    if not exec_refs(arts, probe):
        print('FAIL  gate_selfext0: an INJECTED execution reference to %s was NOT '
              'detected. The scan cannot go red and is asserting nothing.' % a)
        return False
    return True

# ── ★ CONVERTED, 2026-08-24, WHEN STAGE 2 LANDED ────────────────────────────
#  The baseline form asserted that NO adopted artifact was on an execution
#  path. Stage 2 made that false on purpose, and the gate fired naming the two
#  references. The scope required conversion rather than deletion: a deleted
#  tripwire loses the only record of what changed.
#  So it is now a PINNED LEDGER. Both sets are fixed:
#      ON AN EXECUTION PATH   what stage 2 deliberately made runnable
#      READ-ONLY              everything that is still only read
#  An artifact silently JOINING the execution path fires. One silently LEAVING
#  it fires too -- a capability quietly losing its runtime witness is the same
#  class of drift in the other direction.
#  What this does NOT assert is that the guard WORKS; that is stage 2's own red
#  path, and duplicating it here would be a second check with no second
#  witness. What it does assert is that the guard EXISTS, because an execution
#  path whose refusal arm was deleted would otherwise pass silently.
PINNED_EXEC = {'logos_source.la', 'sx2_child.la', 'sx2_parent.la'}
PINNED_READONLY = {'grown.la', 'opt.la', 'organ.la'}
# ★ logos_source.la joined the execution set when STAGE 2b landed: the organ
# writes the grown source there and then forks+execve's the compiler, which
# reads that fixed path. That is the whole of 2b -- the exec originating
# inside the organ -- so the pin moved deliberately and is recorded here
# rather than being absorbed. sx2_child/sx2_parent came from stage 2.
# The three READ-ONLY artifacts are the ones still verified in-parent and
# demonstrated by no successor; when an organ begets from those, this moves
# again, and it should move by an edit somebody had to justify.
#
# Each open path names the guard that stands over it. Asserting the guard
# EXISTS is not asserting it WORKS -- that is each stage's own red path, and
# duplicating it here would be a second check with no second witness. But a
# guard silently deleted while its path stayed open would otherwise pass.
GUARDS = [
    ('gate_selfext2.sh',        'a child program was written for an UNVERIFIED extension'),
    ('gate_selfext2b_safety.py', 'the generic VM loader'),
]

def main():
    src_of = load()
    if not src_of:
        print('FAIL  gate_selfext0: no sources loaded'); return 1
    arts = adopted_artifacts(src_of)
    if not selftest(src_of, arts):
        return 1

    hits = exec_refs(arts, src_of)
    on_exec = {a for _, _, a, _ in hits}
    read_only = arts - on_exec
    bad = 0

    if on_exec != PINNED_EXEC:
        print('FAIL  gate_selfext0: the set of adopted artifacts ON AN EXECUTION PATH '
              'changed.\n  pinned  : %s\n  measured: %s'
              % (sorted(PINNED_EXEC) or ['(none)'], sorted(on_exec) or ['(none)']))
        print('  An artifact JOINING this set means something new became runnable; '
              'LEAVING it means a capability lost its runtime witness. Either way, '
              'look before re-pinning.')
        bad = 1
    if read_only != PINNED_READONLY:
        print('FAIL  gate_selfext0: the READ-ONLY set changed.\n  pinned  : %s\n  measured: %s'
              % (sorted(PINNED_READONLY), sorted(read_only)))
        bad = 1

    import os.path as _op
    for gf, gt in GUARDS:
        gp = _op.join(REPO, gf)
        try:
            g = open(gp, encoding='utf-8', errors='replace').read()
        except OSError:
            print('FAIL  gate_selfext0: guard %s is absent, so nothing stands over '
                  'the execution path it was written for' % gf); bad = 1; continue
        if gt not in g:
            print('FAIL  gate_selfext0: guard %s no longer contains its load-bearing '
                  'assertion (%r). The execution path is open and its guard is gone.'
                  % (gf, gt)); bad = 1

    if bad:
        return 1
    print('PASS  gate_selfext0: adopted-artifact ledger matches the pin — %d ON an '
          'execution path (%s, opened deliberately by stage 2) and %d READ-ONLY (%s, '
          'still verified in-parent and demonstrated by no successor); the refusal arm '
          'that guards each open path is present (%s). Red path exercised. This gate '
          'was the stage-0 baseline tripwire and has been CONVERTED twice — when '
          'stage 2 opened the first path and when stage 2b opened logos_source.la — '
          'never deleted.'
          % (len(on_exec), ', '.join(sorted(on_exec)),
             len(read_only), ', '.join(sorted(read_only)),
             ', '.join(g for g, _ in GUARDS)))
    return 0

if __name__ == '__main__':
    sys.exit(main())
