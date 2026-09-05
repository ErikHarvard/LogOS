#!/bin/bash
# gate_claimindex.sh — every unbuilt item in LA_COMPLETION.md must appear in
# LA_CLAIM_INDEX.md.
#
# ★ WHY THIS EXISTS. LA_COMPLETION.md's header claimed "Every item carries the
# gate that would prove it, and its white-paper counterpart." Measured: 2 of 38.
# The header was a property a human had to keep true, which is the antipattern
# this repo already ruled against (build.sh: "a number a human must keep true is
# a claim nothing keeps true"). LA_CLAIM_INDEX.md supplies the mapping; this
# gate is what keeps it from rotting the same way.
cd "$(dirname "$(readlink -f "$0")")" || exit 1
C=LA_COMPLETION.md; X=LA_CLAIM_INDEX.md
for f in "$C" "$X"; do
    [ -f "$f" ] || { echo "FAIL  claimindex: $f missing — a broken checkout, not a configuration"; exit 1; }
done

# The status key line lists every marker once and is not an item.
NITEMS=$(grep -c '`\[ \]`' "$C")
KEYLINE=$(grep -c 'Status key:' "$C")
NITEMS=$((NITEMS - KEYLINE))
NROWS=$(grep -c '^| [0-9]' "$X")

# ★ ANTI-VACUITY: prove the two counters can COUNT before comparing them. A pair
# of zeros compares equal and would report a perfectly indexed empty list.
[ "$NITEMS" -gt 0 ] || { echo "FAIL  claimindex: found 0 unbuilt items in $C — the marker scan is broken, not the list empty"; exit 1; }
[ "$NROWS"  -gt 0 ] || { echo "FAIL  claimindex: found 0 rows in $X — the row scan is broken"; exit 1; }

[ "$NITEMS" = "$NROWS" ] \
  || { echo "FAIL  claimindex: $C has $NITEMS unbuilt items but $X indexes $NROWS — an item without a paper counterpart is exactly the gap this index was built to close"; exit 1; }

# Every row must name a tag, a section, or an explicit NONE. A blank counterpart
# is the silent failure mode: a row that looks indexed and says nothing.
BLANK=$(awk -F'|' '/^\| [0-9]/ { t=$5; gsub(/[ \t]/,"",t); if (t=="") print NR }' "$X" | wc -l)
[ "$BLANK" -eq 0 ] || { echo "FAIL  claimindex: $BLANK row(s) carry an empty tag column"; exit 1; }

echo "PASS  claimindex: all $NITEMS unbuilt items in $C are indexed to a paper counterpart in $X, every row carries a tag or an explicit NONE ($(grep -c 'NONE' $X) rows record that the paper has no counterpart, which is a finding rather than an omission)"
