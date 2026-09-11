#!/usr/bin/env bash
# LogOS P4 — PROCESS DEATH VISIBLE TO INIT (`pwait`, LogosInit brick 4 of 7).
#
#   P2 records a death in the PCB (state 3 EXIT or 4 FAULT, plus the exit status or
#   the vector) and P3 creates children, but nothing could WAIT: the scheduler runs
#   each process from its entry to completion, so a parent can learn of a death only
#   by BLOCKING until it happens. `pwait()` (syscall 61) reports a dead child of the
#   CALLER as (pid, cause, detail) and frees its slot; with live children and none
#   dead, it blocks — the caller's full ring-3 context is saved, and a death wakes it;
#   with no children at all, it returns -1 (ECHILD). See LOGOSINIT_SCOPE.md §P4.
#
#   Variants (kernel/gate_p4.sh drives them; their expected shapes are pre-registered
#   in LOGOSINIT_SCOPE.md §P4, commit 3c0f318, BEFORE this code was written):
#     (none)         the green case: pid 1 spawns 4 and 5, 4 spawns 6; every death is
#                    reported to its own parent, with its cause, exactly once
#     --nofix        R1 baseline: the PROBE without the HANDLER. Syscall 61 is unknown,
#                    so pwait "returns" 0 and no death is ever learned — and the build
#                    still exits 33: green by exit code, wrong by content
#     --wrongcause   R2: every death reported as EXIT — child 5's crash reads EXIT 06
#     --noparent     R3: the parent field ignored — a waiter gets processes that are
#                    not its children, and pid 4 never receives its own child 6
#     --noblock      R4: never block (the reapnb shape) — pid 1 exits before any child
#                    dies and never learns of one: the DISCRIMINATOR
#     --nofree       R5: a reported child is not freed — reported again and again until
#                    the probe's cap
#     --nowake       R6: the death paths never wake the parent — the kernel must say
#                    "P4 STUCK" and exit 39, never hang and never exit 33
#
# ⚠ SHARES kernel/entry.inc with every other kernel/build_*.sh — run kernel builds
#   SEQUENTIALLY within this worktree (per-directory, so no cross-worktree collision).
set -euo pipefail
cd "$(dirname "$0")/.."

DEFS="-dP4 -dP4_WAITPROBE"; TAG=""
for a in "$@"; do
    case "$a" in
        --nofix)       DEFS="-dP3 -dP4_WAITPROBE";   TAG="$TAG (R1 baseline: probe, no pwait)" ;;
        --wrongcause)  DEFS="$DEFS -dP4_WRONGCAUSE"; TAG="$TAG (R2: every death reported as EXIT)" ;;
        --noparent)    DEFS="$DEFS -dP4_NOPARENT";   TAG="$TAG (R3: the parent field ignored)" ;;
        --noblock)     DEFS="$DEFS -dP4_NOBLOCK";    TAG="$TAG (R4: never block)" ;;
        --nofree)      DEFS="$DEFS -dP4_NOFREE";     TAG="$TAG (R5: a reported child is not freed)" ;;
        --nowake)      DEFS="$DEFS -dP4_NOWAKE";     TAG="$TAG (R6: a death never wakes the parent)" ;;
        *) echo "usage: build_p4.sh [--nofix] [--wrongcause] [--noparent] [--noblock] [--nofree] [--nowake]" >&2; exit 2 ;;
    esac
done

printf 'LA_ENTRY equ 0x400000\n' > kernel/entry.inc
nasm -f elf64 $DEFS -i kernel/ kernel/boot.asm -o kernel/boot_p4.o
ld -n -T kernel/kernel.ld kernel/boot_p4.o -o kernel/kernel_p4_64.elf
objcopy -O elf32-i386 kernel/kernel_p4_64.elf kernel/kernel_p4.elf
echo "OK: kernel/kernel_p4.elf$TAG"
