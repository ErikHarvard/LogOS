#!/usr/bin/env bash
# LogOS kernel HH2 slice — build the per-process-page-tables isolation probe ELF.
#   boot.asm -dHH2: no LA image (incbin skipped for HH2); after long mode it builds
#   the high map (HH1_HIGHMAP), jumps high, then constructs TWO process PML4s that
#   SHARE the kernel PML4[511] but map the same low virtual page (6 MiB) to distinct
#   physical frames (32 MiB / 34 MiB), and switches CR3 between them to prove
#   address-space isolation (a write under one process is invisible to the other).
#   A ring-0 kernel demo — the process-model foundation HH1 unlocked.
# Separate output (kernel_hh2.elf); every other kernel ELF stays byte-identical
# (all HH2 code is %ifdef HH2 / %ifdef HH1_HIGHMAP). No native compile.
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos

echo "[1/2] entry.inc (dummy; HH2 has no LA image, LA_ENTRY is unused)"
printf 'LA_ENTRY equ 0x400000\n' > kernel/entry.inc

echo "[2/2] assemble boot.asm -dHH2, link (elf64), repackage as elf32-i386"
nasm -f elf64 -dHH2 -i kernel/ kernel/boot.asm -o kernel/boot_hh2.o
ld -n -T kernel/kernel.ld kernel/boot_hh2.o -o kernel/kernel_hh2_64.elf
objcopy -O elf32-i386 kernel/kernel_hh2_64.elf kernel/kernel_hh2.elf

echo "OK: kernel/kernel_hh2.elf"
