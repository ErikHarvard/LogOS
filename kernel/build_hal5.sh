#!/usr/bin/env bash
# LogOS HAL.5a — build the bootable NIC-discovery kernel.
#   nic.la --(native_codegen3)--> native_codegen3_out --> kernel_hal5.elf (ring-0)
# Same pipeline as build_hal3 (default ring-0 boot path); NO regen (inb/inl/outl
# already exist from HAL.1) and NO -D HAL4 (pure port I/O — no high MMIO BAR).
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos

echo "[1/4] compile nic.la via native_codegen3"
cp kernel/nic.la native_input.la
./tiny_host native_codegen3.la >/dev/null
ENTRY=$(readelf -h native_codegen3_out | awk '/Entry point/{print $NF}')
echo "      e_entry (LA prol) = $ENTRY"

echo "[2/4] generate entry.inc"
printf 'LA_ENTRY equ %s\n' "$ENTRY" > kernel/entry.inc

echo "[3/4] assemble boot.asm (default ring-0 path)"
nasm -f elf64 -i kernel/ kernel/boot.asm -o kernel/boot.o

echo "[4/4] link -> kernel_hal5.elf (elf64 -> elf32-i386 container)"
ld -n -T kernel/kernel.ld kernel/boot.o -o kernel/kernel_hal5_64.elf
objcopy -O elf32-i386 kernel/kernel_hal5_64.elf kernel/kernel_hal5.elf

echo "OK: kernel/kernel_hal5.elf"
