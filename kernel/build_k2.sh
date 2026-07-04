#!/usr/bin/env bash
# LogOS kernel K2 — build the normal kernel (K1 regression) AND a fault-
# injection variant. `nasm -dK2_FAULT` makes boot.asm execute `ud2` (#UD,
# vector 6) right after idt_install, before the LA jump — so the IDT is
# exercised. Run from the repo root.
set -euo pipefail
cd "$(dirname "$0")/.."

# Normal kernel (also produces native_codegen3_out + entry.inc via build_k1):
./kernel/build_k1.sh >/dev/null
echo "OK: kernel/kernel.elf (normal)"

# Fault variant: same layout, K2_FAULT flips in the `ud2`.
nasm -f elf64 -dK2_FAULT -i kernel/ kernel/boot.asm -o kernel/boot_fault.o
ld -n -T kernel/kernel.ld kernel/boot_fault.o -o kernel/kernel_fault64.elf
objcopy -O elf32-i386 kernel/kernel_fault64.elf kernel/kernel_fault.elf
echo "OK: kernel/kernel_fault.elf (ud2 -> #UD)"
