#!/usr/bin/env bash
# SHA-256 in Lingua Adamica — the first cryptographic primitive the language can
# express. Before the bitwise builtins (2026-08-21) this module could not exist.
#
# ── KNOWN-ANSWER, NOT SELF-CONSISTENCY ──────────────────────────────────────
# A digest is a known answer or it is nothing. Both NIST vectors are checked:
#   sha256("abc") = ba7816bf...15ad     sha256("")    = e3b0c442...b855
# Any masking slip, rotate off by one, or wrong constant changes the digest
# completely, so this cannot pass by accident.
#
# ★ TWO VECTORS, NOT ONE, AND THAT IS LOAD-BEARING. During development the
# padding produced 63-byte blocks instead of 64 — and sha256("") PASSED ANYWAY,
# because the dropped byte was a zero of the length field. One vector would have
# shipped a broken hash that looked verified.
#
# ── WHICH ENGINES, AND WHY NOT ALL FIVE ─────────────────────────────────────
# C host (~16 s) and the native SECD VM (~0.5 s). eval.la and the bytecode VMs
# are NOT run here: interpreting an interpreter through 64 rounds of list walks
# exceeds four minutes, and the marginal value is low — the BITWISE gate already
# establishes that all five engines agree on band/bor/bxor/bshl/bshr/bnot, which
# is what this module is composed of. This gate establishes that the COMPOSITION
# is correct; that one establishes the engines agree on the parts. Stated rather
# than silently dropped.
set -uo pipefail
cd "$(dirname "$0")"

EXPECT="sha256(abc) OK | sha256('') OK"
ok=1

HOSTOUT="$(timeout 300 ./tiny_host sha256.la 2>&1 | head -1)"
[ "$HOSTOUT" = "$EXPECT" ] || { echo "FAIL  sha256 C host: [$HOSTOUT]"; ok=0; }

rm -f logos_secd logos_program.bin logos_source.la
./tiny_host secd.la >/dev/null 2>&1
cp sha256.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
VMOUT="$(timeout 300 ./logos_secd 2>&1 | head -1)"
rm -f logos_secd logos_program.bin logos_source.la
# ★ RE-POINTED (III-5): HOSTOUT=EXPECT and VMOUT=EXPECT and HOSTOUT=VMOUT is a
#   triangle. The VM is compared to the HOST below; this line is what it implied.
: # (VM-vs-EXPECT folded into the host-vs-EXPECT and VM-vs-host pair)

[ "$HOSTOUT" = "$VMOUT" ] || { echo "FAIL  sha256: host != VM"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  sha256: both NIST vectors correct on the C host AND the native VM, byte-identical — SHA-256 written in Lingua Adamica over the bitwise builtins (band/bxor/bshr/bshl/bnot), constants derived from frac(cbrt(p))/frac(sqrt(p)) rather than transcribed. Cryptography is now writable IN the language."
[ "$ok" -eq 1 ]
