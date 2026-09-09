#!/usr/bin/env bash
# M76 — enumerate the κ-duplication surface BY SHAPE, not by a hardcoded list.
# The predicate, published so M0a's drift gate can be built against it.
#   For each *.la that does NOT import("canon.la"): count how many of canon.la's
#   OWN exported κ-machinery names it re-declares as `^glyph <NAME>`.
# Generic Church boilerplate is excluded by design: Z TRUE FALSE IF AND NOT OR are
# defined by nearly every module and including them buries the signal in ~40 rows.
# ⚠ Consume flags BEFORE the cd, or `cd "${1:-...}"` treats --selftest as a
#   directory and dies. (Made this exact mistake in gate_normdrift.sh the same
#   afternoon: a flag eaten by a positional default is a selftest that can never
#   run, i.e. a control that cannot fire.)
SELF_SRC="$(readlink -f "$0")"   # absolute: $0 is relative and breaks after the cd
SELFTEST=0
case "${1:-}" in --selftest) SELFTEST=1; shift ;; esac
case "${2:-}" in --selftest) SELFTEST=1 ;; esac
cd "${1:-$HOME/logos-b}" || exit 1

# ── --selftest: the two controls, so the number cannot rot into a habit ──────
#  A census is an instrument and its output gets published. These are the checks
#  that were run by hand before it was committed; baking them in means the next
#  reader can re-run them instead of trusting that someone did.
if [ "$SELFTEST" = 1 ]; then
    b=$("$SELF_SRC" . | grep -c .)
    # POSITIVE: adding a κ name to a TRACKED file must raise that file's count.
    cp lexicon.la /tmp/.m76ctl.$$ 2>/dev/null || exit 1
    printf '\nglyph NORMK = la x. x\n' >> lexicon.la
    n=$("$SELF_SRC" . | awk '$2=="lexicon.la"{print $1}')
    cp /tmp/.m76ctl.$$ lexicon.la; rm -f /tmp/.m76ctl.$$
    [ "$n" = "7" ] && echo "  positive control OK (lexicon 6 -> 7 with NORMK planted)" \
                   || { echo "  ✗ POSITIVE CONTROL FAILED (got '$n', expected 7) — census is not detecting"; exit 1; }
    # NEGATIVE: a file that imports canon.la must be EXCLUDED, not counted.
    bad=0
    for f in prop.la specpipe.la metaprop.la obscurantism.la; do
        grep -q 'import("canon.la")' "$f" 2>/dev/null || continue
        "$SELF_SRC" . | grep -q " $f " && { echo "  ✗ NEGATIVE CONTROL FAILED — $f imports canon yet is counted"; bad=1; }
    done
    [ "$bad" -eq 0 ] && echo "  negative control OK (canon importers excluded)"
    echo "  rows: $b  → distinct sites: $((b-4))   [minus 3 spec/generated twins, minus canon_spec]"
    exit $bad
fi
KAPPA="PRIM SYN CON DIR CONT MC CANON KAPPA NORMK NIS MONO REN ETYM COLLAPSE MCOLLAPSE AUTO_OK SORT2 LE REWRITE_MC REWRITE_SYN IS_ALPHA1 ALPHA1 TDEPTH"
for f in *.la; do
  [ "$f" = canon.la ] && continue
  # ⚠ SKIP UNTRACKED SCRATCH. This globs *.la, so handoff artifacts and probe
  #   files land in the population and inflate the count. On 2026-09-09 it began
  #   counting TRACKB-metaglyph-M67-on-2cca4b4.la — my own handoff copy — as a
  #   15th duplication site. The published 14 predates that file and is correct,
  #   but the instrument would have drifted upward on its next run.
  git ls-files --error-unmatch "$f" >/dev/null 2>&1 || continue
  grep -q 'import("canon.la")' "$f" && continue
  n=0; hits=""
  for g in $KAPPA; do grep -qE "^glyph +$g( |=)" "$f" && { n=$((n+1)); hits="$hits $g"; }; done
  [ "$n" -ge 1 ] && printf "%3d  %-24s %s\n" "$n" "$f" "$hits"
done | sort -rn
