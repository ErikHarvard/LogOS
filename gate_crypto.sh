#!/usr/bin/env bash
# The cryptographic substrate above SHA-256, written in Lingua Adamica.
# gate_sha256.sh establishes the hash. This gate establishes everything the
# sovereignty layer is actually built from: a KDF, a MAC, a stream cipher, a
# one-time authenticator, and the AEAD that composes the last two.
#
# ── KNOWN-ANSWER ONLY. NO SELF-CONSISTENCY ANYWHERE. ────────────────────────
# Every vector below is from a published RFC, and several were chosen because
# they DISCRIMINATE — they fail loudly against a plausible wrong implementation
# that a friendlier vector would wave through:
#
#   chacha20  RFC 8439 A.1 #1 (all-zero key/counter/nonce). ★ On 2026-08-22 the
#             module's BLOCK took k0..k7/ctr/n0..n2 as arguments but fed forward
#             HARDCODED constants holding the 2.3.2 vector's own key. It was
#             correct for exactly one input and silently wrong for every other,
#             and the single-vector gate could not tell, because for THAT vector
#             the constants equalled the arguments. A block function that
#             ignored its key entirely would have passed. This vector cannot be
#             satisfied by hardcoding, because its key is not the other's.
#
#   poly1305  RFC 8439 A.3 #5/#6/#7 exist in the RFC specifically to break
#             implementations that mishandle the final partial reduction, the
#             overflow of + s past 2^128, or a carry out of a full limb. Those
#             are the failure modes that yield a PLAUSIBLE WRONG TAG rather than
#             a crash, which is the only kind that ships.
#
#   aead      RFC 8439 2.8.2, and then a FORGED tag differing in ONE BIT that
#             must release no plaintext at all. ★ The first version of that
#             control passed the GENUINE tag, so decrypt correctly released the
#             plaintext and the check reported a leak — it was testing the
#             accept path. A negative control that cannot fail is not a control.
#
#   hmacdrbg  NIST SP 800-90A 10.1.2, SHA-256, no reseed/PR. TWO generate calls,
#             THE FIRST DISCARDED. That discard is the whole point: it forces the
#             K/V state ratchet to be exercised before the comparison, so an
#             implementation that never updated its state fails here and would
#             pass a single-generate test. The failure this catches is the
#             update() branch run once where it should run twice — which still
#             emits statistically perfect bytes while silently destroying
#             BACKTRACKING RESISTANCE. No randomness test detects that. Only a
#             known-answer vector does, which is why it is gated rather than
#             trusted.
#             ★ Wired 2026-09-09. It had been in the tree since af730ee, whose
#             own subject line claims "DRBG", referenced by NO script on ANY
#             branch — authored, self-testing, and never once run.
#
# ── WHICH ENGINES, AND WHY NOT ALL OF THEM ──────────────────────────────────
# chacha20/poly1305/aead run on the C host AND the native SECD VM (~2 min).
# hmac/hkdf/hmacdrbg run on the C host ONLY. That is a measured decision, not an
# oversight: hkdf's codegen leg alone costs 398 s (2026-08-22) [⚠ UNLOADED -- that
# figure carries no load and therefore cannot be used to set a budget or to justify a
# RED; a datum with a stated limitation is worth more than either a fabricated
# precision or a hole, so it is annotated rather than re-measured or deleted]; it was
# RE-MEASURED 2026-09-09 at 1001 s (see THE HOST TIMEOUT below), and the VM leg would add no
# information — hmac and hkdf are compositions of SHA-256, whose host==VM
# agreement gate_sha256.sh already establishes, over concat/xor, whose
# five-engine agreement the BITWISE gate already establishes. Stated rather
# than silently dropped. hmacdrbg is host-only for the SAME reason — it is a
# composition of HMAC-SHA256 — and gating it on the VM ALONE was considered and
# REJECTED: that would make the engine under test its own sole witness, and the
# C host is the reference interpreter.
#
# ★ hmacdrbg CARRIES ITS OWN BUDGET (3600 s) AND THAT IS DELIBERATE. It is ~25
# HMAC-SHA256 evaluations (instantiate, then 2x(4 generate blocks + update)), each a
# full SHA-256 written in Lingua Adamica. The inherited 900 s default KILLS IT AT THE
# CAP -- which reads as a broken module and is not one. Do not "tidy" it back.
#
# THE BUDGET IS NOT THE MEASUREMENT, and the two are stated separately on purpose:
#   MEASURED  1964 s wall, on a box under load 6.89-9.13 (24 cores, 3 jobs sharing).
#   BUDGET    3600 s -- deliberate headroom, NOT the measurement rounded up.
# A budget set just above its own datum turns every slow day into a red build. The
# measurement bounds the cost from ONE side only; the budget must clear it by enough
# that LOAD never decides the verdict.
# ★ AND THE VARIANCE IS MEASURED, NOT FEARED, ACROSS THREE RUNS. In-gate on the
# 2026-09-09 green run it took ~1610 s (gate total 2674 s, rc 0) at load ~9.6.
# The SAME module on the SAME box ran in
# ~1200 s earlier the same day at load ~4.8 (observed to ~19 min elapsed shortly before
# it completed -- an OBSERVATION, not an instrumented timing, and recorded as such),
# against the 1964 s above at load ~8. Load alone moves this ~1.6x. That spread is the
# whole argument for the headroom: a 2000 s budget would have passed the fast run and
# failed the slow one, on identical code.
#
# ── ★ WHY NOT THE NATIVE VM, WHICH IS CHEAPER. READ BEFORE "OPTIMISING" THIS. ──
# Measured 2026-09-09, three-phase: secd.la emit 35 s + codegen 806 s + VM RUN 41 s
# = 882 s VM-total, and the VM PRINTS THE IDENTICAL CORRECT ANSWER.
# ⚠ Load during that leg: ~5-9, NOT separately instrumented (observed 4.8 just before it
# started, 6.89-9.13 sampled across the overlap), 2-3 concurrent jobs throughout. Stated
# as a bound because a fabricated precision would be worse than the gap -- and because
# THIS HEADER BROKE ITS OWN RULE when first written: it published these four durations
# with no load at all, three lines below the paragraph demanding loads. No position
# outside the class, including the position of having just written the rule. The native run is
# ~29x faster than the host; codegen eats the whole gain, so the cost of the VM path
# here is COMPILE, not COMPUTE. Two reasons it is still not the gate's leg:
#   1. SOLE WITNESS. The C host is the reference interpreter. Gating on the VM alone
#      would stop the reference engine witnessing the module -- and the header's
#      host-only rule for hmac/hkdf is an argument about what a second engine ADDS,
#      which does not become false when the VM turns out fast.
#   2. ★ 882 s DOES NOT FIT THE 900 s DEFAULT AT ALL, WHICH IS ARITHMETIC, NOT JUDGEMENT.
#      It looks like 18 s of headroom. Apply the load swing this module's own three
#      runs establish (~1200 / ~1610 / 1964 s, a 64% spread) and 882 s becomes ~1450 s
#      under contention -- past the cap outright. So the VM leg would not be a thin
#      budget, it would be a gate that goes RED FOR LOAD, silently, with the blame
#      landing on hmacdrbg. Reason 2 is the one a cost-minded reader will not derive
#      alone, which is why the arithmetic is written out rather than asserted.
# ⇒ host==VM agreement for hmacdrbg is therefore MEASURED, not inferred from
#   gate_sha256. "Omitted after checking, on cost" is strictly stronger than "omitted
#   on principle": the first is a witness, the second only an argument.
set -uo pipefail
cd "$(dirname "$0")"
ok=1

# ── THE HOST TIMEOUT — raised 900 -> 1800 on 2026-09-09, and why ────────────
#  It was 900 s and hkdf now needs 1001 s, so this gate failed EVERY build with
#  `FAIL hkdf C host: []`. The empty [] is the timeout's own signature: the
#  capture below is empty when `timeout` kills the process, so a budget overrun
#  is indistinguishable from a wrong answer at the point of failure. hkdf was
#  never wrong — measured untimed, it prints the expected E_HKDF and exits 0.
#
#  ★ MEASURED, AND DECOMPOSED, so the next person re-derives instead of guessing
#  (`/usr/bin/time -v`, isolated dirs, load/core 0.41 on 24 cores — untainted):
#      documented 2026-08-22 (af730ee)        398.00 s
#      Aug-22 host + Aug-22 hkdf.la           738.66 s   <- NEITHER had changed
#      current host + Aug-22 hkdf.la          970.63 s   <- interpreter only
#      current host + current hkdf.la        1001.02 s   <- source only
#  Of the 603 s gap: 341 s (56%) the 398 s figure never reproduced on this
#  hardware AT ALL; 232 s (38%) commit adc80a6 "str_at: O(1) indexed access",
#  which made hkdf 31% slower on the C host and is a real interpreter
#  regression affecting every LA compile, not just this gate; 30 s (5%) hkdf.la's
#  own growth. Runs 2 and 3 differ in tiny_host ONLY (md5-verified).
#
#  ⚠ 2400 IS A HANG-CATCHER, NOT A PERFORMANCE BUDGET, and it is 2400 rather
#  than 1800 because Track A's own note above corrected my arithmetic: this
#  module's three runs establish a ~64% LOAD SWING (~1200 / ~1610 / 1964 s).
#  Apply that to hkdf's 1001 s and a contended run reaches ~1642 s — so 1800
#  would have been ~10% of headroom, not the 80% "1.8x the measured cost"
#  suggests. A budget set from a quiet-machine number is how a gate acquires a
#  silent RED-for-load. 2400 clears the contended estimate by ~1.46x. It is not
#  an assertion that 2400 s is acceptable. Two things this does NOT fix and must not be read as fixing:
#  the adc80a6 regression is unaddressed, and whether a ~17-minute leg belongs
#  in build.sh's serial abort chain at all is a separate open question. If this
#  needs raising again, RE-MEASURE and update the table — a budget raised
#  without a measurement is how it drifted 2.5x from its documented cost in the
#  first place.
#
#  The VM timeout below is deliberately left at 900: its legs (chacha20,
#  poly1305, aead) completed inside 900 s in the 2026-09-09 run, so raising it
#  would be guessing at a budget nobody has measured — the exact defect above.
#  ★ THE FUNCTION SHAPE BELOW IS TRACK A's, ADOPTED RATHER THAN RE-DERIVED
#  (kernel-k1, a5b0343). A hit the same wall independently and fixed the half I
#  had not: capture the exit code and SAY which side failed, so a budget kill is
#  never again mistaken for a wrong answer. Mine fixed the number, theirs fixed
#  the diagnosis; the two branches converge here instead of conflicting at merge.
check_host () {   # name expected [timeout_s, default 900]
    local f rc=0 out
    f="$(mktemp)"
    timeout "${3:-900}" ./tiny_host "$1.la" > "$f" 2>&1 || rc=$?
    out="$(head -1 "$f")"; rm -f "$f"
    [ "$rc" = 0 ] || { echo "FAIL  $1 C host: exited $rc (want 0. 124/137/143 = the ${3:-900}s budget killed it -- timeout's own code, a SIGKILL escalation, or the shell reporting SIGTERM; ANY OTHER VALUE IS THE PROGRAM, not the budget); first line: [$out]"; ok=0; return 1; }
    [ "$out" = "$2" ] || { echo "FAIL  $1 C host: [$out]"; ok=0; return 1; }
    return 0
}
check_vm () {     # name expected
    local out
    rm -f logos_secd logos_program.bin logos_source.la
    ./tiny_host secd.la >/dev/null 2>&1
    cp "$1.la" logos_source.la
    ./tiny_host codegen.la >/dev/null 2>&1
    out="$(timeout 900 ./logos_secd 2>&1 | head -1)"
    rm -f logos_secd logos_program.bin logos_source.la
    [ "$out" = "$2" ] || { echo "FAIL  $1 native VM: [$out]"; ok=0; return 1; }
    return 0
}

E_HMAC="hmac TC1 OK | TC2 OK"
E_HKDF="hkdf TC1 OK | TC3 (no salt, no info) OK"
E_CC20="chacha20 2.3.2 OK | A.1#1 zero-key OK"
E_POLY="poly1305 2.5.2 OK | A.3#5 OK | A.3#6 OK | A.3#7 OK"
E_AEAD="aead 2.8.2 ct OK | tag OK | roundtrip OK | forged-tag rejected"
E_DRBG="hmacdrbg SP800-90A OK"

check_host hmac     "$E_HMAC"
check_host hkdf     "$E_HKDF" 2400   # measured 1001 s; see THE HOST TIMEOUT above
check_host chacha20 "$E_CC20" && check_vm chacha20 "$E_CC20"
check_host poly1305 "$E_POLY" && check_vm poly1305 "$E_POLY"
check_host aead     "$E_AEAD" && check_vm aead     "$E_AEAD"
check_host hmacdrbg "$E_DRBG" 3600

[ "$ok" -eq 1 ] && echo "PASS  crypto substrate: HMAC-SHA256 (RFC 4231 TC1/TC2), HKDF (RFC 5869 TC1/TC3), ChaCha20 (RFC 8439 2.3.2 + A.1#1 all-zero-key), Poly1305 (2.5.2 + A.3 #5/#6/#7 — the partial-reduction, s-overflow and limb-carry breakers), and ChaCha20-Poly1305 AEAD (2.8.2 ciphertext + tag + decrypt round-trip + a one-bit forged tag that releases NO plaintext). HMAC_DRBG (NIST SP 800-90A 10.1.2, two generate calls with the first discarded so the K/V state ratchet is exercised — the check that backtracking resistance is real). ChaCha20/Poly1305/AEAD byte-identical on the C host AND the native SECD VM. The OS can now encrypt, authenticate and derive keys in its own language."
[ "$ok" -eq 1 ]
