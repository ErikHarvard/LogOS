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
