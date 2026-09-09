#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
#  gate_normdrift.sh — THE BEHAVIOURAL DRIFT GATE (Tier 1 item, gate (b))
#
#  ★ WHY THIS EXISTS, AND WHY THE EXISTING CHECK DOES NOT COUNT.
#  build.sh:1167 does `grep -qF 'glyph IS_ALPHA1 = …' canon.la`. That is a
#  SOURCE DIFF — a static analyser — and this project's standing rule is that a
#  drift gate must be BEHAVIOURAL, because only execution counts. A textual
#  check passes on two copies that are byte-identical and WRONG, and fails on
#  two that are textually different and behaviourally identical. It answers a
#  different question than the one drift asks.
#
#  ★ THE POPULATION. The spec pipeline's export line landed in 9112c18, but
#  specpipe.la records that it was "inert until a consumer is converted" —
#  eleven generated modules, 313 glyphs, imported by NOTHING. The conversion
#  never happened, so the re-implementations remain. This gate does not remove
#  them; it makes their disagreement IMPOSSIBLE TO MISS.
#
#  ★ VALIDATED AGAINST A KNOWN PAST DEFECT, not a synthetic one.
#  build.sh:928 records it: a correction (91fc923) "reached the live NORMK
#  (WRAP2) and not SRC_NORMK". That is the exact shape this gate must catch —
#  one copy fixed, its twin silently left behind. A gate whose red path is
#  invented can be satisfied by an invented defect; this one is aimed at a
#  divergence that actually happened.
#
#  ★★ WHAT THIS GATE CAUGHT, ON ITS FIRST CORRECT RUN — recorded here because
#  the fix destroys the evidence, and a gate that carries the defect it caught
#  is a gate whose next reader knows what it is for.
#
#    2026-09-09, at HEAD 701f7f3:
#      canon.la:NORMK   MC(PRIM("BEING"))  ->  SELF
#      entropy.la:NKAP  MC(PRIM("BEING"))  ->  ↻(BEING)
#
#    canon.la:89 carries REWRITE_MC (metacursion-idempotence, ↻(BEING) ≡ SELF,
#    an algebra property of 𝒢 declared [W] in the white paper's algebra table).
#    entropy's MC arm was the bare else-branch with no rewrite at all.
#    ⇒ ONE NORMALISER APPLIED A DECLARED REWRITE AND ITS TWIN DID NOT — exactly
#    the shape build.sh:928 records from 91fc923, found by MEASUREMENT rather
#    than read from the record. Ruled a CONFORMANCE defect (not a semantics
#    change); entropy adopted REWRITE_MC in the same commit as this gate.
#    ★ The defect had a DIRECTION, which is what made it a defect rather than a
#    discrepancy: NKAP is used at :104/:127/:162/:167 purely as a canonical form
#    for COMPARISON, so without the rewrite entropy UNDER-REPORTS IDENTITY —
#    :127 can miss a real synonymy, :162 can report a false non-idempotence.
#
#  ⚠ A14: this is a GATE task (ω=0.5). Do not run it beside a deep front.
#     Check `~/logos-dispatch.sh advise` first — `~/logos-hw.sh gate` answers
#     "would a RED be believable", which is NOT the same as "may I start".
# ═══════════════════════════════════════════════════════════════════════════
set -uo pipefail
# ⚠ Flags must NOT be consumed as the directory argument. `cd "${1:-...}"` ran
#   before the --selftest branch, so `--selftest` was cd'd into and the script
#   died at exit 1 — a selftest that can never run is a red path that can never
#   fire, which is the exact defect this gate exists to catch.
SELF_SRC="$(readlink -f "$0")"
SELF=0
case "${1:-}" in
    --selftest) SELF=1; shift ;;
esac
cd "${1:-$(dirname "$0")}" || exit 1
ok=1
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cp canon.la tiny_host "$TMP/" 2>/dev/null || { echo "FAIL normdrift: fixture missing"; exit 1; }

# ── the shared input set. Deliberately includes the cases where normalisers
#    DISAGREE if one of them has drifted: a commutative mode (⊗ must NOT
#    reorder — E1 non-commutativity), an associative-shaped nest, and the one
#    documented rewrite (↻(BEING) → SELF).
INPUTS='SYN(PRIM("BEING"))(PRIM("VOID"))
SYN(PRIM("VOID"))(PRIM("BEING"))
CON(PRIM("BEING"))(PRIM("VOID"))
CON(PRIM("VOID"))(PRIM("BEING"))
MC(PRIM("BEING"))
DIR(PRIM("DEPTH"))(PRIM("RECOGNITION"))
CONT(PRIM("FORM"))(PRIM("DEPTH"))
SYN(SYN(PRIM("BEING"))(PRIM("VOID")))(PRIM("FORM"))'

# ── HOW EACH SITE IS PROBED, and why it is NOT uniform ───────────────────
#  ⚠ THE POPULATION IS HETEROGENEOUS AND MY FIRST DRAFT DID NOT KNOW IT.
#  canon:NORMK and entropy:NKAP return a canonical STRING. onf:CANONIQ and
#  sigil:CANONIQ return a NODE, which must be rendered by that module's OWN
#  CANON to compare. Comparing a node to a string yields "print: argument is
#  not a string", which the first draft reported as DRIFT: THREE false FAILs
#  beside one true one. A gate whose RED is mostly its own noise trains people
#  to ignore it, which is worse than no gate.
#
#  ★ EXCLUDED WITH A REASON, not silently: phonym:NORMP. Same SHAPE (walks
#    nodes, sorts commutative operands) but a different OBSERVABLE — it
#    normalises for PHONYM rendering and phonym.la has no κ renderer. Comparing
#    it here is a category error: the same population mistake that produced my
#    retracted glyph-count "law". Gating phonym's ordering needs its own
#    observable, not this one.
#
#  ★ cp-and-append everywhere, never import: onf exports ZERO constructors, so
#    an import probe cannot even build the input ("unbound variable 'SYN'").
run_norm() {
    local mod="$1" expr="$2" out="" i e
    [ -f "$mod" ] || return 1
    while IFS= read -r i; do
        [ -n "$i" ] || continue
        cp "$mod" "$TMP/probe.la"
        sed -i '0,/^glyph MAIN =/s//glyph MAIN_SHADOWED =/' "$TMP/probe.la"
        e="${expr//@/$i}"
        printf '\nglyph MAIN = print(%s)\n' "$e" >> "$TMP/probe.la"
        out="$out$( cd "$TMP" && ./tiny_host probe.la 2>&1 )"$'\n'
    done <<< "$INPUTS"
    printf '%s' "$out"
}

# ── --selftest: perturbs COPIES in a temp dir; never touches the tree ─────
#  ⚠ THE GATE IS CURRENTLY RED (entropy drift), SO A WHOLE-GATE RED TEST WOULD
#    BE VACUOUS — it would "go red" whether or not the perturbation did
#    anything. The red test is therefore PER ROW: perturb a module that
#    currently AGREES and require a NEW FAIL naming THAT module. A test that
#    cannot distinguish its own effect from a pre-existing failure proves
#    nothing, which is the inert-red-test trap POROS recorded this morning.
if [ "$SELF" = 1 ]; then
    echo "== SELFTEST: each red path must produce a NEW FAIL naming ITS OWN module =="
    fail=0
    base_out="$(bash "$SELF_SRC" . 2>&1)"
    # ★ TWO DIFFERENT IDIOMS, which is the whole point of the second row.
    #   R1 changes an OUTPUT LITERAL — catches "renders differently".
    #   R2 inverts the COMPARATOR in SORTC (STR_LE(CANON a)(CANON b) with the
    #      operands swapped) — catches "ORDERS differently" while touching no
    #      output literal at all. A gate that compared only rendered glyph names
    #      would catch R1 and MISS R2 on any input already in sorted order,
    #      which is why the input set carries BOTH operand orders of ⊗ and ⊕.
    #   R3 is the strongest of the three: it RE-INTRODUCES THE EXACT DEFECT this
    #   gate caught live on 2026-09-09 — entropy's MC arm reverted to the bare
    #   else-branch with no REWRITE_MC. Validating against a defect that actually
    #   happened beats any synthetic perturbation, and unlike build.sh:928 (which
    #   is a record) this one is reproducible on demand.
    for spec in 'R1|onf.la|output literal|concat("⊗(")|concat("XX(")' \
                'R2|sigil.la|comparator inversion|STR_LE(CANON(a))(CANON(b))|STR_LE(CANON(b))(CANON(a))' \
                'R3|entropy.la|the real 2026-09-09 defect|(la a. REWRITE_MC(self(a))))|(la a. concat("↻(")(concat(self(a))(")"))))'; do
        IFS='|' read -r tag mod idiom from to <<< "$spec"
        [ -f "$mod" ] || { echo "  $tag SKIP — $mod absent"; continue; }
        if grep -q "normdrift: $mod " <<< "$base_out"; then
            echo "  $tag ⚠ $mod ALREADY FAILS — a perturbation here is unattributable; skipping"
            fail=1; continue
        fi
        W="$(mktemp -d)"; cp ./*.la tiny_host "$W/" 2>/dev/null; cp "$SELF_SRC" "$W/g.sh"
        b4="$(md5sum "$W/$mod" | cut -d' ' -f1)"
        python3 - "$W/$mod" "$from" "$to" <<'PYX'
import sys
f,a,b=sys.argv[1],sys.argv[2],sys.argv[3]
t=open(f,encoding='utf-8').read()
open(f,'w',encoding='utf-8').write(t.replace(a,b,1))
PYX
        if [ "$b4" = "$(md5sum "$W/$mod" | cut -d' ' -f1)" ]; then
            echo "  $tag ⚠ PERTURBATION DID NOT APPLY to $mod — VACUOUS, not passing"; fail=1; rm -rf "$W"; continue
        fi
        out="$( cd "$W" && bash g.sh . 2>&1 )"
        if grep -q "normdrift: $mod .*REAL DRIFT" <<< "$out"; then
            echo "  $tag RED as required ($idiom) — the new FAIL names $mod"
        else
            echo "  $tag ✗ gate did NOT flag $mod under a real perturbation — blind to this idiom"; fail=1
        fi
        rm -rf "$W"
    done
    [ "$fail" -eq 0 ] && { echo "SELFTEST OK — every red path fires and names its own site"; exit 0; }
    echo "SELFTEST INCOMPLETE"; exit 1
fi

echo "== behavioural drift: every κ-normaliser must agree on the same inputs =="
BASE="$(run_norm canon.la 'NORMK(@)')"
[ -n "$BASE" ] || { echo "FAIL  normdrift: SOURCE produced nothing — gate never ran"; exit 1; }
if grep -qE 'error|not a string' <<< "$BASE"; then
    echo "FAIL  normdrift: the SOURCE probe itself errored — fix the probe before trusting any RED"; exit 1; fi
DISTINCT=$(sort -u <<< "$BASE" | grep -c .)
[ "$DISTINCT" -ge 4 ] || { echo "FAIL  normdrift: input set gives only $DISTINCT distinct outputs — not discriminating"; ok=0; }

for row in "entropy.la|NKAP(@)" "onf.la|CANON(CANONIQ(@))" "sigil.la|CANON(CANONIQ(@))"; do
    mod="${row%%|*}"; expr="${row##*|}"
    [ -f "$mod" ] || { echo "SKIP  normdrift: $mod absent"; continue; }
    GOT="$(run_norm "$mod" "$expr")"
    # ★ A BROKEN PROBE IS NOT DRIFT. Without this split the gate blames the
    #   module for the gate's own failure to build a comparable value.
    if grep -qE 'error|not a string' <<< "$GOT"; then
        echo "FAIL  normdrift: PROBE BROKEN for $mod ($expr) — NOT evidence of drift"
        grep -m1 -E 'error|not a string' <<< "$GOT" | sed 's/^/        /'
        ok=0; continue
    fi
    if [ "$GOT" != "$BASE" ]; then
        echo "FAIL  normdrift: $mod DISAGREES with canon.la:NORMK — REAL DRIFT"
        diff <(printf '%s' "$BASE") <(printf '%s' "$GOT") | head -8 | sed 's/^/        /'
        ok=0
    fi
done

[ "$ok" -eq 1 ] && echo "PASS  normdrift: every re-implementation agrees with canon.la:NORMK on a discriminating input set" || exit 1
