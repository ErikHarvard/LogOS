#!/usr/bin/env bash
# LogOS kernel K7b — build the sovereign, self-booting disk image.
#
#   kernel.la --(build_k1.sh)--> kernel64.elf   (multiboot ELF, 2 PT_LOADs)
#   segment bytes --(dd from the ELF's program headers)--> boot_seg.bin / la_seg.bin
#   boot7b_s2.asm --(nasm -f bin, -D geometry)--> boot7b_s2.bin  (stage 2 loader)
#   boot7b.asm    --(nasm -f bin, -D STAGE2_*)--> boot7b.bin     (512-byte MBR)
#   dd everything onto k7bdisk.img at fixed LBAs.
#
# The MBR + stage 2 read the kernel's two segments off this disk into their
# physical addresses and jump to boot.asm's _start — LogOS boots itself, no
# GRUB. All geometry is DERIVED from the linked ELF, so the loader can never
# drift from the image on the disk.
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos

ELF=kernel/kernel64.elf
MBI_ADDR=0x5000                  # where stage 2 writes the multiboot info struct
MEM_UPPER_KB=261120              # 256 MiB - 1 MiB, matches the gate's -m 256
BOOTPHYS=0x100000
LAPHYS=0x400000

echo "[1/6] build the multiboot kernel ELF (build_k1.sh)"
./kernel/build_k1.sh >/dev/null

# --- read the two PT_LOAD program headers from the ELF ---
# `readelf -lW` LOAD line: LOAD <FileOff> <VirtAddr> <PhysAddr> <FileSiz> <MemSiz> <Flg> <Align>
# (all hex with 0x prefix). awk selects the fields; bash converts hex -> decimal.
echo "[2/6] read PT_LOAD geometry from $ELF"
read_seg() {  # $1 = PhysAddr (decimal) to match -> prints "FileOff FileSiz MemSiz" (decimal)
    local want=$1 off pa fsz msz
    while read -r off pa fsz msz; do
        [ $(( off )) -ge 0 ] 2>/dev/null || continue
        if [ $(( pa )) -eq "$want" ]; then
            echo "$(( off )) $(( fsz )) $(( msz ))"
            return 0
        fi
    done < <(readelf -lW "$ELF" | awk '$1=="LOAD"{print $2, $4, $5, $6}')
    echo "FAIL K7b: no PT_LOAD at phys $want in $ELF" >&2
    return 1
}
read BOOT_OFF BOOT_FSZ BOOT_MSZ  < <(read_seg $((BOOTPHYS)))
read LA_OFF   LA_FSZ   LA_MSZ    < <(read_seg $((LAPHYS)))
echo "      .boot     off=$BOOT_OFF filesz=$BOOT_FSZ memsz=$BOOT_MSZ"
echo "      .la_image off=$LA_OFF filesz=$LA_FSZ memsz=$LA_MSZ"

# --- carve the raw segment bytes straight out of the ELF file ---
echo "[3/6] extract segment images"
dd if="$ELF" of=kernel/boot_seg.bin bs=1 skip="$BOOT_OFF" count="$BOOT_FSZ" status=none
dd if="$ELF" of=kernel/la_seg.bin   bs=1 skip="$LA_OFF"   count="$LA_FSZ"   status=none

ceil_sectors() { echo $(( ($1 + 511) / 512 )); }
BOOT_SECTORS=$(ceil_sectors "$BOOT_FSZ")
LA_SECTORS=$(ceil_sectors "$LA_FSZ")

# --- disk layout (LBAs): 0=MBR, 1..=stage2, then .boot, then .la_image ---
STAGE2_LBA=1
# assemble stage 2 once to learn its size (immediates are 32-bit so the size is
# independent of the LBA values we feed — a second assemble won't change it).
nasm -f bin kernel/boot7b_s2.asm -o kernel/boot7b_s2.bin \
    -D BOOTPHYS=$BOOTPHYS -D LAPHYS=$LAPHYS \
    -D BOOTMEMSZ=$BOOT_MSZ \
    -D BOOT_LBA=0 -D BOOT_SECTORS=$BOOT_SECTORS \
    -D LA_LBA=0   -D LA_SECTORS=$LA_SECTORS \
    -D MBI_ADDR=$MBI_ADDR -D MEM_UPPER_KB=$MEM_UPPER_KB
STAGE2_SECTORS=$(ceil_sectors "$(stat -c%s kernel/boot7b_s2.bin)")

BOOT_LBA=$(( STAGE2_LBA + STAGE2_SECTORS ))
LA_LBA=$(( BOOT_LBA + BOOT_SECTORS ))
echo "[4/6] disk LBAs: stage2@$STAGE2_LBA (+$STAGE2_SECTORS) boot@$BOOT_LBA (+$BOOT_SECTORS) la@$LA_LBA (+$LA_SECTORS)"

echo "[5/6] assemble stage 2 (final LBAs) + the MBR"
nasm -f bin kernel/boot7b_s2.asm -o kernel/boot7b_s2.bin \
    -D BOOTPHYS=$BOOTPHYS -D LAPHYS=$LAPHYS \
    -D BOOTMEMSZ=$BOOT_MSZ \
    -D BOOT_LBA=$BOOT_LBA -D BOOT_SECTORS=$BOOT_SECTORS \
    -D LA_LBA=$LA_LBA     -D LA_SECTORS=$LA_SECTORS \
    -D MBI_ADDR=$MBI_ADDR -D MEM_UPPER_KB=$MEM_UPPER_KB
nasm -f bin kernel/boot7b.asm -o kernel/boot7b.bin \
    -D STAGE2_LBA=$STAGE2_LBA -D STAGE2_SECTORS=$STAGE2_SECTORS
SZ=$(stat -c%s kernel/boot7b.bin)
[ "$SZ" -eq 512 ] || { echo "FAIL K7b: boot7b.bin is $SZ bytes, not 512"; exit 1; }

echo "[6/6] compose k7bdisk.img"
dd if=/dev/zero of=kernel/k7bdisk.img bs=1M count=1 status=none
dd if=kernel/boot7b.bin     of=kernel/k7bdisk.img conv=notrunc status=none
dd if=kernel/boot7b_s2.bin  of=kernel/k7bdisk.img conv=notrunc seek=$STAGE2_LBA status=none
dd if=kernel/boot_seg.bin   of=kernel/k7bdisk.img conv=notrunc seek=$BOOT_LBA   status=none
dd if=kernel/la_seg.bin     of=kernel/k7bdisk.img conv=notrunc seek=$LA_LBA     status=none

echo "OK: kernel/k7bdisk.img (sovereign self-booting disk)"
