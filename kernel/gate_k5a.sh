#!/usr/bin/env bash
# LogOS kernel K5a slice gate — the timer IRQ live on the metal.
# Boot kernel_timer.elf in QEMU and assert the LA image observed the timer:
#   "K5 TICKS <n>" with n >= 1  — an asynchronous IRQ0 fired DURING the LA
#     image's spin (PIC remapped, PIT ~100 Hz, IDT[0x20] -> timer_isr, sti),
#     the ISR bumped the tick counter, and the LA code resumed and read it
#     back through peek() — proving preemption capability on bare metal.
#   then a clean success exit.
#
#   success: n >= 1 over COM1 -> exit(0) -> isa-debug-exit 0x10 -> QEMU exits 33.
#   broken timer: the tick stays 0 -> the LA spin runs to its cap / this 30 s
#     timeout, and the "K5 TICKS 0" (or no line) fails the grep. -no-reboot
#     makes a triple-fault exit non-33.
#
# Builds kernel_timer.elf first (shares native_input.la with build.sh — run
# SEQUENTIALLY, never in parallel with a build). Skips (rc 0) when QEMU absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  K5a-timer gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_k5a.sh >/dev/null 2>&1 || { echo "FAIL  K5a-timer gate: build_k5a.sh failed"; exit 1; }

OUT=$(timeout 30 qemu-system-x86_64 \
        -kernel kernel/kernel_timer.elf -m 256 \
        -serial stdio -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown 2>/dev/null)
RC=$?

ok=1
seen=$(printf '%s' "$OUT" | tr -d '\0' | tr '\n' ' ' | head -c 260)
# The tick count must be present AND >= 1. Grep the line, extract the number.
TICKS=$(printf '%s' "$OUT" | sed -n 's/.*K5 TICKS \([0-9][0-9]*\).*/\1/p' | head -1)
if [ -z "$TICKS" ]; then
    echo "FAIL  K5a-timer: no 'K5 TICKS <n>' line — the LA image never printed a tick count (rc=$RC, got: $seen)"; ok=0
elif [ "$TICKS" -lt 1 ]; then
    echo "FAIL  K5a-timer: tick count is $TICKS — the timer IRQ never fired during LA execution (PIC/PIT/IDT/sti wiring, rc=$RC)"; ok=0
fi
[ "$RC" -eq 33 ] || { echo "FAIL  K5a-timer: clean-exit code != 33 (got $RC — a fault/triple-fault or hang)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  K5a slice: the timer IRQ live on the metal — PIC remapped + PIT ~100 Hz + IDT[0x20] timer_isr; an asynchronous IRQ0 fired DURING the LA image's execution ($TICKS ticks observed via peek), the ISR bumped the counter and the LA code resumed intact (preemption capability, b_tau == f_tau on the metal)"
[ "$ok" -eq 1 ]
