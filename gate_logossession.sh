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
# the contract derives from a passphrase.
#   P  PBKDF2-HMAC-SHA256 (RFC 8018), the module's PBKDF2_KIT, against the
#      RFC 6070 inputs with SHA-256 (the published answers, each confirmed by
#      hashlib.pbkdf2_hmac), RFC 7914 section 11's first vector (two blocks),
#      a key longer than the HMAC block, an empty password, and dklen 1 and 33
#      (a cut final block); iter 0 halts loudly.
# ISOLATION: private temp dir (gate_wm_common.sh); everything is written
# under it. SESSION_SHARDS (default "P") names the shards to run;
# SESSION_CMD_TIMEOUT (default 1800 s) bounds each operation.
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1
: "${SESSION_SHARDS:=P}"
: "${SESSION_CMD_TIMEOUT:=1800}"
: "${SESSION_SHARD_TIMEOUT:=7200}"
wm_setup logossession.la logoscrypt.la

# ── the driver: one command per stdin line, one "= ok …"/"= err …" line back ──
# A command is "word slot field…" with every field hex-encoded.
cat > "$T/drv.la" <<'LAEOF'
import("logoscrypt.la")
import("logossession.la")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph NIL = la n. la c. n(n)
glyph CONS = la h. la t. la n. la c. c(h)(t)
glyph LEN = la s. str_to_int(str_len(s))
glyph HV = la c. (la n. lt(n)(58)(la _. sub(n)(48))(la _. sub(n)(87))("!"))(str_to_int(ord(c)))
glyph UNHEX = la s. Z(la self. la i. la n.
    lt(i)(n)(la _. concat(chr(int_to_str(add(mul(HV(str_at(s)(i)))(16))(HV(str_at(s)(add(i)(1)))))))
                        (self(add(i)(2))(n)))(la _. "")("!"))(0)(LEN(s))
glyph HD = la n. str_at("0123456789abcdef")(n)
glyph HEXE = la s. Z(la self. la i. la n.
    lt(i)(n)(la _. (la b. concat(concat(HD(div(b)(16)))(HD(mod(b)(16))))(self(add(i)(1))(n)))(str_to_int(ord(str_at(s)(i)))))
      (la _. "")("!"))(0)(LEN(s))
# SUB(s)(i)(j): bytes i..j-1, joined by halves
glyph SUB = Z(la self. la s. la i. la j.
    lt(add(i)(1))(j)(la _. (la m. concat(self(s)(i)(m))(self(s)(m)(j)))(add(i)(div(sub(j)(i))(2))))
      (la _. lt(i)(j)(la _. str_at(s)(i))(la _. "")("!"))("!"))
glyph FIND = la s. la c. Z(la go. la i. la n. lt(i)(n)(la _. str_eq(str_at(s)(i))(c)(la _. i)(la _. go(add(i)(1))(n))("!"))(la _. n)("!"))(0)(LEN(s))
glyph SPLIT = la s. la c. (la n. Z(la go. la i. la j.
    lt(j)(n)(la _. str_eq(str_at(s)(j))(c)(la _. CONS(SUB(s)(i)(j))(go(add(j)(1))(add(j)(1))))(la _. go(i)(add(j)(1)))("!"))
            (la _. CONS(SUB(s)(i)(n))(NIL))("!"))(0)(0))(LEN(s))
glyph NTH = Z(la self. la l. la i. l(la _. "")(la h. la t. int_eq(i)(0)(la _. h)(la _. self(t)(sub(i)(1)))("!")))
glyph CR = CRYPT_FAST(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(error)(add)(sub)(mul)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr)
glyph STEP = la PB. la w. la k.
  (la cmd. la s1. la a2. la a3. la a4. la a5.
    str_eq(cmd)("pbkdf2")(la _. k(concat("= ok ")(HEXE(PB(a2)(a3)(str_to_int(a4))(str_to_int(a5))))))(la _.
    k(concat("= err unknown command ")(cmd)))("!"))
  (NTH(w)(0))(NTH(w)(1))(UNHEX(NTH(w)(2)))(UNHEX(NTH(w)(3)))(UNHEX(NTH(w)(4)))(UNHEX(NTH(w)(5)))
glyph READLINE = Z(la self. la buf. la k. (la i.
    lt(i)(LEN(buf))
      (la _. k(SUB(buf)(0)(i))(SUB(buf)(add(i)(1))(LEN(buf))))
      (la _. (la more. str_eq(more)("")(la _. k("quit")(""))(la _. self(concat(buf)(more))(k))("!"))(read("0")("65536")))("!"))
  (FIND(buf)("\n")))
glyph LOOP = Z(la loop. la PB. la buf.
  READLINE(buf)(la line. la rest. (la w.
    str_eq(NTH(w)(0))("quit")(la _. "bye")(la _.
      STEP(PB)(w)(la out. (la _. loop(PB)(rest))(print(out))))("!"))
  (SPLIT(line)(" "))))
glyph MAIN = (la cr. LOOP(PBKDF2_KIT(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(add)(sub)(mul)(div)(mod)(lt)(int_eq)(bxor)(error)(cr))(""))(CR)
LAEOF

# ── the oracle and the shards ───────────────────────────────────────────────
cat > "$T/sgate.py" <<'PYEOF'
import hashlib, hmac, os, select, subprocess, sys, time

def pbkdf2(p, s, c, n): return hashlib.pbkdf2_hmac('sha256', p, s, c, n)

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
        while True:
            l = self._line(deadline)
            if l.startswith('= '):
                dt = time.time() - t0; self.times.append((word, dt, l.startswith('= ok')))
                self.log.write('%-8s %7.2fs  %s\n' % (word, dt, l[:160])); self.log.flush()
                return l[2:]
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
        check('P pbkdf2(%r, %r, %d, %d) = %s' % (p[:24], sa[:24], c, n, 'the published answer' if pub else 'hashlib\'s'),
              r == 'ok ' + want and (pub is None or want == pub), (r, want))
    # LAST: iter 0 halts the driver loudly
    try:
        r = s.cmd('pbkdf2', '-', b'password', b'salt', '0', '32', limit=60)
    except EOFError:
        r = None
    err = open(os.path.join(d, 'drv.err'), 'rb').read()
    s.p.wait(30)
    check('P iter 0 halts loudly (no answer, nonzero exit, "pbkdf2: iter must be at least 1")',
          r is None and s.p.returncode not in (0, None) and b'pbkdf2: iter must be at least 1' in err,
          (r, s.p.returncode, err[-200:]))
    return 'halted'

SHARDS = {'P': shard_p}

if __name__ == '__main__':
    which, d = sys.argv[1], sys.argv[2]
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
        f.write(''.join('%s %.2f\n' % (w, t) for w, t, good in s.times if good))
PYEOF

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
            w, t = l.split(); ts.setdefault(w, []).append(float(t))
    except OSError: pass
print('TIME  driver compile %ss; shards (one at a time): %s' % (cs, secs))
print('TIME  per operation, median wall time of the calls that returned ok: ' +
      ', '.join('%s %.2fs (%d)' % (w, sorted(v)[len(v) // 2], len(v)) for w, v in sorted(ts.items())))
PYEOF
[ "$ok" = 1 ] || exit 1
