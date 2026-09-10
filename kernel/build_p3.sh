#!/usr/bin/env bash
# LogOS P3 — LA-DRIVEN PROCESS CREATION (`pspawn`).
#
#   P1 built its three processes AT BOOT, through the low identity map, before any
#   CR3 was a process's. P3 does the same work AT RUNTIME, from ring 3, under a
#   process's CR3 — where that map is gone, so every write goes through the high
#   alias. `pspawn()` (syscall 57) finds a free PCB slot, takes a pid from a
#   MONOTONIC counter, builds PML4/PDPT/PD, copies the PRISTINE image into the
#   child's frame, stamps its value tag and spawn budget, marks it RUNNABLE, and
#   returns the child's pid TO RING 3.
#
#   It is not fork: nothing of the caller is copied. That is deliberate — P6's
#   restart-after-fault must REBUILD (a faulted address space is corrupt), so the
#   from-pristine path is the one that brick needs.
#
#   Variants (kernel/gate_p3.sh drives them):
#     (none)       pid 1 spawns child 4; child 4 spawns child 5 — the green case
#     --nofix      R1 baseline: the PROBE without the HANDLER. Syscall 57 is unknown,
#                  so syscall_entry's `xor rax,rax` returns 0 and no child exists.
#                  ★ Note this build still exits 33 — the baseline is green by exit
#                  code and wrong by content, so the gate must assert content.
#     --sharedcr3  R2: give the child the PARENT'S CR3 — val must collapse D4 -> A1.
#     --phantom    R3: allocate and return a pid, record NOTHING. The PSPAWN line
#                  still prints; no fourth process ever runs.
#     --nodepth    R4: refuse a caller whose pid is above the boot-built range, so
#                  child 4 cannot spawn 5. The ONLY control separating P3 from
#                  `P1_NPROC equ 4`.
#     --flood      R5: never decrement the budget, so every process spawns and the
#                  table must fill — exhaustion REPORTED (-1 -> "NO CHILD") and the
#                  machine still drains and exits 33.
#
# ⚠ SHARES kernel/entry.inc with every other kernel/build_*.sh — run kernel
#   builds SEQUENTIALLY within this worktree (per-directory, so no cross-worktree
#   collision).
set -euo pipefail
cd "$(dirname "$0")/.."

DEFS="-dP3 -dP3_SPAWNPROBE"; TAG=""
for a in "$@"; do
    case "$a" in
        --nofix)      DEFS="-dP2 -dP3_SPAWNPROBE";  TAG="$TAG (R1 baseline: probe, no pspawn)" ;;
        --sharedcr3)  DEFS="$DEFS -dP3_SHAREDCR3";  TAG="$TAG (R2: child gets the parent's CR3)" ;;
        --phantom)    DEFS="$DEFS -dP3_PHANTOM";    TAG="$TAG (R3: announce, do not record)" ;;
        --nodepth)    DEFS="$DEFS -dP3_NODEPTH";    TAG="$TAG (R4: a spawned process may not spawn)" ;;
        --flood)      DEFS="$DEFS -dP3_FLOOD";      TAG="$TAG (R5: budget never decremented)" ;;
        *) echo "usage: build_p3.sh [--nofix] [--sharedcr3] [--phantom] [--nodepth] [--flood]" >&2; exit 2 ;;
    esac
done

printf 'LA_ENTRY equ 0x400000\n' > kernel/entry.inc
nasm -f elf64 $DEFS -i kernel/ kernel/boot.asm -o kernel/boot_p3.o
ld -n -T kernel/kernel.ld kernel/boot_p3.o -o kernel/kernel_p3_64.elf
objcopy -O elf32-i386 kernel/kernel_p3_64.elf kernel/kernel_p3.elf
echo "OK: kernel/kernel_p3.elf$TAG"
