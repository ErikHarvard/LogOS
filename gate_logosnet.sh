#!/usr/bin/env bash
# gate_logosnet.sh — LogosNet (logosnet.la, NET_KIT), on the native VM.
#
# WHAT IT GUARDS (NET_DESIGN.md section 2):
#   1. frames: frame/deframe against Python's own framing (struct ">I"), over
#      random payloads cut at random chunk boundaries (1-byte chunks, cuts
#      inside a header, a 1 MiB payload, an empty one); a payload of 1 MiB + 1
#      halts loudly; a declared length above 1 MiB is reported as broken.
#   2. Noise: the gate's own Noise (noiseref.py: the `cryptography` package's
#      X25519 and ChaCha20-Poly1305 when present, else RFC 7748 / RFC 8439
#      transcriptions; SHA-256 and HMAC from hashlib) is first checked against
#      the published cacophony vectors for Noise_XX and Noise_X; then the LA's
#      XX and X match it byte for byte on those vectors and on random keys with
#      fixed ephemerals and the LogosNet/1 prologue, in both roles (the LA
#      initiator reading the oracle's responder messages and the reverse),
#      through the handshake and six transport messages; flipped bytes and a
#      replay are refused; the 65535-byte limit both ways; an all-zero DH
#      ends the handshake; out-of-turn use halts.
# ISOLATION: a private temp dir (gate_wm_common.sh; mktemp honours TMPDIR).
# VM only (the C host is far too slow for the crypto underneath).
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1
pass() { echo "PASS  logosnet: $*"; }
fail() { echo "FAIL  logosnet: $*"; ok=0; }
check() { if [ "$1" = 1 ]; then pass "$2"; else fail "$2"; [ -n "${3:-}" ] && echo "      $3"; fi; }
command -v python3 >/dev/null || { echo "FAIL  logosnet: python3 (the oracle) is not installed"; exit 1; }
wm_setup logosnet.la logoscrypt.la x25519.la
G0=$(date +%s)

# vm_compile PROG.la BIN: compile on the VM into $T/BIN; a failure ends the gate
vm_compile() {
    cp "$T/$1" "$T/logos_source.la"; cp "$T/compiler.bin" "$T/logos_program.bin"
    vrc=0; ( cd "$T" && timeout "$WM_VM_TIMEOUT" ./logos_secd >/dev/null 2>"$T/vce" ) || vrc=$?
    [ "$vrc" = 0 ] || { echo "FAIL  logosnet: $1 did not compile (rc $vrc)"; tail -c 400 "$T/vce"; exit 1; }
    cp "$T/logos_program.bin" "$T/$2"
}
# vm_run BIN MODE OUT: run BIN in $T with mode.txt = MODE; sets vrc, stderr in $T/vre
vm_run() {
    printf '%s' "$2" > "$T/mode.txt"; cp "$T/$1" "$T/logos_program.bin"
    vrc=0; ( cd "$T" && timeout "$WM_VM_TIMEOUT" ./logos_secd >"$3" 2>"$T/vre" ) || vrc=$?
}

# ── the oracle ─────────────────────────────────────────────────────────
cat > "$T/noiseref.py" <<'PYEOF'
# noiseref.py — the gate's own Noise (revision 34), independent of the LA:
# X25519 and ChaCha20-Poly1305 from the `cryptography` package when present,
# else the RFC 7748 / RFC 8439 transcriptions below; SHA-256 and HMAC from
# hashlib/hmac. Checked against the published cacophony vectors before use.
import hashlib, hmac, struct
M32 = 0xffffffff
P25519 = 2**255 - 19
def _clamp(k):
    k = bytearray(k); k[0] &= 248; k[31] &= 127; k[31] |= 64; return bytes(k)
def t_x25519(k, u):            # RFC 7748 section 5
    k = int.from_bytes(_clamp(k), "little")
    x1 = (int.from_bytes(u, "little") & ((1 << 255) - 1)) % P25519
    x2, z2, x3, z3, swap = 1, 0, x1, 1, 0
    for t in range(254, -1, -1):
        kt = (k >> t) & 1; swap ^= kt
        if swap: x2, x3, z2, z3 = x3, x2, z3, z2
        swap = kt
        A = x2 + z2; AA = A * A; B = x2 - z2; BB = B * B; E = AA - BB
        C = x3 + z3; D = x3 - z3; DA = D * A; CB = C * B
        x3 = (DA + CB) ** 2 % P25519; z3 = x1 * (DA - CB) ** 2 % P25519
        x2 = AA * BB % P25519; z2 = E * (AA + 121665 * E) % P25519
    if swap: x2, x3, z2, z3 = x3, x2, z3, z2
    return (x2 * pow(z2, P25519 - 2, P25519) % P25519).to_bytes(32, "little")
def _rotl(v, c): return ((v << c) & M32) | (v >> (32 - c))
def _qr(x, a, b, c, d):
    x[a] = (x[a] + x[b]) & M32; x[d] = _rotl(x[d] ^ x[a], 16)
    x[c] = (x[c] + x[d]) & M32; x[b] = _rotl(x[b] ^ x[c], 12)
    x[a] = (x[a] + x[b]) & M32; x[d] = _rotl(x[d] ^ x[a], 8)
    x[c] = (x[c] + x[d]) & M32; x[b] = _rotl(x[b] ^ x[c], 7)
def _block(key, ctr, nonce):    # RFC 8439 2.3
    st = [0x61707865, 0x3320646e, 0x79622d32, 0x6b206574] + list(struct.unpack("<8I", key)) \
         + [ctr] + list(struct.unpack("<3I", nonce))
    x = st[:]
    for _ in range(10):
        _qr(x, 0, 4, 8, 12); _qr(x, 1, 5, 9, 13); _qr(x, 2, 6, 10, 14); _qr(x, 3, 7, 11, 15)
        _qr(x, 0, 5, 10, 15); _qr(x, 1, 6, 11, 12); _qr(x, 2, 7, 8, 13); _qr(x, 3, 4, 9, 14)
    return struct.pack("<16I", *[(x[i] + st[i]) & M32 for i in range(16)])
def _chacha(key, ctr, nonce, data):
    out = bytearray()
    for i in range(0, len(data), 64):
        ks = _block(key, ctr + i // 64, nonce)
        out += bytes(a ^ b for a, b in zip(data[i:i + 64], ks))
    return bytes(out)
def _poly(key, msg):            # RFC 8439 2.5
    r = int.from_bytes(key[:16], "little") & 0x0ffffffc0ffffffc0ffffffc0fffffff
    s = int.from_bytes(key[16:], "little"); p = (1 << 130) - 5; acc = 0
    for i in range(0, len(msg), 16):
        acc = (acc + int.from_bytes(msg[i:i + 16] + b"\x01", "little")) * r % p
    return ((acc + s) & ((1 << 128) - 1)).to_bytes(16, "little")
def _pad16(b): return b"\x00" * (-len(b) % 16)
def _macdata(ad, c): return ad + _pad16(ad) + c + _pad16(c) + struct.pack("<QQ", len(ad), len(c))
def t_seal(k, n, ad, pt):       # RFC 8439 2.8
    ct = _chacha(k, 1, n, pt); return ct + _poly(_block(k, 0, n)[:32], _macdata(ad, ct))
def t_open(k, n, ad, ct):
    if len(ct) < 16: return None
    c, tag = ct[:-16], ct[-16:]
    if not hmac.compare_digest(_poly(_block(k, 0, n)[:32], _macdata(ad, c)), tag): return None
    return _chacha(k, 1, n, c)
try:
    from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey, X25519PublicKey
    from cryptography.hazmat.primitives.ciphers.aead import ChaCha20Poly1305
    from cryptography.hazmat.primitives import serialization as _S
    from cryptography.exceptions import InvalidTag
    def x_pub(sk): return X25519PrivateKey.from_private_bytes(sk).public_key().public_bytes(_S.Encoding.Raw, _S.PublicFormat.Raw)
    def x_dh(sk, pk): return X25519PrivateKey.from_private_bytes(sk).exchange(X25519PublicKey.from_public_bytes(pk))
    def seal(k, n, ad, pt): return ChaCha20Poly1305(k).encrypt(n, pt, ad)
    def aopen(k, n, ad, ct):
        try: return ChaCha20Poly1305(k).decrypt(n, ct, ad)
        except InvalidTag: return None
    ORACLE = "the cryptography package"
except ImportError:
    def x_pub(sk): return t_x25519(sk, bytes([9]) + bytes(31))
    def x_dh(sk, pk):
        r = t_x25519(sk, pk)
        if r == bytes(32): raise ValueError("all-zero DH")
        return r
    seal, aopen = t_seal, t_open
    ORACLE = "the RFC 7748 / 8439 transcriptions"
def sha256(b): return hashlib.sha256(b).digest()
def hmac256(k, m): return hmac.new(k, m, hashlib.sha256).digest()
def nonce(n): return b"\x00" * 4 + struct.pack("<Q", n)
class Bad(Exception): pass
class CS:
    def __init__(s, k=None): s.k, s.n = k, 0
    def enc(s, ad, pt):
        if s.k is None: return pt
        ct = seal(s.k, nonce(s.n), ad, pt); s.n += 1; return ct
    def dec(s, ad, ct):
        if s.k is None: return ct
        pt = aopen(s.k, nonce(s.n), ad, ct)
        if pt is None: raise Bad("decrypt")
        s.n += 1; return pt
def hkdf2(ck, ikm):
    tk = hmac256(ck, ikm); o1 = hmac256(tk, b"\x01"); return o1, hmac256(tk, o1 + b"\x02")
class SS:
    def __init__(s, name):
        s.h = name + bytes(32 - len(name)) if len(name) <= 32 else sha256(name)
        s.ck, s.cs = s.h, CS()
    def mix_hash(s, d): s.h = sha256(s.h + d)
    def mix_key(s, ikm): s.ck, tk = hkdf2(s.ck, ikm); s.cs = CS(tk)
    def eah(s, pt): ct = s.cs.enc(s.h, pt); s.mix_hash(ct); return ct
    def dah(s, ct): pt = s.cs.dec(s.h, ct); s.mix_hash(ct); return pt
    def split(s): a, b = hkdf2(s.ck, b""); return CS(a), CS(b)
PATTERNS = {"XX": [["e"], ["e", "ee", "s", "es"], ["s", "se"]], "X": [["e", "es", "s", "ss"]]}
class HS:
    def __init__(s, pat, initiator, prologue, s_sk, e_sk=None, rs=None):
        s.ss = SS(b"Noise_" + pat.encode() + b"_25519_ChaChaPoly_SHA256"); s.ss.mix_hash(prologue)
        s.init, s.s, s.spub = initiator, s_sk, x_pub(s_sk)
        s.e = e_sk; s.epub = x_pub(e_sk) if e_sk else None
        s.rs, s.re = rs, None
        if pat == "X": s.ss.mix_hash(rs if initiator else s.spub)
        s.msgs = [list(m) for m in PATTERNS[pat]]
    def _dh(s, t):
        a, b = {"ee": (s.e, s.re), "ss": (s.s, s.rs),
                "es": (s.e, s.rs) if s.init else (s.s, s.re),
                "se": (s.s, s.re) if s.init else (s.e, s.rs)}[t]
        return x_dh(a, b)
    def write(s, payload):
        out = b""
        for t in s.msgs.pop(0):
            if t == "e": out += s.epub; s.ss.mix_hash(s.epub)
            elif t == "s": out += s.ss.eah(s.spub)
            else: s.ss.mix_key(s._dh(t))
        out += s.ss.eah(payload)
        if len(out) > 65535: raise Bad("too long")
        return out
    def read(s, msg):
        if len(msg) > 65535: raise Bad("too long")
        pos = 0
        for t in s.msgs.pop(0):
            if t == "e":
                if len(msg) < pos + 32: raise Bad("short")
                s.re = msg[pos:pos + 32]; pos += 32; s.ss.mix_hash(s.re)
            elif t == "s":
                L = 48 if s.ss.cs.k else 32
                if len(msg) < pos + L: raise Bad("short")
                s.rs = s.ss.dah(msg[pos:pos + L]); pos += L
            else: s.ss.mix_key(s._dh(t))
        return s.ss.dah(msg[pos:])
    def split(s):
        c1, c2 = s.ss.split(); return (c1, c2) if s.init else (c2, c1)

def transcript(pat, prologue, si, ei, sr, er, payloads):
    """Every message of a session, in order: the handshake, then transport
    messages (XX: the alternation goes on, so message i comes from the
    initiator when i is even; X: initiator to responder).
    Returns (msgs, plaintexts read, hi, hr, rs seen by I, rs seen by R)."""
    if pat == "XX":
        I = HS("XX", True, prologue, si, ei); R = HS("XX", False, prologue, sr, er); nh = 3
    else:
        I = HS("X", True, prologue, si, ei, rs=x_pub(sr)); R = HS("X", False, prologue, sr); nh = 1
    msgs, pts = [], []
    for i, p in enumerate(payloads):
        if i < nh:
            snd, rcv = (I, R) if i % 2 == 0 else (R, I)
            m = snd.write(p); pts.append(rcv.read(m))
            if i == nh - 1:
                (itx, irx), (rtx, rrx) = I.split(), R.split()
        else:
            fromI = pat == "X" or i % 2 == 0
            m = (itx if fromI else rtx).enc(b"", p); pts.append((rrx if fromI else irx).dec(b"", m))
        msgs.append(m)
    return msgs, pts, I.ss.h, R.ss.h, I.rs, R.rs

def check_vectors(vectors):
    """the published cacophony vectors, before this implementation is trusted"""
    H = bytes.fromhex
    for name, pat in (("Noise_XX_25519_ChaChaPoly_SHA256", "XX"), ("Noise_X_25519_ChaChaPoly_SHA256", "X")):
        v = vectors[name]
        if pat == "X": assert x_pub(H(v["resp_static"])) == H(v["init_remote_static"])
        msgs, pts, hi, hr, _, _ = transcript(pat, H(v["init_prologue"]), H(v["init_static"]), H(v["init_ephemeral"]),
                                             H(v["resp_static"]), H(v.get("resp_ephemeral", "")) or None,
                                             [H(m[0]) for m in v["messages"]])
        assert len(msgs) == 6
        for m, p, w in zip(msgs, pts, v["messages"]):
            assert m.hex() == w[1], (name, m.hex(), w[1])
            assert p.hex() == w[0]
        assert hi.hex() == v["handshake_hash"] and hr.hex() == v["handshake_hash"], name

# The published test vectors (cacophony, the Haskell Noise implementation:
# vectors/cacophony.txt), Noise_XX and Noise_X with 25519, ChaChaPoly and
# SHA256; messages are [payload, ciphertext] in hex.
VECTORS = {
"Noise_XX_25519_ChaChaPoly_SHA256": {
"protocol_name": "Noise_XX_25519_ChaChaPoly_SHA256",
"init_prologue": "4a6f686e2047616c74",
"init_static": "e61ef9919cde45dd5f82166404bd08e38bceb5dfdfded0a34c8df7ed542214d1",
"init_ephemeral": "893e28b9dc6ca8d611ab664754b8ceb7bac5117349a4439a6b0569da977c464a",
"resp_prologue": "4a6f686e2047616c74",
"resp_static": "4a3acbfdb163dec651dfa3194dece676d437029c62a408b4c5ea9114246e4893",
"resp_ephemeral": "bbdb4cdbd309f1a1f2e1456967fe288cadd6f712d65dc7b7793d5e63da6b375b",
"handshake_hash": "c8e5f64e846193be2a834104c2a009868d6c9f3bd3c186299888b488b2f1f58e",
"messages": [
[
"4c756477696720766f6e204d69736573",
"ca35def5ae56cec33dc2036731ab14896bc4c75dbb07a61f879f8e3afa4c79444c756477696720766f6e204d69736573"
],
[
"4d757272617920526f746862617264",
"95ebc60d2b1fa672c1f46a8aa265ef51bfe38e7ccb39ec5be34069f14480884381cbad1f276e038c48378ffce2b65285e08d6b68aaa3629a5a8639392490e5b9bd5269c2f1e4f488ed8831161f19b7815528f8982ffe09be9b5c412f8a0db50f8814c7194e83f23dbd8d162c9326ad"
],
[
"462e20412e20486179656b",
"c7195ffacac1307ff99046f219750fc47693e23c3cb08b89c2af808b444850a80ae475b9df0f169ae80a89be0865b57f58c9fea0d4ec82a286427402f113e4b6ae769a1d95941d49b25030"
],
[
"4361726c204d656e676572",
"96763ed773f8e47bb3712f0e29b3060ffc956ffc146cee53d5e1df"
],
[
"4a65616e2d426170746973746520536179",
"3e40f15f6f3a46ae446b253bf8b1d9ffb6ed9b174d272328ff91a7e2e5c79c07f5"
],
[
"457567656e2042f6686d20766f6e2042617765726b",
"eb3f3515110702e047a6c9da4478b6ead94873c11c0f2d710ddb3f09fce024b3a58502ae3f"
]
]
},
"Noise_X_25519_ChaChaPoly_SHA256": {
"protocol_name": "Noise_X_25519_ChaChaPoly_SHA256",
"init_prologue": "4a6f686e2047616c74",
"init_static": "e61ef9919cde45dd5f82166404bd08e38bceb5dfdfded0a34c8df7ed542214d1",
"init_ephemeral": "893e28b9dc6ca8d611ab664754b8ceb7bac5117349a4439a6b0569da977c464a",
"init_remote_static": "31e0303fd6418d2f8c0e78b91f22e8caed0fbe48656dcf4767e4834f701b8f62",
"resp_prologue": "4a6f686e2047616c74",
"resp_static": "4a3acbfdb163dec651dfa3194dece676d437029c62a408b4c5ea9114246e4893",
"handshake_hash": "e6adfaa886b76b16b2aa79c54434c77fed488c8aa66d2c545608f4352f70f664",
"messages": [
[
"4c756477696720766f6e204d69736573",
"ca35def5ae56cec33dc2036731ab14896bc4c75dbb07a61f879f8e3afa4c79446c15957a594079a5bdeae05d01e089fbb7cc6ea2ecfd209b941f73c9235213bc875f7283e9e17ebdac8112627915b455fdc3aaa6de60cb3c98302f370fdb03ea850b9b0cf22fec13e4dc0707245c8721"
],
[
"4d757272617920526f746862617264",
"9868def631af6242aaf00c35218275832d8d022af1c67b9fc5e8ba90f4d91b"
],
[
"462e20412e20486179656b",
"9fdd2576d757f880de49b32b80abf53afec16ddc86769f0e92daff"
],
[
"4361726c204d656e676572",
"0e5a48d10dfd648145b78012bc9edc8440cbb6e9e237eb8d5b9c25"
],
[
"4a65616e2d426170746973746520536179",
"11a3818b2523d06a64168b814ff680e60930e7145378cd813055f00e1725b5f9e8"
],
[
"457567656e2042f6686d20766f6e2042617765726b",
"184a48a82f921ee36371d880e2abd177f8967349e992958c66fa51bff262a37845a200d26a"
]
]
}
}
PYEOF

cat > "$T/oracle.py" <<'PYEOF'
import os, sys, random, struct
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
def frame(p): return struct.pack(">I", len(p)) + p
mode = sys.argv[1]
if mode == "cmp":
    # cmp EXP OUT: per "== name" section, ok or the first line that differs
    def secs(f):
        d, cur = {}, None
        for ln in open(f, encoding="utf-8", errors="replace").read().split("\n"):
            if ln.startswith("== "): cur = ln[3:]; d[cur] = []
            elif cur is not None and ln: d[cur].append(ln)
        return d
    e, o = secs(sys.argv[2]), secs(sys.argv[3])
    for name in e:
        g = o.get(name)
        if g == e[name]: print(name, "ok", len(e[name])); continue
        if g is None: print(name, "missing"); continue
        i = next((i for i in range(max(len(g), len(e[name]))) if i >= len(g) or i >= len(e[name]) or g[i] != e[name][i]), 0)
        print(name, "differ at line %d: expected %r got %r" % (i + 1, (e[name] + [""])[min(i, len(e[name]))][:90], (g + [""])[min(i, len(g))][:90]))
if mode == "noise":
    # Two vector sets for the LA, every expected line computed by noiseref:
    # cc_ = the cacophony vectors (prologue "John Galt"); ln_ = random static
    # and ephemeral keys and payloads, prologue "LogosNet/1".
    import noiseref as N
    N.check_vectors(N.VECTORS)
    open("oracle.txt", "w").write(N.ORACLE)
    R = random.Random(int(sys.argv[2])); H = bytes.fromhex
    rb = lambda n: bytes(R.getrandbits(8) for _ in range(n))
    v = N.VECTORS["Noise_XX_25519_ChaChaPoly_SHA256"]; w = N.VECTORS["Noise_X_25519_ChaChaPoly_SHA256"]
    cc = dict(pro=H(v["init_prologue"]), si=H(v["init_static"]), ei=H(v["init_ephemeral"]),
              sr=H(v["resp_static"]), er=H(v["resp_ephemeral"]), p=[H(m[0]) for m in v["messages"]],
              xsi=H(w["init_static"]), xei=H(w["init_ephemeral"]), xsr=H(w["resp_static"]),
              xp=[H(m[0]) for m in w["messages"]])
    ln = dict(pro=b"LogosNet/1", si=rb(32), ei=rb(32), sr=rb(32), er=rb(32),
              p=[rb(n) for n in (0, 5, 64, 0, 1000, 3)],
              xsi=rb(32), xei=rb(32), xsr=rb(32), xp=[rb(n) for n in (0, 17, 0, 300, 5, 1)])
    T = {}
    for name, S in (("cc", cc), ("ln", ln)):
        pre = name + "_"
        def W(f, b): open(pre + f, "wb").write(b)
        W("pro.bin", S["pro"])
        for k in ("si", "ei", "sr", "er", "xsi", "xei", "xsr"): W(k + ".bin", S[k])
        W("xrs.bin", N.x_pub(S["xsr"]))
        for i, q in enumerate(S["p"]): W("p%d.bin" % i, q)
        for i, q in enumerate(S["xp"]): W("xp%d.bin" % i, q)
        ms, pts, hi, hr, rsi, rsr = N.transcript("XX", S["pro"], S["si"], S["ei"], S["sr"], S["er"], S["p"])
        xm, xpts, xhi, xhr, xrsi, xrsr = N.transcript("X", S["pro"], S["xsi"], S["xei"], S["xsr"], None, S["xp"])
        for i, m in enumerate(ms): W("m%d.bin" % i, m)
        for i, m in enumerate(xm): W("xm%d.bin" % i, m)
        T[name] = (S, ms, xm)
        L = lambda t, b: "%s %s" % (t, b.hex())
        out = ["== xx", L("m0", ms[0]), L("pt0", pts[0]), L("m1", ms[1]), L("pt1", pts[1]), L("m2", ms[2]), L("pt2", pts[2]),
               L("hi", hi), L("rsi", rsi), L("hr", hr), L("rsr", rsr), L("m3", ms[3]), L("pt3", pts[3]),
               L("m4", ms[4]), L("pt4", pts[4]), L("m5", ms[5]), L("pt5", pts[5]), "end"]
        out += ["== xxi", L("m0", ms[0]), L("pt1", pts[1]), L("m2", ms[2]), L("hi", hi), L("rsi", rsi),
                L("pt3", pts[3]), L("m4", ms[4]), L("pt5", pts[5]), "end"]
        out += ["== xxr", L("pt0", pts[0]), L("m1", ms[1]), L("pt2", pts[2]), L("hr", hr), L("rsr", rsr),
                L("m3", ms[3]), L("pt4", pts[4]), L("m5", ms[5]), "end"]
        out += ["== x", L("m0", xm[0]), L("pt0", xpts[0]), L("hi", xhi), L("rsi", xrsi), L("hr", xhr), L("rsr", xrsr)]
        for i in range(1, 6): out += [L("m%d" % i, xm[i]), L("pt%d" % i, xpts[i])]
        out += ["end", "== xi", L("m0", xm[0]), L("hi", xhi), L("rsi", xrsi)] + [L("m%d" % i, xm[i]) for i in range(1, 6)] + ["end"]
        out += ["== xr", L("pt0", xpts[0]), L("hr", xhr), L("rsr", xrsr)] + [L("pt%d" % i, xpts[i]) for i in range(1, 6)] + ["end"]
        open(pre + "noise.exp", "w").write("\n".join(out) + "\n")
    # tamper (ln_): what the oracle itself says of each flipped message
    S, ms, xm = T["ln"]
    flip = lambda b, i: b[:i] + bytes([b[i] ^ 1]) + b[i + 1:]
    def attempt(f):
        try: f(); return "some"
        except (N.Bad, ValueError): return "none"
    def I1():
        I = N.HS("XX", True, S["pro"], S["si"], S["ei"]); I.write(S["p"][0]); return I
    def R2():
        Rr = N.HS("XX", False, S["pro"], S["sr"], S["er"]); Rr.read(ms[0]); Rr.write(S["p"][1]); return Rr
    def Irx():
        I = I1(); I.read(ms[1]); I.write(S["p"][2]); return I.split()[1]
    XR = lambda: N.HS("X", False, S["pro"], S["xsr"])
    out = []
    for nm, pos in (("0", 0), ("40", 40), ("last", len(ms[1]) - 1)):
        out.append("tm1-%s %s" % (nm, attempt(lambda pos=pos: I1().read(flip(ms[1], pos)))))
    for nm, pos in (("0", 0), ("last", len(ms[2]) - 1)):
        out.append("tm2-%s %s" % (nm, attempt(lambda pos=pos: R2().read(flip(ms[2], pos)))))
    Rx = N.HS("XX", False, S["pro"], S["sr"], S["er"])
    out.append("tm0-r " + attempt(lambda: Rx.read(flip(ms[0], 0))))
    m1x = Rx.write(S["p"][1])
    out.append("tm0-i " + attempt(lambda: I1().read(m1x)))
    out.append("tm3-0 " + attempt(lambda: Irx().dec(b"", flip(ms[3], 0))))
    out.append("tm3-last " + attempt(lambda: Irx().dec(b"", flip(ms[3], len(ms[3]) - 1))))
    rx = Irx()
    out.append("tm3-ok " + attempt(lambda: rx.dec(b"", ms[3])))
    out.append("tm3-replay " + attempt(lambda: rx.dec(b"", ms[3])))
    for nm, pos in (("0", 0), ("40", 40), ("last", len(xm[0]) - 1)):
        out.append("tx0-%s %s" % (nm, attempt(lambda pos=pos: XR().read(flip(xm[0], pos)))))
    Xr = XR(); Xr.read(xm[0])
    out.append("tx1-0 " + attempt(lambda: Xr.split()[1].dec(b"", flip(xm[1], 0))))
    open("tamper.exp", "w").write("\n".join(out + ["end"]) + "\n")
    # small-order points (RFC 7748 6.1): 0, 1, a point of order 8, p - 1
    lows = ["00" * 32, "01" + "00" * 31,
            "e0eb7a7c3b41b8ae1656e3faf19fc46ada098deb9c32b1fd866205165f49b800", "ec" + "ff" * 30 + "7f"]
    for u in lows: assert N.t_x25519(S["si"], H(u)) == bytes(32)
    open("ln_low.bin", "wb").write(b"".join(H(u) for u in lows))
    out = []
    for k in range(4): out += ["xinit-%d none" % k, "xxr-%d none" % k, "xxi-%d none" % k]
    open("low.exp", "w").write("\n".join(out + ["xinit-valid some", "done0 none", "done1 none", "end"]) + "\n")
    open("limits.exp", "w").write("w 65535\nr some\nr65536 none\ne 65535\nd some\nd65536 none\nend\n")
if mode == "frames":
    # stream.bin: frames of many small payloads and some large ones;
    # sched.txt: the chunk sizes the LA cuts the stream into
    R = random.Random(int(sys.argv[2]))
    ps = [b"", b"\x00", b"ab", b"abc", b"abcd", b"\x00\x00\x00\x05\xff"]
    ps += [os.urandom(R.randint(0, 300)) for _ in range(150)]
    ps += [os.urandom(70000), b"", os.urandom(1 << 20), os.urandom(65535), b"z"]
    stream = b"".join(frame(p) for p in ps)
    cuts, pos = [], 0
    while pos < len(stream):
        r = R.random()
        if pos < 40000: n = R.randint(1, 37)            # small chunks: cuts inside headers
        elif r < 0.3: n = R.randint(1, 5)
        else: n = R.randint(1000, 300000)
        n = min(n, len(stream) - pos); cuts.append(n); pos += n
    open("stream.bin", "wb").write(stream)
    open("sched.txt", "w").write(" ".join(map(str, cuts)))
    print("frames %d tail 0" % len(ps))
    print("lens " + " ".join(str(len(p)) for p in ps))
    print("chunks %d" % len(cuts))
if mode == "framescheck":
    # the LA's re-framing of what it deframed must be the stream itself
    print("same" if open("out.bin", "rb").read() == open("stream.bin", "rb").read() else "differ")
if mode == "broken":
    big = 1048577
    open("brk1.bin", "wb").write(struct.pack(">I", big) + b"xyz")
    open("brk2.bin", "wb").write(frame(b"hello") + struct.pack(">I", 0xffffffff) + b"q")
    open("brk3.bin", "wb").write(struct.pack(">I", 1 << 20) + b"partial")
    open("brk4.bin", "wb").write(frame(b"x") + b"\x00\x10")
    # an oversize frame complete in the buffer: deframe must not release it
    open("brk5.bin", "wb").write(struct.pack(">I", big) + b"o" * big + frame(b"after"))
    print("brk1 0 broken T tail 7\nbrk2 1 broken T tail 5\nbrk3 0 broken F tail 11\nbrk4 1 broken F tail 2\n"
          "brk5 0 broken T tail %d" % (4 + big + 4 + 5))
PYEOF

# ── the LA test program: one compiled program, dispatching on mode.txt ──
cat > "$T/t.la" <<'LAEOF'
import("logosnet.la")
import("logoscrypt.la")
import("x25519.la")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph LET = la v. la k. k(v)
glyph SEQ = la a. la b. b
glyph NIL = la n. la c. n(n)
glyph CONS = la h. la t. la n. la c. c(h)(t)
glyph PR = la a. la b. la k. k(a)(b)
glyph BOOL = la b. b("T")("F")
glyph SP = la a. la b. concat(a)(concat(" ")(b))
# The test program's own helpers are a kit too: naming a builtin in a loop
# walks the whole program (the crypto modules included), so they are built
# once, with the builtins as parameters.
#   TK -> la s. s(len)(sub)(words)(join)(map)(rev)(app)(count)(rep)(showl)(feed)
glyph TK = (la str_at. la str_to_int. la int_to_str. la concat. la str_eq. la str_len.
            la add. la sub. la div. la lt. la int_eq. la C0. la C1. la C2. la nil. la cons.
    LET(la s. str_to_int(str_len(s)))(la len.
    LET(Z(la sp. la f. la lo. la hi.
        lt(add(lo)(C1))(hi)
          (la _. (la mid. concat(sp(f)(lo)(mid))(sp(f)(mid)(hi)))(div(add(lo)(hi))(C2)))
          (la _. lt(lo)(hi)(la _. f(lo))(la _. "")(C0))(C0)))(la span.
    LET(la s. la a. la b. span(str_at(s))(a)(b))(la ssub.
    LET(Z(la go. la acc. la l. l(la _. acc)(la h. la t. go(cons(h)(acc))(t)))(nil))(la rev.
    LET(Z(la go. la a. la b. a(la _. b)(la h. la t. cons(h)(go(t)(b)))))(la app.
    LET(Z(la go. la l. l(la _. C0)(la h. la t. add(C1)(go(t)))))(la count.
    LET(Z(la go. la f. la l. l(la _. nil)(la h. la t. cons(f(h))(go(f)(t)))))(la map.
    # words(s): the space-separated words of s
    LET(la s. (la n. Z(la go. la i. la st. la acc.
        lt(i)(n)
          (la _. str_eq(str_at(s)(i))(" ")
                   (la _. go(add(i)(C1))(add(i)(C1))(lt(st)(i)(la _. cons(ssub(s)(st)(i))(acc))(la _. acc)(C0)))
                   (la _. go(add(i)(C1))(st)(acc))(C0))
          (la _. rev(lt(st)(i)(la _. cons(ssub(s)(st)(i))(acc))(la _. acc)(C0)))(C0))(C0)(C0)(nil))(len(s)))(la words.
    # join(l): balanced concatenation of a list
    LET(Z(la go. la n. la l. la k. int_eq(n)(C0)(la _. k(nil)(l))
        (la _. l(la _. k(nil)(nil))(la h. la t. go(sub(n)(C1))(t)(la a. la b. k(cons(h)(a))(b))))(C0)))(la half.
    LET(Z(la go. la l. (la n. lt(n)(C2)
        (la _. l(la _. "")(la h. la t. h))
        (la _. half(div(n)(C2))(l)(la a. la b. concat(go(a))(go(b))))(C0))(count(l))))(la join.
    # rep(n)(s): n copies of s, by doubling
    LET(Z(la go. la n. la s. lt(n)(C1)(la _. "")
        (la _. (la h. (la hh. int_eq(sub(n)(add(div(n)(C2))(div(n)(C2))))(C1)(la _. concat(hh)(s))(la _. hh)(C0))
                      (concat(h)(h)))(go(div(n)(C2))(s)))(C0)))(la rep.
    LET(la l. join(map(la x. concat(" ")(x))(l)))(la showl.
    # feed(deframe)(s)(sizes): cut s by the sizes, deframe each chunk in turn;
    # la k. k(payloads)(buf)
    LET(la deframe. la s. Z(la go. la pos. la sizes. la buf. la acc.
        sizes(la _. la k. k(rev(acc))(buf))
             (la h. la t. (la e. deframe(buf)(ssub(s)(pos)(e))(la ps. la b2.
                             go(e)(t)(b2)(app(rev(ps))(acc))))
                          (add(pos)(str_to_int(h)))))(C0))(la feed.
      la s. s(len)(ssub)(words)(join)(map)(rev)(app)(count)(rep)(showl)(feed)))))))))))))))
  (str_at)(str_to_int)(int_to_str)(concat)(str_eq)(str_len)(add)(sub)(div)(lt)(int_eq)(0)(1)(2)(NIL)(CONS)
glyph B = la s. s(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(str_eq)(error)
                 (add)(sub)(mul)(div)(mod)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr)
glyph X = la s. s(socket)(bind)(listen)(accept)(connect)(send)(recv)(close)(unlink)(poll)
                 (random)(clock_gettime)(print)(read_file)(write_file)(chmod)(stat)(mkdir)
                 (rmdir)(rename)(sigprocmask)
glyph CRYPT = CRYPT_FAST(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(error)
    (add)(sub)(mul)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr)
glyph XK = X25519_KIT(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(error)
    (add)(sub)(mul)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr)
# DISPATCH(mode)(table): run the thunk named mode
glyph DISPATCH = Z(la go. la mode. la l. l(la _. print(concat("unknown mode ")(mode)))
    (la h. la t. h(la name. la f. str_eq(name)(mode)(la _. f("!"))(la _. go(mode)(t))("!"))))
# NETV(net)(f): the record NET_KIT returns, as the fields these tests use
glyph NETV = la net. la f. net(la frame. la deframe. la broken. la keypair. la xx_init. la xx_resp. la x_init. la x_resp.
    la write_message. la read_message. la done. la encrypt. la decrypt. la prologue.
  f(frame)(deframe)(broken)(keypair)(xx_init)(xx_resp)(x_init)(x_resp)(write_message)(read_message)(done)(encrypt)(decrypt)(prologue))
glyph FRAMES = la tk. la net. tk(la len. la ssub. la words. la join. la map. la rev. la app. la count. la rep. la showl. la feed.
  NETV(net)(la frame. la deframe. la broken. la keypair. la xx_init. la xx_resp. la x_init. la x_resp.
    la write_message. la read_message. la done. la encrypt. la decrypt. la prologue.
    (la s. la sched. feed(deframe)(s)(sched)("")(NIL)(la ps. la buf.
       SEQ(write_file("out.bin")(join(map(frame)(ps))))(
       SEQ(print(SP("frames")(SP(int_to_str(count(ps)))(SP("tail")(int_to_str(len(buf)))))))(
       SEQ(print(concat("lens")(showl(map(la p. int_to_str(len(p)))(ps)))))(
       print(SP("chunks")(int_to_str(count(sched)))))))))
    (read_file("stream.bin"))(words(read_file("sched.txt")))))
glyph BROKEN1 = la tk. la net. la name. tk(la len. la ssub. la words. la join. la map. la rev. la app. la count. la rep. la showl. la feed.
  NETV(net)(la frame. la deframe. la broken. la keypair. la xx_init. la xx_resp. la x_init. la x_resp.
    la write_message. la read_message. la done. la encrypt. la decrypt. la prologue.
    deframe("")(read_file(concat(name)(".bin")))(la ps. la buf.
      print(SP(name)(SP(int_to_str(count(ps)))(SP("broken")(SP(BOOL(broken(buf)))(SP("tail")(int_to_str(len(buf)))))))))))
glyph FRAMEBIG = la tk. la net. tk(la len. la ssub. la words. la join. la map. la rev. la app. la count. la rep. la showl. la feed.
  NETV(net)(la frame. la deframe. la broken. la keypair. la xx_init. la xx_resp. la x_init. la x_resp.
    la write_message. la read_message. la done. la encrypt. la decrypt. la prologue.
    SEQ(frame(rep(1048577)("x")))(print("frame_big: no halt"))))
glyph BROKEN = la tk. la net. SEQ(BROKEN1(tk)(net)("brk1"))(SEQ(BROKEN1(tk)(net)("brk2"))(SEQ(BROKEN1(tk)(net)("brk3"))(SEQ(BROKEN1(tk)(net)("brk4"))(BROKEN1(tk)(net)("brk5")))))
# ── Noise tests ──
# RF(name): the file prefix.txt ++ name (the vector set: cc_ or ln_)
glyph RF = la name. read_file(concat(read_file("prefix.txt"))(name))
glyph LINE = la crypt. la tag. la s. crypt(la sha256. la hmac. la hkdf. la seal. la open. la hex. print(concat(tag)(concat(" ")(hex(s)))))
glyph OPTS = la o. o(la _. "none")(la x. "some")
glyph SAY = la tag. la o. print(concat(tag)(concat(" ")(OPTS(o))))
# continuation helpers: each prints one line and passes on what it made
glyph WR = la crypt. la wm. la tag. la hs. la p. la k. wm(hs)(p)(la m. la hs2. SEQ(LINE(crypt)(tag)(m))(k(m)(hs2)))
glyph RD = la crypt. la rm. la tag. la hs. la m. la k. rm(hs)(m)(la _. print(concat(tag)(" none")))(la r. r(la pt. la hs2. SEQ(LINE(crypt)(tag)(pt))(k(hs2))))
glyph EN = la crypt. la en. la tag. la cs. la p. la k. en(cs)(p)(la m. la cs2. SEQ(LINE(crypt)(tag)(m))(k(m)(cs2)))
glyph DE = la crypt. la de. la tag. la cs. la m. la k. de(cs)(m)(la _. print(concat(tag)(" none")))(la r. r(la pt. la cs2. SEQ(LINE(crypt)(tag)(pt))(k(cs2))))
glyph DN = la crypt. la dn. la tag. la hs. la k. dn(hs)(la _. print(concat(tag)(" not done")))(la d. d(la tx. la rx. la rs. la h.
    SEQ(LINE(crypt)(concat("h")(tag))(h))(SEQ(LINE(crypt)(concat("rs")(tag))(rs))(k(tx)(rx)))))
# NT(crypt)(net)(f): f(wr)(rd)(en)(de)(dn)(xx_i)(xx_r)(x_i)(x_r)(keypair) for the set's prologue
glyph NT = la crypt. la net. la f. NETV(net)(la frame. la deframe. la broken. la keypair. la xx_init. la xx_resp. la x_init. la x_resp.
    la write_message. la read_message. la done. la encrypt. la decrypt. la prologue.
  prologue(RF("pro.bin"))(la xi. la xr. la yi. la yr.
    f(WR(crypt)(write_message))(RD(crypt)(read_message))(EN(crypt)(encrypt))(DE(crypt)(decrypt))(DN(crypt)(done))
     (la a. la b. xi(keypair(RF(a)))(keypair(RF(b))))
     (la a. la b. xr(keypair(RF(a)))(keypair(RF(b))))
     (la a. la b. la r. yi(keypair(RF(a)))(keypair(RF(b)))(RF(r)))
     (la a. yr(keypair(RF(a))))
     (keypair)))
# XX, both sides LA
glyph TXX = la crypt. la net. NT(crypt)(net)(la wr. la rd. la en. la de. la dn. la xi. la xr. la yi. la yr. la kp.
  wr("m0")(xi("si.bin")("ei.bin"))(RF("p0.bin"))(la m0. la I1.
  rd("pt0")(xr("sr.bin")("er.bin"))(m0)(la R1.
  wr("m1")(R1)(RF("p1.bin"))(la m1. la R2.
  rd("pt1")(I1)(m1)(la I2.
  wr("m2")(I2)(RF("p2.bin"))(la m2. la I3.
  rd("pt2")(R2)(m2)(la R3.
  dn("i")(I3)(la itx. la irx.
  dn("r")(R3)(la rtx. la rrx.
  en("m3")(rtx)(RF("p3.bin"))(la m3. la rtx2.
  de("pt3")(irx)(m3)(la irx2.
  en("m4")(itx)(RF("p4.bin"))(la m4. la itx2.
  de("pt4")(rrx)(m4)(la rrx2.
  en("m5")(rtx2)(RF("p5.bin"))(la m5. la rtx3.
  de("pt5")(irx2)(m5)(la irx3. print("end"))))))))))))))))
# XX, the LA initiator against the oracle's responder messages
glyph TXXI = la crypt. la net. NT(crypt)(net)(la wr. la rd. la en. la de. la dn. la xi. la xr. la yi. la yr. la kp.
  wr("m0")(xi("si.bin")("ei.bin"))(RF("p0.bin"))(la m0. la I1.
  rd("pt1")(I1)(RF("m1.bin"))(la I2.
  wr("m2")(I2)(RF("p2.bin"))(la m2. la I3.
  dn("i")(I3)(la itx. la irx.
  de("pt3")(irx)(RF("m3.bin"))(la irx2.
  en("m4")(itx)(RF("p4.bin"))(la m4. la itx2.
  de("pt5")(irx2)(RF("m5.bin"))(la irx3. print("end")))))))))
# XX, the LA responder against the oracle's initiator messages
glyph TXXR = la crypt. la net. NT(crypt)(net)(la wr. la rd. la en. la de. la dn. la xi. la xr. la yi. la yr. la kp.
  rd("pt0")(xr("sr.bin")("er.bin"))(RF("m0.bin"))(la R1.
  wr("m1")(R1)(RF("p1.bin"))(la m1. la R2.
  rd("pt2")(R2)(RF("m2.bin"))(la R3.
  dn("r")(R3)(la rtx. la rrx.
  en("m3")(rtx)(RF("p3.bin"))(la m3. la rtx2.
  de("pt4")(rrx)(RF("m4.bin"))(la rrx2.
  en("m5")(rtx2)(RF("p5.bin"))(la m5. la rtx3. print("end")))))))))
# X, both sides LA (one-way: every transport message from the initiator)
glyph TX = la crypt. la net. NT(crypt)(net)(la wr. la rd. la en. la de. la dn. la xi. la xr. la yi. la yr. la kp.
  yi("xsi.bin")("xei.bin")("xrs.bin")(la _. print("x_init none"))(la I0.
  wr("m0")(I0)(RF("xp0.bin"))(la m0. la I1.
  rd("pt0")(yr("xsr.bin"))(m0)(la R1.
  dn("i")(I1)(la itx. la irx.
  dn("r")(R1)(la rtx. la rrx.
  en("m1")(itx)(RF("xp1.bin"))(la m1. la itx2.
  de("pt1")(rrx)(m1)(la rrx2.
  en("m2")(itx2)(RF("xp2.bin"))(la m2. la itx3.
  de("pt2")(rrx2)(m2)(la rrx3.
  en("m3")(itx3)(RF("xp3.bin"))(la m3. la itx4.
  de("pt3")(rrx3)(m3)(la rrx4.
  en("m4")(itx4)(RF("xp4.bin"))(la m4. la itx5.
  de("pt4")(rrx4)(m4)(la rrx5.
  en("m5")(itx5)(RF("xp5.bin"))(la m5. la itx6.
  de("pt5")(rrx5)(m5)(la rrx6. print("end")))))))))))))))))
# X, the LA initiator (its messages) and the LA responder (the oracle's)
glyph TXI = la crypt. la net. NT(crypt)(net)(la wr. la rd. la en. la de. la dn. la xi. la xr. la yi. la yr. la kp.
  yi("xsi.bin")("xei.bin")("xrs.bin")(la _. print("x_init none"))(la I0.
  wr("m0")(I0)(RF("xp0.bin"))(la m0. la I1.
  dn("i")(I1)(la itx. la irx.
  en("m1")(itx)(RF("xp1.bin"))(la m1. la itx2.
  en("m2")(itx2)(RF("xp2.bin"))(la m2. la itx3.
  en("m3")(itx3)(RF("xp3.bin"))(la m3. la itx4.
  en("m4")(itx4)(RF("xp4.bin"))(la m4. la itx5.
  en("m5")(itx5)(RF("xp5.bin"))(la m5. la itx6. print("end"))))))))))
glyph TXR = la crypt. la net. NT(crypt)(net)(la wr. la rd. la en. la de. la dn. la xi. la xr. la yi. la yr. la kp.
  rd("pt0")(yr("xsr.bin"))(RF("xm0.bin"))(la R1.
  dn("r")(R1)(la rtx. la rrx.
  de("pt1")(rrx)(RF("xm1.bin"))(la rrx2.
  de("pt2")(rrx2)(RF("xm2.bin"))(la rrx3.
  de("pt3")(rrx3)(RF("xm3.bin"))(la rrx4.
  de("pt4")(rrx4)(RF("xm4.bin"))(la rrx5.
  de("pt5")(rrx5)(RF("xm5.bin"))(la rrx6. print("end")))))))))
glyph NOISE = la crypt. la net.
  SEQ(print("== xx"))(SEQ(TXX(crypt)(net))(SEQ(print("== xxi"))(SEQ(TXXI(crypt)(net))(SEQ(print("== xxr"))(SEQ(TXXR(crypt)(net))(
  SEQ(print("== x"))(SEQ(TX(crypt)(net))(SEQ(print("== xi"))(SEQ(TXI(crypt)(net))(SEQ(print("== xr"))(TXR(crypt)(net))))))))))))
# TAMPER: flipped bytes anywhere are refused, and a replayed transport message
glyph FLIP = la tk. la s. la i. tk(la len. la ssub. la words. la join. la map. la rev. la app. la count. la rep. la showl. la feed.
    concat(ssub(s)(0)(i))(concat(chr(int_to_str(bxor(str_to_int(ord(str_at(s)(i))))(1))))(ssub(s)(add(i)(1))(len(s)))))
glyph LAST = la s. sub(str_to_int(str_len(s)))(1)
glyph TAMPER = la tk. la crypt. la net. NETV(net)(la frame. la deframe. la broken. la keypair. la xx_init. la xx_resp. la x_init. la x_resp.
    la write_message. la read_message. la done. la encrypt. la decrypt. la prologue.
  (la F. la I0. la R0. la M0. la M1. la M2. la M3. la XM0. la XM1. la XR.
    write_message(I0)(RF("p0.bin"))(la m0. la I1.
    SEQ(SAY("tm1-0")(read_message(I1)(F(M1)(0))))(
    SEQ(SAY("tm1-40")(read_message(I1)(F(M1)(40))))(
    SEQ(SAY("tm1-last")(read_message(I1)(F(M1)(LAST(M1)))))(
    read_message(R0)(M0)(la _. print("R0 none"))(la r. r(la pt0. la R1.
    write_message(R1)(RF("p1.bin"))(la m1. la R2.
    SEQ(SAY("tm2-0")(read_message(R2)(F(M2)(0))))(
    SEQ(SAY("tm2-last")(read_message(R2)(F(M2)(LAST(M2)))))(
    read_message(R0)(F(M0)(0))(la _. print("tm0-r none"))(la r. r(la ptx. la R1x.
    SEQ(print("tm0-r some"))(
    write_message(R1x)(RF("p1.bin"))(la m1x. la R2x.
    SEQ(SAY("tm0-i")(read_message(I1)(m1x)))(
    read_message(I1)(M1)(la _. print("I1 none"))(la r. r(la pt1. la I2.
    write_message(I2)(RF("p2.bin"))(la m2. la I3.
    done(I3)(la _. print("I3 not done"))(la d. d(la itx. la irx. la irs. la ih.
    SEQ(SAY("tm3-0")(decrypt(irx)(F(M3)(0))))(
    SEQ(SAY("tm3-last")(decrypt(irx)(F(M3)(LAST(M3)))))(
    decrypt(irx)(M3)(la _. print("tm3-ok none"))(la r. r(la pt3. la irx2.
    SEQ(print("tm3-ok some"))(
    SEQ(SAY("tm3-replay")(decrypt(irx2)(M3)))(
    SEQ(SAY("tx0-0")(read_message(XR)(F(XM0)(0))))(
    SEQ(SAY("tx0-40")(read_message(XR)(F(XM0)(40))))(
    SEQ(SAY("tx0-last")(read_message(XR)(F(XM0)(LAST(XM0)))))(
    read_message(XR)(XM0)(la _. print("XR none"))(la r. r(la xpt0. la XR1.
    done(XR1)(la _. print("XR1 not done"))(la d. d(la xtx. la xrx. la xrs. la xh.
    SEQ(SAY("tx1-0")(decrypt(xrx)(F(XM1)(0))))(
    print("end")))))))))))))))))))))))))))))))))))
  (FLIP(tk))
  (xx_init(keypair(RF("si.bin")))(keypair(RF("ei.bin"))))
  (xx_resp(keypair(RF("sr.bin")))(keypair(RF("er.bin"))))
  (RF("m0.bin"))(RF("m1.bin"))(RF("m2.bin"))(RF("m3.bin"))(RF("xm0.bin"))(RF("xm1.bin"))
  (x_resp(keypair(RF("xsr.bin")))))
# LIMITS: the 65535-byte message limit, both ways
glyph LIMITS = la tk. la crypt. la net. tk(la len. la ssub. la words. la join. la map. la rev. la app. la count. la rep. la showl. la feed.
  NETV(net)(la frame. la deframe. la broken. la keypair. la xx_init. la xx_resp. la x_init. la x_resp.
    la write_message. la read_message. la done. la encrypt. la decrypt. la prologue.
  (la I0. la R0.
    write_message(I0)(rep(65503)("a"))(la mbig. la Ib.
    SEQ(print(concat("w ")(int_to_str(len(mbig)))))(
    SEQ(SAY("r")(read_message(R0)(mbig)))(
    SEQ(SAY("r65536")(read_message(R0)(concat(mbig)("a"))))(
    write_message(I0)(RF("p0.bin"))(la m0. la I1.
    read_message(R0)(m0)(la _. print("R0 none"))(la r. r(la pt0. la R1.
    write_message(R1)(RF("p1.bin"))(la m1. la R2.
    read_message(I1)(m1)(la _. print("I1 none"))(la r. r(la pt1. la I2.
    write_message(I2)(RF("p2.bin"))(la m2. la I3.
    read_message(R2)(m2)(la _. print("R2 none"))(la r. r(la pt2. la R3.
    done(I3)(la _. print("I3 not done"))(la d. d(la itx. la irx. la irs. la ih.
    done(R3)(la _. print("R3 not done"))(la d. d(la rtx. la rrx. la rrs. la rh.
    encrypt(itx)(rep(65519)("b"))(la cbig. la itx2.
    SEQ(print(concat("e ")(int_to_str(len(cbig)))))(
    SEQ(SAY("d")(decrypt(rrx)(cbig)))(
    SEQ(SAY("d65536")(decrypt(rrx)(concat(cbig)("b"))))(
    print("end")))))))))))))))))))))))
  (xx_init(keypair(RF("si.bin")))(keypair(RF("ei.bin"))))
  (xx_resp(keypair(RF("sr.bin")))(keypair(RF("er.bin"))))))
glyph LIMW = la tk. la net. tk(la len. la ssub. la words. la join. la map. la rev. la app. la count. la rep. la showl. la feed.
  NETV(net)(la frame. la deframe. la broken. la keypair. la xx_init. la xx_resp. la x_init. la x_resp.
    la write_message. la read_message. la done. la encrypt. la decrypt. la prologue.
    write_message(xx_init(keypair(RF("si.bin")))(keypair(RF("ei.bin"))))(rep(65504)("a"))(la m. la h. print("limw: no halt"))))
glyph LIME = la tk. la net. tk(la len. la ssub. la words. la join. la map. la rev. la app. la count. la rep. la showl. la feed.
  NETV(net)(la frame. la deframe. la broken. la keypair. la xx_init. la xx_resp. la x_init. la x_resp.
    la write_message. la read_message. la done. la encrypt. la decrypt. la prologue.
    encrypt(la k. k(RF("si.bin"))(0))(rep(65520)("a"))(la c. la cs. print("lime: no halt"))))
# LOW: an all-zero DH ends the handshake; and done/turn before the end
glyph LOW = la tk. la crypt. la net. tk(la len. la ssub. la words. la join. la map. la rev. la app. la count. la rep. la showl. la feed.
  NETV(net)(la frame. la deframe. la broken. la keypair. la xx_init. la xx_resp. la x_init. la x_resp.
    la write_message. la read_message. la done. la encrypt. la decrypt. la prologue.
  (la low. la SK. la EK. la RSK. la REK.
    write_message(xx_init(SK)(EK))(RF("p0.bin"))(la m0. la I1.
    (la one. SEQ(one("0"))(SEQ(one("1"))(SEQ(one("2"))(SEQ(one("3"))(
      SEQ(SAY("xinit-valid")(x_init(SK)(EK)(RF("xrs.bin"))))(
      SEQ(SAY("done0")(done(xx_init(SK)(EK))))(
      SEQ(SAY("done1")(done(I1)))(
      print("end")))))))))
    (la k. (la u.
       SEQ(SAY(concat("xinit-")(k))(x_init(SK)(EK)(u)))(
       SEQ(SAY(concat("xxr-")(k))(read_message(xx_resp(RSK)(REK))(u)))(
       SAY(concat("xxi-")(k))(read_message(I1)(concat(u)(rep(64)("z")))))))
      (ssub(low)(mul(32)(str_to_int(k)))(mul(32)(add(str_to_int(k))(1)))))))
  (RF("low.bin"))(keypair(RF("si.bin")))(keypair(RF("ei.bin")))(keypair(RF("sr.bin")))(keypair(RF("er.bin")))))
glyph TURN = la net. NETV(net)(la frame. la deframe. la broken. la keypair. la xx_init. la xx_resp. la x_init. la x_resp.
    la write_message. la read_message. la done. la encrypt. la decrypt. la prologue.
    read_message(xx_init(keypair(RF("si.bin")))(keypair(RF("ei.bin"))))(RF("m1.bin"))(la _. print("turn: none"))(la r. print("turn: some")))
glyph MAIN = (la crypt. (la tk. la net. DISPATCH(read_file("mode.txt"))(
    CONS(PR("frames")(la _. FRAMES(tk)(net)))(
    CONS(PR("frame_big")(la _. FRAMEBIG(tk)(net)))(
    CONS(PR("broken")(la _. BROKEN(tk)(net)))(
    CONS(PR("noise")(la _. NOISE(crypt)(net)))(
    CONS(PR("tamper")(la _. TAMPER(tk)(crypt)(net)))(
    CONS(PR("limits")(la _. LIMITS(tk)(crypt)(net)))(
    CONS(PR("limw")(la _. LIMW(tk)(net)))(
    CONS(PR("lime")(la _. LIME(tk)(net)))(
    CONS(PR("low")(la _. LOW(tk)(crypt)(net)))(
    CONS(PR("turn")(la _. TURN(net)))(
    NIL))))))))))))
  (TK)(NET_KIT(B)(X)(crypt)(XK)))(CRYPT)
LAEOF

echo "      compiling the test program on the VM ..."
tc0=$(date +%s)
vm_compile t.la t.bin
echo "      (compiled in $(( $(date +%s) - tc0 )) s)"

# ── 1. frames ──────────────────────────────────────────────────────────
( cd "$T" && python3 oracle.py frames "$RANDOM" > frames.exp )
vm_run t.bin frames "$T/frames.out"
( cd "$T" && python3 oracle.py framescheck > frames.same )
check "$([ "$vrc" = 0 ] && cmp -s "$T/frames.exp" "$T/frames.out" && [ "$(cat "$T/frames.same")" = same ] && echo 1)" \
    "frames round-trip: $(grep -c . "$T/frames.exp" >/dev/null; head -1 "$T/frames.exp" | cut -d' ' -f2) payloads (0 B to 1 MiB) cut into $(sed -n 3p "$T/frames.exp" | cut -d' ' -f2) chunks, re-framed byte for byte as Python frames them" \
    "rc $vrc; $(diff "$T/frames.exp" "$T/frames.out" | head -c 300); re-frame: $(cat "$T/frames.same")"
vm_run t.bin frame_big "$T/fbig.out"
check "$([ "$vrc" = 1 ] && [ ! -s "$T/fbig.out" ] && grep -q '^logosnet: frame: payload longer than 1 MiB' "$T/vre" && echo 1)" \
    "frame halts on a payload of 1 MiB + 1 byte (rc $vrc: $(head -c 80 "$T/vre"))"
( cd "$T" && python3 oracle.py broken > broken.exp )
vm_run t.bin broken "$T/broken.out"
check "$([ "$vrc" = 0 ] && cmp -s "$T/broken.exp" "$T/broken.out" && echo 1)" \
    "deframe: a declared length above 1 MiB is broken (and its payload never released, even when complete), after the frames before it; exactly 1 MiB still pending is not" \
    "rc $vrc; $(diff "$T/broken.exp" "$T/broken.out" | head -c 300)"

# ── 2. Noise ───────────────────────────────────────────────────────────
if ( cd "$T" && python3 oracle.py noise "$RANDOM" ) > "$T/noise.gen" 2>&1; then
    pass "the gate's own Noise ($(cat "$T/oracle.txt")) reproduces the published cacophony vectors, XX and X: every message and both handshake hashes"
else
    fail "the gate's own Noise does not reproduce the cacophony vectors"; tail -5 "$T/noise.gen"
fi
noise_set() {  # noise_set PREFIX LABEL
    printf '%s' "$1" > "$T/prefix.txt"
    vm_run t.bin noise "$T/$1noise.out"
    ( cd "$T" && python3 oracle.py cmp "$1noise.exp" "$1noise.out" ) > "$T/$1noise.cmp"
    local sec what
    for sec in xx xxi xxr x xi xr; do
        case $sec in
            xx)  what="Noise_XX, both sides LA: every handshake and transport message, payload, handshake hash and remote static key" ;;
            xxi) what="Noise_XX initiator (LA) against the oracle's responder messages" ;;
            xxr) what="Noise_XX responder (LA) against the oracle's initiator messages" ;;
            x)   what="Noise_X, both sides LA" ;;
            xi)  what="Noise_X initiator (LA): its message and transport messages" ;;
            xr)  what="Noise_X responder (LA) against the oracle's messages" ;;
        esac
        check "$([ "$vrc" = 0 ] && grep -q "^$sec ok" "$T/$1noise.cmp" && echo 1)" "$what, $2, byte for byte" \
            "rc $vrc; $(grep "^$sec " "$T/$1noise.cmp"); $(tail -c 200 "$T/vre")"
    done
}
noise_set cc_ "the cacophony vectors (prologue \"John Galt\")"
noise_set ln_ "random static keys and fixed ephemerals, prologue LogosNet/1"
printf 'ln_' > "$T/prefix.txt"
vm_run t.bin tamper "$T/tamper.out"
check "$([ "$vrc" = 0 ] && cmp -s "$T/tamper.exp" "$T/tamper.out" && echo 1)" \
    "a flipped byte is refused wherever it is (XX messages 2 and 3, a transport message, the X message, its transport), so is a replayed transport message; a flip in XX message 1 (unauthenticated) is caught at message 2" \
    "rc $vrc; $(diff "$T/tamper.exp" "$T/tamper.out" | head -c 400)"
vm_run t.bin limits "$T/limits.out"
check "$([ "$vrc" = 0 ] && cmp -s "$T/limits.exp" "$T/limits.out" && echo 1)" \
    "the 65535-byte limit: a 65535-byte handshake message and transport message pass, one byte more is refused on reading" \
    "rc $vrc; $(diff "$T/limits.exp" "$T/limits.out" | head -c 300)"
vm_run t.bin limw "$T/limw.out"
check "$([ "$vrc" = 1 ] && [ ! -s "$T/limw.out" ] && grep -q '^logosnet: write_message: message longer than 65535 bytes' "$T/vre" && echo 1)" \
    "write_message refuses a payload that would make a 65536-byte message (rc $vrc: $(head -c 70 "$T/vre"))"
vm_run t.bin lime "$T/lime.out"
check "$([ "$vrc" = 1 ] && [ ! -s "$T/lime.out" ] && grep -q '^logosnet: encrypt: message longer than 65535 bytes' "$T/vre" && echo 1)" \
    "encrypt refuses a 65520-byte payload (rc $vrc: $(head -c 70 "$T/vre"))"
vm_run t.bin low "$T/low.out"
check "$([ "$vrc" = 0 ] && cmp -s "$T/low.exp" "$T/low.out" && echo 1)" \
    "an all-zero DH ends the handshake: x_init refuses a small-order rs, the XX responder a small-order e, the XX initiator a small-order re (u = 0, 1, order 8, p - 1); done is none before the end" \
    "rc $vrc; $(diff "$T/low.exp" "$T/low.out" | head -c 300)"
vm_run t.bin turn "$T/turn.out"
check "$([ "$vrc" = 1 ] && [ ! -s "$T/turn.out" ] && grep -q "^logosnet: read_message: it is this side's turn to write" "$T/vre" && echo 1)" \
    "read_message out of turn halts (rc $vrc: $(head -c 70 "$T/vre"))"

echo "      (gate ran $(( $(date +%s) - G0 )) s)"
if [ "$ok" = 1 ]; then echo "PASS  logosnet: all checks"; exit 0; else echo "FAIL  logosnet: some checks failed"; exit 1; fi
