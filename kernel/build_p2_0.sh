#!/usr/bin/env bash
# LogOS P2.0 — make the fault path REACHABLE from every address space
# (LogosInit brick P2, step 0 of 2: loudness before attribution).
#
#   MEASURED starting state (2026-09-08). A ring-3 fault inside a P1 process
#   produces NO serial output and NO exit code — the machine wedges. The same
#   `ud2` on the kernel's own CR3 gives "EXCEPTION 06 ... rip=ffffffff8010035c"
#   and exit 35. The only variable is the address space: K2's loud-failure
#   guarantee does NOT extend into a process address space.
#
#   WHY. A P1 process's PML4 maps only its own 2 MiB page (pd_i[128]) plus the
#   kernel high half at [511]. Every fault-path dependency is below 2 MiB, in
#   PD[0], which is NOT PRESENT under a process CR3:
#       idt      — idt_ptr's base is the LOW BSS address; the IDTR is not
#                  reloaded on a CR3 switch, so it keeps pointing there
#       isrN     — isr_table holds LOW absolute handler addresses, so every
#                  gate offset is low
#       exc_msg  — isr_common does `mov rsi, exc_msg`, a low absolute
#   The CPU faults reading the IDT descriptor, that fault is undeliverable too,
#   -> double -> triple -> CPU stops.
#
#   P2.0 relocates all three to the high alias (%ifdef P2_HIGHIDT in idt.asm).
#   It restores K2's EXISTING diagnostic inside a process and NOTHING ELSE — no
#   attribution, no containment, the machine still halts. That is deliberate:
#   P2.0 and P2 must be separately gateable, and a handler that cannot deliver
#   an interrupt cannot be tested for what it reports.
#
#   --nofix : THE RED CONTROL. Same faulting image built WITHOUT the relocation
#             (-dP1 only). Must reproduce the measured wedge: no output, rc 124.
#             gate_p2_0.sh --red REQUIRES that, and requires it BY NAME rather
#             than accepting any non-green — a timeout is also what a hang, a
#             lost serial, or too short a timeout produce.
#
# Separate output (kernel_p2_0.elf); every other kernel ELF stays byte-identical
# (all P2.0 code is %ifdef-guarded). No LA image, so no native compile.
#
# ⚠ SHARES kernel/entry.inc WITH build.sh AND the other kernel/build_*.sh — run
#   kernel builds SEQUENTIALLY within this worktree. (Per-directory, so another
#   worktree's build cannot collide with this one.)
set -euo pipefail
cd "$(dirname "$0")/.."

case "${1:-}" in
    "")       DEFS="-dP2_0 -dP1_FAULTPROBE"; TAG="" ;;
    --nofix)  DEFS="-dP1 -dP1_FAULTPROBE";   TAG="  (RED CONTROL: no high IDT)" ;;
    *)        echo "usage: build_p2_0.sh [--nofix]" >&2; exit 2 ;;
esac

echo "[1/2] entry.inc (dummy; P2.0 has no LA image, LA_ENTRY is unused)"
printf 'LA_ENTRY equ 0x400000\n' > kernel/entry.inc

echo "[2/2] assemble boot.asm $DEFS, link (elf64), repackage as elf32-i386"
nasm -f elf64 $DEFS -i kernel/ kernel/boot.asm -o kernel/boot_p2_0.o
ld -n -T kernel/kernel.ld kernel/boot_p2_0.o -o kernel/kernel_p2_0_64.elf
objcopy -O elf32-i386 kernel/kernel_p2_0_64.elf kernel/kernel_p2_0.elf

echo "OK: kernel/kernel_p2_0.elf$TAG"
