#!/usr/bin/env bash
# buildla_verdict.sh <gate_buildla-log>  —  parse a gate_buildla run into STEPS / SKIPPED / FAIL /
# VERDICT, from the log gate_buildla actually writes.
#
# ★ WHY THIS EXISTS (POROS, 2026-09-10). A runner reported "REAL-PASS 0 / SKIPPED 0" from a GREEN
#   gate_buildla by grepping the log for per-step "  PASS  " / "(skipped)" lines. But gate_buildla
#   does NOT emit per-step lines on green: buildla.la prints them, gate_buildla CAPTURES them in a
#   variable and prints only an AGGREGATE — "PASS  buildla: … ran N steps with M failures" — on
#   green, or "FAIL  buildla: N step(s) reported FAIL:" plus the failing lines on FAIL. So a per-step
#   grep of a green log counts 0. **A zero that did not look is the instrument lying** (the
#   absence-read-as-status class, turned on a count). This reads the aggregate instead, and reports
#   SKIPPED as UNKNOWN on green — never 0 — because the per-step skip lines are not in the log.
#
#   The gate-side issue (buildla folds each "PASS (skipped)" into its N, so N over-counts coverage in
#   a fresh export) is buildla.la's — Track A's file — and is NOT fixed here. This only stops the
#   RUNNER from inventing a 0 it never measured.
#
# OUTPUT (one line): STEPS=<n|UNKNOWN> SKIPPED=<UNKNOWN|n> FAIL=<n> VERDICT=<GREEN|RED|UNRESOLVED>
# EXIT: 0 GREEN · 1 RED · 2 UNRESOLVED (no aggregate/verdict line — a truncated or empty log;
#       never reported as green, because a run whose verdict line is missing did not finish).
set -uo pipefail

parse_buildla() {   # $1 = log file ; prints the summary line ; returns 0/1/2
    local log="$1" line n m nf
    [ -f "$log" ] || { echo "STEPS=UNKNOWN SKIPPED=UNKNOWN FAIL=UNKNOWN VERDICT=UNRESOLVED (no such log: $log)"; return 2; }
    # strip ANSI so the match is robust
    local plain; plain=$(sed 's/\x1b\[[0-9;]*m//g' "$log")

    # GREEN aggregate: "PASS  buildla: … ran N steps with M failures"
    line=$(grep -E '^PASS  buildla:.*ran [0-9]+ steps with [0-9]+ failures' <<< "$plain" | head -1)
    if [ -n "$line" ]; then
        n=$(sed -E 's/.*ran ([0-9]+) steps with ([0-9]+) failures.*/\1/' <<< "$line")
        m=$(sed -E 's/.*ran ([0-9]+) steps with ([0-9]+) failures.*/\2/' <<< "$line")
        # skips are folded into N and not emitted per-step on green -> UNKNOWN, never 0
        echo "STEPS=$n SKIPPED=UNKNOWN FAIL=$m VERDICT=GREEN (skips folded into STEPS; the gate emits no per-step lines on green)"
        return 0
    fi

    # FAIL aggregate: "FAIL  buildla: N step(s) reported FAIL:"  or  "FAIL  buildla: only N PASS lines…"
    line=$(grep -E '^FAIL  buildla:' <<< "$plain" | head -1)
    if [ -n "$line" ]; then
        nf=$(sed -nE 's/^FAIL  buildla: ([0-9]+) step\(s\) reported FAIL.*/\1/p' <<< "$line")
        [ -n "$nf" ] || nf="$(grep -cE '^        FAIL  ' <<< "$plain")"   # fall back to the listed failing steps
        echo "STEPS=UNKNOWN SKIPPED=UNKNOWN FAIL=${nf:-1+} VERDICT=RED ($line)"
        return 1
    fi

    # SKIP (whole gate skipped, e.g. tiny_host/qemu absent) — a verdict, but not green
    line=$(grep -E '^SKIP  buildla:' <<< "$plain" | head -1)
    if [ -n "$line" ]; then
        echo "STEPS=UNKNOWN SKIPPED=ALL FAIL=0 VERDICT=UNRESOLVED ($line)"
        return 2
    fi

    # No aggregate/verdict line at all -> the log is truncated or the run never finished. NOT green.
    echo "STEPS=UNKNOWN SKIPPED=UNKNOWN FAIL=UNKNOWN VERDICT=UNRESOLVED (no aggregate/verdict line — truncated or unfinished log)"
    return 2
}

selftest() {   # self-contained fixtures: a green must give N + UNKNOWN skips; a truncated green must go UNRESOLVED
    local d; d=$(mktemp -d) || { echo "selftest: no scratch dir"; return 1; }
    local ok=1
    printf '%s\n' 'START x' 'PASS  buildla: the LA build driver ran 110 steps with 0 failures (rc=0) — marker, cross-engine' 'END' > "$d/green.log"
    printf '%s\n' 'START x' 'FAIL  buildla: 1 step(s) reported FAIL:' '        FAIL  familytree — the derived catalogue is grounded' > "$d/fail.log"
    printf '%s\n' 'START x' 'pins: …' 'load … on 24 cores' > "$d/trunc.log"     # a green log cut BEFORE the aggregate
    printf '%s\n' 'SKIP  buildla: tiny_host not built' > "$d/skip.log"

    local out rc
    out=$(parse_buildla "$d/green.log"); rc=$?
    if [ "$rc" -eq 0 ] && [[ "$out" == *"STEPS=110"* && "$out" == *"SKIPPED=UNKNOWN"* && "$out" != *"SKIPPED=0"* ]]; then
        echo "  RED-arm PASS green: STEPS=110, SKIPPED=UNKNOWN (never 0) — $out"
    else echo "  ‼ green arm FAILED (rc=$rc): $out"; ok=0; fi

    out=$(parse_buildla "$d/trunc.log"); rc=$?
    if [ "$rc" -eq 2 ] && [[ "$out" == *"no aggregate/verdict line"* ]]; then
        echo "  RED-arm PASS truncated: UNRESOLVED, 'no aggregate line' — NOT green"
    else echo "  ‼ truncated arm FAILED (rc=$rc, must be 2/UNRESOLVED): $out"; ok=0; fi

    out=$(parse_buildla "$d/fail.log"); rc=$?
    [ "$rc" -eq 1 ] && [[ "$out" == *"VERDICT=RED"* ]] && echo "  arm PASS fail: RED" || { echo "  ‼ fail arm (rc=$rc): $out"; ok=0; }

    out=$(parse_buildla "$d/skip.log"); rc=$?
    [ "$rc" -eq 2 ] && [[ "$out" == *"VERDICT=UNRESOLVED"* ]] && echo "  arm PASS whole-skip: UNRESOLVED" || { echo "  ‼ skip arm (rc=$rc): $out"; ok=0; }

    rm -rf "$d"
    [ "$ok" -eq 1 ] && { echo "buildla_verdict selftest: all arms pass"; return 0; } || { echo "buildla_verdict selftest: FAILED"; return 1; }
}

case "${1:-}" in
    --selftest) selftest; exit $? ;;
    "") echo "usage: $0 <gate_buildla-log> | --selftest" >&2; exit 2 ;;
    *) parse_buildla "$1"; exit $? ;;
esac
