#!/bin/sh
# gate_link_reloc.sh — link_reloc.la slice 3: relocations applied.
#
# BYTE-IDENTITY IS THE RIGHT GATE HERE, and slices 1-2 deliberately refused it.
# A whole-file diff against ld measures ld's own choices (build-id, section
# ordering, padding). A RELOCATED INSTRUCTION is different in kind: given the
# same addresses the patched bytes are DETERMINED — `call greet` at 0x401001
# targeting 0x401010 has exactly one correct rel32. So each object's patched
# .text is diffed byte-for-byte against ld's.
#
# The 2-byte alignment gap between the objects is NOT compared, and that is
# stated here rather than hidden: ld fills it with a 2-byte nop (66 90), this
# pads with single-byte nops (90 90). Both correct, neither reachable. Every
# other byte must match exactly.
set -e
cd "$(dirname "$0")"
ok=1

for t in nasm ld objcopy; do
    command -v $t >/dev/null 2>&1 || { echo "SKIP  link_reloc gate: $t absent"; exit 0; }
done

nasm -f elf64 link_test_a.asm -o link_test_a.o
nasm -f elf64 link_test_b.asm -o link_test_b.o
ld -o link_ref link_test_a.o link_test_b.o
objcopy -O binary --only-section=.text link_ref ldtext.bin

cp link_test_a.o link_in1.o
cp link_test_b.o link_in2.o
rm -f link_text.bin
OUT=$(timeout 240 ./tiny_host link_reloc.la 2>&1) || {
    echo "FAIL  link_reloc.la: crashed or timed out"; echo "$OUT"; exit 1; }
[ -f link_text.bin ] || { echo "FAIL  link_reloc.la: wrote no link_text.bin"; exit 1; }

# --- the merged .text must be exactly as long as ld's ---
ours=$(stat -c%s link_text.bin); theirs=$(stat -c%s ldtext.bin)
[ "$ours" = "$theirs" ] || { echo "FAIL  link_reloc.la: merged .text $ours bytes, ld's $theirs"; ok=0; }

# --- object A's patched span: R_X86_64_PC32, the relative kind ---
#   Sizes come from the objects themselves, so the gate cannot drift from the
#   fixtures the way a hard-coded 14/16/28 would.
asize=$(readelf -S --wide link_test_a.o | sed -n 's/^  \[ *[0-9]\+\] \.text \+PROGBITS \+[0-9a-f]\+ \+[0-9a-f]\+ \+\([0-9a-f]\+\).*/\1/p')
asize=$(printf '%d' "0x$asize")
cmp -n "$asize" link_text.bin ldtext.bin \
    || { echo "FAIL  link_reloc.la: object A's patched .text differs from ld's"; ok=0; }

# --- object B's patched span: R_X86_64_64, the absolute kind ---
#   B starts at the 16-byte-aligned offset after A, which is where the gap ends.
bstart=$(( (asize + 15) / 16 * 16 ))
OB=$(mktemp); LB=$(mktemp)
dd if=link_text.bin bs=1 skip=$bstart of="$OB" 2>/dev/null
dd if=ldtext.bin    bs=1 skip=$bstart of="$LB" 2>/dev/null
cmp "$OB" "$LB" || { echo "FAIL  link_reloc.la: object B's patched .text differs from ld's"; ok=0; }
rm -f "$OB" "$LB"

# --- name the two relocation kinds explicitly, so a regression says WHICH ---
#   PC32 is the one with nowhere to hide: it depends on P, the address of the
#   patch site, which only the layout supplies. An absolute relocation can be
#   right while a relative one is wrong.
pc32=$(dd if=link_text.bin bs=1 skip=1 count=4 2>/dev/null | xxd -p)
pc32ld=$(dd if=ldtext.bin bs=1 skip=1 count=4 2>/dev/null | xxd -p)
[ "$pc32" = "$pc32ld" ] || { echo "FAIL  link_reloc.la: PC32 rel32 is $pc32, ld says $pc32ld"; ok=0; }

abs64=$(dd if=link_text.bin bs=1 skip=$((bstart + 12)) count=8 2>/dev/null | xxd -p)
abs64ld=$(dd if=ldtext.bin bs=1 skip=$((bstart + 12)) count=8 2>/dev/null | xxd -p)
[ "$abs64" = "$abs64ld" ] || { echo "FAIL  link_reloc.la: 64-bit absolute is $abs64, ld says $abs64ld"; ok=0; }

# --- NEGATIVE: an unresolved symbol must still refuse, at patch time too ---
cp link_test_a.o link_in2.o
if timeout 240 ./tiny_host link_reloc.la >/dev/null 2>&1; then
    echo "FAIL  link_reloc.la: patched an unresolved symbol instead of refusing"; ok=0
else
    timeout 240 ./tiny_host link_reloc.la 2>&1 | grep -q "unresolved symbol: greet" \
        || { echo "FAIL  link_reloc.la: refused, but not with the unresolved-symbol diagnostic"; ok=0; }
fi

rm -f link_in1.o link_in2.o
[ "$ok" = 1 ] && echo "PASS  link_reloc.la: both relocation kinds byte-identical to ld (PC32 + 64, 1 negative gate)"
[ "$ok" = 1 ]
