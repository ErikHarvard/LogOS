#!/usr/bin/env bash
# LogOS kernel K4b capstone — build the bootable CR3-switch ELF.
#   paging_cr3.la --(native_codegen3, with peek + poke + the new set_cr3 builtin)-->
#     the LA image that BUILDS a 4-level page table in real PMM frames and loads CR3.
#   boot.asm (UNCHANGED: MB_FLAGS|=0x2, threads EBX->MBI_SAVE, tall stack,
#     identity-maps low 1 GiB as writable 2 MiB pages) + incbin(image)
#     --> kernel_paging_cr3.elf
# Separate output so the K1/K2/K3b/K4b ELFs are untouched. Shares native_input.la /
# entry.inc with build.sh — run SEQUENTIALLY, never in parallel with a build/gate.
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos

echo "[1/4] compile paging_cr3.la via native_codegen3 (uses peek + poke + set_cr3)"
cp kernel/paging_cr3.la native_input.la
( if [ -x native_codegen3_selfhost.bin ]; then cp native_codegen3_selfhost.bin /tmp/_ncc$$ && chmod +x /tmp/_ncc$$ && /tmp/_ncc$$; rc=$?; rm -f /tmp/_ncc$$; exit $rc; else ./tiny_host native_codegen3.la; fi; ) >/dev/null
ENTRY=$(readelf -h native_codegen3_out | awk '/Entry point/{print $NF}')
echo "      e_entry (LA prol) = $ENTRY"

echo "[2/4] generate entry.inc"
printf 'LA_ENTRY equ %s\n' "$ENTRY" > kernel/entry.inc

echo "[3/4] assemble boot.asm"
nasm -f elf64 -i kernel/ kernel/boot.asm -o kernel/boot_paging_cr3.o

echo "[4/4] link -> kernel_paging_cr3.elf (elf64), repackage as elf32-i386"
ld -n -T kernel/kernel.ld kernel/boot_paging_cr3.o -o kernel/kernel_paging_cr3_64.elf
objcopy -O elf32-i386 kernel/kernel_paging_cr3_64.elf kernel/kernel_paging_cr3.elf

echo "OK: kernel/kernel_paging_cr3.elf"
