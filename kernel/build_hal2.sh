#!/usr/bin/env bash
# LogOS HAL.2 — build the bootable PS/2-keyboard kernel.
#   kbd.la --(native_codegen3)--> native_codegen3_out (LA image @0x400000)
#   e_entry --> entry.inc ; boot.asm (default ring-0 path) + incbin --> kernel_hal2.elf
# The LA image runs at ring 0, so kbd.la's port I/O (inb 0x60/0x64) executes
# directly. Same pipeline as build_k1.sh/build_hal1.sh, only the program differs.
# NO regen needed: inb already exists (HAL.1).
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos

echo "[1/4] compile kbd.la via native_codegen3"
cp kernel/kbd.la native_input.la
./tiny_host native_codegen3.la >/dev/null
ENTRY=$(readelf -h native_codegen3_out | awk '/Entry point/{print $NF}')
echo "      e_entry (LA prol) = $ENTRY"

echo "[2/4] generate entry.inc"
printf 'LA_ENTRY equ %s\n' "$ENTRY" > kernel/entry.inc

echo "[3/4] assemble boot.asm (default ring-0 path)"
nasm -f elf64 -i kernel/ kernel/boot.asm -o kernel/boot.o

echo "[4/4] link -> kernel_hal2.elf (elf64), repackage container as elf32-i386"
ld -n -T kernel/kernel.ld kernel/boot.o -o kernel/kernel_hal2_64.elf
objcopy -O elf32-i386 kernel/kernel_hal2_64.elf kernel/kernel_hal2.elf

echo "OK: kernel/kernel_hal2.elf"
