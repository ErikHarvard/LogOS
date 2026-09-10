#!/usr/bin/env bash
# LogOS P2 — FAULT ATTRIBUTION AND CONTAINMENT (LogosInit keystone).
#
#   K2's 32 handlers diagnose a vector and HALT. P2 makes a ring-3 fault name its
#   OWNER (the pid the table says is current), record vector + error code + CR2
#   into that process's PCB, mark it dead-by-fault, unmap its address space, and
#   return to P1's scheduler. The machine survives; the process does not.
#
#   Ring-0 faults stay FATAL and keep K2's loud halt: containment is for
#   processes, and a kernel bug that "recovered" is the masking R3 forbids.
#
#   Variants (kernel/gate_p2.sh drives them):
#     (none)    #UD in process 2 — the green case
#     --nofix   P2.0 WITHOUT P2: R1' baseline. Now that P2.0 has landed this is
#               "diagnosed-but-halted" (EXCEPTION 06, exit 35, siblings never
#               run), not the pre-P2.0 wedge — a far more informative control.
#     --pid3    R2: process 3 faults instead. The reported pid must follow.
#     --pf      R5: #PF instead of #UD. vec 0e, err non-zero, CR2 = P2_PF_VA.
#     --shared  R4: all three PCBs on ONE PML4, so the per-process values must
#               collapse — proving the isolation assertion could have failed.
#     --mask    R3: the WRONG implementation compiled in — map past the fault and
#               RESUME the process. Satisfies every assertion except the marker
#               the resumed process prints, which is exactly why that marker is
#               asserted. Requires the marker to APPEAR.
#
# ⚠ SHARES kernel/entry.inc with every other kernel/build_*.sh — run kernel
#   builds SEQUENTIALLY within this worktree (per-directory, so no cross-worktree
#   collision).
set -euo pipefail
cd "$(dirname "$0")/.."

DEFS="-dP2 -dP2_FAULTPROBE"; TAG=""
for a in "$@"; do
    case "$a" in
        --nofix)  DEFS="-dP2_0 -dP2_FAULTPROBE"; TAG="$TAG (R1' baseline: P2.0, no P2)" ;;
        --pid3)   DEFS="$DEFS -dP2_FAULT_PID=3"; TAG="$TAG (R2: process 3 faults)" ;;
        --pf)     DEFS="$DEFS -dP2_FAULT_PF";    TAG="$TAG (R5: #PF shape)" ;;
        --shared) DEFS="$DEFS -dP1_SHARED";      TAG="$TAG (R4: one shared PML4)" ;;
        --mask)   DEFS="$DEFS -dP2_MASK_INSTEAD"; TAG="$TAG (R3: MASK — resume, do not kill)" ;;
        *) echo "usage: build_p2.sh [--nofix] [--pid3] [--pf] [--shared]" >&2; exit 2 ;;
    esac
done

printf 'LA_ENTRY equ 0x400000\n' > kernel/entry.inc
nasm -f elf64 $DEFS -i kernel/ kernel/boot.asm -o kernel/boot_p2.o
ld -n -T kernel/kernel.ld kernel/boot_p2.o -o kernel/kernel_p2_64.elf
objcopy -O elf32-i386 kernel/kernel_p2_64.elf kernel/kernel_p2.elf
echo "OK: kernel/kernel_p2.elf$TAG"
