#!/usr/bin/env bash
# LogOS HAL.4h — build the bootable mouse-cursor-sprite kernel.
#   cursor.la --(native_codegen3)--> native_codegen3_out (LA image @0x400000)
#   e_entry --> entry.inc ; boot.asm assembled -D HAL4 (identity-maps 0..4 GiB
#   so the high VGA LFB is reachable) + incbin --> kernel_cursor_faulted.elf
# Uses BOTH the framebuffer (HAL.4) and the PS/2 mouse (HAL.2c) on one image.
# inb/outb/inl/outl/inw/outw + peek/poke all exist (HAL.1/HAL.4), so NO regen.
# NOTE: native_codegen3 is slow on this fused program (~11 min) — the gate's
# rebuild is correspondingly long.
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos-d

echo "[1/4] compile cursor.la via native_codegen3 (slow — fused fb+mouse program)"
cp kernel/cursor_faulted.la native_input.la
./tiny_host native_codegen3.la >/dev/null
ENTRY=$(readelf -h native_codegen3_out | awk '/Entry point/{print $NF}')
echo "      e_entry (LA prol) = $ENTRY"

echo "[2/4] generate entry.inc"
printf 'LA_ENTRY equ %s\n' "$ENTRY" > kernel/entry.inc

echo "[3/4] assemble boot.asm (-D HAL4: identity-map 0..4 GiB for the LFB)"
nasm -f elf64 -D HAL4 -i kernel/ kernel/boot.asm -o kernel/boot.o

echo "[4/4] link -> kernel_cursor_faulted.elf (elf64 -> elf32-i386 container)"
ld -n -T kernel/kernel.ld kernel/boot.o -o kernel/kernel_cursor_faulted_64.elf
objcopy -O elf32-i386 kernel/kernel_cursor_faulted_64.elf kernel/kernel_cursor_faulted.elf

echo "OK: kernel/kernel_cursor_faulted.elf"
