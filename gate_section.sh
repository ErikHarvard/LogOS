#!/bin/sh
# ── gate_section.sh N [N ...] — run ONLY the named sections of gate_registers.sh (FREEZE-TRACKF.md V8, PINPOINT) ──
#  When the suite reports a FAIL, re-run just that section in seconds instead of the whole suite in hours: the
#  section's own lines, VERBATIM, after the gate's real preamble (the host/want/red helpers WITH their F18/F19/V5
#  checks, the temp dir, the trap, REGS_KEEP). Nothing is re-typed, so it cannot drift from the gate it slices.
#  Every section is self-contained: none reads another section's output (checked 2026-09-18, 46 sections).
#  Its PASS line names the sections it ran and says it is NOT the gate's PASS line — a slice is not the suite.
#    e.g.  sh gate_section.sh 45            REGS_KEEP=.sec-out sh gate_section.sh 31 32
set -u
cd "$(dirname "$0")" || exit 1
[ $# -ge 1 ] || { echo "usage: gate_section.sh N [N ...]"; exit 2; }
for n in "$@"; do
    case "$n" in ''|*[!0-9]*) echo "REFUSE: section '$n' is not a number"; exit 2;; esac
    grep -qE "^# ═══ $n\." gate_registers.sh || { echo "REFUSE: gate_registers.sh has no section $n"; exit 2; }
done
S=$(mktemp ./.gate_section_XXXXXX) || exit 1
awk -v sel=" $* " '
    BEGIN { mode = "pre" }
    /^# ═══ [0-9]+\./ { s = $3; sub(/\.$/, "", s); mode = (index(sel, " " s " ") ? "in" : "out") }
    /^\[ "\$ok" -eq 1 \] && echo "PASS  registers:/ { mode = "end" }
    mode == "pre" || mode == "in" { print }
' gate_registers.sh > "$S"
printf '%s\n' "[ \"\$ok\" -eq 1 ] && echo \"PASS  registers/sections $*: ALONE — a slice of the suite, NOT the gate's PASS line\" || { echo \"FAIL  registers/sections $*\"; exit 1; }" >> "$S"
sh "$S"; rc=$?
rm -f "$S"
exit $rc
