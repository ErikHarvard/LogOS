#!/usr/bin/env bash
# LogOS kernel K6c.3b slice — build the ring-3 two-LA-task typed-IPC probe ELF.
#   ipc2.la --(native_codegen3, with the new send/recv builtins)--> the LA
#     image @0x400000, incbin'd into the kernel ELF exactly as K6b does.
#   boot.asm -dK6C3: same ring-3 LA-image entry as K6b (LA_RING3_IMAGE — user-map
#     the low 1 GiB, set METAL_FLAG, TSS, iretq to LA_ENTRY at CPL 3) PLUS the IPC
#     channel layer (%ifdef IPC: k6c_chans + the send/recv syscall dispatch). The
#     LA image's send(0)(msg)/recv(0) lower to SYS_SEND(0x300)/SYS_RECV(0x301),
#     which the kernel services against channel 0 and sysrets back to ring 3.
# Separate output (kernel_k6c3b.elf); every other kernel ELF stays byte-identical.
#
# DRIFT GUARD: like build_k6b.sh, derive the LA runtime's METAL_FLAG slot address
# from the fresh rt listing and thread it through entry.inc (never a stale const).
# Shares native_input.la / entry.inc with build.sh — run SEQUENTIALLY.
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos

echo "[1/5] derive METAL_FLAG_ABS from the rt listing (its file offset + 0x400078)"
nasm -f bin native_codegen3_rt.asm -o /tmp/k6c3b_rt.bin -l /tmp/k6c3b_rt.lst
OFF=$(awk '/ METAL_FLAG: dq/{print $2; exit}' /tmp/k6c3b_rt.lst)
[ -n "$OFF" ] || { echo "FAIL K6c3 build: no METAL_FLAG label in rt listing"; exit 1; }
METAL_ABS=$(( 0x400078 + 0x$OFF ))
printf '      METAL_FLAG @ 0x%x (%d)\n' "$METAL_ABS" "$METAL_ABS"

echo "[2/5] compile ipc2.la via native_codegen3 (the LA IPC program)"
cp kernel/ipc2.la native_input.la
( if [ -x native_codegen3_selfhost.bin ]; then cp native_codegen3_selfhost.bin /tmp/_ncc$$ && chmod +x /tmp/_ncc$$ && /tmp/_ncc$$; rc=$?; rm -f /tmp/_ncc$$; exit $rc; else ./tiny_host native_codegen3.la; fi; ) >/dev/null
ENTRY=$(readelf -h native_codegen3_out | awk '/Entry point/{print $NF}')
echo "      e_entry (LA prol) = $ENTRY"

echo "[3/5] generate entry.inc (LA_ENTRY + METAL_FLAG_ABS)"
{ printf 'LA_ENTRY equ %s\n' "$ENTRY"
  printf 'METAL_FLAG_ABS equ 0x%x\n' "$METAL_ABS"; } > kernel/entry.inc

echo "[4/5] assemble boot.asm -dK6C3, link (elf64)"
nasm -f elf64 -dK6C3 -i kernel/ kernel/boot.asm -o kernel/boot_k6c3b.o
ld -n -T kernel/kernel.ld kernel/boot_k6c3b.o -o kernel/kernel_k6c3b_64.elf

echo "[5/5] repackage as elf32-i386 (multiboot1)"
objcopy -O elf32-i386 kernel/kernel_k6c3b_64.elf kernel/kernel_k6c3b.elf

echo "OK: kernel/kernel_k6c3b.elf"
