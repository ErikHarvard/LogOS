#!/usr/bin/env bash
# LogOS kernel K4b gate — paging wired to the METAL (poke builtin).
# Boot kernel_paging.elf in QEMU and assert the LA image:
#   (1) allocates a real physical frame from the K3 PMM (real multiboot map) —
#       "K4B FRAME 1048576" (0x100000, the arena base);
#   (2) BUILDS a K4a page-table entry in that real frame via poke and reads it
#       back via peek, byte-identical to the K4a-assembled value:
#         "K4B PTELO 2097155"     (PTE_LO(0x200000, P|W) = 0x200000|3)
#         "K4B PTEHI 2147483648"  (PTE_HI(0x200000, NX)  = NX bit, high32 bit31)
#   then a clean success exit.
#
#   success: the pokes land in the real frame, peek reads them back -> the three
#            lines over COM1 -> exit(0) -> isa-debug-exit 0x10 -> QEMU exits 33.
#   any fault / wrong value: loud (K2's IDT diagnoses a fault; a wrong value
#            fails the grep). -no-reboot makes a triple-fault exit non-33.
#
# Builds kernel_paging.elf first (shares native_input.la with build.sh — run
# SEQUENTIALLY, never in parallel with a build). Skips (rc 0) when QEMU absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  K4b gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_k4b.sh >/dev/null 2>&1 || { echo "FAIL  K4b gate: build_k4b.sh failed"; exit 1; }

OUT=$(timeout 30 qemu-system-x86_64 \
        -kernel kernel/kernel_paging.elf -m 256 \
        -serial stdio -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown 2>/dev/null)
RC=$?

ok=1
seen=$(printf '%s' "$OUT" | tr -d '\0' | tr '\n' ' ' | head -c 200)
printf '%s' "$OUT" | grep -qF "K4B FRAME 1048576"      || { echo "FAIL  K4b: PMM did not allocate the arena frame 0x100000 (rc=$RC, got: $seen)"; ok=0; }
printf '%s' "$OUT" | grep -qF "K4B PTELO 2097155"      || { echo "FAIL  K4b: PTE low32 read back from the real frame != 0x200003 (rc=$RC, got: $seen)"; ok=0; }
printf '%s' "$OUT" | grep -qF "K4B PTEHI 2147483648"   || { echo "FAIL  K4b: PTE high32 (NX) read back from the real frame != bit63 (rc=$RC, got: $seen)"; ok=0; }
[ "$RC" -eq 33 ] || { echo "FAIL  K4b: clean-exit code != 33 (got $RC — a fault/triple-fault or hang)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  K4b: paging wired to the metal — PMM allocates a real frame, a K4a PTE is BUILT in it via poke and read back byte-identical via peek (b_τ ≡ f_τ, the write half of paging on the metal)"
[ "$ok" -eq 1 ]
