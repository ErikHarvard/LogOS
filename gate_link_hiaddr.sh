#!/bin/sh
# gate_link_hiaddr.sh — the 32-BIT WINDOW is enforced, not merely declared.
#
# ★ WHAT THIS EXISTS TO CATCH. link.la reads the LOW 4 bytes of each 8-byte
#   ELF64 field. Its header has always said the high word is "checked where it
#   costs nothing so the failure is loud rather than silent." It was NOT:
#   SYM_VHIGH was defined AND exported and called by NOTHING, and the STAB
#   record captured ST_VHI without ever looking at it. A symbol at or above
#   4 GB had its high word DISCARDED and linked to its low word.
#
# ★★ AND IT DEFEATED THE GUARD THAT DID EXIST. link_reloc.la's FITS32 refuses a
#   value too large to write into a 4-byte field — but a truncated READ yields a
#   SMALL number (0x1_0000_0000 reads as 0), which FITS32 then accepts. Guarding
#   the write is worthless while the read silently truncates; both directions
#   are needed to close one limit.
#
# ★★★ MEASURED RED PATH, not asserted. Against the PRE-GUARD linker this exact
#   fixture exits 0 and prints "resolved greet -> 4198416" — a symbol genuinely
#   at 0x100000000 linked to 0x401010. Plausible, wrong, and green. That is the
#   failure this gate converts into a loud refusal.
#
# Latent today (this layout sits near 0x401000, kernel.ld at 0x100000) and
# reachable the moment anything links high — a higher-half kernel at
# 0xffffffff80000000 is the obvious case.
#
# No `set -e`: this gate's assertions READ the output of commands that are
# EXPECTED to exit non-zero, and `set -e` would abort before the FAIL line ever
# printed. Statuses are checked explicitly instead.
cd "$(dirname "$0")" || exit 1
ok=1

command -v nasm    >/dev/null 2>&1 || { echo "SKIP  link_hiaddr gate: nasm absent"; exit 0; }
command -v readelf >/dev/null 2>&1 || { echo "SKIP  link_hiaddr gate: readelf absent"; exit 0; }

nasm -f elf64 link_test_a.asm -o link_test_a.o || { echo "FAIL  link_hiaddr: nasm a"; exit 1; }
nasm -f elf64 link_test_b.asm -o link_test_b.o || { echo "FAIL  link_hiaddr: nasm b"; exit 1; }

# ── CONTROL: the UNPATCHED objects must still link green. ────────────────────
#   A guard that refuses everything is as useless as one that refuses nothing,
#   and both look identical from the red case alone. This is the half that
#   proves the guard is SELECTIVE.
cp link_test_a.o link_in1.o
cp link_test_b.o link_in2.o
if timeout 240 ./tiny_host link_layout.la >/dev/null 2>&1; then
    echo "PASS  link_hiaddr control: an ordinary (sub-4 GB) link is NOT refused"
else
    echo "FAIL  link_hiaddr control: the guard refuses a NORMAL link — it fires on everything"
    ok=0
fi

# ── Locate greet's st_value high word, DERIVED at gate time, never hardcoded. ─
#   Offsets shift whenever the fixture changes; a baked constant would silently
#   patch the wrong byte and the gate would go green having tested nothing.
#   Scanned RELATIVE TO THE NAME, not by fixed field number: readelf prints
#   "[ 4]" as two whitespace-separated fields and "[12]" as one, so any fixed
#   $N shifts the moment the section index reaches double digits. Name, type,
#   address, offset are consecutive, so offset is (name field + 3).
symoff=$(readelf -S -W link_test_b.o \
         | awk '{for(i=1;i<=NF;i++) if($i==".symtab"){print $(i+3); exit}}')
idx=$(readelf -s -W link_test_b.o | awk '$8=="greet" {sub(/:/,"",$1); print $1; exit}')
if [ -z "$symoff" ] || [ -z "$idx" ]; then
    echo "FAIL  link_hiaddr gate bug: could not locate .symtab offset or 'greet' index"; exit 1
fi
# entry = symtab + idx*24; st_value at +8, its HIGH word at +12.
hi=$(( 0x$symoff + idx * 24 + 12 ))

cp link_test_a.o link_in1.o
cp link_test_b.o link_in2.o
printf '\001\000\000\000' | dd of=link_in2.o bs=1 seek="$hi" conv=notrunc status=none

# The patch must be real: readelf must now agree the symbol sits at 4 GB.
if ! readelf -s -W link_in2.o | awk '$8=="greet" {print $2}' | grep -qi '^0000000100000000$'; then
    echo "FAIL  link_hiaddr gate bug: patch did not land — greet is not at 0x100000000"
    readelf -s -W link_in2.o | grep greet
    exit 1
fi

# ── THE ASSERTION: refuse loudly, and name the symbol. ───────────────────────
OUT=$(timeout 240 ./tiny_host link_layout.la 2>&1)
rc=$?
if [ "$rc" -eq 0 ]; then
    echo "FAIL  link_hiaddr: a symbol at 0x100000000 was ACCEPTED (exit 0) — the high"
    echo "      word was discarded and the symbol linked to its low word. Got:"
    echo "$OUT" | grep -E 'greet' | sed 's/^/        /'
    ok=0
elif ! printf '%s' "$OUT" | grep -q 'symbol value above 4 GB'; then
    echo "FAIL  link_hiaddr: refused (rc=$rc) but WITHOUT the 32-bit-window diagnostic."
    echo "      A refusal for the wrong reason is not this guard firing. Got:"
    printf '%s\n' "$OUT" | tail -3 | sed 's/^/        /'
    ok=0
elif ! printf '%s' "$OUT" | grep -q 'greet'; then
    echo "FAIL  link_hiaddr: refused with the right diagnostic but did not NAME the symbol"
    ok=0
else
    echo "PASS  link_hiaddr: a symbol at 4 GB is REFUSED by name, not silently truncated to its low word"
fi

# ── THE THIRD ADDRESS SITE: the RELOCATION-APPLICATION path. ────────────────
#   ★ The two guards above were NOT enough, and only measurement said so. A
#   symbol that is DEFINED in the object referencing it never reaches the
#   cross-object resolver, so STADDR's guard never sees it; it goes through
#   SYMVAL, which added base + SYM_VALUE with no high-word check. That is the
#   path that actually PATCHES BYTES.
#   ★★ Reachable with ORDINARY COMPILER OUTPUT, which is what makes it matter:
#   nasm always relocates against SECTION symbols (st_value always 0, so the
#   high word is structurally 0 and this can never fire), but gcc/GAS relocate
#   against a DEFINED GLOBAL BY NAME — verified here, `movq $greet, %rax` emits
#   R_X86_64_32S against `greet` itself. Measured against the commit that added
#   the first two guards: it links this object rc=0, truncating silently.
#   Hence GAS, not nasm, for this case — with nasm the case is unconstructible.
if command -v gcc >/dev/null 2>&1; then
    G=.hiaddrgate; rm -rf "$G"; mkdir -p "$G"
    cat > "$G/sv.s" <<'ASM'
        .globl _start
        .globl greet
        .text
_start:
        movq    $greet, %rax
        movl    $60, %eax
        xorl    %edi, %edi
        syscall
greet:
        ret
ASM
    if gcc -c "$G/sv.s" -o link_in1.o 2>/dev/null; then
        gidx=$(readelf -s -W link_in1.o | awk '$8=="greet" {sub(/:/,"",$1); print $1; exit}')
        goff=$(readelf -S -W link_in1.o \
               | awk '{for(i=1;i<=NF;i++) if($i==".symtab"){print $(i+3); exit}}')
        if [ -n "$gidx" ] && [ -n "$goff" ]; then
            printf '\001\000\000\000' | dd of=link_in1.o bs=1 \
                seek=$(( 0x$goff + gidx * 24 + 12 )) conv=notrunc status=none
            printf 'link_in1.o\n' > link_inputs.txt
            ROUT=$(timeout 300 ./tiny_host link_reloc.la 2>&1)
            rrc=$?
            if [ "$rrc" -eq 0 ]; then
                echo "FAIL  link_hiaddr reloc-path: link_reloc.la ACCEPTED (exit 0) a DEFINED"
                echo "      GLOBAL at 0x100000010 — SYMVAL truncated the high word on the path"
                echo "      that patches bytes. Got: $(printf '%s' "$ROUT" | tail -1)"
                ok=0
            elif printf '%s' "$ROUT" | grep -q 'symbol value above 4 GB'; then
                echo "PASS  link_hiaddr reloc-path: a DEFINED GLOBAL at 4 GB is REFUSED by link_reloc.la (SYMVAL), not truncated"
            else
                echo "FAIL  link_hiaddr reloc-path: refused (rc=$rrc) but not with the 32-bit-window"
                echo "      diagnostic — a refusal for another reason is not this guard firing:"
                printf '%s\n' "$ROUT" | tail -2 | sed 's/^/        /'
                ok=0
            fi
        else
            echo "FAIL  link_hiaddr gate bug: could not locate greet/symtab in the GAS object"; ok=0
        fi
    else
        echo "SKIP  link_hiaddr reloc-path: gcc cannot assemble the GAS fixture"
    fi
    rm -rf "$G"
else
    echo "SKIP  link_hiaddr reloc-path: gcc absent"
fi

rm -f link_in1.o link_in2.o
[ "$ok" -eq 1 ] || exit 1
