#!/usr/bin/env bash
# LogOS kernel K4c slice — build the bootable LA-HEAP-ON-PMM ELF.
#   paging_heap.la --(native_codegen3, with peek + poke + set_cr3)-->
#     the LA image that builds a 4-level table (identity low 1 GiB + a 4 KiB-
#     granular heap window over real PMM frames), loads CR3, and writes/reads
#     heap memory through the high vaddrs.
#   boot.asm (UNCHANGED — no WP/NXE needed for this slice; plain translation +
#     read/write, like the K4b-cr3 capstone) + incbin(image) --> kernel_paging_heap.elf
# Separate output so the K1/K2/K3b/K4b/K4c-wx/K4c-nx ELFs are untouched. Shares
# native_input.la / entry.inc with build.sh — run SEQUENTIALLY, never in parallel.
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos

echo "[1/4] compile paging_heap.la via native_codegen3 (uses peek + poke + set_cr3)"
cp kernel/paging_heap.la native_input.la
( if [ -x native_codegen3_selfhost.bin ]; then cp native_codegen3_selfhost.bin /tmp/_ncc$$ && chmod +x /tmp/_ncc$$ && /tmp/_ncc$$; rc=$?; rm -f /tmp/_ncc$$; exit $rc; else ./tiny_host native_codegen3.la; fi; ) >/dev/null
ENTRY=$(readelf -h native_codegen3_out | awk '/Entry point/{print $NF}')
echo "      e_entry (LA prol) = $ENTRY"

echo "[2/4] generate entry.inc"
printf 'LA_ENTRY equ %s\n' "$ENTRY" > kernel/entry.inc

echo "[3/4] assemble boot.asm (UNCHANGED bytes — no -d flags)"
nasm -f elf64 -i kernel/ kernel/boot.asm -o kernel/boot_paging_heap.o

echo "[4/4] link -> kernel_paging_heap.elf (elf64), repackage as elf32-i386"
ld -n -T kernel/kernel.ld kernel/boot_paging_heap.o -o kernel/kernel_paging_heap_64.elf
objcopy -O elf32-i386 kernel/kernel_paging_heap_64.elf kernel/kernel_paging_heap.elf

echo "OK: kernel/kernel_paging_heap.elf"
