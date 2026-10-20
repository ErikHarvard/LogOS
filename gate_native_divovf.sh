#!/bin/sh
# gate_native_divovf.sh — div(LONG_MIN)(-1) halts with the SAME diagnostic on host,
# VM and native: "<engine>: div: overflow (LONG_MIN / -1)", rc 1.
#
# WHAT IT GUARDS. Differential fuzzing (round 5, 2026-10-07) found native routing
# LONG_MIN / -1 to its division-by-zero exit, so it said "native: div: division
# by zero" where host and the VM say overflow. The halt was already loud and
# correct; the message named the wrong fault. Division by zero itself is the
# control: it must keep its own message.
#
# ISOLATION: private mktemp dir; touches no tracked file. Needs gcc. ~3 min.
set -eu
ROOT=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
gcc -O2 -o "$T/tiny_host" "$ROOT/tiny_host.c"
cp "$ROOT/secd.la" "$ROOT/codegen.la" "$ROOT/native_codegen3.la" "$T/"
( cd "$T" && ./tiny_host secd.la >/dev/null 2>&1 && cp codegen.la logos_source.la \
    && ./tiny_host codegen.la >/dev/null 2>&1 && cp logos_program.bin compiler.bin )
ok=1

check() {   # $1 label, $2 got stderr, $3 got rc, $4 want stderr
    if [ "$3" = 1 ] && [ "$2" = "$4" ]; then echo "PASS  divovf ($1): rc 1, '$4'"
    else echo "FAIL  divovf ($1): rc=$3 err='$2' (want rc 1, '$4')"; ok=0; fi
}

# case <label> <MAIN expr> <message after "<engine>: ">
case_() {
    printf 'glyph MAIN = %s\n' "$2" > "$T/p.la"
    rc=0; ( cd "$T" && ./tiny_host p.la >/dev/null 2>"$T/e" ) || rc=$?
    check "host, $1" "$(cat "$T/e")" "$rc" "host: $3"

    cp "$T/p.la" "$T/logos_source.la"; cp "$T/compiler.bin" "$T/logos_program.bin"
    ( cd "$T" && ./logos_secd >/dev/null 2>&1 ) || true
    rc=0; ( cd "$T" && timeout 20 ./logos_secd >/dev/null 2>"$T/e" ) || rc=$?
    check "secd, $1" "$(cat "$T/e")" "$rc" "secd: $3"

    cp "$T/p.la" "$T/native_input.la"; rm -f "$T/native_codegen3_out"
    ( cd "$T" && timeout 600 ./tiny_host native_codegen3.la >/dev/null 2>&1 ) || true
    rc=0; ( cd "$T" && timeout 20 ./native_codegen3_out >/dev/null 2>"$T/e" ) || rc=$?
    check "native, $1" "$(cat "$T/e")" "$rc" "native: $3"
}

LMIN='sub(sub(0)(9223372036854775807))(1)'
case_ 'LONG_MIN / -1'      "print(int_to_str(div($LMIN)(sub(0)(1))))" 'div: overflow (LONG_MIN / -1)'
case_ 'control: 1 / 0'     'print(int_to_str(div(1)(0)))'             'div: division by zero'

[ "$ok" = 1 ] || exit 1
