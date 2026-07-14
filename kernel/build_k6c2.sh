#!/usr/bin/env bash
# LogOS kernel K6c.2 slice — build the two-ring-3-task IPC probe ELF.
#   boot.asm assembled -dK6C2: no LA image (incbin skipped for K6C2), no timer;
#   after the usual long-mode/syscall setup it maps a U=1 page at 256 MiB, copies
#   TWO position-independent ring-3 payloads there (task A @0x10000000, task B
#   @0x10010000), seeds a 128-byte PCB per task (entry rip / rflags / stack top),
#   and launches task A via k6c2_run (sysret). A cooperative `yield` syscall drives
#   a real kernel context switch between the two: A send + yield -> B recv + reply
#   + yield -> A recv. Proves two ring-3 tasks exchange a typed message through
#   kernel channels with the kernel saving/restoring each task's full context.
# Separate output (kernel_k6c2.elf); every other kernel ELF stays byte-identical
# (all K6c2 code is %ifdef K6C2 / %ifdef IPC / %ifdef RING3). No native compile.
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos

echo "[1/2] entry.inc (dummy; the K6c2 build has no LA image, LA_ENTRY is unused)"
printf 'LA_ENTRY equ 0x400000\n' > kernel/entry.inc

echo "[2/2] assemble boot.asm -dK6C2, link (elf64), repackage as elf32-i386"
nasm -f elf64 -dK6C2 -i kernel/ kernel/boot.asm -o kernel/boot_k6c2.o
ld -n -T kernel/kernel.ld kernel/boot_k6c2.o -o kernel/kernel_k6c2_64.elf
objcopy -O elf32-i386 kernel/kernel_k6c2_64.elf kernel/kernel_k6c2.elf

echo "OK: kernel/kernel_k6c2.elf"
