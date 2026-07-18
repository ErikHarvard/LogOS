#!/usr/bin/env bash
# LogOS HAL.4d — build the bootable INTERACTIVE metal-compositor session.
#   comp_session.la --(native_codegen3)--> native_codegen3_out --> kernel_comp_session.elf
#   boot.asm assembled with -D HAL4 (identity-maps 0..4 GiB): needed for the high
#   VGA LFB BAR and the 256 MiB backbuffer at 0x10000000 (same as HAL.4c). Uses
#   HAL.4b's fill/memcpy ternary builtins + HAL.1 inb/outl/inl/outw + peek, all
#   already regen'd into the compiler. No IRQ/PIC setup — the keyboard is POLLED.
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos

echo "[1/4] compile comp_session.la via native_codegen3"
cp kernel/comp_session.la native_input.la
./tiny_host native_codegen3.la >/dev/null
ENTRY=$(readelf -h native_codegen3_out | awk '/Entry point/{print $NF}')
echo "      e_entry (LA prol) = $ENTRY"

echo "[2/4] generate entry.inc"
printf 'LA_ENTRY equ %s\n' "$ENTRY" > kernel/entry.inc

echo "[3/4] assemble boot.asm (-D HAL4: identity-map 0..4 GiB)"
nasm -f elf64 -D HAL4 -i kernel/ kernel/boot.asm -o kernel/boot.o

echo "[4/4] link -> kernel_comp_session.elf (elf64 -> elf32-i386 container)"
ld -n -T kernel/kernel.ld kernel/boot.o -o kernel/kernel_comp_session_64.elf
objcopy -O elf32-i386 kernel/kernel_comp_session_64.elf kernel/kernel_comp_session.elf

echo "OK: kernel/kernel_comp_session.elf"
