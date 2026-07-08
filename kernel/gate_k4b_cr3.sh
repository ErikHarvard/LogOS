#!/usr/bin/env bash
# LogOS kernel K4b CAPSTONE gate — the CR3 SWITCH on the METAL.
# Boot kernel_paging_cr3.elf in QEMU and assert the LA image:
#   (1) allocates a real PMM frame for the PML4 — "K4C FRAME <n>";
#   (2) builds a 4-level page table in real frames (identity low 1 GiB, like
#       boot.asm, PLUS PDPT[1]->PD1->a 2 MiB page at phys 160 MiB), loads its
#       base into CR3 via the new set_cr3 builtin, and reads a sentinel (0xAB)
#       back THROUGH the high vaddr 0x40000000 — a vaddr boot.asm's table does
#       NOT map. Reading it proves the CPU walked the LA-built table:
#         "K4C READ 171"   (0xAB, through the high vaddr -> the LA table is live)
#         "K4C IDENT 171"  (identity mapping still intact after the switch)
#   then a clean success exit.
#
#   success: the CR3 switch takes, both peeks read 0xAB -> the three lines over
#            COM1 -> exit(0) -> isa-debug-exit 0x10 -> QEMU exits 33.
#   fault: loud (K2's IDT diagnoses a #PF if the switch faults; a wrong value
#            fails the grep). -no-reboot makes a triple-fault exit non-33.
#
# Builds kernel_paging_cr3.elf first (shares native_input.la with build.sh — run
# SEQUENTIALLY, never in parallel with a build). Skips (rc 0) when QEMU absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  K4b-cr3 gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_k4b_cr3.sh >/dev/null 2>&1 || { echo "FAIL  K4b-cr3 gate: build_k4b_cr3.sh failed"; exit 1; }

OUT=$(timeout 30 qemu-system-x86_64 \
        -kernel kernel/kernel_paging_cr3.elf -m 256 \
        -serial stdio -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown 2>/dev/null)
RC=$?

ok=1
seen=$(printf '%s' "$OUT" | tr -d '\0' | tr '\n' ' ' | head -c 200)
printf '%s' "$OUT" | grep -qF "K4C FRAME "     || { echo "FAIL  K4b-cr3: PMM did not allocate a frame for the PML4 (rc=$RC, got: $seen)"; ok=0; }
printf '%s' "$OUT" | grep -qF "K4C READ 171"   || { echo "FAIL  K4b-cr3: sentinel NOT read back through the high vaddr after the CR3 switch — the CPU did not walk the LA-built table (rc=$RC, got: $seen)"; ok=0; }
printf '%s' "$OUT" | grep -qF "K4C IDENT 171"  || { echo "FAIL  K4b-cr3: identity mapping broken after the switch (rc=$RC, got: $seen)"; ok=0; }
[ "$RC" -eq 33 ] || { echo "FAIL  K4b-cr3: clean-exit code != 33 (got $RC — a fault/triple-fault or hang)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  K4b capstone: the CR3 SWITCH — an LA-built 4-level page table (PMM frames, poke'd entries) is loaded into CR3; the CPU walks it, reading a sentinel through a HIGH vaddr only the LA table maps (b_τ ≡ f_τ, paging live on the metal)"
[ "$ok" -eq 1 ]
