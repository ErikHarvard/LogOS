#!/usr/bin/env bash
# LogOS kernel K1 — build the bootable multiboot ELF.
#   kernel.la --(native_codegen3)--> native_codegen3_out (LA image, 0x400000)
#   e_entry   --> entry.inc (LA_ENTRY)
#   boot.asm + entry.inc + incbin(image) --(nasm)--> boot.o
#   boot.o    --(ld, kernel.ld)--> kernel.elf   (one multiboot ELF)
# Run from the repo root (~/logos): incbin resolves native_codegen3_out in cwd.
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos

echo "[1/4] compile kernel.la via native_codegen3"
cp kernel/kernel.la native_input.la
( if [ -x native_codegen3_selfhost.bin ]; then cp native_codegen3_selfhost.bin /tmp/_ncc$$ && chmod +x /tmp/_ncc$$ && /tmp/_ncc$$; rc=$?; rm -f /tmp/_ncc$$; exit $rc; else ./tiny_host native_codegen3.la; fi; ) >/dev/null
ENTRY=$(readelf -h native_codegen3_out | awk '/Entry point/{print $NF}')
echo "      e_entry (LA prol) = $ENTRY"

echo "[2/4] generate entry.inc"
printf 'LA_ENTRY equ %s\n' "$ENTRY" > kernel/entry.inc

echo "[3/4] assemble boot.asm"
nasm -f elf64 -i kernel/ kernel/boot.asm -o kernel/boot.o

echo "[4/4] link -> kernel.elf (elf64), repackage container as elf32-i386"
# Link as ELF64 so 64-bit absolute relocations (LSTAR handler, GDT ptr) resolve;
# then rewrite the ELF container to 32-bit — QEMU's -kernel multiboot loader
# rejects an ELFCLASS64 image ("give a 32bit one"). All vaddrs are < 4 GiB, so
# the 32-bit container holds them; the loaded bytes (incl. the 64-bit code) are
# unchanged. The CPU still enters _start in 32-bit mode and trampolines to long.
ld -n -T kernel/kernel.ld kernel/boot.o -o kernel/kernel64.elf
objcopy -O elf32-i386 kernel/kernel64.elf kernel/kernel.elf

echo "OK: kernel/kernel.elf"
