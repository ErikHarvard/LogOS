#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
#  build.sh — bootstrap LogOS: compile the host, speak the Word, replicate.
#  Each replication writes a unique sibling  new_logos_gen{N+1}_pid{PID}.bin :
#  the gen number is true ancestral depth (parent + 1); the PID keeps siblings
#  from the same parent distinct. A host can breed even when run directly.
# ─────────────────────────────────────────────────────────────────────
set -euo pipefail
cd "$(dirname "$0")"

say() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }

# Run a host on kernel.la. Captures stdout in RUN_OUT and the replicated
# child's path (parsed from copy_self's stderr line) in RUN_CHILD.
run_host() {
    local bin="$1" err
    err="$(mktemp)"
    RUN_OUT="$("$bin" kernel.la 2>"$err")"
    RUN_ERR="$(cat "$err")"
    RUN_CHILD="$(sed -n 's/^copy_self: replicated -> //p' "$err" | tail -1)"
    rm -f "$err"
}

say "Compiling the host (tiny_host.c)"
gcc -O2 -Wall -Wextra -o tiny_host tiny_host.c
echo "compiled -> tiny_host"

say "Testing concat built-in"
cat > /tmp/test_concat.la <<'LAEOF'
glyph MAIN = print(concat("hello, ")("world"))
LAEOF
OUT="$(./tiny_host /tmp/test_concat.la 2>/dev/null)"
if [ "$OUT" = "hello, world" ]; then
    echo "PASS  concat(\"hello, \")(\"world\") = \"hello, world\""
else
    echo "FAIL  expected 'hello, world', got '$OUT'"
    exit 1
fi

say "Testing str_head built-in"
cat > /tmp/test_str_head.la <<'LAEOF'
glyph MAIN = print(str_head("hello"))
LAEOF
OUT="$(./tiny_host /tmp/test_str_head.la 2>/dev/null)"
if [ "$OUT" = "h" ]; then
    echo "PASS  str_head(\"hello\") = \"h\""
else
    echo "FAIL  expected 'h', got '$OUT'"
    exit 1
fi
cat > /tmp/test_str_head_empty.la <<'LAEOF'
glyph MAIN = print(concat("[")(concat(str_head(""))("]")))
LAEOF
OUT="$(./tiny_host /tmp/test_str_head_empty.la 2>/dev/null)"
if [ "$OUT" = "[]" ]; then
    echo "PASS  str_head(\"\") = \"\""
else
    echo "FAIL  expected '[]', got '$OUT'"
    exit 1
fi

say "Testing str_tail built-in"
cat > /tmp/test_str_tail.la <<'LAEOF'
glyph MAIN = print(str_tail("hello"))
LAEOF
OUT="$(./tiny_host /tmp/test_str_tail.la 2>/dev/null)"
if [ "$OUT" = "ello" ]; then
    echo "PASS  str_tail(\"hello\") = \"ello\""
else
    echo "FAIL  expected 'ello', got '$OUT'"
    exit 1
fi

say "Testing str_eq built-in"
cat > /tmp/test_str_eq.la <<'LAEOF'
glyph MAIN = print(str_eq("abc")("abc")("equal")("not equal"))
LAEOF
OUT="$(./tiny_host /tmp/test_str_eq.la 2>/dev/null)"
if [ "$OUT" = "equal" ]; then
    echo "PASS  str_eq(\"abc\")(\"abc\") = TRUE"
else
    echo "FAIL  expected 'equal', got '$OUT'"
    exit 1
fi
cat > /tmp/test_str_eq2.la <<'LAEOF'
glyph MAIN = print(str_eq("abc")("xyz")("equal")("not equal"))
LAEOF
OUT="$(./tiny_host /tmp/test_str_eq2.la 2>/dev/null)"
if [ "$OUT" = "not equal" ]; then
    echo "PASS  str_eq(\"abc\")(\"xyz\") = FALSE"
else
    echo "FAIL  expected 'not equal', got '$OUT'"
    exit 1
fi

say "Testing binary-safe primitives (chr / ord / write_exec)"
cat > /tmp/test_chr.la <<'LAEOF'
glyph SEQ = la a. la b. b
glyph MAIN = SEQ(print(ord(chr("65"))))(SEQ(print(chr("73")))(print(ord("A"))))
LAEOF
OUT="$(./tiny_host /tmp/test_chr.la 2>/dev/null)"
if [ "$OUT" = "$(printf '65\nI\n65')" ]; then
    echo "PASS  chr/ord round-trip (ord(chr 65)=65, chr 73='I', ord 'A'=65)"
else
    echo "FAIL  chr/ord: got '$OUT'"
    exit 1
fi
# A NUL byte must survive concat and write_file: A \0 B == 41 00 42.
cat > /tmp/test_nul.la <<'LAEOF'
glyph MAIN = write_file("/tmp/test_nul.bin")(concat(chr("65"))(concat(chr("0"))(chr("66"))))
LAEOF
./tiny_host /tmp/test_nul.la >/dev/null 2>&1
if [ "$(stat -c%s /tmp/test_nul.bin 2>/dev/null)" = "3" ] && [ "$(od -An -tx1 /tmp/test_nul.bin | tr -d ' \n')" = "410042" ]; then
    echo "PASS  embedded NUL survives concat + write_file (41 00 42)"
else
    echo "FAIL  binary string not NUL-safe: $(od -An -tx1 /tmp/test_nul.bin)"
    exit 1
fi
rm -f /tmp/test_nul.bin

say "Testing read_file built-in"
printf 'test content' > /tmp/test_rf_input.txt
cat > /tmp/test_read_file.la <<'LAEOF'
glyph MAIN = print(read_file("/tmp/test_rf_input.txt"))
LAEOF
OUT="$(./tiny_host /tmp/test_read_file.la 2>/dev/null)"
if [ "$OUT" = "test content" ]; then
    echo "PASS  read_file returned 'test content'"
else
    echo "FAIL  expected 'test content', got '$OUT'"
    exit 1
fi
rm -f /tmp/test_rf_input.txt

say "Testing write_file built-in"
rm -f /tmp/test_wf_output.txt
cat > /tmp/test_write_file.la <<'LAEOF'
glyph MAIN = print(write_file("/tmp/test_wf_output.txt")("written by LogOS"))
LAEOF
OUT="$(./tiny_host /tmp/test_write_file.la 2>/dev/null)"
WRITTEN="$(cat /tmp/test_wf_output.txt 2>/dev/null)"
ok=1
[ "$OUT" = "written by LogOS" ]     || { echo "FAIL  write_file did not return content: '$OUT'"; ok=0; }
[ "$WRITTEN" = "written by LogOS" ] || { echo "FAIL  file contents wrong: '$WRITTEN'";           ok=0; }
if [ "$ok" -eq 1 ]; then
    echo "PASS  write_file wrote and returned 'written by LogOS'"
else
    exit 1
fi
rm -f /tmp/test_wf_output.txt

say "Testing read_file + write_file round-trip"
printf 'round trip data' > /tmp/test_rt_src.txt
cat > /tmp/test_roundtrip.la <<'LAEOF'
glyph SEQ = la a. la b. b
glyph MAIN = SEQ(write_file("/tmp/test_rt_dst.txt")(read_file("/tmp/test_rt_src.txt")))(print(read_file("/tmp/test_rt_dst.txt")))
LAEOF
OUT="$(./tiny_host /tmp/test_roundtrip.la 2>/dev/null)"
if [ "$OUT" = "round trip data" ]; then
    echo "PASS  read -> write -> read round-trip"
else
    echo "FAIL  expected 'round trip data', got '$OUT'"
    exit 1
fi
rm -f /tmp/test_rt_src.txt /tmp/test_rt_dst.txt

say "Testing Z combinator (fixed-point recursion)"
cat > /tmp/test_z.la <<'LAEOF'
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph IF = la cond. la t. la f. cond(t)(f)("!")
glyph REVERSE = Z(la self. la s. IF(str_eq(s)(""))(la _. "")(la _. concat(self(str_tail(s)))(str_head(s))))
glyph MAIN = print(REVERSE("abcde"))
LAEOF
OUT="$(./tiny_host /tmp/test_z.la 2>/dev/null)"
if [ "$OUT" = "edcba" ]; then
    echo "PASS  Z combinator: REVERSE(\"abcde\") = \"edcba\""
else
    echo "FAIL  expected 'edcba', got '$OUT'"
    exit 1
fi

say "Native integers + arithmetic (built-in type, like strings)"
# Integers are Form (g_8, tau_Q): bare-digit literals, arithmetic as
# Ontodirection (add/sub/mul/div/mod), comparison returning Church booleans
# (lt/int_eq), and int<->string conversion. Recursion (factorial) confirms
# they compose with the Z combinator.
cat > /tmp/test_int.la <<'LAEOF'
glyph IF  = la c. la t. la f. c(t)(f)("!")
glyph SEQ = la a. la b. b
glyph Z   = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph FACT = Z(la self. la n. IF(int_eq(n)(0))(la _. 1)(la _. mul(n)(self(sub(n)(1)))))
glyph MAIN =
    SEQ(print(int_to_str(add(2)(3))))(
    SEQ(print(int_to_str(div(17)(5))))(
    SEQ(print(int_to_str(mod(17)(5))))(
    SEQ(print(IF(lt(3)(5))(la _. "less")(la _. "no")))(
        print(concat("fact5=")(int_to_str(FACT(5))))))))
LAEOF
OUT="$(./tiny_host /tmp/test_int.la 2>/dev/null)"
expected=$'5\n3\n2\nless\nfact5=120'
if [ "$OUT" = "$expected" ]; then
    echo "PASS  native ints: add/div/mod, lt boolean, int_to_str, and FACT(5)=120 via Z"
else
    echo "FAIL  native ints: got [$OUT]"
    exit 1
fi
rm -f /tmp/test_int.la

say "Module system (import / export with namespace isolation)"
# app.la imports stdlib.la, which `export`s MAP/FILTER/ALL/LIST_FIND and keeps
# its Church-encoding helpers private. app uses the four exports on its own
# lists, and deliberately defines IF and SECRET with the SAME NAMES as stdlib
# privates. Isolation requires two things at once:
#   • app sees its OWN SECRET ("app-value"), not stdlib's private one — the
#     module's privates are alpha-renamed at import, so they do not leak in;
#   • the imported MAP/FILTER/ALL still work even though app's IF is a broken
#     "DECOY" — they use stdlib's own private IF, not app's.
OUT="$(./tiny_host app.la 2>/dev/null)"
ok=1
printf '%s\n' "$OUT" | grep -qxF "MAP head:    aa"          || { echo "FAIL  module: MAP export";           ok=0; }
printf '%s\n' "$OUT" | grep -qxF "FILTER head: b"           || { echo "FAIL  module: FILTER export";        ok=0; }
printf '%s\n' "$OUT" | grep -qxF "ALL no-z:    T"           || { echo "FAIL  module: ALL (app's decoy IF leaked into stdlib?)"; ok=0; }
printf '%s\n' "$OUT" | grep -qxF "FIND y:      Y"           || { echo "FAIL  module: LIST_FIND export";     ok=0; }
printf '%s\n' "$OUT" | grep -qxF "SECRET:      app-value"   || { echo "FAIL  module: isolation (stdlib private SECRET leaked and shadowed app's)"; ok=0; }
if [ "$ok" -eq 1 ]; then
    echo "PASS  import(\"stdlib.la\"): MAP/FILTER/ALL/LIST_FIND imported; privates isolated (SECRET stays app's)"
else
    exit 1
fi

say "Cross-engine import (import/export resolved by EVERY engine)"
# The host test above proves import on the C host. This proves the SAME
# import/export semantics now hold on every self-hosted engine: import is
# resolved at PARSE time (pure generation), producing one flat, path-mangled
# glyph table that EVAL / RUN_BYTES / RUN_SM / the native SECD VM all consume
# unchanged — so the output is byte-identical across engines. greetapp.la
# imports greetmod.la (exports GREET, keeps SECRET private) and defines its
# OWN same-named SECRET; the single output line proves both isolation ways:
#   module-importer -> GREET used the MODULE's private SECRET (importer's didn't leak in)
#   mine:-importer  -> MAIN saw the IMPORTER's own SECRET    (module's didn't leak out)
XEXP="module-importer / mine:-importer"
ok=1
cxi () { [ "$2" = "$XEXP" ] || { echo "FAIL  cross-import $1: [$2] != [$XEXP]"; ok=0; }; }

cxi "C host"    "$(./tiny_host greetapp.la 2>/dev/null)"

# eval.la — the self-hosted meta-evaluator.
EVM="$(grep -n '^glyph MAIN' eval.la | tail -1 | cut -d: -f1)"
head -$((EVM-1)) eval.la > /tmp/xi_eval.la
printf 'glyph MAIN = RUN(PARSE_PROGRAM(read_file("greetapp.la")))\n' >> /tmp/xi_eval.la
cxi "eval.la"   "$(./tiny_host /tmp/xi_eval.la 2>/dev/null)"

# bytecode.la — RUN_BYTES (direct byte VM) and RUN_SM (SECD stack machine).
BCM="$(grep -n '^glyph MAIN' bytecode.la | tail -1 | cut -d: -f1)"
head -$((BCM-1)) bytecode.la > /tmp/xi_bc.la
printf 'glyph MAIN = (la _. print(""))(RUN_BYTES_PROGRAM(PARSE_PROGRAM(read_file("greetapp.la"))))\n' >> /tmp/xi_bc.la
cxi "RUN_BYTES" "$(./tiny_host /tmp/xi_bc.la 2>/dev/null | sed '${/^$/d;}')"
head -$((BCM-1)) bytecode.la > /tmp/xi_sm.la
printf 'glyph MAIN = (la _. print(""))(RUN_SM_PROGRAM(PARSE_PROGRAM(read_file("greetapp.la"))))\n' >> /tmp/xi_sm.la
cxi "RUN_SM"    "$(./tiny_host /tmp/xi_sm.la 2>/dev/null | sed '${/^$/d;}')"

# native SECD VM — codegen.la resolves the import at COMPILE time and lowers
# the merged table to a stream; the VM (which has no notion of import) runs it.
rm -f logos_secd logos_program.bin logos_source.la
./tiny_host secd.la >/dev/null 2>&1
cp greetapp.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
cxi "native VM" "$(./logos_secd 2>/dev/null)"
rm -f logos_secd logos_program.bin logos_source.la

if [ "$ok" -eq 1 ]; then
    echo "PASS  import/export coherent across all 5 engines (C host, eval.la, RUN_BYTES, RUN_SM, native VM)"
else
    exit 1
fi
rm -f /tmp/xi_eval.la /tmp/xi_bc.la /tmp/xi_sm.la

# ── Export-of-undefined is rejected loudly at parse time on EVERY engine ──
# A module declaring `export FOO` with no `glyph FOO` must be rejected, not
# silently accepted (a typo that would otherwise surface as a runtime unbound
# variable, or not at all). The C host checks this; CHECK_EXPORTS (folded into
# MANGLE_MODULE) gives the four self-hosted parsers the same parse-time guard, so
# b_τ ≡ f_τ: all five engines reject identically.
cat > /tmp/f3mod.la <<'LAEOF'
export GREET PHANTOM
glyph GREET = la x. x
LAEOF
cat > /tmp/f3imp.la <<'LAEOF'
import("/tmp/f3mod.la")
glyph MAIN = print(GREET("ok"))
LAEOF
f3ok=1
f3check() {  # $1 = engine label, $2 = combined output, $3 = rc
    if [ "$3" -ne 0 ] && printf '%s\n' "$2" | grep -qiE "exports.*does not define|module exports undefined glyph"; then :; else
        echo "FAIL  bad-export ($1): rc=$3 msg='$2' (want non-zero + export-undefined diagnostic)"; f3ok=0; fi
}
rc=0; M="$(./tiny_host /tmp/f3imp.la 2>&1)" || rc=$?; f3check "C host" "$M" "$rc"
EVM="$(grep -n '^glyph MAIN' eval.la | tail -1 | cut -d: -f1)"; head -$((EVM-1)) eval.la > /tmp/f3_eval.la
printf 'glyph MAIN = RUN(PARSE_PROGRAM(read_file("/tmp/f3imp.la")))\n' >> /tmp/f3_eval.la
rc=0; M="$(./tiny_host /tmp/f3_eval.la 2>&1)" || rc=$?; f3check "eval.la" "$M" "$rc"
BCM="$(grep -n '^glyph MAIN' bytecode.la | tail -1 | cut -d: -f1)"; head -$((BCM-1)) bytecode.la > /tmp/f3_bc.la
printf 'glyph MAIN = (la _. print(""))(RUN_BYTES_PROGRAM(PARSE_PROGRAM(read_file("/tmp/f3imp.la"))))\n' >> /tmp/f3_bc.la
rc=0; M="$(./tiny_host /tmp/f3_bc.la 2>&1)" || rc=$?; f3check "RUN_BYTES" "$M" "$rc"
head -$((BCM-1)) bytecode.la > /tmp/f3_sm.la
printf 'glyph MAIN = (la _. print(""))(RUN_SM_PROGRAM(PARSE_PROGRAM(read_file("/tmp/f3imp.la"))))\n' >> /tmp/f3_sm.la
rc=0; M="$(./tiny_host /tmp/f3_sm.la 2>&1)" || rc=$?; f3check "RUN_SM" "$M" "$rc"
cp /tmp/f3imp.la logos_source.la; rm -f logos_program.bin
rc=0; M="$(./tiny_host codegen.la 2>&1)" || rc=$?; f3check "codegen→VM" "$M" "$rc"
rm -f /tmp/f3mod.la /tmp/f3imp.la /tmp/f3_eval.la /tmp/f3_bc.la /tmp/f3_sm.la logos_source.la logos_program.bin
if [ "$f3ok" -eq 1 ]; then
    echo "PASS  export of an undefined glyph rejected loudly at parse time on all 5 engines"
else
    exit 1
fi

say "str_len builtin coherent across all engines"
# str_len(s) -> decimal byte length. Strings are length-carrying, so it is O(1)
# on every engine; the bundler (below) needs it to patch the ELF p_filesz. Like
# the integer builtins, every engine must agree on the same program. "Lingua
# Adamica" is 14 bytes (exercises the multi-digit decimal path).
echo 'glyph MAIN = print(str_len("Lingua Adamica"))' > /tmp/sl.la
ok=1
sl () { [ "$2" = "14" ] || { echo "FAIL  str_len $1: [$2] != 14"; ok=0; }; }
sl "C host"    "$(./tiny_host /tmp/sl.la 2>/dev/null)"
EVM="$(grep -n '^glyph MAIN' eval.la | tail -1 | cut -d: -f1)"
head -$((EVM-1)) eval.la > /tmp/sl_eval.la
printf 'glyph MAIN = RUN(PARSE_PROGRAM(read_file("/tmp/sl.la")))\n' >> /tmp/sl_eval.la
sl "eval.la"   "$(./tiny_host /tmp/sl_eval.la 2>/dev/null)"
BCM="$(grep -n '^glyph MAIN' bytecode.la | tail -1 | cut -d: -f1)"
head -$((BCM-1)) bytecode.la > /tmp/sl_bc.la
printf 'glyph MAIN = (la _. print(""))(RUN_BYTES_PROGRAM(PARSE_PROGRAM(read_file("/tmp/sl.la"))))\n' >> /tmp/sl_bc.la
sl "RUN_BYTES" "$(./tiny_host /tmp/sl_bc.la 2>/dev/null | sed '${/^$/d;}')"
head -$((BCM-1)) bytecode.la > /tmp/sl_sm.la
printf 'glyph MAIN = (la _. print(""))(RUN_SM_PROGRAM(PARSE_PROGRAM(read_file("/tmp/sl.la"))))\n' >> /tmp/sl_sm.la
sl "RUN_SM"    "$(./tiny_host /tmp/sl_sm.la 2>/dev/null | sed '${/^$/d;}')"
rm -f logos_secd logos_program.bin logos_source.la
./tiny_host secd.la >/dev/null 2>&1
cp /tmp/sl.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
sl "native VM" "$(./logos_secd 2>/dev/null)"
rm -f logos_secd logos_program.bin logos_source.la /tmp/sl.la /tmp/sl_eval.la /tmp/sl_bc.la /tmp/sl_sm.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  str_len = 14 on all 5 engines (C host, eval.la, RUN_BYTES, RUN_SM, native VM)"
else
    exit 1
fi

say "LogosIPC: typed message layer (import + decode)"
# The transport is now pipe-based (SEND/RECV use the VM-only pipe/read/write
# syscalls — the live channel runs on the native VM, see the LogosInit section).
# This host demo exercises the engine-independent part: ipc_demo.la imports the
# module and decodes a wire message (TYPE <NUL> BODY) with MSG_TYPE/MSG_BODY,
# then MSG_OK-dispatches on the type.
OUT="$(./tiny_host ipc_demo.la 2>/dev/null)"
ok=1
printf '%s\n' "$OUT" | grep -qxF "type:     greeting"   || { echo "FAIL  ipc: MSG_TYPE";        ok=0; }
printf '%s\n' "$OUT" | grep -qxF "body:     hello, bus" || { echo "FAIL  ipc: MSG_BODY";        ok=0; }
printf '%s\n' "$OUT" | grep -qxF "typed-ok: yes"        || { echo "FAIL  ipc: MSG_OK dispatch"; ok=0; }
if [ "$ok" -eq 1 ]; then
    echo "PASS  import(\"logosipc.la\"): MSG_TYPE/MSG_BODY/MSG_OK decode a typed message"
else
    exit 1
fi

say "Self-verifying LogOS (metadebug.la — META_DEBUG_SPEC phases 1-4)"
# One run of metadebug.la emits a labelled line per check; the spec table,
# DEBUG, and META_DEBUG share one glyph table so the debugger sees every
# glyph it verifies. Debug(Debug) = Debug.
OUT="$(./tiny_host metadebug.la 2>/dev/null)"
ok=1
check_line () {   # $1 = exact expected line
    printf '%s\n' "$OUT" | grep -qxF "$1" || { echo "FAIL  metadebug: missing '$1'"; ok=0; }
}
# Phase 1 — standard library
check_line "MAP: aabbcc"
check_line "FILTER: b"
check_line "ALL: T"
check_line "ANY_b: T"
check_line "ANY_z: F"
check_line "LENGTH: |||"
check_line "FIND: Y"
# Phase 2 — spec table (GET_SPEC resolves a hit and reports a miss)
check_line "SPEC_ID: F"
check_line "SPEC_MISSING: T"
# Phase 3 — DEBUG (good glyph passes, broken glyph caught, every specced glyph autological)
check_line "DEBUG_GOOD: PASS"
check_line "DEBUG_BAD: FAIL"
check_line "ALL_SPECCED: T"
# Phase 4 — META_DEBUG (the debugger debugging itself; a broken debug glyph is caught)
check_line "META_DEBUG: T"
check_line "META_CATCH: FAIL"
# Native integers survive self-application: add/mul/lt/int_to_str are specced
# and included in GLYPH_REGISTRY, so ALL_SPECCED: T above already proves they
# are autological. ARITH demonstrates a live computation.
check_line "ARITH: 42"
# Type System T1: types as predicates. HAS_TYPE(A)(x) = A(x); a type is a
# predicate (its spec). The predicates IS_INT/IS_STR/IS_FUN/HAS_TYPE are in
# GLYPH_REGISTRY, so ALL_SPECCED: T also certifies they are autological.
check_line "T1_int_pos: T"
check_line "T1_int_neg: F"
check_line "T1_str: T"
check_line "T1_fun: T"
# Type System T2: the five type constructors = the five modes of combination
# (PROD ⊗, SUM ⊕, ARROW ▷, REFINE ⊂, REC ↻). Each is in GLYPH_REGISTRY with
# accept+reject specs, so ALL_SPECCED: T certifies they are autological too.
check_line "T2_prod: T"
check_line "T2_sum: T"
check_line "T2_arrow: T"
check_line "T2_refine: T"
check_line "T2_rec: T"
# Type System T3: dependent types indexed by native integers. FIN n / VEC n A
# / a sampled Pi-type; all in GLYPH_REGISTRY (ALL_SPECCED: T certifies them).
check_line "T3_fin_in: T"
check_line "T3_fin_out: F"
check_line "T3_vec_ok: T"
check_line "T3_vec_bad: F"
check_line "T3_pi: T"
# Type System T4: TYPECHECK = the autological check (type-checking IS verifying
# b_τ ≡ f_τ). It type-checks itself: TYPECHECK(IS_FUN)(TYPECHECK) = well-typed.
check_line "T4_ok: well-typed"
check_line "T4_bad: type error"
check_line "T4_self: well-typed"
# Type System T5: the type-of-types. IS_TYPE(A) holds iff A is a type; the
# closure IS_TYPE(IS_TYPE) = T is C(C)=C for the type system (analogue of
# META_DEBUG), on the well-founded fragment.
check_line "T5_int: T"
check_line "T5_self: T"
if [ "$ok" -eq 1 ]; then
    echo "PASS  Phase 1: MAP/FILTER/ALL/ANY/LIST_FIND/LENGTH over Church lists"
    echo "PASS  Phase 2: SPEC_TABLE / GET_SPEC resolve specs (hit + miss)"
    echo "PASS  Phase 3: DEBUG passes good glyphs, catches broken ones; all specced glyphs autological"
    echo "PASS  Phase 4: META_DEBUG verifies the debugger itself; broken VERIFY_ONE caught"
    echo "PASS  Native integers are autological: add/mul/lt/int_to_str pass their specs under DEBUG"
    echo "PASS  Type System T1: HAS_TYPE accepts inhabitants, rejects non-inhabitants (types as predicates)"
    echo "PASS  Type System T2: PROD/SUM/ARROW/REFINE/REC build correct types (the five modes); all autological"
    echo "PASS  Type System T3: dependent types FIN n / VEC n A / Pi-type check against integer indices; all autological"
    echo "PASS  Type System T4: TYPECHECK is the autological check and type-checks itself (well-typed)"
    echo "PASS  Type System T5: IS_TYPE is the type-of-types; IS_TYPE(IS_TYPE)=T closes C(C)=C (well-founded fragment)"
else
    printf '%s\n' "$OUT"
    exit 1
fi

say "Spec → implementation pipeline (specpipe.la: GENERATE / META_DEBUG / DEPLOY)"
# specpipe.la holds a SPEC — a list of (name, definition, test-cases) triples —
# GENERATEs .la source from it, DEPLOYs it (write_file + re-read + verify), and
# runs META_DEBUG (each glyph's test cases) on every generated glyph. We check
# the in-process verification AND independently run the written module on the
# host: spec → a written, verified, working module in one call.
rm -f math_generated.la
PIPE="$(./tiny_host specpipe.la 2>/dev/null)"
ok=1
printf '%s\n' "$PIPE" | grep -qx "  ADD: PASS"      || { echo "FAIL  pipeline: ADD not verified"; ok=0; }
printf '%s\n' "$PIPE" | grep -qx "  SUBTRACT: PASS" || { echo "FAIL  pipeline: SUBTRACT not verified"; ok=0; }
printf '%s\n' "$PIPE" | grep -qx "  MULTIPLY: PASS" || { echo "FAIL  pipeline: MULTIPLY not verified"; ok=0; }
printf '%s\n' "$PIPE" | grep -q "on-disk file == generated source: T" || { echo "FAIL  pipeline: written file != generated source"; ok=0; }
printf '%s\n' "$PIPE" | grep -q "module VERIFIED"   || { echo "FAIL  pipeline: module not verified"; ok=0; }
[ -f math_generated.la ] || { echo "FAIL  pipeline: math_generated.la was not written"; ok=0; }
# Independently run the GENERATED module on the host (it is real .la source):
# ADD(MULTIPLY(6)(7))(SUBTRACT(10)(8)) = 42 + 2 = 44.
cp math_generated.la /tmp/mathmod.la 2>/dev/null
printf 'glyph MAIN = print(int_to_str(ADD(MULTIPLY(6)(7))(SUBTRACT(10)(8))))\n' >> /tmp/mathmod.la
GENOUT="$(./tiny_host /tmp/mathmod.la 2>/dev/null)"
[ "$GENOUT" = "44" ] || { echo "FAIL  pipeline: generated module ran wrong ($GENOUT != 44)"; ok=0; }
rm -f /tmp/mathmod.la math_generated.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  pipeline: GENERATE emits .la source from a SPEC"
    echo "PASS  pipeline: DEPLOY writes the module + META_DEBUG verifies every generated glyph (ADD/SUBTRACT/MULTIPLY PASS)"
    echo "PASS  pipeline: the generated module runs on the host (ADD(MUL(6)(7))(SUB(10)(8)) = 44)"
else
    printf '%s\n' "$PIPE"
    exit 1
fi

say "Spec pipeline: a string-utilities module via import(\"specpipe.la\")"
# strutil_spec.la imports the pipeline and writes a SPEC for STARTS_WITH /
# ENDS_WITH / CONTAINS / SPLIT / JOIN / REPLACE (type signatures + test cases),
# plus the support glyphs they need. GENERATE + DEPLOY produce and verify a
# self-contained module; then we run that module stand-alone on the host.
rm -f strutil_generated.la
SU="$(./tiny_host strutil_spec.la 2>/dev/null)"
ok=1
for G in STARTS_WITH ENDS_WITH CONTAINS SPLIT JOIN REPLACE; do
    printf '%s\n' "$SU" | grep -qx "  $G: PASS" || { echo "FAIL  strutil: $G not verified"; ok=0; }
done
printf '%s\n' "$SU" | grep -q "module VERIFIED" || { echo "FAIL  strutil: module not verified"; ok=0; }
[ -f strutil_generated.la ] || { echo "FAIL  strutil: strutil_generated.la was not written"; ok=0; }
# Run the GENERATED module stand-alone (it is self-contained .la); exercise each
# utility. STARTS_WITH/ENDS_WITH/CONTAINS -> TTT; REPLACE(a->X)(banana)=bXnXnX;
# JOIN(/)(SPLIT(.)(a.b.c))=a/b/c  =>  TTTbXnXnXa/b/c
cp strutil_generated.la /tmp/sumod.la 2>/dev/null
cat >> /tmp/sumod.la <<'LA'
glyph SEQ = la a. la b. b
glyph BOOL_STR = la b. b(la _. "T")(la _. "F")("!")
glyph MAIN = print(concat(BOOL_STR(STARTS_WITH("ab")("abc")))(concat(BOOL_STR(ENDS_WITH("c")("abc")))(concat(BOOL_STR(CONTAINS("b")("abc")))(concat(REPLACE("a")("X")("banana"))(JOIN("/")(SPLIT(".")("a.b.c")))))))
LA
SUOUT="$(./tiny_host /tmp/sumod.la 2>/dev/null)"
[ "$SUOUT" = "TTTbXnXnXa/b/c" ] || { echo "FAIL  strutil: generated module ran wrong ($SUOUT)"; ok=0; }
rm -f /tmp/sumod.la strutil_generated.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  strutil: import(\"specpipe.la\") + SPEC GENERATEs/DEPLOYs the string module"
    echo "PASS  strutil: META_DEBUG verifies STARTS_WITH/ENDS_WITH/CONTAINS/SPLIT/JOIN/REPLACE"
    echo "PASS  strutil: the generated string module runs stand-alone on the host"
else
    printf '%s\n' "$SU"
    exit 1
fi

say "Testing self-hosted parser (parser.la parses kernel.la)"
OUT="$(./tiny_host parser.la 2>/dev/null)"
if printf '%s\n' "$OUT" | grep -qF "Kernel parse: IIIIIIIII glyph(s)"; then
    echo "PASS  parser.la parsed kernel.la (9 glyphs)"
else
    echo "FAIL  parser did not produce expected output"
    printf '%s\n' "$OUT"
    exit 1
fi
if printf '%s\n' "$OUT" | grep -qF "glyph ∃ = LAM[self, VAR[self]]"; then
    echo "PASS  parser correctly parsed ∃ (existence glyph)"
else
    echo "FAIL  ∃ glyph not correctly parsed"
    exit 1
fi

say "Testing byte instructions + stack machine (bytecode.la)"
# bytecode.la is a third representation of a program: a flat byte-
# instruction stream. EMIT compiles an AST to byte instructions,
# PARSE_BYTES decodes them back, RUN_BYTES executes them directly (no AST
# rebuilt), and RUN_SM is a real stack machine (S/E/C/D) over a compiled
# instruction list. Both engines run the kernel straight to replication.
rm -f new_logos_gen*.bin
ERR_B="$(mktemp)"
OUT="$(./tiny_host bytecode.la 2>"$ERR_B")"
BYTE_CHILD="$(sed -n 's/^copy_self: replicated -> //p' "$ERR_B" | tail -1)"
rm -f "$ERR_B"
ok=1
# The hand-built AST  la x. f(x)("a;b\c")  must emit this exact stream.
# (The string payload exercises field escaping: ';' -> '\;', '\' -> '\\'.)
printf '%s\n' "$OUT" | grep -qxF 'Lx;AAVf;Vx;Sa\;b\\c;'      || { echo "FAIL  byte-instr: unexpected encoding"; ok=0; }
printf '%s\n' "$OUT" | grep -qxF 'la x. f(x)("a;b\\c")'      || { echo "FAIL  byte-instr: decode+unparse mismatch"; ok=0; }
printf '%s\n' "$OUT" | grep -qxF "bytes round-trip: stable"  || { echo "FAIL  byte-instr: expression round trip"; ok=0; }
printf '%s\n' "$OUT" | grep -qxF "kernel round-trip: stable" || { echo "FAIL  byte-instr: kernel.la round trip"; ok=0; }
# RUN_BYTES executes byte instructions directly.
printf '%s\n' "$OUT" | grep -qxF "byte vm"                   || { echo "FAIL  byte-vm: literal byte stream did not execute"; ok=0; }
printf '%s\n' "$OUT" | grep -qxF "yes kept"                  || { echo "FAIL  byte-vm: closures/booleans/lookup"; ok=0; }
printf '%s\n' "$OUT" | grep -qxF "I AM THAT I AM"            || { echo "FAIL  byte-vm: kernel did not speak from bytes"; ok=0; }
# The stack machine (S/E/C/D) executes the compiled program and the kernel.
printf '%s\n' "$OUT" | grep -qxF "TF"                              || { echo "FAIL  stack-machine: precompiled SM_TRUE/SM_FALSE booleans"; ok=0; }
printf '%s\n' "$OUT" | grep -qxF "kernel ran on the stack machine" || { echo "FAIL  stack-machine: kernel did not run"; ok=0; }
# Both engines replicated; the last child (from the stack machine) must match.
case "$BYTE_CHILD" in new_logos_gen1_pid*.bin) : ;; *) echo "FAIL  byte-vm: kernel did not replicate ('$BYTE_CHILD')"; ok=0 ;; esac
[ -n "$BYTE_CHILD" ] && [ -f "$BYTE_CHILD" ] && cmp -s tiny_host "$BYTE_CHILD" \
    || { echo "FAIL  byte-vm: replicant not byte-identical"; ok=0; }
# Native integers on BOTH byte engines (RUN_BYTES and RUN_SM): they lex digits,
# desugar n -> str_to_int("n"), and dispatch the int builtins. Must match the C
# host — this closes the last cross-engine integer gap (all five engines agree).
printf 'glyph SEQ = la a. la b. b\nglyph IF = la c. la t. la f. c(t)(f)("!")\nglyph MAIN = SEQ(print(int_to_str(add(mul(6)(7))(sub(10)(8)))))(SEQ(print(int_to_str(div(17)(5))))(print(IF(lt(3)(5))(la _. "yes")(la _. "no"))))\n' > /tmp/bcint.la
BCM=$(grep -n '^glyph MAIN' bytecode.la | tail -1 | cut -d: -f1)
head -$((BCM-1)) bytecode.la > /tmp/bc_rb.la
printf 'glyph MAIN = RUN_BYTES_PROGRAM(PARSE_PROGRAM(read_file("/tmp/bcint.la")))\n' >> /tmp/bc_rb.la
head -$((BCM-1)) bytecode.la > /tmp/bc_sm.la
printf 'glyph MAIN = RUN_SM_PROGRAM(PARSE_PROGRAM(read_file("/tmp/bcint.la")))\n' >> /tmp/bc_sm.la
EXPECT_INT="$(printf '44\n3\nyes')"
[ "$(./tiny_host /tmp/bc_rb.la 2>/dev/null)" = "$EXPECT_INT" ] || { echo "FAIL  RUN_BYTES integers"; ok=0; }
[ "$(./tiny_host /tmp/bc_sm.la 2>/dev/null)" = "$EXPECT_INT" ] || { echo "FAIL  RUN_SM integers"; ok=0; }
rm -f /tmp/bcint.la /tmp/bc_rb.la /tmp/bc_sm.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  EMIT/PARSE_BYTES round-trip an AST through byte instructions"
    echo "PASS  every glyph of kernel.la survives AST -> bytes -> AST"
    echo "PASS  RUN_BYTES executes byte instructions directly (no AST rebuilt)"
    echo "PASS  the stack machine (S/E/C/D) runs the compiled program and kernel"
    echo "PASS  the kernel ran from bytes and on the stack machine: spoke and bred $BYTE_CHILD"
    echo "PASS  RUN_BYTES and RUN_SM execute integers, matching the C host (all five engines agree)"
else
    printf '%s\n' "$OUT"
    exit 1
fi
rm -f new_logos_gen*.bin

say "Emitting native x86-64 code (Albedo Stage 1 — elf.la)"
# elf.la assembles a minimal static ELF64 from Lingua Adamica (chr + concat
# + write_exec) and emits a runnable native binary. The host plays no part in
# running it: the OS loads it and it makes its own write/exit syscalls.
rm -f logos_native
./tiny_host elf.la >/dev/null 2>&1
ok=1
[ -f logos_native ]                              || { echo "FAIL  native: logos_native not emitted"; ok=0; }
[ "$(stat -c%s logos_native 2>/dev/null)" = "171" ] || { echo "FAIL  native: wrong size ($(stat -c%s logos_native 2>/dev/null) != 171)"; ok=0; }
NATIVE_OUT="$(./logos_native 2>/dev/null)"; NATIVE_RC=$?
[ "$NATIVE_OUT" = "I AM THAT I AM" ]             || { echo "FAIL  native: emitted binary said '$NATIVE_OUT'"; ok=0; }
[ "$NATIVE_RC" = "0" ]                           || { echo "FAIL  native: emitted binary exited $NATIVE_RC"; ok=0; }
if [ "$ok" -eq 1 ]; then
    echo "PASS  elf.la emitted a 171-byte native ELF executable"
    echo "PASS  the emitted binary ran on the bare OS and spoke: I AM THAT I AM"
else
    exit 1
fi
rm -f logos_native

say "Native codegen: compile to SECD streams, diff against RUN_SM (Albedo Stage 2)"
# secd.la emits the native SECD VM once; codegen.la compiles a source program
# (logos_source.la) to a native instruction stream (logos_program.bin); the VM
# runs it. For kernel.la and two other programs we check the native stdout
# equals the .la stack machine RUN_SM on the same program — generation lowered
# to native, recognition unchanged.
rm -f logos_secd logos_program.bin logos_source.la new_logos_secd.bin new_logos_gen*.bin
./tiny_host secd.la >/dev/null 2>&1
ok=1
[ -f logos_secd ]                                  || { echo "FAIL  codegen: VM not emitted"; ok=0; }
[ "$(stat -c%s logos_secd 2>/dev/null)" = "9504" ] || { echo "FAIL  codegen: VM wrong size ($(stat -c%s logos_secd 2>/dev/null) != 9504)"; ok=0; }
# Drift guard: the VM bytes must match their documented source.
if command -v nasm >/dev/null 2>&1; then
    nasm -f bin secd.asm -o /tmp/secd_ref 2>/dev/null
    cmp -s logos_secd /tmp/secd_ref || { echo "FAIL  codegen: VM bytes differ from nasm -f bin secd.asm"; ok=0; }
    rm -f /tmp/secd_ref
fi
# RUN_SM harness: bytecode.la's machinery, running logos_source.la and
# discarding the result so only the program's own output shows.
RUNSM_MAIN="$(grep -n '^glyph MAIN' bytecode.la | tail -1 | cut -d: -f1)"
head -$((RUNSM_MAIN-1)) bytecode.la > /tmp/runsm.la
printf 'glyph MAIN = (la _. print(""))(RUN_SM_PROGRAM(PARSE_PROGRAM(read_file("logos_source.la"))))\n' >> /tmp/runsm.la
diff_native_runsm () {   # $1 = label
    ./tiny_host codegen.la >/dev/null 2>&1
    local native runsm
    native="$(./logos_secd 2>/dev/null)"
    runsm="$(./tiny_host /tmp/runsm.la 2>/dev/null | sed '${/^$/d;}')"
    if [ "$native" = "$runsm" ]; then
        echo "PASS  native == RUN_SM — $1"
    else
        echo "FAIL  $1: native [$native] != RUN_SM [$runsm]"; ok=0
    fi
}
printf 'glyph MAIN = print(concat("Hello, ")("native world"))\n' > logos_source.la
diff_native_runsm "concat + print"
printf 'glyph MAIN = print(concat(str_head("ABC"))(str_tail("XYZ")))\n' > logos_source.la
diff_native_runsm "str_head / str_tail / concat -> AYZ"
cp kernel.la logos_source.la
diff_native_runsm "kernel.la (glyph table, read_file, copy_self, closures)"
# Native integers on the VM (tag-4 INT; str_to_int/int_to_str/add/sub/mul/div/
# mod/lt/int_eq). RUN_SM has no integers, so compare the VM directly to the C
# host — the cross-engine coherence check for arithmetic.
printf 'glyph SEQ = la a. la b. b\nglyph IF = la c. la t. la f. c(t)(f)("!")\nglyph MAIN = SEQ(print(int_to_str(add(mul(6)(7))(sub(10)(8)))))(SEQ(print(int_to_str(div(17)(5))))(print(IF(lt(3)(5))(la _. "yes")(la _. "no"))))\n' > logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
NAT_INT="$(./logos_secd 2>/dev/null)"
HOST_INT="$(./tiny_host logos_source.la 2>/dev/null)"
[ "$NAT_INT" = "$HOST_INT" ] && [ "$NAT_INT" = "$(printf '44\n3\nyes')" ] \
    || { echo "FAIL  native ints: VM [$NAT_INT] != host [$HOST_INT]"; ok=0; }
if [ "$ok" -eq 1 ]; then
    echo "PASS  codegen.la lowers arbitrary programs to native SECD streams"
    echo "PASS  the native VM ran kernel.la and matched the interpreter (and replicated itself)"
    echo "PASS  the native VM executes integers and matches the C host (44 / 3 / yes)"
    command -v nasm >/dev/null 2>&1 && echo "PASS  VM bytes are byte-identical to nasm -f bin secd.asm"
else
    exit 1
fi

say "The compiler and VM regenerate themselves — no C host in the loop (Albedo Stage 4)"
# Seed the VM and the compiler with the C host ONCE (the bootstrap seed). Then,
# using only those two native artifacts, regenerate BOTH and run a program —
# with no further tiny_host:
#   compiler.bin --(native)--> compiles codegen.la --> compiler.bin (identical)
#   compiler.bin --(native)--> compiles secd.la --> stream --> VM emits VM (identical)
#   regenerated VM runs kernel.la --> speaks the Word
rm -f logos_secd logos_program.bin logos_source.la compiler.bin vm_seed runner vm2 new_logos_secd.bin
./tiny_host secd.la >/dev/null 2>&1                       # seed: emit the VM
cp logos_secd vm_seed
cp codegen.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1                    # seed: compile the compiler
cp logos_program.bin compiler.bin
ok=1
cp vm_seed runner; chmod +x runner                        # a differently-named VM to run with
# (1) compiler reproduces itself
cp codegen.la logos_source.la; cp compiler.bin logos_program.bin
./runner >/dev/null 2>&1
cmp -s logos_program.bin compiler.bin \
    || { echo "FAIL  Stage4: native self-compilation of codegen.la differs from the seed"; ok=0; }
# (2) VM reproduces itself: native-compile secd.la, then run it to emit the VM
cp secd.la logos_source.la; cp compiler.bin logos_program.bin
./runner >/dev/null 2>&1                                  # logos_program.bin := secd.la stream
rm -f logos_secd
./runner >/dev/null 2>&1                                  # run secd.la stream -> emit logos_secd
{ [ -f logos_secd ] && cmp -s logos_secd vm_seed; } \
    || { echo "FAIL  Stage4: native-regenerated VM differs from the seed"; ok=0; }
# (3) the regenerated VM runs kernel.la
cp logos_secd vm2; chmod +x vm2
cp kernel.la logos_source.la; cp compiler.bin logos_program.bin
./vm2 >/dev/null 2>&1                                      # native-compile kernel.la
KOUT="$(./vm2 2>/dev/null)"
printf '%s\n' "$KOUT" | grep -qx "I AM THAT I AM" \
    || { echo "FAIL  Stage4: regenerated VM did not run kernel.la (got '$KOUT')"; ok=0; }
if [ "$ok" -eq 1 ]; then
    echo "PASS  compiler.bin natively recompiles codegen.la to itself"
    echo "PASS  compiler.bin natively recompiles secd.la; the VM re-emits itself byte-for-byte"
    echo "PASS  the regenerated VM runs kernel.la and speaks the Word — no C host in the loop  (∃(∃) ≡ ∃)"
else
    exit 1
fi
rm -f compiler.bin vm_seed runner vm2

rm -f logos_secd logos_program.bin logos_source.la new_logos_secd.bin new_logos_gen*.bin /tmp/runsm.la

say "Self-contained per-program ELF: bundle VM + stream into ONE binary (Albedo Stage 5)"
# bundle.la appends a compiled program stream to the VM image and patches the
# ELF p_filesz (offset 96) so the kernel maps it; the VM's _start detects the
# embedded stream (nonzero first byte at progembed) and runs it with no external
# file. The result is a single executable that needs no host and no .bin stream.
rm -f logos_secd logos_program.bin logos_embed.bin logos_source.la logos_app \
      logos_kernel_app new_logos_secd.bin compiler.bin runner
./tiny_host secd.la >/dev/null 2>&1            # emit the VM
ok=1
printf 'glyph MAIN = print(concat("bundled and ")("standalone"))\n' > /tmp/b_simple.la

# Host-side bundler: compile $1, hand its stream to bundle.la -> logos_app, and
# delete every external input so the run below can only succeed if the program
# is genuinely embedded in the single file.
host_bundle () {
    cp "$1" logos_source.la
    ./tiny_host codegen.la >/dev/null 2>&1
    cp logos_program.bin logos_embed.bin
    ./tiny_host bundle.la  >/dev/null 2>&1
    rm -f logos_program.bin logos_embed.bin logos_source.la
}

# (1) a simple program runs standalone on the bare OS
host_bundle /tmp/b_simple.la
SOUT="$(./logos_app 2>/dev/null)"
[ "$SOUT" = "bundled and standalone" ] || { echo "FAIL  bundle: simple standalone [$SOUT]"; ok=0; }
rm -f logos_app

# (2) greetapp.la — cross-engine import, now from ONE bundled file
host_bundle greetapp.la
GOUT="$(./logos_app 2>/dev/null)"
[ "$GOUT" = "module-importer / mine:-importer" ] || { echo "FAIL  bundle: import standalone [$GOUT]"; ok=0; }
rm -f logos_app

# (3) kernel.la — the bundle speaks the Word AND self-replicates; copy_self
#     replicates /proc/self/exe = the whole bundle, so the replicant is
#     byte-identical: a self-contained, self-replicating native binary.
host_bundle kernel.la
mv logos_app logos_kernel_app; rm -f new_logos_secd.bin
KOUT="$(./logos_kernel_app 2>/dev/null)"
printf '%s\n' "$KOUT" | grep -qx "I AM THAT I AM" || { echo "FAIL  bundle: kernel Word [$KOUT]"; ok=0; }
{ [ -f new_logos_secd.bin ] && cmp -s logos_kernel_app new_logos_secd.bin; } \
    || { echo "FAIL  bundle: kernel replicant not byte-identical to the bundle"; ok=0; }
rm -f logos_kernel_app new_logos_secd.bin

# (4) cross-check: the bundled output equals the VM + external-stream path
cp /tmp/b_simple.la logos_source.la; ./tiny_host codegen.la >/dev/null 2>&1
VS="$(./logos_secd 2>/dev/null)"
[ "$VS" = "bundled and standalone" ] || { echo "FAIL  bundle: VM+stream cross-check [$VS]"; ok=0; }
rm -f logos_program.bin logos_source.la

if [ "$ok" -eq 1 ]; then
    echo "PASS  bundle.la (host): kernel.la is ONE self-contained ELF that speaks + self-replicates byte-identically; greetapp.la imports cross-engine from a single file"
else
    exit 1
fi

# Stage B — the bundler itself runs ON THE VM (no tiny_host in the bundling).
# Seed the VM and the native compiler once (the irreducible bootstrap seed),
# then: native-compile a target program, native-compile bundle.la, and RUN
# bundle.la on the VM to splice the two into a self-contained binary.
rm -f logos_secd logos_program.bin logos_embed.bin logos_source.la logos_app compiler.bin runner
./tiny_host secd.la >/dev/null 2>&1            # seed: the VM
cp logos_secd runner; chmod +x runner
cp codegen.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1          # seed: the compiler
cp logos_program.bin compiler.bin
ok=1
# native-compile the target program -> its stream -> logos_embed.bin
printf 'glyph MAIN = print(concat("native ")("bundler"))\n' > logos_source.la
cp compiler.bin logos_program.bin
./runner >/dev/null 2>&1
cp logos_program.bin logos_embed.bin
# native-compile bundle.la, then run it on the VM to perform the bundling
cp bundle.la logos_source.la; cp compiler.bin logos_program.bin
./runner >/dev/null 2>&1                         # logos_program.bin := bundle.la stream
./runner >/dev/null 2>&1                          # RUN bundle.la on the VM -> logos_app
rm -f logos_program.bin logos_embed.bin logos_source.la
NOUT="$(./logos_app 2>/dev/null)"
[ "$NOUT" = "native bundler" ] || { echo "FAIL  Stage5(native): bundled output [$NOUT]"; ok=0; }
rm -f logos_secd logos_app compiler.bin runner /tmp/b_simple.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  bundle.la on the VM: a self-contained binary produced with no C host in the bundling  (∃(∃) ≡ ∃)"
else
    exit 1
fi

say "Theourgia: the compositor's software surface core (Stage 1)"
# theourgia.la builds SURFACES and COMPOSES them (z-ordered blits) entirely in
# Lingua Adamica, then serialises the final buffer to a PPM (P6) raster — the
# byte array a framebuffer wants, written to a file until a scanout backend
# (DRM/KMS, needs VM mmap/ioctl) lands. It uses only existing builtins, so the
# same composition runs byte-identically on the C host and the native VM.
# The scene: a 32x24 blue desktop with a red window at (4,4) and a green one
# at (18,12). We check the PPM header, size, and that the composited pixels
# land at the right places with the right colours.
ok=1
px () { od -An -tu1 -j "$1" -N3 canvas.ppm | tr -s ' ' | sed 's/^ //;s/ $//'; }
check_canvas () {  # $1 = engine label
    [ "$(head -c 13 canvas.ppm)" = "$(printf 'P6\n32 24\n255\n')" ] || { echo "FAIL  theourgia($1): PPM header"; ok=0; }
    [ "$(stat -c%s canvas.ppm)" = "2317" ] || { echo "FAIL  theourgia($1): size $(stat -c%s canvas.ppm) != 2317"; ok=0; }
    [ "$(px 13)"   = "0 0 128" ]   || { echo "FAIL  theourgia($1): bg pixel [$(px 13)]";    ok=0; }
    [ "$(px 508)"  = "200 30 30" ] || { echo "FAIL  theourgia($1): win1 pixel [$(px 508)]"; ok=0; }
    [ "$(px 1417)" = "30 200 30" ] || { echo "FAIL  theourgia($1): win2 pixel [$(px 1417)]"; ok=0; }
}
rm -f canvas.ppm
./tiny_host theourgia.la >/dev/null 2>&1
check_canvas "C host"
cp canvas.ppm /tmp/canvas_host.ppm; rm -f canvas.ppm
# Sovereign: the same composition on the native VM must be byte-identical.
rm -f logos_secd logos_program.bin logos_source.la
./tiny_host secd.la >/dev/null 2>&1
cp theourgia.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
./logos_secd >/dev/null 2>&1
check_canvas "native VM"
cmp -s canvas.ppm /tmp/canvas_host.ppm || { echo "FAIL  theourgia: native raster != C host raster"; ok=0; }
rm -f canvas.ppm /tmp/canvas_host.ppm logos_secd logos_program.bin logos_source.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  theourgia: surfaces compose to a correct 32x24 raster, byte-identical on host and native VM"
else
    exit 1
fi

say "Theourgia: DRM/KMS scanout builtins (Stage 2, native VM)"
# Stage 2 adds two VM-only builtins — drm_mode() (open card0, find the connected
# mode, allocate+map a 32-bpp dumb framebuffer, SETCRTC) and present() (blit a
# framebuffer image into the scanned-out buffer). Real scanout needs DRM master,
# which only a bare VT grants; under a running compositor the kernel refuses
# SETCRTC and the builtin halts LOUDLY ("secd: drm error", exit 1) without
# touching the display. That loud, safe failure is what we assert here: the
# builtins are wired (no "unbound variable") and the full DRM sequence runs and
# fails cleanly. Actual painting is verified manually from a VT (see
# theourgia_drm.la). We only run this when a graphical session is active — i.e.
# a compositor holds master, so the test cannot seize a bare VT's display.
if [ -n "$WAYLAND_DISPLAY" ] || [ -n "$DISPLAY" ]; then
    if [ -e /dev/dri/card0 ]; then
        rm -f logos_secd logos_program.bin logos_source.la
        ./tiny_host secd.la >/dev/null 2>&1
        cp theourgia_drm.la logos_source.la
        ./tiny_host codegen.la >/dev/null 2>&1
        drm_rc=0
        ./logos_secd >/tmp/drm_out.txt 2>/tmp/drm_err.txt || drm_rc=$?
        ok=1
        grep -q "unbound" /tmp/drm_err.txt && { echo "FAIL  theourgia drm: drm_mode/present unbound (not wired)"; ok=0; }
        grep -q "secd: drm error" /tmp/drm_err.txt || { echo "FAIL  theourgia drm: expected loud 'secd: drm error' under a compositor, got [$(cat /tmp/drm_err.txt)] rc=$drm_rc"; ok=0; }
        [ "$drm_rc" -eq 1 ] || { echo "FAIL  theourgia drm: expected exit 1 (loud fail), got rc=$drm_rc"; ok=0; }
        rm -f logos_secd logos_program.bin logos_source.la /tmp/drm_out.txt /tmp/drm_err.txt
        if [ "$ok" -eq 1 ]; then
            echo "PASS  theourgia: drm_mode/present wired; full DRM sequence runs and fails loudly without master (no display touched)"
        else
            exit 1
        fi
    else
        echo "SKIP  theourgia drm: no /dev/dri/card0"
    fi
else
    echo "SKIP  theourgia drm: no graphical session (won't seize a bare VT's display)"
fi

say "Linux syscalls (native sovereign session)"
# The native VM lowers write/open/close/mount/fork/execve/waitpid/exit to real
# Linux syscalls (integers cross the LA boundary as decimal strings). Compile
# each .la program with the native compiler and run it on the VM.
rm -f logos_secd logos_program.bin logos_source.la compiler.bin runner new_logos_secd.bin
./tiny_host secd.la >/dev/null 2>&1
cp codegen.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
cp logos_program.bin compiler.bin
cp logos_secd runner; chmod +x runner
ok=1
nrun () {   # $1 = .la source file → native stdout
    cp "$1" logos_source.la
    cp compiler.bin logos_program.bin
    ./runner >/dev/null 2>&1
    ./runner 2>/dev/null
}
# fork / exit / waitpid: child exits 42, parent reaps it.
cat > /tmp/t_proc.la <<'LAEOF'
glyph SEQ = la a. la b. b
glyph IF = la c. la t. la f. c(t)(f)("!")
glyph MAIN = (la pid. IF(str_eq(pid)("0"))(la _. exit("42"))(la _. SEQ(print(concat("child exit code: ")(waitpid(pid))))(print("init done"))))(fork("!"))
LAEOF
OUT="$(nrun /tmp/t_proc.la)"
printf '%s\n' "$OUT" | grep -qxF "child exit code: 42" || { echo "FAIL  syscalls: fork/exit/waitpid"; ok=0; }
printf '%s\n' "$OUT" | grep -qxF "init done"           || { echo "FAIL  syscalls: parent continuation"; ok=0; }
# execve: child becomes /bin/true (exit 0), parent reaps.
cat > /tmp/t_exec.la <<'LAEOF'
glyph IF = la c. la t. la f. c(t)(f)("!")
glyph MAIN = (la pid. IF(str_eq(pid)("0"))(la _. execve("/bin/true"))(la _. print(concat("exec child status: ")(waitpid(pid)))))(fork("!"))
LAEOF
OUT="$(nrun /tmp/t_exec.la)"
printf '%s\n' "$OUT" | grep -qxF "exec child status: 0" || { echo "FAIL  syscalls: execve/waitpid"; ok=0; }
# open / write / close: write a file via raw fds, then read it back.
rm -f /tmp/logos_io.txt
cat > /tmp/t_io.la <<'LAEOF'
glyph SEQ = la a. la b. b
glyph MAIN = (la fd. SEQ(write(fd)("io syscalls work\n"))(close(fd)))(open("/tmp/logos_io.txt")("577"))
LAEOF
nrun /tmp/t_io.la >/dev/null
[ "$(cat /tmp/logos_io.txt 2>/dev/null)" = "io syscalls work" ] || { echo "FAIL  syscalls: open/write/close"; ok=0; }
rm -f /tmp/t_proc.la /tmp/t_exec.la /tmp/t_io.la /tmp/logos_io.txt
if [ "$ok" -eq 1 ]; then
    echo "PASS  write/open/close/fork/execve/waitpid/exit work as native syscalls"
else
    exit 1
fi

say "LogosInit: orphan reaping + shell spawn + supervision loop"
# reap("!") = wait4(-1): block until ANY child terminates and return its pid
# (a negative -errno when none remain). This is the orphan-reaping primitive an
# init needs — waitpid takes a specific pid and yields only an exit status.

# (1) reap drains the caller's own children deterministically: fork 3 children
# that exit, reap all three by pid, then ECHILD. No privileges needed.
cat > /tmp/t_reap.la <<'LAEOF'
glyph SEQ = la a. la b. b
glyph Z   = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph IF  = la c. la t. la f. c(t)(f)("!")
glyph SPAWN = la _. (la pid. IF(str_eq(pid)("0"))(la _. exit("7"))(la _. pid))(fork("!"))
glyph DRAIN = Z(la self. la n.
    (la r. IF(str_eq(str_head(r))("-"))
              (la _. print(concat("reaped ")(int_to_str(n))))
              (la _. self(add(n)(1))))
    (reap("!")))
glyph MAIN = SEQ(SPAWN("!"))(SEQ(SPAWN("!"))(SEQ(SPAWN("!"))(DRAIN(0))))
LAEOF
OUT="$(nrun /tmp/t_reap.la 2>/dev/null || true)"
printf '%s\n' "$OUT" | grep -qxF "reaped 3" \
    && echo "PASS  reap(-1) drains direct children: forked 3, reaped 3, then ECHILD" \
    || { echo "FAIL  reap: expected 'reaped 3', got '$OUT'"; exit 1; }

# (2) true orphan reaping as PID 1 (needs a PID namespace). A child forks a
# grandchild then exits, orphaning it; reparented to PID 1 it is reaped by the
# same -1 wait. Either exit order yields exactly 2 reaps. Falls back gracefully
# where unprivileged PID namespaces are unavailable.
cat > /tmp/t_orphan.la <<'LAEOF'
glyph SEQ = la a. la b. b
glyph Z   = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph IF  = la c. la t. la f. c(t)(f)("!")
glyph CHILD = la _. SEQ(fork("!"))(exit("0"))
glyph TOP   = la _. (la pid. IF(str_eq(pid)("0"))(la _. CHILD("!"))(la _. pid))(fork("!"))
glyph DRAIN = Z(la self. la n.
    (la r. IF(str_eq(str_head(r))("-"))
              (la _. print(concat("reaped ")(int_to_str(n))))
              (la _. self(add(n)(1))))
    (reap("!")))
glyph MAIN = SEQ(TOP("!"))(DRAIN(0))
LAEOF
if unshare -rpf --mount-proc true >/dev/null 2>&1; then
    cp /tmp/t_orphan.la logos_source.la; cp compiler.bin logos_program.bin
    ./runner >/dev/null 2>&1                          # compile (not as PID 1)
    OUT="$(unshare -rpf --mount-proc ./runner 2>/dev/null || true)"
    printf '%s\n' "$OUT" | grep -qxF "reaped 2" \
        && echo "PASS  PID 1 reaps an orphaned grandchild via reparenting: 2 reaps" \
        || { echo "FAIL  orphan reaping: expected 'reaped 2', got '$OUT'"; exit 1; }
else
    echo "PASS  (skipped) orphan-reaping-as-PID-1 test: unprivileged PID namespace unavailable"
fi

# (3) the real logosinit.la: announce, spawn /bin/sh (fork+execve), and a
# supervision loop that never exits. Run under a timeout with the shell's stdin
# held open (sleep) so it stays alive — reap blocks, no respawn spin. The
# timeout having to KILL init (rc 124) is the proof the loop never exits.
cp logosinit.la logos_source.la; cp compiler.bin logos_program.bin
./runner >/dev/null 2>&1
# timeout KILLING init (rc 124) is the success signal — capture it via `|| irc=$?`
# so `set -e` does not treat the expected non-zero exit as a build failure.
irc=0
{ echo 'echo LOGOS_SHELL_OK'; sleep 3; } | timeout 2 ./runner >/tmp/logos_initout 2>/dev/null || irc=$?
INITOUT="$(cat /tmp/logos_initout)"
rm -f /tmp/t_reap.la /tmp/t_orphan.la /tmp/logos_initout
if printf '%s\n' "$INITOUT" | grep -qxF "LogOS sovereign session initialized." \
   && printf '%s\n' "$INITOUT" | grep -qxF "LOGOS_SHELL_OK" \
   && [ "$irc" = "124" ]; then
    echo "PASS  logosinit announced, spawned /bin/sh (execve), and supervised without exiting"
else
    echo "FAIL  logosinit: out='$INITOUT' rc=$irc (want announce + LOGOS_SHELL_OK + rc 124)"; exit 1
fi

# sleep builtin: nanosleep for N seconds. A program that sleeps 1s takes ≥1s.
cat > /tmp/t_sleep.la <<'LAEOF'
glyph SEQ = la a. la b. b
glyph MAIN = SEQ(sleep("1"))(print("awake"))
LAEOF
cp /tmp/t_sleep.la logos_source.la; cp compiler.bin logos_program.bin; ./runner >/dev/null 2>&1
t0=$(date +%s); SLP="$(./runner 2>/dev/null)"; t1=$(date +%s)
rm -f /tmp/t_sleep.la
if [ "$SLP" = "awake" ] && [ "$((t1 - t0))" -ge 1 ]; then
    echo "PASS  sleep(\"1\") blocked ~1s then continued (nanosleep)"
else
    echo "FAIL  sleep: out='$SLP' elapsed=$((t1 - t0))s"; exit 1
fi

# Respawn throttle: a shell that dies instantly is rate-limited by BACKOFF, not
# re-forked in a tight loop. tick.sh appends one byte per spawn; over a 4s
# window with BACKOFF=1 the init respawns only a handful of times (an
# unthrottled loop would fork thousands). The init reaps its own dying shell
# children, so no PID namespace is needed here.
printf '#!/bin/sh\nprintf t >> /tmp/logos_ticks\n' > /tmp/tick.sh; chmod +x /tmp/tick.sh
rm -f /tmp/logos_ticks
sed 's#/bin/sh#/tmp/tick.sh#' logosinit.la > /tmp/t_flap.la
cp /tmp/t_flap.la logos_source.la; cp compiler.bin logos_program.bin; ./runner >/dev/null 2>&1
timeout 4 ./runner >/dev/null 2>&1 || true
TICKS=$(wc -c </tmp/logos_ticks 2>/dev/null || echo 0)
rm -f /tmp/tick.sh /tmp/logos_ticks /tmp/t_flap.la
if [ "$TICKS" -ge 2 ] && [ "$TICKS" -le 12 ]; then
    echo "PASS  respawn throttle: flapping shell rate-limited to $TICKS respawns in 4s (BACKOFF=1)"
else
    echo "FAIL  respawn throttle: $TICKS respawns in 4s (want a small bounded handful, not a fork-storm)"; exit 1
fi

# ── LogosIPC over a pipe on the native VM: init forks a worker that messages back ──
# The real (VM-native) LogosInit pattern, now over a PIPE: init creates the
# channel ONCE (pipe → "<rfd> <wfd>"), forks; the worker SENDs a typed message
# through the pipe and exits; init RECVs it (read blocks until the SEND arrives),
# decodes type/body, then reaps. The channel must be bound once before the fork
# so both processes share the same pipe fds — hence (la chan. … )(CHANNEL(…)).
# logosipc.la is now IMPORTED for real: the native VM gained cross-engine
# `import`, so codegen.la (running here as compiler.bin ON THE VM) resolves
# import("logosipc.la") at compile time — read_file is a VM builtin. The
# module exports CHANNEL/SEND/RECV/MSG_TYPE/MSG_BODY/MSG_OK and keeps its
# Church/IF helpers private (mangled away), so the importer supplies its OWN
# IF/SEQ. This exercises a real multi-export module through the fully-native
# import path (no inlining, no `export`-stripping).
cat > /tmp/t_ipc.la <<'LAEOF'
import("logosipc.la")
glyph SEQ = la a. la b. b
glyph IF  = la c. la t. la f. c(t)(f)("!")
glyph WORKER = la chan. SEQ(SEND(chan)("status")("worker-ready"))(exit("0"))
glyph MAIN = (la chan.
    (la pid. IF(str_eq(pid)("0"))
        (la _. WORKER(chan))
        (la _. (la msg.
            SEQ(print(concat("init recv type: ")(MSG_TYPE(msg))))(
            SEQ(print(concat("init recv body: ")(MSG_BODY(msg))))(
                waitpid(pid))))
          (RECV(chan))))
    (fork("!")))
    (CHANNEL("init"))
LAEOF
cp /tmp/t_ipc.la logos_source.la; cp compiler.bin logos_program.bin
./runner >/dev/null 2>&1                 # native-compile the inlined program
IPCOUT="$(./runner 2>/dev/null)"
rm -f /tmp/t_ipc.la
ok=1
printf '%s\n' "$IPCOUT" | grep -qxF "init recv type: status"       || { echo "FAIL  ipc(VM): init did not receive the typed message"; ok=0; }
printf '%s\n' "$IPCOUT" | grep -qxF "init recv body: worker-ready" || { echo "FAIL  ipc(VM): message body wrong";                  ok=0; }
if [ "$ok" -eq 1 ]; then
    echo "PASS  LogosIPC over a pipe (real import(\"logosipc.la\") on the native VM): init forked a worker that sent a typed message back through the channel"
else
    echo "  (got: $IPCOUT)"; exit 1
fi

# ── Copying GC: bounded memory under high heap churn ──
# Each iteration builds a 6 KiB string and immediately discards it: str_head
# copies out one byte, so the concat becomes garbage. ~1 GiB of total churn far
# exceeds one 768 MiB semispace, so the program completes ONLY if the collector
# reclaims the dead intermediates — the pre-GC bump heap exhausts on the same
# program. Recursion depth (180k) stays within the dump stack.
GCBIG="$(printf 'x%.0s' $(seq 1 3000))"
cat > /tmp/t_gc.la <<LAEOF
glyph SEQ = la a. la b. b
glyph Z   = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph IF  = la c. la t. la f. c(t)(f)("!")
glyph S   = "$GCBIG"
glyph LOOP = Z(la self. la n.
    IF(int_eq(n)(0))(la _. n)(la _.
        SEQ(str_head(concat(S)(S)))(self(sub(n)(1)))))
glyph MAIN = SEQ(LOOP(180000))(print("gc loop survived"))
LAEOF
GCOUT="$(nrun /tmp/t_gc.la 2>/dev/null || true)"
rm -f /tmp/t_gc.la
if printf '%s\n' "$GCOUT" | grep -qxF "gc loop survived"; then
    echo "PASS  copying GC reclaims ~1 GiB of churn — bounded memory, no exhaustion"
else
    echo "FAIL  GC: high-churn loop did not survive (got '$GCOUT')"; exit 1
fi

# ── Stack-overflow guard: deep non-tail recursion halts loudly, not silently ──
# The operand stack and dump are not GC'd, so a recursion deeper than the
# ~1M-frame dump would overrun into adjacent memory. The VM must halt with
# "secd: stack overflow" (non-zero exit) rather than silently corrupting state
# and exiting 0 with the wrong result. The recursive call is wrapped by str_tail
# so it is NEVER in tail position — it grows the dump even with TCO on (a tail
# call would instead run forever in bounded dump; see the TCO test below).
cat > /tmp/t_stack.la <<'LAEOF'
glyph Z   = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph IF  = la c. la t. la f. c(t)(f)("!")
glyph LOOP = Z(la self. la n.
    IF(int_eq(n)(0))(la _. "done")(la _. str_tail(self(sub(n)(1)))))
glyph MAIN = print(LOOP(3000000))
LAEOF
cp /tmp/t_stack.la logos_source.la; cp compiler.bin logos_program.bin
./runner >/dev/null 2>&1                       # compile
src=0
SOUT="$(./runner 2>/tmp/t_stack.err)" || src=$?
SERR="$(cat /tmp/t_stack.err)"
rm -f /tmp/t_stack.la /tmp/t_stack.err
if [ "$src" -ne 0 ] && printf '%s\n' "$SERR" | grep -qF "secd: stack overflow"; then
    echo "PASS  stack-overflow guard: deep non-tail recursion halts loudly (rc $src, 'secd: stack overflow')"
else
    echo "FAIL  stack guard: rc=$src stdout='$SOUT' stderr='$SERR' (want non-zero + 'secd: stack overflow')"; exit 1
fi

# ── Tail-call optimisation: a tail-recursive loop runs in bounded dump ──
# Under TCO an APPLY immediately followed by RET reuses the dump frame instead
# of pushing a new one, so a tail-recursive loop runs indefinitely rather than
# overflowing the dump at ~1M frames. This loop has the LogosInit supervision
# loop's exact shape — nested IF, a (la x. …)(arg) binder, tail self-calls — and
# 5M iterations (5x the old dump ceiling) complete with the right result.
cat > /tmp/t_tco.la <<'LAEOF'
glyph IF  = la c. la t. la f. c(t)(f)("!")
glyph Z   = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph LOOP = Z(la self. la n.
    (la m. IF(int_eq(m)(0))
              (la _. "supervised")
              (la _. IF(lt(m)(0))(la _. self(sub(m)(1)))(la _. self(sub(m)(1)))))
    (n))
glyph MAIN = print(LOOP(5000000))
LAEOF
cp /tmp/t_tco.la logos_source.la; cp compiler.bin logos_program.bin
./runner >/dev/null 2>&1                       # compile
TCOUT="$(./runner 2>/dev/null)"
rm -f /tmp/t_tco.la
if [ "$TCOUT" = "supervised" ]; then
    echo "PASS  TCO: 5M-deep tail recursion (supervision-loop shape) runs in bounded dump"
else
    echo "FAIL  TCO: tail loop did not complete (got '$TCOUT')"; exit 1
fi

# ── Path-length guard: a path longer than the 4 KiB buffer halts loudly ──
# read_file/write_file/write_exec/open/mount/execve copy the path into a fixed
# 4096-byte buffer; an over-long path must halt with "secd: path too long"
# rather than overrunning the buffer into fsbuf / the GC worklist.
python3 -c "open('/tmp/t_path.la','w').write('glyph MAIN = read_file(\"/'+('a'*5000)+'\")\n')"
cp /tmp/t_path.la logos_source.la; cp compiler.bin logos_program.bin; ./runner >/dev/null 2>&1
prc=0; PERR="$(./runner 2>&1 1>/dev/null)" || prc=$?
rm -f /tmp/t_path.la
if [ "$prc" -ne 0 ] && printf '%s\n' "$PERR" | grep -qF "secd: path too long"; then
    echo "PASS  path-length guard: a >4 KiB path halts loudly (rc $prc, 'secd: path too long')"
else
    echo "FAIL  path guard: rc=$prc stderr='$PERR' (want non-zero + 'secd: path too long')"; exit 1
fi

# ── Malformed-input halt: codegen aborts via `error`, no silent truncation ──
# codegen.la's PARSE_PROGRAM used to treat a parse failure as end-of-input and
# emit a truncated stream. It now halts loudly through the `error` builtin (a
# host builtin and now a VM opcode too), so a syntax error compiled on the
# native VM aborts with "parse error" instead of silently producing corrupt
# output. A valid file with trailing whitespace/comments still ends cleanly
# (every other program in this suite compiles, proving the clean-end path).
printf 'glyph FOO = la x. x\n@#$ not a glyph\n' > /tmp/t_bad.la
cp /tmp/t_bad.la logos_source.la; cp compiler.bin logos_program.bin
erc=0; EERR="$(./runner 2>&1 1>/dev/null)" || erc=$?
rm -f /tmp/t_bad.la
if [ "$erc" -ne 0 ] && printf '%s\n' "$EERR" | grep -qiF "parse error"; then
    echo "PASS  codegen halts on malformed input via error (rc $erc) — no silent truncation"
else
    echo "FAIL  malformed-input halt: rc=$erc stderr='$EERR' (want non-zero + 'parse error')"; exit 1
fi

# ── String-builtin type guards: a non-string argument halts loudly, not SIGSEGV ──
# Every string builtin reads its argument as a descriptor ([len][ptr]). Since
# native integers, an int literal `n` desugars to str_to_int("n"), so e.g.
# `str_len(5)` passes an INT value whose payload IS the integer, not a pointer —
# dereferencing it as a descriptor would SIGSEGV. The VM must halt with "secd:
# argument is not a string" (non-zero exit), matching the C host's loud
# "<builtin>: argument is not a string". chr/ord were hardened first; this
# verifies the whole set (str_head/str_tail/str_len/str_to_int/concat/str_eq/
# write_file/write_exec, both curried positions) and that valid use is intact.
guard_compile() {                                # $1 = MAIN body → compile to stream
    printf 'glyph MAIN = %s\n' "$1" > logos_source.la
    cp compiler.bin logos_program.bin
    ./runner >/dev/null 2>&1
}
gok=1
guard_loud() {                                   # $1 = label, $2 = MAIN body
    guard_compile "$2"
    grc=0; gerr="$(./runner 2>&1 1>/dev/null)" || grc=$?
    if [ "$grc" -eq 1 ] && printf '%s\n' "$gerr" | grep -qF "secd: argument is not a string"; then
        : # loud halt as required
    else
        echo "FAIL  type guard ($1): rc=$grc stderr='$gerr' (want rc 1 + 'argument is not a string'; rc 139 = SIGSEGV regression)"; gok=0
    fi
}
guard_loud "chr(65)"          'print(chr(65))'
guard_loud "ord(65)"          'print(ord(65))'
guard_loud "str_len(5)"       'print(str_len(5))'
guard_loud "str_head(5)"      'print(str_head(5))'
guard_loud "str_tail(5)"      'print(str_tail(5))'
guard_loud "str_to_int(5)"    'print(str_to_int(5))'
guard_loud "concat(5)(x)"     'print(concat(5)("x"))'
guard_loud "concat(x)(5)"     'print(concat("x")(5))'
guard_loud "str_eq(5)(x)"     'print(str_eq(5)("x"))'
guard_loud "str_eq(x)(5)"     'print(str_eq("x")(5))'
guard_loud "write_file(5)(x)" 'print(write_file(5)("x"))'
# present(pixels) is a DRM builtin but its arg is a string; its tag guard fires
# before the drm-state check, so a non-string is rejected regardless of DRM state.
guard_loud "present(5)"       'present(5)'
# Syscall builtins take their int args as decimal STRINGS via desc_atoi; a native
# INT would deref its payload (the integer itself) as a [len][ptr] descriptor and
# SIGSEGV. Same tag guard, one-arg (r8) and two-arg curried (PA record [r11+8])
# positions; it fires before any syscall, so the bad-typed call has no fd/process
# effect. (fork/reap/pipe take an ignored "!" and never deref it.)
guard_loud "close(5)"         'close(5)'
guard_loud "exit(5)"          'exit(5)'
guard_loud "waitpid(5)"       'waitpid(5)'
guard_loud "sleep(5)"         'sleep(5)'
guard_loud "execve(5)"        'execve(5)'
guard_loud "write(5)(x)"      'write(5)("x")'
guard_loud "write(1)(5)"      'write("1")(5)'
guard_loud "open(5)(0)"       'open(5)("0")'
guard_loud "open(x)(5)"       'open("/x")(5)'
guard_loud "mount(5)(x)"      'mount(5)("x")'
guard_loud "mount(x)(5)"      'mount("x")(5)'
guard_loud "read(5)(1)"       'read(5)("1")'
guard_loud "read(0)(5)"       'read("0")(5)'
# valid string use must still work (regression guard for the new tag checks)
guard_compile 'print(concat(str_head("hi"))(str_tail("abc")))'
gv="$(./runner 2>/dev/null)"
[ "$gv" = "hbc" ] || { echo "FAIL  type guard: valid concat/str_head/str_tail broke (got '$gv', want 'hbc')"; gok=0; }
# print(INT) must COERCE to its decimal, matching the C host's print("%ld") —
# b_τ ≡ f_τ: print(5) works on the host, so it must work (not crash) on the VM.
guard_compile 'print(sub(0)(42))'
gp="$(./runner 2>/dev/null)"
[ "$gp" = "-42" ] || { echo "FAIL  print(INT) coercion: got '$gp', want '-42' (C host prints the integer)"; gok=0; }
# str_to_int: malformed input (non-digit, lone '-', empty, leading '+') must halt
# LOUDLY on BOTH the C host and the VM — b_τ ≡ f_τ. Previously the host parsed a
# lenient strtol prefix ("12x"->12, "abc"->0) while the VM ran every byte through
# (c-'0') and silently produced a DIFFERENT wrong number ("12x"->1923). Now both
# reject: host "str_to_int: not a decimal integer", VM "secd: not a decimal integer".
sti_reject() {                                   # $1 = the string passed to str_to_int
    sbody="print(int_to_str(str_to_int(\"$1\")))"
    printf 'glyph MAIN = %s\n' "$sbody" > /tmp/sti.la
    hrc=0; herr="$(./tiny_host /tmp/sti.la 2>&1 1>/dev/null)" || hrc=$?
    { [ "$hrc" -eq 1 ] && printf '%s' "$herr" | grep -qF "str_to_int: not a decimal integer"; } \
        || { echo "FAIL  str_to_int reject ('$1') on C host: rc=$hrc err='$herr'"; gok=0; }
    guard_compile "$sbody"
    vrc=0; verr="$(./runner 2>&1 1>/dev/null)" || vrc=$?
    { [ "$vrc" -eq 1 ] && printf '%s' "$verr" | grep -qF "secd: not a decimal integer"; } \
        || { echo "FAIL  str_to_int reject ('$1') on VM: rc=$vrc err='$verr'"; gok=0; }
}
sti_accept() {                                   # $1 = string, $2 = expected decimal
    sbody="print(int_to_str(str_to_int(\"$1\")))"
    printf 'glyph MAIN = %s\n' "$sbody" > /tmp/sti.la
    hv="$(./tiny_host /tmp/sti.la 2>/dev/null)"
    [ "$hv" = "$2" ] || { echo "FAIL  str_to_int accept ('$1') on C host: got '$hv' want '$2'"; gok=0; }
    guard_compile "$sbody"
    vv="$(./runner 2>/dev/null)"
    [ "$vv" = "$2" ] || { echo "FAIL  str_to_int accept ('$1') on VM: got '$vv' want '$2'"; gok=0; }
}
sti_reject "12x3"; sti_reject "abc"; sti_reject "+5"; sti_reject "1 2"; sti_reject ""
sti_accept "42" "42"; sti_accept "-5" "-5"; sti_accept "0" "0"
rm -f /tmp/sti.la
if [ "$gok" -eq 1 ]; then
    echo "PASS  string + syscall builtin type guards + str_to_int strictness: bad input halts loudly cross-engine (no SIGSEGV); print(INT) coerces like the host"
else
    exit 1
fi

rm -f logos_secd logos_program.bin logos_source.la compiler.bin runner new_logos_secd.bin

say "Closing the self-hosting loop (eval.la interprets kernel.la, reconstructs itself)"
# eval.la is a lexer + parser + evaluator written entirely in Lingua
# Adamica. It reads kernel.la, parses it, evaluates it — and the
# self-interpreted kernel speaks the Word and replicates, one meta-level up.
# Its final act reads and parses its OWN source, then has INNER (its own
# unparser) reconstruct the WHOLE of eval.la from the parsed glyph table,
# writing it to eval_reconstructed.la. (The two self-parses take ~25s.)
rm -f new_logos_gen*.bin eval_reconstructed.la
ERR_E="$(mktemp)"
EVAL_OUT="$(./tiny_host eval.la 2>"$ERR_E")"
EVAL_CHILD="$(sed -n 's/^copy_self: replicated -> //p' "$ERR_E" | tail -1)"
rm -f "$ERR_E"
SRC_GLYPHS="$(grep -c '^glyph ' eval.la)"
RECON_GLYPHS="$(grep -c '^glyph ' eval_reconstructed.la 2>/dev/null || echo 0)"
ok=1
printf '%s\n' "$EVAL_OUT" | grep -qF "hello from the meta-evaluator" || { echo "FAIL  meta-eval: trivial print";   ok=0; }
printf '%s\n' "$EVAL_OUT" | grep -qF "identity works"                || { echo "FAIL  meta-eval: lambda apply";    ok=0; }
printf '%s\n' "$EVAL_OUT" | grep -qxF "concat"                       || { echo "FAIL  meta-eval: curried concat";  ok=0; }
printf '%s\n' "$EVAL_OUT" | grep -qF "I can read myself, I AM THAT I AM" || { echo "FAIL  meta-eval: kernel self-read"; ok=0; }
printf '%s\n' "$EVAL_OUT" | grep -qxF "I AM THAT I AM"                || { echo "FAIL  meta-eval: kernel Word";     ok=0; }
printf '%s\n' "$EVAL_OUT" | grep -qxF "round-trip: stable"           || { echo "FAIL  meta-eval: parse∘unparse not a fixed point"; ok=0; }
[ -f eval_reconstructed.la ]                                         || { echo "FAIL  meta-eval: eval_reconstructed.la not written"; ok=0; }
[ "$RECON_GLYPHS" -eq "$SRC_GLYPHS" ] \
    || { echo "FAIL  meta-eval: reconstructed $RECON_GLYPHS glyphs, source has $SRC_GLYPHS"; ok=0; }
case "$EVAL_CHILD" in new_logos_gen1_pid*.bin) : ;; *) echo "FAIL  meta-eval: no replicant ('$EVAL_CHILD')"; ok=0 ;; esac
[ -n "$EVAL_CHILD" ] && [ -f "$EVAL_CHILD" ] && cmp -s tiny_host "$EVAL_CHILD" \
    || { echo "FAIL  meta-eval: replicant not byte-identical"; ok=0; }
# Cross-engine native integers: the SAME integer program must produce the
# SAME output on the C host (direct) and the self-hosted meta-evaluator
# (eval.la test 6). Confirms integers were propagated coherently, not just
# added to the host. (eval.la lexes digits, desugars n -> str_to_int("n"),
# and bridges the int builtins; codegen.la compiles the same desugaring.)
echo 'glyph MAIN = print(int_to_str(add(mul(6)(7))(sub(10)(8))))' > /tmp/xeng.la
HOST_INT="$(./tiny_host /tmp/xeng.la 2>/dev/null)"
# test 6's result is the only standalone "44" line (the reconstructed-source
# dump from test 5 has no bare "44"); take it directly.
META_INT="$(printf '%s\n' "$EVAL_OUT" | grep -xF "44" | tail -1)"
[ "$HOST_INT" = "44" ]                       || { echo "FAIL  native int: C host computed '$HOST_INT' != 44"; ok=0; }
[ "$META_INT" = "44" ]                        || { echo "FAIL  native int: meta-evaluator computed '$META_INT' != 44"; ok=0; }
[ "$HOST_INT" = "$META_INT" ]                 || { echo "FAIL  native int: host and meta-evaluator disagree"; ok=0; }
rm -f /tmp/xeng.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  the language interpreted itself: kernel spoke and bred $EVAL_CHILD"
    echo "PASS  INNER reconstructed the whole of eval.la ($RECON_GLYPHS glyphs, round-trip stable)"
    echo "PASS  native integers agree cross-engine: C host == eval.la meta-evaluator (= 44)"
else
    printf '%s\n' "$EVAL_OUT"
    exit 1
fi
rm -f eval_reconstructed.la

say "Clearing previous generations"
rm -f new_logos_gen*.bin new_logos.bin logos_child.bin
echo "clean"

say "Booting the LogOS kernel (kernel.la)   generation 0 -> 1"
run_host ./tiny_host
printf '%s\n%s\n' "$RUN_ERR" "$RUN_OUT"
GEN1="$RUN_CHILD"

say "Verifying the Word"
if printf '%s\n' "$RUN_OUT" | grep -qx "I AM THAT I AM"; then
    echo "PASS  the kernel spoke: I AM THAT I AM"
else
    echo "FAIL  expected the kernel to speak 'I AM THAT I AM'"
    exit 1
fi

say "Verifying self-reading"
if printf '%s\n' "$RUN_OUT" | grep -qF "I can read myself, I AM THAT I AM"; then
    echo "PASS  the kernel can read itself"
else
    echo "FAIL  expected 'I can read myself, I AM THAT I AM'"
    exit 1
fi

say "Verifying self-replication   (∃(∃) ≡ ∃)"
case "$GEN1" in
    new_logos_gen1_pid*.bin) : ;;
    *) echo "FAIL  unexpected child name: '$GEN1'"; exit 1 ;;
esac
[ -f "$GEN1" ] || { echo "FAIL  $GEN1 was not created"; exit 1; }
if cmp -s tiny_host "$GEN1"; then
    echo "PASS  $GEN1 is byte-identical to its source"
else
    echo "FAIL  the copy differs from the original"
    exit 1
fi

say "Letting the replicant breed   generation 1 -> 2 (run directly, in place)"
chmod +x "$GEN1"
G1_BEFORE="$(md5sum "$GEN1" | cut -d' ' -f1)"
run_host "./$GEN1"
GEN2="$RUN_CHILD"
printf '%s\n%s\n' "$RUN_ERR" "$RUN_OUT"
G1_AFTER="$(md5sum "$GEN1" | cut -d' ' -f1)"

ok=1
printf '%s\n' "$RUN_OUT" | grep -qx "I AM THAT I AM" || { echo "FAIL  replicant is mute";            ok=0; }
case "$GEN2" in new_logos_gen2_pid*.bin) : ;; *) echo "FAIL  child not gen2: '$GEN2'"; ok=0 ;; esac
[ -f "$GEN2" ]                         || { echo "FAIL  gen2 was not created";          ok=0; }
cmp -s tiny_host "$GEN2"               || { echo "FAIL  gen2 differs from the original"; ok=0; }
[ "$G1_BEFORE" = "$G1_AFTER" ]         || { echo "FAIL  gen1 mutated its own binary";    ok=0; }
if [ "$ok" -eq 1 ]; then
    echo "PASS  gen1 ran in place, stayed intact, and bred $GEN2"
else
    exit 1
fi

say "Verifying unique siblings   (same parent, run twice -> two distinct files)"
run_host ./tiny_host;  SIB_A="$RUN_CHILD"
run_host ./tiny_host;  SIB_B="$RUN_CHILD"
ok=1
case "$SIB_A" in new_logos_gen1_pid*.bin) : ;; *) echo "FAIL  sibling A not gen1: '$SIB_A'"; ok=0 ;; esac
case "$SIB_B" in new_logos_gen1_pid*.bin) : ;; *) echo "FAIL  sibling B not gen1: '$SIB_B'"; ok=0 ;; esac
[ "$SIB_A" != "$SIB_B" ]   || { echo "FAIL  two runs produced the same filename"; ok=0; }
[ -f "$SIB_A" ] && [ -f "$SIB_B" ] || { echo "FAIL  a sibling file is missing"; ok=0; }
cmp -s "$SIB_A" "$SIB_B"   || { echo "FAIL  siblings are not byte-identical"; ok=0; }
if [ "$ok" -eq 1 ]; then
    echo "PASS  same generation, distinct vessels:"
    echo "        $SIB_A"
    echo "        $SIB_B"
else
    exit 1
fi

say "Lineage   (same Word, same bytes, distinct vessels)"
printf '  %s  %s\n' "$(md5sum tiny_host | cut -d' ' -f1)" "tiny_host  (progenitor, gen 0)"
for f in new_logos_gen*.bin; do
    printf '  %s  %s\n' "$(md5sum "$f" | cut -d' ' -f1)" "$f"
done

say "LogOS bootstrap complete"
echo "∃(∃) ≡ ∃"
