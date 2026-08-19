#!/bin/sh
# gate_hal3bc.sh — HAL.3bc: the ATA WRITE path's waits are BOUNDED, so a channel
# that never becomes ready is diagnosed BY STAGE instead of killing the kernel.
#
# The write twin of gate_hal3c.sh. ata3b.la had THREE unbounded waits where the
# read path had one — DRQ before pushing the sector, BSY after the cache flush,
# DRQ again on the read-back — so a wedged channel had three ways to die with
# nothing on serial naming the disk. The flush wait is the worst of them: it
# sits AFTER 512 bytes have already been pushed, which is exactly where giving
# up without a word costs most.
#
# ★ WHY THE STAGE IS NAMED, not just the timeout: "which of the three waits gave
# up" is the difference between a drive that never accepted the write and one
# that never flushed it. A bare "timeout" would collapse those into one symptom.
#
# Same three checks as HAL.3c: healthy path unchanged / fault diagnosed /
# red-path against the unbounded original, which must still crash.
set -u
cd "$(dirname "$0")/.." || exit 1
ok=1
command -v qemu-system-x86_64 >/dev/null 2>&1 || { echo "SKIP  HAL.3bc: qemu absent"; exit 0; }
[ -x ./kernel/build_hal3b.sh ] || { echo "SKIP  HAL.3bc: build_hal3b.sh absent"; exit 0; }

boot() {  # $1 = elf, $2 = extra qemu args ("" for no disk)
    timeout 60 qemu-system-x86_64 -kernel "$1" $2 -m 256 -serial stdio -display none \
      -device isa-debug-exit,iobase=0xf4,iosize=0x04 -no-reboot -no-shutdown 2>/dev/null | tr -d '\0'
}

./kernel/build_hal3b.sh >/dev/null 2>&1 || { echo "FAIL  HAL.3bc: build_hal3b.sh failed"; exit 1; }

# ── 1. healthy path unchanged ──────────────────────────────────────────────
H=$(boot kernel/kernel_hal3b.elf "-drive file=kernel/hal3bdisk.img,format=raw,if=ide")
if printf '%s' "$H" | grep -qF 'ata3b done' && printf '%s' "$H" | grep -qF 'LOGOS-WROTE-THIS-HAL3B'; then
    echo "PASS  HAL.3bc 1: with a real disk the bounded write path still round-trips the sector"
else
    echo "FAIL  HAL.3bc 1: the bounds broke the WORKING case: $(printf '%s' "$H" | tr '\n' '|' | head -c 180)"; ok=0
fi

# ── 2. the fault is diagnosed, by stage, and is not fatal ──────────────────
F=$(boot kernel/kernel_hal3b.elf "")
fseen=$(printf '%s' "$F" | tr '\n' '|' | head -c 180)
if printf '%s' "$F" | grep -q 'EXCEPTION'; then
    echo "FAIL  HAL.3bc 2: the kernel still faults on a never-ready channel: $fseen"; ok=0
elif printf '%s' "$F" | grep -qF 'ata3b dead' && printf '%s' "$F" | grep -q 'ata3b .* timeout st='; then
    echo "PASS  HAL.3bc 2: a never-ready channel is diagnosed and the kernel exits cleanly — $(printf '%s' "$F" | grep -o 'ata3b [a-z ]*timeout st=[0-9]*')"
else
    echo "FAIL  HAL.3bc 2: no staged diagnosis on serial (wanted 'ata3b <stage> timeout st=' + 'ata3b dead'): $fseen"; ok=0
fi

# ── 2b. the stage named must be the FIRST wait, not a later one ────────────
#   With no drive at all, the failure must be reported at 'write drq' — the
#   first wait. If it named 'flush bsy' or 'readback drq' the driver would have
#   walked past a wait that never succeeded, which is the bug in a new costume.
if printf '%s' "$F" | grep -qF 'ata3b write drq timeout'; then
    echo "PASS  HAL.3bc 2b: the stage named is the FIRST wait ('write drq') — the driver stopped where it actually stalled"
elif printf '%s' "$F" | grep -q 'ata3b .* timeout'; then
    echo "FAIL  HAL.3bc 2b: diagnosed at '$(printf '%s' "$F" | grep -o 'ata3b [a-z ]*timeout')' but with NO drive the first wait must be the one that fails — a later stage means an earlier wait was walked past"; ok=0
fi

# ── 3. RED PATH: the unbounded control must still die ──────────────────────
if [ -x ./kernel/build_hal3bc_ctrl.sh ] && [ -f kernel/ata3b_ctrl.la ]; then
    ./kernel/build_hal3bc_ctrl.sh >/dev/null 2>&1 || { echo "FAIL  HAL.3bc: control build failed"; ok=0; }
    if [ -f kernel/kernel_hal3b_ctrl.elf ]; then
        C=$(boot kernel/kernel_hal3b_ctrl.elf "")
        cseen=$(printf '%s' "$C" | tr '\n' '|' | head -c 120)
        if printf '%s' "$C" | grep -q 'EXCEPTION'; then
            echo "      red-path OK: the UNBOUNDED control still dies on the same input ($cseen) — the bounds are load-bearing"
        else
            echo "FAIL  HAL.3bc 3 [red-path]: the unbounded control did NOT crash ($cseen) — this gate cannot"
            echo "      distinguish the fix from no fix, so check 2 proves nothing."; ok=0
        fi
    fi
else
    echo "      NOTE: red-path SKIPPED — kernel/ata3b_ctrl.la + build_hal3bc_ctrl.sh not present."
fi

[ "$ok" = 1 ] && echo "PASS  HAL.3bc: the ATA WRITE path's three waits are bounded — a channel that never becomes ready is named on serial WITH THE STAGE THAT STALLED and the kernel exits cleanly, where before it recursed into unmapped memory and died. (The write control faults as EXCEPTION 06 and the read control as 0d -- runaway recursion lands wherever it lands, so the check greps for ANY exception and this line no longer names one it cannot promise.) Honest scope: this bounds and DIAGNOSES; it does not re-initialise the channel and retry, and a mid-write stall still leaves the sector unwritten — it just says so." || { echo "HAL.3bc gate RED"; exit 1; }
