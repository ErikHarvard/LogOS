#!/usr/bin/env bash
# LogOS kernel HH1b slice — the kernel runs WHOLLY in the higher half.
#   gen_hh_compiler.py -> native_codegen3_hh.la (a kernel-only compiler variant:
#     all address constants rebased to the −2 GiB half via `sub(0)(mag)`, HEAP_SIZE
#     shrunk to the high 1 GiB window, RT blob re-assembled at org 0xFFFFFFFF80400078).
#   kernel.la --(native_codegen3_hh)--> a HIGH LA image (VADDR 0xFFFFFFFF80400000),
#     incbin'd into the kernel ELF at its low physical slot (0x400000); the high map
#     aliases it at 0xFFFFFFFF80400000.
#   boot.asm -dHH1B: builds the high map (HH1_HIGHMAP), jumps high, re-points LSTAR
#     at the HIGH syscall_entry, sets a HIGH stack, DROPS the low identity map, and
#     enters the HIGH LA image — which speaks the Word entirely from the −2 GiB half.
# Separate output (kernel_hh1b.elf); every other kernel ELF stays byte-identical
# (all HH1b code is %ifdef HH1B / %ifdef HH1_HIGHMAP). native_codegen3.la (the
# Stage-4 self-host) is NOT touched. Shares native_input.la — run SEQUENTIALLY.
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos

echo "[1/5] generate the higher-half compiler variant (native_codegen3_hh.la)"
python3 kernel/gen_hh_compiler.py

echo "[2/5] compile kernel.la via native_codegen3_hh -> a HIGH LA image"
cp kernel/kernel.la native_input.la
./tiny_host native_codegen3_hh.la >/dev/null
ENTRY=$(readelf -h native_codegen3_out | awk '/Entry point/{print $NF}')
VA=$(python3 -c "import struct;print(hex(struct.unpack('<Q',open('native_codegen3_out','rb').read()[0x40+16:0x40+24])[0]))")
echo "      e_entry = $ENTRY   p_vaddr = $VA"
case "$ENTRY" in 0xffffffff8*) : ;; *) echo "FAIL HH1b: LA image is not high-based ($ENTRY)"; exit 1;; esac

echo "[3/5] entry.inc (LA_ENTRY = the HIGH e_entry)"
printf 'LA_ENTRY equ %s\n' "$ENTRY" > kernel/entry.inc

echo "[4/5] assemble boot.asm -dHH1B, link (elf64)"
nasm -f elf64 -dHH1B -i kernel/ kernel/boot.asm -o kernel/boot_hh1b.o
ld -n -T kernel/kernel.ld kernel/boot_hh1b.o -o kernel/kernel_hh1b_64.elf

echo "[5/5] repackage as elf32-i386 (multiboot1)"
objcopy -O elf32-i386 kernel/kernel_hh1b_64.elf kernel/kernel_hh1b.elf

echo "OK: kernel/kernel_hh1b.elf"
