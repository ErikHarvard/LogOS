#!/usr/bin/env bash
# LogOS HAL.3b gate — an ATA disk-WRITE driver in Lingua Adamica persists data
# to real storage. Attach a BLANK data disk, boot the write kernel, and assert
# the LA driver wrote it off the metal — two independent ways:
#   SERIAL (the driver's own round-trip):
#     - "ata3b:"                  — the driver started;
#     - "ata write done"          — it issued WRITE SECTORS + CACHE FLUSH;
#     - "LOGOS-WROTE-THIS-HAL3B"  — it read LBA 2 back and echoed the signature;
#     - "ata3b done" + exit 33.
#   DISK FILE (independent proof the write reached the backing store):
#     - byte offset 1024 (= LBA 2 * 512) of hal3bdisk.img holds the signature,
#       though the disk was seeded all-zero — so the bytes came from the driver.
# So: on the HAL.1 port-I/O primitives, an LA program at ring 0 wrote a 512-byte
# sector via ATA PIO (128 outl to the data port) + cache-flush, and it landed on
# disk. The kernel persists to storage it drives itself. Skips (rc 0) if QEMU
# is absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  HAL.3b ATA-write gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_hal3b.sh >/dev/null 2>&1 || { echo "FAIL  HAL.3b gate: build_hal3b.sh failed"; exit 1; }

OUT=$(timeout 30 qemu-system-x86_64 \
        -kernel kernel/kernel_hal3b.elf \
        -drive file=kernel/hal3bdisk.img,format=raw,if=ide -m 256 \
        -serial stdio -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown 2>/dev/null)
RC=$?
CLEAN=$(printf '%s' "$OUT" | tr -d '\0')
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 240)

ok=1
for tok in 'ata3b:' 'ata write done' 'LOGOS-WROTE-THIS-HAL3B' 'ata3b done'; do
    printf '%s' "$CLEAN" | grep -qF "$tok" || { echo "FAIL  HAL.3b: '$tok' not on serial (rc=$RC, got: $seen)"; ok=0; }
done
[ "$RC" -eq 33 ] || { echo "FAIL  HAL.3b: exit code != 33 (got $RC; got: $seen)"; ok=0; }

# Independent proof: the signature is on the DISK FILE at LBA 2 (offset 1024),
# though the image was seeded all-zero.
ONDISK=$(dd if=kernel/hal3bdisk.img bs=1 skip=1024 count=22 status=none 2>/dev/null)
if [ "$ONDISK" = "LOGOS-WROTE-THIS-HAL3B" ]; then
    echo "      disk file @LBA2 (offset 1024) = '$ONDISK' (was all-zero — the driver's write persisted)"
else
    echo "FAIL  HAL.3b: disk file @offset 1024 = '$ONDISK', expected 'LOGOS-WROTE-THIS-HAL3B' (write did not persist)"; ok=0
fi

[ "$ok" -eq 1 ] && echo "PASS  HAL.3b: ATA disk WRITE in Lingua Adamica — on the HAL.1 port-I/O primitives, an LA program at ring 0 issued WRITE SECTORS on the primary IDE bus, pushed a 512-byte sector via 128 32-bit outl writes to the data port, cache-flushed it, and read it back — and the signature is on the disk FILE at LBA 2 though it was seeded all-zero. The kernel persists data to storage it drives itself, driver written in the language (the write-twin of HAL.3's read)."
[ "$ok" -eq 1 ]
