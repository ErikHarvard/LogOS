#!/usr/bin/env python3
"""audit_gates — triage every assertion in build.sh by DISCRIMINATING POWER.

WHY
---
Freeze-Day Audit II asks a question the first audit did not: *which assertions
cannot go RED?*  A check that cannot fail is not a check.  Four have been found
in this codebase, every one by accident while looking at something else:

  1. an empty marker, contained in every output -> the step PASSed unconditionally
  2. a gate on a state the type system makes UNCONSTRUCTIBLE (>2-parent node)
  3. a reclamation gate voided when HEAP_SIZE went 1.5 -> 16 GiB: it now passes
     with ZERO reclamation while its text still claims "impossible without"
  4. a gate whose MEASUREMENT step died on an octal parse -- the assertion never
     ran and it still exited 0

build.sh has ~600 FAIL assertions.  Hand-reviewing all of them is not finite, so
this AUTOMATES THE TRIAGE and leaves humans the suspects.

WHAT IT IS NOT
--------------
A heuristic, not an oracle.  It parses bash with regexes; it will misclassify.
Its output is a RANKED WORKLIST, and a clean report is NOT evidence that a gate
can fail -- only that this tool found nothing to flag.  Every survivor still
needs one human line: *the input that would make this go red.*

USAGE
    audit_gates.py [--file build.sh] [--class E] [--suspects] [--section PAT]
"""
import argparse, os, re, sys
from collections import Counter, defaultdict

SAY   = re.compile(r'^say\s+"(.+?)"')
# assertion shapes, strongest first
SHAPES = [
    ("A-byte-identity", re.compile(r'\bcmp\s+-s\b')),
    ("D-exit+diag",     re.compile(r'\brc\b.*=|\breturncode\b|\bexit\s+code\b|"\$\?"')),
    ("B-exact-string",  re.compile(r'\bgrep\s+-q[a-zA-Z]*F[a-zA-Z]*\b|\bgrep\s+-qx\b')),
    ("C-pattern",       re.compile(r'\bgrep\s+-q\b')),
    ("F-threshold",     re.compile(r'\b-(lt|le|gt|ge)\b|\$\(\(')),
    ("E-presence",      re.compile(r'\[\s+-[fdsxe]\s|\[\s+-n\s|\[\s+-z\s')),
    # ★ APPENDED 2026-08-26 (Freeze II, finishing the Z pile). The first run left
    #   251 rows "Z-unclassified", read as 251 gates needing hand review. They were
    #   not: the table was simply MISSING build.sh's most common assertion idioms.
    #   Bucketing the Z rows by what their window actually contained gave
    #   str-eq 128 · case/esac 40 · numeric-eq 13 · diff 13 — i.e. the tool was
    #   reporting its own blind spot as a property of the code.
    #   ★ These are APPENDED, never reordered: classify() returns the FIRST match,
    #   so appending can only reclassify rows that were already Z. A/B/C/D/E/F
    #   counts are unchanged by construction, and that is asserted in the tests.
    ("G-string-eq",     re.compile(r'\[\s*"?\$[A-Za-z_{(][^]]*"?\s*!?=\s')),
    ("H-numeric-eq",    re.compile(r'\s-(eq|ne)\s')),
    ("J-diff",          re.compile(r'\bdiff\b')),
    ("I-case-dispatch", re.compile(r'\bcase\b.*\bin\b|\besac\b')),
    # ★ The POSITIVE complement of the negative class: `cmd || { echo "FAIL" ...; }`
    #   asserts the command MUST SUCCEED. Sound by construction on the never-ran
    #   axis -- a missing binary exits non-zero and the gate goes RED, correctly and
    #   for the right reason. This is why it is a separate class from N: the same
    #   accident that makes a NEGATIVE assertion silently green makes a POSITIVE one
    #   loudly red. All four rows still unrecognised at a 40-line window were this.
    ("K-must-succeed",  re.compile(r'\|\|\s*\{\s*echo\s+"FAIL')),
]

# ★ THE NEGATIVE-ASSERTION CLASS (new 2026-08-26, and the audit's first proven
#   defect came out of it).  Shape:  `cmd && { echo "FAIL ..."; ok=0; }`
#   The assertion is "cmd must FAIL". It therefore passes on ANY non-zero exit —
#   including exits for the WRONG REASON: the binary is missing, its input was
#   never written, it died on a parse error unrelated to the property under test.
#   A negative assertion is only sound if something PAIRS with it to prove the
#   step actually ran and failed for the stated reason. That pairing is what
#   distinguishes "the compiler correctly refused" from "there was no compiler".
NEGATIVE = re.compile(r'&&\s*\{\s*echo\s+"FAIL')
# evidence that the same run was independently observed: a positive assertion on
# its output, an exact rc, or a byte-comparison.
#   ★ CALIBRATION 3 (2026-08-26) — this detector's FIRST verdicts included two
#   false positives of its own, and they are recorded here for the same reason
#   calibrations 1 and 2 are: a triage tool that cries wolf gets ignored, and one
#   that cries "sound" is worse. `[ "$ok" -eq 1 ]` is the VERDICT AGGREGATOR that
#   closes every gate block in build.sh. It says nothing about any particular
#   assertion, yet it matched the rc arm and certified build.sh:2622 and :2691 as
#   PAIRED. Pairing must be evidence about THIS run, so the aggregator variables
#   are excluded by name.
AGG = r'(?!ok\b|rc\b)'
PAIRED = re.compile(r'grep\s+-q|cmp\s+-s'
                    r'|\[\s*"?\$\{?' + AGG + r'\w+"?\s*-eq\s'
                    r'|\[\s*"?\$\{?' + AGG + r'\w+"?\s*=\s')
FAILLINE = re.compile(r'echo\s+"FAIL')

def marker_of(line):
    """Best-effort: the literal a grep is matching."""
    m = re.search(r"grep\s+-q[a-zA-Z]*\s+(['\"])(.*?)\1", line)
    return m.group(2) if m else None

def classify(line):
    for name, rx in SHAPES:
        if rx.search(line):
            return name
    return "Z-unclassified"

def suspects(line, cls, marker, section):
    """Return list of (severity, reason) flags. Severity 3 = review first."""
    out = []
    if marker is not None:
        s = marker.strip()
        # ★ CALIBRATION (2026-08-18): the first run's three top-severity flags were
        #   ALL false positives -- '$1'/'$3' are shell VARIABLES in helper functions,
        #   not literals, and 'TF' is a legitimate 2-char expected value on a
        #   byte-identity check. A triage tool that cries wolf gets ignored, so:
        #   skip pure variable references, and do not penalise short markers when the
        #   assertion is already a STRONG class (byte-identity / exact-string).
        if re.fullmatch(r'\$[0-9A-Za-z_{}]+', s):
            return out
        if cls in ("A-byte-identity", "B-exact-string") and s:
            return out
        if s == "":
            out.append((3, "EMPTY marker — contained in every output; cannot fail"))
        elif len(s) <= 2:
            out.append((3, f"marker {marker!r} is {len(s)} char(s) — over-matches trivially"))
        elif len(s) <= 5 and not any(c.isdigit() for c in s):
            out.append((2, f"marker {marker!r} is very short — check it cannot over-match"))
        if s.upper() in ("PASS", "OK", "DONE", "SUCCESS", "TRUE", "T"):
            out.append((3, f"asserts the word {s!r} — checks that it RAN, not that it was RIGHT"))
    if cls == "E-presence":
        out.append((2, "presence-only ([-f]/[-n]) — a file existing is not a file being correct"))
    if cls == "F-threshold":
        out.append((2, "absolute threshold — the 24B-reclamation defect: a resize can void it "
                       "silently. Prefer a RATIO; a ratio cannot be gutted by rescaling"))
    if cls == "Z-unclassified":
        out.append((1, "shape not recognised — read it by hand"))
    # a measurement computed inside the gate, not itself checked (defect #4).
    # ★ CALIBRATION 2: only the ASSERTION's own line counts. Matching the whole
    #   lookback window flagged setup arithmetic (`head -$((BCM-1))`) as if it were
    #   part of the check -- two false positives at build.sh:2321-2322, whose real
    #   assertions are exact string equality and perfectly strong.
    last = line.rsplit("\n", 1)[-1]
    if re.search(r'\$\(\(|\bawk\b|\bbc\b|%e|%M', last) and "cmp -s" not in last:
        out.append((2, "computes a value inline — if the MEASUREMENT fails soft the "
                       "assertion never runs and the gate still exits 0. Assert you measured."))
    return out

def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--file", default="build.sh")
    ap.add_argument("--suspects", action="store_true", help="only flagged lines")
    ap.add_argument("--klass", default=None, help="filter to one class, e.g. E-presence")
    ap.add_argument("--section", default=None, help="regex filter on section title")
    a = ap.parse_args()
    if not os.path.exists(a.file):
        print(f"SKIP audit_gates: no {a.file}"); return 0

    # ★ Classify on a WINDOW, not the FAIL line alone.  Most assertions live in an
    #   `if`/`||` above their `echo "FAIL"`, so same-line matching left ~90% of them
    #   unclassified -- a useless tool, not a finding.  Look back up to WINDOW lines.
    WINDOW = 6
    lines = open(a.file, encoding="utf-8", errors="replace").read().splitlines()
    section, rows, sec_at = "(preamble)", [], {}
    for n, line in enumerate(lines, 1):
        m = SAY.match(line)
        if m: section = m.group(1)[:70]
        sec_at[n] = section
    for n, line in enumerate(lines, 1):
        if not FAILLINE.search(line):
            continue
        ctx = "\n".join(lines[max(0, n - 1 - WINDOW):n])   # the FAIL line + lookback
        cls    = classify(ctx)
        marker = marker_of(ctx)
        flags  = suspects(ctx, cls, marker, sec_at[n])
        # ★ negative assertions: judged on the FAIL LINE itself, and paired against
        #   BOTH directions — many gates assert the diagnostic on the lines AFTER.
        if NEGATIVE.search(line):
            fwd = "\n".join(lines[n:min(len(lines), n + 4)])
            if PAIRED.search(ctx + "\n" + fwd):
                flags.append((1, "negative assertion (`cmd && FAIL`) — PAIRED with a "
                                 "positive check on the same run; sound"))
            else:
                flags.append((3, "NEGATIVE assertion with NOTHING proving the step ran: "
                                 "passes on any non-zero exit, so 'correctly refused' and "
                                 "'never ran at all' are indistinguishable"))
        rows.append((n, sec_at[n], cls, marker, flags, line.strip()))

    if a.klass:   rows = [r for r in rows if r[2] == a.klass]
    if a.section: rows = [r for r in rows if re.search(a.section, r[1], re.I)]
    flagged = [r for r in rows if r[4]]
    if a.suspects: rows = flagged

    by_cls = Counter(r[2] for r in rows)
    by_sec = defaultdict(int)
    for r in flagged: by_sec[r[1]] += 1

    for n, sec, cls, marker, flags, text in sorted(rows, key=lambda r: -max([f[0] for f in r[4]], default=0)):
        if not (a.suspects or flags): continue
        top = max([f[0] for f in flags], default=0)
        bar = {3: "!!!", 2: " !!", 1: "  !"}.get(top, "   ")
        print(f"{bar} {a.file}:{n}  [{cls}]  {sec}")
        if marker is not None: print(f"      marker: {marker!r}")
        for sev, why in flags: print(f"      -> {why}")
        print()

    print("="*78)
    print(f"assertions parsed : {len(rows)}")
    print(f"flagged for review: {len(flagged)}")
    print("by class          : " + ", ".join(f"{k}={v}" for k, v in sorted(by_cls.items())))
    if by_sec:
        print("\ntop sections by flag count (review these first):")
        for sec, c in sorted(by_sec.items(), key=lambda kv: -kv[1])[:8]:
            print(f"  {c:3}  {sec}")
    print("\nNOTE: a clean report is NOT evidence a gate can fail — only that this")
    print("tool found nothing to flag. Every survivor still needs one human line:")
    print("the input that would make it go RED.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
