#!/usr/bin/env bash
# LogOS kernel HH2b slice gate — a ring-3 LA PROCESS in its own address space.
# Boot kernel_hh2b.elf in QEMU and assert:
#   - "I AM THAT I AM" on serial — the kernel, running in the shared HIGH half,
#     built a per-process PML4 whose LOW half (U=1) holds the LA image and whose
#     HIGH half shares the kernel (supervisor), switched CR3 to it, and iretq'd to
#     ring 3 at the LA image, which spoke the Word through a write syscall that
#     crossed ring3(low) -> ring0(HIGH kernel) -> ring3. The process runs in its
#     OWN address space (its own PML4), not the shared identity map;
#   - exit code 33 — the LA image's exit syscall reached isa-debug-exit.
# Composes HH1 (kernel high) + HH2 (per-process page tables) + K6b (ring-3 LA). A
# bad process PML4 / lost kernel share / bad high LSTAR would #PF/triple-fault. Needs
# -m 1024 (the low 1 GiB user half: LA heap + 128 MiB stack). Skips if QEMU absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  HH2b per-process-LA gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_hh2b.sh >/dev/null 2>&1 || { echo "FAIL  HH2b gate: build_hh2b.sh failed"; exit 1; }

OUT=$(timeout 30 qemu-system-x86_64 \
        -kernel kernel/kernel_hh2b.elf -m 1024 \
        -serial stdio -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown 2>/dev/null)
RC=$?
CLEAN=$(printf '%s' "$OUT" | tr -d '\0')
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 200)

ok=1
printf '%s' "$CLEAN" | grep -qF 'I AM THAT I AM' || { echo "FAIL  HH2b: 'I AM THAT I AM' not on serial — the ring-3 LA process did not run in its own PML4 (bad process page tables, high LSTAR, or CR3/iretq) (rc=$RC, got: $seen)"; ok=0; }
[ "$RC" -eq 33 ] || { echo "FAIL  HH2b: exit code != 33 (got $RC — a fault entering/running the process, or the high-kernel syscall path)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  HH2b slice: a ring-3 LA PROCESS in its own address space — the kernel runs in the shared high half (PML4[511]); a per-process PML4 maps the LA image + heap + stack in its OWN user low half and shares the kernel (supervisor) in the high half; CR3 selects it and the LA image runs at ring 3, its write/exit syscalls serviced by the HIGH kernel (ring3-low -> ring0-high -> ring3). The process model: an isolated address space per LA process. Next: two such processes exchanging a typed message through the shared kernel channel."
[ "$ok" -eq 1 ]
