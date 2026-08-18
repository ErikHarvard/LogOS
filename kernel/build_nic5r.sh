#!/usr/bin/env bash
# LogOS HAL.5r — build the bootable SELF-REPAIRING (RX-side) ICMP responder.
#   nic5r.la --(native_codegen3)--> native_codegen3_out --> kernel_nic5r.elf
#
# 5r is the RX twin of 5q: TX is clean (TE on), RX is deliberately faulted
# (SETUP's first pass leaves RE off, CR:=4). WAITRX is BOUNDED (RXFUEL=200000):
# this fixes a REAL latent bug — every prior 5x kernel used WAITRX fuel 20000000,
# which on a genuinely stuck RX recurses ~20M deep and OVERFLOWS THE STACK
# (deterministic EXCEPTION 0e) before the fuel bound can fire. Bounded, the wait
# times out cleanly; SCAN then SENSES CR, DIAGNOSES ("nic rx wedged cr=XX"),
# re-enables RE (CR:=TE|RE), and RETRIES the receive — a later frame is caught
# and "nic rx recovered" prints before the reply goes out.
#
# ── COMPILER CHOICE (default: tiny_host, matching build_nic5q.sh) ─────────────
# Uses ./tiny_host native_codegen3.la for parity with the 5x arc (authoritative;
# never ships a stale native image). COST ~51 min — RESPOND is a deep SEQ tower
# and tiny_host is super-linear in nesting depth. native_codegen3_selfhost.bin
# compiles it in ~2s and was proven byte-identical on the 5q kernel; to use it
# swap the compile line for `./native_codegen3_selfhost.bin >/dev/null` (regen
# the selfhost image after any native_codegen3.la change — see
# logos-la-driver-build-workflow).
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos-d

echo "[1/4] compile nic5r.la via native_codegen3"
cp kernel/nic5r.la native_input.la
./tiny_host native_codegen3.la >/dev/null
ENTRY=$(readelf -h native_codegen3_out | awk '/Entry point/{print $NF}')
echo "      e_entry (LA prol) = $ENTRY"

echo "[2/4] generate entry.inc"
printf 'LA_ENTRY equ %s\n' "$ENTRY" > kernel/entry.inc

echo "[3/4] assemble boot.asm (default ring-0 path)"
nasm -f elf64 -i kernel/ kernel/boot.asm -o kernel/boot.o

echo "[4/4] link -> kernel_nic5r.elf (elf64 -> elf32-i386 container)"
ld -n -T kernel/kernel.ld kernel/boot.o -o kernel/kernel_nic5r_64.elf
objcopy -O elf32-i386 kernel/kernel_nic5r_64.elf kernel/kernel_nic5r.elf

echo "OK: kernel/kernel_nic5r.elf"
