#!/usr/bin/env bash
# gate_logossec.sh — the Γ-Security model (logossec.la): HMAC-chained
# capability tokens, the within rule, static confinement, and the reference
# monitor, against known answers.
#
# WHAT IT GUARDS. A capability system fails OPEN quietly: a token that should
# be refused is accepted and nothing looks wrong. So every refusal the contract
# (OS_LAYERS_DESIGN.md, "logossec.la") names is driven here and must come back
# as a refusal with its reason, and every acceptance must carry the right id.
# The oracle is independent of the module: Python's hmac/hashlib mints every
# expected token (sig0 = HMAC(K, id), sig_i = HMAC(sig_{i-1}, caveat_i)), and
# the expected verdicts are written from the contract by hand.
#
#   1. pure (stub crypt record, no HMAC): within — obj vs obj2, a
#      trailing-slash prefix, . / .. / empty segments, a control byte — on the
#      VM, and four of those cases on the host; confine on the VM — granted names only (ok), naming
#      read_file and fork (err naming them), own glyphs (ok), a lambda
#      parameter shadowing a builtin (ok), the same name free outside that
#      lambda (err), a glyph shadowing a builtin (ok), integer literals
#      counting as str_to_int, an import, parse errors, logosipc.la (err
#      listing what it names) and, the SELF-APPLICATION of confine,
#      logossec.la itself against an empty grant list (ok).
#   2. tokens (VM, CRYPT_REF): mint and attenuate give Python's tokens byte for
#      byte; malformed ids, caveats and root keys are errors; verify accepts
#      within every caveat kind (res, ops, until at its boundary) and their
#      intersection, and refuses outside each one; attenuation never widens
#      (requests tried on a token and on its attenuations: whatever an
#      attenuation allows, the original allows); a forged signature, a wrong
#      root key, a truncated token, a dropped caveat, reordered caveats, a
#      caveat appended by editing the string, a revoked id, an unknown caveat,
#      a malformed until, malformed tokens and malformed requests are all
#      refused, each with its reason.
#   3. the guard (VM, CRYPT_REF, real files, processes and a socket): read,
#      write (atomic: no .tmp left), spawn (fork + execv of /usr/bin/touch)
#      and connect (logosipc CONNECT to a Python AF_UNIX server, which must
#      receive exactly one typed message) happen only with a covering token,
#      and the files and the server show nothing happened otherwise; revoke
#      needs a token for sec/policy with op a, a revoked token is then refused,
#      and — the SELF-APPLICATION of the guard — the policy protects itself:
#      an administrator that revokes its own id can revoke nothing more.
#
# COST. Every acceptance and every signature failure costs (caveats + 1)
# HMACs, and with CRYPT_REF on the VM one HMAC takes about a minute of CPU
# (CRYPT_REF names its builtins, and each name walks the ~155 KB program).
# Refusals by a caveat cost none, because verify checks the token's caveats
# before its signature. So the cases are split into four shards of 8-11 HMACs
# that run in parallel from ONE compiled driver: about 12 minutes on an idle
# 4-core machine, far longer on a busy one, since the gate needs some 40
# CPU-minutes in all (SEC_SHARD_TIMEOUT, default 7200 s, bounds each shard).
# The host checks four within cases, alongside the shards: its substitution
# inlines every helper into each function, so building the kit takes about
# two minutes there, each within about one, an HMAC about 160 s, and confine
# far longer.
# ISOLATION: private temp dir (gate_wm_common.sh); the socket is
# /tmp/logosipc-secgate<pid>, removed on exit.
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1
CHAN="secgate$$"
trap 'rm -rf "$T"; rm -f "/tmp/logosipc-$CHAN"' EXIT
: "${SEC_SHARD_TIMEOUT:=7200}"
pass() { echo "PASS  $*"; }
fail() { echo "FAIL  $*"; ok=0; }
wm_setup logossec.la logosipc.la crypt_ref.la sha256.la hmac.la hkdf.la aead.la chacha20.la poly1305.la

# check EXPECT OUT TAG: EXPECT holds "label<TAB>expected" lines; OUT must hold
# exactly those expected lines, in order, and then the line "end".
check() {
    python3 - "$1" "$2" "$3" <<'PYEOF' || ok=0
import sys
exp = open(sys.argv[1], "rb").read().split(b"\n")[:-1]
try:
    raw = open(sys.argv[2], "rb").read()
except OSError:
    raw = b""
out = raw.split(b"\n") if raw else []
bad = 0
for i, e in enumerate(exp):
    label, want = e.split(b"\t", 1)
    got = out[i] if i < len(out) else b"<missing>"
    if got == want:
        print("PASS  %s: %s" % (sys.argv[3], label.decode()))
    else:
        bad = 1
        print("FAIL  %s: %s\n        want %r\n        got  %r" % (sys.argv[3], label.decode(), want, got))
if out[len(exp):len(exp) + 1] != [b"end"]:
    bad = 1; print("FAIL  %s: the program did not finish (no end line)" % sys.argv[3])
sys.exit(bad)
PYEOF
}

# ── 1. pure: within and confine (VM), within (host) ───────────────────────
cat > "$T/pure.la" <<'LAEOF'
import("logossec.la")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph NIL = la n. la c. n(n)
glyph CONS = la h. la t. la n. la c. c(h)(t)
glyph APP = Z(la self. la a. la b. a(la _. b)(la h. la t. CONS(h)(self(t)(b))))
glyph UNL = Z(la self. la l. l(la _. "end")(la h. la t. concat(h)(concat("\n")(self(t)))))
# a stub crypt record: within and confine never touch it
glyph STUB = la s. s(la m. m)(la k. la m. m)(la a. a)(la a. a)(la a. a)(la x. x)
glyph B = la b. b("T")("F")
glyph R = la r. r(la m. concat("err ")(m))(la v. "ok")
glyph G = CONS("concat")(CONS("print")(NIL))
glyph WITHIN_CASES = la within.
   CONS(B(within("obj/1")("obj")))
   (CONS(B(within("obj")("obj")))
   (CONS(B(within("obj2")("obj")))
   (CONS(B(within("obj2/x")("obj")))
   (CONS(B(within("obj/")("obj")))
   (CONS(B(within("obj/1")("obj/")))
   (CONS(B(within("obj/../x")("obj")))
   (CONS(B(within("obj/./x")("obj")))
   (CONS(B(within("obj//x")("obj")))
   (CONS(B(within("obj/..")("obj")))
   (CONS(B(within("")("")))
   (CONS(B(within("obj/1")("")))
   (CONS(B(within(concat("obj/a")(chr("1")))("obj")))
   (CONS(B(within("fs/home/alice/notes")("fs/home/alice")))
   (CONS(B(within("fs/home/alicebob")("fs/home/alice")))
   (NIL)))))))))))))))
glyph CONFINE_CASES = la confine.
   CONS(R(confine("glyph MAIN = print(concat(\"a\")(\"b\"))")(G)))
   (CONS(R(confine("glyph MAIN = print(read_file(\"x\"))\nglyph Y = fork(\"!\")(read_file)")(G)))
   (CONS(R(confine("# c\nglyph MAIN = print(H(\"q\"))\nglyph H = la s. concat(s)(s)")(G)))
   (CONS(R(confine("glyph A = la read_file. read_file(\"x\")\nglyph MAIN = print(A(concat))")(G)))
   (CONS(R(confine("glyph MAIN = (la read_file. read_file)(read_file)")(G)))
   (CONS(R(confine("glyph MAIN = (la f. f(la x. x(fork)))(print)")(G)))
   (CONS(R(confine("glyph read_file = la p. \"safe\"\nglyph MAIN = print(read_file(\"x\"))")(G)))
   (CONS(R(confine("glyph MAIN = print(int_to_str(add(1)(22)))")(G)))
   (CONS(R(confine("import(\"x.la\")\nglyph MAIN = print(\"a\")")(G)))
   (CONS(R(confine("export MAIN\nglyph MAIN = (la x. x)(print)(\"a)b\\\"c\")")(G)))
   (CONS(R(confine("glyph MAIN = print(\"a\"")(G)))
   (CONS(R(confine("glyph MAIN = la 5. x")(G)))
   (CONS(R(confine("glyph MAIN = print(\"unterminated)")(G)))
   (CONS(R(confine(read_file("logosipc.la"))(NIL)))
   (CONS(R(confine(read_file("logossec.la"))(NIL)))
   (NIL)))))))))))))))
# four of the within cases, for the host (about a minute each there)
glyph HOST_CASES = la within.
   CONS(B(within("obj/1")("obj")))(CONS(B(within("obj2")("obj")))
   (CONS(B(within("obj/../x")("obj")))(CONS(B(within("obj/1")("obj/")))(NIL))))
# pure_part.txt holds exactly "host" (no newline) or "all"
glyph MAIN = SEC_KIT(str_at)(ord)(str_len)(str_to_int)(int_to_str)(chr)(concat)(str_eq)(add)(sub)(mul)(div)(lt)(int_eq)(band)(bor)(bxor)(STUB)
 (la mint. la attenuate. la verify. la within. la confine.
  print(UNL(str_eq(read_file("pure_part.txt"))("host")
    (la _. HOST_CASES(within))
    (la _. APP(WITHIN_CASES(within))(CONFINE_CASES(confine)))("!"))))
LAEOF
python3 - "$T" <<'PYEOF'
import sys
W = [("within: obj/1 is within obj", "T"), ("within: obj is within itself", "T"),
     ("within: obj2 is not within obj", "F"), ("within: obj2/x is not within obj", "F"),
     ("within: a request with a trailing slash is refused", "F"),
     ("within: a prefix with a trailing slash contains nothing", "F"),
     ("within: a .. segment is refused", "F"), ("within: a . segment is refused", "F"),
     ("within: an empty segment is refused", "F"), ("within: a final .. is refused", "F"),
     ("within: the empty resource is refused", "F"), ("within: the empty prefix contains nothing", "F"),
     ("within: a control byte is refused", "F"),
     ("within: fs/home/alice/notes is within fs/home/alice", "T"),
     ("within: fs/home/alicebob is not within fs/home/alice", "F")]
C = [("confine: a program using only granted names", "ok"),
     ("confine: naming read_file and fork is refused, naming them", "err confine: not granted: read_file fork"),
     ("confine: a program defining and using its own glyphs", "ok"),
     ("confine: a lambda parameter shadowing a builtin name", "ok"),
     ("confine: the same name used outside the lambda that binds it", "err confine: not granted: read_file"),
     ("confine: a builtin reached deep inside nested lambdas", "err confine: not granted: fork"),
     ("confine: a glyph shadowing a builtin name", "ok"),
     ("confine: an integer literal is a use of str_to_int", "err confine: not granted: int_to_str add str_to_int"),
     ("confine: an import is refused", "err confine: import is not allowed (one module, no imports)"),
     ("confine: export lines and a string full of ( ) and escapes", "ok"),
     ("confine: a missing ) is a parse error", "err confine: parse error at byte 22: expected )"),
     ("confine: a number as a parameter is a parse error", "err confine: parse error at byte 15: expected a parameter name"),
     ("confine: an unterminated string is a parse error", "err confine: parse error at byte 19: expected a closing quote"),
     ("confine: logosipc.la names its builtins, all listed", "err confine: not granted: chr concat unlink bind listen socket accept connect send recv str_eq str_head str_tail"),
     ("SELF-APPLICATION: confine(logossec.la)(nil) is ok, it holds no ambient authority", "ok")]
w = lambda name, cs: open(sys.argv[1] + "/" + name, "w").write("".join("%s\t%s\n" % c for c in cs))
w("pure_expect.txt", W + C)
w("pure_expect_host.txt", [W[0], W[2], W[6], W[5]])
PYEOF
printf all > "$T/pure_part.txt"
s=$(date +%s); wm_vm pure.la "$T/pure_vm.txt"; PURE_VM_S=$(( $(date +%s) - s ))
if [ "$vrc" = 0 ]; then check "$T/pure_expect.txt" "$T/pure_vm.txt" "pure (VM)"
else fail "pure (VM): rc=$vrc"; tail -3 "$T/vce" "$T/vre" 2>/dev/null; fi
# the host checks four within cases, in the background while the VM shards
# run (building the kit there takes minutes, and each within about one)
printf host > "$T/pure_part.txt"
( s=$(date +%s); WM_HOST_TIMEOUT=$SEC_SHARD_TIMEOUT wm_host pure.la "$T/pure_host.txt"
  echo "$hrc" > "$T/pure_host.rc"; echo $(( $(date +%s) - s )) > "$T/pure_host.secs" ) &
HOSTJOB=$!

# ── 2 and 3. tokens and the guard: one driver, four shards ────────────────
# The driver reads cases.txt: one operation per line, the command word and
# then its fields in hex, and prints one result line per operation (a newline
# inside a result is printed as \n).
cat > "$T/drv.la" <<'LAEOF'
import("crypt_ref.la")
import("logosipc.la")
import("logossec.la")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph NIL = la n. la c. n(n)
glyph CONS = la h. la t. la n. la c. c(h)(t)
glyph HV = la c. (la n. lt(n)(58)(la _. sub(n)(48))(la _. sub(n)(87))("!"))(str_to_int(ord(c)))
glyph UNHEX = la s. Z(la self. la i. la n.
    lt(i)(n)(la _. concat(chr(int_to_str(add(mul(HV(str_at(s)(i)))(16))(HV(str_at(s)(add(i)(1)))))))
                        (self(add(i)(2))(n)))(la _. "")("!"))(0)(str_to_int(str_len(s)))
glyph ESC = la s. Z(la self. la i. la n.
    lt(i)(n)(la _. (la c. concat(str_eq(c)("\n")("\\n")(c))(self(add(i)(1))(n)))(str_at(s)(i)))(la _. "")("!"))
    (0)(str_to_int(str_len(s)))
glyph SUB = Z(la self. la s. la i. la j. lt(i)(j)(la _. concat(str_at(s)(i))(self(s)(add(i)(1))(j)))(la _. "")("!"))
glyph SPLIT = la s. la c. (la n. Z(la go. la i. la j.
    lt(j)(n)(la _. str_eq(str_at(s)(j))(c)(la _. CONS(SUB(s)(i)(j))(go(add(j)(1))(add(j)(1))))(la _. go(i)(add(j)(1)))("!"))
            (la _. CONS(SUB(s)(i)(n))(NIL))("!"))(0)(0))(str_to_int(str_len(s)))
glyph MAPL = Z(la self. la f. la l. l(la _. NIL)(la h. la t. CONS(f(h))(self(f)(t))))
glyph NTH = Z(la self. la l. la i. l(la _. "")(la h. la t. int_eq(i)(0)(la _. h)(la _. self(t)(sub(i)(1)))("!")))
glyph DROPL = Z(la self. la l. la i. int_eq(i)(0)(la _. l)(la _. l(la _. NIL)(la h. la t. self(t)(sub(i)(1))))("!"))
glyph JOINC = Z(la self. la l. l(la _. "")(la h. la t. t(la _. h)(la h2. la t2. concat(h)(concat(",")(self(t))))))
glyph RES = la r. r(la m. concat("err ")(m))(la v. concat("ok ")(v))
glyph PAIR = la a. la b. la k. k(a)(b)
glyph GUARD = la sec. la K. GUARD_KIT(str_at)(ord)(str_len)(str_to_int)(int_to_str)(chr)(concat)(str_eq)
    (add)(sub)(mul)(div)(lt)(int_eq)(band)(bor)(bxor)
    (stat)(read_file)(write_file)(rename)(unlink)(fork)(execv)(exit)(clock_gettime)(CONNECT)(sec)(K)
# one operation: la k. k(output line)(the guard after it)
glyph OP = la sec. la hex. la cmd. la a. la g.
  sec(la mint. la attenuate. la verify. la within. la confine.
  g(la gread. la gwrite. la gspawn. la gconnect. la grevoke. la grevoked.
  str_eq(cmd)("mint")(la _. PAIR(RES(mint(NTH(a)(0))(NTH(a)(1))(DROPL(a)(2))))(g))(la _.
  str_eq(cmd)("att")(la _. PAIR(RES(attenuate(NTH(a)(0))(NTH(a)(1))))(g))(la _.
  str_eq(cmd)("verify")(la _. PAIR(RES(verify(NTH(a)(0))(DROPL(a)(5))(NTH(a)(2))(NTH(a)(3))(NTH(a)(4))
                                      (str_to_int(NTH(a)(1)))))(g))(la _.
  str_eq(cmd)("within")(la _. PAIR(within(NTH(a)(0))(NTH(a)(1))("T")("F"))(g))(la _.
  str_eq(cmd)("confine")(la _. PAIR(confine(read_file(NTH(a)(0)))(DROPL(a)(1))(la m. concat("err ")(m))(la v. "ok"))(g))(la _.
  str_eq(cmd)("guard")(la _. PAIR("guard")(GUARD(sec)(NTH(a)(0))))(la _.
  str_eq(cmd)("read")(la _. PAIR(gread(NTH(a)(0))(NTH(a)(1))(la m. concat("err ")(m))(la v. concat("ok ")(hex(v))))(g))(la _.
  str_eq(cmd)("write")(la _. PAIR(RES(gwrite(NTH(a)(0))(NTH(a)(1))(NTH(a)(2))))(g))(la _.
  str_eq(cmd)("spawn")(la _. PAIR(gspawn(NTH(a)(0))(NTH(a)(1))(NTH(a)(2))
                                  (la m. concat("err ")(m))(la pid. concat("ok status ")(waitpid(pid))))(g))(la _.
  str_eq(cmd)("connect")(la _. PAIR(gconnect(NTH(a)(0))(NTH(a)(1))
                                  (la m. concat("err ")(m))(la fd. (la _. "ok sent")(SEND(fd)("ping")(NTH(a)(2)))))(g))(la _.
  str_eq(cmd)("revoke")(la _. grevoke(NTH(a)(0))(NTH(a)(1))(la m. PAIR(concat("err ")(m))(g))(la g2. PAIR("ok")(g2)))(la _.
  str_eq(cmd)("revoked")(la _. PAIR(concat("revoked ")(JOINC(grevoked)))(g))(la _.
  PAIR(concat("unknown command ")(cmd))(g))("!"))("!"))("!"))("!"))("!"))("!"))("!"))("!"))("!"))("!"))("!"))("!")))
glyph NOGUARD = la s. s("")("")("")("")("")(NIL)
glyph RUN = la sec. la hex. Z(la loop. la lines. la g.
  lines(la _. print("end"))(la line. la rest.
    str_eq(line)("")(la _. loop(rest)(g))(la _.
      SPLIT(line)(" ")(la _. loop(rest)(g))(la cmd. la args.
        OP(sec)(hex)(cmd)(MAPL(UNHEX)(args))(g)(la out. la g2. (la _. loop(rest)(g2))(print(ESC(out))))))("!")))
glyph MAIN = (la crypt. crypt(la sha256. la hmac. la hkdf. la seal. la open. la hex.
    RUN(SEC_KIT(str_at)(ord)(str_len)(str_to_int)(int_to_str)(chr)(concat)(str_eq)(add)(sub)(mul)(div)(lt)(int_eq)
               (band)(bor)(bxor)(crypt))(hex)(SPLIT(read_file("cases.txt"))("\n"))(NOGUARD)))(CRYPT_REF)
LAEOF

# The oracle: the cases, the tokens Python mints, the expected lines, and the
# guard's fixtures. Each shard's expect.txt holds "label<TAB>expected line".
G="$T/g"
mkdir -p "$G/data" "$G/other"
printf 'secret data\nline 2\001\377' > "$G/data/in.txt"
printf 'top secret\n' > "$G/other/secret.txt"
python3 - "$T" "$G" "$CHAN" <<'PYEOF'
import hmac, hashlib, os, sys
T, G, CHAN = sys.argv[1:4]
K = hashlib.sha256(b"logossec gate root").digest()
K2 = hashlib.sha256(b"some other root").digest()
def tok(key, i, cavs):
    s = hmac.new(key, i.encode(), hashlib.sha256).digest()
    for c in cavs:
        s = hmac.new(s, c.encode(), hashlib.sha256).digest()
    return "|".join([i] + cavs + [s.hex()])
def sig(t): return t.rsplit("|", 1)[1]
def enc(x): return (x.encode("latin-1") if isinstance(x, str) else x).hex()
shards = {}
def case(shard, label, cmd, fields, expect):
    shards.setdefault(shard, []).append((label, cmd + "".join(" " + enc(f) for f in fields), expect))
def mint(sh, label, key, i, cavs, expect): case(sh, label, "mint", [key, i] + cavs, expect)
def att(sh, label, t, c, expect): case(sh, label, "att", [t, c], expect)
def verify(sh, label, t, res, op, expect, now=1000, key=K, revoked=()):
    case(sh, label, "verify", [key, str(now), t, res, op] + list(revoked), expect)
ID64 = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXY_.-"
assert len(ID64) == 64
T0   = tok(K, "root", [])
TM   = tok(K, ID64, ["res=fs/home/alice", "ops=rw"])
Tr   = tok(K, "tr", ["res=fs/home/alice"])
Tro  = tok(K, "tr", ["res=fs/home/alice", "ops=r"])
Tw   = tok(K, "tr", ["res=fs/home/alice", "res=fs"])
Tu   = tok(K, "tu", ["until=1000"])
Tunk = tok(K, "tk", ["color=blue"])
Tmal = tok(K, "tm", ["until=12x"])
IN, OUT = "fs/home/alice/notes", "fs/etc/passwd"

# shard 1: mint and attenuate give Python's tokens; their errors; each caveat
mint(1, "mint: a 64-char id over every id character, two caveats = Python's token", K, ID64, ["res=fs/home/alice", "ops=rw"], "ok " + TM)
att(1, "attenuate(res token)(ops=r) = Python's token", Tr, "ops=r", "ok " + Tro)
att(1, "attenuate(res token)(res=fs), an attempt to widen = Python's token", Tr, "res=fs", "ok " + Tw)
mint(1, "mint refuses an id with |", K, "bad|id", [], "err mint: bad id: bad|id")
mint(1, "mint refuses an empty id", K, "", [], "err mint: bad id: ")
mint(1, "mint refuses a 65-char id", K, ID64 + "x", [], "err mint: bad id: " + ID64 + "x")
mint(1, "mint refuses an id with a space", K, "a b", [], "err mint: bad id: a b")
mint(1, "mint refuses a caveat without =", K, "ok", ["nokey"], "err mint: bad caveat: nokey")
mint(1, "mint refuses a caveat with an empty key", K, "ok", ["=v"], "err mint: bad caveat: =v")
mint(1, "mint refuses a caveat with |", K, "ok", ["res=a", "a=b|c"], "err mint: bad caveat: a=b|c")
mint(1, "mint refuses a caveat with a newline", K, "ok", ["a=b\nc"], "err mint: bad caveat: a=b\\nc")
mint(1, "mint refuses a 15-byte root key", K[:15], "ok", [], "err mint: bad root key")
att(1, "attenuate refuses a malformed caveat", Tr, "nokey", "err attenuate: bad caveat: nokey")
att(1, "attenuate refuses a malformed token", "garbage", "res=x", "err malformed token: no signature")
verify(1, "res: a request within the prefix is granted (any op)", Tr, IN, "r", "ok tr")
verify(1, "res: the same token grants w there too", Tr, IN, "w", "ok tr")
verify(1, "res: a request outside the prefix is refused", Tr, OUT, "r", "err caveat not met: res=fs/home/alice")
verify(1, "res: alicebob is not within alice (obj vs obj2)", Tr, "fs/home/alicebob", "r", "err caveat not met: res=fs/home/alice")
verify(1, "until: now equal to the limit is granted", Tu, "obj/1", "r", "ok tu", now=1000)
verify(1, "until: one second later is refused (expired)", Tu, "obj/1", "r", "err caveat not met: until=1000", now=1001)
verify(1, "an unknown caveat fails closed", Tunk, "obj/1", "r", "err unknown caveat: color=blue")
verify(1, "a malformed until fails closed", Tmal, "obj/1", "r", "err malformed caveat: until=12x")
verify(1, "attenuated ops=r: w, which the original granted, is refused", Tro, IN, "w", "err caveat not met: ops=r")
verify(1, "attenuated ops=r: outside the prefix is still refused", Tro, OUT, "r", "err caveat not met: res=fs/home/alice")
verify(1, "attenuated res=fs: outside the original prefix is still refused (no widening)", Tw, OUT, "r", "err caveat not met: res=fs/home/alice")

# shard 2: tampering, revocation, malformed tokens and requests
flip = T0[:-1] + ("0" if T0[-1] != "0" else "1")
verify(2, "a token with no caveats grants everything", T0, "obj/1", "r", "ok root")
verify(2, "a wrong root key: bad signature", T0, "obj/1", "r", "err bad signature", key=K2)
verify(2, "a forged signature (one hex digit changed): bad signature", flip, "obj/1", "r", "err bad signature")
verify(2, "a truncated token (last hex digit cut): malformed", T0[:-1], "obj/1", "r", "err malformed token: bad signature encoding")
verify(2, "a dropped caveat (the signature kept): bad signature", "tr|" + sig(Tr), IN, "r", "err bad signature")
verify(2, "reordered caveats: bad signature", "tr|ops=r|res=fs/home/alice|" + sig(Tro), IN, "r", "err bad signature")
verify(2, "a caveat appended by editing the string, not re-signed: bad signature", "root|res=obj|" + sig(T0), "obj/1", "r", "err bad signature")
verify(2, "a revoked id is refused", T0, "obj/1", "r", "err revoked: root", revoked=["x", "root"])
verify(3, "intersection: within res AND ops=r is granted", Tro, IN, "r", "ok tr")
verify(2, "an empty token: malformed", "", "obj/1", "r", "err malformed token: no signature")
verify(2, "no | at all: malformed", "nobar", "obj/1", "r", "err malformed token: no signature")
verify(2, "an empty id: malformed", "|" + sig(T0), "obj/1", "r", "err malformed token: bad id")
verify(2, "an id with a bad character: malformed", "bad id!|" + sig(T0), "obj/1", "r", "err malformed token: bad id")
verify(2, "an empty caveat field: malformed", "root||" + sig(T0), "obj/1", "r", "err malformed token: bad caveat: ")
verify(2, "an upper-case hex signature: malformed", "root|" + sig(T0).upper(), "obj/1", "r", "err malformed token: bad signature encoding")
verify(2, "a request with a .. segment is refused outright", T0, "obj/../x", "r", "err bad resource: obj/../x")
verify(2, "an empty request resource is refused", T0, "", "r", "err bad resource: ")
verify(2, "a leading slash is refused", T0, "/obj", "r", "err bad resource: /obj")
verify(2, "a trailing slash is refused", T0, "obj/", "r", "err bad resource: obj/")
verify(2, "a control byte in the resource is refused", T0, "obj/a\x01b", "r", "err bad resource: obj/a\x01b")
verify(2, "an unknown op is refused", T0, "obj/1", "z", "err bad op: z")
verify(2, "two ops at once are refused", T0, "obj/1", "rw", "err bad op: rw")
verify(2, "a 15-byte root key is refused", T0, "obj/1", "r", "err bad root key", key=K[:15])

# shards 3 and 4: the guard over real files, processes and a socket
DATA = "fs" + G + "/data"
Td   = tok(K, "g1", ["res=" + DATA])
Tro_ = tok(K, "ro", ["ops=r"])
Tadm = tok(K, "adm", ["res=sec/policy"])
Tpr  = tok(K, "pr", ["res=sec/policy", "ops=r"])
inb = open(G + "/data/in.txt", "rb").read()
def g(sh, label, cmd, fields, expect): case(sh, label, cmd, fields, expect)
g(3, "guard built", "guard", [K], "guard")
g(3, "read with a covering token returns the file's bytes", "read", [Td, G + "/data/in.txt"], "ok " + inb.hex())
g(3, "read outside the token's subtree is refused", "read", [Td, G + "/other/secret.txt"], "err read denied: caveat not met: res=" + DATA)
g(3, "read through .. is refused before the disk is touched", "read", [Td, G + "/data/../other/secret.txt"], "err read denied: bad resource: fs" + G + "/data/../other/secret.txt")
g(3, "read of a relative path is refused", "read", [Td, "relative/x"], "err not an absolute path: relative/x")
g(3, "read of a missing file is an error, not empty bytes", "read", [T0, G + "/data/missing.txt"], "err read: not a regular file: " + G + "/data/missing.txt")
g(3, "write with a covering token", "write", [Td, G + "/data/out.txt", "hello\nworld\x00!"], "ok " + G + "/data/out.txt")
g(3, "write outside the subtree is refused", "write", [Td, G + "/other/x.txt", "no"], "err write denied: caveat not met: res=" + DATA)
g(3, "write with a read-only token is refused", "write", [Tro_, G + "/data/ro.txt", "no"], "err write denied: caveat not met: ops=r")
g(3, "spawn with a covering token runs the program", "spawn", [T0, "/usr/bin/touch", "touch " + G + "/data/spawned"], "ok status 0")
g(3, "spawn with a read-only token is refused", "spawn", [Tro_, "/usr/bin/touch", "touch " + G + "/data/nope"], "err spawn denied: caveat not met: ops=r")
g(3, "spawn of a non-executable file is an error", "spawn", [T0, G + "/data/in.txt", "x"], "err spawn: not an executable file: " + G + "/data/in.txt")
g(3, "connect without an ipc grant is refused", "connect", [Td, CHAN, "nothing"], "err connect denied: caveat not met: res=" + DATA)
g(3, "connect to a name with / is refused", "connect", [T0, "a/b", "nothing"], "err connect: bad channel name: a/b")
g(3, "connect with a covering token reaches the server", "connect", [T0, CHAN, "hello"], "ok sent")
g(4, "guard built", "guard", [K], "guard")
g(4, "revoke with a token for a file subtree is refused", "revoke", [Td, "g1"], "err revoke denied: caveat not met: res=" + DATA)
g(4, "revoke with sec/policy but only op r is refused", "revoke", [Tpr, "g1"], "err revoke denied: caveat not met: ops=r")
g(4, "revoke of a malformed id is refused", "revoke", [Tadm, "bad|id"], "err revoke: bad id: bad|id")
g(4, "revoke with an admin token for sec/policy", "revoke", [Tadm, "g1"], "ok")
g(4, "the revocation list holds g1", "revoked", [], "revoked g1")
g(4, "the revoked token is refused by the new guard", "read", [Td, G + "/data/in.txt"], "err read denied: revoked: g1")
g(4, "the administrator revokes its own id", "revoke", [Tadm, "adm"], "ok")
g(4, "self-application: the policy now refuses its own administrator", "revoke", [Tadm, "ro"], "err revoke denied: revoked: adm")
g(4, "the revocation list holds adm and g1", "revoked", [], "revoked adm,g1")
for sh, cs in shards.items():
    d = os.path.join(T, "s%d" % sh)
    os.makedirs(d)
    with open(os.path.join(d, "cases.txt"), "w") as f:
        f.write("".join(c[1] + "\n" for c in cs))
    with open(os.path.join(d, "expect.txt"), "wb") as f:
        f.write(b"".join(c[0].encode() + b"\t" + c[2].encode("latin-1") + b"\n" for c in cs))
PYEOF
[ -f "$T/s4/cases.txt" ] || { echo "FAIL  logossec: the oracle did not write its cases"; exit 1; }

# compile the driver once
cp "$T/drv.la" "$T/logos_source.la"; cp "$T/compiler.bin" "$T/logos_program.bin"
s=$(date +%s)
( cd "$T" && timeout "$WM_VM_TIMEOUT" ./logos_secd >/dev/null 2>"$T/dce" ) || { fail "driver: did not compile"; tail -3 "$T/dce"; exit 1; }
COMPILE_S=$(( $(date +%s) - s ))

# the connect shard's server: one connection, everything it receives, to a file
python3 - "/tmp/logosipc-$CHAN" "$T/server.txt" <<'PYEOF' &
import socket, sys, os
path, out = sys.argv[1], sys.argv[2]
try: os.unlink(path)
except FileNotFoundError: pass
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.bind(path); s.listen(4)
s.settimeout(float(os.environ.get("SEC_SHARD_TIMEOUT", "7200")))
conns, data = 0, b""
try:
    c, _ = s.accept(); conns = 1
    while True:
        b = c.recv(4096)
        if not b: break
        data += b
    s.settimeout(0.5)
    try:
        s.accept(); conns += 1
    except OSError: pass
except OSError: pass
open(out, "w").write("%d %s\n" % (conns, data.hex()))
PYEOF
SERVER=$!
for i in $(seq 50); do [ -S "/tmp/logosipc-$CHAN" ] && break; sleep 0.1; done

pids=()
for sh in 1 2 3 4; do
    ( cd "$T/s$sh" && cp "$T/logos_secd" . && cp "$T/logos_program.bin" . \
      && s=$(date +%s) && { timeout "$SEC_SHARD_TIMEOUT" ./logos_secd > out.txt 2> err.txt; echo $? > rc; } \
      && echo $(( $(date +%s) - s )) > secs ) &
    pids+=($!)
done
for p in "${pids[@]}"; do wait "$p"; done
wait "$SERVER" 2>/dev/null

wait "$HOSTJOB"
if [ "$(cat "$T/pure_host.rc" 2>/dev/null)" = 0 ]; then check "$T/pure_expect_host.txt" "$T/pure_host.txt" "pure (host)"
else fail "pure (host): rc=$(cat "$T/pure_host.rc" 2>/dev/null)"; tail -3 "$T/hre"; fi
for sh in 1 2 3 4; do
    d="$T/s$sh"
    if [ "$(cat "$d/rc" 2>/dev/null)" != 0 ]; then
        fail "shard $sh: rc=$(cat "$d/rc" 2>/dev/null) (124 = SEC_SHARD_TIMEOUT)"; tail -3 "$d/err.txt"
    fi
    check "$d/expect.txt" "$d/out.txt" "shard $sh"
done

# what the guard did (and did not do) to the world
if [ "$(od -An -c "$G/data/out.txt" 2>/dev/null | tr -s ' ')" = "$(printf 'hello\nworld\000!' | od -An -c | tr -s ' ')" ] \
   && [ ! -e "$G/data/out.txt.tmp" ]; then
    pass "guard: the granted write wrote exactly its bytes (NUL included), atomically (no .tmp left)"
else fail "guard: the granted write's file is wrong or its .tmp was left"; fi
if [ ! -e "$G/other/x.txt" ] && [ ! -e "$G/data/ro.txt" ] && [ ! -e "$G/data/nope" ]; then
    pass "guard: refused writes and the refused spawn left nothing on disk"
else fail "guard: a refused operation changed the disk"; fi
if [ -e "$G/data/spawned" ]; then pass "guard: the granted spawn really ran /usr/bin/touch"
else fail "guard: the granted spawn did not run"; fi
if [ "$(cat "$T/server.txt" 2>/dev/null)" = "1 $(printf 'ping\000hello' | od -An -tx1 | tr -d ' \n')" ]; then
    pass "guard: the server saw exactly one connection carrying ping/hello (the refused connects never connected)"
else fail "guard: the server saw: $(cat "$T/server.txt" 2>/dev/null)"; fi

echo "TIME  pure: VM ${PURE_VM_S}s (compile + run, within and confine, incl. confining logossec.la); host $(cat "$T/pure_host.secs" 2>/dev/null)s (kit + four within)"
echo "TIME  driver compile ${COMPILE_S}s; shards (run, parallel): 1 $(cat "$T/s1/secs" 2>/dev/null)s, 2 $(cat "$T/s2/secs" 2>/dev/null)s, 3 $(cat "$T/s3/secs" 2>/dev/null)s, 4 $(cat "$T/s4/secs" 2>/dev/null)s"
[ "$ok" = 1 ] || exit 1
