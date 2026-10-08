#!/bin/sh
# gate_native_fold.sh — the native compiler's constant folding must not evaluate a
# malformed integer literal AT COMPILE TIME.
#
# WHAT IT GUARDS. native_codegen3.la folds str_to_int("<literal>") (CG_UN) and
# add/sub/mul of two such literals (CG_BIN) by calling str_to_int INSIDE the
# compiler. On a malformed literal ("12x") that call halted the COMPILER, so a
# program that host and the VM run correctly was refused, if the literal sat in
# a branch that never executes:
#     glyph PARSE = la s. IF(str_eq(s)("bad"))(la _. str_to_int("12x"))(la _. str_to_int(s))
#     glyph MAIN  = print(PARSE(concat("4")("2")))      host: 42   secd: 42
#     native: "native: str_to_int: not a decimal integer" from the compiler, no binary
# And where the literal IS reached, every effect before it was lost (host prints
# "before" and then halts; native printed nothing because nothing was built).
# Found by differential fuzzing (host vs native), 2026-10-04.
#
# THE RULE NOW: fold only a literal that is a well-formed decimal of at most 18
# digits, which cannot overflow and so folds to exactly what the runtime would
# compute. Anything else is emitted as a runtime call and fails, or not, at run
# time, as on host.
#
# ISOLATION: private mktemp dir; touches no tracked file. Needs gcc. ~1 min (each
# program is compiled through tiny_host native_codegen3.la, i.e. the SOURCE).
set -eu
ROOT=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
gcc -O2 -o "$T/tiny_host" "$ROOT/tiny_host.c"
cp "$ROOT/native_codegen3.la" "$T/"
ok=1
PRE='glyph TRUE = la t. la f. t
glyph FALSE = la t. la f. f
glyph IF = la c. la t. la f. c(t)(f)("!")
glyph SEQ = la a. la b. b'

# case <label> <MAIN-and-glyphs>: native stdout+rc must equal host stdout+rc
case_() {
    printf '%s\n%s\n' "$PRE" "$2" > "$T/native_input.la"
    cp "$T/native_input.la" "$T/p.la"
    hrc=0; hout=$( cd "$T" && ./tiny_host p.la 2>/dev/null ) || hrc=$?
    rm -f "$T/native_codegen3_out"
    ( cd "$T" && timeout 600 ./tiny_host native_codegen3.la >/dev/null 2>"$T/c.err" ) || true
    if [ ! -x "$T/native_codegen3_out" ]; then
        echo "FAIL  native fold ($1): the compiler refused a program host runs (rc $hrc): $(head -1 "$T/c.err")"; ok=0; return
    fi
    nrc=0; nout=$( cd "$T" && timeout 20 ./native_codegen3_out 2>/dev/null ) || nrc=$?
    if [ "$hout" = "$nout" ] && [ "$hrc" = "$nrc" ]; then
        echo "PASS  native fold ($1): native == host (stdout '$(printf '%s' "$nout" | tr '\n' '|')', rc $nrc)"
    else
        echo "FAIL  native fold ($1): host rc=$hrc out='$hout'  native rc=$nrc out='$nout'"; ok=0
    fi
}

case_ "malformed literal on a branch never taken" \
'glyph PARSE = la s. IF(str_eq(s)("bad"))(la _. str_to_int("12x"))(la _. str_to_int(s))
glyph MAIN = print(PARSE(concat("4")("2")))'
case_ "malformed literal reached: effects before it survive" \
'glyph MAIN = SEQ(print("before"))(print(str_to_int("12x")))'
case_ "malformed literal inside a folded add" \
'glyph F = la s. IF(str_eq(s)("bad"))(la _. add(str_to_int(""))(1))(la _. 7)
glyph MAIN = print(F(concat("o")("k")))'
case_ "well-formed literals still fold to the runtime value" \
'glyph MAIN = SEQ(print(add(40)(2)))(SEQ(print(str_to_int("-007")))(print(mul(str_to_int("-9"))(3))))'

[ "$ok" = 1 ] || exit 1
