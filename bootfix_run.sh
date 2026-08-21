#!/bin/bash
# Full boot fixture through the PATCHED asm.la, all three arms.
set -u
B="$HOME/logos-b"; F="$B/.bootfix"
cd "$F"
{
echo "[1/4] emit the VM"; s=$(date +%s)
./tiny_host secd.la >/dev/null 2>&1
echo "  logos_secd $(stat -c%s logos_secd 2>/dev/null) B in $(( $(date +%s)-s ))s"
echo "[2/4] flatten (PATCHED asm.la)"
python3 la_flatten.py asmelfobj.la logos_source.la asm.la:A_ elfobj.la:E_ \
  && echo "  logos_source.la $(stat -c%s logos_source.la) B"
echo "[3/4] codegen"; s=$(date +%s)
./tiny_host codegen.la >/dev/null 2>&1
echo "  logos_program.bin $(stat -c%s logos_program.bin 2>/dev/null) B in $(( $(date +%s)-s ))s"
[ -s logos_program.bin ] || { echo "FAIL: codegen produced nothing"; exit 1; }
echo "[4/4] assemble all three arms concurrently"
for ARM in NONE HH1 HH2; do
  D="$B/.bootfix_$ARM"; rm -rf "$D"; mkdir -p "$D"
  cp "$F"/* "$D"/ 2>/dev/null; rm -f "$D"/asm_in_*.asm "$D"/elfobj_out.o
  case $ARM in NONE) cp "$F/asm_in.asm" "$D/asm_in.asm";; *) cp "$F/asm_in_$ARM.asm" "$D/asm_in.asm";; esac
  for dep in entry.inc idt.asm timer.asm kbdirq.asm native_codegen3_out; do
    [ -s "$D/$dep" ] || { echo "FAIL $ARM: dep $dep missing"; exit 1; }
  done
  ( cd "$D"; nasm -f elf64 asm_in.asm -o nasm_ref.o 2>/dev/null || { echo "$ARM: nasm refused" > nasm.fail; exit 1; }
    t=$(date +%s); ./logos_secd >/dev/null 2>&1
    echo "  $ARM elfobj_out.o $(stat -c%s elfobj_out.o 2>/dev/null) B in $(( $(date +%s)-t ))s" ) &
done
wait
echo "BOOTFIX_DONE $(date +%H:%M:%S)"
} 2>&1
