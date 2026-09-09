#!/usr/bin/env bash
# gate_bootelf.sh — the boot.asm SCALE gate: ld(asm.la's object) == ld(nasm's),
# PER CONDITIONAL ARM.
#
# Promoted (and committed) from .elfobjgate/bootelf2/gate_boot.sh so the
# milestone "NASM is out of the kernel object step" (BOOTELF.md, GREEN
# 2026-07-23) is GUARDED ON DEMAND, not proven only by a manual VM cycle. The
# cheap per-build guard is gate_asmelf.sh (asm_elf_r3..r9, each a mechanism
# boot.asm needs); this is the full-scale check on the real 60 KB kernel boot
# file.
#
# ── WHY THIS GATE IS PER-ARM (FREEZE_II_FINDINGS.md Q0b) ─────────────────────
# This gate used to assemble boot.asm ONCE, with no -D flags, and it came back
# GREEN having assembled NONE of the three `equ` sites it exists to cover. The
# sites sit inside an %elifdef chain (kernel/boot.asm:364 %ifdef K6A ... :610
# %elifdef HH1 ... :676 %elifdef HH2 ...), so with nothing defined no arm is
# taken and the preprocessor deletes the defective construct before the
# assembler ever sees it. The green was TRUE and it was HOLLOW.
#
#   MEASURED, by assembling each arm and reading the SYMBOL TABLE of the
#   resulting object — never by reading the directives, which two independent
#   readers got wrong on this same file:
#     arm    object    equ sites present in the object
#     NONE     6864 B  (none — 0 of 3)          <- what this gate used to run
#     HH1      7424 B  hh_msg_len
#     HH2      8368 B  hh2_ok_len, hh2_bad_len
#   HH1 and HH2 are MUTUALLY EXCLUSIVE arms of one chain, so no single build can
#   carry all three sites: %define HH1 alone exercises ONE of three and reports
#   green. Coverage here is therefore a property of the ARM SET, not of the run,
#   and the gate asserts its own arm set below rather than trusting a caller to
#   pass the right flags.
#
# THE STANDARD (same as gate_asmelf.sh, one level up from .o byte-identity):
#   an object's internal layout — section order, padding, the bytes in a field
#   a relocation will overwrite — is nasm convention, not semantics. What an
#   object MEANS is what it links to. So the gate is
#         ld(ours.o) == ld(nasm.o)   byte-identical, PER ARM,
#   backed by non-vacuous section-header / symbol-table / relocation identity
#   checks so a regression names the layer it broke instead of surfacing as one
#   anonymous byte diff in the linked image.
#
# ── THE COVERAGE ASSERTION, AND WHY IT IS NOT DECORATION ─────────────────────
# Comparing ours.o to ref.o cannot notice that BOTH are missing the construct:
# a source-level or preprocessor-level disappearance moves both sides equally
# and stays green. That is exactly how the hollow green happened. So each arm
# additionally asserts that the sites it exists to cover are PRESENT in both
# objects, and the NONE arm asserts they are ABSENT — the control that proves
# the arms are doing the work rather than the assertion passing vacuously.
# Red-tested: dropping the %define from an arm makes that arm FAIL the presence
# assertion instead of quietly assembling the empty configuration.
#
# WHAT THIS GATE DOES NOT DO — the honest boundary:
#   It does NOT re-derive ours.o. Producing asm.la+elfobj.la's object for
#   boot.asm is the native-SECD-VM cycle documented in BOOTELF.md, which drives
#   logos_program.bin and so MUST run in an isolated `~/logos-agent a` session,
#   in a scratch dir. This gate takes those objects as input and holds them to
#   the standard. It also does NOT link the final kernel — that seam is `ld` /
#   link.la (Track B); this closes only the ASSEMBLER + OBJECT-WRITER step. And
#   it covers the arms named in ARMS below, which are the arms carrying the
#   three equ sites — NOT all 51 conditional arms in boot.asm (49 are covered by neither gate).
#
# The reference is assembled by THIS script (fresh `nasm -f elf64` on the frozen
# boot source, per arm), never handed in, so a rigged ref.o cannot make it pass.
# boot.asm is read from a frozen copy dir, NOT kernel/boot.asm directly: track D
# regenerates entry.inc there per build, and reading kernel/ while D is live in
# it races. nasm and asm.la assemble from the SAME per-arm file — the arm is
# selected by a `%define` prepended to the source, not by a -D flag on one side
# only — so both see one configuration and the comparison stays like-for-like.
# (asm.la has a full %define/%ifdef/%ifndef/%elifdef/%else/%endif preprocessor
# of its own, so no asm.la change was needed to reach the arms. MEASURED that
# the prepend is exactly -D semantics rather than assumed: for HH1 and HH2,
# `nasm -f elf64 -D $ARM asm_in.asm` and `nasm -f elf64 asm_in.asm` on the
# %define-prepended file produce BYTE-IDENTICAL objects.)
#
# USAGE
#   ./gate_bootelf.sh <bootsrc-dir> <objdir>
#     <bootsrc-dir>  a dir holding the frozen boot source as `boot_base.asm`
#                    plus its four %includes (entry.inc idt.asm timer.asm
#                    kbdirq.asm) and the incbin stub (native_codegen3_out).
#     <objdir>       a dir holding asm.la+elfobj.la's ELF64 object for EACH arm,
#                    named ours_<ARM>.o (ours_NONE.o, ours_HH1.o, ours_HH2.o).
#                    Each is produced by the BOOTELF.md cycle run on the
#                    corresponding per-arm source this script writes out.
#
# All scratch lands in .elfobjgate/_bootelfgate/ under THIS worktree — never
# /tmp (so it is safe without isolation: nasm/ld/readelf only, no VM), never
# under kernel/. A missing or unreadable input HALTS LOUDLY (exit 1); it never
# skips to green. Requires nasm + ld + readelf + python3.
set -u

die() { echo "gate_bootelf: $*" >&2; exit 1; }

# The arm set this gate covers, and the equ sites each arm must carry.
ARMS="NONE HH1 HH2"
sites_for() {
    case "$1" in
        NONE) echo "" ;;
        HH1)  echo "hh_msg_len" ;;
        HH2)  echo "hh2_ok_len hh2_bad_len" ;;
        *)    die "no coverage declared for arm '$1'" ;;
    esac
}
# Every site the arm set must cover between them. If an arm stops carrying its
# site, the union shrinks and the gate fails rather than reporting a true-but-
# hollow green.
REQUIRED_SITES="hh_msg_len hh2_ok_len hh2_bad_len"

DIR="${1:-}"; OBJDIR="${2:-}"
[ -n "$DIR" ] && [ -n "$OBJDIR" ] || die "usage: $0 <bootsrc-dir> <objdir>"
[ -d "$DIR" ]    || die "no bootsrc dir at '$DIR'"
[ -d "$OBJDIR" ] || die "no object dir at '$OBJDIR'"
[ -s "$DIR/boot_base.asm" ] || die "'$DIR' has no boot_base.asm (the frozen boot.asm)"
for inc in entry.inc idt.asm timer.asm kbdirq.asm native_codegen3_out; do
    [ -e "$DIR/$inc" ] || die "'$DIR' is missing boot.asm dependency: $inc"
done
for arm in $ARMS; do
    [ -s "$OBJDIR/ours_$arm.o" ] \
      || die "no ours_$arm.o in '$OBJDIR' (produce it via BOOTELF.md's VM cycle on the $arm source, isolated session) — an uncovered arm is a FAIL, never a skip"
done
command -v nasm    >/dev/null || die "nasm not found"
command -v ld      >/dev/null || die "ld not found"
command -v readelf >/dev/null || die "readelf not found"
command -v python3 >/dev/null || die "python3 not found"

DIR="$(cd "$DIR" && pwd)"
OBJDIR="$(cd "$OBJDIR" && pwd)"
ROOT="$(cd "$(dirname "$0")" && pwd)"
G="$ROOT/.elfobjgate/_bootelfgate"
rm -rf "$G"; mkdir -p "$G" || die "cannot make scratch $G"

# stage the frozen boot source + its deps INTO scratch, so nasm assembles a bare
# basename from cwd — %includes and the incbin stub resolve from co-location,
# and nasm's FILE symbol is the basename, matching asm.la's (which names the
# FILE symbol by the basename it was given). Passing nasm an absolute path
# instead makes it record the whole path in .strtab, bloating the section and
# diverging the linked image — a like-for-like violation, NOT an assembler
# difference.
cp "$DIR/boot_base.asm" "$G/" || die "cannot stage boot_base.asm"
for inc in entry.inc idt.asm timer.asm kbdirq.asm native_codegen3_out; do
    cp "$DIR/$inc" "$G/" || die "cannot stage $inc"
done

cd "$G" || die "cannot cd scratch"
fail=0
covered=""

# Symbols present in an object's symbol table, one per line.
symnames() { readelf -sW "$1" | awk 'NR>3 && NF>=8 {print $8}'; }

for arm in $ARMS; do
    echo
    echo "######## ARM $arm ########"
    # ONE source per arm, read by BOTH assemblers. The arm is selected by a
    # %define prepended to the frozen source — never by a -D on one side only,
    # which would be a like-for-like violation.
    if [ "$arm" = NONE ]; then
        cp boot_base.asm asm_in.asm || die "cannot write asm_in.asm"
    else
        { printf '%%define %s\n' "$arm"; cat boot_base.asm; } > asm_in.asm \
          || die "cannot write asm_in.asm for $arm"
    fi
    cp asm_in.asm "asm_in_$arm.asm"
    cp "$OBJDIR/ours_$arm.o" boot_ours.o || die "cannot stage ours_$arm.o"

    nasm -f elf64 asm_in.asm -o boot_ref.o 2>"nasm_$arm.err" \
        || { sed 's/^/  nasm: /' "nasm_$arm.err" >&2; die "nasm failed on the $arm boot.asm"; }

    # ── COVERAGE: the construct this arm exists to cover must BE THERE ───────
    # Checked in BOTH objects: comparing ours to ref cannot notice that both
    # lost the construct, which is exactly how this gate went hollow-green.
    want="$(sites_for "$arm")"
    if [ -n "$want" ]; then
        echo "== coverage: equ sites this arm must carry =="
        for s in $want; do
            if symnames boot_ref.o | grep -qx "$s" && symnames boot_ours.o | grep -qx "$s"; then
                echo "  ok   $s present in BOTH ref and ours"
                covered="$covered $s"
            else
                echo "  MISSING $s — the arm assembled a configuration in which the construct does not exist (hollow green); ref=$(symnames boot_ref.o | grep -cx "$s") ours=$(symnames boot_ours.o | grep -cx "$s")"
                fail=1
            fi
        done
    else
        # The control. NONE is the configuration this gate used to run, and it
        # must carry NONE of the sites — if it ever does, the arms are not what
        # selects them and every per-arm claim above is meaningless.
        echo "== control: the no-define configuration must carry NO equ site =="
        ctl=0
        for s in $REQUIRED_SITES; do
            if symnames boot_ref.o | grep -qx "$s"; then
                echo "  UNEXPECTED $s present with no %define — the arm set no longer selects the sites"; fail=1; ctl=1
            fi
        done
        [ "$ctl" = 0 ] && echo "  ok   none of: $REQUIRED_SITES (this is the hollow configuration, kept as the control)"
    fi

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
         <(readelf -sW boot_ours.o | awk 'NR>3{$1="";print}') >"sym_$arm.diff" 2>&1 \
      && echo "  ok   symbols identical ($(readelf -sW boot_ref.o | awk 'NR>3&&NF' | wc -l) entries)" \
      || { echo "  DIFF $(grep -c '^[<>]' "sym_$arm.diff") lines — see $G/sym_$arm.diff"; head -6 "sym_$arm.diff"; fail=1; }

    echo "== relocations (offset/type/symbol/addend, in order) =="
    diff <(readelf -rW boot_ref.o  | awk '/R_X86/{print $1,$3,$5,$6,$7}') \
         <(readelf -rW boot_ours.o | awk '/R_X86/{print $1,$3,$5,$6,$7}') >"rel_$arm.diff" 2>&1 \
      && echo "  ok   relocations identical ($(readelf -rW boot_ref.o | awk '/R_X86/' | wc -l) relocs)" \
      || { echo "  DIFF $(grep -c '^[<>]' "rel_$arm.diff") lines — see $G/rel_$arm.diff"; head -6 "rel_$arm.diff"; fail=1; }

    echo "== THE GATE: ld(ours) == ld(nasm) =="
    ld boot_ref.o  -o boot_ref.elf  2>"ld_ref_$arm.err"  || { sed 's/^/  ld ref: /' "ld_ref_$arm.err" >&2; die "ld failed on nasm's $arm object"; }
    ld boot_ours.o -o boot_ours.elf 2>"ld_ours_$arm.err" || { sed 's/^/  ld ours: /' "ld_ours_$arm.err" >&2; die "ld failed on asm.la's $arm object"; }
    if cmp -s boot_ref.elf boot_ours.elf; then
        echo "  ★ $arm GREEN — linked outputs byte-identical"
    else
        echo "  RED — $arm: $(cmp boot_ref.elf boot_ours.elf 2>&1 | head -1)"; fail=1
    fi
    mv boot_ref.o "ref_$arm.o"; mv boot_ours.o "ours_$arm.o"
done

# ── THE ARM-SET ASSERTION ────────────────────────────────────────────────────
# Per-arm greens do not add up to coverage on their own: an arm that silently
# stopped carrying its site would pass everything above by comparing two equally
# empty objects. The union of what was actually observed must equal the required
# set.
echo
echo "== arm-set coverage: the union over $ARMS =="
for s in $REQUIRED_SITES; do
    case " $covered " in
        *" $s "*) echo "  ok   $s covered" ;;
        *)        echo "  UNCOVERED $s — no arm in '$ARMS' carried it"; fail=1 ;;
    esac
done

echo
[ "$fail" = 0 ] && echo "---- gate_bootelf: GREEN (arms: $ARMS; sites: $REQUIRED_SITES) ----" \
                || echo "---- gate_bootelf: RED ----"
exit $fail
