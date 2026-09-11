#!/usr/bin/env bash
# gate_metalogic_deployed.sh — E15: EXECUTE the connectives metalogic_spec.la
#   DEPLOYS, on every row, against truth tables DERIVED from the Three Laws.
#
#   ./gate_metalogic_deployed.sh [module.la]        default: metalogic.la
#
# THE DEFECT THIS CLOSES (rulings/E15.md; measured by The Lieutenant 2026-09-09).
#   metalogic_spec.la's META_DEBUG runs each glyph's tests against the spec's
#   in-memory VALUE (AND is even imported from specpipe.la), while DEPLOY writes a
#   SEPARATE string (SRC_NOT, SRC_AND, ...) into metalogic.la. Nothing checked the
#   two denote one function: with SRC_NOT = "la b. b(TRUE)(TRUE)" the spec printed
#   NOT: PASS and module VERIFIED, and deployed a negation that returns TRUE for
#   everything. The tests also ran 2 of 4 rows per binary connective (AND never
#   with a false first argument, OR never with a true one), against literals.
#
# ⚠ MEASURED 2026-09-10, correcting part of the ruling. The build block's own
#   stand-alone witness (build.sh, after the spec run) ALSO executes a copy of the
#   deployed module, and it DOES go red on both mutations the ruling used —
#   incidentally: SRC_NOT through WELLFORMED and IMPLIES, SRC_AND through
#   NC_TYPECHECK. It reaches the connectives only on the rows its law-witnesses
#   happen to use: SRC_OR broken on TT,TF ("la a. la b. a(FALSE)(b)") passes the
#   spec AND that witness byte-for-byte. This gate is the one that covers every row.
#
# WHAT THIS GATE DOES — one part per measurement in the ruling:
#   (3) it EXECUTES THE DEPLOYED FILE, never the spec's value: a harness is
#       appended to a copy and run on the C host AND on the native SECD VM, the VM
#       built fresh in a scratch dir (a VM left in the tree could be a stale
#       artifact certified as current);
#   (2) it runs EVERY row: NOT on T,F; AND, OR, IMPLIES on TT,TF,FT,FF;
#   (1) the expected rows are DERIVED, never typed: for each connective every
#       candidate truth function (4 unary, 16 binary) is enumerated and kept only
#       if it satisfies that connective's sentence in Codex II Proof Table 4.1,
#       and the gate REQUIRES EXACTLY ONE SURVIVOR. A sentence that admits no
#       table, or two, fails loudly: the Laws must DETERMINE the table, not merely
#       permit it. The Laws are then checked ACROSS the derived tables.
#
# SOURCE, pinned by content (a line count is not a pin):
#   ~/Downloads/CODICIES/2. Logos & Paradox/L&P English/Logos & Paradox English.tex
#   sha256 d3acf8b940df387a…  Proof Table 4.1, lines 1837-1842.
#
# ⚠ HONEST BOUND. Each law_* below is an ENCODING of a Table 4.1 sentence. What is
#   witnessed: (a) each sentence, so encoded, admits exactly one table — checked,
#   not assumed; (b) the deployed module computes that table on every row, on both
#   engines. NOT witnessed: that this encoding is the only reading of the sentence.
#   That is E15's other register — encodings are stipulated, tables are derived —
#   and this gate stays inside it. The Church encoding and the render T->1, F->0
#   are stipulated too. Only NOT is derived from two laws (NC + EM); AND, OR and
#   IMPLIES are derived from sentences the Codex states as characterizations.
#
# ⚠ IFF (item 5) is derived here and NOT DEPLOYED: Table 4.1 names five
#   connectives and metalogic.la carries four. A NOTE, not a FAIL — this gate
#   tests what is deployed; adding IFF is a spec change, not a gate change.
set -u
cd "$(dirname "$0")" || exit 1
ROOT=$PWD
MOD="${1:-metalogic.la}"
[ -f "$MOD" ] || { echo "FAIL  metalogic-deployed: module not found: $MOD"; exit 1; }
MOD="$(cd "$(dirname "$MOD")" && pwd)/$(basename "$MOD")"
W="$(mktemp -d)" || exit 1
trap 'rm -rf "$W"' EXIT
fail=0

# ── THE DERIVATION ──────────────────────────────────────────────────────────
# Truth values are 1/0. A unary table is two bits f(T)f(F); a binary table is
# four bits f(T,T)f(T,F)f(F,T)f(F,F). Each law_* takes a CANDIDATE table and
# returns 0 iff the candidate satisfies the sentence, on every row.
law_not(){   # item 2: "NOT A is true iff A does not hold", FORCED by the exclusion
             # self-identity imposes — as two laws over every a:
             #   Non-Contradiction  NOT(a AND NOT a)   not both
             #   Excluded Middle    a OR NOT a         not neither
  local t=$1 a na i=0
  for a in 1 0; do na=${t:i:1}; i=$((i+1))
    [ $(( a & na )) -eq 0 ] || return 1
    [ $(( a | na )) -eq 1 ] || return 1
  done; return 0; }
law_and(){   # item 1: "A AND B is true iff A is true and B is true
             #          (both must be themselves for the conjunction to be itself)"
  local t=$1 a b i=0 c
  for a in 1 0; do for b in 1 0; do c=${t:i:1}; i=$((i+1))
    if [ $a -eq 1 ] && [ $b -eq 1 ]; then [ "$c" -eq 1 ] || return 1
    else [ "$c" -eq 0 ] || return 1; fi
  done; done; return 0; }
law_or(){    # item 3: "A OR B is true iff at least one of A, B is true
             #          (the middle is excluded)"
  local t=$1 a b i=0 d
  for a in 1 0; do for b in 1 0; do d=${t:i:1}; i=$((i+1))
    if [ $a -eq 1 ] || [ $b -eq 1 ]; then [ "$d" -eq 1 ] || return 1
    else [ "$d" -eq 0 ] || return 1; fi
  done; done; return 0; }
law_implies(){ # item 4: "A -> B is false only when A is true and B is false —
               #          recognition that leads from truth to falsehood is failed"
  local t=$1 a b i=0 r
  for a in 1 0; do for b in 1 0; do r=${t:i:1}; i=$((i+1))
    if [ $a -eq 1 ] && [ $b -eq 0 ]; then [ "$r" -eq 0 ] || return 1
    else [ "$r" -eq 1 ] || return 1; fi
  done; done; return 0; }
law_iff(){   # item 5: "A and B are the same in truth-value"
  local t=$1 a b i=0 e
  for a in 1 0; do for b in 1 0; do e=${t:i:1}; i=$((i+1))
    if [ $a -eq $b ]; then [ "$e" -eq 1 ] || return 1
    else [ "$e" -eq 0 ] || return 1; fi
  done; done; return 0; }

derive(){ # $1 law, $2 width (2|4) -> prints the UNIQUE surviving table
  local fn=$1 w=$2 k j t surv="" count=0
  for (( k=0; k < (1 << w); k++ )); do
    t=""; for (( j=w-1; j>=0; j-- )); do t+=$(( (k >> j) & 1 )); done
    if "$fn" "$t"; then surv=$t; count=$((count+1)); fi
  done
  if [ $count -ne 1 ]; then
    echo "FAIL  metalogic-deployed: $fn admits $count tables — its sentence does not DETERMINE the table" >&2
    return 1
  fi
  printf '%s' "$surv"
}
NOT_T=$(derive law_not 2) || fail=1
AND_T=$(derive law_and 4) || fail=1
OR_T=$(derive law_or 4) || fail=1
IMP_T=$(derive law_implies 4) || fail=1
IFF_T=$(derive law_iff 4) || fail=1
[ $fail -eq 0 ] || { echo "FAIL  metalogic-deployed: derivation incomplete — refusing to compare against a partial expectation"; exit 1; }
echo "PASS  metalogic-deployed: derived NOT=$NOT_T AND=$AND_T OR=$OR_T IMPLIES=$IMP_T — each the UNIQUE table its Table 4.1 sentence admits"

# ── THE LAWS, ACROSS THE DERIVED TABLES ─────────────────────────────────────
# row index of (a,b) is (1-a)*2 + (1-b); of a unary a is (1-a).
laws_ok=1
for a in 1 0; do
  na=${NOT_T:1-a:1}
  [ "${AND_T:(1-a)*2+(1-na):1}" -eq 0 ] || { echo "FAIL  metalogic-deployed: Non-Contradiction broken across tables: $a AND NOT $a is true"; laws_ok=0; }
  [ "${OR_T:(1-a)*2+(1-na):1}" -eq 1 ]  || { echo "FAIL  metalogic-deployed: Excluded Middle broken across tables: $a OR NOT $a is false"; laws_ok=0; }
  [ "${AND_T:(1-a)*3:1}" -eq $a ] && [ "${OR_T:(1-a)*3:1}" -eq $a ] || { echo "FAIL  metalogic-deployed: Identity broken across tables: $a AND/OR $a is not $a"; laws_ok=0; }
  for b in 1 0; do
    ab=${IMP_T:(1-a)*2+(1-b):1}; ba=${IMP_T:(1-b)*2+(1-a):1}
    [ "${AND_T:(1-ab)*2+(1-ba):1}" -eq "${IFF_T:(1-a)*2+(1-b):1}" ] || { echo "FAIL  metalogic-deployed: item 5's two statements disagree at ($a,$b): (A->B) AND (B->A) is not A<->B"; laws_ok=0; }
  done
done
if [ $laws_ok -eq 1 ]; then echo "PASS  metalogic-deployed: the Three Laws hold ACROSS the derived tables (NC via AND/NOT, EM via OR/NOT, Identity as AND/OR idempotence, item 5's two statements agree)"; else fail=1; fi

WANT="TRUE:1 FALSE:0 NOT:$NOT_T AND:$AND_T OR:$OR_T IMPLIES:$IMP_T"

# ── THE HARNESS — appended to a COPY of the deployed module ─────────────────
# Inputs are the harness's own canonical Church booleans, so a broken deployed
# TRUE/FALSE is caught by its own render, not silently fed to every row.
cp "$MOD" "$W/h.la"
cat >> "$W/h.la" <<'LA'
glyph GATE_T = la t. la f. t
glyph GATE_F = la t. la f. f
glyph GATE_B = la b. b("1")("0")
glyph GATE_U = la g. concat(GATE_B(g(GATE_T)))(GATE_B(g(GATE_F)))
glyph GATE_R = la g. concat(GATE_B(g(GATE_T)(GATE_T)))(concat(GATE_B(g(GATE_T)(GATE_F)))(concat(GATE_B(g(GATE_F)(GATE_T)))(GATE_B(g(GATE_F)(GATE_F)))))
glyph GATE_P1 = concat("TRUE:")(GATE_B(TRUE))
glyph GATE_P2 = concat(GATE_P1)(concat(" FALSE:")(GATE_B(FALSE)))
glyph GATE_P3 = concat(GATE_P2)(concat(" NOT:")(GATE_U(NOT)))
glyph GATE_P4 = concat(GATE_P3)(concat(" AND:")(GATE_R(AND)))
glyph GATE_P5 = concat(GATE_P4)(concat(" OR:")(GATE_R(OR)))
glyph GATE_P6 = concat(GATE_P5)(concat(" IMPLIES:")(GATE_R(IMPLIES)))
glyph MAIN = print(GATE_P6)
LA

compare(){ # $1 engine, $2 got — name every connective whose rows differ
  local eng=$1 got=$2 w g
  if [ "$got" = "$WANT" ]; then
    echo "PASS  metalogic-deployed: $eng executes the DEPLOYED $(basename "$MOD") on all 14 rows = the derived tables"
    return 0
  fi
  echo "FAIL  metalogic-deployed: $eng rows differ from the law-derived tables"
  for w in $WANT; do
    g=$(tr ' ' '\n' <<< "$got" | grep -m1 "^${w%%:*}:" || true)
    [ "$g" = "$w" ] || echo "      ${w%%:*}: deployed ${g#*:} — derived ${w#*:}   (rows ${w%%:*}=NOT: T,F · binary: TT,TF,FT,FF)"
  done
  return 1
}

HOST="$(timeout 120 "$ROOT/tiny_host" "$W/h.la" 2>"$W/host.err")"; rc=$?
if [ $rc -ne 0 ]; then echo "FAIL  metalogic-deployed: host run exited rc=$rc: $(head -c 200 "$W/host.err")"; fail=1
else compare "host" "$HOST" || fail=1; fi

# the native VM, built fresh from secd.la in the scratch dir
cp "$ROOT/secd.la" "$ROOT/codegen.la" "$W/"
cp "$W/h.la" "$W/logos_source.la"
( cd "$W" && timeout 300 "$ROOT/tiny_host" secd.la >"$W/secd.out" 2>&1 ); rc=$?
if [ $rc -ne 0 ] || [ ! -x "$W/logos_secd" ]; then echo "FAIL  metalogic-deployed: VM build from secd.la failed rc=$rc"; fail=1
else
  ( cd "$W" && timeout 300 "$ROOT/tiny_host" codegen.la >"$W/cg.out" 2>&1 ); rc=$?
  if [ $rc -ne 0 ]; then echo "FAIL  metalogic-deployed: codegen of the harness failed rc=$rc: $(tail -c 200 "$W/cg.out")"; fail=1
  else
    VM="$(cd "$W" && timeout 120 ./logos_secd 2>"$W/vm.err")"; rc=$?
    if [ $rc -ne 0 ]; then echo "FAIL  metalogic-deployed: VM run exited rc=$rc: $(head -c 200 "$W/vm.err")"; fail=1
    else compare "native VM" "$VM" || fail=1; fi
  fi
fi

echo "NOTE  metalogic-deployed: IFF derived as $IFF_T and NOT DEPLOYED — Table 4.1 item 6 names five connectives; $(basename "$MOD") carries four"
[ $fail -eq 0 ] || exit 1
exit 0
