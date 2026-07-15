#!/usr/bin/env bash
# LogOS kernel K7b gate — LogOS boots ITSELF end-to-end (no GRUB).
# Boot the raw disk image (its own MBR + stage-2 loader, NOT QEMU -kernel) and
# assert the whole sovereign chain fired:
#   - "K7 real"    — the MBR ran in real mode (BIOS loaded sector 0);
#   - "K7 stage2"  — the MBR read stage 2 off disk (int 0x13) and jumped to it;
#   - "K7 pmode"   — stage 2 enabled A20, built a GDT, entered protected mode;
#   - "K7 handoff" — stage 2 ATA-PIO-loaded the kernel image from disk and set
#                    up the multiboot handoff;
#   - "I AM THAT I AM" — the handed-off kernel brought up long mode + the
#                    syscall substrate and the LA image SPOKE THE WORD;
#   - exit code 33 — it reached exit(33) via isa-debug-exit.
# So: LogOS's own bytes, off its own disk, booted the whole kernel. K1..K7.
# Skips (rc 0) if QEMU is absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  K7b sovereign-boot gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_k7b.sh >/dev/null 2>&1 || { echo "FAIL  K7b gate: build_k7b.sh failed"; exit 1; }

OUT=$(timeout 40 qemu-system-x86_64 \
        -drive file=kernel/k7bdisk.img,format=raw,if=ide -m 256 \
        -serial stdio -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown 2>/dev/null)
RC=$?
CLEAN=$(printf '%s' "$OUT" | tr -d '\0')
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 240)

ok=1
for tok in 'K7 real' 'K7 stage2' 'K7 pmode' 'K7 handoff' 'I AM THAT I AM'; do
    printf '%s' "$CLEAN" | grep -qF "$tok" || { echo "FAIL  K7b: '$tok' not on serial (rc=$RC, got: $seen)"; ok=0; }
done
[ "$RC" -eq 33 ] || { echo "FAIL  K7b: exit code != 33 (got $RC; got: $seen)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  K7b: the sovereign boot — LogOS's OWN MBR + stage-2 loader (no GRUB, no multiboot loader, no QEMU -kernel) booted from a raw disk, read the kernel image's segments off disk via ATA-PIO into their physical addresses, handed off to _start, and the LA image spoke 'I AM THAT I AM' + exit(33). LogOS boots itself, K1..K7 complete."
[ "$ok" -eq 1 ]
