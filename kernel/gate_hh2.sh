#!/usr/bin/env bash
# LogOS kernel HH2 slice gate — per-process address-space isolation.
# Boot kernel_hh2.elf in QEMU and assert:
#   - "HH2 ISOLATED A=AA B=BB" on serial — the kernel (running high) built two
#     process PML4s sharing the kernel PML4[511] but with distinct low halves
#     mapping the SAME virtual page (6 MiB) to different physical frames, then:
#     under A wrote 0xAA, switched CR3 to B and wrote 0xBB to the same VA, and on
#     switching CR3 back to A read 0xAA — B's write did NOT touch A's frame. Two
#     isolated address spaces, selected by CR3, over one shared kernel;
#   - exit code 33.
# A failure prints "HH2 LEAK" (A saw B's write -> not isolated) or faults (a bad
# process PML4 / lost kernel share on CR3 switch). -m 256 (frames at 32/34 MiB +
# the high stack at 128 MiB must be real RAM). Skips (rc 0) if QEMU is absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  HH2 per-process-isolation gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_hh2.sh >/dev/null 2>&1 || { echo "FAIL  HH2 gate: build_hh2.sh failed"; exit 1; }

OUT=$(timeout 30 qemu-system-x86_64 \
        -kernel kernel/kernel_hh2.elf -m 256 \
        -serial stdio -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown 2>/dev/null)
RC=$?
CLEAN=$(printf '%s' "$OUT" | tr -d '\0')
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 200)

ok=1
printf '%s' "$CLEAN" | grep -qF 'HH2 ISOLATED' || { echo "FAIL  HH2: 'HH2 ISOLATED' not on serial — address spaces not isolated, or a CR3 switch lost the kernel/stack (rc=$RC, got: $seen)"; ok=0; }
[ "$RC" -eq 33 ] || { echo "FAIL  HH2: exit code != 33 (got $RC — a fault building/switching the process page tables)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  HH2 slice: per-process page tables — two process PML4s share the kernel PML4[511] but hold DISTINCT low halves; the same virtual page (6 MiB) maps to different physical frames per process, so a write under process A is invisible to process B and vice-versa (verified by a CR3 round-trip: A=0xAA survives B's 0xBB at the same VA). Isolated address spaces over one shared high-half kernel — the process-model foundation. Next: give each ring-3 LA process its own PML4."
[ "$ok" -eq 1 ]
