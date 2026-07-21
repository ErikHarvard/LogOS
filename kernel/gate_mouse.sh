#!/usr/bin/env bash
# LogOS HAL.2c gate — the kernel's POINTER sense: a PS/2 mouse in Lingua Adamica.
# Boot the PS/2-mouse kernel, inject relative motion + a button via the QEMU
# monitor (mouse_move / mouse_button), and assert the LA driver brought the AUX
# device up itself and decoded the i8042 packet stream:
#   - "mouse:"     — the driver started, enabled AUX + reporting, drained the ACK;
#   - "m <f> ..."  — it polled status 0x64 for AUX bytes (bit5) and read 3-byte
#                    packets off 0x60. A valid PS/2 packet always has flags bit3
#                    set, so f >= 8 on every line — a broken/keyboard read cannot
#                    fake that. At least one packet must carry NON-ZERO motion
#                    (the injected move actually reached the guest), and one must
#                    carry a pressed button (flags bit0, so f is odd -> f >= 9);
#   - "mouse done" — it read its bounded PKTN packets and returned;
#   - exit 33      — clean exit via isa-debug-exit.
# QEMU only queues mouse motion AFTER the guest sends 0xF4, so a passing gate
# proves the LA init (outb 0xA8 / 0xD4 / 0xF4) ran. Events go in on the monitor;
# serial output comes out to a file. Skips (rc 0) if QEMU is absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  HAL.2c mouse gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_mouse.sh >/dev/null 2>&1 || { echo "FAIL  HAL.2c gate: build_mouse.sh failed"; exit 1; }

OUTF=$(mktemp)
# Boot, wait for the driver to enable reporting, then inject > 3 events so the
# bounded reader never starves: two moves, a click (press+release), one move.
{ sleep 2
  echo "mouse_move 30 0";  sleep 0.4
  echo "mouse_move 0 30";  sleep 0.4
  echo "mouse_button 1";   sleep 0.4
  echo "mouse_button 0";   sleep 0.4
  echo "mouse_move -30 0"; sleep 0.4
  sleep 1
} | timeout 40 qemu-system-x86_64 \
        -kernel kernel/kernel_mouse.elf -m 256 \
        -serial "file:$OUTF" -monitor stdio -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown >/dev/null 2>&1
RC=$?
OUT=$(tr -d '\0' < "$OUTF"); rm -f "$OUTF"
seen=$(printf '%s' "$OUT" | tr '\n' ' ' | head -c 300)

ok=1
printf '%s' "$OUT" | grep -qF 'mouse:'    || { echo "FAIL  HAL.2c: 'mouse:' not on serial (rc=$RC, got: $seen)"; ok=0; }
printf '%s' "$OUT" | grep -qF 'mouse done' || { echo "FAIL  HAL.2c: 'mouse done' not on serial — a packet read starved or MAIN exited early (rc=$RC, got: $seen)"; ok=0; }

# Parse the "m <flags> <dx> <dy>" packet lines.
PKTS=$(printf '%s' "$OUT" | grep -E '^m [0-9]+ [0-9]+ [0-9]+$')
NPKT=$(printf '%s' "$PKTS" | grep -c .)
[ "$NPKT" -ge 3 ] || { echo "FAIL  HAL.2c: fewer than 3 packet lines decoded (got $NPKT; $seen)"; ok=0; }

# Every packet's flags must have bit3 set (>=8) — the PS/2 sync bit.
BADSYNC=$(printf '%s' "$PKTS" | awk '{ if ($2 < 8) print }')
[ -z "$BADSYNC" ] || { echo "FAIL  HAL.2c: a packet lacks the flags-bit3 sync bit (flags<8): $BADSYNC"; ok=0; }

# At least one packet carried real motion (dx or dy != 0).
MOVED=$(printf '%s' "$PKTS" | awk '($3 != 0 || $4 != 0){c++} END{print c+0}')
[ "${MOVED:-0}" -ge 1 ] || { echo "FAIL  HAL.2c: no packet carried non-zero motion — injected moves never reached the guest ($seen)"; ok=0; }

# At least one packet had the left button down (flags bit0 set -> odd flags).
CLICKED=$(printf '%s' "$PKTS" | awk '($2 % 2 == 1){c++} END{print c+0}')
[ "${CLICKED:-0}" -ge 1 ] || { echo "FAIL  HAL.2c: no packet reported a button press (flags bit0) ($seen)"; ok=0; }

[ "$RC" -eq 33 ] || { echo "FAIL  HAL.2c: exit code != 33 (got $RC; $seen)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  HAL.2c: PS/2 mouse (the AUX device) in Lingua Adamica — on the HAL.1 port-I/O primitives (inb+outb), an LA program at ring 0 enabled the aux device (0xA8), turned on data reporting (0xD4/0xF4), then polled the i8042 (status 0x64 bit5 = AUX / data 0x60) and decoded $NPKT three-byte packets: sync bit3 present on all, real motion + a button press seen. The kernel's pointer sense, driver written in the language itself, bounded and correct."
[ "$ok" -eq 1 ]
