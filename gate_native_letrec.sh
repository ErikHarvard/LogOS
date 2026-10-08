#!/bin/sh
# gate_native_letrec.sh — recursion BY NAME (a glyph that refers to itself, or a
# cycle of glyphs) must mean on native what it means on host and secd.
#
# WHAT IT GUARDS. native_codegen3 inlines every glyph, so its letrec pass turns a
# glyph cycle into one fixpoint bundle. Differential fuzzing (host vs native vs
# secd, 2026-10-04) found it wrong three ways:
#   (a) it applied a glyph literally named Z, so a program with no Z failed to
#       compile: "native_codegen3: unbound name: Z";
#   (b) the bundle evaluated EVERY member's body whenever any member was used, so
#       a data glyph in a cycle (TBL = PAIR(F)(..), F using TBL) re-entered the
#       bundle forever: "native: stack overflow" where host and secd print the value;
#   (c) a program whose own Z is not the fixpoint combinator had it applied as one.
# Now the bundle uses the compiler's private __LRZ and thunks each member, so a
# glyph is evaluated by name, when used, as on host.
#
# ISOLATION: private mktemp dir; touches no tracked file. Needs gcc. ~3 min.
set -eu
ROOT=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
gcc -O2 -o "$T/tiny_host" "$ROOT/tiny_host.c"
cp "$ROOT/native_codegen3.la" "$T/"
ok=1
PRE='glyph TRUE = la t. la f. t
glyph FALSE = la t. la f. f
glyph IF = la c. la t. la f. c(t)(f)("!")
glyph SEQ = la a. la b. b
glyph PAIR = la a. la b. la k. k(a)(b)
glyph FST = la p. p(la a. la b. a)'
case_() {   # $1 label, $2 glyphs: native stdout+rc must equal host's
    printf '%s\n%s\n' "$PRE" "$2" > "$T/native_input.la"; cp "$T/native_input.la" "$T/p.la"
    hrc=0; hout=$( cd "$T" && timeout 20 ./tiny_host p.la 2>/dev/null ) || hrc=$?
    rm -f "$T/native_codegen3_out"
    ( cd "$T" && timeout 900 ./tiny_host native_codegen3.la >/dev/null 2>"$T/c.err" ) || true
    if [ ! -x "$T/native_codegen3_out" ]; then
        echo "FAIL  native letrec ($1): no binary — $(head -1 "$T/c.err") (host rc $hrc, '$hout')"; ok=0; return
    fi
    nrc=0; nout=$( cd "$T" && timeout 20 ./native_codegen3_out 2>"$T/n.err" ) || nrc=$?
    if [ "$hout" = "$nout" ] && [ "$hrc" = "$nrc" ]; then
        echo "PASS  native letrec ($1): native == host ('$(printf '%s' "$nout" | tr '\n' '|')', rc $nrc)"
    else
        echo "FAIL  native letrec ($1): host rc=$hrc '$hout'  native rc=$nrc '$nout' $(head -1 "$T/n.err")"; ok=0
    fi
}
case_ "(a) self-recursion, no Z in the program" \
'glyph COUNT = la n. IF(lt(n)(1))(la _. "done")(la _. COUNT(sub(n)(1)))
glyph MAIN = print(COUNT(5))'
case_ "(b) a function and a data glyph in one cycle" \
'glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph F = la n. IF(lt(n)(1))(la _. "zero")(la _. FST(TBL)(sub(n)(1)))
glyph TBL = PAIR(F)("x")
glyph MAIN = print(F(3))'
case_ "(c) the program's own Z is not a fixpoint combinator" \
'glyph Z = "not a combinator"
glyph COUNT = la n. IF(lt(n)(1))(la _. "done")(la _. COUNT(sub(n)(1)))
glyph MAIN = SEQ(print(Z))(print(COUNT(2)))'
case_ "control: mutual recursion EVEN/ODD" \
'glyph EVEN = la n. IF(lt(n)(1))(la _. "even")(la _. ODD(sub(n)(1)))
glyph ODD = la n. IF(lt(n)(1))(la _. "odd")(la _. EVEN(sub(n)(1)))
glyph MAIN = SEQ(print(EVEN(10)))(print(EVEN(7)))'
[ "$ok" = 1 ] || exit 1
