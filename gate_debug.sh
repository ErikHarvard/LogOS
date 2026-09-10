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
# the environment and must not perturb it either. Check 3 then asks the two
# questions agreement cannot: does the breakpoint fire WHERE it should, and
# — the half that is easy to forget — does it fire NOWHERE ELSE. A predicate
# that is accidentally always-true still agrees on every answer.
# (That was "Check 4" until slice 3 inserted a check ahead of it. A stale
# cross-reference in a gate's own header is the cheapest kind of drift and
# the easiest to leave: nothing executes it, so nothing catches it.)
#
# SLICE 3 (the call stack) adds the second projection a breakpoint reports:
# env answers "what is bound here" (LEXICAL — the scope a closure was made
# in), bt answers "how did control get here" (DYNAMIC). Neither is derivable
# from the other, so check 4 asserts they DISAGREE on a program built to
# force them apart, and asserts the ABSENCE of the lexical binder from the
# chain as well as the presence of the call chain — the absence is the only
# half a backtrace secretly rendered from the environment would fail.
#
# SLICE 4 (conditional breakpoints) makes those projections DECIDE rather
# than merely display. Until it, the stack was threaded and printed and
# nothing read it, so a fault in it could only produce a wrong-looking line;
# BRK_CALLER conditions the break ON it, so a fault now changes WHICH nodes
# break. Check 5 runs the unconditioned predicate on the same program as a
# CONTROL and requires the conditional to fire strictly less often — a
# BRK_CALLER degraded to BRK_VAR still fires, still prints a plausible bt,
# and still agrees, so the count relation is the only thing separating them.
#
# SLICE 5 (stepping) adds no dispatch either: a step command is a STOP
# CONDITION, which is how a real debugger implements it — gdb's `next` sets a
# condition on the current FRAME and resumes rather than running a second,
# slower interpreter. So step/step-over/step-out are three more predicates
# over the same (d, ast, env, stk) signature, and check 6 asserts they select
# strictly NESTED stop sets. They measure the STACK, not the depth: `d` counts
# every subexpression while only a call pushes a frame, and on SRC_STEP the
# two numbers differ (7 against 8), so a step-over written on `d` is caught.
#
# SLICE 6 is the DRIVER and the first slice to change the evaluator's SHAPE:
# an ordinal counts nodes already visited, so it flows ACROSS siblings where d
# and stk flow downward, and no predicate can express it. The dispatch threads
# state and returns PAIR(value)(state), the old tracer being DEFINED from it by
# taking FST. Note the cost, which check 7 exists to cover: agreement compares
# the VALUE, so it cannot see a mis-threaded ordinal — measured, not assumed,
# by a red run in which check 1 stayed green with DEBUG_EVAL replaced by EVAL
# outright. The ordinal's oracle is the printed trace: the k-th ENTER line IS
# node k.
#
# SLICE 7 is the POST-MORTEM. Every branch that could not proceed called
# `error` and died with one line — not where, not how control got there, not
# what was bound — so the debugger was useless at exactly the moment you would
# reach for one. It now reports and THEN dies: check 8's load-bearing assertion
# is the NON-ZERO EXIT, because a post-mortem that caught the fault would turn
# a loud failure into a silent one. And "exits non-zero" is true of a harness
# that merely failed to parse, so the run must first be shown to have got far
# enough to fault — that guard is red-tested, not assumed.
set -u
cd "$(dirname "$0")" || exit 1
ok=1
EXPECT_AGREE=23
EXPECT_BREAK=11

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
#   A breakpoint now reports TWO projections (slice 3), so they are
#   counted separately and required to pair up — a break that printed one
#   without the other would otherwise satisfy every count below.
#   ★ COUNTED OVER THE NON-STEPPING SECTIONS ONLY, and slice 5 is why. A
#   step predicate also fires BREAK lines — 19 of them — so counting them
#   here silently folded stepping into a check about breakpoints, and every
#   stepping defect then reported as "a breakpoint case silently stopped
#   firing": the RIGHT verdict through the WRONG assertion, which is the
#   failure this gate warns about at slice 1 and which was caught here by a
#   red run, not by reading. The filter clears on any OTHER section header
#   rather than cutting to end-of-output, so a slice appended after stepping
#   is counted again instead of silently dropped.
nostep() { printf '%s\n' "$H" | awk '/^--- step: /{s=1;next} /^--- /{s=0} !s'; }
brk_env=$(nostep | grep -c '!! BREAK .* env:')
brk_bt=$(nostep | grep -c '!! BREAK .* bt:')
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
#   ★ THE TERMINATOR MATCHES ANY SECTION HEADER, not this section's own
#   prefix. Terminating on `/^--- break: /` meant appending a section with a
#   different prefix silently EXTENDED this one — slice 4's `--- cond:`
#   sections did exactly that to check 4 and turned it red. A section
#   extractor anchored to the names that existed when it was written is a
#   gate that breaks the next time anyone appends to the program.
neg_sec=$(printf '%s\n' "$H" | awk '/^--- break: VAR nosuchvar/{f=1;next} /^--- /{f=0} f')
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
elif [ "$brk_env" -ne "$EXPECT_BREAK" ]; then
    echo "FAIL  debug 3: $brk_env breakpoint env lines, expected $EXPECT_BREAK — a breakpoint case silently stopped firing"; ok=0
elif [ "$brk_bt" -ne "$brk_env" ]; then
    echo "FAIL  debug 3: $brk_env env lines but $brk_bt bt lines — a breakpoint reported one projection without the other"; ok=0
else
    echo "PASS  debug 3: breakpoints fire exactly where armed ($brk_env, each reporting both env and bt: bound value, shadowed pair innermost-first, 3 at depth 1) and not at all on a name that does not occur, while all $EXPECT_AGREE programs still AGREE"
fi

# ── 4. the call stack is DYNAMIC, not the environment relabelled ───────────
#   SRC_DYN is built so the two projections MUST disagree: MK captures v
#   and returns a closure; USE applies that closure somewhere MK never
#   mentions. At `v` the environment is MK's (lexical) and the call chain
#   is USE's (dynamic). Asserting only the presence of a plausible bt line
#   would not discriminate — a "backtrace" quietly rendered from the env
#   chain prints something equally plausible — so the ABSENCE is asserted
#   too: MK bound the value that is in scope and must NOT be on the stack,
#   because it already returned.
stk4_ok=1
need_stk() {
    printf '%s\n' "$H" | grep -qF "$1" || { echo "FAIL  debug 4: expected stack line missing: '$1'"; ok=0; stk4_ok=0; }
}
need_stk "!! BREAK VAR env: q=str:arg, v=str:cap"
need_stk "!! BREAK VAR bt: q <- f <- MAIN"

dyn_sec=$(printf '%s\n' "$H" | awk '/^--- stack: lexical/{f=1;next} /^--- /{f=0} f')
dyn_lines=$(printf '%s\n' "$dyn_sec" | grep -c .)
#   ★ THE DISCRIMINATOR IS `v`, not MK. `v` is the name that IS in the
#   environment at the breakpoint, so a bt rendered from the env chain
#   prints it and a bt built from calls cannot. MK is checked too (it
#   defined the closure and had already returned), but `v` is the one an
#   env-derived backtrace actually gets wrong.
dyn_bt=$(printf '%s\n' "$dyn_sec" | grep '!! BREAK .* bt:')
dyn_mk=$(printf '%s\n' "$dyn_bt" | grep -cE '(: |<- )(v|MK)( |$)')
#   The no-invention half, the counterpart of check 3's must-not-fire: a
#   program that calls nothing must show exactly the one frame the runner
#   entered. A " <- " in that bt line means a frame was pushed by
#   something that is not a call.
top_sec=$(printf '%s\n' "$H" | awk '/^--- stack: no calls/{f=1;next} /^--- /{f=0} f')
top_bt=$(printf '%s\n' "$top_sec" | grep '!! BREAK .* bt:')
top_extra=$(printf '%s\n' "$top_bt" | grep -c ' <- ')
if [ "$dyn_lines" -lt 5 ]; then
    echo "FAIL  debug 4: the lexical-vs-dynamic section has only $dyn_lines lines — it did not run, so its absences prove nothing"; ok=0
elif [ "$dyn_mk" -ne 0 ]; then
    echo "FAIL  debug 4: the call stack names a lexical binder ($dyn_bt) — v is in the ENVIRONMENT at this breakpoint and MK had already returned, so a bt naming either is the env chain relabelled, not the call chain"; ok=0
elif [ -z "$top_bt" ]; then
    echo "FAIL  debug 4: no bt line in the no-calls section — cannot judge the frame count"; ok=0
elif [ "$top_extra" -ne 0 ]; then
    echo "FAIL  debug 4: the no-calls program shows more than one frame ($top_bt) — a frame was pushed by something that is not a call"; ok=0
elif [ "$stk4_ok" -ne 1 ]; then
    :   # a required stack line was already reported missing above
else
    echo "PASS  debug 4: env and bt genuinely disagree (v is bound lexically by MK, absent from the dynamic chain q <- f <- MAIN) and a call-free program shows exactly one frame"
fi

# ── 5. CONDITIONAL breakpoints: the stack DECIDES, it does not just display ─
#   Until slice 4 the call stack was display-only — threaded and printed,
#   with nothing deciding on it, so a wrong stack could only ever produce a
#   wrong-looking line. BRK_CALLER conditions the break ON it, which makes a
#   stack fault change WHICH nodes break. SRC_TWO reaches ONE node (`VAR x`
#   in ID's body) by TWO routes, through A and through B.
#
#   ★ THE CONTROL IS LOAD-BEARING AND IS RUN ON THE SAME PROGRAM. A
#   BRK_CALLER that had silently degraded to plain BRK_VAR would still fire,
#   still print a plausible bt, and still AGREE. The only thing that
#   separates them is that the unconditioned predicate must fire STRICTLY
#   MORE OFTEN on this program. Asserting the conditional's count alone
#   would be the inert-control mistake from slice 3 all over again.
csec() { printf '%s\n' "$H" | awk -v s="$1" 'index($0,s){f=1;next} /^--- /{f=0} f'; }
c_ctl=$(csec "BRK_VAR x, the control" | grep -c '!! BREAK .* env:')
c_via=$(csec "BRK_CALLER x via A"     | grep -c '!! BREAK .* env:')
c_nos_l=$(csec "BRK_CALLER x via NOSUCH" | grep -c .)
c_nos=$(csec "BRK_CALLER x via NOSUCH" | grep -c '!! BREAK')
c_whn=$(csec "BRK_WHEN x = from-b"    | grep -c '!! BREAK .* env:')
cond5_ok=1
need_cond() {
    printf '%s\n' "$H" | grep -qF "$1" || { echo "FAIL  debug 5: expected conditional line missing: '$1'"; ok=0; cond5_ok=0; }
}
#   The stack-conditional picks the A route; the env-conditional picks the B
#   route. Asserting BOTH pins them apart: a predicate that had degraded to
#   "fire on the first visit" would select A in both cases.
need_cond "!! BREAK VAR bt: x <- A <- MAIN"
need_cond "!! BREAK VAR env: x=str:from-a"
need_cond "!! BREAK VAR bt: x <- B <- MAIN"
need_cond "!! BREAK VAR env: x=str:from-b"
#   ★ EVALUATED UNCONDITIONALLY, not as an `elif`, and the red path shows
#   that placement is load-bearing rather than merely defensive. Injection A
#   — STK_HAS negated, so an ABSENT frame matches and a PRESENT one does not
#   — drives c_via to 0 rather than over-firing. `c_via >= c_ctl` is
#   therefore FALSE, so inside the chain this would have fallen through to
#   the exact-count branch and reported an off-by-count, never saying that a
#   frame which is not on the stack had matched. Unconditional, it reports
#   the real defect: NOSUCH fired 4 times.
#   (This corrects an earlier claim here that every such defect also makes
#   the present frame over-fire, leaving the branch "reachable in principle,
#   shadowed in practice". Injection A is the counterexample that claim said
#   could not be constructed — it was an argument, not a red run, and the
#   red run disagreed with it.)
if [ "$c_nos_l" -lt 3 ]; then
    echo "FAIL  debug 5: the must-not-fire section has only $c_nos_l lines — it did not run, so '0 breakpoints' proves nothing"; ok=0; cond5_ok=0
elif [ "$c_nos" -ne 0 ]; then
    echo "FAIL  debug 5: BRK_CALLER(\"x\")(\"NOSUCH\") fired $c_nos time(s) — a frame that is never on the stack matched it"; ok=0; cond5_ok=0
fi

if [ "$c_ctl" -ne 2 ]; then
    echo "FAIL  debug 5: the control BRK_VAR(\"x\") fired $c_ctl times, expected 2 — SRC_TWO is supposed to reach the SAME node by two routes, so the premise of the whole check is gone"; ok=0
#   ★ THE RELATIONAL CHECK COMES FIRST BECAUSE IT IS THE LOAD-BEARING ONE.
#   Written after the two exact-count tests it was UNREACHABLE — c_ctl is
#   already pinned to 2 and c_via to 1, so `c_via >= c_ctl` could never be
#   true, and the branch that states the actual claim of this check would
#   have been dead code that reads as rigour. Ordered first, a BRK_CALLER
#   that degrades to BRK_VAR fires it and gets the RIGHT diagnosis
#   ("not filtering") rather than an off-by-count one.
elif [ "$c_via" -ge "$c_ctl" ]; then
    echo "FAIL  debug 5: the stack-conditional fired $c_via times and the unconditioned control $c_ctl — the conditional is not filtering, so it is indistinguishable from BRK_VAR and the stack is not deciding anything"; ok=0
elif [ "$c_via" -ne 1 ]; then
    echo "FAIL  debug 5: BRK_CALLER(\"x\")(\"A\") fired $c_via times, expected 1"; ok=0
elif [ "$c_whn" -ne 1 ]; then
    echo "FAIL  debug 5: BRK_WHEN(\"x\")(\"from-b\") fired $c_whn times, expected 1"; ok=0
elif [ "$cond5_ok" -ne 1 ]; then
    :   # a required conditional line was already reported missing above
else
    echo "PASS  debug 5: conditionals filter — same node reached twice, control fires $c_ctl, stack-conditional $c_via (route A), env-conditional $c_whn (route B), unmatched frame 0, all $EXPECT_AGREE programs still AGREE"
fi

# ── 6. STEPPING: the three commands select strictly NESTED stop sets ───────
#   SRC_STEP puts nodes at THREE frame depths (MAIN's own, F's, and G's
#   nested inside F) because a one-call program makes step-out EMPTY, and an
#   empty set satisfies "strictly fewer" while asserting nothing — the
#   vacuity this gate has had to guard against at every slice.
#
#   ★ THE FRAME DEPTH IS READ OFF THE bt LINE, NOT OFF THE PREDICATE. SHOW_STK
#   renders one frame per name joined by " <- ", so a stop inside a nested call
#   is exactly a bt line carrying two separators. Asserting on the OUTPUT means
#   the predicate and the renderer would both have to be wrong, in agreement,
#   to pass — where asserting on a recomputed depth would just be asking the
#   suspect to confirm its own story.
s_into=$(csec "step: INTO" | grep -c '!! BREAK .* env:')
s_over=$(csec "step: OVER" | grep -c '!! BREAK .* env:')
s_out=$(csec  "step: OUT"  | grep -c '!! BREAK .* env:')
s_out_l=$(csec "step: OUT" | grep -c .)
over_deep=$(csec "step: OVER" | grep '!! BREAK .* bt:' | grep -c ' <- .* <- ')
out_deep=$(csec  "step: OUT"  | grep '!! BREAK .* bt:' | grep -c ' <- ')
#   Containment, as an identity between counts rather than a set diff: OVER
#   must be exactly INTO restricted to frame depth <= 2, and OUT exactly the
#   frame-depth-1 stops. That IS the specification of the three predicates,
#   and it needs only grep — `comm` would want temp files and `diff <(…)` is
#   the process-substitution bashism this #!/bin/sh gate cannot use.
into_le2=$(csec "step: INTO" | grep '!! BREAK .* bt:' | grep -vc ' <- .* <- ')
over_shallow=$(csec "step: OVER" | grep '!! BREAK .* bt:' | grep -vc ' <- ')
#   ★ ORDERED SEMANTIC-FIRST, EXACT-COUNTS-LAST, for the reason slice 4 found
#   the hard way: written after the exact counts, every check below would be
#   unreachable, because 9/7/3 already pins each number. A stepper that had
#   stopped descending entirely (all three selecting the same 3 nodes) passes
#   both absences and is caught ONLY by the strict ordering — so that branch
#   has to be able to run.
if [ "$s_out_l" -lt 3 ] || [ "$s_out" -eq 0 ]; then
    echo "FAIL  debug 6: the step-out section has $s_out_l lines and $s_out stops — an empty set satisfies every 'fewer than' test below, so it proves nothing"; ok=0
elif [ "$over_deep" -ne 0 ]; then
    echo "FAIL  debug 6: step-over stopped $over_deep time(s) inside a nested call (a bt line with two frames above it) — it is descending into calls, which is the one thing step-over means not to do"; ok=0
elif [ "$out_deep" -ne 0 ]; then
    echo "FAIL  debug 6: step-out stopped $out_deep time(s) while still inside the frame it was leaving — it is using <= where it must use <"; ok=0
elif [ "$s_into" -le "$s_over" ] || [ "$s_over" -le "$s_out" ]; then
    echo "FAIL  debug 6: stops are into=$s_into over=$s_over out=$s_out — not strictly nested, so at least two of the three commands are the same command"; ok=0
elif [ "$into_le2" -ne "$s_over" ]; then
    echo "FAIL  debug 6: step-over selected $s_over stops but INTO has $into_le2 at frame depth <= 2 — over is not INTO restricted to this frame"; ok=0
elif [ "$over_shallow" -ne "$s_out" ]; then
    echo "FAIL  debug 6: step-out selected $s_out stops but OVER has $over_shallow at frame depth 1 — out is not OVER restricted to the caller"; ok=0
elif [ "$s_into" -ne 9 ] || [ "$s_over" -ne 7 ] || [ "$s_out" -ne 3 ]; then
    echo "FAIL  debug 6: stops are into=$s_into over=$s_over out=$s_out, expected 9/7/3 — the traced shape of SRC_STEP changed"; ok=0
else
    echo "PASS  debug 6: stepping selects strictly nested stop sets (into $s_into, over $s_over, out $s_out) — step-over never enters a call, step-out never stops inside the frame it leaves, and each is the previous one restricted by FRAME depth (7 here, where node depth would give 8)"
fi

# ── 7. THE DRIVER: resume, and a session where the COMMAND decides ─────────
#   Slice 5 gave stop CONDITIONS; a condition cannot say "resume from where
#   I am". Slice 6 threads an ordinal so it can, and a session is a fold
#   carrying (after, frame-depth). The two middle sessions are the assertion:
#   IDENTICAL first command, ONE differing second command. If the driver
#   ignored the command, or restarted from the beginning each time, both
#   would report the same thing.
ords()   { printf '%s\n' "$1" | sed -n 's/^  stop #\([0-9]*\) .*/\1/p'   | tr '\n' ' ' | sed 's/ $//'; }
kinds()  { printf '%s\n' "$1" | sed -n 's/^  stop #[0-9]* \([A-Z]*\) .*/\1/p' | tr '\n' ' ' | sed 's/ $//'; }
frames() { printf '%s\n' "$1" | sed -n 's/^  stop #[0-9]* [A-Z]* frame\([0-9]*\) .*/\1/p' | tr '\n' ' ' | sed 's/ $//'; }
d_or=$(csec "drive: INTO x4")
d_in=$(csec "drive: run to G, then INTO")
d_ov=$(csec "drive: run to G, then OVER")
d_en=$(csec "drive: run to z")
o_or=$(ords "$d_or"); k_or=$(kinds "$d_or"); f_or=$(frames "$d_or")
o_in=$(ords "$d_in"); f_in=$(frames "$d_in")
o_ov=$(ords "$d_ov"); f_ov=$(frames "$d_ov")
#   ★ THE ORDINAL'S ORACLE IS THE TRACE, NOT THE DRIVER'S OWN ARITHMETIC.
#   Agreement compares the VALUE (FST), so a mis-threaded counter leaves it
#   green — measured, not assumed: a red run showed check 1 stays green even
#   when DEBUG_EVAL is replaced by EVAL outright. ENTER emits one line per
#   node in visit order, so the k-th ENTER line IS node k. Taking the kinds
#   from the traced run and requiring the session's first four stops to match
#   checks the counter against something that did not compute it.
trace_k=$(csec "step: INTO" | sed -n 's/^ *-> \([A-Z]*\)$/\1/p' | head -4 | tr '\n' ' ' | sed 's/ $//')
in2=$(printf '%s\n' "$o_in" | awk '{print $2}')
ov2=$(printf '%s\n' "$o_ov" | awk '{print $2}')
mono=1; prev=-1
for x in $o_in; do [ "$x" -gt "$prev" ] || mono=0; prev=$x; done
if [ -z "$o_or" ] || [ -z "$o_in" ] || [ -z "$o_ov" ]; then
    echo "FAIL  debug 7: a session reported no stops at all (oracle='$o_or' into='$o_in' over='$o_ov') — nothing below can mean anything"; ok=0
#   ★ MONOTONIC FIRST, THEN DIVERGENCE, THEN THE EXHAUSTED PATH — and this
#   order was established by red runs, not by taste. With the exhausted-path
#   check first, BOTH the restart defect and the ignored-command defect
#   reported "the exhausted path is not being exercised": true, but a
#   consequence rather than the cause, and it named neither bug. A restart
#   makes ordinals repeat, so monotonic catches it and says so; an ignored
#   command makes the two sessions agree, so divergence catches that.
elif [ "$mono" -ne 1 ]; then
    echo "FAIL  debug 7: session ordinals '$o_in' are not strictly increasing — the driver is not resuming from the last stop, it is restarting"; ok=0
elif [ "$in2" = "$ov2" ]; then
    echo "FAIL  debug 7: after the SAME first command, step-into and step-over both stopped at #$in2 — the command is not deciding anything, so this is not a driver"; ok=0
elif ! printf '%s\n' "$d_en" | grep -q 'no further stop'; then
    echo "FAIL  debug 7: the run-off-the-end session never reported 'no further stop' — the exhausted path is not being exercised"; ok=0
elif [ "$k_or" != "$trace_k" ]; then
    echo "FAIL  debug 7: session kinds '$k_or' but the traced visit order begins '$trace_k' — the threaded ordinal disagrees with the trace, so the state is mis-threaded"; ok=0
elif [ "$o_or" != "0 1 2 3" ]; then
    echo "FAIL  debug 7: four step-intos from the start gave ordinals '$o_or', expected '0 1 2 3'"; ok=0
#   ★ THE ORACLE SESSION IS WHERE FRAME DEPTH AND NODE DEPTH DIVERGE, so its
#   frames are asserted and the other sessions' are not enough. Reporting `d`
#   in place of STK_LEN was INERT against every other assertion here: at #5/#6/#7
#   the two numbers coincide (2/3/2), so the substitution changed nothing. Across
#   these four stops they do not — frames are 1 1 2 1 where depths are 0 1 2 1.
elif [ "$f_or" != "1 1 2 1" ]; then
    echo "FAIL  debug 7: the oracle session reported frames '$f_or', expected '1 1 2 1' — a stop is reporting NODE depth where it must report FRAME depth, which is the number the next step command is relative to"; ok=0
elif [ "$o_in" != "5 6 7" ] || [ "$f_in" != "2 3 2" ]; then
    echo "FAIL  debug 7: run-to-G/into/out gave ordinals '$o_in' frames '$f_in', expected '5 6 7' / '2 3 2'"; ok=0
elif [ "$o_ov" != "5 7" ] || [ "$f_ov" != "2 2" ]; then
    echo "FAIL  debug 7: run-to-G/over gave ordinals '$o_ov' frames '$f_ov', expected '5 7' / '2 2' — over must SKIP #6 inside G"; ok=0
else
    echo "PASS  debug 7: the driver resumes and the command decides — from the same stop #5, into descends to #6 (frame 3, inside G) and over skips it to #7 (frame 2); ordinals strictly increase, match the traced visit order, and the exhausted run reports no further stop"
fi

# ── 8. THE FAULT REPORT: a post-mortem, and STILL a loud failure ───────────
#   ★ THE HARNESS IS BUILT FROM debug_eval.la ITSELF — everything before its
#   MAIN, plus a MAIN that runs a program which cannot complete. That is the
#   idiom build.sh already uses for its RUN_SM harness, and it is chosen over
#   a second .la file for one reason: there is no copy of the machinery, so
#   the harness cannot drift from the thing it is testing. A faulting program
#   cannot live in debug_eval.la's own MAIN, because halting there would take
#   the other seven checks down with it.
F_LA=./debug_fault_gen.la
FMAIN=$(grep -n '^glyph MAIN = ' debug_eval.la | tail -1 | cut -d: -f1)
head -$((FMAIN-1)) debug_eval.la > "$F_LA"
printf 'glyph MAIN = DEBUG_RUN(PARSE_PROGRAM("glyph H = la w. nosuchname\\nglyph G = la z. H(z)\\nglyph F = la y. G(y)\\nglyph MAIN = F(\\"in\\")"))\n' >> "$F_LA"
FOUT=$(timeout 300 ./tiny_host "$F_LA" 2>&1); FRC=$?
rm -f "$F_LA"
f_trace=$(printf '%s\n' "$FOUT" | grep -c '^ *-> ')
#   ★ NON-VACUITY IS NOT OPTIONAL HERE, IT IS THE WHOLE TRAP. "Exits
#   non-zero" is ALSO true of a harness that failed to parse, or that never
#   ran at all. So the run must be shown to have got somewhere first —
#   otherwise the loud-failure assertion below passes for the wrong reason
#   and reports a working post-mortem where there is none.
if [ "$f_trace" -lt 5 ]; then
    echo "FAIL  debug 8: the fault harness produced only $f_trace trace lines — it did not get far enough to fault, so a non-zero exit proves nothing"; ok=0
#   ★ THE LOUD FAILURE IS THE LOAD-BEARING ASSERTION. A debugger that
#   REPORTED the fault and then exited 0 would be strictly worse than no
#   debugger: it converts a loud failure into a silent one, which is the one
#   discipline this whole project is built on. Reporting must not catch.
elif [ "$FRC" -eq 0 ]; then
    echo "FAIL  debug 8: the fault harness exited 0 — the post-mortem SWALLOWED the error instead of reporting and dying, turning a loud failure into a silent one"; ok=0
elif ! printf '%s\n' "$FOUT" | grep -qF '!! FAULT debug_eval: unbound variable: nosuchname'; then
    echo "FAIL  debug 8: the fault produced no report line — it died with only the message, which is the state slice 7 exists to end"; ok=0
#   The location line is asserted VERBATIM because it pins four separate
#   things at once: slice 6's ordinal, the node kind, the FRAME depth, and
#   slice 3's dynamic chain. It is rendered by STOP_REC, the same renderer
#   the driver uses for a stop, so a fault reads in a breakpoint's
#   coordinates and there is no second formatter to drift from it.
elif ! printf '%s\n' "$FOUT" | grep -qF '!! FAULT at #12 VAR frame4 bt: w <- z <- y <- MAIN'; then
    echo "FAIL  debug 8: the fault location line is wrong or missing — expected '#12 VAR frame4 bt: w <- z <- y <- MAIN', got: $(printf '%s\n' "$FOUT" | grep '!! FAULT at' | head -1)"; ok=0
#   ★ AND THE TWO PROJECTIONS MUST STILL DISAGREE AT THE FAULT. `w` is the
#   only binding in scope, while control arrived through four frames. A
#   report that printed the environment wearing a backtrace label would show
#   the same thing twice — the slice 3 discriminator, applied where it
#   matters most.
elif ! printf '%s\n' "$FOUT" | grep -qF '!! FAULT env: w=str:in'; then
    echo "FAIL  debug 8: the fault report did not show the environment in force ('w=str:in') — a post-mortem without the bindings is half a report"; ok=0
else
    echo "PASS  debug 8: a fault reports before it dies — #12 VAR frame4, dynamic chain w <- z <- y <- MAIN, env w=str:in — and still exits $FRC, so the post-mortem reports without catching"
fi

# ── 9. INSPECTION: the answer must come from the STOPPED scope ─────────────
#   ★ THE DISCRIMINATOR IS TWO ANSWERS TO ONE QUESTION. Evaluating in the
#   top-level environment still yields a plausible value for any expression
#   naming only glyphs, and silently answers the WRONG question wherever a
#   local is involved — while looking exactly like a working inspector. So the
#   SAME expression is asked at two stops of SRC_TWO, where `x` is bound
#   differently on each route, and the two answers must DIFFER. Asserting one
#   value alone would pass against an inspector wired to the wrong scope.
a_lines=$(csec "ask: concat" | grep -c '!! \|stop #')
a1=$(csec "ask: concat" | sed -n 's/.*concat(x)("!") = //p' | sed -n 1p)
a2=$(csec "ask: concat" | sed -n 's/.*concat(x)("!") = //p' | sed -n 2p)
a_glyph=$(csec "ask: an expression naming" | sed -n 's/.*ID("probe") = //p' | sed -n 1p)
m_band=$(csec "merged: builtins" | grep -c '^AGREE str:8$')
m_strat=$(csec "merged: builtins" | grep -c '^AGREE str:b$')
if [ "$a_lines" -lt 2 ]; then
    echo "FAIL  debug 9: the inspection section produced $a_lines stop lines — it did not run, so any agreement below proves nothing"; ok=0
elif [ -z "$a1" ] || [ -z "$a2" ]; then
    echo "FAIL  debug 9: fewer than two inspections were reported (got '$a1' / '$a2') — the two-stop discriminator needs both"; ok=0
elif [ "$a1" = "$a2" ]; then
    echo "FAIL  debug 9: the same expression answered '$a1' at BOTH stops — EITHER the inspection is not using the stopped scope, OR the ask-session is not resuming and both stops are the same stop; a red run showed the second cause reaches this branch, so it names both"; ok=0
elif [ "$a1" != "str:from-a!" ] || [ "$a2" != "str:from-b!" ]; then
    echo "FAIL  debug 9: inspections were '$a1' and '$a2', expected 'str:from-a!' and 'str:from-b!'"; ok=0
#   An expression naming a GLYPH rather than a local proves the table is
#   threaded too — a stopped env alone cannot resolve ID.
#   ★ UPDATED BY SLICE 9, which changed what is testable here. When these two
#   branches were written INSPECT was strict, so both defects they guard were
#   FATAL rather than wrong-answering — the run died and check 1's completion
#   guard caught it, leaving both branches defensive. Slice 9 made inspection
#   TOTAL, and that promoted one of them: a wrong scope now answers
#   "<unavailable>" instead of halting, so the a1=a2 discriminator above is
#   RED-TESTED and fires on it.
#   The branch below is still NOT. Its defect — EVAL given a different glyph
#   table from the one FREE_OK consulted — is an INTERNAL INCONSISTENCY between
#   the availability check and the evaluation, so FREE_OK reports the name
#   resolvable and EVAL then halts on it. Totality cannot cover a disagreement
#   about what totality was computed against. Recorded as defensive rather than
#   counted as covered.
elif [ "$a_glyph" != "str:probe" ]; then
    echo "FAIL  debug 9: ID(\"probe\") inspected to '$a_glyph', expected 'str:probe' — the glyph table is not reaching the inspector"; ok=0
#   The merge brought str_at and the bitwise ops to all five engines. DEBUG_EVAL
#   resolves builtins through eval.la's IS_BI_NAME/APPLY_BI, which it IMPORTS
#   rather than copies, so it should have gained them for free — this is the
#   check that removes the word "should".
elif [ "$m_band" -ne 1 ] || [ "$m_strat" -ne 1 ]; then
    echo "FAIL  debug 9: the merged builtins did not agree under the debugger (band $m_band, str_at $m_strat of 1 each) — DEBUG_EVAL has drifted from the builtin table it imports"; ok=0
else
    echo "PASS  debug 9: inspection answers from the STOPPED scope — one expression, two stops, '$a1' then '$a2'; a glyph-naming expression resolves to $a_glyph; and the merged band/str_at builtins agree under the debugger"
fi

# ── 10. WATCHPOINTS: stopping on VALUE, which position cannot express ──────
#   Every stop condition before this one is POSITIONAL — this name, this frame,
#   this depth. A watchpoint asks about VALUE, and that is not expressible
#   positionally at all. It is the composition of slice 6 (find the next node
#   after here) with slice 8 (evaluate in that node's scope), which is why it
#   could not have been built before either of them.
w_sec=$(csec "watch: x over SRC_TWO")
w_n=$(printf '%s\n' "$w_sec" | grep -c '^  watch #')
w_vals=$(printf '%s\n' "$w_sec" | sed -n 's/.*  |  x = //p' | tr '\n' ' ' | sed 's/ $//')
#   The SECOND stop is the discriminator: its bt is bare MAIN, i.e. a node
#   where `x` is not in scope at all and which is not an `x` node.
w_mid=$(printf '%s\n' "$w_sec" | sed -n '2s/^  watch #[0-9]* [A-Z]* frame\([0-9]*\) bt: \([^|]*\)  |.*/\1 \2/p' | sed 's/ *$//')
w_none=$(csec "watch: an expression never in scope" | grep -c 'no further change')
w_end=$(printf '%s\n' "$H" | grep -c '^--- watch: end ---')
if [ "$w_n" -lt 1 ]; then
    echo "FAIL  debug 10: the watch section reported $w_n stops — it did not run, so nothing below means anything"; ok=0
#   ★ THE LOAD-BEARING ASSERTION, and it is not a count. A watch that had
#   quietly degraded into "stop at every occurrence of x" would still report
#   plausible values at plausible places. What it could NOT do is stop at #9 —
#   frame 1, bt bare MAIN — where `x` is not an operand and is not in scope.
#   That stop exists only because the VALUE changed (it went out of scope), so
#   it is the one observation no positional predicate can produce.
elif [ "$w_mid" != "1 MAIN" ]; then
    echo "FAIL  debug 10: the watch's second stop was at frame/bt '$w_mid', expected '1 MAIN' — it is not stopping where the value CHANGED, only where the name appears, which is a positional breakpoint wearing a watchpoint's name"; ok=0
elif [ "$w_vals" != "str:from-a <unavailable> str:from-b" ]; then
    echo "FAIL  debug 10: watched values were '$w_vals', expected 'str:from-a <unavailable> str:from-b' — bound, out of scope, rebound"; ok=0
elif [ "$w_n" -ne 3 ]; then
    echo "FAIL  debug 10: the watch fired $w_n times, expected 3 transitions"; ok=0
#   ★ TOTALITY, and it is a prerequisite rather than a nicety. A watch must
#   evaluate its expression at EVERY node, and at most nodes the expression is
#   out of scope; a strict inspector HALTS there. HONEST NOTE: this branch is
#   DEFENSIVE. Breaking totality for real (FREE_OK forced true) kills the run
#   outright, so check 1's completion guard catches it and this branch never
#   runs. It is kept because it names the right failure if a future change
#   makes non-totality survivable, not because a red run has reached it.
elif [ "$w_none" -ne 1 ] || [ "$w_end" -ne 1 ]; then
    echo "FAIL  debug 10: watching a never-in-scope name did not complete cleanly (no-change $w_none, end-marker $w_end of 1 each) — a strict inspector would have halted the run here"; ok=0
else
    echo "PASS  debug 10: watchpoints stop on VALUE — $w_n transitions '$w_vals', including one at frame 1 (bt MAIN) where x is not in scope and no positional predicate could stop; and a never-in-scope watch completes instead of halting"
fi

# ── 11. REVERSE STEPPING: history recomputed, not stored ───────────────────
#   A conventional debugger stepping backwards needs record/replay, because
#   re-running a process does not reproduce it. This evaluator is a pure
#   function of its input, so re-execution reproduces the identical trace node
#   for node — history can be RECOMPUTED rather than stored, and "step back"
#   is the same deterministic walk keeping the LAST match before a point
#   instead of the first match after it.
b_f1=$(csec "back: two steps forward" | sed -n 's/^  fwd1 #\([0-9]*\) .*/\1/p')
b_f2=$(csec "back: two steps forward" | sed -n 's/^  fwd2 #\([0-9]*\) .*/\1/p')
b_bk=$(csec "back: two steps forward" | sed -n 's/^  back #\([0-9]*\) .*/\1/p')
b_lt=$(csec "back: two steps forward" | sed -n 's/^  last #\([0-9]*\) .*/\1/p')
if [ -z "$b_f1" ] || [ -z "$b_f2" ] || [ -z "$b_bk" ] || [ -z "$b_lt" ]; then
    echo "FAIL  debug 11: the reverse-step section reported '$b_f1'/'$b_f2'/'$b_bk'/'$b_lt' — a search returned nothing, so nothing below means anything"; ok=0
#   ★ THE DISCRIMINATOR IS `last`, NOT THE ROUND TRIP. A REC_LAST that had
#   quietly kept the FIRST match below the bound still passes the round trip —
#   stepping back from #1 lands on #0 under either rule, because #0 is both
#   the first and the last qualifying node below 1. Only a search from BEYOND
#   the end separates them: keep-last gives the final qualifying node, keep-
#   first gives #0 again. Asserting the round trip alone would accept a
#   backward search that never looked backwards.
elif [ "$b_lt" = "$b_f1" ]; then
    echo "FAIL  debug 11: stepping back from beyond the end gave #$b_lt, the same as the FIRST forward stop — the backward search is keeping the first match, not the last, and the round trip cannot tell the difference"; ok=0
elif [ "$b_bk" != "$b_f1" ]; then
    echo "FAIL  debug 11: forward to #$b_f1 then #$b_f2, but stepping back gave #$b_bk — the round trip does not return to where it started"; ok=0
elif [ "$b_f1" != "0" ] || [ "$b_f2" != "1" ] || [ "$b_lt" != "7" ]; then
    echo "FAIL  debug 11: reverse-step ordinals were fwd1=$b_f1 fwd2=$b_f2 last=$b_lt, expected 0/1/7"; ok=0
else
    echo "PASS  debug 11: reverse stepping recomputes history — forward #$b_f1 then #$b_f2, back returns to #$b_bk, and a step back from beyond the end reaches #$b_lt (the LAST qualifying node, which the round trip alone could not distinguish from the first)"
fi

# ── 12. THE TAPE: an optimisation checked against its definition ───────────
#   Slice 10 made history RECOMPUTED rather than stored, which is what made
#   reverse stepping nearly free — and quadratic: every search re-runs the whole
#   program. The tape walks once and answers afterwards from the record.
#
#   ★ RECOMPUTATION STAYS THE DEFINITION; THE TAPE IS THE OPTIMISATION, and the
#   check compares the two rather than testing the tape alone. An optimisation
#   verified only against itself is not verified. If they ever disagree, the
#   recompute path is the one that is right.
t_f1=$(csec "tape: recompute" | sed -n 's/^  fwd1 \([A-Z]*\)  \(.*\)$/\1 \2/p')
t_f2=$(csec "tape: recompute" | sed -n 's/^  fwd2 \([A-Z]*\)  \(.*\)$/\1 \2/p')
t_bk=$(csec "tape: recompute" | sed -n 's/^  back \([A-Z]*\)  \(.*\)$/\1 \2/p')
t_n=$(csec "tape: recompute" | sed -n 's/^  nodes on tape \([0-9]*\)$/\1/p')
#   ★ "SAME" HAS A VACUITY HOLE AND IS NOT ASSERTED ALONE. SAME_STOP reports
#   SAME when BOTH sides are empty, so two searches that each found nothing
#   agree perfectly. The tape's own stop is therefore asserted by VALUE beside
#   the verdict — and the node count is cross-checked against check 6, which
#   independently establishes that SRC_STEP has 9 nodes by stepping through it.
if [ -z "$t_f1" ] || [ -z "$t_bk" ] || [ -z "$t_n" ]; then
    echo "FAIL  debug 12: the tape section reported '$t_f1' / '$t_bk' / nodes '$t_n' — it did not run"; ok=0
elif [ "$t_n" -ne "$s_into" ]; then
    echo "FAIL  debug 12: the tape holds $t_n nodes but check 6 stepped through $s_into — the tape is not recording every visit, so a search over it can miss stops the run would have found"; ok=0
elif [ "$t_f1" != "SAME #0 APP frame1 bt: MAIN" ]; then
    echo "FAIL  debug 12: tape forward search gave '$t_f1', expected 'SAME #0 APP frame1 bt: MAIN'"; ok=0
elif [ "$t_f2" != "SAME #1 VAR frame1 bt: MAIN" ]; then
    echo "FAIL  debug 12: tape second forward search gave '$t_f2', expected 'SAME #1 VAR frame1 bt: MAIN'"; ok=0
elif [ "$t_bk" != "SAME #7 VAR frame2 bt: y <- MAIN" ]; then
    echo "FAIL  debug 12: tape backward search gave '$t_bk', expected 'SAME #7 VAR frame2 bt: y <- MAIN' — the tape and the recompute path disagree, and the recompute path is the definition"; ok=0
else
    echo "PASS  debug 12: the tape agrees with recomputation on all three searches, by VALUE not just verdict ($t_f1), and holds $t_n nodes — the same count check 6 reached by stepping"
fi

# ── 13. THE TRACE BUDGET: bounded observation, announced truncation ────────
#   Until this slice the trace was all-or-nothing, so the debugger could not be
#   pointed at any program large enough to want one. The budget needs no new
#   state — the ordinal threaded since slice 6 IS a node counter.
b4_enter=$(csec "budget: 4 nodes" | grep -c '^ *-> ')
b4_trunc=$(csec "budget: 4 nodes" | grep -c '^\.\.\. trace truncated after 4 nodes$')
b4_agree=$(csec "budget: 4 nodes" | grep -c '^AGREE ')
bl_trunc=$(csec "budget: 1000 nodes" | grep -c '^\.\.\. trace truncated')
bl_enter=$(csec "budget: 1000 nodes" | grep -c '^ *-> ')
bl_agree=$(csec "budget: 1000 nodes" | grep -c '^AGREE ')
if [ "$b4_enter" -eq 0 ] || [ "$bl_enter" -eq 0 ]; then
    echo "FAIL  debug 13: a budget section emitted no trace at all (4-budget $b4_enter, large-budget $bl_enter) — it did not run"; ok=0
#   ★ ANNOUNCED, NEVER SILENT. A trace that simply stops is indistinguishable
#   from a program that finished: the reader cannot tell "this is all that
#   happened" from "this is all I was willing to show". The marker is the only
#   thing that separates those two readings.
elif [ "$b4_trunc" -ne 1 ]; then
    echo "FAIL  debug 13: the 4-node budget emitted $b4_trunc truncation markers, expected exactly 1 — a trace that stops without saying so reads as a program that finished"; ok=0
#   ★ THE ABSENCE HALF, and it is the one that keeps the marker honest. A
#   marker printed unconditionally satisfies the check above and tells the
#   reader nothing. Red-tested against exactly that.
elif [ "$bl_trunc" -ne 0 ]; then
    echo "FAIL  debug 13: a budget of 1000 over a 9-node program still announced truncation ($bl_trunc times) — the marker fires regardless of the bound, so it carries no information"; ok=0
elif [ "$b4_enter" -ne 4 ]; then
    echo "FAIL  debug 13: the 4-node budget emitted $b4_enter entered-node lines, expected 4 — the bound is not the number of nodes shown"; ok=0
elif [ "$bl_enter" -le "$b4_enter" ]; then
    echo "FAIL  debug 13: the large budget showed $bl_enter nodes and the small one $b4_enter — raising the bound did not show more, so the budget is not what is limiting the trace"; ok=0
#   ★ SLICE 1'S INVARIANT, RE-TESTED UNDER A NEW CONDITION. A truncated trace
#   is still an observation; if stopping the trace early changed the result,
#   the emitter would be doing more than emitting. HONEST NOTE: this branch is
#   REDUNDANT with check 1, which already folds both budget programs into its
#   22-program agreement sweep and reports DIVERGED first. Perturbing the
#   bounded run fires check 1 and the non-vacuity guard above, not this line.
#   Kept because it names the invariant at the point it applies, not because a
#   red run has reached it.
elif [ "$b4_agree" -ne 1 ] || [ "$bl_agree" -ne 1 ]; then
    echo "FAIL  debug 13: bounded tracing changed the answer (AGREE lines: 4-budget $b4_agree, large $bl_agree of 1 each) — observing must not perturb, bounded or not"; ok=0
else
    echo "PASS  debug 13: the trace budget bounds observation without changing it — 4 nodes shown then truncation announced exactly once, $bl_enter shown unbounded with no marker, and both still AGREE"
fi

# ── 14. THE DEBUGGER TRACING AN EVALUATOR ──────────────────────────────────
#   This file's header claims it is "the evaluator watching itself", and
#   CLAUDE.md asks for Meta-Debug(Meta-Debug) = Debug. Until slice 12 that could
#   not be attempted at all: the trace was unbounded.
#
#   ★ WHAT IS GATED IS ONE HONEST LEVEL BELOW THE LITERAL CLAIM, and the reason
#   is measured rather than assumed. Tracing eval.la's own RUN runs past 150
#   SECONDS on the host before host==VM doubles it, because the budget bounds
#   what is EMITTED, not what is EXECUTED — a budget cannot make meta-evaluation
#   cheap. The literal self-application therefore lives in debug_meta.la, run by
#   hand, as this project already treats theourgia_*_live and sigil_live.
#
#   ★ AND THE ASSERTION IS THE INTERPRETING, NOT THE ANSWER. "AGREE str:9" is
#   equally true of tracing any program that computes 9. What makes SRC_MINI an
#   evaluator is visible in the trace: a fixed point being tied (clo:self) and a
#   Scott-encoded term selecting its own handler (clo:l). Asserting only the
#   result would pass against a test that had quietly stopped being meta.
m_agree=$(csec "meta: the debugger tracing" | grep -c '^AGREE str:9$')
m_knot=$(csec "meta: the debugger tracing" | grep -c '<- LAM = clo:self$')
m_disp=$(csec "meta: the debugger tracing" | grep -c '<- APP = clo:l$')
m_trunc=$(csec "meta: the debugger tracing" | grep -c '^\.\.\. trace truncated after 24 nodes$')
if [ "$m_agree" -ne 1 ]; then
    echo "FAIL  debug 14: the traced evaluator did not agree (AGREE str:9 count $m_agree) — tracing changed what the interpreter computed"; ok=0
elif [ "$m_knot" -eq 0 ]; then
    echo "FAIL  debug 14: the trace shows no fixed point being built (no 'clo:self') — the traced program is not constructing a recursive evaluator, so this check is no longer meta"; ok=0
elif [ "$m_disp" -eq 0 ]; then
    echo "FAIL  debug 14: the trace shows no term selecting its handler (no 'clo:l') — the traced program is not DISPATCHING on an encoded term, which is what makes it an interpreter rather than an expression"; ok=0
elif [ "$m_trunc" -ne 1 ]; then
    echo "FAIL  debug 14: the meta trace announced truncation $m_trunc times, expected 1 — an evaluator-sized trace must stay bounded and say so"; ok=0
#   ★ MODULE LIVENESS, because debug_meta.la is run BY HAND and nothing else
#   would notice it rotting. It depends on debug_eval.la's export list, and a
#   name quietly dropped from that list would leave the capstone broken until
#   someone next ran it — which is precisely how 25 committed kernel gates came
#   to be dead on this branch. A trivial importer costs ~1s and closes it.
elif [ ! -f debug_meta.la ]; then
    echo "FAIL  debug 14: debug_meta.la is missing — the literal self-application capstone this check is the affordable half OF"; ok=0
else
    MOD_LA=./debug_modcheck_gen.la
    printf 'import("debug_eval.la")\nglyph MAIN = print(AGREES_BUD(3)("glyph MAIN = concat(\\"o\\")(\\"k\\")"))\n' > "$MOD_LA"
    MOUT=$(timeout 120 ./tiny_host "$MOD_LA" 2>&1); MRC=$?
    rm -f "$MOD_LA"
    if [ "$MRC" -ne 0 ] || ! printf '%s\n' "$MOUT" | grep -q '^AGREE '; then
        echo "FAIL  debug 14: an importer could not use the debugger through its export list (rc $MRC): $(printf '%s' "$MOUT" | tail -1)"; ok=0
    elif ! grep -q '^import("debug_eval.la")$' debug_meta.la; then
        echo "FAIL  debug 14: debug_meta.la no longer imports the debugger — a capstone that copies the machinery tests its own copy"; ok=0
    else
    echo "PASS  debug 14: the debugger traces an evaluator — a fixed point tied ($m_knot clo:self), terms dispatching to their handlers ($m_disp clo:l), bounded to 24 nodes with truncation announced, the interpreter still computes 9, and an importer can reach the API that debug_meta.la's manual capstone depends on"
    fi
fi

# ── 15. DISPATCH COVERAGE: is the agreement suite a COVER or a SAMPLE? ─────
#   ★ THE DEFENCE THIS WHOLE FILE RESTS ON WAS NEVER SHOWN TO BE COMPLETE. The
#   header's argument is that a reproduced evaluator can DRIFT, and the answer
#   is that DEBUG_EVAL and EVAL AGREE on every program tested. But N programs
#   is a SAMPLE of the dispatch, not a COVER of it: a branch no test program
#   reaches could drift arbitrarily and every one of them would still agree.
#   The tape holds every visited node, so the set of AST kinds in it IS the set
#   of dispatch branches that actually ran.
c_step=$(csec "cover: which dispatch" | sed -n 's/^  SRC_STEP  *//p')
c_str=$(csec "cover: which dispatch" | sed -n 's/^  SRC_STR  *//p')
if [ -z "$c_step" ] || [ -z "$c_str" ]; then
    echo "FAIL  debug 15: the coverage section reported '$c_step' / '$c_str' — it did not run"; ok=0
elif [ "$c_step" != "VARy LAMy APPy STRy" ]; then
    echo "FAIL  debug 15: SRC_STEP covers '$c_step', expected all four branches — the suite's representative program no longer exercises the whole dispatch, so agreement over it is a sample of less than it was"; ok=0
#   ★ THE SECOND LINE IS THE DISCRIMINATOR AND IS NOT ILLUSTRATION. A coverage
#   measure that answered "all four" for everything satisfies the assertion
#   above and means nothing. SRC_STR is a lone string literal — one branch,
#   three untouched — so it MUST report three n's. Without this line an
#   always-yes measure passes, which is the inert-control failure this gate has
#   been catching in itself since slice 4.
elif [ "$c_str" != "VARn LAMn APPn STRy" ]; then
    echo "FAIL  debug 15: a single string literal covers '$c_str', expected 'VARn LAMn APPn STRy' — the coverage measure is not discriminating, so its all-four answer above carries no information"; ok=0
else
    echo "PASS  debug 15: the suite's dispatch coverage is measured, not assumed — SRC_STEP reaches all four branches ($c_step) and a lone string literal reaches exactly one ($c_str), so the measure discriminates"
fi

# ── 16. host == VM ─────────────────────────────────────────────────────────
#   codegen.la resolves debug_eval.la's `import("eval.la")` at COMPILE time and
#   lowers the merged table; the VM has no notion of import. Costly (~11 min:
#   secd.la build + codegen over eval.la + debug_eval.la), so it is skippable
#   for a quick loop — but skipping is ANNOUNCED, never silent.
if [ "${SKIP_VM:-0}" = 1 ]; then
    echo "SKIP  debug 16: host==VM skipped by SKIP_VM=1 (the expensive half — do not read a green here as engine agreement)"
else
    rm -f logos_secd logos_program.bin logos_source.la
    timeout 900 ./tiny_host secd.la >/dev/null 2>&1
    if [ ! -x logos_secd ]; then
        echo "SKIP  debug 16: could not build logos_secd from secd.la — no VM to compare against"
    else
        cp debug_eval.la logos_source.la
        timeout 1800 ./tiny_host codegen.la >/dev/null 2>&1
        if [ ! -s logos_program.bin ]; then
            echo "FAIL  debug 16: codegen produced no program from debug_eval.la"; ok=0
        else
            V=$(timeout 600 ./logos_secd 2>&1)
            if [ "$V" = "$H" ]; then
                echo "PASS  debug 16: host == VM — byte-identical output from tiny_host and the native SECD VM"
            else
                echo "FAIL  debug 16: host and VM disagree"
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
