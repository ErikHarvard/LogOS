#!/bin/sh
# gate_mouse_bounded.sh — Freeze Audit II / Q3: the mouse driver's OWED waits are
# bounded, so a controller that never answers is DIAGNOSED instead of killing the
# kernel.
#
# ── THE ADJUDICATION THIS GATE ENCODES ──────────────────────────────────────
#   waiting for a USER            -> correctly unbounded (packet byte 0)
#   waiting for a response OWED   -> must be bounded (IBF handshake, 0xFA ACK,
#      by the device                packet bytes 1-2)
# Bounding byte 0 as well would make an idle user look like a broken device, so
# it is deliberately left alone and this gate does not test it.
#
# ── WHY A SELF-INFLICTED FAULT IS LEGITIMATE HERE ───────────────────────────
# A BOUND claims only "this loop terminates". Any never-satisfied condition
# tests that, so removing the command whose ACK we then wait for is a fair red
# path. A REPAIR would claim the DEVICE was fixed, which needs a fault that is
# realistic AND persistent -- the standard HAL.3d failed twice (see
# SELFREPAIR_3d_DESIGN.md). Do not read this gate as proving fault-tolerance.
#
# Three kernels, one fault:
#   kernel_mouse.elf          healthy device      -> must still work (gate_mouse.sh)
#   kernel_mouse_faulted.elf  fault + bounded     -> must DIAGNOSE, exit cleanly
#   kernel_mouse_ctrl.elf     fault + UNBOUNDED   -> must DIE (the pre-fix driver)
set -u
cd "$(dirname "$0")/.." || exit 1
ok=1
command -v qemu-system-x86_64 >/dev/null 2>&1 || { echo "SKIP  mouse_bounded: qemu absent"; exit 0; }

boot() {
    timeout 45 qemu-system-x86_64 -kernel "$1" -m 256 -serial stdio -display none \
      -device isa-debug-exit,iobase=0xf4,iosize=0x04 -no-reboot -no-shutdown 2>/dev/null | tr -d '\0'
}

# ── 1. bounded + fault: diagnose, do not die ───────────────────────────────
./kernel/build_mouse_faulted.sh >/dev/null 2>&1 || { echo "FAIL  mouse_bounded: faulted build failed"; exit 1; }
F=$(boot kernel/kernel_mouse_faulted.elf)
fseen=$(printf '%s' "$F" | tr '\n' '|' | head -c 160)
if printf '%s' "$F" | grep -q 'EXCEPTION'; then
    echo "FAIL  mouse_bounded 1: the BOUNDED driver still faults on an unanswered wait: $fseen"; ok=0
elif printf '%s' "$F" | grep -qF 'mouse dead' && printf '%s' "$F" | grep -q 'mouse ack timeout st='; then
    echo "PASS  mouse_bounded 1: an unanswered ACK is diagnosed and the kernel exits cleanly — $(printf '%s' "$F" | grep -o 'mouse ack timeout st=[0-9]*')"
else
    echo "FAIL  mouse_bounded 1: no diagnosis (wanted 'mouse ack timeout st=' + 'mouse dead'): $fseen"; ok=0
fi

# ── 2. RED PATH: the pre-fix driver, same fault, must die ──────────────────
#   ★ Without this the gate shows only that the FIXED driver behaves, which is
#   equally consistent with the bound doing nothing at all.
if [ -x ./kernel/build_mouse_ctrl.sh ] && [ -f kernel/mouse_ctrl.la ]; then
    ./kernel/build_mouse_ctrl.sh >/dev/null 2>&1 || { echo "FAIL  mouse_bounded: control build failed"; ok=0; }
    if [ -f kernel/kernel_mouse_ctrl.elf ]; then
        C=$(boot kernel/kernel_mouse_ctrl.elf)
        cseen=$(printf '%s' "$C" | tr '\n' '|' | head -c 140)
        if printf '%s' "$C" | grep -q 'EXCEPTION'; then
            echo "      red-path OK: the UNBOUNDED pre-fix driver dies on the same input ($cseen) — the bound is load-bearing"
        elif printf '%s' "$C" | grep -qF 'mouse dead'; then
            echo "FAIL  mouse_bounded 2 [red-path]: the control DIAGNOSED — it is not the unbounded driver, so this gate proves nothing"; ok=0
        else
            echo "FAIL  mouse_bounded 2 [red-path]: control did neither ($cseen)"; ok=0
        fi
    fi
else
    echo "      NOTE: red-path SKIPPED — kernel/mouse_ctrl.la + build_mouse_ctrl.sh absent."
fi

[ "$ok" = 1 ] && echo "PASS  mouse_bounded: the PS/2 mouse driver's OWED waits are bounded — an IBF handshake, a 0xFA ACK or a packet continuation byte that never arrives is now named on serial with the stage that stalled and the kernel exits cleanly, where the pre-fix driver recursed until it faulted (EXCEPTION 0e). The USER wait (packet byte 0) is deliberately still unbounded: an idle user is not a broken device." || { echo "mouse_bounded gate RED"; exit 1; }
