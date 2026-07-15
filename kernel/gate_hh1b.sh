#!/usr/bin/env bash
# LogOS kernel HH1b slice gate — the kernel speaks the Word from the higher half.
# Boot kernel_hh1b.elf in QEMU and assert:
#   - "I AM THAT I AM" on serial — the LA image, compiled by native_codegen3_hh with
#     VADDR/RT_*/heap all in the −2 GiB half, ran and spoke the Word AFTER the low
#     identity map was dropped, so it executed ENTIRELY from 0xFFFFFFFF80.......
#     (a low-based image or a surviving low ref would #PF/triple-fault -> silence);
#   - exit code 33 — its epilogue exit syscall (serviced by the HIGH syscall_entry
#     via the re-pointed LSTAR) reached isa-debug-exit.
# This is the full HH1 payoff: kernel + LA image running wholly high, the low
# canonical half freed for future user processes (HH2). -m 256. Skips (rc 0) if
# QEMU is absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  HH1b higher-half gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_hh1b.sh >/dev/null 2>&1 || { echo "FAIL  HH1b gate: build_hh1b.sh failed"; exit 1; }

OUT=$(timeout 30 qemu-system-x86_64 \
        -kernel kernel/kernel_hh1b.elf -m 256 \
        -serial stdio -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown 2>/dev/null)
RC=$?
CLEAN=$(printf '%s' "$OUT" | tr -d '\0')
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 200)

ok=1
printf '%s' "$CLEAN" | grep -qF 'I AM THAT I AM' || { echo "FAIL  HH1b: 'I AM THAT I AM' not on serial — the HIGH LA image did not run after dropping the low map (a bad rebase, lost LSTAR, or a stray low ref) (rc=$RC, got: $seen)"; ok=0; }
[ "$RC" -eq 33 ] || { echo "FAIL  HH1b: exit code != 33 (got $RC — a fault running wholly high, or the exit syscall's high LSTAR path)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  HH1b slice: the kernel speaks the Word from the HIGHER HALF — native_codegen3_hh emitted an LA image based at 0xFFFFFFFF80400000, and boot dropped the low identity map (PML4[0]=0), re-pointed LSTAR at the high syscall_entry, and entered it; the kernel + LA image now run ENTIRELY in the −2 GiB half, freeing the low canonical half for user processes. HH1 COMPLETE."
[ "$ok" -eq 1 ]
