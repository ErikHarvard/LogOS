#!/usr/bin/env bash
# LogOS kernel K3b gate — the PMM walks the REAL multiboot map on the metal.
# Boot kernel_pmm.elf in QEMU and assert the largest usable arena base — read
# from the loader's REAL memory map via peek() (not a synthetic string) — is
# 0x100000 (1 MiB, the standard start of usable PC RAM), and the first frame
# allocated from it is the same, then a clean success exit.
#
#   success: LA image parses the real map -> prints "K3B ARENA 1048576" +
#            "K3B FRAME 1048576" over COM1 -> exit(0) -> isa-debug-exit 0x10
#            -> QEMU exits (0x10<<1)|1 = 33.
#   any fault / wrong map: loud (K2's IDT diagnoses a fault; a wrong base fails
#            the grep). -no-reboot makes a triple-fault exit non-33.
#
# Builds kernel_pmm.elf first (shares native_input.la/native_codegen3_out with
# build.sh — run SEQUENTIALLY, never in parallel with a build). Skips (rc 0)
# when QEMU is absent, like the K1/K2 gates.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  K3b gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_k3b.sh >/dev/null 2>&1 || { echo "FAIL  K3b gate: build_k3b.sh failed"; exit 1; }

OUT=$(timeout 30 qemu-system-x86_64 \
        -kernel kernel/kernel_pmm.elf -m 256 \
        -serial stdio -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown 2>/dev/null)
RC=$?

ok=1
printf '%s' "$OUT" | grep -qF "K3B ARENA 1048576" || { echo "FAIL  K3b: arena base != 0x100000 from the real map (rc=$RC, got: $(printf '%s' "$OUT" | tr -d '\0' | tr '\n' ' ' | head -c 160))"; ok=0; }
printf '%s' "$OUT" | grep -qF "K3B FRAME 1048576" || { echo "FAIL  K3b: first allocated frame != arena base (rc=$RC)"; ok=0; }
[ "$RC" -eq 33 ] || { echo "FAIL  K3b: clean-exit code != 33 (got $RC — a fault/triple-fault or hang)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  K3b: PMM walks the REAL multiboot map on the metal via peek() -> largest arena 0x100000 -> first frame allocated, clean halt (b_τ ≡ f_τ to the metal)"
[ "$ok" -eq 1 ]
