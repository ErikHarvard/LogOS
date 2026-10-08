#!/usr/bin/env bash
# gate_crypt_ref.sh — the reference crypt record (crypt_ref.la) gives the
# published answers, on the native VM.
#
# WHAT IT GUARDS. crypt_ref.la only composes modules whose own gates hold
# (gate_sha256.sh, gate_crypto.sh), but the composition is new code: SEAL must
# append the tag computed over the ciphertext it produced, OPEN must split the
# sealed string at length-16 and refuse anything that does not authenticate.
# Known answers only:
#   sha256("abc")                      FIPS 180-2 B.1
#   HMAC-SHA256("Jefe", "what do ya want for nothing?")    RFC 4231 test case 2
#   HKDF-SHA256(no salt, 22 x 0x0b, no info, 42)           RFC 5869 test case 3
#   seal(RFC 8439 2.8.2 key, nonce, aad, plaintext) = its ciphertext ++ tag
#   open of that sealed string = the plaintext
#   open with ONE ciphertext bit flipped = none (no bytes released)
#   open of a string shorter than a tag = none
# ISOLATION: private temp dir (gate_wm_common.sh). VM only; several minutes.
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1
wm_setup crypt_ref.la sha256.la hmac.la hkdf.la aead.la chacha20.la poly1305.la
cat > "$T/t.la" <<'LAEOF'
import("crypt_ref.la")
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
glyph MAIN = CRYPT_REF(la sha256. la hmac. la hkdf. la seal. la open. la hex.
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
wm_vm t.la "$T/out.txt"
if [ "$vrc" = 0 ] && [ "$(cat "$T/out.txt")" = "$EXPECT" ]; then
    echo "PASS  crypt_ref (VM): sha256, HMAC, HKDF, seal and open give the published answers; a flipped bit and a short string release nothing"
else
    echo "FAIL  crypt_ref (VM): rc=$vrc"; diff <(echo "$EXPECT") "$T/out.txt" | head -20; tail -3 "$T/vce" "$T/vre" 2>/dev/null; ok=0
fi
[ "$ok" = 1 ] || exit 1
