#!/usr/bin/env bash
# LogOS kernel K6c slice (K6c.1) — build the ring-3 IPC probe ELF.
#   boot.asm assembled -dK6C: no LA image (incbin is skipped for K6C), no timer;
#   after the usual long-mode/syscall setup it adds the ring-3 GDT selectors + TSS
#   (shared RING3 machinery), maps a U=1 page at 256 MiB, copies a payload there,
#   and iretq's to ring 3. The payload uses the NEW send/recv syscalls to deposit
#   a typed message into a kernel channel and withdraw it, then write()s the
#   recovered message and exit()s — proving the kernel services IPC across the
#   privilege boundary (send/recv cross ring3->ring0(channel)->ring3).
# Separate output (kernel_k6c.elf); every other kernel ELF stays byte-identical
# (all K6c code is %ifdef K6C). No native_codegen3 compile -> fast, like K6a.
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos

echo "[1/2] entry.inc (dummy; the K6c build has no LA image, LA_ENTRY is unused)"
printf 'LA_ENTRY equ 0x400000\n' > kernel/entry.inc

echo "[2/2] assemble boot.asm -dK6C, link (elf64), repackage as elf32-i386"
nasm -f elf64 -dK6C -i kernel/ kernel/boot.asm -o kernel/boot_k6c.o
ld -n -T kernel/kernel.ld kernel/boot_k6c.o -o kernel/kernel_k6c_64.elf
objcopy -O elf32-i386 kernel/kernel_k6c_64.elf kernel/kernel_k6c.elf

echo "OK: kernel/kernel_k6c.elf"
