#!/bin/sh
# gate_abspath.sh — no tracked CODE file may hardcode an absolute home path.
#
# ── THE DEFECT THIS EXISTS FOR (found 2026-08-18, in committed code) ────────
# kernel/gen_nic5q.py wrote its output to:
#       path = "/home/<user>/logos-d/kernel/nic5q.la"
# Running that generator from ANY other worktree would reach across and
# overwrite track D's source. That is precisely the cross-session collision the
# worktree isolation exists to prevent — and it is a case the isolation CANNOT
# catch: `logos-agent` gives each session a private /tmp, and this path is in
# $HOME. The one mechanism designed for this class of failure does not reach it.
#
# It was found by a scan run before publishing to a public repo, not by any
# gate. Nothing in the build looks for this. Hence this file.
#
# ── WHY THE RULE IS NARROW, AND MEASURED RATHER THAN GUESSED ────────────────
# The obvious rule — "no absolute paths" — is useless here: build.sh alone
# hardcodes ~481 /tmp paths by design. And "no ~/logos references" would fire on
# 66 tracked files, 57 of which use the CORRECT idiom
#       cd "$(dirname "$0")/.."          # -> ~/logos
# where the path appears only in a trailing comment. A gate that is RED on
# arrival gets disabled, so it would protect nothing.
#
# What was measured instead (all four branches, 2026-08-18): ZERO tracked code
# files contain a literal /home/<user>/ path, and ZERO reference a sibling
# worktree. So this rule is green on arrival, and it would have caught the real
# bug. That is the whole design: one rule, unambiguous, currently true.
set -u
cd "$(dirname "$0")" || exit 1
ok=1

# CODE = things that EXECUTE. A home path in prose is a stale doc; in a script
# it is a cross-worktree write waiting to happen. Different severities, and the
# gate says so rather than pretending they are the same defect.
CODE=$(git ls-files '*.sh' '*.py' '*.la' '*.c' '*.h' '*.asm' 2>/dev/null)
n_code=$(printf '%s\n' "$CODE" | grep -c .)

# ★ NON-VACUITY FIRST. Every verdict below is taken from this file list; if the
# list were empty (wrong cwd, not a repo, ls-files failing) then "no matches"
# would be trivially true and the gate would pass while checking nothing.
if [ "$n_code" -lt 50 ]; then
    echo "FAIL  abspath: only $n_code tracked code files found — the scan is not seeing the repo, so a clean result would mean nothing"
    exit 1
fi

# ── RULE 1 (HARD): a literal home path in a file that executes ─────────────
HITS=$(printf '%s\n' "$CODE" | xargs -r grep -nI '/home/[a-z_][a-z0-9_-]*/' 2>/dev/null)
if [ -n "$HITS" ]; then
    echo "FAIL  abspath: tracked CODE hardcodes an absolute home path — from another worktree this reads or writes the WRONG tree:"
    printf '%s\n' "$HITS" | sed 's/^/        /' | head -20
    echo "        Fix: derive from the file's own location, e.g."
    echo "          python: os.path.join(os.path.dirname(os.path.abspath(__file__)), \"x\")"
    echo "          shell:  cd \"\$(dirname \"\$0\")\""
    ok=0
else
    echo "PASS  abspath 1: none of $n_code tracked code files hardcodes an absolute home path"
fi

# ── REPORT (not a failure): code that names a worktree path ───────────────
# ★ THIS WAS A HARD RULE IN THE FIRST DRAFT AND IT WAS WRONG — recorded because
# it is the exact failure this gate's own design section warns about, committed
# in the same file. It flagged `logos-[bcd]` as "a sibling worktree" without
# accounting for WHICH worktree the gate runs in, so on track-d it fired on:
#   - CLAUDE.md naming ~/logos, ~/logos-b, ~/logos-c in order to say DO NOT
#     TOUCH THEM — the instruction that prevents the very thing being checked;
#   - `cd "$(dirname "$0")/.."   # -> ~/logos-d`, the CORRECT idiom, naming its
#     OWN worktree, in a COMMENT.
# Every hit was correct code. A rule whose first run is entirely false positives
# would have been switched off within a day, and the sharp rule above with it.
# So it is a REPORT: the count is visible, drift is noticeable, nothing fails on
# text that is doing its job.
WT=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
WTREFS=$(git ls-files '*.sh' '*.py' '*.la' '*.c' '*.h' '*.asm' 2>/dev/null \
         | xargs -r grep -lIE '(~|\$HOME)/logos' 2>/dev/null | grep -v '^gate_abspath.sh$')
n_wt=$(printf '%s\n' "$WTREFS" | grep -c .)
[ "$n_wt" -gt 0 ] && echo "NOTE  abspath: $n_wt tracked code file(s) mention a ~/logos… path (this worktree is '$WT'); reported, NOT a failure — most are the correct \`cd \"\$(dirname \"\$0\")/..\"\` idiom with the path in a trailing comment"

# ── REPORT (not a failure): prose ──────────────────────────────────────────
# A home path in a .md/.tex is a stale document, not a cross-worktree write. It
# is REPORTED so the count is visible and drift is noticed, and deliberately
# does NOT fail the gate — conflating it with rule 1 is how a sharp gate becomes
# one people stop reading.
PROSE=$(git ls-files '*.md' '*.tex' '*.txt' 2>/dev/null | xargs -r grep -lI '/home/[a-z_][a-z0-9_-]*/' 2>/dev/null | grep -v '^gate_abspath.sh$')
n_prose=$(printf '%s\n' "$PROSE" | grep -c .)
if [ "$n_prose" -gt 0 ]; then
    echo "NOTE  abspath: $n_prose prose file(s) mention an absolute home path (reported, NOT a failure):"
    printf '%s\n' "$PROSE" | sed 's/^/        /' | head -10
fi

# ── HONEST GAP, stated so a green is not over-read ─────────────────────────
echo "NOTE  abspath: NOT checked — a script writing outside its own worktree via \`~/logos\` or a relative"
echo "      escape. 66 tracked files reference ~/logos and 57 are the correct \`cd \"\$(dirname \"\$0\")/..\"\`"
echo "      idiom with the path in a COMMENT; grep cannot separate a mention from a write, and failing all"
echo "      66 would make this gate RED on arrival and therefore ignored. THIS GATE FAILS ON EXACTLY ONE THING:"
echo "      a literal /home/<user>/ path in a tracked file that executes. Everything else here is a REPORT."

[ "$ok" = 1 ] && echo "abspath gate GREEN" || { echo "abspath gate RED"; exit 1; }
