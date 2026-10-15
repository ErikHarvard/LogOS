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

# ── #137 font: GLYPH_ROW and BIT are total on their stated domain ─────────────
# GLYPH_ROW indexed FONTDATA at index*8+r with no bound (H row 8 = 30, row 0 of
# I); BIT divided by POW2(col): col 64 → POW2 = 0 → 'div: division by zero',
# col < 0 never terminated. Fixed: a row outside 0..FH-1 is 0 (blank), a column
# outside 0..FW-1 is unset. Expected values derived from the standard 8x8 font:
# 'H' = 0x33 0x33 0x33 0x3F 0x33 0x33 0x33 0x00 → rows 0 and 3 are 51 and 63
# (control); 255 has every bit 0..7 set → BIT(255)(7) = T (control).
case_mod_font_bounds() {
    local probe out
    nomain theourgia_font.la t_fb1.la 'glyph MAIN = print(concat(int_to_str(GLYPH_ROW("H")(8)))(concat(" ")(concat(int_to_str(GLYPH_ROW("H")(sub(0)(1))))(concat(" ")(concat(int_to_str(GLYPH_ROW("H")(0)))(concat(" ")(concat(int_to_str(GLYPH_ROW("H")(3)))(concat(" ")(BIT(255)(7)("T")("F"))))))))))'
    run t_fb1.la 120
    if [ "$RC" = 0 ] && [ "$OUT" = "0 0 51 63 T" ]; then pass "font: GLYPH_ROW row 8 / row -1 are blank (0); H rows 0,3 = 51,63 and BIT(255,7) = T (controls)"
    else fail "font GLYPH_ROW bounds: rc=$RC out=[$(printf '%s' "$OUT" | head -c 120)] want [0 0 51 63 T]"; fi
    for probe in 64 63 "sub(0)(1)"; do
        nomain theourgia_font.la t_fb2.la "glyph MAIN = print(BIT(255)($probe)(\"T\")(\"F\"))"
        run t_fb2.la 60
        if [ "$RC" = 0 ] && [ "$OUT" = F ]; then pass "font: BIT(255)($probe) = F (column outside 0..7)"
        else fail "font BIT(255)($probe): rc=$RC out=[$(printf '%s' "$OUT" | head -c 120)] want [F]"; fi
    done
}

# ── #77 text session: the font is decoded once per frame, not per lookup ──────
# A glyph is re-evaluated on every reference, so GLYPH_ROW re-decoded all 296
# tokens of FONTDATA on each of the 112 lookups a frame makes (14 chars x 8
# rows) — ~95% of the frame. Fixed: FRAME_TW binds FONTDATA once and threads it
# through GLYPH_ROW_IN. The frame must be byte-identical to a raster derived
# here independently: python decodes FONTDATA's decimal string itself and lays
# out the 160x48 panel (pitch 640) = the window exactly: rows 0-19 and 28-47 all
# WIN_RED (40,40,210,0); text rows 20-27 = 24 red | 14 chars x 8 px (bit c of the
# row byte, bit 0 leftmost: set → 255,255,255,0, else red) | 24 red. Plus a time
# bound: one frame on the host in under FONT_BOUND s (default 25; measured on
# this branch's box: base ~70 s, fixed ~5 s — see the commit).
case_mod_font_hoist() {
    nomain theourgia_text_session_live.la t_fh.la 'glyph MAIN = write_file("fh.bin")(RENDER_FRAME(CONS("160")(CONS("48")(CONS("640")(NIL))))(0)(0))'
    rm -f fh.bin; local t0 t1 secs
    t0=$(date +%s.%N); run t_fh.la 600; t1=$(date +%s.%N)
    secs=$(python3 -c "print(round($t1-$t0,1))")
    local r; r=$(python3 - "$REPO/theourgia_font.la" <<'PYEOF'
import re,sys
src=open(sys.argv[1]).read()
toks=[int(t) for t in re.search(r'glyph FONTDATA = BYTES\("([0-9 ]+)"\)',src).group(1).split()]
idx=" ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
red=bytes([40,40,210,0]); wht=bytes([255,255,255,0])
txt="I AM THAT I AM"
out=red*160*20
for gr in range(8):
    row=red*24
    for ch in txt:
        b=toks[idx.index(ch)*8+gr]
        row+=b''.join(wht if (b>>c)&1 else red for c in range(8))
    out+=row+red*24
out+=red*160*20
try: got=open('fh.bin','rb').read()
except Exception: got=b''
print('OK' if got==out else 'DIFF len %d want %d'%(len(got),len(out)))
PYEOF
)
    if [ "$RC" = 0 ] && [ "$r" = OK ]; then pass "text session frame byte-identical to the independently derived 160x48 raster (${secs}s)"
    else fail "text session frame: rc=$RC $r out=[$(printf '%s' "$OUT" | head -c 100)]"; fi
    if [ "$RC" = 0 ] && python3 -c "import sys; sys.exit(0 if $secs < ${FONT_BOUND:-25} else 1)"; then pass "text session: one frame in ${secs}s (< ${FONT_BOUND:-25}s)"
    else fail "text session: one frame took ${secs}s (bound ${FONT_BOUND:-25}s) — font decoded per lookup?"; fi
}

# ── #34 cob: beat ii's pixel witness is inked by the loop, not by the arms ────
# B2 probed the centre (16,16), but LOOPS_N's RING(16)(16)(5)(1) inks only
# 16 < d² ≤ 25, never the centre; ARM 0/1 (SEGs through (16,16)) ink it for any
# concept with a branch. So the witness was YES for the cycle-free control
# NOCYC = ▷(RECOGNITION,⊗(VOID,BEING)) (feat 0/2/0/2: no ↻). The probe evaluates
# cob.la's OWN beat-ii pixel line with COB replaced by NOCYC: it must say NO,
# and stay YES for COB. Derived: (19,20) has d² = 3²+4² = 25 (on the radius-5
# loop), lies on none of the six arms (rows/cols 16, the anti-diagonal r+c = 32),
# and COB's depth-3 rings have radii 14,11,8 — only the loop can ink it.
case_mod_cob_witness() {
    local wl; wl=$(grep -E '^glyph B2_[A-Z]*PX *=' cob.la | head -1)
    local wn=${wl#glyph }; wn=${wn%% *}
    nomain cob.la t_cob.la "glyph NOCYC = DIR(PRIM(\"RECOGNITION\"))(SYN(PRIM(\"VOID\"))(PRIM(\"BEING\")))"
    printf '%s\n' "$(sed "s/^glyph $wn/glyph W_NOCYC/; s/DSIGIL(COB)/DSIGIL(NOCYC)/" <<< "$wl")" \
        "glyph MAIN = print(concat(\"NOCYC \")(concat(YN(W_NOCYC))(concat(\" COB \")(YN($wn)))))" >> t_cob.la
    run t_cob.la 300
    if [ "$RC" = 0 ] && [ "$OUT" = "NOCYC NO COB YES" ]; then pass "cob beat ii: the loop witness ($wn) is NO for the cycle-free control, YES for COB"
    else fail "cob beat-ii witness $wn: rc=$RC out=[$(printf '%s' "$OUT" | head -c 120)] want [NOCYC NO COB YES]"; fi
}

CASES="${*:-mod_repeat2 mod_font_bounds mod_font_hoist mod_cob_witness}"
for c in $CASES; do "case_$c"; done
[ "$FAILS" -eq 0 ] && { echo "gate_audit2_modules: all passed"; exit 0; } || { echo "gate_audit2_modules: $FAILS failed"; exit 1; }
