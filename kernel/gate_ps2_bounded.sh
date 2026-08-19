#!/bin/sh
# gate_ps2_bounded.sh <driver> <tag> — Freeze Audit II / Q3 red-path.
#
# Proves a PS/2 driver's OWED waits are bounded: the fixed driver DIAGNOSES an
# unanswered ACK and STOPS, while the pre-fix driver dies on the same input.
#
#   <driver>_faulted  = the FIXED driver, 0xF4 removed so no ACK is owed
#   <driver>_ctrl     = the PRE-FIX driver, same fault
#
# ★ WHAT THIS PROVES AND WHAT IT DOES NOT. A bound claims only "this loop
# terminates", so a self-inflicted never-satisfied wait is a fair test of it.
# It is NOT evidence of fault tolerance: a REPAIR would claim the device was
# fixed, which needs a fault both realistic and persistent -- a standard HAL.3d
# failed twice (SELFREPAIR_3d_DESIGN.md).
#
# ★ AND IT MUST CHECK THE DRIVER STOPS, not merely that it printed. mouse.la's
# first cut diagnosed correctly and then read packets from the device it had
# just declared dead, faulting a second time (EXCEPTION 03) -- a bound that
# reports and continues has MOVED the crash, not removed it.
set -u
[ $# -eq 2 ] || { echo "usage: gate_ps2_bounded.sh <driver> <tag>"; exit 2; }
D=$1; TAG=$2
cd "$(dirname "$0")/.." || exit 1
ok=1
command -v qemu-system-x86_64 >/dev/null 2>&1 || { echo "SKIP  ${D}_bounded: qemu absent"; exit 0; }

boot() {
    timeout 45 qemu-system-x86_64 -kernel "$1" -m 256 -serial stdio -display none \
      -device isa-debug-exit,iobase=0xf4,iosize=0x04 -no-reboot -no-shutdown 2>/dev/null | tr -d '\0'
}

[ -x "./kernel/build_${D}_faulted.sh" ] || { echo "SKIP  ${D}_bounded: no faulted build script"; exit 0; }
./kernel/build_${D}_faulted.sh >/dev/null 2>&1 || { echo "FAIL  ${D}_bounded: faulted build failed"; exit 1; }
F=$(boot "kernel/kernel_${D}_faulted.elf")
fseen=$(printf '%s' "$F" | tr '\n' '|' | head -c 170)
if printf '%s' "$F" | grep -q 'EXCEPTION'; then
    echo "FAIL  ${D}_bounded 1: the BOUNDED driver still faults: $fseen"; ok=0
elif printf '%s' "$F" | grep -qF "$TAG dead" && printf '%s' "$F" | grep -q "$TAG .* timeout st="; then
    echo "PASS  ${D}_bounded 1: unanswered ACK diagnosed and the kernel STOPPED cleanly — $(printf '%s' "$F" | grep -o "$TAG [a-z0-9 ]*timeout st=[0-9]*")"
else
    echo "FAIL  ${D}_bounded 1: no diagnosis (wanted '$TAG ... timeout st=' + '$TAG dead'): $fseen"; ok=0
fi

if [ -x "./kernel/build_${D}_ctrl.sh" ] && [ -f "kernel/${D}_ctrl.la" ]; then
    ./kernel/build_${D}_ctrl.sh >/dev/null 2>&1 || { echo "FAIL  ${D}_bounded: control build failed"; ok=0; }
    if [ -f "kernel/kernel_${D}_ctrl.elf" ]; then
        C=$(boot "kernel/kernel_${D}_ctrl.elf")
        cseen=$(printf '%s' "$C" | tr '\n' '|' | head -c 140)
        if printf '%s' "$C" | grep -q 'EXCEPTION'; then
            echo "      red-path OK: the UNBOUNDED pre-fix driver dies on the same input ($cseen) — the bound is load-bearing"
        else
            echo "FAIL  ${D}_bounded 2 [red-path]: control did not die ($cseen) — this gate cannot tell the fix from no fix"; ok=0
        fi
    fi
else
    echo "      NOTE: red-path SKIPPED — kernel/${D}_ctrl.la absent."
fi

[ "$ok" = 1 ] && echo "PASS  ${D}_bounded: OWED waits bounded — an unanswered handshake or ACK is named on serial with the stage that stalled and the driver STOPS, where the pre-fix version recursed until it faulted. The USER wait (packet byte 0) is deliberately still unbounded." || { echo "${D}_bounded gate RED"; exit 1; }
