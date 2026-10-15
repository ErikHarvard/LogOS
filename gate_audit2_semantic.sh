#!/bin/bash
# gate_audit2_semantic.sh — regression gates for the CODE-CHANGING fixes to the
# LogOS_bug_audit_2.md "semantic module" findings (claims a module's code did not
# compute). Each case FAILS on the unfixed tree and PASSES with its fix. Pure-comment
# rewordings (honest-claim fixes) carry no gate. Host only — every case runs one
# small module under tiny_host in well under a second; the cross-engine (VM) half of
# each module is still covered by its build.sh section.
# Runs in a private temp dir (no fixed /tmp paths); needs gcc.
#   usage: ./gate_audit2_semantic.sh [case ...]     (no args = every case)
set -u
REPO=$(cd "$(dirname "$0")" && pwd)
W=$(mktemp -d "${TMPDIR:-/tmp}/gate_audit2_semantic.XXXXXX")
trap 'rm -rf "$W"' EXIT
cd "$W"
gcc -O2 -o tiny_host "$REPO/tiny_host.c" || { echo "FAIL  gate: cannot build tiny_host"; exit 1; }
cp "$REPO"/*.la .
FAILS=0
pass() { echo "PASS  $*"; }
fail() { echo "FAIL  $*"; FAILS=$((FAILS+1)); }

# ── #101 archroot: the VERDICT is counted from the derivation checks ───────────
# Unfixed: L12 is a print literal "3 of 9 derive", so forcing a derivation check
# FALSE leaves the verdict unchanged. Fixed: the count and the lists follow
# DV_SELF/DV_REC/DV_LOVE. Expected strings are written from the definitions, not
# captured: with DV_LOVE forced FALSE, SELF and RECOGNITION remain (2 of 9) and
# LOVE joins the six never-attempted atoms (7 underived, LOVE first). The unmutated
# module must still print the original verdict byte-for-byte (build.sh greps it).
case_archroot_verdict() {
    local tail=' = THE GAP, not a result: derivation from the root is NOT YET ATTEMPTED for these six. The chain does NOT generate the nine.'
    local want_all="VERDICT: 3 of 9 derive (SELF, RECOGNITION, LOVE); 6 UNDERIVED (BEING, RELATION, DEPTH, VOID, FORM, BECOMING)$tail"
    local want_mut="VERDICT: 2 of 9 derive (SELF, RECOGNITION); 7 UNDERIVED (LOVE, BEING, RELATION, DEPTH, VOID, FORM, BECOMING)$tail"
    sed 's/^glyph DV_LOVE = .*/glyph DV_LOVE = FALSE/' archroot.la > t_arch_mut.la
    grep -qx 'glyph DV_LOVE = FALSE' t_arch_mut.la || { fail "archroot verdict: mutation did not apply"; return; }
    local a m; a=$(timeout 20 ./tiny_host archroot.la 2>&1 | grep '^VERDICT') ; m=$(timeout 20 ./tiny_host t_arch_mut.la 2>&1 | grep '^VERDICT')
    if [ "$a" = "$want_all" ] && [ "$m" = "$want_mut" ]; then
        pass "archroot: VERDICT counted from DV_* (3 of 9 as shipped; 2 of 9 with LOVE's check forced false)"
    else
        fail "archroot verdict: shipped=[$a] mutated=[$m]"
    fi
}

# ── #101 archroot: L1 reports the root seal's RECOV status instead of asserting
# "autological". Independently: SEAL_ARCHE's ren is the literal '∃(∃)≡∃' and its
# etymology ↻(∃) canonicalises to '↻(∃)', so RECOV is false → "? no". Control: a
# copy whose ren IS '↻(∃)' must flip to "? YES" (the answer is computed, not typed).
# Also: the report no longer claims "only rho fits" (only ρ is tested).
case_archroot_seal() {
    sed 's/^glyph SEAL_ARCHE = MONO("∃(∃)≡∃")/glyph SEAL_ARCHE = MONO("↻(∃)")/' archroot.la > t_arch_seal.la
    local o c; o=$(timeout 20 ./tiny_host archroot.la 2>&1); c=$(timeout 20 ./tiny_host t_arch_seal.la 2>&1)
    local l1 l1c; l1=$(sed -n 1p <<< "$o"); l1c=$(sed -n 1p <<< "$c")
    if grep -qF 'autological seal names itself' <<< "$o"; then
        fail "archroot L1 still asserts 'autological seal names itself' (RECOV(SEAL_ARCHE) is false) — got: $l1"
    elif grep -qF 'etymology canon = ↻(∃), name recoverable from etymology (RECOV) ? no' <<< "$l1" \
         && grep -qF '(RECOV) ? YES' <<< "$l1c" && ! grep -qF 'only rho fits' <<< "$o"; then
        pass "archroot: L1 reports RECOV(SEAL_ARCHE) = no (computed; a recoverable control flips to YES); no unverified 'only'"
    else
        fail "archroot L1: got [$l1] control [$l1c]"
    fi
}

# ── #45 metaglyph: the printed claim matches what OP_DET computes ─────────────
# OP_DET compares ν*'s action with 𝔑(𝔑)'s — two operators whose mode SKELETONS
# differ — so it cannot show "the name fixes the action" (two same-skeleton,
# different-leaf operators act identically; checked here as the control).
# Unfixed: the module prints "minted op's action fixed by its name ? YES".
# Fixed: it prints what was compared.
case_metaglyph_claim() {
    local o; o=$(timeout 20 ./tiny_host metaglyph.la 2>&1)
    sed '/^glyph MAIN/,$d' metaglyph.la > t_mg.la
    cat >> t_mg.la <<'LA'
glyph OTHER = COLLAPSE(SYN)(GLYPHOF(DIR(PRIM("DEPTH"))(PRIM("FORM"))))(GLYPHOF(MC(PRIM("BEING"))))
glyph MAIN = print(YN(str_eq(CANON(MKOP(NU_STAR)(OPA)(OPB)))(CANON(MKOP(OTHER)(OPA)(OPB)))))
LA
    local ctl; ctl=$(timeout 20 ./tiny_host t_mg.la 2>&1)
    if grep -qF 'action fixed by its name' <<< "$o"; then
        fail "metaglyph still prints 'minted op's action fixed by its name' (same-skeleton ops act identically: $ctl)"
    elif grep -qxF 'ν* action ≠ 𝔑(𝔑) action (different mode skeletons) ? YES' <<< "$o" && [ "$ctl" = YES ]; then
        pass "metaglyph: prints what OP_DET compares (skeletons), not 'name fixes action' (control: same-skeleton ops identical = YES)"
    else
        fail "metaglyph claim: control=[$ctl] out: $(grep -F 'ν*' <<< "$o" | tr '\n' '|')"
    fi
}

CASES="${*:-archroot_verdict archroot_seal metaglyph_claim}"
for c in $CASES; do "case_$c"; done
[ "$FAILS" -eq 0 ] && { echo "gate_audit2_semantic: all passed"; exit 0; } || { echo "gate_audit2_semantic: $FAILS failed"; exit 1; }
