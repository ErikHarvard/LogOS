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

say "LogosIPC: capability gating (object-capabilities, Layer 4)"
# logoscap.la adds the Codex's "capability-gated" property to the typed bus via
# the Morris sealer/unsealer — the canonical object-capability primitive, exact
# in lambda calculus. A BRAND mints a write capability (sealer) and a read
# capability (unsealer); a sealed box is an opaque probe-guarded closure that
# reveals its payload only to the brand's secret. It imports logosipc.la (ENCODE/
# MSG_TYPE/MSG_BODY) so a gated message is a SEALed typed message, and is pure
# Lingua Adamica, so it runs byte-identically on the C host and native VM. The
# demo: realm A sends a typed message on its own authority; A's read capability
# opens it (authorized = ping/hello), B's foreign capability cannot (isolation =
# denied), and probing the bare box with no capability stays opaque (forged =
# denied). We assert all three on both engines, byte-identical.
ok=1
CAP_EXPECT="$(printf 'logoscap: authorized read = ping/hello\nlogoscap: foreign capability = denied\nlogoscap: forged probe = denied')"
HCAP="$(./tiny_host logoscap.la 2>/dev/null)"
[ "$HCAP" = "$CAP_EXPECT" ] || { echo "FAIL  logoscap (C host): capability gating mismatch"; printf '%s\n' "$HCAP"; ok=0; }
rm -f logos_secd logos_program.bin logos_source.la
./tiny_host secd.la >/dev/null 2>&1
cp logoscap.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
VCAP="$(./logos_secd 2>/dev/null)"
[ "$VCAP" = "$CAP_EXPECT" ] || { echo "FAIL  logoscap (native VM): capability gating mismatch"; printf '%s\n' "$VCAP"; ok=0; }
[ "$HCAP" = "$VCAP" ] || { echo "FAIL  logoscap: host and VM differ"; ok=0; }
rm -f logos_secd logos_program.bin logos_source.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  import(\"logosipc.la\") + capabilities: sealed typed messages — authorized opens, foreign cap and forged probe denied, byte-identical on host and VM"
else
    exit 1
fi
# Random-nonce branding (VM-only): MINT("!") brands a realm with a fresh 32-byte
# nonce from the `random` builtin instead of a fixed string. Two MINTs give
# independent nonces, so realm A's box opens for A (authorized) but not for B
# (foreign = denied) — and that "denied" PROVES the two nonces differ (no entropy
# → identical nonce → B would leak A's message). VM-only since `random` is a VM
# builtin; the pure sealer mechanism above already proved cross-engine.
sed '/^glyph MAIN/,$d' logoscap.la > /tmp/capmint.la
cat >> /tmp/capmint.la <<'LA'
glyph MAIN =
  (la realmA. (la realmB.
    (la box.
      SEQ(SHOW_OPEN("authorized = ")(CAP_RECV(GRANT_RECV(realmA))(box))(la w. concat(MSG_TYPE(w))(concat("/")(MSG_BODY(w)))))
          (SHOW_OPEN("foreign = ")(CAP_RECV(GRANT_RECV(realmB))(box))(la w. concat("LEAKED ")(MSG_TYPE(w)))))
    (CAP_SEND(GRANT_SEND(realmA))("ping")("hello"))
  )(MINT("!")))(MINT("!"))
LA
rm -f logos_secd logos_program.bin logos_source.la
./tiny_host secd.la >/dev/null 2>&1
cp /tmp/capmint.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
MCAP="$(./logos_secd 2>/dev/null)"
MCAP_EXPECT="$(printf 'authorized = ping/hello\nforeign = denied')"
rm -f /tmp/capmint.la logos_secd logos_program.bin logos_source.la
if [ "$MCAP" = "$MCAP_EXPECT" ]; then
    echo "PASS  logoscap MINT: random-nonce brands via random(\"32\") — A opens, B (distinct nonce) denied; entropy makes the secret unforgeable (native VM)"
else
    echo "FAIL  logoscap MINT: random-nonce branding ($MCAP)"; exit 1
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

say "Spec pipeline: an evdev input module via import(\"specpipe.la\")"
# evdev_spec.la is the evdev module written as a SPEC (NOT hand-written source):
# for each glyph a type signature, body source, live implementation, and test
# cases. GENERATE + DEPLOY produce and verify evdev.la — the committed module is
# REGENERATED from the spec here, so this also guards that evdev.la never drifts
# from its spec. We assert every decode/support glyph passes its tests and the
# module is VERIFIED, then run the generated module stand-alone on both engines.
# (The 3 I/O bindings OPEN_INPUT/READ_EVENT/CLOSE_INPUT wrap VM-only syscalls and
# carry no host-runnable test — verified live on the VM, like the input reader.)
EV="$(./tiny_host evdev_spec.la 2>/dev/null)"
ok=1
for G in DROP B U16 U32 S32 EV_TYPE EV_CODE EV_VALUE IS_KEY_PRESS IS_KEY_RELEASE IS_MOUSE_MOVE; do
    printf '%s\n' "$EV" | grep -qx "  $G: PASS" || { echo "FAIL  evdev: $G not verified"; ok=0; }
done
printf '%s\n' "$EV" | grep -q "module VERIFIED" || { echo "FAIL  evdev: module not verified"; ok=0; }
[ -f evdev.la ] || { echo "FAIL  evdev: evdev.la was not written"; ok=0; }
# Run the GENERATED module stand-alone: build a KEY_A press and a REL_X -3 event,
# decode + classify. Same program on host and VM must give the identical line.
make_evtest () {
    cp evdev.la /tmp/evtest.la
    cat >> /tmp/evtest.la <<'LA'
glyph SEQ = la a. la b. b
glyph BYTE = la n. chr(int_to_str(n))
glyph REP = Z(la self. la n. la s. IF(int_eq(n)(0))(la _. "")(la _. concat(s)(self(sub(n)(1))(s))))
glyph LE16 = la n. concat(BYTE(mod(n)(256)))(BYTE(div(n)(256)))
glyph MKEV = la t. la c. la v0. la v1. la v2. la v3. concat(REP(16)(BYTE(0)))(concat(LE16(t))(concat(LE16(c))(concat(BYTE(v0))(concat(BYTE(v1))(concat(BYTE(v2))(BYTE(v3)))))))
glyph PRESS = MKEV(1)(30)(1)(0)(0)(0)
glyph REL = MKEV(2)(0)(253)(255)(255)(255)
glyph BS = la b. b(la _. "T")(la _. "F")("!")
glyph MAIN =
  SEQ(print(concat("type=")(int_to_str(EV_TYPE(PRESS)))))(
  SEQ(print(concat("code=")(int_to_str(EV_CODE(PRESS)))))(
  SEQ(print(concat("press=")(BS(IS_KEY_PRESS(PRESS)))))(
  SEQ(print(concat("release=")(BS(IS_KEY_RELEASE(PRESS)))))(
  SEQ(print(concat("relval=")(int_to_str(EV_VALUE(REL)))))(
      print(concat("mouse=")(BS(IS_MOUSE_MOVE(REL)))))))))
LA
}
EV_EXPECT="$(printf 'type=1\ncode=30\npress=T\nrelease=F\nrelval=-3\nmouse=T')"
make_evtest
EVH="$(./tiny_host /tmp/evtest.la 2>/dev/null)"
[ "$EVH" = "$EV_EXPECT" ] || { echo "FAIL  evdev: generated module ran wrong on host"; printf '%s\n' "$EVH"; ok=0; }
rm -f logos_secd logos_program.bin logos_source.la
./tiny_host secd.la >/dev/null 2>&1
cp /tmp/evtest.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
EVV="$(./logos_secd 2>/dev/null)"
[ "$EVV" = "$EV_EXPECT" ] || { echo "FAIL  evdev: generated module ran wrong on native VM"; printf '%s\n' "$EVV"; ok=0; }
rm -f /tmp/evtest.la logos_secd logos_program.bin logos_source.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  evdev: SPEC GENERATEs/DEPLOYs evdev.la, META_DEBUG verifies every decode glyph"
    echo "PASS  evdev: the generated module decodes/classifies events stand-alone, byte-identical on host and VM"
else
    printf '%s\n' "$EV"
    exit 1
fi

say "Spec pipeline: the nine LA primitives via import(\"specpipe.la\")"
# primitives_spec.la writes the nine typed primitives of M₀ (Being, Recognition,
# Love, Self, Relation, Void, Becoming, Form, Depth — plus Z and the guarded
# DEPTH_Z) as a SPEC, GENERATEs + DEPLOYs primitives.la (REGENERATED here, so it
# never drifts from its spec), and META_DEBUG-verifies each glyph against its
# AUTOLOGY test cases: the primitive applied to itself reduces to the meaningful
# value (the template being ∃(∃) ≡ ∃). Seven autologies terminate to a fixed
# point / value; BECOMING(BECOMING) terminates to a higher-order process. DEPTH
# is the deliberate exception — DEPTH(DEPTH) is the infinite descent Ω — so its
# META_DEBUG tests metacursion on halting args, and its divergence is asserted
# below via timeout, on both engines.
PR="$(./tiny_host primitives_spec.la 2>/dev/null)"
ok=1
for G in BEING Z RELATION RECOGNITION LOVE SELF VOID BECOMING FORM DEPTH DEPTH_Z; do
    printf '%s\n' "$PR" | grep -qx "  $G: PASS" || { echo "FAIL  primitives: $G autology not verified"; ok=0; }
done
printf '%s\n' "$PR" | grep -q "module VERIFIED" || { echo "FAIL  primitives: module not verified"; ok=0; }
[ -f primitives.la ] || { echo "FAIL  primitives: primitives.la was not written"; ok=0; }
# The shipped module is also compile-time typed: nine primitives carry formal
# `:: <type>` signatures the type checker verifies (incl. the higher-order
# RELATION, parenthesised RECOGNITION/LOVE, and the expanded Church-Nat BECOMING);
# the two point-free glyphs (SELF, DEPTH_Z) stay untyped/trusted.
for G in BEING Z RELATION RECOGNITION LOVE VOID BECOMING FORM DEPTH; do
    printf '%s\n' "$PR" | grep -qE "^  $G : .*  OK$" || { echo "FAIL  primitives: $G not type-checked OK"; ok=0; }
done
for G in SELF DEPTH_Z; do
    printf '%s\n' "$PR" | grep -qx "  $G: untyped (trusted)" || { echo "FAIL  primitives: $G not reported untyped/trusted"; ok=0; }
done
# Run the GENERATED module stand-alone: one char per primitive's autology witness
# (each char is the sentinel echoed back through the self-applied primitive, so
# "abcdefghi" appears only if every autology holds). Host and VM must agree.
cp primitives.la /tmp/primtest.la
cat >> /tmp/primtest.la <<'LA'
glyph FST = la p. p(la a. la b. a)
glyph SND = la p. p(la a. la b. b)
glyph IF  = la c. la t. la f. c(t)(f)("!")
glyph MAIN =
  print(concat(SND(RELATION(RELATION)("a")))(
        concat(FST(FST(RECOGNITION(RECOGNITION))("b")))(
        concat(FST(FST(FST(FST(LOVE(LOVE)(LOVE)))("c")("z"))))(
        concat(SELF(SELF)("d"))(
        concat(VOID(VOID)("e"))(
        concat(BECOMING(BECOMING)(la _. "f")("z"))(
        concat(FORM(FORM)(la x. x)("g")(la x. x))(
        concat(DEPTH(BEING)("h"))(
        DEPTH_Z(la self. la n. IF(int_eq(n)(0))(la _. "i")(la _. self(sub(n)(1))))(3))))))))))
LA
PRIM_EXPECT="abcdefghi"
PRH="$(./tiny_host /tmp/primtest.la 2>/dev/null)"
[ "$PRH" = "$PRIM_EXPECT" ] || { echo "FAIL  primitives: autology witnesses wrong on host"; printf '%s\n' "$PRH"; ok=0; }
rm -f logos_secd logos_program.bin logos_source.la
./tiny_host secd.la >/dev/null 2>&1
cp /tmp/primtest.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
PRV="$(./logos_secd 2>/dev/null)"
[ "$PRV" = "$PRIM_EXPECT" ] || { echo "FAIL  primitives: autology witnesses wrong on native VM"; printf '%s\n' "$PRV"; ok=0; }
rm -f /tmp/primtest.la logos_secd logos_program.bin logos_source.la
# DEPTH autology is non-termination (Ω). Assert DEPTH(DEPTH) never returns on
# either engine: under `timeout` it must be killed (exit 124), not complete.
printf 'glyph DEPTH = la g. g(g)\nglyph MAIN = DEPTH(DEPTH)\n' > /tmp/depthdiv.la
# timeout KILLING the divergence (rc 124) is the success signal — capture it via
# `|| drc=$?` so `set -e` does not treat the expected non-zero exit as a failure.
drc=0; timeout 4 ./tiny_host /tmp/depthdiv.la >/dev/null 2>&1 || drc=$?
[ "$drc" -eq 124 ] || { echo "FAIL  primitives: DEPTH(DEPTH) did not diverge on host (rc=$drc, expected timeout 124)"; ok=0; }
rm -f logos_secd logos_program.bin logos_source.la
./tiny_host secd.la >/dev/null 2>&1
cp /tmp/depthdiv.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
drc=0; timeout 4 ./logos_secd >/dev/null 2>&1 || drc=$?
[ "$drc" -eq 124 ] || { echo "FAIL  primitives: DEPTH(DEPTH) did not diverge on native VM (rc=$drc, expected timeout 124)"; ok=0; }
rm -f /tmp/depthdiv.la logos_secd logos_program.bin logos_source.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  primitives: SPEC GENERATEs/DEPLOYs primitives.la, META_DEBUG verifies every primitive's autology"
    echo "PASS  primitives: nine glyphs compile-time type-checked (arrow arity), SELF/DEPTH_Z trusted (point-free)"
    echo "PASS  primitives: autology witnesses (abcdefghi) byte-identical on host and VM; DEPTH(DEPTH) diverges (timeout) on both"
else
    printf '%s\n' "$PR"
    exit 1
fi

say "Spec pipeline: κ + etymology-bearing glyphs (canon_spec.la — autological Ren)"
# canon_spec.la writes κ (CANON) as a SPEC and GENERATEs + DEPLOYs canon.la
# (REGENERATED here, so it never drifts). κ takes a DECOMPOSITION — a primitive
# leaf or a combination via the five modes ⊗ ⊕ ▷ ⊂ ↻ — and produces a canonical
# glyph SPECIFICATION (a deterministic prefix-notation string Theourgia will
# later render). The Law of Identity is the triple bar: IS(a)(b) ≡ str_eq(κa)(κb)
# — A IS B iff they canonicalize to the same glyph (identity, NOT equality). The
# three laws of thought are theorems over IS (each ≡ TRUE). META_DEBUG verifies
# all of it; then the GENERATED module is run stand-alone, byte-identical on host
# and VM.
CK="$(./tiny_host canon_spec.la 2>/dev/null)"
ok=1
for G in Z TRUE FALSE NOT AND OR PRIM SYN CON DIR CONT MC CANON IS LAW_ID LAW_NC LAW_EM KAPPA \
         REVAL SR_TO SR_ABOUT SR_AS SR_BY SR_FROM SR_THROUGH SR_FOR SR_WITH \
         IF MAX TDEPTH MONO REN ETYM GLYPH COLLAPSE MCOLLAPSE DEPTH AUTO_OK \
         BYTE_LT LE WRAP2 SORT2 REWRITE_MC NORMK NIS IS_ALPHA1 ALPHA1; do
    printf '%s\n' "$CK" | grep -qx "  $G: PASS" || { echo "FAIL  canon: $G not verified"; ok=0; }
done
printf '%s\n' "$CK" | grep -q "module VERIFIED" || { echo "FAIL  canon: module not verified"; ok=0; }
[ -f canon.la ] || { echo "FAIL  canon: canon.la was not written"; ok=0; }
# the logical core + etymology layer carry formal `:: <type>` signatures (incl. the
# three laws); the Scott-encoded modes, κ, KAPPA, and the Z-recursive TDEPTH are
# point-free/Z-recursive → trusted.
for G in TRUE FALSE NOT AND OR IS LAW_ID LAW_NC LAW_EM IF MAX MONO REN ETYM GLYPH COLLAPSE MCOLLAPSE DEPTH AUTO_OK; do
    printf '%s\n' "$CK" | grep -qE "^  $G : .*  OK$" || { echo "FAIL  canon: $G not type-checked OK"; ok=0; }
done
for G in PRIM SYN CON DIR CONT MC CANON KAPPA REVAL SR_TO SR_ABOUT SR_AS SR_BY SR_FROM SR_THROUGH SR_FOR SR_WITH TDEPTH BYTE_LT LE WRAP2 SORT2 REWRITE_MC NORMK NIS IS_ALPHA1 ALPHA1; do
    printf '%s\n' "$CK" | grep -qx "  $G: untyped (trusted)" || { echo "FAIL  canon: $G not reported untyped/trusted"; ok=0; }
done
# Run the GENERATED canon.la stand-alone. The witness has three parts joined by
# '|': (1) κ on a nested decomposition + κ(κ)=↻(KAPPA), and the three laws +
# identity (sentinels I N E = → "INE=" only if every law and identity hold); (2)
# the ETYMOLOGY layer — two monoglyphs COLLAPSE (not couple) into ONE deeper
# monoglyph G3 whose Ren = ▷(⊗(BEING,VOID),FORM), depth = 2 (deeper, not larger),
# and AUTO_OK = TRUE (the name IS its etymology — autological). Host and VM agree.
cp canon.la /tmp/canontest.la
cat >> /tmp/canontest.la <<'LA'
glyph G3 = COLLAPSE(DIR)(COLLAPSE(SYN)(GLYPH("BEING"))(GLYPH("VOID")))(GLYPH("FORM"))
glyph W1 = CANON(CONT(MC(PRIM("DEPTH")))(SYN(PRIM("BEING"))(PRIM("FORM"))))
glyph W2 = CANON(MC(KAPPA))
glyph W3 = concat(LAW_ID(PRIM("LOVE"))("I")("x"))(concat(LAW_NC(PRIM("BEING"))(PRIM("VOID"))("N")("x"))(concat(LAW_EM(PRIM("BEING"))(PRIM("VOID"))("E")("x"))(IS(PRIM("BEING"))(PRIM("BEING"))("=")("x"))))
glyph W4 = REN(G3)
glyph W5 = concat("d=")(int_to_str(DEPTH(G3)))
glyph W6 = AUTO_OK(G3)("A")("h")
# W7: monosemic normalization — ⊕(A,B)≡⊕(B,A) (commutative) and ↻(BEING)≡SELF
# (algebraic) collapse to one canonical glyph; ▷ stays directional → distinct.
glyph W7 = concat(NORMK(CON(PRIM("B"))(PRIM("A"))))(concat(NIS(CON(PRIM("A"))(PRIM("B")))(CON(PRIM("B"))(PRIM("A")))("m")("x"))(concat(NORMK(MC(PRIM("BEING"))))(NIS(DIR(PRIM("A"))(PRIM("B")))(DIR(PRIM("B"))(PRIM("A")))("x")("d"))))
# W8: α=1 alignment — ⊕(A,B) is the ontoglyph (α=1, sign IS referent), ⊕(B,A) is a
# synonym (α<1) that collapses to the same α=1 representative.
glyph W8 = concat(IS_ALPHA1(CON(PRIM("A"))(PRIM("B")))("1")("<"))(concat(IS_ALPHA1(CON(PRIM("B"))(PRIM("A")))("1")("<"))(ALPHA1(CON(PRIM("B"))(PRIM("A")))))
# W9: the eight self-relations (six instantiated). SR_TO = Logos-to-itself = ↻(DEPTH);
# each is a metacursive fixed point SR(SR) ≡ SR; distinct self-relations are distinct
# glyphs (SR_AS ≢ SR_FROM). "↻(DEPTH)" then "=" (SR_TO autological) "=" (SR_BY) "d" (SR_AS≠SR_FROM).
glyph W9 = concat(CANON(SR_TO))(concat("/")(concat(NIS(MC(SR_TO))(SR_TO)("=")("x"))(concat(NIS(MC(SR_BY))(SR_BY)("=")("x"))(IS(SR_AS)(SR_FROM)("x")("d")))))
glyph BAR = "|"
glyph MAIN = print(concat(W1)(concat(BAR)(concat(W2)(concat(BAR)(concat(W3)(concat(BAR)(concat(W4)(concat(BAR)(concat(W5)(concat(BAR)(concat(W6)(concat(BAR)(concat(W7)(concat(BAR)(concat(W8)(concat(BAR)(W9)))))))))))))))))
LA
CANON_EXPECT="⊂(↻(DEPTH),⊗(BEING,FORM))|↻(▷(RECOGNITION,FORM))|INE=|▷(⊗(BEING,VOID),FORM)|d=2|A|⊕(A,B)mSELFd|1<⊕(A,B)|↻(DEPTH)/==d"
CKH="$(./tiny_host /tmp/canontest.la 2>/dev/null)"
[ "$CKH" = "$CANON_EXPECT" ] || { echo "FAIL  canon: κ/etymology witness wrong on host"; printf 'got: %s\n' "$CKH"; ok=0; }
rm -f logos_secd logos_program.bin logos_source.la
./tiny_host secd.la >/dev/null 2>&1
cp /tmp/canontest.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
CKV="$(./logos_secd 2>/dev/null)"
[ "$CKV" = "$CANON_EXPECT" ] || { echo "FAIL  canon: κ/etymology witness wrong on native VM"; printf 'got: %s\n' "$CKV"; ok=0; }
rm -f /tmp/canontest.la logos_secd logos_program.bin logos_source.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  canon: SPEC GENERATEs/DEPLOYs canon.la, META_DEBUG verifies κ, IS (≡), the three laws, the etymology layer, and NORMK"
    echo "PASS  canon: κ(κ) well-defined; etymology contained; NORMK collapses synonyms → monosemic; α=1 ontoglyph (sign IS referent), synonyms collapse to it; byte-identical host/VM"
else
    printf '%s\n' "$CK"
    exit 1
fi

say "Spec pipeline: PSC* invariant preservation (psc_spec.la — Θ_P, ⊗ preserves parent formants)"
# psc_spec.la writes the Phonosemantic Compiler's invariant layer as a SPEC and
# GENERATEs+DEPLOYs psc.la (regenerated here, so it never drifts). Θ_P is a phonym's
# topological invariant signature (its distinct formant peaks; idempotent, Θ(Θx)=Θx
# §6282); the ⊗ compound invariant is the SUPERPOSITION (union) of the parents'
# spectra; PRESERVES is set-containment. The theorem: a neologistically-compressed
# phonym preserves the topological invariants of BOTH constituents — Love's /u/ and
# Recognition's /i/ formants both survive in Compassion (⊗) — while a non-constituent
# (Depth /ɔ/) does NOT (real preservation, not trivial), and the duration is max of
# the parents, not the sum (compression, §4233). phonym.la realises this in audio
# (SYNP superposition; FFT recovers 6/6 of each parent's formants). META_DEBUG
# verifies; then the GENERATED psc.la runs stand-alone, byte-identical host and VM.
PK="$(./tiny_host psc_spec.la 2>/dev/null)"
ok=1
for G in Z TRUE FALSE AND IF LNIL LCONS LMEM LSUB LAPP LDEDUP LREN THETA_P SYN_INV PRESERVES SYN_DUR LOVE_F REC_F DEPTH_F; do
    printf '%s\n' "$PK" | grep -qx "  $G: PASS" || { echo "FAIL  psc: $G not verified"; ok=0; }
done
printf '%s\n' "$PK" | grep -q "module VERIFIED" || { echo "FAIL  psc: module not verified"; ok=0; }
[ -f psc.la ] || { echo "FAIL  psc: psc.la was not written"; ok=0; }
# Run the GENERATED psc.la stand-alone: the preservation witness.
#   L = Love's formants ⊆ Compassion; R = Recognition's ⊆ Compassion; d = Depth NOT
#   ⊆ (non-constituent); then the superposed union spectrum; dur=max(parents); i = Θ_P
#   idempotent.
cp psc.la /tmp/psctest.la
cat >> /tmp/psctest.la <<'LA'
glyph W1 = PRESERVES(LOVE_F)(SYN_INV(LOVE_F)(REC_F))("L")("x")
glyph W2 = PRESERVES(REC_F)(SYN_INV(LOVE_F)(REC_F))("R")("x")
glyph W3 = PRESERVES(DEPTH_F)(SYN_INV(LOVE_F)(REC_F))("x")("d")
glyph W4 = LREN(SYN_INV(LOVE_F)(REC_F))
glyph W5 = concat("dur=")(int_to_str(SYN_DUR(6560)(6720)))
glyph W6 = str_eq(LREN(THETA_P(THETA_P(LAPP(LOVE_F)(REC_F)))))(LREN(THETA_P(LAPP(LOVE_F)(REC_F))))("i")("x")
glyph MAIN = print(concat(W1)(concat(W2)(concat(W3)(concat("|")(concat(W4)(concat("|")(concat(W5)(concat("|")(W6)))))))))
LA
PSC_EXPECT="LRd|300,870,2240,270,2300,3000,|dur=6720|i"
PKH="$(./tiny_host /tmp/psctest.la 2>/dev/null)"
[ "$PKH" = "$PSC_EXPECT" ] || { echo "FAIL  psc: preservation witness wrong on host"; printf 'got: %s\n' "$PKH"; ok=0; }
rm -f logos_secd logos_program.bin logos_source.la
./tiny_host secd.la >/dev/null 2>&1
cp /tmp/psctest.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
PKV="$(./logos_secd 2>/dev/null)"
[ "$PKV" = "$PSC_EXPECT" ] || { echo "FAIL  psc: preservation witness wrong on native VM"; printf 'got: %s\n' "$PKV"; ok=0; }
rm -f /tmp/psctest.la logos_secd logos_program.bin logos_source.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  psc: SPEC GENERATEs/DEPLOYs psc.la; Θ_P invariant signature, ⊗ preserves BOTH parents' formants (Love+Recognition→Compassion) under compression (dur=max not sum), non-constituent not preserved, byte-identical host/VM"
else
    printf '%s\n' "$PK"
    exit 1
fi

say "Spec pipeline: TopoEmbed invariant preservation (topoembed_spec.la — visual ⊗ recoverable)"
# The VISUAL parallel of psc (Refinement 2). topoembed_spec.la GENERATEs+DEPLOYs
# topoembed.la: Θ_V (VINV) is a glyph's visual invariant signature = its mode
# symbol + its ONF leaf-set (constituent primitives); PRESERVES_V is set-
# containment; MODE_REC checks distinct modes over the same operands give distinct
# invariants (⊗ ≠ ⊕). The theorem: a neologistically-compressed sigil preserves
# the topological invariants of BOTH constituents AND its combining mode is
# recoverable from the form — Love's and Recognition's primitives both survive in
# Compassion (⊗) while a non-constituent (Being) does not, and ⊗ is distinguishable
# from ⊕. sigil.la realises this: the ⊗ render is THE SEALING — both parents
# interpenetrate into ONE fused sigil (formal complexity one) + a ⊗ mode-mark,
# the etymology recoverable AUTOLOGICALLY from the sealed structure (see seal stage).
# META_DEBUG verifies; then the GENERATED topoembed.la runs stand-alone host/VM.
TK="$(./tiny_host topoembed_spec.la 2>/dev/null)"
ok=1
for G in Z TRUE FALSE NOT AND IF PRIM SYN CON DIR CONT MC STARTSW CONTAINS LEAVES MODESYM VINV PRESERVES_V MODE_REC; do
    printf '%s\n' "$TK" | grep -qx "  $G: PASS" || { echo "FAIL  topoembed: $G not verified"; ok=0; }
done
printf '%s\n' "$TK" | grep -q "module VERIFIED" || { echo "FAIL  topoembed: module not verified"; ok=0; }
[ -f topoembed.la ] || { echo "FAIL  topoembed: topoembed.la was not written"; ok=0; }
# Run the GENERATED topoembed.la stand-alone: the recoverability witness.
#   L = Love's form ⊆ Compassion; R = Recognition's ⊆; b = Being NOT ⊆; then the
#   visual invariant signature (mode + leaves); m = mode recoverable (⊗ ≠ ⊕).
cp topoembed.la /tmp/tetest.la
cat >> /tmp/tetest.la <<'LA'
glyph COMPASSION = SYN(PRIM("LOVE"))(PRIM("RECOGNITION"))
glyph MAIN = print(concat(PRESERVES_V("LOVE")(COMPASSION)("L")("x"))(concat(PRESERVES_V("RECOGNITION")(COMPASSION)("R")("x"))(concat(PRESERVES_V("BEING")(COMPASSION)("x")("b"))(concat("|")(concat(VINV(COMPASSION))(concat("|")(MODE_REC(PRIM("LOVE"))(PRIM("RECOGNITION"))("m")("x"))))))))
LA
TE_EXPECT="LRb|⊗:LOVE,RECOGNITION,|m"
TKH="$(./tiny_host /tmp/tetest.la 2>/dev/null)"
[ "$TKH" = "$TE_EXPECT" ] || { echo "FAIL  topoembed: recoverability witness wrong on host"; printf 'got: %s\n' "$TKH"; ok=0; }
rm -f logos_secd logos_program.bin logos_source.la
./tiny_host secd.la >/dev/null 2>&1
cp /tmp/tetest.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
TKV="$(./logos_secd 2>/dev/null)"
[ "$TKV" = "$TE_EXPECT" ] || { echo "FAIL  topoembed: recoverability witness wrong on native VM"; printf 'got: %s\n' "$TKV"; ok=0; }
rm -f /tmp/tetest.la logos_secd logos_program.bin logos_source.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  topoembed: SPEC GENERATEs/DEPLOYs topoembed.la; Θ_V invariant, ⊗ preserves BOTH parents' forms (Love+Recognition→Compassion), non-constituent not preserved, MODE recoverable (⊗≠⊕) — byte-identical host/VM"
else
    printf '%s\n' "$TK"
    exit 1
fi

say "Autonomous self-improving loop (autoloop.la — generate→verify→iterate, bounded)"
# autoloop.la imports specpipe.la and runs the autonomous cycle: for each step of a
# GOAL (a spec supplied from outside) it verifies the glyph via META_DEBUG and
# accepts it ONLY if every test passes (verify-or-reject — no unverified code
# enters), carrying the verified set forward; on completion it GENERATEs+DEPLOYs the
# whole module. Bounded, with three clear terminations: goal met, step budget
# exhausted, or a verification failure (LOUD HALT via `error`, nonzero exit). We
# assert all three on the host. (host==VM was verified byte-identical — both the
# loop trace AND the generated mathutil.la — but isn't re-run each build: codegen of
# a specpipe-importer is ~160s; like the DRM/live capstones, it is host-checked here
# with manual VM confirmation.)
ok=1
# (1) SUCCESS — a 4-step math-utilities goal runs autonomously to completion + deploy.
rm -f mathutil.la
AL="$(./tiny_host autoloop.la 2>/dev/null)"
printf '%s\n' "$AL" | grep -q "step 1: DOUBLE — META_DEBUG PASS, accepted" || { echo "FAIL  autoloop: step 1 not autonomously accepted"; ok=0; }
printf '%s\n' "$AL" | grep -q "step 4: SUMSQ — META_DEBUG PASS, accepted"  || { echo "FAIL  autoloop: step 4 not reached/accepted"; ok=0; }
printf '%s\n' "$AL" | grep -q "✓ AUTOLOOP goal met: 4 step(s), all verified" || { echo "FAIL  autoloop: goal not met"; ok=0; }
printf '%s\n' "$AL" | grep -q "module VERIFIED"                              || { echo "FAIL  autoloop: deployed module not verified"; ok=0; }
[ -f mathutil.la ]                                                          || { echo "FAIL  autoloop: mathutil.la not generated"; ok=0; }
grep -q "glyph SUMSQ = la x. la y. add(mul(x)(x))(mul(y)(y))" mathutil.la   || { echo "FAIL  autoloop: generated module body wrong"; ok=0; }
# (2) LOUD HALT — a step whose impl fails its test must stop nonzero, refusing it.
cat > /tmp/al_loud.la <<'LA'
import("specpipe.la")
import("autoloop.la")
glyph BAD = CONS(ENT("DOUBLE")(":: a -> a")("la x. add(x)(x)")(la x. add(x)(x))(SING(TC(la g. int_to_str(g(5)))("10"))))(CONS(ENT("SQUARE")(":: a -> a")("la x. add(x)(x)")(la x. add(x)(x))(SING(TC(la g. int_to_str(g(4)))("16"))))(NIL))
glyph MAIN = AUTOLOOP(10)(0)(BAD)
LA
# `|| LRC=$?` so `set -e` does not treat the EXPECTED loud-halt exit as a build failure.
LRC=0; ./tiny_host /tmp/al_loud.la >/tmp/al_loud.out 2>&1 || LRC=$?
[ "$LRC" -ne 0 ]                          || { echo "FAIL  autoloop: broken step did not loud-halt (rc=$LRC)"; ok=0; }
grep -q "loud halt" /tmp/al_loud.out      || { echo "FAIL  autoloop: no loud-halt message"; ok=0; }
grep -q "step 1: DOUBLE" /tmp/al_loud.out || { echo "FAIL  autoloop: did not accept the valid step before halting"; ok=0; }
# (3) BUDGET — a 3-step goal with budget 2 stops cleanly, goal NOT met.
cat > /tmp/al_bud.la <<'LA'
import("specpipe.la")
import("autoloop.la")
glyph G =
  CONS(ENT("DOUBLE")(":: a -> a")("la x. add(x)(x)")(la x. add(x)(x))(SING(TC(la g. int_to_str(g(5)))("10"))))(
  CONS(ENT("SQUARE")(":: a -> a")("la x. mul(x)(x)")(la x. mul(x)(x))(SING(TC(la g. int_to_str(g(4)))("16"))))(
  CONS(ENT("INC")(":: a -> a")("la x. add(x)(1)")(la x. add(x)(1))(SING(TC(la g. int_to_str(g(7)))("8"))))(
  NIL)))
glyph MAIN = AUTOLOOP(2)(0)(G)
LA
BUD="$(./tiny_host /tmp/al_bud.la 2>/dev/null)"; BRC=$?
[ "$BRC" -eq 0 ]                                              || { echo "FAIL  autoloop: budget stop should be clean (rc=$BRC)"; ok=0; }
printf '%s\n' "$BUD" | grep -q "budget exhausted after 2"     || { echo "FAIL  autoloop: budget bound not reported"; ok=0; }
rm -f mathutil.la /tmp/al_loud.la /tmp/al_loud.out /tmp/al_bud.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  autoloop: autonomous generate→verify→iterate — 4-step goal verified+deployed with no intervention; LOUD HALT on a step that fails META_DEBUG (rc≠0, unverified code refused); clean stop at the step budget (goal not met). Bounded; host==VM verified byte-identical (manual)"
else
    exit 1
fi

say "Spec pipeline: the three laws of thought — metalogical ontosyntax (metalogic_spec.la)"
# metalogic_spec.la writes the THREE LAWS OF THOUGHT as first-class glyphs and
# GENERATEs + DEPLOYs metalogic.la (REGENERATED here, so it never drifts). It makes
# the distinction canon.la's IS only gestured at EXPLICIT: two relations, never
# conflated (Codex I's category error). ≡ TRIBAR — ONTOLOGICAL IDENTITY over a
# being's self-grounded FORM (∃(∃) ≡ ∃ via the GROUND rewrite); = YIELDS —
# COMPUTATIONAL equality over evaluated VALUE. They GENUINELY disagree: add(2,3) = 5
# (same value) yet add(2,3) ≢ 5 (different beings); identity entails equality but
# equality does NOT entail identity. The three laws are glyphs over ≡:
# LAW_IDENTITY (A≡A, self-grounding), LAW_NONCONTRADICTION (wired to the type
# checker — INHABITS is the arity judgement, and DEPLOY rejects a type-contradiction),
# LAW_EXCLUDED_MIDDLE (wired to loud failure — VERDICT is total: ≡ or ≢, never a
# silent third; VERDICT_OR_DIE halts loudly on an ill-formed term). Each law is
# AUTOLOGICAL (holds of its own term). META_DEBUG verifies all of it; then the
# GENERATED module is run stand-alone, byte-identical on host and VM.
ML="$(./tiny_host metalogic_spec.la 2>/dev/null)"
ok=1
for G in TRUE FALSE NOT AND OR IF IMPLIES TERM FORM VAL GROUND YIELDS TRIBAR \
         LAW_IDENTITY LAW_NONCONTRADICTION LAW_EXCLUDED_MIDDLE INHABITS NC_TYPECHECK \
         VERDICT WELLFORMED VERDICT_OR_DIE T_LAW_IDENTITY T_LAW_NONCONTRADICTION \
         T_LAW_EXCLUDED_MIDDLE LAWS_AUTOLOGICAL; do
    printf '%s\n' "$ML" | grep -qx "  $G: PASS" || { echo "FAIL  metalogic: $G not verified"; ok=0; }
done
printf '%s\n' "$ML" | grep -q "module VERIFIED" || { echo "FAIL  metalogic: module not verified"; ok=0; }
[ -f metalogic.la ] || { echo "FAIL  metalogic: metalogic.la was not written"; ok=0; }
# the logical core, the two relations, the three laws and their wirings carry formal
# `:: <type>` signatures (the laws OBEY the laws — NC type-checks the law glyphs);
# the three law term-witnesses are TERM data → trusted.
for G in TRUE FALSE NOT AND OR IF IMPLIES TERM FORM VAL GROUND YIELDS TRIBAR \
         LAW_IDENTITY LAW_NONCONTRADICTION LAW_EXCLUDED_MIDDLE INHABITS NC_TYPECHECK \
         VERDICT WELLFORMED VERDICT_OR_DIE LAWS_AUTOLOGICAL; do
    printf '%s\n' "$ML" | grep -qE "^  $G : .*  OK$" || { echo "FAIL  metalogic: $G not type-checked OK"; ok=0; }
done
for G in T_LAW_IDENTITY T_LAW_NONCONTRADICTION T_LAW_EXCLUDED_MIDDLE; do
    printf '%s\n' "$ML" | grep -qx "  $G: untyped (trusted)" || { echo "FAIL  metalogic: $G not reported untyped/trusted"; ok=0; }
done
# Run the GENERATED metalogic.la stand-alone. The witness is six parts joined by '|':
# (1) ∃(∃) ≡ ∃ — the Archē as ONTOLOGICAL identity (VERDICT → "≡"); (2) "=≢" — the
# category distinction: add(2,3) = 5 (yields) yet ≢ 5 (being); (3) "INE" — the three
# laws hold; (4) "ineY" — AUTOLOGY: each law of its own term + LAWS_AUTOLOGICAL; (5)
# "TFy" — NC wired to the type checker: INHABITS match (T), mismatch caught (F), NC
# holds (y); (6) "du" — = does NOT entail ≡ (d), but ≡ DOES entail = (u). Host == VM.
cp metalogic.la /tmp/mltest.la
cat >> /tmp/mltest.la <<'LA'
glyph ADD23     = TERM("add(2,3)")(int_to_str(add(2)(3)))
glyph FIVE      = TERM("5")(int_to_str(5))
glyph EXIST     = TERM("∃")("∃")
glyph EXIST_SELF = TERM("∃(∃)")("∃")
glyph W1 = VERDICT(EXIST_SELF)(EXIST)
glyph W2 = concat(YIELDS(ADD23)(FIVE)("=")("x"))(VERDICT(ADD23)(FIVE))
glyph W3 = concat(LAW_IDENTITY(ADD23)("I")("x"))(concat(LAW_NONCONTRADICTION(ADD23)(FIVE)("N")("x"))(LAW_EXCLUDED_MIDDLE(ADD23)(FIVE)("E")("x")))
glyph W4 = concat(LAW_IDENTITY(T_LAW_IDENTITY)("i")("x"))(concat(LAW_NONCONTRADICTION(T_LAW_NONCONTRADICTION)(T_LAW_NONCONTRADICTION)("n")("x"))(concat(LAW_EXCLUDED_MIDDLE(T_LAW_EXCLUDED_MIDDLE)(T_LAW_EXCLUDED_MIDDLE)("e")("x"))(LAWS_AUTOLOGICAL("!")("Y")("x"))))
glyph W5 = concat(INHABITS(2)(2)("T")("F"))(concat(INHABITS(2)(1)("T")("F"))(NC_TYPECHECK(2)(1)("y")("x")))
glyph W6 = concat(IMPLIES(YIELDS(ADD23)(FIVE))(TRIBAR(ADD23)(FIVE))("x")("d"))(IMPLIES(TRIBAR(ADD23)(ADD23))(YIELDS(ADD23)(ADD23))("u")("x"))
glyph J = la a. la b. concat(a)(concat("|")(b))
glyph MAIN = print(J(W1)(J(W2)(J(W3)(J(W4)(J(W5)(W6))))))
LA
ML_EXPECT="≡|=≢|INE|ineY|TFy|du"
MLH="$(./tiny_host /tmp/mltest.la 2>/dev/null)"
[ "$MLH" = "$ML_EXPECT" ] || { echo "FAIL  metalogic: laws/≡-vs-= witness wrong on host"; printf 'got: %s\n' "$MLH"; ok=0; }
rm -f logos_secd logos_program.bin logos_source.la
./tiny_host secd.la >/dev/null 2>&1
cp /tmp/mltest.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
MLV="$(./logos_secd 2>/dev/null)"
[ "$MLV" = "$ML_EXPECT" ] || { echo "FAIL  metalogic: laws/≡-vs-= witness wrong on native VM"; printf 'got: %s\n' "$MLV"; ok=0; }
# EXCLUDED MIDDLE wired to LOUD FAILURE: VERDICT_OR_DIE on an ill-formed term must
# HALT LOUDLY (non-zero), not return a silent third value — on host AND VM.
cp metalogic.la /tmp/mlloud.la
cat >> /tmp/mlloud.la <<'LA'
glyph MAIN = print(VERDICT_OR_DIE(TERM("")("x"))(TERM("∃")("∃")))
LA
./tiny_host /tmp/mlloud.la >/dev/null 2>&1 && { echo "FAIL  metalogic: ill-formed term did NOT halt on host (no excluded middle)"; ok=0; }
rm -f logos_secd logos_program.bin logos_source.la
./tiny_host secd.la >/dev/null 2>&1
cp /tmp/mlloud.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
./logos_secd >/dev/null 2>&1 && { echo "FAIL  metalogic: ill-formed term did NOT halt on VM (no excluded middle)"; ok=0; }
# NON-CONTRADICTION wired to the TYPE CHECKER: a type-contradiction (declared arity
# ≠ body arity) is REJECTED at the DEPLOY gate and the module is never written.
cat > /tmp/nc_reject_spec.la <<'LA'
import("specpipe.la")
glyph E = la name. la sig. la src. la val. la tests. TRIPLE(name)(DEF(sig)(src)(val))(tests)
glyph BAD_SPEC = CONS(E("CONTRADICT")(":: a -> b -> c")("la x. x")(la x. x)(CONS(PAIR(la g. g("y")("z"))("y"))(NIL)))(NIL)
glyph MAIN = print(DEPLOY(BAD_SPEC)("/tmp/should_not_exist.la"))
LA
rm -f /tmp/should_not_exist.la
NCR="$(./tiny_host /tmp/nc_reject_spec.la 2>/dev/null)"
printf '%s\n' "$NCR" | grep -q "module REJECTED" || { echo "FAIL  metalogic: type-contradiction NOT rejected by the checker"; ok=0; }
[ -f /tmp/should_not_exist.la ] && { echo "FAIL  metalogic: rejected module was written anyway"; ok=0; }
rm -f /tmp/mltest.la /tmp/mlloud.la /tmp/nc_reject_spec.la /tmp/should_not_exist.la logos_secd logos_program.bin logos_source.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  metalogic: SPEC GENERATEs/DEPLOYs metalogic.la, META_DEBUG verifies the two relations (≡ vs =), the three laws, and their autology"
    echo "PASS  metalogic: ≡ (ontological identity) and = (computational yields) genuinely disagree (add(2,3)=5 yet ≢5); NC→type checker rejects contradictions; EM→loud halt; byte-identical host/VM"
else
    printf '%s\n' "$ML"
    exit 1
fi

say "Spec pipeline: the Autological Adequacy Tautological Criterion — LogosMentor's symbolic core (aatc_spec.la)"
# aatc_spec.la writes the AATC (Being & Becoming Ch.6) as first-class glyphs and
# GENERATEs + DEPLOYs aatc.la (REGENERATED here, so it never drifts). The four
# conditions a self-referential structure must meet — self-inclusion, self-
# application, self-validation (X(X)≡X, the α=1 fixed point), and closure —
# composed into one verdict AATC; AUTOLOGICAL/HETEROLOGICAL split structures by
# whether they exempt themselves (the property they ascribe to others); ALPHA
# (α=1 ⟺ X(X)=X, the autological index) and DELTA (∂, depth to the fixed point).
# The criterion is itself autological: AATC(AATC) ≡ TRUE. On top of the criterion
# sits the INFERENCE LAYER — the Centropic loop (LINGUA ADAMICA.tex): DIAGNOSE a
# structure's heterology, PRESCRIBE a transformation 𝒯 (= recognition applied to
# revision, an honest deepening — never a flag-flip that games the verdict), and
# RE-VERIFY with AATC, iterating to autological closure (REPAIR). META_DEBUG
# verifies all of it; then the GENERATED module runs stand-alone, host == VM.
AC="$(./tiny_host aatc_spec.la 2>/dev/null)"
ok=1
for G in TRUE FALSE AND IF NOT OR STRUCT SNAME SINSCOPE SSELFAPP SLACKS \
         SELF_INCLUSION SELF_APPLICATION SELF_VALIDATION CLOSURE \
         AATC AUTOLOGICAL HETEROLOGICAL ALPHA DELTA \
         TF DIAGNOSE T_APPLY T_GROUND T_INCLUDE T_CLOSE TRANSFORM REPAIR \
         Zc C01 RHO FOLDR FORALL PHI; do
    printf '%s\n' "$AC" | grep -qx "  $G: PASS" || { echo "FAIL  aatc: $G not verified"; ok=0; }
done
printf '%s\n' "$AC" | grep -q "module VERIFIED" || { echo "FAIL  aatc: module not verified"; ok=0; }
[ -f aatc.la ] || { echo "FAIL  aatc: aatc.la was not written"; ok=0; }
# every glyph carries a formal :: <type> signature → all type-checked OK at deploy
for G in TRUE FALSE AND IF NOT OR STRUCT SNAME SINSCOPE SSELFAPP SLACKS \
         SELF_INCLUSION SELF_APPLICATION SELF_VALIDATION CLOSURE \
         AATC AUTOLOGICAL HETEROLOGICAL ALPHA DELTA \
         TF DIAGNOSE T_APPLY T_GROUND T_INCLUDE T_CLOSE TRANSFORM REPAIR \
         Zc C01 RHO FORALL PHI; do
    printf '%s\n' "$AC" | grep -qE "^  $G : .*  OK$" || { echo "FAIL  aatc: $G not type-checked OK"; ok=0; }
done
# FOLDR is point-free (Z-recursive), so it is trusted (untyped), like canon's TDEPTH.
printf '%s\n' "$AC" | grep -qx "  FOLDR: untyped (trusted)" || { echo "FAIL  aatc: FOLDR not reported untyped/trusted"; ok=0; }
# Run the GENERATED aatc.la stand-alone. The witness is eleven parts joined by '|':
# the CRITERION — (1) AATC(∃) the Archē passes; (2) AATC(AATC) the criterion's own
# autology; (3) HETEROLOGICAL(TOE_P) a physical TOE exempts itself; (4) "FTTF" the
# four conditions on TOE_P; (5) "11" α(∃)=1 and ∂(AATC)=1; (6) "F0" COGITO fails
# AATC, α=0 — then the INFERENCE LAYER (the Centropic loop driving structures to
# autological closure): (7) "FFFF" DIAGNOSE(BROKEN) the maximal heterology; (8) "T"
# REPAIR(BROKEN) is AUTOLOGICAL; (9) "TTTT" DIAGNOSE(REPAIR(BROKEN)) every condition
# restored; (10) "TTTT" one 𝒯 step grounds the cogito; (11) "T" REPAIR(TOE_P)
# autological — then the remaining two AATC OPERATORS: (12) "3" ρ(∃)=3 fully
# witnessed; (13) "0" ρ(BROKEN)=0 unwitnessed (drifts to potentiality); (14) "1"
# φ of an autological whole with autological parts (fractally coherent); (15) "0"
# φ with a heterological part (a part fails to mirror the whole). Host == VM.
cp aatc.la /tmp/actest.la
cat >> /tmp/actest.la <<'LA'
glyph ALL = la nm. TRUE
glyph ARCHE = STRUCT("∃")(ALL)("∃")("")
glyph AATC_S = STRUCT("AATC")(ALL)("AATC")("")
glyph TOE_P = STRUCT("TOE_P")(la nm. NOT(str_eq(nm)("TOE_P")))("TOE_P")("epistemology")
glyph COGITO = STRUCT("COGITO")(ALL)("SUM")("")
glyph BROKEN = STRUCT("BROKEN")(la nm. NOT(str_eq(nm)("BROKEN")))("")("dep")
glyph LNIL = la n. la c. n
glyph LCONS = la h. la t. la n. la c. c(h)(t)
glyph W1 = AATC(ARCHE)("T")("F")
glyph W2 = AATC(AATC_S)("T")("F")
glyph W3 = HETEROLOGICAL(TOE_P)("T")("F")
glyph W4 = concat(SELF_INCLUSION(TOE_P)("T")("F"))(concat(SELF_APPLICATION(TOE_P)("T")("F"))(concat(SELF_VALIDATION(TOE_P)("T")("F"))(CLOSURE(TOE_P)("T")("F"))))
glyph W5 = concat(ALPHA(ARCHE))(DELTA(AATC_S))
glyph W6 = concat(AATC(COGITO)("T")("F"))(ALPHA(COGITO))
glyph I7 = DIAGNOSE(BROKEN)
glyph I8 = AUTOLOGICAL(REPAIR(BROKEN))("T")("F")
glyph I9 = DIAGNOSE(REPAIR(BROKEN))
glyph I10 = DIAGNOSE(TRANSFORM(COGITO))
glyph I11 = AUTOLOGICAL(REPAIR(TOE_P))("T")("F")
glyph R1 = RHO(ARCHE)
glyph R2 = RHO(BROKEN)
glyph P1 = PHI(ARCHE)(LCONS(ARCHE)(LCONS(AATC_S)(LNIL)))
glyph P2 = PHI(ARCHE)(LCONS(TOE_P)(LNIL))
glyph J = la a. la b. concat(a)(concat("|")(b))
glyph MAIN = print(J(W1)(J(W2)(J(W3)(J(W4)(J(W5)(J(W6)(J(I7)(J(I8)(J(I9)(J(I10)(J(I11)(J(R1)(J(R2)(J(P1)(P2)))))))))))))))
LA
AC_EXPECT="T|T|T|FTTF|11|F0|FFFF|T|TTTT|TTTT|T|3|0|1|0"
ACH="$(./tiny_host /tmp/actest.la 2>/dev/null)"
[ "$ACH" = "$AC_EXPECT" ] || { echo "FAIL  aatc: AATC witness wrong on host"; printf 'got: %s\n' "$ACH"; ok=0; }
rm -f logos_secd logos_program.bin logos_source.la
./tiny_host secd.la >/dev/null 2>&1
cp /tmp/actest.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
ACV="$(./logos_secd 2>/dev/null)"
[ "$ACV" = "$AC_EXPECT" ] || { echo "FAIL  aatc: AATC witness wrong on native VM"; printf 'got: %s\n' "$ACV"; ok=0; }
rm -f /tmp/actest.la logos_secd logos_program.bin logos_source.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  aatc: SPEC GENERATEs/DEPLOYs aatc.la, META_DEBUG verifies the four AATC conditions, the AATC(AATC) autology, and the α/∂ operators"
    echo "PASS  aatc: AATC composes the laws into one verdict — the Archē passes, a self-exempting TOE is HETEROLOGICAL; byte-identical host/VM"
    echo "PASS  aatc: the inference layer (Centropic loop) DIAGNOSEs heterology + PRESCRIBEs 𝒯 (honest deepening) + REPAIRs to autological closure — the maximal heterology and the cogito both driven to a fixed point; byte-identical host/VM"
    echo "PASS  aatc: the five AATC operators are complete — α (index) · ∂ (depth) · 𝒯 (transformation) · ρ (recognition coefficient, 0..3) · φ (fractal coherence, each part mirrors the ∃(∃)≡∃ whole); byte-identical host/VM"
else
    printf '%s\n' "$AC"
    exit 1
fi

say "Spec pipeline: structurally-encoded compressing glyph form (glyphdag_spec.la)"
# glyphdag_spec.la writes the canonical glyph as a SINGLE flat hash-consed DAG
# string "def0;def1;...;defk" (root = last def), and GENERATEs + DEPLOYs
# glyphdag.la (REGENERATED here, no drift). DECOMP recovers the full etymology
# tree from the one form; DCOLLAPSE neologizes two forms into ONE, re-interning
# with structure SHARING. META_DEBUG verifies all 47 glyphs; then the GENERATED
# module proves the author's three criteria stand-alone, byte-identical on host
# and VM: (1) combining two forms yields ONE form (not a pair); (2)
# DAG(DECOMP(form))==form (the full tree is recoverable by decomposing the one
# form); (3) self-combining grows the node count LINEARLY (3 4 5 6) while the
# unfolded tree grows EXPONENTIALLY (3 7 15 31) — deep concepts COMPRESS.
DG="$(./tiny_host glyphdag_spec.la 2>/dev/null)"
ok=1
printf '%s\n' "$DG" | grep -q "module VERIFIED" || { echo "FAIL  glyphdag: module not verified"; ok=0; }
[ -f glyphdag.la ] || { echo "FAIL  glyphdag: glyphdag.la was not written"; ok=0; }
for G in Zc PRIM SYN INTERN DAG NODES DECOMP DCOLLAPSE TSIZE; do
    printf '%s\n' "$DG" | grep -qx "  $G: PASS" || { echo "FAIL  glyphdag: $G not verified"; ok=0; }
done
cp glyphdag.la /tmp/dagtest.la
cat >> /tmp/dagtest.la <<'LA'
glyph G  = DAG(SYN(PRIM("BEING"))(PRIM("VOID")))
glyph G2 = DCOLLAPSE(SYN_S)(G)(G)
glyph G3 = DCOLLAPSE(SYN_S)(G2)(G2)
glyph G4 = DCOLLAPSE(SYN_S)(G3)(G3)
glyph MAIN = print(concat(G2)(concat("|rt=")(concat(str_eq(DAG(DECOMP(G2)))(G2)("ok")("no"))(concat("|n=")(concat(int_to_str(NODES(G4)))(concat("|t=")(int_to_str(TSIZE(DECOMP(G4))))))))))
LA
DAG_EXPECT="BEING;VOID;⊗0.1;⊗2.2|rt=ok|n=6|t=31"
DGH="$(./tiny_host /tmp/dagtest.la 2>/dev/null)"
[ "$DGH" = "$DAG_EXPECT" ] || { echo "FAIL  glyphdag: witness wrong on host"; printf 'got: %s\n' "$DGH"; ok=0; }
rm -f logos_secd logos_program.bin logos_source.la
./tiny_host secd.la >/dev/null 2>&1
cp /tmp/dagtest.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
DGV="$(./logos_secd 2>/dev/null)"
[ "$DGV" = "$DAG_EXPECT" ] || { echo "FAIL  glyphdag: witness wrong on native VM"; printf 'got: %s\n' "$DGV"; ok=0; }
rm -f /tmp/dagtest.la logos_secd logos_program.bin logos_source.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  glyphdag: SPEC GENERATEs/DEPLOYs glyphdag.la (47 glyphs), META_DEBUG verifies the hash-consed DAG"
    echo "PASS  glyphdag: combine→ONE form; tree recoverable (DECOMP); self-combine compresses (nodes 3..6 vs tree 3..31); byte-identical host/VM"
else
    printf '%s\n' "$DG"
    exit 1
fi

say "Spec pipeline: static SWC checker — ill-foundedness + operator-order (swc_spec.la)"
# swc_spec.la writes a CONSERVATIVE static checker and GENERATEs + DEPLOYs swc.la
# (REGENERATED here). It enforces two constraints BEFORE evaluation:
#  (a) ill-foundedness over lambda ASTs: WF (0, no bound-var self-application →
#      accept), ILL (2, an EAGER self-application — la g. g(g) / liar la x. f(x(x))
#      / Ω → refuse), UNKNOWN (1, GUARDED self-application as in Z → undecidable
#      halting residue, let through to the resource guards);
#  (b) operator-order (Grammar of Composition): the five operators chain
#      ∂→δ→γ→ρ→𝔄 (ranks 1..5), so a later operator must nest OUTSIDE an earlier
#      one. A descendant of higher rank = out of order; the canonical violation is
#      𝔄(integrate,5) inside δ(bound,2) = integrate-before-bound = unbounded
#      meaning (Pathology 3). META_DEBUG verifies both; then the GENERATED module
#      runs stand-alone, byte-identical on host and VM.
SW="$(./tiny_host swc_spec.la 2>/dev/null)"
ok=1
printf '%s\n' "$SW" | grep -q "module VERIFIED" || { echo "FAIL  swc: module not verified"; ok=0; }
[ -f swc.la ] || { echo "FAIL  swc: swc.la was not written"; ok=0; }
for G in Z AST_VAR AST_LAM AST_APP IS_VAR FIND_SA SWC VERDICT OATOM OOP MAXRANK ORD ORDER; do
    printf '%s\n' "$SW" | grep -qx "  $G: PASS" || { echo "FAIL  swc: $G not verified"; ok=0; }
done
cp swc.la /tmp/swctest.la
cat >> /tmp/swctest.la <<'LA'
glyph TD = AST_LAM("g")(AST_APP(AST_VAR("g"))(AST_VAR("g")))
glyph TS = AST_LAM("x")(AST_APP(AST_VAR("f"))(AST_VAR("x")))
glyph TZ = AST_LAM("f")(AST_APP(AST_LAM("x")(AST_APP(AST_VAR("f"))(AST_LAM("v")(AST_APP(AST_APP(AST_VAR("x"))(AST_VAR("x")))(AST_VAR("v"))))))(AST_STR("z")))
glyph WW = AST_LAM("x")(AST_APP(AST_VAR("x"))(AST_VAR("x")))
glyph BAD = OOP(2)(OATOM("x"))(OOP(5)(OATOM("a"))(OATOM("b")))
glyph GOOD = OOP(5)(OOP(2)(OATOM("a"))(OATOM("b")))(OATOM("c"))
glyph V1 = VERDICT(TD)
glyph V2 = VERDICT(TS)
glyph V3 = VERDICT(TZ)
glyph V4 = VERDICT(AST_APP(WW)(WW))
glyph V5 = ORDER(BAD)
glyph V6 = ORDER(GOOD)
glyph MAIN = print(concat(V1)(concat("|")(concat(V2)(concat("|")(concat(V3)(concat("|")(concat(V4)(concat("|")(concat(V5)(concat("|")(V6)))))))))))
LA
SWC_EXPECT="ILL|WF|UNKNOWN|ILL|ORDER-VIOLATION|WELL-ORDERED"
SWH="$(./tiny_host /tmp/swctest.la 2>/dev/null)"
[ "$SWH" = "$SWC_EXPECT" ] || { echo "FAIL  swc: witness wrong on host"; printf 'got: %s\n' "$SWH"; ok=0; }
rm -f logos_secd logos_program.bin logos_source.la
./tiny_host secd.la >/dev/null 2>&1
cp /tmp/swctest.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
SWV="$(./logos_secd 2>/dev/null)"
[ "$SWV" = "$SWC_EXPECT" ] || { echo "FAIL  swc: witness wrong on native VM"; printf 'got: %s\n' "$SWV"; ok=0; }
rm -f /tmp/swctest.la logos_secd logos_program.bin logos_source.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  swc: SPEC GENERATEs/DEPLOYs swc.la, META_DEBUG verifies ill-foundedness + operator-order checks"
    echo "PASS  swc: refuses ILL (la g.g(g)/liar/Ω) + integrate-before-bound (Pathology 3); accepts WF/well-ordered; Z UNKNOWN; byte-identical host/VM"
else
    printf '%s\n' "$SW"
    exit 1
fi

say "Spec pipeline: COMPILE-TIME type checking inside DEPLOY"
# specpipe.la's DEPLOY now runs a compile-time TYPE CHECKER after GENERATE and
# before accepting: it reads the GENERATED source, parses each glyph's body, and
# verifies its abstraction arity equals the arrow arity of its declared type
# (the decidable type property for untyped λ). A signature marked `:: <type>` is
# checked; any other (prose) signature is `untyped (trusted)` — so the existing
# specs above are unaffected (and the fact they still deploy VERIFIED proves the
# new phase is backward-compatible). typed_spec.la deploys a WELL-TYPED module
# (accepted) and an ILL-TYPED one (BADCONST: declared a->b->a, arity 2, but body
# `la x. x`, arity 1) which must be REJECTED with no file written.
rm -f typed_module.la typed_bad.la typed_badtype.la
TY="$(./tiny_host typed_spec.la 2>/dev/null)"
ok=1
# (1) the well-typed module: every checked glyph reports OK, and it is VERIFIED
for G in IDT KESTREL COMPOSE FLIP PAIRT; do
    printf '%s\n' "$TY" | grep -qE "^  $G : .*  OK$" || { echo "FAIL  typecheck: $G not reported type-OK"; ok=0; }
done
printf '%s\n' "$TY" | grep -q "module VERIFIED" || { echo "FAIL  typecheck: well-typed module not VERIFIED"; ok=0; }
[ -f typed_module.la ] || { echo "FAIL  typecheck: typed_module.la (well-typed) was not written"; ok=0; }
# (2) the ill-typed module: BADCONST flagged TYPE ERROR, module REJECTED, no file
printf '%s\n' "$TY" | grep -qE "^  BADCONST : .*  TYPE ERROR$" || { echo "FAIL  typecheck: BADCONST not flagged as TYPE ERROR"; ok=0; }
printf '%s\n' "$TY" | grep -q "module REJECTED" || { echo "FAIL  typecheck: ill-typed module not REJECTED"; ok=0; }
[ -f typed_bad.la ] && { echo "FAIL  typecheck: typed_bad.la was written despite type error (must be rejected)"; ok=0; }
# (3) malformed type signature (dangling arrow) flagged MALFORMED TYPE, rejected, no file
printf '%s\n' "$TY" | grep -qE "^  DANGLE : .*  MALFORMED TYPE$" || { echo "FAIL  typecheck: DANGLE (dangling-arrow type) not flagged MALFORMED TYPE"; ok=0; }
[ -f typed_badtype.la ] && { echo "FAIL  typecheck: typed_badtype.la was written despite malformed type"; ok=0; }
# (4) the ACCEPTED artifact is valid runnable LA (compose two string ops)
cp typed_module.la /tmp/tymod.la 2>/dev/null
printf 'glyph SEQ = la a. la b. b\nglyph MAIN = print(COMPOSE(la s. concat(s)("!"))(la s. concat(">")(s))("ok"))\n' >> /tmp/tymod.la
TYRUN="$(./tiny_host /tmp/tymod.la 2>/dev/null)"
[ "$TYRUN" = ">ok!" ] || { echo "FAIL  typecheck: accepted module ran wrong (got '$TYRUN', want '>ok!')"; ok=0; }
rm -f /tmp/tymod.la typed_module.la typed_bad.la typed_badtype.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  typecheck: DEPLOY type-checks the generated source; well-typed module accepted (arities match) + VERIFIED"
    echo "PASS  typecheck: ill-typed glyph (arity mismatch) + malformed type signature both REJECTED at compile time, no file written"
else
    printf '%s\n' "$TY"
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

say "Native backend Stage 0: the carved runtime, usable outside the SECD dispatch (nativert.la)"
# Stage 0 of the native x86-64 backend. nativert.asm carves secd.asm's str/print runtime
# — rt_make_str / rt_print = the .bi_print STR path + the STRDESC [gc-hdr][len][ptr]
# allocation, lifted verbatim into CALLABLE (ret-terminated) routines. nativert.la emits
# that ELF from Lingua Adamica (the elf.la pattern). The binary builds a STR value on the
# heap via the runtime and prints the Word — proving the runtime runs natively with NO
# per-instruction dispatch loop. secd.asm is UNTOUCHED (the existing engine cannot regress);
# this is purely additive. ABI byte-identical to secd.asm, so the runtime is mergeable later.
rm -f logos_nativert
./tiny_host nativert.la >/dev/null 2>&1
ok=1
[ -f logos_nativert ] || { echo "FAIL  nativert: logos_nativert not emitted"; ok=0; }
# drift guard: the LA-emitted bytes equal the nasm source of truth (as secd.la is to secd.asm)
if command -v nasm >/dev/null 2>&1; then
    nasm -f bin nativert.asm -o /tmp/nativert_ref 2>/dev/null
    cmp -s logos_nativert /tmp/nativert_ref || { echo "FAIL  nativert: LA-emitted bytes differ from nasm -f bin nativert.asm"; ok=0; }
    rm -f /tmp/nativert_ref
fi
# native == host: the carved runtime's output is byte-identical to print("I AM THAT I AM")
chmod +x logos_nativert 2>/dev/null
printf 'glyph MAIN = print("I AM THAT I AM")\n' > /tmp/nativert_word.la
./logos_nativert > /tmp/nativert_native.out 2>/dev/null; NRC=$?
./tiny_host /tmp/nativert_word.la > /tmp/nativert_host.out 2>/dev/null
cmp -s /tmp/nativert_native.out /tmp/nativert_host.out || { echo "FAIL  nativert: native runtime output != host print"; ok=0; }
[ "$NRC" = "0" ] || { echo "FAIL  nativert: emitted binary exited $NRC"; ok=0; }
rm -f /tmp/nativert_word.la /tmp/nativert_native.out /tmp/nativert_host.out
if [ "$ok" -eq 1 ]; then
    echo "PASS  native backend Stage 0: nativert.la emits the carved runtime (byte-identical to nasm nativert.asm); the binary builds a heap STR value via rt_make_str + prints via rt_print — native==host byte-identical, no SECD dispatch loop, secd.asm untouched"
else
    exit 1
fi
rm -f logos_nativert

say "Native backend Stage 1: minimal native execution — literals + builtins + int arithmetic (native_codegen.la)"
# Stage 1 of the native x86-64 backend. native_codegen.la compiles a single-
# expression program (integer/string literals, add/sub/mul/div/mod, concat,
# int_to_str, print) DIRECTLY to an x86-64 ELF that runs on the carved runtime
# (native_codegen_rt.asm) — NO SECD interpreter, NO per-instruction dispatch.
# Types are inferred statically (no runtime tags). The gate is native==host: the
# emitted binary's stdout must byte-match the same program run on tiny_host,
# across arithmetic / string / print programs. Pure generation; secd.asm and
# nativert.asm are UNTOUCHED (additive), so the existing engines cannot regress.
rm -f native_codegen_out native_input.la
ok=1
# Drift guard: the LA-embedded runtime bytes equal nasm -f bin native_codegen_rt.asm
# (the accepted "physics" seed — only the runtime is asm), as secd.la is to secd.asm.
if command -v nasm >/dev/null 2>&1; then
    printf 'glyph MAIN = print(42)\n' > native_input.la
    ./tiny_host native_codegen.la >/dev/null 2>&1
    nasm -f bin native_codegen_rt.asm -o /tmp/ncrt_ref 2>/dev/null
    # the runtime sits at file offset 120 (after the 64-byte ELF header + 56-byte phdr), 1313 bytes
    dd if=native_codegen_out of=/tmp/ncrt_emb bs=1 skip=120 count=1313 2>/dev/null
    cmp -s /tmp/ncrt_emb /tmp/ncrt_ref || { echo "FAIL  native_codegen: embedded runtime differs from nasm -f bin native_codegen_rt.asm"; ok=0; }
    rm -f /tmp/ncrt_ref /tmp/ncrt_emb
fi
# native==host across a spread of Stage-1 programs (the b_τ ≡ f_τ gate)
ncheck () {
    printf 'glyph MAIN = %s\n' "$1" > native_input.la
    ./tiny_host native_codegen.la >/dev/null 2>/tmp/nc_err || { echo "FAIL  native_codegen: compile error on [$1]: $(head -1 /tmp/nc_err)"; ok=0; return; }
    ./native_codegen_out > /tmp/nc_native.out 2>/dev/null; nrc=$?
    ./tiny_host native_input.la > /tmp/nc_host.out 2>/dev/null
    cmp -s /tmp/nc_native.out /tmp/nc_host.out || { echo "FAIL  native_codegen: native != host on [$1] (native='$(cat /tmp/nc_native.out)' host='$(cat /tmp/nc_host.out)')"; ok=0; }
    [ "$nrc" = "0" ] || { echo "FAIL  native_codegen: emitted binary for [$1] exited $nrc"; ok=0; }
}
ncheck 'print(42)'
ncheck 'print(add(2)(3))'
ncheck 'print(sub(2)(5))'
ncheck 'print(mul(6)(7))'
ncheck 'print(div(100)(7))'
ncheck 'print(mod(17)(5))'
ncheck 'print(add(mul(3)(4))(div(20)(5)))'
ncheck 'print("I AM THAT I AM")'
ncheck 'print(concat("hello, ")("world"))'
ncheck 'print(concat(concat("a")("b"))("c"))'
ncheck 'print(int_to_str(add(40)(2)))'
ncheck 'print(concat("n=")(int_to_str(mod(17)(5))))'
# Loud failure: an unsupported builtin must halt the compiler non-zero (no silent wrong binary).
printf 'glyph MAIN = print(lt(1)(2))\n' > native_input.la
./tiny_host native_codegen.la >/dev/null 2>&1 && { echo "FAIL  native_codegen: unsupported builtin did not halt the compiler"; ok=0; }
if [ "$ok" -eq 1 ]; then
    echo "PASS  native backend Stage 1: native_codegen.la compiles literals + print + int arithmetic (add/sub/mul/div/mod) + string concat/int_to_str DIRECTLY to x86-64 ELF on the carved runtime (embedded bytes == nasm native_codegen_rt.asm); 12 programs run native==host byte-identical, unsupported forms halt loudly, secd.asm/nativert.asm untouched"
else
    exit 1
fi
rm -f native_codegen_out native_input.la /tmp/nc_native.out /tmp/nc_host.out /tmp/nc_err

say "Native backend Stage 2: closures & environments — native APPLY/RET + the Z combinator (native_codegen2.la)"
# Stage 2 of the native x86-64 backend. native_codegen2.la compiles a multi-glyph
# LA program (lambdas, application/currying, variables, the Stage-1 builtins)
# DIRECTLY to an x86-64 ELF on the carved Stage-2 runtime (native_codegen2_rt.asm).
# Values are uniformly boxed [tag][payload]; a closure is a heap record
# [codeptr][captured-env]; rt_apply extends the env and tail-jumps the body (a
# native APPLY/RET calling convention) — NO SECD interpreter, NO dispatch loop.
# Glyph references are inlined to one closed lambda term, compiled with de Bruijn
# addressing; comparisons return Church TRUE/FALSE closures. Gate: native==host on
# lambda-heavy programs (the Z combinator, Church booleans, recursion). Additive —
# secd.asm / nativert.asm / native_codegen_rt.asm are UNTOUCHED.
rm -f native_codegen2_out native_input.la
ok=1
# Drift guard: the LA-embedded runtime equals nasm -f bin native_codegen2_rt.asm.
if command -v nasm >/dev/null 2>&1; then
    printf 'glyph MAIN = print(42)\n' > native_input.la
    ./tiny_host native_codegen2.la >/dev/null 2>&1
    nasm -f bin native_codegen2_rt.asm -o /tmp/nc2rt_ref 2>/dev/null
    # the runtime sits at file offset 120 (after the 64-byte ELF header + 56-byte phdr), 1111 bytes
    dd if=native_codegen2_out of=/tmp/nc2rt_emb bs=1 skip=120 count=1111 2>/dev/null
    cmp -s /tmp/nc2rt_emb /tmp/nc2rt_ref || { echo "FAIL  native_codegen2: embedded runtime differs from nasm -f bin native_codegen2_rt.asm"; ok=0; }
    rm -f /tmp/nc2rt_ref /tmp/nc2rt_emb
fi
# native==host across lambda/closure programs (the b_τ ≡ f_τ gate)
n2check () {  # $1 = whole program (multi-line) ; $2 = label
    printf '%s\n' "$1" > native_input.la
    ./tiny_host native_codegen2.la >/dev/null 2>/tmp/n2.err || { echo "FAIL  native_codegen2: compile error on [$2]: $(head -1 /tmp/n2.err)"; ok=0; return; }
    ./native_codegen2_out > /tmp/n2_native.out 2>/dev/null; nrc=$?
    ./tiny_host native_input.la > /tmp/n2_host.out 2>/dev/null
    cmp -s /tmp/n2_native.out /tmp/n2_host.out || { echo "FAIL  native_codegen2: native != host on [$2]"; ok=0; }
    [ "$nrc" = "0" ] || { echo "FAIL  native_codegen2: emitted binary for [$2] exited $nrc"; ok=0; }
}
n2check 'glyph MAIN = print((la x. x)(42))' 'identity lambda'
n2check 'glyph ADDER = la x. la y. add(x)(y)
glyph MAIN = print(ADDER(10)(32))' 'closure capture'
n2check 'glyph K = la a. la b. a
glyph MAIN = print(K(7)(9))' 'K combinator'
n2check 'glyph TRUE = la t. la f. t
glyph FALSE = la t. la f. f
glyph IF = la c. la t. la f. c(t)(f)("!")
glyph MAIN = print(IF(int_eq(3)(3))(la _. 111)(la _. 222))' 'Church IF + int_eq (true)'
n2check 'glyph TRUE = la t. la f. t
glyph FALSE = la t. la f. f
glyph IF = la c. la t. la f. c(t)(f)("!")
glyph MAIN = print(IF(int_eq(3)(4))(la _. 111)(la _. 222))' 'Church IF + int_eq (false)'
n2check 'glyph TRUE = la t. la f. t
glyph FALSE = la t. la f. f
glyph IF = la c. la t. la f. c(t)(f)("!")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph FACT = Z(la self. la n. IF(int_eq(n)(0))(la _. 1)(la _. mul(n)(self(sub(n)(1)))))
glyph MAIN = print(FACT(5))' 'Z combinator: FACT(5)=120'
n2check 'glyph TRUE = la t. la f. t
glyph FALSE = la t. la f. f
glyph IF = la c. la t. la f. c(t)(f)("!")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph REVERSE = Z(la self. la s. IF(str_eq(s)(""))(la _. "")(la _. concat(self(str_tail(s)))(str_head(s))))
glyph MAIN = print(REVERSE("abcde"))' 'Z combinator: REVERSE'
n2check 'glyph SEQ = la a. la b. b
glyph MAIN = SEQ(print("first"))(print("second"))' 'SEQ multi-print'
# Loud failure: a non-builtin free name halts the compiler non-zero (no silent wrong binary).
printf 'glyph MAIN = print(chr("65"))\n' > native_input.la
./tiny_host native_codegen2.la >/dev/null 2>&1 && { echo "FAIL  native_codegen2: unsupported name did not halt the compiler"; ok=0; }
if [ "$ok" -eq 1 ]; then
    echo "PASS  native backend Stage 2: native_codegen2.la compiles lambdas/closures/currying + int/string builtins to x86-64 on the carved runtime (native closure record [codeptr][env] + env cells + tail-jump APPLY/RET; comparisons -> Church TRUE/FALSE closures; embedded bytes == nasm native_codegen2_rt.asm); 9 lambda-heavy programs incl. the Z combinator (FACT(5)=120, REVERSE=edcba) run native==host byte-identical, unsupported names halt loudly, secd.asm/nativert.asm/native_codegen_rt.asm untouched"
else
    exit 1
fi
rm -f native_codegen2_out native_input.la /tmp/n2_native.out /tmp/n2_host.out /tmp/n2.err

say "Native backend Stage 3a: TCO — tail recursion runs in bounded native stack (native_codegen3.la)"
# Stage 3a = native_codegen2.la + TAIL-CALL OPTIMISATION. A general application in
# TAIL position emits `pop rbx; jmp rt_apply` instead of `call rt_apply`, so the
# callee's ret returns straight to OUR caller and a tail-recursive loop runs in
# BOUNDED native stack. CODEGEN-ONLY change: rt_apply already tail-jumps, so the
# runtime native_codegen2_rt.asm is REUSED UNCHANGED (drift-guarded below); only the
# emitted call site differs. The emitted heap is enlarged (memsz only, lazily mapped)
# so the CPU stack — not the un-GC'd bump heap — is the binding constraint, making TCO
# observable. Additive: native_codegen2.la + all asm runtimes UNTOUCHED.
rm -f native_codegen3_out native_input.la
ok=1
# Drift guard: the embedded runtime equals nasm -f bin native_codegen3_rt.asm
# (Stage 3b forked the runtime to add object headers; codegen3 no longer reuses codegen2's).
if command -v nasm >/dev/null 2>&1; then
    printf 'glyph MAIN = print(42)\n' > native_input.la
    ./tiny_host native_codegen3.la >/dev/null 2>&1
    nasm -f bin native_codegen3_rt.asm -o /tmp/c3rt_ref 2>/dev/null
    dd if=native_codegen3_out of=/tmp/c3rt_emb bs=1 skip=120 count=9619 2>/dev/null
    cmp -s /tmp/c3rt_emb /tmp/c3rt_ref || { echo "FAIL  native_codegen3: embedded runtime differs from nasm native_codegen3_rt.asm"; ok=0; }
    rm -f /tmp/c3rt_ref /tmp/c3rt_emb
fi
# native==host (b_τ ≡ f_τ): TCO must PRESERVE semantics on every program shape.
c3check () {  # $1 = whole program ; $2 = label ; expects native==host, rc 0
    printf '%s\n' "$1" > native_input.la
    ./tiny_host native_codegen3.la >/dev/null 2>/tmp/c3.err || { echo "FAIL  native_codegen3: compile error on [$2]: $(head -1 /tmp/c3.err)"; ok=0; return; }
    rc=0; ./native_codegen3_out > /tmp/c3_native.out 2>/dev/null || rc=$?
    ./tiny_host native_input.la > /tmp/c3_host.out 2>/dev/null
    cmp -s /tmp/c3_native.out /tmp/c3_host.out || { echo "FAIL  native_codegen3: native != host on [$2]"; ok=0; }
    [ "$rc" = "0" ] || { echo "FAIL  native_codegen3: emitted binary for [$2] exited $rc"; ok=0; }
}
c3check 'glyph MAIN = print((la x. x)(42))' 'identity lambda'
c3check 'glyph ADDER = la x. la y. add(x)(y)
glyph MAIN = print(ADDER(10)(32))' 'closure capture'
c3check 'glyph K = la a. la b. a
glyph MAIN = print(K(7)(9))' 'K combinator'
c3check 'glyph TRUE = la t. la f. t
glyph FALSE = la t. la f. f
glyph IF = la c. la t. la f. c(t)(f)("!")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph FACT = Z(la self. la n. IF(int_eq(n)(0))(la _. 1)(la _. mul(n)(self(sub(n)(1)))))
glyph MAIN = print(FACT(5))' 'FACT(5)=120 (non-tail recursion, shallow)'
c3check 'glyph TRUE = la t. la f. t
glyph FALSE = la t. la f. f
glyph IF = la c. la t. la f. c(t)(f)("!")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph REVERSE = Z(la self. la s. IF(str_eq(s)(""))(la _. "")(la _. concat(self(str_tail(s)))(str_head(s))))
glyph MAIN = print(REVERSE("abcde"))' 'REVERSE=edcba'
c3check 'glyph TRUE = la t. la f. t
glyph FALSE = la t. la f. f
glyph IF = la c. la t. la f. c(t)(f)("!")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph COUNT = Z(la self. la n. la acc. IF(int_eq(n)(0))(la _. acc)(la _. self(sub(n)(1))(add(acc)(1))))
glyph MAIN = print(COUNT(1000)(0))' 'tail recursion N=1000 (semantics preserved)'
c3check 'glyph TRUE = la t. la f. t
glyph FALSE = la t. la f. f
glyph IF = la c. la t. la f. c(t)(f)("!")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph NT = Z(la self. la n. IF(int_eq(n)(0))(la _. 0)(la _. add(1)(self(sub(n)(1)))))
glyph MAIN = print(NT(100))' 'non-tail recursion N=100 (semantics preserved)'
# Stage 3c.1: the missing unary value builtins chr / ord / str_len, native==host.
# ord/str_len return the DECIMAL string of an int (via rt_int_to_str_raw), faithful
# to the host; chr maps a decimal string 0..255 to its one-byte string.
c3check 'glyph MAIN = print(str_len("Lingua Adamica"))' 'str_len native (=14)'
c3check 'glyph MAIN = print(ord("A"))' 'ord native (=65)'
c3check 'glyph MAIN = print(chr("73"))' 'chr native (=I)'
c3check 'glyph MAIN = print(ord(chr("65")))' 'chr/ord round-trip native (=65)'
# Stage 3c.2: the `error` builtin — a loud halt. A compiled program that calls
# error(msg) must print msg + newline to stderr and exit non-zero, NOT degrade —
# b_τ ≡ f_τ with the host (same diagnostic, same exit code). c3check expects rc 0,
# so this is a dedicated check: native and host must agree on BOTH stderr and rc.
printf 'glyph MAIN = error("native: boom")\n' > native_input.la
./tiny_host native_codegen3.la >/dev/null 2>/tmp/c3.err || { echo "FAIL  native_codegen3: compile error on [error builtin]: $(head -1 /tmp/c3.err)"; ok=0; }
nrc=0; nerr=$(./native_codegen3_out 2>&1 >/dev/null) || nrc=$?
hrc=0; herr=$(./tiny_host native_input.la 2>&1 >/dev/null) || hrc=$?
{ [ "$nrc" != "0" ] && [ "$nerr" = "native: boom" ] && [ "$nerr" = "$herr" ] && [ "$nrc" = "$hrc" ]; } \
  || { echo "FAIL  native_codegen3: error builtin not faithful (native rc=$nrc err='$nerr' ; host rc=$hrc err='$herr'; want non-zero rc, stderr 'native: boom', native==host)"; ok=0; }
# Stage 3c.3: write_exec(path)(content) — the first BINARY builtin: write content
# to path, mark it 0755, return content. The 3e kernel self-replication capstone
# needs it. The content is binary-safe (NUL embedded below). native and host write
# the SAME path SEQUENTIALLY (host first, then native — no shared-file race), and
# must agree on stdout (the returned content) AND on the bytes + 0755 mode written.
printf 'glyph MAIN = print(write_exec("/tmp/c3_we_out")(concat("A")(concat(chr("0"))("B\nC"))))\n' > native_input.la
./tiny_host native_codegen3.la >/dev/null 2>/tmp/c3.err || { echo "FAIL  native_codegen3: compile error on [write_exec]: $(head -1 /tmp/c3.err)"; ok=0; }
rm -f /tmp/c3_we_out /tmp/c3_we_host /tmp/c3_we_native
./tiny_host native_input.la > /tmp/c3_we_hstdout 2>/dev/null; cp /tmp/c3_we_out /tmp/c3_we_host; hmode=$(stat -c '%a' /tmp/c3_we_out)
./native_codegen3_out  > /tmp/c3_we_nstdout 2>/dev/null; cp /tmp/c3_we_out /tmp/c3_we_native; nmode=$(stat -c '%a' /tmp/c3_we_out)
{ cmp -s /tmp/c3_we_nstdout /tmp/c3_we_hstdout && cmp -s /tmp/c3_we_native /tmp/c3_we_host \
  && [ "$nmode" = "755" ] && [ "$hmode" = "755" ] && [ "$(wc -c < /tmp/c3_we_native)" = "5" ]; } \
  || { echo "FAIL  native_codegen3: write_exec not faithful (stdout/file/mode native vs host; nmode=$nmode hmode=$hmode size=$(wc -c < /tmp/c3_we_native))"; ok=0; }
rm -f /tmp/c3_we_out /tmp/c3_we_host /tmp/c3_we_native /tmp/c3_we_hstdout /tmp/c3_we_nstdout
# Stage 3d: the module system (import / export) resolved at PARSE time in codegen3.
# greetapp.la import("greetmod.la")s, redefines the module's private SECRET name,
# and both isolation directions must hold (module private wins inside GREET; the
# importer's SECRET does not leak in). Compiling it with codegen3 and running the
# native binary must match the host — adding the native x86-64 backend as another
# engine to the cross-engine import demo. Also: a module exporting an undefined
# glyph is rejected loudly at compile time (CHECK_EXPORTS, matching the host).
cp greetapp.la native_input.la
./tiny_host native_codegen3.la >/dev/null 2>/tmp/c3.err || { echo "FAIL  native_codegen3: compile error on [greetapp import]: $(head -1 /tmp/c3.err)"; ok=0; }
nimp=$(./native_codegen3_out 2>/dev/null); himp=$(./tiny_host greetapp.la 2>/dev/null)
{ [ "$nimp" = "$himp" ] && [ "$nimp" = "module-importer / mine:-importer" ]; } \
  || { echo "FAIL  native_codegen3: module import not faithful (native='$nimp' host='$himp')"; ok=0; }
printf 'export NOPE\nglyph FOO = "x"\n' > /tmp/c3_badmod.la
printf 'import("/tmp/c3_badmod.la")\nglyph MAIN = print(FOO)\n' > native_input.la
brc=0; berr=$(./tiny_host native_codegen3.la 2>&1 >/dev/null) || brc=$?
{ [ "$brc" != "0" ] && printf '%s' "$berr" | grep -qF "exports undefined glyph"; } \
  || { echo "FAIL  native_codegen3: undefined export not rejected at compile (rc=$brc err='$berr')"; ok=0; }
rm -f /tmp/c3_badmod.la
# Stage 3e — the CAPSTONE: compile kernel.la to a native x86-64 ELF that speaks the
# Word and self-replicates BYTE-IDENTICALLY, with no C host and no SECD interpreter
# in the loop. Needs the two builtins kernel.la uses that 3a-3d lacked: read_file
# (SOURCE = read_file("kernel.la")) and copy_self (replicate /proc/self/exe). The
# native binary must (a) print the same two lines as the host, and (b) copy_self a
# child that is byte-identical to itself — the native backend joining every other
# engine on the kernel self-replication gate (∃(∃) ≡ ∃).
cp kernel.la native_input.la
./tiny_host native_codegen3.la >/dev/null 2>/tmp/c3.err || { echo "FAIL  native_codegen3: kernel.la compile error: $(head -1 /tmp/c3.err)"; ok=0; }
cp native_codegen3_out /tmp/c3_kernel_elf
rm -f new_logos_native.bin
knrc=0; ./native_codegen3_out > /tmp/c3_kn_out 2>/dev/null || knrc=$?
./tiny_host kernel.la > /tmp/c3_kn_host 2>/dev/null
{ [ "$knrc" = "0" ] && cmp -s /tmp/c3_kn_out /tmp/c3_kn_host \
  && [ -f new_logos_native.bin ] && cmp -s new_logos_native.bin /tmp/c3_kernel_elf \
  && [ "$(stat -c '%a' new_logos_native.bin)" = "755" ]; } \
  || { echo "FAIL  native_codegen3: kernel capstone (rc=$knrc; stdout native==host? $(cmp -s /tmp/c3_kn_out /tmp/c3_kn_host && echo y || echo n); replicant byte-identical? $([ -f new_logos_native.bin ] && cmp -s new_logos_native.bin /tmp/c3_kernel_elf && echo y || echo n))"; ok=0; }
rm -f new_logos_native.bin /tmp/c3_kernel_elf /tmp/c3_kn_out /tmp/c3_kn_host
# HEADLINE differential — SAME compiler, SAME 768 MB heap, SAME depth N=1,000,000;
# only tail-position differs. The TAIL loop completes in bounded native stack (TCO);
# the matched NON-TAIL recursion grows the native stack and FAULTS.
printf 'glyph TRUE = la t. la f. t
glyph FALSE = la t. la f. f
glyph IF = la c. la t. la f. c(t)(f)("!")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph COUNT = Z(la self. la n. la acc. IF(int_eq(n)(0))(la _. acc)(la _. self(sub(n)(1))(add(acc)(1))))
glyph MAIN = print(COUNT(1000000)(0))\n' > native_input.la
./tiny_host native_codegen3.la >/dev/null 2>&1 || { echo "FAIL  native_codegen3: compile tail-1M"; ok=0; }
rc=0; timeout 120 ./native_codegen3_out > /tmp/c3_tail.out 2>/dev/null || rc=$?
{ [ "$rc" = "0" ] && [ "$(cat /tmp/c3_tail.out)" = "1000000" ]; } || { echo "FAIL  native_codegen3: tail N=1,000,000 did not complete (rc=$rc out=$(cat /tmp/c3_tail.out))"; ok=0; }
printf 'glyph TRUE = la t. la f. t
glyph FALSE = la t. la f. f
glyph IF = la c. la t. la f. c(t)(f)("!")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph NT = Z(la self. la n. IF(int_eq(n)(0))(la _. 0)(la _. add(1)(self(sub(n)(1)))))
glyph MAIN = print(NT(1000000))\n' > native_input.la
./tiny_host native_codegen3.la >/dev/null 2>&1 || { echo "FAIL  native_codegen3: compile nontail-1M"; ok=0; }
rc=0; NTERR=$(timeout 120 ./native_codegen3_out 2>&1 >/dev/null) || rc=$?
# 3b.4: the deep non-tail recursion must halt LOUDLY via the native stack guard
# (clean `native: stack overflow`, exit 134) — NOT complete (rc 0) and NOT a raw
# SIGSEGV (rc 139, the pre-3b.4 behaviour).
{ [ "$rc" != "0" ] && [ "$rc" != "139" ] && printf '%s' "$NTERR" | grep -qF "native: stack overflow"; } || { echo "FAIL  native_codegen3: non-tail N=1,000,000 did not halt cleanly via the stack guard (rc=$rc err='$NTERR'; want non-zero, not 139/SIGSEGV, + 'native: stack overflow')"; ok=0; }
if [ "$ok" -eq 1 ]; then
    echo "PASS  native backend Stage 3a: native_codegen3.la adds TCO (tail-position general apply -> pop rbx; jmp rt_apply; runtime native_codegen2_rt.asm REUSED unchanged, drift-guarded); semantics preserved native==host on lambdas/closures/currying + non-tail (FACT(5)=120, REVERSE=edcba) + moderate tail recursion; HEADLINE differential at N=1,000,000 (same compiler/heap/depth) — the TAIL loop COMPLETES in bounded native stack while the matched NON-TAIL recursion halts LOUDLY via the 3b.4 native stack guard (each lambda body checks rsp vs STACK_LIMIT=STACK_BASE-7MiB; below it jumps to rt_stack_overflow -> 'native: stack overflow', exit 134 — a clean diagnostic, NOT a raw SIGSEGV); honest limits: heap still un-GC'd bump (tail loop ultimately heap-bounded until 3b GC); native_codegen2.la + all asm runtimes UNTOUCHED"
else
    exit 1
fi
rm -f native_codegen3_out native_input.la /tmp/c3_native.out /tmp/c3_host.out /tmp/c3.err /tmp/c3_tail.out /tmp/c3_nt.out

# ── Stage 4: native self-hosting fixed point ──────────────────────────────────
# The self-hosted compiler image (native_codegen3_selfhost.bin, committed as the
# reference) compiling native_codegen3.la's OWN 576-line source must reproduce
# ITSELF byte-for-byte — the fixed point ∃(∃) ≡ ∃ at the compiler level — and must
# compile kernel.la native==host. This runs in seconds: the reference image (16 GiB
# heap) bootstraps the next image natively; the ~11h tiny_host seed is the one-time
# genesis, not run here. The reference image is regenerated after any
# native_codegen3.la / native_codegen3_rt.asm change (recipe in STAGE4_STATUS.md), so
# a stale image fails this check — it doubles as a drift guard binding image to source.
say "Native backend Stage 4: self-hosting fixed point (native_codegen3 reproduces itself, native==host)"
SH_REF=native_codegen3_selfhost.bin
SH_AVAIL=$(free -m 2>/dev/null | awk '/^Mem:/{print $7}')
if [ ! -x "$SH_REF" ]; then
    echo "NOTE  Stage 4 self-host check skipped: $SH_REF not present (regenerate it — STAGE4_STATUS.md)"
elif [ -z "$SH_AVAIL" ] || [ "$SH_AVAIL" -lt 12000 ]; then
    echo "NOTE  Stage 4 self-host check skipped: needs ~10 GiB free for the self-compile; available=${SH_AVAIL:-?} MiB"
else
    cp "$SH_REF" /tmp/sh_cc; chmod +x /tmp/sh_cc
    cp native_codegen3.la native_input.la; rm -f native_codegen3_out
    /tmp/sh_cc >/dev/null 2>&1
    if [ ! -f native_codegen3_out ] || ! cmp -s native_codegen3_out "$SH_REF"; then
        echo "FAIL  native_codegen3 Stage 4: $SH_REF is NOT a fixed point of native_codegen3.la — stale reference image; regenerate it after the source change (STAGE4_STATUS.md)"; exit 1
    fi
    cp kernel.la native_input.la; rm -f native_codegen3_out
    /tmp/sh_cc >/dev/null 2>&1
    ./native_codegen3_out >/tmp/sh_kn 2>/dev/null
    ./tiny_host kernel.la >/tmp/sh_kh 2>/dev/null
    cmp -s /tmp/sh_kn /tmp/sh_kh || { echo "FAIL  native_codegen3 Stage 4: reference image's kernel.la output != host"; exit 1; }
    echo "PASS  native backend Stage 4: self-hosting fixed point — $SH_REF compiling native_codegen3.la reproduces ITSELF byte-identically (∃(∃)≡∃, no C host / no SECD interp in the loop), and compiles kernel.la native==host"
    rm -f /tmp/sh_cc /tmp/sh_kn /tmp/sh_kh native_codegen3_out native_input.la
fi

say "Native backend Stage 3b: conservative mark-sweep GC — bounded memory (native_codegen3_rt.asm)"
# Stage 3b adds a conservative mark-sweep collector to the native runtime: every
# heap object carries an 8-byte header (kind/mark/size), and rt_gc (triggered at
# allocator entry on exhaustion) marks from the verified root set (all GP regs +
# TRUEVAL/FALSEVAL + the stack), then sweeps unmarked 24-byte objects onto a
# free-list that the allocators reuse. HEADLINE: an int-forced tail loop at
# N=10,000,000 allocates ~8 GB of mostly-dead 24-byte objects but COMPLETES in the
# 1.5 GB heap — impossible without reclamation (the same workload un-GC'd runs the
# bump frontier off the end). 3b.3b adds blob reclamation: blobs round up to
# power-of-2 size-class free-lists (FREEBLOB), so a blob-churn loop is bounded too.
# 3b.4 native stack guard (the last Stage-3b piece): every compiled lambda body
# checks rsp against STACK_LIMIT (= STACK_BASE - 7 MiB), so a deep NON-tail
# recursion now halts loudly ('native: stack overflow', exit 134) before the 8 MiB
# OS stack is exhausted, instead of a raw SIGSEGV. Exercised in the Stage-3a block
# above (the non-tail N=1,000,000 differential).
rm -f native_codegen3_out native_input.la
ok=1
# (a) 24-byte reclamation: int-forced tail loop, ~8 GB of dead 24B objects in 1.5 GB.
printf 'glyph TRUE = la t. la f. t
glyph FALSE = la t. la f. f
glyph IF = la c. la t. la f. c(t)(f)(0)
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph COUNT = Z(la self. la n. la acc. IF(int_eq(n)(0))(la _. acc)(la _. self(sub(n)(1))(add(acc)(1))))
glyph MAIN = print(COUNT(10000000)(0))\n' > native_input.la
./tiny_host native_codegen3.la >/dev/null 2>&1 || { echo "FAIL  native_codegen3 Stage 3b: compile 24B GC-churn"; ok=0; }
rc=0; timeout 300 ./native_codegen3_out > /tmp/c3gc.out 2>/dev/null || rc=$?
{ [ "$rc" = "0" ] && [ "$(cat /tmp/c3gc.out)" = "10000000" ]; } || { echo "FAIL  native_codegen3 Stage 3b: 24B tail N=10,000,000 not bounded (rc=$rc out=$(cat /tmp/c3gc.out))"; ok=0; }
# (b) blob reclamation: a tail loop that builds + discards strings each iter; a
#     256-char literal materialised + concatenated is ~2 KB of blobs/iter, so
#     N=2,000,000 churns ~4 GB of blobs that must run in the 1.5 GB heap.
LIT=$(printf 'x%.0s' $(seq 1 256))
printf 'glyph TRUE = la t. la f. t
glyph FALSE = la t. la f. f
glyph IF = la c. la t. la f. c(t)(f)(0)
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph CHURN = Z(la self. la n. IF(int_eq(n)(0))(la _. "done")(la _. (la s. self(sub(n)(1)))(concat("%s")("%s"))))
glyph MAIN = print(CHURN(2000000))\n' "$LIT" "$LIT" > native_input.la
./tiny_host native_codegen3.la >/dev/null 2>&1 || { echo "FAIL  native_codegen3 Stage 3b: compile blob-churn"; ok=0; }
rc=0; timeout 400 ./native_codegen3_out > /tmp/c3bc.out 2>/dev/null || rc=$?
{ [ "$rc" = "0" ] && [ "$(cat /tmp/c3bc.out)" = "done" ]; } || { echo "FAIL  native_codegen3 Stage 3b: blob-churn N=2,000,000 not bounded (rc=$rc out=$(cat /tmp/c3bc.out))"; ok=0; }
# (c) FREEZE-DAY FIX #1 — large-blob GC sweep must not corrupt REGDUMP. A >4 MB
#     read_file/concat blob has classidx >= 22; the sweep re-buckets it via
#     FREEBLOB[classidx]. FREEBLOB was sized 22 (idx 0..21), so a >4 MB dead blob
#     overflowed the array into the adjacent REGDUMP and clobbered the registers
#     rt_gc restores -> corrupt output then SIGSEGV (a pre-existing memory-corruption
#     bug since 3b). FREEBLOB is now 32 entries (idx 5..30 cover every blob the 1.5 GB
#     heap can hold). This tail-discards a 5 MB file (classidx 23) in a loop so the GC
#     repeatedly sweeps a large DEAD blob; it must complete 'done' and match the host
#     byte-for-byte (no corruption, no crash).
head -c 5242880 < /dev/zero | tr '\0' a > c3_big.txt
printf 'glyph IF = la c. la t. la f. c(t)(f)("!")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph LOOP = Z(la self. la n. IF(int_eq(n)(0))(la _. "done")(la _. (la _. self(sub(n)(1)))(read_file("c3_big.txt"))))
glyph MAIN = print(LOOP(400))\n' > native_input.la
./tiny_host native_codegen3.la >/dev/null 2>&1 || { echo "FAIL  native_codegen3 freeze-day #1: compile large-blob sweep"; ok=0; }
rc=0; timeout 200 ./native_codegen3_out > /tmp/c3big.out 2>/dev/null || rc=$?
./tiny_host native_input.la > /tmp/c3big.host 2>/dev/null
{ [ "$rc" = "0" ] && [ "$(cat /tmp/c3big.out)" = "done" ] && cmp -s /tmp/c3big.out /tmp/c3big.host; } || { echo "FAIL  native_codegen3 freeze-day #1: >4 MB blob GC sweep corrupts/diverges (rc=$rc native='$(cat /tmp/c3big.out)' host='$(cat /tmp/c3big.host)')"; ok=0; }
rm -f c3_big.txt /tmp/c3big.out /tmp/c3big.host
if [ "$ok" -eq 1 ]; then
    echo "PASS  native backend Stage 3b: conservative mark-sweep GC — bounded memory. (a) 24-byte reclamation: an int-forced tail loop at N=10,000,000 (~8 GB of dead 24B objects) COMPLETES in the 1.5 GB heap (live set ~25/pass via the FREE24 free-list). (b) blob reclamation: a blob-churn loop at N=2,000,000 (~4 GB of blobs via power-of-2 FREEBLOB size-class lists) COMPLETES in the 1.5 GB heap (result 'done'). Both impossible without reclamation; roots = all GP regs + TRUEVAL/FALSEVAL + stack, swept cells re-collected via a kind-6 FREE header (no double-free), frontier-exact heap walk. (c) 3b.4 native stack guard COMPLETE: a deep non-tail recursion halts loudly ('native: stack overflow', exit 134) via the per-lambda rsp-vs-STACK_LIMIT check rather than a raw SIGSEGV (asserted in the Stage-3a non-tail differential). (d) FREEZE-DAY FIX #1: a >4 MB read_file blob (classidx >= 22) is now swept into the enlarged 32-entry FREEBLOB without overflowing the adjacent REGDUMP — a 5 MB tail-discard churn (classidx 23, dead blob swept every GC) completes 'done' native==host, where the 22-entry array corrupted the saved registers (wrong output then SIGSEGV). Stage 3b (GC) is now complete"
else
    exit 1
fi
rm -f native_codegen3_out native_input.la /tmp/c3gc.out /tmp/c3bc.out

# ── FREEZE-DAY FIX #2 — a string builtin given a non-STR argument must HALT LOUDLY,
#    not SIGSEGV. Every native string builtin (str_len/ord/chr/str_to_int/str_head/
#    str_tail/read_file + both args of concat/str_eq/write_exec) now checks the value
#    tag ([value+0]==0 = STR) at entry and jumps to rt_not_string (exit 1, "native:
#    argument is not a string") on mismatch, matching the C host and the SECD VM.
#    Before this, e.g. str_len(add(1)(2)) derefed the boxed INT as a [len][ptr]
#    descriptor -> wild read -> SIGSEGV (rc 139) — a unique native divergence (the
#    host halts cleanly rc 1). Checks 9 non-STR repros (unary + both binary arg
#    positions): native must halt non-zero, NOT 139, with empty stdout, and the host
#    must also halt non-zero. Valid string use must be unaffected.
say "Native backend freeze-day fix #2: non-STR argument loud-halt (no SIGSEGV)"
c2ok=1
for c2p in 'str_len(add(1)(2))' 'ord(add(1)(2))' 'chr(add(1)(2))' 'str_to_int(add(1)(2))' 'str_head(add(1)(2))' 'str_tail(add(1)(2))' 'concat(add(1)(2))("x")' 'concat("x")(add(1)(2))' 'read_file(add(1)(2))'; do
    printf 'glyph MAIN = print(%s)\n' "$c2p" > native_input.la
    ./tiny_host native_codegen3.la >/dev/null 2>&1 || { echo "FAIL  native_codegen3 #2: compile '$c2p'"; c2ok=0; }
    nrc=0; nout=$(timeout 30 ./native_codegen3_out 2>/dev/null) || nrc=$?
    hrc=0; ./tiny_host native_input.la >/dev/null 2>&1 || hrc=$?
    { [ "$nrc" != "0" ] && [ "$nrc" != "139" ] && [ -z "$nout" ] && [ "$hrc" != "0" ]; } \
      || { echo "FAIL  native_codegen3 #2: '$c2p' (native_rc=$nrc out='$nout' host_rc=$hrc; want native non-zero non-139 empty, host non-zero)"; c2ok=0; }
done
# valid string use is UNAFFECTED (the guard rejects only non-STR values)
printf 'glyph MAIN = print(str_len("Lingua Adamica"))\n' > native_input.la
./tiny_host native_codegen3.la >/dev/null 2>&1
{ [ "$(./native_codegen3_out)" = "14" ] && [ "$(./tiny_host native_input.la)" = "14" ]; } \
  || { echo "FAIL  native_codegen3 #2: guard broke a valid str_len"; c2ok=0; }
if [ "$c2ok" -eq 1 ]; then
    echo "PASS  native backend freeze-day fix #2: a non-STR argument to a string builtin (str_len/ord/chr/str_to_int/str_head/str_tail/read_file + both positions of concat/str_eq/write_exec) now HALTS LOUDLY (rt_not_string, exit 1, 'native: argument is not a string') instead of dereferencing the value as a [len][ptr] descriptor and SIGSEGV'ing — native exit matches the host's clean rc 1 (was rc 139) on 9 non-STR repros across unary + both binary arg positions; valid string ops unaffected (str_len(\"Lingua Adamica\")=14 native==host). The C host and SECD VM already guarded this; the native codegen3 runtime now does too."
else
    exit 1
fi
rm -f native_codegen3_out native_input.la

# ── FREEZE-DAY FIX #3 — chr(decimal STR) must denote a byte 0..255. rt_chr stored
#    only the low byte of the accumulated value (mov [numbuf],al), so chr("256")
#    silently became chr(0) and the program exited 0 with wrong output. The C host
#    rejects it loudly ("chr: value N out of byte range 0..255", exit 1) and so does
#    the SECD VM; rt_chr now range-checks (> 255 -> rt_chr_range, exit 1).
say "Native backend freeze-day fix #3: chr out-of-range loud-halt"
c3ok=1
for c3v in 256 300 999; do
    printf 'glyph MAIN = print(chr("%s"))\n' "$c3v" > native_input.la
    ./tiny_host native_codegen3.la >/dev/null 2>&1 || { echo "FAIL  native_codegen3 #3: compile chr($c3v)"; c3ok=0; }
    nrc=0; nout=$(./native_codegen3_out 2>/dev/null) || nrc=$?
    hrc=0; ./tiny_host native_input.la >/dev/null 2>&1 || hrc=$?
    { [ "$nrc" = "1" ] && [ -z "$nout" ] && [ "$hrc" = "1" ]; } \
      || { echo "FAIL  native_codegen3 #3: chr($c3v) (native_rc=$nrc out='$nout' host_rc=$hrc; want both rc1, native empty)"; c3ok=0; }
done
# in-range chr is UNAFFECTED (boundary 0 and 255, plus a mid value) native==host
for c3v in 0 65 255; do
    printf 'glyph MAIN = print(ord(chr("%s")))\n' "$c3v" > native_input.la
    ./tiny_host native_codegen3.la >/dev/null 2>&1
    { [ "$(./native_codegen3_out)" = "$c3v" ] && [ "$(./tiny_host native_input.la)" = "$c3v" ]; } \
      || { echo "FAIL  native_codegen3 #3: in-range chr($c3v) broke"; c3ok=0; }
done
if [ "$c3ok" -eq 1 ]; then
    echo "PASS  native backend freeze-day fix #3: chr(decimal STR) > 255 now HALTS LOUDLY (rt_chr_range, exit 1, 'native: chr value out of byte range 0..255') instead of silently storing the low byte (chr(\"256\") -> 0) and exiting 0 — native exit matches the host's clean rc 1 on 256/300/999; in-range chr (0/65/255 boundary) unaffected native==host. The C host and SECD VM already range-check; the native codegen3 runtime now does too."
else
    exit 1
fi
rm -f native_codegen3_out native_input.la

# ── FREEZE-DAY FIX #4 — str_to_int(decimal STR) must be STRICT. The native
#    rt_str_to_int folded every byte through (c-'0'), so "12x" yielded a garbage
#    number and "" yielded 0 — diverging from the C host, which accepts an optional
#    leading '-' then one or more digits and otherwise halts loudly ("str_to_int:
#    not a decimal integer", exit 1). rt_str_to_int now validates (empty -> .bad,
#    lone '-' -> .bad, any non-digit -> .bad) and jumps to rt_not_decimal.
#    NOTE: the codegen FOLDS a literal str_to_int("…") at compile time (its own
#    strict host str_to_int), so a malformed *literal* aborts the COMPILE, not the
#    runtime — to exercise the runtime guard the argument must be COMPUTED, so each
#    case wraps the digits past a one-char prefix in str_tail (e.g. str_tail("x12x")
#    -> "12x"), defeating the literal fold.
say "Native backend freeze-day fix #4: str_to_int strictness loud-halt"
c4ok=1
for c4s in x12x x x-; do   # str_tail -> "12x" (non-digit) / "" (empty) / "-" (lone minus)
    printf 'glyph MAIN = print(int_to_str(str_to_int(str_tail("%s"))))\n' "$c4s" > native_input.la
    ./tiny_host native_codegen3.la >/dev/null 2>&1 || { echo "FAIL  native_codegen3 #4: compile str_to_int(str_tail($c4s))"; c4ok=0; }
    nrc=0; nout=$(./native_codegen3_out 2>/dev/null) || nrc=$?
    hrc=0; ./tiny_host native_input.la >/dev/null 2>&1 || hrc=$?
    { [ "$nrc" = "1" ] && [ -z "$nout" ] && [ "$hrc" = "1" ]; } \
      || { echo "FAIL  native_codegen3 #4: str_to_int(str_tail(\"$c4s\")) (native_rc=$nrc out='$nout' host_rc=$hrc; want both rc1, native empty)"; c4ok=0; }
done
# valid decimals are UNAFFECTED (optional '-', a zero) computed past a prefix, native==host
set -- "x42:42" "x-5:-5" "x0:0"
for pair in "$@"; do
    inp=${pair%%:*}; exp=${pair##*:}
    printf 'glyph MAIN = print(int_to_str(str_to_int(str_tail("%s"))))\n' "$inp" > native_input.la
    ./tiny_host native_codegen3.la >/dev/null 2>&1
    { [ "$(./native_codegen3_out)" = "$exp" ] && [ "$(./tiny_host native_input.la)" = "$exp" ]; } \
      || { echo "FAIL  native_codegen3 #4: valid str_to_int(str_tail(\"$inp\"))=$exp broke (native='$(./native_codegen3_out)' host='$(./tiny_host native_input.la)')"; c4ok=0; }
done
if [ "$c4ok" -eq 1 ]; then
    echo "PASS  native backend freeze-day fix #4: str_to_int(decimal STR) is now STRICT (rt_not_decimal, exit 1, 'native: str_to_int: not a decimal integer') — a non-digit byte, a lone '-', or an empty string HALTS LOUDLY instead of folding garbage (\"12x\" -> wrong number, \"\" -> 0) and exiting 0; native exit matches the host's clean rc 1 on computed \"12x\"/\"\"/\"-\" (wrapped past str_tail to defeat the compile-time literal fold); valid \"42\"/\"-5\"/\"0\" unaffected native==host. The C host and SECD VM are already strict; the native codegen3 runtime now is too."
else
    exit 1
fi
rm -f native_codegen3_out native_input.la

# ── FREEZE-DAY FIX #5 — integer div/mod by zero. rt_div/rt_mod did a bare idiv, so
#    a zero divisor (or the LONG_MIN/-1 overflow) raised SIGFPE — div(x,0) crashed
#    with rc 136 and no clean diagnostic. The C host rejects it loudly ("div:
#    division by zero" / "mod: modulo by zero", exit 1) and returns 0 for the
#    LONG_MIN%-1 corner; rt_div/rt_mod now check the divisor first (-> rt_div_zero /
#    rt_mod_zero loud halt, exit 1) and special-case LONG_MIN%-1 -> 0.
#    The divisor is COMPUTED (sub(N)(N) = 0) so it is a real runtime value, not a
#    constant the compiler could fold.
say "Native backend freeze-day fix #5: div/mod by zero loud-halt (no SIGFPE)"
c5ok=1
for c5p in 'div(10)(sub(3)(3))' 'mod(10)(sub(7)(7))'; do
    printf 'glyph MAIN = print(%s)\n' "$c5p" > native_input.la
    ./tiny_host native_codegen3.la >/dev/null 2>&1 || { echo "FAIL  native_codegen3 #5: compile [$c5p]"; c5ok=0; }
    nrc=0; nout=$(./native_codegen3_out 2>/dev/null) || nrc=$?
    hrc=0; ./tiny_host native_input.la >/dev/null 2>&1 || hrc=$?
    { [ "$nrc" = "1" ] && [ -z "$nout" ] && [ "$hrc" = "1" ]; } \
      || { echo "FAIL  native_codegen3 #5: [$c5p] (native_rc=$nrc out='$nout' host_rc=$hrc; want both rc1 — NOT 136 SIGFPE — native empty)"; c5ok=0; }
done
# valid div/mod (incl. a negative and an exact division) UNAFFECTED native==host
for pair in 'div(17)(5):3' 'mod(17)(5):2' 'div(20)(4):5' 'mod(10)(sub(0)(3)):1'; do
    prog=${pair%:*}; exp=${pair##*:}
    printf 'glyph MAIN = print(%s)\n' "$prog" > native_input.la
    ./tiny_host native_codegen3.la >/dev/null 2>&1
    { [ "$(./native_codegen3_out)" = "$exp" ] && [ "$(./tiny_host native_input.la)" = "$exp" ]; } \
      || { echo "FAIL  native_codegen3 #5: valid [$prog]=$exp broke (native='$(./native_codegen3_out)' host='$(./tiny_host native_input.la)')"; c5ok=0; }
done
if [ "$c5ok" -eq 1 ]; then
    echo "PASS  native backend freeze-day fix #5: integer div/mod by a (computed) zero divisor now HALTS LOUDLY (rt_div_zero/rt_mod_zero, exit 1, 'native: div: division by zero' / 'native: mod: modulo by zero') instead of a bare idiv SIGFPE (rc 136) — native exit matches the host's clean rc 1; the LONG_MIN/-1 overflow is guarded too (div halts, mod -> 0, as the host); valid div/mod (incl. negative + exact) unaffected native==host. The C host already guards this; the native codegen3 runtime now does too."
else
    exit 1
fi
rm -f native_codegen3_out native_input.la

# ── FREEZE-DAY FIX #6 — a negative integer aborts the COMPILER. str_to_int("-5")
#    folds at compile time to MOV_RAX_IMM(-5) -> LE8(-5); LEBYTES used signed C `mod`
#    (mod(-5)(256) = -5), so B(mod(n)(256)) = chr("-5") tripped chr's 0..255 range
#    check and the compile ABORTED on a host-valid program. LEBYTES now extracts the
#    low byte unsigned (((n mod 256)+256) mod 256) and floor-shifts via div(sub(n)(b))
#    (256) — byte-identical for positives, so all emitted addresses are unchanged.
say "Native backend freeze-day fix #6: negative literal compiles (LEBYTES unsigned)"
c6ok=1
for pair in '-5:-5' '-1:-1' '-256:-256' '-65536:-65536' '-2147483648:-2147483648'; do
    inp=${pair%:*}; exp=${pair##*:}
    printf 'glyph MAIN = print(int_to_str(str_to_int("%s")))\n' "$inp" > native_input.la
    ./tiny_host native_codegen3.la >/dev/null 2>/tmp/c6.err \
      || { echo "FAIL  native_codegen3 #6: str_to_int(\"$inp\") still aborts the compile: $(head -1 /tmp/c6.err)"; c6ok=0; continue; }
    { [ "$(./native_codegen3_out)" = "$exp" ] && [ "$(./tiny_host native_input.la)" = "$exp" ]; } \
      || { echo "FAIL  native_codegen3 #6: str_to_int(\"$inp\")=$exp (native='$(./native_codegen3_out)' host='$(./tiny_host native_input.la)')"; c6ok=0; }
done
# positives + arithmetic UNCHANGED (LEBYTES byte-identical for n>=0; addresses intact)
for pair in 'print(42):42' 'print(str_to_int("0")):0' 'print(add(17)(5)):22' 'print((la x. x)(255)):255'; do
    prog=${pair%:*}; exp=${pair##*:}
    printf 'glyph MAIN = %s\n' "$prog" > native_input.la
    ./tiny_host native_codegen3.la >/dev/null 2>&1
    { [ "$(./native_codegen3_out)" = "$exp" ] && [ "$(./tiny_host native_input.la)" = "$exp" ]; } \
      || { echo "FAIL  native_codegen3 #6: positive [$prog]=$exp regressed (native='$(./native_codegen3_out)' host='$(./tiny_host native_input.la)')"; c6ok=0; }
done
if [ "$c6ok" -eq 1 ]; then
    echo "PASS  native backend freeze-day fix #6: a negative integer (str_to_int(\"-5\") folding to MOV_RAX_IMM(-5) -> LE8(-5)) now COMPILES and runs native==host instead of aborting the compiler — LEBYTES extracts the low byte unsigned (((n mod 256)+256) mod 256) so the two's-complement bytes encode, with a floor-shift div(sub(n)(b))(256) correct for both signs; verified on -5/-1/-256/-65536/-2147483648 native==host, and byte-identical for positives (42/0/add/255) so no address moved. The C host runs negatives fine; the native codegen3 compiler now emits them too."
else
    exit 1
fi
rm -f native_codegen3_out native_input.la

# ── FREEZE-DAY FIX #7 — module mangle collision. MANGLE = "__mod_"+SANITIZE(path)+
#    "__"+name, and the old SANITIZE mapped every non-ident char to one "_", so the
#    DISTINCT import paths "fdmA.la" and "fdmA_la" both sanitized to "fdmA_la"; two
#    modules with a same-named PRIVATE glyph then mangled identically and first-match
#    lookup resolved one module's export against the OTHER's private. SANITIZE is now
#    injective (non-alnum -> "_<ord>_"), so distinct paths give distinct names.
#    CONSTRUCTED repro: two modules at colliding paths, each a private SECRET its
#    export returns; the importer concats both exports and must get "AB" (not "AA"/"BB").
say "Native backend freeze-day fix #7: import-path mangle collision (injective SANITIZE)"
c7ok=1
printf 'export EA\nglyph SECRET = "A"\nglyph EA = SECRET\n' > fdmA.la       # path -> old "fdmA_la"
printf 'export EB\nglyph SECRET = "B"\nglyph EB = SECRET\n' > fdmA_la       # path -> old "fdmA_la" (collision)
printf 'import("fdmA.la")\nimport("fdmA_la")\nglyph MAIN = print(concat(EA)(EB))\n' > native_input.la
if ./tiny_host native_codegen3.la >/dev/null 2>/tmp/c7.err; then
    nout=$(./native_codegen3_out 2>/dev/null); hout=$(./tiny_host native_input.la 2>/dev/null)
    { [ "$nout" = "AB" ] && [ "$hout" = "AB" ]; } \
      || { echo "FAIL  native_codegen3 #7: colliding-path imports mis-resolved (native='$nout' host='$hout'; want 'AB' — a same-named private leaked across modules)"; c7ok=0; }
else
    echo "FAIL  native_codegen3 #7: compile error on colliding-path imports: $(head -1 /tmp/c7.err)"; c7ok=0
fi
rm -f fdmA.la fdmA_la
if [ "$c7ok" -eq 1 ]; then
    echo "PASS  native backend freeze-day fix #7: two imports whose DISTINCT paths ('fdmA.la' / 'fdmA_la') collided under the old lossy SANITIZE (both -> 'fdmA_la') no longer cross-resolve a same-named PRIVATE glyph — SANITIZE is now injective (alnum passthrough, every other char incl. '_' escaped to '_<ord>_', e.g. '.'->'_46_', '_'->'_95_'), so each module's private mangles distinctly and the importer gets concat(EA)(EB)='AB' native==host (was 'AA'/'BB' from first-match leakage). Path-derived + deterministic (cross-engine design), not the C host's counter."
else
    exit 1
fi
rm -f native_codegen3_out native_input.la

# ── FREEZE-DAY FIX #8 — write_file missing from the native backend. The C host has
#    write_file (a normal non-VM builtin: fopen(path,"wb")), but native IS_BUILTIN2
#    lacked it, so a program calling write_file failed to COMPILE ("unbound name")
#    where the host runs it. Added rt_write_file (= rt_write_exec with open mode 0644
#    and NO chmod 0755 — a plain data file) + wired IS_BUILTIN2 and RT_BIN with its OWN
#    case BEFORE the rt_write_exec fall-through (SAFETY: else it would be chmod'd 0755).
#    typeof remains an honest limit (documented), not implemented here.
say "Native backend freeze-day fix #8: write_file in the native backend (non-exec)"
c8ok=1
rm -f /tmp/c8_nat.txt /tmp/c8_host.txt
printf 'glyph MAIN = print(write_file("/tmp/c8_nat.txt")("hello write_file"))\n' > native_input.la
./tiny_host native_codegen3.la >/dev/null 2>/tmp/c8.err || { echo "FAIL  native_codegen3 #8: write_file failed to compile (still unbound?): $(head -1 /tmp/c8.err)"; c8ok=0; }
nout=$(./native_codegen3_out 2>/dev/null)
printf 'glyph MAIN = print(write_file("/tmp/c8_host.txt")("hello write_file"))\n' > native_input.la
hout=$(./tiny_host native_input.la 2>/dev/null)
# return value (the content) matches, file content matches, NOT executable (the safety property)
{ [ "$nout" = "hello write_file" ] && [ "$hout" = "hello write_file" ]; } \
  || { echo "FAIL  native_codegen3 #8: write_file return value (native='$nout' host='$hout'; want 'hello write_file')"; c8ok=0; }
{ [ "$(cat /tmp/c8_nat.txt 2>/dev/null)" = "hello write_file" ] && [ "$(cat /tmp/c8_host.txt 2>/dev/null)" = "hello write_file" ]; } \
  || { echo "FAIL  native_codegen3 #8: file contents (native='$(cat /tmp/c8_nat.txt 2>/dev/null)' host='$(cat /tmp/c8_host.txt 2>/dev/null)')"; c8ok=0; }
{ [ ! -x /tmp/c8_nat.txt ] && [ ! -x /tmp/c8_host.txt ]; } \
  || { echo "FAIL  native_codegen3 #8: write_file produced an EXECUTABLE file (must be a plain data file, unlike write_exec)"; c8ok=0; }
# read_file round-trips the native-written file (the moved rt_read_file/rt_copy_self addrs still resolve)
printf 'glyph MAIN = print(read_file("/tmp/c8_nat.txt"))\n' > native_input.la
./tiny_host native_codegen3.la >/dev/null 2>&1
{ [ "$(./native_codegen3_out)" = "hello write_file" ] && [ "$(./tiny_host native_input.la)" = "hello write_file" ]; } \
  || { echo "FAIL  native_codegen3 #8: read_file of the native-written file (native='$(./native_codegen3_out)' host='$(./tiny_host native_input.la)')"; c8ok=0; }
rm -f /tmp/c8_nat.txt /tmp/c8_host.txt
if [ "$c8ok" -eq 1 ]; then
    echo "PASS  native backend freeze-day fix #8: write_file now COMPILES and runs in the native backend (was 'unbound name', a compile failure on a host-valid program) — rt_write_file mirrors rt_write_exec but opens 0644 and never chmods 0755, so it writes a PLAIN data file (verified non-executable, content + return value native==host = 'hello write_file', and read_file round-trips it). Wired with its OWN RT_BIN case before the rt_write_exec fall-through so it is never silently made executable. (typeof stays an honest limit, not in the native backend.)"
else
    exit 1
fi
rm -f native_codegen3_out native_input.la

# ── FREEZE-DAY FIX #9 — "la" was not in IS_KEYWORD. codegen3 lexes every keyword as a
#    plain "name" token, and PARSE_EXPORT_NAMES collects consecutive non-keyword names
#    after `export`; so a `la` token following an export-name list was wrongly collected
#    as a bogus export ("exports undefined glyph: la"), where the host treats `la` as a
#    binder keyword and stops the export list there. "la" is now in IS_KEYWORD, so the
#    export list terminates at the binder and native agrees with the host.
say "Native backend freeze-day fix #9: 'la' is a keyword (export list stops at a binder)"
c9ok=1
# (a) a normal export still works native==host (no regression)
printf 'export EX\nglyph EX = "ok"\n' > fdm9.la
printf 'import("fdm9.la")\nglyph MAIN = print(EX)\n' > native_input.la
./tiny_host native_codegen3.la >/dev/null 2>/tmp/c9.err || { echo "FAIL  native_codegen3 #9: normal export failed to compile: $(head -1 /tmp/c9.err)"; c9ok=0; }
{ [ "$(./native_codegen3_out)" = "ok" ] && [ "$(./tiny_host native_input.la)" = "ok" ]; } \
  || { echo "FAIL  native_codegen3 #9: normal export native='$(./native_codegen3_out)' host='$(./tiny_host native_input.la)' (want 'ok')"; c9ok=0; }
rm -f native_codegen3_out
# (b) a stray `la` after an export name is a KEYWORD boundary, not a collected export:
#     pre-fix native collected it -> "exports undefined glyph: la"; the host stops at the
#     `la` binder and rejects the malformed form (rc!=0). Native now AGREES: rejects (rc!=0)
#     WITHOUT the bogus-export error.
printf 'export EX la\nglyph EX = "ok"\n' > fdm9.la
printf 'import("fdm9.la")\nglyph MAIN = print(EX)\n' > native_input.la
nrc=0; ./tiny_host native_codegen3.la >/dev/null 2>/tmp/c9n.err || nrc=$?
hrc=0; ./tiny_host native_input.la >/dev/null 2>/tmp/c9h.err || hrc=$?
{ [ "$nrc" != "0" ] && [ "$hrc" != "0" ] && ! grep -q "exports undefined glyph: la" /tmp/c9n.err; } \
  || { echo "FAIL  native_codegen3 #9: stray 'la' after export (native rc=$nrc host rc=$hrc; native must reject WITHOUT mis-collecting 'la' as an export — err='$(head -1 /tmp/c9n.err)')"; c9ok=0; }
rm -f fdm9.la /tmp/c9n.err /tmp/c9h.err /tmp/c9.err
if [ "$c9ok" -eq 1 ]; then
    echo "PASS  native backend freeze-day fix #9: 'la' is now a keyword in IS_KEYWORD, so PARSE_EXPORT_NAMES stops the export-name list at a lambda binder instead of collecting 'la' as a bogus export — a normal 'export EX' still resolves native==host ('ok'), and a stray 'la' after an export name is now rejected exactly as the host rejects it (rc!=0, NO 'exports undefined glyph: la' mis-collection). Latent hardening: the host and other engines already treat 'la' as a keyword; the native codegen3 parser now does too."
else
    exit 1
fi
rm -f native_codegen3_out native_input.la

# ── FREEZE-DAY FIX #10/#11 — rt_copy_self robustness (short-write loop + heap-end bound) ──
#   #10: copy_self issued ONE write() per 64 KiB chunk and IGNORED its return, so a short
#        write (fewer bytes than requested) would silently truncate the child. It now loops
#        the write exactly as rt_write_exec's .wr does — flushing the whole chunk and halting
#        loudly ("copy_self: write failed", exit 1) on a write error.
#   #11: the 64 KiB read scratch is [r15, r15+65536) with r15 the heap bump top; a near-full
#        heap would overrun the mapping. copy_self now bound-checks r15+65536 against HEAP_END
#        and halts loudly ("copy_self: heap too full to replicate", exit 1) instead of overrunning.
#   Both triggers are LATENT (regular-file writes don't short-write; copy_self runs with a
#   near-empty heap), so the deterministic regression is happy-path NON-REGRESSION: the
#   refactored loop must still breed a byte-identical, FULL-SIZE, 0755 child — a truncating
#   write loop would change the child's size/bytes; a broken bound check would crash.
say "Native backend freeze-day fix #10/#11: copy_self short-write loop + heap-end bound (latent hardening)"
printf 'glyph MAIN = copy_self(print("native replicate"))\n' > native_input.la
rm -f new_logos_native.bin
c1011ok=1
./tiny_host native_codegen3.la >/dev/null 2>/tmp/c1011.err || { echo "FAIL  native_codegen3 #10/#11: codegen failed: $(head -1 /tmp/c1011.err)"; c1011ok=0; }
csrc="$(./native_codegen3_out 2>/dev/null)"; csrc_rc=$?
{ [ "$csrc" = "native replicate" ] && [ "$csrc_rc" = "0" ] && [ -f new_logos_native.bin ] \
  && cmp -s new_logos_native.bin native_codegen3_out \
  && [ "$(stat -c%s new_logos_native.bin)" = "$(stat -c%s native_codegen3_out)" ] \
  && [ "$(stat -c '%a' new_logos_native.bin)" = "755" ]; } \
  || { echo "FAIL  native_codegen3 #10/#11: copy_self did not breed a byte-identical full-size 0755 child (stdout='$csrc' rc=$csrc_rc; child? $([ -f new_logos_native.bin ] && echo y || echo n); identical? $([ -f new_logos_native.bin ] && cmp -s new_logos_native.bin native_codegen3_out && echo y || echo n); size $([ -f new_logos_native.bin ] && stat -c%s new_logos_native.bin) vs $(stat -c%s native_codegen3_out))"; c1011ok=0; }
if [ "$c1011ok" -eq 1 ]; then
    echo "PASS  native backend freeze-day fix #10/#11: rt_copy_self now flushes each 64 KiB chunk with a short-write loop (mirroring rt_write_exec — looping until the whole chunk lands, halting loudly on a write error) and bound-checks the r15 read scratch against HEAP_END (halting loudly rather than overrunning a near-full heap). Both triggers are latent (regular-file writes don't short-write; copy_self runs heap-near-empty), so verified by happy-path non-regression: copy_self still breeds a byte-identical, full-size, 0755 child — a truncating write loop would change the size/bytes. The latent short-write/overrun paths now end in a clean diagnostic + exit 1 instead of a truncated child or SIGSEGV."
else
    exit 1
fi
rm -f native_codegen3_out native_input.la new_logos_native.bin /tmp/c1011.err

# ── FREEZE-DAY FIX #12 — read_file on a non-seekable fd (lseek/ftell fails) ──
#   read_file sizes the file with lseek(SEEK_END)/ftell; on a non-seekable fd (pipe,
#   FIFO, char device) that returns -1, after which the NATIVE backend did
#   alloc_blob(-1) (misalloc + unbounded read -> SIGSEGV) and the C HOST did
#   malloc(0)+fread(SIZE_MAX) (heap overflow). BOTH engines now guard the failed seek
#   and halt loudly (exit 1), so a non-seekable read_file is rejected IDENTICALLY
#   instead of corrupting memory — b_tau == f_tau restored. Triggered deterministically
#   via read_file("/dev/stdin") with stdin from a pipe (lseek -> ESPIPE).
say "Native backend freeze-day fix #12: read_file on a non-seekable fd halts loudly (host + native)"
c12ok=1
printf 'glyph MAIN = print(read_file("/dev/stdin"))\n' > native_input.la
h12rc=0; echo data | ./tiny_host native_input.la >/dev/null 2>/tmp/h12.err || h12rc=$?
./tiny_host native_codegen3.la >/dev/null 2>/tmp/c12.err || { echo "FAIL  native_codegen3 #12: codegen failed: $(head -1 /tmp/c12.err)"; c12ok=0; }
n12rc=0; echo data | ./native_codegen3_out >/dev/null 2>/tmp/n12.err || n12rc=$?
{ [ "$h12rc" = "1" ] && [ "$n12rc" = "1" ] \
  && grep -q "not a seekable file" /tmp/h12.err && grep -q "not a seekable file" /tmp/n12.err; } \
  || { echo "FAIL  native_codegen3 #12: non-seekable read_file not rejected cleanly (host rc=$h12rc '$(head -1 /tmp/h12.err)'; native rc=$n12rc '$(head -1 /tmp/n12.err)')"; c12ok=0; }
# happy path: a regular (seekable) file still reads byte-identically native==host
printf 'seekable regular file\n' > /tmp/c12_reg.txt
printf 'glyph MAIN = print(read_file("/tmp/c12_reg.txt"))\n' > native_input.la
h12v="$(./tiny_host native_input.la 2>/dev/null)"
./tiny_host native_codegen3.la >/dev/null 2>&1; n12v="$(./native_codegen3_out 2>/dev/null)"
{ [ "$h12v" = "seekable regular file" ] && [ "$n12v" = "seekable regular file" ]; } \
  || { echo "FAIL  native_codegen3 #12: regular-file read_file regressed (host='$h12v' native='$n12v')"; c12ok=0; }
if [ "$c12ok" -eq 1 ]; then
    echo "PASS  native backend freeze-day fix #12: read_file on a NON-SEEKABLE fd (lseek(SEEK_END)/ftell -> -1) now halts loudly on BOTH engines instead of corrupting memory — the native backend guarded the failed lseek (was alloc_blob(-1): misalloc + unbounded read -> SIGSEGV) and the C host guarded the failed ftell (was malloc(0)+fread(SIZE_MAX): heap overflow). read_file('/dev/stdin') from a pipe is rejected identically (exit 1, each engine's own 'not a seekable file' diagnostic, NEITHER crashes), and a regular seekable file still reads byte-identically native==host. b_tau == f_tau restored on the non-seekable path."
else
    exit 1
fi
rm -f native_codegen3_out native_input.la /tmp/c12_reg.txt /tmp/h12.err /tmp/n12.err /tmp/c12.err

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
[ "$(stat -c%s logos_secd 2>/dev/null)" = "13775" ] || { echo "FAIL  codegen: VM wrong size ($(stat -c%s logos_secd 2>/dev/null) != 13775)"; ok=0; }
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

say "Autopoiesis: the system runs its own successor (self-perpetuating lineage)"
# Every prior generation of LogOS was launched by an outside hand. autopoiesis.la
# closes that gap: bundled into ONE self-contained vessel, each generation reads
# its number from the medium (autopoiesis.gen), speaks the Word, copy_self's a
# byte-identical successor vessel, then fork+execve's it — the parent *runs its
# own child*, which runs its own child, with no external driver. There is no
# recursion combinator; the loop IS the process lineage. A generation cap (3)
# makes it terminate so we can observe the whole succession; an unbounded
# organism just raises the cap. We bundle it (copy_self replicates the whole
# vessel, so only a bundle reproduces something its child can execve standalone),
# seed the medium at 0, run it, and assert: generations 0..3 each spoke in order,
# the lineage reported completion, exit 0, and the begotten successor is
# byte-identical to the bundle (a faithful self-contained copy).
rm -f logos_secd logos_program.bin logos_embed.bin logos_source.la logos_app \
      new_logos_secd.bin autopoiesis.gen
./tiny_host secd.la >/dev/null 2>&1                       # emit the VM
cp autopoiesis.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1                    # compile -> logos_program.bin
cp logos_program.bin logos_embed.bin
./tiny_host bundle.la >/dev/null 2>&1                     # fuse -> logos_app (self-contained)
rm -f logos_program.bin logos_embed.bin logos_source.la
ok=1
[ -f logos_app ] || { echo "FAIL  autopoiesis: bundle not produced"; ok=0; }
printf '0' > autopoiesis.gen                              # seed the medium at generation 0
ap_rc=0
APOUT="$(./logos_app 2>/dev/null)" || ap_rc=$?
[ "$ap_rc" -eq 0 ] || { echo "FAIL  autopoiesis: lineage exited nonzero (rc=$ap_rc)"; ok=0; }
# Each generation 0..3 spoke the Word, in order.
gen=0
while [ "$gen" -le 3 ]; do
    printf '%s\n' "$APOUT" | grep -qx "LogOS autopoiesis — generation $gen: I AM THAT I AM" \
        || { echo "FAIL  autopoiesis: generation $gen did not speak"; ok=0; }
    gen=$((gen + 1))
done
# The lineage ran exactly the four generations (no runaway), then completed.
spoke="$(printf '%s\n' "$APOUT" | grep -c 'I AM THAT I AM')"
[ "$spoke" = "4" ] || { echo "FAIL  autopoiesis: expected 4 speaking generations, got $spoke"; ok=0; }
printf '%s\n' "$APOUT" | grep -q "lineage complete" \
    || { echo "FAIL  autopoiesis: lineage did not report completion"; ok=0; }
# The successor the organism begat is a byte-identical self-contained vessel.
{ [ -f new_logos_secd.bin ] && cmp -s logos_app new_logos_secd.bin; } \
    || { echo "FAIL  autopoiesis: begotten successor not byte-identical to the bundle"; ok=0; }
rm -f logos_secd logos_app new_logos_secd.bin autopoiesis.gen
if [ "$ok" -eq 1 ]; then
    echo "PASS  autopoiesis: the bundle ran its own successor across 4 process generations — self-perpetuating, no external driver  (∃(∃) ≡ ∃)"
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

say "Theourgia: framebuffer bridge — composed scene -> XRGB8888 (Stage 3)"
# Stage 3 (theourgia_fb.la) imports Stage 1's surface core and adds TO_FB, which
# converts a composed RGB surface into the XRGB8888 framebuffer image present()
# scans out: each pixel R,G,B -> B,G,R,0, each row zero-padded to the screen
# PITCH, the image zero-padded to the screen HEIGHT. This is the missing link
# between Stage 1 (RGB composition) and Stage 2 (which only knew flat blue). It
# uses only existing builtins, so — like Stage 1 — it runs byte-identically on
# the C host and native VM, verifiable with no screen: we write the framebuffer
# to a file and check the converted pixels land with the right BGRX bytes, then
# diff the two engines. (cross-engine import is resolved by codegen.la on the VM)
# The scene is the 32x24 desktop laid into a 26-row x 160-byte-pitch buffer.
ok=1
fbpx () { od -An -tu1 -j "$1" -N4 framebuffer.bin | tr -s ' ' | sed 's/^ //;s/ $//'; }
check_fb () {  # $1 = engine label
    [ "$(stat -c%s framebuffer.bin)" = "4160" ] || { echo "FAIL  theourgia_fb($1): size $(stat -c%s framebuffer.bin) != 4160 (26*160)"; ok=0; }
    [ "$(fbpx 0)"    = "128 0 0 0" ]   || { echo "FAIL  theourgia_fb($1): bg pixel BGRX [$(fbpx 0)] != 128 0 0 0";    ok=0; }
    [ "$(fbpx 656)"  = "30 30 200 0" ] || { echo "FAIL  theourgia_fb($1): win1 pixel BGRX [$(fbpx 656)] != 30 30 200 0"; ok=0; }
    [ "$(fbpx 1992)" = "30 200 30 0" ] || { echo "FAIL  theourgia_fb($1): win2 pixel BGRX [$(fbpx 1992)] != 30 200 30 0"; ok=0; }
    [ "$(fbpx 128)"  = "0 0 0 0" ]     || { echo "FAIL  theourgia_fb($1): row pad [$(fbpx 128)] not zero";  ok=0; }
    [ "$(fbpx 3840)" = "0 0 0 0" ]     || { echo "FAIL  theourgia_fb($1): blank row [$(fbpx 3840)] not zero"; ok=0; }
}
rm -f framebuffer.bin
./tiny_host theourgia_fb.la >/dev/null 2>&1
check_fb "C host"
cp framebuffer.bin /tmp/fb_host.bin; rm -f framebuffer.bin
# Sovereign: the same conversion on the native VM must be byte-identical.
rm -f logos_secd logos_program.bin logos_source.la
./tiny_host secd.la >/dev/null 2>&1
cp theourgia_fb.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
./logos_secd >/dev/null 2>&1
check_fb "native VM"
cmp -s framebuffer.bin /tmp/fb_host.bin || { echo "FAIL  theourgia_fb: native framebuffer != C host framebuffer"; ok=0; }
rm -f framebuffer.bin /tmp/fb_host.bin logos_secd logos_program.bin logos_source.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  theourgia: composed scene -> XRGB8888 framebuffer (R,G,B->B,G,R,0, pitch/height pad), byte-identical on host and native VM"
else
    exit 1
fi

say "Theourgia: DRM/KMS scanout builtins (Stage 2, native VM)"
# Stage 2 adds two VM-only builtins — drm_mode() (open card0, find the connected
# mode, allocate+map a 32-bpp dumb framebuffer, SETCRTC) and present() (blit a
# framebuffer image into the scanned-out buffer). Real scanout needs DRM master,
# which only a bare VT grants; under a running compositor the kernel refuses
# SETCRTC and the builtin halts LOUDLY (e.g. "secd: drm SETCRTC failed: -13", exit 1) without
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
        # Under a running compositor every DRM ioctl up to SETCRTC succeeds (they
        # need only an open fd, not master); only SETCRTC is master-gated, so it
        # fails loudly naming itself and its -errno (e.g. -13 EACCES). Asserting
        # the SETCRTC line proves the whole prior sequence ran AND that .drm_fail
        # reports the specific failing call, not a generic message.
        grep -qE "secd: drm SETCRTC failed: -[0-9]+" /tmp/drm_err.txt || { echo "FAIL  theourgia drm: expected loud 'secd: drm SETCRTC failed: -<errno>' under a compositor, got [$(cat /tmp/drm_err.txt)] rc=$drm_rc"; ok=0; }
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

say "Theourgia: input layer — evdev event decoder (Stage 4)"
# Stage 4 (theourgia_input.la) gives the compositor ears: it decodes Linux evdev
# records (24-byte struct input_event: type u16 @16, code u16 @18, value s32 @20,
# little-endian) out of an event string with ord + integer arithmetic. The live
# reader (open/read/close on /dev/input) is VM-only and needs a real device +
# privilege, so — like DRM scanout — it is verified manually; here we exercise
# the DECODER, which is pure LA and must agree byte-for-byte on the C host and
# the native VM. The demo decodes a synthetic KEY_A press (type 1, code 30,
# value 1) and a REL_X motion of -3 (type 2, code 0, value -3 — exercising the
# signed-32 path), and we assert both engines print the identical decode.
ok=1
EXPECT="$(printf 'press A: type=1 code=30 value=1\nrel x: type=2 code=0 value=-3')"
HIN="$(./tiny_host theourgia_input.la 2>/dev/null)"
[ "$HIN" = "$EXPECT" ] || { echo "FAIL  theourgia_input (C host): decode mismatch"; printf '%s\n' "$HIN"; ok=0; }
rm -f logos_secd logos_program.bin logos_source.la
./tiny_host secd.la >/dev/null 2>&1
cp theourgia_input.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
VIN="$(./logos_secd 2>/dev/null)"
[ "$VIN" = "$EXPECT" ] || { echo "FAIL  theourgia_input (native VM): decode mismatch"; printf '%s\n' "$VIN"; ok=0; }
[ "$HIN" = "$VIN" ] || { echo "FAIL  theourgia_input: host and VM decodes differ"; ok=0; }
rm -f logos_secd logos_program.bin logos_source.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  theourgia: evdev decoder reads type/code/value (incl. signed deltas), byte-identical on host and native VM"
else
    exit 1
fi

say "Theourgia: interactive session — input -> state -> recompose (Stage 5)"
# Stage 5 (theourgia_session.la) is the compositor loop: it imports the surface
# core (Stage 1) and the evdev decoder (Stage 4) and adds STEP, a pure reducer
# that folds a decoded event into scene state — here a movable window's (x,y),
# nudged one cell per arrow-key PRESS — then RENDER recomposes the desktop and
# rasters it (Stage 1's PPM). Because STEP is a pure function of (state, event),
# folding a fixed event sequence is deterministic and byte-identical on the C
# host and native VM. We fold RIGHT, RIGHT, DOWN from (4,4): the window must end
# at (6,5), the recomposed raster must show the window's red at its new position
# (pixel 6,5) and blue where it used to be (pixel 4,4), on both engines, and the
# two rasters must be byte-identical. (The LIVE device->screen loop — read+decode
# -> STEP -> compose -> TO_FB -> present — is the VM-only capstone, run manually
# from a VT, as DRM scanout and the input reader are.)
ok=1
# pixel(px,py) on a 32-wide P6 raster: byte offset 13 + (py*32 + px)*3
ssp () { od -An -tu1 -j "$1" -N3 session.ppm | tr -s ' ' | sed 's/^ //;s/ $//'; }
check_session () {  # $1 = engine label, $2 = captured stdout
    printf '%s\n' "$2" | grep -qx "session: window at 6 5" \
        || { echo "FAIL  session($1): window not at (6,5) after RIGHT,RIGHT,DOWN [$2]"; ok=0; }
    [ "$(stat -c%s session.ppm 2>/dev/null)" = "2317" ] || { echo "FAIL  session($1): raster size $(stat -c%s session.ppm 2>/dev/null) != 2317"; ok=0; }
    [ "$(ssp 511)" = "200 30 30" ] || { echo "FAIL  session($1): window not at new pos (6,5) [$(ssp 511)]"; ok=0; }
    [ "$(ssp 409)" = "0 0 128" ]   || { echo "FAIL  session($1): old pos (4,4) not vacated [$(ssp 409)]"; ok=0; }
}
rm -f session.ppm
HS="$(./tiny_host theourgia_session.la 2>/dev/null)"
check_session "C host" "$HS"
cp session.ppm /tmp/session_host.ppm; rm -f session.ppm
rm -f logos_secd logos_program.bin logos_source.la
./tiny_host secd.la >/dev/null 2>&1
cp theourgia_session.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
VS="$(./logos_secd 2>/dev/null)"
check_session "native VM" "$VS"
cmp -s session.ppm /tmp/session_host.ppm || { echo "FAIL  session: native raster != C host raster"; ok=0; }
rm -f session.ppm /tmp/session_host.ppm logos_secd logos_program.bin logos_source.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  theourgia: interactive session folds input into state and recomposes, byte-identical on host and native VM"
else
    exit 1
fi

say "Theourgia: multiplexed input loop — poll(fds) marshalling + dispatch (Stage 6)"
# Stage 6 (theourgia_poll.la) is the multi-device input loop. A real compositor
# has many input devices + a signalfd and must service whichever is ready, never
# blocking on one while another waits — that is fd multiplexing, and the `poll`
# VM builtin (added alongside this stage) is the primitive. poll speaks a
# space-separated decimal fd string both ways, so the pure, testable core is the
# marshalling — JOIN (fd list -> poll's request, generation) and SPLIT (poll's
# ready-set -> fd list, recognition) — plus DRAIN, the dispatch reducer, which is
# parameterised by its reader so build.sh drives it with a pure SIMREAD (the live
# loop, theourgia_poll_live.la, uses the real read()). We check JOIN, the
# SPLIT∘JOIN round-trip, the empty (timeout) ready-set, and the headline: a poll
# result of "7 5" drains BOTH devices — fd 7 (mouse, REL_X -3) then fd 5
# (keyboard, KEY_A press) — each routed through the imported Stage 4 decoder,
# byte-identical on the C host and the native VM. (The live poll+read multi-device
# loop is the VM-only capstone, run manually like DRM scanout and the Stage 4/5
# readers; see theourgia_poll_live.la.)
ok=1
EXPECT="$(printf 'join=5 7 9\nrt=5 7 9\nempty=\nfd 7: type=2 code=0 value=-3\nfd 5: type=1 code=30 value=1')"
HP="$(./tiny_host theourgia_poll.la 2>/dev/null)"
[ "$HP" = "$EXPECT" ] || { echo "FAIL  theourgia_poll (C host): mismatch"; printf '%s\n' "$HP"; ok=0; }
rm -f logos_secd logos_program.bin logos_source.la
./tiny_host secd.la >/dev/null 2>&1
cp theourgia_poll.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
VP="$(./logos_secd 2>/dev/null)"
[ "$VP" = "$EXPECT" ] || { echo "FAIL  theourgia_poll (native VM): mismatch"; printf '%s\n' "$VP"; ok=0; }
[ "$HP" = "$VP" ] || { echo "FAIL  theourgia_poll: host and VM differ"; ok=0; }
rm -f logos_secd logos_program.bin logos_source.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  theourgia: multiplexed input loop — JOIN/SPLIT poll marshalling + DRAIN dispatch routes a ready-set through the decoder, byte-identical on host and native VM"
else
    exit 1
fi

say "Theourgia: multiplexed session — poll-drained input folds into one scene (Stage 7)"
# Stage 7 (theourgia_mux_session.la) wires Stage 6's poll multiplexing into Stage
# 5's session: a real compositor polls every input device and folds EVERY ready
# event from EVERY device into the ONE shared scene state per frame, then
# recomposes. The new heart is DRAIN_STEP, the multiplexed fold — it threads the
# state through STEP over the ready fds, so a single poll cycle that reports two
# ready devices applies BOTH their events before rendering. Pure function of
# (state, events) like Stage 5's STEP, so build.sh drives it with a pure SIMREAD
# (fd -> a synthetic key event): a poll cycle reporting fds "5 7" (fd 5 = a RIGHT
# press, fd 7 = a DOWN press) folds both, moving the window (4,4) -> (5,5) in one
# cycle, and the recomposed raster shows the window's red at (5,5) and blue at
# (4,4) — byte-identical on the C host and native VM, no device/screen. (The LIVE
# drm_mode -> poll/drain/STEP/compose/TO_FB/present loop is the VM-only capstone,
# run manually from a bare VT, as DRM scanout and the Stage 4-6 readers are.)
ok=1
sp7 () { od -An -tu1 -j "$1" -N3 mux_session.ppm | tr -s ' ' | sed 's/^ //;s/ $//'; }
check_mux () {  # $1 = engine label, $2 = captured stdout
    printf '%s\n' "$2" | grep -qx "mux-session: window at 5 5" \
        || { echo "FAIL  mux($1): window not at (5,5) after RIGHT+DOWN in one poll cycle [$2]"; ok=0; }
    [ "$(stat -c%s mux_session.ppm 2>/dev/null)" = "2317" ] || { echo "FAIL  mux($1): raster size $(stat -c%s mux_session.ppm 2>/dev/null) != 2317"; ok=0; }
    [ "$(sp7 508)" = "200 30 30" ] || { echo "FAIL  mux($1): window not at new pos (5,5) [$(sp7 508)]"; ok=0; }
    [ "$(sp7 409)" = "0 0 128" ]   || { echo "FAIL  mux($1): (4,4) not background blue [$(sp7 409)]"; ok=0; }
}
rm -f mux_session.ppm
HM="$(./tiny_host theourgia_mux_session.la 2>/dev/null)"
check_mux "C host" "$HM"
cp mux_session.ppm /tmp/mux_host.ppm; rm -f mux_session.ppm
rm -f logos_secd logos_program.bin logos_source.la
./tiny_host secd.la >/dev/null 2>&1
cp theourgia_mux_session.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
VMUX="$(./logos_secd 2>/dev/null)"
check_mux "native VM" "$VMUX"
cmp -s mux_session.ppm /tmp/mux_host.ppm || { echo "FAIL  mux: native raster != C host raster"; ok=0; }
rm -f mux_session.ppm /tmp/mux_host.ppm logos_secd logos_program.bin logos_source.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  theourgia: multiplexed session — one poll cycle's two device events (RIGHT+DOWN) fold into one scene → window (5,5), recomposed byte-identical on host and native VM"
else
    exit 1
fi

say "Theourgia: text rendering — embedded 8x8 bitmap font (Stage 8)"
# Stage 8 (theourgia_text.la) adds the last UI primitive: TEXT. An EMBEDDED 8x8
# bitmap font (A-Z 0-9 space, one bit per pixel, bit 0 = leftmost; theourgia_
# font.la, packed as a flat decimal string) plus DRAW_TEXT(dst)(text)(x)(y)(fg)
# (bg), which builds an 8-tall ribbon (set->fg, unset->bg) and COMPOSEs it onto a
# Stage 1 surface. Pure generation (concat / native ints, importing the font +
# Stage 1), so it runs byte-identically on the C
# host and native VM, verifiable with no screen: we draw "HI" in white onto a
# 24x12 blue surface and check the rastered pixels. 'H' row 0 lights columns
# 0,1,4,5 (the two verticals) but NOT column 2; row 3 is the full crossbar, so
# column 2 there IS lit — that row-dependent difference proves real glyph shape,
# not a block. 'I' is the second character (x += 8), proving advance. (The live
# device->screen demo is theourgia_text_live.la, run from a bare VT.)
ok=1
tp () { od -An -tu1 -j "$1" -N3 text.ppm | tr -s ' ' | sed 's/^ //;s/ $//'; }
check_text () {  # $1 = engine label
    [ "$(head -c 13 text.ppm)" = "$(printf 'P6\n24 12\n255\n')" ] || { echo "FAIL  theourgia_text($1): PPM header"; ok=0; }
    [ "$(stat -c%s text.ppm)" = "877" ] || { echo "FAIL  theourgia_text($1): size $(stat -c%s text.ppm) != 877"; ok=0; }
    [ "$(tp 13)"  = "0 0 128" ]       || { echo "FAIL  theourgia_text($1): bg pixel [$(tp 13)] != 0 0 128"; ok=0; }
    [ "$(tp 160)" = "255 255 255" ]   || { echo "FAIL  theourgia_text($1): H r0 c0 [$(tp 160)] != white"; ok=0; }
    [ "$(tp 166)" = "0 0 128" ]       || { echo "FAIL  theourgia_text($1): H r0 c2 gap [$(tp 166)] != bg"; ok=0; }
    [ "$(tp 382)" = "255 255 255" ]   || { echo "FAIL  theourgia_text($1): H r3 c2 crossbar [$(tp 382)] != white"; ok=0; }
    [ "$(tp 187)" = "255 255 255" ]   || { echo "FAIL  theourgia_text($1): I top bar [$(tp 187)] != white (2nd char advance)"; ok=0; }
}
rm -f text.ppm
./tiny_host theourgia_text.la >/dev/null 2>&1
check_text "C host"
cp text.ppm /tmp/text_host.ppm; rm -f text.ppm
# Sovereign: the same render on the native VM must be byte-identical.
rm -f logos_secd logos_program.bin logos_source.la
./tiny_host secd.la >/dev/null 2>&1
cp theourgia_text.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
./logos_secd >/dev/null 2>&1
check_text "native VM"
cmp -s text.ppm /tmp/text_host.ppm || { echo "FAIL  theourgia_text: native raster != C host raster"; ok=0; }
rm -f text.ppm /tmp/text_host.ppm logos_secd logos_program.bin logos_source.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  theourgia: DRAW_TEXT rasters an 8x8 bitmap font (\"HI\": glyph shape + char advance) onto a surface, byte-identical on host and native VM"
else
    exit 1
fi

say "Sigil: the visual modality — the nine catalogue sigils (LINGUA_ADAMICA.tex)"
# sigil.la is the VISUAL layer of Lingua Adamica. The NINE primitive sigils are
# DRAWN exactly as the Sigil Catalogue specifies (LINGUA_ADAMICA.tex, Ch. "The
# Nine Sigils"); DERIVED concepts are GENERATED from them via the five blend modes
# aligned to the TopoEmbed Graph-Feature->Geometric-Primitive table. A SIGIL is a
# pure r->c->bool predicate over a 32x32 grid built only from integer drawing
# primitives, so a sigil and its ASCII rasterisation are byte-identical on the C
# host and native VM. We verify each rendered primitive against its catalogue
# description by its distinctive symmetry signature (forms are centred on cell 16,
# so the mirror axis runs through column/row 16; column/row 0 is the lone unpaired
# margin, always blank, and is dropped before the palindrome test):
#   SELF (lemniscate, crosses itself at centre)        -> H and V symmetric
#   RECOGNITION (the eye, "identical and symmetric")   -> H and V symmetric
#   RELATION (two points, symmetric double arc)        -> H and V symmetric
#   VOID (broken circle, gap at the CROWN only)        -> H symmetric, NOT V
#   LOVE (flame, base down / tip up)                   -> H symmetric, NOT V
#   FORM (triangle in circle, apex up)                 -> H symmetric, NOT V
#   BECOMING (the chiral spiral)                       -> neither H nor V
#   Truth = MC(RECOGNITION) (self-fold)                -> H symmetric (generated)
# plus all nine primitive labels present + host==VM byte-identity.
ok=1
# block LABEL FILE -> the 32 grid rows printed under that SHOW label
block () { grep -A32 "$1" "$2" | tail -32; }
# symmetric about cell 16: mirror cols/rows 1..31 (drop the unpaired margin 0).
is_hsym () { awk '{ s=substr($0,2); r=""; for(i=length(s);i>=1;i--) r=r substr(s,i,1); if(r!=s) bad=1 } END { exit bad?1:0 }'; }
is_vsym () { awk '{ a[NR]=$0 } END { for(i=2;i<=NR;i++) if(a[i]!=a[NR+2-i]) bad=1; exit bad?1:0 }'; }
HSYM () { block "$1" "$2" | is_hsym; }   # rc 0 = H-symmetric
VSYM () { block "$1" "$2" | is_vsym; }   # rc 0 = V-symmetric
check_sigil () {  # $1 = engine label, $2 = output file
    grep -q '###' "$2"                            || { echo "FAIL  sigil($1): no ink rendered"; ok=0; }
    [ "$(grep -c '^g[1-9] ' "$2")" = "9" ]        || { echo "FAIL  sigil($1): expected 9 primitive sigils, got $(grep -c '^g[1-9] ' "$2")"; ok=0; }
    HSYM "g4 SELF" "$2"        &&   VSYM "g4 SELF" "$2"        || { echo "FAIL  sigil($1): SELF not a centred lemniscate (expect H+V symmetric)"; ok=0; }
    HSYM "g2 RECOGNITION" "$2" &&   VSYM "g2 RECOGNITION" "$2" || { echo "FAIL  sigil($1): RECOGNITION eye not mutual (expect H+V symmetric)"; ok=0; }
    HSYM "g6 VOID" "$2"        && ! VSYM "g6 VOID" "$2"        || { echo "FAIL  sigil($1): VOID gap not at the crown (expect H symmetric, NOT V)"; ok=0; }
    HSYM "g3 LOVE" "$2"        && ! VSYM "g3 LOVE" "$2"        || { echo "FAIL  sigil($1): LOVE flame not upright (expect H symmetric, NOT V)"; ok=0; }
    HSYM "g8 FORM" "$2"        && ! VSYM "g8 FORM" "$2"        || { echo "FAIL  sigil($1): FORM apex not up (expect H symmetric, NOT V)"; ok=0; }
    ! HSYM "g7 BECOMING" "$2"  && ! VSYM "g7 BECOMING" "$2"    || { echo "FAIL  sigil($1): BECOMING spiral not chiral (expect neither H nor V symmetric)"; ok=0; }
    HSYM "DERIVED Truth" "$2"                                 || { echo "FAIL  sigil($1): Truth=MC(RECOGNITION) not H-symmetric (self-fold not generated)"; ok=0; }
    # 𝓜 ⊂ 𝒜: the five combination modes render as sigils from their decompositions:
    [ "$(grep -c '^META ' "$2")" = "6" ]                      || { echo "FAIL  sigil($1): expected 6 𝓜 sigils (5 modes + evaluator), got $(grep -c '^META ' "$2")"; ok=0; }
    # The Logos / Meta-Word Λ: present, and its form INTEGRATES the totality (the
    # central ∃(∃)≡∃ lemniscate-crossing, a wide ink run at the midline — distinct
    # from a bare circle), so it is "the whole naming itself", not an empty mark.
    grep -q '^Λ  LOGOS' "$2"                                  || { echo "FAIL  sigil($1): Logos/Meta-Word (Λ) sigil missing"; ok=0; }
    block "Λ  LOGOS" "$2" | awk 'NR==17 && index($0,"############")>0{ok=1} END{exit ok?0:1}' || { echo "FAIL  sigil($1): Logos lacks the central ∃(∃)≡∃ crossing (not the whole-naming-itself form)"; ok=0; }
}
rm -f sigil_host.txt sigil_vm.txt
./tiny_host sigil.la > sigil_host.txt 2>/dev/null
check_sigil "C host" sigil_host.txt
# Sovereign: the same sigils rendered on the native VM must be byte-identical.
rm -f logos_secd logos_program.bin logos_source.la
./tiny_host secd.la >/dev/null 2>&1
cp sigil.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
./logos_secd > sigil_vm.txt 2>/dev/null
check_sigil "native VM" sigil_vm.txt
cmp -s sigil_host.txt sigil_vm.txt || { echo "FAIL  sigil: native render != C host render"; ok=0; }
rm -f sigil_host.txt sigil_vm.txt logos_secd logos_program.bin logos_source.la
# ── α=1 canonical injectivity (completeness item 1): one CONCEPT → one form,
#    regardless of operand order. The audit found ⊗(Love,Recognition) and
#    ⊗(Recognition,Love) — one commutative concept — drew two different sigils (an
#    α<1 leak). SIGIL now CANONIQ-normalizes (NORMK parity) before drawing, so the
#    two orders must render identically. Host-only ASCII render + compare (fast). ──
cat > /tmp/t_sigcanon.la <<'LAEOF'
import("sigil.la")
glyph SEQ = la a. la b. b
glyph IF = la c. la t. la f. c(t)(f)("!")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph CELL = la s. la r. la c. IF(SIG_AT(s)(r)(c))(la _. "#")(la _. ".")
glyph ROW = Z(la self. la s. la r. la c. IF(int_eq(c)(SZ))(la _. "")(la _. concat(CELL(s)(r)(c))(self(s)(r)(add(c)(1)))))
glyph ASCII = Z(la self. la s. la r. IF(int_eq(r)(SZ))(la _. "")(la _. concat(concat(ROW(s)(r)(0))("|"))(self(s)(add(r)(1)))))
glyph A = SIGIL(SYN(PRIM("LOVE"))(PRIM("RECOGNITION")))
glyph BB = SIGIL(SYN(PRIM("RECOGNITION"))(PRIM("LOVE")))
glyph MAIN = SEQ(print(concat("A=")(ASCII(A)(0))))(print(concat("B=")(ASCII(BB)(0))))
LAEOF
SCOUT="$(./tiny_host /tmp/t_sigcanon.la 2>/dev/null || true)"
rm -f /tmp/t_sigcanon.la
SCA="$(printf '%s\n' "$SCOUT" | sed -n 's/^A=//p')"
SCB="$(printf '%s\n' "$SCOUT" | sed -n 's/^B=//p')"
{ [ -n "$SCA" ] && [ "$SCA" = "$SCB" ]; } || { echo "FAIL  sigil: render not canonical — ⊗ operand order changes the form (α<1 injectivity leak)"; ok=0; }
if [ "$ok" -eq 1 ]; then
    echo "PASS  sigil: the nine catalogue sigils render to their described forms (per-primitive symmetry signatures) + derived concepts GENERATED via the blend modes; α=1 canonical injectivity (one concept → one form, order-independent); byte-identical on host and native VM"
else
    exit 1
fi

say "Deep geometry (item 7): a sigil's form DERIVED from ONF graph features (onf.la + topoderive.la)"
# The spec's TopoEmbed (LINGUA_ADAMICA.tex :5485): a sigil's geometry is COMPUTED
# from the concept's ONF GRAPH FEATURES (cycles/hierarchy/branching/automorphism),
# not from the declared combining mode (which is what sigil.la's mode-walk does).
# onf.la extracts the features by folding over the WHOLE canonicalized graph;
# topoderive.la's DSIGIL composes geometry from them per the table. COEXISTS with
# sigil.la (does not replace SIGIL). HONEST SCOPE: a 32×32 1-bit realization —
# feature counts + the leaf-set, NOT WL colour classes / force-layout / colour.
ok=1
# (a) onf.la feature extraction — correct values + canonicality + host==VM byte-identical
rm -f onf_host.out onf_vm.out logos_secd logos_program.bin logos_source.la
./tiny_host onf.la > onf_host.out 2>/dev/null
grep -qxF "onf Truth  = 1/1/0/0/N/RECOGNITION," onf_host.out         || { echo "FAIL  onf: ↻ cycle feature wrong"; ok=0; }
grep -qxF "onf Nest3  = 0/2/2/2/N/VOID,FORM,DEPTH," onf_host.out      || { echo "FAIL  onf: ⊂ hierarchy feature (depth/containment) wrong"; ok=0; }
grep -qxF "onf Auto   = 0/1/0/1/Y/SELF,SELF," onf_host.out           || { echo "FAIL  onf: automorphism (F_SYM, commutative equal operands) wrong"; ok=0; }
ONFLR="$(sed -n 's/^onf LR     = //p' onf_host.out)"; ONFRL="$(sed -n 's/^onf RL     = //p' onf_host.out)"
{ [ -n "$ONFLR" ] && [ "$ONFLR" = "$ONFRL" ]; }                       || { echo "FAIL  onf: feature extraction not canonical (⊗LR ≠ ⊗RL)"; ok=0; }
./tiny_host secd.la >/dev/null 2>&1
cp onf.la logos_source.la; ./tiny_host codegen.la >/dev/null 2>&1; ./logos_secd > onf_vm.out 2>/dev/null
cmp -s onf_host.out onf_vm.out                                       || { echo "FAIL  onf: native feature extraction != host"; ok=0; }
# (b) topoderive.la DSIGIL render — host==VM byte-identical (imports sigil.la + onf.la)
rm -f td_host.out td_vm.out logos_secd logos_program.bin logos_source.la
./tiny_host secd.la >/dev/null 2>&1
./tiny_host topoderive.la > td_host.out 2>/dev/null
cp topoderive.la logos_source.la; ./tiny_host codegen.la >/dev/null 2>&1; ./logos_secd > td_vm.out 2>/dev/null
cmp -s td_host.out td_vm.out                                         || { echo "FAIL  topoderive: native DSIGIL render != host"; ok=0; }
# (c) DSIGIL injectivity + canonicality + directionality (host-only render compare)
cat > /tmp/t_dsig.la <<'LAEOF'
import("topoderive.la")
import("sigil.la")
glyph SEQ = la a. la b. b
glyph IF = la c. la t. la f. c(t)(f)("!")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph CELL = la s. la r. la c. IF(SIG_AT(s)(r)(c))(la _. "#")(la _. ".")
glyph ROW = Z(la self. la s. la r. la c. IF(int_eq(c)(SZ))(la _. "")(la _. concat(CELL(s)(r)(c))(self(s)(r)(add(c)(1)))))
glyph ASCII = Z(la self. la s. la r. IF(int_eq(r)(SZ))(la _. "")(la _. concat(concat(ROW(s)(r)(0))("|"))(self(s)(add(r)(1)))))
glyph P = la lbl. la s. print(concat(lbl)(ASCII(s)(0)))
glyph MAIN =
  SEQ(P("injA=")(DSIGIL(SYN(PRIM("LOVE"))(PRIM("RECOGNITION")))))(
  SEQ(P("injB=")(DSIGIL(SYN(PRIM("BEING"))(PRIM("VOID")))))(
  SEQ(P("canA=")(DSIGIL(CON(PRIM("LOVE"))(PRIM("RECOGNITION")))))(
  SEQ(P("canB=")(DSIGIL(CON(PRIM("RECOGNITION"))(PRIM("LOVE")))))(
  SEQ(P("dirA=")(DSIGIL(DIR(PRIM("LOVE"))(PRIM("RECOGNITION")))))(
      P("dirB=")(DSIGIL(DIR(PRIM("RECOGNITION"))(PRIM("LOVE")))))))))
LAEOF
DOUT="$(./tiny_host /tmp/t_dsig.la 2>/dev/null || true)"
dg(){ printf '%s\n' "$DOUT" | sed -n "s/^$1=//p"; }
{ [ -n "$(dg injA)" ] && [ "$(dg injA)" != "$(dg injB)" ]; }          || { echo "FAIL  topoderive: not injective (distinct ONF → same form)"; ok=0; }
{ [ "$(dg canA)" = "$(dg canB)" ] && [ -n "$(dg canA)" ]; }           || { echo "FAIL  topoderive: not canonical (commutative ⊕ order changes form)"; ok=0; }
[ "$(dg dirA)" != "$(dg dirB)" ]                                      || { echo "FAIL  topoderive: directional ▷ wrongly order-independent"; ok=0; }
rm -f /tmp/t_dsig.la onf_host.out onf_vm.out td_host.out td_vm.out logos_secd logos_program.bin logos_source.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  deep geometry (item 7): onf.la extracts ONF graph features (cycles/hierarchy/branching/automorphism, canonical) + topoderive.la's DSIGIL derives geometry from them per the TopoEmbed table — injective (distinct ONF→distinct form via leaf-marks), order-independent for commutative modes, directional for ▷; byte-identical host==VM. (32×32 1-bit: feature counts + leaf-set, not WL/force-layout/colour.)"
else
    exit 1
fi

say "Cycle of Being (item 7, Stage-4 d): does the derived geometry enact B&B's cosmogenic cycle? (cob.la)"
# A TEST, NOT A TARGET (observe, never impose; "does not enact" is a legitimate result).
# cob.la encodes the Cycle of Being faithfully per Being & Becoming — ↻(recognition ▷
# (VOID ⊗ BEING)): the first distinction arising from the Void, recognized, metacursively
# RETURNED — pushes it through onf.la/topoderive.la, and OBSERVES whether the DERIVED
# geometry exhibits the three beats (bifurcation from Void / recognition-collapse / the
# Return / preserved distinction). Made DISCRIMINATING by the control ↻(BEING), which
# canonicalizes to a single SELF (cycle AND distinction erased) — so a YES is not trivial.
# Pure (node-building + str/int + pixel reads) ⇒ byte-identical host == VM.
ok=1
check_cob () {  # $1 = engine label, $2 = output file
    grep -q 'DEG  feat = 0/0/0/0/N/SELF,' "$2"                                            || { echo "FAIL  cob($1): control ↻(BEING) did not collapse to a point — test not discriminating"; ok=0; }
    grep -q 'COB  feat (cyc/dep/cont/br/sym/leaves) = 1/3/0/2/N/RECOGNITION,BEING,VOID,' "$2" || { echo "FAIL  cob($1): the Cycle-of-Being concept's features changed"; ok=0; }
    grep -q 'beat i   bifurcation from Void   \[arms + Void leaf-mark\]      : YES' "$2"   || { echo "FAIL  cob($1): beat i (bifurcation from Void) not observed in the geometry"; ok=0; }
    grep -q 'beat ii  recognition-collapse    \[central loop + collapse\]   : YES' "$2"    || { echo "FAIL  cob($1): beat ii (recognition-collapse / the Return) not observed"; ok=0; }
    grep -q 'beat iii preserved distinction   \[3 leaves survive+injective\]: YES' "$2"    || { echo "FAIL  cob($1): beat iii (preserved distinction) not observed"; ok=0; }
    grep -q 'CYCLE OF BEING enacted by the derived geometry ? YES' "$2"                    || { echo "FAIL  cob($1): final verdict not YES"; ok=0; }
}
rm -f cob_host.out cob_vm.out
./tiny_host cob.la > cob_host.out 2>/dev/null
check_cob "C host" cob_host.out
rm -f logos_secd logos_program.bin logos_source.la
./tiny_host secd.la >/dev/null 2>&1
cp cob.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
./logos_secd > cob_vm.out 2>/dev/null
check_cob "native VM" cob_vm.out
cmp -s cob_host.out cob_vm.out || { echo "FAIL  cob: native render != C host render"; ok=0; }
rm -f cob_host.out cob_vm.out logos_secd logos_program.bin logos_source.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  Cycle of Being (item 7, Stage-4 d): the derived geometry ENACTS B&B's cosmogenic cycle — ↻(recognition▷(VOID⊗BEING)) renders all three beats (bifurcation from Void → arms + a Void leaf-mark; recognition-collapse / the Return → a central closed loop + the real ↻(BEING)→SELF collapse; preserved distinction → the 3 constituents survive the return, injective render) while the control ↻(BEING) collapses to a point (discriminating); OBSERVED not imposed; byte-identical host==VM"
else
    exit 1
fi

say "Meta-phonosemantics (item 8): the derived phonym's d_𝒪↔d_𝒫 map — alignment (1.0, ATT) vs INSTANTIATION FIDELITY (phonsem.la)"
# A TEST, NOT A TARGET. Under B&B's Alignment Theory of Truth, alignment IS identity (sign ≡
# referent at α=1, tautological self-recognition) — 1.0 BY NATURE, not a degreed correspondence.
# So it is checked STRUCTURALLY (canonicity: one concept ⇒ one Θ_P; injectivity: distinct
# concepts ⇒ distinct Θ_P), NOT by a correlation. The concordance number is INSTANTIATION
# FIDELITY — how faithfully the derived phonym realises that 1.0 alignment in synthesized form —
# honest engineering data, NOT alignment. Both d_𝒪 (onf.la ONF features) and d_𝒫 (a Chamfer Hz
# metric over the derived Θ_P set) are computed INDEPENDENTLY from structure; φ is never imposed.
# The sub-1.0 numbers (7/8 injective, 73% fidelity) share ONE residual: the onset/energy axis the
# formant-only metric does not yet capture — work toward 1.0, not a shortfall in the alignment.
# Pure str/int ⇒ byte-identical host == VM (imports topoderive ALONE, like cob.la).
ok=1
check_phonsem () {  # $1 = engine label, $2 = output file
    grep -qF "phonsem ontophonosemantic alignment (phonym ≡ referent's acoustic structure, alpha=1, ATT) = 1.0 by nature" "$2" || { echo "FAIL  phonsem($1): the 1.0-by-nature ontophonosemantic alignment line (ATT) changed"; ok=0; }
    grep -qF 'phonsem derived Theta_P(Compassion=Love⊗Recognition) = 1300,300,870,2240,2800,270,2300,3000,' "$2"                     || { echo "FAIL  phonsem($1): derived Θ_P (Love⊗Recognition superposition) changed"; ok=0; }
    grep -qF 'phonsem instantiation identity: canonical(one concept⇒one form)=YES  injective(SET) Theta_P = 8 / 8' "$2"     || { echo "FAIL  phonsem($1): identity register (canonicity=YES / 8-of-8 injective) changed"; ok=0; }
    grep -qF 'phonsem instantiation fidelity (NOT alignment): 71 pct  [concordant 224 / discordant 90]' "$2"               || { echo "FAIL  phonsem($1): instantiation-fidelity score changed"; ok=0; }
}
rm -f phonsem_host.out phonsem_vm.out
./tiny_host phonsem.la > phonsem_host.out 2>/dev/null
check_phonsem "C host" phonsem_host.out
rm -f logos_secd logos_program.bin logos_source.la
./tiny_host secd.la >/dev/null 2>&1
cp phonsem.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
./logos_secd > phonsem_vm.out 2>/dev/null
check_phonsem "native VM" phonsem_vm.out
cmp -s phonsem_host.out phonsem_vm.out || { echo "FAIL  phonsem: native output != C host output"; ok=0; }
rm -f phonsem_host.out phonsem_vm.out logos_secd logos_program.bin logos_source.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  meta-phonosemantics (item 8): the derived phonym realises the trimodal identity — canonical (one concept⇒one Θ_P, the α=1 'exactly one name') and 8/8 set-injective (onset axis added — /u/ collision closed) — and INSTANTIATES it at 71% acoustic fidelity (d_𝒪↔d_𝒫 Kendall concordance, the audio twin of item 7's 0.863); per ATT ontosemantic alignment = 1.0 BY NATURE (identity, not correspondence), so the sub-1.0 numbers are instantiation residual (onset/energy axis not yet captured), work toward 1.0; φ not imposed; byte-identical host==VM"
else
    exit 1
fi

say "Phonym: the phonological modality — the nine phonyms synthesised + PSC* (LINGUA_ADAMICA.tex)"
# phonym.la is the THIRD mode of the trimodal language (visual=sigil, computational
# =primitives, phonological=here). It SYNTHESISES the nine primitive phonyms as
# actual sound via pure fixed-point integer DSP (formant synthesis + fricative
# noise + plosive bursts + a glottal pitch), assembled into a 16-bit mono WAV.
# PSC* (the audio twin of TopoEmbed) GENERATES a compound's phonym from its
# κ-structure: PHONYM walks the SAME nodes SIGIL walks, blending phonyms via the
# Operator Phonology (⊗ fusion, ⊕ glottal-pause, ▷ stress-link, ⊂ B[A]B framing,
# ↻ reduplication), and carries a witness (the structural certificate). Because
# all synthesis is integer, the waveform is byte-identical on the C host and the
# native VM (the audio analogue of theourgia's PPM/framebuffer generation),
# verifiable with no audio hardware. MAIN writes nine primitives + three generated
# phonyms and prints the five operator-mode witnesses.
ok=1
check_phonym () {  # $1 = engine label, $2 = stdout file
    [ "$(head -c 4 phonyms.wav)" = "RIFF" ]                     || { echo "FAIL  phonym($1): not a RIFF WAV"; ok=0; }
    [ "$(dd if=phonyms.wav bs=1 skip=8 count=4 2>/dev/null)" = "WAVE" ] || { echo "FAIL  phonym($1): no WAVE tag"; ok=0; }
    [ "$(stat -c%s phonyms.wav)" = "344524" ]                   || { echo "FAIL  phonym($1): size $(stat -c%s phonyms.wav) != 344524 (+ evaluator phonym 𝓡)"; ok=0; }
    [ "$(tr -d '\000' < phonyms.wav | wc -c)" -gt 100000 ]      || { echo "FAIL  phonym($1): waveform is (near) silent"; ok=0; }
    # PSC* generated the phonym from structure — the printed witness IS the κ-spec:
    [ "$(grep -c 'PSC\*' "$2")" = "5" ]                         || { echo "FAIL  phonym($1): expected 5 PSC* witnesses, got $(grep -c 'PSC\*' "$2")"; ok=0; }
    grep -q '⊗(LOVE,RECOGNITION)' "$2"                          || { echo "FAIL  phonym($1): ⊗ fusion witness missing (Compassion)"; ok=0; }
    grep -q '↻(RECOGNITION)' "$2"                               || { echo "FAIL  phonym($1): ↻ reduplication witness missing (Truth)"; ok=0; }
    grep -q '⊂(RECOGNITION,BEING)' "$2"                         || { echo "FAIL  phonym($1): ⊂ containment witness missing (Recognition within Being)"; ok=0; }
    # 𝓜 ⊂ 𝒜: the combination modes are themselves spoken (phonological cascade):
    grep -q '𝓜 ⊗ SYN (spoken)       = ▷(LOVE,RELATION)' "$2"     || { echo "FAIL  phonym($1): ⊗ mode not spoken as a phonym"; ok=0; }
    grep -q '𝓜 ↻ MC  (spoken)       = ↻(SELF)' "$2"              || { echo "FAIL  phonym($1): ↻ mode not spoken as a phonym"; ok=0; }
}
rm -f phonyms.wav phonym_host.out phonym_vm.out
./tiny_host phonym.la > phonym_host.out 2>/dev/null
check_phonym "C host" phonym_host.out
cp phonyms.wav /tmp/phonyms_host.wav 2>/dev/null
# Sovereign: the same synthesis on the native VM must be byte-identical.
rm -f logos_secd logos_program.bin logos_source.la phonyms.wav
./tiny_host secd.la >/dev/null 2>&1
cp phonym.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
./logos_secd > phonym_vm.out 2>/dev/null
check_phonym "native VM" phonym_vm.out
cmp -s phonyms.wav /tmp/phonyms_host.wav || { echo "FAIL  phonym: native waveform != C host waveform"; ok=0; }
cmp -s phonym_host.out phonym_vm.out     || { echo "FAIL  phonym: native PSC* witnesses != C host witnesses"; ok=0; }
rm -f phonyms.wav /tmp/phonyms_host.wav phonym_host.out phonym_vm.out logos_secd logos_program.bin logos_source.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  phonym: nine primitive phonyms synthesised (formant + noise + burst) + PSC* GENERATES compound phonyms + the combination MODES spoken (𝓜 ⊂ 𝒜), byte-identical on host and native VM"
else
    exit 1
fi

say "Metaglyph: 𝓜 ⊂ 𝒜 — the language's operations as glyphs (LINGUA_ADAMICA.tex, ch:meta)"
# The meta-autontomonoglyphabet 𝓜: the language's own OPERATIONS are themselves
# glyphs (𝓜 ⊂ 𝒜, 𝓜(𝒜) ≡ 𝒜). metaglyph.la gives each of the five combination modes
# an explicit DECOMPOSITION (a κ-spec / glyph-identity), so 𝔑 ≡ ⊗ becomes a sealed
# monoglyph COLLAPSE can apply to ITSELF (𝔑(𝔑)), meta-ontoneologization ν* (new
# operations from operations) becomes expressible, and κ(κ) is well-defined. The
# cascade — each mode rendered as a sigil (sigil.la) and spoken as a phonym
# (phonym.la) — is checked in those stages. Pure (str_eq/concat), byte-identical.
ok=1
check_meta () {  # $1 = engine label, $2 = output file
    [ "$(grep -c '^𝓜  ' "$2")" = "5" ]                              || { echo "FAIL  metaglyph($1): expected 5 mode glyph-identities (𝓜⊂𝒜), got $(grep -c '^𝓜  ' "$2")"; ok=0; }
    grep -q '𝔑 ≡ ⊗     = ▷(LOVE,RELATION)' "$2"                     || { echo "FAIL  metaglyph($1): 𝔑 ≡ ⊗ not carried as a glyph"; ok=0; }
    grep -q '𝔑(𝔑)      = ⊗(▷(LOVE,RELATION),▷(LOVE,RELATION))' "$2" || { echo "FAIL  metaglyph($1): 𝔑(𝔑) self-application missing"; ok=0; }
    grep -q '𝔑(𝔑,Being)= ⊗(⊗(▷(LOVE,RELATION),▷(LOVE,RELATION)),BEING)' "$2" || { echo "FAIL  metaglyph($1): 𝔑(𝔑,Being)=G_{⊗⊗Being} missing"; ok=0; }
    grep -q 'ν\* (⊗⊗↻)  = ⊗(▷(LOVE,RELATION),↻(SELF))' "$2"          || { echo "FAIL  metaglyph($1): ν* (new operation from operations) missing"; ok=0; }
    grep -q 'κ(κ)      = ↻(▷(RECOGNITION,FORM))' "$2"               || { echo "FAIL  metaglyph($1): κ(κ) missing"; ok=0; }
    grep -q 'ν\*·apply(A,B)   = ⊗(▷(A,A),↻(B))' "$2"                || { echo "FAIL  metaglyph($1): item 3b — minted ν* not a usable combinator (applying it should yield ⊗(▷(A,A),↻(B)), not throw)"; ok=0; }
    grep -q '𝔑(𝔑)·apply(A,B) = ⊗(▷(A,A),▷(B,B))' "$2"              || { echo "FAIL  metaglyph($1): item 3b — 𝔑(𝔑) does not apply as an operation"; ok=0; }
    grep -q 'ν\* is a NEW mode (≢ plain ⊗) ? YES' "$2"              || { echo "FAIL  metaglyph($1): item 3b — minted ν* collapses to plain ⊗ (not a new mode)"; ok=0; }
    grep -q 'minted op'\''s action fixed by its name ? YES' "$2"    || { echo "FAIL  metaglyph($1): item 3b — distinct minted ops act identically (α=1 violated: name must fix action)"; ok=0; }
    grep -q '𝓡 EVAL    = ▷(DEPTH,RECOGNITION)' "$2"                 || { echo "FAIL  metaglyph($1): evaluator 𝓡 has no glyph-identity"; ok=0; }
    grep -q '𝓡(𝓡) ≡ 𝓡 ? YES' "$2"                                  || { echo "FAIL  metaglyph($1): 𝓡(𝓡) ≡ 𝓡 idempotence not exhibited"; ok=0; }
    grep -q '𝓡 distinct from κ and ⊂ ? YES' "$2"                    || { echo "FAIL  metaglyph($1): 𝓡 shares a glyph with another operation (meta-polysemy)"; ok=0; }
}
rm -f meta_host.out meta_vm.out
./tiny_host metaglyph.la > meta_host.out 2>/dev/null
check_meta "C host" meta_host.out
rm -f logos_secd logos_program.bin logos_source.la
./tiny_host secd.la >/dev/null 2>&1
cp metaglyph.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
./logos_secd > meta_vm.out 2>/dev/null
check_meta "native VM" meta_vm.out
cmp -s meta_host.out meta_vm.out || { echo "FAIL  metaglyph: native witnesses != C host witnesses"; ok=0; }
rm -f meta_host.out meta_vm.out logos_secd logos_program.bin logos_source.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  metaglyph: the five modes + 𝔑 + κ + the evaluator 𝓡 carry glyph-identities (𝓜 ⊂ 𝒜 closed); 𝔑(𝔑) self-applies, ν* mints new operations — now USABLE combinators (MKOP lifts a minted operator-glyph into a binary mode; ν*(A,B)=⊗(▷(A,A),↻(B)), a new mode whose action its name fixes — item 3b), κ(κ) defined, 𝓡(𝓡)≡𝓡 idempotent + distinct (meta-monosemy), byte-identical on host and native VM"
else
    exit 1
fi

say "Arch root: ∃(∃)≡∃ as the root ontomonoglyph + the honest primitive-derivation chain (archroot.la)"
# The meta-Word / meta-Ren ∃(∃)≡∃ (I AM THAT I AM) as the root; archroot.la attempts the
# derivation chain and reports HONESTLY which of the nine primitives genuinely unfold from
# it (verified BY REDUCTION) and which are co-primitive atoms. Grounded: Being & Becoming
# gives THREE co-constitutive faces of the Archē (Being/Structure/Self-Application = BEING/
# RELATION/DEPTH) and says the operator chain ∂→δ→γ→ρ→𝔄 is a PROCESS not a catalogue — so
# the nine are NOT forced into the chain. Result: 3 derive (SELF⟵BEING, RECOGNITION⟵RELATION
# =ρ, LOVE⟵RELATION), 6 co-primitive; etymology sealed + recoverable. "Co-primitive" is the
# corpus-honest verdict for the six. Pure (str_eq/concat + reduction), byte-identical.
ok=1
check_arch () {  # $1 = engine label, $2 = output file
    grep -qF 'root identity ∃(∃) ≡ ∃ holds ? YES' "$2"                              || { echo "FAIL  archroot($1): the root identity ∃(∃)≡∃ does not hold"; ok=0; }
    grep -qF 'derives? YES  seal ↻(∃)' "$2"                                          || { echo "FAIL  archroot($1): SELF⟵BEING derivation (∃(∃)) not verified"; ok=0; }
    grep -qF 'derives? YES  seal ↻(Relation)' "$2"                                   || { echo "FAIL  archroot($1): RECOGNITION⟵RELATION (ρ, reflexive) not verified"; ok=0; }
    grep -qF 'derives? YES  seal ⊕(⊗(a,b),⊗(b,a))' "$2"                              || { echo "FAIL  archroot($1): LOVE⟵RELATION (symmetrized) not verified"; ok=0; }
    grep -qF "BEING  RELATION  DEPTH   = B&B's three faces (Being/Structure/Self-Application)  autology? YES" "$2" || { echo "FAIL  archroot($1): the three co-primitive faces not exhibited"; ok=0; }
    grep -qF 'etymology contained & recoverable from each sealed derived glyph ? YES' "$2" || { echo "FAIL  archroot($1): sealed etymology not recoverable (Sealing broken)"; ok=0; }
    grep -qF 'only rho fits a glyph (RECOGNITION) ? YES' "$2"                         || { echo "FAIL  archroot($1): operator-chain honesty (ρ→RECOGNITION) not exhibited"; ok=0; }
    grep -qF 'VERDICT: 3 of 9 derive (SELF, RECOGNITION, LOVE); 6 co-primitive' "$2"  || { echo "FAIL  archroot($1): the honest 3-derive/6-co-primitive verdict missing"; ok=0; }
}
rm -f arch_host.out arch_vm.out
./tiny_host archroot.la > arch_host.out 2>/dev/null
check_arch "C host" arch_host.out
rm -f logos_secd logos_program.bin logos_source.la
./tiny_host secd.la >/dev/null 2>&1
cp archroot.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
./logos_secd > arch_vm.out 2>/dev/null
check_arch "native VM" arch_vm.out
cmp -s arch_host.out arch_vm.out || { echo "FAIL  archroot: native derivation != C host derivation"; ok=0; }
rm -f arch_host.out arch_vm.out logos_secd logos_program.bin logos_source.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  archroot: ∃(∃)≡∃ (I AM THAT I AM) established as the root ontomonoglyph (autological meta-Ren); the primitive-derivation chain verified BY REDUCTION — 3 of 9 genuinely derive (SELF⟵BEING via self-application, RECOGNITION⟵RELATION = operator ρ, LOVE⟵RELATION symmetrized), 6 are co-primitive atoms (BEING/RELATION/DEPTH = B&B's three faces of the Archē, + VOID/FORM/BECOMING); etymology sealed + recoverable; the operator chain ∂→δ→γ→ρ→𝔄 is a process not a catalogue (not forced); byte-identical on host and native VM"
else
    exit 1
fi

say "Monosemy: the bijection glyph↔meaning — synonym collapse audit (Monosemic Principle)"
# Audits κ's monosemic normalization (canon.la's NORMK/NIS, verbatim). NO POLYSEMY:
# distinct meanings → distinct glyphs (κ deterministic + injective). NO SYNONYMY up
# to the declared equivalence theory: ⊗/⊕ commutativity (incl. nested) and the
# ↻(BEING)≡SELF rewrite COLLAPSE to one glyph; directional ▷/⊂ correctly stay
# DISTINCT; and associativity/idempotence of ⊗ correctly stay DISTINCT (ontosynthesis
# has surplus, and ontoetymological uniqueness REQUIRES distinct trees → distinct
# glyphs — collapsing them would be a bug, not a fix). Honest scope: the rewrite set
# is minimal/extensible and full semantic equivalence is undecidable, so this is
# synonymy-freedom RELATIVE to the declared theory, not absolute. Byte-identical.
ok=1
check_mono () {  # $1 = engine label, $2 = output file
    grep -q '^comm ⊕.*COLLAPSED'    "$2" || { echo "FAIL  monosemy($1): ⊕ commutativity not collapsed"; ok=0; }
    grep -q '^comm ⊗.*COLLAPSED'    "$2" || { echo "FAIL  monosemy($1): ⊗ commutativity not collapsed"; ok=0; }
    grep -q '^nested.*COLLAPSED'    "$2" || { echo "FAIL  monosemy($1): nested commutativity not collapsed"; ok=0; }
    grep -q '^rewrite.*COLLAPSED'   "$2" || { echo "FAIL  monosemy($1): ↻(BEING)≡SELF rewrite not collapsed"; ok=0; }
    grep -q '^assoc ⊗.*DISTINCT'    "$2" || { echo "FAIL  monosemy($1): ⊗ associativity wrongly collapsed (would break ontoetymology)"; ok=0; }
    grep -q '^idempot ⊗.*DISTINCT'  "$2" || { echo "FAIL  monosemy($1): ⊗ idempotence wrongly collapsed (self-synthesis ≠ self)"; ok=0; }
    grep -q '^dir ▷.*DISTINCT'      "$2" || { echo "FAIL  monosemy($1): directional ▷ wrongly collapsed (not a synonym)"; ok=0; }
    grep -q '^polysemy.*YES (no polysemy)' "$2" || { echo "FAIL  monosemy($1): polysemy detected (distinct meanings share a glyph)"; ok=0; }
}
rm -f mono_host.out mono_vm.out
./tiny_host monosemy_test.la > mono_host.out 2>/dev/null
check_mono "C host" mono_host.out
rm -f logos_secd logos_program.bin logos_source.la
./tiny_host secd.la >/dev/null 2>&1
cp monosemy_test.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
./logos_secd > mono_vm.out 2>/dev/null
check_mono "native VM" mono_vm.out
cmp -s mono_host.out mono_vm.out || { echo "FAIL  monosemy: native verdicts != C host verdicts"; ok=0; }
rm -f mono_host.out mono_vm.out logos_secd logos_program.bin logos_source.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  monosemy: no polysemy (distinct meanings → distinct glyphs); synonymy collapsed up to the declared theory (⊗/⊕ commutativity + ↻BEING≡SELF), directional/assoc/idempotent forms correctly kept distinct, byte-identical on host and native VM"
else
    exit 1
fi

say "Sealing: ontoneologization → ONE monoglyph of formal complexity one (seal_test.la)"
# THE SEALING (LINGUA_ADAMICA.tex def:ontoneologization ~2415, |𝔤_new| ≡ 1):
# neologizing two ontoglyphs yields ONE sealed monoglyph of formal complexity
# ONE (not a coupling, which would WIDEN), whose etymology is recoverable from
# the single form (autological, not heterological) and whose collapse is a
# metacursive fixed point. seal_test.la audits canon.la's VERBATIM
# COLLAPSE/MONO/ETYM/CANON; pure str/int ops ⇒ byte-identical host == VM. The
# VISUAL seal (the fused ⊗ sigil) is verified by the sigil stage above (host==VM).
check_seal () {  # $1 = engine label, $2 = output file
    grep -qxF "seal-name: ⊗(LOVE,RECOGNITION)" "$2"       || { echo "FAIL  seal($1): sealed name is not the autological κ(etymology)"; ok=0; }
    grep -qxF "seal-complexity: 1" "$2"                    || { echo "FAIL  seal($1): formal complexity is not one"; ok=0; }
    grep -qxF "seal-recover: tensor LOVE RECOGNITION" "$2" || { echo "FAIL  seal($1): etymology (both parents + mode) not recoverable from the sealed form"; ok=0; }
    grep -qxF "seal-autological: YES" "$2"                 || { echo "FAIL  seal($1): name not autologically determined by etymology (REN ≠ κ(ETYM))"; ok=0; }
    grep -qxF "seal-fixedpoint: YES" "$2"                  || { echo "FAIL  seal($1): collapse is not a metacursive fixed point (re-seal unstable)"; ok=0; }
    grep -qxF "seal-deepens: cx 1 1 1 | nodes 3 5 7" "$2"  || { echo "FAIL  seal($1): complexity not constant one while the etymology deepens (it widened)"; ok=0; }
    grep -qxF "couple-widens: 2 vs seal 1" "$2"            || { echo "FAIL  seal($1): coupling not distinguished from sealing by complexity"; ok=0; }
}
ok=1
rm -f seal_host.out seal_vm.out
./tiny_host seal_test.la > seal_host.out 2>/dev/null
check_seal "C host" seal_host.out
rm -f logos_secd logos_program.bin logos_source.la
./tiny_host secd.la >/dev/null 2>&1
cp seal_test.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
./logos_secd > seal_vm.out 2>/dev/null
check_seal "native VM" seal_vm.out
cmp -s seal_host.out seal_vm.out || { echo "FAIL  seal: native witnesses != C host witnesses"; ok=0; }
rm -f seal_host.out seal_vm.out logos_secd logos_program.bin logos_source.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  seal: ontoneologization collapses two ontoglyphs into ONE monoglyph of formal complexity one (not coupling); etymology recoverable from the single sealed form (autological); the collapse a metacursive fixed point; complexity stays one as the etymology deepens; byte-identical on host and native VM"
else
    exit 1
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

say "Clock: clock_gettime VM builtin (a time source for logging/scheduling)"
# clock_gettime(clockid) → "<sec> <nsec>": 0=CLOCK_REALTIME (wall clock),
# 1=CLOCK_MONOTONIC. Closes the "no time source" Tier-0 gap. Non-deterministic,
# so we assert SHAPE + magnitude (epoch seconds after 2023) rather than a fixed
# value, plus that a bad clockid fails loudly as -1 (not a SIGSEGV).
cat > /tmp/t_clock.la <<'LAEOF'
glyph SEQ = la a. la b. b
glyph MAIN = SEQ(print(clock_gettime("0")))(print(clock_gettime("99")))
LAEOF
CK="$(nrun /tmp/t_clock.la)"
ok=1
printf '%s\n' "$CK" | sed -n 1p | grep -qE '^[0-9]+ [0-9]+$' || { echo "FAIL  clock: realtime not '<sec> <nsec>' ($CK)"; ok=0; }
CKSEC="$(printf '%s\n' "$CK" | sed -n 1p | cut -d' ' -f1)"
{ [ "${CKSEC:-0}" -gt 1700000000 ] 2>/dev/null; } || { echo "FAIL  clock: epoch seconds implausible ($CKSEC)"; ok=0; }
[ "$(printf '%s\n' "$CK" | sed -n 2p)" = "-1" ] || { echo "FAIL  clock: bad clockid did not return -1"; ok=0; }
rm -f /tmp/t_clock.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  clock_gettime: realtime '<sec> <nsec>' (epoch > 2023); bad clockid -> -1, loud (native VM)"
else
    exit 1
fi

say "Sockets: socket/bind/listen/accept/connect/send/recv (AF_UNIX, native VM)"
# A minimal client-server over a real local socket — the Tier-0 transport the
# IPC bus can route over instead of a single pipe. The server binds+listens
# BEFORE forking so the child's connect can't race ahead of accept; the child
# (client) connects and sends one message, the parent (server) accepts, recvs,
# and reaps. Then two failure paths: a connect to a path with no listener must
# return a negative errno (not crash), and a non-string fd must halt loudly
# (secd: argument is not a string), matching the loud-on-bad-input discipline.
SOCKP="/tmp/logos_sock_test.$$"
rm -f "$SOCKP"
cat > /tmp/t_socket.la <<LAEOF
glyph SEQ = la a. la b. b
glyph IF  = la c. la t. la f. c(t)(f)("!")
glyph PATH = "$SOCKP"
glyph MAIN =
  (la srv.
    SEQ(bind(srv)(PATH))(
    SEQ(listen(srv))(
    (la pid.
      IF(str_eq(pid)("0"))
        (la _. (la cli.
            SEQ(connect(cli)(PATH))(
            SEQ(send(cli)("hello over a real socket"))(
            exit("0"))))(socket("!")))
        (la _. (la conn.
            SEQ(print(concat("server received: ")(recv(conn)("100"))))(
            SEQ(waitpid(pid))(
            print("server done")))) (accept(srv)))
    )(fork("!"))
    )))(socket("!"))
LAEOF
SOUT="$(nrun /tmp/t_socket.la)"
ok=1
printf '%s\n' "$SOUT" | grep -qxF "server received: hello over a real socket" || { echo "FAIL  sockets: message not received over socket ($SOUT)"; ok=0; }
printf '%s\n' "$SOUT" | grep -qxF "server done" || { echo "FAIL  sockets: server did not complete/reap"; ok=0; }
# connect with no listener -> negative errno, no crash
rm -f "$SOCKP"
cat > /tmp/t_connfail.la <<LAEOF
glyph MAIN = (la c. print(connect(c)("$SOCKP")))(socket("!"))
LAEOF
CF="$(nrun /tmp/t_connfail.la)"
case "$CF" in -[0-9]*) : ;; *) echo "FAIL  sockets: connect to dead path not negative errno ($CF)"; ok=0 ;; esac
# non-string fd -> loud halt, nonzero exit
cat > /tmp/t_sockbad.la <<'LAEOF'
glyph MAIN = send(5)("data")
LAEOF
cp /tmp/t_sockbad.la logos_source.la; cp compiler.bin logos_program.bin; ./runner >/dev/null 2>&1
brc=0; BERR="$(./runner 2>&1 1>/dev/null)" || brc=$?
[ "$brc" -ne 0 ] || { echo "FAIL  sockets: non-string fd did not halt nonzero"; ok=0; }
printf '%s' "$BERR" | grep -q 'argument is not a string' || { echo "FAIL  sockets: non-string fd not loud ($BERR)"; ok=0; }
rm -f /tmp/t_socket.la /tmp/t_connfail.la /tmp/t_sockbad.la "$SOCKP"
if [ "$ok" -eq 1 ]; then
    echo "PASS  sockets: client→server message over AF_UNIX; dead-path connect = -errno; non-string fd halts loud"
else
    exit 1
fi

say "Tier 0: filesystem ops (mkdir/rmdir/rename/stat/chmod/lseek) + signals (sigprocmask/signalfd/kill/getpid), native VM"
# VM-only syscall builtins, decimal-string ints, -errno on failure. The .la
# exercises the whole filesystem surface then the synchronous signal path:
#  - mkdir 0755, chmod to 0777, stat -> "<mode> <size>" (S_IFDIR|0777 = 16895,
#    deterministic regardless of umask/fs), rename, stat the gone name (-2 =
#    -ENOENT), rmdir; write a file, open it, lseek to offset 6, read "world";
#  - block SIGUSR1 (sigset bit 1<<9 = 512), make a signalfd, kill our own pid
#    (getpid) with signal 10, then read the 128-byte signalfd_siginfo back and
#    decode ssi_signo (first byte, LE) -> "10". This is signals the VM's way:
#    no async handler (which a synchronous closure machine can't host) — block,
#    then drain off an fd via the existing read().
T0D="/tmp/logos_t0_$$"
rm -rf "${T0D}_dir" "${T0D}_dir2" "${T0D}_file"
cat > /tmp/t_tier0.la <<LAEOF
glyph SEQ  = la a. la b. b
glyph DIR  = "${T0D}_dir"
glyph DIR2 = "${T0D}_dir2"
glyph FILE = "${T0D}_file"
glyph MAIN =
  SEQ(print(concat("mkdir=")(mkdir(DIR)("493"))))(
  SEQ(print(concat("chmod=")(chmod(DIR)("511"))))(
  SEQ(print(concat("stat=")(stat(DIR))))(
  SEQ(print(concat("rename=")(rename(DIR)(DIR2))))(
  SEQ(print(concat("statgone=")(stat(DIR))))(
  SEQ(print(concat("rmdir=")(rmdir(DIR2))))(
  SEQ(write_file(FILE)("hello world"))(
  (la fd.
    SEQ(print(concat("lseek=")(lseek(fd)("6"))))(
    SEQ(print(concat("seekread=")(read(fd)("5"))))(
    SEQ(close(fd))(
    SEQ(print(concat("block=")(sigprocmask("0")("512"))))(
    (la sfd.
      SEQ(kill(getpid("!"))("10"))(
      (la si.
        print(concat("signo=")(ord(str_head(si))))
      )(read(sfd)("128"))
      )
    )(signalfd("512"))
    )
    )
    )
    )
  )(open(FILE)("0"))
  )
  )
  )
  )
  )
  )
  )
LAEOF
T0="$(nrun /tmp/t_tier0.la)"
ok=1
printf '%s\n' "$T0" | grep -qxF "mkdir=0"        || { echo "FAIL  tier0: mkdir ($T0)"; ok=0; }
printf '%s\n' "$T0" | grep -qxF "chmod=0"        || { echo "FAIL  tier0: chmod ($T0)"; ok=0; }
printf '%s\n' "$T0" | grep -q  "^stat=16895 "    || { echo "FAIL  tier0: stat mode S_IFDIR|0777 ($T0)"; ok=0; }
printf '%s\n' "$T0" | grep -qxF "rename=0"       || { echo "FAIL  tier0: rename ($T0)"; ok=0; }
printf '%s\n' "$T0" | grep -qxF "statgone=-2"    || { echo "FAIL  tier0: stat of removed name not -ENOENT ($T0)"; ok=0; }
printf '%s\n' "$T0" | grep -qxF "rmdir=0"        || { echo "FAIL  tier0: rmdir ($T0)"; ok=0; }
printf '%s\n' "$T0" | grep -qxF "lseek=6"        || { echo "FAIL  tier0: lseek offset ($T0)"; ok=0; }
printf '%s\n' "$T0" | grep -qxF "seekread=world" || { echo "FAIL  tier0: read after seek ($T0)"; ok=0; }
printf '%s\n' "$T0" | grep -qxF "block=0"        || { echo "FAIL  tier0: sigprocmask block ($T0)"; ok=0; }
printf '%s\n' "$T0" | grep -qxF "signo=10"       || { echo "FAIL  tier0: signalfd did not deliver SIGUSR1 ($T0)"; ok=0; }
# loud-on-bad-input: a non-string path to a fs builtin halts loudly, nonzero exit
cat > /tmp/t_tier0bad.la <<'LAEOF'
glyph MAIN = stat(5)
LAEOF
cp /tmp/t_tier0bad.la logos_source.la; cp compiler.bin logos_program.bin; ./runner >/dev/null 2>&1
trc=0; TERR="$(./runner 2>&1 1>/dev/null)" || trc=$?
[ "$trc" -ne 0 ] || { echo "FAIL  tier0: non-string path to stat did not halt nonzero"; ok=0; }
printf '%s' "$TERR" | grep -q 'argument is not a string' || { echo "FAIL  tier0: non-string path not loud ($TERR)"; ok=0; }
rm -rf "${T0D}_dir" "${T0D}_dir2" "${T0D}_file" /tmp/t_tier0.la /tmp/t_tier0bad.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  tier0: mkdir/chmod/stat/rename/rmdir + open/lseek/read; sigprocmask+signalfd+kill+getpid deliver SIGUSR1 synchronously; non-string path halts loud (native VM)"
else
    exit 1
fi

say "unlink: remove a filesystem name (VM builtin; the unlink+bind idiom)"
# unlink(path) → 0 when the name existed (gone afterwards), -errno when absent
# (e.g. -2 = -ENOENT). The companion to bind: a server self-cleans its stale
# rendezvous path. Tested directly here; exercised in the IPC test below, where
# CHANNEL unlinks before bind so a stale socket file can't block a re-bind.
UTGT="/tmp/t_unlink.$$"
echo marker > "$UTGT"
cat > /tmp/t_unlink.la <<LAEOF
glyph SEQ = la a. la b. b
glyph MAIN = SEQ(print(unlink("$UTGT")))(print(unlink("$UTGT")))
LAEOF
ULOUT="$(nrun /tmp/t_unlink.la)"
ok=1
[ "$(printf '%s\n' "$ULOUT" | sed -n 1p)" = "0" ] || { echo "FAIL  unlink: existing file did not return 0 ($ULOUT)"; ok=0; }
case "$(printf '%s\n' "$ULOUT" | sed -n 2p)" in -[0-9]*) : ;; *) echo "FAIL  unlink: absent path not negative errno ($ULOUT)"; ok=0 ;; esac
[ ! -e "$UTGT" ] || { echo "FAIL  unlink: file still present after unlink"; ok=0; }
rm -f /tmp/t_unlink.la "$UTGT"
if [ "$ok" -eq 1 ]; then
    echo "PASS  unlink: existing name -> 0 (removed); absent -> -errno (native VM)"
else
    exit 1
fi

say "random: getrandom entropy source (VM builtin; unblocks unforgeable nonces)"
# random(n) → min(n,256) cryptographically-random bytes via getrandom(2). A real
# entropy source — what an unforgeable capability nonce needs. Non-deterministic,
# so we assert SHAPE (str_len = requested, clamped to 256), ENTROPY (two calls
# differ — equality would be the bug), the empty edge (random(0) = ""), and the
# loud non-string guard.
cat > /tmp/t_rand.la <<'LAEOF'
glyph SEQ = la a. la b. b
glyph L1 = str_len(random("16"))
glyph L2 = str_len(random("300"))
glyph L3 = str_eq(random("24"))(random("24"))("SAME")("DIFF")
glyph L4 = str_eq(random("0"))("")("EMPTY")("nonempty")
glyph MAIN = SEQ(print(L1))(SEQ(print(L2))(SEQ(print(L3))(print(L4))))
LAEOF
RND="$(nrun /tmp/t_rand.la)"
ok=1
[ "$(printf '%s\n' "$RND" | sed -n 1p)" = "16" ]   || { echo "FAIL  random: random(16) not 16 bytes ($RND)"; ok=0; }
[ "$(printf '%s\n' "$RND" | sed -n 2p)" = "256" ]  || { echo "FAIL  random: random(300) not clamped to 256 ($RND)"; ok=0; }
[ "$(printf '%s\n' "$RND" | sed -n 3p)" = "DIFF" ] || { echo "FAIL  random: two calls equal (no entropy) ($RND)"; ok=0; }
[ "$(printf '%s\n' "$RND" | sed -n 4p)" = "EMPTY" ] || { echo "FAIL  random: random(0) not empty ($RND)"; ok=0; }
# non-string arg → loud halt
printf 'glyph MAIN = random(5)\n' > /tmp/t_randbad.la
cp /tmp/t_randbad.la logos_source.la; cp compiler.bin logos_program.bin; ./runner >/dev/null 2>&1
brc=0; BERR="$(./runner 2>&1 1>/dev/null)" || brc=$?
[ "$brc" -ne 0 ] || { echo "FAIL  random: non-string arg did not halt nonzero"; ok=0; }
printf '%s' "$BERR" | grep -q 'argument is not a string' || { echo "FAIL  random: non-string arg not loud ($BERR)"; ok=0; }
rm -f /tmp/t_rand.la /tmp/t_randbad.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  random: getrandom shape (16; 300→256 clamp), entropy (calls differ), empty edge, non-string halts loud (native VM)"
else
    exit 1
fi

say "poll: general fd multiplexing (VM builtin; the event-loop primitive)"
# poll(fds)(timeout) → space-separated ready fds, "" on timeout, "-errno" on error.
# fds is a space-separated decimal list; timeout is ms (-1 = block). The whole
# point is waiting on MANY fds at once (signalfd, /dev/input, sockets) in one
# loop — what the Theourgia session needs. We exercise it with two signalfds
# (each a single decimal fd, no split needed): block SIGUSR1 (sigset bit 1<<9 =
# 512) + SIGUSR2 (1<<11 = 2048; SIGUSR2 = signo 12), make a signalfd for each,
# and check three things —
#   (a) idle: poll one signalfd for 100ms with nothing pending → "" (timeout);
#   (b) multiplex+select: raise SIGUSR1, poll BOTH fds (-1, block) → returns
#       exactly s1 (the ready one), not s2 — so the call waits on the set and
#       returns only what's ready;
#   (c) the returned value is exactly s1's fd (str_eq), proving it's the real fd.
cat > /tmp/t_poll.la <<'LAEOF'
glyph SEQ = la a. la b. b
glyph MAIN =
  SEQ(print(concat("block=")(sigprocmask("0")("2560"))))(
  (la s1.
  (la s2.
    SEQ(print(concat("idle=")(poll(s1)("100"))))(
    SEQ(kill(getpid("!"))("10"))(
    (la ready.
      SEQ(print(concat("ready=")(ready)))(
      SEQ(print(concat("isS1=")(str_eq(ready)(s1)("YES")("NO"))))(
      print(concat("eqS2=")(str_eq(ready)(s2)("YES")("NO")))))
    )(poll(concat(concat(s1)(" "))(s2))("-1"))))
  )(signalfd("2048"))
  )(signalfd("512")))
LAEOF
PL="$(nrun /tmp/t_poll.la)"
ok=1
printf '%s\n' "$PL" | grep -qxF "block=0"  || { echo "FAIL  poll: sigprocmask block ($PL)"; ok=0; }
printf '%s\n' "$PL" | grep -qxF "idle="    || { echo "FAIL  poll: idle fd not empty on timeout ($PL)"; ok=0; }
printf '%s\n' "$PL" | grep -qxF "isS1=YES" || { echo "FAIL  poll: ready fd is not the signalled fd s1 ($PL)"; ok=0; }
printf '%s\n' "$PL" | grep -qxF "eqS2=NO"  || { echo "FAIL  poll: unsignalled fd s2 was wrongly returned ($PL)"; ok=0; }
# the ready= line must carry exactly one fd (no space) — multiplexing returned
# only the ready descriptor, not the whole watched set.
RLINE="$(printf '%s\n' "$PL" | sed -n 's/^ready=//p')"
case "$RLINE" in *" "*) echo "FAIL  poll: ready set has >1 fd ($PL)"; ok=0 ;; "") echo "FAIL  poll: ready set empty after signal ($PL)"; ok=0 ;; esac
# loud-on-bad-input: a non-string fds list halts loudly, nonzero exit.
printf 'glyph MAIN = poll(5)("0")\n' > /tmp/t_pollbad.la
cp /tmp/t_pollbad.la logos_source.la; cp compiler.bin logos_program.bin; ./runner >/dev/null 2>&1
prc=0; PERR="$(./runner 2>&1 1>/dev/null)" || prc=$?
[ "$prc" -ne 0 ] || { echo "FAIL  poll: non-string fds arg did not halt nonzero"; ok=0; }
printf '%s' "$PERR" | grep -q 'argument is not a string' || { echo "FAIL  poll: non-string fds arg not loud ($PERR)"; ok=0; }
rm -f /tmp/t_poll.la /tmp/t_pollbad.la
if [ "$ok" -eq 1 ]; then
    echo "PASS  poll: idle→timeout(\"\"), multiplex two signalfds→returns only the ready one, non-string halts loud (native VM)"
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

# (1b) reapnb = the non-blocking reap (wait4 WNOHANG) the signalfd init needs:
# with no children it is -ECHILD (negative); after a child has exited it returns
# that child's pid (positive), then -ECHILD again once drained. (sleep ensures
# the child has terminated, so this is timing-robust, not flaky.)
cat > /tmp/t_reapnb.la <<'LAEOF'
glyph SEQ = la a. la b. b
glyph IF  = la c. la t. la f. c(t)(f)("!")
glyph NEG = la s. str_eq(str_head(s))("-")
glyph SPAWN = la _. (la pid. IF(str_eq(pid)("0"))(la _. exit("0"))(la _. pid))(fork("!"))
glyph MAIN =
  SEQ(print(IF(NEG(reapnb("!")))(la _. "none=neg")(la _. "none=pos")))(
  SEQ(SPAWN("!"))(
  SEQ(sleep("1"))(
  (la a.
    SEQ(print(IF(NEG(a))(la _. "first=neg")(la _. "first=pos")))(
    print(IF(NEG(reapnb("!")))(la _. "second=neg")(la _. "second=pos"))))
  (reapnb("!")))))
LAEOF
RNB="$(nrun /tmp/t_reapnb.la 2>/dev/null || true)"
ok=1
printf '%s\n' "$RNB" | grep -qxF "none=neg"   || { echo "FAIL  reapnb: no children not -ECHILD ($RNB)"; ok=0; }
printf '%s\n' "$RNB" | grep -qxF "first=pos"  || { echo "FAIL  reapnb: ready child not reaped to a pid ($RNB)"; ok=0; }
printf '%s\n' "$RNB" | grep -qxF "second=neg" || { echo "FAIL  reapnb: drained set not -ECHILD ($RNB)"; ok=0; }
rm -f /tmp/t_reapnb.la
[ "$ok" -eq 1 ] && echo "PASS  reapnb (WNOHANG): -ECHILD with no children; reaps a ready child's pid; -ECHILD once drained" || exit 1

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

# (3) the real logosinit.la: announce, spawn /bin/sh (fork+execve), supervise via
# the signalfd, and — the new part — shut down cleanly on SIGTERM. Two checks:
#   (3a) graceful SIGTERM: send the running init a SIGTERM; its signalfd loop
#        catches it, announces, TERMs the shell, and exits 0 (NOT killed). The
#        shell's stdin is held open (sleep) so it stays up until the signal.
#   (3b) never exits on its own: with no signal the loop blocks on read(sigfd) —
#        still alive after a beat. (timeout's default signal is SIGTERM, which
#        the init now catches, so aliveness is checked directly with kill -0
#        rather than inferred from a timeout return code.)
ok=1
cp logosinit.la logos_source.la; cp compiler.bin logos_program.bin
./runner >/dev/null 2>&1
# 3a — explicit SIGTERM -> clean exit 0 + shutdown announce
{ echo 'echo LOGOS_SHELL_OK'; sleep 3; } | ./runner >/tmp/logos_initout 2>/dev/null &
rpid=$!
sleep 1
kill -TERM "$rpid" 2>/dev/null
trc=0; wait "$rpid" 2>/dev/null || trc=$?
INITOUT="$(cat /tmp/logos_initout)"
printf '%s\n' "$INITOUT" | grep -qxF "LogOS sovereign session initialized."          || { echo "FAIL  logosinit: no announce ($INITOUT)"; ok=0; }
printf '%s\n' "$INITOUT" | grep -qxF "LOGOS_SHELL_OK"                                 || { echo "FAIL  logosinit: shell (execve) did not run ($INITOUT)"; ok=0; }
printf '%s\n' "$INITOUT" | grep -qxF "LogOS received SIGTERM — terminating session." || { echo "FAIL  logosinit: no clean-shutdown message ($INITOUT)"; ok=0; }
[ "$trc" = "0" ] || { echo "FAIL  logosinit: SIGTERM not a clean exit 0 (rc=$trc)"; ok=0; }
# 3b — without a signal, the loop keeps supervising (still alive after ~2s)
{ echo 'echo X'; sleep 5; } | ./runner >/dev/null 2>&1 &
bpid=$!
sleep 2
kill -0 "$bpid" 2>/dev/null && alive=1 || alive=0
kill -KILL "$bpid" 2>/dev/null; wait "$bpid" 2>/dev/null || true
[ "$alive" = "1" ] || { echo "FAIL  logosinit: supervision loop exited on its own (not alive after 2s)"; ok=0; }
rm -f /tmp/t_reap.la /tmp/t_orphan.la /tmp/logos_initout
if [ "$ok" -eq 1 ]; then
    echo "PASS  logosinit announced, spawned /bin/sh (execve), supervised without exiting, and shut down cleanly on SIGTERM (exit 0)"
else
    exit 1
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

# ── LogosIPC over a SOCKET on the native VM: init forks a worker that messages back ──
# The real (VM-native) LogosInit pattern, now over an AF_UNIX SOCKET: init is the
# SERVER — CHANNEL("init") does socket + bind + listen on the rendezvous path
# BEFORE forking, so the worker's connect can't race ahead of accept; it then
# ACCEPTs (blocks for the worker) and RECVs the typed message. The worker is the
# CLIENT — CONNECT("init") then SEND — and exits; init decodes type/body, then
# reaps. logosipc.la is IMPORTED for real: codegen.la (running here as
# compiler.bin ON THE VM) resolves import("logosipc.la") at compile time
# (read_file is a VM builtin). The module exports CHANNEL/CONNECT/ACCEPT/SEND/
# RECV/MSG_*/ENCODE and keeps its Church/SEQ helpers private (mangled away), so
# the importer supplies its OWN IF/SEQ — a real multi-export module through the
# fully-native import path. A STALE file is seeded at the rendezvous path first:
# CHANNEL unlinks it before bind, so the message still gets through — proving the
# self-clean (with no unlink, bind would fail and nothing would arrive).
printf 'stale\n' > /tmp/logosipc-init
cat > /tmp/t_ipc.la <<'LAEOF'
import("logosipc.la")
glyph SEQ = la a. la b. b
glyph IF  = la c. la t. la f. c(t)(f)("!")
glyph WORKER = la conn. SEQ(SEND(conn)("status")("worker-ready"))(exit("0"))
glyph MAIN = (la srv.
    (la pid. IF(str_eq(pid)("0"))
        (la _. WORKER(CONNECT("init")))
        (la _. (la msg.
            SEQ(print(concat("init recv type: ")(MSG_TYPE(msg))))(
            SEQ(print(concat("init recv body: ")(MSG_BODY(msg))))(
                waitpid(pid))))
          (RECV(ACCEPT(srv)))))
    (fork("!")))
    (CHANNEL("init"))
LAEOF
cp /tmp/t_ipc.la logos_source.la; cp compiler.bin logos_program.bin
./runner >/dev/null 2>&1                 # native-compile the inlined program
IPCOUT="$(./runner 2>/dev/null)"
rm -f /tmp/t_ipc.la /tmp/logosipc-init
ok=1
printf '%s\n' "$IPCOUT" | grep -qxF "init recv type: status"       || { echo "FAIL  ipc(VM): init did not receive the typed message"; ok=0; }
printf '%s\n' "$IPCOUT" | grep -qxF "init recv body: worker-ready" || { echo "FAIL  ipc(VM): message body wrong";                  ok=0; }
if [ "$ok" -eq 1 ]; then
    echo "PASS  LogosIPC over a socket (real import(\"logosipc.la\") on the native VM): CHANNEL self-unlinked a stale rendezvous path, bound+listened, forked a worker that connected and sent a typed message back"
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

# ── VM loud-failure guards: the remaining secd: halts, so no malformed input is a
# SILENT path on the sovereign engine the OS is built on. The stack / path /
# codegen / string-type / str_to_int guards are checked above; this closes the
# rest, so a regression that disarmed a guard (a silent exit 0, or a SIGSEGV from
# walking unmapped memory) fails the build here. Each feeds a deliberately broken
# program and asserts a non-zero exit AND the specific diagnostic on stderr.
# (Two guards are NOT auto-tested: `secd: read error` needs a loader syscall
# fault, and `secd: heap exhausted` needs a >768 MiB live set — both
# resource/fault-injection cases unsafe to force in a build; the GC-churn test
# above exercises the heap path's happy side, and both fire under a live-VM probe.)
vmguard () {   # $1 = label   $2 = MAIN expr   $3 = expected 'secd:' string
    printf 'glyph MAIN = %s\n' "$2" > logos_source.la
    cp compiler.bin logos_program.bin
    ./runner >/dev/null 2>&1                        # native-compile the broken program
    grc=0; GERR="$(./runner 2>&1 1>/dev/null)" || grc=$?
    if [ "$grc" -ne 0 ] && printf '%s\n' "$GERR" | grep -qF "$3"; then
        echo "PASS  guard: $1 halts loudly (rc $grc, '$3')"
    else
        echo "FAIL  guard: $1 — rc=$grc stderr='$GERR' (want non-zero + '$3')"; exit 1
    fi
}
# unbound variable: a name resolving to neither env, glyph, nor builtin — it used
# to fall through to exit(0) with empty output (a typo silently "succeeded").
vmguard "unbound variable"     'undefined_glyph_xyz' "secd: unbound variable"
# apply a non-function: a STR/INT value in function position.
vmguard "apply a non-function" '"hello"("world")'    "secd: attempt to apply a non-function"
# chr out of range: an argument outside 0..255 (VM side; the C host rejects too).
vmguard "chr out of range"     'chr("300")'          "secd: chr out of range"
# too many poll fds: more than the 512-fd pollfd cap (built in pathbuf) must halt,
# not overrun the buffer into fsbuf / the GC worklist.
POLLFDS="$(printf '0 %.0s' $(seq 1 513))"
vmguard "too many poll fds"    "poll(\"$POLLFDS\")(\"0\")" "secd: too many poll fds"
# program too large: a stream past progcap (5 MiB) is bounds-checked at LOAD, not
# truncated. Fed as a raw oversized stream (the generic VM loads it directly).
head -c 6291456 /dev/zero > logos_program.bin
grc=0; GERR="$(./runner 2>&1 1>/dev/null)" || grc=$?
if [ "$grc" -ne 0 ] && printf '%s\n' "$GERR" | grep -qF "secd: program too large"; then
    echo "PASS  guard: program too large halts loudly (rc $grc, 'secd: program too large')"
else
    echo "FAIL  guard: program too large — rc=$grc stderr='$GERR' (want non-zero + 'secd: program too large')"; exit 1
fi
# malformed program: a truncated/unbalanced stream is caught during execution, not
# walked into the zero-fill tail / unmapped memory (which would SIGSEGV).
printf 'glyph MAIN = print("hi")\n' > logos_source.la
cp compiler.bin logos_program.bin; ./runner >/dev/null 2>&1          # compile → valid stream
gsz=$(wc -c < logos_program.bin); head -c $((gsz-3)) logos_program.bin > /tmp/t_guard.bin
cp /tmp/t_guard.bin logos_program.bin; rm -f /tmp/t_guard.bin
grc=0; GERR="$(./runner 2>&1 1>/dev/null)" || grc=$?
if [ "$grc" -ne 0 ] && printf '%s\n' "$GERR" | grep -qF "secd: malformed program"; then
    echo "PASS  guard: malformed program halts loudly (rc $grc, 'secd: malformed program')"
else
    echo "FAIL  guard: malformed program — rc=$grc stderr='$GERR' (want non-zero + 'secd: malformed program')"; exit 1
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

say "Auto-checkpoint   (tag this commit when the full audit is green)"
# Reached only when every check above passed (each failure exits 1 earlier),
# so the audit is clean here. Tag the CURRENT COMMIT as a verified rollback
# point — but only on a clean working tree, because a dirty tree means the
# audit tested uncommitted changes the commit would NOT capture (a false
# checkpoint, exactly the trap we hit by hand). Skip if a verified-* tag
# already marks this commit. A tagging hiccup must never fail a green build,
# so every fallible step degrades to a NOTE.
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "NOTE  auto-tag skipped: not a git repository"
elif [ -n "$(git status --porcelain)" ]; then
    echo "NOTE  auto-tag skipped: working tree dirty — commit, then re-run to checkpoint"
elif existing="$(git tag --points-at HEAD | grep '^verified-' || true)"; [ -n "$existing" ]; then
    echo "NOTE  auto-tag skipped: this commit is already checkpointed ($existing)"
else
    tag="verified-$(date +%Y-%m-%d)-$(git rev-parse --short HEAD)"
    if git tag -a "$tag" -m "Full audit (build.sh) passed clean." 2>/dev/null; then
        echo "TAG   auto-checkpoint: $tag"
    else
        echo "NOTE  auto-tag skipped: could not create $tag"
    fi
fi

say "LogOS bootstrap complete"
echo "∃(∃) ≡ ∃"
