#!/usr/bin/env bash
# gate_sha3.sh — SHA3_KIT (logossha3.la) is FIPS 202's SHA3-256, SHA3-512,
# SHAKE128 and SHAKE256, on the native VM, and the C host agrees.
#
# WHAT IT GUARDS:
#   0. the tables, statically: the 24 round constants written in
#      logossha3.la are the ones FIPS 202 Algorithm 5 (the LFSR rc(t)) and
#      Algorithm 6 give; rho and pi are read by evaluating the module's own
#      pi (K_PI over the K_ROW/K_ROW0 builders SHA3_KIT gives it) on
#      symbolic lanes, and each output position (x', y') must hold the input
#      lane (x, y) = ((x' + 3y') mod 5, x') rotated by FIPS 202 3.2.2's
#      r[x,y] (the triangular numbers (t+1)(t+2)/2 mod 64 along the walk
#      (x,y) -> (y, 2x+3y)), A[0,0] unrotated, each output row handed to chi
#      (row 0 to chi0 with the round constant); theta's rotation is 1;
#   1. known answers, from literal hex below (where each comes from is
#      written beside it): the empty message and "abc" for all four
#      functions, SHAKE at 32 and 64 bytes; and NIST's 1600-bit message (200
#      bytes of 0xA3: two absorbed blocks at rates 136 and 168, three at
#      SHA3-512's 72) for all four;
#   2. hashlib as the oracle on random messages of every length 0..3r+1 for
#      each function (r = 136, 72, 168, 136; SHAKE128 at 32 bytes out,
#      SHAKE256 at 64), the boundaries r-1, r, r+1 and 2r-1 called out; the
#      messages are drawn from a seeded generator (SHA3_SEED, printed);
#   3. SHAKE output lengths 0, 1, r-1, r, r+1 and 3r+5 (four squeeze blocks
#      for SHAKE128, four for SHAKE256), each on messages of 0, 1, r-1, r and
#      r+1 bytes, against hashlib;
#   4. a negative output length halts loudly (rc 1, the message, nothing on
#      stdout), for SHAKE128 and SHAKE256;
#   5. the C host gives the VM's bytes, and hashlib's, on a small set (SHA3-256
#      of "abc" and of 136 bytes, SHA3-512 of "" and of 71 bytes, SHAKE128 of
#      "abc" to 170 bytes, SHAKE256 of 200 x 0xA3 to 64 bytes); SHA3_HOST=0
#      skips it (reported as not run);
#   6. confine(logossha3.la)(nil) is ok (logossec.la's static confinement:
#      every name the module uses is a parameter or its own glyph);
#   7. kit style, statically: every reference to a glyph in logossha3.la is
#      in SHA3_KIT and evaluated while the kit is built (a LET's value or
#      continuation, an applied lambda), none inside a function the kit
#      returns (a parse of the module, as gate_logossign.sh does);
#   8. position: one timing program runs as it is and with a glyph of
#      SHA3_POS_MB megabytes (default 4; the stream must stay under the VM's
#      5 MiB) in front of the module in its compiled stream, three times each,
#      alternating. A call that names one builtin (str_len) measures what ONE
#      name resolved at run time costs there (it walks the glyph: about 1.3 ms
#      at 4 MB, against about 1.2 ms for a whole sha3_512); each of sha3_512,
#      sha3_256, shake128 and shake256 of a short message may take at most
#      SHA3_POS_FRAC percent (default 50) of that walk more than its least
#      time without the glyph, so a single name resolved at run time on every
#      call fails the arm (and confine or kit style say which name);
#   9. timing lines (INFO, CPU time inside the program, best of 5): one
#      Keccak-f permutation (SHAKE128 of the empty message to 0 bytes: one
#      padded block absorbed, one permutation, nothing squeezed), ten more
#      squeeze blocks (SHAKE128 to 1848 bytes against 168), and SHA3-512 of
#      0, 1 KB and 10 KB, every timed result checked against hashlib.
# ISOLATION: private temp dir (gate_wm_common.sh). The VM test program is
# compiled once and run per arm with mode.txt naming the arm; the C host run
# (about 20 s) starts first and runs beside the VM arms; the whole
# gate took about 23 s of wall time on a 4-core machine.
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1
wm_setup logossha3.la logossec.la
command -v python3 >/dev/null || { echo "FAIL  sha3: python3 (the oracle) is not installed"; exit 1; }
: "${SHA3_POS_MB:=4}"
: "${SHA3_POS_FRAC:=50}"
: "${SHA3_HOST:=1}"
: "${SHA3_SEED:=$(python3 -c 'import os; print(int.from_bytes(os.urandom(4), "big"))')}"

# A VM process killed by SIGKILL (rc 137) was killed from outside (the memory
# cgroup's OOM killer on a busy machine), which says nothing about the code:
# it is retried twice, after a pause, with a NOTE. Every other result counts.
vm_once() {  # vm_once OUT ERR: run logos_program.bin in $T; sets vrc
    local tries=0
    while :; do
        vrc=0; ( cd "$T" && timeout "$WM_VM_TIMEOUT" ./logos_secd >"$1" 2>"$2" ) || vrc=$?
        [ "$vrc" = 137 ] && [ "$tries" -lt 2 ] || return 0
        tries=$((tries + 1)); echo "NOTE  sha3: a VM process was killed by SIGKILL (out of memory on a busy machine?); retrying"
        sleep 30
    done
}
vm_compile() {  # vm_compile PROG.la BIN: compile on the VM into $T/BIN; a failure ends the gate
    cp "$T/$1" "$T/logos_source.la"; cp "$T/compiler.bin" "$T/logos_program.bin"
    vm_once /dev/null "$T/vce"
    [ "$vrc" = 0 ] || { echo "FAIL  sha3: $1 did not compile (rc $vrc)"; tail -3 "$T/vce"; exit 1; }
    cp "$T/logos_program.bin" "$T/$2"
}
vm_run() {  # vm_run BIN MODE OUT: run the compiled BIN with mode.txt = MODE; sets vrc, stderr in $T/vre
    printf '%s' "$2" > "$T/mode.txt"; cp "$T/$1" "$T/logos_program.bin"
    vm_once "$3" "$T/vre"
}

# ── the oracle ─────────────────────────────────────────────────────────
cat > "$T/oracle.py" <<'PYEOF'
import functools, hashlib, os, random, re, sys
RATE = {"s256": 136, "s512": 72, "k128": 168, "k256": 136}
# a parse of an LA module (no imports): glyph name -> AST, the AST nodes
# ("var", name), ("str", s), ("int", digits), ("lam", x, body), ("app", f, a)
def parse_module(src):
    i, n, toks = 0, len(src), []
    idc = lambda c: c.isalnum() or c == "_" or ord(c) >= 0x80
    while i < n:
        c = src[i]
        if c.isspace(): i += 1; continue
        if c == "#":
            while i < n and src[i] != "\n": i += 1
            continue
        if c in "().=": toks.append((c, None)); i += 1; continue
        if c == '"':
            j = i + 1
            while j < n and src[j] != '"': j += 2 if src[j] == "\\" else 1
            if j >= n: raise SyntaxError("unterminated string")
            toks.append(("str", src[i + 1:j])); i = j + 1; continue
        if c.isdigit():
            j = i
            while j < n and src[j].isdigit(): j += 1
            toks.append(("int", src[i:j])); i = j; continue
        if idc(c):
            j = i
            while j < n and idc(src[j]): j += 1
            w = src[i:j]
            toks.append((w, None) if w in ("glyph", "la", "import", "export") else ("id", w)); i = j; continue
        raise SyntaxError("unexpected character %r" % c)
    pos = [0]
    def peek(): return toks[pos[0]][0] if pos[0] < len(toks) else None
    def take(k):
        if peek() != k: raise SyntaxError("expected %s, got %s at token %d" % (k, peek(), pos[0]))
        v = toks[pos[0]][1]; pos[0] += 1; return v
    def expr():
        if peek() == "la":
            take("la"); x = take("id"); take(".")
            return ("lam", x, expr())
        k = peek()
        if k == "id": e = ("var", take("id"))
        elif k in ("str", "int"): e = (k, take(k))
        elif k == "(": take("("); e = expr(); take(")")
        else: raise SyntaxError("unexpected %s at token %d" % (k, pos[0]))
        while peek() == "(":
            take("("); a = expr(); take(")"); e = ("app", e, a)
        return e
    glyphs = {}
    while peek() is not None:
        if peek() == "glyph":
            take("glyph"); g = take("id"); take("="); glyphs[g] = expr()
        elif peek() == "export":
            take("export")
            while peek() == "id": take("id")
        else: raise SyntaxError("unexpected top-level %s (a kit module imports nothing)" % peek())
    return glyphs
SWEEPOUT = {"k128": 32, "k256": 64}
def H(tag, m, L=None):
    if tag == "s256": return hashlib.sha3_256(m).digest()
    if tag == "s512": return hashlib.sha3_512(m).digest()
    if tag == "k128": return hashlib.shake_128(m).digest(SWEEPOUT["k128"] if L is None else L)
    if tag == "k256": return hashlib.shake_256(m).digest(SWEEPOUT["k256"] if L is None else L)
def msg(tag, n): return open("m/%s_%d" % (tag, n), "rb").read()
# the SHAKE output-length cases: message lengths x output lengths
def outcases(tag):
    r = RATE[tag]
    return [(n, L) for n in (0, 1, r - 1, r, r + 1) for L in (0, 1, r - 1, r, r + 1, 3 * r + 5)]
cmd = sys.argv[1]
if cmd == "data":
    # m/<tag>_<n> for n = 0..3r+1, and the two timing messages, from the seed
    rnd = random.Random(int(sys.argv[2]))
    os.makedirs("m", exist_ok=True)
    for tag, r in RATE.items():
        for n in range(3 * r + 2):
            open("m/%s_%d" % (tag, n), "wb").write(rnd.randbytes(n))
    open("m/t1k", "wb").write(rnd.randbytes(1024)); open("m/t10k", "wb").write(rnd.randbytes(10240))
elif cmd == "sweep":
    for tag in ("s256", "s512", "k128", "k256"):
        for n in range(3 * RATE[tag] + 2): print(tag, n, H(tag, msg(tag, n)).hex())
    print("end")
elif cmd == "checksweep":
    # every line equal, and the boundary lengths present among them
    want = open(sys.argv[2]).read().split("\n"); got = open(sys.argv[3]).read().split("\n")
    bad = [(w, g) for w, g in zip(want, got) if w != g]
    if len(want) != len(got) or bad:
        print("FAIL first difference: want %r got %r (%d lines wanted, %d got)"
              % ((bad[0] if bad else ("", ""))[0][:90], (bad[0] if bad else ("", ""))[1][:90], len(want), len(got)))
        sys.exit(0)
    seen = {(l.split(" ")[0], int(l.split(" ")[1])) for l in got if l.count(" ") == 2}
    marks = []
    for tag in ("s256", "s512", "k128", "k256"):
        r = RATE[tag]; b = [r - 1, r, r + 1, 2 * r - 1]
        assert all((tag, n) in seen for n in b) and all((tag, n) in seen for n in range(3 * r + 2)), tag
        marks.append("%s r=%d: 0..%d, boundaries %s" % (tag, r, 3 * r + 1, " ".join(map(str, b))))
    print("ok %d; %s" % (len(seen), "; ".join(marks)))
elif cmd == "outlen":
    for tag in ("k128", "k256"):
        for n, L in outcases(tag): print(tag, n, L, H(tag, msg(tag, n), L).hex())
    print("end")
elif cmd == "host":
    print("sha3_256 abc " + hashlib.sha3_256(b"abc").hexdigest())
    print("sha3_256 136 " + hashlib.sha3_256(msg("s256", 136)).hexdigest())
    print("sha3_512 empty " + hashlib.sha3_512(b"").hexdigest())
    print("sha3_512 71 " + hashlib.sha3_512(msg("s512", 71)).hexdigest())
    print("shake128 abc 170 " + hashlib.shake_128(b"abc").hexdigest(170))
    print("shake256 a3x200 64 " + hashlib.shake_256(b"\xa3" * 200).hexdigest(64))
    print("end")
elif cmd == "time":
    m1, m10 = open("m/t1k", "rb").read(), open("m/t10k", "rb").read()
    print("perm " + hashlib.shake_128(b"").hexdigest(0))
    print("squeeze1 " + hashlib.shake_128(b"").hexdigest(168))
    print("squeeze11 " + hashlib.shake_128(b"").hexdigest(1848))
    print("sha3_512-0 " + hashlib.sha3_512(b"").hexdigest())
    print("sha3_512-1KB " + hashlib.sha3_512(m1).hexdigest())
    print("sha3_512-10KB " + hashlib.sha3_512(m10).hexdigest())
    print("end")
elif cmd == "pos":
    m = b"attack at dawn"
    print("walk " + m.hex())
    print("sha3_512 " + hashlib.sha3_512(m).hexdigest()); print("sha3_256 " + hashlib.sha3_256(m).hexdigest())
    print("shake128 " + hashlib.shake_128(m).hexdigest(32)); print("shake256 " + hashlib.shake_256(m).hexdigest(64))
    print("end")
elif cmd == "tables":
    src = open(sys.argv[2], encoding="utf-8").read()
    # FIPS 202 Algorithm 5: rc(t) from the LFSR x^8 + x^6 + x^5 + x^4 + 1
    def rc_bit(t):
        if t % 255 == 0: return 1
        R = [1, 0, 0, 0, 0, 0, 0, 0]
        for _ in range(t % 255):
            R = [0] + R
            R[0] ^= R[8]; R[4] ^= R[8]; R[5] ^= R[8]; R[6] ^= R[8]
            R = R[:8]
        return R[0]
    # Algorithm 6: RC[i] has bit 2^j - 1 = rc(j + 7 i), j = 0..6
    RC = [sum(rc_bit(j + 7 * i) << ((1 << j) - 1) for j in range(7)) for i in range(24)]
    # 3.2.2: r[x,y], walking (x,y) = (1,0), then (y, 2x+3y), t = 0..23
    r = [[0] * 5 for _ in range(5)]; x, y = 1, 0
    for t in range(24):
        r[x][y] = ((t + 1) * (t + 2) // 2) % 64; x, y = y, (2 * x + 3 * y) % 5
    want_rows = [[r[(xp + 3 * yp) % 5][xp] for xp in range(5)] for yp in range(5)]
    i0, i1 = src.find("LET(cons(1)"), src.find("(la RC.")
    assert 0 <= i0 < i1, "no round-constant list"
    got_rc = []
    for top, lo1, lo2 in re.findall(r"cons\((?:bor\((TOP)\)\((\d+)\)|(\d+))\)", src[i0:i1]):
        got_rc.append(((1 << 63) if top else 0) | int(lo1 or lo2))
    assert len(got_rc) == 24, "%d round constants, want 24" % len(got_rc)
    assert got_rc == RC, "round constants differ from FIPS 202 Algorithm 6: %s" % next(
        "RC[%d] = %#018x, want %#018x" % (i, g, w) for i, (g, w) in enumerate(zip(got_rc, RC)) if g != w)
    # rho and pi, by evaluating the module's own code on symbols: the value
    # SHA3_KIT gives pi (K_PI applied to its five output-row builders, each a
    # K_ROW or K_ROW0 of chi and its rotations), applied to the round
    # constant w and five rows of named lanes A[x,y]. M, chi, chi0 and rot
    # stay symbols, so the result reads M(row 0)..(row 4), row y' being
    # chi(..) of its five lanes (chi0(w)(..) for row 0) and each lane
    # rot(N)(A[x,y]) or A[x,y] itself. Output position (x', y') must hold
    # B[x', y'] = rot(r[x,y])(A[x,y]) with (x, y) = ((x' + 3y') mod 5, x')
    # (pi: B[y, 2x+3y] = A[x,y] rotated by rho), A[0,0] unrotated.
    G = parse_module(src)
    class Clo:
        def __init__(c, x, body, env): c.x, c.body, c.env = x, body, env
    def ev(e, env):
        if e[0] == "var":
            if e[1] in env: return env[e[1]]
            if e[1] in G: return ev(G[e[1]], {})
            return ("sym", e[1])
        if e[0] == "int": return int(e[1])
        if e[0] == "str": return ("strlit", e[1])
        if e[0] == "lam": return Clo(e[1], e[2], env)
        return ap(ev(e[1], env), ev(e[2], env))
    def ap(f, a):
        if isinstance(f, Clo): env = dict(f.env); env[f.x] = a; return ev(f.body, env)
        if callable(f): return f(a)
        return ("ap", f, a)
    def spine(t):
        args = []
        while isinstance(t, tuple) and t[0] == "ap": args.append(t[2]); t = t[1]
        return t, args[::-1]
    def show(t):
        if isinstance(t, tuple) and t[0] == "lane": return "A[%d,%d]" % t[1:]
        if isinstance(t, tuple) and t[0] == "sym": return t[1]
        if isinstance(t, tuple) and t[0] == "ap": return show(t[1]) + "(" + show(t[2]) + ")"
        return repr(t)
    def find_let(e, name):  # the value of the LET(value)(la name. ...) in e
        todo = [e]
        while todo:
            t = todo.pop()
            if t[0] == "app":
                if t[1][0] == "app" and t[1][1] == ("var", "LET") and t[2][0] == "lam" and t[2][1] == name: return t[1][2]
                todo += [t[1], t[2]]
            elif t[0] == "lam": todo.append(t[2])
    assert "SHA3_KIT" in G and "K_PI" in G, "no SHA3_KIT or K_PI"
    piv = find_let(G["SHA3_KIT"], "pi")
    assert piv is not None, "no LET(...)(la pi. ...) in SHA3_KIT"
    lane = lambda x, y: ("lane", x, y)
    row = lambda y: (lambda k: functools.reduce(ap, [lane(x, y) for x in range(5)], k))
    out = functools.reduce(ap, [("sym", "w")] + [row(y) for y in range(5)],
                           ev(piv, {v: ("sym", v) for v in ("M", "chi", "chi0", "rot")}))
    head, rows = spine(out)
    assert head == ("sym", "M") and len(rows) == 5, "pi's result is not M of five rows: %s" % show(out)[:200]
    got_rows = []
    for yp, rw in enumerate(rows):
        h, xs = spine(rw)
        if yp == 0:
            assert h == ("sym", "chi0") and len(xs) == 6 and xs[0] == ("sym", "w"), \
                "output row 0 is not chi0(w) of five lanes: %s" % show(rw)
            xs = xs[1:]
        else:
            assert h == ("sym", "chi") and len(xs) == 5, "output row %d is not chi of five lanes: %s" % (yp, show(rw))
        offs = []
        for xp, t in enumerate(xs):
            x, y = (xp + 3 * yp) % 5, xp
            want = lane(x, y) if r[x][y] == 0 else ("ap", ("ap", ("sym", "rot"), r[x][y]), lane(x, y))
            assert t == want, "output row %d position %d is %s, want %s (FIPS 202 3.2.2 r[%d,%d] = %d at the lane pi gathers)" % (
                yp, xp, show(t), show(want), x, y, r[x][y])
            offs.append(r[x][y])
        got_rows.append(offs)
    assert got_rows == want_rows
    assert "LET(K_D(bxor)(M)(rot(C1)))" in src, "theta's rotation is not rot(C1)"
    print("ok RC[0..23] = %#x .. %#x; rows %s" % (RC[0], RC[23], " ".join("/".join(map(str, w)) for w in want_rows)))
elif cmd == "kitstyle":
    # Kit style, statically (gate_logossign.sh's check, with LET the only
    # record form): every reference to a glyph must be in KIT's body and
    # evaluated while the kit is built (under its parameters, in the value or
    # the continuation of a LET, or an applied lambda), never inside a lambda
    # the kit returns or passes as a value; every other glyph names none.
    src, kit = open(sys.argv[2], encoding="utf-8").read(), sys.argv[3]
    glyphs = parse_module(src)
    def lams(e, k=None):
        xs = []
        while e[0] == "lam" and (k is None or len(xs) < k): xs.append(e[1]); e = e[2]
        return xs, e
    bad, seen = [], [0]
    def walk(e, bound, now):
        if e[0] == "var":
            if e[1] in glyphs and e[1] not in bound:
                if now: seen[0] += 1
                else: bad.append(e[1])
            return
        if e[0] in ("str", "int"): return
        if e[0] == "lam": walk(e[2], bound | {e[1]}, False); return
        head, args = e, []
        while head[0] == "app": args.append(head[2]); head = head[1]
        args.reverse()
        run = None  # the argument whose lambda is applied while the kit is built
        if now:
            hn = head[1] if head[0] == "var" else None
            if hn == "LET" and hn not in bound and len(args) == 2: run = 1
            elif head[0] == "lam":
                xs, body = lams(head, len(args))
                if len(xs) == len(args):
                    for a in args: walk(a, bound, True)
                    walk(body, bound | set(xs), True); return
        walk(head, bound, now)
        for j, a in enumerate(args):
            xs, body = lams(a, 1 if j == run else 0)
            if j == run and len(xs) == 1: walk(body, bound | set(xs), True)
            else: walk(a, bound, now)
    for g, e in glyphs.items():
        if g == kit: xs, body = lams(e); walk(body, set(xs), True)
        else: walk(e, set(), False)
    assert kit in glyphs, "no glyph " + kit
    assert not bad, "glyphs named at run time: " + " ".join(bad)
    print("ok %d %d %s" % (len(glyphs), seen[0], ",".join(sorted(glyphs))))
PYEOF

# ── the test program, compiled once ────────────────────────────────────
cat > "$T/t.la" <<'LAEOF'
import("logossha3.la")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph SEQ = la a. la b. b
glyph NIL = la n. la c. n(n)
glyph C = la h. la t. la n. la c. c(h)(t)
glyph PR = la a. la b. la k. k(a)(b)
glyph FOR = Z(la go. la l. la f. l(la _. "")(la h. la t. (la _. go(t)(f))(f(h))))
glyph UPTO = Z(la go. la a. la b. lt(a)(b)(la _. C(a)(go(add(a)(1))(b)))(la _. NIL)("!"))
glyph REP = Z(la go. la n. la s. int_eq(n)(0)(la _. "")(la _. concat(s)(go(sub(n)(1))(s)))("!"))
glyph SP = la x. la y. concat(x)(concat(" ")(y))
# hex(raw): lowercase hex, joined by halving; a kit, built once
glyph HEXKIT = la str_at. la ord. la str_to_int. la concat. la str_len. la add. la lt. la bshr. la band. la fix.
  (la H. la n4. la sp. la raw.
     (la sa. sp(la i. (la b. concat(H(bshr(b)(4)))(H(n4(b))))(str_to_int(ord(sa(i)))))(0)(str_to_int(str_len(raw))))
     (str_at(raw)))
  (str_at("0123456789abcdef"))(band(15))
  (la f. fix(la sp. la lo. la hi.
     lt(add(lo)(1))(hi)
       (la _. (la mid. concat(sp(lo)(mid))(sp(mid)(hi)))(bshr(add(lo)(hi))(1)))
       (la _. lt(lo)(hi)(la _. f(lo))(la _. "")("!"))
       ("!")))
glyph MSG = la tag. la n. read_file(concat(concat(concat("m/")(tag))("_"))(int_to_str(n)))
glyph A3X200 = REP(200)(chr("163"))
# the known answers (the expected hex is the gate's, written in the shell script)
glyph KAT = la s2. la s5. la k1. la k2. la hex.
  SEQ(FOR(C(PR("empty")(""))(C(PR("abc")("abc"))(C(PR("a3x200")(A3X200))(NIL))))(la p. p(la name. la m.
        SEQ(SEQ(SEQ(SEQ(SEQ(SEQ(
          print(SP(SP("sha3_256")(name))(hex(s2(m)))))
          (print(SP(SP("sha3_512")(name))(hex(s5(m))))))
          (print(SP(SP(SP("shake128")(name))("32"))(hex(k1(m)(32))))))
          (print(SP(SP(SP("shake128")(name))("64"))(hex(k1(m)(64))))))
          (print(SP(SP(SP("shake256")(name))("32"))(hex(k2(m)(32))))))
          (print(SP(SP(SP("shake256")(name))("64"))(hex(k2(m)(64))))))
          (""))))
     (print("end"))
# every length 0..3r+1, the message from m/<tag>_<n>
glyph SWEEP = la s2. la s5. la k1. la k2. la hex.
  SEQ(SEQ(SEQ(SEQ(
    FOR(UPTO(0)(410))(la n. print(SP(SP("s256")(int_to_str(n)))(hex(s2(MSG("s256")(n)))))))
    (FOR(UPTO(0)(218))(la n. print(SP(SP("s512")(int_to_str(n)))(hex(s5(MSG("s512")(n))))))))
    (FOR(UPTO(0)(506))(la n. print(SP(SP("k128")(int_to_str(n)))(hex(k1(MSG("k128")(n))(32)))))))
    (FOR(UPTO(0)(410))(la n. print(SP(SP("k256")(int_to_str(n)))(hex(k2(MSG("k256")(n))(64)))))))
    (print("end"))
# SHAKE output lengths 0, 1, r-1, r, r+1, 3r+5 on messages of 0, 1, r-1, r, r+1 bytes
glyph OUTL1 = la tag. la k. la hex. la r.
  FOR(C(0)(C(1)(C(sub(r)(1))(C(r)(C(add(r)(1))(NIL))))))(la n.
    FOR(C(0)(C(1)(C(sub(r)(1))(C(r)(C(add(r)(1))(C(add(mul(3)(r))(5))(NIL)))))))(la L.
      print(SP(SP(SP(tag)(int_to_str(n)))(int_to_str(L)))(hex(k(MSG(tag)(n))(L))))))
glyph OUTLEN = la s2. la s5. la k1. la k2. la hex.
  SEQ(SEQ(OUTL1("k128")(k1)(hex)(168))(OUTL1("k256")(k2)(hex)(136)))(print("end"))
glyph HOST = la s2. la s5. la k1. la k2. la hex.
  SEQ(SEQ(SEQ(SEQ(SEQ(SEQ(
    print(SP("sha3_256 abc")(hex(s2("abc")))))
    (print(SP("sha3_256 136")(hex(s2(MSG("s256")(136)))))))
    (print(SP("sha3_512 empty")(hex(s5(""))))))
    (print(SP("sha3_512 71")(hex(s5(MSG("s512")(71)))))))
    (print(SP("shake128 abc 170")(hex(k1("abc")(170))))))
    (print(SP("shake256 a3x200 64")(hex(k2(A3X200)(64))))))
    (print("end"))
# timing: clock_gettime is bound to cg, and the output lengths to names,
# before the first clock read, so nothing between two reads names a glyph or
# a builtin (an integer literal is a call of str_to_int by name, which would
# walk the program); CPU time (clock 2) in ns
glyph TSPLIT = Z(la go. la s. la acc. str_eq(str_head(s))(" ")(la _. la k. k(acc)(str_tail(s)))(la _. go(str_tail(s))(concat(acc)(str_head(s))))("!"))
glyph NS = la s. TSPLIT(s)("")(la a. la b. add(mul(str_to_int(a))(1000000000))(str_to_int(b)))
glyph KTIME = la cg. la f. (la t0. (la r. (la t1. la k. k(t0)(t1)(r))(cg("2")))(f("!")))(cg("2"))
glyph PBEST = Z(la go. la n. la cg. la f. la best. la res.
  int_eq(n)(0)(la _. la k. k(best)(res))
    (la _. KTIME(cg)(f)(la t0. la t1. la r.
             (la d. go(sub(n)(1))(cg)(f)(lt(d)(best)(la _. d)(la _. best)("!"))(r))(sub(NS(t1))(NS(t0)))))
    ("!"))
glyph TIME = la s2. la s5. la k1. la k2. la hex.
  (la cg. la m1. la m10. la L0. la L1. la L11.
    (la run.
      SEQ(SEQ(SEQ(SEQ(SEQ(SEQ(
        run("perm")(la _. k1("")(L0)))
        (run("squeeze1")(la _. k1("")(L1))))
        (run("squeeze11")(la _. k1("")(L11))))
        (run("sha3_512-0")(la _. s5(""))))
        (run("sha3_512-1KB")(la _. s5(m1))))
        (run("sha3_512-10KB")(la _. s5(m10))))
        (print("end")))
    (la label. la f. PBEST(5)(cg)(f)(999999999999999)("")(la ns. la r.
       print(SP(SP(label)(int_to_str(div(ns)(1000))))(hex(r))))))
  (clock_gettime)(read_file("m/t1k"))(read_file("m/t10k"))(0)(168)(1848)
# position: "walk" names one builtin (str_len) between the clock reads on
# purpose, so it costs one walk of the program: what a single name resolved
# at run time would add to a call
glyph POS = la s2. la s5. la k1. la k2. la hex.
  (la cg. la m. la L32. la L64.
    (la run.
      SEQ(SEQ(SEQ(SEQ(SEQ(
        run("walk")(la _. (la x. m)(str_len(m))))
        (run("sha3_512")(la _. s5(m))))
        (run("sha3_256")(la _. s2(m))))
        (run("shake128")(la _. k1(m)(L32))))
        (run("shake256")(la _. k2(m)(L64))))
        (print("end")))
    (la label. la f. PBEST(15)(cg)(f)(999999999999999)("")(la ns. la r.
       print(SP(SP(label)(int_to_str(ns)))(hex(r))))))
  (clock_gettime)("attack at dawn")(32)(64)
glyph NEG128 = la s2. la s5. la k1. la k2. la hex. SEQ(k1("abc")(sub(0)(1)))(print("NOT REACHED"))
glyph NEG256 = la s2. la s5. la k1. la k2. la hex. SEQ(k2("abc")(sub(0)(1)))(print("NOT REACHED"))
glyph DISPATCH = Z(la go. la mode. la l. la args. l(la _. print(concat("unknown mode ")(mode)))
    (la h. la t. h(la name. la f. str_eq(name)(mode)(la _. args(f))(la _. go(mode)(t)(args))("!"))))
glyph MAIN = SHA3_KIT(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(error)
    (add)(sub)(mul)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr)
 (la s2. la s5. la k1. la k2.
   (la hex. DISPATCH(read_file("mode.txt"))
      (C(PR("kat")(KAT))(C(PR("sweep")(SWEEP))(C(PR("outlen")(OUTLEN))(C(PR("host")(HOST))
      (C(PR("time")(TIME))(C(PR("pos")(POS))(C(PR("neg128")(NEG128))(C(PR("neg256")(NEG256))(NIL)))))))))
      (la f. f(s2)(s5)(k1)(k2)(hex)))
   (HEXKIT(str_at)(ord)(str_to_int)(concat)(str_len)(add)(lt)(bshr)(band)(Z)))
LAEOF
( cd "$T" && python3 oracle.py data "$SHA3_SEED" ) || { echo "FAIL  sha3: the oracle could not write the messages"; exit 1; }

# ── 5 (started now, checked at the end): the C host ────────────────────────
if [ "$SHA3_HOST" = 1 ]; then
    mkdir -p "$T/host"; cp -r "$T/tiny_host" "$T/logossha3.la" "$T/t.la" "$T/m" "$T/host/"
    printf host > "$T/host/mode.txt"
    ( cd "$T/host" && { timeout "$WM_HOST_TIMEOUT" ./tiny_host t.la > host.out 2> host.err; echo $? > host.rc; } ) &
    host_pid=$!
fi

# ── 0. the tables, statically ──────────────────────────────────────────────
tres=$(cd "$T" && python3 -I oracle.py tables logossha3.la 2>&1 | tail -1)
if [ "${tres%% *}" = ok ]; then
    echo "PASS  sha3 tables (static): the round constants in logossha3.la are FIPS 202 Algorithm 6's (from the LFSR of Algorithm 5); the module's pi, evaluated on symbolic lanes, puts at each output position (x', y') the input lane ((x' + 3y') mod 5, x') rotated by 3.2.2's r[x,y], each row into chi (row 0 into chi0 with the round constant); theta rotates by 1: ${tres#ok }"
else
    echo "FAIL  sha3 tables (static): $tres"; ok=0
fi

# ── 7. kit style, statically ───────────────────────────────────────────────
ksres=$(cd "$T" && python3 -I oracle.py kitstyle logossha3.la SHA3_KIT 2>&1 | tail -1)
read -r ksw ksn ksr _ <<< "$ksres"
if [ "$ksw" = ok ]; then
    echo "PASS  sha3 kit style (static): no glyph is named at run time: all $ksr references to the module's $ksn glyphs are in SHA3_KIT and evaluated while the kit is built (a LET's value or continuation, an applied lambda), none inside a function the kit returns"
else
    echo "FAIL  sha3 kit style (static): $ksres"; ok=0
fi

vm_compile t.la t.bin

# ── 1. known answers ──────────────────────────────────────────────────────
# Where each value comes from:
#   empty: NIST CSRC "Examples with Intermediate Values" (Cryptographic
#     Standards and Guidelines, example values for FIPS 202): SHA3-256_Msg0,
#     SHA3-512_Msg0, SHAKE128_Msg0 and SHAKE256_Msg0 (the SHAKE files give
#     4096 output bits; the first 32 and 64 bytes are these);
#   a3x200: the same page's 1600-bit message, 200 bytes of 0xA3: SHA3-256_1600,
#     SHA3-512_1600, SHAKE128_Msg1600, SHAKE256_Msg1600;
#   abc: not one of NIST's FIPS 202 examples (whose byte-aligned messages are
#     the two above); these are the values commonly published for "abc".
# The hex was written into this gate without the documents at hand (no
# network where it was written), and every value was confirmed against
# Python's hashlib (arm 2's oracle) before it was committed.
EXPECT="sha3_256 empty a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a
sha3_512 empty a69f73cca23a9ac5c8b567dc185a756e97c982164fe25859e0d1dcc1475c80a615b2123af1f5f94c11e3e9402c3ac558f500199d95b6d3e301758586281dcd26
shake128 empty 32 7f9c2ba4e88f827d616045507605853ed73b8093f6efbc88eb1a6eacfa66ef26
shake128 empty 64 7f9c2ba4e88f827d616045507605853ed73b8093f6efbc88eb1a6eacfa66ef263cb1eea988004b93103cfb0aeefd2a686e01fa4a58e8a3639ca8a1e3f9ae57e2
shake256 empty 32 46b9dd2b0ba88d13233b3feb743eeb243fcd52ea62b81b82b50c27646ed5762f
shake256 empty 64 46b9dd2b0ba88d13233b3feb743eeb243fcd52ea62b81b82b50c27646ed5762fd75dc4ddd8c0f200cb05019d67b592f6fc821c49479ab48640292eacb3b7c4be
sha3_256 abc 3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532
sha3_512 abc b751850b1a57168a5693cd924b6b096e08f621827444f70d884f5d0240d2712e10e116e9192af3c91a7ec57647e3934057340b4cf408d5a56592f8274eec53f0
shake128 abc 32 5881092dd818bf5cf8a3ddb793fbcba74097d5c526a6d35f97b83351940f2cc8
shake128 abc 64 5881092dd818bf5cf8a3ddb793fbcba74097d5c526a6d35f97b83351940f2cc844c50af32acd3f2cdd066568706f509bc1bdde58295dae3f891a9a0fca578378
shake256 abc 32 483366601360a8771c6863080cc4114d8db44530f8f1e1ee4f94ea37e78b5739
shake256 abc 64 483366601360a8771c6863080cc4114d8db44530f8f1e1ee4f94ea37e78b5739d5a15bef186a5386c75744c0527e1faa9f8726e462a12a4feb06bd8801e751e4
sha3_256 a3x200 79f38adec5c20307a98ef76e8324afbfd46cfd81b22e3973c65fa1bd9de31787
sha3_512 a3x200 e76dfad22084a8b1467fcf2ffa58361bec7628edf5f3fdc0e4805dc48caeeca81b7c13c30adf52a3659584739a2df46be589c51ca1a4a8416df6545a1ce8ba00
shake128 a3x200 32 131ab8d2b594946b9c81333f9bb6e0ce75c3b93104fa3469d3917457385da037
shake128 a3x200 64 131ab8d2b594946b9c81333f9bb6e0ce75c3b93104fa3469d3917457385da037cf232ef7164a6d1eb448c8908186ad852d3f85a5cf28da1ab6fe343817197846
shake256 a3x200 32 cd8a920ed141aa0407a22d59288652e9d9f1a7ee0c1e7c1ca699424da84a904d
shake256 a3x200 64 cd8a920ed141aa0407a22d59288652e9d9f1a7ee0c1e7c1ca699424da84a904d2d700caae7396ece96604440577da4f3aa22aeb8857f961c4cd8e06f0ae6610b
end"
vm_run t.bin kat "$T/kat.out"
if [ "$vrc" = 0 ] && [ "$(cat "$T/kat.out")" = "$EXPECT" ]; then
    echo "PASS  sha3 known answers (VM): SHA3-256, SHA3-512, SHAKE128 and SHAKE256 (32 and 64 bytes) of the empty message, of \"abc\" and of NIST's 200 x 0xA3: $(($(wc -l < "$T/kat.out") - 1)) values equal to the literal hex"
else
    echo "FAIL  sha3 known answers (VM): rc=$vrc"; diff <(echo "$EXPECT") "$T/kat.out" | head -10; tail -3 "$T/vre"; ok=0
fi

# ── 2. hashlib on every length 0..3r+1 ───────────────────────────────────
vm_run t.bin sweep "$T/sweep.out"; src=$vrc
( cd "$T" && python3 oracle.py sweep ) > "$T/sweep.exp"
sres=$(cd "$T" && python3 oracle.py checksweep sweep.exp sweep.out 2>&1 | tail -1)
if [ "$src" = 0 ] && [ "${sres%% *}" = ok ]; then
    echo "PASS  sha3 oracle (VM): hashlib on random messages (seed $SHA3_SEED) of every length, ${sres#ok }: all equal"
else
    echo "FAIL  sha3 oracle (VM): rc=$src seed=$SHA3_SEED: $sres"; tail -3 "$T/vre"; ok=0
fi

# ── 3. SHAKE output lengths ───────────────────────────────────────────────
vm_run t.bin outlen "$T/outlen.out"
( cd "$T" && python3 oracle.py outlen ) > "$T/outlen.exp"
if [ "$vrc" = 0 ] && cmp -s "$T/outlen.out" "$T/outlen.exp"; then
    echo "PASS  sha3 output lengths (VM): SHAKE128 to 0, 1, 167, 168, 169 and 509 bytes and SHAKE256 to 0, 1, 135, 136, 137 and 413 bytes, each on messages of 0, 1, r-1, r and r+1 bytes: $(($(wc -l < "$T/outlen.exp") - 1)) outputs equal to hashlib's"
else
    echo "FAIL  sha3 output lengths (VM): rc=$vrc seed=$SHA3_SEED"; diff "$T/outlen.exp" "$T/outlen.out" | cut -c1-120 | head -6; tail -3 "$T/vre"; ok=0
fi

# ── 4. a negative output length halts loudly ───────────────────────────────
for k in 128 256; do
    vm_run t.bin "neg$k" "$T/neg.out"
    msgk="logossha3: shake$k: the output length must not be negative"
    if [ "$vrc" = 1 ] && grep -qxF "$msgk" "$T/vre" && [ ! -s "$T/neg.out" ]; then
        echo "PASS  sha3 misuse (VM): shake$k with an output length of -1 halts with '$msgk'"
    else
        echo "FAIL  sha3 misuse (VM): shake$k(-1): rc=$vrc stdout=$(head -c 80 "$T/neg.out") stderr=$(head -c 120 "$T/vre")"; ok=0
    fi
done

# ── 6. confine ────────────────────────────────────────────────────────────
cat > "$T/cf.la" <<'LAEOF'
import("logossec.la")
glyph NIL = la n. la c. n(n)
# a stub crypt record: confine never touches it
glyph STUB = la s. s(la m. m)(la k. la m. m)(la a. a)(la a. a)(la a. a)(la x. x)
glyph MAIN = SEC_KIT(str_at)(ord)(str_len)(str_to_int)(int_to_str)(chr)(concat)(str_eq)(add)(sub)(mul)(div)(lt)(int_eq)(band)(bor)(bxor)(STUB)
 (la mint. la attenuate. la verify. la within. la confine.
   print(confine(read_file("logossha3.la"))(NIL)(la m. concat("err ")(m))(la v. "ok")))
LAEOF
vm_compile cf.la cf.bin; vm_run cf.bin - "$T/cf.out"
if [ "$vrc" = 0 ] && [ "$(cat "$T/cf.out")" = ok ]; then
    echo "PASS  sha3 confine (VM): confine(logossha3.la)(nil) is ok: every name the module uses is a parameter or one of its own glyphs (it imports nothing, names no builtin, and an integer literal is its str_to_int parameter)"
else
    echo "FAIL  sha3 confine (VM): rc=$vrc '$(head -c 200 "$T/cf.out")'"; tail -2 "$T/vre"; ok=0
fi

# ── 8. position ───────────────────────────────────────────────────────────
( cd "$T" && python3 oracle.py pos ) > "$T/pos.exp"
python3 -c "import sys; d=open(sys.argv[1],'rb').read(); open(sys.argv[2],'wb').write(b'FILLER\x00\x01'+b'a'*(int(sys.argv[3])*1048576)+b'\x00\x05'+d)" "$T/t.bin" "$T/tfill.bin" "$SHA3_POS_MB"
prc=0
for i in 1 2 3; do
    vm_run t.bin pos "$T/pos_plain$i.out"; [ "$vrc" = 0 ] || prc=$vrc
    vm_run tfill.bin pos "$T/pos_fill$i.out"; [ "$vrc" = 0 ] || prc=$vrc
done
pbad=0
for f in "$T"/pos_plain[123].out "$T"/pos_fill[123].out; do
    [ "$(awk 'NF == 3 {print $1, $3} NF == 1 {print}' "$f" 2>/dev/null)" = "$(cat "$T/pos.exp")" ] || pbad=1
done
least() { cat "$T"/pos_$1[123].out 2>/dev/null | awk -v op="$2" '$1 == op && (m == "" || $2 < m) {m = $2} END {print m}'; }
# W: one walk of the glyph (ns), from the call that names str_len
wa=$(least plain walk); wb=$(least fill walk); W=0; pslow=0; plines=""
if [ -n "$wa" ] && [ -n "$wb" ] && [ "$wb" -gt "$wa" ]; then W=$((wb - wa)); else pslow=1; fi
for op in sha3_512 sha3_256 shake128 shake256; do
    a=$(least plain $op); b=$(least fill $op)
    if [ -n "$a" ] && [ -n "$b" ] && [ "$a" -gt 0 ]; then
        d=$(((b - a) / 1000)); [ "$d" -ge 0 ] && d="+$d"
        plines="$plines $op $((a / 1000))/$((b / 1000)) us ($d us, $((b * 100 / a))%)"
        [ $(((b - a) * 100)) -le $((W * SHA3_POS_FRAC)) ] || pslow=1
    else pslow=1; fi
done
wline="one name resolved at run time (a call naming str_len) costs $((W / 1000)) us there ($((${wa:-0} / 1000)) us without the glyph, $((${wb:-0} / 1000)) us with)"
if [ "$prc" = 0 ] && [ "$pbad" = 0 ] && [ "$pslow" = 0 ]; then
    echo "PASS  sha3 position (VM): with a ${SHA3_POS_MB} MB glyph in front of the module $wline, and each function of a 14-byte message takes at most ${SHA3_POS_FRAC}% of that more than without the glyph, every result hashlib's; without/with:$plines"
else
    echo "FAIL  sha3 position (VM): rc=$prc wrong=$pbad over-${SHA3_POS_FRAC}%-of-a-walk=$pslow; with a ${SHA3_POS_MB} MB glyph $wline; without/with:$plines"; tail -3 "$T/vre"; ok=0
fi

# ── 9. timing ─────────────────────────────────────────────────────────────
vm_run t.bin time "$T/time.out"; trc=$vrc
( cd "$T" && python3 oracle.py time ) > "$T/time.exp"
tbad=0
while read -r op us dig; do
    [ "$op" = end ] && continue
    [ "$(awk -v k="$op" '$1 == k {print $2}' "$T/time.exp")" = "${dig:-}" ] || { tbad=1; echo "      wrong result: $op"; }
done < "$T/time.out"
tus() { awk -v k="$1" '$1 == k {print $2}' "$T/time.out"; }
if [ "$trc" = 0 ] && [ "$tbad" = 0 ] && [ "$(tail -1 "$T/time.out")" = end ] && [ -n "$(tus sha3_512-10KB)" ]; then
    s1=$(tus squeeze1); s11=$(tus squeeze11)
    echo "INFO  sha3 timing (VM, CPU time, best of 5): one Keccak-f permutation (shake128 of 0 bytes to 0: one padded block, one permutation) $(tus perm) us; a squeeze block (permutation + 168 bytes out) $(((s11 - s1) / 10)) us; sha3_512 of 0 bytes $(tus sha3_512-0) us, of 1 KB $(tus sha3_512-1KB) us, of 10 KB $(tus sha3_512-10KB) us"
    echo "PASS  sha3 timing (VM): every timed result is hashlib's"
else
    echo "FAIL  sha3 timing (VM): rc=$trc wrong=$tbad"; tail -3 "$T/vre"; ok=0
fi

# ── 5. the C host (started at the top) ─────────────────────────────────────
if [ "$SHA3_HOST" = 1 ]; then
    wait "$host_pid"
    hrc=$(cat "$T/host/host.rc" 2>/dev/null || echo none)
    vm_run t.bin host "$T/host.vm"
    ( cd "$T" && python3 oracle.py host ) > "$T/host.exp"
    if [ "$hrc" = 0 ] && [ "$vrc" = 0 ] && cmp -s "$T/host/host.out" "$T/host.vm" && cmp -s "$T/host.vm" "$T/host.exp"; then
        echo "PASS  sha3 engines: the C host and the VM give the same bytes, hashlib's, for SHA3-256 of \"abc\" and of 136 bytes, SHA3-512 of \"\" and of 71 bytes, SHAKE128 of \"abc\" to 170 bytes and SHAKE256 of 200 x 0xA3 to 64 bytes"
    else
        echo "FAIL  sha3 engines: host rc=$hrc vm rc=$vrc"; diff "$T/host.exp" "$T/host/host.out" | head -4; diff "$T/host.exp" "$T/host.vm" | head -4; tail -2 "$T/host/host.err"; ok=0
    fi
else
    echo "NOTE  sha3 engines: not run (SHA3_HOST=0)"
fi
[ "$ok" = 1 ] || exit 1
