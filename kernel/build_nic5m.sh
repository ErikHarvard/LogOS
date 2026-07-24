#!/usr/bin/env bash
# LogOS HAL.5m — build the bootable frame-classifying ICMP responder with RX-ring advance kernel.
#   nic5m.la --(native_codegen3)--> native_codegen3_out --> kernel_nic5m.elf
# Identical pipeline to build_nic5h.sh (default ring-0 boot path); NO regen (the
# port-I/O builtins exist from HAL.1/HAL.4) and NO -D HAL4 (the DMA buffers live
# at 256 MiB, inside the default 0..1 GiB identity map). 5m adds no builtin —
# reading the IHL nibble is mod/mul, plain arithmetic.
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos-d

echo "[1/4] compile nic5m.la via native_codegen3"
cp kernel/nic5m.la native_input.la
./tiny_host native_codegen3.la >/dev/null
ENTRY=$(readelf -h native_codegen3_out | awk '/Entry point/{print $NF}')
echo "      e_entry (LA prol) = $ENTRY"

echo "[2/4] generate entry.inc"
printf 'LA_ENTRY equ %s\n' "$ENTRY" > kernel/entry.inc

echo "[3/4] assemble boot.asm (default ring-0 path)"
nasm -f elf64 -i kernel/ kernel/boot.asm -o kernel/boot.o

echo "[4/4] link -> kernel_nic5m.elf (elf64 -> elf32-i386 container)"
ld -n -T kernel/kernel.ld kernel/boot.o -o kernel/kernel_nic5m_64.elf
objcopy -O elf32-i386 kernel/kernel_nic5m_64.elf kernel/kernel_nic5m.elf

echo "OK: kernel/kernel_nic5m.elf"
