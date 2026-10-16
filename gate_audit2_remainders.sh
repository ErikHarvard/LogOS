#!/bin/bash
# gate_audit2_remainders.sh — regression gates for the REMAINING halves of the
# LogOS_bug_audit_2.md findings that earlier batches only partly fixed (#35 #59
# #102). Each case FAILS on the unfixed tree (a24a719) and PASSES with its fix;
# every expected value is derived by hand in the case's comment, not captured
# from a run. Runs in a private temp dir; needs gcc only. Not wired into
# build.sh — one line to hook it in.
#   usage: ./gate_audit2_remainders.sh [case ...]     (no args = every case)
set -u
REPO=$(cd "$(dirname "$0")" && pwd)
W=$(mktemp -d "${TMPDIR:-/tmp}/gate_audit2_rem.XXXXXX")
trap 'rm -rf "$W"' EXIT
cd "$W"
gcc -O2 -o tiny_host "$REPO/tiny_host.c" || { echo "FAIL  gate: cannot build tiny_host"; exit 1; }
cp "$REPO"/*.la .
FAILS=0
pass() { echo "PASS  $*"; }
fail() { echo "FAIL  $*"; FAILS=$((FAILS+1)); }

# ── #35 import mangling: SANITIZE once per module, one rename walk per body ───
# MANGLE_MODULE is called on a hand-built module in each of the four .la
# parsers, with SANITIZE wrapped to print "SAN" per call. Module "mod" (an
# alphanumeric path, so the expected names hold under the pre- AND post-#114
# SANITIZE rule), table [A = la x. PA(x)(B)(la PA. PA(B)) ; PA = B ; B = "s"],
# exports [A], so the privates are PA and B.
#   Expected table (by hand): PA and B renamed everywhere free; the inner
#   `la PA.` shadows PA (left alone) but NOT B (still renamed); the private KEYS
#   are mangled, the exported key is not:
#     A=(la x. __mod_mod__PA(x)(__mod_mod__B)((la PA. PA(__mod_mod__B))));
#     __mod_mod__PA=__mod_mod__B;__mod_mod__B="s";
#   Expected SANITIZE calls: 1 (once per module). Unfixed: eval/bytecode/parser
#   fold RENAME_FREE once per private (MANGLE_BODY) and call MANGLE per
#   (body, private) — 3 bodies x 2 privates + 2 private keys = 8 calls; codegen's
#   RENAME_ALL calls MANGLE per renamed variable — 4 free private refs + 2 keys = 6.
case_mangle_once() {
    local f out rc san tab
    local want='A=(la x. __mod_mod__PA(x)(__mod_mod__B)((la PA. PA(__mod_mod__B))));__mod_mod__PA=__mod_mod__B;__mod_mod__B="s";'
    for f in eval.la bytecode.la parser.la codegen.la; do
        { sed -e '/^glyph MAIN/,$d' -e 's/^glyph SANITIZE = /glyph SANITIZE0 = /' "$f"
          cat <<'LA'
glyph SANITIZE = la s. (la _. SANITIZE0(s))(print("SAN"))
glyph SHOWA = Z(la self. la n. n (la v. v) (la p. la b. concat("(la ")(concat(p)(concat(". ")(concat(self(b))(")"))))) (la g. la a. concat(self(g))(concat("(")(concat(self(a))(")")))) (la s. concat("\"")(concat(s)("\""))))
glyph SHOWT = Z(la self. la t. IF(IS_CONS(t))(la _. concat(FST(LIST_HD(t)))(concat("=")(concat(SHOWA(SND(LIST_HD(t))))(concat(";")(self(LIST_TL(t)))))))(la _. ""))
glyph T_TABLE = CONS(PAIR("A")(AST_LAM("x")(AST_APP(AST_APP(AST_APP(AST_VAR("PA"))(AST_VAR("x")))(AST_VAR("B")))(AST_LAM("PA")(AST_APP(AST_VAR("PA"))(AST_VAR("B")))))))(CONS(PAIR("PA")(AST_VAR("B")))(CONS(PAIR("B")(AST_STR("s")))(NIL)))
glyph MAIN = print(SHOWT(MANGLE_MODULE(T_TABLE)(CONS("A")(NIL))("mod")))
LA
        } > t_mangle.la
        rc=0; out=$(timeout 60 ./tiny_host t_mangle.la 2>&1) || rc=$?
        san=$(grep -cx SAN <<< "$out"); tab=$(tail -1 <<< "$out")
        if [ "$rc" = 0 ] && [ "$san" = 1 ] && [ "$tab" = "$want" ]; then
            pass "$f: MANGLE_MODULE renames in one walk, SANITIZE once per module (table unchanged)"
        else
            fail "$f: rc=$rc SANITIZE calls=$san (want 1) table=[$tab]"
        fi
    done
}

#CASES-BELOW

CASES="${*:-mangle_once}"
for c in $CASES; do "case_$c"; done
[ "$FAILS" -eq 0 ] && { echo "gate_audit2_remainders: all passed"; exit 0; } || { echo "gate_audit2_remainders: $FAILS failed"; exit 1; }
