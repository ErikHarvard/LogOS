#!/usr/bin/env bash
# LogOS kernel K5a slice — build the bootable TIMER-IRQ probe ELF.
#   timer_probe.la --(native_codegen3, uses peek)--> the LA image that spins
#     reading the tick counter at TICK_ADDR until the timer has fired.
#   boot.asm (assembled -dK5_TIMER: PIC remap + PIT ~100 Hz + IDT[0x20]
#     timer_isr + sti; timer.asm's body is otherwise zero bytes) + incbin(image)
#     --> kernel_timer.elf
# Separate output so the K1/K2/K3b/K4b/K4c ELFs are untouched. Shares
# native_input.la / entry.inc with build.sh — run SEQUENTIALLY, never in parallel.
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos

echo "[1/4] compile timer_probe.la via native_codegen3 (uses peek)"
cp kernel/timer_probe.la native_input.la
( if [ -x native_codegen3_selfhost.bin ]; then cp native_codegen3_selfhost.bin /tmp/_ncc$$ && chmod +x /tmp/_ncc$$ && /tmp/_ncc$$; rc=$?; rm -f /tmp/_ncc$$; exit $rc; else ./tiny_host native_codegen3.la; fi; ) >/dev/null
ENTRY=$(readelf -h native_codegen3_out | awk '/Entry point/{print $NF}')
echo "      e_entry (LA prol) = $ENTRY"

echo "[2/4] generate entry.inc"
printf 'LA_ENTRY equ %s\n' "$ENTRY" > kernel/entry.inc

echo "[3/4] assemble boot.asm -dK5_TIMER (timer substrate armed)"
nasm -f elf64 -dK5_TIMER -i kernel/ kernel/boot.asm -o kernel/boot_timer.o

echo "[4/4] link -> kernel_timer.elf (elf64), repackage as elf32-i386"
ld -n -T kernel/kernel.ld kernel/boot_timer.o -o kernel/kernel_timer_64.elf
objcopy -O elf32-i386 kernel/kernel_timer_64.elf kernel/kernel_timer.elf

echo "OK: kernel/kernel_timer.elf"
