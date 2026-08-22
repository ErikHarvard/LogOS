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
# ── WHICH ENGINES, AND WHY NOT ALL OF THEM ──────────────────────────────────
# chacha20/poly1305/aead run on the C host AND the native SECD VM (~2 min).
# hmac/hkdf run on the C host ONLY. That is a measured decision, not an
# oversight: hkdf's codegen leg alone costs 398 s, and the VM leg would add no
# information — hmac and hkdf are compositions of SHA-256, whose host==VM
# agreement gate_sha256.sh already establishes, over concat/xor, whose
# five-engine agreement the BITWISE gate already establishes. Stated rather
# than silently dropped.
set -uo pipefail
cd "$(dirname "$0")"
ok=1

check_host () {   # name expected
    local out; out="$(timeout 900 ./tiny_host "$1.la" 2>&1 | head -1)"
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

check_host hmac     "$E_HMAC"
check_host hkdf     "$E_HKDF"
check_host chacha20 "$E_CC20" && check_vm chacha20 "$E_CC20"
check_host poly1305 "$E_POLY" && check_vm poly1305 "$E_POLY"
check_host aead     "$E_AEAD" && check_vm aead     "$E_AEAD"

[ "$ok" -eq 1 ] && echo "PASS  crypto substrate: HMAC-SHA256 (RFC 4231 TC1/TC2), HKDF (RFC 5869 TC1/TC3), ChaCha20 (RFC 8439 2.3.2 + A.1#1 all-zero-key), Poly1305 (2.5.2 + A.3 #5/#6/#7 — the partial-reduction, s-overflow and limb-carry breakers), and ChaCha20-Poly1305 AEAD (2.8.2 ciphertext + tag + decrypt round-trip + a one-bit forged tag that releases NO plaintext). ChaCha20/Poly1305/AEAD byte-identical on the C host AND the native SECD VM. The OS can now encrypt, authenticate and derive keys in its own language."
[ "$ok" -eq 1 ]
