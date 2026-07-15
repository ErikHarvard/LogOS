#!/usr/bin/env bash
# LogOS kernel HH1a slice — build the higher-half boot probe ELF.
#   kernel.la --(native_codegen3)--> the LA image @0x400000 (LOW, unchanged),
#     incbin'd exactly as K1/K6b do.
#   boot.asm -dHH1: the 32-bit trampoline builds, alongside the low identity map,
#     a HIGH map (PML4[511] -> pdpt_high[510] -> the low-1-GiB pd) aliasing every
#     low physical page at 0xFFFFFFFF80000000+P. After long mode it jumps to the
#     HIGH alias of hh_high, prints "HH1@<top-nibble-of-RIP>" (F proves it runs in
#     the −2 GiB half), then hands off to the still-low LA image, which speaks the
#     Word (the low identity map is kept for HH1a). No METAL_FLAG needed (the LA
#     image runs at ring 0 low, taking rt_init's metal path via CPL==0, like K1).
# Separate output (kernel_hh1.elf); every other kernel ELF stays byte-identical
# (all HH1 code is %ifdef HH1). Shares native_input.la / entry.inc with build.sh —
# run SEQUENTIALLY.
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos

echo "[1/4] compile kernel.la via native_codegen3 (the LA image that speaks the Word)"
cp kernel/kernel.la native_input.la
./tiny_host native_codegen3.la >/dev/null
ENTRY=$(readelf -h native_codegen3_out | awk '/Entry point/{print $NF}')
echo "      e_entry (LA prol) = $ENTRY"

echo "[2/4] entry.inc (LA_ENTRY only; HH1a references no METAL_FLAG)"
printf 'LA_ENTRY equ %s\n' "$ENTRY" > kernel/entry.inc

echo "[3/4] assemble boot.asm -dHH1, link (elf64)"
nasm -f elf64 -dHH1 -i kernel/ kernel/boot.asm -o kernel/boot_hh1.o
ld -n -T kernel/kernel.ld kernel/boot_hh1.o -o kernel/kernel_hh1_64.elf

echo "[4/4] repackage as elf32-i386 (multiboot1)"
objcopy -O elf32-i386 kernel/kernel_hh1_64.elf kernel/kernel_hh1.elf

echo "OK: kernel/kernel_hh1.elf"
