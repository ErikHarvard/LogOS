#!/bin/bash
# gate_audit2_checks.sh — witnesses for the audit-2 "checks that cannot fail"
# fixes (batch E). Each chk_ case PLANTS the defect its check exists to catch (a
# mutant, built here in the temp dir, never in the tree) and requires the check
# to go RED on it, then requires the same check GREEN on the real code. Run on
# the unfixed tree, the mutant half FAILS (the old check stayed green).
#   usage: ./gate_audit2_checks.sh [case ...]     (no args = every case)
set -u
REPO=$(cd "$(dirname "$0")" && pwd)
W=$(mktemp -d "${TMPDIR:-/tmp}/gate_audit2_checks.XXXXXX")
trap 'rm -rf "$W"' EXIT
cd "$W"
gcc -O2 -o tiny_host "$REPO/tiny_host.c" || { echo "FAIL  gate: cannot build tiny_host"; exit 1; }
cp "$REPO"/*.la .
FAILS=0
pass() { echo "PASS  $*"; }
fail() { echo "FAIL  $*"; FAILS=$((FAILS+1)); }
# has <file> <exact line> — grep -x on a fixed string
has() { grep -qxF "$2" "$1"; }

# ── #37 glyphdag_spec: INTERNB/INTERNU tests must call the glyph ──────────────
# Mutant: the INTERNB/INTERNU spec entries carry a wrong implementation (returns
# the table untouched, index 0). Unfixed, the probes `la g. "ib"` never call g:
# both rows PASS and the module is VERIFIED.
chk_glyphdag_intern() {
    sed -e 's/(SRC_INTERNB)(INTERNB)/(SRC_INTERNB)(la self. la sym. la a. la b. la tbl. PAIRc(tbl)(0))/' \
        -e 's/(SRC_INTERNU)(INTERNU)/(SRC_INTERNU)(la self. la sym. la a. la tbl. PAIRc(tbl)(0))/' \
        -e 's/("glyphdag.la")/("t_gd_mut.la")/' glyphdag_spec.la > t_gd_mut_spec.la
    sed -e 's/("glyphdag.la")/("t_gd_real.la")/' glyphdag_spec.la > t_gd_real_spec.la
    timeout 120 ./tiny_host t_gd_mut_spec.la > gd_mut.out 2>&1
    timeout 120 ./tiny_host t_gd_real_spec.la > gd_real.out 2>&1
    if ! has gd_mut.out "  INTERNB: FAIL" || ! has gd_mut.out "  INTERNU: FAIL"; then
        fail "glyphdag #37: mutant INTERNB/INTERNU not caught — $(grep -E '^  INTERN[BU]: |^RESULT' gd_mut.out | tr '\n' '|')"
    elif has gd_real.out "  INTERNB: PASS" && has gd_real.out "  INTERNU: PASS" && grep -q 'module VERIFIED' gd_real.out; then
        pass "glyphdag #37: INTERNB/INTERNU tests call the glyph — mutant FAILs, real PASSes"
    else fail "glyphdag #37: real spec not verified — $(grep -E '^  INTERN[BU]: |^RESULT' gd_real.out | tr '\n' '|')"; fi
}

# ── #126 psc_spec: SYN_DUR's second test must discriminate ────────────────────
# Mutant: SYN_DUR = "the second argument" (equals max on (6560,6720) only).
# Unfixed, test 2 is lt(g(a)(b))(a+b), true for max/min/either/mean: PASS.
chk_psc_syndur() {
    sed -e 's/(SRC_SYNDUR)(SYN_DUR)/(SRC_SYNDUR)(la da. la db. db)/' -e 's/("psc.la")/("t_psc_mut.la")/' psc_spec.la > t_psc_mut_spec.la
    sed -e 's/("psc.la")/("t_psc_real.la")/' psc_spec.la > t_psc_real_spec.la
    timeout 120 ./tiny_host t_psc_mut_spec.la > psc_mut.out 2>&1
    timeout 120 ./tiny_host t_psc_real_spec.la > psc_real.out 2>&1
    if ! has psc_mut.out "  SYN_DUR: FAIL"; then fail "psc #126: SYN_DUR=second-arg mutant not caught — $(grep -E '^  SYN_DUR: |^RESULT' psc_mut.out | tr '\n' '|')"
    elif has psc_real.out "  SYN_DUR: PASS" && grep -q 'module VERIFIED' psc_real.out; then pass "psc #126: SYN_DUR tests reject a non-max implementation; real SYN_DUR PASSes"
    else fail "psc #126: real spec not verified — $(grep -E '^  SYN_DUR: |^RESULT' psc_real.out | tr '\n' '|')"; fi
}

# ── #41 metadebug: a registry name missing from SPEC_TABLE is not autological ─
# Mutant (the audit's): MAP's registry entry renamed MAPX and broken (returns NIL).
# Unfixed, GET_SPEC("MAPX") = NIL and ALL over NIL is TRUE: ALL_SPECCED: T.
chk_metadebug_unspecced() {
    sed 's/CONS(PAIR("MAP")(MAP))(/CONS(PAIR("MAPX")(la f. la l. NIL))(/' metadebug.la > t_md_mut.la
    grep -q 'PAIR("MAPX")' t_md_mut.la || { fail "metadebug #41: mutant not planted"; return; }
    timeout 120 ./tiny_host t_md_mut.la > md_mut.out 2>&1
    timeout 120 ./tiny_host metadebug.la > md_real.out 2>&1
    if ! has md_mut.out "ALL_SPECCED: F"; then fail "metadebug #41: unspecced MAPX not caught — $(grep ALL_SPECCED md_mut.out)"
    elif has md_real.out "ALL_SPECCED: T" && has md_real.out "META_DEBUG: T"; then pass "metadebug #41: an unspecced registry name fails ALL_SPECCED; real registry still T"
    else fail "metadebug #41: real metadebug not green — $(grep -E 'ALL_SPECCED|META_DEBUG:' md_real.out | tr '\n' '|')"; fi
}

# ── #135 specpipe: an entry with no tests is UNTESTED, not PASS ───────────────
# Mutant: a spec entry whose implementation is wrong and whose test list is NIL.
# Unfixed, META_DEBUG prints "BROKEN: PASS" and "every glyph passed its spec".
chk_specpipe_untested() {
    cat > t_untested_spec.la <<'LA'
import("specpipe.la")
glyph S = CONS(TRIPLE("GOOD")(DEF("Int -> Int")("la x. x")(la x. x))(CONS(PAIR(la g. int_to_str(g(7)))("7"))(NIL)))(
          CONS(TRIPLE("BROKEN")(DEF("Int -> Int")("la x. \"WRONG\"")(la x. "WRONG"))(NIL))(NIL))
glyph MAIN = print(DEPLOY(S)("t_untested_mod.la"))
LA
    sed -e 's/("evdev.la")/("t_evdev_real.la")/' evdev_spec.la > t_evdev_real_spec.la
    timeout 120 ./tiny_host t_untested_spec.la > un_mut.out 2>&1
    timeout 120 ./tiny_host t_evdev_real_spec.la > un_real.out 2>&1
    if ! has un_mut.out "  BROKEN: UNTESTED" || grep -q 'every glyph passed its spec' un_mut.out; then
        fail "specpipe #135: untested entry reported as verified — $(grep -E '^  (GOOD|BROKEN): |^RESULT' un_mut.out | tr '\n' '|')"
    elif has un_real.out "  OPEN_INPUT: UNTESTED" && has un_real.out "  EV_TYPE: PASS" \
         && has un_real.out "RESULT: module VERIFIED — every TESTED glyph passed its spec; 3 glyph(s) UNTESTED (no test cases)"; then
        pass "specpipe #135: NIL-test entries print UNTESTED and the RESULT counts them; evdev's tested decoders still PASS"
    else fail "specpipe #135: evdev report wrong — $(grep -E '^  (OPEN_INPUT|EV_TYPE): |^RESULT' un_real.out | tr '\n' '|')"; fi
}

# ── #106 build.sh check_sigil: RELATION's H+V symmetry is asserted ────────────
# The check_sigil block is extracted from build.sh and run on the host render.
# Mutant: RELATION's lower point moved off the mirror axis (DISK at col 26, not
# 27), so the double arc is no longer H-symmetric. Unfixed, check_sigil has no
# RELATION line: the mutant render passes it.
chk_sigil_relation() {
    awk '/^block \(\) \{/{p=1} p{print} p&&/^check_sigil \(\) \{/{c=1} c&&/^}$/{exit}' "$REPO/build.sh" > sigil_fns.sh
    grep -q '^check_sigil ()' sigil_fns.sh || { fail "sigil #106: cannot extract check_sigil from build.sh"; return; }
    sed 's/OR(DISK(16)(5)(2)(r)(c))(OR(DISK(16)(27)(2)(r)(c))/OR(DISK(16)(5)(2)(r)(c))(OR(DISK(16)(26)(2)(r)(c))/' sigil.la > t_sigil_mut.la
    cmp -s sigil.la t_sigil_mut.la && { fail "sigil #106: mutant not planted"; return; }
    timeout 120 ./tiny_host t_sigil_mut.la > sig_mut.txt 2>/dev/null
    timeout 120 ./tiny_host sigil.la > sig_real.txt 2>/dev/null
    local mo ro
    mo=$(bash -c 'ok=1; . ./sigil_fns.sh; check_sigil "C host" sig_mut.txt; echo "ok=$ok"' 2>&1)
    ro=$(bash -c 'ok=1; . ./sigil_fns.sh; check_sigil "C host" sig_real.txt; echo "ok=$ok"' 2>&1)
    if ! grep -q 'FAIL  sigil(C host): RELATION' <<< "$mo" || ! grep -qx 'ok=0' <<< "$mo"; then
        fail "sigil #106: asymmetric RELATION not caught — $(tr '\n' '|' <<< "$mo")"
    elif [ "$ro" = "ok=1" ]; then pass "sigil #106: check_sigil asserts RELATION H+V — mutant FAILs, real render passes"
    else fail "sigil #106: real render not green — $(tr '\n' '|' <<< "$ro")"; fi
}

# ── #103 build.sh: the DEPTH(DEPTH) divergence check runs the deployed DEPTH ──
# The divergence block is extracted from build.sh (fixed /tmp path rewritten to
# the temp dir) and run on host + VM. Mutant: primitives.la's DEPTH terminates
# (la g. g). Unfixed, the block tests an inline `la g. g(g)` and stays green.
chk_depth_div() {
    awk '/^# DEPTH autology is non-termination/{p=1} p{print} p&&/^rm -f \/tmp\/depthdiv.la/{exit}' "$REPO/build.sh" \
        | sed 's#/tmp/depthdiv.la#depthdiv.la#g' > depth_blk.sh
    grep -q 'timeout 4 ./logos_secd' depth_blk.sh || { fail "depth #103: cannot extract the block from build.sh"; return; }
    cp primitives.la primitives.real.la
    sed 's/^glyph DEPTH = la g. g(g)$/glyph DEPTH = la g. g/' primitives.real.la > primitives.mut.la
    cmp -s primitives.real.la primitives.mut.la && { fail "depth #103: mutant not planted"; return; }
    local mo ro
    cp primitives.mut.la primitives.la;  mo=$(bash -c 'ok=1; . ./depth_blk.sh; echo "ok=$ok"' 2>&1)
    cp primitives.real.la primitives.la; ro=$(bash -c 'ok=1; . ./depth_blk.sh; echo "ok=$ok"' 2>&1)
    if ! grep -q 'FAIL  primitives: DEPTH(DEPTH) did not diverge on host' <<< "$mo" || ! grep -qx 'ok=0' <<< "$mo"; then
        fail "depth #103: terminating DEPTH not caught — $(tr '\n' '|' <<< "$mo")"
    elif [ "$ro" = "ok=1" ]; then pass "depth #103: divergence check runs the deployed primitives.la — terminating DEPTH FAILs, real DEPTH diverges on host+VM"
    else fail "depth #103: real DEPTH not green — $(tr '\n' '|' <<< "$ro")"; fi
}

# ── #109 bytecode.la: a program without MAIN names the cause on RUN_BYTES/RUN_SM
# The planted defect is the program: no MAIN glyph. Unfixed, R_VAL(NONE) applies
# "" and the host reports a generic "attempt to apply a non-function".
chk_bytecode_nomain() {
    printf 'glyph A = print("A evaluated")\n' > t_nomain.la
    printf 'glyph MAIN = print("main ran")\n' > t_main.la
    local eng fn out rc ok=1 msg=""
    for eng in vm:RUN_BYTES_PROGRAM sm:RUN_SM_PROGRAM; do
        fn=${eng#*:}; eng=${eng%%:*}
        { sed '/^glyph MAIN/,$d' bytecode.la; printf 'glyph MAIN = %s(PARSE_PROGRAM(read_file("prog.la")))\n' "$fn"; } > t_drv.la
        cp t_nomain.la prog.la; out=$(timeout 120 ./tiny_host t_drv.la 2>&1); rc=$?
        if [ "$rc" = 0 ] || ! grep -qF "$eng: no glyph: MAIN" <<< "$out"; then ok=0; msg="$msg $fn(no MAIN): rc=$rc [$(tr '\n' '|' <<< "$out")]"; fi
        cp t_main.la prog.la; out=$(timeout 120 ./tiny_host t_drv.la 2>&1); rc=$?
        if [ "$rc" != 0 ] || ! grep -qx 'main ran' <<< "$out"; then ok=2; msg="$msg $fn(real): rc=$rc [$(tr '\n' '|' <<< "$out")]"; fi
    done
    if [ $ok = 1 ]; then pass "bytecode #109: missing MAIN halts with 'vm/sm: no glyph: MAIN'; a real MAIN still runs on both"
    else fail "bytecode #109:$msg"; fi
}

# ── #72 specpipe DEPLOY: a duplicate glyph name is rejected ───────────────────
# Mutant (the audit's): two entries named IDT with different bodies and tests.
# Unfixed, both are "IDT: PASS", both are written, the module is VERIFIED, and
# the host runs only the first — the second's tests verified dead code.
chk_specpipe_dup() {
    cat > t_dup_spec.la <<'LA'
import("specpipe.la")
glyph S = CONS(TRIPLE("IDT")(DEF(":: a -> a")("la x. x")(la x. x))(CONS(PAIR(la g. g("x"))("x"))(NIL)))(
          CONS(TRIPLE("IDT")(DEF(":: a -> a")("la x. \"A\"")(la x. "A"))(CONS(PAIR(la g. g("x"))("A"))(NIL)))(NIL))
glyph MAIN = print(DEPLOY(S)("t_dup_mod.la"))
LA
    rm -f t_dup_mod.la
    timeout 120 ./tiny_host t_dup_spec.la > dup_mut.out 2>&1
    sed 's/("math_generated.la")/("t_math_real.la")/' specpipe.la > t_sp_real.la
    timeout 120 ./tiny_host t_sp_real.la > dup_real.out 2>&1
    if ! grep -q '^RESULT: module REJECTED — duplicate glyph name(s): IDT ' dup_mut.out || [ -e t_dup_mod.la ]; then
        fail "specpipe #72: duplicate IDT not rejected — $(grep -E '^  IDT: |^RESULT' dup_mut.out | tr '\n' '|')$( [ -e t_dup_mod.la ] && echo ' (module written)')"
    elif grep -q 'module VERIFIED' dup_real.out && has dup_real.out "  MULTIPLY: PASS"; then pass "specpipe #72: DEPLOY rejects a duplicate glyph name (nothing written); MATH_SPEC still VERIFIED"
    else fail "specpipe #72: MATH_SPEC not verified — $(grep '^RESULT' dup_real.out)"; fi
}

# ── #105 build.sh: a bare VM step that exits non-zero prints a FAIL line ──────
# The vmrun helper (if any) and the sigil stage's bare VM line are extracted from
# build.sh and run under its `set -euo pipefail`. The planted defect is a VM that
# dies of SIGSEGV. Unfixed, the script just ends — rc 139, not one FAIL line.
chk_bare_vm() {
    { grep -E '^exec 3>&1$|^vmrun\(\) \{' "$REPO/build.sh"
      grep -E '^(vmrun )?\./logos_secd > sigil_vm\.txt 2>/dev/null$' "$REPO/build.sh"; echo 'echo reached'; } > bare_blk.sh
    grep -q 'sigil_vm.txt' bare_blk.sh || { fail "bare #105: cannot extract the sigil VM line from build.sh"; return; }
    mkdir -p d105
    printf '#!/bin/bash\necho "secd: boom" >&2; kill -SEGV $$\n' > d105/seg; printf '#!/bin/bash\necho rendered\n' > d105/okvm
    chmod +x d105/seg d105/okvm
    local mo ro mrc rrc
    cp d105/seg d105/logos_secd;  mo=$(cd d105 && timeout 30 bash -c 'set -euo pipefail; . ../bare_blk.sh' 2>&1); mrc=$?
    cp d105/okvm d105/logos_secd; ro=$(cd d105 && timeout 30 bash -c 'set -euo pipefail; . ../bare_blk.sh' 2>&1); rrc=$?
    if [ "$mrc" = 0 ] || ! grep -q "^FAIL  build.sh:[0-9]*: './logos_secd' exited 139" <<< "$mo"; then
        fail "bare #105: SIGSEGV in a bare VM step left no FAIL line (rc=$mrc, out=[$(tr '\n' '|' <<< "$mo")])"
    elif [ "$rrc" = 0 ] && [ "$ro" = reached ] && [ "$(cat d105/sigil_vm.txt)" = rendered ]; then
        pass "bare #105: a VM step that dies prints 'FAIL … exited 139' and stops the build; a good step runs on, output redirect intact"
    else fail "bare #105: good VM step not green (rc=$rrc, out=[$(tr '\n' '|' <<< "$ro")])"; fi
}

CASES="${*:-glyphdag_intern psc_syndur metadebug_unspecced specpipe_untested specpipe_dup sigil_relation depth_div bytecode_nomain bare_vm}"
for c in $CASES; do "chk_$c"; done
[ "$FAILS" -eq 0 ] && { echo "gate_audit2_checks: all passed"; exit 0; } || { echo "gate_audit2_checks: $FAILS failed"; exit 1; }
