#!/usr/bin/env bash
# gate_x25519.sh — X25519_KIT (x25519.la) is RFC 7748 X25519, on the native VM.
#
# WHAT IT GUARDS (NET_DESIGN.md section 1):
#   0. the generated section of x25519.la is exactly what x25519_gen.la (the
#      LA generator committed beside it) prints: the module cannot drift from
#      its generator;
#   1. known answers: RFC 7748 5.2's two test vectors, 5.2's iteration test
#      after 1 iteration (k = u = 9) and after 1000, and 6.1's Alice and Bob:
#      both public keys and the shared secret, computed from each side;
#   2. shared refuses the all-zero result: u = 0 and u = 1 (RFC 7748 6.1),
#      and the other small-order encodings (the two points of order 8, p-1,
#      p, p+1, and u = 0 with the top bit set) -- each gives none, and
#      scalarmult gives 32 zero bytes there;
#   3. independent oracles: (a) RFC 7748 section 5 transcribed in Python
#      below (big integers, checked against the RFC's vectors first) on
#      random (k, u) and on edge inputs (non-canonical u >= p, the top bit
#      set, k all zero and all ones); (b) the Python `cryptography` package's
#      X25519 on 16 random key pairs: both public keys and the shared secret
#      from both sides (when the package is absent a NOTE says so and the
#      pairs are checked against (a) only);
#   4. the 64-bit bounds of x25519.la's header: recomputed here, and the
#      field kernels run on operands at the limits of every class the ladder
#      uses (carried, sum, difference + 2p, the select, the E/T kernel) and on
#      random operands inside them; each result is checked mod p against
#      Python and its limbs against the carried bound;
#   5. a key or point that is not 32 bytes halts loudly (rc 1, the message,
#      nothing on stdout), through scalarmult, public and shared;
#   6. the C host gives the same bytes (RFC 7748 5.2 vector 1);
#   7. timing: CPU and wall time per scalarmult, public and shared on the VM,
#      measured inside the program (clock_gettime 2 and 1), best of 3.
# ISOLATION: private temp dir (gate_wm_common.sh). The VM programs are
# compiled once each and run per test; the 1000-iteration test and the host
# run take a few minutes each on a loaded machine. Each VM run stays below
# about 0.8 GB (a VM touches its second 768 MiB semispace after about 34
# scalarmults), so the 1000 iterations and the key pairs run in chunks.
# X25519_HOST_TIMEOUT (default 2400 s) bounds the host run: it needs about
# two CPU minutes, which can be 10 minutes of wall time on a busy machine.
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1
wm_setup x25519.la x25519_gen.la
command -v python3 >/dev/null || { echo "FAIL  x25519: python3 (the oracle) is not installed"; exit 1; }

# A VM process killed by SIGKILL (rc 137) was killed from outside -- on a busy
# shared machine, by the memory cgroup's OOM killer (a compile, or a long run,
# reaches about 1.4 GB) -- which says nothing about the code: it is retried
# twice, after a pause, with a NOTE. Every other result counts at once.
vm_once() {  # vm_once OUT ERR: run logos_program.bin in $T; sets vrc
    local tries=0
    while :; do
        vrc=0; ( cd "$T" && timeout "$WM_VM_TIMEOUT" ./logos_secd >"$1" 2>"$2" ) || vrc=$?
        [ "$vrc" = 137 ] && [ "$tries" -lt 2 ] || return 0
        tries=$((tries + 1)); echo "NOTE  x25519: a VM process was killed by SIGKILL (out of memory on a busy machine?); retrying"
        sleep 30
    done
}
# vm_compile PROG.la BIN: compile on the VM into $T/BIN; a failure ends the gate
vm_compile() {
    cp "$T/$1" "$T/logos_source.la"; cp "$T/compiler.bin" "$T/logos_program.bin"
    vm_once /dev/null "$T/vce"
    [ "$vrc" = 0 ] || { echo "FAIL  x25519: $1 did not compile (rc $vrc)"; tail -3 "$T/vce"; exit 1; }
    cp "$T/logos_program.bin" "$T/$2"
}
# vm_run BIN MODE OUT: run the compiled BIN with mode.txt = MODE; sets vrc, stderr in $T/vre
vm_run() {
    printf '%s' "$2" > "$T/mode.txt"; cp "$T/$1" "$T/logos_program.bin"
    vm_once "$3" "$T/vre"
}

# ── the oracle ─────────────────────────────────────────────────────────
cat > "$T/oracle.py" <<'PYEOF'
import os, sys
P = 2**255 - 19
A24 = 121665
def clamp(k):
    k = bytearray(k); k[0] &= 248; k[31] &= 127; k[31] |= 64; return bytes(k)
def x25519(k, u):
    # RFC 7748 section 5, transcribed: decodeScalar25519, decodeUCoordinate
    # (top bit masked, non-canonical values reduced), the ladder with cswap
    k = int.from_bytes(clamp(k), "little")
    x1 = (int.from_bytes(u, "little") & ((1 << 255) - 1)) % P
    x2, z2, x3, z3, swap = 1, 0, x1, 1, 0
    for t in range(254, -1, -1):
        kt = (k >> t) & 1
        swap ^= kt
        if swap: x2, x3, z2, z3 = x3, x2, z3, z2
        swap = kt
        A = x2 + z2; AA = A * A; B = x2 - z2; BB = B * B; E = AA - BB
        C = x3 + z3; D = x3 - z3; DA = D * A; CB = C * B
        x3 = (DA + CB) ** 2 % P; z3 = x1 * (DA - CB) ** 2 % P
        x2 = AA * BB % P; z2 = E * (AA + A24 * E) % P
    if swap: x2, x3, z2, z3 = x3, x2, z3, z2
    return (x2 * pow(z2, P - 2, P) % P).to_bytes(32, "little")
H = bytes.fromhex
NINE = bytes([9]) + bytes(31)
# the transcription against the RFC's own vectors before it is trusted
assert x25519(H("a546e36bf0527c9d3b16154b82465edd62144c0ac1fc5a18506a2244ba449ac4"),
              H("e6db6867583030db3594c1a424b15f7c726624ec26b3353b10a903a6d0ab1c4c")).hex() \
    == "c3da55379de9c6908e94ea4df28d084f32eccf03491c71f754b4075577a28552"
assert x25519(H("4b66e9d4d1b4673c5ad22691957d6af5c11b6421e0ea01d42ca4169e7918ba0d"),
              H("e5210f12786811d3f4b7959d0538ae2c31dbe7106fc03c3efc4cd549c715a493")).hex() \
    == "95cbde9476e8907d7aade45cb4b873f88b595a68799fa152e6f8f7647aac7957"
assert x25519(NINE, NINE).hex() == "422c8e7a6227d7bca1350b3e2bb7279f7897b87bb6854b783c60e80311ae3079"
assert x25519(H("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a"), NINE).hex() \
    == "8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a"
def hexopt(r): return "none" if r == bytes(32) else r.hex()
mode = sys.argv[1]
if mode == "bulk":            # random and edge (k, u); writes cases.bin, prints the expected lines
    cases = [(os.urandom(32), os.urandom(32)) for _ in range(16)]
    pm = lambda v: v.to_bytes(32, "little")
    cases += [(bytes(32), NINE), (b"\xff" * 32, NINE), (os.urandom(32), b"\xff" * 32),
              (os.urandom(32), pm(P + 2)), (os.urandom(32), pm(P + 9)), (os.urandom(32), pm(2**255 - 1)),
              (os.urandom(32), pm(9 + 2**255)), (os.urandom(32), pm(2)), (os.urandom(32), pm(P - 2))]
    open("cases.bin", "wb").write(b"".join(k + u for k, u in cases))
    print("\n".join("sm " + x25519(k, u).hex() for k, u in cases) + "\nend")
if mode == "lows":            # the small-order encodings: all-zero results
    pts = ["00" * 32, "01" + "00" * 31,
           "e0eb7a7c3b41b8ae1656e3faf19fc46ada098deb9c32b1fd866205165f49b800",
           "5f9c95bca3508c24b1d0b1559c83ef5b04445cc4581c8e86d8224eddd09f1157",
           "ec" + "ff" * 30 + "7f", "ed" + "ff" * 30 + "7f", "ee" + "ff" * 30 + "7f", "00" * 31 + "80"]
    cases = [(os.urandom(32), H(p)) for p in pts]
    for k, u in cases: assert x25519(k, u) == bytes(32)
    open("lows.bin", "wb").write(b"".join(k + u for k, u in cases))
    print("\n".join("lo none " + "00" * 32 for _ in cases) + "\nend")
if mode == "pairs":           # 16 random key pairs: the package's X25519 if present, else the transcription
    try:
        from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey, X25519PublicKey
        from cryptography.hazmat.primitives import serialization as S
        def pub(sk): return X25519PrivateKey.from_private_bytes(sk).public_key().public_bytes(S.Encoding.Raw, S.PublicFormat.Raw)
        def sh(sk, pk): return X25519PrivateKey.from_private_bytes(sk).exchange(X25519PublicKey.from_public_bytes(pk))
        print("oracle cryptography", file=sys.stderr)
    except ImportError:
        def pub(sk): return x25519(sk, NINE)
        def sh(sk, pk): return x25519(sk, pk)
        print("oracle transcription", file=sys.stderr)
    prs = [(os.urandom(32), os.urandom(32)) for _ in range(16)]
    open("pairs.bin", "wb").write(b"".join(a + b for a, b in prs))
    out = []
    for a, b in prs:
        pa, pb = pub(a), pub(b)
        assert pa == x25519(a, NINE) and sh(a, pb) == x25519(a, pb)
        out.append("pa %s %s %s %s" % (pa.hex(), pb.hex(), hexopt(sh(a, pb)), hexopt(sh(b, pa))))
    print("\n".join(out) + "\nend")
if mode == "timing":          # the results the timed program must give
    k, u = bytes(range(32)), bytes(range(32, 64))
    print("scalarmult " + x25519(k, u).hex()); print("public " + x25519(k, NINE).hex())
    print("shared " + x25519(u, x25519(k, NINE)).hex())
PYEOF

# the bounds of x25519.la's header, recomputed from the arithmetic (fixpoint of
# the carried bound), and the white-box cases at the limits
cat > "$T/bounds.py" <<'PYEOF'
import math, random, sys
P = 2**255 - 19
W = [26, 25] * 5
OFF = [0, 26, 51, 77, 102, 128, 153, 179, 204, 230]
P2 = [2**27 - 38] + [2**26 - 2 if k % 2 else 2**27 - 2 for k in range(1, 10)]
def cols(f, g):
    h = []
    for k in range(10):
        s = 0
        for i in range(10):
            for j in range(10):
                c = 2 if (i % 2 and j % 2) else 1
                if i + j == k: s += c * f[i] * g[j]
                elif i + j == k + 10: s += 19 * c * f[i] * g[j]
        h.append(s)
    return h
def chain(h):
    t = [h[0]]
    for k in range(1, 10): t.append(h[k] + (t[k - 1] >> W[k - 1]))
    u0 = (2**26 - 1) + 19 * (t[9] >> 25)
    return [2**26 - 1, 2**25 - 1 + (u0 >> 26)] + [2**W[k] - 1 for k in range(2, 10)], max(t + [u0])
c = [2**w - 1 for w in W]
while True:
    s2 = [2 * x for x in c]; d = [c[k] + P2[k] for k in range(10)]
    cls = {"diff*diff": (d, d), "diff*sum": (d, s2), "sum*sum": (s2, s2), "diff*carried": (d, c), "carried*carried": (c, c)}
    worst = [max(cols(*v)[k] for v in cls.values()) for k in range(10)]
    c2, tmax = chain(worst)
    if c2 == c: break
    c = c2
val = lambda l: sum(x << OFF[k] for k, x in enumerate(l))
T = [c[k] + 121665 * d[k] for k in range(10)]
if sys.argv[1] == "check":
    top = max(max(cols(*v)) for v in cls.values())
    assert top < 2**63 and tmax < 2**63 and max(T) < 2**63
    assert all(c[k] <= P2[k] for k in range(10))          # a difference never goes negative
    assert val(c) < 2 * P                                   # one conditional subtraction suffices
    assert c[1] - (2**25 - 1) == 1711 and c[0] == 2**26 - 1 and all(c[k] == 2**W[k] - 1 for k in range(2, 10))
    print("bounds: worst column 2^%.2f, chain 2^%.2f, T 2^%.2f, all < 2^63; limb-1 excess %d; carried value < 2p"
          % (math.log2(top), math.log2(tmax), math.log2(max(T)), c[1] - (2**25 - 1)))
if sys.argv[1] == "cases":
    # each case: (label, LA expression for the carried result, expected value mod p)
    R = random.Random(int(sys.argv[2]))
    z = [0] * 10
    mk = lambda l: "MK" + "".join("(%d)" % x for x in l)
    rnd = lambda b: [R.randint(0, x) for x in b]
    cases = []
    def mul(lbl, f, g): cases.append((lbl, "fmul(%s)(%s)" % (mk(f), mk(g)), val(f) * val(g) % P))
    def sq(lbl, f): cases.append((lbl, "sq(%s)" % mk(f), val(f) ** 2 % P))
    for a, an in ((d, "diff"), (s2, "sum"), (c, "carried")):
        for b, bn in ((d, "diff"), (s2, "sum"), (c, "carried")):
            mul("mul-%s-%s-max" % (an, bn), a, b)
        sq("sq-%s-max" % an, a)
    for i in range(6):
        for a, an in ((d, "diff"), (s2, "sum")):
            mul("mul-%s-rand" % an, rnd(a), rnd(d)); sq("sq-%s-rand" % an, rnd(a))
    # through the lazy kernels the ladder uses: L2's sum and difference, the
    # select in both directions, and E*T with AA, BB at their extremes
    cases.append(("l2-diff*l2-sum", "L2C(%s)(%s)(la A. la B. L2C(%s)(%s)(la A2. la B2. fmul(B)(A2)))" % (mk(c), mk(z), mk(c), mk(c)),
                  val(d) * (2 * val(c)) % P))
    cases.append(("sqsel-0", "%s(%s(sqsel))(bor)(band(sub(0)(1)))(band(0))" % (mk(s2), mk(d)), val(d) ** 2 % P))
    cases.append(("sqsel-1", "%s(%s(sqsel))(bor)(band(0))(band(sub(0)(1)))" % (mk(s2), mk(d)), val(s2) ** 2 % P))
    for AA, BB, nm in ((c, z, "max-0"), (z, c, "0-max"), (c, c, "max-max"), (rnd(c), rnd(c), "rand")):
        E = (val(AA) - val(BB)) % P
        cases.append(("etk-" + nm, "%s(%s(etk))" % (mk(BB), mk(AA)), E * (val(AA) + 121665 * E) % P))
    with open("wbcases.la", "w") as fo:
        body = 'print("end")'
        for lbl, e, _ in reversed(cases):
            body = '(la _. %s)(SHOW("%s")(%s))' % (body, lbl, e)
        fo.write("glyph CASES = la MK. la fmul. la sq. la sqsel. la etk. la L2C. la SHOW. la bor. la band. la sub.\n  " + body + "\n")
    with open("wbexpect.txt", "w") as fo:
        for lbl, _, v in cases: fo.write("%s %d\n" % (lbl, v))
if sys.argv[1] == "verify":
    exp = [l.split() for l in open("wbexpect.txt")]
    got = [l.split() for l in open("wb.out")]
    bad = 0
    if len(got) != len(exp) + 1 or got[-1] != ["end"]: print("wrong output length"); bad = 1
    for (lbl, v), g in zip(exp, got):
        limbs = [int(x) for x in g[1:]]
        if g[0] != lbl or len(limbs) != 10: print("bad line", g[:2]); bad = 1; continue
        if any(limbs[k] < 0 or limbs[k] > c[k] for k in range(10)): print(lbl, "limb outside the carried bound"); bad = 1
        if val(limbs) % P != int(v): print(lbl, "wrong value mod p"); bad = 1
    print("verified %d cases" % len(exp)); sys.exit(bad)
PYEOF

# ── the LA programs ─────────────────────────────────────────────────────
# t.la: one compiled program, dispatching on mode.txt
cat > "$T/t.la" <<'LAEOF'
import("x25519.la")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph SEQ = la a. la b. b
glyph SPAN = la f. la a. la b. (Z(la sp. la lo. la hi.
    lt(add(lo)(1))(hi)
      (la _. (la mid. concat(sp(lo)(mid))(sp(mid)(hi)))(div(add(lo)(hi))(2)))
      (la _. lt(lo)(hi)(la _. f(lo))(la _. "")("!"))
      ("!")))(a)(b)
glyph SUB = la s. la a. la b. SPAN(la i. str_at(s)(i))(a)(b)
glyph LEN = la s. str_to_int(str_len(s))
glyph HEX = la s. SPAN(la i. (la b. concat(str_at("0123456789abcdef")(div(b)(16)))(str_at("0123456789abcdef")(mod(b)(16))))
                           (str_to_int(ord(str_at(s)(i)))))(0)(LEN(s))
glyph FROMHEX = la s. SPAN(la i. (la hv. chr(int_to_str(add(mul(hv(str_at(s)(mul(i)(2))))(16))(hv(str_at(s)(add(mul(i)(2))(1)))))))
                           (la c. (la n. lt(n)(58)(la _. sub(n)(48))(la _. sub(n)(87))("!"))(str_to_int(ord(c)))))(0)(div(LEN(s))(2))
glyph OPT = la o. o(la _. "none")(la s. HEX(s))
glyph ZEROS = la n. SPAN(la i. chr("0"))(0)(n)
glyph NINE = concat(chr("9"))(ZEROS(31))
# FORREC(s)(n)(f): f on each n-byte record of s, in order
glyph FORREC = la s. la n. la f. Z(la go. la o. lt(o)(LEN(s))(la _. SEQ(f(SUB(s)(o)(add(o)(n))))(go(add(o)(n))))(la _. "")("!"))(0)
glyph SP = la x. la y. concat(x)(concat(" ")(y))
glyph P4 = la a. la b. la c. la d. print(SP(SP(SP(a)(b))(c))(d))
glyph TSPLIT = Z(la go. la s. la acc. str_eq(str_head(s))(" ")(la _. la k. k(acc)(str_tail(s)))(la _. go(str_tail(s))(concat(acc)(str_head(s))))("!"))
glyph NOW = la id. TSPLIT(clock_gettime(id))("")(la a. la b. add(mul(str_to_int(a))(1000000))(div(str_to_int(b))(1000)))
glyph MIN = la a. la b. lt(a)(b)(a)(b)
# best of 3: la k. k(cpu us)(wall us)(result)
glyph TIMED = la f. Z(la go. la n. la bc. la bw. la r.
    int_eq(n)(0)(la _. la k. k(bc)(bw)(r))
      (la _. (la c0. la w0. (la x. (la c1. la w1. go(sub(n)(1))(MIN(bc)(sub(c1)(c0)))(MIN(bw)(sub(w1)(w0)))(x))(NOW("2"))(NOW("1")))(f("!")))
             (NOW("2"))(NOW("1")))("!"))(3)(999999999999)(999999999999)("")
glyph REPORT = la name. la f. TIMED(f)(la c. la w. la r. P4(concat("time ")(name))(int_to_str(c))(int_to_str(w))(HEX(r)))
# ITERS(sm)(n)(k)(u): RFC 7748 5.2's iteration, n times (k, u := X25519(k, u), k): k ++ u
glyph ITERS = la sm. Z(la go. la n. la k. la u. int_eq(n)(0)(la _. concat(k)(u))(la _. go(sub(n)(1))(sm(k)(u))(k))("!"))
glyph KAT = la sm. la pub. la sh.
  (la A. la B.
    SEQ(SEQ(SEQ(SEQ(SEQ(SEQ(SEQ(
      print(concat("v1 ")(HEX(sm(FROMHEX("a546e36bf0527c9d3b16154b82465edd62144c0ac1fc5a18506a2244ba449ac4"))
                               (FROMHEX("e6db6867583030db3594c1a424b15f7c726624ec26b3353b10a903a6d0ab1c4c"))))))
      (print(concat("v2 ")(HEX(sm(FROMHEX("4b66e9d4d1b4673c5ad22691957d6af5c11b6421e0ea01d42ca4169e7918ba0d"))
                                (FROMHEX("e5210f12786811d3f4b7959d0538ae2c31dbe7106fc03c3efc4cd549c715a493")))))))
      (print(concat("iter 1 ")(HEX(SUB(ITERS(sm)(1)(NINE)(NINE))(0)(32))))))
      (print(concat("alice-public ")(HEX(pub(A))))))
      (print(concat("bob-public ")(HEX(pub(B))))))
      (print(concat("alice-shared ")(OPT(sh(A)(FROMHEX("de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f")))))))
      (print(concat("bob-shared ")(OPT(sh(B)(FROMHEX("8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a")))))))
      (print("end")))
  (FROMHEX("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a"))
  (FROMHEX("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb"))
glyph K31 = "0123456789abcdef0123456789abcde"
glyph K32 = "0123456789abcdef0123456789abcdef"
glyph K33 = "0123456789abcdef0123456789abcdefg"
glyph NIL = la n. la c. n(n)
glyph C = la h. la t. la n. la c. c(h)(t)
glyph PR = la a. la b. la k. k(a)(b)
# DISPATCH(mode)(table): run the thunk named mode
glyph DISPATCH = Z(la go. la mode. la l. l(la _. print(concat("unknown mode ")(mode)))
    (la h. la t. h(la name. la f. str_eq(name)(mode)(la _. f("!"))(la _. go(mode)(t))("!"))))
glyph MAIN = X25519_KIT(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(error)
    (add)(sub)(mul)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr)
 (la sm. la pub. la sh. DISPATCH(read_file("mode.txt"))(
   C(PR("kat")(la _. KAT(sm)(pub)(sh)))
  (C(PR("bulk")(la _. SEQ(FORREC(read_file("cases.bin"))(64)(la r. print(concat("sm ")(HEX(sm(SUB(r)(0)(32))(SUB(r)(32)(64)))))))
                         (print("end"))))
  (C(PR("lows")(la _. SEQ(FORREC(read_file("lows.bin"))(64)(la r.
        (la k. la u. print(concat(concat("lo ")(OPT(sh(k)(u))))(concat(" ")(HEX(sm(k)(u))))))(SUB(r)(0)(32))(SUB(r)(32)(64))))
                         (print("end"))))
  (C(PR("pairs")(la _. SEQ(FORREC(read_file("pairs.bin"))(64)(la r.
        (la a. la b. (la pa. la pb. P4(concat("pa ")(HEX(pa)))(HEX(pb))(OPT(sh(a)(pb)))(OPT(sh(b)(pa))))(pub(a))(pub(b)))
        (SUB(r)(0)(32))(SUB(r)(32)(64))))(print("end"))))
  # n.txt iterations from the state in iter.bin (k ++ u), printed, then written back
  (C(PR("iter")(la _. (la st. (la r. SEQ(print(concat("iter ")(HEX(SUB(r)(0)(32)))))(write_file("iter.bin")(r)))
        (ITERS(sm)(str_to_int(read_file("n.txt")))(SUB(st)(0)(32))(SUB(st)(32)(64))))(read_file("iter.bin"))))
  (C(PR("time")(la _. (la k. la u. (la pk. SEQ(SEQ(SEQ(
        REPORT("scalarmult")(la _. sm(k)(u)))
        (REPORT("public")(la _. pub(k))))
        (REPORT("shared")(la _. sh(u)(pk)(la _. "none")(la s. s))))
        (print("end")))(pub(k)))
      (SPAN(la i. chr(int_to_str(i)))(0)(32))(SPAN(la i. chr(int_to_str(i)))(32)(64))))
  (C(PR("halt-key31")(la _. SEQ(sm(K31)(K32))(print("NOT REACHED"))))
  (C(PR("halt-key33")(la _. SEQ(sm(K33)(K32))(print("NOT REACHED"))))
  (C(PR("halt-point31")(la _. SEQ(sm(K32)(K31))(print("NOT REACHED"))))
  (C(PR("halt-point33")(la _. SEQ(sm(K32)(K33))(print("NOT REACHED"))))
  (C(PR("halt-empty")(la _. SEQ(sm("")(""))(print("NOT REACHED"))))
  (C(PR("halt-public31")(la _. SEQ(pub(K31))(print("NOT REACHED"))))
  (C(PR("halt-shared33")(la _. SEQ(sh(K32)(K33))(print("NOT REACHED"))))
  (NIL)))))))))))))))
LAEOF
vm_compile t.la t.bin

# ── 0. the generated section is the generator's output ────────────────────
vm_compile x25519_gen.la gen.bin; vm_run gen.bin gen "$T/gen.out"
sed -n '/^# >>> generated by x25519_gen.la/,/^# <<< end of generated section/p' "$T/x25519.la" > "$T/gen.in"
if [ "$vrc" = 0 ] && [ -s "$T/gen.in" ] && cmp -s "$T/gen.out" "$T/gen.in"; then
    echo "PASS  x25519 generator (VM): x25519_gen.la prints exactly the $(wc -l < "$T/gen.in")-line generated section of x25519.la (the 10x10 multiplication, the squaring, the carry and the limb-wise kernels)"
else
    echo "FAIL  x25519 generator (VM): rc=$vrc, the generated section differs from x25519_gen.la's output"; diff "$T/gen.in" "$T/gen.out" | head -6; ok=0
fi

# ── 1. RFC 7748 known answers ──────────────────────────────────────────────
vm_run t.bin kat "$T/kat.out"
EXPECT="v1 c3da55379de9c6908e94ea4df28d084f32eccf03491c71f754b4075577a28552
v2 95cbde9476e8907d7aade45cb4b873f88b595a68799fa152e6f8f7647aac7957
iter 1 422c8e7a6227d7bca1350b3e2bb7279f7897b87bb6854b783c60e80311ae3079
alice-public 8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a
bob-public de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f
alice-shared 4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742
bob-shared 4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742
end"
if [ "$vrc" = 0 ] && [ "$(cat "$T/kat.out")" = "$EXPECT" ]; then
    echo "PASS  x25519 known answers (VM): RFC 7748 5.2 both vectors and the iteration test after 1 iteration; 6.1 Alice's and Bob's public keys and the shared secret from both sides"
else
    echo "FAIL  x25519 known answers (VM): rc=$vrc"; diff <(echo "$EXPECT") "$T/kat.out" | head -10; tail -3 "$T/vre"; ok=0
fi
# A VM process allocates about 22 MB per scalarmult and touches its second
# 768 MiB semispace after about 34, so the 1000 iterations run as 1 + 37 x 27,
# the state passed through iter.bin: every run stays below about 0.8 GB.
python3 -c 'import sys; sys.stdout.buffer.write((bytes([9]) + bytes(31)) * 2)' > "$T/iter.bin"
printf 1 > "$T/n.txt"; vm_run t.bin iter "$T/iter.out"; irc=$vrc; cp "$T/iter.out" "$T/iter.all"
printf 27 > "$T/n.txt"
for i in $(seq 37); do
    [ "$irc" = 0 ] || break
    vm_run t.bin iter "$T/iter.out"; irc=$vrc
done
EXPECT="iter 422c8e7a6227d7bca1350b3e2bb7279f7897b87bb6854b783c60e80311ae3079
iter 684cf59ba83309552800ef566f2f4d3c1c3887c49360e3875f2eb94d99532c51"
if [ "$irc" = 0 ] && [ "$(cat "$T/iter.all" "$T/iter.out")" = "$EXPECT" ]; then
    echo "PASS  x25519 iteration test (VM): RFC 7748 5.2, k = u = 9, after 1 and after 1000 iterations"
else
    echo "FAIL  x25519 iteration test (VM): rc=$irc"; diff <(echo "$EXPECT") <(cat "$T/iter.all" "$T/iter.out") | head -6; tail -3 "$T/vre"; ok=0
fi

# ── 2. shared refuses the all-zero result ────────────────────────────────
( cd "$T" && python3 oracle.py lows ) > "$T/lows.exp"
vm_run t.bin lows "$T/lows.out"
if [ "$vrc" = 0 ] && cmp -s "$T/lows.out" "$T/lows.exp"; then
    echo "PASS  x25519 small-order points (VM): u = 0, u = 1, the two points of order 8, p-1, p, p+1 and 0 with the top bit set: shared gives none, scalarmult 32 zero bytes (all $(grep -c '^lo' "$T/lows.exp"), as the oracle)"
else
    echo "FAIL  x25519 small-order points (VM): rc=$vrc"; diff "$T/lows.exp" "$T/lows.out" | head -6; tail -3 "$T/vre"; ok=0
fi

# ── 3. the oracles ─────────────────────────────────────────────────────────
( cd "$T" && python3 oracle.py bulk ) > "$T/bulk.exp"
vm_run t.bin bulk "$T/bulk.out"
if [ "$vrc" = 0 ] && cmp -s "$T/bulk.out" "$T/bulk.exp"; then
    echo "PASS  x25519 oracle (VM): $(grep -c '^sm' "$T/bulk.exp") scalarmults equal RFC 7748 transcribed in Python: 16 random (k, u), k all zero and all ones, u all ones, u = p+2, p+9, 2^255-1, 9 + 2^255 (top bit set), 2, p-2"
else
    echo "FAIL  x25519 oracle (VM): rc=$vrc"; diff "$T/bulk.exp" "$T/bulk.out" | head -6; tail -3 "$T/vre"; ok=0
fi
( cd "$T" && python3 oracle.py pairs ) > "$T/pairs.exp" 2> "$T/pairs.who"
# four pairs (16 scalarmults) per VM run, for the memory reason above
cp "$T/pairs.bin" "$T/pairs.all"; : > "$T/pairs.out"; prc=0
for i in 0 1 2 3; do
    dd if="$T/pairs.all" of="$T/pairs.bin" bs=256 skip=$i count=1 status=none
    vm_run t.bin pairs "$T/pairs.one"
    if [ "$vrc" != 0 ]; then prc=$vrc; elif [ "$(tail -1 "$T/pairs.one")" != end ]; then prc=1; fi
    grep -v '^end$' "$T/pairs.one" >> "$T/pairs.out"
done
echo end >> "$T/pairs.out"; vrc=$prc
if grep -q cryptography "$T/pairs.who"; then who="the Python cryptography package's X25519"
else who="RFC 7748 transcribed in Python"; echo "NOTE  x25519: the Python cryptography package is absent; the key pairs are checked against the transcription only"; fi
if [ "$vrc" = 0 ] && cmp -s "$T/pairs.out" "$T/pairs.exp"; then
    echo "PASS  x25519 key pairs (VM): 16 random pairs, both public keys and the shared secret from both sides equal $who"
else
    echo "FAIL  x25519 key pairs (VM): rc=$vrc against $who"; diff "$T/pairs.exp" "$T/pairs.out" | head -6; tail -3 "$T/vre"; ok=0
fi

# ── 4. the 64-bit bounds, and the kernels at the limits ─────────────────────
if b=$( cd "$T" && python3 bounds.py check ); then echo "PASS  x25519 $b"
else echo "FAIL  x25519 bounds: the header's limits do not hold"; ok=0; fi
( cd "$T" && python3 bounds.py cases "$RANDOM" )
{ grep -v '^export ' "$T/x25519.la"; cat "$T/wbcases.la"; cat <<'LAEOF'
glyph MAIN = (la add. la sub. la mul. la band. la bor. la bshr. la int_to_str. la concat.
  (la C2. la C4. la C19. la C25. la C26. la C38. la C76. la M25. la M26. la Q2. la O2. la R2. la A24.
    LET(X25519_CARRY(add)(bshr)(band(M26))(band(M25))(mul(C19))(C26)(C25))(la carry.
    LET(X25519_MULC(mul(C2))(mul(C19))(mul(C38))(carry))(la mulc.
    LET(X25519_SQC(mul(C2))(mul(C4))(mul(C19))(mul(C38))(mul(C76))(carry))(la sqc.
    LET(X25519_TOPA(mul))(la topa.
    LET(X25519_L2(add)(sub)(Q2)(O2)(R2))(la l2.
    LET(X25519_SQSEL(sqc)(mul)(add))(la sqsel.
    LET(X25519_ETK(add)(sub)(mul(A24))(mul)(Q2)(O2)(R2)(carry)(la E. la T. T(E(mulc))(add)))(la etk.
      CASES(la a. la b. la c. la d. la e. la f. la g. la h. la i. la j. la k. k(a)(b)(c)(d)(e)(f)(g)(h)(i)(j))
           (la F. la G. G(topa(F)(mulc))(add))(la F. F(sqc)(mul)(add))(sqsel)(etk)
           (la F. la G. G(F(l2)))
           (la name. la R. R(la a. la b. la c. la d. la e. la f. la g. la h. la i. la j.
              (la SP. la I. print(SP(SP(SP(SP(SP(SP(SP(SP(SP(SP(name)(I(a)))(I(b)))(I(c)))(I(d)))(I(e)))(I(f)))(I(g)))(I(h)))(I(i)))(I(j))))(la x. la y. concat(x)(concat(" ")(y)))(int_to_str)))
           (bor)(band)(sub)))))))))
   (2)(4)(19)(25)(26)(38)(76)(33554431)(67108863)(134217690)(67108862)(134217726)(121665))
  (add)(sub)(mul)(band)(bor)(bshr)(int_to_str)(concat)
LAEOF
} > "$T/wb.la"
vm_compile wb.la wb.bin; vm_run wb.bin wb "$T/wb.out"
if [ "$vrc" = 0 ] && v=$( cd "$T" && python3 bounds.py verify ); then
    echo "PASS  x25519 kernels at the limits (VM): $v -- difference, sum and carried operands at their maxima and at random, L2's lazy sum and difference, the select both ways, E*T with AA and BB at 0 and at the maximum -- each right mod p with carried limbs"
else
    echo "FAIL  x25519 kernels at the limits (VM): rc=$vrc ${v:-}"; tail -3 "$T/vre" 2>/dev/null; ok=0
fi

# ── 5. a wrong length halts loudly ─────────────────────────────────────────
MSG="x25519: scalarmult: key and point must be 32 bytes"
for m in halt-key31 halt-key33 halt-point31 halt-point33 halt-empty halt-public31 halt-shared33; do
    vm_run t.bin "$m" "$T/halt.out"
    if [ "$vrc" = 1 ] && grep -qxF "$MSG" "$T/vre" && [ ! -s "$T/halt.out" ]; then :
    else echo "FAIL  x25519 misuse (VM): $m: rc=$vrc stdout=$(head -c 80 "$T/halt.out") stderr=$(head -c 120 "$T/vre")"; ok=0; hbad=1; fi
done
[ -z "${hbad:-}" ] && echo "PASS  x25519 misuse (VM): a 31- or 33-byte key, a 31- or 33-byte point, empty strings, through scalarmult, public and shared: each halts with '$MSG', rc 1, nothing on stdout"

# ── 6. the C host gives the same bytes ─────────────────────────────────────
cat > "$T/host.la" <<'LAEOF'
import("x25519.la")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph SPAN = la f. la a. la b. (Z(la sp. la lo. la hi.
    lt(add(lo)(1))(hi)
      (la _. (la mid. concat(sp(lo)(mid))(sp(mid)(hi)))(div(add(lo)(hi))(2)))
      (la _. lt(lo)(hi)(la _. f(lo))(la _. "")("!"))
      ("!")))(a)(b)
glyph HEX = la s. SPAN(la i. (la b. concat(str_at("0123456789abcdef")(div(b)(16)))(str_at("0123456789abcdef")(mod(b)(16))))
                           (str_to_int(ord(str_at(s)(i)))))(0)(str_to_int(str_len(s)))
glyph FROMHEX = la s. SPAN(la i. (la hv. chr(int_to_str(add(mul(hv(str_at(s)(mul(i)(2))))(16))(hv(str_at(s)(add(mul(i)(2))(1)))))))
                           (la c. (la n. lt(n)(58)(la _. sub(n)(48))(la _. sub(n)(87))("!"))(str_to_int(ord(c)))))(0)(div(str_to_int(str_len(s)))(2))
glyph MAIN = X25519_KIT(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(error)
    (add)(sub)(mul)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr)
 (la sm. la pub. la sh. print(HEX(sm(FROMHEX("a546e36bf0527c9d3b16154b82465edd62144c0ac1fc5a18506a2244ba449ac4"))
                                    (FROMHEX("e6db6867583030db3594c1a424b15f7c726624ec26b3353b10a903a6d0ab1c4c")))))
LAEOF
hs=$(date +%s); WM_HOST_TIMEOUT=${X25519_HOST_TIMEOUT:-2400} wm_host host.la "$T/host.out"; he=$(date +%s)
if [ "$hrc" = 0 ] && [ "$(cat "$T/host.out")" = "c3da55379de9c6908e94ea4df28d084f32eccf03491c71f754b4075577a28552" ]; then
    echo "PASS  x25519 engines: the C host gives RFC 7748 5.2 vector 1 too ($((he - hs)) s on the host)"
else
    echo "FAIL  x25519 engines: host rc=$hrc out=$(head -c 80 "$T/host.out")"; tail -2 "$T/hre"; ok=0
fi

# ── 7. timing ──────────────────────────────────────────────────────────────
( cd "$T" && python3 oracle.py timing ) > "$T/timing.exp"
vm_run t.bin time "$T/time.out"
tbad=0
while read -r w op cpu wall dig; do
    [ "$w" = time ] || continue
    [ "$(awk -v o="$op" '$1 == o {print $2}' "$T/timing.exp")" = "$dig" ] || { tbad=1; echo "      wrong result: $op"; }
    echo "INFO  x25519 timing (VM): $op $((cpu / 1000)) ms CPU, $((wall / 1000)) ms wall (best of 3)"
done < "$T/time.out"
if [ "$vrc" = 0 ] && [ "$tbad" = 0 ] && [ "$(grep -c '^time ' "$T/time.out")" = 3 ]; then
    echo "PASS  x25519 timing (VM): every timed result is the oracle's"
else
    echo "FAIL  x25519 timing (VM): rc=$vrc wrong=$tbad"; tail -3 "$T/vre"; ok=0
fi
[ "$ok" = 1 ] || exit 1
