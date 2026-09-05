#!/usr/bin/env bash
# LogOS kernel K4b — build the bootable paging-on-metal ELF.
#   paging_metal.la --(native_codegen3, with peek + the new poke builtin)-->
#     the LA image that allocates a real PMM frame and BUILDS a PTE in it.
#   boot.asm (UNCHANGED from K3b: MB_FLAGS|=0x2, threads EBX->MBI_SAVE, tall
#     stack, identity-maps low 1 GiB as writable 2 MiB pages) + incbin(image)
#     --> kernel_paging.elf
# Separate output (kernel_paging.elf) so the K1/K2/K3b ELFs are untouched.
# Shares native_input.la / native_codegen3_out / entry.inc with build.sh —
# run SEQUENTIALLY (never in parallel with a build or another kernel gate).
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos

echo "[1/4] compile paging_metal.la via native_codegen3 (uses peek + poke)"
cp kernel/paging_metal.la native_input.la
( if [ -x native_codegen3_selfhost.bin ]; then cp native_codegen3_selfhost.bin /tmp/_ncc$$ && chmod +x /tmp/_ncc$$ && /tmp/_ncc$$; rc=$?; rm -f /tmp/_ncc$$; exit $rc; else ./tiny_host native_codegen3.la; fi; ) >/dev/null
ENTRY=$(readelf -h native_codegen3_out | awk '/Entry point/{print $NF}')
echo "      e_entry (LA prol) = $ENTRY"

echo "[2/4] generate entry.inc"
printf 'LA_ENTRY equ %s\n' "$ENTRY" > kernel/entry.inc

echo "[3/4] assemble boot.asm"
nasm -f elf64 -i kernel/ kernel/boot.asm -o kernel/boot_paging.o

echo "[4/4] link -> kernel_paging.elf (elf64), repackage as elf32-i386"
ld -n -T kernel/kernel.ld kernel/boot_paging.o -o kernel/kernel_paging64.elf
objcopy -O elf32-i386 kernel/kernel_paging64.elf kernel/kernel_paging.elf

echo "OK: kernel/kernel_paging.elf"
