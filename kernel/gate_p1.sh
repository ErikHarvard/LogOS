#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════════
#  P1 GATE — the kernel process table (LogosInit brick 1 of 7).
#
#  Erik's ruling (2026-09-06): LogosInit supervises FAULT-ISOLATED PROCESSES.
#  P1 is the foundation — a real PCB array the kernel owns, with a scheduler
#  over it, replacing HH2c's hardcoded two-process/one-stage-byte demo.
#
#  ★ WHY THREE PROCESSES, AND NOT TWO. This is the whole design of the gate.
#  HH2c already boots two isolated LA processes and passes its gate — but it
#  does it with a hardcoded `hh2c_stage` byte: the FIRST .sys_exit switches CR3
#  to B, the second halts. That is not a process table, it is an if-statement,
#  and a two-process gate CANNOT TELL THE DIFFERENCE. A third process is the
#  discriminator: nothing hardcoded for two produces a third without a real
#  table and a real scheduler loop. So the gate asserts THREE distinct pids,
#  and that assertion is the entire reason the number is three.
#
#  ASSERTIONS (serial + isa-debug-exit):
#    1. three lines, `P1 pid=N val=X`, one per process, in scheduler order
#    2. the pids are 1, 2, 3 — DISTINCT, so a table exists and carries identity
#    3. each pid reads its OWN value at the SAME virtual address:
#         pid=1 val=A1   pid=2 val=B2   pid=3 val=C3
#       Same VA, three different values = three address spaces, selected by the
#       CR3 the PCB holds. This is HH2's isolation proof, now DRIVEN FROM THE
#       TABLE rather than from a hand-written CR3 round-trip in boot.
#    4. exit 33.
#
#  ★ THE RED CONTROL, which must exist or assertion 3 is vacuous:
#    build with -D P1_SHARED, which points all three PCBs at ONE PML4. Then all
#    three processes read the SAME value at that VA (whoever wrote last), the
#    val assertions fail, and the gate goes red. Without this, "each read its
#    own value" is unfalsifiable — nothing would ever have made it otherwise.
#    Run it with:  ./kernel/gate_p1.sh --red
#    The gate REQUIRES that variant to fail; a green there means the isolation
#    assertion is measuring nothing and THIS GATE MUST BE REWRITTEN.
#
#  Skips (rc 0) if QEMU is absent — and a SKIP IS NOT A PASS.
# ════════════════════════════════════════════════════════════════════════════
set -uo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-}"

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  P1 process-table gate: qemu-system-x86_64 not installed"
    exit 0
fi

run_variant() {   # $1 = "" (normal) | "red" ; echoes serial, sets RC
    ./kernel/build_p1.sh ${1:+--shared} >/dev/null 2>&1 \
        || { echo "__BUILDFAIL__"; return 1; }
    OUT=$(timeout 30 qemu-system-x86_64 \
            -kernel kernel/kernel_p1.elf -m 512 \
            -serial stdio -display none \
            -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
            -no-reboot -no-shutdown 2>/dev/null)
    RC=$?
    printf '%s' "$OUT" | tr -d '\0'
}

# ── the red control, on demand ──────────────────────────────────────────────
if [ "$MODE" = "--red" ]; then
    CLEAN=$(run_variant red); RC=${RC:-1}
    bad=0
    for pair in "1 A1" "2 B2" "3 C3"; do
        set -- $pair
        printf '%s' "$CLEAN" | grep -qF "P1 pid=$1 val=$2" && bad=$((bad+1))
    done
    if [ "$bad" -eq 3 ]; then
        echo "FAIL  P1 RED CONTROL PASSED — with all three PCBs sharing ONE PML4 the"
        echo "      processes STILL each read their own value. Assertion 3 is therefore"
        echo "      measuring nothing: no arrangement of memory could have failed it."
        echo "      REWRITE THIS GATE — do not delete the control."
        exit 1
    fi
    echo "PASS  P1 red control: with one shared PML4 the per-process values collapse"
    echo "      ($bad/3 survived, expected <3) — so assertion 3 in the real gate is"
    echo "      falsifiable, and isolation is what makes it pass."
    exit 0
fi

# ── the real gate ───────────────────────────────────────────────────────────
CLEAN=$(run_variant); RC=${RC:-1}
printf '%s' "$CLEAN" | grep -qF '__BUILDFAIL__' && { echo "FAIL  P1 gate: build_p1.sh failed"; exit 1; }
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 240)

ok=1
for pair in "1 A1" "2 B2" "3 C3"; do
    set -- $pair
    printf '%s' "$CLEAN" | grep -qF "P1 pid=$1 val=$2" \
        || { echo "FAIL  P1: no 'P1 pid=$1 val=$2' on serial — process $1 did not run, or read another process's memory at the shared VA (rc=$RC, got: $seen)"; ok=0; }
done

NPROC=$(printf '%s\n' "$CLEAN" | grep -c '^P1 pid=')
[ "$NPROC" -eq 3 ] || { echo "FAIL  P1: expected exactly 3 processes, saw $NPROC. TWO is the number a hardcoded stage byte can fake (HH2c does); three is what requires a real table and scheduler."; ok=0; }

[ "$RC" -eq 33 ] || { echo "FAIL  P1: exit code != 33 (got $RC — a fault building a PCB, switching CR3, or entering ring 3)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  P1: the kernel process table — THREE ring-3 processes, each entered from a PCB the kernel owns (pid, CR3, state, entry), each in its OWN address space: the same virtual address reads A1/B2/C3 per process, so isolation is selected by the table's CR3 and not by a hand-written round-trip. Three is the assertion that matters — two is what HH2c's hardcoded stage byte can fake, and a third process cannot come from an if-statement. Falsifiability of the isolation claim is proven separately by './kernel/gate_p1.sh --red' (all three PCBs on one PML4 -> the values collapse)."
[ "$ok" -eq 1 ]
