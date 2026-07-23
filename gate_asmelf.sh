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
    if cmp -s "$G/$n.ref.elf" "$G/$n.ours.elf"; then
        printf 'PASS %-14s ld(ours) == ld(nasm)\n' "$n"; pass=$((pass+1))
    else
        printf 'FAIL %-14s %s\n' "$n" "$(cmp "$G/$n.ref.elf" "$G/$n.ours.elf" 2>&1 | head -1)"; fail=$((fail+1))
    fi
done
echo "---- asm.la -f elf64 gate: $pass pass, $fail fail ----"
[ "$fail" -eq 0 ]
