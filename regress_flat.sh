#!/bin/sh
# Full asm regression, using the pipeline build.sh ACTUALLY uses:
#   cp <test>.asm asm_in.asm ; ./tiny_host asm.la  ->  asm_out.bin
#   nasm -f bin <test>.asm                         ->  ref.bin
#   cmp
# My first attempt fed these to `-f elf64` through asmelfobj.la and got 6 FAILs
# and 13 SKIPs — every one of them my harness, not the assembler. These are
# FLAT-BINARY tests; asmelfobj.la correctly refuses a source with no `section`,
# and nasm -f elf64 correctly refuses `org`. An instrument that reports failure
# must first be shown to be running the thing under test.
cd "$HOME/logos-b/.regress" || exit 1
pass=0; fail=0; skip=0
for f in asm_test*.asm; do
  b=${f%.asm}
  if ! nasm -f bin "$f" -o "$b.ref.bin" 2>"$b.nasm.err"; then
    printf 'SKIP  %-24s nasm -f bin refuses it: %s\n' "$b" "$(head -1 $b.nasm.err | cut -c1-46)"
    skip=$((skip+1)); continue
  fi
  rm -f asm_out.bin; cp "$f" asm_in.asm
  if ! timeout 300 ./tiny_host asm.la > "$b.out" 2>&1 || [ ! -s asm_out.bin ]; then
    printf 'FAIL  %-24s asm.la produced nothing: %s\n' "$b" "$(tail -1 $b.out | cut -c1-46)"
    fail=$((fail+1)); continue
  fi
  if cmp -s asm_out.bin "$b.ref.bin"; then
    printf 'PASS  %-24s %s B byte-identical\n' "$b" "$(stat -c%s asm_out.bin)"
    pass=$((pass+1))
  else
    printf 'FAIL  %-24s ours=%s nasm=%s  %s\n' "$b" "$(stat -c%s asm_out.bin)" "$(stat -c%s $b.ref.bin)" "$(cmp asm_out.bin $b.ref.bin 2>&1 | head -1)"
    cp asm_out.bin "$b.ours.bin"
    fail=$((fail+1))
  fi
done
echo "----------------------------------------"
echo "REGRESSION: $pass PASS / $fail FAIL / $skip SKIP"
