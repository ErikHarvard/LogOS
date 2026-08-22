#!/bin/sh
# Object-side regression, using gate_asmelf.sh's own methodology:
#   the gate is ld(ours) == ld(nasm) byte-identical, NOT byte-identity of the .o
#   (asmelfobj.la's header says so: an object's internal layout is nasm
#   convention, not semantics). This is the ONLY path that exercises my
#   relocation changes -- RIPXSECRELS and the cursec threading are invisible to
#   the flat -f bin suite.
cd "$HOME/logos-b/.elfreg" || exit 1
pass=0; fail=0
for f in asm_elf_*.asm; do
  n=${f%.asm}
  cp "$f" asm_in.asm; rm -f elfobj_out.o
  if ! timeout 300 ./tiny_host asmelfobj.la > "$n.log" 2>&1 || [ ! -s elfobj_out.o ]; then
    printf 'FAIL  %-16s producer: %s\n' "$n" "$(tail -1 $n.log | cut -c1-48)"; fail=$((fail+1)); continue
  fi
  cp elfobj_out.o "$n.ours.o"
  nasm -f elf64 asm_in.asm -o "$n.ref.o" 2>/dev/null || { printf 'FAIL  %-16s nasm refused\n' "$n"; fail=$((fail+1)); continue; }
  ld "$n.ref.o"  -o "$n.ref.elf"  2>/dev/null || { printf 'SKIP  %-16s ld(nasm) failed — no control\n' "$n"; continue; }
  if ! ld "$n.ours.o" -o "$n.ours.elf" 2>"$n.ld.err"; then
    printf 'FAIL  %-16s ld(ours) failed: %s\n' "$n" "$(head -1 $n.ld.err | cut -c1-44)"; fail=$((fail+1)); continue
  fi
  if cmp -s "$n.ref.elf" "$n.ours.elf"; then
    printf 'PASS  %-16s ld(ours) == ld(nasm), %s B\n' "$n" "$(stat -c%s $n.ours.elf)"; pass=$((pass+1))
  else
    printf 'FAIL  %-16s linked images differ: %s\n' "$n" "$(cmp $n.ref.elf $n.ours.elf 2>&1 | head -1)"; fail=$((fail+1))
  fi
done
echo "----------------------------------------"
echo "OBJECT REGRESSION: $pass PASS / $fail FAIL"
