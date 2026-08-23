#!/usr/bin/env python3
"""fuzz_canon — property-based fuzzing of canon.la's monosemy (spec Gap 13).

WHY
---
The spec's Practical Implementation Blueprint, Gap 13, asks for "hypothesis-style
kappa-injectivity fuzzing."  What exists is monosemy_test.la: a handful of FIXED
cases.  A fixed test only ever checks the shapes its author thought of; a
property test checks an invariant over many random shapes.  This closes Gap 13
for the monosemy invariants.

It also avoids the trap it was built to expose: monosemy_test.la copies canon's
glyphs and its copy of REWRITE_MC has DRIFTED (missing canon's metacursion
fixed-points), so it tests a simpler normalization than canon.la actually runs.
This fuzzer instead appends its MAIN to canon.la's OWN text -- it exercises the
real NORMK/REWRITE_MC verbatim, so it cannot drift, and property P3 below
targets exactly the idempotence the drifted copy would break.

PROPERTIES FUZZED (over random decomposition trees of the 9 primitives x 5 modes)
  P1  commutative collapse: swapping the operands of a commutative node (SYN=otimes,
      CON=oplus) ANYWHERE in a tree gives the SAME glyph (NIS == TRUE).
  P2  directional sensitivity: swapping a directional node's (DIR=triangleright,
      CONT=subset) DISTINCT operands gives a DIFFERENT glyph (NIS == FALSE).
  P3  metacursion idempotence: NORMK(MC(MC(t))) == NORMK(MC(MC(MC(t)))) for ALL t
      -- after two folds the form is a fixed point, so a third fold changes
      nothing.  This is precisely the property canon's real REWRITE_MC provides
      and monosemy_test's stale copy does NOT (its REWRITE_MC always re-wraps).

A violation is a real bug in canon.la (or a proof the invariant is weaker than
claimed).  All-pass over N random trees hardens the monosemy claim beyond the
fixed cases.  Reproducible: fixed seed, and each case prints its own tree.

USAGE
    fuzz_canon.py [--n N] [--seed S] [--logos DIR] [--show]
"""
import argparse
import os
import random
import subprocess
import sys
import tempfile

PRIMS = ["BEING", "RECOGNITION", "LOVE", "SELF", "RELATION",
         "VOID", "BECOMING", "FORM", "DEPTH"]
COMMUTATIVE = ["SYN", "CON"]      # otimes, oplus  -> SORT2 (order-independent)
DIRECTIONAL = ["DIR", "CONT"]     # triangleright, subset -> WRAP2 (order-kept)


# --- a decomposition tree as nested python tuples -------------------------
#   ("PRIM", name) | ("SYN"/"CON"/"DIR"/"CONT", a, b) | ("MC", a)
def gen_tree(rng, depth):
    if depth <= 0 or (depth < 3 and rng.random() < 0.45):
        return ("PRIM", rng.choice(PRIMS))
    k = rng.random()
    if k < 0.25:
        return ("MC", gen_tree(rng, depth - 1))
    mode = rng.choice(COMMUTATIVE + DIRECTIONAL)
    return (mode, gen_tree(rng, depth - 1), gen_tree(rng, depth - 1))


def render(t):
    if t[0] == "PRIM":
        return f'PRIM("{t[1]}")'
    if t[0] == "MC":
        return f'MC({render(t[1])})'
    return f'{t[0]}({render(t[1])})({render(t[2])})'


def binary_nodes(t, path=()):
    """Yield (path, node) for every binary node, for choosing one to swap."""
    if t[0] in ("SYN", "CON", "DIR", "CONT"):
        yield path, t
    if t[0] in ("SYN", "CON", "DIR", "CONT"):
        yield from binary_nodes(t[1], path + (1,))
        yield from binary_nodes(t[2], path + (2,))
    elif t[0] == "MC":
        yield from binary_nodes(t[1], path + (1,))


def swap_at(t, path):
    """Return t with the binary node at `path` having its operands swapped."""
    if not path:
        return (t[0], t[2], t[1])
    if t[0] == "MC":
        return ("MC", swap_at(t[1], path[1:]))
    head = t[0]
    if path[0] == 1:
        return (head, swap_at(t[1], path[1:]), t[2])
    return (head, t[1], swap_at(t[2], path[1:]))


def tree_eq(a, b):
    return a == b


def build_cases(rng, n):
    """Return a list of (kind, laA, laB, expect_same) checks."""
    cases = []
    tries = 0
    while len(cases) < n and tries < n * 20:
        tries += 1
        t = gen_tree(rng, rng.randint(2, 4))
        bins = list(binary_nodes(t))
        # P1 / P2: pick a binary node to swap
        comm = [(p, nd) for p, nd in bins if nd[0] in COMMUTATIVE]
        direc = [(p, nd) for p, nd in bins
                 if nd[0] in DIRECTIONAL and not tree_eq(nd[1], nd[2])]
        if comm:
            p, _ = rng.choice(comm)
            cases.append(("P1", render(t), render(swap_at(t, p)), True))
        if direc:
            p, _ = rng.choice(direc)
            cases.append(("P2", render(t), render(swap_at(t, p)), False))
        # P3: metacursion idempotence on a random subject
        mm = f'MC(MC({render(t)}))'
        mmm = f'MC(MC(MC({render(t)})))'
        cases.append(("P3", mm, mmm, True))
    return cases[:n]


def emit_program(canon_src, cases):
    """canon.la's own body (MAIN stripped) + a fuzz MAIN that prints verdicts.
    Using canon's real text means the REAL NORMK/REWRITE_MC are exercised."""
    body = "\n".join(l for l in canon_src.splitlines()
                     if not l.lstrip().startswith("glyph MAIN"))
    lines = [body,
             'glyph FZ_YN = la b. b("T")("F")',
             'glyph FZ_SEQ = la a. la b. b']
    # one print per case: "<i> <kind> <T|F>"
    prints = []
    for i, (kind, a, b, _) in enumerate(cases):
        prints.append(f'print(concat("{i} {kind} ")(FZ_YN(NIS({a})({b}))))')
    # right-fold the prints through FZ_SEQ so effects are ordered
    expr = prints[-1]
    for p in reversed(prints[:-1]):
        expr = f'FZ_SEQ({p})({expr})'
    lines.append(f'glyph MAIN = {expr}')
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--n", type=int, default=60)
    ap.add_argument("--seed", type=int, default=1729)
    ap.add_argument("--logos", default=os.path.expanduser("~/logos"))
    ap.add_argument("--show", action="store_true", help="print each verdict")
    args = ap.parse_args()

    canon = os.path.join(args.logos, "canon.la")
    host = os.path.join(args.logos, "tiny_host")
    for f in (canon, host):
        if not os.path.exists(f):
            print(f"SKIP  fuzz_canon: missing {f}"); return 0

    rng = random.Random(args.seed)
    cases = build_cases(rng, args.n)
    prog = emit_program(open(canon).read(), cases)

    # run from a scratch dir (canon.la is pure; tiny_host has no /tmp paths)
    wd = tempfile.mkdtemp()
    src = os.path.join(wd, "fz.la")
    with open(src, "w") as fh:
        fh.write(prog)
    try:
        out = subprocess.run([host, src], capture_output=True, text=True,
                             timeout=600)
    finally:
        os.unlink(src)
        os.rmdir(wd)
    if out.returncode != 0:
        print(f"FAIL  fuzz_canon: tiny_host rc={out.returncode}\n{out.stderr[-500:]}")
        return 1

    verdict = {}
    for line in out.stdout.splitlines():
        p = line.split()
        if len(p) == 3 and p[0].isdigit():
            verdict[int(p[0])] = (p[1], p[2])

    fails = []
    checked = 0
    for i, (kind, a, b, expect_same) in enumerate(cases):
        got = verdict.get(i)
        if got is None:
            fails.append((i, kind, a, b, "no output")); continue
        checked += 1
        same = got[1] == "T"
        if same != expect_same:
            fails.append((i, kind, a, b,
                          f"NIS={got[1]} expected {'T' if expect_same else 'F'}"))
        if args.show:
            print(f"  {i:3} {kind} NIS={got[1]}  {a}  {'==' if same else '!='}  {b}")

    by = {}
    for kind, *_ in cases:              # kind is the FIRST field of a case tuple
        by[kind] = by.get(kind, 0) + 1
    tally = " ".join(f"{k}:{v}" for k, v in sorted(by.items()))
    if fails:
        print(f"FAIL  fuzz_canon: {len(fails)}/{checked} monosemy violations "
              f"(seed {args.seed}, {tally})")
        for i, kind, a, b, why in fails[:12]:
            print(f"  [{kind} #{i}] {why}\n      A: {a}\n      B: {b}")
        return 1
    print(f"PASS  fuzz_canon: {checked} random cases, 0 monosemy violations "
          f"(seed {args.seed}, {tally}) -- commutative collapse, directional "
          f"distinctness, metacursion idempotence all hold")
    return 0


if __name__ == "__main__":
    sys.exit(main())
