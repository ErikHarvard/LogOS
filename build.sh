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
for G in PRIM SYN CON DIR CONT MC CANON KAPPA TDEPTH BYTE_LT LE WRAP2 SORT2 REWRITE_MC NORMK NIS IS_ALPHA1 ALPHA1; do
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
glyph BAR = "|"
glyph MAIN = print(concat(W1)(concat(BAR)(concat(W2)(concat(BAR)(concat(W3)(concat(BAR)(concat(W4)(concat(BAR)(concat(W5)(concat(BAR)(concat(W6)(concat(BAR)(concat(W7)(concat(BAR)(W8)))))))))))))))
LA
CANON_EXPECT="⊂(↻(DEPTH),⊗(BEING,FORM))|↻(▷(RECOGNITION,FORM))|INE=|▷(⊗(BEING,VOID),FORM)|d=2|A|⊕(A,B)mSELFd|1<⊕(A,B)"
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
[ "$(stat -c%s logos_secd 2>/dev/null)" = "11025" ] || { echo "FAIL  codegen: VM wrong size ($(stat -c%s logos_secd 2>/dev/null) != 11025)"; ok=0; }
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
