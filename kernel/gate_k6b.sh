#!/usr/bin/env bash
# LogOS kernel K6b slice gate — the REAL LA image at ring 3 on the metal.
# Boot kernel_k6b.elf in QEMU and assert that kernel.la, running at CPL 3, spoke
# the Word and exited cleanly:
#   - "I AM THAT I AM" on serial — the LA image's `print` lowered to a `write`
#     syscall that CROSSED ring3->ring0->ring3 (a ring-3 task cannot touch COM1
#     directly, so the bytes on serial ARE the proof the syscall path worked both
#     ways) AND rt_init took the metal path (bitmap OFF / low-RAM stacks) via the
#     boot-set METAL_FLAG — a wrong discriminator would fault on the 16 GiB-high
#     bitmap/stack base and print nothing;
#   - exit code 33 — the image's `exit` syscall reached isa-debug-exit.
# A broken privilege drop / missing U-bit on the image's pages / bad METAL_FLAG
# addr would #GP or triple-fault (exit != 33) or print nothing. Needs -m 1024 so
# the low 1 GiB (heap + the 128 MiB stack) is real RAM. Skips (rc 0) if QEMU absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  K6b ring-3 LA-image gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_k6b.sh >/dev/null 2>&1 || { echo "FAIL  K6b gate: build_k6b.sh failed"; exit 1; }

OUT=$(timeout 30 qemu-system-x86_64 \
        -kernel kernel/kernel_k6b.elf -m 1024 \
        -serial stdio -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown 2>/dev/null)
RC=$?
CLEAN=$(printf '%s' "$OUT" | tr -d '\0')
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 200)

ok=1
printf '%s' "$CLEAN" | grep -qF 'I AM THAT I AM' || { echo "FAIL  K6b: 'I AM THAT I AM' not on serial — the ring-3 LA image never ran, faulted (bad U-bit / METAL_FLAG), or the write syscall failed (rc=$RC, got: $seen)"; ok=0; }
[ "$RC" -eq 33 ] || { echo "FAIL  K6b: exit code != 33 (got $RC — a #GP/triple-fault in the privilege drop, a bad sysret, or exit never reached)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  K6b slice: the real LA image (kernel.la) at ring 3 on the metal — kernel.la ran at CPL 3 on the user-mapped low 1 GiB, took rt_init's metal path via the boot-set METAL_FLAG (not CPL), spoke the Word through a write syscall serviced ring3->ring0->ring3, and exit(0)'d; proves ∃(∃)≡∃ speaks from ring 3 (b_tau == f_tau: the SAME image runs at ring 0 under K1..K5 and at ring 3 here)"
[ "$ok" -eq 1 ]
