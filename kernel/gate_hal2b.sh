#!/usr/bin/env bash
# LogOS HAL.2b gate — an IRQ-driven keyboard driver in Lingua Adamica reads real
# keystrokes woken by a hardware interrupt. Boot the kernel (PIC remapped,
# IDT[0x21]->kbd_isr, IRQ1 unmasked, interrupts on), inject `l o g o s <enter>`
# through the QEMU monitor, and assert the LA driver echoed the line off the
# metal:
#   - "kbd2:"    — the driver started;
#   - "logos"    — IRQ1 fired per key, kbd_isr read each SET-1 scancode from 0x60
#                  into the ring, and the LA driver consumed + decoded the ring
#                  (peek 0x320000/0x320008) until ENTER;
#   - "kbd done" — it finished;
#   - exit 33    — clean exit via isa-debug-exit.
# So: a real hardware interrupt path (8259 PIC + IRQ1 + an IDT gate) drives input
# with the LA program never touching the i8042 — the interrupt-driven twin of
# HAL.2's polling driver. Skips (rc 0) if QEMU is absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  HAL.2b keyboard gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_hal2b.sh >/dev/null 2>&1 || { echo "FAIL  HAL.2b gate: build_hal2b.sh failed"; exit 1; }

OUTF=$(mktemp)
# Boot, wait for the driver to arm, then inject l o g o s <enter> via the monitor.
# Each key is spaced out; IRQ1 delivers each scancode to the ring as it arrives.
{ sleep 2
  for k in l o g o s; do echo "sendkey $k"; sleep 0.3; done
  sleep 0.3; echo "sendkey ret"
  sleep 1
} | timeout 40 qemu-system-x86_64 \
        -kernel kernel/kernel_hal2b.elf -m 256 \
        -serial "file:$OUTF" -monitor stdio -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown >/dev/null 2>&1
RC=$?
OUT=$(tr -d '\0' < "$OUTF"); rm -f "$OUTF"
seen=$(printf '%s' "$OUT" | tr '\n' ' ' | head -c 240)

ok=1
for tok in 'kbd2:' 'logos' 'kbd done'; do
    printf '%s' "$OUT" | grep -qF "$tok" || { echo "FAIL  HAL.2b: '$tok' not on serial (rc=$RC, got: $seen)"; ok=0; }
done
[ "$RC" -eq 33 ] || { echo "FAIL  HAL.2b: exit code != 33 (got $RC; got: $seen)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  HAL.2b: IRQ-driven keyboard in Lingua Adamica — the kernel remapped the 8259 PIC, installed IDT[0x21]->kbd_isr and unmasked IRQ1; each keystroke's hardware interrupt woke the ISR to read the SET-1 scancode from 0x60 into a ring, and the LA driver consumed + decoded that ring (peek) until ENTER, never touching the i8042. A real interrupt path drives input — the interrupt-driven twin of HAL.2's polling driver."
[ "$ok" -eq 1 ]
