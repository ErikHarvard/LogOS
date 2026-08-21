#!/bin/sh
# run_arm.sh <ARM>  — LA-side encoding evidence for one %ifdef arm.
#
# WHY THIS IS NOT THREE FULL CYCLES (A's ~78 min estimate):
#   asmelfobj.la bakes SRCNAME = "asm_in.asm" into the compiled program, so
#   logos_program.bin depends on the input FILENAME, never on its CONTENT.
#   Steps 1-3 (VM + flatten + codegen, ~13 min) are therefore input-independent
#   and are done ONCE by the base cycle. Only step 4 (~14 min) is per-arm, and
#   each arm gets its own directory so the three can run CONCURRENTLY.
#   Cost: 13 + 14 wall-clock, not 3 x 26.
#
# ABSENCE RULE (earned today, four instruments deep): never conclude from what
# is not in an artifact until the artifact is proven to exist and be non-empty.
set -e
ARM="$1"
[ -n "$ARM" ] || { echo "usage: run_arm.sh <HH1|HH2|NONE>"; exit 2; }
B="$HOME/logos-b"; SRC="$B/.bootelf"; D="$B/.bootelf_$ARM"

# --- preconditions, each one fatal rather than skipped ------------------
[ -s "$SRC/logos_program.bin" ] || { echo "FAIL $ARM: logos_program.bin missing/empty — base cycle has not produced it"; exit 1; }
[ -s "$SRC/logos_secd" ]        || { echo "FAIL $ARM: logos_secd missing/empty"; exit 1; }
case "$ARM" in
  NONE) IN="$SRC/asm_in.asm" ;;
  *)    IN="$SRC/asm_in_$ARM.asm" ;;
esac
[ -s "$IN" ] || { echo "FAIL $ARM: input $IN missing/empty"; exit 1; }

rm -rf "$D"; mkdir -p "$D"
# Stage the WHOLE fixture set. asm_in.asm %includes entry.inc/idt.asm/timer.asm/
# kbdirq.asm and incbins native_codegen3_out; staging only asm_in.asm reproduces
# exactly the missing-include failure that made a listing empty upstream today.
cp "$SRC"/* "$D"/ 2>/dev/null
rm -f "$D"/asm_in_*.asm "$D"/elfobj_out.o
cp "$IN" "$D/asm_in.asm"          # name MUST stay asm_in.asm: baked into the program
cd "$D"
for dep in entry.inc idt.asm timer.asm kbdirq.asm native_codegen3_out; do
  [ -s "$dep" ] || { echo "FAIL $ARM: dependency $dep missing/empty in the staged fixture"; exit 1; }
done

# --- nasm control, same source NAME so the FILE symbol matches ----------
nasm -f elf64 -l nasm_ref.lst asm_in.asm -o nasm_ref.o 2>nasm.err || {
  echo "FAIL $ARM: nasm refused the fixture — no control to compare against"; cat nasm.err; exit 1; }
[ -s nasm_ref.lst ] || { echo "FAIL $ARM: nasm listing empty — refusing to read site offsets out of nothing"; exit 1; }
[ -s nasm_ref.o ]   || { echo "FAIL $ARM: nasm object empty"; exit 1; }

echo "[$ARM] assembling with asm.la on the VM (~14 min)  start $(date +%H:%M:%S)"
s=$(date +%s)
./logos_secd > run.out 2>&1 || true
e=$(( $(date +%s) - s ))
[ -s elfobj_out.o ] || { echo "FAIL $ARM: asm.la produced no object after ${e}s"; tail -5 run.out; exit 1; }
echo "[$ARM] elfobj_out.o $(stat -c%s elfobj_out.o) B in ${e}s"
