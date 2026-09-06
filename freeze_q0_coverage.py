#!/usr/bin/env python3
"""q0_coverage — WHAT DOES THE SUITE NEVER RUN?

Q1 (do two engines disagree) and Q2 (which assertions cannot go RED) both operate
on what the suite ALREADY RUNS. Neither can see a module the suite never invokes,
or a gate that reaches a green verdict having executed zero assertions. Coverage is
PRIOR to both, so this runs first.

Prompted by two Track-D findings, both invisible to Q1/Q2 by construction:
  · buildla.la — the LA reimplementation of build.sh, 91/103 stages — was reachable
    from NOTHING: zero mentions in build.sh, no gate.
  · gate_hal_idle.sh consumed four UNTRACKED prebuilt ELFs, `continue`d past every
    absent one, found none, printed SKIP and exit 0. On a fresh clone it passed
    having tested nothing.

★ METHOD CAVEAT, paid for by Track D and honoured here: a PARAMETERISED reference
(kernel/${D}_ctrl.la) is invisible to a static sweep. Unresolved expansions are
COUNTED AND REPORTED, never silently dropped — otherwise the coverage number is
wrong in the safe-looking direction.

Read-only. Touches nothing.
"""
import re, subprocess, sys
from pathlib import Path

# The repo is where THIS SCRIPT lives, not a path baked in at authoring time.
# A hardcoded $HOME makes a tool silently read the wrong worktree when run from
# another one -- and the worktree isolation that guards /tmp cannot see it,
# because the path is not in /tmp.
REPO = Path(__file__).resolve().parent

def tracked():
    out = subprocess.run(["git","-C",str(REPO),"ls-files"],capture_output=True,text=True).stdout
    return [l for l in out.splitlines() if l.strip()]

LA_REF   = re.compile(r'([A-Za-z0-9_./-]+\.la)\b')
SH_REF   = re.compile(r'([A-Za-z0-9_./-]*gate_[A-Za-z0-9_.-]+\.sh|[A-Za-z0-9_./-]*build_[A-Za-z0-9_.-]+\.sh)\b')
IMPORT   = re.compile(r'import\("([^"]+)"\)')
PARAM    = re.compile(r'\$\{[A-Za-z_][A-Za-z0-9_]*\}|\$[A-Za-z_][A-Za-z0-9_]*')

def read(p):
    try: return (REPO/p).read_text(errors="replace")
    except Exception: return ""

def main():
    files    = tracked()
    la_files = {f for f in files if f.endswith(".la")}
    sh_files = {f for f in files if f.endswith(".sh")}

    # ── roots: build.sh and every gate/build script it can reach ──
    roots, seen_sh, queue = set(), set(), ["build.sh"]
    while queue:
        s = queue.pop()
        if s in seen_sh: continue
        seen_sh.add(s); roots.add(s)
        txt = read(s)
        for m in SH_REF.finditer(txt):
            cand = m.group(1).lstrip("./")
            for f in sh_files:
                if f == cand or f.endswith("/"+cand):
                    if f not in seen_sh: queue.append(f)

    # ── every .la named by a reachable script, plus transitive import() ──
    direct, unresolved = set(), []
    for s in sorted(seen_sh):
        txt = read(s)
        for m in LA_REF.finditer(txt):
            r = m.group(1).lstrip("./")
            if PARAM.search(m.group(0)): unresolved.append((s, m.group(1))); continue
            for f in la_files:
                if f == r or f.endswith("/"+r): direct.add(f)
        # a parameterised .la reference hides its real targets
        for line in txt.splitlines():
            if ".la" in line and PARAM.search(line):
                frag = line.strip()[:100]
                if not any(frag == u[1] for u in unresolved): unresolved.append((s, frag))

    reach, q = set(), list(direct)
    while q:
        f = q.pop()
        if f in reach: continue
        reach.add(f)
        for m in IMPORT.finditer(read(f)):
            t = m.group(1).lstrip("./")
            for g in la_files:
                if g == t or g.endswith("/"+t):
                    if g not in reach: q.append(g)

    orphans = sorted(la_files - reach)

    print("=" * 72)
    print("Q0 — COVERAGE. What the suite never runs.")
    print("=" * 72)
    print(f"tracked .la            : {len(la_files)}")
    print(f"reachable from build.sh: {len(reach)}")
    print(f"UNREACHABLE            : {len(orphans)}")
    print(f"scripts walked         : {len(seen_sh)}")
    print()
    print(f"★ UNREACHABLE .la — outside Q1 and Q2 BY CONSTRUCTION ({len(orphans)}):")
    for o in orphans: print(f"    {o}")
    print()
    print(f"⚠ UNRESOLVED PARAMETERISED REFS ({len(unresolved)}) — each may hide real")
    print("  targets, so the UNREACHABLE list above is an UPPER bound, not a verdict:")
    for s, frag in unresolved[:15]: print(f"    {s}: {frag}")
    if len(unresolved) > 15: print(f"    ... and {len(unresolved)-15} more")

    # ── gate scripts audit_gates.py has never read (it only opens build.sh) ──
    gates = sorted(f for f in sh_files if "gate_" in f)
    print()
    print(f"★ GATE SCRIPTS audit_gates.py HAS NEVER READ ({len(gates)}):")
    print("  Q2's classifier defaults to --file build.sh and walks nothing else, so")
    print("  every assertion in these is unclassified — and a zero-iteration loop in")
    print("  any of them is invisible to it twice over (no control-flow model either).")
    for g in gates[:20]: print(f"    {g}")
    if len(gates) > 20: print(f"    ... and {len(gates)-20} more")

if __name__ == "__main__": main()
