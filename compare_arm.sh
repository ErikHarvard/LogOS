#!/bin/sh
# compare_arm.sh <ARM> — does asm.la encode this arm's equ sites as nasm does?
#
# ★ THE SECTION NAME IS NOT GUESSED. This fixture has NO .text: the code lives
#   in .boot32 (+ .multiboot, .rodata, .la_image). A .text-keyed comparison
#   extracts an empty file on BOTH sides and two empty files compare EQUAL —
#   a vacuous pass on a section that does not exist. So the section set is
#   ENUMERATED FROM THE OBJECT, and a mismatch in the set is itself a finding.
# ★ Sections are compared, never raw object bytes: the .symtab FILE symbol
#   carries the input's path, so a whole-object cmp reports a spurious
#   difference driven purely by filename length.
set -e
ARM="$1"; D="$HOME/logos-b/.bootelf_$ARM"
cd "$D" 2>/dev/null || { echo "FAIL $ARM: no run directory"; exit 1; }
for f in elfobj_out.o nasm_ref.o nasm_ref.lst; do
  [ -s "$f" ] || { echo "FAIL $ARM: $f missing/empty — refusing to compare"; exit 1; }
done
echo "=== $ARM ==============================================="

progbits() { readelf -SW "$1" | sed -n 's/.*\] \(\.[a-zA-Z0-9_.]*\) *PROGBITS.*/\1/p' | sort; }
progbits nasm_ref.o  > nasm.secs
progbits elfobj_out.o > ours.secs
[ -s nasm.secs ] || { echo "  FAIL: nasm object has NO PROGBITS sections — nothing to compare"; exit 1; }
echo "  sections (nasm): $(tr '\n' ' ' < nasm.secs)"
if cmp -s nasm.secs ours.secs; then
  echo "  PASS section set identical"
else
  echo "  FAIL section set differs — ours: $(tr '\n' ' ' < ours.secs)"
fi

# --- concatenate every PROGBITS section, in a fixed order, from each side ----
: > ours.bytes; : > nasm.bytes
while read -r s; do
  objcopy -O binary --only-section="$s" nasm_ref.o  "n.$s.bin" 2>/dev/null || true
  objcopy -O binary --only-section="$s" elfobj_out.o "o.$s.bin" 2>/dev/null || true
  nb=$(stat -c%s "n.$s.bin" 2>/dev/null || echo 0); ob=$(stat -c%s "o.$s.bin" 2>/dev/null || echo 0)
  if [ "$nb" -eq 0 ]; then echo "  NOTE $s: nasm side empty, skipping"; continue; fi
  cat "n.$s.bin" >> nasm.bytes; cat "o.$s.bin" >> ours.bytes
  # ★ MASK RELOCATED FIELDS BEFORE COMPARING. nasm zeroes a relocated field and
  # carries the value in the RELA addend; asm.la writes it inline. The linker
  # overwrites with S+A either way, so a raw compare accuses asm.la of a defect
  # it does not have -- asmelfobj.la's header says the gate is ld(ours)==ld(nasm),
  # not byte-identity of the .o. Raw compare found 19 "differences" in .boot32
  # and 65 in .rodata; ALL 19 fell inside relocation fields.
  nr=$(python3 "$HOME/logos-b/maskrel.py" nasm_ref.o   "$s" "n.$s.bin" "nm.$s.bin") || { echo "  FAIL $s: masking refused"; fail=1; continue; }
  python3 "$HOME/logos-b/maskrel.py" elfobj_out.o "$s" "o.$s.bin" "om.$s.bin" >/dev/null || { echo "  FAIL $s: masking refused"; continue; }
  if cmp -s "nm.$s.bin" "om.$s.bin"; then
    echo "  PASS $s byte-identical to nasm outside $nr relocated field(s) ($nb B)"
  else
    echo "  FAIL $s differs OUTSIDE relocated fields: $(cmp "om.$s.bin" "nm.$s.bin" 2>&1 | head -1)"
  fi
done < nasm.secs
[ -s nasm.bytes ] || { echo "  FAIL: every section extract was empty — refusing to conclude"; exit 1; }

# --- relocation tables are the semantic content of an object -----------------
readelf -rW nasm_ref.o   | awk 'NF>3 && $1 ~ /^[0-9a-f]+$/ {print $1,$3,$5,$6,$7}' | sort > n.rel
readelf -rW elfobj_out.o | awk 'NF>3 && $1 ~ /^[0-9a-f]+$/ {print $1,$3,$5,$6,$7}' | sort > o.rel
if [ ! -s n.rel ]; then echo "  NOTE no relocations in this object"
elif cmp -s n.rel o.rel; then echo "  PASS relocation tables identical ($(wc -l < n.rel) entries: offset, type, symbol, addend)"
else echo "  FAIL relocation tables differ"; diff n.rel o.rel | head -6 | sed 's/^/        /'; fi

# --- the three sites, by raw byte pattern: 41 B9 imm32 (5B) ------------------
oh=$(xxd -p ours.bytes | tr -d '\n'); nh=$(xxd -p nasm.bytes | tr -d '\n')
case "$ARM" in
  HH1)  SITES="hh_msg_len:41b904000000" ;;
  HH2)  SITES="hh2_ok_len:41b917000000 hh2_bad_len:41b918000000" ;;
  NONE) SITES="" ; echo "  (NONE: all three sites compiled out — no site expected)" ;;
esac
for s in $SITES; do
  sym=${s%%:*}; pat=${s##*:}
  nc=$(printf '%s' "$nh" | grep -o "$pat" | wc -l)
  oc=$(printf '%s' "$oh" | grep -o "$pat" | wc -l)
  if [ "$nc" -eq 0 ]; then
    echo "  FAIL $sym: pattern absent from NASM's OWN bytes — the expectation is wrong, not asm.la"
  elif [ "$oc" -eq "$nc" ]; then
    echo "  PASS $sym  $pat  = mov r9d,imm32 (5 B)  ours=$oc nasm=$nc"
  else
    echo "  FAIL $sym  ours=$oc nasm=$nc occurrences of $pat"
  fi
done
# the 10-byte defect form must appear in neither
for bad in 49b904000000000000 49b917000000000000 49b918000000000000; do
  ob=$(printf '%s' "$oh" | grep -o "$bad" | wc -l)
  [ "$ob" -eq 0 ] || echo "  FAIL: 10-byte defect form $bad present in ours ($ob x)"
done
