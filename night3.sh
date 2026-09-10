#!/bin/bash
# Continuation of night2.sh. WAITS for it rather than running concurrently —
# one heavy job at a time is the rule. Same safety contract: no push, no shared
# files, no touching ~/logos, every diagnostic captured, rc>=128 labelled KILLED.
set -u
B="$HOME/logos-b"; L="$B/.night3.log"; : > "$L"
say(){ echo "[$(date +%H:%M:%S)] $*" >> "$L"; }
run(){ local lbl=$1 lf=$2; shift 2; local s=$(date +%s)
  "$@" > "$lf" 2>&1; local rc=$?
  say "  $lbl rc=$rc $(( $(date +%s)-s ))s  $(grep -c '^PASS' "$lf" 2>/dev/null) PASS / $(grep -c '^FAIL' "$lf" 2>/dev/null) FAIL"
  [ "$rc" -ge 128 ] && say "     ^ rc>=128 = KILLED, not failed"
  grep '^FAIL' "$lf" 2>/dev/null | head -3 | sed 's/^/     /' >> "$L"; return $rc; }

for i in $(seq 1 240); do
  pgrep -f 'night2\.sh$' >/dev/null 2>&1 || break
  sleep 60
done
say "=== night3 start (night2 finished or absent) ==="

# ---- 7. re-verify all six boot arms against the CURRENT asm.la -------------
#   The freeze was proven on an asm.la that has since gained the P66 work.
#   "It passed before the last change" is not a verified state.
say "step 7: six boot arms with the current asm.la (~1.5 h)"
cp "$B/.imm64/asm.la" "$B/.bootfix3/asm.la" 2>/dev/null
run bootarms "$B/.n_arms.log" "$B/bootfix3_run.sh"
for A in HH2B HH2C; do
  d="$B/.bootfix3_$A"
  if [ -s "$d/elfobj_out.o" ] && [ -s "$d/nasm_ref.o" ]; then
    ( cd "$d"
      objcopy -O binary --only-section=.boot32 elfobj_out.o o.bin 2>/dev/null
      objcopy -O binary --only-section=.boot32 nasm_ref.o   n.bin 2>/dev/null
      python3 "$B/maskrel.py" elfobj_out.o .boot32 o.bin om.bin >/dev/null 2>&1
      python3 "$B/maskrel.py" nasm_ref.o   .boot32 n.bin nm.bin >/dev/null 2>&1
      if cmp -s om.bin nm.bin; then echo "PASS $A .boot32 identical outside relocs"
      else echo "FAIL $A .boot32 differs"; fi
      diff <(readelf -rW nasm_ref.o|awk 'NF>3&&$1~/^[0-9a-f]+$/{print $1,$3,$5,$6,$7}'|sort) \
           <(readelf -rW elfobj_out.o|awk 'NF>3&&$1~/^[0-9a-f]+$/{print $1,$3,$5,$6,$7}'|sort) >/dev/null \
        && echo "PASS $A relocation tables identical" || echo "FAIL $A relocs differ" ) >> "$B/.n_arms.log" 2>&1
  else
    echo "FAIL $A: no object — refusing to compare" >> "$B/.n_arms.log"
  fi
done
say "  arm comparison: $(grep -c '^PASS' "$B/.n_arms.log") PASS / $(grep -c '^FAIL' "$B/.n_arms.log") FAIL"

# ---- 8. the LA-ONLY CHAIN end to end: asm.la -> link.la -> image -----------
#   The milestone claim is "no nasm, no ld". Each half is gated separately;
#   the WHOLE chain on the real boot fixture is the thing nobody has run.
say "step 8: full LA-only chain on the boot fixture (asm.la -> link.la)"
{
  D="$B/.n_chain"; rm -rf "$D"; mkdir -p "$D"
  cp "$B/.bootfix3"/* "$D/" 2>/dev/null
  cp "$B"/link.la "$B"/link_script.la "$B"/link_reloc.la "$B"/link_layout.la "$D/" 2>/dev/null
  cd "$D" || exit 1
  cp asm_in.asm asm_in.keep 2>/dev/null
  if [ ! -s elfobj_out.o ]; then
    timeout 3000 ./logos_secd > secd.out 2>&1
  fi
  if [ -s elfobj_out.o ]; then
    echo "asm.la produced $(stat -c%s elfobj_out.o) B object"
    ld elfobj_out.o -o ld_ref.elf 2>ld.err && echo "ld control: $(stat -c%s ld_ref.elf) B" || echo "NOTE ld refused: $(head -1 ld.err)"
    printf 'elfobj_out.o\n' > link_inputs.txt
    timeout 3000 ./tiny_host link_reloc.la > link.log 2>&1
    if [ -s link_out ]; then
      echo "PASS LA-only chain: link.la produced $(stat -c%s link_out) B with NO nasm and NO ld"
      readelf -hW link_out 2>/dev/null | grep -E 'Entry point' | sed 's/^/  /'
    else
      echo "FAIL LA-only chain: link.la produced nothing: $(tail -1 link.log)"
    fi
  else
    echo "FAIL LA-only chain: asm.la produced no object: $(tail -1 secd.out)"
  fi
} > "$B/.n_chain.log" 2>&1
say "  chain: $(grep -cE '^PASS' "$B/.n_chain.log") PASS / $(grep -cE '^FAIL' "$B/.n_chain.log") FAIL"

# ---- 9. does link.la handle every type asm.la can EMIT? -------------------
say "step 9: asm.la's emitted type set vs link.la's handled set"
{
  echo "link.la handles:"; grep -oE 'int_eq\(ty\)\([0-9]+\)' "$B/link_reloc.la" | grep -oE '[0-9]+' | sort -n -u | tr '\n' ' '; echo
  echo "asm.la can emit (from every fixture on disk):"
  for f in "$B"/.bootfix3_*/nasm_ref.o "$B"/.elfreg/*.ref.o "$B"/.seamgate/nasm_ref.o; do
    [ -s "$f" ] && readelf -rW "$f" 2>/dev/null | awk 'NF>3&&$1~/^[0-9a-f]+$/{print $3}'
  done | sort -u | tr '\n' ' '; echo
} > "$B/.n_typeset.log" 2>&1
say "  type-set comparison written"

# ---- 10. claimed-vs-exercised, beyond relocations -------------------------
say "step 10: what else does link.la claim that nothing tests?"
{
  echo "== glyphs matching IS<CAP> (a claimed capability predicate) =="
  grep -oE '^glyph IS[A-Z0-9_]+' "$B"/link*.la | sed 's/.*glyph //' | sort -u | while read g; do
    used=$(grep -c "$g" "$B"/link*.la | awk -F: '{s+=$2} END{print s}')
    intest=$(grep -lc "$g" "$B"/gate_link*.sh 2>/dev/null | wc -l)
    printf '  %-14s refs=%-3s gates-mentioning=%s\n' "$g" "$used" "$intest"
  done
} > "$B/.n_claims.log" 2>&1
say "  capability audit written ($(wc -l < "$B/.n_claims.log") lines)"

say "=== night3 complete ==="
say "SUMMARY:"
for f in .n_arms .n_chain; do
  [ -f "$B/$f.log" ] && say "  $f: $(grep -c '^PASS' "$B/$f.log") PASS / $(grep -c '^FAIL' "$B/$f.log") FAIL"
done
