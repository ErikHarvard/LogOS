#!/usr/bin/env bash
# LogOS HAL.5b — build the bootable NIC send+receive kernel.
#   nic5b.la --(native_codegen3)--> native_codegen3_out --> kernel_hal5b.elf
# Same pipeline as build_hal5 (default ring-0 boot path); NO regen (inb/inl/
# outb/outl already exist from HAL.1, outw/inw from HAL.4) and NO -D HAL4 (the
# DMA buffers live at 256 MiB, inside the default 0..1 GiB identity map).
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos

echo "[1/4] compile nic5b.la via native_codegen3"
cp kernel/nic5b.la native_input.la
( if [ -x native_codegen3_selfhost.bin ]; then cp native_codegen3_selfhost.bin /tmp/_ncc$$ && chmod +x /tmp/_ncc$$ && /tmp/_ncc$$; rc=$?; rm -f /tmp/_ncc$$; exit $rc; else ./tiny_host native_codegen3.la; fi; ) >/dev/null
ENTRY=$(readelf -h native_codegen3_out | awk '/Entry point/{print $NF}')
echo "      e_entry (LA prol) = $ENTRY"

echo "[2/4] generate entry.inc"
printf 'LA_ENTRY equ %s\n' "$ENTRY" > kernel/entry.inc

echo "[3/4] assemble boot.asm (default ring-0 path)"
nasm -f elf64 -i kernel/ kernel/boot.asm -o kernel/boot.o

echo "[4/4] link -> kernel_hal5b.elf (elf64 -> elf32-i386 container)"
ld -n -T kernel/kernel.ld kernel/boot.o -o kernel/kernel_hal5b_64.elf
objcopy -O elf32-i386 kernel/kernel_hal5b_64.elf kernel/kernel_hal5b.elf

echo "OK: kernel/kernel_hal5b.elf"
