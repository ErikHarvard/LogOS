#!/usr/bin/env python3
"""
wotsp_model.py -- an INDEPENDENT model of the WOTS+ one-time signature scheme,
written before a line of wotsp.la, to generate the vectors that module must match.

WHY A MODEL FIRST
This project learned it the expensive way: poly1305's transcription errors were
caught in seconds against a Python model instead of minutes-long interpreter
runs.  A SHA-256 call costs 6.5 s on the C host and 0.31 s on the native VM
(measured 2026-08-23), so a full WOTS+ keygen is ~1000 hashes = 1.8 h on the
host.  Debugging that interactively is not possible.  The model is the only
affordable place to be wrong.

WHAT THIS IS -- AND THE ONE THING IT IS NOT
WOTS+ as specified by RFC 8391 section 3.1 (base_w, the checksum, the chaining
function, the shift) with the SPHINCS+ "simple" tweakable hash: chain step j of
chain i is domain-separated by (i, j) rather than by RFC 8391's per-step
bitmasks.  That substitution is deliberate and is stated in wotsp.la too.

It is NOT FIPS 205.  There are no published third-party test vectors for this
exact construction, and this file does not pretend otherwise: the vectors below
are cross-implementation agreement between this model and wotsp.la, which is
weaker than a known answer.  What makes it more than self-consistency is that
(a) it stands on SHA-256, which IS known-answer verified against NIST vectors on
two engines, and (b) the gate's negative controls are discriminating -- see
below.  The honest way to close the gap is a full RFC 8391 XMSS KAT once a
Merkle layer exists; that is named, not implied.

THE DEFECT SHAPE THIS IS BUILT TO CATCH
chacha20.la's BLOCK took its key as an argument and then fed forward hardcoded
constants that happened to equal that one vector's key: correct for exactly one
input, silently wrong for every other, and the known-answer gate could not see
it.  For a signature scheme the same shape is a signer that ignores the message.
So the checks here are not "a valid signature verifies" -- that alone cannot
fail.  They are:
    sign(m1) != sign(m2)          the signer reads the message
    verify(m2, sign(m1)) == False the verifier reads the message
    tampered signature rejected   the verifier reads the signature
    wrong public key rejected     the verifier reads the public key
    sign(m1) == sign(m1)          deterministic (no hidden entropy)
"""

import hashlib

# ---------------------------------------------------------------- domain tags
# Every hash call in the scheme is prefixed with a distinct byte so that no
# output of one function can ever be replayed as the output of another.  Without
# this a chain value could be presented as a secret key.
D_PRF, D_F, D_MSG, D_PK = b"\x00", b"\x01", b"\x02", b"\x03"


def u32be(x):
    return x.to_bytes(4, "big")


class WOTS:
    def __init__(self, n, w):
        assert w in (4, 16, 256), "w must be a power of two we have a lg for"
        self.n = n
        self.w = w
        self.lg_w = {4: 2, 16: 4, 256: 8}[w]
        self.len1 = (8 * n + self.lg_w - 1) // self.lg_w
        # RFC 8391: len2 = floor(log2(len1*(w-1)) / lg_w) + 1
        self.len2 = (len1_bits := (self.len1 * (self.w - 1)).bit_length() - 1) // self.lg_w + 1
        self.len = self.len1 + self.len2

    # -------------------------------------------------------- the three hashes
    def _trunc(self, b):
        return hashlib.sha256(b).digest()[: self.n]

    def prf(self, sk_seed, i):
        """Derive secret chain-start i from the private seed."""
        return self._trunc(D_PRF + sk_seed + u32be(i))

    def f(self, pk_seed, i, j, x):
        """One chain step: step j of chain i.  (i,j) is the WOTS+ tweak."""
        return self._trunc(D_F + pk_seed + u32be(i) + u32be(j) + x)

    def h_msg(self, pk_seed, m):
        return self._trunc(D_MSG + pk_seed + m)

    def compress(self, pk_seed, pks):
        return self._trunc(D_PK + pk_seed + b"".join(pks))

    # ------------------------------------------------------------- the chain
    def chain(self, x, start, steps, i, pk_seed):
        for j in range(start, start + steps):
            x = self.f(pk_seed, i, j, x)
        return x

    # ------------------------------------------------- base-w and the checksum
    def base_w(self, data, out_len):
        """Split `data` into out_len base-w digits, most significant first."""
        out, bits, total, inp = [], 0, 0, 0
        for _ in range(out_len):
            if bits == 0:
                total = data[inp]
                inp += 1
                bits = 8
            bits -= self.lg_w
            out.append((total >> bits) & (self.w - 1))
        return out

    def digits(self, msg_digest):
        """The len digits a signature commits to: message digits, then checksum.

        The checksum is what makes the scheme unforgeable: raising any message
        digit (which an attacker can do, since chains only go forward) must
        LOWER a checksum digit, which they cannot do.  Get the shift wrong and
        the checksum silently drops bits -- forgeable, but it still verifies.
        """
        b = self.base_w(msg_digest, self.len1)
        csum = sum(self.w - 1 - x for x in b)
        csum <<= (8 - ((self.len2 * self.lg_w) % 8)) % 8
        csum_bytes = (self.len2 * self.lg_w + 7) // 8
        b += self.base_w(csum.to_bytes(csum_bytes, "big"), self.len2)
        return b

    # ---------------------------------------------------------------- the API
    def keygen(self, sk_seed, pk_seed):
        sk = [self.prf(sk_seed, i) for i in range(self.len)]
        pks = [self.chain(sk[i], 0, self.w - 1, i, pk_seed) for i in range(self.len)]
        return sk, self.compress(pk_seed, pks)

    def sign(self, sk, pk_seed, msg):
        b = self.digits(self.h_msg(pk_seed, msg))
        return [self.chain(sk[i], 0, b[i], i, pk_seed) for i in range(self.len)]

    def pk_from_sig(self, sig, pk_seed, msg):
        b = self.digits(self.h_msg(pk_seed, msg))
        pks = [
            self.chain(sig[i], b[i], self.w - 1 - b[i], i, pk_seed)
            for i in range(self.len)
        ]
        return self.compress(pk_seed, pks)

    def verify(self, sig, pk, pk_seed, msg):
        return self.pk_from_sig(sig, pk_seed, msg) == pk


# ---------------------------------------------------------------------------
#  Vectors + the discriminating checks.  Seeds are fixed ASCII so wotsp.la can
#  hold them as literals; nothing here depends on randomness.
# ---------------------------------------------------------------------------
SK_SEED = b"logos-wots-sk-seed"
PK_SEED = b"logos-wots-pk-seed"
M1 = b"the first message"
M2 = b"the second message"


def hx(b):
    return b.hex()


def report(n, w):
    ws = WOTS(n, w)
    sk, pk = ws.keygen(SK_SEED, PK_SEED)
    s1 = ws.sign(sk, PK_SEED, M1)
    s2 = ws.sign(sk, PK_SEED, M2)

    cost_keygen = ws.len + ws.len * (w - 1)
    b1 = ws.digits(ws.h_msg(PK_SEED, M1))

    print(f"=== WOTS+  n={n} w={w}  len1={ws.len1} len2={ws.len2} len={ws.len} ===")
    print(f"  digits(m1)[0:8] = {b1[:8]}   checksum digits = {b1[ws.len1:]}")
    print(f"  PK              = {hx(pk)}")
    print(f"  sig(m1)[0]      = {hx(s1[0])}")
    print(f"  sig(m1)[last]   = {hx(s1[-1])}")
    print(f"  hashes: keygen~{cost_keygen}  sign~{sum(b1)}  verify~{ws.len*(w-1)-sum(b1)}")

    # --- the checks that can actually fail -------------------------------
    checks = [
        ("genuine verifies",            ws.verify(s1, pk, PK_SEED, M1) is True),
        ("signer reads the message",    s1 != s2),
        ("verifier reads the message",  ws.verify(s1, pk, PK_SEED, M2) is False),
        ("deterministic",               ws.sign(sk, PK_SEED, M1) == s1),
    ]
    # tampered signature: flip one bit of one chain value
    tam = list(s1)
    tam[0] = bytes([tam[0][0] ^ 1]) + tam[0][1:]
    checks.append(("tampered sig rejected", ws.verify(tam, pk, PK_SEED, M1) is False))
    # wrong public key: flip one bit of the PK
    badpk = bytes([pk[0] ^ 1]) + pk[1:]
    checks.append(("wrong PK rejected", ws.verify(s1, badpk, PK_SEED, M1) is False))

    for name, got in checks:
        print(f"  [{'OK  ' if got else 'FAIL'}] {name}")
    print()
    return all(g for _, g in checks)


if __name__ == "__main__":
    ok = True
    for n, w in ((2, 4), (32, 16)):
        ok &= report(n, w)
    print("MODEL", "OK" if ok else "FAIL")
    raise SystemExit(0 if ok else 1)
