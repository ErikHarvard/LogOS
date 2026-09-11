#!/usr/bin/env bash
# ═════════════════════════════════════════════════════════════════════════════
#  P4 GATE — `pwait`: A PARENT LEARNS HOW ITS CHILD DIED.
#
#  The shapes below were PRE-REGISTERED in LOGOSINIT_SCOPE.md §P4 (commit 3c0f318)
#  before a line of P4 code existed, including the green transcript's ORDER, which
#  was derived from the scheduler's scan order. If a run's order differs, that
#  derivation was wrong, and that is a finding, not a flake.
#
#  ★ THE DISCRIMINATOR IS BLOCKING (R4). The scheduler runs each process from its
#  entry to completion, so a non-blocking pwait (the reapnb shape) is answered "none
#  dead yet" while the child is still waiting to run — the parent exits first and
#  never learns. Only a pwait that BLOCKS, and is WOKEN by the death, can report it.
#
#  GREEN — asserted on content, not on the exit code alone:
#    1. P1 pid=2/3 lines                       the boot-built table is untouched
#    2. "FAULT pid=05 vec=06"                  P2's own line: pid 5 crashed
#    3. "PWAIT pid=1 -> child 5 FAULT 06"      ★ the cause AND which fault
#    4. "PWAIT pid=4 -> child 6 EXIT 09"       a grandchild's death goes to ITS parent
#    5. "PWAIT pid=1 -> child 4 EXIT 07"       a clean exit, with its status
#    6. "PWAIT pid=1 -> ECHILD"                no children left: -1, never a phantom
#    7. no PWAIT line hands anyone a process that is not its child
#    8. each child is reported EXACTLY once
#    9. the order is 2 -> 3 -> 4 -> 5 -> 6 above, and each report follows the death
#   10. the drain dump shows NO "pcb pid=04/05/06": a reported child is FREED
#   11. "P1 table drained", exit 33, no "P4 STUCK", no "PWAIT CAP"
#  Every PWAIT line is printed BY THE WAITING PROCESS from pwait's return registers.
#
#  REDS — six. Run: gate_p4.sh --red|--r2|--r3|--r4|--r5|--r6
#    --red  R1 BASELINE: the probe without the handler. Expected "PWAIT pid=1 -> child
#           0" and exit 33 — green by exit code, wrong by content, as in P3's R1.
#    --r2   CAUSE: every death reported as EXIT. Expected "child 5 EXIT 06".
#    --r3   ★ ATTRIBUTION: the parent field ignored. Expected: pid 4 never receives its
#           child 6, and some waiter is handed a process that is not its child.
#    --r4   ★ BLOCKING HAS POWER: never block. Expected: pid 1 is told "child 0", never
#           hears of 4 or 5 — though pid 5 DID crash (its FAULT line is there).
#    --r5   REPORT ONCE: a reported child is not freed. Expected: "child 5" reported
#           more than once, the probe's cap reached, and "pcb pid=05" still in the dump.
#    --r6   A LOST WAKE-UP IS LOUD: no death wakes a parent. Expected "P4 STUCK pid=01"
#           and exit 39 — never 124 (a hang) and never 33.
#
#  ★ EVERY CONTROL md5s THE ELF AND FAILS IF THE PERTURBATION WAS ABSORBED — an
#  absorbed break and a working assertion look the same from the gate's side.
#
#  Shell discipline: no `set -e` (it would kill the verdict block on the failing path),
#  no EXIT trap, and run_variant sets CLEAN/RC in the CALLER. ★ And has()/cnt() read the
#  transcript through HERE-STRINGS, not `printf | grep -q`: under pipefail an early
#  `grep -q` SIGPIPEs the writer, and the pipeline reports 141 for a SUCCESSFUL match.
# ═════════════════════════════════════════════════════════════════════════════
set -uo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-}"
if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  P4 pwait gate: qemu-system-x86_64 not installed"; exit 2
fi

run_variant() {   # $@ = build_p4.sh flags ; sets CLEAN, RC, BUILDFAIL, ELFSUM
    if ! ./kernel/build_p4.sh "$@" >/dev/null 2>&1; then
        BUILDFAIL=1; CLEAN=""; RC=-1; ELFSUM="none"; return
    fi
    BUILDFAIL=0
    ELFSUM=$(md5sum kernel/kernel_p4.elf | cut -c1-12)
    CLEAN=$(timeout 25 qemu-system-x86_64 \
            -kernel kernel/kernel_p4.elf -m 512 \
            -serial stdio -display none \
            -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
            -no-reboot -no-shutdown 2>/dev/null)
    RC=$?
    CLEAN=$(tr -d '\0' <<< "$CLEAN")
}
has() { grep -qF -- "$1" <<< "$CLEAN"; }
cnt() { grep -cF -- "$1" <<< "$CLEAN"; }
at()  { grep -nF -- "$1" <<< "$CLEAN" | head -1 | cut -d: -f1; }
seen() { tr '\n' ' ' <<< "$CLEAN" | head -c 320; }
absorbed_check() {  # $1 = good sum, $2 = this variant's sum, $3 = label
    if [ "$1" = "$2" ]; then
        echo "FAIL  P4 $3: the perturbation produced a BYTE-IDENTICAL ELF ($2)."
        echo "      It was ABSORBED, so this control asked the gate nothing."
        return 1
    fi
    return 0
}
control() {  # $1 = build flag, $2 = label: build + boot the green build, then the variant
    run_variant; GOODSUM="$ELFSUM"
    [ "$BUILDFAIL" -eq 1 ] && { echo "FAIL  P4 $2: the GREEN build failed, so there is no baseline to compare"; exit 1; }
    run_variant "$1"
    [ "$BUILDFAIL" -eq 1 ] && { echo "FAIL  P4 $2: $1 failed to build. A control that cannot build is a control that is not running"; exit 1; }
    absorbed_check "$GOODSUM" "$ELFSUM" "$2" || exit 1
}

case "$MODE" in
--red)
    control --nofix R1
    if has 'PWAIT pid=1 -> child 5' || has 'PWAIT pid=1 -> child 4'; then
        echo "FAIL  P4 R1 PASSED — the build WITHOUT pwait still reported a death. Then pwait is"
        echo "      not what makes assertions 3 and 5 pass. REWRITE THE GATE."; exit 1; fi
    if has 'PWAIT pid=1 -> child 0' && [ "$RC" -eq 33 ] && has 'P1 table drained'; then
        echo "PASS  P4 R1 baseline: shape = ASKED-BUT-NEVER-ANSWERED. Syscall 61 is unknown, so"
        echo "      syscall_entry hands ring 3 a 0, pid 1 is told 'child 0', and no death is ever"
        echo "      learned. ★ THE EXIT CODE IS 33 — the same as green. Green by status, wrong by"
        echo "      content, which is why every assertion here reads the transcript."; exit 0; fi
    echo "FAIL  P4 R1: shape = UNEXPECTED (rc=$RC). Expected 'child 0', exit 33, table drained."
    echo "      Got: $(seen)"; exit 1 ;;
--r2)
    control --wrongcause R2
    if has 'PWAIT pid=1 -> child 5 EXIT 06' && ! has 'PWAIT pid=1 -> child 5 FAULT 06'; then
        echo "PASS  P4 R2 cause fidelity: with every death reported as EXIT, pid 5's crash reads"
        echo "      'child 5 EXIT 06'. So assertion 3 COULD have failed — a supervision tree fed"
        echo "      this would back off nothing. (good $GOODSUM -> wrongcause $ELFSUM)"; exit 0; fi
    echo "FAIL  P4 R2: reporting every death as EXIT did not change child 5's line (rc=$RC)."
    echo "      Got: $(seen)"; exit 1 ;;
--r3)
    control --noparent R3
    foreign=0
    for l in 'PWAIT pid=4 -> child 2' 'PWAIT pid=4 -> child 3' 'PWAIT pid=1 -> child 2' 'PWAIT pid=1 -> child 3' 'PWAIT pid=1 -> child 6'; do
        has "$l" && foreign=1
    done
    if ! has 'PWAIT pid=4 -> child 6 EXIT 09' && [ "$foreign" -eq 1 ]; then
        echo "PASS  P4 R3 ATTRIBUTION BY PARENT: with the parent field ignored, a waiter is handed"
        echo "      a process that is not its child and pid 4 never receives its own child 6. So"
        echo "      assertions 4 and 7 are falsifiable: pwait is scoped to the caller's children"
        echo "      by the parent field, not by luck of the schedule. (good $GOODSUM -> $ELFSUM)"; exit 0; fi
    echo "FAIL  P4 R3: ignoring the parent field did not misattribute any death (rc=$RC)."
    echo "      Got: $(seen)"; exit 1 ;;
--r4)
    control --noblock R4
    if has 'PWAIT pid=1 -> child 0' && ! has 'PWAIT pid=1 -> child 4' && ! has 'PWAIT pid=1 -> child 5' && has 'FAULT pid=05'; then
        echo "PASS  P4 R4 BLOCKING HAS POWER — the discriminator. A pwait that never blocks tells"
        echo "      pid 1 'child 0' while its children are still waiting to run; pid 1 exits, and"
        echo "      it never hears of 4 or 5 — though pid 5 DID crash ('FAULT pid=05' is there)."
        echo "      Under run-to-completion only a BLOCKING pwait observes a death."
        echo "      (good $GOODSUM -> noblock $ELFSUM)"; exit 0; fi
    echo "FAIL  P4 R4: a non-blocking pwait still learned of a death, or no death happened (rc=$RC)."
    echo "      Got: $(seen)"; exit 1 ;;
--r5)
    control --nofree R5
    n5=$(cnt 'PWAIT pid=1 -> child 5 ')
    ok=1
    [ "$n5" -gt 1 ]           || { echo "FAIL  P4 R5: child 5 was reported $n5 time(s) with freeing disabled — the report-once assertion measures nothing"; ok=0; }
    has 'PWAIT CAP'           || { echo "FAIL  P4 R5: the probe's cap was never reached"; ok=0; }
    has 'P1 pcb pid=05'       || { echo "FAIL  P4 R5: pid 5's slot is not in the drain dump, though nothing freed it"; ok=0; }
    [ "$ok" -eq 1 ] && { echo "PASS  P4 R5 report once: with freeing disabled, child 5 is reported $n5 times, the"
        echo "      probe's cap is reached, and 'pcb pid=05' stays in the table. So assertions 8 and"
        echo "      10 are falsifiable. (good $GOODSUM -> nofree $ELFSUM)"; exit 0; }
    echo "      Got: $(seen)"; exit 1 ;;
--r6)
    control --nowake R6
    if has 'P4 STUCK pid=01' && [ "$RC" -ne 33 ] && [ "$RC" -ne 124 ]; then
        echo "PASS  P4 R6 a lost wake-up is LOUD: with no death waking its parent, the kernel says"
        echo "      'P4 STUCK pid=01' and exits $RC — not 124 (a hang) and not 33 (a lie)."
        echo "      (good $GOODSUM -> nowake $ELFSUM)"; exit 0; fi
    echo "FAIL  P4 R6: a lost wake-up did not produce 'P4 STUCK' with a non-33, non-124 exit (rc=$RC)."
    echo "      Got: $(seen)"; exit 1 ;;
"") ;;
*)  echo "usage: gate_p4.sh [--red|--r2|--r3|--r4|--r5|--r6]" >&2; exit 2 ;;
esac

# ── the real gate ─────────────────────────────────────────────────────────────
run_variant
[ "$BUILDFAIL" -eq 1 ] && { echo "FAIL  P4 gate: build_p4.sh failed"; exit 1; }
ok=1
has 'P1 pid=2 val=B2' || { echo "FAIL  P4: process 2 did not run — the boot-built table must be untouched (rc=$RC, got: $(seen))"; ok=0; }
has 'P1 pid=3 val=C3' || { echo "FAIL  P4: process 3 did not run (rc=$RC, got: $(seen))"; ok=0; }
has 'FAULT pid=05 vec=06' || { echo "FAIL  P4: pid 5 did not crash as designed — P2's FAULT line is missing (rc=$RC, got: $(seen))"; ok=0; }
has 'PWAIT pid=1 -> child 5 FAULT 06' || { echo "FAIL  P4: ★ the parent did not learn its child CRASHED, and with which vector (rc=$RC, got: $(seen))"; ok=0; }
has 'PWAIT pid=4 -> child 6 EXIT 09' || { echo "FAIL  P4: the grandchild's death did not reach ITS parent, pid 4 (rc=$RC, got: $(seen))"; ok=0; }
has 'PWAIT pid=1 -> child 4 EXIT 07' || { echo "FAIL  P4: the parent did not learn its child EXITED cleanly, with status 7 (rc=$RC, got: $(seen))"; ok=0; }
has 'PWAIT pid=1 -> ECHILD' || { echo "FAIL  P4: with every child accounted for, pwait must answer ECHILD — never a phantom (rc=$RC, got: $(seen))"; ok=0; }
for l in 'PWAIT pid=1 -> child 6' 'PWAIT pid=1 -> child 2' 'PWAIT pid=1 -> child 3' 'PWAIT pid=4 -> child 2' 'PWAIT pid=4 -> child 3' 'PWAIT pid=4 -> child 5'; do
    has "$l" && { echo "FAIL  P4: '$l' — a waiter was handed a process that is NOT its child"; ok=0; }
done
for c in 4 5 6; do
    n=$(cnt "-> child $c ")
    [ "$n" -eq 1 ] || { echo "FAIL  P4: child $c was reported $n times — a death is reported exactly once"; ok=0; }
done
L_F5=$(at 'FAULT pid=05'); L_W15=$(at 'PWAIT pid=1 -> child 5'); L_W46=$(at 'PWAIT pid=4 -> child 6')
L_W14=$(at 'PWAIT pid=1 -> child 4'); L_E=$(at 'PWAIT pid=1 -> ECHILD'); L_P6=$(at 'P1 pid=6 val=F6'); L_P4=$(at 'P1 pid=4 val=D4')
if [ -n "$L_F5" ] && [ -n "$L_W15" ] && [ -n "$L_W46" ] && [ -n "$L_W14" ] && [ -n "$L_E" ]; then
    { [ "$L_F5" -lt "$L_W15" ] && [ "$L_W15" -lt "$L_W46" ] && [ "$L_W46" -lt "$L_W14" ] && [ "$L_W14" -lt "$L_E" ]; } \
        || { echo "FAIL  P4: ★ the order is not the pre-registered one (FAULT 5 @$L_F5 < 1<-5 @$L_W15 < 4<-6 @$L_W46 < 1<-4 @$L_W14 < ECHILD @$L_E). The scan-order derivation in §P4 or the code is wrong"; ok=0; }
fi
if [ -n "$L_P6" ] && [ -n "$L_W46" ]; then [ "$L_P6" -lt "$L_W46" ] || { echo "FAIL  P4: pid 4 reported child 6 before child 6 had run"; ok=0; }; fi
if [ -n "$L_P4" ] && [ -n "$L_W14" ]; then [ "$L_P4" -lt "$L_W14" ] || { echo "FAIL  P4: pid 1 reported child 4 before child 4 had run"; ok=0; }; fi
for c in 04 05 06; do
    has "P1 pcb pid=$c" && { echo "FAIL  P4: 'pcb pid=$c' is still in the drain dump — a REPORTED child must be freed"; ok=0; }
done
has 'P1 pcb pid=01 state=03' || { echo "FAIL  P4: pid 1 is not recorded as a clean exit in the drain dump (rc=$RC, got: $(seen))"; ok=0; }
has 'P4 STUCK' && { echo "FAIL  P4: a process was left WAITING — a lost wake-up"; ok=0; }
has 'PWAIT CAP' && { echo "FAIL  P4: pid 1's pwait loop hit its cap — ECHILD never came"; ok=0; }
has 'P1 table drained' || { echo "FAIL  P4: the kernel did not drain its table (rc=$RC, got: $(seen))"; ok=0; }
[ "$RC" -eq 33 ] || { echo "FAIL  P4: exit code != 33 (got $RC). 124 means it wedged; 35 a kernel fault; 39 P4 STUCK"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  P4: pwait — a parent learns HOW its child died. pid 1 blocked in pwait, was WOKEN by its children's deaths and resumed from its saved context: 'child 5 FAULT 06' (a crash, and which one), then 'child 4 EXIT 07' (a clean exit, with its status), then ECHILD. The grandchild's death went to ITS parent ('pid=4 -> child 6 EXIT 09'), never to pid 1; each death was reported exactly once, and each reported slot was freed. The order was the one derived in advance from the scheduler's scan. Falsifiable: '--r4' never blocks and pid 1 never hears of a death; '--r3' ignores the parent and deaths go to the wrong waiter; '--r2' reads a crash as an exit; '--r6' loses a wake-up and the kernel says STUCK."
[ "$ok" -eq 1 ]
