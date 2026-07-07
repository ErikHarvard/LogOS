#!/usr/bin/env bash
# LogOS kernel K3b — build the bootable PMM-on-metal ELF.
#   pmm_metal.la --(native_codegen3, with the new peek builtin)--> the LA image
#   boot.asm (MB_FLAGS|=0x2, threads EBX->MBI_SAVE) + incbin(image) --> kernel_pmm.elf
# Separate output (kernel_pmm.elf) so the K1/K2 kernel.elf is untouched.
# Shares native_input.la / native_codegen3_out / entry.inc with build.sh —
# run SEQUENTIALLY (never in parallel with a build or the K3a gate).
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos

echo "[1/4] compile pmm_metal.la via native_codegen3 (uses peek)"
cp kernel/pmm_metal.la native_input.la
./tiny_host native_codegen3.la >/dev/null
ENTRY=$(readelf -h native_codegen3_out | awk '/Entry point/{print $NF}')
echo "      e_entry (LA prol) = $ENTRY"

echo "[2/4] generate entry.inc"
printf 'LA_ENTRY equ %s\n' "$ENTRY" > kernel/entry.inc

echo "[3/4] assemble boot.asm"
nasm -f elf64 -i kernel/ kernel/boot.asm -o kernel/boot_pmm.o

echo "[4/4] link -> kernel_pmm.elf (elf64), repackage as elf32-i386"
ld -n -T kernel/kernel.ld kernel/boot_pmm.o -o kernel/kernel_pmm64.elf
objcopy -O elf32-i386 kernel/kernel_pmm64.elf kernel/kernel_pmm.elf

echo "OK: kernel/kernel_pmm.elf"
