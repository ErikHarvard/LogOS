#!/usr/bin/env bash
# LogOS HAL.5r RED-PATH CONTROL — build the no-repair control kernel.
#   nic5r_ctrl.la --(native_codegen3)--> native_codegen3_out --> kernel_nic5r_ctrl.elf
#
# nic5r_ctrl.la is nic5r.la with the RX REPAIR REMOVED: on the (bounded) WAITRX
# timeout it DIAGNOSES ("nic rx wedged cr=XX") and STOPS — no RE re-enable, no
# retry. RE therefore stays off, no frame is ever received, and the pinger gets
# NO reply. gate_nic5r.sh's red-path block boots this and asserts the pinger
# FAILS (rc != 0), proving 5r's gate can fail (the repair is load-bearing).
#
# Compiler choice: same as build_nic5r.sh — tiny_host by default (authoritative,
# ~51 min); the byte-verified native_codegen3_selfhost.bin (~2s) is the fast
# alternative (regen after any native_codegen3.la change).
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos-d

echo "[1/4] compile nic5r_ctrl.la via native_codegen3"
cp kernel/nic5r_ctrl.la native_input.la
./tiny_host native_codegen3.la >/dev/null
ENTRY=$(readelf -h native_codegen3_out | awk '/Entry point/{print $NF}')
echo "      e_entry (LA prol) = $ENTRY"

echo "[2/4] generate entry.inc"
printf 'LA_ENTRY equ %s\n' "$ENTRY" > kernel/entry.inc

echo "[3/4] assemble boot.asm (default ring-0 path)"
nasm -f elf64 -i kernel/ kernel/boot.asm -o kernel/boot.o

echo "[4/4] link -> kernel_nic5r_ctrl.elf (elf64 -> elf32-i386 container)"
ld -n -T kernel/kernel.ld kernel/boot.o -o kernel/kernel_nic5r_ctrl_64.elf
objcopy -O elf32-i386 kernel/kernel_nic5r_ctrl_64.elf kernel/kernel_nic5r_ctrl.elf

echo "OK: kernel/kernel_nic5r_ctrl.elf"
