"""make_toy_vectors.py -- write toy_vectors.txt from slhdsa_model.py.

  python3 -I make_toy_vectors.py OUT_PATH

The toy record is a CODE-PATH WITNESS for the Lingua Adamica module, not a
security claim: n=16 h=6 d=3 h'=2 a=3 k=4 lg_w=4 m=4, SHA2 family, category 1
(every function over SHA-256, as for SLH-DSA-SHA2-128s/f).  The generator checks
every verify result it writes against the model before writing it.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import slhdsa_model as M  # noqa: E402

s = M.get("TOY-SHA2")
p = s.p
n = p.n


def hx(b):
    return b.hex() if len(b) else "-"


def seeds(i):
    base = 48 * i
    return bytes(range(base, base + 16)), bytes(range(base + 16, base + 32)), bytes(range(base + 32, base + 48))


def message(L):
    return bytes((7 * j + L) % 256 for j in range(L))


CTX = b"ctx"                          # 63 74 78
ADDRND = bytes(range(0xA0, 0xB0))     # a0 a1 ... af
MSG_LENS = (0, 1, 33, 300)


def flip(sig, byte, mask):
    b = bytearray(sig)
    b[byte] ^= mask
    return bytes(b)


def main():
    out_path = sys.argv[1]
    lines = []
    lay = s.layout()
    H = lines.append
    H("# SLH-DSA toy vectors (FIPS 205 algorithms, toy parameter record), written by make_toy_vectors.py from slhdsa_model.py.")
    H("# The toy set is a CODE-PATH WITNESS for the LA module, NOT a security claim.")
    H("# param: family SHA2, category 1 (F, H, T_l, PRF over SHA-256 with ADRSc and toByte(0,64-n) padding; PRF_msg HMAC-SHA-256; H_msg MGF1-SHA-256)")
    H("# param: n=%d h=%d d=%d h'=%d a=%d k=%d lg_w=%d m=%d; len1=%d len2=%d len=%d; |sk|=%d |pk|=%d |sig|=%d"
      % (p.n, p.h, p.d, p.hp, p.a, p.k, p.lg_w, p.m, p.len1, p.len2, p.len, p.sk_bytes, p.pk_bytes, p.sig_bytes))
    H("# m check: ceil(k*a/8)=%d + ceil((h-h/d)/8)=%d + ceil((h/d)/8)=%d = %d"
      % (p.md_bytes, p.tree_bytes, p.leaf_bytes, p.m_formula))
    H("# signature layout (byte offsets, half-open): R [%d,%d); FORS tree i (i=0..%d) sk [%d+%d*i,%d+%d*i), auth [%d+%d*i,%d+%d*i);"
      % (lay["R"][0], lay["R"][1], p.k - 1, n, (p.a + 1) * n, 2 * n, (p.a + 1) * n,
         2 * n, (p.a + 1) * n, (p.a + 2) * n, (p.a + 1) * n))
    for j, L in enumerate(lay["ht"]):
        H("#   hypertree layer %d: WOTS+ sig [%d,%d), XMSS auth [%d,%d)" % (j, L["wots"][0], L["wots"][1], L["auth"][0], L["auth"][1]))
    H("# keys: key i (i=0,1,2): base=48*i; sk_seed=bytes(range(base,base+16)), sk_prf=bytes(range(base+16,base+32)), pk_seed=bytes(range(base+32,base+48))")
    H("# messages: length L in {0,1,33,300}: byte j = (7*j + L) mod 256.  ctx (pure modes) = 'ctx' = 637478.  hedged addrnd = a0a1...af (bytes(range(0xa0,0xb0))).")
    H("# Hex is lowercase; '-' is an empty field.  One record per line, fields separated by one space:")
    H("#   keygen KEY SK_SEED SK_PRF PK_SEED SK PK                      (Alg. 18 slh_keygen_internal)")
    H("#   sign KEY MODE CTX ADDRND MSG SIG VERIFY                      MODE: internal-det (Alg. 19, opt_rand=PK.seed; verify Alg. 20),")
    H("#                                                                pure-det / pure-hedged (Alg. 22 with M' = 00 || len(ctx) || ctx || M; verify Alg. 24)")
    H("#   reject KEY KIND WHERE IFACE CTX PK MSG SIG VERIFY            IFACE pure (Alg. 24) or internal (Alg. 20); VERIFY is the expected result (0)")
    H("#     WHERE is BYTE:MASK for a one-bit flip, X[BYTE] ^= MASK, of X = SIG for the flip_* kinds, MSG for wrong_msg, PK for wrong_pk_*,")
    H("#     CTX for wrong_ctx; '-' for truncated (last byte dropped) and extended (one 00 byte appended).  Every reject case is derived from key 0's pure-det signature")
    H("#     of the 33-byte message with ctx 'ctx'; the pk/msg/ctx/sig fields are the ones handed to verify.")
    H("#   VERIFY is 1 (True) or 0 (False), the model's result, asserted equal to the expected one when this file was written.")

    sks, skp, pks = seeds(0)
    s.reset_counts(); sk0, pk0 = s.slh_keygen_internal(sks, skp, pks); ckg = dict(s.counts)
    s.reset_counts(); sg0 = s.slh_sign(message(33), CTX, sk0, None); csg = dict(s.counts)
    s.reset_counts(); assert s.slh_verify(message(33), sg0, CTX, pk0); cvf = dict(s.counts)
    for nm, c in (("keygen", ckg), ("sign pure-det key 0, 33-byte msg", csg), ("verify of that signature", cvf)):
        H("# hash calls, %s: F=%d H=%d T_l=%d PRF=%d PRF_msg=%d H_msg=%d (F varies with the message: top-layer WOTS+ chains in sign, all layers in verify)"
          % (nm, c["F"], c["H"], c["T"], c["PRF"], c["PRF_msg"], c["H_msg"]))
    keys = []
    for i in range(3):
        sks, skp, pks = seeds(i)
        sk, pk = s.slh_keygen_internal(sks, skp, pks)
        keys.append((sk, pk))
        H("keygen %d %s %s %s %s %s" % (i, hx(sks), hx(skp), hx(pks), hx(sk), hx(pk)))

    nsign = 0
    for i, (sk, pk) in enumerate(keys):
        for L in MSG_LENS:
            msg = message(L)
            sig_i = s.slh_sign_internal(msg, sk, None)
            ok_i = s.slh_verify_internal(msg, sig_i, pk)
            sig_p = s.slh_sign(msg, CTX, sk, None)
            ok_p = s.slh_verify(msg, sig_p, CTX, pk)
            sig_h = s.slh_sign(msg, CTX, sk, ADDRND)
            ok_h = s.slh_verify(msg, sig_h, CTX, pk)
            assert ok_i is True and ok_p is True and ok_h is True
            assert len({sig_i, sig_p, sig_h}) == 3
            H("sign %d internal-det - - %s %s 1" % (i, hx(msg), hx(sig_i)))
            H("sign %d pure-det %s - %s %s 1" % (i, hx(CTX), hx(msg), hx(sig_p)))
            H("sign %d pure-hedged %s %s %s %s 1" % (i, hx(CTX), hx(ADDRND), hx(msg), hx(sig_h)))
            nsign += 3
            # the default call of the pure interface: an EMPTY ctx, M' = 00 || 00 || M
            sig_e = s.slh_sign(msg, b"", sk, None)
            assert s.slh_verify(msg, sig_e, b"", pk) is True and sig_e not in (sig_i, sig_p, sig_h)
            assert s.slh_verify(msg, sig_e, CTX, pk) is False
            H("sign %d pure-det - - %s %s 1" % (i, hx(msg), hx(sig_e)))
            nsign += 1

    sk, pk = keys[0]
    msg = message(33)
    base = s.slh_sign(msg, CTX, sk, None)
    fors0 = lay["fors"][0]
    fors1 = lay["fors"][1]
    l0, l1 = lay["ht"][0], lay["ht"][1]
    cases = []

    def add_flip(kind, byte, mask):
        cases.append((kind, "%d:%02x" % (byte, mask), "pure", CTX, pk, msg, flip(base, byte, mask)))

    add_flip("flip_R", lay["R"][0] + 5, 0x01)
    add_flip("flip_fors_sk", fors0["sk"][0] + 3, 0x80)
    add_flip("flip_fors_auth", fors1["auth"][0] + n + 7, 0x04)        # FORS tree 1, auth node 1
    add_flip("flip_wots_l0", l0["wots"][0] + 10 * n + 2, 0x10)        # layer 0, chain 10
    add_flip("flip_wots_l1", l1["wots"][0] + 34 * n + 15, 0x01)       # layer 1, chain 34 (checksum chain)
    add_flip("flip_ht_auth", l0["auth"][0] + n + 9, 0x20)             # layer 0, XMSS auth node 1
    add_flip("flip_last_byte", len(base) - 1, 0x01)
    cases.append(("wrong_msg", "0:01", "pure", CTX, pk, flip(msg, 0, 0x01), base))
    cases.append(("wrong_pk_seed", "0:01", "pure", CTX, flip(pk, 0, 0x01), msg, base))
    cases.append(("wrong_pk_root", "%d:01" % (2 * n - 1), "pure", CTX, flip(pk, 2 * n - 1, 0x01), msg, base))
    cases.append(("wrong_ctx", "2:01", "pure", flip(CTX, 2, 0x01), pk, msg, base))
    cases.append(("truncated", "-", "pure", CTX, pk, msg, base[:-1]))
    cases.append(("extended", "-", "pure", CTX, pk, msg, base + b"\x00"))

    assert s.slh_verify(msg, base, CTX, pk) is True
    for (kind, where, iface, ctx, pkx, msgx, sigx) in cases:
        got = s.slh_verify(msgx, sigx, ctx, pkx) if iface == "pure" else s.slh_verify_internal(msgx, sigx, pkx)
        assert got is False, kind
        H("reject 0 %s %s %s %s %s %s %s 0" % (kind, where, iface, hx(ctx), hx(pkx), hx(msgx), hx(sigx)))

    with open(out_path, "w") as f:
        f.write("\n".join(lines) + "\n")
    print("wrote %s: 3 keygen, %d sign (all verify True), %d reject (all verify False)" % (out_path, nsign, len(cases)))


if __name__ == "__main__":
    main()
