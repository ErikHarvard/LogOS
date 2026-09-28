#!/usr/bin/env bash
# gate_error_format.sh — one diagnostic format on every engine:
#     <engine>: <builtin>: <message>      exit 1
# with <engine> = host (tiny_host.c) | secd (the SECD VM) | native (native_codegen3).
#
# WHAT IT GUARDS. Before the ruling each engine had its own shape for the same
# failure: the host said "mod: modulo by zero", the VM "secd: division by zero"
# (no builtin), the native runtime "native: mod: modulo by zero"; a non-string
# argument was "str_len: argument is not a string" / "secd: argument is not a
# string" / "native: argument is not a string". Now every builtin-attributable
# error names its engine AND its builtin; engine-level errors (heap exhausted,
# unbound variable, malformed program, ...) are "<engine>: <message>".
#
# WHAT IT RUNS. Three faulty programs, each on all three engines, stderr matched
# EXACTLY (not a substring — a stray prefix or a lost builtin name fails):
#   str_len(5)             -> <e>: str_len: argument is not a string
#   mod(5)(<computed 0>)   -> <e>: mod: division by zero
#   chr(<computed "300">)  -> host adds the value; VM/native: value out of byte range 0..255
# (divisor and chr argument are computed so no engine can constant-fold them.)
#
# ISOLATION: private mktemp dir; touches no tracked file. Needs gcc. ~90 s (the
# native backend compiles each program through tiny_host).
set -eu
ROOT=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
gcc -O2 -o "$T/tiny_host" "$ROOT/tiny_host.c"
cp "$ROOT/secd.la" "$ROOT/codegen.la" "$ROOT/native_codegen3.la" "$T/"
( cd "$T" && ./tiny_host secd.la >/dev/null 2>&1 )
ok=1

check() {   # $1 engine label, $2 got stderr, $3 got rc, $4 want stderr
    if [ "$3" = 1 ] && [ "$2" = "$4" ]; then
        echo "PASS  error format ($1): '$4', rc 1"
    else
        echo "FAIL  error format ($1): rc=$3 stderr='$2' (want rc 1 + '$4')"; ok=0
    fi
}

# case <label> <MAIN expr> <host want> <secd want> <native want>
case_() {
    printf 'glyph MAIN = %s\n' "$2" > "$T/p.la"
    rc=0; err=$( cd "$T" && ./tiny_host p.la 2>&1 >/dev/null ) || rc=$?
    check "host, $1" "$err" "$rc" "$3"

    cp "$T/p.la" "$T/logos_source.la"
    ( cd "$T" && timeout 120 ./tiny_host codegen.la >/dev/null 2>&1 )
    rc=0; err=$( cd "$T" && timeout 20 ./logos_secd 2>&1 >/dev/null ) || rc=$?
    check "secd, $1" "$err" "$rc" "$4"

    cp "$T/p.la" "$T/native_input.la"; rm -f "$T/native_codegen3_out"
    ( cd "$T" && timeout 600 ./tiny_host native_codegen3.la >/dev/null 2>&1 )
    rc=0; err=$( cd "$T" && timeout 20 ./native_codegen3_out 2>&1 >/dev/null ) || rc=$?
    check "native, $1" "$err" "$rc" "$5"
}

case_ "str_len(5)" 'print(str_len(5))' \
    "host: str_len: argument is not a string" \
    "secd: str_len: argument is not a string" \
    "native: str_len: argument is not a string"
case_ "mod by zero" 'print(int_to_str(mod(5)(sub(3)(3))))' \
    "host: mod: division by zero" \
    "secd: mod: division by zero" \
    "native: mod: division by zero"
case_ "chr 300" 'print(chr(concat("3")("00")))' \
    "host: chr: value 300 out of byte range 0..255" \
    "secd: chr: value out of byte range 0..255" \
    "native: chr: value out of byte range 0..255"

[ "$ok" = 1 ] || exit 1
