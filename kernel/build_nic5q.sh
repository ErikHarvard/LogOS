#!/usr/bin/env bash
# LogOS HAL.5q — build the bootable self-repairing ICMP responder (Tier-2b) kernel.
#   nic5q.la --(native_codegen3)--> native_codegen3_out --> kernel_nic5q.elf
# Identical pipeline to build_nic5h.sh (default ring-0 boot path); NO regen (the
# port-I/O builtins exist from HAL.1/HAL.4) and NO -D HAL4 (the DMA buffers live
# at 256 MiB, inside the default 0..1 GiB identity map). 5q adds no builtin —
# reading the IHL nibble is mod/mul, plain arithmetic.
#
# ★★ VERIFY-FIRST (isolated session): this kernel's whole point is the repair
# path, which only fires if the injected TE-off fault MANIFESTS in QEMU (TOK
# withheld while TE is off). That is UNVERIFIED. After the first gate run, CHECK
# THE SERIAL: it MUST show "nic tx wedged" then "nic tx recovered". If it shows
# "nic tx ok" instead, QEMU ignored TE, the fault did not manifest, the repair
# branch is DEAD CODE, and a GREEN gate proves NOTHING. Redesign the fault
# (mis-set CAPR to wedge RX, or a zero TSAD pointer) before trusting any green.
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos-d

echo "[1/4] compile nic5q.la via native_codegen3"
cp kernel/nic5q.la native_input.la
./tiny_host native_codegen3.la >/dev/null
ENTRY=$(readelf -h native_codegen3_out | awk '/Entry point/{print $NF}')
echo "      e_entry (LA prol) = $ENTRY"

echo "[2/4] generate entry.inc"
printf 'LA_ENTRY equ %s\n' "$ENTRY" > kernel/entry.inc

echo "[3/4] assemble boot.asm (default ring-0 path)"
nasm -f elf64 -i kernel/ kernel/boot.asm -o kernel/boot.o

echo "[4/4] link -> kernel_nic5q.elf (elf64 -> elf32-i386 container)"
ld -n -T kernel/kernel.ld kernel/boot.o -o kernel/kernel_nic5q_64.elf
objcopy -O elf32-i386 kernel/kernel_nic5q_64.elf kernel/kernel_nic5q.elf

echo "OK: kernel/kernel_nic5q.elf"
