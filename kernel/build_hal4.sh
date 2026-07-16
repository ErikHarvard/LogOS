#!/usr/bin/env bash
# LogOS HAL.4 — build the bootable linear-framebuffer display kernel.
#   fb.la --(native_codegen3)--> native_codegen3_out --> kernel_hal4.elf
#   boot.asm assembled with -D HAL4 (identity-maps 0..4 GiB so the high VGA LFB
#   BAR is reachable by poke). Needs the outw/inw builtins (regen'd into the
#   compiler); the ring-0 LA image drives the VBE registers + the framebuffer.
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos

echo "[1/4] compile fb.la via native_codegen3"
cp kernel/fb.la native_input.la
./tiny_host native_codegen3.la >/dev/null
ENTRY=$(readelf -h native_codegen3_out | awk '/Entry point/{print $NF}')
echo "      e_entry (LA prol) = $ENTRY"

echo "[2/4] generate entry.inc"
printf 'LA_ENTRY equ %s\n' "$ENTRY" > kernel/entry.inc

echo "[3/4] assemble boot.asm (-D HAL4: identity-map 0..4 GiB)"
nasm -f elf64 -D HAL4 -i kernel/ kernel/boot.asm -o kernel/boot.o

echo "[4/4] link -> kernel_hal4.elf (elf64 -> elf32-i386 container)"
ld -n -T kernel/kernel.ld kernel/boot.o -o kernel/kernel_hal4_64.elf
objcopy -O elf32-i386 kernel/kernel_hal4_64.elf kernel/kernel_hal4.elf

echo "OK: kernel/kernel_hal4.elf"
