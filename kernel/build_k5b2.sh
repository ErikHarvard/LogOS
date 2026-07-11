#!/usr/bin/env bash
# LogOS kernel K5b.2 slice — build the bootable PREEMPTIVE-tasks probe ELF.
#   task_preempt.la --(native_codegen3, spawn/yield + the rt_apply safe point)-->
#     the LA image: two NON-yielding workers that only interleave if the timer
#     preempts them.
#   boot.asm assembled -dK5_TIMER -dK5B2:
#     K5_TIMER -> PIC remap + PIT ~100 Hz + IDT[0x20] timer_isr + sti;
#     K5B2     -> the ISR ALSO sets the LA runtime's YIELD_PENDING byte, and MAIN
#                 gets a high stack (0x3F000000) above the task stacks.
#   incbin(image) -> kernel_preempt.elf (separate output; K1..K5a ELFs untouched).
#
# DRIFT GUARD: timer.asm hard-codes YIELD_PENDING_ABS (the LA runtime data slot's
# absolute address). A native_codegen3_rt.asm edit can move that slot, so we
# re-derive it from the rt listing and assert the equ still matches — otherwise
# the ISR would poke a random byte in the LA image and never preempt.
#
# Shares native_input.la / entry.inc with build.sh — run SEQUENTIALLY.
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos

echo "[1/5] drift guard: timer.asm YIELD_PENDING_ABS == rt-listing YIELD_PENDING slot"
nasm -f bin native_codegen3_rt.asm -o /tmp/k5b2_rt.bin -l /tmp/k5b2_rt.lst
OFF=$(awk '/ YIELD_PENDING: dq/{print $2; exit}' /tmp/k5b2_rt.lst)
[ -n "$OFF" ] || { echo "FAIL K5b.2 build: no YIELD_PENDING label in rt listing"; exit 1; }
DERIVED=$(( 0x400078 + 0x$OFF ))
EQU_HEX=$(grep -oE 'YIELD_PENDING_ABS[[:space:]]+equ[[:space:]]+0x[0-9A-Fa-f]+' kernel/timer.asm | grep -oE '0x[0-9A-Fa-f]+')
[ -n "$EQU_HEX" ] || { echo "FAIL K5b.2 build: no YIELD_PENDING_ABS equ in timer.asm"; exit 1; }
EQU=$(( EQU_HEX ))
[ "$DERIVED" -eq "$EQU" ] || { printf 'FAIL K5b.2 build: YIELD_PENDING addr drift — rt listing 0x%x != timer.asm 0x%x\n' "$DERIVED" "$EQU"; exit 1; }
printf '      YIELD_PENDING @ 0x%x (%d) — timer.asm matches the rt slot\n' "$DERIVED" "$DERIVED"

echo "[2/5] compile task_preempt.la via native_codegen3 (spawn/yield + safe point)"
cp kernel/task_preempt.la native_input.la
./tiny_host native_codegen3.la >/dev/null
ENTRY=$(readelf -h native_codegen3_out | awk '/Entry point/{print $NF}')
echo "      e_entry (LA prol) = $ENTRY"

echo "[3/5] generate entry.inc"
printf 'LA_ENTRY equ %s\n' "$ENTRY" > kernel/entry.inc

echo "[4/5] assemble boot.asm -dK5_TIMER -dK5B2 (preemption armed)"
nasm -f elf64 -dK5_TIMER -dK5B2 -i kernel/ kernel/boot.asm -o kernel/boot_preempt.o

echo "[5/5] link -> kernel_preempt.elf (elf64), repackage as elf32-i386"
ld -n -T kernel/kernel.ld kernel/boot_preempt.o -o kernel/kernel_preempt_64.elf
objcopy -O elf32-i386 kernel/kernel_preempt_64.elf kernel/kernel_preempt.elf

echo "OK: kernel/kernel_preempt.elf"
