#!/usr/bin/env bash
# XMSS — the MANY-TIME hash-based signature. This is the gate that actually
# unblocks ROADMAP G1's "signed updates and identity": `wotsp.la` gave the
# system a public-key primitive, but a one-time key cannot sign a stream of
# updates, so WOTS+ alone left G1 half-open. A Merkle tree over 2^h WOTS+ keys
# closes it — one small public key, 2^h signatures.
#
# ── THE ONE CHECK THAT IS THE WHOLE POINT ───────────────────────────────────
# "leaf2 verifies vs SAME root". Any single-signature test passes on a tree
# that ignores its leaf index entirely; only signing under TWO DIFFERENT leaves
# and verifying both against ONE root witnesses many-time-ness. Everything else
# here supports that claim or attacks it.
#
# ── THE NEGATIVES, AND WHAT EACH ONE FORCES THE VERIFIER TO READ ────────────
#     wrong leaf idx rejected      -- the index is authenticated, not decorative
#     corrupt auth path rejected   -- the path is authenticated
#     wrong msg rejected           -- the message is authenticated
#     wrong root rejected          -- the root is authenticated
# ★ FOUR of the nine checks are negative AND DISCRIMINATING (corrected 2026-08-27,
# Freeze-Day Audit IV). A fifth — "wrong root rejected" — asserts r0 != FLIPS(root)
# while a neighbour already asserts r0 == root, so it reduces to root != FLIPS(root),
# true by construction of FLIPS. A gate whose only case is "a signature
# verifies" cannot fail in the way this project has already been bitten by
# (chacha20's BLOCK ignoring its own key argument and passing anyway).
#
# ── EXPECTED-STRING PROVENANCE (read this before editing E_XMSS) ────────────
# ★ E_XMSS below was DERIVED from xmss.la's own concat structure and the model's
# vectors, NOT pasted from a run's stdout. That distinction is the difference
# between a gate and a rubber stamp: an expected value copied from observed
# output cannot detect a wrong observed output, because it IS the observed
# output. If this string ever needs updating, derive it again — do not capture
# it. The root (7d20) and leaf0 (cf5d) inside xmss.la come from xmss_model.py,
# an independent Python implementation written before the LA one.
#
# ── PROVENANCE OF THE VECTORS THEMSELVES — THE STANDING LIMIT ───────────────
# Cross-implementation agreement with a model by the same author is WEAKER than
# a published known answer, and this gate does not blur the two. RFC 8391
# publishes XMSS test vectors, and reaching them is now a concrete, bounded
# task rather than a wish — it requires the RFC's own tweakable hash (per-step
# bitmasks + L-trees) in place of the SPHINCS+ "simple" (i,j) construction used
# here. Until that is done this remains a construction witness, not a KAT.
#
# ── WHY n=2 w=4 h=2, STATED NOT HIDDEN ──────────────────────────────────────
# One leaf is a full WOTS+ keygen. At n=32 w=16 that is 1072 hashes, measured at
# ~1.75 s/hash on the native VM for this input size: ~31 min PER LEAF, ~2 h for
# a four-leaf tree before signing anything. So the witnessed parameters are a
# TOY security level (16 bits) chosen to exercise every code path — two tree
# levels, both sibling directions, an even leaf and an odd one — not to be safe.
# ★ Before the expensive run, the Merkle layer was verified SEPARATELY with the
# leaf function stubbed out: all four leaves walked to the same root, and the
# root and both internal nodes matched the Python model byte-for-byte. That
# isolates a tree/auth-path off-by-one from the WOTS integration, and it cost
# seconds instead of the ~100 min the full host leg costs.
# ── MEASURED COST — this gate is EXPENSIVE, know it before wiring it ────────
#     C host      7426 s  (124 min)
#     native VM   1597 s codegen (27 min) + 601 s run (10 min)
#     TOTAL       ~2 h 41 min
# ★ The host leg is ~12x the VM leg for the identical program. On a ~3 h build
# this gate roughly doubles it, so — as with gate_wotsp.sh — wiring it whole is
# a decision, not a default. The cheapest honest option is the VM leg alone
# (~37 min), at the cost of giving up host==VM, which is the project's core
# discipline; that trade is stated so it can be made deliberately.
set -uo pipefail
cd "$(dirname "$0")"
ok=1

E_XMSS="xmss n=2 w=4 h=2: root OK | leaf0 OK | leaf0 verifies OK | leaf2 verifies vs SAME root OK | sigs differ OK | wrong leaf idx rejected OK | corrupt auth path rejected OK | wrong msg rejected OK | wrong root rejected OK"

HOSTOUT="$(timeout 10800 ./tiny_host xmss.la 2>&1 | head -1)"
[ "$HOSTOUT" = "$E_XMSS" ] || { echo "FAIL  xmss C host: [$HOSTOUT]"; ok=0; }

rm -f logos_secd logos_program.bin logos_source.la
./tiny_host secd.la >/dev/null 2>&1
cp xmss.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
VMOUT="$(timeout 10800 ./logos_secd 2>&1 | head -1)"
rm -f logos_secd logos_program.bin logos_source.la
[ "$VMOUT" = "$E_XMSS" ] || { echo "FAIL  xmss native VM: [$VMOUT]"; ok=0; }

# Separate from the two value checks on purpose: both engines can be wrong the
# same way, and each can be wrong its own way. Only this line catches the second.
[ "$HOSTOUT" = "$VMOUT" ] || { echo "FAIL  xmss: host != VM"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  xmss: a MANY-TIME hash-based signature in Lingua Adamica — a Merkle tree over 2^h WOTS+ one-time keys, so one small public key (the root) signs 2^h messages. This is what ROADMAP G1's 'signed updates and identity' actually needs; wotsp.la alone could sign once. Two signatures under DIFFERENT leaves verify against the SAME root, and FOUR DISCRIMINATING negative controls reject: a wrong leaf index, a one-bit-corrupted authentication path, a wrong message, and the two signatures are not equal. (A fifth control, a flipped bit in the ROOT, is NOT discriminating — Audit IV, 2026-08-27: it reduces to root != FLIPS(root), true by construction, and is retained pending a baseline run.) Byte-identical on the C host AND the native VM. Parameters n=2 w=4 h=2 are a TOY security level chosen for code-path coverage, NOT a safe parameter set — n=32 w=16 costs ~31 min per leaf on this substrate. Vectors are cross-implementation agreement with an independent Python model, NOT a published RFC 8391 KAT."
[ "$ok" -eq 1 ]
