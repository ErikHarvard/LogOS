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
    fsz=$(stat -c%s link_out)
    lastend=0
    for pair in $(readelf -l --wide link_out 2>/dev/null | awk '/^  LOAD/ {print $2","$5}'); do
        poff=${pair%,*}; pfsz=${pair#*,}
        [ "$pfsz" = "0x000000" ] && continue
        end=$(( $(printf '%d' "$poff") + $(printf '%d' "$pfsz") ))
        [ "$end" -gt "$lastend" ] && lastend=$end
    done
    [ "$fsz" = "$lastend" ] \
        || { echo "FAIL  link_reloc.la: file is $fsz bytes but its last loadable byte is at $lastend — $((fsz - lastend)) bytes of padding nothing reads"; ok=0; }
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
        else
            echo "FAIL  link_reloc.la: gcc-object link emitted no executable"; ok=0
        fi
        rm -f gate_g1.o gate_g2.o
    fi
fi

rm -f link_in1.o link_in2.o link_inputs.txt
[ "$ok" = 1 ] && echo "PASS  link_reloc.la: relocations byte-identical to ld, AND THE LINKED PROGRAM RUNS (3 objects$([ "$GCC_RAN" = yes ] && echo " incl. REAL GCC OUTPUT"), PC32 + PLT32 + 64 + 32/32S, 4 sections incl. .bss and a writable segment, W^X, page-aligned, 3 negative gates)"
[ "$ok" = 1 ]
