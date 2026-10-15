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

CASES="${*:-mod_font_bounds}"
for c in $CASES; do "case_$c"; done
[ "$FAILS" -eq 0 ] && { echo "gate_audit2_modules: all passed"; exit 0; } || { echo "gate_audit2_modules: $FAILS failed"; exit 1; }
