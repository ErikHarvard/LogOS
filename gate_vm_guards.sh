#!/usr/bin/env bash
# gate_vm_guards.sh — the native SECD VM's builtin guards must halt LOUDLY
# (a "secd: …" diagnostic, rc 1), never crash and never give a wrong answer.
#
# WHAT IT GUARDS (each was a real failure on kernel-k1 before the fix):
#   int builtin given a STR      add("3")(4) → printed the descriptor POINTER, rc 0
#   error(5)                     → SIGSEGV (rc 139)
#   read_file on a directory     → heap pointer moved backwards, then SIGSEGV
#   div(LONG_MIN)(-1)            → SIGFPE (rc 136);  mod(LONG_MIN)(-1) → SIGFPE
#   div by zero                  → rc 1 with NO message
#   read_file of a missing file  → returned "" with rc 0 (host halts; silent success)
#   missing logos_program.bin    → rc 1 with NO message
# Each case is a tiny .la program compiled by codegen.la and run on the VM
# emitted from the committed secd.la; the expected stderr is matched exactly.
#
# ISOLATION: private mktemp dir; builds tiny_host and the VM there; touches no
# tracked file and no fixed /tmp path. Needs: gcc. ~20 s (codegen per case).
set -eu
ROOT=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
gcc -O2 -o "$T/tiny_host" "$ROOT/tiny_host.c"
cp "$ROOT/secd.la" "$ROOT/codegen.la" "$T/"
( cd "$T" && ./tiny_host secd.la >/dev/null 2>&1 )
ok=1

# run_la <label> <program text> <expected rc> <expected stderr> [expected stdout]
run_la() {
    printf '%s\n' "$2" > "$T/logos_source.la"
    ( cd "$T" && timeout 120 ./tiny_host codegen.la >/dev/null 2>&1 ) || { echo "FAIL  vm guards gate ($1): codegen failed"; ok=0; return; }
    rc=0; out=$( cd "$T" && timeout 20 ./logos_secd 2>"$T/err" ) || rc=$?
    err=$(cat "$T/err")
    sfx=""; [ -z "${5:-}" ] || sfx=", stdout '${5}'"
    if [ "$rc" = "$3" ] && [ "$err" = "$4" ] && [ "$out" = "${5:-}" ]; then
        echo "PASS  vm guards gate ($1): rc $rc, '${4:-<no stderr>}'$sfx"
    else
        echo "FAIL  vm guards gate ($1): rc=$rc out='$out' err='$err' (want rc $3, stderr '$4'$sfx; rc 139/136 = crash regression, rc 0 = silent wrong answer)"; ok=0
    fi
}
LMIN='glyph LMIN = sub(sub(0)(9223372036854775807))(1)'
run_la "int builtin on STR"   'glyph MAIN = print(int_to_str(add("3")(4)))'               1 "secd: add: argument is not an integer"
run_la "int_to_str on STR"    'glyph MAIN = print(int_to_str("x"))'                       1 "secd: int_to_str: argument is not an integer"
run_la "error(5)"             'glyph MAIN = print(error(5))'                              1 "secd: error: argument is not a string"
run_la "read_file directory"  'glyph MAIN = print(str_len(read_file("/")))'               1 "secd: read_file: read failed"
run_la "LONG_MIN / -1"        "$LMIN"$'\n''glyph MAIN = print(int_to_str(div(LMIN)(sub(0)(1))))' 1 "secd: div: overflow (LONG_MIN / -1)"
run_la "LONG_MIN mod -1"      "$LMIN"$'\n''glyph MAIN = print(int_to_str(mod(LMIN)(sub(0)(1))))' 0 "" "0"
run_la "div by zero"          'glyph MAIN = print(int_to_str(div(1)(0)))'                 1 "secd: div: division by zero"
run_la "read_file missing file" 'glyph MAIN = print(concat("[")(concat(read_file("no_such_file"))("]")))' 1 "secd: read_file: cannot open 'no_such_file'"
run_la "mod by zero"          'glyph MAIN = print(int_to_str(mod(1)(0)))'                 1 "secd: mod: division by zero"
run_la "control: 6*7"         'glyph MAIN = print(int_to_str(mul(6)(7)))'                 0 "" "42"

# missing program stream
rm -f "$T/logos_program.bin"
rc=0; out=$( cd "$T" && ./logos_secd 2>"$T/err" ) || rc=$?; err=$(cat "$T/err")
if [ "$rc" = 1 ] && [ "$err" = "secd: cannot open logos_program.bin" ]; then
    echo "PASS  vm guards gate (missing logos_program.bin): rc 1, '$err'"
else
    echo "FAIL  vm guards gate (missing logos_program.bin): rc=$rc err='$err' (want rc 1 + 'secd: cannot open logos_program.bin')"; ok=0
fi

[ "$ok" = 1 ] || exit 1
