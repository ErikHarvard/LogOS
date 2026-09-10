#!/bin/sh
# gate_link_layout.sh — link_layout.la slice 2: layout + cross-object resolution.
#
# THE WITNESS IS ld ITSELF. Addresses are a CHOICE, not a fact, so a linker's
# own output is self-consistent whatever it decides — checking it against
# itself proves nothing. link_layout.la therefore adopts ld's layout policy on
# these inputs, and this gate reads the expected addresses out of `nm link_ref`
# AT GATE TIME and demands they agree number-for-number. A plausible-but-wrong
# layout cannot pass, which a "does it run" test alone would let through.
set -e
cd "$(dirname "$0")"
ok=1

command -v nasm >/dev/null 2>&1 || { echo "SKIP  link_layout gate: nasm absent"; exit 0; }
command -v ld   >/dev/null 2>&1 || { echo "SKIP  link_layout gate: ld absent"; exit 0; }
command -v nm   >/dev/null 2>&1 || { echo "SKIP  link_layout gate: nm absent"; exit 0; }

nasm -f elf64 link_test_a.asm -o link_test_a.o
nasm -f elf64 link_test_b.asm -o link_test_b.o
ld -o link_ref link_test_a.o link_test_b.o

cp link_test_a.o link_in1.o
cp link_test_b.o link_in2.o
OUT=$(timeout 240 ./tiny_host link_layout.la 2>&1) || {
    echo "FAIL  link_layout.la: crashed or timed out"; echo "$OUT"; exit 1; }

# --- each symbol's address must equal the one ld chose ---
for sym in _start greet; do
    hex=$(nm link_ref | awk -v s="$sym" '$3==s {print $1}')
    [ -n "$hex" ] || { echo "FAIL  gate bug: ld's binary has no symbol '$sym'"; ok=0; continue; }
    dec=$(printf '%d' "0x$hex")
    echo "$OUT" | grep -q " $sym = $dec$" \
        || { echo "FAIL  link_layout.la: $sym should be $dec (ld says 0x$hex); got:"
             echo "$OUT" | grep " $sym ="; ok=0; }
done

# --- .rodata's base must match where ld put the local symbol living in it ---
msghex=$(nm link_ref | awk '$3=="msg" {print $1}')
msgdec=$(printf '%d' "0x$msghex")
echo "$OUT" | grep -q "\.rodata obj2 @ $msgdec" \
    || { echo "FAIL  link_layout.la: .rodata base should be $msgdec (ld's msg at 0x$msghex)"; ok=0; }

# --- THE THRESHOLD: a symbol defined in one object, referenced from another ---
#   This is the case that separates a linker from a reader. `greet` is
#   UNDEFINED in object A and defined in object B; it must resolve to B's
#   address, not to 0 and not to A's.
greetdec=$(printf '%d' "0x$(nm link_ref | awk '$3=="greet" {print $1}')")
echo "$OUT" | grep -q "resolved greet -> $greetdec" \
    || { echo "FAIL  link_layout.la: cross-object resolution of 'greet' wrong or missing"; ok=0; }

# --- NEGATIVE: an unresolved symbol must be REFUSED, never linked as zero ---
#   Feeding object A as BOTH inputs leaves `greet` defined nowhere. Silently
#   resolving it to 0 is the classic linker failure — the program links, then
#   jumps to null at run time and the diagnostic arrives as a segfault far from
#   the cause. It must halt, and say which symbol.
cp link_test_a.o link_in1.o
cp link_test_a.o link_in2.o
if timeout 240 ./tiny_host link_layout.la >/dev/null 2>&1; then
    echo "FAIL  link_layout.la: accepted an unresolved symbol — must refuse, not link as 0"; ok=0
else
    timeout 240 ./tiny_host link_layout.la 2>&1 | grep -q "unresolved symbol: greet" \
        || { echo "FAIL  link_layout.la: refused, but not with the unresolved-symbol diagnostic"; ok=0; }
fi

rm -f link_in1.o link_in2.o
[ "$ok" = 1 ] && echo "PASS  link_layout.la: layout + cross-object resolution agree with ld (3 addresses, 1 negative gate)"
[ "$ok" = 1 ]
