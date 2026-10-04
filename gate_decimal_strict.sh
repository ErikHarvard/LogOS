#!/bin/sh
# gate_decimal_strict.sh — the decimal arguments of chr and str_to_int follow ONE
# rule on every engine, and a bad one halts loudly instead of silently diverging.
#
# WHAT IT GUARDS. Differential fuzzing (host vs native vs secd, 2026-10-04) found:
#   * chr of a non-decimal string succeeded silently, with DIFFERENT bytes per
#     engine: host strtol gave chr("x") = "\0", chr("7x") = "\a"; the VM and native
#     ran every byte through (c-'0') and gave "H" and byte 216.
# THE RULE: an optional '-' then one or more digits, else
#   "<engine>: <builtin>: not a decimal integer", rc 1 (str_to_int already did this);
# chr's value must be 0..255, overflow included, else the range message.
#
# ISOLATION: private mktemp dir; touches no tracked file. Needs gcc. ~3 min (the
# native backend compiles each case through tiny_host native_codegen3.la).
set -eu
ROOT=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
gcc -O2 -o "$T/tiny_host" "$ROOT/tiny_host.c"
cp "$ROOT/secd.la" "$ROOT/codegen.la" "$ROOT/native_codegen3.la" "$T/"
( cd "$T" && ./tiny_host secd.la >/dev/null 2>&1 && cp codegen.la logos_source.la \
    && ./tiny_host codegen.la >/dev/null 2>&1 && cp logos_program.bin compiler.bin )
ok=1

check() {   # $1 label, $2 got stdout, $3 got stderr, $4 got rc, $5 want stdout, $6 want stderr, $7 want rc
    if [ "$2" = "$5" ] && [ "$3" = "$6" ] && [ "$4" = "$7" ]; then
        msg="rc $4"; [ -n "$6" ] && msg="$msg, '$6'"; [ -n "$5" ] && msg="$msg, out '$5'"
        echo "PASS  decimal ($1): $msg"
    else
        echo "FAIL  decimal ($1): rc=$4 out='$2' err='$3' (want rc $7, out '$5', err '$6')"; ok=0
    fi
}

# case <label> <MAIN expr> <want stdout> <want rc> <host err> <secd err> <native err>
case_() {
    printf 'glyph MAIN = %s\n' "$2" > "$T/p.la"
    rc=0; out=$( cd "$T" && ./tiny_host p.la 2>"$T/e" ) || rc=$?
    check "host, $1" "$out" "$(cat "$T/e")" "$rc" "$3" "$5" "$4"

    cp "$T/p.la" "$T/logos_source.la"; cp "$T/compiler.bin" "$T/logos_program.bin"
    ( cd "$T" && ./logos_secd >/dev/null 2>&1 ) || true
    rc=0; out=$( cd "$T" && timeout 20 ./logos_secd 2>"$T/e" ) || rc=$?
    check "secd, $1" "$out" "$(cat "$T/e")" "$rc" "$3" "$6" "$4"

    cp "$T/p.la" "$T/native_input.la"; rm -f "$T/native_codegen3_out"
    ( cd "$T" && timeout 600 ./tiny_host native_codegen3.la >/dev/null 2>&1 ) || true
    rc=0; out=$( cd "$T" && timeout 20 ./native_codegen3_out 2>"$T/e" ) || rc=$?
    check "native, $1" "$out" "$(cat "$T/e")" "$rc" "$3" "$7" "$4"
}
nd() { case_ "$1" "$2" "" 1 "host: chr: not a decimal integer" "secd: chr: not a decimal integer" "native: chr: not a decimal integer"; }

nd 'chr("x")'  'print(chr(concat("x")("")))'
nd 'chr("")'   'print(chr(concat("")("")))'
nd 'chr("7x")' 'print(chr(concat("7")("x")))'
nd 'chr(" 5")' 'print(chr(concat(" ")("5")))'
case_ 'chr(20 digits)' 'print(chr(concat("9999999999")("9999999999")))' "" 1 \
    "host: chr: value 99999999999999999999 out of byte range 0..255" \
    "secd: chr: value out of byte range 0..255" "native: chr: value out of byte range 0..255"
case_ 'chr("-1")' 'print(chr(concat("-")("1")))' "" 1 \
    "host: chr: value -1 out of byte range 0..255" \
    "secd: chr: value out of byte range 0..255" "native: chr: value out of byte range 0..255"
case_ 'chr("065")' 'print(chr(concat("06")("5")))' "A" 0 "" "" ""

[ "$ok" = 1 ] || exit 1
