#!/usr/bin/env bash
# gate_logossession.sh — LogosSession (logossession.la) against known answers
# and an independent oracle, on the native VM.
#
# WHAT IT GUARDS. A session manager fails quietly: a wrong passphrase that
# gets in, a "locked" session that still holds the keys, two users who can
# read each other's objects, a key derivation that round-trips through its
# own code but is not the one the contract names. So nothing here checks the
# module against itself. The oracle is Python written from OS_LAYERS_DESIGN.md
# alone: hashlib's pbkdf2_hmac, hmac and HKDF (RFC 5869) recompute every key
# the contract derives from a passphrase, logossec's token construction is
# recomputed with hmac, and ChaCha20-Poly1305 (RFC 8439, in plain Python,
# first checked against RFC 8439 2.8.2) opens the user's AletheiaFS objects
# on disk with the K_M it derives itself.
#   P  PBKDF2-HMAC-SHA256 (RFC 8018), the module's PBKDF2_KIT, against the
#      RFC 6070 inputs with SHA-256 (the published answers, each confirmed by
#      hashlib.pbkdf2_hmac), RFC 7914 section 11's first vector (two blocks),
#      a key longer than the HMAC block, an empty password, and dklen 1 and 33
#      (a cut final block); iter 0 halts loudly.
#   A  accounts, keys, lock, the guard adapter and isolation: adduser writes
#      exactly the record format (salt, iter, verifier = hashlib's), mode
#      0600 in a 0700 directory, holding neither the passphrase nor K_U (nor
#      the stretch, K_M or the capability root), raw or in hex; adduser
#      refuses an existing user or home, bad names, an empty passphrase, a
#      root with a NUL, a failing random and a leftover .tmp, writing
#      nothing; login gives the oracle's root token (so K_U, and the
#      capability root under it, are the contract's derivations) and a
#      record of the session; objects it puts open under the oracle's K_M; a
#      wrong passphrase, a missing user and every malformed record are
#      refused; the iteration count is read from the record (an oracle-made
#      record with iter=7 logs in); lock drops the keys (the locked value
#      gives no view, no object, no guard, and the session's ephemeral
#      objects can no longer be opened) and unlock restores the same session
#      (the same record and token, the objects readable again), refusing a
#      wrong passphrase; THE GUARD ADAPTER: every refusal logossec's verify
#      can give (bad signature, forged, malformed, caveats not met, an
#      unknown caveat, a bad resource or op, an expired until) is FALSE and
#      only ok is TRUE, the until caveat is checked against the real clock,
#      and a clock that cannot be read denies everything; ISOLATION both
#      ways between two users with the SAME passphrase: different salts and
#      keys, neither's tokens verify under the other's capability root (as a
#      guard question and as a refused store operation), and neither can
#      open the other's objects even when they are copied into its store.
#   S  suspend and resume, and SELF-APPLICATION: suspend stores the state as
#      one sealed object of the user's own store (the oracle opens it with
#      the K_M it derives) holding the session manager's own record of the
#      session (id, user, since, suspends) and then the state byte for byte,
#      nothing of either on disk in the clear, and returns a locked
#      session; resume returns the state and a session whose record is the
#      restored one (the same id and since, unlike a fresh login); a second
#      suspend is version 2, chained; resume refuses a wrong passphrase, a
#      user with nothing suspended, eight saved sessions the oracle seals
#      correctly but that name another user or are malformed, and two
#      objects with the tag (so does suspend).
# ISOLATION: private temp dir (gate_wm_common.sh); everything is written
# under it. SESSION_SHARDS (default "P A S") names the shards to run, one at
# a time; SESSION_CMD_TIMEOUT (default 1800 s) bounds each operation and
# SESSION_SHARD_TIMEOUT (default 7200 s) each shard.
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1
: "${SESSION_SHARDS:=P A S}"
: "${SESSION_CMD_TIMEOUT:=1800}"
: "${SESSION_SHARD_TIMEOUT:=7200}"
wm_setup logossession.la logoscrypt.la logossec.la aletheiafs.la

# ── the driver: one command per stdin line, one "= ok …"/"= err …" line back ──
# A command is "word slot field…" with every field hex-encoded. Before its
# answer the driver prints "time <µs>", the operation's own time on the
# monotonic clock (the decoding of the command is not counted).
cat > "$T/drv.la" <<'LAEOF'
import("logoscrypt.la")
import("logossec.la")
import("aletheiafs.la")
import("logossession.la")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph NIL = la n. la c. n(n)
glyph CONS = la h. la t. la n. la c. c(h)(t)
glyph PAIR = la a. la b. la k. k(a)(b)
# DKIT: the driver's own string work, built once, kit style (naming a
# builtin at run time walks the whole program, so a per-byte loop that
# names them makes every command slow)
#   -> la k. k(len)(slice)(unhex)(fields)(nth)(find)
glyph DKIT = la str_at. la ord. la str_to_int. la int_to_str. la chr. la concat. la str_eq. la str_len.
    la add. la sub. la mul. la div. la lt. la int_eq. la fix.
  (la C0. la C1. la C2. la C16. la C48. la C58. la C87.
   (la len. (la slice. (la hv. (la find.
     la k. k(len)(slice)
       (la s. fix(la go. la i. la j. lt(add(i)(C1))(j)
                 (la _. (la m. concat(go(i)(m))(go(m)(j)))(add(i)(div(sub(j)(i))(C2))))
                 (la _. lt(i)(j)(la _. (la p. chr(int_to_str(add(mul(hv(str_at(s)(p)))(C16))(hv(str_at(s)(add(p)(C1)))))))(add(i)(i)))
                                (la _. "")(C0))(C0))(C0)(div(len(s))(C2)))
       (la s. la c. (la n. fix(la go. la i. (la j. (la hd. (la tl. la nn. la cc. cc(hd)(tl))
                                 (lt(j)(n)(la _. go(add(j)(C1)))(la _. la n2. la c2. n2(n2))(C0)))(slice(s)(i)(j)))
                               (find(s)(n)(c)(i)))(C0))(len(s)))
       (fix(la nth. la l. la i. l(la _. "")(la h. la t. int_eq(i)(C0)(la _. h)(la _. nth(t)(sub(i)(C1)))(C0))))
       (find))
     (fix(la find. la s. la n. la c. la i. lt(i)(n)(la _. str_eq(str_at(s)(i))(c)(la _. i)(la _. find(s)(n)(c)(add(i)(C1)))(C0))(la _. n)(C0))))
     (la c. (la n. lt(n)(C58)(la _. sub(n)(C48))(la _. sub(n)(C87))(C0))(str_to_int(ord(c)))))
     (fix(la slice. la s. la i. la j. lt(add(i)(C1))(j)(la _. (la m. concat(slice(s)(i)(m))(slice(s)(m)(j)))(add(i)(div(sub(j)(i))(C2))))
                                    (la _. lt(i)(j)(la _. str_at(s)(i))(la _. "")(C0))(C0))))
     (la s. str_to_int(str_len(s))))
  (0)(1)(2)(16)(48)(58)(87)
glyph JOINC = Z(la self. la l. l(la _. "")(la h. la t. t(la _. h)(la h2. la t2. concat(h)(concat(",")(self(t))))))
# slots: a list of PAIR(name)(value). SETK drops the old binding (it would
# otherwise stay reachable, and with it a session's keys)
glyph LOOKUP = Z(la self. la k. la l. la dflt. l(la _. dflt)(la h. la t. h(la a. la b. str_eq(a)(k)(la _. b)(la _. self(k)(t)(dflt))("!"))))
glyph DROPK = Z(la self. la k. la l. l(la _. NIL)(la h. la t. h(la a. la b. str_eq(a)(k)(la _. self(k)(t))(la _. CONS(h)(self(k)(t)))("!"))))
glyph SETK = la k. la v. la l. CONS(PAIR(k)(v))(DROPK(k)(l))
# a slot that holds nothing is a locked session of nobody
glyph MISSING = la o. la l. l("missing")("/nonexistent")(la k. k("")("missing")(0)(0))
glyph NOEPH = la s. s(la _. la e. la o. e("no such handle"))
# random fails while ./badrandom exists; the clock while ./badclock exists
glyph RND = la n. str_eq(str_at(stat("badrandom"))(0))("-")(la _. random(n))(la _. "")("!")
glyph CLK = la id. str_eq(str_at(stat("badclock"))(0))("-")(la _. clock_gettime(id))(la _. "-22")("!")
# CHURN(n): allocate n MiB that die at once, so that the heap is collected
# several times over (each semispace is 768 MiB) and what is not live is
# overwritten
glyph DOUBLE = Z(la self. la n. la s. int_eq(n)(0)(la _. s)(la _. self(sub(n)(1))(concat(s)(s)))("!"))
glyph CHURN = la n. (la big. Z(la go. la i. la acc.
    lt(i)(n)(la _. go(add(i)(1))(str_len(concat(big)(int_to_str(i)))))(la _. "churned")("!"))(0)("0"))(DOUBLE(20)("x"))
glyph RES = la r. la f. r(la m. concat("= err ")(m))(la v. concat("= ok ")(f(v)))
glyph VIEW = la r. la f. r(la m. concat("= err ")(m))(la v. v(f))
glyph CR = CRYPT_FAST(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(error)(add)(sub)(mul)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr)
glyph STEP = la K. la FK. la PB. la D. la HEXE. la slots. la ephs. la w. la k0.
  K(la adduser. la login. la lock. la unlock. la suspend. la resume. la state. la logout.
  FK(la fopen. la fput. la fget. la fupdate. la fhistory. la fversion. la ffind. la fverify. la fremove. la fephemeral. la fclose.
  D(la len. la slice. la unhex. la fields. la nth. la find.
  (la now.
  (la cmd. la s1. la a2. la a3. la a4. la a5. (la cur. (la t0. (la k. (la same. (la fail.
    str_eq(cmd)("pbkdf2")(la _. same(concat("= ok ")(HEXE(PB(a2)(a3)(str_to_int(a4))(str_to_int(a5))))))(la _.
    str_eq(cmd)("adduser")(la _. same(RES(adduser(a2)(a3)(a4))(la n. n)))(la _.
    str_eq(cmd)("login")(la _. login(a2)(a3)(a4)(fail)(la x. k("= ok")(SETK(s1)(x)(slots))(ephs)))(la _.
    str_eq(cmd)("lock")(la _. k("= ok")(SETK(s1)(lock(cur))(slots))(ephs))(la _.
    str_eq(cmd)("unlock")(la _. unlock(cur)(a2)(fail)(la x. k("= ok")(SETK(s1)(x)(slots))(ephs)))(la _.
    str_eq(cmd)("suspend")(la _. suspend(cur)(a2)(fail)(la x. k("= ok")(SETK(s1)(x)(slots))(ephs)))(la _.
    str_eq(cmd)("resume")(la _. resume(a2)(a3)(a4)(fail)
                                 (la p. p(la x. la st. k(concat("= ok ")(HEXE(st)))(SETK(s1)(x)(slots))(ephs))))(la _.
    str_eq(cmd)("state")(la _. same(VIEW(state(cur))(la name. la h. la tok. la g. la rec.
         concat("= ok ")(concat(HEXE(name))(concat(" ")(concat(HEXE(tok))(concat(" ")(HEXE(rec)))))))))(la _.
    str_eq(cmd)("logout")(la _. k(RES(logout(cur))(la n. n))(DROPK(s1)(slots))(ephs))(la _.
    str_eq(cmd)("drop")(la _. k("= ok")(DROPK(s1)(slots))(ephs))(la _.
    str_eq(cmd)("guard")(la _. same(VIEW(state(cur))(la name. la h. la tok. la g. la rec.
         concat("= ok ")(g(a2)(a3)(a4)("T")("F")))))(la _.
    str_eq(cmd)("put")(la _. same(VIEW(state(cur))(la name. la h. la tok. la g. la rec.
         RES(fput(h)(a2)(a3)(str_eq(a4)("")(la _. NIL)(la _. fields(a4)(","))("!"))(name))(la id. id))))(la _.
    str_eq(cmd)("get")(la _. same(VIEW(state(cur))(la name. la h. la tok. la g. la rec.
         RES(fget(h)(a2)(a3))(la r. r(la c. la t. la o. la n.
           concat(HEXE(c))(concat(" ")(concat(HEXE(JOINC(t)))(concat(" ")(concat(HEXE(o))(concat(" ")(int_to_str(n))))))))))))(la _.
    str_eq(cmd)("eph")(la _. state(cur)(fail)(la v. v(la name. la h. la tok. la g. la rec.
         fephemeral(h)(a3)(fail)(la eh. k("= ok")(slots)(SETK(a2)(eh)(ephs))))))(la _.
    str_eq(cmd)("eread")(la _. same(RES(LOOKUP(s1)(ephs)(NOEPH)(la rd. rd("!")))(la c. HEXE(c))))(la _.
    str_eq(cmd)("churn")(la _. same(concat("= ok ")(CHURN(str_to_int(s1)))))(la _.
    same(concat("= err unknown command ")(cmd)))("!"))("!"))("!"))("!"))("!"))("!"))("!"))("!"))("!"))("!"))("!"))("!"))("!"))("!"))("!"))("!"))
    (la m. k(concat("= err ")(m))(slots)(ephs)))
    (la out. k(out)(slots)(ephs)))
    (la out. la sl. la ep. (la _. k0(out)(sl)(ep))(print(concat("time ")(int_to_str(sub(now("!"))(t0)))))))
    (now("!")))
    (LOOKUP(s1)(slots)(MISSING)))
  (nth(w)(0))(nth(w)(1))(unhex(nth(w)(2)))(unhex(nth(w)(3)))(unhex(nth(w)(4)))(unhex(nth(w)(5))))
  # now(_): the monotonic clock in microseconds
  (la _. (la t. (la n. (la sp. add(mul(str_to_int(slice(t)(0)(sp)))(1000000))(div(str_to_int(slice(t)(add(sp)(1))(n)))(1000)))
                 (find(t)(n)(" ")(0)))(len(t)))(clock_gettime("1"))))))
glyph READLINE = la D. D(la len. la slice. la unhex. la fields. la nth. la find.
  Z(la self. la buf. la k. (la n. (la i.
    lt(i)(n)
      (la _. k(slice(buf)(0)(i))(slice(buf)(add(i)(1))(n)))
      (la _. (la more. str_eq(more)("")(la _. k("quit")(""))(la _. self(concat(buf)(more))(k))("!"))(read("0")("65536")))("!"))
    (find(buf)(n)("\n")(0)))(len(buf))))
glyph LOOP = Z(la loop. la K. la FK. la PB. la D. la HEXE. la slots. la ephs. la buf.
  READLINE(D)(buf)(la line. la rest. D(la len. la slice. la unhex. la fields. la nth. la find. (la w.
    str_eq(nth(w)(0))("quit")(la _. "bye")(la _.
      STEP(K)(FK)(PB)(D)(HEXE)(slots)(ephs)(w)(la out. la slots2. la ephs2.
        (la _. loop(K)(FK)(PB)(D)(HEXE)(slots2)(ephs2)(rest))(print(out))))("!"))
  (fields(line)(" ")))))
glyph MAIN = (la cr. (la sec. (la fk.
    LOOP(SESSION_KIT(str_at)(ord)(str_len)(str_to_int)(int_to_str)(chr)(concat)(str_eq)(add)(sub)(mul)(div)(mod)(lt)(int_eq)
                    (bor)(bxor)(error)(stat)(read_file)(open)(write)(close)(rename)(unlink)(mkdir)(chmod)(CLK)
                    (cr)(sec)(fk)(RND))
        (fk)
        (PBKDF2_KIT(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(add)(sub)(mul)(div)(mod)(lt)(int_eq)(bxor)(error)(cr))
        (DKIT(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_eq)(str_len)(add)(sub)(mul)(div)(lt)(int_eq)(Z))
        (cr(la sha. la hm. la hk. la se. la op. la hex. hex))
        (NIL)(NIL)(""))
    (FS_KIT(str_at)(ord)(str_len)(str_to_int)(int_to_str)(chr)(concat)(str_eq)(add)(sub)(mul)(div)(mod)(lt)(int_eq)
           (stat)(read_file)(write_file)(rename)(unlink)(mkdir)(rmdir)(pipe)(open)(close)(read)(write)(cr)(RND)))
  (SEC_KIT(str_at)(ord)(str_len)(str_to_int)(int_to_str)(chr)(concat)(str_eq)(add)(sub)(mul)(div)(lt)(int_eq)(band)(bor)(bxor)(cr)))
  (CR)
LAEOF

# ── the oracle and the shards ───────────────────────────────────────────────
cat > "$T/sgate.py" <<'PYEOF'
import hashlib, hmac, os, re, select, shutil, struct, subprocess, sys, time

# ── hashes and keys, from the contract ──────────────────────────────────────
def pbkdf2(p, s, c, n): return hashlib.pbkdf2_hmac('sha256', p, s, c, n)
def H(k, m): return hmac.new(k, m, hashlib.sha256).digest()
def hkdf(salt, ikm, info, n):
    prk = H(salt, ikm); out, t, i = b'', b'', 1
    while len(out) < n:
        t = H(prk, t + info + bytes([i])); out += t; i += 1
    return out[:n]
def keys(p, salt, it):
    """everything the contract derives from a passphrase and a user record"""
    st = pbkdf2(p, salt, it, 32)
    ku = hkdf(salt, st, b'logos/gamma', 32)
    km = hkdf(b'', ku, b'aletheia/master', 32)
    kc = hkdf(b'', ku, b'gamma/root', 32)
    return dict(st=st, ku=ku, km=km, kc=kc, ki=hkdf(b'', km, b'aletheia/index', 32), ver=H(st, b'logos/verifier'))
def token(kc, name, cavs=()):
    """logossec: sig0 = hmac(K_root)(id), sig_i = hmac(sig_{i-1})(caveat_i)"""
    sig = H(kc, name.encode())
    for c in cavs: sig = H(sig, c.encode())
    return '|'.join([name] + list(cavs) + [sig.hex()])
def atten(tok, cav):
    pre, sh = tok.rsplit('|', 1)
    return pre + '|' + cav + '|' + H(bytes.fromhex(sh), cav.encode()).hex()
RECRE = re.compile(rb'logos-user 1\nname=([a-z0-9_-]{1,32})\nsalt=([0-9a-f]{32})\niter=([1-9][0-9]*)\nverifier=([0-9a-f]{64})\n\Z')
def userfile(name, salt, it, ver, head=b'logos-user 1'):
    return b'%s\nname=%s\nsalt=%s\niter=%s\nverifier=%s\n' % (head, name, salt, it, ver)
SRECRE = re.compile(rb'session=([0-9a-f]{32})\nuser=([a-z0-9_-]{1,32})\nsince=(0|[1-9][0-9]*)\nsuspends=(0|[1-9][0-9]*)\n\Z')

# ── ChaCha20-Poly1305 (RFC 8439) and the AletheiaFS format, to read a store ──
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
    if sealed is None or len(sealed) < 16: return None
    ct, tag = sealed[:-16], sealed[-16:]
    return chacha_xor(key, 1, nonce, ct) if hmac.compare_digest(_mac(key, nonce, aad, ct), tag) else None
def aead_selftest():
    key = bytes(range(0x80, 0xa0)); nonce = bytes.fromhex('070000004041424344454647')
    aad = bytes.fromhex('50515253c0c1c2c3c4c5c6c7')
    pt = b"Ladies and Gentlemen of the class of '99: If I could offer you only one tip for the future, sunscreen would be it."
    want = bytes.fromhex(
        'd31a8d34648e60db7b86afbc53ef7ec2a4aded51296e08fea9e2b5a736ee62d63dbea45e8ca9671282fafb69da92728b'
        '1a71de0a9e060b2905d6a5b67ecd3b3692ddbd7f2d778b8c9803aee328091b58fab324e4fad675945585808b4831d7bc'
        '3ff4def08e4b7a9de576d26586cec64b61161ae10b594f09e26a7e902ecbd0600691')
    return seal(key, nonce, aad, pt) == want and aopen(key, nonce, aad, want) == pt \
        and aopen(key, nonce, aad, bytes([want[0] ^ 1]) + want[1:]) is None
def k_obj(km, oid): return hkdf(oid.encode(), km, b'aletheia/object', 32)
def k_of(km, oid): return hkdf(b'', km, b'aletheia/index', 32) if oid == 'index' else k_obj(km, oid)
def nonce_of(n): return n.to_bytes(12, 'little')
def aad_of(oid, n): return ('%s|%d' % (oid, n)).encode()
def rd(p):
    try: return open(p, 'rb').read()
    except OSError: return None
def wr(p, b):
    os.makedirs(os.path.dirname(p), exist_ok=True); open(p, 'wb').write(b)
def version_pt(home, km, oid, n):
    """version n of object oid in the store at home, opened with K_M km (None if it does not open)"""
    return aopen(k_of(km, oid), nonce_of(n), aad_of(oid, n), rd(os.path.join(home, 'obj', oid, str(n))))
def body(pt):
    """the content of a version's plaintext (after its five header lines)"""
    if pt is None: return None
    parts = pt.split(b'\n', 5)
    return parts[5] if len(parts) == 6 else None
def mode(p):
    try: return os.stat(p).st_mode & 0o7777
    except OSError: return None

class Session:
    def __init__(self, cwd, log):
        self.err = open(os.path.join(cwd, 'drv.err'), 'wb'); self.cwd = cwd
        self.p = subprocess.Popen(['./logos_secd'], cwd=cwd, stdin=subprocess.PIPE,
                                  stdout=subprocess.PIPE, stderr=self.err)
        self.buf = b''; self.log = log; self.times = []
    def _line(self, deadline):
        while b'\n' not in self.buf:
            left = deadline - time.time()
            if left <= 0: raise TimeoutError('the driver took longer than SESSION_CMD_TIMEOUT')
            r, _, _ = select.select([self.p.stdout], [], [], left)
            if not r: continue
            chunk = os.read(self.p.stdout.fileno(), 65536)
            if not chunk: raise EOFError('the driver exited: ' + open(os.path.join(self.cwd, 'drv.err'), 'rb').read()[-300:].decode('latin-1'))
            self.buf += chunk
        l, self.buf = self.buf.split(b'\n', 1)
        return l.decode('latin-1')
    def cmd(self, word, slot='-', *fields, limit=None):
        enc = [f.hex() if isinstance(f, bytes) else str(f).encode().hex() for f in fields]
        t0 = time.time()
        self.p.stdin.write((' '.join([word, slot] + enc) + '\n').encode()); self.p.stdin.flush()
        deadline = t0 + (limit or float(os.environ.get('SESSION_CMD_TIMEOUT', '1800')))
        us = None
        while True:
            l = self._line(deadline)
            if l.startswith('time '): us = int(l[5:]); continue
            if l.startswith('= '):
                self.times.append((word, us, l.startswith('= ok')))
                self.log.write('%-8s %9.3fs (op %s us)  %s\n' % (word, time.time() - t0, us, l[:160])); self.log.flush()
                return l[2:]
    def state(self, slot):
        """(name, token, record) of the session in slot, or the error"""
        r = self.cmd('state', slot)
        f = r.split(' ')
        if len(f) == 4 and f[0] == 'ok':
            return bytes.fromhex(f[1]).decode('latin-1'), bytes.fromhex(f[2]).decode('latin-1'), bytes.fromhex(f[3])
        return r
    def quit(self):
        try:
            self.p.stdin.write(b'quit\n'); self.p.stdin.flush(); self.p.wait(60)
        except Exception:
            self.p.kill(); self.p.wait()
        return self.p.returncode

OUT = []
def check(label, cond, detail=''):
    OUT.append(('PASS  ' if cond else 'FAIL  ') + 'logossession: ' + label + ('' if cond else '  [' + str(detail)[:400] + ']'))

# ── P: PBKDF2-HMAC-SHA256 known answers ─────────────────────────────────────
# (password, salt, iterations, dklen, the published answer or None). The first
# five are RFC 6070's inputs; their SHA-256 answers are the widely published
# ones, each also recomputed here by hashlib. The sixth is RFC 7914 section 11.
VECTORS = [
    (b'password', b'salt', 1, 32, '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b'),
    (b'password', b'salt', 2, 32, 'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43'),
    (b'password', b'salt', 4096, 32, 'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a'),
    (b'passwordPASSWORDpassword', b'saltSALTsaltSALTsaltSALTsaltSALTsalt', 4096, 40,
     '348c89dbcbd32b2f32d814b8116e84cf2b17347ebc1800181c4e2a1fb8dd53e1c635518c7dac47e9'),
    (b'pass\x00word', b'sa\x00lt', 4096, 16, '89b69d0516f829893c696226650a8687'),
    (b'passwd', b'salt', 1, 64,
     '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc'
     '49ca9cccf179b645991664b39d77ef317c71b845b1e30bd509112041d3a19783'),
    (b'K' * 100, bytes(range(20)), 3, 33, None),
    (b'', b'salt', 2, 32, None),
    (b'password', b'', 5, 1, None),
]
def shard_p(d, s):
    good = all(pub is None or pbkdf2(p, sa, c, n).hex() == pub for p, sa, c, n, pub in VECTORS)
    check('P the oracle (hashlib.pbkdf2_hmac) reproduces every published answer (RFC 6070 inputs with SHA-256, RFC 7914 11)', good)
    for p, sa, c, n, pub in VECTORS:
        r = s.cmd('pbkdf2', '-', p, sa, str(c), str(n))
        want = pbkdf2(p, sa, c, n).hex()
        check('P pbkdf2(%r, %r, %d, %d) = %s' % (p[:24], sa[:12], c, n, 'the published answer' if pub else 'hashlib\'s'),
              r == 'ok ' + want and (pub is None or want == pub), (r, want))
    # LAST: iter 0 halts the driver loudly
    try:
        r = s.cmd('pbkdf2', '-', b'password', b'salt', '0', '32', limit=60)
    except EOFError:
        r = None
    s.p.wait(30)
    err = open(os.path.join(d, 'drv.err'), 'rb').read()
    check('P iter 0 halts loudly (no answer, nonzero exit, "pbkdf2: iter must be at least 1")',
          r is None and s.p.returncode not in (0, None) and b'pbkdf2: iter must be at least 1' in err,
          (r, s.p.returncode, err[-200:]))
    return 'halted'

# ── A: accounts, keys, lock, the guard adapter, isolation ───────────────────
def shard_a(d, s):
    root = os.path.join(d, 'sys'); users = os.path.join(root, 'users')
    PA = b'correct horse ' + os.urandom(6).hex().encode()
    upath = lambda n: os.path.join(users, n)
    hpath = lambda n: os.path.join(root, 'home', n)
    r = s.cmd('adduser', '-', root, 'alice', PA)
    check('A adduser -> ok(alice)', r == 'ok alice', r)
    rec = rd(upath('alice')) or b''
    m = RECRE.match(rec)
    check('A the user record is exactly the format: "logos-user 1", name=alice, a 16-byte salt in hex, iter=1000, '
          'a 32-byte verifier in hex', m is not None and m.group(1) == b'alice' and m.group(3) == b'1000', rec)
    if m is None: return
    salt = bytes.fromhex(m.group(2).decode()); KA = keys(PA, salt, 1000)
    check('A verifier = hmac(stretch)("logos/verifier"), stretch = PBKDF2-HMAC-SHA256(pass, salt, 1000, 32) (hashlib)',
          m.group(4).decode() == KA['ver'].hex(), (m.group(4), KA['ver'].hex()))
    secrets = [PA, KA['st'], KA['ku'], KA['km'], KA['kc'], KA['ki']]
    check('A the stored record holds neither the passphrase nor K_U, nor the stretch, K_M or the capability root, '
          'raw or in hex', not any(x in rec or x.hex().encode() in rec for x in secrets))
    check('A users/ is mode 0700, the record 0600, and no .tmp is left',
          mode(users) == 0o700 and mode(upath('alice')) == 0o600 and not os.path.exists(upath('alice') + '.tmp'),
          (oct(mode(users) or 0), oct(mode(upath('alice')) or 0)))
    r = s.cmd('adduser', '-', root, 'alice', b'another')
    check('A adduser of an existing user -> "the user exists", the record unchanged',
          r == 'err adduser: the user exists' and rd(upath('alice')) == rec, r)
    before = sorted(os.listdir(users))
    rs = [s.cmd('adduser', '-', root, n, b'pw') for n in ('Alice', 'a/b', '', '..', 'a' * 33, 'a b', 'ok\n')]
    check('A adduser refuses bad names (upper case, a slash, empty, "..", 33 bytes, a space, a newline), writing nothing',
          rs == ['err adduser: bad name'] * 7 and sorted(os.listdir(users)) == before, rs)
    rs = [s.cmd('adduser', '-', root, 'carl', b''), s.cmd('adduser', '-', root + '\x00x', 'carl', b'pw'),
          s.cmd('adduser', '-', '', 'carl', b'pw')]
    check('A adduser refuses an empty passphrase and a root that is empty or has a NUL byte',
          rs == ['err adduser: empty passphrase', 'err adduser: bad root', 'err adduser: bad root']
          and not os.path.exists(upath('carl')), rs)
    os.makedirs(hpath('zed'))
    r = s.cmd('adduser', '-', root, 'zed', b'pw')
    check('A adduser refuses a user whose home already exists (a store sealed under someone else\'s key)',
          r == 'err adduser: %s already exists' % hpath('zed') and not os.path.exists(upath('zed')), r)
    wr(upath('frank') + '.tmp', b'left by a crash')
    r = s.cmd('adduser', '-', root, 'frank', b'pw')
    check('A adduser refuses when a .tmp is already there (created afresh, never opened), leaving it as it was',
          r == 'err adduser: cannot create %s.tmp' % upath('frank') and not os.path.exists(upath('frank'))
          and rd(upath('frank') + '.tmp') == b'left by a crash', r)
    wr(os.path.join(d, 'badrandom'), b'')
    r = s.cmd('adduser', '-', root, 'gina', b'pw')
    os.unlink(os.path.join(d, 'badrandom'))
    check('A adduser fails closed when random fails, writing nothing',
          r == 'err adduser: random failed' and not os.path.exists(upath('gina')) and not os.path.exists(upath('gina') + '.tmp'), r)

    # login, and every key the session derives
    rs = [s.cmd('login', 'x', root, 'alice', PA[:-1]), s.cmd('login', 'x', root, 'alice', b'x' + PA), s.state('x')]
    check('A a wrong passphrase is refused before anything is opened: the very first login with one (a store that '
          'is still empty, so nothing else could notice) gets no session and no home store is created',
          rs == ['err login: wrong user or passphrase'] * 2 + ['err state: the session is locked']
          and not os.path.exists(hpath('alice')), rs)
    r = s.cmd('login', 'a', root, 'alice', PA)
    check('A login with the right passphrase -> ok(session)', r == 'ok', r)
    st = s.state('a')
    TA = token(KA['kc'], 'alice')
    check('A the session\'s root token is the oracle\'s: name|hex(hmac(K_cap)(name)), K_cap = hkdf("")(K_U)("gamma/root")(32), '
          'K_U = hkdf(salt)(stretch)("logos/gamma")(32)', isinstance(st, tuple) and st[0] == 'alice' and st[1] == TA, (st, TA))
    if not isinstance(st, tuple): return
    sm = SRECRE.match(st[2])
    check('A the session manager\'s record of the session: a 16-byte session id, the user, since = now, 0 suspends',
          sm is not None and sm.group(2) == b'alice' and abs(int(sm.group(3)) - time.time()) < 300 and sm.group(4) == b'0', st[2])
    check('A login opened the user\'s AletheiaFS store at <root>/home/<name> (mode 0700)',
          os.path.isdir(os.path.join(hpath('alice'), 'obj')) and mode(hpath('alice')) == 0o700, oct(mode(hpath('alice')) or 0))
    r = s.cmd('put', 'a', TA, b"alice's secret\x00\xff", 'notes')
    ida = r[3:] if r.startswith('ok ') else ''
    pt = version_pt(hpath('alice'), KA['km'], ida, 1) if ida else None
    check('A an object the session puts is sealed under the oracle\'s K_M = hkdf("")(K_U)("aletheia/master")(32): '
          'it opens with it, holding the content', body(pt) == b"alice's secret\x00\xff", (r, pt))
    r = s.cmd('get', 'a', TA, ida)
    check('A ... and the session reads it back', r == 'ok %s %s %s 1' % (b"alice's secret\x00\xff".hex(), b'notes'.hex(), b'alice'.hex()), r)
    rs = [s.cmd('login', 'x', root, 'alice', PA + b'!'), s.cmd('login', 'x', root, 'alice', b''),
          s.cmd('login', 'x', root, 'nobody', PA)]
    check('A a wrong passphrase (one byte more, empty) and a user that does not exist are refused alike',
          rs == ['err login: wrong user or passphrase'] * 3, rs)
    rs = [s.cmd('login', 'x', root, 'Alice', PA), s.cmd('login', 'x', root + '\x00', 'alice', PA), s.state('x')]
    check('A login refuses a bad name and a root with a NUL; no session is made',
          rs == ['err login: bad name', 'err login: bad root', 'err state: the session is locked'], rs)
    # the iteration count is the record's
    PC, sc = b'carol pass', os.urandom(16)
    KC = keys(PC, sc, 7)
    wr(upath('carol'), userfile(b'carol', sc.hex().encode(), b'7', KC['ver'].hex().encode()))
    r = s.cmd('login', 'c', root, 'carol', PC)
    stc = s.state('c')
    check('A the iteration count is the record\'s: an oracle-written record with iter=7 logs in, and the token is the '
          'one PBKDF2 with 7 iterations gives', r == 'ok' and isinstance(stc, tuple) and stc[1] == token(KC['kc'], 'carol'), (r, stc))
    s.cmd('logout', 'c')
    bad = {
        'iter=0': userfile(b'carol', sc.hex().encode(), b'0', KC['ver'].hex().encode()),
        'iter=07': userfile(b'carol', sc.hex().encode(), b'07', KC['ver'].hex().encode()),
        'iter=-7': userfile(b'carol', sc.hex().encode(), b'-7', KC['ver'].hex().encode()),
        'iter=10000001': userfile(b'carol', sc.hex().encode(), b'10000001', KC['ver'].hex().encode()),
        'iter=99999999999': userfile(b'carol', sc.hex().encode(), b'99999999999', KC['ver'].hex().encode()),
        'a version 2 header': userfile(b'carol', sc.hex().encode(), b'7', KC['ver'].hex().encode(), b'logos-user 2'),
        'another name': userfile(b'carla', sc.hex().encode(), b'7', KC['ver'].hex().encode()),
        'an upper-case salt': userfile(b'carol', sc.hex().upper().encode(), b'7', KC['ver'].hex().encode()),
        'a short salt': userfile(b'carol', sc[:15].hex().encode(), b'7', KC['ver'].hex().encode()),
        'a short verifier': userfile(b'carol', sc.hex().encode(), b'7', KC['ver'][:31].hex().encode()),
        'a line more': userfile(b'carol', sc.hex().encode(), b'7', KC['ver'].hex().encode()) + b'x=1\n',
        'no final newline': userfile(b'carol', sc.hex().encode(), b'7', KC['ver'].hex().encode())[:-1],
        'no verifier': b'logos-user 1\nname=carol\nsalt=%s\niter=7\n' % sc.hex().encode(),
        'an empty file': b'',
    }
    rs = {}
    for what, b in bad.items():
        wr(upath('carol'), b); rs[what] = s.cmd('login', 'c', root, 'carol', PC)
    check('A every malformed record is refused as "bad user record" (iter 0, 07, -7, above 10^7, 11 digits; another '
          'header or name; a salt in upper case or short; a short verifier; a line more; no final newline; no '
          'verifier; an empty file)', all(v == 'err login: bad user record' for v in rs.values()), rs)
    wr(upath('carol'), userfile(b'carol', sc.hex().encode(), b'7', H(b'not the stretch', b'logos/verifier').hex().encode()))
    rs = [s.cmd('login', 'c', root, 'carol', PC)]
    os.unlink(upath('carol')); os.makedirs(upath('carol'))
    rs.append(s.cmd('login', 'c', root, 'carol', PC))
    check('A a record whose verifier does not match, and a record that is a directory, are refused as a wrong user or '
          'passphrase', rs == ['err login: wrong user or passphrase'] * 2, rs)

    # THE GUARD ADAPTER: only ok grants
    now = int(time.time())
    G = lambda tok, res='obj', op='r', slot='a': s.cmd('guard', slot, tok, res, op)
    forged = 'alice|' + os.urandom(32).hex()
    flipped = TA[:-1] + ('0' if TA[-1] != '0' else '1')
    cases = [
        ('the root token, obj w', TA, 'obj', 'w', 'T'),
        ('the root token, obj/<id> r', TA, 'obj/' + ida, 'r', 'T'),
        ('ops=r, asked r', atten(TA, 'ops=r'), 'obj', 'r', 'T'),
        ('ops=r, asked w (caveat not met)', atten(TA, 'ops=r'), 'obj', 'w', 'F'),
        ('res=obj/<id>, asked obj/<id>', atten(TA, 'res=obj/' + ida), 'obj/' + ida, 'r', 'T'),
        ('res=obj/<id>, asked obj (caveat not met)', atten(TA, 'res=obj/' + ida), 'obj', 'r', 'F'),
        ('until an hour from now', atten(TA, 'until=%d' % (now + 3600)), 'obj', 'r', 'T'),
        ('until 100 s ago (expired, against the real clock)', atten(TA, 'until=%d' % (now - 100)), 'obj', 'r', 'F'),
        ('until=soon (malformed caveat)', atten(TA, 'until=soon'), 'obj', 'r', 'F'),
        ('an unknown caveat', atten(TA, 'color=blue'), 'obj', 'r', 'F'),
        ('a forged signature', forged, 'obj', 'r', 'F'),
        ('the last hex digit changed', flipped, 'obj', 'r', 'F'),
        ('a caveat removed from an attenuated token', TA.rsplit('|', 1)[0] + '|' + atten(TA, 'ops=r').rsplit('|', 1)[1], 'obj', 'w', 'F'),
        ('the empty string', '', 'obj', 'r', 'F'),
        ('no signature', 'alice', 'obj', 'r', 'F'),
        ('a bad id', 'al ice|' + TA.rsplit('|', 1)[1], 'obj', 'r', 'F'),
        ('a bad signature encoding', 'alice|' + 'Z' * 64, 'obj', 'r', 'F'),
        ('a bad resource (obj/../x)', TA, 'obj/../x', 'r', 'F'),
        ('a bad op (z)', TA, 'obj', 'z', 'F'),
    ]
    got = [(what, G(tok, res, op)) for what, tok, res, op, want in cases]
    wrong = [(w, g) for (w, g), c in zip(got, cases) if g != 'ok ' + c[4]]
    check('A THE GUARD ADAPTER (verify with the realtime clock, ok -> TRUE, err -> FALSE): every refusal verify can give '
          'is FALSE and only ok is TRUE (%d questions: res, ops and until caveats on both sides, an unknown or '
          'malformed caveat, forged, altered, truncated and malformed tokens, a bad resource and a bad op)' % len(cases),
          wrong == [], wrong)
    wr(os.path.join(d, 'badclock'), b'')
    rs = [G(TA, 'obj', 'r'), G(TA, 'obj', 'w'), s.cmd('get', 'a', TA, ida), s.cmd('login', 'x', root, 'alice', PA)]
    os.unlink(os.path.join(d, 'badclock'))
    rs.append(G(TA, 'obj', 'r'))
    check('A a clock that cannot be read denies everything, even the root token (and a store read through it is '
          'refused), and login says so; with the clock back the token grants again',
          rs == ['ok F', 'ok F', 'err denied: obj/%s r' % ida, 'err login: no clock', 'ok T'], rs)
    rs = [s.cmd('put', 'a', atten(TA, 'ops=r'), b'x', 't'), s.cmd('get', 'a', atten(TA, 'ops=r'), ida)[:3],
          s.cmd('get', 'a', atten(TA, 'res=obj/' + '0' * 32), ida)]
    check('A the store asks the adapter: an ops=r token reads but cannot put, a token for another object reads nothing',
          rs == ['err denied: obj w', 'ok ', 'err denied: obj/%s r' % ida], rs)

    # lock drops the keys; unlock restores them
    r1 = s.cmd('eph', 'a', 'e1', b'ephemeral bytes')
    r2 = s.cmd('eread', 'e1')
    r3 = s.cmd('lock', 'a')
    rs = [s.cmd('state', 'a'), s.cmd('get', 'a', TA, ida), s.cmd('guard', 'a', TA, 'obj', 'r'),
          s.cmd('put', 'a', TA, b'x', 't'), s.cmd('eread', 'e1')]
    check('A lock: the locked value gives no view, no object, no guard and no put, and the session\'s ephemeral '
          'objects can no longer be opened',
          [r1, r2, r3] == ['ok', 'ok ' + b'ephemeral bytes'.hex(), 'ok'] and
          rs == ['err state: the session is locked'] * 4 + ['err ephemeral: session closed'], ([r1, r2, r3], rs))
    rs = [s.cmd('unlock', 'a', PA + b'x'), s.cmd('unlock', 'a', b''), s.cmd('state', 'a')]
    check('A unlock with a wrong passphrase is refused and the session stays locked',
          rs == ['err unlock: wrong user or passphrase'] * 2 + ['err state: the session is locked'], rs)
    r = s.cmd('unlock', 'a', PA)
    st2 = s.state('a')
    check('A unlock restores the same session: the same record (session id, since) and the same root token',
          r == 'ok' and st2 == st, (r, st2, st))
    r = s.cmd('get', 'a', TA, ida)
    check('A ... and the keys are back: the object reads again',
          r == 'ok %s %s %s 1' % (b"alice's secret\x00\xff".hex(), b'notes'.hex(), b'alice'.hex()), r)
    rs = [s.cmd('unlock', 'a', PA), s.cmd('lock', 'a'), s.cmd('lock', 'a'), s.state('a'), s.cmd('unlock', 'a', PA)]
    check('A unlock of an open session is refused; locking twice leaves it locked; it unlocks once',
          rs == ['err unlock: the session is not locked', 'ok', 'ok', 'err state: the session is locked', 'ok'], rs)

    # ISOLATION: bob has the SAME passphrase
    r = s.cmd('adduser', '-', root, 'bob', PA)
    mb = RECRE.match(rd(upath('bob')) or b'')
    KB = keys(PA, bytes.fromhex(mb.group(2).decode()), 1000) if mb else None
    check('A a second user with the same passphrase gets a different salt, so a different K_U, K_M and capability root',
          r == 'ok bob' and KB is not None and mb.group(2) != m.group(2) and KB['ku'] != KA['ku'] and KB['km'] != KA['km']
          and KB['kc'] != KA['kc'], r)
    if KB is None: return
    r = s.cmd('login', 'b', root, 'bob', PA)
    stb = s.state('b'); TB = token(KB['kc'], 'bob')
    check('A bob logs in; his root token is the oracle\'s for his own keys', r == 'ok' and isinstance(stb, tuple) and stb[1] == TB, (r, stb))
    r = s.cmd('put', 'b', TB, b"bob's secret", 'notes')
    idb = r[3:] if r.startswith('ok ') else ''
    check('A bob\'s object opens under bob\'s K_M, not alice\'s',
          body(version_pt(hpath('bob'), KB['km'], idb, 1)) == b"bob's secret" and version_pt(hpath('bob'), KA['km'], idb, 1) is None, r)
    rs = [G(TA, 'obj', 'r', 'b'), G(atten(TA, 'ops=r'), 'obj', 'r', 'b'), G(TB, 'obj', 'r', 'a'), G(TB, 'obj', 'r', 'b'),
          G(TA, 'obj', 'r', 'a')]
    check('A tokens are isolated both ways: alice\'s tokens (and their attenuations) do not verify under bob\'s '
          'capability root, nor bob\'s under alice\'s; each verifies under its own', rs == ['ok F', 'ok F', 'ok F', 'ok T', 'ok T'], rs)
    rs = [s.cmd('get', 'b', TA, ida), s.cmd('put', 'b', TA, b'x', 't'), s.cmd('get', 'a', TB, idb), s.cmd('put', 'a', TB, b'x', 't')]
    check('A ... and the stores refuse the other user\'s token', rs == ['err denied: obj/%s r' % ida, 'err denied: obj w',
          'err denied: obj/%s r' % idb, 'err denied: obj w'], rs)
    for src, dst, oid in (('alice', 'bob', ida), ('bob', 'alice', idb)):
        for side in ('obj', 'mirror'):
            shutil.copytree(os.path.join(hpath(src), side, oid), os.path.join(hpath(dst), side, oid))
    copied = [rd(os.path.join(hpath(u), 'obj', o, '1')) for u, o in (('bob', ida), ('alice', idb))]
    rs = [s.cmd('get', 'b', TB, ida), s.cmd('get', 'a', TA, idb)]
    check('A objects are isolated both ways: alice\'s object copied into bob\'s store does not open with bob\'s session '
          '(different K_M), nor bob\'s in alice\'s, and neither copy is "repaired"',
          rs == ['err lost: version 1'] * 2 and copied == [rd(os.path.join(hpath(u), 'obj', o, '1')) for u, o in (('bob', ida), ('alice', idb))]
          and version_pt(hpath('bob'), KA['km'], ida, 1) is not None and version_pt(hpath('bob'), KB['km'], ida, 1) is None, rs)
    rs = [s.cmd('eph', 'a', 'e2', b'more'), s.cmd('logout', 'a'), s.cmd('eread', 'e2'), s.state('a'),
          s.cmd('lock', 'b'), s.cmd('logout', 'b')]
    check('A logout -> ok(name), closing the session\'s ephemeral objects; a locked session logs out too',
          rs == ['ok', 'ok alice', 'err ephemeral: session closed', 'err state: the session is locked', 'ok', 'ok bob'], rs)

# ── S: suspend, resume, and the session manager's record of the session ─────
def store_ids(home, km, tag):
    """the ids the store's newest index version lists with tag, read with the oracle's K_M"""
    h = rd(os.path.join(home, 'obj', 'index', 'head'))
    b = body(version_pt(home, km, 'index', int(h))) if h else None
    if b is None: return None
    return [l.split(b' ', 1)[0].decode() for l in b.split(b'\n') if l and tag in l.split(b' ', 1)[1].split(b',')]
def header(pt):
    return dict(l.split(b'=', 1) for l in pt.split(b'\n', 5)[:5]) if pt else {}
def append_version(home, km, oid, content, tags=b'logos-session', owner=b'dave'):
    """the oracle seals version n+1 of oid itself, exactly as the AletheiaFS format says"""
    n = int(rd(os.path.join(home, 'obj', oid, 'head')))
    prev = hashlib.sha256(rd(os.path.join(home, 'obj', oid, str(n)))).hexdigest().encode()
    pt = b'n=%d\ntags=%s\nowner=%s\nprev=%s\nlen=%d\n' % (n + 1, tags, owner, prev, len(content)) + content
    blob = seal(k_obj(km, oid), nonce_of(n + 1), aad_of(oid, n + 1), pt)
    for side in ('obj', 'mirror'):
        wr(os.path.join(home, side, oid, str(n + 1)), blob); wr(os.path.join(home, side, oid, 'head'), str(n + 1).encode())
def saved(rec, st): return b'logos-session 1\n' + rec + b'state=%d\n' % len(st) + st
def files_under(top):
    for r, ds, fs in os.walk(top):
        for f in fs: yield os.path.join(r, f)
def shard_s(d, s):
    root = os.path.join(d, 'sys'); hpath = lambda n: os.path.join(root, 'home', n)
    PD = b'dave ' + os.urandom(6).hex().encode(); home = hpath('dave')
    s.cmd('adduser', '-', root, 'dave', PD)
    mr = RECRE.match(rd(os.path.join(root, 'users', 'dave')) or b'')
    if mr is None: check('S adduser', False); return
    KD = keys(PD, bytes.fromhex(mr.group(2).decode()), 1000); TD = token(KD['kc'], 'dave')
    s.cmd('login', 'd', root, 'dave', PD)
    st0 = s.state('d')
    m0 = SRECRE.match(st0[2]) if isinstance(st0, tuple) else None
    if m0 is None: check('S login', False, st0); return
    sid0, since0 = m0.group(1), m0.group(3)
    R = lambda n, sid=sid0, since=since0: b'session=%s\nuser=dave\nsince=%s\nsuspends=%d\n' % (sid, since, n)
    WM = b'windows=2\nlayout=H500(L1,L2)\ncwd=/home/dave\n' + bytes(range(256)) * 4
    r = s.cmd('suspend', 'd', WM)
    check('S suspend -> ok(the locked session): the value it gives holds no view',
          r == 'ok' and s.state('d') == 'err state: the session is locked', (r, s.state('d')))
    ids = store_ids(home, KD['km'], b'logos-session')
    check('S the state is stored as ONE sealed object of the user\'s own store, tagged logos-session (the store\'s '
          'index, opened with the oracle\'s K_M, lists it)', ids is not None and len(ids) == 1, ids)
    if not ids: return
    oid = ids[0]
    pt1 = version_pt(home, KD['km'], oid, 1)
    check('S SELF-APPLICATION: the sealed object holds the session manager\'s own record of the session (its id, the '
          'user, since, and its suspends, now 1) and then the state, byte for byte; owner dave',
          body(pt1) == saved(R(1), WM) and header(pt1).get(b'owner') == b'dave' and header(pt1).get(b'tags') == b'logos-session',
          (body(pt1) or b'')[:200])
    clear = [f for f in files_under(root) if WM[:40] in rd(f) or R(1) in rd(f)]
    check('S ... and neither the state nor the record is anywhere on disk in the clear', clear == [], clear)
    r = s.cmd('unlock', 'd', PD)
    check('S the locked session suspend gave unlocks to the same session, its record counting the suspend',
          r == 'ok' and s.state('d') == ('dave', TD, R(1)), (r, s.state('d')))
    s.cmd('logout', 'd')
    r = s.cmd('resume', 'e', root, 'dave', PD)
    check('S resume(root)(name)(pass) -> ok(session, state): the state exactly as it was suspended', r == 'ok ' + WM.hex(), r[:80])
    check('S SELF-APPLICATION: the resumed session IS the suspended one: its record is restored from the store (the same '
          'session id and since, 1 suspend) and it holds the user\'s keys (the root token)', s.state('e') == ('dave', TD, R(1)), s.state('e'))
    r = s.cmd('login', 'f', root, 'dave', PD)
    stf = s.state('f'); mf = SRECRE.match(stf[2]) if isinstance(stf, tuple) else None
    check('S ... whereas a plain login is a new session: a new id, 0 suspends',
          r == 'ok' and mf is not None and mf.group(1) != sid0 and mf.group(4) == b'0', stf)
    s.cmd('logout', 'f')
    WM2 = b'second state\n'
    r = s.cmd('suspend', 'e', WM2)
    pt2 = version_pt(home, KD['km'], oid, 2)
    check('S suspending again writes version 2 of the same object (chained to version 1), its record counting 2, '
          'and the index still lists one session object',
          r == 'ok' and body(pt2) == saved(R(2), WM2)
          and header(pt2).get(b'prev') == hashlib.sha256(rd(os.path.join(home, 'obj', oid, '1'))).hexdigest().encode()
          and store_ids(home, KD['km'], b'logos-session') == [oid], (r, (body(pt2) or b'')[:200]))
    r = s.cmd('resume', 'g', root, 'dave', PD)
    check('S resume gives the newest state and record', r == 'ok ' + WM2.hex() and s.state('g') == ('dave', TD, R(2)), (r, s.state('g')))
    rs = [s.cmd('lock', 'g'), s.cmd('suspend', 'g', b'x'), s.cmd('resume', 'x', root, 'dave', PD + b'?'), s.state('x')]
    check('S suspend of a locked session is refused; resume with a wrong passphrase is refused and gives no session',
          rs == ['ok', 'err suspend: the session is locked', 'err resume: wrong user or passphrase',
                 'err state: the session is locked'], rs)
    PE = b'erin pass'
    s.cmd('adduser', '-', root, 'erin', PE)
    rs = [s.cmd('resume', 'h', root, 'erin', PE), s.state('h')]
    check('S resume of a user who never suspended -> "nothing suspended", and no session',
          rs == ['err resume: nothing suspended', 'err state: the session is locked'], rs)
    # fail closed: saved sessions sealed properly (by the oracle) but not this user's, or not well formed
    rs = []
    for content in (saved(R(2).replace(b'user=dave', b'user=mallory'), b'x'),
                    saved(R(2), b'short')[:-1], saved(R(2), b'x') + b'y',
                    b'logos-session 2\n' + R(2) + b'state=1\nx',
                    saved(R(2, sid=sid0.upper()), b'x'), saved(R(2, since=b'01'), b'x'),
                    saved(R(2), b'x').replace(b'suspends=2\n', b''), b''):
        append_version(home, KD['km'], oid, content)
        rs.append(s.cmd('resume', 'h', root, 'dave', PD))
    check('S resume refuses a saved session, sealed under the right key, that names another user, has a state shorter '
          'or longer than its length, another header, a bad session id, a since with a leading zero, no suspends '
          'line, or nothing at all; no session is made',
          rs == ["err resume: the saved session is not dave's"] + ['err resume: malformed saved session'] * 7
          and s.state('h') == 'err state: the session is locked', rs)
    WM3 = b'third'
    rs = [s.cmd('login', 'i', root, 'dave', PD)]
    sti = s.state('i'); mi = SRECRE.match(sti[2]) if isinstance(sti, tuple) else None
    rs += [s.cmd('suspend', 'i', WM3), s.cmd('resume', 'j', root, 'dave', PD)]
    check('S the next suspend writes a well-formed version again, and resume restores that session (its own id, 1 suspend)',
          rs == ['ok', 'ok', 'ok ' + WM3.hex()] and mi is not None
          and s.state('j') == ('dave', TD, R(1, sid=mi.group(1), since=mi.group(3))), (rs, s.state('j')))
    rs = [s.cmd('put', 'j', TD, b'decoy', 'logos-session')[:3], s.cmd('suspend', 'j', b'x'), isinstance(s.state('j'), tuple),
          s.cmd('resume', 'k', root, 'dave', PD)]
    check('S a second object tagged logos-session makes suspend and resume refuse (which one is the saved session would '
          'be a guess); the session stays open', rs == ['ok ', 'err suspend: more than one saved session', True,
          'err resume: more than one saved session'], rs)

SHARDS = {'P': shard_p, 'A': shard_a, 'S': shard_s}

if __name__ == '__main__':
    which, d = sys.argv[1], sys.argv[2]
    if which == 'selftest':
        print('PASS  logossession: the oracle\'s ChaCha20-Poly1305 reproduces RFC 8439 2.8.2 (seal, open, a flipped bit refused)'
              if aead_selftest() else 'FAIL  logossession: the oracle does not reproduce RFC 8439 2.8.2'); sys.exit(0)
    log = open(os.path.join(d, 'session.log'), 'w')
    s = Session(d, log)
    try:
        how = SHARDS[which](d, s)
        if how != 'halted':
            rc = s.quit()
            err = open(os.path.join(d, 'drv.err'), 'rb').read()
            check('%s the driver ran to the end: exit 0, nothing on stderr' % which, rc == 0 and err == b'', (rc, err[-200:]))
    except (EOFError, TimeoutError, OSError) as e:
        check('%s the session ran to the end' % which, False, e); s.p.kill()
    with open(os.path.join(d, 'result.txt'), 'w') as f:
        f.write(''.join(l + '\n' for l in OUT))
    with open(os.path.join(d, 'times.txt'), 'w') as f:
        f.write(''.join('%s %d\n' % (w, us) for w, us, good in s.times if good and us is not None))
PYEOF

r=$(python3 "$T/sgate.py" selftest "$T"); echo "$r"; case "$r" in PASS*) ;; *) ok=0 ;; esac

# compile the driver once
cp "$T/drv.la" "$T/logos_source.la"; cp "$T/compiler.bin" "$T/logos_program.bin"
s=$(date +%s)
( cd "$T" && timeout "$WM_VM_TIMEOUT" ./logos_secd >/dev/null 2>"$T/dce" ) \
    || { echo "FAIL  logossession: the driver did not compile"; tail -3 "$T/dce"; exit 1; }
cp "$T/logos_program.bin" "$T/prog.bin"
COMPILE_S=$(( $(date +%s) - s ))

for sh in $SESSION_SHARDS; do
    mkdir -p "$T/s$sh"
    ( cd "$T/s$sh" && cp "$T/logos_secd" . && cp "$T/prog.bin" logos_program.bin \
      && s=$(date +%s) && timeout "$SESSION_SHARD_TIMEOUT" python3 "$T/sgate.py" "$sh" "$T/s$sh"; \
      echo $? > rc; echo $(( $(date +%s) - s )) > secs )
    d="$T/s$sh"
    if [ -s "$d/result.txt" ]; then cat "$d/result.txt"; grep -q '^FAIL' "$d/result.txt" && ok=0
    else echo "FAIL  logossession: shard $sh produced no results (rc $(cat "$d/rc" 2>/dev/null))"; ok=0; fi
done

python3 - "$T" "$COMPILE_S" "$SESSION_SHARDS" <<'PYEOF'
import sys, os
T, cs, shards = sys.argv[1], sys.argv[2], sys.argv[3].split()
secs = ' '.join('%s %ss' % (sh, open(os.path.join(T, 's' + sh, 'secs')).read().strip()) for sh in shards
                if os.path.exists(os.path.join(T, 's' + sh, 'secs')))
ts = {}
for sh in shards:
    try:
        for l in open(os.path.join(T, 's' + sh, 'times.txt')):
            w, t = l.split(); ts.setdefault(w, []).append(int(t) / 1e6)
    except OSError: pass
print('TIME  driver compile %ss; shards (one at a time): %s' % (cs, secs))
print('TIME  per operation on the VM, median of the calls that returned ok (count), timed inside the driver: ' +
      ', '.join('%s %.3fs (%d)' % (w, sorted(v)[len(v) // 2], len(v)) for w, v in sorted(ts.items())
                if w in ('pbkdf2', 'adduser', 'login', 'lock', 'unlock', 'suspend', 'resume', 'state', 'logout', 'guard', 'put', 'get')))
PYEOF
[ "$ok" = 1 ] || exit 1
