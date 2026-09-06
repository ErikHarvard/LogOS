#!/usr/bin/env bash
# gate_asmelf.sh — the `-f elf64` gate: ld(asm.la's object) == ld(nasm's object).
#
# WHY THE GATE IS ONE LEVEL UP.
#   An object file's internal layout — section order, padding, and the bytes
#   sitting in a field a relocation is going to overwrite — is nasm CONVENTION,
#   not semantics. What an object MEANS is what it links to. So the standard is
#   byte-identity of the LINKED result, not of the `.o`. (Measured, not assumed:
#   clobbering a RELA field with DEADBEEF and relinking produced a byte-identical
#   executable, because ld computes S+A and overwrites the field.)
#
# WHY nasm IS GIVEN THE SAME FILE NAME.
#   nasm records its input's name as the FILE symbol, and that symbol survives
#   into the linked .symtab. Assembling `r3.asm` with nasm while asm.la reads
#   `asm_in.asm` would differ by that string alone — a real difference in the
#   linked output that has nothing to do with the assembler being right. Both
#   sides therefore assemble the file under the identical name.
#
# FIXTURES — and why there are two.
#   asm_elf_r3  every reloc type (64 / 32 / 32S) plus data relocs, all targeting
#               a label at section offset 0.
#   asm_elf_r4  the same shapes targeting a label at a NONZERO section offset.
#               This one is not redundant: red-path tested by forcing the addend
#               to a constant 0, r3 stayed GREEN while r4 went RED. r3 alone
#               cannot see a whole class of producer bug.
#
# Everything lands under .elfobjgate/ref/ inside this worktree — never /tmp,
# which is shared with the other tracks unless every session was launched via
# ~/logos-agent. Do not run this concurrently with the `-f bin` gate: both drive
# asm_in.asm in the worktree root.
set -u
cd "$(dirname "$0")" || exit 1
G=.elfobjgate/ref
mkdir -p "$G"

pass=0; fail=0
for f in asm_elf_*.asm; do
    n="${f%.asm}"
    cp "$f" asm_in.asm
    if ! ./tiny_host asmelfobj.la >"$G/$n.log" 2>&1; then
        printf 'FAIL %-14s producer: %s\n' "$n" "$(tail -1 "$G/$n.log")"; fail=$((fail+1)); continue
    fi
    cp elfobj_out.o "$G/$n.ours.o"
    nasm -f elf64 asm_in.asm -o "$G/$n.ref.o" || { printf 'FAIL %-14s nasm refused it\n' "$n"; fail=$((fail+1)); continue; }
    ld "$G/$n.ref.o"  -o "$G/$n.ref.elf"  2>"$G/$n.ldref.err" || { printf 'FAIL %-14s ld(nasm) failed\n' "$n"; fail=$((fail+1)); continue; }
    if ! ld "$G/$n.ours.o" -o "$G/$n.ours.elf" 2>"$G/$n.ldours.err"; then
        printf 'FAIL %-14s ld(ours) failed: %s\n' "$n" "$(head -1 "$G/$n.ldours.err")"; fail=$((fail+1)); continue
    fi
    if ! cmp -s "$G/$n.ref.elf" "$G/$n.ours.elf"; then
        printf 'FAIL %-14s %s\n' "$n" "$(cmp "$G/$n.ref.elf" "$G/$n.ours.elf" 2>&1 | head -1)"; fail=$((fail+1)); continue
    fi
    # SECOND ASSERTION — the section header TABLE, minus file offsets.
    #
    # DEFENCE IN DEPTH, and honestly labelled as such: every red path tried so
    # far (wrong addend, dropped st_value high half, dropped preamble equs,
    # alignment not raised, .bss typed PROGBITS) was already caught by ld==ld
    # above. This assertion has not yet caught anything that one missed.
    #
    # It is kept because it is nearly free and it pins the properties a
    # PERMISSIVE link could absorb — type, flags, alignment, size are SEMANTICS
    # (a NOBITS section occupies memory but not the file), whereas plain `ld`
    # with its default script is one linker with one policy. At boot.asm scale
    # the real link uses kernel/kernel.ld, where flags and alignment decide
    # placement. sh_offset and inter-section padding stay excluded: those really
    # are nasm convention, which is why the PRIMARY standard remains the link.
    #
    # (An earlier version of this comment claimed ld==ld was blind to the
    # PROGBITS/NOBITS swap. That was false — the red path that "passed" had
    # only changed which CONTENT was emitted, not the section type, so the
    # header still said NOBITS and the object was semantically identical. A
    # red path that does not test what you think it tests is worse than none:
    # it manufactures false confidence in the opposite direction.)
    if ! python3 - "$G/$n.ref.o" "$G/$n.ours.o" >"$G/$n.hdr.diff" 2>&1 <<'PY'
import subprocess, sys
def hdrs(p):
    out = subprocess.check_output(['readelf','-SW',p]).decode().splitlines()
    rows = []
    for ln in out:
        ln = ln.strip()
        if not ln.startswith('['): continue
        ln = ln[ln.index(']')+1:].split()
        if len(ln) < 9: continue          # the NULL section prints fewer columns
        name, typ, addr, off, size, es, *rest = ln
        flg  = rest[0] if len(rest) == 4 else ''
        al   = rest[-1]
        rows.append((name, typ, flg, al, size))
    return rows
a, b = hdrs(sys.argv[1]), hdrs(sys.argv[2])
if a != b:
    for x, y in zip(a, b):
        if x != y: print('nasm', x, '!= ours', y)
    if len(a) != len(b): print('section COUNT differs:', len(a), 'vs', len(b))
    sys.exit(1)
PY
    then
        printf 'FAIL %-14s section headers: %s\n' "$n" "$(head -1 "$G/$n.hdr.diff")"; fail=$((fail+1)); continue
    fi
    printf 'PASS %-14s ld(ours) == ld(nasm), headers match\n' "$n"; pass=$((pass+1))
done
echo "---- asm.la -f elf64 gate: $pass pass, $fail fail ----"
[ "$fail" -eq 0 ]
