#!/usr/bin/env python3
"""audit_standalone_gates — Freeze-Day Audit III: the surface Audit II could not see.

WHY THIS EXISTS
---------------
`audit_gates.py` triages build.sh's ~600 assertions by discriminating power.  It
was never pointed at the STANDALONE `gate_*.sh` scripts, and could not have been:
its FAIL-line regex is `echo "FAIL` and its section parser expects build.sh's
`say "..."` idiom.  The standalone gates use three different failure idioms and
have no sections at all.  So ~110 assertions across 16 gate scripts have never
been asked the Audit II question: *which of these cannot go RED?*

That surface is not clean.  Audit II's own docstring lists four cannot-fail
checks, every one found BY ACCIDENT while looking at something else.  On
2026-08-27, without searching for them, two more families turned up in exactly
this surface:

  5. `wrong-PK rejected` in wotsp.la / wotsp_prod.la / xmss.la — asserts
     `pkA != FLIPS(pk)` while a neighbour already asserts `pkA == pk`, so it
     reduces to `pk != FLIPS(pk)`, true by construction of FLIPS.
  6. the `host != VM` line in gate_sha256.sh / gate_wotsp.sh / gate_xmss.sh /
     gate_xmssidx.sh — see G-implied below.

Six known, all found by accident.  Accident is not a search.  This is the search
for the shape of (6), which is the one that is mechanically detectable.

THE NEW DETECTOR — G-implied
----------------------------
A gate that checks HOSTOUT against a constant E, checks VMOUT against THE SAME
constant E, and then checks HOSTOUT against VMOUT, has written a third assertion
that the first two ENTAIL: if both equal E they equal each other.  It can never
go red on its own.  In all four cases its comment claims it catches "each engine
wrong its own way" — it cannot; the value checks catch that.

The fix is not to delete it.  Compare the host to the derived expectation and the
VM TO THE HOST: identical total strength, every line live, and each red points at
what actually broke.  gate_xmss_signer.sh is built that way and is this tool's
NEGATIVE CONTROL.

★ CO-REACHABILITY IS LOAD-BEARING, and it is why this is not a three-line regex.
gate_xmss_signer.sh contains BOTH `VMOUT = E_SIGNER` and `VMOUT = HOSTOUT` — but
in mutually exclusive branches of `if SIGNER_VM_ONLY`.  A detector without branch
awareness flags it, and a triage tool that cries wolf gets ignored (Audit II
learned this: its first run's three top-severity flags were all false positives).
So every comparison carries its branch path, and two comparisons count as
co-reachable only if they agree on every `if` they share.

WHAT THIS IS NOT
----------------
A heuristic, not an oracle.  It parses bash with regexes; `case`/`&&`-chains are
not branch-tracked, so a `case`-guarded pair can still false-positive.  Its output
is a RANKED WORKLIST.  ★ A clean report is NOT evidence a gate can fail — only
that this tool found nothing.  Every survivor still needs one human line: *the
input that would make it go RED.*

★ AND THE TOOL MUST PROVE IT LOOKED.  `--selftest` runs the detector against the
four KNOWN-dead lines and the one KNOWN-live line and fails loudly if it does not
reproduce them.  A reporting tool whose own harness is dead reports ABSENCE and
is believed.  Run --selftest before believing any clean report from this file.

USAGE
    audit_standalone_gates.py --selftest              # calibrate FIRST
    audit_standalone_gates.py gate_*.sh               # triage
    audit_standalone_gates.py --suspects gate_*.sh    # flagged only
"""
import argparse, os, re, sys
from collections import Counter, defaultdict

# ── the three failure idioms, established by survey across all 16 gates, not
#    assumed.  echo "FAIL (13 gates) · printf 'FAIL + fail=$((fail+1))
#    (gate_asmelf.sh) · die "..." (gate_bootelf.sh, 18 of them).
FAILLINE = re.compile(r'echo\s+"FAIL|printf\s+[\'"]FAIL|\bdie\s+"')

# a shell test comparing two "$VAR" operands, or a var against a literal
CMP_VV = re.compile(r'\[\s+"\$\{?(\w+)\}?"\s+(=|!=)\s+"\$\{?(\w+)\}?"\s+\]')

SHAPES = [
    ("A-byte-identity", re.compile(r'\bcmp\s+-s\b')),
    ("D-exit+diag",     re.compile(r'\brc\b.*=|\breturncode\b|"\$\?"|\brc\b.*-ne')),
    ("B-exact-string",  re.compile(r'\bgrep\s+-q[a-zA-Z]*F[a-zA-Z]*\b|\bgrep\s+-qx\b')),
    ("C-pattern",       re.compile(r'\bgrep\s+-q\b')),
    ("G-string-eq",     re.compile(r'\[\s+"\$\w+"\s+(=|!=)\s+"')),
    ("F-threshold",     re.compile(r'\b-(lt|le|gt|ge)\b|\$\(\(')),
    ("E-presence",      re.compile(r'\[\s+-[fdsxe]\s|\[\s+-n\s|\[\s+-z\s')),
]


def branch_paths(lines):
    """Map 1-based lineno -> tuple of (if_id, branch_index).

    Two lines are CO-REACHABLE iff they agree on every `if` they share.  This is
    what keeps gate_xmss_signer.sh's two VMOUT comparisons — one per arm of
    `if SIGNER_VM_ONLY` — from reading as a contradiction.
    """
    out, stack, nextid = {}, [], [0]
    for n, raw in enumerate(lines, 1):
        s = raw.strip()
        if re.match(r'^if\s|\bif\s+\[', s) and not s.startswith('#'):
            nextid[0] += 1
            stack.append([nextid[0], 0])
        elif re.match(r'^(elif|else)\b', s) and stack:
            stack[-1][1] += 1
        out[n] = tuple(tuple(x) for x in stack)
        if re.match(r'^fi\b', s) and stack:
            stack.pop()
    return out


def coreachable(p, q):
    """True unless p and q sit in different branches of a shared `if`."""
    qd = dict(q)
    for ifid, br in p:
        if ifid in qd and qd[ifid] != br:
            return False
    return True


def find_implied(path, lines):
    """The G-implied detector.  Returns [(lineno, a, b, const, ref_a, ref_b)]."""
    bp = branch_paths(lines)
    # var -> [(const_name, lineno)] for `[ "$var" = "$CONST" ]`
    against = defaultdict(list)
    cmps = []
    for n, raw in enumerate(lines, 1):
        if raw.strip().startswith('#'):
            continue
        for m in CMP_VV.finditer(raw):
            a, op, b = m.group(1), m.group(2), m.group(3)
            if op != '=':
                continue
            cmps.append((n, a, b))
            against[a].append((b, n))
            against[b].append((a, n))
    hits = []
    for n, a, b in cmps:
        # does some constant C exist that BOTH a and b are separately compared to,
        # each co-reachable with this line?
        for ca, na in against[a]:
            if ca == b or na == n:
                continue
            for cb, nb in against[b]:
                if cb == a or nb == n or cb != ca:
                    continue
                if coreachable(bp[n], bp[na]) and coreachable(bp[n], bp[nb]):
                    hits.append((n, a, b, ca, na, nb))
                    break
            else:
                continue
            break
    return hits


def classify(ctx):
    for name, rx in SHAPES:
        if rx.search(ctx):
            return name
    return "Z-unclassified"


def marker_of(ctx):
    m = re.search(r"grep\s+-q[a-zA-Z]*\s+(['\"])(.*?)\1", ctx)
    return m.group(2) if m else None


def suspects(ctx, cls, marker):
    out = []
    if marker is not None:
        s = marker.strip()
        if re.fullmatch(r'\$[0-9A-Za-z_{}]+', s):
            return out
        if cls in ("A-byte-identity", "B-exact-string") and s:
            return out
        if s == "":
            out.append((3, "EMPTY marker — contained in every output; cannot fail"))
        elif len(s) <= 2:
            out.append((3, f"marker {marker!r} is {len(s)} char(s) — over-matches trivially"))
        if s.upper() in ("PASS", "OK", "DONE", "SUCCESS", "TRUE", "T"):
            out.append((3, f"asserts the word {s!r} — checks that it RAN, not that it was RIGHT"))
    if cls == "E-presence":
        out.append((2, "presence-only — a file existing is not a file being correct"))
    if cls == "F-threshold":
        out.append((2, "absolute threshold — a resize can void it silently; prefer a RATIO"))
    if cls == "Z-unclassified":
        out.append((1, "shape not recognised — read it by hand"))
    last = ctx.rsplit("\n", 1)[-1]
    if re.search(r'\$\(\(|\bawk\b|\bbc\b', last) and "cmp -s" not in last:
        out.append((2, "computes a value inline — if the MEASUREMENT fails soft the "
                       "assertion never runs and the gate still exits 0"))
    return out


def audit(path, suspects_only=False, quiet=False):
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    rows = []
    WINDOW = 6
    for n, line in enumerate(lines, 1):
        if line.strip().startswith('#') or not FAILLINE.search(line):
            continue
        ctx = "\n".join(lines[max(0, n - 1 - WINDOW):n])
        cls = classify(ctx)
        mk = marker_of(ctx)
        rows.append((n, cls, mk, suspects(ctx, cls, mk), line.strip()))

    implied = find_implied(path, lines)
    for n, a, b, c, na, nb in implied:
        rows.append((n, "G-implied", None,
                     [(3, f"IMPLIED: ${a} and ${b} are each checked against ${c} "
                          f"(lines {na}, {nb}), so this comparison CANNOT go red on its "
                          f"own. Compare ${b} to ${a} instead of both to ${c}.")],
                     lines[n - 1].strip()))

    flagged = [r for r in rows if r[3]]
    if not quiet:
        show = flagged if suspects_only else rows
        for n, cls, mk, flags, text in sorted(show, key=lambda r: -max([f[0] for f in r[3]], default=0)):
            if not flags and suspects_only:
                continue
            top = max([f[0] for f in flags], default=0)
            bar = {3: "!!!", 2: " !!", 1: "  !"}.get(top, "   ")
            print(f"{bar} {path}:{n}  [{cls}]")
            if mk is not None:
                print(f"      marker: {mk!r}")
            for sev, why in flags:
                print(f"      -> {why}")
            if flags:
                print(f"      | {text[:100]}")
                print()
    return rows, flagged, implied


# ── CALIBRATION ─────────────────────────────────────────────────────────────
# ★ Four KNOWN-dead lines this detector must reproduce, and one KNOWN-live line
#   it must NOT flag.  Established by hand 2026-08-27 before the tool existed, so
#   the tool is being tested against them rather than defining them.
KNOWN_DEAD = {
    "gate_sha256.sh":   41,
    "gate_wotsp.sh":    94,
    "gate_xmss.sh":     79,
    "gate_xmssidx.sh": 123,
}
KNOWN_LIVE = "gate_xmss_signer.sh"   # VM is compared to HOST, not both to E


def selftest(root):
    ok = True
    print("CALIBRATION — the detector must reproduce what is already known.\n")
    for fn, want in KNOWN_DEAD.items():
        p = os.path.join(root, fn)
        if not os.path.exists(p):
            print(f"  MISS  {fn}: not present at {root} — cannot calibrate"); ok = False; continue
        _, _, imp = audit(p, quiet=True)
        got = [h[0] for h in imp]
        if want in got:
            print(f"  ok    {fn}:{want} flagged G-implied")
        else:
            print(f"  FAIL  {fn}: expected a G-implied hit at line {want}, got {got or 'none'}"); ok = False
    p = os.path.join(root, KNOWN_LIVE)
    if not os.path.exists(p):
        print(f"  MISS  {KNOWN_LIVE}: not present — the NEGATIVE control cannot run"); ok = False
    else:
        _, _, imp = audit(p, quiet=True)
        if imp:
            print(f"  FAIL  {KNOWN_LIVE}: flagged {[h[0] for h in imp]} but its VM leg is "
                  f"compared to the HOST, not to the constant — false positive"); ok = False
        else:
            print(f"  ok    {KNOWN_LIVE} NOT flagged (negative control)")

    # the FAIL-line detector must see all three idioms, or the triage silently
    # covers a third of the surface and reports a clean sweep.
    for fn, idiom in (("gate_xmss.sh", 'echo "FAIL'), ("gate_asmelf.sh", "printf 'FAIL"),
                      ("gate_bootelf.sh", 'die "')):
        p = os.path.join(root, fn)
        if not os.path.exists(p):
            print(f"  MISS  {fn}: absent — cannot confirm the {idiom!r} idiom is seen"); continue
        rows, _, _ = audit(p, quiet=True)
        n = len([r for r in rows if r[1] != "G-implied"])
        print(f"  {'ok   ' if n else 'FAIL '} {fn}: {n} assertion(s) seen via {idiom!r}")
        if not n:
            ok = False
    print("\n" + ("CALIBRATION PASSED — clean reports from this tool mean something."
                  if ok else
                  "★ CALIBRATION FAILED — do NOT believe any report from this tool."))
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("files", nargs="*")
    ap.add_argument("--suspects", action="store_true")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--root", default=".", help="dir the --selftest fixtures live in")
    a = ap.parse_args()
    if a.selftest:
        return selftest(a.root)
    if not a.files:
        ap.error("give gate files, or --selftest")
    tot = fl = 0
    per_class = Counter()
    for f in a.files:
        if not os.path.exists(f):
            print(f"SKIP {f}: absent"); continue
        rows, flagged, _ = audit(f, a.suspects)
        tot += len(rows); fl += len(flagged)
        for r in rows:
            per_class[r[1]] += 1
    print("=" * 78)
    print(f"gates audited     : {len(a.files)}")
    print(f"assertions parsed : {tot}")
    print(f"flagged for review: {fl}")
    print("by class          : " + ", ".join(f"{k}={v}" for k, v in sorted(per_class.items())))
    print("\n★ A clean report is NOT evidence a gate can fail — only that this tool")
    print("found nothing. Every survivor needs one human line: the input that would")
    print("make it go RED. Run --selftest first; an uncalibrated sweep proves nothing.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
