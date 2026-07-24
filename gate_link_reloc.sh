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


# ── byte-identity of the merged .text, for ANY object pair ─────────────────
#   The original check was bespoke to link_test_a.o + link_test_b.o, so the
#   32/32S fixtures were verified behaviourally only — a weaker guarantee that a
#   five-row relocation table quietly implied was uniform. This makes the strong
#   check reusable, so a relocation type is diffed against ld rather than merely
#   observed to work.
#
#   The alignment gap between objects is NOT compared: ld fills it with a 2-byte
#   nop (66 90), this pads with single-byte nops. Both correct, neither
#   reachable. Sizes and alignments are read from the objects themselves, so the
#   spans cannot drift from the fixtures.
cmp_text_against_ld() {   # $1=obj1 $2=obj2 $3=label
    _o1="$1"; _o2="$2"; _lbl="$3"
    ld -o cmp_ref "$_o1" "$_o2" 2>/dev/null || { echo "SKIP  $_lbl: ld could not link the pair"; return 0; }
    objcopy -O binary --only-section=.text cmp_ref cmp_ld.bin 2>/dev/null
    cp "$_o1" link_in1.o; cp "$_o2" link_in2.o
    printf 'link_in1.o\nlink_in2.o\n' > link_inputs.txt
    rm -f link_text.bin
    if _out=$(timeout 240 ./tiny_host link_reloc.la 2>&1); then :; else
        echo "FAIL  $_lbl: link failed: $_out"; ok=0; return 0; fi
    [ -f link_text.bin ] || { echo "FAIL  $_lbl: no link_text.bin"; ok=0; return 0; }

    _sz1=$(readelf -S --wide "$_o1" | awk '/ \.text /{print $(NF-5)}')
    _sz1=$(printf '%d' "0x$_sz1")
    _al2=$(readelf -S --wide "$_o2" | awk '/ \.text /{print $NF}')
    [ -n "$_al2" ] && [ "$_al2" -gt 0 ] || _al2=1
    _start2=$(( (_sz1 + _al2 - 1) / _al2 * _al2 ))

    cmp -n "$_sz1" link_text.bin cmp_ld.bin \
        || { echo "FAIL  $_lbl: first object's patched .text differs from ld's"; ok=0; }
    _a=$(mktemp); _b=$(mktemp)
    dd if=link_text.bin bs=1 skip=$_start2 of="$_a" 2>/dev/null
    dd if=cmp_ld.bin    bs=1 skip=$_start2 of="$_b" 2>/dev/null
    cmp "$_a" "$_b" \
        || { echo "FAIL  $_lbl: second object's patched .text differs from ld's"; ok=0; }
    rm -f "$_a" "$_b"

    #   ...and RUN it, from the same link. These were previously two separate
    #   links of the same pair — one to diff, one to execute — which is a full
    #   ~25 s of linking for no extra information. Byte-identity says the code
    #   is right; running says the ELF around it is loadable. Both matter, and
    #   one link answers both.
    if [ -x link_out ]; then
        if ./link_out >cmp_got.txt 2>&1; then _ourrc=0; else _ourrc=$?; fi
        if ./cmp_ref  >cmp_want.txt 2>&1; then _ldrc=0; else _ldrc=$?; fi
        cmp -s cmp_got.txt cmp_want.txt \
            || { echo "FAIL  $_lbl: output differs from ld's binary"; ok=0; }
        [ "$_ourrc" = "$_ldrc" ] \
            || { echo "FAIL  $_lbl: exit $_ourrc, ld's binary exits $_ldrc"; ok=0; }
        rm -f cmp_got.txt cmp_want.txt
    else
        echo "FAIL  $_lbl: no executable emitted"; ok=0
    fi
    rm -f cmp_ref cmp_ld.bin
}

nasm -f elf64 link_test_a.asm -o link_test_a.o
nasm -f elf64 link_test_dup.asm -o link_test_dup.o
nasm -f elf64 link_test_plt.asm -o link_test_plt.o
nasm -f elf64 link_test_rw.asm -o link_test_rw.o
nasm -f elf64 link_test_bss.asm -o link_test_bss.o
nasm -f elf64 link_test_c.asm -o link_test_c.o
nasm -f elf64 link_test_b.asm -o link_test_b.o
nasm -f elf64 link_test_reldata.asm -o link_test_reldata.o
ld -o link_ref link_test_a.o link_test_b.o
objcopy -O binary --only-section=.text link_ref ldtext.bin

cp link_test_a.o link_in1.o
cp link_test_b.o link_in2.o
printf 'link_in1.o\nlink_in2.o\n' > link_inputs.txt
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
printf 'link_in1.o\nlink_in2.o\n' > link_inputs.txt
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
printf 'link_in1.o\nlink_in2.o\n' > link_inputs.txt
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
printf 'link_in1.o\nlink_in2.o\n' > link_inputs.txt
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
printf 'link_in1.o\nlink_in2.o\n' > link_inputs.txt
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
printf 'link_in1.o\nlink_in2.o\n' > link_inputs.txt
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
    #   ★ AN EMPTY REGION MUST COST NO FILE SPACE. Padding up to a .bss
    #   segment's offset once wrote 16 KB of zeros to hold nothing.
    #
    #   This began as `[ "$fsz" -lt 12288 ]`, which was correct but BRITTLE: a
    #   magic threshold coupled to today's section count. Add a legitimate
    #   fifth section, the file outgrows the number, the gate fails
    #   spuriously — and whoever "fixes" it by raising the threshold silently
    #   destroys the protection. Correct today, wrong the moment the thing it
    #   guards changes shape.
    #
    #   Stated structurally instead: the file must end exactly where its last
    #   segment WITH FILE BYTES ends. Any byte past that is padding nothing
    #   reads, whatever the section count. (Prompted by track A's review — the
    #   claim there was that no assertion existed, which was wrong; the real
    #   defect was that the assertion could not survive the next section.)
    #
    #   ★★ AND IT DID NOT SURVIVE THE NEXT *STRUCTURE*. That version assumed
    #   nothing may follow the last loadable byte, which held only while the
    #   linker emitted no section header table. It emits one now (so that
    #   `objcopy` can read the output at all), and a section table legitimately
    #   lives past the segments — ld's own file does exactly this. The gate went
    #   RED on a correct image.
    #
    #   The INTENT survives, so it is restated one level up rather than
    #   loosened: the file must end exactly where the SECTION TABLE ends, and
    #   only alignment may separate the last loadable byte from the section-name
    #   table. Dead padding is still caught anywhere it could hide — before the
    #   name table, or after the headers — but the bytes tools actually read are
    #   no longer counted as waste. Twice now this assertion has been re-derived
    #   at a higher level; each time the magic-number version would have been
    #   "fixed" by raising a threshold, which is how a guard becomes decorative.
    fsz=$(stat -c%s link_out)
    lastend=0
    for pair in $(readelf -l --wide link_out 2>/dev/null | awk '/^  LOAD/ {print $2","$5}'); do
        poff=${pair%,*}; pfsz=${pair#*,}
        [ "$pfsz" = "0x000000" ] && continue
        end=$(( $(printf '%d' "$poff") + $(printf '%d' "$pfsz") ))
        [ "$end" -gt "$lastend" ] && lastend=$end
    done
    shoff=$(readelf -hW link_out | awk '/Start of section headers/{print $5}')
    shnum=$(readelf -hW link_out | awk '/Number of section headers/{print $5}')
    shent=$(readelf -hW link_out | awk '/Size of section headers/{print $5}')
    stroff=$(readelf -SW link_out | sed 's/^ *\[[ 0-9]*\] *//' \
             | awk '$1==".shstrtab"{print $4}')
    #   ★ Assert the measurement parsed before asserting anything about it: an
    #   empty $shnum would make the arithmetic below silently agree with itself.
    if [ -z "$shoff" ] || [ -z "$shnum" ] || [ -z "$shent" ] || [ -z "$stroff" ] \
       || [ "$shnum" -lt 2 ]; then
        echo "FAIL  link_reloc.la: could not read the section table (shoff=$shoff shnum=$shnum shent=$shent stroff=$stroff) — the file-size check would be vacuous"; ok=0
    else
        tabend=$(( shoff + shnum * shent ))
        [ "$fsz" = "$tabend" ] \
            || { echo "FAIL  link_reloc.la: file is $fsz bytes but the section table ends at $tabend — $((fsz - tabend)) bytes nothing reads"; ok=0; }
        slack=$(( $(printf '%d' "0x$stroff") - lastend ))
        [ "$slack" -ge 0 ] && [ "$slack" -le 7 ] \
            || { echo "FAIL  link_reloc.la: $slack bytes between the last loadable byte ($lastend) and the section-name table (0x$stroff) — more than alignment"; ok=0; }
    fi
    BGOT=$(./link_out); BRC2=$?
    BWANT=$(./link_ref_bss)
    [ "$BGOT" = "$BWANT" ] && [ "$BRC2" = "0" ] \
        || { echo "FAIL  .bss binary printed '$BGOT' rc=$BRC2, ld's prints '$BWANT'"; ok=0; }
else
    echo "FAIL  link_reloc.la: .bss link emitted no executable"; ok=0
fi

# --- THREE OBJECTS: N is not 2 ---
#   Every stage of the N-object rewrite was verified equivalent ON TWO OBJECTS,
#   which by construction cannot tell "supports N" from "shaped for two but
#   tidier" — the same blind spot as DUPCHECK's nested walk covering exactly
#   one pair. This is the case that distinguishes them, and it needs NO code
#   change: a third line in the manifest.
#
#   A dropped third object would fail no other assertion here, since every
#   other check uses the two-object fixtures. It would simply link two objects,
#   run correctly, and be missing `bump`.
ld -o link_ref3 link_test_a.o link_test_b.o link_test_c.o
cp link_test_a.o link_in1.o
cp link_test_b.o link_in2.o
cp link_test_c.o link_in3.o
printf 'link_in1.o\nlink_in2.o\nlink_in3.o\n' > link_inputs.txt
rm -f link_out
if TOUT=$(timeout 240 ./tiny_host link_reloc.la 2>&1); then TRC=0; else TRC=$?; fi
[ "$TRC" -eq 0 ] || { echo "FAIL  link_reloc.la: could not link three objects: $TOUT"; ok=0; }
echo "$TOUT" | grep -q "linked 3 objects" \
    || { echo "FAIL  link_reloc.la: did not report linking 3 objects (got: $TOUT)"; ok=0; }
if [ -x link_out ]; then
    #   The third object's placement is the payload: its .text must be packed
    #   after the other two, at the address ld independently chose for `bump`.
    want=$(nm link_ref3 | awk '$3=="bump"{print $1}')
    wantdec=$(printf '%d' "0x$want")
    tsz=$(readelf -l --wide link_out | awk '/^  LOAD/ && $7=="R" && $8=="E" {print $5; exit}')
    [ -n "$tsz" ] || tsz=$(readelf -l --wide link_out | awk '/^  LOAD.*R E/ {print $5; exit}')
    csz=$(readelf -S --wide link_test_c.o | awk '/ \.text /{print $7}')
    endaddr=$(( 4198400 + $(printf '%d' "$tsz") ))
    cstart=$(( endaddr - $(printf '%d' "0x$csz") ))
    [ "$cstart" = "$wantdec" ] \
        || { echo "FAIL  link_reloc.la: third object placed at $cstart, ld put bump at $wantdec"; ok=0; }
    TGOT=$(./link_out); TRC2=$?
    [ "$TGOT" = "$(./link_ref3)" ] && [ "$TRC2" = "0" ] \
        || { echo "FAIL  3-object binary printed '$TGOT' rc=$TRC2"; ok=0; }
else
    echo "FAIL  link_reloc.la: 3-object link emitted no executable"; ok=0
fi

# --- the ABSOLUTE relocations: 32 and 32S ---
#   nasm emits 32 for `mov eax, label`; gcc -fno-pic emits 32S for static data
#   addressing. Handling only PC32/PLT32/64 refused ordinary non-PIC code.
#
#   Each is diffed against ld AND run, from ONE link. They used to be two links
#   apiece — a behavioural check and a byte-identity check of the same pair —
#   which cost ~50 s of the suite's runtime for no extra information.
#
#   The 32S pair uses REAL gcc output: pick(2) indexes a static table, so a
#   wrong base address reads four plausible bytes and the program exits CLEANLY
#   with the wrong number. Byte-identity catches that; "it ran" would not.
cmp_text_against_ld link_test_a.o link_test_abs.o "R_X86_64_32 byte-identity"
if command -v gcc >/dev/null 2>&1; then
    gcc -c -O1 -fno-pic -mcmodel=small -x c - -o cmp_s32.o 2>/dev/null <<'CS32'
static const int table[4] = {10, 20, 30, 40};
int pick(int i) { return table[i & 3]; }
CS32
    if [ -f cmp_s32.o ] && readelf -r --wide cmp_s32.o | grep -q R_X86_64_32S; then
        cmp_text_against_ld link_test_s32.o cmp_s32.o "R_X86_64_32S byte-identity"
        rm -f cmp_s32.o
    fi
fi

# --- NEGATIVE: a section the layout cannot place must be REFUSED ---
#   ★ THIS FIXTURE REPLACED A STALE ONE, which is the point. The gate used to
#   point at a gcc object, whose .data/.bss/.eh_frame were all unplaceable when
#   it was written. Then .data and .bss became placeable and .eh_frame
#   explicitly droppable — so that object no longer had the property the gate
#   NAMES, and it began failing for an unrelated reason (unresolved symbol).
#   The gate caught that ONLY because it asserts WHICH diagnostic; a check for
#   "it failed" would have passed while testing nothing, indefinitely.
#
#   link_test_odd.asm carries `.weird`: PROGBITS + SHF_ALLOC, so it occupies
#   memory at run time and the layout must answer for it, and it is a name this
#   linker cannot know. It exists for no other purpose, so it cannot quietly
#   become placeable the way .data did.
cp link_test_a.o   link_in1.o
cp link_test_odd.o link_in2.o
printf 'link_in1.o\nlink_in2.o\n' > link_inputs.txt
rm -f link_out link_text.bin
if SOUT=$(timeout 240 ./tiny_host link_reloc.la 2>&1); then SRC=0; else SRC=$?; fi
[ "$SRC" -ne 0 ] \
    || { echo "FAIL  link_reloc.la: accepted an object with an unplaceable section"; ok=0; }
echo "$SOUT" | grep -q "allocatable section this layout cannot place" \
    || { echo "FAIL  link_reloc.la: refused, but not for the section reason (got: $(echo "$SOUT" | tail -1))"; ok=0; }
[ -e link_out ] && { echo "FAIL  link_reloc.la: wrote link_out despite refusing"; ok=0; }


# --- REAL COMPILER OUTPUT: asm entry + two gcc objects ---
#   The first fixture whose inputs this project did not author. gcc picks its
#   own section layout, symbol ordering and relocations; the linker either
#   copes or it only ever worked on objects shaped by its author.
#
#   The assertion is the EXIT STATUS: compute(21) -> helper(21)+1 = 43, so the
#   value travelled through BOTH C objects. A wrong address for either gives a
#   segfault or garbage, never 43.
#
#   ★ set -e KILLS the script on any non-zero exit, and this fixture exits 43
#   BY DESIGN. Every other gated binary exits 0, so that trap was unreachable
#   until a test whose whole point is a non-zero status — it died silently with
#   exit=43, a suspiciously specific number that is test DATA, not a shell code.
GCC_RAN=no
if command -v gcc >/dev/null 2>&1; then
    gcc -c -O0 -x c - -o gate_g1.o 2>/dev/null <<'C1'
extern int helper(int);
int compute(int x) { return helper(x) + 1; }
C1
    gcc -c -O0 -x c - -o gate_g2.o 2>/dev/null <<'C2'
int helper(int x) { return x * 2; }
C2
    if [ -f gate_g1.o ] && [ -f gate_g2.o ]; then
        GCC_RAN=yes
        ld -o link_ref_gcc link_test_start.o gate_g1.o gate_g2.o 2>/dev/null
        if ./link_ref_gcc; then LDRC=0; else LDRC=$?; fi
        cp link_test_start.o link_in1.o
        cp gate_g1.o link_in2.o
        cp gate_g2.o link_in3.o
        printf 'link_in1.o\nlink_in2.o\nlink_in3.o\n' > link_inputs.txt
        rm -f link_out
        if GOUT=$(timeout 240 ./tiny_host link_reloc.la 2>&1); then GRC=0; else GRC=$?; fi
        [ "$GRC" -eq 0 ] || { echo "FAIL  link_reloc.la: could not link real gcc objects: $GOUT"; ok=0; }
        if [ -x link_out ]; then
            if ./link_out; then OURRC=0; else OURRC=$?; fi
            [ "$OURRC" = "$LDRC" ] \
                || { echo "FAIL  gcc-object link exited $OURRC, ld's binary exits $LDRC"; ok=0; }
            [ "$OURRC" = "43" ] \
                || { echo "FAIL  gcc-object link exited $OURRC, expected 43"; ok=0; }

            # --- ★ .eh_frame PLACED AND RELOCATED — the FDEs point at the code ---
            #   Each gcc object carries a .eh_frame with one R_X86_64_PC32: the
            #   FDE's PC-begin, pointing at the .text function it describes.
            #   .eh_frame used to be DROPPED; it is now placed in the R segment
            #   (grouped with .rodata by the linker SCRIPT) and its relocations
            #   applied via the plan. This asserts the placement is CORRECT, not
            #   merely present: every function address ld records in its unwind
            #   FDEs must appear, PC-relative-encoded, in OUR placed .eh_frame.
            #   An unrelocated field decodes to an address INSIDE .eh_frame
            #   (never into .text), so it fails the search — the exact
            #   silent-wrongness signature.
            #
            #   No section headers are emitted, so .eh_frame is found via the
            #   R (read-only) PT_LOAD from readelf -l, and each FDE by
            #   SCANNING for the position that decodes to an expected pc — robust
            #   to the CIE/FDE layout, no offset arithmetic. Expected pcs are
            #   read off ld at gate time, never hardcoded. This decode check is
            #   kept alongside the byte-identity check below because it validates
            #   the FDE *semantics* (points at the right code) independently of
            #   the exact bytes. .eh_frame is now MERGED (see below), not
            #   concatenated, so it is byte-identical to ld's.
            if command -v python3 >/dev/null 2>&1; then
                EHREPORT=$(python3 - link_out link_ref_gcc 2>&1 <<'PYEH' || true
import sys,struct,subprocess,re
ours,ref=sys.argv[1],sys.argv[2]
fr=subprocess.run(["readelf","--debug-dump=frames",ref],capture_output=True,text=True).stdout
want=sorted({int(m,16) for m in re.findall(r'pc=([0-9a-f]+)\.\.',fr)})
if not want:
    print("SKIP  no FDEs in ld reference to check"); sys.exit(0)
lo=subprocess.run(["readelf","-lW",ours],capture_output=True,text=True).stdout
segs=[]
for m in re.finditer(r'LOAD\s+0x([0-9a-f]+)\s+0x([0-9a-f]+)\s+0x[0-9a-f]+\s+0x([0-9a-f]+)\s+0x([0-9a-f]+)\s+([RWE ]+?)\s+0x',lo):
    segs.append((int(m.group(1),16),int(m.group(2),16),int(m.group(3),16),int(m.group(4),16),m.group(5).strip()))
eh=[s for s in segs if s[4]=="R"]
tx=[s for s in segs if 'E' in s[4]]
if not eh: print("FAIL  .eh_frame R segment (flags R) not emitted"); sys.exit(0)
if not tx: print("FAIL  no R+X text segment to bound the FDE pcs"); sys.exit(0)
ehoff,ehva,ehfsz=eh[0][0],eh[0][1],eh[0][2]
txlo,txhi=tx[0][1],tx[0][1]+tx[0][3]
data=open(ours,"rb").read()[ehoff:ehoff+ehfsz]
found=[]
for w in want:
    hit=None
    for i in range(0,len(data)-3):
        v=struct.unpack_from("<i",data,i)[0]
        if ehva+i+v==w: hit=ehva+i; break
    found.append((w,hit))
miss=[hex(w) for w,h in found if h is None]
if miss:
    print("FAIL  .eh_frame FDE(s) not relocated to "+",".join(miss)+" (an unrelocated field decodes into .eh_frame, never into .text)"); sys.exit(0)
outside=[hex(w) for w,h in found if not (txlo<=w<txhi)]
if outside:
    print("FAIL  .eh_frame FDE pc "+",".join(outside)+" is not inside our R+X text segment"); sys.exit(0)
print("OK  "+str(len(found))+" FDE(s) point at .text: "+",".join(hex(w) for w,_ in found))
PYEH
)
                case "$EHREPORT" in
                    OK*)   : ;;
                    SKIP*) echo "NOTE  link_reloc.la: .eh_frame check skipped — $EHREPORT" ;;
                    *)     echo "$EHREPORT"; ok=0 ;;
                esac
            fi

            # --- ★★ .eh_frame MERGED BYTE-IDENTICAL TO ld ---
            #   The linker no longer CONCATENATES the objects' .eh_frame — it
            #   MERGES like ld: one shared CIE (deduped), then every FDE with its
            #   CIE_pointer rewritten and its initial_location relocated at the
            #   FDE's new merged position. Since our .eh_frame base already equals
            #   ld's, a correct merge is BYTE-IDENTICAL to ld's .eh_frame — the
            #   strongest witness there is (the forced answer, demanded exactly,
            #   like the .text relocation diff). For THIS fixture the R (read-only)
            #   segment holds ONLY .eh_frame (no .rodata), so the whole segment is
            #   the merged table; extract it and cmp against `objcopy`'s .eh_frame
            #   from ld's binary. A concatenated (unmerged) table is 0x70, ld's is
            #   0x58 — a length diff alone would already fail.
            if command -v objcopy >/dev/null 2>&1; then
                objcopy -O binary --only-section=.eh_frame link_ref_gcc ld_ehframe.bin 2>/dev/null
                # our R-only PT_LOAD (flags "R", not "R E"): file offset + filesz,
                # parsed as hex WITHOUT awk strtonum (mawk lacks it — see K4c/build.sh)
                EHLINE=$(readelf -lW link_out | awk '/LOAD/ && $7=="R" && $8!="E"{print $2, $5; exit}')
                if [ -n "$EHLINE" ] && [ -s ld_ehframe.bin ]; then
                    EHOFF=$(( ${EHLINE%% *} )); EHSZ=$(( ${EHLINE##* } ))
                    dd if=link_out bs=1 skip="$EHOFF" count="$EHSZ" of=our_ehframe.bin 2>/dev/null
                    if cmp -s our_ehframe.bin ld_ehframe.bin; then
                        :
                    else
                        echo "FAIL  link_reloc.la: merged .eh_frame is not byte-identical to ld ($(stat -c%s our_ehframe.bin 2>/dev/null) vs $(stat -c%s ld_ehframe.bin) bytes) — CIE not deduped or an FDE mis-relocated"; ok=0
                    fi
                    rm -f our_ehframe.bin
                fi
                rm -f ld_ehframe.bin
            fi
        else
            echo "FAIL  link_reloc.la: gcc-object link emitted no executable"; ok=0
        fi
        rm -f gate_g1.o gate_g2.o
    fi
fi

# --- ★ -ffunction-sections: .text.* / .data.* merged into output sections ---
#   `gcc -ffunction-sections -fdata-sections` (the input to `--gc-sections`
#   dead-code elimination) splits code into .text.compute / .text.helper and
#   data into .rodata.<sym> / .data.<sym>. A linker MERGES each family into its
#   standard output section. This linker used to REFUSE them ("allocatable
#   section this layout cannot place: .text.compute"); it now maps every section
#   by OUTPUT name and packs the .text.* into the R+X segment. Assertion is the
#   EXIT STATUS: compute(21) -> helper(21)+1 = 43 travels through BOTH merged
#   functions, so a .text.* that was mis-merged, mis-ordered or left unresolved
#   segfaults or returns garbage — never exactly 43. (Same set -e caveat as the
#   gcc block: the fixture exits 43 BY DESIGN, captured, not run bare.)
if command -v gcc >/dev/null 2>&1; then
    gcc -c -O0 -ffunction-sections -fdata-sections -x c - -o gate_fs.o 2>/dev/null <<'CFS'
extern int helper(int);
int compute(int x){return helper(x)+1;}
int helper(int x){return x*2;}
CFS
    if [ -f gate_fs.o ]; then
        # Prove the fixture actually splits — else it would silently prove nothing.
        if readelf -SW gate_fs.o | grep -q '\.text\.compute'; then
            ld -o link_ref_fs link_test_start.o gate_fs.o 2>/dev/null
            if ./link_ref_fs; then LDFRC=0; else LDFRC=$?; fi
            cp link_test_start.o link_in1.o
            cp gate_fs.o          link_in2.o
            printf 'link_in1.o\nlink_in2.o\n' > link_inputs.txt
            rm -f link_out
            if FSOUT=$(timeout 240 ./tiny_host link_reloc.la 2>&1); then FSRC=0; else FSRC=$?; fi
            [ "$FSRC" -eq 0 ] \
                || { echo "FAIL  link_reloc.la: could not link -ffunction-sections object: $FSOUT"; ok=0; }
            if [ -x link_out ]; then
                if ./link_out; then OFRC=0; else OFRC=$?; fi
                [ "$OFRC" = "$LDFRC" ] \
                    || { echo "FAIL  -ffunction-sections link exited $OFRC, ld's binary exits $LDFRC"; ok=0; }
                [ "$OFRC" = "43" ] \
                    || { echo "FAIL  -ffunction-sections link exited $OFRC, expected 43 — a .text.* was mis-merged or unresolved"; ok=0; }
            else
                echo "FAIL  link_reloc.la: -ffunction-sections link emitted no executable"; ok=0
            fi
            rm -f link_in1.o link_in2.o link_inputs.txt link_ref_fs
        else
            echo "NOTE  link_reloc.la: gcc did not split sections — -ffunction-sections check skipped"
        fi
        rm -f gate_fs.o
    fi
fi

# --- ★ WEAK symbols: strong overrides weak; a weak def resolves when no strong ---
#   __attribute__((weak)) (and the weak symbols C++ emits for inline functions /
#   templates) bind differently from a plain global: a STRONG definition anywhere
#   overrides a weak one EVERYWHERE — even the weak object's own references — and
#   a weak definition satisfies a reference only when no strong one exists. Our
#   DEFINES (strong-only) already keeps a weak+strong pair from being a multiple-
#   definition error; this checks RESOLUTION, two ways:
#     A. weak-only   -> the weak def is used (was "unresolved symbol", a refusal
#        of a VALID link ld accepts);
#     B. weak+strong -> the strong def wins, INCLUDING the weak object's own
#        reference (was the weak def: exit 53, not ld's 43).
#   Assertion is exit-status agreement with ld — a mis-resolution changes it.
if command -v gcc >/dev/null 2>&1; then
    gcc -c -O0 -x c - -o w_ref.o    2>/dev/null <<'CWR'
extern int helper(int);
int compute(int x){return helper(x)+1;}
CWR
    gcc -c -O0 -x c - -o w_weak.o   2>/dev/null <<'CWW'
__attribute__((weak)) int helper(int x){return x*2;}
CWW
    gcc -c -O0 -x c - -o w_cw.o     2>/dev/null <<'CWC'
extern int helper(int);
int compute(int x){return helper(x)+1;}
__attribute__((weak)) int helper(int x){return x*100;}
CWC
    gcc -c -O0 -x c - -o w_strong.o 2>/dev/null <<'CWS'
int helper(int x){return x*2;}
CWS
    if [ -f w_weak.o ] && readelf -sW w_weak.o | grep -q 'WEAK.* helper'; then
        # A. weak fallback (no strong def anywhere)
        ld -o w_ref_a link_test_start.o w_ref.o w_weak.o 2>/dev/null
        if ./w_ref_a; then LDA=0; else LDA=$?; fi
        cp link_test_start.o link_in1.o; cp w_ref.o link_in2.o; cp w_weak.o link_in3.o
        printf 'link_in1.o\nlink_in2.o\nlink_in3.o\n' > link_inputs.txt; rm -f link_out
        if WAO=$(timeout 240 ./tiny_host link_reloc.la 2>&1); then :; else
            echo "FAIL  link_reloc.la: weak-only link failed (weak symbol not resolved): $WAO"; ok=0; fi
        if [ -x link_out ]; then
            if ./link_out; then OA=0; else OA=$?; fi
            [ "$OA" = "$LDA" ] || { echo "FAIL  weak-only link exited $OA, ld exits $LDA"; ok=0; }
        else echo "FAIL  weak-only: no executable emitted"; ok=0; fi
        # B. a strong def overrides the weak one, even the weak object's own ref
        ld -o w_ref_b link_test_start.o w_cw.o w_strong.o 2>/dev/null
        if ./w_ref_b; then LDB=0; else LDB=$?; fi
        cp w_cw.o link_in2.o; cp w_strong.o link_in3.o
        printf 'link_in1.o\nlink_in2.o\nlink_in3.o\n' > link_inputs.txt; rm -f link_out
        if WBO=$(timeout 240 ./tiny_host link_reloc.la 2>&1); then :; else
            echo "FAIL  link_reloc.la: weak+strong link failed: $WBO"; ok=0; fi
        if [ -x link_out ]; then
            if ./link_out; then OB=0; else OB=$?; fi
            [ "$OB" = "$LDB" ] \
                || { echo "FAIL  weak+strong link exited $OB, ld exits $LDB — the strong def did not override the weak one"; ok=0; }
        else echo "FAIL  weak+strong: no executable emitted"; ok=0; fi
        rm -f link_in1.o link_in2.o link_in3.o link_inputs.txt w_ref_a w_ref_b
    else
        echo "NOTE  link_reloc.la: gcc emitted no WEAK helper — weak-symbol check skipped"
    fi
    rm -f w_ref.o w_weak.o w_cw.o w_strong.o
fi

# --- ★ weak-UNDEF -> 0: an undefined WEAK reference resolves to 0, not an error ---
#   `extern T sym __attribute__((weak));` referenced but defined NOWHERE is not an
#   error in ld — the reference resolves to 0, the idiom behind optional-symbol
#   probing (`if (&opt) opt();`). RESOLVE_L is non-fatal now; SYMVAL turns a
#   still-unresolved WEAK reference into 0 while a STRONG one stays the loud
#   "unresolved symbol" (exercised by the negative gate above / the dup section).
#   Built -fno-pic so `&opt` is a direct R_X86_64_32, not a GOT reloc (GOTPCRELX /
#   type 42 is a separate unsupported-reloc gap). Assertion: it LINKS (a
#   regression would refuse it) and its exit matches ld's.
if command -v gcc >/dev/null 2>&1; then
    gcc -c -O0 -fno-pic -mcmodel=small -x c - -o wu.o 2>/dev/null <<'CWU'
extern int opt(int) __attribute__((weak));
int compute(int x){ return (&opt) ? opt(x) : x*2+1; }
CWU
    if [ -f wu.o ] && readelf -sW wu.o | grep -q 'WEAK.* opt$'; then
        ld -o wu_ref link_test_start.o wu.o 2>/dev/null
        if ./wu_ref; then LDU=0; else LDU=$?; fi
        cp link_test_start.o link_in1.o; cp wu.o link_in2.o
        printf 'link_in1.o\nlink_in2.o\n' > link_inputs.txt; rm -f link_out
        if WUO=$(timeout 240 ./tiny_host link_reloc.la 2>&1); then :; else
            echo "FAIL  link_reloc.la: undefined-weak link failed (weak ref not resolved to 0): $WUO"; ok=0; fi
        if [ -x link_out ]; then
            if ./link_out; then OU=0; else OU=$?; fi
            [ "$OU" = "$LDU" ] || { echo "FAIL  weak-undef link exited $OU, ld exits $LDU"; ok=0; }
        else echo "FAIL  weak-undef: no executable emitted"; ok=0; fi
        rm -f link_in1.o link_in2.o link_inputs.txt wu_ref
    else
        echo "NOTE  link_reloc.la: gcc emitted no undefined-WEAK opt — weak-undef check skipped"
    fi
    rm -f wu.o
fi

# --- ★ GOTPCRELX relaxation: PIC address-of-external through the GOT ---
#   A -fPIE/-fPIC object taking an external symbol's ADDRESS emits
#   `mov sym@GOTPCREL(%rip),%reg` with an R_X86_64_REX_GOTPCRELX reloc. For a
#   static image the address is known, so no GOT is needed: this linker RELAXES
#   the mov (opcode 8b) to lea (8d) and resolves the disp32 as a plain PC32 — as
#   ld does (it too emits no .got). Fixture: compute() takes &extfn (external),
#   extfn defined in a second object. Assertion is the EXIT STATUS matching ld:
#   exit 43 = extfn(21)*2+1 only holds if the address was LOADED (opcode
#   rewritten) and CALLED (disp correct) — an un-relaxed mov reads a nonexistent
#   GOT slot and calls garbage, a wrong disp calls the wrong place; neither is 43.
#   NOT byte-identical to ld, and that is a DIFFERENT VALID CHOICE, not a layout
#   accident: ld relaxes to `mov $addr,%reg` (48 c7, absolute immediate) while
#   this linker relaxes to `lea addr(%rip),%reg` (48 8d, PC-relative). Both load
#   the symbol's address; the lea form is position-independent (also correct for
#   a PIE image, where ld's absolute mov would not be), so the witness is that it
#   RUNS with ld's exit, not a byte-diff.
if command -v gcc >/dev/null 2>&1; then
    gcc -c -O0 -fPIE -x c - -o gx.o 2>/dev/null <<'CGX'
extern int extfn(int);
int compute(int x){ int (*f)(int) = extfn; return f(x)+1; }
CGX
    gcc -c -O0 -x c - -o gxd.o 2>/dev/null <<'CGXD'
int extfn(int x){ return x*2; }
CGXD
    if [ -f gx.o ] && readelf -rW gx.o | grep -q 'GOTPCREL'; then
        ld -o gx_ref link_test_start.o gx.o gxd.o 2>/dev/null
        if ./gx_ref; then LDX=0; else LDX=$?; fi
        cp link_test_start.o link_in1.o; cp gx.o link_in2.o; cp gxd.o link_in3.o
        printf 'link_in1.o\nlink_in2.o\nlink_in3.o\n' > link_inputs.txt; rm -f link_out
        if GXO=$(timeout 300 ./tiny_host link_reloc.la 2>&1); then :; else
            echo "FAIL  link_reloc.la: GOTPCRELX link failed: $GXO"; ok=0; fi
        if [ -x link_out ]; then
            if ./link_out; then OX=0; else OX=$?; fi
            [ "$OX" = "$LDX" ] \
                || { echo "FAIL  GOTPCRELX link exited $OX, ld exits $LDX — the mov->lea relaxation is wrong"; ok=0; }
        else echo "FAIL  GOTPCRELX: no executable emitted"; ok=0; fi
        rm -f link_in1.o link_in2.o link_in3.o link_inputs.txt gx_ref
    else
        echo "NOTE  link_reloc.la: gcc emitted no GOTPCREL reloc — GOTPCRELX check skipped"
    fi
    rm -f gx.o gxd.o
fi

# --- ★ REAL .got SYNTHESIS: a symbol referenced through the GOT as DATA ---
#   ld relaxes the mov/call GOTPCREL forms away (that is the GOTPCRELX case above,
#   where NEITHER linker keeps a .got). But `.quad sym@GOT` — R_X86_64_GOT64 —
#   stores a symbol's GOT-SLOT OFFSET as DATA and CANNOT be relaxed: ld
#   synthesises a real .got, and so must this linker. The fixture proves ld keeps
#   a .got (else the case is vacuous), then requires ours to RUN with ld's exit.
#     readval(): rbx = _GLOBAL_OFFSET_TABLE_ (GOTPC32), rax = val@GOT (GOT64),
#                then *(rbx+rax) = &val, then *&val = 41.  _start exits with it.
#   It exits 41 ONLY if the slot held &val and the base/offset both resolved — a
#   wrong GOT would fault or return garbage. (ld's GOT base sits PAST its slots,
#   ours at the slots' start: different convention, same result, so the witness
#   is ld's EXIT, not a byte-diff — a layout choice, like the segment ordering.)
cat > gg2.s <<'GGR'
.text
.globl readval
readval:
  lea _GLOBAL_OFFSET_TABLE_(%rip), %rbx
  movq gotslot(%rip), %rax
  movq (%rbx,%rax), %rax
  movl (%rax), %eax
  ret
.data
gotslot: .quad val@GOT
GGR
cat > gg1.s <<'GGS'
.text
.globl _start
_start:
  call readval
  mov %eax, %edi
  mov $60, %eax
  syscall
GGS
cat > gg3.s <<'GGV'
.data
.globl val
val: .long 41
GGV
gcc -c gg2.s -o gg2.o 2>/dev/null
if [ -f gg2.o ] && readelf -rW gg2.o | grep -q 'GOT64'; then
    gcc -c gg1.s -o gg1.o 2>/dev/null
    gcc -c gg3.s -o gg3.o 2>/dev/null
    ld -static --no-pie -e _start -o gg_ref gg1.o gg2.o gg3.o 2>/dev/null
    #   set -e: ./gg_ref exits 41 BY DESIGN, so capture via if/else — a bare
    #   `./gg_ref; LDGX=$?` would abort the whole script at the non-zero exit.
    if ./gg_ref >/dev/null 2>&1; then LDGX=0; else LDGX=$?; fi
    if readelf -SW gg_ref 2>/dev/null | grep -q ' \.got '; then
        cp gg1.o link_in1.o; cp gg2.o link_in2.o; cp gg3.o link_in3.o
        printf 'link_in1.o\nlink_in2.o\nlink_in3.o\n' > link_inputs.txt; rm -f link_out
        if GGO=$(timeout 400 ./tiny_host link_reloc.la 2>&1); then :; else
            echo "FAIL  link_reloc.la: real-.got link failed: $GGO"; ok=0; fi
        if [ -x link_out ]; then
            if ./link_out >/dev/null 2>&1; then OG=0; else OG=$?; fi
            [ "$OG" = "$LDGX" ] \
                || { echo "FAIL  real-.got link exited $OG, ld exits $LDGX — the .got synthesis is wrong"; ok=0; }
        else echo "FAIL  real-.got: no executable emitted"; ok=0; fi
        rm -f link_in1.o link_in2.o link_in3.o link_inputs.txt gg_ref
    else
        echo "NOTE  link_reloc.la: ld relaxed the GOT64 fixture (kept no .got) — real-.got check skipped"
    fi
    rm -f gg1.o gg3.o
else
    echo "NOTE  link_reloc.la: gcc/as emitted no GOT64 reloc — real-.got check skipped"
fi
rm -f gg1.s gg2.s gg3.s gg2.o

# --- ★ --gc-sections: drop unreferenced sections (opt-in) ---
#   A `--gc-sections` directive line in link_inputs.txt turns on dead-section
#   elimination: only sections REACHABLE from _start survive. The fixture adds a
#   `dead_never_called` function (its own .text.dead_never_called under
#   -ffunction-sections) that nothing references. WITH gc it must be dropped, so
#   our R+X segment shrinks to exactly what ld --gc-sections produces, AND the
#   program must still run (exit 43 — a wrongly-dropped LIVE section would
#   segfault, a wrongly-kept dead one would leave the segment too big). The
#   opt-in default (no directive) is already exercised by the -ffunction-sections
#   block above, which keeps every section and runs. .eh_frame's dead FDE is
#   pruned too (else the merge would fail relocating against the dropped
#   function) — proven implicitly: a failed prune aborts the link.
if command -v gcc >/dev/null 2>&1; then
    gcc -c -O0 -ffunction-sections -fdata-sections -x c - -o gate_gc.o 2>/dev/null <<'CGC'
extern int helper(int);
int compute(int x){return helper(x)+1;}
int helper(int x){return x*2;}
int dead_never_called(int x){return x*999+12345;}
CGC
    if [ -f gate_gc.o ] && readelf -SW gate_gc.o | grep -q '\.text\.dead_never_called'; then
        ld --gc-sections -o link_ref_gc link_test_start.o gate_gc.o -e _start 2>/dev/null
        if ./link_ref_gc; then LDGRC=0; else LDGRC=$?; fi
        LDGCSZ=$(readelf -lW link_ref_gc | awk '/LOAD/ && $7=="R" && $8=="E"{print $5; exit}')
        cp link_test_start.o link_in1.o
        cp gate_gc.o          link_in2.o
        printf -- '--gc-sections\nlink_in1.o\nlink_in2.o\n' > link_inputs.txt
        rm -f link_out
        if GCOUT=$(timeout 500 ./tiny_host link_reloc.la 2>&1); then GCRC=0; else GCRC=$?; fi
        [ "$GCRC" -eq 0 ] \
            || { echo "FAIL  link_reloc.la: --gc-sections link failed (a dead FDE mis-pruned?): $GCOUT"; ok=0; }
        if [ -x link_out ]; then
            if ./link_out; then OGRC=0; else OGRC=$?; fi
            [ "$OGRC" = "43" ] \
                || { echo "FAIL  --gc-sections link exited $OGRC, expected 43 — a live section was dropped or a dead one kept"; ok=0; }
            OURGCSZ=$(readelf -lW link_out | awk '/LOAD/ && $7=="R" && $8=="E"{print $5; exit}')
            [ "$OURGCSZ" = "$LDGCSZ" ] \
                || { echo "FAIL  --gc-sections R+X size $OURGCSZ, ld --gc-sections gives $LDGCSZ — dead_never_called not dropped (or a live section dropped)"; ok=0; }
        else
            echo "FAIL  link_reloc.la: --gc-sections link emitted no executable"; ok=0
        fi
        rm -f link_in1.o link_in2.o link_inputs.txt link_ref_gc
    else
        echo "NOTE  link_reloc.la: gcc did not split sections — --gc-sections check skipped"
    fi
    rm -f gate_gc.o
fi

# --- ★ A RELOCATION OUTSIDE .text — the SILENT-WRONGNESS case ---
#   Every other fixture above relocates in .text ONLY — verified, not assumed:
#   rw/b/abs/bss all carry `.rela.text` and nothing else, and link_test_c
#   carries no relocations at all. link_test_rw has a .data, but a .data of
#   LITERAL bytes, which needs no patching. So a linker applying only
#   `.rela.text` passed every check on this page.
#
#   link_test_reldata.asm closes that: `msgptr: dq msg` puts an R_X86_64_64 in
#   .data. Unpatched, msgptr stays 0, and the program writes from a null
#   pointer — which is the whole danger, because it does NOT crash:
#
#       the link succeeds, .data is placed, nothing is patched,
#       write(1, NULL, 15) returns -EFAULT, and the program exits 0.
#
#   ★ SO EXIT STATUS CANNOT BE THE ASSERTION. `exit=0` is exactly what the bug
#   produces; a gate checking only the status passes on the broken linker. The
#   assertion has to be the OUTPUT TEXT, and the empty-output-with-exit-0
#   signature is named explicitly so a regression says WHICH failure rather
#   than "differs from ld" (this board's method finding 3).
ld -o link_ref_reldata link_test_a.o link_test_reldata.o
cp link_test_a.o       link_in1.o
cp link_test_reldata.o link_in2.o
printf 'link_in1.o\nlink_in2.o\n' > link_inputs.txt
rm -f link_out
if RDOUT=$(timeout 240 ./tiny_host link_reloc.la 2>&1); then RDLRC=0; else RDLRC=$?; fi
[ "$RDLRC" -eq 0 ] \
    || { echo "FAIL  link_reloc.la: could not link the .rela.data fixture: $RDOUT"; ok=0; }
if [ -x link_out ]; then
    if RDGOT=$(./link_out 2>&1); then RDRC=0; else RDRC=$?; fi
    RDWANT=$(./link_ref_reldata 2>&1)
    #   the precise signature FIRST, so the diagnostic names the cause
    if [ -z "$RDGOT" ] && [ "$RDRC" = "0" ]; then
        echo "FAIL  link_reloc.la: .rela.data NOT applied — printed nothing and exited 0 (msgptr left unrelocated at 0; the null write returns -EFAULT and is discarded)"
        ok=0
    else
        [ "$RDGOT" = "$RDWANT" ] \
            || { echo "FAIL  link_reloc.la: .rela.data fixture printed '$RDGOT', ld's binary prints '$RDWANT'"; ok=0; }
    fi
    #   ...and the patched pointer ITSELF, read straight out of the writable
    #   segment — a direct look at the byte the bug leaves at zero, instead of
    #   inferring it from what was printed.
    #
    #   ★ NOT via `objcopy --only-section=.data`: this linker emits NO SECTION
    #   HEADERS, only program headers, so that form silently finds nothing and
    #   skips — a check that cannot fail, in the gate whose whole job is
    #   catching exactly that. It is read from the RW PT_LOAD's file offset.
    #
    #   The expected value is OUR OWN read-only segment's vaddr, not ld's:
    #   layout is a choice (see the 3-section case above), so what must hold is
    #   that msgptr points at the msg WE placed, whatever address we chose.
    RDRW=$(readelf -l --wide link_out 2>/dev/null | awk '/^  LOAD/ && $7=="RW" {print $2; exit}')
    RDRO=$(readelf -l --wide link_out 2>/dev/null | awk '/^  LOAD/ && $7=="R" && $8!="E" {print $3; exit}')
    if [ -n "$RDRW" ] && [ -n "$RDRO" ]; then
        RDPTR=$(dd if=link_out bs=1 skip=$(printf '%d' "$RDRW") count=8 2>/dev/null | od -An -tx8 | tr -d ' \n')
        RDWANT_PTR=$(printf '%016x' "$(printf '%d' "$RDRO")")
        if [ "$RDPTR" = "0000000000000000" ]; then
            echo "FAIL  link_reloc.la: msgptr is still 0 — the R_X86_64_64 in .data was never applied"; ok=0
        elif [ "$RDPTR" != "$RDWANT_PTR" ]; then
            echo "FAIL  link_reloc.la: msgptr is 0x$RDPTR but our .rodata segment is at 0x$RDWANT_PTR"; ok=0
        fi
    else
        echo "FAIL  link_reloc.la: .rela.data fixture emitted no RW or RO segment to check msgptr in"; ok=0
    fi
else
    echo "FAIL  link_reloc.la: .rela.data link emitted no executable"; ok=0
fi

rm -f link_in1.o link_in2.o link_inputs.txt
[ "$ok" = 1 ] && echo "PASS  link_reloc.la: relocations byte-identical to ld, AND THE LINKED PROGRAM RUNS (3 objects$([ "$GCC_RAN" = yes ] && echo " incl. REAL GCC OUTPUT"), PC32 + PLT32 + 64 + 32/32S + GOTPCRELX(mov->lea relax) + REAL .got SYNTHESIS (GOT64/GOTPC32 via .quad sym@GOT, non-relaxable, RUNS == ld), WEAK symbols (strong overrides weak; weak resolves when no strong; undefined weak -> 0), 5 sections incl. .bss and a writable segment + .eh_frame MERGED byte-identical to ld (deduped CIE, FDEs relocated to point at .text), -ffunction-sections .text.*/.data.* merged into output sections, --gc-sections drops unreferenced sections (== ld --gc-sections), W^X, page-aligned, 3 negative gates, .rela.data patched and ASSERTED BY OUTPUT not exit status)"
[ "$ok" = 1 ]
