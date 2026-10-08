#!/bin/sh
# gate_native_nonfn.sh — applying a non-function must fail LOUDLY on native, as it
# does on host and secd.
#
# WHAT IT GUARDS. rt_apply's non-function path exited 70 with NOTHING on stderr,
# so `print(("x")("y"))` looked like an anonymous failure while host and secd say
# "<engine>: attempt to apply a non-function". Found by differential fuzzing
# (host vs native), 2026-10-04. The exit code stays 70, as for the runtime's other
# distinctive exits (71-73, 134), each of which also prints its message first;
# only the silence was the defect.
#
# ISOLATION: private mktemp dir; touches no tracked file. Needs gcc. ~1 min.
set -eu
ROOT=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
gcc -O2 -o "$T/tiny_host" "$ROOT/tiny_host.c"
cp "$ROOT/native_codegen3.la" "$T/"
ok=1
case_() {   # $1 label, $2 program
    printf '%s\n' "$2" > "$T/native_input.la"; cp "$T/native_input.la" "$T/p.la"
    hout=$( cd "$T" && ./tiny_host p.la 2>/dev/null ) || true
    rm -f "$T/native_codegen3_out"
    ( cd "$T" && timeout 600 ./tiny_host native_codegen3.la >/dev/null 2>&1 ) || true
    [ -x "$T/native_codegen3_out" ] || { echo "FAIL  native nonfn ($1): no binary"; ok=0; return; }
    nrc=0; nout=$( cd "$T" && timeout 20 ./native_codegen3_out 2>"$T/n.err" ) || nrc=$?
    nerr=$(cat "$T/n.err")
    if [ "$nrc" -ne 0 ] && [ "$nerr" = "native: attempt to apply a non-function" ] && [ "$nout" = "$hout" ]; then
        echo "PASS  native nonfn ($1): '$nerr', rc $nrc, stdout before it == host"
    else
        echo "FAIL  native nonfn ($1): rc=$nrc stderr='$nerr' stdout='$nout' (host stdout '$hout'; want rc!=0 + 'native: attempt to apply a non-function')"; ok=0
    fi
}
case_ "apply a string" 'glyph MAIN = print(("x")("y"))'
case_ "apply an int, after output" 'glyph SEQ = la a. la b. b
glyph MAIN = SEQ(print("before"))(print((add(1)(2))("y")))'
[ "$ok" = 1 ] || exit 1
