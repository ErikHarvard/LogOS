#!/usr/bin/env bash
# q1_diff — run one .la program on all five engines and compare.
#
# Recipe per the project's differential-testing note. ★ UNIQUE FILE PER RUN: a
# shared prog.la read by one engine while another writes it produces wild fake
# nondeterminism (RUN_SM worst), which has already cost this project real time
# and is NOT a GC bug. Serial by construction here.
#
# TARGETING: the last differential covered 120 random programs plus div/mod-by-
# zero, negatives and empty strings — 0 mismatches. Repeating that learns nothing.
# 187 commits have landed since, and the trimodal layer put UTF-8 SIGILS through
# every string path (⊗ ⊕ ▷ ⊂ ↻, IPA in phonym). Whether five engines agree on
# multi-byte str_head/str_tail/str_len is untested, and is where a silent
# disagreement would hide.
set -uo pipefail
cd "$HOME/logos" || exit 1
W="$HOME/logos/.q1"; mkdir -p "$W"
PROG="${1:-}"; TAG="${2:-adhoc}"
u="$W/p_${TAG}_$$.la"
[ -n "$PROG" ] && [ -f "$PROG" ] && cp "$PROG" "$u"

# ── PROBES, inlined so the harness is SELF-CONTAINED. Loose .la fixtures at repo
# root would become Tier-1 orphans by Q0's own measure — files no script
# mentions. A harness that carries its own probes cannot drift from them.
case "${2:-}" in
    chr)
      cat > "$u" <<'PROBE_EOF'
# chr takes a STRING (chr("65")), not an integer — corrected after the first probe
# passed an int and got "chr: argument is not a string" from the C host.
# ord is deliberately EXCLUDED: it is unbound on eval.la / RUN_BYTES / RUN_SM, so
# including it makes every engine fail for that reason and hides everything else.
glyph J = la a. la b. concat(a)(concat("|")(b))
glyph L = la s. int_to_str(str_to_int(str_len(s)))
glyph MAIN = print(
  J(chr("65"))(
  J(chr("73"))(
  J(L(chr("0")))(
  J(L(concat(chr("65"))(concat(chr("0"))(chr("66")))))(
  J(L(chr("200")))(
  J(str_head(concat(chr("200"))(chr("65"))))(
    L(concat(chr("255"))(chr("128")))))))))) 
PROBE_EOF
      ;;
    chrord)
      cat > "$u" <<'PROBE_EOF'
# chr/ord round-trip across the byte range, including the high bytes that make
# strings binary-safe (the property elf.la depends on).
glyph J = la a. la b. concat(a)(concat("|")(b))
glyph RT = la n. int_to_str(ord(chr(n)))
glyph MAIN = print(
  J(RT(0))(
  J(RT(65))(
  J(RT(127))(
  J(RT(128))(
  J(RT(200))(
  J(RT(255))(
  J(int_to_str(str_to_int(str_len(chr(0)))))(
    int_to_str(ord(str_head(concat(chr(200))(chr(65))))))))))))) 
PROBE_EOF
      ;;
    control)
      cat > "$u" <<'PROBE_EOF'
glyph MAIN = print(concat("ab")("cd"))
PROBE_EOF
      ;;
    rec)
      cat > "$u" <<'PROBE_EOF'
# Deep Z-recursion. secd.asm carries a documented NON-TAIL dump-depth limit, and
# the four engines have entirely different stack disciplines — the C host recurses
# on the C stack, secd on its own dump, eval.la interprets, RUN_BYTES/RUN_SM run a
# stack machine. If depth handling diverges, this is where it shows.
# TAIL and NON-TAIL are probed separately: TCO should keep the first bounded while
# the second grows the dump.
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph J = la a. la b. concat(a)(concat("|")(b))
# tail-recursive count-down: should run in bounded space on an engine with TCO
glyph TAILC = Z(la self. la n. la acc. IF0(n)(la _. acc)(la _. self(sub(n)(1))(add(acc)(1))))
glyph IF0 = la n. la t. la f. (la c. c(t)(f)("!"))(int_eq(n)(0))
# NON-tail: the add happens after the call returns, so the dump must grow
glyph SUMN = Z(la self. la n. IF0(n)(la _. 0)(la _. add(n)(self(sub(n)(1)))))
glyph MAIN = print(
  J(int_to_str(TAILC(2000)(0)))(
  J(int_to_str(SUMN(100)))(
  J(int_to_str(SUMN(500)))(
    int_to_str(SUMN(1000))))))
PROBE_EOF
      ;;
    rec2)
      cat > "$u" <<'PROBE_EOF'
# Depth reduced so the INTERPRETED engines can finish. The first probe used
# SUMN(1000) and every engine but the C host returned empty — which read as a
# divergence and was actually my harness's per-engine timeout: a thousand non-tail
# frames on a stack machine that is itself interpreted is enormously expensive.
# A probe the slowest engine cannot finish measures the harness, not the engines.
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph J = la a. la b. concat(a)(concat("|")(b))
glyph IF0 = la n. la t. la f. (la c. c(t)(f)("!"))(int_eq(n)(0))
glyph TAILC = Z(la self. la n. la acc. IF0(n)(la _. acc)(la _. self(sub(n)(1))(add(acc)(1))))
glyph SUMN = Z(la self. la n. IF0(n)(la _. 0)(la _. add(n)(self(sub(n)(1)))))
glyph MAIN = print(J(int_to_str(TAILC(60)(0)))(J(int_to_str(SUMN(20)))(int_to_str(SUMN(60)))))
PROBE_EOF
      ;;
    utf8)
      cat > "$u" <<'PROBE_EOF'
glyph J = la a. la b. concat(a)(concat("|")(b))
glyph S = "⊗↻∃"
glyph MAIN = print(
  J(str_head(S))(
  J(str_head(str_tail(S)))(
  J(int_to_str(str_to_int(str_len(S))))(
  J(str_head("é"))(
  J(concat(str_head(S))(str_tail(S)))(
    str_head(str_tail(str_tail(S)))))))))
PROBE_EOF
      ;;
    wrap)
      cat > "$u" <<'PROBE_EOF'
# 64-bit wrap boundaries. tiny_host computes add/sub/mul through UNSIGNED long
# specifically so signed overflow (UB in C) matches the SECD VM's wrap. That
# reasoning has never been differentially tested.
glyph J = la a. la b. concat(a)(concat("|")(b))
glyph MAX = 9223372036854775807
glyph MIN = sub(0)(9223372036854775807)
glyph MAIN = print(
  J(int_to_str(add(MAX)(1)))(
  J(int_to_str(sub(MIN)(1)))(
  J(int_to_str(mul(MAX)(2)))(
  J(int_to_str(mul(MIN)(MIN)))(
  J(int_to_str(sub(0)(MIN)))(
  J(int_to_str(add(MAX)(MAX)))(
    int_to_str(mul(4294967296)(4294967296))))))))) 
PROBE_EOF
      ;;
    *) : ;;   # $1 is a path: use it as given
esac


# ★ TIMEOUT MUST NEVER LOOK LIKE A RESULT. Three "divergences" in this sweep were
# my own per-engine timeouts reported as empty output, which is indistinguishable
# from a real mismatch. timeout(1) exits 124; every engine now reports <TIMEOUT Ns>
# explicitly, so a limit of the harness can never be read as a finding.
run_engine(){ local lim=$1; shift; local o rc
  o=$(timeout "$lim" "$@" 2>&1); rc=$?
  if [ $rc -eq 124 ]; then printf '<TIMEOUT %ss>' "$lim"; else printf '%s' "$o"; fi; }
host=$(run_engine 300 ./tiny_host "$u")

# eval.la — self-interpreting evaluator
sed '/^glyph MAIN/,$d' eval.la > "$W/e_$TAG.la"
printf 'glyph MAIN = RUN(PARSE_PROGRAM(read_file("%s")))\n' "$u" >> "$W/e_$TAG.la"
evala=$(run_engine 600 ./tiny_host "$W/e_$TAG.la")

# bytecode.la — two interpreters
for eng in RUN_BYTES RUN_SM; do
  sed '/^glyph MAIN/,$d' bytecode.la > "$W/b_${TAG}_$eng.la"
  printf 'glyph MAIN = (la _. print(""))(%s_PROGRAM(PARSE_PROGRAM(read_file("%s"))))\n' "$eng" "$u" >> "$W/b_${TAG}_$eng.la"
  # ★ NO `sed '$d'` here. The note says to strip the trailing blank line the
  # (la _. print("")) wrapper emits — but $( ) has ALREADY stripped trailing
  # newlines, so `$d` deletes the CONTENT instead. That made both bytecode
  # engines return empty and read as a UTF-8 divergence in the trimodal layer.
  # Caught by the ASCII control, which disagreed identically.
  out=$(run_engine 900 ./tiny_host "$W/b_${TAG}_$eng.la")
  eval "res_$eng=\$out"
done

printf '%-12s |%s|\n' "C host"    "$host"
printf '%-12s |%s|\n' "eval.la"   "$evala"
printf '%-12s |%s|\n' "RUN_BYTES" "${res_RUN_BYTES:-}"
printf '%-12s |%s|\n' "RUN_SM"    "${res_RUN_SM:-}"
if [ "$host" = "$evala" ] && [ "$host" = "${res_RUN_BYTES:-}" ] && [ "$host" = "${res_RUN_SM:-}" ]; then
  echo "AGREE"
else
  echo "★ DISAGREE"
fi
rm -f "$u"
