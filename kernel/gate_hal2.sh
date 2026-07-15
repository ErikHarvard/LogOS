#!/usr/bin/env bash
# LogOS HAL.2 gate — the kernel's first INPUT sense, keyboard, in Lingua Adamica.
# Boot the PS/2-keyboard kernel, inject a keystroke sequence via the QEMU monitor
# (sendkey), and assert the LA driver read + decoded them off the i8042:
#   - "kbd:"     — the driver started;
#   - "logos"    — it polled the controller, decoded SET-1 scancodes for the
#                  injected keys l,o,g,o,s, and echoed the collected line;
#   - "kbd done" — it saw ENTER (scancode 28) and finished;
#   - exit 33    — clean exit via isa-debug-exit.
# Keys go in on the monitor; serial output comes out to a file (the two channels
# kept separate). So: the HAL.1 port-I/O primitive (inb) lets an LA program at
# ring 0 drive a real input device — the reciprocal of the serial console.
# Skips (rc 0) if QEMU is absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  HAL.2 keyboard gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_hal2.sh >/dev/null 2>&1 || { echo "FAIL  HAL.2 gate: build_hal2.sh failed"; exit 1; }

OUTF=$(mktemp)
# Boot, wait for the driver to start polling, then inject l o g o s <enter>.
# The i8042 buffers keystrokes, and each key is spaced out, so the poll loop
# catches every one. Serial -> file; monitor <- our sendkey stream on stdin.
{ sleep 2
  for k in l o g o s; do echo "sendkey $k"; sleep 0.3; done
  sleep 0.3; echo "sendkey ret"
  sleep 1
} | timeout 40 qemu-system-x86_64 \
        -kernel kernel/kernel_hal2.elf -m 256 \
        -serial "file:$OUTF" -monitor stdio -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown >/dev/null 2>&1
RC=$?
OUT=$(tr -d '\0' < "$OUTF"); rm -f "$OUTF"
seen=$(printf '%s' "$OUT" | tr '\n' ' ' | head -c 240)

ok=1
for tok in 'kbd:' 'logos' 'kbd done'; do
    printf '%s' "$OUT" | grep -qF "$tok" || { echo "FAIL  HAL.2: '$tok' not on serial (rc=$RC, got: $seen)"; ok=0; }
done
[ "$RC" -eq 33 ] || { echo "FAIL  HAL.2: exit code != 33 (got $RC; got: $seen)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  HAL.2: PS/2 keyboard input in Lingua Adamica — on the HAL.1 port-I/O primitive (inb), an LA program at ring 0 polled the i8042 (status 0x64 / data 0x60), decoded SET-1 scancodes for the injected keys, and echoed 'logos' + finished on ENTER. The kernel's first input sense, driver written in the language itself."
[ "$ok" -eq 1 ]
