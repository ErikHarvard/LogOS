#!/bin/sh
# gate_hal3c.sh — HAL.3c: the ATA wait is BOUNDED, so a disk that never becomes
# ready is DIAGNOSED instead of killing the kernel.
#
# ── THE BUG THIS GATE EXISTS FOR (found + reproduced 2026-08-18) ────────────
# ata.la's WAITDRQ had no fuel. On a channel that never becomes ready it
# recursed until it ran off into unmapped memory:
#     ata:|EXCEPTION 0d err=0000000000000000 rip=0000000007ffffc0
# Deterministic, and identical with a present-but-empty CD-ROM — two real fault
# modes, one silent crash with nothing naming the disk as the cause.
#
# ★ WHY NO GATE SAW IT: every ATA gate attaches a working disk. HAL.3 and HAL.3b
# are both [x] DONE + gated and both were RIGHT — they simply never presented
# the fault. A driver is not proven robust by a gate that only ever gives it a
# healthy device. That is the same blind spot HAL.5q/5r were built to close on
# the NIC, applied to the disk organ.
#
# ── THREE CHECKS ───────────────────────────────────────────────────────────
#   1. HEALTHY PATH UNCHANGED — with a real disk the driver still reads the
#      sector. The bound must not cost the working case.
#   2. FAULT DIAGNOSED — with no disk it prints "ata drq timeout st=<status>"
#      and "ata dead", and exits CLEANLY. No EXCEPTION.
#   3. RED PATH — the unbounded control (kernel/ata_ctrl.la, the driver exactly
#      as it was before) must still CRASH on the same input. Without this the
#      gate cannot tell you the bound did anything.
set -u
cd "$(dirname "$0")/.." || exit 1
ok=1
command -v qemu-system-x86_64 >/dev/null 2>&1 || { echo "SKIP  HAL.3c: qemu absent"; exit 0; }

boot() {  # $1 = elf, $2 = extra qemu args ("" for no disk)
    timeout 60 qemu-system-x86_64 -kernel "$1" $2 -m 256 -serial stdio -display none \
      -device isa-debug-exit,iobase=0xf4,iosize=0x04 -no-reboot -no-shutdown 2>/dev/null | tr -d '\0'
}

[ -x ./kernel/build_hal3.sh ] || { echo "SKIP  HAL.3c: build_hal3.sh absent"; exit 0; }
./kernel/build_hal3.sh >/dev/null 2>&1 || { echo "FAIL  HAL.3c: build_hal3.sh failed"; exit 1; }

# ── 1. healthy path ────────────────────────────────────────────────────────
H=$(boot kernel/kernel_hal3.elf "-drive file=kernel/hal3disk.img,format=raw,if=ide")
if printf '%s' "$H" | grep -qF 'ata done' && printf '%s' "$H" | grep -qF 'LOGOS-DISK-OK-HAL3'; then
    echo "PASS  HAL.3c 1: with a real disk the bounded driver still reads the sector (healthy path unchanged)"
else
    echo "FAIL  HAL.3c 1: the bound broke the WORKING case: $(printf '%s' "$H" | tr '\n' '|' | head -c 160)"; ok=0
fi

# ── 2. the fault is diagnosed, not fatal ───────────────────────────────────
F=$(boot kernel/kernel_hal3.elf "")
fseen=$(printf '%s' "$F" | tr '\n' '|' | head -c 160)
if printf '%s' "$F" | grep -q 'EXCEPTION'; then
    echo "FAIL  HAL.3c 2: the kernel still faults on a never-ready channel: $fseen"; ok=0
elif printf '%s' "$F" | grep -qF 'ata drq timeout st=' && printf '%s' "$F" | grep -qF 'ata dead'; then
    echo "PASS  HAL.3c 2: a never-ready channel is DIAGNOSED and the kernel exits cleanly — $(printf '%s' "$F" | grep -o 'ata drq timeout st=[0-9]*')"
else
    echo "FAIL  HAL.3c 2: no diagnosis on serial (wanted 'ata drq timeout st=' + 'ata dead'): $fseen"; ok=0
fi

# ── 3. RED PATH: the unbounded control must still die ──────────────────────
#   ★ Without this the gate proves only that the FIXED driver behaves, which is
#   consistent with the bound doing nothing at all.
if [ -x ./kernel/build_hal3c_ctrl.sh ] && [ -f kernel/ata_ctrl.la ]; then
    ./kernel/build_hal3c_ctrl.sh >/dev/null 2>&1 || { echo "FAIL  HAL.3c: control build failed"; ok=0; }
    if [ -f kernel/kernel_hal3_ctrl.elf ]; then
        C=$(boot kernel/kernel_hal3_ctrl.elf "")
        cseen=$(printf '%s' "$C" | tr '\n' '|' | head -c 120)
        if printf '%s' "$C" | grep -q 'EXCEPTION'; then
            echo "      red-path OK: the UNBOUNDED control still dies on the same input ($cseen) — the bound is load-bearing"
        else
            echo "FAIL  HAL.3c 3 [red-path]: the unbounded control did NOT crash ($cseen) — this gate cannot"
            echo "      distinguish the fix from no fix, so check 2 proves nothing."; ok=0
        fi
    fi
else
    echo "      NOTE: red-path SKIPPED — kernel/ata_ctrl.la + build_hal3c_ctrl.sh not present."
fi

[ "$ok" = 1 ] && echo "PASS  HAL.3c: the ATA wait is bounded — a disk that never becomes ready is named on serial and the kernel exits cleanly, where before it recursed into unmapped memory and died with EXCEPTION 0d and no mention of the disk. Honest scope: this bounds and DIAGNOSES the fault; it does not yet re-initialise the channel and retry (that is the 5q/5r repair loop applied to the disk organ, still open)." || { echo "HAL.3c gate RED"; exit 1; }
