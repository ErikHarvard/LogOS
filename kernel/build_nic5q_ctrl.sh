#!/usr/bin/env bash
# LogOS HAL.5q RED-PATH CONTROL — build the no-repair control kernel.
#   nic5q_ctrl.la --(native_codegen3)--> native_codegen3_out --> kernel_nic5q_ctrl.elf
#
# nic5q_ctrl.la is nic5q.la with the REPAIR BRANCH REMOVED: on a TX timeout it
# DIAGNOSES ("nic tx wedged") and STOPS — no TE re-enable, no retry. The injected
# TE-off fault therefore never clears, the transmit never completes, and the
# pinger gets NO reply. gate_nic5q.sh's red-path block boots this and asserts the
# pinger FAILS (rc != 0) — proving 5q's gate can fail, i.e. that the repair path
# is load-bearing and 5q's green is not vacuous.
#
# NOTE (verified 2026-08-03): the control still prints "nic icmp reply sent"
# unconditionally (that line sits OUTSIDE the transmit branch), so the red-path
# relies on the PINGER getting no echo, NEVER on this serial line. gate_nic5q.sh
# already keys the red-path on the pinger rc, which is correct.
#
# ── COMPILER CHOICE (default: tiny_host, matching build_nic5q.sh) ─────────────
# This uses ./tiny_host native_codegen3.la for byte-exact parity with the sibling
# build_nic5q.sh and the whole 5x arc (the authoritative path — interprets the
# source, so it can never ship a stale native image). COST: ~51 min on this
# kernel, because RESPOND is a deeply-nested SEQ tower and tiny_host is
# super-linear in nesting depth (HAL.5c noted ~12 min; 5q is ~4x that).
#
# The native image native_codegen3_selfhost.bin compiles this in ~2s and was
# proven BYTE-IDENTICAL to the tiny_host output on the main 5q kernel (full ELF
# cmp, 2026-08-03). To use it, swap the compile line below for:
#     ./native_codegen3_selfhost.bin >/dev/null
# — but heed logos-la-driver-build-workflow: a stale selfhost image silently
# emits wrong bytes, so regen it (bash regen_selfhost.sh) after ANY change to
# native_codegen3.la / *_rt.asm before trusting it in a gate.
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos-d

echo "[1/4] compile nic5q_ctrl.la via native_codegen3"
cp kernel/nic5q_ctrl.la native_input.la
./tiny_host native_codegen3.la >/dev/null
ENTRY=$(readelf -h native_codegen3_out | awk '/Entry point/{print $NF}')
echo "      e_entry (LA prol) = $ENTRY"

echo "[2/4] generate entry.inc"
printf 'LA_ENTRY equ %s\n' "$ENTRY" > kernel/entry.inc

echo "[3/4] assemble boot.asm (default ring-0 path)"
nasm -f elf64 -i kernel/ kernel/boot.asm -o kernel/boot.o

echo "[4/4] link -> kernel_nic5q_ctrl.elf (elf64 -> elf32-i386 container)"
ld -n -T kernel/kernel.ld kernel/boot.o -o kernel/kernel_nic5q_ctrl_64.elf
objcopy -O elf32-i386 kernel/kernel_nic5q_ctrl_64.elf kernel/kernel_nic5q_ctrl.elf

echo "OK: kernel/kernel_nic5q_ctrl.elf"
