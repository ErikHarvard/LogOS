#!/usr/bin/env bash
# gate_bootelf.sh — the boot.asm SCALE gate: ld(asm.la's object) == ld(nasm's).
#
# Promoted (and committed) from .elfobjgate/bootelf2/gate_boot.sh so the
# milestone "NASM is out of the kernel object step" (BOOTELF.md, GREEN
# 2026-07-23) is GUARDED ON DEMAND, not proven only by a manual VM cycle. The
# cheap per-build guard is gate_asmelf.sh (asm_elf_r3..r9, each a mechanism
# boot.asm needs); this is the full-scale check on the real 60 KB kernel boot
# file — 5 sections, 106 symbols, 53 relocations.
#
# THE STANDARD (same as gate_asmelf.sh, one level up from .o byte-identity):
#   an object's internal layout — section order, padding, the bytes in a field
#   a relocation will overwrite — is nasm convention, not semantics. What an
#   object MEANS is what it links to. So the gate is
#         ld(ours.o) == ld(nasm.o)   byte-identical,
#   backed by non-vacuous section-header / symbol-table / relocation identity
#   checks so a regression names the layer it broke instead of surfacing as one
#   anonymous byte diff in the linked image.
#
# WHAT THIS GATE DOES NOT DO — the honest boundary:
#   It does NOT re-derive ours.o. Producing asm.la+elfobj.la's object for
#   boot.asm is the ~26-minute native-SECD-VM cycle documented in BOOTELF.md
#   (la_flatten -> codegen.la -> logos_secd), which drives logos_program.bin and
#   so MUST run in an isolated `~/logos-agent a` session, in a scratch dir. This
#   gate takes that object as input and holds it to the standard. It also does
#   NOT link the final kernel — that seam is `ld` / link.la (Track B); this
#   closes only the ASSEMBLER + OBJECT-WRITER step.
#
# The reference is assembled by THIS script (fresh `nasm -f elf64` on the frozen
# boot source), never handed in, so a rigged ref.o cannot make it pass. boot.asm
# is read from a frozen copy dir, NOT kernel/boot.asm directly: track D
# regenerates entry.inc there per build, and reading kernel/ while D is live in
# it races. nasm and asm.la assemble from the SAME dir, so both see one entry.inc
# value and the comparison stays like-for-like — this proves the ASSEMBLER agrees
# with nasm, not that the object matches whatever kernel/ last built.
#
# USAGE
#   ./gate_bootelf.sh <ours.o> <bootsrc-dir>
#     <ours.o>        elfobj_out.o — asm.la+elfobj.la's ELF64 object for boot.asm
#     <bootsrc-dir>   a dir holding the frozen boot source as `asm_in.asm` plus
#                     its four %includes (entry.inc idt.asm timer.asm kbdirq.asm)
#                     and the incbin stub (native_codegen3_out). The frozen
#                     .bootrun/ set + .elfobjgate/ stub is one such dir; the last
#                     green VM run left a self-contained one at
#                     .elfobjgate/bootelf2/.
#
# All scratch lands in .elfobjgate/_bootelfgate/ under THIS worktree — never
# /tmp (so it is safe without isolation: nasm/ld/readelf only, no VM), never
# under kernel/. A missing or unreadable input HALTS LOUDLY (exit 1); it never
# skips to green. Requires nasm + ld + readelf + python3.
set -u

die() { echo "gate_bootelf: $*" >&2; exit 1; }

OURS="${1:-}"; DIR="${2:-}"
[ -n "$OURS" ] && [ -n "$DIR" ] || die "usage: $0 <ours.o> <bootsrc-dir>"
[ -s "$OURS" ] || die "no ours.o at '$OURS' (produce it via BOOTELF.md's VM cycle, isolated session)"
[ -d "$DIR" ]  || die "no bootsrc dir at '$DIR'"
[ -s "$DIR/asm_in.asm" ] || die "'$DIR' has no asm_in.asm (the frozen boot.asm)"
for inc in entry.inc idt.asm timer.asm kbdirq.asm native_codegen3_out; do
    [ -e "$DIR/$inc" ] || die "'$DIR' is missing boot.asm dependency: $inc"
done
command -v nasm    >/dev/null || die "nasm not found"
command -v ld      >/dev/null || die "ld not found"
command -v readelf >/dev/null || die "readelf not found"
command -v python3 >/dev/null || die "python3 not found"

# resolve inputs to absolute paths before we cd into scratch
OURS="$(cd "$(dirname "$OURS")" && pwd)/$(basename "$OURS")"
DIR="$(cd "$DIR" && pwd)"

ROOT="$(cd "$(dirname "$0")" && pwd)"
G="$ROOT/.elfobjgate/_bootelfgate"
rm -rf "$G"; mkdir -p "$G" || die "cannot make scratch $G"
cp "$OURS" "$G/boot_ours.o" || die "cannot stage ours.o"
# stage the frozen boot source + its deps INTO scratch, so nasm assembles the
# bare basename `asm_in.asm` from cwd — %includes and the incbin stub resolve
# from co-location, and nasm's FILE symbol is the basename, matching asm.la's
# (which names the FILE symbol by the basename it was given). Passing nasm an
# absolute path instead makes it record the whole path in .strtab, bloating the
# section and diverging the linked image — a like-for-like violation, NOT an
# assembler difference. This is exactly the invocation the milestone was proven
# with (.elfobjgate/bootelf2/gate_boot.sh: `nasm -f elf64 asm_in.asm`).
cp "$DIR/asm_in.asm" "$G/" || die "cannot stage asm_in.asm"
for inc in entry.inc idt.asm timer.asm kbdirq.asm native_codegen3_out; do
    cp "$DIR/$inc" "$G/" || die "cannot stage $inc"
done

cd "$G" || die "cannot cd scratch"
fail=0

# fresh reference: nasm on the bare basename from cwd (never handed a ref.o).
nasm -f elf64 asm_in.asm -o boot_ref.o 2>nasm.err \
    || { sed 's/^/  nasm: /' nasm.err >&2; die "nasm failed on the frozen boot.asm"; }

echo "== section headers (type/flags/align/size — semantics, not layout) =="
python3 - boot_ref.o boot_ours.o <<'PY' || fail=1
import subprocess, sys
def hdrs(p):
    rows = []
    for ln in subprocess.check_output(['readelf','-SW',p]).decode().splitlines():
        ln = ln.strip()
        if not ln.startswith('['): continue
        ln = ln[ln.index(']')+1:].split()
        if len(ln) < 9: continue
        name, typ, addr, off, size, es, *rest = ln
        rows.append((name, typ, rest[0] if len(rest) == 4 else '', rest[-1], size))
    return rows
a, b = hdrs(sys.argv[1]), hdrs(sys.argv[2])
for x, y in zip(a, b):
    print(('  ok  ' if x == y else '  DIFF'), x, '' if x == y else f'!= {y}')
if len(a) != len(b): print('  DIFF section count', len(a), 'vs', len(b))
sys.exit(0 if a == b else 1)
PY

echo "== symbol table (name/bind/type/shndx/value, in order) =="
diff <(readelf -sW boot_ref.o  | awk 'NR>3{$1="";print}') \
     <(readelf -sW boot_ours.o | awk 'NR>3{$1="";print}') >sym.diff 2>&1 \
  && echo "  ok   symbols identical ($(readelf -sW boot_ref.o | awk 'NR>3&&NF' | wc -l) entries)" \
  || { echo "  DIFF $(grep -c '^[<>]' sym.diff) lines — see $G/sym.diff"; head -6 sym.diff; fail=1; }

echo "== relocations (offset/type/symbol/addend, in order) =="
diff <(readelf -rW boot_ref.o  | awk '/R_X86/{print $1,$3,$5,$6,$7}') \
     <(readelf -rW boot_ours.o | awk '/R_X86/{print $1,$3,$5,$6,$7}') >rel.diff 2>&1 \
  && echo "  ok   relocations identical ($(readelf -rW boot_ref.o | awk '/R_X86/' | wc -l) relocs)" \
  || { echo "  DIFF $(grep -c '^[<>]' rel.diff) lines — see $G/rel.diff"; head -6 rel.diff; fail=1; }

echo "== THE GATE: ld(ours) == ld(nasm) =="
ld boot_ref.o  -o boot_ref.elf  2>ld_ref.err  || { sed 's/^/  ld ref: /' ld_ref.err >&2; die "ld failed on nasm's object"; }
ld boot_ours.o -o boot_ours.elf 2>ld_ours.err || { sed 's/^/  ld ours: /' ld_ours.err >&2; die "ld failed on asm.la's object"; }
if cmp -s boot_ref.elf boot_ours.elf; then
    echo "  ★ GREEN — linked outputs byte-identical (nasm-free object step holds)"
else
    echo "  RED — $(cmp boot_ref.elf boot_ours.elf 2>&1 | head -1)"; fail=1
fi

[ "$fail" = 0 ] && echo "---- gate_bootelf: GREEN ----" || echo "---- gate_bootelf: RED ----"
exit $fail
