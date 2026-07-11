#!/usr/bin/env bash
# LogOS kernel K6a slice — build the ring-3 user-mode probe ELF.
#   boot.asm assembled -dK6A: no LA image (incbin is %ifndef K6A), no timer; after
#   the usual long-mode/syscall setup it adds ring-3 GDT selectors + a TSS, maps a
#   U=1 page at 256 MiB, copies a tiny payload there, and iretq's to ring 3. The
#   payload syscalls write()+exit() back into the kernel (sysret return path).
# Separate output (kernel_k6a.elf); every other kernel ELF stays byte-identical
# (all K6a code is %ifdef K6A). No native_codegen3 compile -> fast.
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos

echo "[1/2] entry.inc (dummy; the K6a build has no LA image, LA_ENTRY is unused)"
printf 'LA_ENTRY equ 0x400000\n' > kernel/entry.inc

echo "[2/2] assemble boot.asm -dK6A, link (elf64), repackage as elf32-i386"
nasm -f elf64 -dK6A -i kernel/ kernel/boot.asm -o kernel/boot_k6a.o
ld -n -T kernel/kernel.ld kernel/boot_k6a.o -o kernel/kernel_k6a_64.elf
objcopy -O elf32-i386 kernel/kernel_k6a_64.elf kernel/kernel_k6a.elf

echo "OK: kernel/kernel_k6a.elf"
