#!/usr/bin/env python3
"""q2_skiptogreen — a non-vacuity guard that EXITS GREEN when nothing was tested.

★ SIGNATURE DERIVED FROM A VERIFIED INSTANCE, not guessed. Two earlier cuts of
this tool were wrong and the positive control caught both:
  cut 1  flagged 39/43 on "no non-vacuity guard" — meaningless, since gate_k4a.sh's
         assertions are UNCONDITIONAL and need no guard.
  cut 2  assumed the defect was a MISSING counter. The pre-fix gate_hal_idle.sh has
         `found=0 / found=1` — the counter was there all along.

The actual defect (kernel/gate_hal_idle.sh, fixed by Track D in 22dfd8c):

    found=0
    for ... ; do  [ -f "$elf" ] || continue ;  found=1 ; ... done
    if [ "$found" -eq 0 ]; then echo "SKIP ..."; exit 0; fi      <-- GREEN on nothing

The guard fires correctly and then does nothing. Track D's fix changed one token,
exit 0 -> exit 1, with the comment "Testing nothing is not passing."

So the question is not "is there a guard" but "does the guard have TEETH":
    G  a zero-case check whose branch exits 0 instead of 1

This is the vacuous-gate pattern one level up — an assertion that CAN fire, fires,
and is then discarded. Still a SHAPE: a gate that legitimately reports SKIP when
hardware is absent is correct. The defect is exiting 0 while KNOWING it tested
nothing, because the caller cannot distinguish that from success.
"""
import re, subprocess
from pathlib import Path
REPO = Path("/home/erikxanderharvard/logos")

def strip_comments(t):
    out=[]
    for line in t.splitlines():
        if line.lstrip().startswith("#"): continue
        out.append(line)
    return "\n".join(out)

# a zero/emptiness check on a counter-ish variable ...
ZEROCHK = re.compile(r'\[\s*"?\$\{?(\w+)\}?"?\s+-eq\s+0\s*\]|'
                     r'\[\s*-z\s+"?\$\{?(\w+)\}?"?\s*\]|'
                     r'\[\s*"?\$\{?(\w+)\}?"?\s*=\s*"?0"?\s*\]')
EXIT0   = re.compile(r'^\s*exit\s+0\s*$', re.M)
ASSERTS = re.compile(r'echo\s+"FAIL|\bok=0\b')

def toothless(txt):
    """A zero-case check whose following block exits 0 (within 6 lines)."""
    hits=[]
    lines=txt.splitlines()
    for i,l in enumerate(lines):
        m=ZEROCHK.search(l)
        if not m: continue
        block="\n".join(lines[i:i+6])
        if EXIT0.search(block):
            var=next(g for g in m.groups() if g)
            hits.append((i+1,var))
    return hits

def gates(root):
    out=subprocess.run(["git","-C",str(root),"ls-files"],capture_output=True,text=True).stdout
    return [l for l in out.split() if re.search(r'(^|/)gate_.*\.sh$', l)]

def main():
    # ── POSITIVE CONTROL FIRST. A detector that misses the known instance is worthless. ──
    D=Path("/home/erikxanderharvard/logos-d")
    pre=subprocess.run(["git","-C",str(D),"log","--format=%H","-1","--skip=1","--",
                        "kernel/gate_hal_idle.sh"],capture_output=True,text=True).stdout.strip()
    okctl=False
    if pre:
        old=strip_comments(subprocess.run(["git","-C",str(D),"show",f"{pre}:kernel/gate_hal_idle.sh"],
                                          capture_output=True,text=True).stdout)
        new=strip_comments((D/"kernel/gate_hal_idle.sh").read_text(errors="replace"))
        a,b=toothless(old),toothless(new)
        okctl = bool(a) and not b
        print(f"CONTROL pre-fix  gate_hal_idle.sh : {'FIRES  ' + str(a) if a else '✗ MISSED'}")
        print(f"CONTROL post-fix gate_hal_idle.sh : {'✗ still fires '+str(b) if b else 'silent — fix confirmed'}")
        print(f"⇒ detector {'VALID — fires on the bad version, silent on the fixed one' if okctl else 'INVALID — do not trust the results below'}")
    print("="*74)
    if not okctl:
        print("Results suppressed: the detector failed its own control."); return
    rows=[]
    for g in sorted(gates(REPO)):
        txt=strip_comments((REPO/g).read_text(errors="replace"))
        if not ASSERTS.search(txt): continue
        h=toothless(txt)
        if h: rows.append((g,h))
    print(f"Q2b — TOOTHLESS NON-VACUITY GUARDS (exit 0 when nothing was tested)")
    print("="*74)
    print(f"gate scripts with assertions : {len([g for g in gates(REPO) if ASSERTS.search((REPO/g).read_text(errors='replace'))])}")
    print(f"flagged                      : {len(rows)}")
    print()
    for g,h in rows:
        for ln,var in h: print(f"  {g}:{ln}  guard on ${var} exits 0")
    if not rows: print("  (none in this tree)")

if __name__=="__main__": main()
