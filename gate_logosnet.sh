#!/usr/bin/env bash
# gate_logosnet.sh — LogosNet (logosnet.la, NET_KIT), on the native VM.
#
# WHAT IT GUARDS (NET_DESIGN.md section 2):
#   1. frames: frame/deframe against Python's own framing (struct ">I"), over
#      random payloads cut at random chunk boundaries (1-byte chunks, cuts
#      inside a header, a 1 MiB payload, an empty one); a payload of 1 MiB + 1
#      halts loudly; a declared length above 1 MiB is reported as broken.
# ISOLATION: a private temp dir (gate_wm_common.sh; mktemp honours TMPDIR).
# VM only (the C host is far too slow for the crypto underneath).
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1
pass() { echo "PASS  logosnet: $*"; }
fail() { echo "FAIL  logosnet: $*"; ok=0; }
check() { if [ "$1" = 1 ]; then pass "$2"; else fail "$2"; [ -n "${3:-}" ] && echo "      $3"; fi; }
command -v python3 >/dev/null || { echo "FAIL  logosnet: python3 (the oracle) is not installed"; exit 1; }
wm_setup logosnet.la logoscrypt.la x25519.la
G0=$(date +%s)

# vm_compile PROG.la BIN: compile on the VM into $T/BIN; a failure ends the gate
vm_compile() {
    cp "$T/$1" "$T/logos_source.la"; cp "$T/compiler.bin" "$T/logos_program.bin"
    vrc=0; ( cd "$T" && timeout "$WM_VM_TIMEOUT" ./logos_secd >/dev/null 2>"$T/vce" ) || vrc=$?
    [ "$vrc" = 0 ] || { echo "FAIL  logosnet: $1 did not compile (rc $vrc)"; tail -c 400 "$T/vce"; exit 1; }
    cp "$T/logos_program.bin" "$T/$2"
}
# vm_run BIN MODE OUT: run BIN in $T with mode.txt = MODE; sets vrc, stderr in $T/vre
vm_run() {
    printf '%s' "$2" > "$T/mode.txt"; cp "$T/$1" "$T/logos_program.bin"
    vrc=0; ( cd "$T" && timeout "$WM_VM_TIMEOUT" ./logos_secd >"$3" 2>"$T/vre" ) || vrc=$?
}

# ── the oracle ─────────────────────────────────────────────────────────
cat > "$T/oracle.py" <<'PYEOF'
import os, sys, random, struct
def frame(p): return struct.pack(">I", len(p)) + p
mode = sys.argv[1]
if mode == "frames":
    # stream.bin: frames of many small payloads and some large ones;
    # sched.txt: the chunk sizes the LA cuts the stream into
    R = random.Random(int(sys.argv[2]))
    ps = [b"", b"\x00", b"ab", b"abc", b"abcd", b"\x00\x00\x00\x05\xff"]
    ps += [os.urandom(R.randint(0, 300)) for _ in range(150)]
    ps += [os.urandom(70000), b"", os.urandom(1 << 20), os.urandom(65535), b"z"]
    stream = b"".join(frame(p) for p in ps)
    cuts, pos = [], 0
    while pos < len(stream):
        r = R.random()
        if pos < 40000: n = R.randint(1, 37)            # small chunks: cuts inside headers
        elif r < 0.3: n = R.randint(1, 5)
        else: n = R.randint(1000, 300000)
        n = min(n, len(stream) - pos); cuts.append(n); pos += n
    open("stream.bin", "wb").write(stream)
    open("sched.txt", "w").write(" ".join(map(str, cuts)))
    print("frames %d tail 0" % len(ps))
    print("lens " + " ".join(str(len(p)) for p in ps))
    print("chunks %d" % len(cuts))
if mode == "framescheck":
    # the LA's re-framing of what it deframed must be the stream itself
    print("same" if open("out.bin", "rb").read() == open("stream.bin", "rb").read() else "differ")
if mode == "broken":
    big = 1048577
    open("brk1.bin", "wb").write(struct.pack(">I", big) + b"xyz")
    open("brk2.bin", "wb").write(frame(b"hello") + struct.pack(">I", 0xffffffff) + b"q")
    open("brk3.bin", "wb").write(struct.pack(">I", 1 << 20) + b"partial")
    open("brk4.bin", "wb").write(frame(b"x") + b"\x00\x10")
    # an oversize frame complete in the buffer: deframe must not release it
    open("brk5.bin", "wb").write(struct.pack(">I", big) + b"o" * big + frame(b"after"))
    print("brk1 0 broken T tail 7\nbrk2 1 broken T tail 5\nbrk3 0 broken F tail 11\nbrk4 1 broken F tail 2\n"
          "brk5 0 broken T tail %d" % (4 + big + 4 + 5))
PYEOF

# ── the LA test program: one compiled program, dispatching on mode.txt ──
cat > "$T/t.la" <<'LAEOF'
import("logosnet.la")
import("logoscrypt.la")
import("x25519.la")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph LET = la v. la k. k(v)
glyph SEQ = la a. la b. b
glyph NIL = la n. la c. n(n)
glyph CONS = la h. la t. la n. la c. c(h)(t)
glyph PR = la a. la b. la k. k(a)(b)
glyph BOOL = la b. b("T")("F")
glyph SP = la a. la b. concat(a)(concat(" ")(b))
# The test program's own helpers are a kit too: naming a builtin in a loop
# walks the whole program (the crypto modules included), so they are built
# once, with the builtins as parameters.
#   TK -> la s. s(len)(sub)(words)(join)(map)(rev)(app)(count)(rep)(showl)(feed)
glyph TK = (la str_at. la str_to_int. la int_to_str. la concat. la str_eq. la str_len.
            la add. la sub. la div. la lt. la int_eq. la C0. la C1. la C2. la nil. la cons.
    LET(la s. str_to_int(str_len(s)))(la len.
    LET(Z(la sp. la f. la lo. la hi.
        lt(add(lo)(C1))(hi)
          (la _. (la mid. concat(sp(f)(lo)(mid))(sp(f)(mid)(hi)))(div(add(lo)(hi))(C2)))
          (la _. lt(lo)(hi)(la _. f(lo))(la _. "")(C0))(C0)))(la span.
    LET(la s. la a. la b. span(str_at(s))(a)(b))(la ssub.
    LET(Z(la go. la acc. la l. l(la _. acc)(la h. la t. go(cons(h)(acc))(t)))(nil))(la rev.
    LET(Z(la go. la a. la b. a(la _. b)(la h. la t. cons(h)(go(t)(b)))))(la app.
    LET(Z(la go. la l. l(la _. C0)(la h. la t. add(C1)(go(t)))))(la count.
    LET(Z(la go. la f. la l. l(la _. nil)(la h. la t. cons(f(h))(go(f)(t)))))(la map.
    # words(s): the space-separated words of s
    LET(la s. (la n. Z(la go. la i. la st. la acc.
        lt(i)(n)
          (la _. str_eq(str_at(s)(i))(" ")
                   (la _. go(add(i)(C1))(add(i)(C1))(lt(st)(i)(la _. cons(ssub(s)(st)(i))(acc))(la _. acc)(C0)))
                   (la _. go(add(i)(C1))(st)(acc))(C0))
          (la _. rev(lt(st)(i)(la _. cons(ssub(s)(st)(i))(acc))(la _. acc)(C0)))(C0))(C0)(C0)(nil))(len(s)))(la words.
    # join(l): balanced concatenation of a list
    LET(Z(la go. la n. la l. la k. int_eq(n)(C0)(la _. k(nil)(l))
        (la _. l(la _. k(nil)(nil))(la h. la t. go(sub(n)(C1))(t)(la a. la b. k(cons(h)(a))(b))))(C0)))(la half.
    LET(Z(la go. la l. (la n. lt(n)(C2)
        (la _. l(la _. "")(la h. la t. h))
        (la _. half(div(n)(C2))(l)(la a. la b. concat(go(a))(go(b))))(C0))(count(l))))(la join.
    # rep(n)(s): n copies of s, by doubling
    LET(Z(la go. la n. la s. lt(n)(C1)(la _. "")
        (la _. (la h. (la hh. int_eq(sub(n)(add(div(n)(C2))(div(n)(C2))))(C1)(la _. concat(hh)(s))(la _. hh)(C0))
                      (concat(h)(h)))(go(div(n)(C2))(s)))(C0)))(la rep.
    LET(la l. join(map(la x. concat(" ")(x))(l)))(la showl.
    # feed(deframe)(s)(sizes): cut s by the sizes, deframe each chunk in turn;
    # la k. k(payloads)(buf)
    LET(la deframe. la s. Z(la go. la pos. la sizes. la buf. la acc.
        sizes(la _. la k. k(rev(acc))(buf))
             (la h. la t. (la e. deframe(buf)(ssub(s)(pos)(e))(la ps. la b2.
                             go(e)(t)(b2)(app(rev(ps))(acc))))
                          (add(pos)(str_to_int(h)))))(C0))(la feed.
      la s. s(len)(ssub)(words)(join)(map)(rev)(app)(count)(rep)(showl)(feed)))))))))))))))
  (str_at)(str_to_int)(int_to_str)(concat)(str_eq)(str_len)(add)(sub)(div)(lt)(int_eq)(0)(1)(2)(NIL)(CONS)
glyph B = la s. s(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(str_eq)(error)
                 (add)(sub)(mul)(div)(mod)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr)
glyph X = la s. s(socket)(bind)(listen)(accept)(connect)(send)(recv)(close)(unlink)(poll)
                 (random)(clock_gettime)(print)(read_file)(write_file)(chmod)(stat)(mkdir)
                 (rmdir)(rename)(sigprocmask)
glyph CRYPT = CRYPT_FAST(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(error)
    (add)(sub)(mul)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr)
glyph XK = X25519_KIT(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(error)
    (add)(sub)(mul)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr)
# DISPATCH(mode)(table): run the thunk named mode
glyph DISPATCH = Z(la go. la mode. la l. l(la _. print(concat("unknown mode ")(mode)))
    (la h. la t. h(la name. la f. str_eq(name)(mode)(la _. f("!"))(la _. go(mode)(t))("!"))))
glyph FRAMES = la tk. la net. tk(la len. la ssub. la words. la join. la map. la rev. la app. la count. la rep. la showl. la feed.
  net(la frame. la deframe. la broken.
    (la s. la sched. feed(deframe)(s)(sched)("")(NIL)(la ps. la buf.
       SEQ(write_file("out.bin")(join(map(frame)(ps))))(
       SEQ(print(SP("frames")(SP(int_to_str(count(ps)))(SP("tail")(int_to_str(len(buf)))))))(
       SEQ(print(concat("lens")(showl(map(la p. int_to_str(len(p)))(ps)))))(
       print(SP("chunks")(int_to_str(count(sched)))))))))
    (read_file("stream.bin"))(words(read_file("sched.txt")))))
glyph BROKEN1 = la tk. la net. la name. tk(la len. la ssub. la words. la join. la map. la rev. la app. la count. la rep. la showl. la feed.
  net(la frame. la deframe. la broken.
    deframe("")(read_file(concat(name)(".bin")))(la ps. la buf.
      print(SP(name)(SP(int_to_str(count(ps)))(SP("broken")(SP(BOOL(broken(buf)))(SP("tail")(int_to_str(len(buf)))))))))))
glyph FRAMEBIG = la tk. la net. tk(la len. la ssub. la words. la join. la map. la rev. la app. la count. la rep. la showl. la feed.
  net(la frame. la deframe. la broken.
    SEQ(frame(rep(1048577)("x")))(print("frame_big: no halt"))))
glyph BROKEN = la tk. la net. SEQ(BROKEN1(tk)(net)("brk1"))(SEQ(BROKEN1(tk)(net)("brk2"))(SEQ(BROKEN1(tk)(net)("brk3"))(SEQ(BROKEN1(tk)(net)("brk4"))(BROKEN1(tk)(net)("brk5")))))
glyph MAIN = (la tk. la net. DISPATCH(read_file("mode.txt"))(
    CONS(PR("frames")(la _. FRAMES(tk)(net)))(
    CONS(PR("frame_big")(la _. FRAMEBIG(tk)(net)))(
    CONS(PR("broken")(la _. BROKEN(tk)(net)))(
    NIL)))))
  (TK)(NET_KIT(B)(X)(CRYPT)(XK))
LAEOF

echo "      compiling the test program on the VM ..."
tc0=$(date +%s)
vm_compile t.la t.bin
echo "      (compiled in $(( $(date +%s) - tc0 )) s)"

# ── 1. frames ──────────────────────────────────────────────────────────
( cd "$T" && python3 oracle.py frames "$RANDOM" > frames.exp )
vm_run t.bin frames "$T/frames.out"
( cd "$T" && python3 oracle.py framescheck > frames.same )
check "$([ "$vrc" = 0 ] && cmp -s "$T/frames.exp" "$T/frames.out" && [ "$(cat "$T/frames.same")" = same ] && echo 1)" \
    "frames round-trip: $(grep -c . "$T/frames.exp" >/dev/null; head -1 "$T/frames.exp" | cut -d' ' -f2) payloads (0 B to 1 MiB) cut into $(sed -n 3p "$T/frames.exp" | cut -d' ' -f2) chunks, re-framed byte for byte as Python frames them" \
    "rc $vrc; $(diff "$T/frames.exp" "$T/frames.out" | head -c 300); re-frame: $(cat "$T/frames.same")"
vm_run t.bin frame_big "$T/fbig.out"
check "$([ "$vrc" = 1 ] && [ ! -s "$T/fbig.out" ] && grep -q '^logosnet: frame: payload longer than 1 MiB' "$T/vre" && echo 1)" \
    "frame halts on a payload of 1 MiB + 1 byte (rc $vrc: $(head -c 80 "$T/vre"))"
( cd "$T" && python3 oracle.py broken > broken.exp )
vm_run t.bin broken "$T/broken.out"
check "$([ "$vrc" = 0 ] && cmp -s "$T/broken.exp" "$T/broken.out" && echo 1)" \
    "deframe: a declared length above 1 MiB is broken (and its payload never released, even when complete), after the frames before it; exactly 1 MiB still pending is not" \
    "rc $vrc; $(diff "$T/broken.exp" "$T/broken.out" | head -c 300)"

echo "      (gate ran $(( $(date +%s) - G0 )) s)"
if [ "$ok" = 1 ]; then echo "PASS  logosnet: all checks"; exit 0; else echo "FAIL  logosnet: some checks failed"; exit 1; fi
