#!/usr/bin/env bash
# LogOS HAL.4e — build the bootable TERMINAL WINDOW in the compositor.
#   comp_term.la --(native_codegen3)--> native_codegen3_out --> kernel_comp_term.elf
# boot.asm with -D HAL4 (identity-maps 0..4 GiB) for the high VGA LFB BAR and the
# 256 MiB backbuffer at 0x10000000, exactly as HAL.4c/4d. Keyboard is POLLED, so no
# IRQ/PIC setup is added to the straight-line boot.
#
# Compiles with the SELF-HOSTED image when present (seconds) and falls back to
# tiny_host (minutes) otherwise. The two must produce the same bytes; the Stage-4
# gate in build.sh is what asserts that, not this script.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "[1/4] compile comp_term.la"
cp kernel/comp_term.la native_input.la
rm -f native_codegen3_out
if [ -x native_codegen3_selfhost.bin ]; then
    cp native_codegen3_selfhost.bin /tmp/ct_cc; chmod +x /tmp/ct_cc
    /tmp/ct_cc >/dev/null; rm -f /tmp/ct_cc
else
    ./tiny_host native_codegen3.la >/dev/null
fi
[ -s native_codegen3_out ] || { echo "FAIL: no native_codegen3_out"; exit 1; }
ENTRY=$(readelf -h native_codegen3_out | awk '/Entry point/{print $NF}')
echo "      e_entry (LA prol) = $ENTRY"

echo "[2/4] generate entry.inc"
printf 'LA_ENTRY equ %s\n' "$ENTRY" > kernel/entry.inc

echo "[3/4] assemble boot.asm (-D HAL4)"
nasm -f elf64 -D HAL4 -i kernel/ kernel/boot.asm -o kernel/boot.o

echo "[4/4] link -> kernel_comp_term.elf"
ld -n -T kernel/kernel.ld kernel/boot.o -o kernel/kernel_comp_term_64.elf
objcopy -O elf32-i386 kernel/kernel_comp_term_64.elf kernel/kernel_comp_term.elf

echo "OK: kernel/kernel_comp_term.elf"
