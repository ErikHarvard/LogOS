#!/usr/bin/env bash
# LogOS HAL.2b — build the bootable IRQ-driven-keyboard kernel.
#   kbd2.la --(native_codegen3)--> native_codegen3_out --> kernel_hal2b.elf
#   boot.asm assembled with -D HAL2B (kbdirq.asm: remap PIC, IDT[0x21]->kbd_isr,
#   unmask IRQ1, sti). Same pipeline as build_hal5b; NO regen (kbd2.la uses only
#   peek + arithmetic — no new builtin; the interrupt substrate is pure asm).
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos

echo "[1/4] compile kbd2.la via native_codegen3"
cp kernel/kbd2.la native_input.la
( if [ -x native_codegen3_selfhost.bin ]; then cp native_codegen3_selfhost.bin /tmp/_ncc$$ && chmod +x /tmp/_ncc$$ && /tmp/_ncc$$; rc=$?; rm -f /tmp/_ncc$$; exit $rc; else ./tiny_host native_codegen3.la; fi; ) >/dev/null
ENTRY=$(readelf -h native_codegen3_out | awk '/Entry point/{print $NF}')
echo "      e_entry (LA prol) = $ENTRY"

echo "[2/4] generate entry.inc"
printf 'LA_ENTRY equ %s\n' "$ENTRY" > kernel/entry.inc

echo "[3/4] assemble boot.asm (-D HAL2B: PIC + IRQ1 keyboard ISR)"
nasm -f elf64 -D HAL2B -i kernel/ kernel/boot.asm -o kernel/boot.o

echo "[4/4] link -> kernel_hal2b.elf (elf64 -> elf32-i386 container)"
ld -n -T kernel/kernel.ld kernel/boot.o -o kernel/kernel_hal2b_64.elf
objcopy -O elf32-i386 kernel/kernel_hal2b_64.elf kernel/kernel_hal2b.elf

echo "OK: kernel/kernel_hal2b.elf"
