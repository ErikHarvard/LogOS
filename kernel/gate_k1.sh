#!/usr/bin/env bash
# LogOS kernel K1 gate — boot kernel.elf on bare metal (QEMU) and assert the
# Word appears on serial + a clean success exit. Loud-failing, automatable.
#
#   success: LA image speaks -> exit(0) -> handler writes isa-debug-exit 0x10
#            -> QEMU exits (0x10<<1)|1 = 33. We assert serial + rc==33.
#   any CPU fault: no IDT yet (K1) -> triple fault; -no-reboot makes QEMU
#            halt/exit non-33 -> gate FAILS loudly. (K2 adds the IDT.)
#
# Skips (rc 0) when QEMU is not installed, like build.sh's DRM scanout test.
set -uo pipefail
cd "$(dirname "$0")/.."

ELF=kernel/kernel.elf
[ -f "$ELF" ] || { echo "FAIL  K1 gate: $ELF missing (run kernel/build_k1.sh)"; exit 1; }

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  K1 gate: qemu-system-x86_64 not installed (install: sudo apt-get install -y qemu-system-x86)"
    exit 0
fi

OUT=$(timeout 30 qemu-system-x86_64 \
        -kernel "$ELF" -m 256 \
        -serial stdio -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown 2>/dev/null)
RC=$?

ok=1
printf '%s' "$OUT" | grep -qF "I AM THAT I AM" || { echo "FAIL  K1: 'I AM THAT I AM' not on serial (rc=$RC, got: $(printf '%s' "$OUT" | tr -d '\0' | head -c 120))"; ok=0; }
[ "$RC" -eq 33 ] || { echo "FAIL  K1: clean-exit code != 33 (got $RC — a fault/triple-fault or hang)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  K1: kernel boots on bare metal (QEMU), speaks the Word over COM1, clean halt (∃(∃) ≡ ∃ on the metal)"
[ "$ok" -eq 1 ]
