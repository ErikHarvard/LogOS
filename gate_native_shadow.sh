#!/bin/sh
# gate_native_shadow.sh — a name that shadows a builtin means the same thing on
# host, VM and native: a glyph or a lambda parameter named like a builtin wins
# over the builtin, as host and the VM resolve names (scope, then glyph, then
# builtin).
#
# WHAT IT GUARDS. Differential testing (2026-10-07) found native resolving such a
# name as the builtin:
#   * glyph str_head = la s. "mine" ; print(str_head("abc"))
#       host/VM "mine", native "a" (INLINE tested IS_BUILTIN before the table);
#   * a Z-recursive helper whose parameter is named str_head or concat
#       host/VM "mine", native "a" (CG_APP matched a head-position builtin by
#       name without asking whether the name is bound).
# A program that uses a builtin directly is unaffected (the control case).
#
# ISOLATION: private mktemp dir; touches no tracked file. Needs gcc. ~8 min (the
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
glyph IF = la c. la t. la f. c(t)(f)("!")'

check() {   # $1 label, $2 stdout, $3 stderr, $4 rc, $5 want stdout
    if [ "$4" = 0 ] && [ "$2" = "$5" ]; then echo "PASS  shadow ($1): out '$5'"
    else echo "FAIL  shadow ($1): rc=$4 out='$2' err='$3' (want rc 0, out '$5')"; ok=0; fi
}

# case <label> <glyph lines before MAIN> <MAIN expr> <want stdout>
case_() {
    printf '%s\n%s\nglyph MAIN = %s\n' "$PRELUDE" "$2" "$3" > "$T/p.la"
    rc=0; out=$( cd "$T" && ./tiny_host p.la 2>"$T/e" ) || rc=$?
    check "host, $1" "$out" "$(cat "$T/e")" "$rc" "$4"

    cp "$T/p.la" "$T/logos_source.la"; cp "$T/compiler.bin" "$T/logos_program.bin"
    rc=0; ( cd "$T" && timeout 60 ./logos_secd >/dev/null 2>"$T/e" ) || rc=$?
    if [ "$rc" = 0 ]; then rc=0; out=$( cd "$T" && timeout 20 ./logos_secd 2>"$T/e" ) || rc=$?; else out=""; fi
    check "secd, $1" "$out" "$(cat "$T/e")" "$rc" "$4"

    cp "$T/p.la" "$T/native_input.la"; rm -f "$T/native_codegen3_out"
    rc=0; ( cd "$T" && timeout 600 ./tiny_host native_codegen3.la >/dev/null 2>"$T/e" ) || rc=$?
    if [ "$rc" = 0 ] && [ -x "$T/native_codegen3_out" ]; then
        rc=0; out=$( cd "$T" && timeout 20 ./native_codegen3_out 2>"$T/e" ) || rc=$?
    else out=""; [ "$rc" = 0 ] && rc=1; fi
    check "native, $1" "$out" "$(cat "$T/e")" "$rc" "$4"
}

case_ 'glyph named like a unary builtin' 'glyph str_head = la s. "mine"' 'print(str_head("abc"))' 'mine'
case_ 'glyph named like a binary builtin' 'glyph concat = la a. la b. "mine"' 'print(concat("a")("b"))' 'mine'
case_ 'parameter named like a unary builtin, through recursion' \
    'glyph F = Z(la self. la str_head. la n. IF(lt(n)(1))(la _. str_head("abc"))(la _. self(str_head)(sub(n)(1))))' \
    'print(F(la s. "mine")(3))' 'mine'
case_ 'parameter named like a binary builtin, through recursion' \
    'glyph G = Z(la self. la concat. la n. IF(lt(n)(1))(la _. concat("a")("b"))(la _. self(concat)(sub(n)(1))))' \
    'print(G(la x. la y. "mine")(3))' 'mine'
case_ 'control: the builtin itself' '' 'print(concat(str_head("abc"))("b"))' 'ab'

[ "$ok" = 1 ] || exit 1
