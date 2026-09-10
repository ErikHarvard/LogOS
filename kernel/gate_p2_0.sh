#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════════
#  P2.0 MICRO-GATE — the fault path is REACHABLE from a process address space.
#
#  The prerequisite for P2 (fault attribution, the keystone of Erik's ruling).
#  It asserts ONE thing: a ring-3 fault INSIDE a P1 process is DIAGNOSED. Not
#  attributed to a pid, not contained, not survived — the machine still halts.
#  Loudness only, so P2.0 and P2 stay separately gateable and a handler that
#  cannot deliver an interrupt is never tested for what it reports.
#
#  ASSERTIONS (serial + isa-debug-exit):
#    1. "EXCEPTION 06" appears at all — today it does not; the machine wedges.
#    2. err=0000000000000000 — #UD carries no error code.
#    3. ★ rip=0000000010000000 — the PROCESS's own entry VA (P1_UVA). This is
#       the assertion that makes the gate about a PROCESS fault: a fault taken
#       on the kernel's own CR3 reports a 0xffffffff8....... rip instead, so a
#       build that "passed" by faulting before the CR3 switch fails HERE.
#    4. exit 35 (IDT_FAIL) — K2's loud-halt code, NOT 33 and NOT a timeout.
#
#  ★ THE RED CONTROL, and why it must name its shape:
#    build_p2_0.sh --nofix builds the same faulting image WITHOUT the high-IDT
#    relocation. The measured behaviour is a WEDGE: no serial output at all,
#    rc 124 under timeout. A timeout is a WEAK red — a hang, a lost serial, or
#    too short a timeout all produce it — so this gate does not accept "not
#    green". It names what it saw:
#        wedged (rc 124, no output)  -> the expected red, P2.0 is doing work
#        diagnosed-but-halted (35)   -> the fix leaked into the control
#        unexpected                  -> report and fail
#    Run it with:  ./kernel/gate_p2_0.sh --red
#
#  Skips (rc 0) if QEMU is absent — and a SKIP IS NOT A PASS.
#
#  Shell discipline (LOGOSINIT_SCOPE.md §5.0.3, learned from gate_p1.sh's own
#  defect): NO `set -e` here — it kills the verdict block on the failing path,
#  so the gate could not print its own FAIL. NO EXIT trap. And run_variant sets
#  CLEAN/RC/BUILDFAIL in the CALLER: assigning a status inside a function that
#  is then called in $( ) loses it to the subshell, which is exactly how
#  gate_p1.sh could never have gone green.
# ════════════════════════════════════════════════════════════════════════════
set -uo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-}"
QEMU_TIMEOUT=25

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  P2.0 fault-reachability gate: qemu-system-x86_64 not installed"
    exit 0
fi

run_variant() {   # $1 = "" (with the fix) | "nofix" ; sets CLEAN, RC, BUILDFAIL
    if ! ./kernel/build_p2_0.sh ${1:+--nofix} >/dev/null 2>&1; then
        BUILDFAIL=1; CLEAN=""; RC=-1; return
    fi
    BUILDFAIL=0
    CLEAN=$(timeout "$QEMU_TIMEOUT" qemu-system-x86_64 \
            -kernel kernel/kernel_p2_0.elf -m 512 \
            -serial stdio -display none \
            -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
            -no-reboot -no-shutdown 2>/dev/null)
    RC=$?
    CLEAN=$(printf '%s' "$CLEAN" | tr -d '\0')
}

# ── the red control: name the shape, do not accept "not green" ──────────────
if [ "$MODE" = "--red" ]; then
    run_variant nofix
    [ "$BUILDFAIL" -eq 1 ] && { echo "FAIL  P2.0 red control: build_p2_0.sh --nofix failed to build"; exit 1; }
    NOUT=$(printf '%s' "$CLEAN" | tr -d '[:space:]' | wc -c)
    if printf '%s' "$CLEAN" | grep -qF 'EXCEPTION 06'; then
        echo "FAIL  P2.0 RED CONTROL PASSED — WITHOUT the high-IDT relocation the fault"
        echo "      was still diagnosed (rc=$RC). Then the relocation is not what makes"
        echo "      assertion 1 pass, and this gate is measuring nothing. REWRITE IT —"
        echo "      do not delete the control."
        exit 1
    fi
    if [ "$RC" -eq 124 ] && [ "$NOUT" -eq 0 ]; then
        echo "PASS  P2.0 red control: shape = WEDGED (rc 124, no serial output at all) —"
        echo "      the measured pre-P2.0 behaviour. The CPU cannot read the IDT under a"
        echo "      process CR3, so the fault is undeliverable and it triple-faults. This"
        echo "      is named rather than inferred from 'not green': a bare non-green also"
        echo "      matches a hang, a lost serial, or too short a timeout."
        exit 0
    fi
    if [ "$RC" -eq 35 ]; then
        echo "FAIL  P2.0 red control: shape = DIAGNOSED-BUT-HALTED (rc 35) — the control"
        echo "      built WITHOUT the relocation still reached the handler, so the fix has"
        echo "      leaked into the -dP1-only build (check the %ifdef P2_HIGHIDT guards)."
        exit 1
    fi
    echo "FAIL  P2.0 red control: shape = UNEXPECTED (rc=$RC, $NOUT non-space bytes of"
    echo "      serial). Expected the measured wedge (rc 124, no output). Got: $(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 160)"
    exit 1
fi

# ── the real gate ───────────────────────────────────────────────────────────
run_variant
[ "$BUILDFAIL" -eq 1 ] && { echo "FAIL  P2.0 gate: build_p2_0.sh failed"; exit 1; }
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 200)

ok=1
printf '%s' "$CLEAN" | grep -qF 'EXCEPTION 06' \
    || { echo "FAIL  P2.0: no 'EXCEPTION 06' on serial — a ring-3 fault inside a process address space was NOT diagnosed. That is the pre-P2.0 behaviour: the IDT, the gate offsets or isr_common's strings are still LOW and unreachable under a process CR3 (rc=$RC, got: $seen)"; ok=0; }

printf '%s' "$CLEAN" | grep -qF 'err=0000000000000000' \
    || { echo "FAIL  P2.0: #UD must carry err=0000000000000000 — a different error code means a different vector was taken, not the ud2 (rc=$RC, got: $seen)"; ok=0; }

printf '%s' "$CLEAN" | grep -qF 'rip=0000000010000000' \
    || { echo "FAIL  P2.0: rip is not 0000000010000000 (P1_UVA) — the fault was NOT taken at ring 3 inside the process. A fault on the kernel's own CR3 reports a 0xffffffff8....... rip and would satisfy every other assertion here, so this is the one that makes the gate about a PROCESS fault (rc=$RC, got: $seen)"; ok=0; }

[ "$RC" -eq 35 ] || { echo "FAIL  P2.0: exit code != 35 (got $RC). 35 is K2's IDT_FAIL loud halt; 124 means the machine wedged with the fault still undeliverable; 33 would mean the process never faulted at all"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  P2.0: the fault path is REACHABLE from a process address space — a ring-3 #UD inside a P1 process is DIAGNOSED ('EXCEPTION 06 err=0 rip=0000000010000000', exit 35) where before it produced no output at all and wedged the machine. The rip IS the process's own entry VA, which is what makes this a process fault rather than a kernel one. Loudness only: the machine still halts, nothing is attributed to a pid and nothing is contained — that is P2. Falsifiability is proven separately by './kernel/gate_p2_0.sh --red', which requires the un-relocated build to reproduce the measured WEDGE by name (rc 124, no output) rather than merely fail."
[ "$ok" -eq 1 ]
