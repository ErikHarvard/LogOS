#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  build_kernel_half.sh — run build.sh's KERNEL HALF against a prebuilt
#  language half.
#
#  WHY THIS EXISTS
#  build.sh is 7511 lines. The kernel half is lines 7064-7485 — 422 lines, the
#  last 5.6% of the file, holding 65 of the file's 83 `|| exit 1` hard aborts.
#  Nothing reaches it until the entire language half passes, which is why every
#  verdict this project has produced is a verdict on the language half only.
#  MEASURED 2026-09-08: a build that ran for hours invoked ZERO gate scripts.
#
#  WHAT THE KERNEL HALF ACTUALLY NEEDS FROM THE LANGUAGE HALF
#  Traced through every kernel/*.sh reference — exactly two artifacts:
#      tiny_host                        gcc -O2 tiny_host.c, seconds
#      native_codegen3_selfhost.bin     COMMITTED TO GIT (9112c18), on disk
#  plus nasm / ld / objcopy / qemu. Every gate but gate_k1.sh builds its own
#  prerequisite, and gate_k1's ELF comes from the region's own build_k2.sh line.
#  The region references ZERO shell variables — it inherits nothing from the
#  7000 lines above it except say(), `set -euo pipefail`, and the cwd. That is
#  what makes lifting it exact rather than approximate.
#
#  ★ THE REGION IS EXTRACTED FROM build.sh AT RUN TIME, NOT COPIED.
#  A second copy of 422 lines would drift, and drift is this project's
#  characteristic defect: gate_bootelf.sh sits on disk invoked by nothing, and
#  ROADMAP called four PS/2 gates "DONE + gated" while nothing ran them. So
#  build.sh stays the ONE definition of what the kernel half is; a gate added
#  there runs here the same day with no second edit. The sentinels it is cut on
#  are two comment lines.
#
#  ★ THE REGION RUNS VERBATIM. Rewriting 65 `|| exit 1` clauses with sed would
#  be text-matching a shell grammar — the failure mode this repo has been bitten
#  by three times in one evening. Instead a shell FUNCTION named `bash`
#  intercepts each invocation, runs the real gate, classifies it, and returns 0
#  in tally mode, so `|| exit 1` never fires and the extracted text executes
#  byte-for-byte as build.sh executes it.
#
#  ★ SKIP IS A COUNTED, NAMED, EXIT-AFFECTING CLASS — and not only for gates
#  this script adds (it adds none). The 52 invoked kernel gates carry 57 SKIP
#  paths between them, each exiting 0 while asserting nothing, so a tally of
#  exit statuses shows nothing wrong. Here a SKIP is counted, named in the
#  summary, and forces exit status 2 (INCOMPLETE) — distinct from green and red.
#  A run that verified nothing cannot present itself as a run that passed.
#
#  EXIT STATUS
#      0   every selected gate PASSed, none skipped
#      1   at least one FAIL / UNKNOWN, or the runner could not run
#      2   no FAILs, but at least one gate SKIPped — INCOMPLETE, not green
#
#  USAGE
#      kernel/build_kernel_half.sh                  # the whole kernel half
#      kernel/build_kernel_half.sh --only 'hal4|comp_term'
#      kernel/build_kernel_half.sh --list           # manifest, run nothing
#      kernel/build_kernel_half.sh --dry-run        # print the extracted program
#      kernel/build_kernel_half.sh --abort-first    # build.sh's serial-abort semantics
#      kernel/build_kernel_half.sh --no-lock        # caller already holds the gate lock
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
cd "$(dirname "$0")/.."

BEGIN_MARK='# ===KERNEL-HALF-BEGIN==='
END_MARK='# ===KERNEL-HALF-END==='
# KH_SRC exists so this runner can be RED-TESTED against synthetic regions by
# kernel/gate_kernel_half.sh — a classifier that has only ever seen passing
# gates is an untested classifier, and an assertion never shown to reject is
# inert. It defaults to build.sh and is not a normal user knob.
SRC="${KH_SRC:-build.sh}"

ONLY=''; MODE=run; LOCK=1
while [ $# -gt 0 ]; do
    case "$1" in
        --only)        ONLY="${2:-}"; shift 2 ;;
        --only=*)      ONLY="${1#--only=}"; shift ;;
        --list)        MODE=list; shift ;;
        --dry-run)     MODE=dry;  shift ;;
        --abort-first) MODE=abort; shift ;;
        --no-lock)     LOCK=0; shift ;;
        -h|--help)     sed -n '2,55p' "$0"; exit 0 ;;
        *) echo "FAIL  build_kernel_half: unknown option '$1' (see --help)" >&2; exit 1 ;;
    esac
done

die() { echo "FAIL  build_kernel_half: $*" >&2; exit 1; }

# ── locate the region ────────────────────────────────────────────────────────
# A missing sentinel is a HARD ERROR. It must never degrade to a line-number
# guess or to running nothing: a runner that reports success having executed no
# gate is the precise defect this file exists to remove.
[ -f "$SRC" ] || die "$SRC not found (run from the repo root or via its own path)"
# ★ -x (WHOLE-LINE match), not a substring match. build.sh's own sentinel
# comment block NAMES the end marker in its prose, so a substring grep finds
# that prose line first and collapses the region to nothing. That happened on
# the first run of this script: `grep -nF` returned 7066 (prose) before 7508
# (the real marker). The anti-vacuity floor below caught it and refused, rather
# than executing an empty region and reporting a clean tally — but the matcher
# was still wrong, and it was wrong in this repo's characteristic way: a comment
# read as an execution path (the defect fixed in 041631a, reproduced here in the
# instrument written to avoid it).
# The prose occurrence is deliberately LEFT IN build.sh as a standing control:
# revert this to `grep -nF` and the region collapses and this runner refuses.
B=$(grep -nxF -- "$BEGIN_MARK" "$SRC" | head -1 | cut -d: -f1)
E=$(grep -nxF -- "$END_MARK"   "$SRC" | head -1 | cut -d: -f1)
[ -n "$B" ] || die "$BEGIN_MARK not found in $SRC — the sentinels were removed or lost in a merge; restore them around the kernel-gate block (this runner will NOT guess line numbers)"
[ -n "$E" ] || die "$END_MARK not found in $SRC — see above"
[ "$E" -gt "$B" ] || die "sentinels out of order in $SRC ($BEGIN_MARK at $B, $END_MARK at $E)"

REGION=$(sed -n "$((B+1)),$((E-1))p" "$SRC")
[ -n "$REGION" ] || die "the region between the sentinels is empty"

# ── account for EVERY invocation, or refuse to run ───────────────────────────
# Invocation-anchored, not bare-name: a bare-name grep over this region matches
# 9 scripts that appear only inside comments (the census error of 2026-09-08,
# reproduced deliberately here and rejected). Two shapes exist in the region:
#   64x   bash kernel/gate_X.sh [args] || exit 1     -> caught by the wrapper
#    1x   ./gate_buildla.sh            || exit 1     -> rewritten, asserted once
TOTAL=$(printf '%s\n' "$REGION" | grep -cE '^[[:space:]]*(bash|sh|\./)[^#]*gate_[a-z0-9_]*\.sh')
VIA_BASH=$(printf '%s\n' "$REGION" | grep -cE '^[[:space:]]*(bash|sh) +[^#]*gate_[a-z0-9_]*\.sh')
VIA_PATH=$(printf '%s\n' "$REGION" | grep -cE '^[[:space:]]*\./gate_[a-z0-9_]*\.sh')
[ "$TOTAL" -gt 0 ] || die "the region contains no gate invocations — an empty run cannot be a pass"
[ $((VIA_BASH + VIA_PATH)) -eq "$TOTAL" ] \
  || die "$TOTAL invocations in the region but only $((VIA_BASH+VIA_PATH)) can be routed ($VIA_BASH via the bash wrapper, $VIA_PATH via path-rewrite). A gate in an unrecognised shape would run UNCLASSIFIED, so this run is refused rather than reporting a tally that omits it"

# Route the direct-path invocations through the wrapper. Rewrite is targeted and
# counted: if it does not fire exactly VIA_PATH times, build.sh changed shape.
PROGRAM=$(printf '%s\n' "$REGION" | sed -E 's#^([[:space:]]*)\./(gate_[a-z0-9_]*\.sh)#\1bash ./\2#')
# ★ ASSERT THE PROPERTY, NOT A SIDE-EFFECT COUNT. The first version of this
# check counted lines matching `^bash \./gate_` in the OUTPUT and compared it to
# VIA_PATH — but that counts lines already in that form, not lines rewritten, so
# it read 1-vs-0 and refused on a region that was perfectly routed. It only ever
# worked because real build.sh happens to contain no `bash ./gate_*` line. The
# property actually needed is simply: after the rewrite, EVERY invocation goes
# through the wrapper and NONE is left executing directly. Say that.
POST_BASH=$(printf '%s\n' "$PROGRAM" | grep -cE '^[[:space:]]*(bash|sh) +[^#]*gate_[a-z0-9_]*\.sh')
POST_PATH=$(printf '%s\n' "$PROGRAM" | grep -cE '^[[:space:]]*\./[^#]*gate_[a-z0-9_]*\.sh')
[ "$POST_PATH" -eq 0 ] \
  || die "$POST_PATH invocation(s) still execute directly after the rewrite and would run UNCLASSIFIED — refusing rather than reporting a tally that omits them"
[ "$POST_BASH" -eq "$TOTAL" ] \
  || die "$TOTAL invocations in the region but $POST_BASH routed through the wrapper — refusing to run a partially-routed region"

# ── --list / --dry-run ───────────────────────────────────────────────────────
if [ "$MODE" = list ] || [ "$MODE" = dry ]; then
    if [ "$MODE" = dry ]; then
        echo "# extracted from $SRC lines $((B+1))-$((E-1)), path-invocations rewritten:"
        printf '%s\n' "$PROGRAM"
    else
        # ★ DISTINCT-SCRIPT COUNT IS TAKEN FROM INVOCATION LINES ONLY.
        # A bare `grep -oE 'gate_[a-z0-9_]*\.sh'` over the region returns 61,
        # not 52 — it matches the nine gate names that appear ONLY inside this
        # region's comments (gate_bootelf, gate_rss, gate_hal_idle, ...). That
        # is the census error of 2026-09-08, and it was reproduced here on the
        # first draft of this very listing. Count what RUNS, not what is named.
        DISTINCT=$(printf '%s\n' "$REGION" \
          | grep -E '^[[:space:]]*(bash|sh|\./)[^#]*gate_[a-z0-9_]*\.sh' \
          | grep -oE 'gate_[a-z0-9_]*\.sh' | sort -u | grep -c .)
        echo "kernel half: $SRC lines $((B+1))-$((E-1)) — $TOTAL invocations, $DISTINCT distinct scripts that RUN"
        echo "  (a bare-name grep over the same region reports more; those extras appear only in comments)"
        printf '%s\n' "$REGION" \
          | grep -nE '^[[:space:]]*(bash|sh|\./)[^#]*gate_[a-z0-9_]*\.sh' \
          | awk -F: -v b="$B" '{ n=$1; $1=""; sub(/^:/,""); printf "  %s:%d  %s\n", "build.sh", n+b, $0 }'
    fi
    exit 0
fi

# ── serialize against the other tracks ───────────────────────────────────────
# 37 gate scripts launch QEMU under budgets as tight as `timeout 20`. Two tracks
# in QEMU at once produce a red that means "the machine was busy" and costs an
# hour to disprove. Take the lock ONCE for the whole run rather than contending
# per gate. Re-exec, so the lock wraps every gate including their timeouts.
if [ "$LOCK" -eq 1 ] && [ -z "${LOGOS_GATE_LOCKED:-}" ] && [ -x "$HOME/logos-gate" ]; then
    export LOGOS_KH_RELOCK=1
    exec "$HOME/logos-gate" --wait 7200 "$0" --no-lock \
        ${ONLY:+--only "$ONLY"} $([ "$MODE" = abort ] && echo --abort-first)
fi

# ── preconditions: build what is cheap, FAIL LOUDLY on what is not ───────────
# None of these is a skip. A missing prerequisite means no verdict is
# obtainable, and that is reported as a refusal with a nonzero status.
say() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }

if [ ! -x tiny_host ] || [ tiny_host.c -nt tiny_host ]; then
    say "Prebuilt language half: compiling tiny_host (seconds)"
    gcc -O2 -Wall -Wextra -o tiny_host tiny_host.c \
      || die "gcc could not build tiny_host — the kernel half cannot compile any LA image without it"
fi
[ -x native_codegen3_selfhost.bin ] \
  || die "native_codegen3_selfhost.bin missing or not executable. It is COMMITTED to git, so this normally means a deleted or unstaged file: restore it with \`git checkout -- native_codegen3_selfhost.bin\`, or regenerate it per STAGE4_STATUS.md (the ~11h tiny_host seed). Without it every kernel builder falls back to the slow tiny_host path and gates that cost 16s cost 15 minutes"

# QEMU is checked ONCE, as a refusal. Every gate in this region is a QEMU gate
# and each self-skips (exit 0) when it is absent — so without this check the
# runner would print "52 SKIP" and a zero-FAIL tally, which is exactly the shape
# that made 57 existing SKIP paths invisible. No verdict is obtainable, so the
# runner says so and exits nonzero instead of producing a reassuring tally.
command -v qemu-system-x86_64 >/dev/null 2>&1 \
  || die "qemu-system-x86_64 not installed. Every gate in the kernel half is a QEMU gate, so NO verdict is obtainable — this is reported as a refusal, not as 52 skips and a clean tally. Install: sudo apt-get install -y qemu-system-x86"
for t in nasm ld objcopy; do
    command -v "$t" >/dev/null 2>&1 || die "$t not installed — the kernel half cannot assemble or link its images"
done

# ── the wrapper: classify every gate, count every class ──────────────────────
N_PASS=0; N_FAIL=0; N_SKIP=0; N_UNK=0; N_EXCL=0; N_PREREQ_FAIL=0
FAILED=''; SKIPPED=''; UNKNOWN=''; PREREQ_FAILED=''
RUN_LOG=$(mktemp); trap 'rm -f "$RUN_LOG"' EXIT

# The repo's verdict convention is uniform and line-anchored: `echo "PASS  ..."`,
# `SKIP  `, `FAIL  ` at the start of an output line (98 PASS echoes across the
# kernel gates, 0 unanchored, 0 via printf). Classification anchors on that, so
# the words appearing in prose inside a gate's message cannot flip a verdict.
bash() {
    local label="$*" rc out
    # ★ A PREREQUISITE BUILD IS NOT A GATE, and must not be tallied as one.
    # The region contains exactly one non-gate invocation — `bash
    # kernel/build_k2.sh`, which produces the ELF gate_k1 requires. It exits 0
    # printing "OK: ..." and no verdict line, so the gate classifier below would
    # file it UNKNOWN and turn an all-green run RED. It is therefore:
    #   - ALWAYS run, never filtered by --only (gate_k1 needs its ELF, and it
    #     costs 0.2s via the committed selfhost compiler — measured, not assumed)
    #   - never counted in the PASS/FAIL/SKIP gate tally
    #   - fatal to the run's verdict if it FAILS, which is a real failure
    if ! printf '%s' "$label" | grep -qE '(^|/)gate_[a-z0-9_]*\.sh'; then
        printf '\n\033[2m--- prereq: %s\033[0m\n' "$label"
        set +e; command bash "$@"; rc=$?; set -o pipefail
        if [ "$rc" -ne 0 ]; then
            N_PREREQ_FAIL=$((N_PREREQ_FAIL+1))
            PREREQ_FAILED="$PREREQ_FAILED  PREREQ FAIL  $label (rc=$rc)"$'\n'
        fi
        [ "$MODE" = abort ] && return "$rc"
        return 0
    fi
    if [ -n "$ONLY" ] && ! printf '%s' "$label" | grep -qE "$ONLY"; then
        N_EXCL=$((N_EXCL+1)); return 0
    fi
    printf '\n\033[2m--- %s\033[0m\n' "$label"
    # Stream live (these gates run for minutes) AND capture for classification.
    # set +e around the capture: `VAR=$(cmd)` under errexit aborts before the
    # gate's own FAIL line can be read.
    set +e
    command bash "$@" 2>&1 | tee "$RUN_LOG"
    rc=${PIPESTATUS[0]}
    set -o pipefail
    out=$(cat "$RUN_LOG")

    if [ "$rc" -ne 0 ]; then
        N_FAIL=$((N_FAIL+1)); FAILED="$FAILED  FAIL  $label (rc=$rc)"$'\n'
    elif printf '%s\n' "$out" | grep -qE '^PASS'; then
        N_PASS=$((N_PASS+1))
    elif printf '%s\n' "$out" | grep -qE '^SKIP'; then
        N_SKIP=$((N_SKIP+1))
        SKIPPED="$SKIPPED  SKIP  $label — $(printf '%s\n' "$out" | grep -E '^SKIP' | head -1 | cut -c1-110)"$'\n'
    else
        # Exit 0 with no verdict line asserts nothing. Counted FAIL-side: an
        # unreadable result must never be spelled the same way as a pass.
        N_UNK=$((N_UNK+1)); UNKNOWN="$UNKNOWN  UNKNOWN  $label (exit 0, printed no PASS/SKIP/FAIL line)"$'\n'
    fi
    [ "$MODE" = abort ] && return "$rc"
    return 0
}

START=$(date +%s)
say "KERNEL HALF — $SRC lines $((B+1))-$((E-1)), $TOTAL invocations${ONLY:+, filtered by /$ONLY/}"
echo "language half: tiny_host $(stat -c%y tiny_host 2>/dev/null | cut -d. -f1), native_codegen3_selfhost.bin present"

set -e
eval "$PROGRAM" || true
set +e

# ── the tally ────────────────────────────────────────────────────────────────
ELAPSED=$(( $(date +%s) - START ))
RAN=$((N_PASS + N_FAIL + N_SKIP + N_UNK))
printf '\n\033[1m== KERNEL HALF SUMMARY ==\033[0m\n'
[ -n "$PREREQ_FAILED" ] && printf '%s' "$PREREQ_FAILED"
[ -n "$FAILED" ]  && printf '%s' "$FAILED"
[ -n "$UNKNOWN" ] && printf '%s' "$UNKNOWN"
[ -n "$SKIPPED" ] && printf '%s' "$SKIPPED"

# Anti-vacuity floor: a run that executed no gate is a FAIL. Folding over an
# empty collection otherwise yields 0 FAIL and reads as success.
if [ "$RAN" -eq 0 ]; then
    echo "FAIL  kernel half: ZERO gates ran (of $TOTAL invocations, $N_EXCL excluded by --only). An empty run folds to 0 FAIL and would read as a pass; it is a FAIL."
    exit 1
fi

printf '%d PASS / %d FAIL / %d SKIP' "$N_PASS" "$N_FAIL" "$N_SKIP"
[ "$N_UNK" -gt 0 ] && printf ' / %d UNKNOWN' "$N_UNK"
printf '   (%d of %d invocations ran' "$RAN" "$TOTAL"
[ "$N_EXCL" -gt 0 ] && printf ', %d EXCLUDED BY --only — this is NOT a full kernel-half verdict' "$N_EXCL"
printf ')   %dm%02ds\n' $((ELAPSED/60)) $((ELAPSED%60))

if [ "$N_FAIL" -gt 0 ] || [ "$N_UNK" -gt 0 ] || [ "$N_PREREQ_FAIL" -gt 0 ]; then
    echo "RED   kernel half: $((N_FAIL+N_UNK)) gate(s) did not pass$([ "$N_PREREQ_FAIL" -gt 0 ] && echo ", $N_PREREQ_FAIL prerequisite build(s) failed")"
    exit 1
elif [ "$N_SKIP" -gt 0 ]; then
    # Deliberately NOT exit 0. A skipped gate asserted nothing; a run containing
    # one is incomplete, and must not be spelled the same way as a green run.
    echo "INCOMPLETE  kernel half: 0 FAIL, but $N_SKIP gate(s) SKIPPED and therefore asserted NOTHING. Named above. This is exit 2, not 0 — a skip is not a pass."
    exit 2
elif [ "$N_EXCL" -gt 0 ]; then
    echo "GREEN (PARTIAL)  $N_PASS/$N_PASS selected gates passed; $N_EXCL excluded by --only. Re-run without --only for a kernel-half verdict."
    exit 0
else
    echo "GREEN  kernel half: all $N_PASS gates passed, none skipped — a real verdict on the kernel, from a prebuilt language half."
    exit 0
fi
