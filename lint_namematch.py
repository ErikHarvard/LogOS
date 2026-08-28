#!/usr/bin/env python3
"""lint_namematch — flag a NAME matched against TEXT without anchoring, and give
tools a reconcile() they can call instead of a paragraph they can read.

WHY THIS EXISTS, AND WHY DOCUMENTATION WAS NOT ENOUGH
-----------------------------------------------------
On 2026-08-27 this project documented the substring-matching class in the morning
and then produced FIVE instances of it before the day ended, in five different
tools, every one written AFTER the class was documented:

  1. a ` no` scan matching the word "NOT" inside an archclosure gate
  2. a dependency scan matching `basename $f` -> `.bootelf_fix/asm.la` collided
     with the tracked `asm.la` at repo root: 45 false positives, each confidently
     formatted with a real "depended on by:" file list
  3. an instrument-substring mis-fire recorded the same morning in memory
  4. a gate-assertion scan whose FAIL regex saw one of three shell idioms, so it
     read 51 of 96 checks and reported CLEAN
  5. a "newest build log" lookup that matched the right glob in the wrong
     directory and returned a log four days stale, at 93 PASS, confidently

Prose does not reach the moment you type `grep -c "$name"`. A check does. This is
that check — narrow on purpose: ONE shape, the one with five instances.

WHAT IT FLAGS
-------------
A NAME (a filename, an identifier, a variable holding either) compared against a
body of TEXT with no word boundary, no path anchor, and no exact-match flag:

    shell   grep "$f" file            -> substring; `asm.la` matches `x/asm.la`
            grep -c "$name" build.sh  -> counts occurrences of a SUBSTRING
            case "$x" in *"$y"*)      -> substring by construction
            basename "$p" used as a needle at all
    python  if name in text           -> substring
            re.search(var, text)      -> unanchored unless the var is

AND WHAT IT DOES NOT
--------------------
It does not flag a literal grep for a fixed phrase, `grep -w`, `grep -x`,
`grep -F` with anchors, or a python `==`. ★ It is tuned to MISS rather than to cry
wolf: Audit II's first run produced three top-severity false positives and the
lesson recorded then was that a triage tool which cries wolf gets ignored. A lint
nobody runs is worth less than the paragraph it replaced.

THE OTHER HALF — reconcile()
----------------------------
The second-commonest failure was not matching, it was believing a count. A scan
reported 15 untracked files where the truth was 24; a tool parsed 51 checks of 96
and said CLEAN. Both would have been caught by comparing against a count obtained
some OTHER way, before acting. That is a two-line function, so it is provided as
one rather than as advice:

    from lint_namematch import reconcile
    reconcile("MARK checks", surveyed=96, parsed=len(found))   # raises on mismatch

USAGE
    lint_namematch.py --selftest          # calibrate FIRST
    lint_namematch.py *.sh *.py
"""
import argparse, os, re, sys


class ReconcileError(AssertionError):
    pass


def reconcile(what, surveyed, parsed, tolerate=0):
    """Refuse to proceed when an independent count disagrees with the tool's.

    `surveyed` must come from somewhere the tool does not: a shell one-liner, a
    survey taken before the tool existed, `git status --porcelain`. Reconciling a
    tool against itself proves nothing.
    """
    if abs(surveyed - parsed) > tolerate:
        raise ReconcileError(
            f"{what}: independently counted {surveyed}, tool parsed {parsed} — "
            f"{abs(surveyed - parsed)} unaccounted for. Do NOT act on this output "
            f"or report it as clean; the gap is the finding.")
    return True


# ── shell ───────────────────────────────────────────────────────────────────
ANCHORED = re.compile(r'-\w*[wx]\w*\b')          # grep -w / -x (also -qw, -rw)
GREP_VAR = re.compile(r'\bgrep\b([^|;&\n]*?)(["\']?)\$\{?(\w+)\}?\2')
CASE_SUB = re.compile(r'\bcase\s+"?\$\{?(\w+)\}?"?\s+in[^\n]*\*["\']?\$\{?(\w+)\}?')
BASENAME = re.compile(r'\$\(\s*basename\b|`basename\b')
# ★ Anchoring is not only a FLAG. `grep -qE "UND[[:space:]]+$sym\$"` is anchored at
#   both ends by the REGEX -- front by a literal prefix, back by \$ -- and the first
#   real run flagged exactly that line in gate_asmelf_extern.sh:59. A lint that
#   condemns correct code gets switched off, so pattern anchors count too.
REGEX_ANCHOR = re.compile(r'\\\$|\\b|\^')

# ── python ──────────────────────────────────────────────────────────────────
PY_IN = re.compile(r'\bif\s+(\w*(?:name|file|fn|path|base|glyph|mod)\w*)\s+in\s+(\w+)\b', re.I)
PY_RE = re.compile(r'\bre\.(search|match|findall|finditer)\(\s*(\w+)\s*,')

NAMEISH = re.compile(r'name|file|fn|path|base|glyph|mod|needle|pat|sym', re.I)


BASE_ASSIGN = re.compile(r'\b(\w+)=\$\(\s*basename\b|\b(\w+)=`basename\b')


def name_derived_vars(text):
    """Variables assigned from `basename` ARE names, whatever they are called.

    ★ The first calibration run failed exactly here. The fixture assigned
    `b=$(basename "$f")` on one line and matched `grep -q "$b"` on the NEXT, and
    the detector wanted both on one line — so the single most consequential shape
    of the day (45 false positives from a basename collision) did not fire, while
    every other positive did. A one-line window is not enough for a value that
    travels; and `b` is too short to look name-ish, so the generic detector missed
    it too. Two misses compounding, caught only because the self-test names each
    positive individually rather than reporting a total.
    """
    out = set()
    for m in BASE_ASSIGN.finditer(text):
        out.add(m.group(1) or m.group(2))
    return out


def lint_shell(text, path):
    out = []
    derived = name_derived_vars(text)
    for n, line in enumerate(text.splitlines(), 1):
        s = line.strip()
        if s.startswith('#'):
            continue
        for m in GREP_VAR.finditer(line):
            flags, _, var = m.group(1), m.group(2), m.group(3)
            if ANCHORED.search(flags) or REGEX_ANCHOR.search(line):
                continue
            if not NAMEISH.search(var) and var not in derived:
                continue
            out.append((n, "basename-as-needle" if var in derived else "grep-unanchored",
                        (f"${var} holds a `basename` and is matched as a SUBSTRING — two "
                         f"different files share a basename, which is how 45 false positives "
                         f"were produced. Match the FULL PATH."
                         if var in derived else
                         f"`grep` matches ${var} as a SUBSTRING — `asm.la` also matches "
                         f"`x/asm.la`. Use `grep -w` for an identifier, `grep -Fx` for a "
                         f"whole line, or compare paths exactly."), s[:100]))
        for m in CASE_SUB.finditer(line):
            out.append((n, "case-substring",
                        f"`case` glob `*$" + m.group(2) + "*` is a substring test by "
                        f"construction. Match the whole word, or compare with `=`.", s[:100]))
        if BASENAME.search(line) and re.search(r'\bgrep\b|\bcase\b|\bin\b', line):
            out.append((n, "basename-as-needle",
                        "a `basename` is being used as a match needle — two different "
                        "files share a basename, which is exactly how 45 false positives "
                        "were produced. Match the full path.", s[:100]))
    return out


def lint_python(text, path):
    """★ Skips triple-quoted regions. The first real run flagged this file's OWN
    docstring, where the defect is being DESCRIBED — a lint that cannot tell code
    from prose about code is noise, and noise is how the class survived."""
    out = []
    in_doc = False
    for n, line in enumerate(text.splitlines(), 1):
        s = line.strip()
        q = line.count('"""') + line.count("\'\'\'")
        if in_doc:
            if q:
                in_doc = False
            continue
        if q == 1:
            in_doc = True
            continue
        if s.startswith('#'):
            continue
        for m in PY_IN.finditer(line):
            out.append((n, "py-in-substring",
                        f"`{m.group(1)} in {m.group(2)}` is a SUBSTRING test. For a name, "
                        f"compare exactly or split the text into tokens first.", s[:100]))
        for m in PY_RE.finditer(line):
            if NAMEISH.search(m.group(2)):
                out.append((n, "py-re-unanchored",
                            f"`re.{m.group(1)}({m.group(2)}, …)` uses a variable as a "
                            f"pattern with no boundary — wrap it: `rf'\\b{{re.escape("
                            f"{m.group(2)})}}\\b'`.", s[:100]))
    return out


def lint(path):
    text = open(path, encoding='utf-8', errors='replace').read()
    if path.endswith('.py'):
        return lint_python(text, path)
    if path.endswith(('.sh', '.bash')) or text.startswith('#!'):
        return lint_shell(text, path)
    return []


# ── CALIBRATION ─────────────────────────────────────────────────────────────
# Fixtures are EMBEDDED so the self-test cannot drift from an external file, and
# each positive is a shape that actually occurred on 2026-08-27.
POS = {
 "basename-as-needle": '#!/bin/sh\nfor f in $LIST; do\n  b=$(basename "$f")\n  grep -q "$b" build.sh && echo "depended on by: $f"\ndone\n',
 "grep-unanchored":    '#!/bin/sh\nname=asm.la\nn=$(grep -c "$name" build.sh)\necho "$n"\n',
 "case-substring":     '#!/bin/sh\ncase "$out" in *"$modname"*) echo hit ;; esac\n',
 "py-in-substring":    'def f(filename, text):\n    if filename in text:\n        return True\n',
 "py-re-unanchored":   'import re\ndef f(modname, text):\n    return re.search(modname, text)\n',
}
# Each negative is the CORRECT form of the positive above it. If these fire, the
# lint condemns correct code and will be turned off within a day.
NEG = {
 "grep -w":     '#!/bin/sh\nname=asm.la\nn=$(grep -cw "$name" build.sh)\necho "$n"\n',
 "grep -Fx":    '#!/bin/sh\ngrep -Fxq "$path" manifest.txt\n',
 "case equals": '#!/bin/sh\nif [ "$out" = "$modname" ]; then echo hit; fi\n',
 "py ==":       'def f(filename, names):\n    return any(filename == n for n in names)\n',
 "py anchored": 'import re\ndef f(modname, text):\n    return re.search(rf"\\b{re.escape(modname)}\\b", text)\n',
 "literal":     '#!/bin/sh\ngrep -c "^PASS" build.sh\n',
 # ★ both of these fired on the lint's FIRST real run and were wrong; they are
 #   negative controls now so the fix cannot silently regress.
 "regex-anchored": '#!/bin/sh\nreadelf -sW "$O" | grep -qE "UND[[:space:]]+$sym\\$"\n',
 "docstring prose": '\"\"\"describes the bug:\n    if name in text  -> substring\n\"\"\"\ndef g():\n    return 1\n',
}


def selftest(tmp):
    ok = True
    print("CALIBRATION — every positive must fire, every negative must stay silent.\n")
    os.makedirs(tmp, exist_ok=True)
    for want, src in POS.items():
        ext = '.py' if want.startswith('py-') else '.sh'
        p = os.path.join(tmp, f"pos_{want}{ext}")
        open(p, 'w').write(src)
        kinds = [k for _, k, _, _ in lint(p)]
        if want in kinds:
            print(f"  ok    positive {want!r} fires")
        else:
            print(f"  FAIL  positive {want!r} did NOT fire (got {kinds or 'nothing'})"); ok = False
    print()
    for label, src in NEG.items():
        ext = '.py' if label.startswith('py') else '.sh'
        p = os.path.join(tmp, f"neg_{label.replace(' ', '_')}{ext}")
        open(p, 'w').write(src)
        hits = lint(p)
        if hits:
            print(f"  FAIL  negative {label!r} fired {[k for _,k,_,_ in hits]} — this lint "
                  f"condemns correct code and will be switched off"); ok = False
        else:
            print(f"  ok    negative {label!r} silent")

    # ★ the reconcile helper must itself refuse on a mismatch, or it is decoration
    print()
    try:
        reconcile("selftest", surveyed=96, parsed=51)
        print("  FAIL  reconcile() did not raise on 96 vs 51 — the helper is inert"); ok = False
    except ReconcileError:
        print("  ok    reconcile() refuses on a mismatch")
    try:
        reconcile("selftest", surveyed=96, parsed=96)
        print("  ok    reconcile() passes when the counts agree")
    except ReconcileError:
        print("  FAIL  reconcile() raised on equal counts"); ok = False

    print("\n" + ("CALIBRATION PASSED — this lint may be believed."
                  if ok else "★ CALIBRATION FAILED — do NOT believe this lint."))
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("files", nargs="*")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--tmp", default="/tmp/lint_namematch_fixtures")
    a = ap.parse_args()
    if a.selftest:
        return selftest(a.tmp)
    if not a.files:
        ap.error("give files, or --selftest")
    scanned = total = 0
    for f in a.files:
        if not os.path.exists(f):
            continue
        scanned += 1
        for n, kind, why, src in lint(f):
            total += 1
            print(f"!! {f}:{n}  [{kind}]\n   -> {why}\n   |  {src}\n")
    # coverage, reported not assumed: a lint silently skipping files reads clean
    print("=" * 76)
    print(f"files given {len(a.files)} · scanned {scanned} · findings {total}")
    if scanned != len(a.files):
        print(f"★ {len(a.files) - scanned} file(s) were NOT scanned — a clean report here "
              f"covers only what was read.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
