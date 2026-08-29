#!/usr/bin/env bash
# LogOS kernel K4c (first slice) — build the bootable W^X-enforcement ELF.
#   paging_wx_live.la --(native_codegen3, with peek + poke + set_cr3)-->
#     the LA image that BUILDS a 4-level page table in real PMM frames with a
#     READ-ONLY high test page, loads CR3, reads it back, then WRITES it.
#   boot.asm assembled WITH -dK4C_WX (arms EFER.NXE + CR0.WP — the W^X substrate;
#     the guard keeps every other kernel ELF's boot bytes identical) + incbin(image)
#     --> kernel_wx.elf
# Separate output so the K1/K2/K3b/K4b/CR3 ELFs are untouched. Shares
# native_input.la / entry.inc with build.sh — run SEQUENTIALLY, never in parallel
# with a build/gate.
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos

echo "[1/4] compile paging_wx_live.la via native_codegen3 (uses peek + poke + set_cr3)"
cp kernel/paging_wx_live.la native_input.la
( if [ -x native_codegen3_selfhost.bin ]; then cp native_codegen3_selfhost.bin /tmp/_ncc$$ && chmod +x /tmp/_ncc$$ && /tmp/_ncc$$; rc=$?; rm -f /tmp/_ncc$$; exit $rc; else ./tiny_host native_codegen3.la; fi; ) >/dev/null
ENTRY=$(readelf -h native_codegen3_out | awk '/Entry point/{print $NF}')
echo "      e_entry (LA prol) = $ENTRY"

echo "[2/4] generate entry.inc"
printf 'LA_ENTRY equ %s\n' "$ENTRY" > kernel/entry.inc

echo "[3/4] assemble boot.asm WITH -dK4C_WX (arm EFER.NXE + CR0.WP)"
nasm -f elf64 -dK4C_WX -i kernel/ kernel/boot.asm -o kernel/boot_wx.o

echo "[4/4] link -> kernel_wx.elf (elf64), repackage as elf32-i386"
ld -n -T kernel/kernel.ld kernel/boot_wx.o -o kernel/kernel_wx_64.elf
objcopy -O elf32-i386 kernel/kernel_wx_64.elf kernel/kernel_wx.elf

echo "OK: kernel/kernel_wx.elf"
