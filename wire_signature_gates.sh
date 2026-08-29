#!/usr/bin/env bash
# wire_signature_gates.sh — wire Track E's four gates into build.sh.
#
# ★ THIS IS THE PATCH, NOT THE APPLICATION. It refuses to run while a build is
#   executing build.sh, because bash reads a script LAZILY BY BYTE OFFSET:
#   inserting lines shifts every offset after them and corrupts the run in
#   progress. Build 7 was at PASS 143 / FAIL 0 / SKIP 0 and carrying the first
#   selfext2b execution in the project's history when this was written.
#
# WHY IT IS NEEDED
#   grep -c gate_wotsp.sh build.sh          -> 0
#   grep -c gate_xmss.sh build.sh           -> 0
#   grep -c gate_xmssidx.sh build.sh        -> 0
#   grep -c gate_xmss_signer.sh build.sh    -> 0
#   All four of the signature layer's gates are in THE UNGATED SET (Freeze III,
#   FINDING 2). Nothing in build.sh would notice if any of them broke. A gate
#   nobody runs is not a gate, and the layer they cover is ROADMAP G1's open half.
#
# ★ THE COST DECISION, MADE EXPLICITLY RATHER THAN BY DEFAULT
#   Wiring all four WHOLE, from their own measured headers:
#       gate_xmssidx.sh        minutes (pure index logic, no hashing)
#       gate_wotsp.sh          ~36 min at default (n=32 arm already opt-in)
#       gate_xmss.sh           2 h 41 min  (C host 124 min + VM 37 min)
#       gate_xmss_signer.sh    93 min host + VM UNMEASURED
#   = ~5.5 h added to a ~3 h build. Both gate headers say in terms that wiring
#   them whole is "a decision, not a default". An 8-hour build gets run less
#   often, and a gate nobody runs is the finding this whole exercise started from.
#
#   So the two cheap gates go in WHOLE, and the two expensive ones go in on their
#   VM leg only — the trade gate_xmss.sh's header names but never implemented.
#   ★ EVERY OMISSION IS ANNOUNCED IN THE GATE'S OWN PASS LINE. Giving up host==VM
#   is giving up this project's core discipline; it may be traded away, but never
#   silently. A skip that is not announced reads as coverage.
#
#   Net: ~1.5-2 h added instead of 5.5 h, and host==VM is still established for
#   WOTS+ (the primitive everything else composes) and for the index register.
#
# WHAT IT CHANGES
#   gate_xmss.sh  (Track E's)  + an XMSS_VM_ONLY flag, mirroring the SIGNER_VM_ONLY
#                              that gate_xmss_signer.sh already carries
#   build.sh      (SHARED)     + one section after the crypto gate
#
# USAGE
#   bash wire_signature_gates.sh --check    # dry run: show what would change
#   bash wire_signature_gates.sh --apply
set -uo pipefail
cd "$(dirname "$0")" || exit 1
MODE="${1:---check}"

# ── GUARD 1: never edit a script that is being executed ─────────────────────
RUNNING=$(ps -eo args --no-headers | grep -c '[b]ash ./build.sh')
if [ "$RUNNING" -gt 0 ]; then
    echo "REFUSED: a build is executing build.sh right now ($RUNNING process)." >&2
    echo "         bash reads a script lazily by byte offset — editing it mid-run" >&2
    echo "         corrupts the running build. Wait for it to finish." >&2
    exit 1
fi

# ── GUARD 2: build.sh is SHARED, and Track A works in it ────────────────────
[ -f build.sh ] || { echo "REFUSED: no build.sh in $(pwd)" >&2; exit 1; }
grep -q 'bash gate_crypto.sh || exit 1' build.sh || {
    echo "REFUSED: cannot find the crypto-gate anchor in build.sh." >&2
    echo "         It has moved since this patch was written — re-derive the" >&2
    echo "         insertion point rather than guessing at a line number." >&2
    exit 1; }
grep -q 'gate_wotsp.sh' build.sh && {
    echo "REFUSED: build.sh already references gate_wotsp.sh — already wired?" >&2
    exit 1; }

BLOCK='
say "the signature layer — WOTS+ one-time, XMSS many-time, and the durable index register"
# ── ★ ROADMAP G1'"'"'S OPEN HALF, AND THE FOUR GATES THAT COVER IT ───────────────
#  G1 carried "No signature scheme yet — still the blocker for signed updates and
#  identity"; G2 named the choice ("PQ or hash-based signatures"). These four
#  gates are that half. Until 2026-08-28 NONE of them was referenced here — the
#  whole layer sat in the ungated set (Freeze III, FINDING 2), where nothing in
#  build.sh would have noticed if any of it broke.
#
#  ORDER IS THE DIAGNOSTIC, exactly as it is for sha256 -> crypto above: each gate
#  composes the one before it, so if several go red the ORDER says which is the
#  cause. The register first (it hashes nothing and costs seconds), then the
#  one-time primitive, then the Merkle layer over it, then the join.
#
#  ★ TWO OF THESE RUN THEIR VM LEG ONLY, AND THAT IS A TRADE, NOT AN OVERSIGHT.
#  Whole, the four cost ~5.5 h against a ~3 h build. gate_xmss.sh is 2 h 41 m and
#  gate_xmss_signer.sh is 93 min on the C host alone. An 8-hour build gets run
#  less often, and a gate nobody runs is the defect this section exists to close.
#  So host==VM byte-identity — this project'"'"'s core discipline — is established
#  here for WOTS+ and for the register, and GIVEN UP for XMSS and the join.
#  Each of those two SAYS SO IN ITS OWN PASS LINE. Never silently.
#  To restore full coverage out of band:
#      bash gate_xmss.sh              # + the 124-min C host leg
#      bash gate_xmss_signer.sh       # + the 93-min C host leg
#      WOTSP_FULL=1 bash gate_wotsp.sh   # + the n=32 w=16 production arm
#
#  ★ A MISSING GATE FILE IS A HARD FAILURE, not a SKIP. This follows the III-1
#  correction: `if [ -f gate ]; then ... else echo SKIP; fi` kept the build green
#  when the file was deleted. There is no legitimate build in which a gate is
#  optional; absence is a broken checkout.
for g in gate_xmssidx.sh gate_wotsp.sh gate_xmss.sh gate_xmss_signer.sh; do
    [ -f "$g" ] || { echo "FAIL  signature layer: $g is absent — a gate file missing means a broken checkout, not a configuration"; exit 1; }
done
bash gate_xmssidx.sh || exit 1
bash gate_wotsp.sh || exit 1
XMSS_VM_ONLY=1 bash gate_xmss.sh || exit 1
SIGNER_VM_ONLY=1 bash gate_xmss_signer.sh || exit 1
'

if [ "$MODE" = "--check" ]; then
    echo "DRY RUN — nothing written."
    echo
    echo "would insert after build.sh:$(grep -n 'bash gate_crypto.sh || exit 1' build.sh | cut -d: -f1):"
    printf '%s\n' "$BLOCK" | sed 's/^/  | /'
    echo
    echo "would add XMSS_VM_ONLY to gate_xmss.sh: $(grep -c 'XMSS_VM_ONLY' gate_xmss.sh) occurrence(s) today"
    exit 0
fi

[ "$MODE" = "--apply" ] || { echo "usage: $0 [--check|--apply]" >&2; exit 2; }

# ── 1. gate_xmss.sh gains the VM-only arm its own header already describes ──
python3 - <<'PY'
import re, sys
s = open('gate_xmss.sh', encoding='utf-8').read()
if 'XMSS_VM_ONLY' in s:
    print("  gate_xmss.sh: already has XMSS_VM_ONLY, left alone"); sys.exit(0)
old = '''HOSTOUT="$(timeout 10800 ./tiny_host xmss.la 2>&1 | head -1)"
[ "$HOSTOUT" = "$E_XMSS" ] || { echo "FAIL  xmss C host: [$HOSTOUT]"; ok=0; }'''
assert old in s, "gate_xmss.sh host leg not found — re-derive before editing"
new = '''# ★ XMSS_VM_ONLY=1 runs the VM leg alone (~37 min instead of 2 h 41 m) and GIVES
#   UP host==VM. This is the trade this gate's header names above; it is now
#   implemented rather than merely described, and the PASS line SAYS which ran.
if [ "${XMSS_VM_ONLY:-0}" = "1" ]; then
    HOSTNOTE="C host leg NOT RUN in this invocation (XMSS_VM_ONLY=1; that leg is 124 min). host==VM byte-identity is therefore NOT established here — only the native VM ran, against the derived expectation."
    HOSTOUT="$E_XMSS"   # not measured; see the note above
else
    HOSTOUT="$(timeout 10800 ./tiny_host xmss.la 2>&1 | head -1)"
    [ "$HOSTOUT" = "$E_XMSS" ] || { echo "FAIL  xmss C host: [$HOSTOUT]"; ok=0; }
    HOSTNOTE="Byte-identical on the C host AND the native VM."
fi'''
s = s.replace(old, new, 1)
s = s.replace('Byte-identical on the C host AND the native VM. Parameters n=2',
              '$HOSTNOTE Parameters n=2', 1)
open('gate_xmss.sh', 'w', encoding='utf-8').write(s)
print("  gate_xmss.sh: XMSS_VM_ONLY added")
PY

# ── 2. build.sh gains the section, after the crypto gate ────────────────────
python3 - "$BLOCK" <<'PY'
import sys
block = sys.argv[1]
s = open('build.sh', encoding='utf-8').read()
anchor = 'bash gate_crypto.sh || exit 1\n'
assert s.count(anchor) == 1, f"anchor appears {s.count(anchor)} times — refusing"
s = s.replace(anchor, anchor + block, 1)
open('build.sh', 'w', encoding='utf-8').write(s)
print("  build.sh: signature-layer section inserted after the crypto gate")
PY

# ── 3. verify, and prove the verification looked ───────────────────────────
echo "  --- verification ---"
bash -n build.sh && echo "  build.sh: syntax OK" || { echo "  ★ build.sh SYNTAX ERROR — revert immediately"; exit 1; }
bash -n gate_xmss.sh && echo "  gate_xmss.sh: syntax OK" || { echo "  ★ gate_xmss.sh SYNTAX ERROR"; exit 1; }
for g in gate_wotsp.sh gate_xmss.sh gate_xmssidx.sh gate_xmss_signer.sh; do
    n=$(grep -c "$g" build.sh)
    printf '  %-22s now referenced %s time(s) in build.sh\n' "$g" "$n"
    [ "$n" -gt 0 ] || { echo "  ★ $g STILL UNWIRED — the insert did not take"; exit 1; }
done
echo "  ★ NOT YET VERIFIED BY A BUILD. Wiring a gate is not running it; the next"
echo "    full build is what turns this from a reference into coverage."
