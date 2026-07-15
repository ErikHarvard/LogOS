#!/usr/bin/env bash
# LogOS kernel HH1a slice gate — the kernel executes from the higher half.
# Boot kernel_hh1.elf in QEMU and assert:
#   - "HH1@F" on serial — after enabling paging with the high map, the boot jumped
#     to the HIGH alias of hh_high and, running there, read its own RIP and printed
#     its top nibble. 'F' means RIP = 0xFFFFFFFF8........, i.e. the boot code is
#     genuinely executing in the −2 GiB half (a failed high map / bad jump would
#     #PF/triple-fault and print nothing);
#   - "I AM THAT I AM" — the (still-low, dual-mapped) LA image then ran and spoke
#     the Word, proving the low identity map survives alongside the high map;
#   - exit code 33 — the LA image's epilogue exit reached isa-debug-exit.
# -m 256 (the low LA heap ~68 MiB must be real RAM), like K1. Skips (rc 0) if QEMU
# is absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  HH1a higher-half gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_hh1.sh >/dev/null 2>&1 || { echo "FAIL  HH1a gate: build_hh1.sh failed"; exit 1; }

OUT=$(timeout 30 qemu-system-x86_64 \
        -kernel kernel/kernel_hh1.elf -m 256 \
        -serial stdio -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown 2>/dev/null)
RC=$?
CLEAN=$(printf '%s' "$OUT" | tr -d '\0')
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 200)

ok=1
printf '%s' "$CLEAN" | grep -qF 'HH1@F' || { echo "FAIL  HH1a: 'HH1@F' not on serial — the boot did not execute from the high half (bad high map or jump; RIP top nibble != F) (rc=$RC, got: $seen)"; ok=0; }
printf '%s' "$CLEAN" | grep -qF 'I AM THAT I AM' || { echo "FAIL  HH1a: 'I AM THAT I AM' not on serial — the low LA image did not run after the high jump (low identity map lost?) (rc=$RC, got: $seen)"; ok=0; }
[ "$RC" -eq 33 ] || { echo "FAIL  HH1a: exit code != 33 (got $RC — a fault in the high jump or the LA handoff)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  HH1a slice: the kernel executes from the higher half — the 32-bit trampoline built a high map (PML4[511]->pdpt_high[510]->pd) aliasing the low 1 GiB at 0xFFFFFFFF80000000, the boot jumped to its high alias and confirmed RIP=0xF........ ('HH1@F'), then the still-low LA image spoke the Word (low identity map kept). The −2 GiB relink + high mapping are proven; HH1b rebases the LA image high and drops the low map."
[ "$ok" -eq 1 ]
