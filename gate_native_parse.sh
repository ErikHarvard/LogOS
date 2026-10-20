#!/bin/sh
# gate_native_parse.sh — the native compiler must reject what host rejects.
#
# WHAT IT GUARDS. Two leniencies in native_codegen3.la's parser, found by
# differential fuzzing (host vs native), 2026-10-04:
#   * P_LAMBDA dropped the token after the parameter WITHOUT checking it was the
#     '.', so `la t junk la f. t` compiled as `la t. la f. t`;
#   * PARSE_MOD_LOOP took whatever followed `glyph` as the name, so `glyph la = ...`
#     (a keyword) and `glyph "s" = ...` (a string) compiled.
# host rejects all three ("expected '.'", "expected glyph name"), and so does the
# VM's compiler; native built a binary and ran it.
#
# ISOLATION: private mktemp dir; touches no tracked file. Needs gcc. ~2 min.
set -eu
ROOT=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
gcc -O2 -o "$T/tiny_host" "$ROOT/tiny_host.c"
cp "$ROOT/native_codegen3.la" "$T/"
ok=1
compile() {  # $1 program -> sets crc, built
    printf '%s\n' "$1" > "$T/native_input.la"; cp "$T/native_input.la" "$T/p.la"
    rm -f "$T/native_codegen3_out"; crc=0
    ( cd "$T" && timeout 600 ./tiny_host native_codegen3.la >/dev/null 2>"$T/c.err" ) || crc=$?
    built=0; if [ -x "$T/native_codegen3_out" ]; then built=1; fi
}
reject() {   # $1 label, $2 program: host rejects it, so native must too
    hrc=0; printf '%s\n' "$2" > "$T/p.la"; ( cd "$T" && ./tiny_host p.la >/dev/null 2>&1 ) || hrc=$?
    compile "$2"
    if [ "$hrc" -ne 0 ] && [ "$crc" -ne 0 ] && [ "$built" = 0 ]; then
        echo "PASS  native parse ($1): rejected like host — $(head -1 "$T/c.err")"
    else
        echo "FAIL  native parse ($1): host rc=$hrc, native compile rc=$crc built=$built (want both rejecting, no binary)"; ok=0
    fi
}
reject "junk between lambda parameter and '.'" 'glyph K = la t junk la f. t
glyph MAIN = print(K("a")("b"))'
reject "keyword as glyph name" 'glyph la = la x. x
glyph MAIN = print("ok")'
reject "string as glyph name" 'glyph "s" = la x. x
glyph MAIN = print("ok")'
# control: the well-formed shape still compiles and runs
compile 'glyph K = la t. la f. t
glyph MAIN = print(K("a")("b"))'
out=""
if [ "$built" = 1 ]; then out=$( cd "$T" && ./native_codegen3_out 2>&1 ) || true; fi
if [ "$out" = "a" ]; then echo "PASS  native parse (control): la t. la f. t compiles and prints 'a'"
else echo "FAIL  native parse (control): well-formed program gave '$out' (compile rc $crc)"; ok=0; fi
[ "$ok" = 1 ] || exit 1
