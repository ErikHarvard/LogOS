#!/usr/bin/env bash
# gate_wm_termfont.sh — the terminal font (theourgia_termfont.la) decodes to the
# right 768 bytes, the same on the C host and the native VM.
#
# WHAT IT GUARDS. TF_HEX spells the 96-glyph table (codes 32..127) as letters
# because the VM's program stream cannot carry NUL bytes in a literal, and
# TF_DECODE turns the letters back into bytes. A slip in the encoding or the
# decoder shifts or corrupts glyphs silently: text still draws, just wrong.
#
#   1. VM:   TF_DECODE(TF_HEX) equals the expected table below, byte for byte.
#            The expected table is font8x8_basic (public domain) for codes
#            32..126 with LogOS's own T and 7 from theourgia_font.la, and a
#            solid block (eight 255s) at 127, the cursor.
#   2. host: the C host decodes the same bytes as the VM.
#   3. the 37 glyphs theourgia_font.la also carries (space, A-Z, 0-9) are
#      identical in both fonts, read straight out of theourgia_font.la's
#      FONTDATA, so the two fonts cannot drift apart.
#
# ISOLATION: a private temporary directory (gate_wm_common.sh); touches no
# tracked file. About 40 s, nearly all of it building the toolchain.
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1

EXPECT="0 0 0 0 0 0 0 0 24 60 60 24 24 0 24 0 54 54 0 0 0 0 0 0 54 54 127 54 127 54 54 0 12 62 3 30 48 31 12 0 0 99 51 24 12 102 99 0 28 54 28 110 59 51 110 0 6 6 3 0 0 0 0 0 24 12 6 6 6 12 24 0 6 12 24 24 24 12 6 0 0 102 60 255 60 102 0 0 0 12 12 63 12 12 0 0 0 0 0 0 0 12 12 6 0 0 0 63 0 0 0 0 0 0 0 0 0 12 12 0 96 48 24 12 6 3 1 0 62 99 115 123 111 103 62 0 12 14 12 12 12 12 63 0 30 51 48 28 6 51 63 0 30 51 48 28 48 51 30 0 56 60 54 51 127 48 120 0 63 3 31 48 48 51 30 0 28 6 3 31 51 51 30 0 127 51 48 24 12 12 12 0 30 51 51 30 51 51 30 0 30 51 51 62 48 24 14 0 0 12 12 0 0 12 12 0 0 12 12 0 0 12 12 6 24 12 6 3 6 12 24 0 0 0 63 0 0 63 0 0 6 12 24 48 24 12 6 0 30 51 48 24 12 0 12 0 62 99 123 123 123 3 30 0 12 30 51 51 63 51 51 0 63 102 102 62 102 102 63 0 60 102 3 3 3 102 60 0 31 54 102 102 102 54 31 0 127 70 22 30 22 70 127 0 127 70 22 30 22 6 15 0 60 102 3 3 115 102 124 0 51 51 51 63 51 51 51 0 30 12 12 12 12 12 30 0 120 48 48 48 51 51 30 0 103 102 54 30 54 102 103 0 15 6 6 6 70 102 127 0 99 119 127 127 107 99 99 0 99 103 111 123 115 99 99 0 28 54 99 99 99 54 28 0 63 102 102 62 6 6 15 0 30 51 51 51 59 30 56 0 63 102 102 62 54 102 103 0 30 51 7 14 56 51 30 0 63 12 12 12 12 12 12 0 51 51 51 51 51 51 63 0 51 51 51 51 51 30 12 0 99 99 99 107 127 119 99 0 99 99 54 28 28 54 99 0 51 51 51 30 12 12 30 0 127 99 49 24 76 102 127 0 30 6 6 6 6 6 30 0 3 6 12 24 48 96 64 0 30 24 24 24 24 24 30 0 8 28 54 99 0 0 0 0 0 0 0 0 0 0 0 255 12 12 24 0 0 0 0 0 0 0 30 48 62 51 110 0 7 6 6 62 102 102 59 0 0 0 30 51 3 51 30 0 56 48 48 62 51 51 110 0 0 0 30 51 63 3 30 0 28 54 6 15 6 6 15 0 0 0 110 51 51 62 48 31 7 6 54 110 102 102 103 0 12 0 14 12 12 12 30 0 48 0 48 48 48 51 51 30 7 6 102 54 30 54 103 0 14 12 12 12 12 12 30 0 0 0 51 127 127 107 99 0 0 0 31 51 51 51 51 0 0 0 30 51 51 51 30 0 0 0 59 102 102 62 6 15 0 0 110 51 51 62 48 120 0 0 59 110 102 6 15 0 0 0 62 3 30 48 31 0 8 12 62 12 12 44 24 0 0 0 51 51 51 51 110 0 0 0 51 51 51 30 12 0 0 0 99 107 127 127 54 0 0 0 99 54 28 54 99 0 0 0 51 51 51 62 48 31 0 0 63 25 12 38 63 0 56 12 12 7 12 12 56 0 24 24 24 0 24 24 24 0 7 12 12 56 12 12 7 0 110 59 0 0 0 0 0 0 255 255 255 255 255 255 255 255"

wm_setup theourgia_termfont.la
cat > "$T/tf.la" <<'LAEOF'
import("theourgia_termfont.la")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph DUMP = Z(la self. la s. la i. la n.
    int_eq(i)(n)(la _. "")(la _.
      concat(int_to_str(str_to_int(ord(str_at(s)(i)))))
        (concat(int_eq(add(i)(1))(n)(la _. "")(la _. " ")("!"))(self(s)(add(i)(1))(n))))("!"))
glyph MAIN = (la f. print(DUMP(f)(0)(str_to_int(str_len(f)))))
    (TF_DECODE(str_at)(ord)(str_to_int)(str_len)(chr)(int_to_str)(concat)(add)(sub)(mul)(div)(int_eq)(TF_HEX))
LAEOF

wm_vm tf.la "$T/vm.txt"
if [ "$vrc" = 0 ] && [ "$(cat "$T/vm.txt")" = "$EXPECT" ]; then
    echo "PASS  termfont (VM): TF_DECODE(TF_HEX) is the expected 768-byte table"
else
    echo "FAIL  termfont (VM): rc=$vrc, output differs from the expected table ($(head -c 120 "$T/vm.txt")...)"; ok=0
fi

wm_host tf.la "$T/host.txt"
if [ "$hrc" = 0 ] && cmp -s "$T/host.txt" "$T/vm.txt"; then
    echo "PASS  termfont (host): the C host decodes the same bytes as the VM"
else
    echo "FAIL  termfont (host): rc=$hrc, host output differs from the VM's"; ok=0
fi

shared=$(python3 - "$WM_ROOT/theourgia_font.la" "$T/vm.txt" <<'PYEOF'
import re, sys
la = open(sys.argv[1]).read()
index = re.search(r'glyph INDEX = "([^"]*)"', la).group(1)
data = [int(x) for x in re.search(r'glyph FONTDATA = BYTES\("([^"]*)"\)', la).group(1).split()]
tf = [int(x) for x in open(sys.argv[2]).read().split()]
bad = [c for i, c in enumerate(index)
       if data[i*8:i*8+8] != tf[(ord(c)-32)*8:(ord(c)-32)*8+8]]
print(len(index), "".join(bad) if bad else "-")
PYEOF
)
if [ "$shared" = "37 -" ]; then
    echo "PASS  termfont: the 37 glyphs shared with theourgia_font.la are identical"
else
    echo "FAIL  termfont: glyphs that differ from theourgia_font.la (count, chars): $shared"; ok=0
fi

[ "$ok" = 1 ] || exit 1
