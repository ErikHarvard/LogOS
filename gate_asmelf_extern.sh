#!/usr/bin/env bash
# gate_asmelf_extern.sh — the `-f elf64` MULTI-OBJECT gate: asm.la's `extern`.
#
# WHY THIS IS A SEPARATE GATE FROM gate_asmelf.sh.
#   gate_asmelf.sh links each object ALONE. An object with an UNRESOLVED extern
#   cannot link alone — `ld` errors "undefined reference". The whole point of an
#   extern is that another object supplies the symbol, so the smallest honest
#   test is a TWO-object link: a.o references `greet`, b.o defines it.
#
#   a.asm:  extern greet;  mov rax, greet (code reloc);  dq greet (data reloc)
#   b.asm:  global greet;  greet: ...
#
#   This is the exact threshold link.la (Track B) was built to cross — a symbol
#   UNDEFINED in one object, DEFINED in another, resolved across the two. asm.la
#   could not DECLARE such a symbol until the extern slice; now it can.
#
# THE STANDARD IS ld(ours) == ld(nasm), as in gate_asmelf.sh — byte-identity of
#   the LINKED result of BOTH objects, not of either .o (object internal layout
#   is nasm convention, not semantics). Everything lands under .elfobjgate/xern/
#   inside this worktree — never /tmp. Do not run concurrently with the other
#   asm gates: all three drive asm_in.asm in the worktree root.
#
# NON-VACUITY: beyond ld==ld, the gate asserts (a) a.ours.o actually carries an
#   UNDEF GLOBAL `greet` symbol and a relocation NAMING greet — proof the extern
#   path fired rather than greet silently becoming local — and (b) the linked
#   ours.elf RUNS and exits 0. A green with none of those would be decorative.
set -u
cd "$(dirname "$0")" || exit 1
G=.elfobjgate/xern
mkdir -p "$G"

finished=0
trap '[ "$finished" = 1 ] || { echo "---- extern gate: ABORTED early ----"; exit 1; }' EXIT

fail=0

assemble() {          # $1 = fixture file, $2 = short name
    local f="$1" n="$2"
    cp "$f" asm_in.asm
    if ! timeout 180 ./tiny_host asmelfobj.la >"$G/$n.prod.log" 2>&1; then
        echo "FAIL $n: asm.la producer error: $(tail -1 "$G/$n.prod.log")"; return 1
    fi
    [ -s elfobj_out.o ] || { echo "FAIL $n: asm.la produced an empty object"; return 1; }
    cp elfobj_out.o "$G/$n.ours.o"
    nasm -f elf64 asm_in.asm -o "$G/$n.ref.o" || { echo "FAIL $n: nasm refused it"; return 1; }
    return 0
}

assemble asmxern_a.asm a || fail=1
assemble asmxern_b.asm b || fail=1

if [ "$fail" = 0 ]; then
    # (a) the extern mechanism actually fired in a.ours.o — both externs UNDEF,
    #     an ABSOLUTE reloc (R_X86_64_64) against greet, and a PC-RELATIVE reloc
    #     (R_X86_64_PLT32) against exiter (the `jmp exiter` path). A green without
    #     these would be decorative — greet could have silently become local, or
    #     the jmp could have been a short rel8 with no reloc at all.
    for sym in greet exiter; do
        if ! readelf -sW "$G/a.ours.o" | grep -qE "UND[[:space:]]+$sym\$"; then
            echo "FAIL: a.ours.o has no UNDEF '$sym' symbol (extern not emitted)"
            readelf -sW "$G/a.ours.o" | grep -iE 'greet|exiter' || true
            fail=1
        fi
    done
    if ! readelf -rW "$G/a.ours.o" | grep -qE 'R_X86_64_64.*greet'; then
        echo "FAIL: a.ours.o has no absolute (R_X86_64_64) reloc against greet"
        readelf -rW "$G/a.ours.o" || true
        fail=1
    fi
    if ! readelf -rW "$G/a.ours.o" | grep -qE 'R_X86_64_PLT32.*exiter'; then
        echo "FAIL: a.ours.o has no PC-relative (R_X86_64_PLT32) reloc against exiter (jmp-extern)"
        readelf -rW "$G/a.ours.o" || true
        fail=1
    fi
    if ! readelf -rW "$G/a.ours.o" | grep -qE 'R_X86_64_PC32.*greet'; then
        echo "FAIL: a.ours.o has no RIP-relative (R_X86_64_PC32) reloc against greet ([rel greet])"
        readelf -rW "$G/a.ours.o" || true
        fail=1
    fi
fi

if [ "$fail" = 0 ]; then
    # (b) the primary standard: ld(ours+ours) == ld(nasm+nasm), byte-identical
    ld "$G/a.ref.o"  "$G/b.ref.o"  -o "$G/ref.elf"  2>"$G/ldref.err" \
        || { echo "FAIL: ld(nasm) failed: $(head -1 "$G/ldref.err")"; fail=1; }
    ld "$G/a.ours.o" "$G/b.ours.o" -o "$G/ours.elf" 2>"$G/ldours.err" \
        || { echo "FAIL: ld(ours) failed: $(head -1 "$G/ldours.err")"; fail=1; }
fi

if [ "$fail" = 0 ]; then
    if cmp -s "$G/ref.elf" "$G/ours.elf"; then
        echo "PASS ld(ours) == ld(nasm) on the two-object extern link"
    else
        echo "FAIL linked output differs: $(cmp "$G/ref.elf" "$G/ours.elf" 2>&1 | head -1)"; fail=1
    fi
fi

if [ "$fail" = 0 ]; then
    # (c) it RUNS and exits 0 (the resolved extern didn't corrupt the image)
    if "$G/ours.elf"; then
        echo "PASS ours.elf runs and exits 0"
    else
        echo "FAIL ours.elf exited $? (linked binary is broken)"; fail=1
    fi
fi

finished=1
if [ "$fail" = 0 ]; then echo "---- asm.la -f elf64 extern gate: GREEN ----"; else echo "---- asm.la -f elf64 extern gate: RED ----"; fi
[ "$fail" -eq 0 ]
