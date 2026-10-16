#!/bin/bash
# gate_audit2_native.sh — regression gates for the native_codegen3 fixes from
# LogOS_bug_audit_2.md #53 #60 (and #110's same-order claim for COLLECT).
# Each case FAILS on the unfixed tree and PASSES with its fix. Modelled on
# gate_audit2.sh's nc3() cases: compile with native_codegen3.la on the host,
# run the emitted binary. Runs in a private temp dir; needs gcc only.
# Each case is one host compile (~25 s), so the whole gate is ~1.5 min.
# The emitted binaries carry native_codegen3.la's HEAP_SIZE in p_memsz; on a box
# that cannot map it the exec itself fails (rc 139, no output) — SKIP, not PASS.
#   usage: ./gate_audit2_native.sh [case ...]     (no args = every case)
set -u
REPO=$(cd "$(dirname "$0")" && pwd)
W=$(mktemp -d "${TMPDIR:-/tmp}/gate_audit2_native.XXXXXX")
trap 'rm -rf "$W"' EXIT
cd "$W"
gcc -O2 -o tiny_host "$REPO/tiny_host.c" || { echo "FAIL  gate: cannot build tiny_host"; exit 1; }
cp "$REPO"/native_codegen3.la .
FAILS=0
pass() { echo "PASS  $*"; }
fail() { echo "FAIL  $*"; FAILS=$((FAILS+1)); }
skip() { echo "SKIP  $*"; }
nc3c() {  # nc3c <prog.la> -> compiles to ./native_codegen3_out; NRC=COMPILE on failure
    cp "$1" native_input.la; rm -f native_codegen3_out; NRC=
    timeout 900 ./tiny_host native_codegen3.la >/dev/null 2>nc3.err || { NRC=COMPILE; NERR=$(tail -c 200 nc3.err); }
}

# ── #53: \r \f \v are whitespace, as the host's isspace() has them ────────────
# CRLF line endings, a form feed and a vertical tab between top-level forms.
# Expected output is the HOST's (an independent lexer: tiny_host.c uses
# isspace()), and must be its plain result "wxyzw". The literals sit in a
# left-nested application chain with a repeat, so native == host also pins
# #110's claim that COLLECT keeps the same literals in the same order.
# Unfixed: compile rc 1 "expected glyph / import / export".
case_nc3_crlf() {
    printf 'glyph J = la a. la b. la c. la d. concat(a)(concat(b)(concat(c)(concat(d)(a))))\r\n\fglyph MAIN = print(J("w")("x")("y")("z"))\v\r\nglyph X = "w"\r\n' > t_crlf.la
    local h hrc=0; h=$(timeout 60 ./tiny_host t_crlf.la 2>/dev/null) || hrc=$?
    [ "$hrc" = 0 ] && [ "$h" = wxyzw ] || { fail "nc3_crlf: host reference broke (rc=$hrc out=[$h]) — cannot judge"; return; }
    nc3c t_crlf.la
    [ "$NRC" = COMPILE ] && { fail "nc3_crlf: native compile failed on a CRLF/\\f/\\v source — $NERR"; return; }
    local n nrc=0; n=$(timeout 30 ./native_codegen3_out 2>/dev/null) || nrc=$?
    if [ "$nrc" = 0 ] && [ "$n" = "$h" ]; then pass "nc3_crlf: CRLF + \\f + \\v source compiles natively, output == host ($h)"
    elif [ "$nrc" = 139 ] && [ -z "$n" ]; then skip "nc3_crlf: native binary cannot exec here (p_memsz > RAM+swap)"
    else fail "nc3_crlf: native rc=$nrc out=[$n] (host: $h)"; fi
}

# ── #60: the stack guard follows RLIMIT_STACK ─────────────────────────────────
# build.sh's NT(1000000) non-tail recursion must end in "native: stack overflow"
# rc 134 — never a raw SIGSEGV (rc 139) — under ulimit -s 8192 (control), 4096,
# 2048, and at 8192 with a 1.5 MiB environment (12 x 120 KiB vars; exec caps
# each string at 128 KiB). Unfixed: the guard sits at a fixed 7 MiB, so all but
# the control die rc 139 with no message.
case_nc3_stack_rlimit() {
    printf 'glyph TRUE = la t. la f. t
glyph FALSE = la t. la f. f
glyph IF = la c. la t. la f. c(t)(f)("!")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph NT = Z(la self. la n. IF(int_eq(n)(0))(la _. 0)(la _. add(1)(self(sub(n)(1)))))
glyph MAIN = print(NT(1000000))\n' > t_nt.la
    nc3c t_nt.la
    [ "$NRC" = COMPILE ] && { fail "nc3_stack_rlimit: compile — $NERR"; return; }
    local big; big=$(head -c 122880 /dev/zero | tr '\0' x)
    local envs=() i; for i in 1 2 3 4 5 6 7 8 9 10 11 12; do envs+=("BIG$i=$big"); done
    run_nt() {  # run_nt <ulimit -s KiB> [env assignments...] -> RC ERR
        local s=$1; shift
        RC=0; ERR=$( (ulimit -s "$s"; env "$@" timeout 60 ./native_codegen3_out 2>&1 >/dev/null) ) || RC=$?
    }
    run_nt 8192
    if [ "$RC" = 139 ] && [ -z "$ERR" ]; then skip "nc3_stack_rlimit: native binary cannot exec here (p_memsz > RAM+swap)"; return; fi
    [ "$RC" = 134 ] && [ "$ERR" = "native: stack overflow" ] || { fail "nc3_stack_rlimit: control ulimit -s 8192: rc=$RC err=[$ERR]"; return; }
    local bad=""
    run_nt 4096;            [ "$RC" = 134 ] && [ "$ERR" = "native: stack overflow" ] || bad="$bad 4096:rc=$RC"
    run_nt 2048;            [ "$RC" = 134 ] && [ "$ERR" = "native: stack overflow" ] || bad="$bad 2048:rc=$RC"
    run_nt 8192 "${envs[@]}"; [ "$RC" = 134 ] && [ "$ERR" = "native: stack overflow" ] || bad="$bad 8192+1.5MiB-env:rc=$RC"
    if [ -z "$bad" ]; then pass "nc3_stack_rlimit: deep recursion halts 'native: stack overflow' rc 134 at ulimit -s 8192/4096/2048 and with a 1.5 MiB env"
    else fail "nc3_stack_rlimit: raw fault instead of the guard —$bad"; fi
}

CASES="${*:-nc3_crlf nc3_stack_rlimit}"
for c in $CASES; do "case_$c"; done
[ "$FAILS" -eq 0 ] && { echo "gate_audit2_native: all passed"; exit 0; } || { echo "gate_audit2_native: $FAILS failed"; exit 1; }
