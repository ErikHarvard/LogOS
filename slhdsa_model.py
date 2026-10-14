"""slhdsa_model.py -- a plain-Python transcription of FIPS 205 (SLH-DSA).

Written from the standard's algorithm text (FIPS 205, August 2024).  Algorithm
numbers in the comments are FIPS 205's.  This is a gate ORACLE (tooling for
checking the Lingua Adamica module), not production code: it is not constant
time and makes no side-channel claim.

Generic over the parameter record (n, h, d, h', a, k, lg_w, m) and over the hash
family (Section 11.1 SHAKE, Section 11.2 SHA2).  `Params` holds the record; an
`SLHDSA` instance binds a record to a family and counts every call to the six
tweakable functions F, H, T_l, PRF, PRF_msg, H_msg (`counts`).

Midstate note: for SHA2, F/H/T_l/PRF hash PK.seed || toByte(0, b-n) || ADRSc || X,
whose first b bytes (one full compression block, b = 64 for SHA-256 and 128 for
SHA-512) depend only on PK.seed.  With `midstate=True` (default) the model hashes
that block once per PK.seed and copies the hashlib state; the digest is the same
by definition of a Merkle-Damgard hash.  `midstate=False` computes the literal
formula each time; check_acvp.py runs both on the toy set and a keyGen.
"""

import hashlib
import hmac

# ---------------------------------------------------------------------------
# Parameter sets (FIPS 205 Table 2), plus the toy record.

class Params:
    def __init__(self, name, family, n, h, d, hp, a, k, lg_w, m, cat):
        assert family in ("SHA2", "SHAKE")
        assert h == hp * d, "h must equal d*h'"
        self.name, self.family = name, family
        self.n, self.h, self.d, self.hp = n, h, d, hp
        self.a, self.k, self.lg_w, self.m, self.cat = a, k, lg_w, m, cat
        self.w = 1 << lg_w
        # Section 5: len1 = ceil(8n / lg_w); len2 from Algorithm 1.
        self.len1 = (8 * n + lg_w - 1) // lg_w
        self.len2 = gen_len2(n, lg_w)
        self.len = self.len1 + self.len2
        # Byte lengths of the three pieces of the message digest (Alg. 19 lines 7-9).
        self.md_bytes = (k * a + 7) // 8
        self.tree_bytes = (h - h // d + 7) // 8
        self.leaf_bytes = (h // d + 7) // 8
        self.m_formula = self.md_bytes + self.tree_bytes + self.leaf_bytes
        if m != self.m_formula:
            raise ValueError("%s: m=%d but ceil(k*a/8)+ceil((h-h/d)/8)+ceil((h/d)/8)=%d"
                             % (name, m, self.m_formula))
        self.pk_bytes = 2 * n
        self.sk_bytes = 4 * n
        # Alg. 20 line 1: |SIG| = (1 + k(1+a) + h + d*len) * n.
        self.sig_bytes = (1 + k * (1 + a) + h + d * self.len) * n

    def __repr__(self):
        return ("Params(%s n=%d h=%d d=%d h'=%d a=%d k=%d lg_w=%d m=%d len=%d sig=%d)"
                % (self.name, self.n, self.h, self.d, self.hp, self.a, self.k,
                   self.lg_w, self.m, self.len, self.sig_bytes))


def gen_len2(n, lg_w):
    """Algorithm 1: gen_len2(n, lg_w)."""
    w = 1 << lg_w
    len1 = (8 * n + lg_w - 1) // lg_w
    max_checksum = len1 * (w - 1)
    len2 = 1
    capacity = w
    while capacity <= max_checksum:
        len2 += 1
        capacity *= w
    return len2


_TABLE2 = [
    # name           n   h   d  h'  a   k  lg_w  m  category
    ("128s",        16, 63,  7, 9, 12, 14, 4, 30, 1),
    ("128f",        16, 66, 22, 3,  6, 33, 4, 34, 1),
    ("192s",        24, 63,  7, 9, 14, 17, 4, 39, 3),
    ("192f",        24, 66, 22, 3,  8, 33, 4, 42, 3),
    ("256s",        32, 64,  8, 8, 14, 22, 4, 47, 5),
    ("256f",        32, 68, 17, 4,  9, 35, 4, 49, 5),
]

PARAMS = {}
for _fam in ("SHA2", "SHAKE"):
    for (_s, _n, _h, _d, _hp, _a, _k, _lgw, _m, _cat) in _TABLE2:
        _nm = "SLH-DSA-%s-%s" % (_fam, _s)
        PARAMS[_nm] = Params(_nm, _fam, _n, _h, _d, _hp, _a, _k, _lgw, _m, _cat)

# Toy record: a code-path witness only, NOT a security claim.  Category 1 hashing.
TOY_SHA2 = Params("TOY-SHA2", "SHA2", n=16, h=6, d=3, hp=2, a=3, k=4, lg_w=4, m=4, cat=1)
TOY_SHAKE = Params("TOY-SHAKE", "SHAKE", n=16, h=6, d=3, hp=2, a=3, k=4, lg_w=4, m=4, cat=1)

# Expected public-key / signature sizes from Table 2 (a cross-check of the formula).
TABLE2_SIG_BYTES = {"128s": 7856, "128f": 17088, "192s": 16224, "192f": 35664,
                    "256s": 29792, "256f": 49856}

# ---------------------------------------------------------------------------
# Section 4: byte/integer conversions and base_2b.

def toInt(X, n):
    """Algorithm 2: toInt(X, n) -- big-endian."""
    total = 0
    for i in range(n):
        total = 256 * total + X[i]
    return total


def toByte(x, n):
    """Algorithm 3: toByte(x, n) -- big-endian, n bytes."""
    total = x
    S = bytearray(n)
    for i in range(n):
        S[n - 1 - i] = total & 0xFF
        total >>= 8
    return bytes(S)


def base_2b(X, b, out_len):
    """Algorithm 4: base_2b(X, b, out_len)."""
    inp = 0
    bits = 0
    total = 0
    baseb = []
    for _ in range(out_len):
        while bits < b:
            total = (total << 8) + X[inp]
            inp += 1
            bits += 8
        bits -= b
        baseb.append((total >> bits) % (1 << b))
    return baseb

# ---------------------------------------------------------------------------
# Section 4.2: ADRS, a 32-byte address (Table 1 member functions).

WOTS_HASH, WOTS_PK, TREE, FORS_TREE, FORS_ROOTS, WOTS_PRF, FORS_PRF = 0, 1, 2, 3, 4, 5, 6


class ADRS:
    __slots__ = ("b",)

    def __init__(self, raw=None):
        self.b = bytearray(32) if raw is None else bytearray(raw)

    def copy(self):
        return ADRS(self.b)

    def setLayerAddress(self, l):
        self.b[0:4] = toByte(l, 4)

    def setTreeAddress(self, t):
        self.b[4:16] = toByte(t, 12)

    def setTypeAndClear(self, Y):
        self.b[16:20] = toByte(Y, 4)
        self.b[20:32] = bytes(12)

    def setKeyPairAddress(self, i):
        self.b[20:24] = toByte(i, 4)

    def setChainAddress(self, i):
        self.b[24:28] = toByte(i, 4)

    def setTreeHeight(self, z):
        self.b[24:28] = toByte(z, 4)

    def setHashAddress(self, i):
        self.b[28:32] = toByte(i, 4)

    def setTreeIndex(self, i):
        self.b[28:32] = toByte(i, 4)

    def getKeyPairAddress(self):
        return toInt(self.b[20:24], 4)

    def getTreeIndex(self):
        return toInt(self.b[28:32], 4)

    def bytes(self):
        return bytes(self.b)

    def compressed(self):
        """Section 11.2: ADRSc = ADRS[3] || ADRS[8:16] || ADRS[19] || ADRS[20:32] (22 bytes)."""
        b = self.b
        return bytes(b[3:4] + b[8:16] + b[19:20] + b[20:32])

# ---------------------------------------------------------------------------
# Hash families (Section 11).

def mgf1(hashname, seed, length):
    """MGF1 (RFC 8017 B.2.1) as FIPS 205 Section 11.2 uses it."""
    out = b""
    counter = 0
    while len(out) < length:
        out += hashlib.new(hashname, seed + toByte(counter, 4)).digest()
        counter += 1
    return out[:length]


class SLHDSA:
    """One parameter record bound to its hash family, with call counters."""

    COUNTED = ("F", "H", "T", "PRF", "PRF_msg", "H_msg")

    def __init__(self, params, midstate=True):
        self.p = params
        self.midstate = midstate
        self.counts = dict((c, 0) for c in self.COUNTED)
        self._prefix_cache = {}
        p = params
        if p.family == "SHA2":
            if p.cat == 1:
                # Section 11.2.1: every function over SHA-256.
                self._small, self._big = "sha256", "sha256"
            else:
                # Section 11.2.2 (categories 3 and 5): F and PRF over SHA-256,
                # H, T_l, H_msg and PRF_msg over SHA-512.
                self._small, self._big = "sha256", "sha512"

    def reset_counts(self):
        for c in self.COUNTED:
            self.counts[c] = 0

    # -- SHA2 helpers -------------------------------------------------------
    def _sha2_tweak(self, hashname, pk_seed, adrs, M):
        """Trunc_n(Hash(PK.seed || toByte(0, b - n) || ADRSc || M)), b the block size."""
        n = self.p.n
        blk = 64 if hashname == "sha256" else 128
        adrsc = adrs.compressed()
        if self.midstate:
            key = (hashname, bytes(pk_seed))
            st = self._prefix_cache.get(key)
            if st is None:
                st = hashlib.new(hashname, pk_seed + toByte(0, blk - n))
                if len(self._prefix_cache) > 64:
                    self._prefix_cache.clear()
                self._prefix_cache[key] = st
            h = st.copy()
            h.update(adrsc + M)
            return h.digest()[:n]
        return hashlib.new(hashname, pk_seed + toByte(0, blk - n) + adrsc + M).digest()[:n]

    # -- the six functions (Section 11.1 SHAKE / Section 11.2 SHA2) -------
    def F(self, pk_seed, adrs, M1):
        self.counts["F"] += 1
        if self.p.family == "SHAKE":
            return hashlib.shake_256(pk_seed + adrs.bytes() + M1).digest(self.p.n)
        return self._sha2_tweak(self._small, pk_seed, adrs, M1)

    def H(self, pk_seed, adrs, M2):
        self.counts["H"] += 1
        if self.p.family == "SHAKE":
            return hashlib.shake_256(pk_seed + adrs.bytes() + M2).digest(self.p.n)
        return self._sha2_tweak(self._big, pk_seed, adrs, M2)

    def T(self, pk_seed, adrs, Ml):
        self.counts["T"] += 1
        if self.p.family == "SHAKE":
            return hashlib.shake_256(pk_seed + adrs.bytes() + Ml).digest(self.p.n)
        return self._sha2_tweak(self._big, pk_seed, adrs, Ml)

    def PRF(self, pk_seed, sk_seed, adrs):
        self.counts["PRF"] += 1
        if self.p.family == "SHAKE":
            return hashlib.shake_256(pk_seed + adrs.bytes() + sk_seed).digest(self.p.n)
        return self._sha2_tweak(self._small, pk_seed, adrs, sk_seed)

    def PRF_msg(self, sk_prf, opt_rand, M):
        self.counts["PRF_msg"] += 1
        if self.p.family == "SHAKE":
            return hashlib.shake_256(sk_prf + opt_rand + M).digest(self.p.n)
        # Trunc_n(HMAC-SHA-256/512(SK.prf, opt_rand || M)).
        return hmac.new(sk_prf, opt_rand + M, self._big).digest()[:self.p.n]

    def H_msg(self, R, pk_seed, pk_root, M):
        self.counts["H_msg"] += 1
        if self.p.family == "SHAKE":
            return hashlib.shake_256(R + pk_seed + pk_root + M).digest(self.p.m)
        # MGF1-SHA-x(R || PK.seed || SHA-x(R || PK.seed || PK.root || M), m).
        inner = hashlib.new(self._big, R + pk_seed + pk_root + M).digest()
        return mgf1(self._big, R + pk_seed + inner, self.p.m)

    # -- Section 5: WOTS+ ---------------------------------------------------
    def chain(self, X, i, s, pk_seed, adrs):
        """Algorithm 5: chain(X, i, s, PK.seed, ADRS)."""
        tmp = X
        for j in range(i, i + s):
            adrs.setHashAddress(j)
            tmp = self.F(pk_seed, adrs, tmp)
        return tmp

    def _wots_msg(self, M):
        """Alg. 7 lines 1-7 / Alg. 8 lines 1-7: message + checksum in base w."""
        p = self.p
        csum = 0
        msg = base_2b(M, p.lg_w, p.len1)
        for i in range(p.len1):
            csum += p.w - 1 - msg[i]
        csum <<= (8 - ((p.len2 * p.lg_w) % 8)) % 8
        msg = msg + base_2b(toByte(csum, (p.len2 * p.lg_w + 7) // 8), p.lg_w, p.len2)
        return msg

    def wots_pkGen(self, sk_seed, pk_seed, adrs):
        """Algorithm 6: wots_pkGen(SK.seed, PK.seed, ADRS)."""
        p = self.p
        skADRS = adrs.copy()
        skADRS.setTypeAndClear(WOTS_PRF)
        skADRS.setKeyPairAddress(adrs.getKeyPairAddress())
        tmp = []
        for i in range(p.len):
            skADRS.setChainAddress(i)
            sk = self.PRF(pk_seed, sk_seed, skADRS)
            adrs.setChainAddress(i)
            tmp.append(self.chain(sk, 0, p.w - 1, pk_seed, adrs))
        wotspkADRS = adrs.copy()
        wotspkADRS.setTypeAndClear(WOTS_PK)
        wotspkADRS.setKeyPairAddress(adrs.getKeyPairAddress())
        return self.T(pk_seed, wotspkADRS, b"".join(tmp))

    def wots_sign(self, M, sk_seed, pk_seed, adrs):
        """Algorithm 7: wots_sign(M, SK.seed, PK.seed, ADRS)."""
        p = self.p
        msg = self._wots_msg(M)
        skADRS = adrs.copy()
        skADRS.setTypeAndClear(WOTS_PRF)
        skADRS.setKeyPairAddress(adrs.getKeyPairAddress())
        sig = []
        for i in range(p.len):
            skADRS.setChainAddress(i)
            sk = self.PRF(pk_seed, sk_seed, skADRS)
            adrs.setChainAddress(i)
            sig.append(self.chain(sk, 0, msg[i], pk_seed, adrs))
        return b"".join(sig)

    def wots_pkFromSig(self, sig, M, pk_seed, adrs):
        """Algorithm 8: wots_pkFromSig(sig, M, PK.seed, ADRS)."""
        p = self.p
        n = p.n
        msg = self._wots_msg(M)
        tmp = []
        for i in range(p.len):
            adrs.setChainAddress(i)
            tmp.append(self.chain(sig[i * n:(i + 1) * n], msg[i], p.w - 1 - msg[i],
                                  pk_seed, adrs))
        wotspkADRS = adrs.copy()
        wotspkADRS.setTypeAndClear(WOTS_PK)
        wotspkADRS.setKeyPairAddress(adrs.getKeyPairAddress())
        return self.T(pk_seed, wotspkADRS, b"".join(tmp))

    # -- Section 6: XMSS ----------------------------------------------------
    def xmss_node(self, sk_seed, i, z, pk_seed, adrs):
        """Algorithm 9: xmss_node(SK.seed, i, z, PK.seed, ADRS)."""
        if z == 0:
            adrs.setTypeAndClear(WOTS_HASH)
            adrs.setKeyPairAddress(i)
            return self.wots_pkGen(sk_seed, pk_seed, adrs)
        lnode = self.xmss_node(sk_seed, 2 * i, z - 1, pk_seed, adrs)
        rnode = self.xmss_node(sk_seed, 2 * i + 1, z - 1, pk_seed, adrs)
        adrs.setTypeAndClear(TREE)
        adrs.setTreeHeight(z)
        adrs.setTreeIndex(i)
        return self.H(pk_seed, adrs, lnode + rnode)

    def xmss_sign(self, M, sk_seed, idx, pk_seed, adrs):
        """Algorithm 10: xmss_sign(M, SK.seed, idx, PK.seed, ADRS)."""
        p = self.p
        AUTH = []
        for j in range(p.hp):
            k = (idx >> j) ^ 1
            AUTH.append(self.xmss_node(sk_seed, k, j, pk_seed, adrs))
        adrs.setTypeAndClear(WOTS_HASH)
        adrs.setKeyPairAddress(idx)
        sig = self.wots_sign(M, sk_seed, pk_seed, adrs)
        return sig + b"".join(AUTH)

    def xmss_pkFromSig(self, idx, SIG_XMSS, M, pk_seed, adrs):
        """Algorithm 11: xmss_pkFromSig(idx, SIG_XMSS, M, PK.seed, ADRS)."""
        p = self.p
        n = p.n
        adrs.setTypeAndClear(WOTS_HASH)
        adrs.setKeyPairAddress(idx)
        sig = SIG_XMSS[0:p.len * n]
        AUTH = SIG_XMSS[p.len * n:(p.len + p.hp) * n]
        node0 = self.wots_pkFromSig(sig, M, pk_seed, adrs)
        adrs.setTypeAndClear(TREE)
        adrs.setTreeIndex(idx)
        for k in range(p.hp):
            adrs.setTreeHeight(k + 1)
            auth_k = AUTH[k * n:(k + 1) * n]
            if (idx >> k) % 2 == 0:
                adrs.setTreeIndex(adrs.getTreeIndex() // 2)
                node1 = self.H(pk_seed, adrs, node0 + auth_k)
            else:
                adrs.setTreeIndex((adrs.getTreeIndex() - 1) // 2)
                node1 = self.H(pk_seed, adrs, auth_k + node0)
            node0 = node1
        return node0

    # -- Section 7: the hypertree -------------------------------------------
    def ht_sign(self, M, sk_seed, pk_seed, idx_tree, idx_leaf):
        """Algorithm 12: ht_sign(M, SK.seed, PK.seed, idx_tree, idx_leaf)."""
        p = self.p
        adrs = ADRS()
        adrs.setTreeAddress(idx_tree)
        SIG_tmp = self.xmss_sign(M, sk_seed, idx_leaf, pk_seed, adrs)
        SIG_HT = SIG_tmp
        root = self.xmss_pkFromSig(idx_leaf, SIG_tmp, M, pk_seed, adrs)
        for j in range(1, p.d):
            idx_leaf = idx_tree % (1 << p.hp)
            idx_tree = idx_tree >> p.hp
            adrs.setLayerAddress(j)
            adrs.setTreeAddress(idx_tree)
            SIG_tmp = self.xmss_sign(root, sk_seed, idx_leaf, pk_seed, adrs)
            SIG_HT = SIG_HT + SIG_tmp
            if j < p.d - 1:
                root = self.xmss_pkFromSig(idx_leaf, SIG_tmp, root, pk_seed, adrs)
        return SIG_HT

    def ht_verify(self, M, SIG_HT, pk_seed, idx_tree, idx_leaf, pk_root):
        """Algorithm 13: ht_verify(M, SIG_HT, PK.seed, idx_tree, idx_leaf, PK.root)."""
        p = self.p
        step = (p.hp + p.len) * p.n
        adrs = ADRS()
        adrs.setTreeAddress(idx_tree)
        SIG_tmp = SIG_HT[0:step]
        node = self.xmss_pkFromSig(idx_leaf, SIG_tmp, M, pk_seed, adrs)
        for j in range(1, p.d):
            idx_leaf = idx_tree % (1 << p.hp)
            idx_tree = idx_tree >> p.hp
            adrs.setLayerAddress(j)
            adrs.setTreeAddress(idx_tree)
            SIG_tmp = SIG_HT[j * step:(j + 1) * step]
            node = self.xmss_pkFromSig(idx_leaf, SIG_tmp, node, pk_seed, adrs)
        return node == pk_root

    # -- Section 8: FORS ----------------------------------------------------
    def fors_skGen(self, sk_seed, pk_seed, adrs, idx):
        """Algorithm 14: fors_skGen(SK.seed, PK.seed, ADRS, idx)."""
        skADRS = adrs.copy()
        skADRS.setTypeAndClear(FORS_PRF)
        skADRS.setKeyPairAddress(adrs.getKeyPairAddress())
        skADRS.setTreeIndex(idx)
        return self.PRF(pk_seed, sk_seed, skADRS)

    def fors_node(self, sk_seed, i, z, pk_seed, adrs):
        """Algorithm 15: fors_node(SK.seed, i, z, PK.seed, ADRS)."""
        if z == 0:
            sk = self.fors_skGen(sk_seed, pk_seed, adrs, i)
            adrs.setTreeHeight(0)
            adrs.setTreeIndex(i)
            return self.F(pk_seed, adrs, sk)
        lnode = self.fors_node(sk_seed, 2 * i, z - 1, pk_seed, adrs)
        rnode = self.fors_node(sk_seed, 2 * i + 1, z - 1, pk_seed, adrs)
        adrs.setTreeHeight(z)
        adrs.setTreeIndex(i)
        return self.H(pk_seed, adrs, lnode + rnode)

    def fors_sign(self, md, sk_seed, pk_seed, adrs):
        """Algorithm 16: fors_sign(md, SK.seed, PK.seed, ADRS)."""
        p = self.p
        out = []
        indices = base_2b(md, p.a, p.k)
        for i in range(p.k):
            out.append(self.fors_skGen(sk_seed, pk_seed, adrs, (i << p.a) + indices[i]))
            for j in range(p.a):
                s = (indices[i] >> j) ^ 1
                out.append(self.fors_node(sk_seed, (i << (p.a - j)) + s, j, pk_seed, adrs))
        return b"".join(out)

    def fors_pkFromSig(self, SIG_FORS, md, pk_seed, adrs):
        """Algorithm 17: fors_pkFromSig(SIG_FORS, md, PK.seed, ADRS)."""
        p = self.p
        n = p.n
        indices = base_2b(md, p.a, p.k)
        root = []
        for i in range(p.k):
            sk = SIG_FORS[i * (p.a + 1) * n:(i * (p.a + 1) + 1) * n]
            adrs.setTreeHeight(0)
            adrs.setTreeIndex((i << p.a) + indices[i])
            node0 = self.F(pk_seed, adrs, sk)
            auth = SIG_FORS[(i * (p.a + 1) + 1) * n:(i + 1) * (p.a + 1) * n]
            for j in range(p.a):
                adrs.setTreeHeight(j + 1)
                auth_j = auth[j * n:(j + 1) * n]
                if (indices[i] >> j) % 2 == 0:
                    adrs.setTreeIndex(adrs.getTreeIndex() // 2)
                    node1 = self.H(pk_seed, adrs, node0 + auth_j)
                else:
                    adrs.setTreeIndex((adrs.getTreeIndex() - 1) // 2)
                    node1 = self.H(pk_seed, adrs, auth_j + node0)
                node0 = node1
            root.append(node0)
        forspkADRS = adrs.copy()
        forspkADRS.setTypeAndClear(FORS_ROOTS)
        forspkADRS.setKeyPairAddress(adrs.getKeyPairAddress())
        return self.T(pk_seed, forspkADRS, b"".join(root))

    # -- Section 9: SLH-DSA internal functions ------------------------------
    def slh_keygen_internal(self, sk_seed, sk_prf, pk_seed):
        """Algorithm 18: slh_keygen_internal(SK.seed, SK.prf, PK.seed) -> (SK, PK)."""
        p = self.p
        for x in (sk_seed, sk_prf, pk_seed):
            if len(x) != p.n:
                raise ValueError("keygen seed must be n bytes")
        adrs = ADRS()
        adrs.setLayerAddress(p.d - 1)
        pk_root = self.xmss_node(sk_seed, 0, p.hp, pk_seed, adrs)
        return (sk_seed + sk_prf + pk_seed + pk_root, pk_seed + pk_root)

    def _split_digest(self, digest):
        """Alg. 19 lines 7-12 / Alg. 20 lines 8-13."""
        p = self.p
        md = digest[0:p.md_bytes]
        tmp_idx_tree = digest[p.md_bytes:p.md_bytes + p.tree_bytes]
        tmp_idx_leaf = digest[p.md_bytes + p.tree_bytes:
                              p.md_bytes + p.tree_bytes + p.leaf_bytes]
        idx_tree = toInt(tmp_idx_tree, p.tree_bytes) % (1 << (p.h - p.h // p.d))
        idx_leaf = toInt(tmp_idx_leaf, p.leaf_bytes) % (1 << (p.h // p.d))
        return md, idx_tree, idx_leaf

    def slh_sign_internal(self, M, SK, addrnd=None):
        """Algorithm 19: slh_sign_internal(M, SK, addrnd); addrnd None = deterministic."""
        p = self.p
        n = p.n
        if len(SK) != p.sk_bytes:
            raise ValueError("SK must be 4n bytes")
        sk_seed, sk_prf, pk_seed, pk_root = SK[0:n], SK[n:2 * n], SK[2 * n:3 * n], SK[3 * n:4 * n]
        adrs = ADRS()
        # Line 2: opt_rand <- addrnd (hedged) or PK.seed (deterministic variant).
        if addrnd is None:
            opt_rand = pk_seed
        else:
            if len(addrnd) != n:
                raise ValueError("addrnd must be n bytes")
            opt_rand = addrnd
        R = self.PRF_msg(sk_prf, opt_rand, M)
        SIG = R
        digest = self.H_msg(R, pk_seed, pk_root, M)
        md, idx_tree, idx_leaf = self._split_digest(digest)
        adrs.setTreeAddress(idx_tree)
        adrs.setTypeAndClear(FORS_TREE)
        adrs.setKeyPairAddress(idx_leaf)
        SIG_FORS = self.fors_sign(md, sk_seed, pk_seed, adrs)
        SIG = SIG + SIG_FORS
        PK_FORS = self.fors_pkFromSig(SIG_FORS, md, pk_seed, adrs)
        SIG_HT = self.ht_sign(PK_FORS, sk_seed, pk_seed, idx_tree, idx_leaf)
        return SIG + SIG_HT

    def slh_verify_internal(self, M, SIG, PK):
        """Algorithm 20: slh_verify_internal(M, SIG, PK).  Total: bad lengths give False."""
        p = self.p
        n = p.n
        if not isinstance(SIG, (bytes, bytearray)) or not isinstance(PK, (bytes, bytearray)):
            return False
        if not isinstance(M, (bytes, bytearray)):
            return False
        if len(PK) != p.pk_bytes:
            return False
        if len(SIG) != p.sig_bytes:
            return False
        SIG, PK, M = bytes(SIG), bytes(PK), bytes(M)
        pk_seed, pk_root = PK[0:n], PK[n:2 * n]
        adrs = ADRS()
        R = SIG[0:n]
        SIG_FORS = SIG[n:(1 + p.k * (1 + p.a)) * n]
        SIG_HT = SIG[(1 + p.k * (1 + p.a)) * n:(1 + p.k * (1 + p.a) + p.h + p.d * p.len) * n]
        digest = self.H_msg(R, pk_seed, pk_root, M)
        md, idx_tree, idx_leaf = self._split_digest(digest)
        adrs.setTreeAddress(idx_tree)
        adrs.setTypeAndClear(FORS_TREE)
        adrs.setKeyPairAddress(idx_leaf)
        PK_FORS = self.fors_pkFromSig(SIG_FORS, md, pk_seed, adrs)
        return self.ht_verify(PK_FORS, SIG_HT, pk_seed, idx_tree, idx_leaf, pk_root)

    # -- Section 10.2: the external pure interface --------------------------
    @staticmethod
    def pure_message(M, ctx):
        """Alg. 22 line 8 / Alg. 24 line 4: M' = toByte(0,1) || toByte(|ctx|,1) || ctx || M."""
        return toByte(0, 1) + toByte(len(ctx), 1) + ctx + M

    def slh_sign(self, M, ctx, SK, addrnd=None):
        """Algorithm 22: slh_sign(M, ctx, SK); addrnd supplied by the caller (None = deterministic)."""
        if len(ctx) > 255:
            raise ValueError("ctx longer than 255 bytes")
        return self.slh_sign_internal(self.pure_message(M, ctx), SK, addrnd)

    def slh_verify(self, M, SIG, ctx, PK):
        """Algorithm 24: slh_verify(M, SIG, ctx, PK).  Total."""
        if not isinstance(ctx, (bytes, bytearray)) or len(ctx) > 255:
            return False
        if not isinstance(M, (bytes, bytearray)):
            return False
        return self.slh_verify_internal(self.pure_message(bytes(M), bytes(ctx)), SIG, PK)

    # -- Signature layout helpers (offsets of each part, for rejection tests) --
    def layout(self):
        """Byte offsets of the parts of a signature (Fig. 13/14 of FIPS 205)."""
        p = self.p
        n = p.n
        lay = {"R": (0, n)}
        off = n
        fors = []
        for i in range(p.k):
            fors.append({"sk": (off, off + n), "auth": (off + n, off + (p.a + 1) * n)})
            off += (p.a + 1) * n
        lay["fors"] = fors
        layers = []
        for j in range(p.d):
            layers.append({"wots": (off, off + p.len * n),
                           "auth": (off + p.len * n, off + (p.len + p.hp) * n)})
            off += (p.len + p.hp) * n
        lay["ht"] = layers
        lay["end"] = off
        assert off == p.sig_bytes
        return lay


def get(name, midstate=True):
    """SLHDSA instance for a FIPS 205 parameter-set name or 'TOY-SHA2' / 'TOY-SHAKE'."""
    if name == "TOY-SHA2":
        return SLHDSA(TOY_SHA2, midstate)
    if name == "TOY-SHAKE":
        return SLHDSA(TOY_SHAKE, midstate)
    return SLHDSA(PARAMS[name], midstate)


for _s, _sig in TABLE2_SIG_BYTES.items():
    for _fam in ("SHA2", "SHAKE"):
        assert PARAMS["SLH-DSA-%s-%s" % (_fam, _s)].sig_bytes == _sig
