#!/usr/bin/env bash
# LogOS kernel K4c slice gate — the LA HEAP backed by real PMM frames.
# Boot kernel_paging_heap.elf in QEMU and assert the LA image:
#   (1) allocates a real PMM frame for the PML4 — "K4C HFRAME <n>";
#   (2) builds a 4-level table with a 4 KiB-granular HEAP WINDOW (PT0[i] -> a
#       distinct PMM frame), loads CR3, and — through the HIGH vaddrs only our
#       table maps — writes (200+i) to each heap page, then reads back:
#         "K4C HEAP0 200"   (high vaddr of page 0 -> its frame, written value)
#         "K4C HEAP3 203"   (a DIFFERENT high page -> a DIFFERENT frame/value:
#                            four independent 4 KiB mappings)
#         "K4C HPHYS0 200"  (page 0's frame, read through its IDENTITY addr:
#                            the high heap page really landed in that PMM frame)
#         "K4C HPHYS3 203"  (page 3's frame likewise -> distinct real frames)
#   then a clean success exit.
#
#   success: the heap window is live on real PMM frames — high-read == phys-read
#            == written value for two distinct pages -> the four lines over COM1
#            -> exit(0) -> isa-debug-exit 0x10 -> QEMU exits 33.
#   fault: loud (K2's IDT diagnoses a #PF if the walk faults; a wrong value fails
#            the grep). -no-reboot makes a triple-fault exit non-33.
#
# Builds kernel_paging_heap.elf first (shares native_input.la with build.sh — run
# SEQUENTIALLY, never in parallel with a build). Skips (rc 0) when QEMU absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  K4c-heap gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_k4c_heap.sh >/dev/null 2>&1 || { echo "FAIL  K4c-heap gate: build_k4c_heap.sh failed"; exit 1; }

OUT=$(timeout 30 qemu-system-x86_64 \
        -kernel kernel/kernel_paging_heap.elf -m 256 \
        -serial stdio -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown 2>/dev/null)
RC=$?

ok=1
seen=$(printf '%s' "$OUT" | tr -d '\0' | tr '\n' ' ' | head -c 260)
printf '%s' "$OUT" | grep -qF "K4C HFRAME "   || { echo "FAIL  K4c-heap: PMM did not allocate a frame for the PML4 (rc=$RC, got: $seen)"; ok=0; }
printf '%s' "$OUT" | grep -qF "K4C HEAP0 200" || { echo "FAIL  K4c-heap: heap page 0 not read back through the high vaddr after the switch — the 4 KiB heap mapping is not live (rc=$RC, got: $seen)"; ok=0; }
printf '%s' "$OUT" | grep -qF "K4C HEAP3 203" || { echo "FAIL  K4c-heap: heap page 3 wrong — the four 4 KiB pages are not independent mappings (rc=$RC, got: $seen)"; ok=0; }
printf '%s' "$OUT" | grep -qF "K4C HPHYS0 200" || { echo "FAIL  K4c-heap: heap page 0's high write did NOT land in its PMM frame (identity read mismatch) — the heap is not on that real frame (rc=$RC, got: $seen)"; ok=0; }
printf '%s' "$OUT" | grep -qF "K4C HPHYS3 203" || { echo "FAIL  K4c-heap: heap page 3's frame mismatch — the window is not backed by DISTINCT real PMM frames (rc=$RC, got: $seen)"; ok=0; }
[ "$RC" -eq 33 ] || { echo "FAIL  K4c-heap: clean-exit code != 33 (got $RC — a fault/triple-fault or hang)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  K4c slice: the LA HEAP on real PMM frames — an LA-built PT maps a 4 KiB-granular heap window onto distinct PMM-allocated frames; after the CR3 switch the image writes and reads heap memory through the high vaddrs, each landing in its real frame (b_τ ≡ f_τ, VMM-backed heap on the metal)"
[ "$ok" -eq 1 ]
