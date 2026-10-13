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
# ISOLATION: a private temp dir (gate_wm_common.sh; mktemp honours TMPDIR):
# every socket is in it; every VM process is killed on every exit path.
# VM only (the C host is far too slow for the crypto underneath).
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
# torlib.py — drives LogosNet nodes (VM processes) for the gate.
# Every node runs with its working directory at the net directory NET, so
# socket paths stay short (./<id>.sock); its log is NET/<name>.log.
import os, sys, time, socket, struct, subprocess, signal, hashlib, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

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

def x_pub(sk):
    from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey
    from cryptography.hazmat.primitives import serialization as S
    return X25519PrivateKey.from_private_bytes(sk).public_key().public_bytes(S.Encoding.Raw, S.PublicFormat.Raw)

class Mesh:
    def __init__(s, net, vm, prog, pidfile=None):
        s.net, s.vm, s.prog, s.pidfile = net, vm, prog, pidfile   # prog: the compiled node stream
        s.procs, s.keys = {}, {}
        os.makedirs(net, exist_ok=True)
        open(os.path.join(net, "logos_program.bin"), "wb").write(open(prog, "rb").read())
    def key(s, name, sk=None):
        """a key file NET/<name>.key (mode 0600) and the NodeID it must give"""
        sk = sk or os.urandom(32)
        p = os.path.join(s.net, name + ".key")
        if os.path.exists(p): os.remove(p)
        fd = os.open(p, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600); os.write(fd, sk); os.close(fd)
        pub = x_pub(sk)
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
    def kill(s, name, sig=signal.SIGKILL):
        p = s.procs.pop(name, None)
        if p is not None and p.poll() is None:
            p.send_signal(sig); p.wait()
    def rc(s, name, timeout=30):
        p = s.procs.get(name)
        try: return p.wait(timeout)
        except subprocess.TimeoutExpired: return None
    def stop_all(s):
        for n in list(s.procs): s.kill(n)
PYEOF

cat > "$T/tests.py" <<'PYEOF'
# tests.py TEST... — the gate's mesh tests: VM nodes driven from Python.
# Prints PASS/FAIL lines; exits 1 on a FAIL.
import os, sys, time, re, signal, shutil, atexit, socket
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from torlib import Mesh, frame, readframe, unix
T = os.path.dirname(os.path.abspath(__file__))
NET = os.path.join(T, "net")
FAILS = 0
def check(ok, what, detail=""):
    global FAILS
    print(("PASS  logostorrent: " if ok else "FAIL  logostorrent: ") + what, flush=True)
    if not ok:
        FAILS += 1
        if detail: print("      " + str(detail)[:900].replace("\n", " | "), flush=True)
MESHES = []
def cleanup():
    for m in MESHES: m.stop_all()
atexit.register(cleanup)
for sg in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
    signal.signal(sg, lambda *a: sys.exit(2))
def fresh():
    cleanup()
    shutil.rmtree(NET, ignore_errors=True)
    m = Mesh(NET, os.path.join(T, "logos_secd"), os.path.join(T, "node.bin"), os.path.join(T, "procs.pids"))
    MESHES.append(m); return m
def tail(m, *names): return " || ".join("%s: %s" % (n, m.log(n)[-400:]) for n in names)
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

TESTS = {"listen": t_listen}
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
glyph MAIN = TORRENT_KIT(B)(X)(CRYPT)(la s. error("t.la: no net"))(la manifest. la root. la parse.
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

echo "      compiling the test program and the node on the VM ..."
tc0=$(date +%s)
vm_compile t.la t.bin
vm_compile node.la node.bin
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

echo "      (gate ran $(( $(date +%s) - G0 )) s)"
if [ "$ok" = 1 ]; then echo "PASS  logostorrent: all checks"; exit 0; else echo "FAIL  logostorrent: some checks failed"; exit 1; fi
