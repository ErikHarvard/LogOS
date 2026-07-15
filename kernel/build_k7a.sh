#!/usr/bin/env bash
# LogOS kernel K7a slice — build the sovereign boot sector + a bootable raw disk.
#   boot7.asm --(nasm -f bin)--> boot7.bin, a 512-byte MBR (0x55AA signature).
#   Written to sector 0 of a raw disk image the BIOS boots directly — no GRUB,
#   no multiboot, no QEMU -kernel. It goes real-mode -> 32-bit protected mode,
#   announcing from each, proving LogOS's own boot chain + the mode transition.
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos

echo "[1/2] assemble boot7.asm -> boot7.bin (512-byte MBR)"
nasm -f bin kernel/boot7.asm -o kernel/boot7.bin
SZ=$(stat -c%s kernel/boot7.bin)
[ "$SZ" -eq 512 ] || { echo "FAIL K7a: boot7.bin is $SZ bytes, not 512"; exit 1; }

echo "[2/2] lay it into sector 0 of a 1 MiB raw disk image"
dd if=/dev/zero of=kernel/k7disk.img bs=1M count=1 status=none
dd if=kernel/boot7.bin of=kernel/k7disk.img conv=notrunc status=none

echo "OK: kernel/k7disk.img (bootable MBR)"
