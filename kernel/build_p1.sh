#!/usr/bin/env bash
# LogOS P1 — build the kernel-process-table probe ELF (LogosInit brick 1 of 7).
#
#   boot.asm -dP1: no LA image. After long mode it builds the high map
#   (HH1_HIGHMAP), jumps high, then constructs a real PCB ARRAY — pid, CR3,
#   state, entry — and a scheduler that enters each runnable process at ring 3
#   in turn. THREE processes, each with its own PML4 sharing the kernel [511],
#   each mapping the SAME low virtual page to a DIFFERENT physical frame
#   carrying a distinct value (A1/B2/C3). Each process prints its own pid and
#   the value it reads there, then exits; the scheduler advances.
#
#   Three, not two, is the point: HH2c boots two isolated processes with a
#   hardcoded `hh2c_stage` byte, and a two-process probe cannot distinguish a
#   table from an if-statement. See kernel/gate_p1.sh.
#
#   --shared : THE RED CONTROL. Points all three PCBs at ONE PML4, so the three
#              processes share an address space and read the same value at that
#              VA. gate_p1.sh --red REQUIRES this variant to fail the isolation
#              assertions; if it passes, the assertion was measuring nothing.
#
# Separate output (kernel_p1.elf); every other kernel ELF stays byte-identical
# (all P1 code is %ifdef P1). No native compile — pure asm, so no tiny_host.
#
# ⚠ SHARES kernel/entry.inc WITH build.sh AND build_hal4g.sh — run SEQUENTIALLY,
#   never while another kernel build is in flight, or one run's entry.inc lands
#   in the other's ELF.
set -euo pipefail
cd "$(dirname "$0")/.."

SHARED=""
[ "${1:-}" = "--shared" ] && SHARED="-dP1_SHARED"

echo "[1/2] entry.inc (dummy; P1 has no LA image, LA_ENTRY is unused)"
printf 'LA_ENTRY equ 0x400000\n' > kernel/entry.inc

echo "[2/2] assemble boot.asm -dP1 $SHARED, link (elf64), repackage as elf32-i386"
nasm -f elf64 -dP1 $SHARED -i kernel/ kernel/boot.asm -o kernel/boot_p1.o
ld -n -T kernel/kernel.ld kernel/boot_p1.o -o kernel/kernel_p1_64.elf
objcopy -O elf32-i386 kernel/kernel_p1_64.elf kernel/kernel_p1.elf

echo "OK: kernel/kernel_p1.elf${SHARED:+ (RED CONTROL: one shared PML4)}"
