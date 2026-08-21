#!/bin/bash
# HH2B + HH2C through the doubly-patched asm.la.
# Harness fixes from last night, both earned:
#   - logos_secd output is CAPTURED, never /dev/null. The first HH2B failure
#     destroyed its own diagnostic; the re-run named the cause in one line.
#   - NO `exec > >(tee ...)` with a bare `wait`. That deadlocked overnight.sh:
#     `wait` blocked on the tee, which never exits. Redirect to a file, and
#     wait on EXPLICIT pids.
set -u
B="$HOME/logos-b"; F="$B/.bootfix3"; L="$B/.bootfix3.log"
: > "$L"
say() { echo "[$(date +%H:%M:%S)] $*" >> "$L"; }
cd "$F" || exit 1
say "[1/3] emit the VM"
./tiny_host secd.la > vm.out 2>&1
say "  logos_secd $(stat -c%s logos_secd 2>/dev/null || echo 0) B"
[ -s logos_secd ] || { say "FAIL: no VM"; exit 1; }
say "[2/3] flatten + codegen"
python3 la_flatten.py asmelfobj.la logos_source.la asm.la:A_ elfobj.la:E_ >> "$L" 2>&1
s=$(date +%s); ./tiny_host codegen.la > cg.out 2>&1
say "  logos_program.bin $(stat -c%s logos_program.bin 2>/dev/null || echo 0) B in $(( $(date +%s)-s ))s"
[ -s logos_program.bin ] || { say "FAIL: codegen produced nothing"; tail -3 cg.out >> "$L"; exit 1; }
say "[3/3] HH2B and HH2C concurrently"
pids=""
for ARM in HH2B HH2C; do
  D="$B/.bootfix3_$ARM"; rm -rf "$D"; mkdir -p "$D"
  cp "$F"/* "$D"/ 2>/dev/null; rm -f "$D"/asm_in_*.asm "$D"/elfobj_out.o
  { echo "%define $ARM"; echo "%define METAL_FLAG_ABS 0x400078"; cat "$F/asm_in.asm"; } > "$D/asm_in.asm"
  for dep in entry.inc idt.asm timer.asm kbdirq.asm native_codegen3_out logos_secd logos_program.bin; do
    [ -s "$D/$dep" ] || { say "FAIL $ARM: dep $dep missing"; exit 1; }
  done
  ( cd "$D"
    nasm -f elf64 asm_in.asm -o nasm_ref.o 2>nasm.err || { echo "$ARM: nasm refused: $(head -1 nasm.err)" >> "$L"; exit 1; }
    t=$(date +%s)
    timeout 3000 ./logos_secd > secd.out 2>&1        # CAPTURED, not discarded
    rc=$?
    if [ -s elfobj_out.o ]; then
      echo "  $ARM elfobj_out.o $(stat -c%s elfobj_out.o) B in $(( $(date +%s)-t ))s" >> "$L"
    else
      echo "  $ARM FAILED rc=$rc after $(( $(date +%s)-t ))s: $(tail -1 secd.out)" >> "$L"
    fi ) &
  pids="$pids $!"
done
for p in $pids; do wait "$p"; done      # explicit pids — cannot block on a logger
say "BOOTFIX3_DONE"
