#!/bin/sh
# gate_builtin_value.sh — a builtin used as a VALUE (passed, stored, partially
# applied) means the same thing on host, VM and native.
#
# WHAT IT GUARDS. Host and the VM treat a builtin as a first-class value;
# native_codegen3 refused one at compile time ("free variable (builtin used as
# value?)"), so programs such as specpipe.la's CAT = FOLDR(concat)("") ran on
# host and the VM but did not compile natively. All three engines must accept
# and reject the same programs; native now compiles a builtin value as its
# eta-expansion.
# The cases pass the builtin into a Z-recursive helper, which the native
# compiler's beta-reduction cannot unfold back into a head-position call — so the
# value path is what runs.
#
# ISOLATION: private mktemp dir; touches no tracked file. Needs gcc. ~6 min (the
# native backend compiles each case through tiny_host native_codegen3.la).
set -eu
ROOT=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
gcc -O2 -o "$T/tiny_host" "$ROOT/tiny_host.c"
cp "$ROOT/secd.la" "$ROOT/codegen.la" "$ROOT/native_codegen3.la" "$T/"
( cd "$T" && ./tiny_host secd.la >/dev/null 2>&1 && cp codegen.la logos_source.la \
    && ./tiny_host codegen.la >/dev/null 2>&1 && cp logos_program.bin compiler.bin )
ok=1

PRELUDE='glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph IF = la c. la t. la f. c(t)(f)("!")
glyph TIMES1 = Z(la self. la g. la n. IF(int_eq(n)(0))(la _. "")(la _. concat(g("ab"))(self(g)(sub(n)(1)))))
glyph TIMES2 = Z(la self. la g. la n. IF(int_eq(n)(0))(la _. "")(la _. g("x")(self(g)(sub(n)(1)))))'

check() {   # $1 label, $2 stdout, $3 stderr, $4 rc, $5 want stdout
    if [ "$4" = 0 ] && [ "$2" = "$5" ]; then echo "PASS  builtin value ($1): out '$5'"
    else echo "FAIL  builtin value ($1): rc=$4 out='$2' err='$3' (want rc 0, out '$5')"; ok=0; fi
}

# case <label> <MAIN expr> <want stdout>
case_() {
    printf '%s\nglyph MAIN = %s\n' "$PRELUDE" "$2" > "$T/p.la"
    rc=0; out=$( cd "$T" && ./tiny_host p.la 2>"$T/e" ) || rc=$?
    check "host, $1" "$out" "$(cat "$T/e")" "$rc" "$3"

    cp "$T/p.la" "$T/logos_source.la"; cp "$T/compiler.bin" "$T/logos_program.bin"
    rc=0; ( cd "$T" && timeout 60 ./logos_secd >/dev/null 2>"$T/e" ) || rc=$?
    if [ "$rc" = 0 ]; then rc=0; out=$( cd "$T" && timeout 20 ./logos_secd 2>"$T/e" ) || rc=$?; else out=""; fi
    check "secd, $1" "$out" "$(cat "$T/e")" "$rc" "$3"

    cp "$T/p.la" "$T/native_input.la"; rm -f "$T/native_codegen3_out"
    rc=0; ( cd "$T" && timeout 600 ./tiny_host native_codegen3.la >/dev/null 2>"$T/e" ) || rc=$?
    if [ "$rc" = 0 ] && [ -x "$T/native_codegen3_out" ]; then
        rc=0; out=$( cd "$T" && timeout 20 ./native_codegen3_out 2>"$T/e" ) || rc=$?
    else out=""; [ "$rc" = 0 ] && rc=1; fi
    check "native, $1" "$out" "$(cat "$T/e")" "$rc" "$3"
}

case_ 'arity-1 builtin passed to a recursive helper' 'print(TIMES1(str_head)(3))' 'aaa'
case_ 'arity-2 builtin passed to a recursive helper' 'print(TIMES2(concat)(3))'   'xxx'
case_ 'partially applied builtin as a value'         'print(TIMES1(concat("-"))(2))' '-ab-ab'

[ "$ok" = 1 ] || exit 1
