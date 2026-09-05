#!/usr/bin/env python3
"""q2_resolve — resolve the Z-unclassified assertions by finding the GOVERNING test.

audit_gates.py classifies per line. 212 of build.sh's assertions come back
Z-unclassified, and sampling shows why: most are the `echo "FAIL ..."` arm of a
MULTI-LINE if/else, e.g.

    if [ "$OUT" = "hello, world" ]; then      <- the discriminating comparison
        echo "PASS ..."
    else
        echo "FAIL  expected 'hello, world', got '$OUT'"   <- the line flagged
        exit 1
    fi

The message carries no discriminating power; the `if` above it carries all of it.
So the question "what input makes this go RED?" is answerable mechanically for
these: whatever falsifies the governing test.

This walks BACKWARD from each flagged line to the nearest governing construct and
classifies from that, leaving only a residue that genuinely needs a human line.

★ It does NOT claim the resolved ones are GOOD gates — only that their RED path is
identifiable. An exact-string comparison against a literal has an obvious falsifier;
that is a different claim from "this assertion is worth having".
"""
import re, subprocess
from pathlib import Path
# The repo is where THIS SCRIPT lives, not a path baked in at authoring time.
# A hardcoded $HOME makes a tool silently read the wrong worktree when run from
# another one -- and the worktree isolation that guards /tmp cannot see it,
# because the path is not in /tmp.
REPO = Path(__file__).resolve().parent
SRC=(REPO/"build.sh").read_text(errors="replace").splitlines()

GOVERN = [
  ("A-byte-identity", re.compile(r'\bcmp\s+-s\b')),
  ("B-exact-string",  re.compile(r'\[\s*"?\$\w+"?\s*=\s*["\']|'
                                 r'\[\s*"\$\(.*?\)"\s*=\s*["\']|'
                                 r'\bgrep\s+-q[a-zA-Z]*F')),
  ("C-pattern",       re.compile(r'\bgrep\s+-q\b')),
  # ★ R-redpath FIRST: an assertion that something SHOULD have failed. These are
  # the gates Q2 most wants — they test the RED path directly, so their falsifier
  # is "the thing wrongly succeeded". Counted separately rather than lumped in.
  ("R-redpath",       re.compile(r'instead of halting|assembled instead|did NOT halt|'
                                 r'was written anyway|did not fail|should have (failed|halted)')),
  # exit status as the test: $FOO_RC checks, and `cmd || { echo "FAIL` where the
  # command's own exit status IS the discriminator.
  ("D-exit+diag",     re.compile(r'\$\{?\w*RC\b|\brc\b\s*(-ne|-eq|=)|"\$\?"|\bexit\s+code\b|'
                                 r'^\s*[./\w].*\s\|\|\s*\{\s*echo\s+"FAIL')),
  ("F-threshold",     re.compile(r'-(lt|le|gt|ge)\b')),
  ("E-presence",      re.compile(r'\[\s+-[fdsxez]\s|\[\s+-n\s')),
]
FAILLINE=re.compile(r'echo\s+"FAIL')

def govern_of(idx, back=18):
    """nearest preceding construct that actually discriminates"""
    for j in range(idx, max(-1, idx-back), -1):
        l=SRC[j]
        if re.match(r'\s*(if|elif)\s|\[\s|.*\|\|\s*\{', l) or 'cmp -s' in l or 'grep -q' in l:
            for name,rx in GOVERN:
                if rx.search(l): return name, j+1, l.strip()[:90]
    return None, None, None

def main():
    out=subprocess.run(["python3","audit_gates.py"],cwd=str(REPO),capture_output=True,text=True).stdout
    zs=[int(m.group(1)) for m in re.finditer(r'build\.sh:(\d+)\s+\[Z-unclassified\]', out)]
    resolved={}; residue=[]
    for n in zs:
        cls,gl,txt=govern_of(n-1)
        if cls: resolved.setdefault(cls,[]).append((n,gl,txt))
        else:   residue.append((n, SRC[n-1].strip()[:90]))
    print("="*76)
    print("Q2 — RESOLVING THE Z-UNCLASSIFIED ASSERTIONS")
    print("="*76)
    print(f"Z-unclassified in       : {len(zs)}")
    print(f"resolved by governing test: {sum(len(v) for v in resolved.values())}")
    print(f"★ RESIDUE needing a human line: {len(residue)}")
    print()
    for k in sorted(resolved): print(f"  {k:<18} {len(resolved[k]):>4}")
    print()
    print("★ THE RESIDUE — no governing test found within 18 lines:")
    for n,t in residue[:40]: print(f"  build.sh:{n}  {t}")
    if len(residue)>40: print(f"  ... and {len(residue)-40} more")

if __name__=="__main__": main()
