#!/usr/bin/env bash
# LogOS kernel K4c (first slice) gate — W^X ENFORCEMENT on the METAL.
# Boot kernel_wx.elf in QEMU and assert the LA image:
#   (1) allocates a real PMM frame for the PML4 — "K4C FRAME <n>";
#   (2) builds a 4-level page table in real frames with a READ-ONLY high test
#       page (PDPT[1]->PD1[0]->phys 160 MiB, W=0) at vaddr 0x40000000, loads CR3,
#       and reads a sentinel (0xAB) back through the high vaddr — the RO mapping
#       is live and readable:  "K4C WX READ 171";
#   (3) then WRITES through that same high read-only vaddr. With CR0.WP armed the
#       CPU raises a page-protection #PF (vector 14) — W^X is ENFORCED, the write
#       never lands. K2's IDT diagnoses it loudly:
#         "EXCEPTION 0e ..."   (page fault caught, not a silent write / triple-fault)
#       and isa-debug-exit FAIL -> QEMU exit 35 (NOT the clean 33).
#
#   success (W^X live): the RO read line appears AND the write faults loudly
#            (EXCEPTION 0e, exit 35). A regression that disarmed CR0.WP would let
#            the write silently succeed -> no fault, exit 33 -> this gate FAILS.
#
# Builds kernel_wx.elf first (shares native_input.la with build.sh — run
# SEQUENTIALLY, never in parallel with a build). Skips (rc 0) when QEMU absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  K4c-wx gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_k4c_wx.sh >/dev/null 2>&1 || { echo "FAIL  K4c-wx gate: build_k4c_wx.sh failed"; exit 1; }

OUT=$(timeout 30 qemu-system-x86_64 \
        -kernel kernel/kernel_wx.elf -m 256 \
        -serial stdio -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown 2>/dev/null)
RC=$?

ok=1
seen=$(printf '%s' "$OUT" | tr -d '\0' | tr '\n' ' ' | head -c 200)
printf '%s' "$OUT" | grep -qF "K4C FRAME "        || { echo "FAIL  K4c-wx: PMM did not allocate a frame for the PML4 (rc=$RC, got: $seen)"; ok=0; }
printf '%s' "$OUT" | grep -qF "K4C WX READ 171"   || { echo "FAIL  K4c-wx: sentinel NOT read back through the high read-only vaddr — the RO mapping was not live before the write (rc=$RC, got: $seen)"; ok=0; }
printf '%s' "$OUT" | grep -qi "EXCEPTION 0e"      || { echo "FAIL  K4c-wx: the write to the READ-ONLY page did NOT fault — W^X is NOT enforced (CR0.WP disarmed?) (rc=$RC, got: $seen)"; ok=0; }
[ "$RC" -eq 35 ] || { echo "FAIL  K4c-wx: fault exit != 35 (got $RC — the write silently succeeded, or a triple-fault/hang)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  K4c (W^X live): an LA-built page table maps a high page READ-ONLY; the CPU serves reads through it but a ring-0 WRITE raises a page-protection #PF (EXCEPTION 0e, exit 35) — CR0.WP + NXE armed, paging PROTECTION enforced on the metal, not just translation"
[ "$ok" -eq 1 ]
