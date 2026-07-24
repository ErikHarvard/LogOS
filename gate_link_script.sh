#!/bin/sh
# gate_link_script.sh — the layout comes from a LINKER SCRIPT, and `ld -T` on
# the SAME FILE is the witness.
#
# WHY THIS GATE IS SHAPED THIS WAY. Every earlier layout check compared against
# `ld`'s DEFAULTS, so the linker was being asked "did you guess what ld does?"
# and the honest answer had to exclude ld's own choices (build-id, padding,
# section order). A linker script removes the guessing: both linkers are handed
# the same declaration of where things go, so the ADDRESSES are no longer either
# linker's invention and can be compared exactly. The fixtures deliberately name
# 0x500000 and 0x100000 — NOT the built-in 0x401000 — so an image built at the
# default address cannot pass by accident.
#
# Every expected value is read off `ld` AT GATE TIME (readelf/nm), never
# hard-coded from a run someone once eyeballed; and every parse is checked to
# have produced a value, because a check that cannot fail is not a check (this
# suite has already shipped one of those: an awk `strtonum` that mawk does not
# have errored to stderr, emitted nothing, and printed PASS).
set -e
cd "$(dirname "$0")"
ok=1
finished=0

# ★ A GATE THAT STOPS EARLY MUST NOT LOOK LIKE A GATE THAT PASSED. `set -e` and
# a fixture that deliberately exits 43 are a bad pair: `out=$(./fixture)` made
# the shell exit — silently, with status 0 — so build.sh saw success while half
# the assertions never ran. Every run of a fixture below is wrapped in an `if`
# so its exit code is DATA, and this trap catches any other early exit.
trap 'rc=$?; if [ "$finished" != 1 ]; then echo "link_script gate ABORTED (rc=$rc) — the assertions after this point never ran"; [ "$rc" = 0 ] && exit 1; fi; exit $rc' EXIT

for t in nasm ld readelf nm; do
    command -v $t >/dev/null 2>&1 || { echo "SKIP  link_script gate: $t absent"; finished=1; exit 0; }
done

SCRIPT=link_test_script.ld
KSCRIPT=link_test_kernel.ld
for f in "$SCRIPT" "$KSCRIPT" link_test_mb.asm; do
    [ -f "$f" ] || { echo "FAIL  link_script gate: $f missing"; exit 1; }
done

nasm -f elf64 link_test_a.asm  -o link_in1.o
nasm -f elf64 link_test_b.asm  -o link_in2.o
nasm -f elf64 link_test_mb.asm -o link_in3.o

# Every LOAD segment as (vaddr offset filesz memsz flags) — the whole phdr, so
# a difference in ANY field is caught, not just the address.
segs_of() { readelf -lW "$1" | awk '$1=="LOAD"{print $3, $2, $5, $6, $(NF-1)}'; }

# ══ PART 1 — a plain script: `. =`, ALIGN, output sections ═════════════════
ld -o script_ref link_in1.o link_in2.o -T "$SCRIPT" 2>/dev/null \
    || { echo "SKIP  link_script gate: ld could not link with $SCRIPT"; finished=1; exit 0; }

ld_segs=$(segs_of script_ref)
ld_start=$(nm script_ref | awk '$3=="_start"{print $1}')
# ★ Assert the MEASUREMENT parsed before asserting anything about it.
[ -n "$ld_segs" ] && [ -n "$ld_start" ] \
    || { echo "FAIL  link_script: could not read ld's own layout (readelf/nm gave nothing) — the comparison below would have been vacuous"; exit 1; }
if ld_out=$(./script_ref); then ld_rc=0; else ld_rc=$?; fi

printf -- '--script=%s\nlink_in1.o\nlink_in2.o\n' "$SCRIPT" > link_inputs.txt
rm -f link_out
if out=$(timeout 300 ./tiny_host link_reloc.la 2>&1); then :; else
    echo "FAIL  link_script: link failed: $out"; exit 1; fi
[ -f link_out ] || { echo "FAIL  link_script: no link_out produced"; exit 1; }

our_segs=$(segs_of link_out)
if [ "$our_segs" = "$ld_segs" ]; then
    echo "PASS  link_script segments == ld -T's ($(echo "$ld_segs" | wc -l) LOAD, vaddr/offset/filesz/memsz/flags)"
else
    echo "FAIL  link_script segments differ from ld -T's"
    echo "        ld  : $(echo "$ld_segs"  | tr '\n' '|')"
    echo "        ours: $(echo "$our_segs" | tr '\n' '|')"
    ok=0
fi

# The script's own address must actually be in force — a linker that ignored
# the file entirely would still produce a self-consistent, runnable binary at
# 0x401000, which is exactly the failure this compares away.
entry=$(readelf -hW link_out | awk '/Entry point/{print $NF}')
want=$(printf '0x%x' "0x$ld_start")
[ "$entry" = "$want" ] \
    && echo "PASS  link_script entry $entry == ld's _start (the script's base, not the built-in 0x401000)" \
    || { echo "FAIL  link_script entry $entry != ld's _start $want"; ok=0; }

if our_out=$(./link_out); then our_rc=0; else our_rc=$?; fi
if [ "$our_out" = "$ld_out" ] && [ "$our_rc" = "$ld_rc" ]; then
    echo "PASS  link_script output runs: '$our_out' rc=$our_rc, same as ld -T's binary"
else
    echo "FAIL  link_script run: ours '$our_out' rc=$our_rc vs ld '$ld_out' rc=$ld_rc"
    ok=0
fi

# ══ PART 2 — the kernel-shaped script: PHDRS, (NOLOAD), /DISCARD/, `.note*` ══
#   This is `kernel/kernel.ld`'s shape: two explicitly-declared RWX segments,
#   .text and .bss sharing one of them ACROSS an alignment (which is why a
#   segment can no longer be "one `. =` group"), a NOLOAD section carrying
#   memory but no file bytes, and an allocatable note dropped by a wildcard.
ld -o kernel_ref link_in3.o -T "$KSCRIPT" 2>/dev/null \
    || { echo "SKIP  link_script gate: ld could not link with $KSCRIPT"; finished=1; exit 0; }
kld_segs=$(segs_of kernel_ref)
kld_bss=$(nm kernel_ref  | awk '$3=="scratch"{print $1}')
kld_img=$(nm kernel_ref  | awk '$3=="image"{print $1}')
kld_size=$(wc -c < kernel_ref)
[ -n "$kld_segs" ] && [ -n "$kld_bss" ] && [ -n "$kld_img" ] && [ "$kld_size" -gt 0 ] \
    || { echo "FAIL  link_script kernel: could not read ld's layout for $KSCRIPT"; exit 1; }
if kld_out=$(./kernel_ref); then kld_rc=0; else kld_rc=$?; fi

printf -- '--script=%s\nlink_in3.o\n' "$KSCRIPT" > link_inputs.txt
rm -f link_out
if out=$(timeout 400 ./tiny_host link_reloc.la 2>&1); then :; else
    echo "FAIL  link_script kernel: link failed: $out"; exit 1; fi

kour_segs=$(segs_of link_out)
if [ "$kour_segs" = "$kld_segs" ]; then
    echo "PASS  link_script kernel segments == ld -T's (PHDRS RWX honoured, .bss memsz > filesz)"
else
    echo "FAIL  link_script kernel segments differ from ld -T's"
    echo "        ld  : $(echo "$kld_segs"  | tr '\n' '|')"
    echo "        ours: $(echo "$kour_segs" | tr '\n' '|')"
    ok=0
fi

# The permissions must be what the PHDRS block ASKED for. Deriving them (the
# previous slice's rule) would refuse this script outright, so an RWX segment
# here is proof the declaration was read, not inferred.
nrwx=$(readelf -lW link_out | awk '$1=="LOAD" && $(NF-1)=="RWE"' | wc -l)
[ "$nrwx" -eq 2 ] \
    && echo "PASS  link_script kernel: both segments RWX, as PHDRS FLAGS(7) asked (never inferred — a derived layout refuses W+X)" \
    || { echo "FAIL  link_script kernel: expected 2 RWX segments from FLAGS(7), got $nrwx"; ok=0; }

# ★ FILE SIZE. Deriving each segment's file offset from its ADDRESS satisfies
# the loader's congruence rule and still produced a 3 MB file for this script
# (the two segments are 3 MB apart in memory) — correct, runnable, and useless
# as a kernel image. Offsets are packed now; this is the assertion that would
# have caught it.
kour_size=$(wc -c < link_out)
[ "$kour_size" -gt 0 ] || { echo "FAIL  link_script kernel: empty output"; ok=0; }
if [ "$kour_size" -le $(( kld_size * 2 )) ]; then
    echo "PASS  link_script kernel file size ${kour_size}B (ld ${kld_size}B) — segments PACKED in the file, not spread to match their addresses"
else
    echo "FAIL  link_script kernel file is ${kour_size}B against ld's ${kld_size}B — file offsets are tracking addresses instead of packing"
    ok=0
fi

if kour_out=$(./link_out); then kour_rc=0; else kour_rc=$?; fi
if [ "$kour_out" = "$kld_out" ] && [ "$kour_rc" = "$kld_rc" ]; then
    echo "PASS  link_script kernel RUNS: '$kour_out' rc=$kour_rc == ld's (rc reads a byte from the 2nd segment and a byte through .bss, so it only holds if BOTH landed)"
else
    echo "FAIL  link_script kernel run: ours '$kour_out' rc=$kour_rc vs ld '$kld_out' rc=$kld_rc"
    ok=0
fi

# ══ PART 3 — REGRESSION: no --script must change nothing ═══════════════════
printf 'link_in1.o\nlink_in2.o\n' > link_inputs.txt
rm -f link_out
if out=$(timeout 300 ./tiny_host link_reloc.la 2>&1); then :; else
    echo "FAIL  link_script regression: default link failed: $out"; ok=0; fi
def_entry=$(readelf -hW link_out | awk '/Entry point/{print $NF}')
ld -o default_ref link_in1.o link_in2.o 2>/dev/null
def_want=$(printf '0x%x' "0x$(nm default_ref | awk '$3=="_start"{print $1}')")
[ -n "$def_entry" ] && [ "$def_want" != "0x" ] \
    || { echo "FAIL  link_script regression: could not read either entry"; ok=0; }
[ "$def_entry" = "$def_want" ] \
    && echo "PASS  link_script regression: with no --script the default layout is unchanged (entry $def_entry)" \
    || { echo "FAIL  link_script regression: default entry $def_entry != ld's $def_want"; ok=0; }

# ══ PART 4 — NEGATIVE GATES ════════════════════════════════════════════════
#   Each asserts WHICH diagnostic, never merely that the link failed: most wrong
#   implementations also exit non-zero, so "it failed" would pass while the
#   refusal fired in the wrong place — or while the script was being silently
#   half-obeyed, which is this feature's real failure mode.
neg() {   # $1=label  $2=expected substring  $3=objects  $4=script text
    _l="$1"; _want="$2"; _objs="$3"; _txt="$4"
    _f=$(mktemp); printf '%s' "$_txt" > "$_f"
    { printf -- '--script=%s\n' "$_f"; printf '%s\n' $_objs; } > link_inputs.txt
    if _o=$(timeout 400 ./tiny_host link_reloc.la 2>&1); then
        echo "FAIL  link_script negative [$_l]: LINKED instead of refusing"; ok=0
    else
        case "$_o" in
            *"$_want"*) echo "PASS  link_script refuses $_l" ;;
            *) echo "FAIL  link_script negative [$_l]: wrong diagnostic: $_o"; ok=0 ;;
        esac
    fi
    rm -f "$_f"
}

#   ★ THE ONE THAT PROVES /DISCARD/ IS LOAD-BEARING. link_test_mb.asm carries an
#   ALLOCATABLE `.note.mine`; the kernel script drops it via `*(.note*)`. Take
#   the /DISCARD/ line away and the same link must be REFUSED by name. Without
#   this, a linker that ignored /DISCARD/ entirely would pass Part 2 (the note
#   is tiny and nothing references it) — the discard would be decorative.
neg "an allocatable section no segment places, once /DISCARD/ is removed" \
    "allocatable section this layout cannot place: .note.mine" "link_in3.o" \
'ENTRY(_start)
PHDRS { boot PT_LOAD FLAGS(7); img PT_LOAD FLAGS(7); }
SECTIONS {
  . = 0x100000;
  .boot : { *(.multiboot) *(.boot32) *(.text) *(.rodata) } :boot
  . = ALIGN(4096);
  .bss (NOLOAD) : { *(.bss) } :boot
  . = 0x400000;
  .la_image : { *(.la_image) } :img
}
'
neg "an output section assigned to an undeclared segment" \
    "no such segment declared in PHDRS: nowhere" "link_in3.o" \
'ENTRY(_start)
PHDRS { boot PT_LOAD FLAGS(7); }
SECTIONS {
  . = 0x100000;
  .boot : { *(.text) } :nowhere
  /DISCARD/ : { *(.multiboot) *(.boot32) *(.rodata) *(.bss) *(.la_image) *(.note*) }
}
'
neg "an output section with no :segment, in a script that declares PHDRS" \
    "every output section needs an explicit" "link_in3.o" \
'PHDRS { boot PT_LOAD FLAGS(7); }
SECTIONS {
  . = 0x100000;
  .boot : { *(.text) }
}
'
neg "a PHDRS entry with no FLAGS" \
    "no FLAGS for segment: boot" "link_in3.o" \
'PHDRS { boot PT_LOAD; }
SECTIONS { . = 0x100000; .boot : { *(.text) } :boot }
'
neg "a non-PT_LOAD segment type" \
    "only PT_LOAD segments are supported" "link_in3.o" \
'PHDRS { note PT_NOTE FLAGS(4); }
SECTIONS { . = 0x100000; .n : { *(.note*) } :note }
'
#   Two segments interleaved in the plan cannot be described by one
#   (base, filesz, memsz) triple each — they would overlap in the file while
#   every individual address stayed correct.
neg "two segments interleaved in one image" \
    "not contiguous" "link_in3.o" \
'ENTRY(_start)
PHDRS { a PT_LOAD FLAGS(7); b PT_LOAD FLAGS(7); }
SECTIONS {
  . = 0x100000;
  .one : { *(.text) } :a
  .two : { *(.rodata) } :b
  .three : { *(.boot32) } :a
  /DISCARD/ : { *(.multiboot) *(.bss) *(.la_image) *(.note*) }
}
'
neg "a star that is not a trailing wildcard" \
    "only a TRAILING" "link_in1.o link_in2.o" \
'SECTIONS { . = 0x500000; .text : { *(.te*t) } }
'
neg "an output section before any address" \
    "an output section appears before any" "link_in1.o link_in2.o" \
'SECTIONS { .text : { *(.text) } }
'
neg "a trailing MEMORY block" \
    "unsupported directive after SECTIONS: MEMORY" "link_in1.o link_in2.o" \
'SECTIONS { . = 0x500000; .text : { *(.text) } }
MEMORY { ram : ORIGIN = 0 }
'
#   W^X is the one refusal that is OURS, not a parser limitation: the script is
#   well-formed and ld would happily emit the RWX segment it implies. Declaring
#   it in PHDRS is allowed (Part 2); INFERRING it is not.
neg "a derived segment that would need W+X" "would need W+X" "link_in1.o link_in2.o" \
'SECTIONS { . = 0x500000; .all : { *(.text) *(.data) } }
'

# ══ PART 6 — THE SECTION HEADER TABLE ══════════════════════════════════════
#   The linker emitted no section headers at all until now (`e_shnum` 0), and
#   every gate passed, because every gate asked what the LOADER sees — and the
#   loader reads program headers. The gap surfaced only when the real kernel
#   image was linked byte-identically to ld's and the build's NEXT line,
#   `objcopy -O elf32-i386`, refused it: "the input file has no sections".
#   So the assertion here is the CONSUMER's, not ours: objcopy must accept it.
#
#   Note what is already covered elsewhere and deliberately not repeated: that
#   adding the table moved no loadable byte is exactly what Parts 1-2 check, by
#   comparing every LOAD segment's offset and size against ld's.
#   ★ FLAGS ARE COMPARED, not merely used to filter. The first version of this
#   printed (name, address, size) and used the flags column only to select the
#   allocatable sections — so it passed an output whose every section was marked
#   WAX (flags taken from the segment's permissions) where ld emits A / WA / A.
#   A field you filter on is a field you are not checking.
sec_quads() {   # ALLOC sections as (name addr size flags) — all four must agree with ld
    readelf -SW "$1" | sed 's/^ *\[[ 0-9]*\] *//' | awk '$1 ~ /^\./ && $7 ~ /A/ {print $1, $3, $5, $7}'
}

for pair in "$SCRIPT:link_in1.o link_in2.o" "$KSCRIPT:link_in3.o"; do
    scr=${pair%%:*}; objs=${pair#*:}
    ld -o sec_ref $objs -T "$scr" 2>/dev/null
    printf -- '--script=%s\n' "$scr" > link_inputs.txt
    printf '%s\n' $objs | tr ' ' '\n' >> link_inputs.txt
    rm -f link_out
    if out=$(timeout 400 ./tiny_host link_reloc.la 2>&1); then :; else
        echo "FAIL  link_script sections [$scr]: link failed: $out"; ok=0; continue; fi

    if objcopy -O elf32-i386 link_out sec_out32 2>sec_err; then
        echo "PASS  link_script sections [$scr]: objcopy -O elf32-i386 ACCEPTS the image (this is the kernel build's own next step)"
    else
        echo "FAIL  link_script sections [$scr]: objcopy refuses it: $(cat sec_err)"; ok=0
    fi

    ours=$(sec_quads link_out); theirs=$(sec_quads sec_ref)
    [ -n "$theirs" ] || { echo "FAIL  link_script sections [$scr]: ld's own section list came back empty — the comparison would be vacuous"; ok=0; }
    if [ "$ours" = "$theirs" ]; then
        echo "PASS  link_script sections [$scr]: $(echo "$ours" | wc -l) allocatable sections, name/address/size/FLAGS identical to ld's"
    else
        echo "FAIL  link_script sections [$scr]: allocatable sections differ from ld's"
        echo "        ld  : $(echo "$theirs" | tr '\n' '|')"
        echo "        ours: $(echo "$ours"   | tr '\n' '|')"
        ok=0
    fi
    rm -f sec_ref sec_out32 sec_err
done

# ══ PART 5 — the real kernel script parses ════════════════════════════════
#   `kernel/kernel.ld` belongs to track D, so this reads it and never writes it,
#   and it SKIPS when absent. It is a real assertion rather than a note because
#   the whole point of this slice is that the actual kernel script is within
#   reach: if D changes it into something unparseable, track B needs to hear
#   that from a gate and not from a surprise months later.
if [ -f kernel/kernel.ld ]; then
    printf -- '--script=kernel/kernel.ld\nlink_in3.o\n' > link_inputs.txt
    kout=$(timeout 400 ./tiny_host link_reloc.la 2>&1) || true
    case "$kout" in
        *"link script:"*)
            echo "FAIL  link_script: the REAL kernel/kernel.ld is not parseable: $kout"; ok=0 ;;
        *)
            echo "PASS  link_script parses the REAL kernel/kernel.ld (placement then fails on this fixture's sections, which is expected — the script is the assertion here)" ;;
    esac
else
    echo "SKIP  link_script: kernel/kernel.ld absent (track D's file)"
fi

rm -f script_ref kernel_ref default_ref
finished=1
[ "$ok" = 1 ] && echo "link_script gate GREEN" || { echo "link_script gate RED"; exit 1; }
