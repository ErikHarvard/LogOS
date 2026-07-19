#!/usr/bin/env bash
# LogOS HAL.4f — build the bootable TYPEWRITER (comp_term.la).
#   comp_term.la --(native_codegen3)--> native_codegen3_out --> kernel_comp_term.elf
#   Same pipeline as HAL.4e's build_hal4e.sh: boot.asm with -D HAL4
#   (identity-maps 0..4 GiB) for the high VGA LFB BAR + the 256 MiB backbuffer at
#   0x10000000. Uses HAL.4b fill/memcpy + HAL.1 inb/outl/inl/outw + peek — all
#   already regen'd into the compiler, so NO new builtin and NO regen.
#
#   OUT OF BAND, like every heavy kernel ELF: native_codegen3's codegen is
#   superlinear in program size, so expect a LONG compile (HAL.4d's
#   comp_session.la was ~13 min and comp_term.la is comparable). The gate boots
#   the already-built ELF; it never rebuilds.
#
#   Run the cheap pre-flights FIRST — they cost seconds and this costs a quarter
#   hour:  ./tiny_host kernel/keymap_test.la   (the scancode decode, host-side)
set -euo pipefail
cd "$(dirname "$0")/.."          # -> the worktree root

echo "[1/4] compile comp_term.la via native_codegen3 (slow — superlinear codegen)"
cp kernel/comp_term.la native_input.la
time ./tiny_host native_codegen3.la >/dev/null
ENTRY=$(readelf -h native_codegen3_out | awk '/Entry point/{print $NF}')
echo "      e_entry (LA prol) = $ENTRY"

echo "[2/4] generate entry.inc"
printf 'LA_ENTRY equ %s\n' "$ENTRY" > kernel/entry.inc

echo "[3/4] assemble boot.asm (-D HAL4: identity-map 0..4 GiB)"
nasm -f elf64 -D HAL4 -i kernel/ kernel/boot.asm -o kernel/boot.o

echo "[4/4] link -> kernel_comp_term.elf (elf64 -> elf32-i386 container)"
ld -n -T kernel/kernel.ld kernel/boot.o -o kernel/kernel_comp_term_64.elf
objcopy -O elf32-i386 kernel/kernel_comp_term_64.elf kernel/kernel_comp_term.elf

echo "OK: kernel/kernel_comp_term.elf"
echo "HAL4F_BUILD_DONE"
