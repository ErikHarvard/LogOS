#!/usr/bin/env bash
# LogOS HAL.4b — build the bootable bulk-framebuffer kernel.
#   fb4b.la --(native_codegen3)--> native_codegen3_out --> kernel_hal4b.elf
#   boot.asm assembled with -D HAL4 (identity-maps 0..4 GiB so the high VGA LFB
#   BAR is reachable) — the same map HAL.4 needs; fb4b.la additionally uses the
#   fill/memcpy ternary builtins (regen'd into the compiler) to paint the whole
#   screen and blit a RAM backbuffer, instead of HAL.4's poke-per-byte.
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos

echo "[1/4] compile fb4b.la via native_codegen3"
cp kernel/fb4b.la native_input.la
./tiny_host native_codegen3.la >/dev/null
ENTRY=$(readelf -h native_codegen3_out | awk '/Entry point/{print $NF}')
echo "      e_entry (LA prol) = $ENTRY"

echo "[2/4] generate entry.inc"
printf 'LA_ENTRY equ %s\n' "$ENTRY" > kernel/entry.inc

echo "[3/4] assemble boot.asm (-D HAL4: identity-map 0..4 GiB)"
nasm -f elf64 -D HAL4 -i kernel/ kernel/boot.asm -o kernel/boot.o

echo "[4/4] link -> kernel_hal4b.elf (elf64 -> elf32-i386 container)"
ld -n -T kernel/kernel.ld kernel/boot.o -o kernel/kernel_hal4b_64.elf
objcopy -O elf32-i386 kernel/kernel_hal4b_64.elf kernel/kernel_hal4b.elf

echo "OK: kernel/kernel_hal4b.elf"
