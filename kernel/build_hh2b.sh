#!/usr/bin/env bash
# LogOS kernel HH2b slice — build the ring-3 LA-IMAGE probe ELF.
#   kernel.la --(native_codegen3)--> native_codegen3_out (the LA image @0x400000),
#     incbin'd into the kernel ELF exactly as the K1..K5 metal builds do.
#   boot.asm assembled -dHH2B: after the usual long-mode/syscall setup it makes the
#     identity-mapped low 1 GiB USER (U=1 down the whole walk), writes 1 to the LA
#     runtime's METAL_FLAG slot (so rt_init takes the metal path — bitmap OFF, task
#     stacks in low RAM), sets up the ring-3 GDT selectors + TSS(RSP0), and iretq's
#     to LA_ENTRY at CPL 3. The image's own `print`/`exit` syscalls are serviced by
#     the kernel (write->COM1, exit->isa-debug-exit) and sysret back to ring 3.
# Separate output (kernel_hh2b.elf); every other kernel ELF stays byte-identical
# (all K6b code is %ifdef K6B / %ifdef RING3).
#
# DRIFT GUARD: boot.asm's `mov byte [METAL_FLAG_ABS],1` hard-codes the LA runtime
# data slot's absolute address. A native_codegen3_rt.asm edit can move that slot,
# so we DERIVE it from the fresh rt listing and thread it through entry.inc — it is
# never a stale constant. (rt_init reads the SAME slot via `cmp [rel METAL_FLAG]`.)
#
# Shares native_input.la / entry.inc with build.sh — run SEQUENTIALLY.
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos

echo "[1/5] derive METAL_FLAG_ABS from the rt listing (its file offset + 0x400078)"
nasm -f bin native_codegen3_rt.asm -o /tmp/hh2b_rt.bin -l /tmp/hh2b_rt.lst
OFF=$(awk '/ METAL_FLAG: dq/{print $2; exit}' /tmp/hh2b_rt.lst)
[ -n "$OFF" ] || { echo "FAIL K6b build: no METAL_FLAG label in rt listing (rt.asm edit missing?)"; exit 1; }
METAL_ABS=$(( 0x400078 + 0x$OFF ))
printf '      METAL_FLAG @ 0x%x (%d)\n' "$METAL_ABS" "$METAL_ABS"

echo "[2/5] compile kernel.la via native_codegen3 (the LA image that speaks the Word)"
cp kernel/kernel.la native_input.la
./tiny_host native_codegen3.la >/dev/null
ENTRY=$(readelf -h native_codegen3_out | awk '/Entry point/{print $NF}')
echo "      e_entry (LA prol) = $ENTRY"

echo "[3/5] generate entry.inc (LA_ENTRY + METAL_FLAG_ABS)"
{ printf 'LA_ENTRY equ %s\n' "$ENTRY"
  printf 'METAL_FLAG_ABS equ 0x%x\n' "$METAL_ABS"; } > kernel/entry.inc

echo "[4/5] assemble boot.asm -dHH2B, link (elf64)"
nasm -f elf64 -dHH2B -i kernel/ kernel/boot.asm -o kernel/boot_hh2b.o
ld -n -T kernel/kernel.ld kernel/boot_hh2b.o -o kernel/kernel_hh2b_64.elf

echo "[5/5] repackage as elf32-i386 (multiboot1)"
objcopy -O elf32-i386 kernel/kernel_hh2b_64.elf kernel/kernel_hh2b.elf

echo "OK: kernel/kernel_hh2b.elf"
