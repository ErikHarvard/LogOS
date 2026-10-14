#!/usr/bin/env bash
# gate_aletheiafs.sh — AletheiaFS (aletheiafs.la, FS_KIT) against an
# independent model of its on-disk format, on the native VM.
#
# WHAT IT GUARDS. A filesystem that seals and repairs itself fails quietly: a
# wrong nonce or key still round-trips through its own code, a repair that
# copies the wrong way still returns content, a guard that is never asked
# still lets the caller through. So nothing here checks AletheiaFS against
# itself. The oracle is Python written from OS_LAYERS_DESIGN.md alone
# (ChaCha20-Poly1305 per RFC 8439 and HKDF per RFC 5869, in plain Python,
# first checked against the RFC 8439 2.8.2 and RFC 5869 case 3 vectors): it
# recomputes every version and every index version the module must have
# written and compares the files on disk byte for byte, and it writes a
# whole store of its own that the module must read. A stored version is a
# random 12-byte nonce, then the bytes sealed under it, so the oracle reads
# the nonce out of each file and recomputes the ciphertext and the tag under
# it independently (the mirror must be the same bytes, and no two versions
# of an object may share a nonce); the stores it writes use os.urandom
# nonces. Each shard drives ONE
# session of a driver program (compiled once per crypt record) over
# stdin/stdout, and
# tampers with the store between operations.
# THE CRYPT RECORD. Shards A-E build the kit with CRYPT_FAST (logoscrypt.la,
# the documented drop-in for CRYPT_REF, gated by gate_logoscrypt.sh against
# CRYPT_REF itself), so every operation costs milliseconds and the gate can
# afford to probe every clause. Shard R builds the SAME driver with CRYPT_REF
# and does one round trip (put, then get) whose files the oracle checks byte
# for byte, so the module is still shown to work with the reference record.
#   R  CRYPT_REF: open, put (binary content), get; version 1 and index
#      version 1 are the oracle's stored files in both copies.
#   A  round trips: binary content (bytes 0..255), tags and owner; versions
#      1 and 2 and their prev link (the hash of the whole stored file,
#      nonce included); history; version out of range; find by tag; remove
#      (files gone, index line gone); every version and every index version
#      is the oracle's stored file, in both copies, and both heads hold n.
#      SELF-APPLICATION: the index is itself a sealed, versioned, mirrored
#      object of the store.
#   B  auto-repair, on a store the oracle wrote: a tampered newest primary,
#      with both heads damaged, is read intact (the newest version is still
#      found) and rewritten on disk; verify then repairs a deleted primary, a
#      tampered mirror and a tampered primary of the INDEX, while an object
#      whose two copies are both tampered is reported lost and left as it
#      is: the report is exactly checked/repaired/lost = 5 3 1, the repaired
#      files are the oracle's bytes again, a head naming a missing version is
#      rewritten, and get of the lost object is an error that carries no
#      bytes.
#   C  a store written entirely by the oracle (index and an object of three
#      versions whose third has a wrong prev link): find, get and version 2
#      read it, history reports "chain broken at 3"; a token that grants
#      only obj/<id> r reads but cannot update, put, find or remove; a put
#      extends the oracle's index chain byte for byte; a WRONG K_M reads
#      nothing (get, find, put and remove fail; verify reports every index
#      version lost) and changes no file.
#   D  a denying guard blocks put/get/update/history/version/find/remove,
#      each asking exactly one question; a short K_M or an uncreatable root
#      gives a handle on which everything fails; bad ids, tags and owners, a
#      failing random and an id collision are refused before anything is
#      written; the nonce a version is sealed under is the 12 bytes random
#      gives for it, and a random giving 11, 13 or 0 bytes for a nonce
#      refuses put and update with nothing written; ephemeral
#      objects round-trip (bytes 0..255) without a single file appearing,
#      their session pipe is close-on-exec, and close drops that session's
#      objects (and only that session's).
#   E  repair and failure paths, each on a store of its own: with the newest
#      index version lost in both copies, verify still walks the objects the
#      newest readable index version lists and repairs them; a put whose
#      index version reaches neither copy leaves no trace of its object, one
#      that reaches the primary keeps it and verify completes the index; a
#      repair on read whose write fails (rename onto a directory, no space)
#      returns the content, leaves no .tmp and keeps the old primary;
#      history refuses a version 1 whose prev is not "none", and a chain
#      through a version it cannot read (lost, or not a version); an authentic
#      version whose header has the wrong n= or len= is refused; remove
#      takes a crashed write's .tmp files with the object, and removes an
#      object whose mirror directory is already gone; a
#      wrong K_M's verify changes no file even where heads are stale, the
#      right one fixes them and rebuilds a missing mirror directory; an
#      ephemeral object's plaintext is not kept in memory by its handle, nor
#      the session key by the store handle (the driver's memory is scanned
#      after close and a collection), and with random failing ephemeral
#      fails closed; a stored file shorter than a nonce and a tag (27 or 5
#      bytes), or one whose nonce is flipped, is repaired from the mirror,
#      and is lost when both copies are short; a store in the old format
#      (the version number as the nonce, not stored) reads as lost, never
#      as content, and verify changes none of it; a root with a NUL byte is
#      refused.
#   N  no keystream is ever used twice, by an oracle that does not depend
#      on the layout: it knows the plaintexts it makes the module seal, so
#      two stored files of one version that XOR, at offset 0 or 12, to the
#      XOR of their plaintexts were sealed under one key and nonce. (a) a
#      rollback of both copies and both heads, then an update; (b) a crash
#      that left only 2.tmp in both copies, then an update; (c) a write that
#      fails after its bytes left the process (its .tmp a FIFO the gate
#      reads) and is retried; (d) 40 updates and three index versions: every
#      stored file opens under the nonce at its start, and all 44 nonces are
#      distinct. Against the format with the version number as the nonce,
#      all four fail.
# Every operation's guard questions are checked exactly (resource and op).
# COST. With CRYPT_FAST an operation takes milliseconds and shards A-E a few
# seconds each. With CRYPT_REF one HKDF takes 95 s or more (CRYPT_REF names
# its builtins, and each name walks the program), and every object operation
# derives its key: shard R needs three (open, put, get), about 10 minutes on a
# loaded 4-core machine, and it starts first, alongside the others. Its VM
# grows to about 1.4 GB (its two 768 MiB heap halves), as does shard E's
# (whose memory check allocates 4 GB of garbage to collect the heap over
# several times, a few seconds), so FS_PARALLEL
# (default 4) caps how many shards run at once, longest first, for a machine
# short of memory. FS_SHARDS (default "R C A B D E N") names the shards to run;
# leaving R out skips the CRYPT_REF round trip (a development shortcut; a
# plain run always includes it). FS_SHARD_TIMEOUT (default 14400 s) bounds
# each shard, FS_CMD_TIMEOUT (default 7200 s) each operation.
# CRYPT_REF's sha256 is wrong for message lengths of 55 mod 64 (see
# logoscrypt.la); shard R's oracle refuses to build a stored file of such a
# length, and every length R uses avoids it.
# ISOLATION: private temp dir (gate_wm_common.sh); everything is written
# under it.
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1
: "${FS_SHARD_TIMEOUT:=14400}"
: "${FS_CMD_TIMEOUT:=7200}"
: "${FS_PARALLEL:=4}"
: "${FS_SHARDS:=R C A B D E N}"
wm_setup aletheiafs.la logoscrypt.la crypt_ref.la sha256.la hmac.la hkdf.la aead.la chacha20.la poly1305.la

# ── the driver: one command per stdin line, one "= ok …"/"= err …" line back ──
# A command is "word slot field…" with every field hex-encoded; the policy
# guard prints each question ("guard tok res op") before answering it.
# @IMPORT@ and @CRYPT@ are filled in twice below: CRYPT_FAST and CRYPT_REF.
cat > "$T/drv.tpl" <<'LAEOF'
@IMPORT@
import("aletheiafs.la")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph NIL = la n. la c. n(n)
glyph CONS = la h. la t. la n. la c. c(h)(t)
glyph PAIR = la a. la b. la k. k(a)(b)
glyph LEN = la s. str_to_int(str_len(s))
glyph HV = la c. (la n. lt(n)(58)(la _. sub(n)(48))(la _. sub(n)(87))("!"))(str_to_int(ord(c)))
glyph UNHEX = la s. Z(la self. la i. la n.
    lt(i)(n)(la _. concat(chr(int_to_str(add(mul(HV(str_at(s)(i)))(16))(HV(str_at(s)(add(i)(1)))))))
                        (self(add(i)(2))(n)))(la _. "")("!"))(0)(LEN(s))
glyph HD = la n. str_at("0123456789abcdef")(n)
glyph HEXE = la s. Z(la self. la i. la n.
    lt(i)(n)(la _. (la b. concat(concat(HD(div(b)(16)))(HD(mod(b)(16))))(self(add(i)(1))(n)))(str_to_int(ord(str_at(s)(i)))))
      (la _. "")("!"))(0)(LEN(s))
glyph SUB = Z(la self. la s. la i. la j. lt(i)(j)(la _. concat(str_at(s)(i))(self(s)(add(i)(1))(j)))(la _. "")("!"))
glyph FIND = la s. la c. Z(la go. la i. la n. lt(i)(n)(la _. str_eq(str_at(s)(i))(c)(la _. i)(la _. go(add(i)(1))(n))("!"))(la _. n)("!"))(0)(LEN(s))
glyph SPLIT = la s. la c. (la n. Z(la go. la i. la j.
    lt(j)(n)(la _. str_eq(str_at(s)(j))(c)(la _. CONS(SUB(s)(i)(j))(go(add(j)(1))(add(j)(1))))(la _. go(i)(add(j)(1)))("!"))
            (la _. CONS(SUB(s)(i)(n))(NIL))("!"))(0)(0))(LEN(s))
glyph NTH = Z(la self. la l. la i. l(la _. "")(la h. la t. int_eq(i)(0)(la _. h)(la _. self(t)(sub(i)(1)))("!")))
glyph MAPL = Z(la self. la f. la l. l(la _. NIL)(la h. la t. CONS(f(h))(self(f)(t))))
glyph JOINC = Z(la self. la l. l(la _. "")(la h. la t. t(la _. h)(la h2. la t2. concat(h)(concat(",")(self(t))))))
glyph MEMBER = Z(la self. la x. la l. l(la _. la t. la f. f)(la h. la t. str_eq(h)(x)(la _. la t. la f. t)(la _. self(x)(t))("!")))
glyph LOOKUP = Z(la self. la k. la l. l(la _. la s. s("missing"))(la h. la t. h(la a. la b. str_eq(a)(k)(la _. b)(la _. self(k)(t))("!"))))
glyph TAGS = la s. str_eq(s)("")(la _. NIL)(la _. SPLIT(s)(","))("!")
glyph POLICY = la tok. la res. la op.
  (la _. str_eq(tok)("*")(la _. la t. la f. t)(la _. MEMBER(concat(concat(res)(":"))(op))(SPLIT(tok)(",")))("!"))
  (print(concat("guard ")(concat(tok)(concat(" ")(concat(res)(concat(" ")(op)))))))
glyph DENY = la tok. la res. la op.
  (la _. la t. la f. f)(print(concat("guard-deny ")(concat(tok)(concat(" ")(concat(res)(concat(" ")(op)))))))
# RND(n): random(n); but "" while ./badrandom exists, the bytes of
# ./fixedrandom for an id (n = 16) while it exists, and the bytes of
# ./noncerandom for a nonce (n = 12) while it exists
glyph HAS = la p. str_eq(str_at(stat(p))(0))("-")(la _. la t. la f. f)(la _. la t. la f. t)("!")
glyph RND = la n. HAS("badrandom")(la _. "")(la _.
    str_eq(n)("16")(la _. HAS("fixedrandom")(la _. read_file("fixedrandom"))(la _. random(n))("!"))(la _.
    str_eq(n)("12")(la _. HAS("noncerandom")(la _. read_file("noncerandom"))(la _. random(n))("!"))
      (la _. random(n))("!"))("!"))("!")
# CHURN(n): allocate n MiB that die at once, so that the heap is collected
# several times over (each semispace is 768 MiB) and what is not live is
# overwritten
glyph DOUBLE = Z(la self. la n. la s. int_eq(n)(0)(la _. s)(la _. self(sub(n)(1))(concat(s)(s)))("!"))
glyph CHURN = la n. (la big. Z(la go. la i. la acc.
    lt(i)(n)(la _. go(add(i)(1))(str_len(concat(big)(int_to_str(i)))))(la _. "churned")("!"))(0)("0"))(DOUBLE(20)("x"))
glyph RES = la r. la f. r(la m. concat("= err ")(m))(la v. concat("= ok ")(f(v)))
glyph STEP = la fs. la slots. la ephs. la w. la k.
  fs(la fopen. la put. la get. la update. la history. la version. la find. la verify. la remove. la ephemeral. la fclose.
  (la cmd. la s1. la a2. la a3. la a4. la a5. (la h.
    str_eq(cmd)("open")(la _. k("= ok")(CONS(PAIR(s1)(fopen(a2)(a3)(str_eq(a4)("deny")(DENY)(POLICY))))(slots))(ephs))(la _.
    str_eq(cmd)("put")(la _. k(RES(put(h)(a2)(a3)(TAGS(a4))(a5))(la id. id))(slots)(ephs))(la _.
    str_eq(cmd)("get")(la _. k(RES(get(h)(a2)(a3))(la r. r(la c. la t. la o. la n.
        concat(HEXE(c))(concat(" ")(concat(HEXE(JOINC(t)))(concat(" ")(concat(HEXE(o))(concat(" ")(int_to_str(n))))))))))
        (slots)(ephs))(la _.
    str_eq(cmd)("update")(la _. k(RES(update(h)(a2)(a3)(a4))(la n. int_to_str(n)))(slots)(ephs))(la _.
    str_eq(cmd)("history")(la _. k(RES(history(h)(a2)(a3))(la l. JOINC(MAPL(int_to_str)(l))))(slots)(ephs))(la _.
    str_eq(cmd)("version")(la _. k(RES(version(h)(a2)(a3)(str_to_int(a4)))(la c. HEXE(c)))(slots)(ephs))(la _.
    str_eq(cmd)("find")(la _. k(RES(find(h)(a2)(a3))(la l. JOINC(l)))(slots)(ephs))(la _.
    str_eq(cmd)("verify")(la _. k(RES(verify(h))(la r. r(la c. la rp. la l.
        concat(int_to_str(c))(concat(" ")(concat(int_to_str(rp))(concat(" ")(int_to_str(l))))))))(slots)(ephs))(la _.
    str_eq(cmd)("remove")(la _. k(RES(remove(h)(a2)(a3))(la id. id))(slots)(ephs))(la _.
    str_eq(cmd)("eph")(la _. ephemeral(h)(a3)(la m. k(concat("= err ")(m))(slots)(ephs))
                                            (la eh. k("= ok")(slots)(CONS(PAIR(a2)(eh))(ephs))))(la _.
    str_eq(cmd)("eread")(la _. k(LOOKUP(s1)(ephs)(la rd. RES(rd("!"))(la c. HEXE(c))))(slots)(ephs))(la _.
    str_eq(cmd)("close")(la _. k(RES(fclose(h))(la r. r))(slots)(ephs))(la _.
    str_eq(cmd)("churn")(la _. k(concat("= ok ")(CHURN(str_to_int(s1))))(slots)(ephs))(la _.
    k(concat("= err unknown command ")(cmd))(slots)(ephs))("!"))("!"))("!"))("!"))("!"))("!"))("!"))("!"))("!"))("!"))("!"))("!"))("!"))
    (LOOKUP(s1)(slots)))
  (NTH(w)(0))(NTH(w)(1))(UNHEX(NTH(w)(2)))(UNHEX(NTH(w)(3)))(UNHEX(NTH(w)(4)))(UNHEX(NTH(w)(5))))
glyph READLINE = Z(la self. la buf. la k. (la i.
    lt(i)(LEN(buf))
      (la _. k(SUB(buf)(0)(i))(SUB(buf)(add(i)(1))(LEN(buf))))
      (la _. (la more. str_eq(more)("")(la _. k("quit")(""))(la _. self(concat(buf)(more))(k))("!"))(read("0")("65536")))("!"))
  (FIND(buf)("\n")))
glyph LOOP = Z(la loop. la fs. la slots. la ephs. la buf.
  READLINE(buf)(la line. la rest. (la w.
    str_eq(NTH(w)(0))("quit")(la _. "bye")(la _.
      STEP(fs)(slots)(ephs)(w)(la out. la slots2. la ephs2. (la _. loop(fs)(slots2)(ephs2)(rest))(print(out))))("!"))
  (SPLIT(line)(" "))))
glyph MAIN = (la fs. LOOP(fs)(NIL)(NIL)(""))
  (FS_KIT(str_at)(ord)(str_len)(str_to_int)(int_to_str)(chr)(concat)(str_eq)(add)(sub)(mul)(div)(mod)(lt)(int_eq)
         (stat)(read_file)(write_file)(rename)(unlink)(mkdir)(rmdir)(pipe)(open)(close)(read)(write)
         (@CRYPT@)(RND))
LAEOF
sed -e 's/@IMPORT@/import("logoscrypt.la")/' \
    -e 's/@CRYPT@/CRYPT_FAST(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(error)(add)(sub)(mul)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr)/' \
    "$T/drv.tpl" > "$T/drv_fast.la"
sed -e 's/@IMPORT@/import("crypt_ref.la")/' -e 's/@CRYPT@/CRYPT_REF/' "$T/drv.tpl" > "$T/drv_ref.la"

# ── the oracle and the shards ───────────────────────────────────────────────
cat > "$T/fsgate.py" <<'PYEOF'
import hashlib, hmac, os, select, shutil, struct, subprocess, sys, threading, time

def _rotl(v, c): return ((v << c) & 0xffffffff) | (v >> (32 - c))
def _qr(s, a, b, c, d):
    s[a] = (s[a] + s[b]) & 0xffffffff; s[d] = _rotl(s[d] ^ s[a], 16)
    s[c] = (s[c] + s[d]) & 0xffffffff; s[b] = _rotl(s[b] ^ s[c], 12)
    s[a] = (s[a] + s[b]) & 0xffffffff; s[d] = _rotl(s[d] ^ s[a], 8)
    s[c] = (s[c] + s[d]) & 0xffffffff; s[b] = _rotl(s[b] ^ s[c], 7)
def chacha_block(key, counter, nonce):
    st = list(struct.unpack('<4I', b'expand 32-byte k')) + list(struct.unpack('<8I', key)) \
         + [counter] + list(struct.unpack('<3I', nonce))
    w = st[:]
    for _ in range(10):
        _qr(w, 0, 4, 8, 12); _qr(w, 1, 5, 9, 13); _qr(w, 2, 6, 10, 14); _qr(w, 3, 7, 11, 15)
        _qr(w, 0, 5, 10, 15); _qr(w, 1, 6, 11, 12); _qr(w, 2, 7, 8, 13); _qr(w, 3, 4, 9, 14)
    return struct.pack('<16I', *[(w[i] + st[i]) & 0xffffffff for i in range(16)])
def chacha_xor(key, counter, nonce, data):
    out = bytearray()
    for i in range(0, len(data), 64):
        out += bytes(a ^ b for a, b in zip(data[i:i + 64], chacha_block(key, counter + i // 64, nonce)))
    return bytes(out)
def poly1305(key, msg):
    r = int.from_bytes(key[:16], 'little') & 0x0ffffffc0ffffffc0ffffffc0fffffff
    s = int.from_bytes(key[16:], 'little'); p = (1 << 130) - 5; acc = 0
    for i in range(0, len(msg), 16):
        acc = (acc + int.from_bytes(msg[i:i + 16] + b'\x01', 'little')) * r % p
    return ((acc + s) & ((1 << 128) - 1)).to_bytes(16, 'little')
def _pad16(b): return b'' if len(b) % 16 == 0 else b'\x00' * (16 - len(b) % 16)
def _mac(key, nonce, aad, ct):
    return poly1305(chacha_block(key, 0, nonce)[:32],
                    aad + _pad16(aad) + ct + _pad16(ct) + struct.pack('<QQ', len(aad), len(ct)))
def seal(key, nonce, aad, pt):
    ct = chacha_xor(key, 1, nonce, pt); return ct + _mac(key, nonce, aad, ct)
def aopen(key, nonce, aad, sealed):
    if len(sealed) < 16: return None
    ct, tag = sealed[:-16], sealed[-16:]
    return chacha_xor(key, 1, nonce, ct) if hmac.compare_digest(_mac(key, nonce, aad, ct), tag) else None
def hkdf(salt, ikm, info, n):
    prk = hmac.new(salt, ikm, hashlib.sha256).digest(); out, t, i = b'', b'', 1
    while len(out) < n:
        t = hmac.new(prk, t + info + bytes([i]), hashlib.sha256).digest(); out += t; i += 1
    return out[:n]
def selftest():
    key = bytes(range(0x80, 0xa0)); nonce = bytes.fromhex('070000004041424344454647')
    aad = bytes.fromhex('50515253c0c1c2c3c4c5c6c7')
    pt = b"Ladies and Gentlemen of the class of '99: If I could offer you only one tip for the future, sunscreen would be it."
    want = bytes.fromhex(
        'd31a8d34648e60db7b86afbc53ef7ec2a4aded51296e08fea9e2b5a736ee62d63dbea45e8ca9671282fafb69da92728b'
        '1a71de0a9e060b2905d6a5b67ecd3b3692ddbd7f2d778b8c9803aee328091b58fab324e4fad675945585808b4831d7bc'
        '3ff4def08e4b7a9de576d26586cec64b61161ae10b594f09e26a7e902ecbd0600691')
    return seal(key, nonce, aad, pt) == want and aopen(key, nonce, aad, want) == pt \
        and aopen(key, nonce, aad, bytes([want[0] ^ 1]) + want[1:]) is None \
        and hkdf(b'', b'\x0b' * 22, b'', 42).hex() == \
            '8da4e775a563c18f715f802a063c5a31b8a11f5c5ee1879ec3454e5f3c738d2d9d201395faa4b61a96c8'

# ── the format, from OS_LAYERS_DESIGN.md ─────────────────────────────────────
def k_obj(km, oid): return hkdf(oid.encode(), km, b'aletheia/object', 32)
def k_idx(km): return hkdf(b'', km, b'aletheia/index', 32)
def key_of(km, oid): return k_idx(km) if oid == 'index' else k_obj(km, oid)
def aad_of(oid, n): return ('%s|%d' % (oid, n)).encode()
def plain(n, tags, owner, prev, content):
    return b'n=%d\ntags=%s\nowner=%s\nprev=%s\nlen=%d\n' % (n, b','.join(tags), owner, prev, len(content)) + content
def chain(km, oid, versions, tags, owner, links=None, nonces=None):
    """the stored files of versions 1..n: each the 12-byte nonce (nonces[i-1], or a fresh os.urandom(12)), then
    the plaintext sealed under it; prev is the hash of the whole stored file before; links[i] overrides version
    i+1's prev"""
    out, prev, k = [], b'none', key_of(km, oid)
    for i, c in enumerate(versions, 1):
        p = links[i - 1] if links and links[i - 1] is not None else prev
        nonce = nonces[i - 1] if nonces else os.urandom(12)
        f = nonce + seal(k, nonce, aad_of(oid, i), plain(i, tags, owner, p, c))
        if REF and len(f) % 64 == 55:   # CRYPT_REF's sha256 pads these lengths wrongly
            raise SystemExit('gate design: a %d-byte stored file hits CRYPT_REF sha256 at 55 mod 64' % len(f))
        out.append(f); prev = hashlib.sha256(f).hexdigest().encode()
    return out
def old_nonce(n): return n.to_bytes(12, 'little')
def write_old(root, km, oid, versions, tags, owner):
    """an object in the format before the nonce was stored: version n sealed under n as 12 little-endian bytes,
    the sealed bytes alone in the file, prev the hash of the file before"""
    prev = b'none'
    for i, c in enumerate(versions, 1):
        b = seal(key_of(km, oid), old_nonce(i), aad_of(oid, i), plain(i, tags, owner, prev, c))
        for side in ('obj', 'mirror'): wr(os.path.join(root, side, oid, str(i)), b)
        prev = hashlib.sha256(b).hexdigest().encode()
    for side in ('obj', 'mirror'): wr(os.path.join(root, side, oid, 'head'), str(len(versions)).encode())
REF = False   # True in shard R, whose driver runs CRYPT_REF
IDX_TAGS, IDX_OWNER = [b'index'], b'aletheiafs'
def line(oid, tags): return ('%s %s\n' % (oid, tags)).encode()

def rd(p):
    try: return open(p, 'rb').read()
    except OSError: return None
def wr(p, b):
    os.makedirs(os.path.dirname(p), exist_ok=True); open(p, 'wb').write(b)
def flip(p, i):
    """flip byte i of the sealed bytes of a stored version (after its 12-byte nonce)"""
    b = bytearray(open(p, 'rb').read()); b[(12 + i) % len(b)] ^= 0x01; open(p, 'wb').write(bytes(b))
def snap(*dirs):
    out = {}
    for d in dirs:
        for r, ds, fs in os.walk(d):
            for x in ds: out[os.path.join(r, x)] = 'dir'
            for x in fs:
                if x not in ('drv.err', 'session.log'): out[os.path.join(r, x)] = rd(os.path.join(r, x))
    return out
def pipe_fds(pid):
    """the pipe fds above 2 of process pid, with their open flags"""
    out = {}
    for fd in os.listdir('/proc/%d/fd' % pid):
        try:
            if int(fd) > 2 and os.readlink('/proc/%d/fd/%s' % (pid, fd)).startswith('pipe:'):
                out[int(fd)] = int([l for l in open('/proc/%d/fdinfo/%s' % (pid, fd)) if l.startswith('flags:')][0].split()[1], 8)
        except OSError:
            pass
    return out
def mem_has(pid, needles):
    """the needles that occur anywhere in the readable memory of process pid"""
    found, keep = set(), max(len(x) for x in needles) - 1
    with open('/proc/%d/mem' % pid, 'rb', 0) as m:
        for l in open('/proc/%d/maps' % pid):
            f = l.split()
            if not f[1].startswith('r'): continue
            a, b = (int(x, 16) for x in f[0].split('-'))
            tail = b''
            while a < b:
                try:
                    m.seek(a); chunk = tail + m.read(min(b - a, 1 << 26))
                except (OSError, OverflowError):
                    break
                found |= set(x for x in needles if x in chunk)
                tail, a = chunk[-keep:], a + (1 << 26)
    return found
def disk(root, km, oid, versions, tags, owner, links=None):
    """'' when obj/ and mirror/ hold exactly the oracle's stored files and both heads say n. Each version's
    nonce is read out of its primary, the file is recomputed under it (ciphertext and tag), and both copies
    must be those bytes; no two versions may share a nonce"""
    got = [rd(os.path.join(root, 'obj', oid, str(i))) for i in range(1, len(versions) + 1)]
    for i, g in enumerate(got, 1):
        if g is None or len(g) < 28: return 'obj/%s/%d is %s' % (oid, i, 'missing' if g is None else '%d bytes' % len(g))
    if len(set(g[:12] for g in got)) != len(got): return '%s: two versions share a nonce' % oid
    exp = chain(km, oid, versions, tags, owner, links, [g[:12] for g in got])
    for side in ('obj', 'mirror'):
        for i, b in enumerate(exp, 1):
            got = rd(os.path.join(root, side, oid, str(i)))
            if got != b: return '%s/%s/%d differs (%s)' % (side, oid, i, 'missing' if got is None else '%d bytes' % len(got))
        if rd(os.path.join(root, side, oid, 'head')) != str(len(exp)).encode():
            return '%s/%s/head is %r' % (side, oid, rd(os.path.join(root, side, oid, 'head')))
        extra = set(os.listdir(os.path.join(root, side, oid))) - set(['head'] + [str(i) for i in range(1, len(exp) + 1)])
        if extra: return '%s/%s holds %s' % (side, oid, sorted(extra))
    return ''
def write_raw(root, km, oid, pts):
    """an object whose version i is pts[i-1] sealed as the format says (a random nonce stored in front, AAD,
    key), whatever pts holds"""
    for i, pt in enumerate(pts, 1):
        nonce = os.urandom(12); f = nonce + seal(key_of(km, oid), nonce, aad_of(oid, i), pt)
        for side in ('obj', 'mirror'): wr(os.path.join(root, side, oid, str(i)), f)
    for side in ('obj', 'mirror'): wr(os.path.join(root, side, oid, 'head'), str(len(pts)).encode())
def write_store(root, km, oid, versions, tags, owner, links=None, nonces=None):
    """the oracle's own object, the same stored files in both copies; returns them"""
    files = chain(km, oid, versions, tags, owner, links, nonces)
    for side in ('obj', 'mirror'):
        for i, f in enumerate(files, 1):
            wr(os.path.join(root, side, oid, str(i)), f)
        wr(os.path.join(root, side, oid, 'head'), str(len(versions)).encode())
    return files

class Session:
    def __init__(self, cwd, log):
        self.err = open(os.path.join(cwd, 'drv.err'), 'wb'); self.cwd = cwd
        self.p = subprocess.Popen(['./logos_secd'], cwd=cwd, stdin=subprocess.PIPE,
                                  stdout=subprocess.PIPE, stderr=self.err)
        self.buf = b''; self.log = log; self.times = []
    def _line(self, deadline):
        while b'\n' not in self.buf:
            left = deadline - time.time()
            if left <= 0: raise TimeoutError('the driver took longer than FS_CMD_TIMEOUT')
            r, _, _ = select.select([self.p.stdout], [], [], left)
            if not r: continue
            chunk = os.read(self.p.stdout.fileno(), 65536)
            if not chunk: raise EOFError('the driver exited: ' + open(os.path.join(self.cwd, 'drv.err'), 'rb').read()[-300:].decode('latin-1'))
            self.buf += chunk
        l, self.buf = self.buf.split(b'\n', 1)
        return l.decode('latin-1')
    def cmd(self, word, slot='-', *fields, limit=None):
        enc = [f.hex() if isinstance(f, bytes) else f.encode().hex() for f in fields]
        t0 = time.time()
        self.p.stdin.write((' '.join([word, slot] + enc) + '\n').encode()); self.p.stdin.flush()
        guards, deadline = [], t0 + (limit or float(os.environ.get('FS_CMD_TIMEOUT', '3600')))
        while True:
            l = self._line(deadline)
            if l.startswith('= '):
                dt = time.time() - t0; self.times.append((word, dt, l.startswith('= ok')))
                self.log.write('%-8s %7.1fs  %s\n' % (word, dt, l[:120])); self.log.flush()
                return guards, l[2:]
            guards.append(l)
    def quit(self):
        try:
            self.p.stdin.write(b'quit\n'); self.p.stdin.flush(); self.p.wait(60)
        except Exception:
            self.p.kill(); self.p.wait()
        return self.p.returncode

OUT = []
def check(label, cond, detail=''):
    OUT.append(('PASS  ' if cond else 'FAIL  ') + 'aletheiafs: ' + label + ('' if cond else '  [' + str(detail)[:300] + ']'))
def G(tok, res, op): return ['guard %s %s %s' % (tok, res, op)]
def isid(r): return r.startswith('ok ') and len(r) == 35 and all(c in '0123456789abcdef' for c in r[3:])
def getok(content, tags, owner, n): return 'ok %s %s %s %d' % (content.hex(), b','.join(tags).hex(), owner.hex(), n)

# ── R: one round trip with CRYPT_REF, checked byte for byte ─────────────────
def shard_r(d, s):
    global REF
    REF = True
    root = os.path.join(d, 'store'); km = bytes(range(60, 92))
    g, r = s.cmd('open', 'r', root, km, 'policy')
    check('R (CRYPT_REF) open creates the store', r == 'ok' and os.path.isdir(root + '/obj') and os.path.isdir(root + '/mirror'), r)
    C, T, O = bytes(range(256)), [b'ref', b'record'], b'crypt_ref'
    g, r = s.cmd('put', 'r', '*', C, 'ref,record', 'crypt_ref')
    check('R (CRYPT_REF) put -> ok(id), asking for obj w', isid(r) and g == G('*', 'obj', 'w'), (r, g))
    oid = r[3:]
    check('R (CRYPT_REF) version 1 and index version 1 are the oracle\'s stored files in both copies, heads 1',
          disk(root, km, oid, [C], T, O) == '' and disk(root, km, 'index', [line(oid, 'ref,record')], IDX_TAGS, IDX_OWNER) == '',
          disk(root, km, oid, [C], T, O) + disk(root, km, 'index', [line(oid, 'ref,record')], IDX_TAGS, IDX_OWNER))
    g, r = s.cmd('get', 'r', '*', oid)
    check('R (CRYPT_REF) get round-trips the content (bytes 0..255), tags, owner and n = 1',
          r == getok(C, T, O, 1) and g == G('*', 'obj/' + oid, 'r'), (r[:120], g))

# ── A: round trips, versions, history, find, remove, the index object ───────
def shard_a(d, s):
    root = os.path.join(d, 'store'); km = bytes(range(100, 132))
    g, r = s.cmd('open', 'a', root, km, 'policy')
    check('A open creates the store (obj/ and mirror/)', r == 'ok' and g == [] and os.path.isdir(root + '/obj') and os.path.isdir(root + '/mirror'), r)
    P1, T1, O1 = bytes(range(256)), [b'alpha', b'beta'], b'alice'
    g, r = s.cmd('put', 'a', '*', P1, 'alpha,beta', 'alice')
    check('A put -> ok(id), a 32-character lowercase hex id', isid(r), r)
    check('A put asks the guard exactly for obj w', g == G('*', 'obj', 'w'), g)
    id1 = r[3:]; V1 = [P1]
    check('A put writes version 1 to obj/ and mirror/, each byte for byte the oracle\'s stored file '
          '(a 12-byte nonce, then the bytes sealed under it with K_O = hkdf(id)(K_M)("aletheia/object") and AAD id|1, '
          'the n/tags/owner/prev/len header; the oracle recomputes ciphertext and tag under the nonce it reads)',
          disk(root, km, id1, V1, T1, O1) == '', disk(root, km, id1, V1, T1, O1))
    IX = [line(id1, 'alpha,beta')]
    check('A SELF-APPLICATION: the index is a sealed object of the store, version 1 under hkdf("")(K_M)("aletheia/index"), '
          'mirrored, listing the new id with its tags', disk(root, km, 'index', [IX[0]], IDX_TAGS, IDX_OWNER) == '',
          disk(root, km, 'index', [IX[0]], IDX_TAGS, IDX_OWNER))
    g, r = s.cmd('get', 'a', '*', id1)
    check('A get round-trips binary content (bytes 0..255), tags, owner and n = 1', r == getok(P1, T1, O1, 1), r[:120])
    check('A get asks the guard exactly for obj/<id> r', g == G('*', 'obj/' + id1, 'r'), g)
    g, r = s.cmd('update', 'a', '*', id1, b'second version')
    check('A update -> ok(2), asking for obj/<id> w', r == 'ok 2' and g == G('*', 'obj/' + id1, 'w'), (r, g))
    V1 = [P1, b'second version']
    check('A version 2 keeps the tags and owner and chains prev = hex sha256 of version 1\'s whole stored file '
          '(its nonce included), under a nonce of its own, in both copies, heads 2',
          disk(root, km, id1, V1, T1, O1) == '', disk(root, km, id1, V1, T1, O1))
    g, r = s.cmd('history', 'a', '*', id1)
    check('A history -> ok(1,2), asking for obj/<id> r', r == 'ok 1,2' and g == G('*', 'obj/' + id1, 'r'), (r, g))
    rs = [s.cmd('version', 'a', '*', id1, n) for n in ('3', '0')]
    check('A version 3 and version 0 -> no such version (asking for obj/<id> r)',
          rs == [(G('*', 'obj/' + id1, 'r'), 'err no such version')] * 2, rs)
    P2, T2, O2 = b'hello\n', [b'beta'], b'bob'
    g, r = s.cmd('put', 'a', '*', P2, 'beta', 'bob'); id2 = r[3:]
    IX.append(IX[0] + line(id2, 'beta'))
    check('A a second put appends to the index: index version 2 chains to version 1, byte for byte',
          isid(r) and disk(root, km, 'index', IX, IDX_TAGS, IDX_OWNER) == '' and disk(root, km, id2, [P2], T2, O2) == '',
          (r, disk(root, km, 'index', IX, IDX_TAGS, IDX_OWNER)))
    f = [s.cmd('find', 'a', '*', t) for t in ('beta', 'alpha', 'gamma')]
    check('A find by tag -> the ids whose newest version has it, in index order (beta: both, alpha: one, gamma: none)',
          [x[1] for x in f] == ['ok %s,%s' % (id1, id2), 'ok ' + id1, 'ok '], [x[1] for x in f])
    check('A find asks the guard exactly for obj r', all(x[0] == G('*', 'obj', 'r') for x in f), [x[0] for x in f])
    g, r = s.cmd('remove', 'a', '*', id1)
    IX.append(line(id2, 'beta'))
    check('A remove -> ok(id), asking for obj/<id> w; obj/<id> and mirror/<id> are gone',
          r == 'ok ' + id1 and g == G('*', 'obj/' + id1, 'w') and not os.path.exists(root + '/obj/' + id1)
          and not os.path.exists(root + '/mirror/' + id1), (r, g))
    check('A remove writes index version 3 without the line, chained; the other object is untouched',
          disk(root, km, 'index', IX, IDX_TAGS, IDX_OWNER) == '' and disk(root, km, id2, [P2], T2, O2) == '',
          disk(root, km, 'index', IX, IDX_TAGS, IDX_OWNER))
    rs = [s.cmd('get', 'a', '*', id1)[1], s.cmd('history', 'a', '*', id1)[1], s.cmd('remove', 'a', '*', id1)[1],
          s.cmd('find', 'a', '*', 'beta')[1]]
    check('A after remove: get, history and remove -> no such object; find beta -> only the other id',
          rs == ['err no such object'] * 3 + ['ok ' + id2], rs)

# ── B: auto-repair on read and verify ───────────────────────────────────────
def shard_b(d, s):
    root = os.path.join(d, 'store'); km = bytes(range(140, 172))
    # the store comes from the oracle: two objects (2 versions and 1), two index versions
    id1, id2 = os.urandom(16).hex(), os.urandom(16).hex()
    Q, TQ, OQ = [b'repair me: version one', b'repair me: version two'], [b'r1'], b'carol'
    R, TR, OR = [b'the other object'], [b'r2'], b'dave'
    IX = [line(id1, 'r1')]; IX.append(IX[0] + line(id2, 'r2'))
    exp = write_store(root, km, id1, Q, TQ, OQ); write_store(root, km, id2, R, TR, OR)
    write_store(root, km, 'index', IX, IDX_TAGS, IDX_OWNER)
    s.cmd('open', 'b', root, km, 'policy')
    P = lambda side, oid, n: os.path.join(root, side, oid, str(n))
    flip(P('obj', id1, 2), 7)
    wr(os.path.join(root, 'obj', id1, 'head'), b'1'); os.unlink(os.path.join(root, 'mirror', id1, 'head'))
    g, r = s.cmd('get', 'b', '*', id1)
    check('B a tampered newest primary, with obj/<id>/head left at 1 (as after a crash before the head was written) '
          'and mirror/<id>/head deleted: get still finds version 2 and returns it intact', r == getok(Q[1], TQ, OQ, 2), r)
    check('B ... and get rewrote the primary on disk with the authenticated mirror (auto-repair)',
          rd(P('obj', id1, 2)) == exp[1], len(rd(P('obj', id1, 2)) or b''))
    os.unlink(P('obj', id1, 1))                    # a deleted primary
    flip(P('mirror', id1, 2), 3)                   # a tampered mirror
    flip(P('obj', 'index', 2), 20)                 # a tampered primary of the INDEX
    flip(P('obj', id2, 1), 9); flip(P('mirror', id2, 1), 30)   # id2: both copies tampered
    wr(os.path.join(root, 'obj', id1, 'head'), b'7')            # a head naming no version (the mirror's is gone)
    bad2 = (rd(P('obj', id2, 1)), rd(P('mirror', id2, 1)))
    g, r = s.cmd('verify', 'b')
    check('B verify -> checked 5 (2 index + 2 + 1), repaired 3, lost 1, asking the guard nothing',
          r == 'ok 5 3 1' and g == [], (r, g))
    check('B verify rebuilt the deleted primary and the tampered mirror (each from the other copy) and the INDEX\'s '
          'tampered primary (self-application: the index is repaired like any object), with the oracle\'s bytes; '
          'both heads say 2 again',
          disk(root, km, id1, Q, TQ, OQ) == '' and disk(root, km, 'index', IX, IDX_TAGS, IDX_OWNER) == '',
          disk(root, km, id1, Q, TQ, OQ) + disk(root, km, 'index', IX, IDX_TAGS, IDX_OWNER))
    check('B verify left both copies of the lost version exactly as they were (nothing is repaired from nothing)',
          (rd(P('obj', id2, 1)), rd(P('mirror', id2, 1))) == bad2)
    g, r = s.cmd('get', 'b', '*', id2)
    check('B get of the lost object is an error and carries no bytes', r == 'err lost: version 1', r)

# ── C: an oracle-written store; grants; a wrong K_M ─────────────────────────
def shard_c(d, s):
    root = os.path.join(d, 'store'); km = bytes(range(180, 212)); kw = bytes(range(181, 213))
    id3 = os.urandom(16).hex()
    V = [b'written by the oracle, v1', b'written by the oracle, v2', b'v3 links to v1, not v2']
    N3 = [os.urandom(12) for _ in V]   # chosen first, so that version 3 can link to the stored version 1
    b1 = chain(km, id3, V[:1], [b'oracle'], b'python', None, N3[:1])[0]
    links = [None, None, hashlib.sha256(b1).hexdigest().encode()]
    write_store(root, km, id3, V, [b'oracle'], b'python', links, N3)
    IX = [line(id3, 'oracle')]
    write_store(root, km, 'index', IX, IDX_TAGS, IDX_OWNER)
    s.cmd('open', 'c', root, km, 'policy')
    rtok = 'obj/%s:r' % id3
    g, r = s.cmd('find', 'c', 'obj:r', 'oracle')
    check('C find reads an index the oracle wrote', r == 'ok ' + id3 and g == G('obj:r', 'obj', 'r'), (r, g))
    g, r = s.cmd('get', 'c', rtok, id3)
    check('C get reads an object the oracle wrote (the format agrees both ways), with a token granting only obj/<id> r',
          r == getok(V[2], [b'oracle'], b'python', 3) and g == G(rtok, 'obj/' + id3, 'r'), (r, g))
    g, r = s.cmd('history', 'c', rtok, id3)
    check('C history -> chain broken at 3 (version 3\'s prev is the hash of version 1, not of version 2)',
          r == 'err chain broken at 3', r)
    g, r = s.cmd('version', 'c', rtok, id3, '2')
    check('C version 2 of the oracle\'s object', r == 'ok ' + V[1].hex(), r)
    before = snap(root)
    rs = [s.cmd('update', 'c', rtok, id3, b'x'), s.cmd('put', 'c', rtok, b'x', 't', 'o'),
          s.cmd('find', 'c', rtok, 'oracle'), s.cmd('remove', 'c', rtok, id3)]
    check('C that token cannot update, put, find or remove: each is denied, naming the resource and op it asked for',
          [x[1] for x in rs] == ['err denied: obj/%s w' % id3, 'err denied: obj w', 'err denied: obj r', 'err denied: obj/%s w' % id3]
          and [x[0] for x in rs] == [G(rtok, 'obj/' + id3, 'w'), G(rtok, 'obj', 'w'), G(rtok, 'obj', 'r'), G(rtok, 'obj/' + id3, 'w')],
          rs)
    check('C ... and the refused operations changed nothing on disk', snap(root) == before)
    g, r = s.cmd('put', 'c', 'obj:w', b'added by LogOS', 'oracle', 'erin'); id4 = r[3:]
    IX.append(IX[0] + line(id4, 'oracle'))
    check('C a put into the oracle\'s store extends the oracle\'s index chain byte for byte',
          isid(r) and disk(root, km, 'index', IX, IDX_TAGS, IDX_OWNER) == ''
          and disk(root, km, id4, [b'added by LogOS'], [b'oracle'], b'erin') == '',
          (r, disk(root, km, 'index', IX, IDX_TAGS, IDX_OWNER)))
    before = snap(root)
    s.cmd('open', 'w', root, kw, 'policy')
    rs = [s.cmd('get', 'w', '*', id3)[1], s.cmd('find', 'w', '*', 'oracle')[1],
          s.cmd('put', 'w', '*', b'x', 't', 'o')[1], s.cmd('remove', 'w', '*', id3)[1], s.cmd('verify', 'w')[1]]
    check('C a wrong K_M reads nothing: get, find, put and remove fail; verify reports both index versions lost',
          rs == ['err lost: version 3', 'err index: lost: version 2',
                 'err index: lost: version 2', 'err index: lost: version 2', 'ok 2 0 2'], rs)
    check('C ... and with the wrong K_M not one file was written, changed or removed', snap(root) == before)

# ── D: a denying guard, bad handles, bad input, ephemeral objects ───────────
def shard_d(d, s):
    root = os.path.join(d, 'store'); km = bytes(range(220, 252))
    idd = os.urandom(16).hex()
    write_store(root, km, idd, [b'guarded'], [b'g'], b'o')
    write_store(root, km, 'index', [line(idd, 'g')], IDX_TAGS, IDX_OWNER)
    before = snap(root)
    s.cmd('open', 'd', root, km, 'deny')
    rs = [s.cmd('put', 'd', 'T', b'x', 'g', 'o'), s.cmd('get', 'd', 'T', idd), s.cmd('update', 'd', 'T', idd, b'x'),
          s.cmd('history', 'd', 'T', idd), s.cmd('version', 'd', 'T', idd, '1'), s.cmd('find', 'd', 'T', 'g'),
          s.cmd('remove', 'd', 'T', idd)]
    want = [('obj', 'w'), ('obj/' + idd, 'r'), ('obj/' + idd, 'w'), ('obj/' + idd, 'r'), ('obj/' + idd, 'r'),
            ('obj', 'r'), ('obj/' + idd, 'w')]
    check('D a denying guard blocks put, get, update, history, version, find and remove, each asked exactly once',
          [x[1] for x in rs] == ['err denied: %s %s' % w for w in want]
          and [x[0] for x in rs] == [['guard-deny T %s %s' % w] for w in want], rs)
    check('D ... and nothing on disk changed', snap(root) == before)
    short = os.path.join(d, 'short')
    s.cmd('open', 's', short, bytes(31), 'policy')
    rs = [s.cmd('put', 's', '*', b'x', 'g', 'o'), s.cmd('get', 's', '*', idd), s.cmd('find', 's', '*', 'g'),
          s.cmd('verify', 's'), s.cmd('eph', 's', 'e0', b'x'), s.cmd('close', 's')]
    check('D a 31-byte K_M gives a handle on which every operation fails, without asking the guard',
          all(x == ([], 'err open: K_M must be 32 bytes') for x in rs), rs)
    s.cmd('open', 'n', '/nonexistent-aletheiafs/x', km, 'policy')
    r = s.cmd('get', 'n', '*', idd)
    check('D an uncreatable root gives a handle whose operations fail', r == ([], 'err open: cannot create /nonexistent-aletheiafs/x'), r)
    root2 = os.path.join(d, 'store2')
    s.cmd('open', 'p', root2, km, 'policy')
    empty = snap(root2)
    rs = [s.cmd('get', 'p', '*', b'../../etc/passwd'), s.cmd('get', 'p', '*', idd.upper()), s.cmd('get', 'p', '*', idd[:31]),
          s.cmd('get', 'p', '*', '../' + idd[3:]), s.cmd('history', 'p', '*', 'index'), s.cmd('remove', 'p', '*', '')]
    check('D ids that are not 32 lowercase hex characters (a path, upper case, 31 characters, a 32-character "../" path, '
          'the index\'s own name, nothing) are refused before the guard is asked',
          all(x == ([], 'err bad id') for x in rs), rs)
    rs = [s.cmd('put', 'p', '*', b'x', 'a,,b', 'o')[1], s.cmd('put', 'p', '*', b'x', 'a\nb', 'o')[1],
          s.cmd('put', 'p', '*', b'x', 'a', 'o\nwner')[1], s.cmd('find', 'p', '*', 'a,b')[1]]
    check('D an empty tag, a tag with a newline, an owner with a newline and a find for "a,b" are refused',
          rs == ['err bad tag', 'err bad tag', 'err bad owner', 'err bad tag'], rs)
    wr(os.path.join(d, 'badrandom'), b'')
    r = s.cmd('put', 'p', '*', b'x', 'a', 'o')[1]
    os.unlink(os.path.join(d, 'badrandom'))
    check('D when random returns nothing, put fails closed ("random failed")', r == 'err random failed', r)
    R = os.urandom(16); rid = R.hex(); wr(os.path.join(d, 'fixedrandom'), R)
    os.makedirs(os.path.join(root2, 'obj', rid)); r1 = s.cmd('put', 'p', '*', b'x', 'a', 'o')[1]
    os.rmdir(os.path.join(root2, 'obj', rid))
    os.makedirs(os.path.join(root2, 'mirror', rid)); r2 = s.cmd('put', 'p', '*', b'x', 'a', 'o')[1]
    os.rmdir(os.path.join(root2, 'mirror', rid)); os.unlink(os.path.join(d, 'fixedrandom'))
    check('D a new id that already names a primary or a mirror directory is refused ("id collision")',
          r1 == r2 == 'err id collision', (r1, r2))
    check('D ... and none of the refused puts wrote anything', snap(root2) == empty)
    tree = snap(d)
    E1, E2 = bytes(range(256)), b'a second session'
    rs = [s.cmd('eph', 'p', 'e1', E1)[1], s.cmd('eph', 'd', 'e2', E2)[1], s.cmd('eread', 'e1')[1], s.cmd('eread', 'e2')[1]]
    check('D ephemeral objects round-trip (bytes 0..255), on two sessions', rs == ['ok', 'ok', 'ok ' + E1.hex(), 'ok ' + E2.hex()], rs)
    check('D ... and not one file appeared or changed anywhere (the store, the second store, the working directory)',
          snap(d) == tree, sorted(set(snap(d)) ^ set(tree)))
    pid = s.p.pid; pipes = []
    for fd in os.listdir('/proc/%d/fd' % pid):
        try:
            if int(fd) > 2 and os.readlink('/proc/%d/fd/%s' % (pid, fd)).startswith('pipe:'):
                fl = [l for l in open('/proc/%d/fdinfo/%s' % (pid, fd)) if l.startswith('flags:')][0]
                pipes.append(int(fl.split()[1], 8) & 0o2000000 != 0)
        except OSError:
            pass
    check('D each session\'s key pipe is close-on-exec (two open sessions: four pipe ends, all O_CLOEXEC)',
          pipes == [True] * 4, pipes)
    rs = [s.cmd('close', 'p')[1], s.cmd('eread', 'e1')[1], s.cmd('eph', 'p', 'e3', b'x')[1], s.cmd('eread', 'e2')[1],
          s.cmd('close', 'p')[1], s.cmd('close', 'd')[1], s.cmd('eread', 'e2')[1]]
    check('D close drops that session\'s ephemeral objects (and makes new ones impossible), not another session\'s',
          rs == ['ok ' + root2, 'err ephemeral: session closed', 'err ephemeral: session closed', 'ok ' + E2.hex(),
                 'ok ' + root2, 'ok ' + root, 'err ephemeral: session closed'], rs)
    # the nonce is random's: with random giving 12 bytes the gate chose for a
    # nonce, put's object version and its index version start with them and
    # are sealed under them; with random giving 11, 13 or 0 bytes for a
    # nonce, put and update are refused and nothing is written. (Last in the
    # shard, after the pipe check: this opens a third session.)
    root3, NZ = os.path.join(d, 'store3'), os.urandom(12)
    s.cmd('open', 'r', root3, km, 'policy')
    wr(os.path.join(d, 'noncerandom'), NZ)
    r = s.cmd('put', 'r', '*', b'sealed under the nonce the gate chose', 'z', 'o')[1]; idz = r[3:]
    os.unlink(os.path.join(d, 'noncerandom'))
    heads = [(rd(os.path.join(root3, side, o, '1')) or b'')[:12] for o in (idz, 'index') for side in ('obj', 'mirror')]
    check('D the nonce a version is sealed under is the 12 bytes random gives for it: with random giving 12 bytes the '
          'gate chose, the object version and the index version put writes start with them, in both copies, and are '
          'the oracle\'s stored files under them',
          isid(r) and heads == [NZ] * 4 and disk(root3, km, idz, [b'sealed under the nonce the gate chose'], [b'z'], b'o') == ''
          and disk(root3, km, 'index', [line(idz, 'z')], IDX_TAGS, IDX_OWNER) == '',
          (r, [h.hex() for h in heads], disk(root3, km, idz, [b'sealed under the nonce the gate chose'], [b'z'], b'o')))
    before3, rs = snap(root3), []
    for bad in (os.urandom(11), os.urandom(13), b''):
        wr(os.path.join(d, 'noncerandom'), bad)
        rs += [s.cmd('put', 'r', '*', b'x', 'z', 'o')[1], s.cmd('update', 'r', '*', idz, b'x')[1]]
        os.unlink(os.path.join(d, 'noncerandom'))
    check('D a random that gives 11, 13 or 0 bytes for a nonce refuses put and update ("random failed"), and not one '
          'file or directory is left written', rs == ['err random failed'] * 6 and snap(root3) == before3,
          (rs, sorted(set(snap(root3)) ^ set(before3))))

# ── E: repair and failure paths, each on a store of its own ────────────────
def shard_e(d, s):
    km = bytes(range(30, 62))
    V = lambda root, side, oid, n: os.path.join(root, side, oid, str(n))
    # the newest index version lost in both copies: verify still walks the
    # objects that the newest READABLE index version lists
    root = os.path.join(d, 'lostidx')
    ida, idb = os.urandom(16).hex(), os.urandom(16).hex()
    QA, QB = [b'listed by both index versions'], [b'listed only by the lost one']
    IX = [line(ida, 'a')]; IX.append(IX[0] + line(idb, 'b'))
    write_store(root, km, ida, QA, [b'a'], b'o'); write_store(root, km, idb, QB, [b'b'], b'o')
    write_store(root, km, 'index', IX, IDX_TAGS, IDX_OWNER)
    flip(V(root, 'obj', 'index', 2), 5); flip(V(root, 'mirror', 'index', 2), 9)
    flip(V(root, 'obj', ida, 1), 11)
    lost = (rd(V(root, 'obj', 'index', 2)), rd(V(root, 'mirror', 'index', 2)))
    s.cmd('open', 'i', root, km, 'policy')
    g, r = s.cmd('verify', 'i')
    check('E with the newest index version lost in both copies, verify still walks every object the newest READABLE index '
          'version lists: checked 3 (2 index + 1), repaired 1, lost 1', r == 'ok 3 1 1', r)
    check('E ... it rebuilt that object\'s tampered primary with the oracle\'s bytes, and left the lost index version as it was',
          disk(root, km, ida, QA, [b'a'], b'o') == '' and (rd(V(root, 'obj', 'index', 2)), rd(V(root, 'mirror', 'index', 2))) == lost,
          disk(root, km, ida, QA, [b'a'], b'o'))
    # a put whose new index version reaches neither copy leaves nothing of
    # the object behind; one whose index version reaches the primary keeps
    # it (the index lists it) and verify completes the index
    root = os.path.join(d, 'noidx')
    s.cmd('open', 'n', root, km, 'policy')
    os.makedirs(os.path.join(root, 'obj', 'index', '1.tmp'))   # index version 1 cannot be written
    R = os.urandom(16); rid = R.hex(); wr(os.path.join(d, 'fixedrandom'), R)
    g, r = s.cmd('put', 'n', '*', b'never listed', 't', 'o')
    os.unlink(os.path.join(d, 'fixedrandom')); shutil.rmtree(os.path.join(root, 'obj', 'index', '1.tmp'), True)
    left = sorted(p for p, v in snap(root).items() if v != 'dir')
    check('E a put whose index version cannot be written fails ("write failed: <that version>") and leaves nothing of '
          'the object behind: no obj/<id>, no mirror/<id>, not one file in the store',
          r == 'err write failed: %s/obj/index/1' % root and not os.path.exists(os.path.join(root, 'obj', rid))
          and not os.path.exists(os.path.join(root, 'mirror', rid)) and left == [], (r, left))
    root = os.path.join(d, 'halfidx')
    s.cmd('open', 'h', root, km, 'policy')
    os.makedirs(os.path.join(root, 'mirror', 'index', '1.tmp'))  # only the index's mirror cannot be written
    R = os.urandom(16); rid = R.hex(); wr(os.path.join(d, 'fixedrandom'), R)
    g, r = s.cmd('put', 'h', '*', b'listed by the primary', 't', 'o')
    os.unlink(os.path.join(d, 'fixedrandom')); shutil.rmtree(os.path.join(root, 'mirror', 'index', '1.tmp'), True)
    IXH = [line(rid, 't')]
    ix1 = rd(os.path.join(root, 'obj', 'index', '1')) or b''
    check('E a put whose index version reaches the primary but not the mirror fails, and keeps the object it lists',
          r == 'err write failed: %s/mirror/index/1' % root and disk(root, km, rid, [b'listed by the primary'], [b't'], b'o') == ''
          and len(ix1) >= 28 and ix1 == chain(km, 'index', IXH, IDX_TAGS, IDX_OWNER, None, [ix1[:12]])[0],
          (r, disk(root, km, rid, [b'listed by the primary'], [b't'], b'o')))
    g, r = s.cmd('verify', 'h')
    check('E ... and verify completes the index (checked 2, repaired 1, lost 0)',
          r == 'ok 2 1 0' and disk(root, km, 'index', IXH, IDX_TAGS, IDX_OWNER) == '', (r, disk(root, km, 'index', IXH, IDX_TAGS, IDX_OWNER)))
    # a repair on read whose write fails still returns the authenticated
    # content and leaves nothing behind: no .tmp, and the primary is not
    # replaced. One object's primary path is a directory (the rename fails);
    # the other's primary is tampered and its .tmp is /dev/full (the write
    # runs out of space)
    root = os.path.join(d, 'badwrite')
    idg, idf = os.urandom(16).hex(), os.urandom(16).hex()
    write_store(root, km, idg, [b'the rename fails'], [b'g'], b'o'); write_store(root, km, idf, [b'the disk is full'], [b'f'], b'o')
    os.unlink(V(root, 'obj', idg, 1)); os.mkdir(V(root, 'obj', idg, 1))
    flip(V(root, 'obj', idf, 1), 4); bad = rd(V(root, 'obj', idf, 1))
    os.symlink('/dev/full', V(root, 'obj', idf, 1) + '.tmp')
    s.cmd('open', 'w', root, km, 'policy')
    rs = [s.cmd('get', 'w', '*', idg)[1], s.cmd('get', 'w', '*', idf)[1]]
    lg, lf = sorted(os.listdir(os.path.join(root, 'obj', idg))), sorted(os.listdir(os.path.join(root, 'obj', idf)))
    check('E a repair on read whose write fails (a rename onto a directory; a write out of space) still returns the '
          'mirror\'s content, leaves no .tmp behind and does not replace the primary',
          rs == [getok(b'the rename fails', [b'g'], b'o', 1), getok(b'the disk is full', [b'f'], b'o', 1)]
          and lg == lf == ['1', 'head'] and os.path.isdir(V(root, 'obj', idg, 1))
          and not os.path.islink(V(root, 'obj', idf, 1)) and rd(V(root, 'obj', idf, 1)) == bad,
          (rs, lg, lf, os.path.islink(V(root, 'obj', idf, 1))))
    # history checks version 1's link too: its prev must be "none"
    root = os.path.join(d, 'v1prev')
    idp = os.urandom(16).hex()
    write_store(root, km, idp, [b'version 1 links to something', b'version 2'], [b'p'], b'o',
                [hashlib.sha256(b'no such version').hexdigest().encode(), None])
    s.cmd('open', 'p', root, km, 'policy')
    g, r = s.cmd('history', 'p', '*', idp)
    check('E history -> chain broken at 1 when version 1\'s prev is a hash, not "none"', r == 'err chain broken at 1', r)
    # history cannot vouch for a chain through a version it cannot read: a
    # version lost in both copies, or one that authenticates but does not
    # parse, breaks the chain there (it does not end the list early)
    root = os.path.join(d, 'histgap')
    idx2, idy2 = os.urandom(16).hex(), os.urandom(16).hex()
    write_store(root, km, idx2, [b'one', b'two, lost', b'three'], [b'h'], b'o')
    flip(V(root, 'obj', idx2, 2), 6); flip(V(root, 'mirror', idx2, 2), 7)
    write_raw(root, km, idy2, [plain(1, [b'h'], b'o', b'none', b'one'), b'not a header'])
    s.cmd('open', 'g', root, km, 'policy')
    rs = [s.cmd('history', 'g', '*', idx2)[1], s.cmd('history', 'g', '*', idy2)[1]]
    check('E history -> chain broken at 2 when version 2 is lost in both copies, and when it authenticates but is '
          'not a version', rs == ['err chain broken at 2'] * 2, rs)
    # remove takes a crashed write's leftovers with the object: the .tmp of
    # the version after the newest, and the heads' .tmp, in both copies
    root = os.path.join(d, 'leftovers')
    idr = os.urandom(16).hex()
    write_store(root, km, idr, [b'one', b'two'], [b'r'], b'o'); write_store(root, km, 'index', [line(idr, 'r')], IDX_TAGS, IDX_OWNER)
    for side in ('obj', 'mirror'):
        wr(V(root, side, idr, 3) + '.tmp', b'half a version'); wr(os.path.join(root, side, idr, 'head.tmp'), b'3')
    s.cmd('open', 'l', root, km, 'policy')
    g, r = s.cmd('remove', 'l', '*', idr)
    check('E remove of an object that has a crashed write\'s leftovers (a version\'s .tmp, the heads\' .tmp) removes them '
          'with it', r == 'ok ' + idr and not os.path.exists(os.path.join(root, 'obj', idr))
          and not os.path.exists(os.path.join(root, 'mirror', idr)), r)
    # remove of an object one of whose copies is already gone (its whole
    # mirror directory lost) still removes it, and its index line
    root = os.path.join(d, 'halfgone')
    idq = os.urandom(16).hex()
    write_store(root, km, idq, [b'only the primary is left'], [b'q'], b'o'); write_store(root, km, 'index', [line(idq, 'q')], IDX_TAGS, IDX_OWNER)
    shutil.rmtree(os.path.join(root, 'mirror', idq))
    s.cmd('open', 'k', root, km, 'policy')
    rs = [s.cmd('remove', 'k', '*', idq)[1], s.cmd('find', 'k', '*', 'q')[1]]
    check('E remove of an object whose mirror directory is already gone -> ok(id), the primary is gone and find no longer '
          'lists it', rs == ['ok ' + idq, 'ok '] and not os.path.exists(os.path.join(root, 'obj', idq)), rs)
    # a version that authenticates but whose header is not the format (n=
    # not its number, len= not its content's length) is refused, not read
    root = os.path.join(d, 'badhdr')
    idn, idl = os.urandom(16).hex(), os.urandom(16).hex()
    write_raw(root, km, idn, [plain(2, [b't'], b'o', b'none', b'content')])
    write_raw(root, km, idl, [b'n=1\ntags=t\nowner=o\nprev=none\nlen=3\ncontent'])
    s.cmd('open', 'm', root, km, 'policy')
    rs = [s.cmd('get', 'm', '*', idn)[1], s.cmd('get', 'm', '*', idl)[1]]
    check('E an authentic version whose header says n=2 for version 1, or len=3 for 7 bytes of content, is refused '
          '("malformed version 1")', rs == ['err malformed version 1'] * 2, rs)
    # a wrong K_M authenticates nothing, so verify changes no file, even on a
    # store whose index heads are stale (as after a crash before a head write)
    root = os.path.join(d, 'staleheads')
    ids = os.urandom(16).hex()
    IXS = [line(ids, 's')] * 2
    write_store(root, km, ids, [b'one'], [b's'], b'o'); write_store(root, km, 'index', IXS, IDX_TAGS, IDX_OWNER)
    wr(os.path.join(root, 'obj', 'index', 'head'), b'1'); os.unlink(os.path.join(root, 'mirror', 'index', 'head'))
    before = snap(root)
    s.cmd('open', 'x', root, bytes(range(31, 63)), 'policy')
    g, r = s.cmd('verify', 'x')
    check('E with a wrong K_M, verify of a store whose index heads are stale reports both index versions lost and '
          'changes no file', r == 'ok 2 0 2' and snap(root) == before, (r, sorted(set(snap(root).items()) ^ set(before.items()))))
    shutil.rmtree(os.path.join(root, 'mirror', ids))
    s.cmd('open', 'y', root, km, 'policy')
    g, r = s.cmd('verify', 'y')
    check('E ... while with the right K_M, verify of that store fixes both index heads and rebuilds the object\'s whole '
          'missing mirror directory (checked 3, repaired 1, lost 0)',
          r == 'ok 3 1 0' and disk(root, km, 'index', IXS, IDX_TAGS, IDX_OWNER) == '' and disk(root, km, ids, [b'one'], [b's'], b'o') == '',
          (r, disk(root, km, 'index', IXS, IDX_TAGS, IDX_OWNER) + disk(root, km, ids, [b'one'], [b's'], b'o')))
    # a stored file too short to hold a nonce and a tag (12 + 16 bytes) does
    # not authenticate, like any damaged copy: get repairs it from the mirror
    # (and nothing halts on a nonce cut short); so does a file whose nonce is
    # flipped (the sealed bytes intact); with both copies short the version
    # is lost and both are left as they are
    root = os.path.join(d, 'short')
    i27, i5, inon, iboth = [os.urandom(16).hex() for _ in range(4)]
    SC = lambda oid: b'short files: ' + oid.encode()
    files = dict((oid, write_store(root, km, oid, [SC(oid)], [b's'], b'o')) for oid in (i27, i5, inon, iboth))
    def cut(side, oid, n): open(V(root, side, oid, 1), 'wb').write(files[oid][0][:n])
    cut('obj', i27, 27); cut('obj', i5, 5); cut('obj', iboth, 27); cut('mirror', iboth, 11)
    b = bytearray(files[inon][0]); b[0] ^= 0x01; open(V(root, 'obj', inon, 1), 'wb').write(bytes(b))
    s.cmd('open', 'o', root, km, 'policy')
    rs = [s.cmd('get', 'o', '*', oid)[1] for oid in (i27, i5, inon, iboth)]
    check('E a primary cut to 27 bytes (one short of a nonce and a tag), one cut to 5 (shorter than a nonce) and one '
          'whose first nonce byte is flipped do not authenticate: get returns each from its mirror and rewrites the '
          'primary with the oracle\'s bytes',
          rs[:3] == [getok(SC(oid), [b's'], b'o', 1) for oid in (i27, i5, inon)]
          and all(rd(V(root, 'obj', oid, 1)) == files[oid][0] for oid in (i27, i5, inon)), rs[:3])
    check('E ... and with both copies short (27 and 11 bytes) get is "lost: version 1", both left as they were',
          rs[3] == 'err lost: version 1' and rd(V(root, 'obj', iboth, 1)) == files[iboth][0][:27]
          and rd(V(root, 'mirror', iboth, 1)) == files[iboth][0][:11], rs[3])
    # a store in the format before the nonce was stored (version n sealed
    # under n as 12 little-endian bytes, the sealed bytes alone in the file)
    # is not misread: every version is lost, and verify changes nothing
    root = os.path.join(d, 'oldformat')
    ido = os.urandom(16).hex()
    write_old(root, km, ido, [b'old format, version 1', b'old format, version 2'], [b'old'], b'o')
    write_old(root, km, 'index', [line(ido, 'old')], IDX_TAGS, IDX_OWNER)
    before = snap(root)
    s.cmd('open', 'f', root, km, 'policy')
    rs = [s.cmd('get', 'f', '*', ido)[1], s.cmd('version', 'f', '*', ido, '1')[1], s.cmd('history', 'f', '*', ido)[1],
          s.cmd('find', 'f', '*', 'old')[1], s.cmd('update', 'f', '*', ido, b'x')[1], s.cmd('verify', 'f')[1]]
    check('E a store in the old format (the version number as the nonce, nothing stored before the sealed bytes) reads '
          'as lost, never as content: get, version 1, history, find and update fail, verify reports its index version '
          'lost (checked 1, repaired 0, lost 1), and not one file changed',
          rs == ['err lost: version 2', 'err lost: version 1', 'err chain broken at 1', 'err index: lost: version 1',
                 'err lost: version 2', 'ok 1 0 1'] and snap(root) == before, rs)
    # an ephemeral object lives in memory only sealed: once its session is
    # closed and the heap has been collected, its plaintext is nowhere in the
    # process although its handle is still held, while the store handle's
    # K_M, which is meant to stay live, is found (so the scan sees live data)
    # The session key is read out of the new session's pipe (and put back)
    # through /proc, so that it too can be looked for: once the session is
    # closed it must be unreachable, though the store handle is still held.
    root, kq, X = os.path.join(d, 'eph'), os.urandom(32), os.urandom(64)
    pipes0 = pipe_fds(s.p.pid)
    rs = [s.cmd('open', 'q', root, kq, 'policy')[1]]
    new = dict((fd, fl) for fd, fl in pipe_fds(s.p.pid).items() if fd not in pipes0)
    rfd = [fd for fd, fl in new.items() if fl & 3 == 0]; wfd = [fd for fd, fl in new.items() if fl & 3 == 1]
    def peek():   # what the session pipe holds, put back as it was
        if len(rfd) != 1 or len(wfd) != 1: return b''
        fr = os.open('/proc/%d/fd/%d' % (s.p.pid, rfd[0]), os.O_RDONLY | os.O_NONBLOCK)
        try: got = os.read(fr, 64)
        except BlockingIOError: got = b''
        os.close(fr)
        fw = os.open('/proc/%d/fd/%d' % (s.p.pid, wfd[0]), os.O_WRONLY); os.write(fw, got); os.close(fw)
        return got
    SK = peek()
    rs += [s.cmd('eph', 'q', 'ex', X)[1], s.cmd('eread', 'ex')[1], s.cmd('close', 'q')[1]]
    after = peek()
    rs += [s.cmd('eread', 'ex')[1], s.cmd('churn', '4000')[1]]
    found = mem_has(s.p.pid, [X, kq, SK or b'(no key)'])
    check('E once its session is closed and the heap collected, an ephemeral object\'s plaintext is nowhere in the '
          'process, though its handle is still held; the store handle\'s K_M (live) is found',
          rs == ['ok', 'ok', 'ok ' + X.hex(), 'ok ' + root, 'err ephemeral: session closed', 'ok churned']
          and X not in found and kq in found, (rs[3:], 'plaintext found' if X in found else '', 'K_M found' if kq in found else 'K_M not found'))
    check('E close takes the session key out of its pipe: the pipe then holds exactly "closed"', after == b'closed', after)
    check('E ... and the session key (read from its pipe before close) is nowhere in the process either, though the '
          'store handle that opened the session is still held',
          len(SK) == 32 and SK not in found, (len(SK), 'session key found' if SK in found else ''))
    # with random failing, ephemeral fails closed instead of sealing under a
    # nonce that is not random (the same one every time)
    s.cmd('open', 'v', os.path.join(d, 'ephrand'), km, 'policy')
    wr(os.path.join(d, 'badrandom'), b'')
    rs = [s.cmd('eph', 'v', 'ev1', b'first')[1], s.cmd('eph', 'v', 'ev2', b'second')[1]]
    os.unlink(os.path.join(d, 'badrandom'))
    check('E when random returns nothing, ephemeral fails closed ("random failed")', rs == ['err random failed'] * 2, rs)
    # a root with a NUL byte in it names a different directory to every
    # syscall (the path ends at the NUL): open must refuse it, not open the
    # truncated directory and then loop forever probing versions that all
    # "exist" there. LAST in the shard: a module that hangs here leaves the
    # driver busy.
    root = (os.path.join(d, 'wanted') + '\x00elsewhere').encode()
    try:
        rs = [s.cmd('open', 'z', root, km, 'policy', limit=60)[1], s.cmd('put', 'z', '*', b'x', 't', 'o', limit=60)[1],
              s.cmd('get', 'z', '*', os.urandom(16).hex(), limit=60)[1]]
    except TimeoutError:
        rs = ['(the driver hung)']
    check('E a root with a NUL byte gives a handle on which every operation fails at once ("open: root has a NUL byte"), '
          'and nothing is created at the path it would be cut to',
          rs == ['ok', 'err open: root has a NUL byte', 'err open: root has a NUL byte']
          and not os.path.exists(os.path.join(d, 'wanted')), (rs, os.path.exists(os.path.join(d, 'wanted'))))

# ── N: no two sealings of a version share a keystream ──────────────────────
# The oracle knows every plaintext it makes the module seal (the header and
# the content), so it can tell keystream reuse without knowing the layout:
# two stored files sealed under one key and one nonce XOR, over the sealed
# bytes, to the XOR of their plaintexts. Both places the sealed bytes can
# start are tried, offset 0 (the nonce not stored) and offset 12 (a 12-byte
# nonce in front); equality at either is reuse.
def xor(a, b): return bytes(x ^ y for x, y in zip(a, b))
def reuse(fa, fb, pa, pb):
    """the offsets (0, 12) at which the stored files fa and fb XOR to the XOR of the plaintexts pa and pb"""
    L = min(len(pa), len(pb)); want = xor(pa[:L], pb[:L])
    return [o for o in (0, 12) if fa is not None and fb is not None and len(fa) >= o + L and len(fb) >= o + L
            and xor(fa[o:o + L], fb[o:o + L]) == want]
def shard_n(d, s):
    km = bytes(range(70, 102)); TN, ON = [b'n'], b'nonce'
    VP = lambda root, side, oid, n: os.path.join(root, side, oid, str(n))
    SIDES = ('obj', 'mirror')
    def pt(root, oid, n, content):
        """version n's plaintext; its prev is the hash of version n-1's stored file, as it is on disk"""
        prev = b'none' if n == 1 else hashlib.sha256(rd(VP(root, 'obj', oid, n - 1)) or b'').hexdigest().encode()
        return plain(n, TN, ON, prev, content)
    def both(root, oid, n): return dict((side, rd(VP(root, side, oid, n))) for side in SIDES)
    C1 = b'version one, never touched: ' + bytes(range(32, 96))
    CA = b'the first version 2, sealed and then undone: ' + bytes(range(96, 160))
    CB = b'the second version 2, sealed after that, with ' + bytes(range(160, 224))
    # (a) a rollback of both copies and both heads
    root = os.path.join(d, 'rollback'); s.cmd('open', 'a', root, km, 'policy')
    r0 = s.cmd('put', 'a', '*', C1, 'n', 'nonce')[1]; oid = r0[3:]
    r1 = s.cmd('update', 'a', '*', oid, CA)[1]
    old, pa = both(root, oid, 2), pt(root, oid, 2, CA)
    for side in SIDES:
        if os.path.exists(VP(root, side, oid, 2)): os.unlink(VP(root, side, oid, 2))
        wr(os.path.join(root, side, oid, 'head'), b'1')
    r2 = s.cmd('update', 'a', '*', oid, CB)[1]
    new, pb = both(root, oid, 2), pt(root, oid, 2, CB)
    r3 = s.cmd('get', 'a', '*', oid)[1]
    hits = ['%s@%d' % (side, o) for side in SIDES for o in reuse(old[side], new[side], pa, pb)]
    check('N (a) ROLLBACK: after put, update to version 2, both copies of version 2 deleted and both heads rolled back '
          'to 1, an update with other content seals version 2 again, but not under the same keystream (in neither '
          'copy do the old and new version 2 XOR to the XOR of their plaintexts, at offset 0 or 12)',
          isid(r0) and r1 == 'ok 2' and r2 == 'ok 2' and r3 == getok(CB, TN, ON, 2) and not hits,
          ('keystream reused: ' + ' '.join(hits)) if hits else (r0, r1, r2, r3[:80]))
    # (b) a crash that left only <n>.tmp in both copies, the heads not yet written
    root = os.path.join(d, 'crash'); s.cmd('open', 'b', root, km, 'policy')
    r0 = s.cmd('put', 'b', '*', C1, 'n', 'nonce')[1]; oid = r0[3:]
    r1 = s.cmd('update', 'b', '*', oid, CA)[1]
    old, pa = both(root, oid, 2), pt(root, oid, 2, CA)
    for side in SIDES:
        if os.path.exists(VP(root, side, oid, 2)): os.rename(VP(root, side, oid, 2), VP(root, side, oid, 2) + '.tmp')
        wr(os.path.join(root, side, oid, 'head'), b'1')
    r2 = s.cmd('update', 'b', '*', oid, CB)[1]
    new, pb = both(root, oid, 2), pt(root, oid, 2, CB)
    r3 = s.cmd('get', 'b', '*', oid)[1]
    hits = ['%s@%d' % (side, o) for side in SIDES for o in reuse(old[side], new[side], pa, pb)]
    check('N (b) CRASH: with version 2 left only as 2.tmp in both copies and both heads at 1 (a crash before the '
          'renames), an update with other content seals version 2 again, but not under the same keystream as the '
          'crashed write (in neither copy, at offset 0 or 12)',
          isid(r0) and r1 == 'ok 2' and r2 == 'ok 2' and r3 == getok(CB, TN, ON, 2) and not hits,
          ('keystream reused: ' + ' '.join(hits)) if hits else (r0, r1, r2, r3[:80]))
    # (c) a failed write that is retried. obj/<id>/2.tmp is a symlink to a
    # FIFO that the gate reads: the module's write goes through it to the
    # gate (its bytes have left the process, as on a disk that filled up
    # after the write), its size check then sees a FIFO and refuses it, and
    # the update fails. The retry with other content must not reuse the
    # failed write's keystream. (No privilege needed.)
    root = os.path.join(d, 'retry'); s.cmd('open', 'c', root, km, 'policy')
    r0 = s.cmd('put', 'c', '*', C1, 'n', 'nonce')[1]; oid = r0[3:]
    fifo, tmp = os.path.join(d, 'retry.fifo'), VP(root, 'obj', oid, 2) + '.tmp'
    os.mkfifo(fifo); os.symlink(fifo, tmp); got = []
    def drain():
        f = os.open(fifo, os.O_RDONLY); buf = b''
        while True:
            c = os.read(f, 65536)
            if not c: break
            buf += c
        os.close(f); got.append(buf)
    th = threading.Thread(target=drain, daemon=True); th.start()
    try:
        r1 = s.cmd('update', 'c', '*', oid, CA, limit=120)[1]
    except TimeoutError:
        r1 = '(the driver hung)'
    th.join(10)
    if not got:   # release the reader if nothing ever opened the FIFO
        try: os.close(os.open(fifo, os.O_WRONLY | os.O_NONBLOCK))
        except OSError: pass
    pa = pt(root, oid, 2, CA)
    if os.path.lexists(tmp): os.unlink(tmp)
    os.unlink(fifo)
    r2 = s.cmd('update', 'c', '*', oid, CB)[1]
    new, pb = rd(VP(root, 'obj', oid, 2)), pt(root, oid, 2, CB)
    r3 = s.cmd('get', 'c', '*', oid)[1]
    hits = (['@%d' % o for o in reuse(got[0], new, pa, pb)] if got and got[0] else ['(nothing came through the FIFO)'])
    check('N (c) RETRY: version 2\'s first write fails after its bytes have left the process (its .tmp is a FIFO the '
          'gate reads, so the size check refuses it: "write failed"), and the update is retried with other content: '
          'the failed write and the new version 2 were not sealed under the same keystream (at offset 0 or 12)',
          isid(r0) and r1 == 'err write failed: ' + VP(root, 'obj', oid, 2) and r2 == 'ok 2'
          and r3 == getok(CB, TN, ON, 2) and not hits,
          ('keystream reused: ' + ' '.join(hits)) if hits and hits[0].startswith('@') else (hits, r0, r1, r2, r3[:80]))
    # (d) 40 updates of one object, and the index versions of a put and a
    # remove: every stored file is a nonce, then the bytes sealed under it,
    # and no nonce occurs twice
    root = os.path.join(d, 'many'); s.cmd('open', 'd', root, km, 'policy')
    r0 = s.cmd('put', 'd', '*', C1, 'n', 'nonce')[1]; oid = r0[3:]
    rs = [s.cmd('update', 'd', '*', oid, b'update %02d: ' % i + bytes(range(i, i + 40)))[1] for i in range(40)]
    rp = s.cmd('put', 'd', '*', b'a second object', 'n', 'nonce')[1]; oid2 = rp[3:]
    rr = s.cmd('remove', 'd', '*', oid2)[1]
    files = [(o, n, side, rd(VP(root, side, o, n))) for o, top in ((oid, 41), ('index', 3))
             for n in range(1, top + 1) for side in SIDES]
    unopened = ['%s/%s/%d' % (side, o[:6], n) for o, n, side, f in files
                if f is None or len(f) < 28 or aopen(key_of(km, o), f[:12], aad_of(o, n), f[12:]) is None]
    nonces = [f[:12] for o, n, side, f in files if side == 'obj' and f is not None]
    check('N (d) 40 updates of one object, and the index versions of a put and a remove: every stored file of every '
          'version (41 object and 3 index versions, both copies) opens under the 12-byte nonce stored at its start, '
          'and the 44 nonces are all distinct',
          isid(r0) and rs == ['ok %d' % i for i in range(2, 42)] and isid(rp) and rr == 'ok ' + oid2
          and not unopened and len(set(nonces)) == len(nonces) == 44,
          ('%d of %d stored files do not open under a nonce stored at their start: %s' % (len(unopened), len(files), ' '.join(unopened[:4])))
          if unopened else ('%d distinct nonces of %d' % (len(set(nonces)), len(nonces)), r0, rs[-1:], rp, rr))

if __name__ == '__main__':
    which, d = sys.argv[1], sys.argv[2]
    if which == 'selftest':
        print('PASS  aletheiafs: the oracle reproduces RFC 8439 2.8.2 (seal, open, a flipped bit refused) and RFC 5869 case 3'
              if selftest() else 'FAIL  aletheiafs: the oracle does not reproduce its RFC vectors'); sys.exit(0)
    log = open(os.path.join(d, 'session.log'), 'w')
    s = Session(d, log)
    try:
        {'R': shard_r, 'A': shard_a, 'B': shard_b, 'C': shard_c, 'D': shard_d, 'E': shard_e, 'N': shard_n}[which](d, s)
        rc = s.quit()
        err = open(os.path.join(d, 'drv.err'), 'rb').read()
        check('%s the driver ran to the end: exit 0, nothing on stderr' % which, rc == 0 and err == b'', (rc, err[-200:]))
    except (EOFError, TimeoutError, OSError, SystemExit) as e:
        check('%s the session ran to the end' % which, False, e); s.p.kill()
    with open(os.path.join(d, 'result.txt'), 'w') as f:
        f.write(''.join(l + '\n' for l in OUT))
    with open(os.path.join(d, 'times.txt'), 'w') as f:
        f.write(''.join('%s %.1f\n' % (w, t) for w, t, good in s.times if good))
PYEOF

r=$(python3 "$T/fsgate.py" selftest "$T"); echo "$r"; case "$r" in PASS*) ;; *) ok=0 ;; esac

# compile each driver once: CRYPT_FAST always, CRYPT_REF when shard R runs
compile() {  # compile SRC.la OUT.bin
    cp "$T/$1" "$T/logos_source.la"; cp "$T/compiler.bin" "$T/logos_program.bin"
    ( cd "$T" && timeout "$WM_VM_TIMEOUT" ./logos_secd >/dev/null 2>"$T/dce" ) \
        || { echo "FAIL  aletheiafs: the driver $1 did not compile"; tail -3 "$T/dce"; exit 1; }
    cp "$T/logos_program.bin" "$T/$2"
}
s=$(date +%s); compile drv_fast.la prog_fast.bin; COMPILE_S="fast $(( $(date +%s) - s ))s"
case " $FS_SHARDS " in *" R "*)
    s=$(date +%s); compile drv_ref.la prog_ref.bin; COMPILE_S="$COMPILE_S, ref $(( $(date +%s) - s ))s" ;;
esac

# longest first, at most FS_PARALLEL at a time
running=0
for sh in $FS_SHARDS; do
    if [ "$running" -ge "$FS_PARALLEL" ]; then wait -n; running=$((running - 1)); fi
    prog=prog_fast.bin; [ "$sh" = R ] && prog=prog_ref.bin
    mkdir -p "$T/s$sh"
    ( cd "$T/s$sh" && cp "$T/logos_secd" . && cp "$T/$prog" logos_program.bin \
      && s=$(date +%s) && FS_CMD_TIMEOUT=$FS_CMD_TIMEOUT timeout "$FS_SHARD_TIMEOUT" python3 "$T/fsgate.py" "$sh" "$T/s$sh"; \
      echo $? > rc; echo $(( $(date +%s) - s )) > secs ) &
    running=$((running + 1))
done
wait

for sh in R A B C D E N; do
    case " $FS_SHARDS " in *" $sh "*) ;; *) continue ;; esac
    d="$T/s$sh"
    if [ -s "$d/result.txt" ]; then cat "$d/result.txt"; grep -q '^FAIL' "$d/result.txt" && ok=0
    else echo "FAIL  aletheiafs: shard $sh produced no results (rc $(cat "$d/rc" 2>/dev/null); 124 = FS_SHARD_TIMEOUT)"; ok=0; fi
done

# measured times (wall, per operation as the harness saw it, including the driver's hex coding)
python3 - "$T" "$COMPILE_S" <<'PYEOF'
import sys, os
T, cs = sys.argv[1], sys.argv[2]
def times(shards):
    ts = {}
    for sh in shards:
        try:
            for l in open(os.path.join(T, 's' + sh, 'times.txt')):
                w, t = l.split(); ts.setdefault(w, []).append(float(t))
        except OSError: pass
    return ', '.join('%s %.2fs' % (w, sorted(v)[len(v) // 2]) for w, v in sorted(ts.items()) if w in
                     ('open', 'put', 'get', 'update', 'history', 'version', 'find', 'verify', 'remove', 'eph', 'eread', 'close'))
secs = ' '.join('%s %ss' % (sh, open(os.path.join(T, 's' + sh, 'secs')).read().strip()) for sh in 'RABCDEN'
                if os.path.exists(os.path.join(T, 's' + sh, 'secs')))
print('TIME  driver compile %s; shards (parallel): %s' % (cs, secs))
print('TIME  per operation, median wall time of the calls that returned ok, as the harness saw them (with the driver\'s hex coding):')
print('TIME    CRYPT_FAST (A-E, N): ' + times('ABCDEN'))
if os.path.exists(os.path.join(T, 'sR', 'times.txt')):
    print('TIME    CRYPT_REF (R): ' + times('R'))
PYEOF
[ "$ok" = 1 ] || exit 1
