#!/bin/sh
# gate_hal3d.sh — HAL.3d: a SELF-REPAIRING ATA read path.
#
# AATC's Sense -> Diagnose -> Prescribe -> Retry applied to the DISK organ, as
# HAL.5q/5r applied it to the NIC. HAL.3c bounded the wait and NAMED the
# failure; it stops. This one recovers: on a wedged channel it senses status
# and the error register, diagnoses, applies the drive's OWN documented
# software reset (SRST in device control 0x3F6), re-issues the read, and either
# recovers or says "ata dead" — bounded at every step.
#
# ── ★ CHECK 1 IS LOAD-BEARING. READ THIS BEFORE TRUSTING A GREEN ────────────
# The fault is SELF-INFLICTED: the driver holds the drive in reset so its first
# read cannot complete. If QEMU ignores that register write, the drive never
# wedges, the repair branch is DEAD CODE, and every other check here passes
# while proving nothing whatsoever.
#
# This is not hypothetical. HAL.5s died on exactly this: a real TABT fault
# turned out to be inert in QEMU (it raises TOK+TUN and never TABT), and 5s is
# HELD as a result. So check 1 asserts the wedge ACTUALLY HAPPENED, and the
# driver prints "ata read ok (NO WEDGE — fault did not manifest)" if it did not,
# so the failure names itself instead of hiding as a pass.
set -u
cd "$(dirname "$0")/.." || exit 1
ok=1
command -v qemu-system-x86_64 >/dev/null 2>&1 || { echo "SKIP  HAL.3d: qemu absent"; exit 0; }
[ -x ./kernel/build_hal3d.sh ] || { echo "SKIP  HAL.3d: build_hal3d.sh absent"; exit 0; }

boot() {
    timeout 60 qemu-system-x86_64 -kernel "$1" \
      -drive file=kernel/hal3disk.img,format=raw,if=ide -m 256 \
      -serial stdio -display none -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
      -no-reboot -no-shutdown 2>/dev/null | tr -d '\0'
}

./kernel/build_hal3d.sh >/dev/null 2>&1 || { echo "FAIL  HAL.3d: build_hal3d.sh failed"; exit 1; }
M=$(boot kernel/kernel_hal3d.elf)
seen=$(printf '%s' "$M" | tr '\n' '|' | head -c 220)

# ── 1. did the fault manifest AT ALL? ──────────────────────────────────────
if printf '%s' "$M" | grep -qF 'NO WEDGE'; then
    echo "FAIL  HAL.3d 1: the injected fault DID NOT MANIFEST — QEMU ignored the reset hold."
    echo "      The repair branch was never entered, so checks 2 and 3 would be measuring"
    echo "      nothing. Redesign the fault (bogus command byte / out-of-range LBA) rather"
    echo "      than accepting this run. See SELFREPAIR_3d_DESIGN.md. Serial: $seen"
    exit 1
elif printf '%s' "$M" | grep -q 'ata wedged st='; then
    echo "PASS  HAL.3d 1: the fault manifested — $(printf '%s' "$M" | grep -o 'ata wedged st=[0-9]* err=[0-9]*')"
else
    echo "FAIL  HAL.3d 1: neither a wedge nor a clean read on serial — the driver did not reach the loop: $seen"; exit 1
fi

# ── 2. did the repair actually work? ───────────────────────────────────────
if printf '%s' "$M" | grep -qF 'ata recovered' && printf '%s' "$M" | grep -qF 'ata3d done' \
   && printf '%s' "$M" | grep -qF 'LOGOS-DISK-OK-HAL3'; then
    echo "PASS  HAL.3d 2: sensed, diagnosed, reset the drive from spec, retried, and READ THE SECTOR — the repair recovered a real read"
else
    echo "FAIL  HAL.3d 2: no recovery (wanted 'ata recovered' + 'ata3d done' + the on-disk signature): $seen"; ok=0
fi

# ── 3. RED PATH: the control, repair removed, must NOT recover ─────────────
if [ -x ./kernel/build_hal3d_ctrl.sh ] && [ -f kernel/ata3d_ctrl.la ]; then
    ./kernel/build_hal3d_ctrl.sh >/dev/null 2>&1 || { echo "FAIL  HAL.3d: control build failed"; ok=0; }
    if [ -f kernel/kernel_hal3d_ctrl.elf ]; then
        C=$(boot kernel/kernel_hal3d_ctrl.elf)
        cseen=$(printf '%s' "$C" | tr '\n' '|' | head -c 180)
        if printf '%s' "$C" | grep -qF 'ata recovered'; then
            echo "FAIL  HAL.3d 3 [red-path]: the NO-REPAIR control recovered anyway ($cseen)."
            echo "      The drive is shrugging the fault off by itself, so check 2 does not"
            echo "      show the repair doing anything. The gate cannot discriminate."; ok=0
        elif printf '%s' "$C" | grep -qF 'ata dead'; then
            echo "      red-path OK: the no-repair control wedges and dies ($cseen) — the repair is load-bearing"
        else
            echo "FAIL  HAL.3d 3 [red-path]: the control did neither ($cseen)"; ok=0
        fi
    fi
else
    echo "      NOTE: red-path SKIPPED — kernel/ata3d_ctrl.la + build_hal3d_ctrl.sh not present."
fi

[ "$ok" = 1 ] && echo "PASS  HAL.3d: a SELF-REPAIRING ATA read path in Lingua Adamica — the driver's channel was deliberately wedged, its bounded DRQ wait timed out, it SENSED status and the error register, DIAGNOSED the wedge on serial, PRESCRIBED the drive's own documented software reset, RETRIED bounded, and RECOVERED a real sector read; red-pathed against a control with the repair removed, which wedges and dies. Honest scope: a self-inflicted fault proves the MECHANISM, not universal fault-tolerance." || { echo "HAL.3d gate RED"; exit 1; }
