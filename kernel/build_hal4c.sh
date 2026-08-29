#!/usr/bin/env bash
# LogOS HAL.4c — build the bootable metal-compositor kernel.
#   comp.la --(native_codegen3)--> native_codegen3_out --> kernel_hal4c.elf
#   boot.asm assembled with -D HAL4 (identity-maps 0..4 GiB): needed both for the
#   high VGA LFB BAR and for the 256 MiB backbuffer at 0x10000000. Uses HAL.4b's
#   fill/memcpy ternary builtins (regen'd into the compiler).
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos

echo "[1/4] compile comp.la via native_codegen3"
cp kernel/comp.la native_input.la
( if [ -x native_codegen3_selfhost.bin ]; then cp native_codegen3_selfhost.bin /tmp/_ncc$$ && chmod +x /tmp/_ncc$$ && /tmp/_ncc$$; rc=$?; rm -f /tmp/_ncc$$; exit $rc; else ./tiny_host native_codegen3.la; fi; ) >/dev/null
ENTRY=$(readelf -h native_codegen3_out | awk '/Entry point/{print $NF}')
echo "      e_entry (LA prol) = $ENTRY"

echo "[2/4] generate entry.inc"
printf 'LA_ENTRY equ %s\n' "$ENTRY" > kernel/entry.inc

echo "[3/4] assemble boot.asm (-D HAL4: identity-map 0..4 GiB)"
nasm -f elf64 -D HAL4 -i kernel/ kernel/boot.asm -o kernel/boot.o

echo "[4/4] link -> kernel_hal4c.elf (elf64 -> elf32-i386 container)"
ld -n -T kernel/kernel.ld kernel/boot.o -o kernel/kernel_hal4c_64.elf
objcopy -O elf32-i386 kernel/kernel_hal4c_64.elf kernel/kernel_hal4c.elf

echo "OK: kernel/kernel_hal4c.elf"
