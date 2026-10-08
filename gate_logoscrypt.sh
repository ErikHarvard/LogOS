#!/usr/bin/env bash
# gate_logoscrypt.sh — CRYPT_FAST (logoscrypt.la) keeps crypt_ref.la's contract
# exactly, on the native VM, and is much faster.
#
# WHAT IT GUARDS (OS_LAYERS_DESIGN.md, "logoscrypt.la"):
#   1. the published answers gate_crypt_ref.sh checks, from the same program
#      with CRYPT_FAST in place of CRYPT_REF: sha256("abc"), RFC 4231 HMAC
#      case 2, RFC 5869 HKDF case 3 (no salt), the RFC 8439 2.8.2 seal and
#      open, a flipped bit and a short string releasing nothing;
#   2. an independent oracle (stdlib hashlib/hmac, and RFC 8439 transcribed
#      in Python below; nothing derived from the LA code) on inputs generated
#      the same way inside LA: sha256 at every length 0..130 and 1000, 4096;
#      HMAC with keys of 0..200 bytes across the 64-byte block; HKDF at every
#      length 1..96 with an empty and a non-empty salt, and at 0 and 8160;
#      seal/open of 0..1000 bytes with 0..17 bytes of aad; hex of all 256 bytes;
#   3. failure paths: a flipped bit in the first or last ciphertext byte or
#      tag byte, in the aad, a wrong key or nonce, a sealed string cut short or
#      lengthened, an empty, 15-byte or all-zero 16-byte one: each opens to
#      none; a key that is not 32 bytes, a nonce that is not 12, and an hkdf
#      length outside 0..8160 each halt loudly (rc 1, the message, no output);
#   4. self-application: the record hashes its own source, derives a key and
#      nonce from that digest with hkdf, seals its own source under them and
#      opens it back (matching the oracle byte for byte); and the C host gives
#      the oracle's bytes too, on a small program (the host is slow);
#   5. equality with CRYPT_REF itself: sha256 at 0 1 55 56 63 64 65 119 120
#      bytes, HMAC with 65- and 129-byte keys, HKDF at every length 1..96,
#      seal of 0 1 63 64 65 300 bytes byte-equal, and each record opening the
#      other's sealed strings. KNOWN REFERENCE DEFECT: CRYPT_REF's sha256 is
#      wrong for lengths 55 (mod 64) -- sha256.la's PADLEN pads them with 64
#      zero bytes where FIPS 180-4 pads none -- so at 55 and 119 the gate
#      requires the reference's digest to be exactly that mis-padding (the
#      oracle computes it) and CRYPT_FAST's to be FIPS's (part 2), and says so;
#      once sha256.la is fixed those two lengths simply compare equal;
#   6. speed: CRYPT_FAST against CRYPT_REF for sha256 and seal of 1 KB (and the
#      fast record on 10 KB), timed inside the programs with clock_gettime;
#      PASS needs a factor of at least 50 on both. LOGOSCRYPT_REF_10K=1 also
#      times CRYPT_REF on 10 KB (about 30 minutes on a loaded machine).
# ISOLATION: private temp dir (gate_wm_common.sh). VM, plus one small host
# program. CRYPT_REF is slow by design: part 5 and the reference timing take
# most of the run (the whole gate took 32 to 47 minutes on a 4-core machine
# at load average 6 to 13). They run one at a time (each can grow to about
# 1.5 GB). LOGOSCRYPT_REF_TIMEOUT (default 3600 s) bounds each of them.
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1
MODS="logoscrypt.la crypt_ref.la sha256.la hmac.la hkdf.la aead.la chacha20.la poly1305.la"
wm_setup $MODS
: "${LOGOSCRYPT_REF_TIMEOUT:=3600}"

# ── the oracle ─────────────────────────────────────────────────────────
cat > "$T/oracle.py" <<'PYEOF'
import hashlib, hmac as _hmac, struct, sys
def sha256(m): return hashlib.sha256(m).digest()
def hmac(k, m): return _hmac.new(k, m, hashlib.sha256).digest()
def hkdf(salt, ikm, info, n):
    prk = hmac(salt if salt else b"\0" * 32, ikm)
    out, t, i = b"", b"", 1
    while len(out) < n:
        t = hmac(prk, t + info + bytes([i])); out += t; i += 1
    return out[:n]
M = 0xffffffff
def _qr(s, a, b, c, d):
    def rotl(x, n): return ((x << n) | (x >> (32 - n))) & M
    s[a] = (s[a] + s[b]) & M; s[d] = rotl(s[d] ^ s[a], 16)
    s[c] = (s[c] + s[d]) & M; s[b] = rotl(s[b] ^ s[c], 12)
    s[a] = (s[a] + s[b]) & M; s[d] = rotl(s[d] ^ s[a], 8)
    s[c] = (s[c] + s[d]) & M; s[b] = rotl(s[b] ^ s[c], 7)
def chacha_block(key, ctr, nonce):
    st = [0x61707865, 0x3320646e, 0x79622d32, 0x6b206574] + list(struct.unpack("<8I", key)) \
         + [ctr] + list(struct.unpack("<3I", nonce))
    w = st[:]
    for _ in range(10):
        _qr(w, 0, 4, 8, 12); _qr(w, 1, 5, 9, 13); _qr(w, 2, 6, 10, 14); _qr(w, 3, 7, 11, 15)
        _qr(w, 0, 5, 10, 15); _qr(w, 1, 6, 11, 12); _qr(w, 2, 7, 8, 13); _qr(w, 3, 4, 9, 14)
    return struct.pack("<16I", *[(w[i] + st[i]) & M for i in range(16)])
def chacha_xor(key, ctr, nonce, data):
    out = bytearray()
    for j in range(0, len(data), 64):
        ks = chacha_block(key, ctr + j // 64, nonce)
        out += bytes(a ^ b for a, b in zip(data[j:j + 64], ks))
    return bytes(out)
def poly1305(key, msg):
    r = int.from_bytes(key[:16], "little") & 0x0ffffffc0ffffffc0ffffffc0fffffff
    s = int.from_bytes(key[16:], "little")
    p, a = (1 << 130) - 5, 0
    for j in range(0, len(msg), 16):
        a = (a + int.from_bytes(msg[j:j + 16] + b"\x01", "little")) * r % p
    return ((a + s) % (1 << 128)).to_bytes(16, "little")
def _mac(aad, ct):
    pad = lambda x: b"\0" * (-len(x) % 16)
    return aad + pad(aad) + ct + pad(ct) + struct.pack("<QQ", len(aad), len(ct))
def seal(key, nonce, aad, pt):
    ct = chacha_xor(key, 1, nonce, pt)
    return ct + poly1305(chacha_block(key, 0, nonce)[:32], _mac(aad, ct))
def open_(key, nonce, aad, sd):
    if len(sd) < 16: return None
    ct, tag = sd[:-16], sd[-16:]
    if not _hmac.compare_digest(poly1305(chacha_block(key, 0, nonce)[:32], _mac(aad, ct)), tag): return None
    return chacha_xor(key, 1, nonce, ct)
# byte i of gen(n, seed) is (i*7 + seed) mod 256 -- GEN in the LA programs
def gen(n, seed): return bytes((i * 7 + seed) % 256 for i in range(n))
# SHA-256 over an explicitly padded message, to name a known defect of the
# reference exactly: sha256.la's PADLEN takes 64 zero bytes where FIPS 180-4
# takes none, when (L + 1) mod 64 = 56, i.e. L = 55 (mod 64).
_K = [int(x, 16) for x in """428a2f98 71374491 b5c0fbcf e9b5dba5 3956c25b 59f111f1 923f82a4 ab1c5ed5
d807aa98 12835b01 243185be 550c7dc3 72be5d74 80deb1fe 9bdc06a7 c19bf174 e49b69c1 efbe4786 0fc19dc6
240ca1cc 2de92c6f 4a7484aa 5cb0a9dc 76f988da 983e5152 a831c66d b00327c8 bf597fc7 c6e00bf3 d5a79147
06ca6351 14292967 27b70a85 2e1b2138 4d2c6dfc 53380d13 650a7354 766a0abb 81c2c92e 92722c85 a2bfe8a1
a81a664b c24b8b70 c76c51a3 d192e819 d6990624 f40e3585 106aa070 19a4c116 1e376c08 2748774c 34b0bcb5
391c0cb3 4ed8aa4a 5b9cca4f 682e6ff3 748f82ee 78a5636f 84c87814 8cc70208 90befffa a4506ceb bef9a3f7
c67178f2""".split()]
def _sha_blocks(padded):
    rotr = lambda x, n: ((x >> n) | (x << (32 - n))) & M
    H = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]
    for o in range(0, len(padded), 64):
        w = list(struct.unpack(">16I", padded[o:o + 64]))
        for t in range(16, 64):
            w.append((w[t-16] + (rotr(w[t-15], 7) ^ rotr(w[t-15], 18) ^ (w[t-15] >> 3)) + w[t-7]
                      + (rotr(w[t-2], 17) ^ rotr(w[t-2], 19) ^ (w[t-2] >> 10))) & M)
        a, b, c, d, e, f, g_, h = H
        for t in range(64):
            t1 = (h + (rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)) + ((e & f) ^ (~e & g_)) + _K[t] + w[t]) & M
            t2 = ((rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)) + ((a & b) ^ (a & c) ^ (b & c))) & M
            h, g_, f, e, d, c, b, a = g_, f, e, (d + t1) & M, c, b, a, (t1 + t2) & M
        H = [(x + y) & M for x, y in zip(H, [a, b, c, d, e, f, g_, h])]
    return b"".join(struct.pack(">I", x) for x in H)
def _pad(m, k): return m + b"\x80" + b"\0" * k + struct.pack(">Q", 8 * len(m))
def sha256_lapad(m):
    r = (len(m) + 1) % 64
    return _sha_blocks(_pad(m, 56 - r if r < 56 else 120 - r))
for _n in (0, 1, 55, 56, 64, 119, 200):  # the transcription itself, against hashlib
    _m = bytes(range(_n % 256)) * (_n // 256 + 1)
    _m = _m[:_n]
    assert _sha_blocks(_pad(_m, (55 - len(_m)) % 64)) == sha256(_m)
g = gen
SEALN = [0, 1, 15, 16, 17, 63, 64, 65, 127, 128, 129, 300, 1000]
if __name__ == "__main__" and sys.argv[1] == "sweep":
    out = ["hex " + g(256, 0).hex(),
           "sha 1000 " + sha256(g(1000, 3)).hex(), "sha 4096 " + sha256(g(4096, 3)).hex()]
    out += ["sha %d %s" % (n, sha256(g(n, 3)).hex()) for n in range(131)]
    for k in [0, 1, 31, 32, 63, 64, 65, 100, 128, 129, 200]:
        for n in [0, 3, 64, 100]:
            out.append("hmac %d %d %s" % (k, n, hmac(g(k, 5), g(n, k)).hex()))
    for L in range(1, 97):
        out.append("hkdf0 %d %s" % (L, hkdf(b"", g(22, L), g(10, 9), L).hex()))
        out.append("hkdf1 %d %s" % (L, hkdf(b"salt!", g(22, L), g(10, 9), L).hex()))
    out.append("hkdf-len0 []")
    out.append("hkdf-len8160 " + sha256(hkdf(b"", g(22, 0), b"", 8160)).hex())
    for n in SEALN:
        for a in [0, 1, 16, 17]:
            key, nonce, aad, pt = g(32, n + a), g(12, n + 101), g(a, n + 51), g(n, a)
            sd = seal(key, nonce, aad, pt)
            assert open_(key, nonce, aad, sd) == pt
            out += ["seal %d %d %s" % (n, a, sd.hex()), "open %d %d same" % (n, a)]
    print("\n".join(out + ["end"]))
if __name__ == "__main__" and sys.argv[1] == "self":
    src = open(sys.argv[2], "rb").read()
    h = sha256(src)
    key, nonce = hkdf(b"", h, b"logoscrypt/self key", 32), hkdf(b"", h, b"logoscrypt/self nonce", 12)
    sd = seal(key, nonce, b"logoscrypt.la", src)
    assert open_(key, nonce, b"logoscrypt.la", sd) == src
    print("self-sha256 " + h.hex()); print("self-seal " + sha256(sd).hex())
    print("self-open same"); print("end")
if __name__ == "__main__" and sys.argv[1] == "engines":
    k, n = b"0123456789abcdef0123456789abcdef", b"0123456789ab"
    sd = seal(k, n, b"ad", b"hey")
    print("sha256 " + sha256(b"abc").hex()); print("hmac " + hmac(b"Jefe", b"what do ya want for nothing?").hex())
    print("seal " + sd.hex()); print("open hey"); print("tamper none")
    print("hkdf " + hkdf(b"", b"ikm", b"info", 40).hex()); print("end")
if __name__ == "__main__" and sys.argv[1] == "lapad":
    for n in [0, 1, 55, 56, 63, 64, 65, 119, 120]:
        print("sha %d %s %s" % (n, sha256(g(n, 3)).hex(), sha256_lapad(g(n, 3)).hex()))
if __name__ == "__main__" and sys.argv[1] == "timing":
    k1, k10, key, nonce = g(1024, 0), g(10240, 0), g(32, 1), g(12, 2)
    print("sha256-1KB " + sha256(sha256(k1)).hex())
    print("sha256-10KB " + sha256(sha256(k10)).hex())
    print("seal-1KB " + sha256(seal(key, nonce, b"", k1)).hex())
    print("seal-10KB " + sha256(seal(key, nonce, b"", k10)).hex())
PYEOF
command -v python3 >/dev/null || { echo "FAIL  logoscrypt: python3 (the oracle) is not installed"; exit 1; }

# ── the shared LA prelude: test data, list helpers, the fast record ─────
cat > "$T/prelude.la" <<'LAEOF'
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
# GEN(n)(seed): byte i is (i*7 + seed) mod 256, joined by halving
glyph GEN = la n. la seed. (Z(la sp. la lo. la hi.
    lt(add(lo)(1))(hi)
      (la _. (la mid. concat(sp(lo)(mid))(sp(mid)(hi)))(div(add(lo)(hi))(2)))
      (la _. lt(lo)(hi)(la _. chr(int_to_str(mod(add(mul(lo)(7))(seed))(256))))(la _. "")("!"))
      ("!")))(0)(n)
# SUB(s)(a)(b): bytes a..b-1; FLIP(s)(i)(bit): s with that bit of byte i inverted
glyph SUB = la s. la a. la b. (Z(la sp. la lo. la hi.
    lt(add(lo)(1))(hi)
      (la _. (la mid. concat(sp(lo)(mid))(sp(mid)(hi)))(div(add(lo)(hi))(2)))
      (la _. lt(lo)(hi)(la _. str_at(s)(lo))(la _. "")("!"))
      ("!")))(a)(b)
glyph LEN = la s. str_to_int(str_len(s))
glyph FLIP = la s. la i. la bit.
  concat(concat(SUB(s)(0)(i))(chr(int_to_str(bxor(str_to_int(ord(str_at(s)(i))))(bshl(1)(bit))))))(SUB(s)(add(i)(1))(LEN(s)))
glyph SEQ = la a. la b. b
glyph NIL = la n. la c. n(n)
glyph C = la h. la t. la n. la c. c(h)(t)
glyph P = la a. la b. la k. k(a)(b)
glyph FOR = Z(la go. la l. la f. l(la _. "")(la h. la t. (la _. go(t)(f))(f(h))))
glyph UPTO = Z(la go. la a. la b. lt(a)(b)(la _. C(a)(go(add(a)(1))(b)))(la _. NIL)("!"))
glyph SHOW = la tag. la n. la s. print(concat(concat(concat(tag)(int_to_str(n)))(" "))(s))
glyph EQ = la tag. la x. la y. print(concat(tag)(str_eq(x)(y)(la _. " EQ")(la _. " NE")("!")))
glyph FAST = la k. CRYPT_FAST(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(error)
  (add)(sub)(mul)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr)(k)
# in-program timing: BEST(n)(f) -> la k. k(least microseconds of n runs)(result)
glyph TSPLIT = Z(la go. la s. la acc. str_eq(str_head(s))(" ")(la _. la k. k(acc)(str_tail(s)))(la _. go(str_tail(s))(concat(acc)(str_head(s))))("!"))
glyph NOWUS = la _. TSPLIT(clock_gettime("1"))("")(la a. la b. add(mul(str_to_int(a))(1000000))(div(str_to_int(b))(1000)))
glyph BEST = Z(la go. la n. la f. la best. la res.
  int_eq(n)(0)(la _. la k. k(best)(res))
    (la _. (la t0. (la r. (la t1. go(sub(n)(1))(f)(lt(sub(t1)(t0))(best)(la _. sub(t1)(t0))(la _. best)("!"))(r))(NOWUS("!")))(f("!")))(NOWUS("!")))
    ("!"))
glyph REPORT = la hex. la sha256. la label. la reps. la f.
  BEST(reps)(f)(999999999999)("")(la us. la r. print(concat(concat(concat(concat(label)(" "))(int_to_str(us)))(" us "))(hex(sha256(r)))))
LAEOF
mkprog() {  # mkprog NAME.la [ref]: the imports, the prelude, then stdin
    { echo 'import("logoscrypt.la")'; [ "${2:-}" = ref ] && echo 'import("crypt_ref.la")'
      cat "$T/prelude.la" -; } > "$T/$1"
}
# vm_ref DIR PROG.la: compile and run a CRYPT_REF program in its own
# sub-directory, with the long timeout; out.txt, rc (90 = did not compile),
# err.txt. One at a time: this VM's two fixed 768 MiB semispaces let a long
# run grow to about 1.5 GB, and several at once can be OOM-killed.
vm_ref() {
    mkdir -p "$T/$1"
    ( cd "$T" && cp logos_secd compiler.bin $MODS "$2" "$T/$1/" )
    ( cd "$T/$1" && cp compiler.bin logos_program.bin && cp "$2" logos_source.la \
        && { timeout "$LOGOSCRYPT_REF_TIMEOUT" ./logos_secd >/dev/null 2>err.txt || { echo 90 > rc; exit 0; }; } \
        && { timeout "$LOGOSCRYPT_REF_TIMEOUT" ./logos_secd >out.txt 2>>err.txt; echo $? > rc; } )
}

# ── the CRYPT_REF programs (run in part 5) ────────────────────────────────
mkprog eq_sha.la ref <<'LAEOF'
glyph MAIN = FAST(la sha256. la hmac. la hkdf. la seal. la open. la hex.
 CRYPT_REF(la rsha256. la rhmac. la rhkdf. la rseal. la ropen. la rhex.
  (la _. (la _. print("end"))
    (FOR(C(65)(C(129)(NIL)))(la k. (la key. la msg. EQ(concat("hmac key ")(int_to_str(k)))(hmac(key)(msg))(rhmac(key)(msg)))
                                     (GEN(k)(5))(GEN(20)(k)))))
  (FOR(C(0)(C(1)(C(55)(C(56)(C(63)(C(64)(C(65)(C(119)(C(120)(NIL))))))))))(la n.
     (la m. (la f. la r. print(concat(concat("sha ")(int_to_str(n)))(str_eq(f)(r)(la _. " EQ")(la _. concat(" NE ")(hex(r)))("!"))))
              (sha256(m))(rsha256(m)))
     (GEN(n)(3))))))
LAEOF
# CRYPT_REF's 96-byte OKM once: the OKM of length L is by definition its first
# L bytes (hkdf.la's TAKE(l)(TCHAIN) is exactly that); CRYPT_FAST at each L.
mkprog eq_hkdf.la ref <<'LAEOF'
glyph MAIN = FAST(la sha256. la hmac. la hkdf. la seal. la open. la hex.
 CRYPT_REF(la rsha256. la rhmac. la rhkdf. la rseal. la ropen. la rhex.
  (la ikm. la info.
    (la ref.
      (la _. print("end"))
      (FOR(UPTO(1)(97))(la L. EQ(concat("hkdf ")(int_to_str(L)))(hkdf("")(ikm)(info)(L))(SUB(ref)(0)(L)))))
    (rhkdf("")(ikm)(info)(96)))
  (GEN(22)(1))(GEN(10)(9))))
LAEOF
mkprog eq_aead.la ref <<'LAEOF'
glyph MAIN = FAST(la sha256. la hmac. la hkdf. la seal. la open. la hex.
 CRYPT_REF(la rsha256. la rhmac. la rhkdf. la rseal. la ropen. la rhex.
  (la _. print("end"))
  (FOR(C(0)(C(1)(C(63)(C(64)(C(65)(C(300)(NIL)))))))(la n.
    (la key. la nonce. la aad. la pt.
      (la sf. la sr.
        (la _. (la _. print(concat(concat("open-fast ")(int_to_str(n)))
                                  (open(key)(nonce)(aad)(sr)(la _. " none")(la p. str_eq(p)(pt)(la _. " same")(la _. " DIFFERENT")("!")))))
                      (print(concat(concat("open-ref ")(int_to_str(n)))
                                  (ropen(key)(nonce)(aad)(sf)(la _. " none")(la p. str_eq(p)(pt)(la _. " same")(la _. " DIFFERENT")("!"))))))
               (EQ(concat("seal ")(int_to_str(n)))(sf)(sr)))
      (seal(key)(nonce)(aad)(pt))(rseal(key)(nonce)(aad)(pt)))
    (GEN(32)(n))(GEN(12)(add(n)(1)))(GEN(7)(add(n)(2)))(GEN(n)(add(n)(3)))))))
LAEOF
if [ "${LOGOSCRYPT_REF_10K:-}" = 1 ]; then REF10='(rep("ref sha256-10KB")(1)(la _. rsha256(k10))))(rep("ref seal-10KB")(1)(la _. rseal(key)(nonce)("")(k10))))'
else REF10='(print("")))(print("")))'; fi
mkprog tref.la ref <<LAEOF
glyph MAIN = FAST(la sha256. la hmac. la hkdf. la seal. la open. la hex.
 CRYPT_REF(la rsha256. la rhmac. la rhkdf. la rseal. la ropen. la rhex.
  (la rep. la key. la nonce. la k1. la k10.
     SEQ(SEQ(SEQ(rep("ref sha256-1KB")(1)(la _. rsha256(k1)))(rep("ref seal-1KB")(1)(la _. rseal(key)(nonce)("")(k1))))
        $REF10
  (REPORT(hex)(sha256))(GEN(32)(1))(GEN(12)(2))(GEN(1024)(0))(GEN(10240)(0))))
LAEOF

# ── 1. the published answers (gate_crypt_ref.sh's program, CRYPT_FAST) ──
cat > "$T/ka.la" <<'LAEOF'
import("logoscrypt.la")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph FROMHEX = Z(la self. la s.
    str_eq(s)("")(la _. "")(la _.
      (la hv. concat(chr(int_to_str(add(mul(hv(str_head(s)))(16))(hv(str_head(str_tail(s)))))))
                    (self(str_tail(str_tail(s)))))
      (la c. (la n. lt(n)(58)(la _. sub(n)(48))(la _. sub(n)(87))("!"))(str_to_int(ord(c)))))("!"))
glyph REPB = Z(la self. la n. la b. int_eq(n)(0)(la _. "")(la _. concat(b)(self(sub(n)(1))(b)))("!"))
glyph FLIP0 = la s. concat(chr(int_to_str(bxor(str_to_int(ord(str_head(s))))(1))))(str_tail(s))
glyph KEY = FROMHEX("808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f")
glyph NONCE = FROMHEX("070000004041424344454647")
glyph AAD = FROMHEX("50515253c0c1c2c3c4c5c6c7")
glyph PT = "Ladies and Gentlemen of the class of '99: If I could offer you only one tip for the future, sunscreen would be it."
glyph MAIN = CRYPT_FAST(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(error)(add)(sub)(mul)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr)
 (la sha256. la hmac. la hkdf. la seal. la open. la hex.
  (la sealed.
    (la _. (la _. (la _. (la _. (la _. (la _. print("done"))
      (print(concat("short ")(open(KEY)(NONCE)(AAD)("tooshort")(la _. "none")(la p. "SOME")))))
      (print(concat("tamper ")(open(KEY)(NONCE)(AAD)(FLIP0(sealed))(la _. "none")(la p. concat("RELEASED ")(p))))))
      (print(concat("open ")(open(KEY)(NONCE)(AAD)(sealed)(la _. "none")(la p. p)))))
      (print(concat("seal ")(hex(sealed)))))
      (print(concat("hkdf ")(hex(hkdf("")(REPB(22)(chr("11")))("")(42))))))
    ((la _. print(concat("hmac ")(hex(hmac("Jefe")("what do ya want for nothing?")))))
     (print(concat("sha256 ")(hex(sha256("abc")))))))
  (seal(KEY)(NONCE)(AAD)(PT)))
LAEOF
EXPECT="sha256 ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
hmac 5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843
hkdf 8da4e775a563c18f715f802a063c5a31b8a11f5c5ee1879ec3454e5f3c738d2d9d201395faa4b61a96c8
seal d31a8d34648e60db7b86afbc53ef7ec2a4aded51296e08fea9e2b5a736ee62d63dbea45e8ca9671282fafb69da92728b1a71de0a9e060b2905d6a5b67ecd3b3692ddbd7f2d778b8c9803aee328091b58fab324e4fad675945585808b4831d7bc3ff4def08e4b7a9de576d26586cec64b61161ae10b594f09e26a7e902ecbd0600691
open Ladies and Gentlemen of the class of '99: If I could offer you only one tip for the future, sunscreen would be it.
tamper none
short none
done"
wm_vm ka.la "$T/ka.out"
if [ "$vrc" = 0 ] && [ "$(cat "$T/ka.out")" = "$EXPECT" ]; then
    echo "PASS  logoscrypt known answers (VM): sha256, HMAC, HKDF, seal and open give the published answers; a flipped bit and a short string release nothing"
else
    echo "FAIL  logoscrypt known answers (VM): rc=$vrc"; diff <(echo "$EXPECT") "$T/ka.out" | head -10; tail -3 "$T/vce" "$T/vre" 2>/dev/null; ok=0
fi

# ── 2. the oracle sweep ──────────────────────────────────────────────────
mkprog sweep.la <<'LAEOF'
glyph MAIN = FAST(la sha256. la hmac. la hkdf. la seal. la open. la hex.
  SEQ(SEQ(SEQ(SEQ(SEQ(SEQ(SEQ(
    # hex of all 256 bytes; sha256 at 1000, 4096 and every length 0..130
    SEQ(SEQ(print(concat("hex ")(hex(GEN(256)(0)))))
           (SHOW("sha ")(1000)(hex(sha256(GEN(1000)(3))))))
       (SHOW("sha ")(4096)(hex(sha256(GEN(4096)(3))))))
    (FOR(UPTO(0)(131))(la n. SHOW("sha ")(n)(hex(sha256(GEN(n)(3)))))))
    # HMAC: key lengths across the 64-byte block, x message lengths
    (FOR(C(0)(C(1)(C(31)(C(32)(C(63)(C(64)(C(65)(C(100)(C(128)(C(129)(C(200)(NIL))))))))))))(la k.
       FOR(C(0)(C(3)(C(64)(C(100)(NIL)))))(la n.
         print(concat(concat(concat(concat(concat("hmac ")(int_to_str(k)))(" "))(int_to_str(n)))(" "))
                     (hex(hmac(GEN(k)(5))(GEN(n)(k)))))))))
    # HKDF at every length 1..96, empty and non-empty salt; 0 and 8160
    (FOR(UPTO(1)(97))(la L.
       SEQ(SHOW("hkdf0 ")(L)(hex(hkdf("")(GEN(22)(L))(GEN(10)(9))(L))))
          (SHOW("hkdf1 ")(L)(hex(hkdf("salt!")(GEN(22)(L))(GEN(10)(9))(L)))))))
    (print(concat(concat("hkdf-len0 [")(hkdf("")(GEN(22)(0))("")(0)))("]"))))
    (print(concat("hkdf-len8160 ")(hex(sha256(hkdf("")(GEN(22)(0))("")(8160)))))))
    # seal and open over plaintext x aad lengths
    (FOR(C(0)(C(1)(C(15)(C(16)(C(17)(C(63)(C(64)(C(65)(C(127)(C(128)(C(129)(C(300)(C(1000)(NIL))))))))))))))(la n.
       FOR(C(0)(C(1)(C(16)(C(17)(NIL)))))(la a.
         (la key. la nonce. la aad. la pt.
           (la sd. SEQ(print(concat(concat(concat(concat(concat("seal ")(int_to_str(n)))(" "))(int_to_str(a)))(" "))(hex(sd))))
                      (print(concat(concat(concat(concat("open ")(int_to_str(n)))(" "))(int_to_str(a)))
                         (open(key)(nonce)(aad)(sd)(la _. " none")(la p. str_eq(p)(pt)(la _. " same")(la _. " DIFFERENT")("!"))))))
           (seal(key)(nonce)(aad)(pt)))
         (GEN(32)(add(n)(a)))(GEN(12)(add(n)(101)))(GEN(a)(add(n)(51)))(GEN(n)(a))))))
    (print("end")))
LAEOF
wm_vm sweep.la "$T/sweep.out"
( cd "$T" && python3 oracle.py sweep ) > "$T/sweep.exp"
if [ "$vrc" = 0 ] && cmp -s "$T/sweep.out" "$T/sweep.exp"; then
    echo "PASS  logoscrypt oracle (VM): sha256 at 0..130/1000/4096 bytes, HMAC keys 0..200 bytes, HKDF lengths 0..96 and 8160 with and without salt, seal/open of 0..1000 bytes with 0..17 bytes of aad, hex of all 256 bytes: $(wc -l < "$T/sweep.exp") lines equal to the Python oracle"
else
    echo "FAIL  logoscrypt oracle (VM): rc=$vrc"; diff "$T/sweep.exp" "$T/sweep.out" | head -10; tail -3 "$T/vce" "$T/vre" 2>/dev/null; ok=0
fi

# ── 3a. tampering opens to none ────────────────────────────────────────────
mkprog tamper.la <<'LAEOF'
# each case: (label, thunk returning what open gives) for one sealed message;
# the ciphertext cases only where there is a ciphertext byte
glyph CASES = la open. la key. la nonce. la aad. la sd. la L. la n.
  C(P("tag-first-bit0")(la _. open(key)(nonce)(aad)(FLIP(sd)(sub(L)(16))(0))))
  (C(P("tag-last-bit7")(la _. open(key)(nonce)(aad)(FLIP(sd)(sub(L)(1))(7))))
  (C(P("truncated")(la _. open(key)(nonce)(aad)(SUB(sd)(0)(sub(L)(1)))))
  (C(P("extended")(la _. open(key)(nonce)(aad)(concat(sd)("x"))))
  (C(P("aad-empty")(la _. open(key)(nonce)("")(sd)))
  (C(P("aad-flip")(la _. open(key)(nonce)(FLIP(aad)(2)(4))(sd)))
  (C(P("wrong-nonce")(la _. open(key)(GEN(12)(8))(aad)(sd)))
  (C(P("wrong-key")(la _. open(GEN(32)(9))(nonce)(aad)(sd)))
  (lt(n)(1)(la _. NIL)(la _.
     C(P("ct-first-bit0")(la _. open(key)(nonce)(aad)(FLIP(sd)(0)(0))))
     (C(P("ct-last-bit7")(la _. open(key)(nonce)(aad)(FLIP(sd)(sub(L)(17))(7))))(NIL)))("!")))))))))
glyph SHOWR = la what. la n. la r.
  print(concat(concat(concat(concat(what)(" "))(int_to_str(n)))(" "))(r(la _. "none")(la p. "RELEASED")))
glyph MAIN = FAST(la sha256. la hmac. la hkdf. la seal. la open. la hex.
  SEQ(SEQ(
    (la k. la nn. SEQ(SEQ(SHOWR("empty")(0)(open(k)(nn)("")("")))
                          (SHOWR("short15")(15)(open(k)(nn)("")(GEN(15)(1)))))
                      (SHOWR("zero16")(16)(open(k)(nn)("")(GEN(16)(0)))))
      (GEN(32)(0))(GEN(12)(0)))
    (FOR(C(0)(C(1)(C(64)(C(65)(C(300)(NIL))))))(la n.
      (la key. la nonce. la aad. la pt.
        (la sd. SEQ(print(concat(concat(concat("control ")(int_to_str(n)))(" "))
                         (open(key)(nonce)(aad)(sd)(la _. "none")(la p. str_eq(p)(pt)(la _. "same")(la _. "DIFFERENT")("!")))))
                   (FOR(CASES(open)(key)(nonce)(aad)(sd)(LEN(sd))(n))(la c. c(la what. la run. SHOWR(what)(n)(run("!"))))))
        (seal(key)(nonce)(aad)(pt)))
      (GEN(32)(n))(GEN(12)(add(n)(1)))(GEN(5)(add(n)(2)))(GEN(n)(add(n)(3))))))
    (print("end")))
LAEOF
wm_vm tamper.la "$T/tamper.out"
nnone=$(grep -c ' none$' "$T/tamper.out"); nsame=$(grep -c '^control .* same$' "$T/tamper.out")
nbad=$(grep -cv -e ' none$' -e '^control .* same$' -e '^end$' "$T/tamper.out")
if [ "$vrc" = 0 ] && [ "$nnone" = 51 ] && [ "$nsame" = 5 ] && [ "$nbad" = 0 ] && [ "$(tail -1 "$T/tamper.out")" = end ]; then
    echo "PASS  logoscrypt tampering (VM): a flipped bit in the ciphertext, the tag or the aad, a wrong key or nonce, a cut or lengthened, empty, 15-byte or zero-tag string: all $nnone open to none; the $nsame untouched controls open"
else
    echo "FAIL  logoscrypt tampering (VM): rc=$vrc none=$nnone controls=$nsame other=$nbad"; grep -v -e ' none$' -e '^control .* same$' "$T/tamper.out" | head -5; ok=0
fi

# ── 3b. misuse halts loudly ────────────────────────────────────────────────
K32='"0123456789abcdef0123456789abcdef"'; N12='"0123456789ab"'
misuse() {  # misuse LABEL MESSAGE EXPR
    mkprog misuse.la <<LAEOF
glyph MAIN = FAST(la sha256. la hmac. la hkdf. la seal. la open. la hex. SEQ($3)(print("NOT REACHED")))
LAEOF
    wm_vm misuse.la "$T/misuse.out"
    if [ "$vrc" = 1 ] && grep -qxF "$2" "$T/vre" && [ ! -s "$T/misuse.out" ]; then
        echo "PASS  logoscrypt misuse (VM): $1 halts with '$2'"
    else
        echo "FAIL  logoscrypt misuse (VM): $1: rc=$vrc stdout=$(head -c 80 "$T/misuse.out") stderr=$(head -c 120 "$T/vre")"; ok=0
    fi
}
misuse "seal with a 31-byte key" "logoscrypt: seal: key must be 32 bytes" "seal(\"0123456789abcdef0123456789abcde\")($N12)(\"\")(\"x\")"
misuse "open with a 33-byte key" "logoscrypt: open: key must be 32 bytes" "open(\"0123456789abcdef0123456789abcdefg\")($N12)(\"\")(\"0123456789abcdef\")"
misuse "seal with an 11-byte nonce" "logoscrypt: seal: nonce must be 12 bytes" "seal($K32)(\"0123456789a\")(\"\")(\"x\")"
misuse "open with a 13-byte nonce" "logoscrypt: open: nonce must be 12 bytes" "open($K32)(\"0123456789abc\")(\"\")(\"0123456789abcdef\")"
misuse "hkdf of length -1" "logoscrypt: hkdf: len must be 0..8160" "hkdf(\"\")(\"ikm\")(\"\")(sub(0)(1))"
misuse "hkdf of length 8161" "logoscrypt: hkdf: len must be 0..8160" "hkdf(\"\")(\"ikm\")(\"\")(8161)"

# ── 4. self-application ───────────────────────────────────────────────────
mkprog self.la <<'LAEOF'
# the record applied to itself: its own source hashed, a key and a nonce
# derived from that digest, the source sealed under its own identity and opened
glyph MAIN = FAST(la sha256. la hmac. la hkdf. la seal. la open. la hex.
  (la src. (la h. (la key. la nonce. (la sd.
     SEQ(SEQ(SEQ(print(concat("self-sha256 ")(hex(h))))
                (print(concat("self-seal ")(hex(sha256(sd))))))
            (print(concat("self-open ")(open(key)(nonce)("logoscrypt.la")(sd)(la _. "none")
                                          (la p. str_eq(p)(src)(la _. "same")(la _. "DIFFERENT")("!"))))))
        (print("end")))
     (seal(key)(nonce)("logoscrypt.la")(src)))
     (hkdf("")(h)("logoscrypt/self key")(32))(hkdf("")(h)("logoscrypt/self nonce")(12)))
   (sha256(src)))
  (read_file("logoscrypt.la")))
LAEOF
wm_vm self.la "$T/self.out"
( cd "$T" && python3 oracle.py self logoscrypt.la ) > "$T/self.exp"
if [ "$vrc" = 0 ] && cmp -s "$T/self.out" "$T/self.exp"; then
    echo "PASS  logoscrypt self-application (VM): the record hashes its own $(wc -c < "$T/logoscrypt.la")-byte source, seals it under a key derived from that digest and opens it back, as the oracle does"
else
    echo "FAIL  logoscrypt self-application (VM): rc=$vrc"; diff "$T/self.exp" "$T/self.out" | head -6; ok=0
fi

# ── 4b. the C host gives the same bytes (a small program: the host is slow) ──
mkprog engines.la <<'LAEOF'
glyph MAIN = FAST(la sha256. la hmac. la hkdf. la seal. la open. la hex.
  (la k. la n. (la sd.
     SEQ(SEQ(SEQ(SEQ(SEQ(SEQ(print(concat("sha256 ")(hex(sha256("abc")))))
                            (print(concat("hmac ")(hex(hmac("Jefe")("what do ya want for nothing?"))))))
                        (print(concat("seal ")(hex(sd)))))
                    (print(concat("open ")(open(k)(n)("ad")(sd)(la _. "none")(la p. p)))))
                (print(concat("tamper ")(open(k)(n)("ad")(FLIP(sd)(0)(0))(la _. "none")(la p. p)))))
            (print(concat("hkdf ")(hex(hkdf("")("ikm")("info")(40))))))
        (print("end")))
     (seal(k)(n)("ad")("hey")))
   ("0123456789abcdef0123456789abcdef")("0123456789ab"))
LAEOF
( cd "$T" && python3 oracle.py engines ) > "$T/engines.exp"
wm_vm engines.la "$T/engines.vm"
wm_host engines.la "$T/engines.host"
if [ "$vrc" = 0 ] && [ "$hrc" = 0 ] && cmp -s "$T/engines.vm" "$T/engines.exp" && cmp -s "$T/engines.host" "$T/engines.exp"; then
    echo "PASS  logoscrypt engines: the C host and the VM give the oracle's bytes for sha256, HMAC, seal, open (and a tampered open), HKDF"
else
    echo "FAIL  logoscrypt engines: vm rc=$vrc host rc=$hrc"; diff "$T/engines.exp" "$T/engines.host" | head -5; diff "$T/engines.exp" "$T/engines.vm" | head -5; tail -2 "$T/hre" 2>/dev/null; ok=0
fi

# ── 6a. the fast timings ──────────────────────────────────────────────────
mkprog tfast.la <<'LAEOF'
glyph MAIN = FAST(la sha256. la hmac. la hkdf. la seal. la open. la hex.
  (la rep. la key. la nonce. la k1. la k10.
     SEQ(SEQ(SEQ(rep("fast sha256-1KB")(3)(la _. sha256(k1)))
                (rep("fast sha256-10KB")(3)(la _. sha256(k10))))
            (rep("fast seal-1KB")(3)(la _. seal(key)(nonce)("")(k1))))
        (rep("fast seal-10KB")(3)(la _. seal(key)(nonce)("")(k10))))
  (REPORT(hex)(sha256))(GEN(32)(1))(GEN(12)(2))(GEN(1024)(0))(GEN(10240)(0)))
LAEOF
wm_vm tfast.la "$T/tfast.out"
( cd "$T" && python3 oracle.py timing ) > "$T/timing.exp"

# ── 5 and 6b: the CRYPT_REF programs, one after another ───────────────────
for p in eq_aead eq_hkdf eq_sha tref; do vm_ref "r_$p" "$p.la"; done
# CRYPT_REF's sha256 is wrong where L = 55 (mod 64): sha256.la's PADLEN pads
# those with 64 zero bytes, FIPS 180-4 with none (CRYPT_FAST is the oracle's
# there; part 2). Such a line is accepted only at those lengths and only when
# the reference's digest is exactly that mis-padding; it then reads EQ.
( cd "$T" && python3 oracle.py lapad ) > "$T/lapad.txt"
if [ -f "$T/r_eq_sha/out.txt" ]; then
    while read -r w n rest; do
        [ "$w" = sha ] || continue
        case "$rest" in "NE "*)
            want=$(awk -v n="$n" '$2 == n {print $4}' "$T/lapad.txt")
            if [ $((n % 64)) = 55 ] && [ "${rest#NE }" = "$want" ]; then
                echo "NOTE  CRYPT_REF's sha256 of $n bytes is the digest of sha256.la's padding (64 zero bytes too many; FIPS 180-4 pads none), not FIPS's; CRYPT_FAST gives FIPS's"
                sed -i "s/^sha $n NE .*/sha $n EQ/" "$T/r_eq_sha/out.txt"
            fi;;
        esac
    done < "$T/r_eq_sha/out.txt"
fi
for p in eq_sha eq_hkdf eq_aead; do
    d="$T/r_$p"; rc=$(cat "$d/rc" 2>/dev/null || echo none)
    neq=$(grep -c ' EQ$' "$d/out.txt" 2>/dev/null); nsame=$(grep -c ' same$' "$d/out.txt" 2>/dev/null)
    nbad=$(grep -cv -e ' EQ$' -e ' same$' -e '^end$' "$d/out.txt" 2>/dev/null)
    case $p in eq_sha) want="11 0" what="sha256 at 0 1 55 56 63 64 65 119 120 bytes (at 55 and 119 the reference's known padding defect, named exactly) and HMAC with 65- and 129-byte keys";;
               eq_hkdf) want="96 0" what="HKDF (empty salt) at every length 1..96";;
               eq_aead) want="6 12" what="seal of 0 1 63 64 65 300 bytes byte-equal, and each record opens the other's";; esac
    if [ "$rc" = 0 ] && [ "$neq $nsame" = "$want" ] && [ "$nbad" = 0 ] && [ "$(tail -1 "$d/out.txt")" = end ]; then
        echo "PASS  logoscrypt = CRYPT_REF (VM): $what"
    else
        echo "FAIL  logoscrypt = CRYPT_REF (VM): $what: rc=$rc EQ=$neq same=$nsame other=$nbad"
        grep -v -e ' EQ$' -e ' same$' "$d/out.txt" 2>/dev/null | head -5; tail -3 "$d/err.txt" 2>/dev/null; ok=0
    fi
done

# speed: every timed result must be the oracle's, then the factors
d="$T/r_tref"; rc=$(cat "$d/rc" 2>/dev/null || echo none)
cat "$T/tfast.out" "$d/out.txt" 2>/dev/null | grep -E '^(fast|ref) ' > "$T/times.txt"
tbad=0
while read -r who op us dig; do
    [ "$(grep "^$op " "$T/timing.exp" | cut -d' ' -f2)" = "$dig" ] || { tbad=1; echo "      wrong result: $who $op"; }
done < <(awk '{print $1, $2, $3, $5}' "$T/times.txt")
us() { awk -v k="$1 $2" '$1" "$2 == k {print $3}' "$T/times.txt"; }
for op in sha256-1KB sha256-10KB seal-1KB seal-10KB; do
    f=$(us fast $op); r=$(us ref $op)
    if [ -n "$f" ] && [ -n "$r" ]; then
        echo "INFO  logoscrypt timing (VM): $op  CRYPT_FAST $((f / 1000)) ms  CRYPT_REF $((r / 1000)) ms  factor $((r / f))"
    elif [ -n "$f" ]; then
        echo "INFO  logoscrypt timing (VM): $op  CRYPT_FAST $((f / 1000)) ms  (CRYPT_REF on 10 KB: LOGOSCRYPT_REF_10K=1)"
    fi
done
f1=$(us fast sha256-1KB); r1=$(us ref sha256-1KB); f2=$(us fast seal-1KB); r2=$(us ref seal-1KB)
if [ "$vrc" = 0 ] && [ "$rc" = 0 ] && [ "$tbad" = 0 ] && [ -n "$f1" ] && [ -n "$r1" ] && [ -n "$f2" ] && [ -n "$r2" ] \
   && [ $((r1 / f1)) -ge 50 ] && [ $((r2 / f2)) -ge 50 ]; then
    echo "PASS  logoscrypt speed (VM): CRYPT_FAST is $((r1 / f1))x CRYPT_REF on sha256 of 1 KB and $((r2 / f2))x on seal of 1 KB (at least 50x), every timed result the oracle's"
else
    echo "FAIL  logoscrypt speed (VM): fast rc=$vrc ref rc=$rc wrong=$tbad sha256 ${f1:-?}/${r1:-?} us seal ${f2:-?}/${r2:-?} us"; tail -3 "$d/err.txt" 2>/dev/null; ok=0
fi
[ "$ok" = 1 ] || exit 1
