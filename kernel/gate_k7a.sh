#!/usr/bin/env bash
# LogOS kernel K7a slice gate — the sovereign boot sector boots (no GRUB).
# Boot the raw disk image (its own MBR, NOT QEMU -kernel) and assert:
#   - "K7 real"  on serial — LogOS's own 512-byte boot sector ran in real mode
#     (the BIOS loaded sector 0 at 0x7C00 and jumped to it), no GRUB/multiboot;
#   - "K7 pmode" on serial — it built a GDT and entered 32-bit protected mode,
#     announcing from there (the real->protected transition our own code drives);
#   - exit code 33 — it reached isa-debug-exit from protected mode.
# This is the sovereign boot chain: LogOS boots itself. (K7b loads the kernel
# image from disk and hands off in the 32-bit state boot.asm expects.) Skips
# (rc 0) if QEMU is absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  K7a sovereign-boot gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_k7a.sh >/dev/null 2>&1 || { echo "FAIL  K7a gate: build_k7a.sh failed"; exit 1; }

OUT=$(timeout 20 qemu-system-x86_64 \
        -drive file=kernel/k7disk.img,format=raw,if=ide -m 64 \
        -serial stdio -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown 2>/dev/null)
RC=$?
CLEAN=$(printf '%s' "$OUT" | tr -d '\0')
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 200)

ok=1
printf '%s' "$CLEAN" | grep -qF 'K7 real'  || { echo "FAIL  K7a: 'K7 real' not on serial — the boot sector did not run in real mode (bad MBR / signature) (rc=$RC, got: $seen)"; ok=0; }
printf '%s' "$CLEAN" | grep -qF 'K7 pmode' || { echo "FAIL  K7a: 'K7 pmode' not on serial — the real->protected mode transition failed (rc=$RC, got: $seen)"; ok=0; }
[ "$RC" -eq 33 ] || { echo "FAIL  K7a: exit code != 33 (got $RC)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  K7a slice: the sovereign boot sector — LogOS's OWN 512-byte MBR (no GRUB, no multiboot, no QEMU -kernel) ran from a raw disk in real mode, built a GDT, and entered 32-bit protected mode, announcing from each ('K7 real' + 'K7 pmode'), then exit(33). LogOS boots itself; K7b loads the kernel image from disk next."
[ "$ok" -eq 1 ]
