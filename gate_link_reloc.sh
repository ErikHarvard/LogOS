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
nasm -f elf64 link_test_dup.asm -o link_test_dup.o
nasm -f elf64 link_test_plt.asm -o link_test_plt.o
nasm -f elf64 link_test_rw.asm -o link_test_rw.o
nasm -f elf64 link_test_bss.asm -o link_test_bss.o
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

# --- ★ THE CAPSTONE: the emitted executable must RUN ---
#   Every check above compares bytes. This one does not: it executes the
#   program the linker produced and reads what it prints. The asmelf.la
#   standard -- the proof is not a diff, the OS runs it. A linker whose output
#   diffs correctly but segfaults has proved nothing.
[ -x link_out ] || { echo "FAIL  link_reloc.la: emitted no executable link_out"; ok=0; }
if [ -x link_out ]; then
    GOT=$(./link_out); RC=$?
    WANT=$(./link_ref); WRC=$?
    [ "$GOT" = "$WANT" ] || { echo "FAIL  link_out printed '$GOT', ld's binary prints '$WANT'"; ok=0; }
    [ "$RC" = "$WRC" ]   || { echo "FAIL  link_out exited $RC, ld's binary exits $WRC"; ok=0; }
fi

# --- the loader's rule: p_offset must equal p_vaddr modulo the page size ---
#   Violate it and execve fails with ENOEXEC, or the code loads at the wrong
#   address -- a failure that looks like a corrupt binary rather than a layout
#   bug, so it is asserted directly instead of being inferred from "it ran".
readelf -l --wide link_out 2>/dev/null | awk '/^  LOAD/ {print $2, $3}' | while read -r off va; do
    d_off=$(printf '%d' "$off"); d_va=$(printf '%d' "$va")
    [ $((d_off % 4096)) -eq $((d_va % 4096)) ] \
        || { echo "FAIL  link_out: PT_LOAD $off/$va has p_offset !=~ p_vaddr (mod 4096)"; exit 1; }
done || ok=0

# --- W^X: the code segment must not be writable ---
readelf -l --wide link_out 2>/dev/null | grep -q "LOAD.*R E "     || { echo "FAIL  link_out: no R+X code segment (W^X would be undercut)"; ok=0; }
readelf -l --wide link_out 2>/dev/null | grep -q "LOAD.*RWE"     && { echo "FAIL  link_out: emitted a writable+executable segment"; ok=0; }

# --- NEGATIVE: an unresolved symbol must still refuse, at patch time too ---
cp link_test_a.o link_in2.o
#   ONE run per case — see gate_link.sh. Halves the negative-gate cost.
#   `set -e` makes a bare VAR=$(failing-cmd) fatal, and these commands are
#   SUPPOSED to fail — so the capture goes inside an `if`, where the shell
#   exempts it. Getting this wrong killed the gate with no output at all.
if UOUT=$(timeout 240 ./tiny_host link_reloc.la 2>&1); then URC=0; else URC=$?; fi
[ "$URC" -ne 0 ] \
    || { echo "FAIL  link_reloc.la: patched an unresolved symbol instead of refusing"; ok=0; }
echo "$UOUT" | grep -q "unresolved symbol: greet" \
    || { echo "FAIL  link_reloc.la: refused, but not with the unresolved-symbol diagnostic"; ok=0; }

# --- R_X86_64_PLT32: the relocation real objects actually carry ---
#   nasm and gcc emit PLT32 for an ordinary call to a global function, so a
#   linker handling only PC32 fails on most real input while looking fine on a
#   hand-written fixture. Statically the two are equivalent — the callee is in
#   the image being emitted, so the PLT stub it would jump through is
#   redundant — and this proves the equivalence rather than assuming it, by
#   requiring the same bytes ld produces from the same pair.
ld -o link_ref_plt link_test_plt.o link_test_b.o
objcopy -O binary --only-section=.text link_ref_plt ldtext_plt.bin
cp link_test_plt.o link_in1.o
cp link_test_b.o   link_in2.o
rm -f link_out link_text.bin
POUT=$(timeout 240 ./tiny_host link_reloc.la 2>&1) || {
    echo "FAIL  link_reloc.la: crashed on the PLT32 fixture"; echo "$POUT"; ok=0; }
if [ -f link_text.bin ]; then
    cmp -n "$asize" link_text.bin ldtext_plt.bin \
        || { echo "FAIL  link_reloc.la: PLT32 object's patched .text differs from ld's"; ok=0; }
    POB=$(mktemp); PLB=$(mktemp)
    dd if=link_text.bin bs=1 skip=$bstart of="$POB" 2>/dev/null
    dd if=ldtext_plt.bin bs=1 skip=$bstart of="$PLB" 2>/dev/null
    cmp "$POB" "$PLB" || { echo "FAIL  link_reloc.la: PLT32 link's second object differs from ld's"; ok=0; }
    rm -f "$POB" "$PLB"
else
    echo "FAIL  link_reloc.la: PLT32 link produced no .text"; ok=0
fi
#   and it must RUN, not merely diff
if [ -x link_out ]; then
    PGOT=$(./link_out); PRC=$?
    PWANT=$(./link_ref_plt)
    [ "$PGOT" = "$PWANT" ] && [ "$PRC" = "0" ] \
        || { echo "FAIL  PLT32-linked binary printed '$PGOT' rc=$PRC, ld's prints '$PWANT'"; ok=0; }
else
    echo "FAIL  link_reloc.la: PLT32 link emitted no executable"; ok=0
fi

# --- NEGATIVE: a symbol defined TWICE must be refused ---
#   `ld` calls this "multiple definition" and refuses. Without the check a
#   linker takes whichever definition came first and links happily, so the bug
#   presents as the WRONG BEHAVIOUR at run time rather than as a link failure.
#
#   The fixture isolates it deliberately: link_test_dup.o defines BOTH _start
#   and greet, so linking it against link_test_b.o (which also defines greet)
#   is a duplicate and NOTHING ELSE. Using b.o against itself would also be a
#   duplicate, but it lacks _start too, and then the test cannot tell which
#   error it caught — the first version of this check did exactly that and
#   silently proved the wrong thing.
cp link_test_dup.o link_in1.o
cp link_test_b.o   link_in2.o
rm -f link_out link_text.bin
#   `set -e` makes a bare VAR=$(failing-cmd) fatal, and these commands are
#   SUPPOSED to fail — so the capture goes inside an `if`, where the shell
#   exempts it. Getting this wrong killed the gate with no output at all.
if DOUT=$(timeout 240 ./tiny_host link_reloc.la 2>&1); then DRC=0; else DRC=$?; fi
[ "$DRC" -ne 0 ] \
    || { echo "FAIL  link_reloc.la: linked a duplicate definition instead of refusing"; ok=0; }
echo "$DOUT" | grep -q "duplicate symbol: greet" \
    || { echo "FAIL  link_reloc.la: refused, but not with the duplicate-symbol diagnostic"; ok=0; }
#   A refused link must leave NO output — otherwise the next command runs
#   yesterday's binary and the refusal was cosmetic.
[ -e link_out ] && { echo "FAIL  link_reloc.la: wrote link_out despite refusing the link"; ok=0; }

# --- THREE SECTIONS, and the first WRITABLE segment ---
#   .rodata AND .data in one object forces a third PT_LOAD. Until this fixture
#   existed every segment was R or R+X, so "no RWE" passed without the linker
#   ever having had the chance to get it wrong — the W^X assertion was green
#   but untested. This is what makes it a real check.
#
#   .data's ADDRESS is not compared against ld: ld packs it into the tail of
#   the previous page (0x403010) where this gives each section its own page.
#   Both satisfy p_offset = p_vaddr (mod page), and layout is a CHOICE — so the
#   witness here is the emitted structure plus the program running, not a diff.
ld -o link_ref_rw link_test_a.o link_test_rw.o
cp link_test_a.o  link_in1.o
cp link_test_rw.o link_in2.o
rm -f link_out
if ROUT=$(timeout 240 ./tiny_host link_reloc.la 2>&1); then RRC=0; else RRC=$?; fi
[ "$RRC" -eq 0 ] || { echo "FAIL  link_reloc.la: could not link the 3-section fixture: $ROUT"; ok=0; }
if [ -x link_out ]; then
    nseg=$(readelf -l --wide link_out 2>/dev/null | grep -c '^  LOAD')
    [ "$nseg" = "3" ] || { echo "FAIL  link_reloc.la: expected 3 PT_LOADs for .text/.rodata/.data, got $nseg"; ok=0; }
    readelf -l --wide link_out 2>/dev/null | grep -q 'LOAD.*RW ' \
        || { echo "FAIL  link_reloc.la: no writable segment emitted for .data"; ok=0; }
    readelf -l --wide link_out 2>/dev/null | grep -q 'LOAD.*RWE' \
        && { echo "FAIL  link_reloc.la: emitted a WRITABLE+EXECUTABLE segment (W^X violated)"; ok=0; }
    RGOT=$(./link_out); RRC2=$?
    RWANT=$(./link_ref_rw)
    [ "$RGOT" = "$RWANT" ] && [ "$RRC2" = "0" ] \
        || { echo "FAIL  3-section binary printed '$RGOT' rc=$RRC2, ld's prints '$RWANT'"; ok=0; }
else
    echo "FAIL  link_reloc.la: 3-section link emitted no executable"; ok=0
fi

# --- .bss: memory without file bytes ---
#   NOBITS is the first section whose sh_offset does NOT point at real content.
#   Two independent ways to get it wrong, both silent at link time: read those
#   bytes anyway (garbage in the image), or fail to reserve the address space
#   (the symbol overlaps whatever follows). So the gate checks BOTH sizes, not
#   just that a segment exists.
ld -o link_ref_bss link_test_a.o link_test_bss.o
cp link_test_a.o   link_in1.o
cp link_test_bss.o link_in2.o
rm -f link_out
if BOUT=$(timeout 240 ./tiny_host link_reloc.la 2>&1); then BRC=0; else BRC=$?; fi
[ "$BRC" -eq 0 ] || { echo "FAIL  link_reloc.la: could not link the .bss fixture: $BOUT"; ok=0; }
if [ -x link_out ]; then
    #   filesz 0 AND memsz non-zero — that pair IS the .bss property.
    readelf -l --wide link_out 2>/dev/null \
        | awk '/^  LOAD/ && $5=="0x000000" && $6!="0x000000" {found=1} END {exit !found}' \
        || { echo "FAIL  link_reloc.la: no segment with p_filesz=0 and p_memsz>0 (.bss not reserved)"; ok=0; }
    #   and it must be writable, never executable
    readelf -l --wide link_out 2>/dev/null | grep -q 'LOAD.*RWE' \
        && { echo "FAIL  link_reloc.la: .bss segment is executable (W^X violated)"; ok=0; }
    #   an empty region must cost no FILE space: padding to it wrote 16 KB of
    #   zeros to hold nothing until this was fixed.
    fsz=$(stat -c%s link_out)
    [ "$fsz" -lt 12288 ] \
        || { echo "FAIL  link_reloc.la: $fsz-byte file — a zero-filesz segment is consuming file space"; ok=0; }
    BGOT=$(./link_out); BRC2=$?
    BWANT=$(./link_ref_bss)
    [ "$BGOT" = "$BWANT" ] && [ "$BRC2" = "0" ] \
        || { echo "FAIL  .bss binary printed '$BGOT' rc=$BRC2, ld's prints '$BWANT'"; ok=0; }
else
    echo "FAIL  link_reloc.la: .bss link emitted no executable"; ok=0
fi

# --- NEGATIVE: a section the layout cannot place must be REFUSED ---
#   The layout knows .text and .rodata. Every real gcc object also carries
#   .data/.bss/.eh_frame, all SHF_ALLOC — they occupy memory at run time and so
#   need addresses. Previously they were "handled" by not being looked for, and
#   a symbol defined in one resolved against a base that was never assigned:
#   the program links and then misbehaves far from the cause. SHF_ALLOC is the
#   discriminator, not a name blacklist, so .symtab/.strtab/.comment/.note* are
#   correctly ignored — the loader never maps them.
if command -v gcc >/dev/null 2>&1; then
    gcc -c -O0 -x c - -o gate_secs.o 2>/dev/null <<'CEOF'
extern int helper(int);
int compute(int x){ return helper(x); }
CEOF
    if [ -f gate_secs.o ]; then
        cp link_test_a.o link_in1.o
        cp gate_secs.o   link_in2.o
        if SOUT=$(timeout 240 ./tiny_host link_reloc.la 2>&1); then SRC=0; else SRC=$?; fi
        [ "$SRC" -ne 0 ] \
            || { echo "FAIL  link_reloc.la: accepted an object with unplaceable sections"; ok=0; }
        #   Must name the SECTION problem, not some downstream symptom. Both the
        #   right and wrong behaviours exit non-zero, so checking only failure
        #   would pass while the check ran in the wrong place — which it did,
        #   until the check was moved from the body to a binder.
        echo "$SOUT" | grep -q "allocatable section this layout cannot place" \
            || { echo "FAIL  link_reloc.la: refused, but not for the section reason (got: $(echo "$SOUT" | tail -1))"; ok=0; }
        rm -f gate_secs.o
    fi
fi

rm -f link_in1.o link_in2.o
[ "$ok" = 1 ] && echo "PASS  link_reloc.la: relocations byte-identical to ld, AND THE LINKED PROGRAM RUNS (PC32 + PLT32 + 64, 4 sections incl. .bss and a writable segment, W^X, page-aligned, 3 negative gates)"
[ "$ok" = 1 ]
