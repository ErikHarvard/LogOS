# -*- coding: utf-8 -*-
"""F25's real witness: do the Three Laws CONSULT the Archē? Static reachability over glyph definitions.

The claim (09-17 correction 1): "the Three Laws are NOT derived from the Archē". §44's original witness was vacuous —
LR_SIG never used the GROUND it was handed (FREEZE-TRACKF.md F25). In LA the claim has a checkable meaning: none of
LAW_IDENTITY / LAW_NONCONTRADICTION / LAW_EXCLUDED_MIDDLE reaches, through any chain of glyph references, a glyph that
applies an Archē rewrite. This computes that reference closure over the ROOT module's whole import closure — the laws
exactly as the root loads them.

  usage:  python3 derive/lawreach.py lawroot.la [--swap IMPORTED.la=REPLACEMENT.la]
          --swap loads REPLACEMENT wherever the closure imports IMPORTED — how the gate feeds a MUTANT of a dependency
          (metalogic.la, where the laws live) without writing into the worktree; a swap that is never used is an error
  prints: "LAWREACH no law reaches an Archē rewrite:T" (exit 0), or ":F" and one line per law naming the forbidden
          glyph it reaches and the reference path (exit 1); exit 2 if a law is not defined in the closure at all.

SOUND FOR ABSENCE: a name defined in several modules (imported privates are mangled by tiny_host, so same-named
privates of different modules are different glyphs) has the UNION of all its bodies here. That over-approximates the
reference graph, so a reported reach may be spurious, but a reported "none" cannot be: no body of any same-named glyph
reaches a forbidden one. String literals and comments are blanked first, so a name inside a string is not a reference.

It goes RED if a law is rewritten to consult the Archē — gate §44 runs two mutants (LAW_EXCLUDED_MIDDLE routed through
TRIBAR; LAW_IDENTITY through GROUND) and requires the offender named. Bound [B]: this is independence of the
IMPLEMENTED laws from the IMPLEMENTED rewrites — the code's dependency structure, which is what the claim means in LA;
it says nothing of a derivation by some route the code does not contain.
"""
import os, re, sys
FORBIDDEN = ("GROUND", "TRIBAR", "VERDICT", "VERDICT_OR_DIE", "REWRITE_SYN", "REWRITE_MC", "NORMK", "NIS")
LAWS = ("LAW_IDENTITY", "LAW_NONCONTRADICTION", "LAW_EXCLUDED_MIDDLE")
ID = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
STR = re.compile(r'"(?:[^"\\]|\\.)*"')
IMP = re.compile(r'import\("([^"]+)"\)')

def clean(line): return STR.sub('""', line).split("#", 1)[0]
defs = {}
def load(path, seen):
    if path in seen: return
    seen.add(path)
    src = open(path, encoding="utf-8").read().split("\n")
    for line in src:                       # paths resolve against the CWD, exactly as tiny_host's do_import
        for m in IMP.finditer(clean_keep_imports(line)):
            dep = SWAP.get(m.group(1), m.group(1)); used.add(m.group(1))
            if not os.path.exists(dep): print("ERROR: %s imports %s, which does not exist" % (path, dep)); sys.exit(2)
            load(dep, seen)
    cur = None
    for line in src:
        if line.startswith("glyph ") and not re.match(r"^glyph [A-Za-z0-9_]+\s*=", line):   # a def this parser cannot read
            print("ERROR: %s has a glyph line the parser does not read (so absence would be unproven): %s" % (path, line[:80])); sys.exit(2)
        m = re.match(r"^glyph ([A-Za-z0-9_]+)\s*=\s*(.*)$", line)
        if m:
            cur = m.group(1); defs[cur] = defs.get(cur, "") + " " + clean(m.group(2))
        elif cur and line[:1] in (" ", "\t"):
            defs[cur] += " " + clean(line)
        else:
            cur = None
def clean_keep_imports(line): return line.split("#", 1)[0]   # import("…") IS a string; keep it, drop the comment

args = sys.argv[1:]; SWAP = {}; used = set()
while len(args) >= 2 and args[-2] == "--swap":
    k, _, v = args[-1].partition("="); SWAP[k] = v; args = args[:-2]
if len(args) != 1 or any(not v for v in SWAP.values()): print("usage: lawreach.py ROOT.la [--swap IMPORTED.la=REPLACEMENT.la]"); sys.exit(2)
load(args[0], set())
if set(SWAP) - used: print("ERROR: --swap %s was never imported, so nothing was replaced" % ", ".join(sorted(set(SWAP) - used))); sys.exit(2)
missing = [l for l in LAWS if l not in defs]
if missing: print("ERROR: law(s) not defined in the import closure of %s: %s" % (args[0], ", ".join(missing))); sys.exit(2)

def reach(name):
    path = {name: [name]}; stack = [name]
    while stack:
        n = stack.pop()
        for t in ID.findall(defs.get(n, "")):
            if t in defs and t not in path:
                path[t] = path[n] + [t]; stack.append(t)
    return [(f, path[f]) for f in FORBIDDEN if f in path]
hits = [(l, f, p) for l in LAWS for f, p in reach(l)]
print("LAWREACH no law reaches an Archē rewrite:%s" % ("F" if hits else "T"))
for l, f, p in hits: print("  %s reaches %s via %s" % (l, f, " -> ".join(p)))
print("LAWREACH closure: %d glyph names, laws checked: %s" % (len(defs), " ".join(LAWS)))
sys.exit(1 if hits else 0)
