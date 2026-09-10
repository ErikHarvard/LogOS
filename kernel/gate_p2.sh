#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════════
#  P2 GATE — FAULT ATTRIBUTION AND CONTAINMENT ★ the LogosInit keystone.
#
#  K2's handlers diagnose a vector and HALT the machine. P2 makes a ring-3 fault
#  name its OWNER, record vector + error code + CR2 in that process's PCB, mark
#  it dead-by-fault, tear its mapping down, and return to P1's scheduler. The
#  machine survives; the process does not, and it must NOT RESUME.
#
#  SCOPE (Erik's ruling, 2026-09-08): restart-under-a-new-pid and restart-storm
#  backoff belong to P6, NOT here. Restart after a fault means rebuilding the
#  PML4 from a pristine image, which is P3 — a P2 gate asserting it could not go
#  green until P3 existed, stalling the brick everything depends on.
#
#  GREEN — seven assertions:
#    1. "P1 pid=1 val=A1"        process 1 completes normally; the table still works
#    2. "FAULT pid=02 vec=06 ..."  ★ ATTRIBUTION — the new fact over K2's bare
#                                  "EXCEPTION 06", which names a vector and no owner
#    3. "P1 pid=3 val=C3" AND IT APPEARS AFTER THE FAULT LINE — ★ CONTAINMENT.
#       The ordering is the assertion: the scheduler was re-entered FROM the fault
#       handler. Presence alone would not prove that.
#    4. "P1 pcb pid=02 state=04 fault=06"  the death is RECORDED, not just
#       announced. A handler could print a perfect diagnosis and store nothing,
#       and every transcript assertion above would still pass. P4 reads this.
#    5. "P1 table drained"       the kernel outlived the fault
#    6. exit 33                  NOT 35 (K2's halt) and NOT a timeout
#    7. "RESUMED" never appears  ★ see R3
#
#  REDS — five, each catching a different lie. Run: gate_p2.sh --red|--r2|--r3|--r4|--r5
#    --red  R1' BASELINE, and it MOVED because P2.0 landed. Before P2.0 the
#           baseline was a silent wedge; now the no-P2 build is DIAGNOSED-BUT-
#           HALTED (EXCEPTION 06, exit 35, siblings never run). The gate NAMES
#           the shape rather than accepting "not green" — a bare non-green also
#           matches a hang, a lost serial, or too short a timeout.
#    --r2   ATTRIBUTION. Process 3 faults instead of 2; the reported pid MUST
#           follow. Catches a handler that hardcodes a pid or misreads "current".
#    --r3   ★ CONTAINMENT vs MASKING. The wrong implementation compiled in
#           (--mask): step past the fault and RESUME. It satisfies assertions
#           1-6 and is wrong. REQUIRES the RESUMED marker to appear; if it does
#           not, assertion 7 is unfalsifiable.
#    --r4   ISOLATION HAS POWER. All three PCBs on ONE PML4 (P1's already-
#           witnessed --shared): the per-process values MUST collapse.
#    --r5   VECTOR FIDELITY. The #PF shape: vec MUST change 06 -> 0e, err MUST be
#           non-zero, and CR2 MUST equal the address written. Catches a handler
#           reporting a constant vector, or ignoring CR2.
#
#  Shell discipline (LOGOSINIT_SCOPE.md §5.0.3): no `set -e` (it kills the verdict
#  block on the failing path), no EXIT trap, and run_variant sets CLEAN/RC in the
#  CALLER — a status assigned inside a function called in $( ) dies in the subshell.
# ════════════════════════════════════════════════════════════════════════════
set -uo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-}"
if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  P2 fault-attribution gate: qemu-system-x86_64 not installed"; exit 0
fi

run_variant() {   # $@ = build_p2.sh flags ; sets CLEAN, RC, BUILDFAIL, ELFSUM
    if ! ./kernel/build_p2.sh "$@" >/dev/null 2>&1; then
        BUILDFAIL=1; CLEAN=""; RC=-1; ELFSUM="none"; return
    fi
    BUILDFAIL=0
    ELFSUM=$(md5sum kernel/kernel_p2.elf | cut -c1-12)
    CLEAN=$(timeout 25 qemu-system-x86_64 \
            -kernel kernel/kernel_p2.elf -m 512 \
            -serial stdio -display none \
            -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
            -no-reboot -no-shutdown 2>/dev/null)
    RC=$?
    CLEAN=$(printf '%s' "$CLEAN" | tr -d '\0')
}
has() { printf '%s' "$CLEAN" | grep -qF "$1"; }

case "$MODE" in
--red)
    run_variant --nofix
    [ "$BUILDFAIL" -eq 1 ] && { echo "FAIL  P2 R1': --nofix failed to build"; exit 1; }
    if has 'FAULT pid='; then
        echo "FAIL  P2 R1' PASSED — the build WITHOUT P2 still attributed the fault."
        echo "      Then P2 is not what makes assertion 2 pass. REWRITE THE GATE."; exit 1; fi
    if [ "$RC" -eq 35 ] && has 'EXCEPTION 06' && ! has 'P1 pid=3'; then
        echo "PASS  P2 R1' baseline: shape = DIAGNOSED-BUT-HALTED (exit 35, 'EXCEPTION 06',"
        echo "      no 'FAULT pid=', siblings never ran). Named, not inferred from 'not green'."
        echo "      NOTE this shape MOVED when P2.0 landed: before it, the same control was a"
        echo "      silent wedge (rc 124, no output). Two of §5.0.3's three predicted shapes"
        echo "      have now been observed, in the order the spec said they would be."; exit 0; fi
    echo "FAIL  P2 R1': shape = UNEXPECTED (rc=$RC). Expected diagnosed-but-halted."
    echo "      Got: $(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 200)"; exit 1 ;;
--r2)
    run_variant --pid3
    [ "$BUILDFAIL" -eq 1 ] && { echo "FAIL  P2 R2: --pid3 failed to build"; exit 1; }
    if has 'FAULT pid=03' && ! has 'FAULT pid=02'; then
        echo "PASS  P2 R2 attribution: faulting process 3 instead of 2 moved the reported pid"
        echo "      to 03 and 02 does not appear — the pid follows the FAULTING process, so it"
        echo "      comes from the table's 'current' and is not hardcoded. (elf $ELFSUM)"; exit 0; fi
    echo "FAIL  P2 R2: the reported pid did not follow the faulting process (rc=$RC)."
    echo "      Got: $(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 200)"; exit 1 ;;
--r3)
    run_variant; GOODSUM="$ELFSUM"
    run_variant --mask
    [ "$BUILDFAIL" -eq 1 ] && { echo "FAIL  P2 R3: --mask failed to build"; exit 1; }
    if [ "$ELFSUM" = "$GOODSUM" ]; then
        echo "FAIL  P2 R3: --mask produced a BYTE-IDENTICAL ELF ($ELFSUM). The perturbation"
        echo "      was ABSORBED, so this control asked the gate nothing — a green here would"
        echo "      have been a false finding against a working assertion."; exit 1; fi
    if has 'RESUMED'; then
        echo "PASS  P2 R3 containment-vs-MASKING: the wrong implementation (map past the fault"
        echo "      and resume) DOES emit the RESUMED marker, so assertion 7 is falsifiable and"
        echo "      it is the death of the process — not merely its diagnosis — that makes the"
        echo "      real build pass. Perturbation confirmed to have changed the artifact:"
        echo "      good elf $GOODSUM -> masked elf $ELFSUM."; exit 0; fi
    echo "FAIL  P2 R3: the masking build did NOT emit the RESUMED marker, so assertion 7"
    echo "      is unfalsifiable — nothing would ever have made it fire (rc=$RC)."; exit 1 ;;
--r4)
    run_variant --shared
    [ "$BUILDFAIL" -eq 1 ] && { echo "FAIL  P2 R4: --shared failed to build"; exit 1; }
    if ! has 'P1 pid=3 val=C3'; then
        echo "PASS  P2 R4 isolation has power: with all three PCBs on ONE PML4, process 3 no"
        echo "      longer reads its own C3 — so the per-process value assertions could have"
        echo "      failed, and isolation is what makes them pass. (elf $ELFSUM)"; exit 0; fi
    echo "FAIL  P2 R4 PASSED — with ONE shared PML4 process 3 STILL read its own value."
    echo "      No arrangement of memory could have failed that assertion. REWRITE."; exit 1 ;;
--r5)
    run_variant --pf
    [ "$BUILDFAIL" -eq 1 ] && { echo "FAIL  P2 R5: --pf failed to build"; exit 1; }
    ok=1
    has 'FAULT pid=02 vec=0e' || { echo "FAIL  P2 R5: vector did not change 06 -> 0e on the #PF shape"; ok=0; }
    has 'cr2=0000000020000000' || { echo "FAIL  P2 R5: CR2 is not the address written (P2_PF_VA=0x20000000) — the handler is not reading CR2, or is reporting a stale one"; ok=0; }
    printf '%s' "$CLEAN" | grep -q 'FAULT .*err=0000000000000000' && { echo "FAIL  P2 R5: #PF must carry a NON-ZERO error code (P=0,W=1,U=1 -> 6)"; ok=0; }
    [ "$ok" -eq 1 ] && { echo "PASS  P2 R5 vector fidelity: the #PF shape reports vec=0e with a non-zero error"
        echo "      code and cr2=0000000020000000, the exact address written — so the handler"
        echo "      reads the real vector/err/CR2 rather than reporting constants. (elf $ELFSUM)"; exit 0; }
    echo "      Got: $(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 240)"; exit 1 ;;
"") ;;
*)  echo "usage: gate_p2.sh [--red|--r2|--r3|--r4|--r5]" >&2; exit 2 ;;
esac

# ── the real gate ───────────────────────────────────────────────────────────
run_variant
[ "$BUILDFAIL" -eq 1 ] && { echo "FAIL  P2 gate: build_p2.sh failed"; exit 1; }
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 260)
ok=1

has 'P1 pid=1 val=A1' || { echo "FAIL  P2: process 1 did not complete normally — the fault broke the ordinary path (rc=$RC, got: $seen)"; ok=0; }
has 'FAULT pid=02 vec=06' || { echo "FAIL  P2: no 'FAULT pid=02 vec=06' — the fault was not ATTRIBUTED to its process. K2 names a vector and no owner; attribution is the whole of what P2 adds (rc=$RC, got: $seen)"; ok=0; }
has 'P1 pid=3 val=C3' || { echo "FAIL  P2: process 3 never ran — the fault was diagnosed but NOT CONTAINED; the scheduler was not re-entered (rc=$RC, got: $seen)"; ok=0; }

FLINE=$(printf '%s\n' "$CLEAN" | grep -n 'FAULT pid=' | head -1 | cut -d: -f1)
P3LINE=$(printf '%s\n' "$CLEAN" | grep -n 'P1 pid=3' | head -1 | cut -d: -f1)
if [ -n "$FLINE" ] && [ -n "$P3LINE" ]; then
    [ "$P3LINE" -gt "$FLINE" ] || { echo "FAIL  P2: process 3 ran BEFORE the fault (line $P3LINE vs $FLINE). Presence alone is not containment — the sibling must run AFTER, which is what proves the scheduler was re-entered from the handler"; ok=0; }
fi

has 'P1 pcb pid=02 state=04 fault=06' || { echo "FAIL  P2: the PCB does not record dead-by-fault with the vector. Announcing is not recording — a handler can print a perfect diagnosis and store nothing, and every transcript assertion above still passes. P4 (pwait) reads this field (rc=$RC, got: $seen)"; ok=0; }
has 'P1 table drained' || { echo "FAIL  P2: the kernel did not outlive its process table (rc=$RC, got: $seen)"; ok=0; }
printf '%s' "$CLEAN" | grep -qF 'RESUMED' && { echo "FAIL  P2: the faulting process RESUMED. That is MASKING, not containment — the process must die, not be papered over (rc=$RC, got: $seen)"; ok=0; }
[ "$RC" -eq 33 ] || { echo "FAIL  P2: exit code != 33 (got $RC). 35 means the machine halted on the fault instead of surviving it; 124 means it wedged"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  P2: fault attribution and containment — a ring-3 #UD in process 2 is named WITH ITS OWNER ('FAULT pid=02 vec=06 err=... cr2=...'), recorded in its PCB as dead-by-fault with the vector ('pcb pid=02 state=04 fault=06'), its address space torn down, and the scheduler RE-ENTERED so process 3 runs AFTER it and the machine exits 33. K2 diagnosed a vector and stopped the machine; P2 names the owner and the machine survives the process. The faulting process does NOT resume — proven falsifiable by './kernel/gate_p2.sh --r3', which compiles in the map-and-resume implementation and requires the RESUMED marker to appear."
[ "$ok" -eq 1 ]
