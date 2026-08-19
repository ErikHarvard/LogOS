#!/usr/bin/env bash
# LogOS HAL.3 — build the bootable ATA-disk-read kernel + a seeded data disk.
#   ata.la --(native_codegen3)--> native_codegen3_out --> kernel_hal3d_ctrl.elf (ring-0)
#   + hal3disk.img: a raw disk with a known signature at LBA 1, which the LA
#     driver reads back via ATA PIO. Same pipeline as build_k1/build_hal1/hal2;
#     NO regen (inb/outb/inl already exist from HAL.1).
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos

SIG='LOGOS-DISK-OK-HAL3'

echo "[1/5] compile ata3d_ctrl.la (red-path control) via native_codegen3"
cp kernel/ata3d_ctrl.la native_input.la
./tiny_host native_codegen3.la >/dev/null
ENTRY=$(readelf -h native_codegen3_out | awk '/Entry point/{print $NF}')
echo "      e_entry (LA prol) = $ENTRY"

echo "[2/5] generate entry.inc"
printf 'LA_ENTRY equ %s\n' "$ENTRY" > kernel/entry.inc

echo "[3/5] assemble boot.asm (default ring-0 path)"
nasm -f elf64 -i kernel/ kernel/boot.asm -o kernel/boot.o

echo "[4/5] link -> kernel_hal3d_ctrl.elf (elf64 -> elf32-i386 container)"
ld -n -T kernel/kernel.ld kernel/boot.o -o kernel/kernel_hal3d_ctrl_64.elf
objcopy -O elf32-i386 kernel/kernel_hal3d_ctrl_64.elf kernel/kernel_hal3d_ctrl.elf

echo "[5/5] seed data disk: '$SIG' at LBA 1 (byte offset 512)"
dd if=/dev/zero of=kernel/hal3disk.img bs=1M count=1 status=none
printf '%s' "$SIG" | dd of=kernel/hal3disk.img bs=1 seek=512 conv=notrunc status=none

echo "OK: kernel/kernel_hal3d_ctrl.elf + kernel/hal3disk.img"
