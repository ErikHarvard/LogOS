#!/usr/bin/env bash
# LogOS HAL.3b — build the bootable ATA-disk-WRITE kernel + a blank data disk.
#   ata3b.la --(native_codegen3)--> native_codegen3_out --> kernel_hal3b.elf
#   + hal3bdisk.img: a zeroed raw disk the LA driver writes a signature into at
#     LBA 2 (the gate then checks the file to prove the write persisted).
# Same pipeline as build_hal3; NO regen (inb/outb/inl/outl already exist).
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos

echo "[1/5] compile ata3b.la via native_codegen3"
cp kernel/ata3b.la native_input.la
( if [ -x native_codegen3_selfhost.bin ]; then cp native_codegen3_selfhost.bin /tmp/_ncc$$ && chmod +x /tmp/_ncc$$ && /tmp/_ncc$$; rc=$?; rm -f /tmp/_ncc$$; exit $rc; else ./tiny_host native_codegen3.la; fi; ) >/dev/null
ENTRY=$(readelf -h native_codegen3_out | awk '/Entry point/{print $NF}')
echo "      e_entry (LA prol) = $ENTRY"

echo "[2/5] generate entry.inc"
printf 'LA_ENTRY equ %s\n' "$ENTRY" > kernel/entry.inc

echo "[3/5] assemble boot.asm (default ring-0 path)"
nasm -f elf64 -i kernel/ kernel/boot.asm -o kernel/boot.o

echo "[4/5] link -> kernel_hal3b.elf (elf64 -> elf32-i386 container)"
ld -n -T kernel/kernel.ld kernel/boot.o -o kernel/kernel_hal3b_64.elf
objcopy -O elf32-i386 kernel/kernel_hal3b_64.elf kernel/kernel_hal3b.elf

echo "[5/5] blank data disk (1 MiB, all zero — the driver writes LBA 2)"
dd if=/dev/zero of=kernel/hal3bdisk.img bs=1M count=1 status=none

echo "OK: kernel/kernel_hal3b.elf + kernel/hal3bdisk.img"
