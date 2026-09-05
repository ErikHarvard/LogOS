#!/bin/sh
# ── STAGE 4: HELD-OUT ACCEPTANCE ───────────────────────────────────────────
#  selfmod.la's demo writes the neologism and its acceptance test in ONE
#  expression. Nothing is held out, so SYNTH searching until that test passes
#  shows the search TERMINATED, not that a capability was gained.
#
#  ★ THE FIXTURE IS THE CHACHA20 SHAPE IN MINIATURE:
#      honest   TRIPLEDEC = la x. TRIPLEN(DEC(x))   3(x-1) for every x
#      overfit  TRIPLEDEC = la x. 12                correct at x=5 only
#  BOTH pass the organ's own test, and the organ reports own-test-verified=T
#  for both. The overfit one clears stage 1 (it differs, is its own
#  derivation, verifies, parents survive), stage 2/2b (a begotten child
#  demonstrates it) AND stage 3 (it is α-distinct from everything the organ
#  had). Only a probe the synthesiser never saw can refuse it.
#
#  ★★ AND THE HELD-OUT-NESS IS GATED, NOT PROMISED. The probes and their
#  expected values live ONLY here. The gate proves they appear in neither the
#  synthesiser nor the emitted module -- a held-out test whose answer sits
#  inside the thing under test is not held out, which is the very disease.
set -u
cd "$(dirname "$0")" || exit 1
ok=1

# TRIPLEDEC(x) = 3(x-1). The organ has only ever seen x=5 -> 12.
HELD_IN="10 100 34"
HELD_OUT="27 297 99"

emit() {  # $1 = mode
  printf '%s' "$1" > .sx4mode
  rm -f sx4_organ.la
  OUT="$(timeout 900 ./tiny_host selfext4.la 2>&1 || true)"
  [ -f sx4_organ.la ] || { echo "FAIL  selfext4($1): no module emitted — got: $OUT"; ok=0; return 1; }
  case "$OUT" in
    *"own-test-verified=T"*) : ;;
    *) echo "FAIL  selfext4($1): the organ's OWN test did not verify — the fixture is broken, since the overfit extension must look FINE to the organ or this stage proves nothing. got: $OUT"; ok=0 ;;
  esac
}

audit() {  # runs the HELD-OUT probes against whatever module is emitted
  cat > sx4_audit.la <<'AUD'
import("sx4_organ.la")
glyph SP = la a. la b. concat(a)(concat(" ")(b))
glyph MAIN = print(SP(int_to_str(TRIPLEDEC(10)))(SP(int_to_str(TRIPLEDEC(100)))(int_to_str(TRIPLEDEC(34)))))
AUD
  timeout 300 ./tiny_host sx4_audit.la 2>&1
}

# ── ARM A: the honest extension must pass the held-out probes ─────────────
emit honest && {
  A="$(audit)"
  [ "$A" = "$HELD_OUT" ] || { echo "FAIL  selfext4(A): the HONEST extension failed the held-out probes — expected '$HELD_OUT' for inputs '$HELD_IN', got '$A'"; ok=0; }
}

# ── ARM B: the overfit extension must FAIL them ───────────────────────────
#  This is the stage. If it passes here, the held-out probes are not probing.
emit overfit && {
  B="$(audit)"
  if [ "$B" = "$HELD_OUT" ]; then
    echo "FAIL  selfext4(B): the OVERFIT extension (la x. 12) PASSED the held-out probes — they are not discriminating, so 'held out' is decorative"
    ok=0
  fi
  case "$B" in
    *12*) : ;;
    *) echo "FAIL  selfext4(B): the overfit extension did not even return its memorised answer — the fixture is not exercising what it claims; got '$B'"; ok=0 ;;
  esac
}

# ── ARM E: THE ORGAN'S CLAIM MUST HOLD OF THE DEPLOYED ARTIFACT.
#  selfext4.la carries TD_IMPL (what META_DEBUG tests) and TD_SRC (what gets
#  GENERATEd into the module). If those diverge, "own-test-verified=T" is a
#  claim about something other than the thing shipped -- the exact split
#  gate_srcdrift.py was built for, one level down. Found by a mutant that
#  changed only TD_IMPL and SURVIVED: the emitted module was untouched.
#  So the own-test probe is re-run against the EMITTED module, in whichever
#  mode is current, and must agree with what the organ claimed.
cat > sx4_own.la <<'OWN'
import("sx4_organ.la")
glyph MAIN = print(int_to_str(TRIPLEDEC(5)))
OWN
E="$(timeout 300 ./tiny_host sx4_own.la 2>&1)"
[ "$E" = "12" ] || { echo "FAIL  selfext4(E): the organ reported own-test-verified=T but the DEPLOYED module answers its own probe with '$E', not 12 — the organ verified one artifact and emitted another"; ok=0; }

# ── ARM C: NON-REDUNDANCY. The overfit extension must CLEAR the ratchet.
#  Otherwise stage 3 already caught it and stage 4 is ceremony.
grep -v '^glyph TRIPLEDEC' sx4_organ.la > .sx4_parent.la
if python3 ratchet.py .sx4_parent.la sx4_organ.la >/dev/null 2>&1; then :; else
  echo "FAIL  selfext4(C): the OVERFIT extension was rejected by the RATCHET, so stage 3 already covers this case and arm B proves nothing new. The fixture must be α-distinct to isolate what held-out acceptance adds."
  ok=0
fi

# ── ARM D: THE HELD-OUT-NESS ITSELF ──────────────────────────────────────
for V in $HELD_OUT; do
  if grep -qw "$V" selfext4.la; then
    echo "FAIL  selfext4(D): held-out expected value $V appears in the SYNTHESISER (selfext4.la) — it is not held out"; ok=0
  fi
  if grep -qw "$V" sx4_organ.la; then
    echo "FAIL  selfext4(D): held-out expected value $V appears in the EMITTED MODULE — the answer is sitting inside the thing under test"; ok=0
  fi
done
for V in $HELD_IN; do
  grep -qw "$V" selfext4.la && { echo "FAIL  selfext4(D): held-out INPUT $V appears in the synthesiser — it could have been fitted to"; ok=0; }
done

rm -f sx4_audit.la sx4_own.la sx4_organ.la .sx4_parent.la .sx4mode

if [ "$ok" -eq 1 ]; then
  echo "PASS  selfext4: held-out acceptance discriminates — the HONEST extension answers the held-out probes (10/100/34 -> 27/297/99) and the OVERFIT one (la x. 12) does not, though BOTH report own-test-verified=T and the overfit one CLEARS the ratchet (arm C proves stage 3 does not already cover it, so this stage is not ceremony). Neither the held-out inputs nor their expected values appear in the synthesiser or the emitted module (arm D), so 'the synthesiser never saw the audit test' is checked rather than promised; and arm E re-runs the organ's OWN probe against the DEPLOYED module, so 'own-test-verified' cannot be a claim about a different artifact than the one shipped"
  exit 0
fi
exit 1
