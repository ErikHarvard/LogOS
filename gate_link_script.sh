#!/bin/sh
# gate_link_script.sh — the layout comes from a LINKER SCRIPT, and `ld -T` on
# the SAME FILE is the witness.
#
# WHY THIS GATE IS SHAPED THIS WAY. Every earlier layout check compared against
# `ld`'s DEFAULTS, so the linker was being asked "did you guess what ld does?"
# and the honest answer had to exclude ld's own choices (build-id, padding,
# section order). A linker script removes the guessing: both linkers are handed
# the same declaration of where things go, so the ADDRESSES are no longer either
# linker's invention and can be compared exactly. The fixture deliberately names
# 0x500000 — NOT the built-in 0x401000 — so an image built at the default
# address cannot pass by accident.
#
# Every expected value is read off `ld` AT GATE TIME (readelf/nm), never
# hard-coded from a run someone once eyeballed; and every parse is checked to
# have produced a value, because a check that cannot fail is not a check (this
# suite has already shipped one of those: an awk `strtonum` that mawk does not
# have errored to stderr, emitted nothing, and printed PASS).
set -e
cd "$(dirname "$0")"
ok=1

for t in nasm ld readelf nm; do
    command -v $t >/dev/null 2>&1 || { echo "SKIP  link_script gate: $t absent"; exit 0; }
done

SCRIPT=link_test_script.ld
[ -f "$SCRIPT" ] || { echo "FAIL  link_script gate: $SCRIPT missing"; exit 1; }

nasm -f elf64 link_test_a.asm -o link_in1.o
nasm -f elf64 link_test_b.asm -o link_in2.o

# ── the witness: ld given the SAME script ──────────────────────────────────
ld -o script_ref link_in1.o link_in2.o -T "$SCRIPT" 2>/dev/null \
    || { echo "SKIP  link_script gate: ld could not link with $SCRIPT"; exit 0; }

# Two LOAD segments, as (vaddr offset flags) triples, straight from readelf.
ld_segs=$(readelf -lW script_ref | awk '$1=="LOAD"{print $3, $2, $(NF-1)}')
ld_start=$(nm script_ref | awk '$3=="_start"{print $1}')
ld_greet=$(nm script_ref | awk '$3=="greet"{print $1}')
ld_msg=$(nm script_ref | awk '$3=="msg"{print $1}')

# ★ Assert the MEASUREMENT parsed before asserting anything about it.
[ -n "$ld_segs" ] && [ -n "$ld_start" ] && [ -n "$ld_greet" ] && [ -n "$ld_msg" ] \
    || { echo "FAIL  link_script: could not read ld's own layout (readelf/nm gave nothing) — the comparison below would have been vacuous"; exit 1; }

ld_out=$(./script_ref); ld_rc=$?

# ── POSITIVE: link.la follows the same script ──────────────────────────────
printf -- '--script=%s\nlink_in1.o\nlink_in2.o\n' "$SCRIPT" > link_inputs.txt
rm -f link_out
if out=$(timeout 300 ./tiny_host link_reloc.la 2>&1); then :; else
    echo "FAIL  link_script: link failed: $out"; exit 1; fi
[ -f link_out ] || { echo "FAIL  link_script: no link_out produced"; exit 1; }

our_segs=$(readelf -lW link_out | awk '$1=="LOAD"{print $3, $2, $(NF-1)}')
[ -n "$our_segs" ] || { echo "FAIL  link_script: our binary has no LOAD segments"; ok=0; }

if [ "$our_segs" = "$ld_segs" ]; then
    echo "PASS  link_script segments == ld -T's (vaddr/offset/flags, $(echo "$ld_segs" | wc -l) LOAD)"
else
    echo "FAIL  link_script segments differ from ld -T's"
    echo "        ld : $(echo "$ld_segs" | tr '\n' '|')"
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

# ── the strongest check: RUN it ────────────────────────────────────────────
our_out=$(./link_out); our_rc=$?
if [ "$our_out" = "$ld_out" ] && [ "$our_rc" = "$ld_rc" ]; then
    echo "PASS  link_script output runs: '$our_out' rc=$our_rc, same as ld -T's binary"
else
    echo "FAIL  link_script run: ours '$our_out' rc=$our_rc vs ld '$ld_out' rc=$ld_rc"
    ok=0
fi

# ── REGRESSION: no --script must change nothing ────────────────────────────
#   The built-in layout is now expressed in the same segment form the parser
#   produces, so it travels the new code path too. If that path had shifted the
#   default by even a page, every other gate would fail mysteriously; this says
#   so directly.
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

# ── NEGATIVE GATES ─────────────────────────────────────────────────────────
#   Each asserts WHICH diagnostic, never merely that the link failed: most wrong
#   implementations also exit non-zero, so "it failed" would pass while the
#   refusal fired in the wrong place — or while the script was being silently
#   half-obeyed, which is this feature's real failure mode.
neg() {   # $1=label  $2=expected substring  $3=script text
    _l="$1"; _want="$2"; _txt="$3"
    _f=$(mktemp); printf '%s' "$_txt" > "$_f"
    printf -- '--script=%s\nlink_in1.o\nlink_in2.o\n' "$_f" > link_inputs.txt
    if _o=$(timeout 300 ./tiny_host link_reloc.la 2>&1); then
        echo "FAIL  link_script negative [$_l]: LINKED instead of refusing"; ok=0
    else
        case "$_o" in
            *"$_want"*) echo "PASS  link_script refuses $_l" ;;
            *) echo "FAIL  link_script negative [$_l]: wrong diagnostic: $_o"; ok=0 ;;
        esac
    fi
    rm -f "$_f"
}

neg "a PHDRS block" "unsupported directive before SECTIONS: PHDRS" \
'ENTRY(_start)
PHDRS { boot PT_LOAD FLAGS(7); }
SECTIONS { . = 0x500000; .text : { *(.text) } }
'
neg "/DISCARD/" "/DISCARD/ is not supported" \
'SECTIONS { . = 0x500000; .text : { *(.text) }
 /DISCARD/ : { *(.comment) } }
'
neg "a wildcard pattern" "wildcards in a section pattern are not supported: .text*" \
'SECTIONS { . = 0x500000; .text : { *(.text*) } }
'
neg "(NOLOAD)" "expected \`<name> : {'" \
'SECTIONS { . = 0x500000; .b (NOLOAD) : { *(.bss) } }
'
neg "an output section with no address" "an output section appears before any" \
'SECTIONS { .text : { *(.text) } }
'
neg "a trailing MEMORY block" "unsupported directive after SECTIONS: MEMORY" \
'SECTIONS { . = 0x500000; .text : { *(.text) } }
MEMORY { ram : ORIGIN = 0 }
'
#   W^X is the one refusal that is OURS, not a parser limitation: the script is
#   perfectly well-formed, and ld would happily emit the RWX segment it implies.
neg "a segment that would need W+X" "would need W+X" \
'SECTIONS { . = 0x500000; .all : { *(.text) *(.data) } }
'

rm -f script_ref default_ref
[ "$ok" = 1 ] && echo "link_script gate GREEN" || { echo "link_script gate RED"; exit 1; }
