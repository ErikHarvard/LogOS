#!/bin/sh
# gate_debug.sh — the tracing debugger (debug_eval.la), track C.
#
# WHAT IS ACTUALLY AT RISK HERE, and therefore what this gate is about:
# DEBUG_EVAL cannot WRAP EVAL — EVAL's recursion is internal (Z(la self. …)),
# so an outer wrapper observes only the outermost node and nothing beneath it.
# The tracer must BE the self EVAL would have used, so it REPRODUCES EVAL's
# dispatch. A reproduced evaluator can DRIFT from the one it claims to trace,
# and drift is invisible: the trace still looks plausible while describing a
# reduction that never happened.
#
# So the central assertion is NOT "the trace looks right". It is that
# DEBUG_EVAL and EVAL AGREE on the result of every program. Tracing must not
# change the answer. Everything else here is secondary.
#
# SLICE 2 (breakpoints + environment inspection) extends that same assertion
# rather than adding a separate one: every breakpoint program is run through
# the agreement check WITH THE BREAKPOINT ARMED, because a breakpoint reads
# the environment and must not perturb it either. Check 4 then asks the two
# questions agreement cannot: does the breakpoint fire WHERE it should, and
# — the half that is easy to forget — does it fire NOWHERE ELSE. A predicate
# that is accidentally always-true still agrees on every answer.
set -u
cd "$(dirname "$0")" || exit 1
ok=1
EXPECT_AGREE=9
EXPECT_BREAK=5

command -v timeout >/dev/null 2>&1 || { echo "SKIP  debug: timeout(1) absent"; exit 0; }
[ -f debug_eval.la ] || { echo "FAIL  debug: debug_eval.la missing"; exit 1; }

# ── 1. the host engine ─────────────────────────────────────────────────────
H=$(timeout 300 ./tiny_host debug_eval.la 2>&1) || {
    echo "FAIL  debug: tiny_host debug_eval.la did not complete: $(printf '%s' "$H" | tail -1)"; exit 1; }
#   ★ Non-vacuity FIRST. Every count below is taken from $H, so an empty $H
#   would make "0 DIVERGED" true and the whole gate meaningless.
lines=$(printf '%s\n' "$H" | grep -c .)
if [ "$lines" -lt 20 ]; then
    echo "FAIL  debug: host produced only $lines lines — too little to have traced anything; refusing to judge counts taken from it"; exit 1
fi

agree=$(printf '%s\n' "$H" | grep -c '^AGREE')
brk_total=$(printf '%s\n' "$H" | grep -c '!! BREAK')
diverged=$(printf '%s\n' "$H" | grep -c '^DIVERGED')
if [ "$diverged" -ne 0 ]; then
    echo "FAIL  debug 1: $diverged program(s) DIVERGED — tracing changed the answer:"
    printf '%s\n' "$H" | grep '^DIVERGED' | sed 's/^/        /'
    ok=0
elif [ "$agree" -ne "$EXPECT_AGREE" ]; then
    echo "FAIL  debug 1: $agree agreements, expected $EXPECT_AGREE — a program silently stopped being tested"; ok=0
else
    echo "PASS  debug 1: DEBUG_EVAL agrees with EVAL on all $agree programs — tracing does not change the answer"
fi

# ── 2. the trace actually describes the reduction ──────────────────────────
#   Checked on the curried-builtin program, whose shape is forced: concat is
#   looked up (VAR->bi), applied once to become a PARTIAL, then applied again.
#   If the tracer ever silently degraded to "print the top node and delegate",
#   the nested lines would vanish while agreement still passed.
#   ★ EACH HELPER CLEARS ITS CHECK'S OWN FLAG, not just the global `ok`.
#   Without that, a check whose line assertion failed still fell through to
#   its trailing `else` and printed PASS underneath its own FAIL — the exit
#   status was right and the CLAIM was wrong. A gate that reports a green it
#   did not earn is worse than one that fails, because the failure is the
#   part a reader trusts.
line2_ok=1
need_line() {
    printf '%s\n' "$H" | grep -qF "$1" || { echo "FAIL  debug 2: trace is missing the line '$1'"; ok=0; line2_ok=0; }
}
#   Same shape, but reports as check 3, so a failure names the check that
#   actually caught it. Slice 1 learned this the hard way: a red path that
#   fires through the WRONG assertion is not evidence the intended one works.
brk3_ok=1
need_brk() {
    printf '%s\n' "$H" | grep -qF "$1" || { echo "FAIL  debug 3: expected breakpoint line missing: '$1'"; ok=0; brk3_ok=0; }
}
need_line "<- VAR = bi:concat"
need_line "<- APP = pa:concat"
need_line "<- APP = str:abcd"
need_line "<- LAM = clo:x"
depth2=$(printf '%s\n' "$H" | grep -c '^    -> ')
if [ "$depth2" -lt 1 ]; then
    echo "FAIL  debug 2: no depth-2 trace lines — the tracer is not recursing, only reporting the outermost node"; ok=0
elif [ "$line2_ok" -ne 1 ]; then
    :   # a required trace line was already reported missing above; do not claim PASS on top of it
else
    echo "PASS  debug 2: the trace shows real nested reduction ($depth2 lines at depth 2+, curried builtin VAR->bi->pa->str)"
fi

# ── 3. breakpoints: fire where they should, and NOWHERE ELSE ───────────────
#   The env render is the point of the slice, so it is asserted verbatim, not
#   by counting lines: a breakpoint that fired but printed the wrong binding
#   would otherwise pass.
need_brk "!! BREAK VAR env: x=str:VALUE"
#   ★ THE SHADOWING CASE — the question a trace alone cannot answer. Both
#   bindings of x are live; the trace shows only which value came back. Only
#   the environment shows WHY, and the ORDER is the answer: APP conses the
#   new frame on the front and LIST_FIND takes the first match, so "inner"
#   must precede "outer". An env rendered tail-first would still contain both
#   names and still agree on every result, and would be wrong.
need_brk "!! BREAK VAR env: x=str:inner, x=str:outer"

#   The negative half. A predicate that never says no is indistinguishable
#   from a working one by every check above — it fires on the lines we asked
#   for, and agreement still holds because breaking does not change answers.
neg_sec=$(printf '%s\n' "$H" | awk '/^--- break: VAR nosuchvar/{f=1;next} /^--- break: /{f=0} f')
neg_lines=$(printf '%s\n' "$neg_sec" | grep -c .)
neg_brk=$(printf '%s\n' "$neg_sec" | grep -c '!! BREAK')
if [ "$neg_lines" -lt 5 ]; then
    #   Non-vacuity, same discipline as check 1: "0 breakpoints" is trivially
    #   true of an empty section, so the section must be shown to exist first.
    echo "FAIL  debug 3: the must-not-fire section has only $neg_lines lines — it did not run, so '0 breakpoints' proves nothing"; ok=0
elif [ "$neg_brk" -ne 0 ]; then
    echo "FAIL  debug 3: BRK_VAR(\"nosuchvar\") fired $neg_brk time(s) — the predicate matches nodes it should not"; ok=0
elif [ "$brk3_ok" -ne 1 ]; then
    :   # a required breakpoint line was already reported missing above
elif [ "$brk_total" -ne "$EXPECT_BREAK" ]; then
    echo "FAIL  debug 3: $brk_total breakpoint lines, expected $EXPECT_BREAK — a breakpoint case silently stopped firing"; ok=0
else
    echo "PASS  debug 3: breakpoints fire exactly where armed ($brk_total lines: bound value, shadowed pair innermost-first, 3 at depth 1) and not at all on a name that does not occur, while all $EXPECT_AGREE programs still AGREE"
fi

# ── 4. host == VM ──────────────────────────────────────────────────────────
#   codegen.la resolves debug_eval.la's `import("eval.la")` at COMPILE time and
#   lowers the merged table; the VM has no notion of import. Costly (~11 min:
#   secd.la build + codegen over eval.la + debug_eval.la), so it is skippable
#   for a quick loop — but skipping is ANNOUNCED, never silent.
if [ "${SKIP_VM:-0}" = 1 ]; then
    echo "SKIP  debug 4: host==VM skipped by SKIP_VM=1 (the expensive half — do not read a green here as engine agreement)"
else
    rm -f logos_secd logos_program.bin logos_source.la
    timeout 900 ./tiny_host secd.la >/dev/null 2>&1
    if [ ! -x logos_secd ]; then
        echo "SKIP  debug 4: could not build logos_secd from secd.la — no VM to compare against"
    else
        cp debug_eval.la logos_source.la
        timeout 1800 ./tiny_host codegen.la >/dev/null 2>&1
        if [ ! -s logos_program.bin ]; then
            echo "FAIL  debug 4: codegen produced no program from debug_eval.la"; ok=0
        else
            V=$(timeout 600 ./logos_secd 2>&1)
            if [ "$V" = "$H" ]; then
                echo "PASS  debug 4: host == VM — byte-identical output from tiny_host and the native SECD VM"
            else
                echo "FAIL  debug 4: host and VM disagree"
                echo "        host $(printf '%s\n' "$H" | grep -c .) lines, VM $(printf '%s\n' "$V" | grep -c .) lines"
                #   ★ NOT `diff <(…) <(…)`: process substitution is a BASHISM and
                #   this gate is #!/bin/sh (dash), where it is a syntax error that
                #   kills the script mid-run — after two checks had already printed
                #   PASS. Caught by `sh -n` plus an actual run; a gate whose failure
                #   BRANCH does not parse looks perfect until the day it must fire.
                printf '%s\n' "$H" > .dbg_host.txt
                printf '%s\n' "$V" > .dbg_vm.txt
                diff .dbg_host.txt .dbg_vm.txt 2>/dev/null | head -6 | sed 's/^/        /'
                rm -f .dbg_host.txt .dbg_vm.txt
                ok=0
            fi
        fi
    fi
    rm -f logos_secd logos_program.bin logos_source.la
fi

[ "$ok" = 1 ] && echo "debug gate GREEN" || { echo "debug gate RED"; exit 1; }
