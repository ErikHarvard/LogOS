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

# ── #104 build.sh ncheck/n2check: the host run is bounded and its rc checked ──
# ncheck and n2check are extracted from build.sh and run under build.sh's own
# `set -euo pipefail`. The planted defect is a host that prints the right bytes
# and then exits 3, or then hangs. Unfixed: the exit-3 host aborts the script
# with NO FAIL line (set -e), and the hanging host hangs the stage.
chk_ncheck_hostrc() {
    awk '/^ncheck \(\) \{/{p=1} p{print} p&&/^}$/{exit}' "$REPO/build.sh" > nc_fns.sh
    awk '/^n2check \(\) \{/{p=1} p{print} p&&/^}$/{exit}' "$REPO/build.sh" >> nc_fns.sh
    grep -q '^n2check ()' nc_fns.sh || { fail "ncheck #104: cannot extract ncheck/n2check from build.sh"; return; }
    mkdir -p d104 && cp ./*.la d104/ && cp nc_fns.sh d104/
    local mode out res=""
    for mode in exit3 hang real; do
        cat > d104/tiny_host <<SH
#!/bin/bash
if [ "\$1" = native_input.la ] && [ $mode != real ]; then "$W/tiny_host" "\$@"; [ $mode = exit3 ] && exit 3; exec sleep 1000; fi
exec "$W/tiny_host" "\$@"
SH
        chmod +x d104/tiny_host
        out=$(cd d104 && MODE=$mode timeout 100 bash -c 'set -euo pipefail; ok=1; . ./nc_fns.sh
              ncheck "print(42)"; [ "$MODE" = hang ] || n2check "glyph MAIN = print((la x. x)(42))" "identity lambda"; echo "ok=$ok"' 2>&1); local rc=$?
        res="$res [$mode rc=$rc: $(tr '\n' '|' <<< "$out")]"
        case $mode in
          exit3) grep -q 'FAIL  native_codegen: host run of \[print(42)\] exited 3' <<< "$out" \
                 && grep -q 'FAIL  native_codegen2: host run of \[identity lambda\] exited 3' <<< "$out" && grep -qx 'ok=0' <<< "$out" || { fail "ncheck #104: host exit 3 not reported —$res"; return; } ;;
          hang)  grep -q 'host run of \[print(42)\] exited 124' <<< "$out" && grep -qx 'ok=0' <<< "$out" || { fail "ncheck #104: hanging host not bounded —$res"; return; } ;;
          real)  [ "$rc" = 0 ] && [ "$out" = "ok=1" ] || { fail "ncheck #104: real host not green —$res"; return; } ;;
        esac
    done
    pass "ncheck #104: host exit status checked and bounded — exit-3 and hanging hosts give FAIL lines, the real host passes"
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

# ── #113 drm_bringup*.sh: the VM is emitted without nasm; nasm is a drift guard
# Each script's build block (from "building" to `chmod +x logos_secd`) is run
# alone. The planted defect is the environment: no nasm on PATH. Unfixed, all six
# stop with "nasm failed". Real: with nasm present the drift guard passes.
chk_drm_nonasm() {
    mkdir -p d113/nonasm d113/withnasm
    local t f out rc res="" bad=0
    for t in cmp rm stat cp chmod cat; do ln -sf "$(command -v $t)" d113/nonasm/$t; ln -sf "$(command -v $t)" d113/withnasm/$t; done
    if command -v nasm >/dev/null 2>&1; then ln -sf "$(command -v nasm)" d113/withnasm/nasm; fi
    for f in "$REPO"/drm_bringup*.sh; do
        awk '/^echo "== building/{p=1} p{print} p&&/^chmod \+x logos_secd/{exit}' "$f" > d113/blk.sh
        grep -q 'logos_secd' d113/blk.sh || { res="$res $(basename "$f"):no-block"; bad=1; continue; }
        rm -f d113/logos_secd; cp tiny_host secd.la secd.asm d113/ 2>/dev/null; cp "$REPO/secd.asm" d113/ 2>/dev/null
        out=$(cd d113 && timeout 120 env PATH="$PWD/nonasm" /bin/bash ./blk.sh 2>&1); rc=$?
        if [ "$rc" != 0 ] || [ ! -s d113/logos_secd ]; then res="$res $(basename "$f"):no-nasm rc=$rc[$(tr '\n' '|' <<< "$out")]"; bad=1; continue; fi
        if [ -e d113/withnasm/nasm ]; then
            out=$(cd d113 && timeout 120 env PATH="$PWD/withnasm" /bin/bash ./blk.sh 2>&1); rc=$?
            [ "$rc" = 0 ] || { res="$res $(basename "$f"):with-nasm rc=$rc[$(tr '\n' '|' <<< "$out")]"; bad=1; }
        fi
    done
    if [ $bad = 0 ]; then pass "drm #113: all six drm_bringup scripts emit the VM with tiny_host when nasm is absent; nasm drift guard green where present"
    else fail "drm #113:$res"; fi
}

# ── #105 (remainder): the VM steps inside nrun / guard_compile ────────────────
# nrun runs in $(…), where bash drops errexit: a dead compile step was ignored and
# a dead run step ended the build through the assignment, with no FAIL line.
# vmrun, nrun and guard_compile are extracted from build.sh and run under its
# `set -euo pipefail` with a stub runner. Mutants: the compile step dies of
# SIGSEGV (stops); the run step dies at a plain site (stops) and at a `|| true`
# site (runs on to that site's own check); guard_compile's step dies in the main
# shell (stops). Each must print the FAIL line. Real: a good runner's output
# reaches the capture.
chk_bare_vm_helpers() {
    { grep -E '^exec 3>&1$|^vmrun\(\) \{' "$REPO/build.sh"
      awk '/^nrun \(\) \{/,/^\}/' "$REPO/build.sh"
      awk '/^guard_compile\(\) \{/,/^\}/' "$REPO/build.sh"; } > helpers_blk.sh
    grep -q '^nrun ' helpers_blk.sh && grep -q '^guard_compile' helpers_blk.sh \
        || { fail "bare #105h: cannot extract nrun/guard_compile from build.sh"; return; }
    mkdir -p d105h; : > d105h/compiler.bin; : > d105h/t.la
    printf '#!/bin/bash\nkill -SEGV $$\n' > d105h/seg
    printf '#!/bin/bash\nn=$(cat cnt 2>/dev/null || echo 0); n=$((n+1)); echo $n > cnt\n[ $n -ge 2 ] && kill -SEGV $$\necho native out\n' > d105h/runseg
    printf '#!/bin/bash\necho native out\n' > d105h/okvm
    chmod +x d105h/seg d105h/runseg d105h/okvm
    h105() { cp "d105h/$1" d105h/runner; rm -f d105h/cnt
             (cd d105h && timeout 30 bash -c "set -euo pipefail; . ../helpers_blk.sh; $2" 2>&1); }
    local o rc bad="" F="^FAIL  build.sh:[0-9]*: './runner' exited 139"
    o=$(h105 seg 'OUT="$(nrun t.la)"; echo reached'); rc=$?
    { [ "$rc" != 0 ] && grep -q "$F" <<< "$o" && ! grep -q reached <<< "$o"; } || bad+=" compile-dies(rc=$rc,[$(tr '\n' '|' <<< "$o")])"
    o=$(h105 runseg 'OUT="$(nrun t.la)"; echo reached'); rc=$?
    { [ "$rc" != 0 ] && grep -q "$F" <<< "$o" && ! grep -q reached <<< "$o"; } || bad+=" run-dies(rc=$rc,[$(tr '\n' '|' <<< "$o")])"
    o=$(h105 runseg 'OUT="$(nrun t.la 2>/dev/null || true)"; echo reached'); rc=$?
    { [ "$rc" = 0 ] && grep -q "$F" <<< "$o" && grep -q reached <<< "$o"; } || bad+=" or-true-site(rc=$rc,[$(tr '\n' '|' <<< "$o")])"
    o=$(h105 seg 'guard_compile "print(1)"; echo reached'); rc=$?
    { [ "$rc" != 0 ] && grep -q "$F" <<< "$o" && ! grep -q reached <<< "$o"; } || bad+=" guard_compile-dies(rc=$rc,[$(tr '\n' '|' <<< "$o")])"
    # Shape scan, derived from the build.sh text: a VM/native binary (./runner,
    # ./logos_secd, ./vm2, ./native_codegen3_out, /tmp/sh_cc) that STARTS a statement
    # (line start, or after ; && {) on a line that neither handles its status (||)
    # nor backgrounds it (&) is bare. $(…) captures never match: ( is not a start.
    local bare
    bare=$(awk '{ l=$0; sub(/[[:space:]]+#.*$/, "", l) }
        l ~ /^[[:space:]]*#/ { next }
        l ~ /(^|;|&&|\{)[[:space:]]*(\.\/(runner|logos_secd|vm2|native_codegen3_out)|\/tmp\/sh_cc)([[:space:]]|$)/ && l !~ /\|\|/ && l !~ /&[[:space:]]*$/ { printf " %d", NR }' "$REPO/build.sh")
    [ -z "$bare" ] || bad+=" bare VM/native statements at build.sh lines:$bare"
    if [ -n "$bad" ]; then fail "bare #105h: a dead VM step in a helper left no FAIL line:$bad"; return; fi
    o=$(h105 okvm 'OUT="$(nrun t.la)"; guard_compile "print(1)"; echo "reached [$OUT]"'); rc=$?
    if [ "$rc" = 0 ] && [ "$o" = "reached [native out]" ]; then
        pass "bare #105h: nrun (in \$(…), strict and || true sites) and guard_compile print 'FAIL … exited 139' when the VM dies; a good runner's output reaches the capture; no bare VM/native statement left in build.sh"
    else fail "bare #105h: good runner not green (rc=$rc, out=[$(tr '\n' '|' <<< "$o")])"; fi
}

# ── #1 (remainder) build.sh Stage 3b: blob churn (b) and freeze-day #1 (c) need a GC
# Blocks (b)+(c) and ncg3 are extracted from build.sh and run under its
# `set -euo pipefail`, with a tiny_host wrapper that compiles for real (once per
# compiler+program, cached) and, for the mutant, patches the emitted rt_gc to
# reclaim NOTHING (it only re-arms the GC budget, so allocation just bumps).
# Unfixed, both run at the 16 GiB HEAP_SIZE, where ~6 GB / ~3.4 GB fit un-collected:
# the mutant passes. Fixed: they compile at 256 MiB, the mutant halts 'heap
# exhausted' rc 73 -> FAIL lines; the real collector passes both.
chk_gc_smallheap() {
    { awk '/^ncg3 \(\) \{/,/^\}/' "$REPO/build.sh"
      awk '/^NC3_HEAP=|^# \(b\) blob reclamation/{p=1} p{print} p&&/^rm -f c3_big.txt/{exit}' "$REPO/build.sh"; } \
        | sed 's#/tmp/c3#c3#g' > gc_blk.sh
    grep -q '^ncg3 ()' gc_blk.sh && grep -q 'freeze-day #1' gc_blk.sh || { fail "gc #1: cannot extract ncg3 / blocks (b)(c) from build.sh"; return; }
    local nga; nga=$(sed -n 's/^glyph NEXT_GC_ADDR *= *\([0-9]*\)$/\1/p' native_codegen3.la)
    [ -n "$nga" ] || { fail "gc #1: NEXT_GC_ADDR not found in native_codegen3.la"; return; }
    # mov qword [NEXT_GC], 0x400000 ; ret
    local pat; pat=$(printf '\\x48\\xc7\\x04\\x25\\x%02x\\x%02x\\x%02x\\x%02x\\x00\\x00\\x40\\x00\\xc3' \
        $((nga & 255)) $((nga >> 8 & 255)) $((nga >> 16 & 255)) $((nga >> 24 & 255)))
    mkdir -p d1/cache; cp ./*.la d1/; cp gc_blk.sh d1/
    cat > d1/tiny_host <<SH
#!/bin/bash
[ "\$1" = native_input.la ] && exec "$W/tiny_host" "\$@"
k=\$(cat "\$1" native_input.la | md5sum | cut -c1-32)
if [ ! -f "cache/\$k" ]; then "$W/tiny_host" "\$@" || exit \$?; cp native_codegen3_out "cache/\$k"; fi
cp "cache/\$k" native_codegen3_out
if [ "\$MODE" = mut ]; then   # rt_gc's first three instructions save rax/rbx/rcx to REGDUMP
    off=\$(od -An -v -tx1 native_codegen3_out | tr -d ' \n' | grep -ob '48890425........48891c25........48890c25' | cut -d: -f1)
    [ -n "\$off" ] && [ \$((off % 2)) = 0 ] && [ \$(wc -w <<< "\$off") = 1 ] || { echo "rt_gc signature not found once" >&2; exit 99; }
    printf '$pat' | dd of=native_codegen3_out bs=1 seek=\$((off / 2)) conv=notrunc status=none
fi
SH
    chmod +x d1/tiny_host
    local mo ro mrc rrc
    mo=$(cd d1 && MODE=mut timeout 200 bash -c 'set -euo pipefail; ok=1; . ./gc_blk.sh; echo "ok=$ok"' 2>&1); mrc=$?
    ro=$(cd d1 && MODE=real timeout 200 bash -c 'set -euo pipefail; ok=1; . ./gc_blk.sh; echo "ok=$ok"' 2>&1); rrc=$?
    if ! grep -q '^FAIL  native_codegen3 Stage 3b: blob-churn' <<< "$mo" || ! grep -q '^FAIL  native_codegen3 freeze-day #1' <<< "$mo" || ! grep -qx 'ok=0' <<< "$mo"; then
        fail "gc #1: a collector that reclaims nothing passed (b)/(c) (rc=$mrc, out=[$(tr '\n' '|' <<< "$mo")])"
    elif [ "$rrc" = 0 ] && [ "$ro" = "ok=1" ] && [ ! -e d1/nc3_heap.la ]; then
        pass "gc #1: blob churn (b) and freeze-day #1 (c) run in a 256 MiB heap — a no-reclaim rt_gc FAILs both (heap exhausted), the real GC passes"
    else fail "gc #1: real collector not green (rc=$rrc, out=[$(tr '\n' '|' <<< "$ro")])"; fi
}

# ── #31 (remainder) build.sh Stage 4 gate + regen_selfhost.sh ─────────────────
# The Stage 4 block (and its helpers) is extracted from build.sh and run under
# `set -euo pipefail` in a staged directory: SH_MEMINFO/SH_OVERCOMMIT describe the
# box, the reference image is a fixture. Mutants (the planted defects):
#  A  a 16 GiB box (MemTotal 16095000 kB, no swap, mode 0) and an image whose
#     PT_LOAD p_memsz is 17.5 GB (the committed image's own header). Unfixed: the
#     free-memory gate admits it and the exec fails. Fixed: NOTE skipped, naming p_memsz.
#  C  an image that exits 0 and writes nothing. Unfixed: "stale reference image".
#     Fixed: "wrote no native_codegen3_out".
#  D  regen_selfhost.sh with an image that dies of SIGSEGV. Unfixed: no message.
# Control B: on a roomy box the same header-only image IS admitted, and its exec
# failure is reported as an exec failure ("exited"), never as "stale".
chk_stage4_gate() {
    { grep -E '^exec 3>&1$|^vmrun\(\) \{' "$REPO/build.sh"; echo 'say() { :; }'
      awk '/^elf_load_memsz\(\) \{/,/^\}/' "$REPO/build.sh"; awk '/^sh_room\(\) \{/,/^\}/' "$REPO/build.sh"
      awk '/^say "Native backend Stage 4/{p=1} p{print} p&&/^fi$/{exit}' "$REPO/build.sh"; } | sed 's#/tmp/sh_#./sh_#g' > s4_blk.sh
    grep -q 'SH_REF=native_codegen3_selfhost.bin' s4_blk.sh || { fail "stage4 #31: cannot extract the Stage 4 block from build.sh"; return; }
    mkdir -p d31; cp s4_blk.sh native_codegen3.la kernel.la d31/; echo 0 > d31/oc
    printf 'MemTotal:       16095000 kB\nMemAvailable:   15645000 kB\nSwapTotal:             0 kB\nCommitLimit:     8047500 kB\nCommitted_AS:    1000000 kB\n' > d31/small
    printf 'MemTotal:      197269000 kB\nMemAvailable:  160000000 kB\nSwapTotal:             0 kB\nCommitLimit:    98634500 kB\nCommitted_AS:    1000000 kB\n' > d31/big
    head -c 4096 "$REPO/native_codegen3_selfhost.bin" > d31/hdr.bin
    printf 'int main(void){return 0;}\n' > d31/t0.c; gcc -o d31/t0 d31/t0.c || { fail "stage4 #31: cannot build the exit-0 fixture"; return; }
    s4() { cp "d31/$1" d31/native_codegen3_selfhost.bin; chmod +x d31/native_codegen3_selfhost.bin
           (cd d31 && SH_MEMINFO="$PWD/$2" SH_OVERCOMMIT="$PWD/oc" timeout 30 bash -c 'set -euo pipefail; . ./s4_blk.sh; echo reached' 2>&1); }
    local o rc bad=""
    o=$(s4 hdr.bin small); rc=$?
    { [ "$rc" = 0 ] && grep -q '^NOTE  Stage 4 self-host check skipped: .*p_memsz' <<< "$o" && ! grep -q FAIL <<< "$o"; } || bad+=" A-small-box(rc=$rc,[$(tr '\n' '|' <<< "$o")])"
    o=$(s4 hdr.bin big); rc=$?
    { [ "$rc" != 0 ] && grep -q "^FAIL  build.sh:[0-9]*: './sh_cc' exited 139" <<< "$o" && ! grep -q 'stale reference image' <<< "$o"; } || bad+=" B-control(rc=$rc,[$(tr '\n' '|' <<< "$o")])"
    o=$(s4 t0 big); rc=$?
    { [ "$rc" != 0 ] && grep -q 'wrote no native_codegen3_out' <<< "$o" && ! grep -q 'stale reference image' <<< "$o"; } || bad+=" C-no-output(rc=$rc,[$(tr '\n' '|' <<< "$o")])"
    mkdir -p d31r; cp "$REPO/regen_selfhost.sh" d31r/; : > d31r/native_codegen3.la
    printf '#!/bin/bash\nkill -SEGV $$\n' > d31r/native_codegen3_selfhost.bin; chmod +x d31r/native_codegen3_selfhost.bin
    o=$(timeout 30 bash d31r/regen_selfhost.sh 2>&1); rc=$?
    { [ "$rc" != 0 ] && grep -q '^regen_selfhost: iter 1 .* exited 139' <<< "$o"; } || bad+=" D-regen(rc=$rc,[$(tr '\n' '|' <<< "$o")])"
    if [ -z "$bad" ]; then pass "stage4 #31: the gate skips an image this box cannot map (p_memsz), exec failure and no-output are not reported as 'stale', regen_selfhost.sh names a dead run"
    else fail "stage4 #31:$bad"; fi
}

CASES="${*:-glyphdag_intern psc_syndur metadebug_unspecced specpipe_untested specpipe_dup sigil_relation depth_div bytecode_nomain ncheck_hostrc bare_vm drm_nonasm bare_vm_helpers gc_smallheap stage4_gate}"
for c in $CASES; do "chk_$c"; done
[ "$FAILS" -eq 0 ] && { echo "gate_audit2_checks: all passed"; exit 0; } || { echo "gate_audit2_checks: $FAILS failed"; exit 1; }
