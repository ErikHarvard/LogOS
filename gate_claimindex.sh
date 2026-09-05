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

# ── WHAT THIS CHECKS ────────────────────────────────────────────────────────
# ★ THREE EARLIER VERSIONS WERE WRONG, each in a way this repo has a name for:
#   v1 compared COUNTS (38 vs 38). Swapping an item for a different one keeps
#      the total and stays green.
#   v2 keyed rows to each item's SOURCE LINE. That caught the swap — then one
#      edit ABOVE the list shifted every line and produced 31 FALSE REDS. A line
#      number is a position, not an identity.
#   v3 fell back to count-containment plus a "does this row point at real text"
#      arm whose extraction regex still expected v2's removed column. It matched
#      ZERO rows, so the loop never ran and the arm passed VACUOUSLY — it
#      reported a clean index while checking nothing. Found by planting a row
#      pointing at NOSUCHTHING_XYZ and watching it stay green.
# v4 compares IDENTITIES, and the identities are DERIVED rather than hand-kept:
# each index row carries a key generated from the item's own title in $C. A
# retitled item changes its key and goes red, which is correct — the mapping
# should be revisited when the item is rewritten.
CKEYS=/tmp/.ci_ckeys; XKEYS=/tmp/.ci_xkeys
norm_keys () {  # title -> the same 6-word key the index was generated with
    sed 's/`\[[ ~x✓!]\]`//g' | tr 'A-Z' 'a-z' \
      | sed 's/[*`★—–]/ /g; s/[^a-z0-9 /_+⊂⊕⊗▷↻κν∂δγρ𝔄]/ /g' \
      | tr -s ' ' | sed 's/^ //' | cut -d' ' -f1-6
}
grep '`\[ \]`' "$C" | grep -v 'Status key:' | norm_keys | sed 's/ *$//' | sort -u > "$CKEYS"
grep -oE '^\| [0-9]+ \| `[^`]+`' "$X" | sed 's/.*`\(.*\)`/\1/' | sort -u > "$XKEYS"
NITEMS=$(wc -l < "$CKEYS"); NROWS=$(wc -l < "$XKEYS")

# ★ ANTI-VACUITY, ON BOTH SCANS — v3's lesson. An extraction that yields nothing
# makes every containment test below trivially true, so each scan must be shown
# to have produced something before its result is believed.
[ "$NITEMS" -gt 0 ] || { echo "FAIL  claimindex: the item scan over $C yielded 0 keys — the scan is broken, not the list empty"; exit 1; }
[ "$NROWS"  -gt 0 ] || { echo "FAIL  claimindex: the row scan over $X yielded 0 keys — the scan is broken, so every check below would pass vacuously"; exit 1; }

MISSING=$(comm -23 "$CKEYS" "$XKEYS")
[ -z "$MISSING" ] || { echo "FAIL  claimindex: unbuilt item(s) not indexed in $X:"; echo "$MISSING" | sed 's/^/        /'; exit 1; }
rm -f "$CKEYS" "$XKEYS"

# Every row must name a tag, a section, or an explicit NONE. A blank counterpart
# is the silent failure mode: a row that looks indexed and says nothing.
BLANK=$(awk -F'|' '/^\| [0-9]/ { t=$5; gsub(/[ \t]/,"",t); if (t=="") print NR }' "$X" | wc -l)
[ "$BLANK" -eq 0 ] || { echo "FAIL  claimindex: $BLANK row(s) carry an empty tag column"; exit 1; }

echo "PASS  claimindex: all $NITEMS unbuilt items in $C are matched BY DERIVED KEY to a row among the $NROWS in $X (the key comes from the item's own title, so a retitled item goes red rather than drifting silently; which Ledger row a given item maps to remains a human claim), every row carries a tag or an explicit NONE ($(grep -c 'NONE' $X) rows record that the paper has no counterpart, which is a finding rather than an omission)"
