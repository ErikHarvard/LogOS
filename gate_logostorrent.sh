#!/usr/bin/env bash
# gate_logostorrent.sh — LogosTorrent (logostorrent.la, TORRENT_KIT) over
# LogosNet (logosnet.la), on the native VM.
#
# WHAT IT GUARDS (NET_DESIGN.md section 3):
#   1. listen: the control command logosnet.la gained for services that run
#      beside a node in their own process: a listener gets each DATA whose
#      text begins with its tag and a space as one frame "<from> <text>"
#      (binary-safe, from = the sender's NodeID), the node no longer logs it;
#      other texts (no tag, the tag without its space) are still logged as
#      recv; the latest listener of a tag gets it; a listener that has gone
#      is closed and the DATA logged; a malformed listen is refused.
#   2. the manifest: manifest and root against the gate's own Python
#      computation (hashlib) on empty, one-byte, exact-multiple, short-tail,
#      1000-chunk and maximal-chunk files, byte for byte; parse against the
#      gate's own reading of the format on those manifests and on malformed
#      ones (wrong magic, leading zero, uppercase hex, a short line, a byte
#      too many or too few, a line missing, chunk 0 or 65281, a 12-digit
#      length that does not fit, signs): none, never a halt; a chunk size
#      out of 1..65280 halts loudly.
#   3. the torrent service, VM processes in $T/net driven from Python: a ring
#      of four LogosNet nodes F-S1-R-S2, each with its service attached
#      through listen; seed answers the root the gate computes; a 4 KiB file
#      in 512-byte chunks seeded by two nodes, one of which serves corrupt
#      chunks (its copy changed on disk after seed): the fetcher assembles
#      the exact file, refusing every bad chunk, with the GETs spread over
#      both and the bad seeder not asked again; a seeder killed mid-fetch:
#      the fetch completes from the other, the dead one's GETs time out and
#      its service ends with its node; an unknown root reports not found
#      after the find timeout; a manifest whose hash is not the root (served
#      by the gate's own lying Python node, pytor.py, which speaks the wire
#      from the format alone) is refused, the liar never asked for a chunk,
#      and beside an honest seeder the fetch completes; the file is written
#      atomically: a reader polling <out> through every fetch only ever sees
#      it absent, as it was, or whole; an existing <out> is replaced by a
#      rename (a hard link to the old file keeps the old bytes); a failed
#      fetch or write leaves no file and no .part; an empty file; the
#      control channel's errors; quit.
# ISOLATION: a private temp dir (gate_wm_common.sh; mktemp honours TMPDIR):
# every socket and file is in it; every VM process is killed on every exit
# path. VM only (the C host is far too slow for the crypto underneath).
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1
pass() { echo "PASS  logostorrent: $*"; }
fail() { echo "FAIL  logostorrent: $*"; ok=0; }
check() { if [ "$1" = 1 ]; then pass "$2"; else fail "$2"; [ -n "${3:-}" ] && echo "      $3"; fi; }
command -v python3 >/dev/null || { echo "FAIL  logostorrent: python3 (the oracle) is not installed"; exit 1; }
wm_setup logostorrent.la logosnet.la logoscrypt.la x25519.la
G0=$(date +%s)
# Every VM process the Python driver starts has $T/logos_secd as argv[0] and
# its pid in $T/procs.pids; they are killed on every exit path.
cleanup() {
    for p in $(cat "$T/procs.pids" 2>/dev/null); do kill -9 "$p" 2>/dev/null; done
    pkill -KILL -f "$T/logos_secd " 2>/dev/null
    rm -rf "$T"
}
trap cleanup EXIT
trap 'exit 2' INT TERM HUP

# vm_compile PROG.la BIN: compile on the VM into $T/BIN; a failure ends the gate
vm_compile() {
    cp "$T/$1" "$T/logos_source.la"; cp "$T/compiler.bin" "$T/logos_program.bin"
    vrc=0; ( cd "$T" && timeout "$WM_VM_TIMEOUT" ./logos_secd >/dev/null 2>"$T/vce" ) || vrc=$?
    [ "$vrc" = 0 ] || { echo "FAIL  logostorrent: $1 did not compile (rc $vrc)"; tail -c 400 "$T/vce"; exit 1; }
    cp "$T/logos_program.bin" "$T/$2"
}
# vm_run BIN MODE OUT: run BIN in $T with mode.txt = MODE; sets vrc, stderr in $T/vre
vm_run() {
    printf '%s' "$2" > "$T/mode.txt"; cp "$T/$1" "$T/logos_program.bin"
    vrc=0; ( cd "$T" && timeout "$WM_VM_TIMEOUT" ./logos_secd >"$3" 2>"$T/vre" ) || vrc=$?
}

cat > "$T/torlib.py" <<'PYEOF'
# torlib.py — drives LogosNet nodes and their torrent services (VM
# processes) for the gate. Every node runs with its working directory at the
# net directory NET, so socket paths stay short (./<id>.sock); its log is
# NET/<name>.log. A node's torrent service runs in NET/<name>.d (its files
# live there), attached to ../<name>.ctl; its log is NET/<name>.t.log.
import os, sys, time, socket, struct, subprocess, signal, hashlib, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import noiseref as N

def frame(p): return struct.pack(">I", len(p)) + p
def b(x): return x if isinstance(x, bytes) else x.encode()
def unix(net, path, timeout=60):
    """a stream socket connected to path (relative to net)"""
    c = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); c.settimeout(timeout)
    cwd = os.getcwd(); os.chdir(net)
    try: c.connect(path)
    except OSError: c.close(); raise
    finally: os.chdir(cwd)
    return c
def readframe(c, buf=b""):
    """(payload, rest) of the next frame on c; (None, buf) at EOF"""
    while len(buf) < 4 or len(buf) < 4 + struct.unpack(">I", buf[:4])[0]:
        d = c.recv(65536)
        if not d: return None, buf
        buf += d
    n = struct.unpack(">I", buf[:4])[0]
    return buf[4:4 + n], buf[4 + n:]

class Mesh:
    def __init__(s, net, vm, prog, pidfile=None, svcprog=None):
        s.net, s.vm, s.prog, s.pidfile, s.svcprog = net, vm, prog, pidfile, svcprog
        s.procs, s.keys = {}, {}
        os.makedirs(net, exist_ok=True)
        open(os.path.join(net, "logos_program.bin"), "wb").write(open(prog, "rb").read())
    def key(s, name, sk=None):
        """a key file NET/<name>.key (mode 0600) and the NodeID it must give"""
        sk = sk or os.urandom(32)
        p = os.path.join(s.net, name + ".key")
        if os.path.exists(p): os.remove(p)
        fd = os.open(p, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600); os.write(fd, sk); os.close(fd)
        pub = N.x_pub(sk)
        s.keys[name] = (sk, pub, hashlib.sha256(pub).digest()[:16].hex())
        return s.keys[name][2]
    def id(s, name): return s.keys[name][2]
    def path(s, name): return "./%s.sock" % s.id(name)
    def _spawn(s, name, cwd, cfgname):
        log = open(os.path.join(s.net, name + ".log"), "ab")
        s.procs[name] = subprocess.Popen([os.path.abspath(s.vm), cfgname], cwd=cwd, stdout=log, stderr=subprocess.STDOUT)
        log.close()
        if s.pidfile: open(s.pidfile, "a").write("%d\n" % s.procs[name].pid)
    def start(s, name, seeds=(), reach=None, period=1, links=2, extra=""):
        cfg = ["netdir .", "key %s.key" % name, "ctl %s.ctl" % name, "period %d" % period, "links %d" % links]
        cfg += ["seed %s" % s.path(x) for x in seeds]
        if reach is not None: cfg.append("reach " + " ".join(s.id(x) for x in reach))
        cfg.append(extra)
        open(os.path.join(s.net, name + ".cfg"), "w").write("\n".join(cfg) + "\n")
        s._spawn(name, s.net, name + ".cfg")
    def svcdir(s, name): return os.path.join(s.net, name + ".d")
    def start_svc(s, name, extra=""):
        """node name's torrent service, in NET/<name>.d (config: node, ctl, extra)"""
        d = s.svcdir(name); os.makedirs(d, exist_ok=True)
        open(os.path.join(d, "logos_program.bin"), "wb").write(open(s.svcprog, "rb").read())
        open(os.path.join(d, "svc.cfg"), "w").write("node ../%s.ctl\nctl svc.ctl\n%s\n" % (name, extra))
        s._spawn(name + ".t", d, "svc.cfg")
    def log(s, name):
        try: return open(os.path.join(s.net, name + ".log"), encoding="utf-8", errors="replace").read()
        except FileNotFoundError: return ""
    def count(s, name, pat): return len(re.findall(pat, s.log(name), re.M))
    def wait(s, name, pattern, timeout=60, count=1):
        """wait until NET/<name>.log has `count` lines matching the regex"""
        t0 = time.time()
        while time.time() - t0 < timeout:
            if len(re.findall(pattern, s.log(name), re.M)) >= count: return True
            p = s.procs.get(name)
            if p is not None and p.poll() is not None and len(re.findall(pattern, s.log(name), re.M)) < count:
                return False
            time.sleep(0.1)
        return False
    def ctl(s, path, line, timeout=120):
        """one framed command on the control socket at path (relative to NET)
        and its framed reply, as text; None when nothing answers (a socket
        just started is given 10 s to appear)"""
        t0 = time.time()
        while True:
            try: c = unix(s.net, path, timeout); break
            except (FileNotFoundError, ConnectionRefusedError):
                if time.time() - t0 > 10: return None
                time.sleep(0.2)
        c.sendall(frame(b(line)))
        try: p, _ = readframe(c)
        except socket.timeout: p = None
        c.close()
        return None if p is None else p.decode("utf-8", "replace")
    def node(s, name, line, timeout=120): return s.ctl(name + ".ctl", line, timeout)
    def tor(s, name, line, timeout=300): return s.ctl(name + ".d/svc.ctl", line, timeout)
    def kill(s, name, sig=signal.SIGKILL):
        p = s.procs.pop(name, None)
        if p is not None and p.poll() is None:
            p.send_signal(sig); p.wait()
    def rc(s, name, timeout=30):
        p = s.procs.get(name)
        if p is None: return None
        try: return p.wait(timeout)
        except subprocess.TimeoutExpired: return None
    def stop_all(s):
        for n in list(s.procs): s.kill(n)
PYEOF

cat > "$T/noiseref.py" <<'PYEOF'
# noiseref.py — the gate's own Noise (revision 34), independent of the LA,
# for its Python node: X25519 and ChaCha20-Poly1305 from the `cryptography`
# package when present, else the RFC 7748 / RFC 8439 transcriptions below;
# SHA-256 and HMAC from hashlib/hmac. (A copy of gate_logosnet.sh's, which
# checks it against the published cacophony vectors.)
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
PYEOF

cat > "$T/pytor.py" <<'PYEOF'
# pytor.py — a LogosNet node in Python, independent of the LA (the gate's own
# Noise, noiseref.py, for its XX links and the Noise_X blobs; its own framing
# and mesh messages), that speaks LogosTorrent's wire from the format alone
# and lies: for each root in `lies` it answers WANT with HAVE and serves a
# manifest that is NOT the root's (a well-formed manifest of other bytes) and
# chunks consistent with that lie. It records every request it gets.
import os, socket, struct, threading, select, time, hashlib
import noiseref as N
PRO = b"LogosNet/1"
def frame(p): return struct.pack(">I", len(p)) + p
def rawid(pub): return hashlib.sha256(pub).digest()[:16]
def presence(raw, pub, seq, path): return b"P" + raw + pub + struct.pack(">Q", seq) + path
def data(msgid, ttl, dest, blob): return b"D" + msgid + bytes([ttl]) + dest + blob

class Link:
    def __init__(s, sock, hs, expect=None):
        s.sock, s.hs, s.expect, s.buf = sock, hs, expect, b""
        s.tx = s.rx = s.peer = None
    def up(s): return s.tx is not None

class PyTor:
    """net: the net directory; the node listens at ./<id>.sock in it"""
    def __init__(s, net, sk=None):
        s.net, s.sk = net, sk or os.urandom(32)
        s.pub = N.x_pub(s.sk); s.raw = rawid(s.pub); s.id = s.raw.hex()
        s.path = "./%s.sock" % s.id
        s.links, s.seenp, s.seend, s.events, s.dir, s.lies = [], {}, set(), [], {}, {}
        s.lock = threading.RLock(); s.stop = False
        cwd = os.getcwd(); os.chdir(net)
        try:
            if os.path.exists(s.path): os.remove(s.path)
            s.lsock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.lsock.bind(s.path); s.lsock.listen(16)
        finally: os.chdir(cwd)
        s.thread = threading.Thread(target=s._loop, daemon=True); s.thread.start()
    def ev(s, *e):
        with s.lock: s.events.append(e)
    def has(s, *e):
        with s.lock: return e in s.events
    def wait(s, *e, timeout=60):
        t0 = time.time()
        while time.time() - t0 < timeout:
            if s.has(*e): return True
            time.sleep(0.1)
        return False
    def dial(s, path, expect=None):
        c = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        cwd = os.getcwd(); os.chdir(s.net)
        try: c.connect(path)
        finally: os.chdir(cwd)
        hs = N.HS("XX", True, PRO, s.sk, os.urandom(32))
        L = Link(c, hs, expect)
        with s.lock:
            c.sendall(frame(hs.write(b""))); s.links.append(L)
        return L
    def send(s, L, pt):
        with s.lock:
            try: L.sock.sendall(frame(L.tx.enc(b"", pt)))
            except OSError: s._drop(L)
    def flood(s, pt, but=None):
        with s.lock:
            for L in list(s.links):
                if L.up() and L is not but: s.send(L, pt)
    def sendto(s, dest, text):
        """text sealed (Noise_X) to the node dest (hex NodeID) and flooded"""
        with s.lock:
            pub = s.dir.get(dest)
            if pub is None: s.ev("unknown", dest); return
            hs = N.HS("X", True, PRO, s.sk, os.urandom(32), rs=pub)
            s.flood(data(os.urandom(16), 16, bytes.fromhex(dest), hs.write(text)))
    def lie(s, root, man, body, c):
        with s.lock: s.lies[root] = (man, body, c)
    def _drop(s, L):
        if L in s.links:
            s.links.remove(L)
            try: L.sock.close()
            except OSError: pass
            s.ev("unlink", L.peer)
    def _loop(s):
        while not s.stop:
            with s.lock: socks = [s.lsock] + [L.sock for L in s.links]
            try: r, _, _ = select.select(socks, [], [], 0.1)
            except (OSError, ValueError): continue
            for so in r:
                with s.lock:
                    if so is s.lsock:
                        c, _ = s.lsock.accept()
                        s.links.append(Link(c, N.HS("XX", False, PRO, s.sk, os.urandom(32))))
                        continue
                    L = next((x for x in s.links if x.sock is so), None)
                    if L is None: continue
                    try: d = so.recv(65536)
                    except OSError: d = b""
                    if not d: s._drop(L); continue
                    L.buf += d
                    while len(L.buf) >= 4 and len(L.buf) >= 4 + struct.unpack(">I", L.buf[:4])[0]:
                        n = struct.unpack(">I", L.buf[:4])[0]; f = L.buf[4:4 + n]; L.buf = L.buf[4 + n:]
                        if L in s.links: s._frame(L, f)
    def _frame(s, L, f):
        if not L.up():
            try:
                L.hs.read(f)
                if L.hs.msgs: L.sock.sendall(frame(L.hs.write(b"")))
            except (N.Bad, ValueError):
                s.ev("drop", "handshake"); s._drop(L); return
            if not L.hs.msgs:
                L.tx, L.rx = L.hs.split(); L.peer = rawid(L.hs.rs).hex()
                s.ev("link", L.peer)
                s.send(L, presence(s.raw, s.pub, int(time.time() * 1000), s.path.encode()))
            return
        try: pt = L.rx.dec(b"", f)
        except N.Bad: s.ev("drop", "transport"); s._drop(L); return
        if pt[:1] == b"P" and len(pt) >= 58:
            pid, pub, seq = pt[1:17].hex(), pt[17:49], struct.unpack(">Q", pt[49:57])[0]
            if pid == s.id or s.seenp.get(pid, -1) >= seq or rawid(pub).hex() != pid: return
            s.seenp[pid] = seq; s.dir[pid] = pub; s.ev("presence", pid); s.flood(pt, but=L)
        elif pt[:1] == b"D" and len(pt) >= 35:
            mid, ttl, dest, blob = pt[1:17], pt[17], pt[18:34], pt[34:]
            if mid in s.seend: return
            s.seend.add(mid)
            if dest == s.raw:
                hs = N.HS("X", False, PRO, s.sk)
                try: text = hs.read(blob)
                except (N.Bad, ValueError): s.ev("drop", "blob"); return
                s._text(rawid(hs.rs).hex(), text)
            elif ttl - 1 >= 1: s.flood(data(mid, ttl - 1, dest, blob), but=L)
    def _text(s, frm, text):
        """the torrent wire, read from the format alone"""
        if text[:10] == b"TOR1 WANT " and len(text) == 74:
            root = text[10:].decode(); s.ev("want", root, frm)
            if root in s.lies: s.sendto(frm, b"TOR1 HAVE " + root.encode())
        elif text[:9] == b"TOR1 GET " and len(text) > 74 and text[73:74] == b" ":
            root, i = text[9:73].decode(), text[74:].decode(); s.ev("get", root, i, frm)
            if root in s.lies:
                man, body, c = s.lies[root]
                if i == "m": s.sendto(frm, b"TOR1 CHUNK " + root.encode() + b" m " + man)
                else:
                    k = int(i); s.sendto(frm, b"TOR1 CHUNK " + root.encode() + b" " + i.encode() + b" " + body[k * c:(k + 1) * c])
        else: s.ev("text", frm, text[:40])
    def close(s):
        s.stop = True; s.thread.join(2)
        with s.lock:
            for L in list(s.links):
                try: L.sock.close()
                except OSError: pass
            s.links = []
            s.lsock.close()
        cwd = os.getcwd(); os.chdir(s.net)
        try:
            if os.path.exists(s.path): os.remove(s.path)
        finally: os.chdir(cwd)
PYEOF

cat > "$T/tests.py" <<'PYEOF'
# tests.py TEST... — the gate's mesh tests: VM nodes and their torrent
# services driven from Python, checked against the gate's own manifest and
# root (oracle.py) and its own lying Python node (pytor.py). Prints PASS/FAIL
# lines; exits 1 on a FAIL.
import os, sys, time, re, signal, shutil, atexit, socket, threading
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from torlib import Mesh, frame, readframe, unix
from oracle import manifest, root
T = os.path.dirname(os.path.abspath(__file__))
NET = os.path.join(T, "net")
FAILS = 0
def check(ok, what, detail=""):
    global FAILS
    print(("PASS  logostorrent: " if ok else "FAIL  logostorrent: ") + what, flush=True)
    if not ok:
        FAILS += 1
        if detail: print("      " + str(detail)[:1200].replace("\n", " | "), flush=True)
MESHES, PYS = [], []
def cleanup():
    for p in PYS:
        try: p.close()
        except Exception: pass
    for m in MESHES: m.stop_all()
atexit.register(cleanup)
for sg in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
    signal.signal(sg, lambda *a: sys.exit(2))
def fresh():
    cleanup(); PYS.clear()
    shutil.rmtree(NET, ignore_errors=True)
    m = Mesh(NET, os.path.join(T, "logos_secd"), os.path.join(T, "node.bin"), os.path.join(T, "procs.pids"),
             svcprog=os.path.join(T, "svc.bin"))
    MESHES.append(m); return m
def tail(m, *names): return " || ".join("%s: %s" % (n, m.log(n)[-500:]) for n in names)
def okid(reply):
    return reply[3:] if reply and reply.startswith("ok\n") and re.fullmatch(r"[0-9a-f]{32}", reply[3:]) else None

def t_listen():
    m = fresh()
    a, bb = m.key("A"), m.key("B")
    m.start("B"); m.start("A", seeds=["B"])
    up = m.wait("A", r"^net: link %s$" % bb) and m.wait("B", r"^net: link %s$" % a)
    time.sleep(1.5)
    L = unix(NET, "B.ctl"); L.sendall(frame(b"listen T9"))
    r, buf = readframe(L)
    check(up and r == b"ok", "listen <tag>: the node answers ok and keeps the connection open", "%r %s" % (r, tail(m, "B")))
    payload = b"T9 " + bytes(range(256)) + b" end"
    mid = okid(m.node("A", b"send " + bb.encode() + b" " + payload))
    L.settimeout(60)
    got, buf = readframe(L, buf)
    check(mid is not None and got == a.encode() + b" " + payload and m.count("B", r"^net: recv ") == 0,
          "a DATA whose text begins with the tag and a space reaches the listener as one frame \"<from> <text>\", every byte intact (0..255), and is not logged as recv",
          "%r %r %s" % (mid, (got or b"")[:80], tail(m, "B")))
    for text in ("T9x not mine", "plain text", "T9"):
        m.node("A", "send %s %s" % (bb, text))
        okl = m.wait("B", r"^net: recv %s %s$" % (a, re.escape(text)))
        check(okl, "a text that does not begin with the tag and a space (%r) is logged as recv, not passed" % text, tail(m, "B"))
    L2 = unix(NET, "B.ctl"); L2.sendall(frame(b"listen T9"))
    r2, buf2 = readframe(L2)
    m.node("A", "send %s T9 to the latest" % bb)
    L2.settimeout(60)
    g2, buf2 = readframe(L2, buf2)
    L.setblocking(False)
    try: stray = L.recv(65536)
    except BlockingIOError: stray = b""
    check(r2 == b"ok" and g2 == a.encode() + b" T9 to the latest" and stray == b"",
          "with two listeners of a tag the latest gets the DATA, the earlier one nothing", "%r %r %r" % (r2, g2, stray))
    L2.close(); time.sleep(1)
    m.node("A", "send %s T9 back to the first" % bb)
    L.setblocking(True); L.settimeout(60)
    g1, buf = readframe(L, buf)
    L.close(); time.sleep(1)
    m.node("A", "send %s T9 nobody listens" % bb)
    gone = m.wait("B", r"^net: recv %s T9 nobody listens$" % a)
    check(g1 == a.encode() + b" T9 back to the first" and gone and m.count("B", r"^net: recv %s T9 (to the latest|back to the first)$" % a) == 0
          and m.node("B", "id") == "ok\n" + bb,
          "when the latest listener goes, the earlier one gets the tag again; when the last goes, the DATA is logged as recv; the node keeps running",
          "%r %s" % (g1, tail(m, "B")))
    bad = [m.node("B", c) for c in ("listen", "listen a b")]
    check(bad == ["err usage: listen <tag>"] * 2, "a malformed listen (no tag, two tags) is refused: err usage", bad)

# ── the torrent mesh ──────────────────────────────────────────────────
SVC = "chunk 512\nfind 20\nchunktime 8\nwindow 2\n"
FIND = 20
class Watch(threading.Thread):
    """polls a path while a fetch runs: every time the file is there its
    bytes must be one of `allowed`; counts .part files seen beside it"""
    def __init__(s, path, allowed):
        threading.Thread.__init__(s, daemon=True)
        s.path, s.allowed, s.bad, s.seen, s.parts, s.halt = path, allowed, [], 0, 0, False
    def run(s):
        d = os.path.dirname(s.path)
        while not s.halt:
            try:
                b = open(s.path, "rb").read(); s.seen += 1
                if b not in s.allowed: s.bad.append(len(b))
            except (FileNotFoundError, IsADirectoryError): pass
            try:
                if any(n.endswith(".part") for n in os.listdir(d)): s.parts += 1
            except FileNotFoundError: pass
            time.sleep(0.002)
    def end(s): s.halt = True; s.join(5); return s
def parts(d): return sorted(n for n in os.listdir(d) if n.endswith(".part"))
def lines(m, name, pat): return re.findall(pat, m.log(name), re.M)
def after(m, name, first, pat):
    """the lines matching pat that come after the first line matching first"""
    lg = m.log(name); mm = re.search(first, lg, re.M)
    return [] if mm is None else re.findall(pat, lg[mm.end():], re.M)
def peers(m, name):
    r = m.node(name, "peers") or ""
    return set(r.split("\n")[1:]) if r.startswith("ok") else None
def wait_peers(m, name, want, timeout=90):
    t0 = time.time()
    while time.time() - t0 < timeout:
        if peers(m, name) == set(want): return True
        time.sleep(0.5)
    return False
def knows(m, name, other, timeout=60):
    t0 = time.time()
    while time.time() - t0 < timeout:
        d = m.node(name, "directory") or ""
        if any(l.split(" ")[0] == other for l in d.split("\n")[1:]): return True
        time.sleep(0.5)
    return False
class Fetch(threading.Thread):
    """a fetch command running in the background (its reply comes when it ends)"""
    def __init__(s, m, name, line):
        threading.Thread.__init__(s, daemon=True); s.m, s.name, s.line, s.reply, s.t = m, name, line, None, None
    def run(s):
        t0 = time.time(); s.reply = s.m.tor(s.name, s.line, timeout=600); s.t = time.time() - t0

def t_torrent():
    m = fresh()
    ids = {n: m.key(n) for n in ("F", "S1", "R", "S2")}
    ring = ["F", "S1", "R", "S2"]
    for i, n in enumerate(ring):
        m.start(n, seeds=[ring[(i + 1) % 4]], reach=[ring[(i + 1) % 4], ring[(i - 1) % 4]])
    up = all(wait_peers(m, n, [ids[ring[(i + 1) % 4]], ids[ring[(i - 1) % 4]]]) for i, n in enumerate(ring))
    known = all(knows(m, n, ids[o]) for n in ring for o in ring if o != n)
    for n in ring: m.start_svc(n, SVC)
    svcup = all(m.wait(n + ".t", r"^torrent: up %s$" % ids[n]) for n in ring)
    check(up and known and svcup,
          "a ring of four LogosNet nodes F-S1-R-S2 (each linked to its two neighbours, all in every directory), each with its torrent service attached (torrent: up <its node's id>)",
          tail(m, "F", "F.t", "S2.t"))
    F, S1, S2 = m.svcdir("F"), m.svcdir("S1"), m.svcdir("S2")
    # ── seed: the root against the gate's own computation ──
    X = os.urandom(4096); rx = root(manifest(X, 512))
    for d in (S1, S2): open(os.path.join(d, "x.bin"), "wb").write(X)
    r1, r2 = m.tor("S1", "seed x.bin"), m.tor("S2", "seed x.bin 512")
    sl = m.tor("S1", "seeds")
    check(r1 == "ok\n" + rx and r2 == "ok\n" + rx and sl == "ok\n%s 4096 x.bin" % rx and m.wait("S1.t", r"^torrent: seed %s x\.bin$" % rx),
          "seed <path> answers the root the gate computes itself (hashlib) for a 4 KiB file in 512-byte chunks, on both seeders (the config's chunk size and an explicit one); seeds lists it",
          "%r %r %r want %s" % (r1, r2, sl, rx))
    # ── S2's copy changes on disk after seed: it serves corrupt chunks ──
    bad = bytearray(X)
    for k in range(0, 4096, 512): bad[k + 100] ^= 0x5a
    open(os.path.join(S2, "x.bin"), "wb").write(bytes(bad))
    w = Watch(os.path.join(F, "x.out"), {X}); w.start()
    t0 = time.time(); rf = m.tor("F", "fetch %s x.out" % rx); tf = time.time() - t0; time.sleep(0.3); w.end()
    got = open(os.path.join(F, "x.out"), "rb").read() if os.path.exists(os.path.join(F, "x.out")) else None
    g1, g2 = lines(m, "F.t", r"^torrent: get %s \d+ %s$" % (rx, ids["S1"])), lines(m, "F.t", r"^torrent: get %s \d+ %s$" % (rx, ids["S2"]))
    c1, c2 = lines(m, "F.t", r"^torrent: chunk %s (\d+) %s$" % (rx, ids["S1"])), lines(m, "F.t", r"^torrent: chunk %s \d+ %s$" % (rx, ids["S2"]))
    d2 = lines(m, "F.t", r"^torrent: drop chunk %s \d+ %s$" % (rx, ids["S2"]))
    late = after(m, "F.t", r"^torrent: drop chunk %s \d+ %s$" % (rx, ids["S2"]), r"^torrent: get %s \d+ %s$" % (rx, ids["S2"]))
    check(rf == "ok\nx.out" and got == X and sorted(map(int, c1)) == list(range(8)) and not c2 and d2,
          "4-node mesh, a 4 KiB file in 512-byte chunks seeded by two nodes, one serving corrupt chunks: the fetcher assembles the exact file (%.1f s); every chunk S2 sent was refused (%d), all 8 came from S1" % (tf, len(d2)),
          "%r same=%r c1=%r c2=%r d2=%r %s" % (rf, got == X, c1, c2, d2, tail(m, "F.t")))
    check(len(g1) >= 1 and len(g2) >= 1 and lines(m, "S2.t", r"^torrent: serve %s \d+ %s$" % (rx, ids["F"])) and not late,
          "the GETs were spread over both seeders (%d to S1, %d to S2, which served them); after S2's first bad chunk it was not asked again" % (len(g1), len(g2)),
          "late %r %s" % (late, tail(m, "F.t")))
    check(not w.bad and not parts(F),
          "x.out, polled through the whole fetch, was absent until it was whole (%d reads once it was there, all the exact file); no .part file is left" % w.seen,
          "%r %r" % (w.bad[:5], parts(F)))
    open(os.path.join(S2, "x.bin"), "wb").write(X)
    # ── a seeder killed mid-fetch: the fetch completes from the other ──
    Y = os.urandom(8192); ry = root(manifest(Y, 512))
    for d in (S1, S2): open(os.path.join(d, "y.bin"), "wb").write(Y)
    m.tor("S1", "seed y.bin"); m.tor("S2", "seed y.bin")
    fe = Fetch(m, "F", "fetch %s y.out" % ry); fe.start()
    first = m.wait("F.t", r"^torrent: chunk %s \d+ %s$" % (ry, ids["S1"]), timeout=120)
    m.kill("S1")
    at_kill = len(lines(m, "F.t", r"^torrent: chunk %s \d+ " % ry))
    fe.join(400)
    goty = open(os.path.join(F, "y.out"), "rb").read() if os.path.exists(os.path.join(F, "y.out")) else None
    k1, k2 = lines(m, "F.t", r"^torrent: chunk %s \d+ %s$" % (ry, ids["S1"])), lines(m, "F.t", r"^torrent: chunk %s \d+ %s$" % (ry, ids["S2"]))
    to1 = lines(m, "F.t", r"^torrent: timeout %s \d+ %s$" % (ry, ids["S1"]))
    late1 = after(m, "F.t", r"^torrent: timeout %s \d+ %s$" % (ry, ids["S1"]), r"^torrent: get %s \d+ %s$" % (ry, ids["S1"]))
    check(first and at_kill < 16 and fe.reply == "ok\ny.out" and goty == Y and len(k1) >= 1 and len(k1) + len(k2) == 16,
          "a seeder (S1) killed mid-fetch, after %d of 16 chunks were in: the fetch completes from the other (%d chunks from S1 before, %d from S2), exact, in %.1f s" % (at_kill, len(k1), len(k2), fe.t or -1),
          "%r same=%r %s" % (fe.reply, goty == Y, tail(m, "F.t")))
    check(not late1 and m.rc("S1.t", timeout=20) == 0 and m.wait("S1.t", r"^torrent: down %s$" % ids["S1"], timeout=5)
          and "the node closed its connection" in m.log("S1.t"),
          "the GETs the dead seeder held timed out (%d) and it was not asked again; its torrent service ended by itself when its node went (exit 0)" % len(to1),
          "late %r %s" % (late1, tail(m, "S1.t")))
    # ── an unknown root: not found after a timeout; nothing written ──
    ru = os.urandom(32).hex()
    K = b"keep me\n" * 10
    open(os.path.join(F, "keep.bin"), "wb").write(K); os.link(os.path.join(F, "keep.bin"), os.path.join(F, "keep.link"))
    ino = os.stat(os.path.join(F, "keep.bin")).st_ino
    fu = Fetch(m, "F", "fetch %s keep.bin" % ru); fu.start()
    time.sleep(3)
    fl = m.tor("F", "fetches"); again = m.tor("F", "fetch %s other.bin" % ru)
    fu.join(200)
    check(fu.reply == "err not found " + ru and FIND - 1 <= (fu.t or 0) < FIND + 40 and m.wait("F.t", r"^torrent: fail %s not found$" % ru, timeout=5),
          "an unknown root reports not found after the find timeout (err not found <root> after %.1f s; find is %d s)" % (fu.t or -1, FIND),
          "%r %s" % (fu.reply, tail(m, "F.t")))
    check(open(os.path.join(F, "keep.bin"), "rb").read() == K and os.stat(os.path.join(F, "keep.bin")).st_ino == ino and not parts(F)
          and not os.path.exists(os.path.join(F, "other.bin")),
          "a failed fetch leaves nothing behind: the file already at its <out> is untouched (same bytes, same inode), no .part file", parts(F))
    check(fl == "ok\n%s 0/? keep.bin" % ru and again == "err already fetching " + ru,
          "during a fetch: fetches shows it (0 chunks of an unknown count), a second fetch of the same root is refused", "%r %r" % (fl, again))
    # ── a node whose manifest is not the root's: refused ──
    P = py()
    m.keys["P"] = (P.sk, P.pub, P.id)
    L = P.dial(m.path("F"), expect=ids["F"])
    linked = P.wait("link", ids["F"]) and knows(m, "F", P.id) and P.wait("presence", ids["F"], timeout=30)
    Z = os.urandom(2000); rz = root(manifest(Z, 512))
    lie = os.urandom(2000); P.lie(rz, manifest(lie, 512), lie, 512)
    t0 = time.time(); rl = m.tor("F", "fetch %s z.out" % rz); tl = time.time() - t0
    asked = [e for e in P.events if e[0] == "get" and e[1] == rz]
    check(linked and rl == "err no manifest " + rz and m.wait("F.t", r"^torrent: drop manifest %s %s$" % (rz, P.id), timeout=1)
          and [e[2] for e in asked] == ["m"] and not os.path.exists(os.path.join(F, "z.out")) and not parts(F),
          "a manifest whose hash is not the root is refused: the gate's own Python node answers HAVE and serves a well-formed manifest of other bytes; the fetcher drops it, never asks that node for a chunk, and fails (err no manifest, %.1f s) leaving no file" % tl,
          "%r asked=%r %s" % (rl, asked, tail(m, "F.t")))
    open(os.path.join(S2, "z.bin"), "wb").write(Z); m.tor("S2", "seed z.bin")
    n0, l0 = len(P.events), len(m.log("F.t"))
    rl2 = m.tor("F", "fetch %s z.out" % rz)
    gotz = open(os.path.join(F, "z.out"), "rb").read() if os.path.exists(os.path.join(F, "z.out")) else None
    asked2 = [e[2] for e in P.events[n0:] if e[0] == "get" and e[1] == rz]
    lg2 = m.log("F.t")[l0:]
    taken = re.findall(r"^torrent: (?:manifest|chunk) %s (?:\d+ )?%s$" % (rz, P.id), lg2, re.M)
    refused = re.findall(r"^torrent: drop (?:manifest|chunk) %s (?:\d+ |m )?%s$" % (rz, P.id), lg2, re.M)
    check(rl2 == "ok\nz.out" and gotz == Z and not taken,
          "with an honest seeder beside the liar, the same fetch completes with the exact file; nothing the liar sent was taken (asked %s, refused %d times)" % (",".join(asked2) or "nothing", len(refused)),
          "%r %r %r %s" % (rl2, asked2, taken, tail(m, "F.t")))
    # ── the write: atomic replacement, and a failed write removes its .part ──
    O = b"the old file\n" * 50
    open(os.path.join(F, "old.bin"), "wb").write(O); os.link(os.path.join(F, "old.bin"), os.path.join(F, "old.link"))
    ino = os.stat(os.path.join(F, "old.bin")).st_ino
    w = Watch(os.path.join(F, "old.bin"), {O, X}); w.start()
    ro = m.tor("F", "fetch %s old.bin" % rx); w.end()
    check(ro == "ok\nold.bin" and open(os.path.join(F, "old.bin"), "rb").read() == X and open(os.path.join(F, "old.link"), "rb").read() == O
          and os.stat(os.path.join(F, "old.bin")).st_ino != ino and not w.bad and not parts(F),
          "the file is written atomically: an <out> that exists is replaced by a rename (a hard link to the old file still reads the old bytes; the name holds the new, a new inode), and in %d reads during the fetch it was only ever the old file or the new one; no .part left" % w.seen,
          "%r bad=%r %r %s" % (ro, w.bad[:5], parts(F), tail(m, "F.t")))
    os.mkdir(os.path.join(F, "adir"))
    ra, rn = m.tor("F", "fetch %s adir" % rx), m.tor("F", "fetch %s nodir/x.bin" % rx)
    check(ra == "err cannot write adir" and rn == "err cannot write nodir/x.bin" and os.path.isdir(os.path.join(F, "adir")) and not parts(F)
          and not os.path.exists(os.path.join(F, "nodir")),
          "a write that cannot complete fails the fetch (its out is a directory; its directory does not exist): err cannot write, the .part file it made removed, nothing else touched",
          "%r %r %r" % (ra, rn, parts(F)))
    # ── an empty file ──
    open(os.path.join(S2, "e.bin"), "wb").write(b"")
    re_ = root(manifest(b"", 512)); rs = m.tor("S2", "seed e.bin")
    rfe = m.tor("F", "fetch %s e.out" % re_)
    check(rs == "ok\n" + re_ and rfe == "ok\ne.out" and os.path.exists(os.path.join(F, "e.out")) and os.path.getsize(os.path.join(F, "e.out")) == 0,
          "an empty file (a manifest with no chunk lines) is seeded with the gate's root and fetched as an empty file", "%r %r" % (rs, rfe))
    # ── the control channel ──
    rep = [m.tor("F", c) for c in ("seed nosuch.bin", "seed adir", "seed x.out 0", "seed x.out 65281", "seed", "fetch 123 o",
                                    "fetch %s" % rx, "fetch %s a b" % rx, "fetch %s o" % rx.upper(), "bogus", "")]
    want = ["err cannot stat nosuch.bin", "err not a regular file: adir"] + ["err usage: seed <path> [<chunk>]"] * 3 \
         + ["err usage: fetch <root> <out>"] * 4 + ["err unknown command bogus", "err empty command"]
    check(rep == want, "control errors: a missing file, a directory, chunk sizes 0 and 65281, no path, a short, missing or uppercase root, extra words, an unknown command, an empty line", rep)
    sl = m.tor("F", "seeds")
    check(sl is not None and set(sl.split("\n")[1:]) == {"%s 4096 old.bin" % rx, "%s 8192 y.out" % ry, "%s 2000 z.out" % rz, "%s 0 e.out" % re_},
          "a fetched file is seeded from where it was written (seeds: the latest out of each root)", sl)
    q = m.tor("F", "quit")
    check(q == "ok" and m.rc("F.t") == 0 and m.wait("F.t", r"^torrent: down %s$" % ids["F"], timeout=5) and not os.path.exists(os.path.join(F, "svc.ctl"))
          and m.node("F", "id") == "ok\n" + ids["F"],
          "quit: the service answers ok, logs down, exits 0 and removes its socket; its node runs on", "%r %s" % (q, tail(m, "F.t")))

def py(**kw):
    from pytor import PyTor
    p = PyTor(NET, **kw); PYS.append(p); return p

TESTS = {"listen": t_listen, "torrent": t_torrent}
if __name__ == "__main__":
    for name in sys.argv[1:]:
        try: TESTS[name]()
        except Exception as e:
            import traceback; traceback.print_exc()
            check(False, "%s: the test itself failed: %r" % (name, e))
    cleanup()
    sys.exit(1 if FAILS else 0)
PYEOF

cat > "$T/oracle.py" <<'PYEOF'
# oracle.py MODE [SEED] — the gate's own manifest, root and parse (hashlib
# only), independent of the LA.
import os, sys, hashlib, random
def manifest(data, c):
    n = (len(data) + c - 1) // c
    return b"LTOR1\n%d\n%d\n" % (len(data), c) + b"".join(
        hashlib.sha256(data[i * c:(i + 1) * c]).hexdigest().encode() + b"\n" for i in range(n))
def root(m): return hashlib.sha256(m).hexdigest()
def dec(x):
    ok = 1 <= len(x) <= 12 and all(48 <= ch <= 57 for ch in x) and (x[:1] != b"0" or len(x) == 1)
    return int(x) if ok else None
def parse(m):
    """(length, chunk, n, h0) of a well-formed manifest, else None"""
    if m[:6] != b"LTOR1\n": return None
    i = m.find(b"\n", 6)
    if i < 0: return None
    j = m.find(b"\n", i + 1)
    if j < 0: return None
    flen, c = dec(m[6:i]), dec(m[i + 1:j])
    if flen is None or c is None or not 1 <= c <= 65280: return None
    h0, n = j + 1, (flen + c - 1) // c
    if len(m) != h0 + 65 * n: return None
    for k in range(n):
        ln = m[h0 + 65 * k:h0 + 65 * k + 65]
        if ln[64:] != b"\n" or any(ch not in b"0123456789abcdef" for ch in ln[:64]): return None
    return (flen, c, n, h0)
if __name__ == "__main__":
    mode = sys.argv[1]
    R = random.Random(int(sys.argv[2]) if len(sys.argv) > 2 else 1)
    CASES = [("empty", 0, 512), ("one", 1, 512), ("short", 511, 512), ("exact", 512, 512), ("tail", 513, 512),
             ("k4", 4096, 512), ("k4p", 4097, 512), ("unit", 5, 1), ("many", 100000, 100), ("max", 70000, 65280),
             ("odd", 9999, 333)]
    if mode == "mancases":
        with open("cases.txt", "w") as f:
            for name, size, c in CASES:
                open(name + ".dat", "wb").write(bytes(R.randrange(256) for _ in range(size)))
                f.write("%s.dat %d\n" % (name, c))
    if mode == "mancheck":
        got = dict(l.split(" ", 1) for l in open("man.out").read().split("\n") if " " in l)
        bad = []
        for name, size, c in CASES:
            m = manifest(open(name + ".dat", "rb").read(), c)
            try: lm = open(name + ".dat.man", "rb").read()
            except FileNotFoundError: lm = None
            if lm != m: bad.append(name + ": manifest differs")
            if got.get(name + ".dat") != root(m): bad.append(name + ": root %s, not %s" % (got.get(name + ".dat"), root(m)))
        print("ok %d" % len(CASES) if not bad else "; ".join(bad))
    if mode == "parsecases":
        good = manifest(bytes(R.randrange(256) for _ in range(1300)), 512)   # 3 lines
        h0 = good.index(b"\n", 6); h0 = good.index(b"\n", h0 + 1) + 1
        P = {"good": good, "good0": manifest(b"", 512), "goodmax": manifest(b"", 65280),
             "good1k": manifest(bytes(1000), 1), "goodtail": manifest(bytes(70000), 65280),
             "magic": b"LTOR2" + good[5:], "lower": b"ltor1" + good[5:],
             "lead0": good.replace(b"\n1300\n", b"\n01300\n", 1), "chunk0": b"LTOR1\n0\n0\n",
             "chunkbig": b"LTOR1\n0\n65281\n", "upper": good[:h0] + good[h0:h0 + 64].upper() + good[h0 + 64:],
             "shortline": good[:h0 + 10] + good[h0 + 11:], "extra": good + b"0", "fewer": good[:-1],
             "missing": good[:-65], "count": good.replace(b"\n1300\n", b"\n1600\n", 1),
             "empty": b"", "magiconly": b"LTOR1\n", "nolf": b"LTOR1\n1300", "nolf2": b"LTOR1\n1300\n512",
             "huge": b"LTOR1\n999999999999\n65280\n" + good[h0:], "toolong": b"LTOR1\n1234567890123\n512\n",
             "plus": good.replace(b"\n1300\n", b"\n+1300\n", 1), "minus": b"LTOR1\n-0\n512\n",
             "space": good.replace(b"\n512\n", b"\n 512\n", 1), "nonhex": good[:h0] + b"g" + good[h0 + 1:],
             "crlf": good.replace(b"\n", b"\r\n")}
        with open("pcases.txt", "w") as f:
            for k, v in P.items():
                open("p_%s.man" % k, "wb").write(v); f.write("p_%s.man\n" % k)
        with open("parse.exp", "w") as f:
            for k, v in P.items():
                r = parse(v)
                f.write("p_%s.man %s\n" % (k, "none" if r is None else "some %d %d %d %d" % r))
        nsome = sum(parse(v) is not None for v in P.values())
        open("parse.count", "w").write("%d %d" % (nsome, len(P) - nsome))
PYEOF

# t.la: the manifest tests, one program dispatching on mode.txt (no network:
# TORRENT_KIT's net is only used by service)
cat > "$T/t.la" <<'LAEOF'
import("logostorrent.la")
import("logoscrypt.la")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph SEQ = la a. la b. b
glyph B = la s. s(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(str_eq)(error)
                 (add)(sub)(mul)(div)(mod)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr)
glyph X = la s. s(socket)(bind)(listen)(accept)(connect)(send)(recv)(close)(unlink)(poll)
                 (random)(clock_gettime)(print)(read_file)(open)(read)(write)(lseek)(rename)(stat)(sigprocmask)
glyph CRYPT = CRYPT_FAST(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(error)
    (add)(sub)(mul)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr)
glyph LEN = la s. str_to_int(str_len(s))
# SUB(s)(a)(b): bytes a..b-1 of s (short strings only: it is quadratic)
glyph SUB = la s. la a. la b. Z(la go. la i. la acc. lt(i)(b)(la _. go(add(i)(1))(concat(acc)(str_at(s)(i))))(la _. acc)("!"))(a)("")
# IDX(s)(c): the first index of c in s, or its length
glyph IDX = la s. la c. Z(la go. la i. lt(i)(LEN(s))(la _. str_eq(str_at(s)(i))(c)(la _. i)(la _. go(add(i)(1)))("!"))(la _. i)("!"))(0)
# EACH(f)(s): f on each non-empty line of s, in order
glyph EACH = la f. la s. Z(la go. la rest. lt(0)(LEN(rest))
    (la _. (la i. SEQ(lt(0)(i)(la _. f(SUB(rest)(0)(i)))(la _. "")("!"))(go(SUB(rest)(add(i)(1))(LEN(rest)))))(IDX(rest)("\n")))
    (la _. "")("!"))(s)
glyph SP = la a. la b. concat(a)(concat(" ")(b))
glyph MAIN = TORRENT_KIT(B)(X)(CRYPT)(la s. error("t.la: no net"))(la manifest. la root. la parse. la service.
  (la mode.
    str_eq(mode)("man")(la _. EACH(la ln. (la i. (la file. (la m. SEQ(write_file(concat(file)(".man"))(m))(print(SP(file)(root(m)))))
                                                       (manifest(read_file(file))(str_to_int(SUB(ln)(add(i)(1))(LEN(ln))))))
                                             (SUB(ln)(0)(i)))(IDX(ln)(" ")))(read_file("cases.txt")))
    (la _. str_eq(mode)("parse")(la _. EACH(la file. print(SP(file)(parse(read_file(file))(la _. "none")
                                     (la i. i(la m. la flen. la c. la n. la h0.
                                         SP("some")(SP(int_to_str(flen))(SP(int_to_str(c))(SP(int_to_str(n))(int_to_str(h0))))))))))
                                   (read_file("pcases.txt")))
    (la _. str_eq(mode)("bad0")(la _. SEQ(manifest("abc")(0))(print("bad0: no halt")))
    (la _. str_eq(mode)("bad65281")(la _. SEQ(manifest("abc")(65281))(print("bad65281: no halt")))
    (la _. print(concat("unknown mode ")(mode)))("!"))("!"))("!"))("!"))
  (read_file("mode.txt")))
LAEOF

# node.la: one LogosNet node; its config file is argv[1] (from /proc/self/cmdline)
cat > "$T/node.la" <<'LAEOF'
import("logosnet.la")
import("logoscrypt.la")
import("x25519.la")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph B = la s. s(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(str_eq)(error)
                 (add)(sub)(mul)(div)(mod)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr)
glyph X = la s. s(socket)(bind)(listen)(accept)(connect)(send)(recv)(close)(unlink)(poll)
                 (random)(clock_gettime)(print)(read_file)(write_file)(chmod)(stat)(mkdir)
                 (rmdir)(rename)(sigprocmask)
glyph CRYPT = CRYPT_FAST(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(error)
    (add)(sub)(mul)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr)
glyph XK = X25519_KIT(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(error)
    (add)(sub)(mul)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr)
# ARG1(cmdline): the second NUL-terminated field of /proc/self/cmdline (argv[1])
glyph ARG1 = la cl. Z(la go. la i. la start. la seen.
    lt(i)(str_to_int(str_len(cl)))
      (la _. str_eq(str_at(cl)(i))(chr("0"))
               (la _. int_eq(seen)(1)(la _. Z(la cut. la j. la acc. lt(j)(i)(la _. cut(add(j)(1))(concat(acc)(str_at(cl)(j))))(la _. acc)("!"))(start)(""))
                                      (la _. go(add(i)(1))(add(i)(1))(add(seen)(1)))("!"))
               (la _. go(add(i)(1))(start)(seen))("!"))
      (la _. error("node: usage: logos_secd <config file>"))("!"))(0)(0)(0)
glyph MAIN = (la crypt. NODE(B)(X)(crypt)(NET_KIT(B)(X)(crypt)(XK))(read_file(ARG1(read_file("/proc/self/cmdline")))))(CRYPT)
LAEOF

# svc.la: one node's torrent service; its config file is argv[1]
cat > "$T/svc.la" <<'LAEOF'
import("logostorrent.la")
import("logosnet.la")
import("logoscrypt.la")
import("x25519.la")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph B = la s. s(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(str_eq)(error)
                 (add)(sub)(mul)(div)(mod)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr)
glyph X = la s. s(socket)(bind)(listen)(accept)(connect)(send)(recv)(close)(unlink)(poll)
                 (random)(clock_gettime)(print)(read_file)(open)(read)(write)(lseek)(rename)(stat)(sigprocmask)
glyph NX = la s. s(socket)(bind)(listen)(accept)(connect)(send)(recv)(close)(unlink)(poll)
                 (random)(clock_gettime)(print)(read_file)(write_file)(chmod)(stat)(mkdir)
                 (rmdir)(rename)(sigprocmask)
glyph CRYPT = CRYPT_FAST(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(error)
    (add)(sub)(mul)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr)
glyph XK = X25519_KIT(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(error)
    (add)(sub)(mul)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr)
# ARG1(cmdline): the second NUL-terminated field of /proc/self/cmdline (argv[1])
glyph ARG1 = la cl. Z(la go. la i. la start. la seen.
    lt(i)(str_to_int(str_len(cl)))
      (la _. str_eq(str_at(cl)(i))(chr("0"))
               (la _. int_eq(seen)(1)(la _. Z(la cut. la j. la acc. lt(j)(i)(la _. cut(add(j)(1))(concat(acc)(str_at(cl)(j))))(la _. acc)("!"))(start)(""))
                                      (la _. go(add(i)(1))(add(i)(1))(add(seen)(1)))("!"))
               (la _. go(add(i)(1))(start)(seen))("!"))
      (la _. error("torrent: usage: logos_secd <config file>"))("!"))(0)(0)(0)
glyph MAIN = (la crypt. TORRENT_KIT(B)(X)(crypt)(NET_KIT(B)(NX)(crypt)(XK))(la manifest. la root. la parse. la service.
    service(read_file(ARG1(read_file("/proc/self/cmdline"))))))(CRYPT)
LAEOF

echo "      compiling the test program, the node and the torrent service on the VM ..."
tc0=$(date +%s)
vm_compile t.la t.bin
vm_compile node.la node.bin
vm_compile svc.la svc.bin
echo "      (compiled in $(( $(date +%s) - tc0 )) s)"

# tests TEST...: the Python driver's tests and their PASS/FAIL lines
tests() {
    ( cd "$T" && timeout 1800 python3 tests.py "$@" ) > "$T/tests.out" 2>&1
    local rc=$?
    cat "$T/tests.out"
    grep -q '^FAIL' "$T/tests.out" && ok=0
    [ "$rc" = 0 ] || { grep -q '^FAIL' "$T/tests.out" || echo "FAIL  logostorrent: tests.py $* ended with rc $rc"; ok=0; }
}

# ── 1. listen ──────────────────────────────────────────────────────────
tests listen

# ── 2. the manifest ────────────────────────────────────────────────────
( cd "$T" && python3 oracle.py mancases "$RANDOM" )
vm_run t.bin man "$T/man.out"
( cd "$T" && python3 oracle.py mancheck ) > "$T/man.cmp"
check "$([ "$vrc" = 0 ] && [ "$(cut -d' ' -f1 "$T/man.cmp")" = ok ] && echo 1)" \
    "manifest and root equal the gate's own (hashlib) byte for byte on $(grep -c . "$T/cases.txt") random files: empty, 1 byte, 511/512/513 and 4096/4097 bytes in 512-byte chunks, 1-byte chunks, 1000 chunks of 100, 70000 bytes in 65280-byte chunks, 9999 in 333" \
    "rc $vrc; $(cat "$T/man.cmp"); $(tail -c 200 "$T/vre")"
( cd "$T" && python3 oracle.py parsecases "$RANDOM" )
vm_run t.bin parse "$T/parse.out"
read -r np nn < "$T/parse.count"
check "$([ "$vrc" = 0 ] && cmp -s "$T/parse.exp" "$T/parse.out" && echo 1)" \
    "parse agrees with the gate's own reading on $np well-formed manifests (length, chunk, count, offset) and refuses all $nn malformed ones without halting" \
    "rc $vrc; $(diff "$T/parse.exp" "$T/parse.out" | head -c 400); $(tail -c 200 "$T/vre")"
for bm in bad0 bad65281; do
    vm_run t.bin $bm "$T/$bm.out"
    check "$([ "$vrc" = 1 ] && [ ! -s "$T/$bm.out" ] && grep -q '^logostorrent: manifest: the chunk size must be 1..65280 bytes' "$T/vre" && echo 1)" \
        "manifest halts on the chunk size ${bm#bad} (rc $vrc: $(head -c 80 "$T/vre"))"
done

# ── 3. the torrent service on a mesh ───────────────────────────────────
tests torrent

echo "      (gate ran $(( $(date +%s) - G0 )) s)"
if [ "$ok" = 1 ]; then echo "PASS  logostorrent: all checks"; exit 0; else echo "FAIL  logostorrent: some checks failed"; exit 1; fi
