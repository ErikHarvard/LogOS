#!/usr/bin/env bash
# LogOS HAL.3 gate — an ATA disk driver in Lingua Adamica reads real disk data.
# Attach a data disk seeded with a known signature at LBA 1, boot the ATA-read
# kernel, and assert the LA driver read it back off the metal:
#   - "ata:"               — the driver started;
#   - "LOGOS-DISK-OK-HAL3" — it issued READ SECTORS on the primary IDE bus,
#                            polled for DRQ, drained the 512-byte sector via
#                            32-bit inl reads, and reconstructed the bytes;
#   - "ata done"           — it finished;
#   - exit 33              — clean exit via isa-debug-exit.
# So: the HAL.1 port-I/O primitives let an LA program at ring 0 drive a real
# disk (ATA PIO on 0x1F0-0x1F7) — the same sequence K7b's bootloader proved,
# now a driver in the language itself. The kernel has persistent storage it
# drives on its own. Skips (rc 0) if QEMU is absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  HAL.3 ATA gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_hal3.sh >/dev/null 2>&1 || { echo "FAIL  HAL.3 gate: build_hal3.sh failed"; exit 1; }

OUT=$(timeout 30 qemu-system-x86_64 \
        -kernel kernel/kernel_hal3.elf \
        -drive file=kernel/hal3disk.img,format=raw,if=ide -m 256 \
        -serial stdio -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown 2>/dev/null)
RC=$?
CLEAN=$(printf '%s' "$OUT" | tr -d '\0')
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 240)

ok=1
for tok in 'ata:' 'LOGOS-DISK-OK-HAL3' 'ata done'; do
    printf '%s' "$CLEAN" | grep -qF "$tok" || { echo "FAIL  HAL.3: '$tok' not on serial (rc=$RC, got: $seen)"; ok=0; }
done
[ "$RC" -eq 33 ] || { echo "FAIL  HAL.3: exit code != 33 (got $RC; got: $seen)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  HAL.3: ATA disk read in Lingua Adamica — on the HAL.1 port-I/O primitives (outb/inb/inl), an LA program at ring 0 issued READ SECTORS on the primary IDE bus, polled for DRQ, drained a 512-byte sector via 32-bit reads, and recovered the on-disk signature. The kernel drives real persistent storage itself, driver written in the language (K7b's ATA-PIO, now a driver)."
[ "$ok" -eq 1 ]
