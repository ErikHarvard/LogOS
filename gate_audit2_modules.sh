#!/bin/bash
# gate_audit2_modules.sh — regression gates for the LogOS_bug_audit_2.md fixes to
# the compositor and modality modules (theourgia*, sigil*, phonym, cob). Each case
# FAILS on the unfixed tree and PASSES with its fix. Expected pixels/bytes are
# derived by hand or by an independent python computation, never captured from
# the program. Same harness as gate_audit2.sh.
#   usage: ./gate_audit2_modules.sh [case ...]     (no args = every case)
set -u
REPO=$(cd "$(dirname "$0")" && pwd)
W=$(mktemp -d "${TMPDIR:-/tmp}/gate_audit2_modules.XXXXXX")
trap 'rm -rf "$W"' EXIT
cd "$W"
gcc -O2 -o tiny_host "$REPO/tiny_host.c" || { echo "FAIL  gate: cannot build tiny_host"; exit 1; }
cp "$REPO"/*.la .
./tiny_host secd.la >/dev/null 2>&1 || { echo "FAIL  gate: cannot emit logos_secd"; exit 1; }
FAILS=0
pass() { echo "PASS  $*"; }
fail() { echo "FAIL  $*"; FAILS=$((FAILS+1)); }
# vmc <prog.la> — compile a program for the SECD VM with codegen.la on the host
vmc() { cp "$1" logos_source.la && timeout 600 ./tiny_host codegen.la >/dev/null 2>&1; }
# nomain <module.la> <out.la> <MAIN line> — the module's pure part + a probe MAIN
nomain() { sed '/^glyph MAIN =/,$d' "$1" > "$2"; printf '%s\n' "$3" >> "$2"; }
# run <prog.la> [secs] -> OUT RC (host)
run() { RC=0; OUT=$(timeout "${2:-300}" ./tiny_host "$1" 2>&1) || RC=$?; }

# ── #139 REPEAT2 is total; a scene larger than the panel is clipped or halts ──
# REPEAT2 stopped only at n == 0; with C-truncating div/mod a negative n never
# reaches it the intended way, so REPEAT2(-3)(s) = sss. The live frame builders
# then emitted rows/bands longer than the screen whenever the scene did not fit
# (test pattern / window wider than the panel, the 704-px sigil on a 600-row
# panel) — a sheared, over-long frame, rc 0. Fixed: REPEAT2(n<1) = ""; the
# generic rectangle FRAME clips the rectangle to the screen; the fixed-size
# scenes (sigil, text window) halt loudly when the panel is too small.
# Expected values derived by hand:
#   REPEAT2(-3)("ab") = ""   REPEAT2(5)("ab") = "ababababab" (control)
#   FRAME(4)(3)(20)(1)(1)(9)(1)(BG)(FG), BG=1,2,3,0 FG=4,5,6,0: the 9-wide rect
#   clips to 4, x0 = 0, y0 = 1 → row0 = 4×BG+4 NUL, row1 = 4×FG+4 NUL, row2 = row0.
#   Fitting controls: sigil 704x704 pitch 2816 → 704·2816 = 1982464 bytes;
#   text_live 224x120 pitch 896 (window ends at 80+144, 80+40) → 120·896 = 107520;
#   text_session window = 14 chars·8 + 2·24 = 160 by 8 + 2·20 = 48 → 48·640 = 30720.
case_mod_repeat2() {
    local f bad=""
    for f in theourgia_mux_session_live.la theourgia_text_session_live.la theourgia_text_live.la sigil_live.la sigil_seal_live.la; do
        nomain "$f" t_r2.la 'glyph MAIN = print(concat("[")(concat(REPEAT2(sub(0)(3))("ab"))(concat("][")(concat(REPEAT2(5)("ab"))("]")))))'
        run t_r2.la 120
        [ "$RC" = 0 ] && [ "$OUT" = "[][ababababab]" ] || bad="$bad $f:rc=$RC:[$(printf '%s' "$OUT" | head -c 60)]"
    done
    if [ -z "$bad" ]; then pass "REPEAT2(-3) = \"\" and REPEAT2(5) = 5 copies in all five live modules"
    else fail "REPEAT2 negative count:$bad"; fi
    local want; want=$(python3 -c 'bg=bytes([1,2,3,0]);fg=bytes([4,5,6,0]);z=bytes(4);print((bg*4+z+fg*4+z+bg*4+z).hex())')
    for f in theourgia_mux_session_live.la theourgia_text_session_live.la; do
        nomain "$f" t_rf.la 'glyph MAIN = write_file("rf.bin")(FRAME(4)(3)(20)(1)(1)(9)(1)(BGRX(1)(2)(3))(BGRX(4)(5)(6)))'
        rm -f rf.bin; run t_rf.la 120
        local got; got=$(python3 -c 'import sys;print(open("rf.bin","rb").read().hex())' 2>/dev/null)
        if [ "$RC" = 0 ] && [ "$got" = "$want" ]; then pass "$f FRAME: a rectangle wider than the screen is clipped (60-byte frame as derived)"
        else fail "$f FRAME clip: rc=$RC got=[$got] want=[$want] out=[$(printf '%s' "$OUT" | head -c 100)]"; fi
    done
    local spec m
    for spec in "sigil_live.la|FRAME(1024)(600)(4096)|FRAME(704)(704)(2816)|1982464" \
                "sigil_seal_live.la|FRAME(S_LOVE)(1024)(600)(4096)|FRAME(S_LOVE)(704)(704)(2816)|1982464" \
                "theourgia_text_live.la|FRAME_TEXT(200)(100)(800)|FRAME_TEXT(224)(120)(896)|107520" \
                "theourgia_text_session_live.la|RENDER_FRAME(CONS(\"100\")(CONS(\"50\")(CONS(\"400\")(NIL))))(0)(0)|RENDER_FRAME(CONS(\"160\")(CONS(\"48\")(CONS(\"640\")(NIL))))(0)(0)|30720"; do
        IFS='|' read -r f bad_call ok_call ok_len <<< "$spec"
        nomain "$f" t_nf.la "glyph MAIN = print(str_len($bad_call))"
        run t_nf.la 300
        if [ "$RC" = 1 ] && grep -qF 'does not fit' <<< "$OUT"; then pass "$f: a scene larger than the panel halts loudly: $(grep -F 'does not fit' <<< "$OUT" | head -1)"
        else fail "$f too-small panel: rc=$RC out=[$(printf '%s' "$OUT" | head -c 160)] (want rc 1, 'does not fit')"; fi
        [ "$ok_len" = skip ] && continue
        nomain "$f" t_ok.la "glyph MAIN = print(str_len($ok_call))"
        run t_ok.la 300
        if [ "$RC" = 0 ] && [ "$OUT" = "$ok_len" ]; then pass "$f (control): a panel the scene just fits gives h·pitch = $ok_len bytes"
        else fail "$f fitting control: rc=$RC out=[$(printf '%s' "$OUT" | head -c 100)] want $ok_len"; fi
    done
}

CASES="${*:-mod_repeat2}"
for c in $CASES; do "case_$c"; done
[ "$FAILS" -eq 0 ] && { echo "gate_audit2_modules: all passed"; exit 0; } || { echo "gate_audit2_modules: $FAILS failed"; exit 1; }
