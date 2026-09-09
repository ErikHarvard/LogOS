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
#   ./gate_bootelf.sh --coverage-only <bootsrc-dir>
#     The CHEAP HALF, ~0.2 s, wired into build.sh. It asserts only what fresh
#     nasm can settle: that each arm's source really does carry the equ sites
#     that arm exists to cover, that the no-define configuration carries NONE of
#     them, and that the arm set covers all of them between them. That IS the
#     Q0b guard — it is what catches the chain being restructured, an arm
#     renamed, or a site removed, any of which silently returns this gate to
#     assembling a configuration in which the defect cannot exist.
#     ★ IT IS NOT THE SCALE COMPARISON. It never runs ld(ours)==ld(nasm) and
#     never touches asm.la's output, so it can say nothing about whether the
#     assembler is correct. Read its PASS line as "the arms still carry their
#     constructs", never as "the nasm-free object step holds".
#
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

# ── THE PROVENANCE STAMP — "the evidence is old" is not "the code is broken" ──
#  The scale comparison (ld(ours)==ld(nasm)) needs asm.la's per-arm objects, which
#  cost ~62 min to derive and are gitignored. So it runs ON DEMAND, and the verdict
#  it produced is recorded in BOOTELF.md. What runs every build is this: a check
#  that the recorded verdict still describes the current sources.
#
#  ★ A STALENESS RED IS NOT A CORRECTNESS RED, AND THE DIFFERENCE IS THE WHOLE
#  DESIGN. A mismatch here says "nobody has re-derived since asm.la changed." It
#  CANNOT say the new asm.la is wrong. Ruling (The General, 2026-09-09): a
#  staleness red must therefore NOT enter build.sh's serial abort chain, because
#  every `|| exit 1` there strands ~50 of the 52 gate invocations behind it — and
#  giving "nobody has spent 62 minutes yet" the power to halt fifty correctness
#  gates is the wrong trade at any cost. So `--provenance` exits 3, not 1, and
#  build.sh COUNTS it instead of aborting.
#
#  ⚠ AND THE TRAP THAT MAKES THAT LEGITIMATE RATHER THAN A NEW KIND OF SKIP.
#  This tree already has ~49 SKIP paths that report neither PASS nor FAIL and so
#  show nothing wrong in any tally. A third state that is merely QUIET is
#  green-by-absence wearing a new name. Exactly two properties keep STALE honest:
#  it is COUNTED, and the count is ASSERTED ZERO somewhere that blocks a release
#  — build.sh refuses the auto-checkpoint `verified-*` tag while any obligation
#  stands. If either property is ever removed, this has been diluted back into a
#  SKIP and the gate is lying. Do not remove one without removing both and saying
#  so.
#
#  Structure and exclusion discipline copied from kernel/gate_ncc3.sh (POROS,
#  track-d f701984), which solved the same shape for the committed selfhost
#  compiler: an expensive derived artifact plus a gate that detects drift, with
#  the one exclusion asserted BY NAME so the carve-out cannot go stale.
BOOTELF_VERDICT_COMMIT=d7be3be
BOOTELF_VERDICT_DATE=2026-09-09
BOOTELF_STAMP=c8fa4b9c2d8e0484836096a29f4009c2cf3848d7c76e1dfe65d191cfdc25c536
#  What the stamp covers: every input whose change can invalidate the recorded
#  verdict without changing nasm's reference — i.e. the assembler itself — plus
#  the boot source, so a boot.asm edit is reported as STALE with a name rather
#  than surfacing later as an anonymous link diff.
BOOTELF_STAMP_FILES="asm.la elfobj.la asmelfobj.la kernel/boot.asm kernel/idt.asm kernel/timer.asm kernel/kbdirq.asm"
#  ★ WHAT IT DELIBERATELY EXCLUDES, asserted rather than assumed: entry.inc and
#  native_codegen3_out. Both are BUILD PRODUCTS, and this gate generates them
#  itself, deterministically, so both sides read one value. If a future edit ever
#  makes the gate read either from kernel/ instead, the exclusion is stale and the
#  stamp would silently stop covering a real input — so --provenance asserts the
#  generation is still in this file.

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

MODE=full
if [ "${1:-}" = "--coverage-only" ]; then MODE=coverage; shift; fi
if [ "${1:-}" = "--provenance" ]; then MODE=provenance; shift; fi

if [ "$MODE" = provenance ]; then
    # ── anti-vacuity floor ────────────────────────────────────────────────────
    #  Every check below passes on a tree where the stamp was never set, so this
    #  floor is what makes that case FAIL instead of reporting a cheerful match.
    case "$BOOTELF_STAMP" in
        ""|STAMPVALUE|unset) die "BOOTELF_STAMP is unset — the recorded verdict has no provenance, so this check would pass vacuously" ;;
    esac
    [ ${#BOOTELF_STAMP} -eq 64 ] || die "BOOTELF_STAMP is not a sha256 (len ${#BOOTELF_STAMP})"
    [ -n "$BOOTELF_VERDICT_COMMIT" ] || die "BOOTELF_VERDICT_COMMIT is unset"
    command -v sha256sum >/dev/null || die "sha256sum not found"
    #  ⚠ THE EXCLUSION IS ENFORCED AT STAGING TIME, NOT HERE, AND THAT IS
    #  DELIBERATE. An earlier version of this check grepped THIS FILE for the
    #  entry.inc generation — but the generation lives in build.sh's block, and
    #  the grep pattern contained the very string it searched for, so the check
    #  was SELF-SATISFYING and could never fail. It is removed rather than
    #  patched: the real risk (a caller handing us a kernel-derived entry.inc,
    #  which track D regenerates per build, so the stamp would stop covering a
    #  live input) is checked where it can actually be observed — see
    #  ASSERT_DETERMINISTIC_INC in the staging path below, which compares the
    #  handed-in entry.inc against the exact literal both assemblers must read.
    missing=""
    for f in $BOOTELF_STAMP_FILES; do [ -f "$f" ] || missing="$missing $f"; done
    [ -z "$missing" ] && [ -n "$BOOTELF_STAMP_FILES" ] \
      || die "stamp inputs missing:$missing — a broken checkout, not a stale stamp"

    now=$(for f in $BOOTELF_STAMP_FILES; do sha256sum "$f"; done | sha256sum | cut -d' ' -f1)
    if [ "$now" = "$BOOTELF_STAMP" ]; then
        echo "PASS  bootelf-provenance: the recorded per-arm verdict still describes the current sources — BOOTELF.md's GREEN on NONE/HH1/HH2 was taken at $BOOTELF_VERDICT_COMMIT ($BOOTELF_VERDICT_DATE) against these exact bytes of $BOOTELF_STAMP_FILES, and none has changed since. This asserts the EVIDENCE IS CURRENT, not that the assembler is correct — that is the on-demand comparison the verdict records."
        exit 0
    fi
    echo "STALE bootelf-provenance: the recorded per-arm verdict NO LONGER describes the current sources."
    for f in $BOOTELF_STAMP_FILES; do
        h=$(sha256sum "$f" | cut -d' ' -f1)
        git show "$BOOTELF_VERDICT_COMMIT:$f" 2>/dev/null | sha256sum | cut -d' ' -f1 | grep -qx "$h" \
          || echo "        changed since $BOOTELF_VERDICT_COMMIT: $f"
    done
    echo "      This is NOT a claim that asm.la is wrong. It is a claim that nobody has re-derived."
    echo "      To clear it: run BOOTELF.md's cycle once per arm (~62 min), confirm ./gate_bootelf.sh <bootsrc> <objdir> is GREEN,"
    echo "      then update BOOTELF_VERDICT_COMMIT/DATE and BOOTELF_STAMP in this file to the new sources."
    exit 3
fi

DIR="${1:-}"; OBJDIR="${2:-}"
if [ "$MODE" = coverage ]; then
    [ -n "$DIR" ] || die "usage: $0 --coverage-only <bootsrc-dir>"
    OBJDIR=""
else
    [ -n "$DIR" ] && [ -n "$OBJDIR" ] || die "usage: $0 <bootsrc-dir> <objdir>"
    [ -d "$OBJDIR" ] || die "no object dir at '$OBJDIR'"
fi
[ -d "$DIR" ]    || die "no bootsrc dir at '$DIR'"
[ -s "$DIR/boot_base.asm" ] || die "'$DIR' has no boot_base.asm (the frozen boot.asm)"
for inc in entry.inc idt.asm timer.asm kbdirq.asm native_codegen3_out; do
    [ -e "$DIR/$inc" ] || die "'$DIR' is missing boot.asm dependency: $inc"
done
if [ "$MODE" = full ]; then
    for arm in $ARMS; do
        [ -s "$OBJDIR/ours_$arm.o" ] \
          || die "no ours_$arm.o in '$OBJDIR' (produce it via BOOTELF.md's VM cycle on the $arm source, isolated session) — an uncovered arm is a FAIL, never a skip"
    done
fi
command -v nasm    >/dev/null || die "nasm not found"
[ "$MODE" = full ] && { command -v ld >/dev/null || die "ld not found"; }
command -v readelf >/dev/null || die "readelf not found"
command -v python3 >/dev/null || die "python3 not found"

DIR="$(cd "$DIR" && pwd)"
[ "$MODE" = full ] && OBJDIR="$(cd "$OBJDIR" && pwd)"
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

# ── ASSERT_DETERMINISTIC_INC — the exclusion, checked where it can fire ──────
#  entry.inc is excluded from BOOTELF_STAMP_FILES because it is a build product
#  this gate's callers generate deterministically. That exclusion is only safe
#  while the value really is fixed: kernel/entry.inc is regenerated per build by
#  track D, so a caller that handed us THAT file would make the stamp silently
#  stop covering a live input, and the verdict would drift without ever going
#  stale. Asserted rather than trusted, and red-testable by handing a different
#  LA_ENTRY.
EXPECT_INC='LA_ENTRY equ 0x400000'
grep -qxF "$EXPECT_INC" "$G/entry.inc" \
  || die "entry.inc is not the deterministic value this gate's exclusion assumes (expected exactly '$EXPECT_INC', got '$(head -1 "$G/entry.inc")') — either the caller handed us kernel/entry.inc, which track D regenerates per build, or the fixed value changed. Cover entry.inc in BOOTELF_STAMP_FILES or restore the deterministic generation."

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
    if [ "$MODE" = full ]; then
        cp "$OBJDIR/ours_$arm.o" boot_ours.o || die "cannot stage ours_$arm.o"
    fi

    nasm -f elf64 asm_in.asm -o boot_ref.o 2>"nasm_$arm.err" \
        || { sed 's/^/  nasm: /' "nasm_$arm.err" >&2; die "nasm failed on the $arm boot.asm"; }

    # ── COVERAGE: the construct this arm exists to cover must BE THERE ───────
    # Checked in BOTH objects: comparing ours to ref cannot notice that both
    # lost the construct, which is exactly how this gate went hollow-green.
    want="$(sites_for "$arm")"
    if [ -n "$want" ]; then
        echo "== coverage: equ sites this arm must carry =="
        for s in $want; do
            if [ "$MODE" = coverage ]; then
                if symnames boot_ref.o | grep -qx "$s"; then
                    echo "  ok   $s present (nasm side; no object comparison in --coverage-only)"
                    covered="$covered $s"
                else
                    echo "  MISSING $s — the arm assembled a configuration in which the construct does not exist (hollow green); ref=0"
                    fail=1
                fi
            elif symnames boot_ref.o | grep -qx "$s" && symnames boot_ours.o | grep -qx "$s"; then
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

    if [ "$MODE" = coverage ]; then
        mv boot_ref.o "ref_$arm.o"
        continue
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
if [ "$fail" != 0 ]; then
    echo "---- gate_bootelf: RED ----"
elif [ "$MODE" = coverage ]; then
    echo "---- gate_bootelf: GREEN — ARM COVERAGE ONLY (arms: $ARMS; sites: $REQUIRED_SITES) ----"
    echo "     NOT the scale proof: ld(ours)==ld(nasm) was never run and asm.la's"
    echo "     output was never examined. This says the arms still carry their"
    echo "     constructs, nothing about whether the assembler is correct."
else
    echo "---- gate_bootelf: GREEN (arms: $ARMS; sites: $REQUIRED_SITES) ----"
fi
exit $fail
