#!/bin/sh
# gate_unbound_load.sh — host, VM and native accept and reject the SAME programs
# with respect to unbound names, and reject them BEFORE the program runs.
#
# WHAT IT GUARDS. Differential fuzzing (2026-10-04) found native rejecting, at
# compile time, programs host and the VM ran: a typo on a branch that is never
# taken was a valid program on host/VM (they only fail if execution reaches it)
# and a compile error on native. The ruling: all three engines must agree, with
# unbound names rejected at load time on host and VM.
# THE RULE, matching native_codegen3's existing check:
#   * a name is BOUND if it is a lambda parameter in scope, a glyph, or a builtin
#     of ANY engine (the union — so ipc_demo.la-style programs that mention a
#     VM-only builtin still load on host);
#   * the check covers every glyph REACHABLE FROM MAIN — an unused glyph is not
#     checked, as on native;
#   * an unbound name halts the load with rc 1 and the name in the diagnostic,
#     and nothing the program would print is printed.
#
# ISOLATION: private mktemp dir; touches no tracked file. Needs gcc. ~10 min (the
# native backend compiles each case through tiny_host native_codegen3.la).
set -eu
ROOT=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
gcc -O2 -o "$T/tiny_host" "$ROOT/tiny_host.c"
cp "$ROOT/secd.la" "$ROOT/codegen.la" "$ROOT/native_codegen3.la" "$T/"
( cd "$T" && ./tiny_host secd.la >/dev/null 2>&1 && cp codegen.la logos_source.la \
    && ./tiny_host codegen.la >/dev/null 2>&1 && cp logos_program.bin compiler.bin )
ok=1

# verdict <label> <stdout> <stderr> <rc> <want: ok|reject> <name>
verdict() {
    if [ "$5" = ok ]; then
        if [ "$4" = 0 ] && [ "$2" = ok ]; then echo "PASS  unbound ($1): accepted, out 'ok'"
        else echo "FAIL  unbound ($1): want accepted with out 'ok'; got rc=$4 out='$2' err='$3'"; ok=0; fi
    else
        case "$3" in *unbound*"$6"*) named=1 ;; *) named=0 ;; esac
        if [ "$4" != 0 ] && [ -z "$2" ] && [ "$named" = 1 ]; then echo "PASS  unbound ($1): rejected before running, '$3'"
        else echo "FAIL  unbound ($1): want rejected before running, naming '$6'; got rc=$4 out='$2' err='$3'"; ok=0; fi
    fi
}

# case <label> <program text> <ok|reject> <name>
case_() {
    printf '%s\n' "$2" > "$T/p.la"
    rc=0; out=$( cd "$T" && ./tiny_host p.la 2>"$T/e" ) || rc=$?
    verdict "host, $1" "$out" "$(cat "$T/e")" "$rc" "$3" "$4"

    # VM: the load step is the compiler (codegen.la, running as compiler.bin on
    # the VM); a rejection there is the VM's rejection.
    cp "$T/p.la" "$T/logos_source.la"; cp "$T/compiler.bin" "$T/logos_program.bin"
    rc=0; ( cd "$T" && timeout 60 ./logos_secd >/dev/null 2>"$T/e" ) || rc=$?
    if [ "$rc" = 0 ]; then
        rc=0; out=$( cd "$T" && timeout 20 ./logos_secd 2>"$T/e" ) || rc=$?
    else out=""; fi
    verdict "secd, $1" "$out" "$(cat "$T/e")" "$rc" "$3" "$4"

    cp "$T/p.la" "$T/native_input.la"; rm -f "$T/native_codegen3_out"
    rc=0; ( cd "$T" && timeout 600 ./tiny_host native_codegen3.la >/dev/null 2>"$T/e" ) || rc=$?
    if [ "$rc" = 0 ] && [ -x "$T/native_codegen3_out" ]; then
        rc=0; out=$( cd "$T" && timeout 20 ./native_codegen3_out 2>"$T/e" ) || rc=$?
    else out=""; [ "$rc" = 0 ] && rc=1; fi
    verdict "native, $1" "$out" "$(cat "$T/e")" "$rc" "$3" "$4"
}

case_ 'typo on a branch never taken' \
    'glyph MAIN = (la t. la f. t)(la _. print("ok"))(la _. prnt("x"))("!")' reject prnt
case_ 'typo in a glyph MAIN reaches' \
    'glyph HELPER = la x. nosuch(x)
glyph MAIN = (la t. la f. t)(la _. print("ok"))(la _. HELPER("x"))("!")' reject nosuch
case_ 'VM-only builtin on a branch never taken' \
    'glyph MAIN = (la t. la f. t)(la _. print("ok"))(la _. fork("!"))("!")' ok fork
case_ 'unbound name in a glyph MAIN never reaches' \
    'glyph UNUSED = nosuchname("x")
glyph MAIN = print("ok")' ok nosuchname

[ "$ok" = 1 ] || exit 1
