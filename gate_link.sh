#!/bin/sh
# gate_link.sh — link.la slice 1: the ELF64 object READER.
#
# The gate is NOT byte-identity. asm.la is gated against `nasm -f bin` because
# -f bin is deterministic and minimal; `ld`'s output carries choices that are
# ld's own, so a byte-diff here would measure the wrong thing. What is checked
# instead is that link.la RECOVERS THE SAME STRUCTURE readelf reports —
# readelf is the independent witness, and every expected value below is read
# off it at gate time rather than hard-coded from a run I once eyeballed.
#
# A reader that cannot REFUSE is worthless in the same way a build tool that
# cannot go RED is, so the negative cases are gated too.
set -e
cd "$(dirname "$0")"
ok=1

command -v nasm >/dev/null 2>&1    || { echo "SKIP  link.la gate: nasm absent"; exit 0; }
command -v readelf >/dev/null 2>&1 || { echo "SKIP  link.la gate: readelf absent"; exit 0; }

nasm -f elf64 link_test_a.asm -o link_test_a.o
nasm -f elf64 link_test_b.asm -o link_test_b.o

for obj in link_test_a.o link_test_b.o; do
    cp "$obj" link_in.o
    OUT=$(timeout 60 ./tiny_host link.la 2>&1) || { echo "FAIL  link.la: crashed on $obj"; echo "$OUT"; ok=0; continue; }

    # --- section count, offset and size, straight from readelf ---
    readelf -S --wide "$obj" | sed -n 's/^  \[ *\([0-9]\+\)\] \([.a-z]\+\) \+[A-Z]\+ \+[0-9a-f]\+ \([0-9a-f]\+\) \([0-9a-f]\+\).*/\1 \2 \3 \4/p' \
    | while read -r idx name off size; do
        doff=$(printf '%d' "0x$off"); dsize=$(printf '%d' "0x$size")
        echo "$OUT" | grep -q "\[$idx\] $name .*off=$doff size=$dsize" \
            || { echo "FAIL  link.la: $obj section [$idx] $name off=$doff size=$dsize not recovered"; exit 1; }
    done || ok=0

    # --- every symbol name readelf lists must appear ---
    readelf -s --wide "$obj" | sed -n 's/^ \+[0-9]\+: [0-9a-f]\+ \+[0-9]\+ [A-Z]\+ \+[A-Z]\+ \+[A-Z]\+ \+[A-Z0-9]\+ \(.\+\)$/\1/p' \
    | while read -r sym; do
        echo "$OUT" | grep -q "  $sym " \
            || { echo "FAIL  link.la: $obj symbol '$sym' not recovered"; exit 1; }
    done || ok=0
done

# --- the case that makes a linker a linker: a cross-object undefined symbol ---
cp link_test_a.o link_in.o
A_OUT=$(timeout 60 ./tiny_host link.la 2>&1)
echo "$A_OUT" | grep -q "greet .*shndx=0 GLOBAL UNDEFINED" \
    || { echo "FAIL  link.la: 'greet' not reported GLOBAL UNDEFINED in A"; ok=0; }
echo "$A_OUT" | grep -q "offset=1 R_X86_64_PC32 .*sym=greet addend=-4" \
    || { echo "FAIL  link.la: A's PC32 relocation to greet not recovered"; ok=0; }

cp link_test_b.o link_in.o
B_OUT=$(timeout 60 ./tiny_host link.la 2>&1)
echo "$B_OUT" | grep -q "greet .*shndx=2 GLOBAL" \
    || { echo "FAIL  link.la: 'greet' not reported DEFINED in B"; ok=0; }
echo "$B_OUT" | grep -q "offset=12 R_X86_64_64 .*addend=0" \
    || { echo "FAIL  link.la: B's 64-bit absolute relocation not recovered"; ok=0; }

# --- NEGATIVE: it must REFUSE what it cannot link, and say why ---
#   ld's own output is ET_EXEC, so it is the honest not-an-object input.
ld -o link_ref link_test_a.o link_test_b.o 2>/dev/null
cp link_ref link_in.o
#   ONE run per case: capture output and exit status together. Running the
#   linker twice — once to see it fail, once to read why — doubled the cost of
#   every negative gate for no extra information.
#   `set -e` makes a bare VAR=$(failing-cmd) fatal, and these commands are
#   SUPPOSED to fail — so the capture goes inside an `if`, where the shell
#   exempts it. Getting this wrong killed the gate with no output at all.
if EOUT=$(timeout 60 ./tiny_host link.la 2>&1); then ERC=0; else ERC=$?; fi
[ "$ERC" -ne 0 ] \
    || { echo "FAIL  link.la: accepted an ET_EXEC — a reader that cannot refuse is worthless"; ok=0; }
echo "$EOUT" | grep -q "not ET_REL" \
    || { echo "FAIL  link.la: refused the ET_EXEC but not with the ET_REL diagnostic"; ok=0; }

printf 'not an elf at all' > link_in.o
#   `set -e` makes a bare VAR=$(failing-cmd) fatal, and these commands are
#   SUPPOSED to fail — so the capture goes inside an `if`, where the shell
#   exempts it. Getting this wrong killed the gate with no output at all.
if NOUT=$(timeout 60 ./tiny_host link.la 2>&1); then NRC=0; else NRC=$?; fi
[ "$NRC" -ne 0 ] || { echo "FAIL  link.la: accepted a non-ELF file"; ok=0; }
echo "$NOUT" | grep -q "not an ELF object" \
    || { echo "FAIL  link.la: refused the non-ELF but not with the ELF diagnostic"; ok=0; }

rm -f link_in.o
[ "$ok" = 1 ] && echo "PASS  link.la: ELF64 object reader agrees with readelf (2 objects, both relocation kinds, 2 negative gates)"
[ "$ok" = 1 ]
