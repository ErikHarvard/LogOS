#!/usr/bin/env bash
# gate_logospkg.sh — LogosPkg (logospkg.la, Citrinitas layer 12) on the native VM.
#
# WHAT IT GUARDS. Every operation of PKG_KIT and the failure paths the
# contract (OS_LAYERS_DESIGN.md, "logospkg.la") lists, against an independent
# Python oracle (pkg_oracle.py, written below): the archive bytes pack must
# produce, sha256 ids, the HMAC index signature, and a sha256 snapshot of
# whole directory trees before and after every refused operation.
#    pack       byte-identical to the format, for every package the gate makes
#    unpack     a binary-safe round trip (NUL, 0x80..0xff, an embedded
#               "\nend\n", an empty file) and 22 malformed archives refused
#    publish    ids = hashlib sha256, index lines, index.sig = HMAC; a
#               duplicate, a malformed archive and a tampered index refused,
#               with the repository untouched
#    install    dependencies first in topological order (shown by the log the
#               self-tests themselves append to, on a diamond), every file
#               byte-identical, the NEWEST version by dotted-decimal order
#               (published 1.9, 1.10, 1.2); and REFUSED, with the installation
#               tree unchanged, for: self-test output one byte off (after its
#               dependency's test passed, so the dependency is not installed
#               either; and again on an EMPTY installation, which stays
#               empty), output longer than .expected, output shorter, a test
#               that does not compile, a test that exits 3,
#               a dependency cycle (and, on update, one that closes through
#               an installed package), a missing dependency, a file clash, a
#               tampered archive (id mismatch), a signed index entry naming
#               another package's archive, a tampered index, a tampered or
#               missing signature, a wrong key, an interrupted earlier
#               install, a relative vm path, a missing compiler, a package
#               already installed
#    remove     refused while needed; then each package and finally both
#               versions of alpha removed
#    advise     reports alpha 1.0 -> 1.1 and changes nothing
#    update     installs 1.1 (its self-test runs), keeps 1.0; a package then
#               installed sees the CURRENT alpha beside its test; rr 1.0 ->
#               1.1 -> 1.2; refused, unchanged, when an index line was added
#               without re-signing (an attacker's genuine-looking rr 9.0)
#    rollback   back to 1.0; none earlier is an error; update rolls forward;
#               with three versions, 1.2 -> 1.1 -> 1.0 (the previous, not
#               the lowest), then update rolls forward to 1.2
#    list       the installed packages with their current versions and ids
#  SELF-APPLICATION. logospkg.la itself is packaged (1.0 = the module under
#  test, 1.1 one comment newer, 1.2 with a real bug: unpack accepts trailing
#  bytes) and installed by logospkg; then a program that imports ONLY the
#  installed copy (compiled where no other logospkg.la exists) advises and
#  updates it to 1.1, and the 1.1 copy refuses 1.2 because 1.2's own self-test
#  fails. Every self-test is compiled and run on the VM in a child process.
#
# CRYPTOGRAPHY. PKG_KIT takes the crypt record as a parameter. CRYPT_REF in
# this driver took 198 s for ONE sha256 of a 491-byte archive (it names its
# builtins on every step, each a walk of the whole program) and cannot hash
# logospkg.la's own 40 KB archive, so the gate hands PKG_KIT gate_lincrypt.la:
# the same contract, kit style, checked here against hashlib/hmac first.
#
# ISOLATION: private temp dir (gate_wm_common.sh). VM only. A few minutes.
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1
wm_setup logospkg.la

cat > "$T/gate_lincrypt.la" <<'LAEOF'
# gate_lincrypt.la — written by gate_logospkg.sh; not a repository module.
# The crypt record the gate hands PKG_KIT: the contract of crypt_ref.la
# (la s. s(sha256)(hmac)(hkdf)(seal)(open)(hex), raw-byte outputs), with sha256
# and hmac in kit style and linear in the message. CRYPT_REF is correct but
# names its builtins on every step, and in a program that also holds
# logospkg.la the VM resolves each name by walking the whole program: one
# sha256 of a 491-byte archive took 198 s there, and it re-walks the remaining
# message with str_tail, so logospkg.la's own 40 KB archive would not finish.
# hkdf, seal and open halt loudly: the package manager never calls them. The
# gate checks this record against hashlib/hmac (the SHA-256 padding
# boundaries, a key longer than a block) and every id and signature it
# produces against Python. CRYPT_FAST (logoscrypt.la) is the drop-in for it.
export LIN_CRYPT

glyph Z   = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph LET = la v. la k. k(v)

glyph LIN_CRYPT = la concat. la str_len. la str_at. la ord. la chr. la str_to_int. la int_to_str.
    la add. la sub. la mul. la mod. la lt. la band. la bor. la bxor. la bshl. la bshr. la bnot. la error.
  (la C0. la C1. la C2. la C3. la C4. la C6. la C7. la C8. la C9. la C10. la C11. la C13. la C14. la C15.
      la C16. la C17. la C18. la C19. la C21. la C22. la C24. la C25. la C26. la C30. la C32.
      la C40. la C48. la C54. la C55. la C56. la C64. la C92. la C255. la M.
  LET(la n. la c. n(n))(la nil.
  LET(la h. la t. la n. la c. c(h)(t))(la cons.
  LET(Z(la app. la a. la b. a(la _. b)(la h. la t. cons(h)(app(t)(b)))))(la append.
  LET(Z(la nth. la l. la i. l(la _. C0)(la h. la t. lt(C0)(i)(la _. nth(t)(sub(i)(C1)))(la _. h)(""))))(la nth.
  LET(Z(la pairs. la l. l(la _. nil)(la h. la t.
      t(la _. cons(h)(nil))(la h2. la t2. cons(concat(h)(h2))(pairs(t2))))))(la pairs.
  LET(Z(la cat. la l. l(la _. "")(la h. la t. t(la _. h)(la h2. la t2. cat(pairs(l))))))(la cat.
  LET(la s. str_to_int(str_len(s)))(la len.
  LET(la d. la i. str_to_int(ord(str_at(d)(i))))(la byte.
  LET(la n. chr(int_to_str(n)))(la chrn.
  LET(la a. la b. band(add(a)(b))(M))(la a32.
  LET(la x. la n. la m. bor(bshr(x)(n))(band(bshl(x)(m))(M)))(la rotr.
  LET(la x. bxor(bxor(rotr(x)(C2)(C30))(rotr(x)(C13)(C19)))(rotr(x)(C22)(C10)))(la S0.
  LET(la x. bxor(bxor(rotr(x)(C6)(C26))(rotr(x)(C11)(C21)))(rotr(x)(C25)(C7)))(la S1.
  LET(la x. bxor(bxor(rotr(x)(C7)(C25))(rotr(x)(C18)(C14)))(bshr(x)(C3)))(la s0.
  LET(la x. bxor(bxor(rotr(x)(C17)(C15))(rotr(x)(C19)(C13)))(bshr(x)(C10)))(la s1.
  LET(la d. la i. bor(bor(bshl(byte(d)(i))(C24))(bshl(byte(d)(add(i)(C1)))(C16)))
                     (bor(bshl(byte(d)(add(i)(C2)))(C8))(byte(d)(add(i)(C3)))))(la word.
  LET(Z(la go. la d. la i. la e. lt(i)(e)(la _. cons(word(d)(i))(go(d)(add(i)(C4))(e)))(la _. nil)("")))(la words.
  # ext(win)(k): the next k schedule words after the window win (16 words, oldest first)
  LET(Z(la ext. la win. la k. lt(C0)(k)
      (la _. (la w. cons(w)(win(la _. nil)(la h. la t. ext(append(t)(cons(w)(nil)))(sub(k)(C1)))))
             (a32(a32(s1(nth(win)(C14)))(nth(win)(C9)))(a32(s0(nth(win)(C1)))(nth(win)(C0)))))
      (la _. nil)("")))(la ext.
  LET(Z(la rounds. la ks. la ws. la a. la b. la c. la d. la e. la f. la g. la h.
      ws(la _. la k. k(a)(b)(c)(d)(e)(f)(g)(h))(la w. la wt. ks(la _. la k. k(a)(b)(c)(d)(e)(f)(g)(h))(la kk. la kt.
        (la t1. (la t2. rounds(kt)(wt)(a32(t1)(t2))(a)(b)(c)(a32(d)(t1))(e)(f)(g))
           (a32(S0(a))(bxor(bxor(band(a)(b))(band(a)(c)))(band(b)(c)))))
        (band(add(add(add(h)(S1(e)))(bxor(band(e)(f))(band(bnot(e))(g))))(add(kk)(w)))(M))))))(la rounds.
  LET(cons(1116352408)(cons(1899447441)(cons(3049323471)(cons(3921009573)(cons(961987163)(cons(1508970993)(cons(2453635748)(cons(2870763221)
     (cons(3624381080)(cons(310598401)(cons(607225278)(cons(1426881987)(cons(1925078388)(cons(2162078206)(cons(2614888103)(cons(3248222580)
     (cons(3835390401)(cons(4022224774)(cons(264347078)(cons(604807628)(cons(770255983)(cons(1249150122)(cons(1555081692)(cons(1996064986)
     (cons(2554220882)(cons(2821834349)(cons(2952996808)(cons(3210313671)(cons(3336571891)(cons(3584528711)(cons(113926993)(cons(338241895)
     (cons(666307205)(cons(773529912)(cons(1294757372)(cons(1396182291)(cons(1695183700)(cons(1986661051)(cons(2177026350)(cons(2456956037)
     (cons(2730485921)(cons(2820302411)(cons(3259730800)(cons(3345764771)(cons(3516065817)(cons(3600352804)(cons(4094571909)(cons(275423344)
     (cons(430227734)(cons(506948616)(cons(659060556)(cons(883997877)(cons(958139571)(cons(1322822218)(cons(1537002063)(cons(1747873779)
     (cons(1955562222)(cons(2024104815)(cons(2227730452)(cons(2361852424)(cons(2428436474)(cons(2756734187)(cons(3204031479)(cons(3329325298)
     (nil)))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))(la KL.
  LET(la H. la d. la o. H(la h0. la h1. la h2. la h3. la h4. la h5. la h6. la h7.
      (la w16. rounds(KL)(append(w16)(ext(w16)(C48)))(h0)(h1)(h2)(h3)(h4)(h5)(h6)(h7)
         (la a. la b. la c. la dd. la e. la f. la g. la h. la k.
            k(a32(h0)(a))(a32(h1)(b))(a32(h2)(c))(a32(h3)(dd))(a32(h4)(e))(a32(h5)(f))(a32(h6)(g))(a32(h7)(h))))
      (words(d)(o)(add(o)(C64)))))(la block.
  LET(Z(la blocks. la H. la d. la o. la n. lt(o)(n)(la _. blocks(block(H)(d)(o))(d)(add(o)(C64))(n))(la _. H)("")))(la blocks.
  LET(Z(la zs. la k. lt(C0)(k)(la _. concat(chrn(C0))(zs(sub(k)(C1))))(la _. "")("")))(la zeros.
  LET(la L. cat(cons(chrn(band(bshr(L)(C56))(C255)))(cons(chrn(band(bshr(L)(C48))(C255)))
      (cons(chrn(band(bshr(L)(C40))(C255)))(cons(chrn(band(bshr(L)(C32))(C255)))(cons(chrn(band(bshr(L)(C24))(C255)))
      (cons(chrn(band(bshr(L)(C16))(C255)))(cons(chrn(band(bshr(L)(C8))(C255)))
      (cons(chrn(band(L)(C255)))(nil))))))))))(la be64.
  LET(la w. cat(cons(chrn(band(bshr(w)(C24))(C255)))(cons(chrn(band(bshr(w)(C16))(C255)))
      (cons(chrn(band(bshr(w)(C8))(C255)))(cons(chrn(band(w)(C255)))(nil))))))(la be32.
  LET(la m. (la n. cat(cons(m)(cons(chrn(128))(cons(zeros(mod(add(sub(C55)(mod(n)(C64)))(C64))(C64)))
      (cons(be64(mul(n)(C8)))(nil))))))(len(m)))(la pad.
  LET(la m. (la d. blocks(la k. k(1779033703)(3144134277)(1013904242)(2773480762)(1359893119)(2600822924)(528734635)(1541459225))
                      (d)(C0)(len(d))
         (la a. la b. la c. la dd. la e. la f. la g. la h.
            cat(cons(be32(a))(cons(be32(b))(cons(be32(c))(cons(be32(dd))(cons(be32(e))(cons(be32(f))(cons(be32(g))(cons(be32(h))(nil)))))))))))
     (pad(m)))(la sha256.
  LET(Z(la go. la s. la i. la n. lt(i)(n)(la _. (la b. cons(str_at("0123456789abcdef")(bshr(b)(C4)))(cons(str_at("0123456789abcdef")(band(b)(C15)))(go(s)(add(i)(C1))(n))))(byte(s)(i)))(la _. nil)("")))(la hexl.
  LET(la s. cat(hexl(s)(C0)(len(s))))(la hex.
  LET(Z(la go. la k. la c. la i. lt(i)(C64)(la _. cons(chrn(bxor(lt(i)(len(k))(la _. byte(k)(i))(la _. C0)(""))(c)))(go(k)(c)(add(i)(C1))))(la _. nil)("")))(la xpad.
  LET(la key. la msg. (la k. sha256(concat(cat(xpad(k)(C92)(C0)))(sha256(concat(cat(xpad(k)(C54)(C0)))(msg)))))
      (lt(C64)(len(key))(la _. sha256(key))(la _. key)("")))(la hmac.
    la s. s(sha256)(hmac)(la a. la b. la c. la d. error("gate crypt: no hkdf"))
           (la a. la b. la c. la d. error("gate crypt: no seal"))(la a. la b. la c. la d. error("gate crypt: no open"))(hex)
  )))))))))))))))))))))))))))))))
  )(0)(1)(2)(3)(4)(6)(7)(8)(9)(10)(11)(13)(14)(15)(16)(17)(18)(19)(21)(22)(24)(25)(26)(30)(32)
   (40)(48)(54)(55)(56)(64)(92)(255)(4294967295)
LAEOF

cat > "$T/pkgdrv.la" <<'LAEOF'
# pkgdrv.la — written by gate_logospkg.sh: runs ONE logospkg operation, named
# in step.txt ("<cfg> <op> <args...>"), and prints its result: "ok ..." or
# "err <message>". The VM and compiler.bin paths come from <cfg>.txt.
import("logospkg.la")
import("gate_lincrypt.la")

glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph NIL = la n. la c. n(n)
glyph CONS = la h. la t. la n. la c. c(h)(t)
glyph SEQ = la a. la b. b
glyph LEN = la s. str_to_int(str_len(s))
# SPLITAT(c)(s): the non-empty pieces of s between the bytes c
glyph SPLITGO = Z(la go. la c. la s. la n. la i. la acc.
    int_eq(i)(n)
      (la _. str_eq(acc)("")(la _. NIL)(la _. CONS(acc)(NIL))("!"))
      (la _. (la ch. str_eq(ch)(c)
          (la _. str_eq(acc)("")(la _. go(c)(s)(n)(add(i)(1))(""))(la _. CONS(acc)(go(c)(s)(n)(add(i)(1))("")))("!"))
          (la _. go(c)(s)(n)(add(i)(1))(concat(acc)(ch)))("!"))(str_at(s)(i)))("!"))
glyph SPLITAT = la c. la s. SPLITGO(c)(s)(LEN(s))(0)("")
glyph WORDS = la s. SPLITAT(" ")(SPLITAT("\n")(s)(la _. "")(la h. la t. h))
glyph NTH = Z(la nth. la l. la i. l(la _. "")(la h. la t. int_eq(i)(0)(la _. h)(la _. nth(t)(sub(i)(1)))("!")))
glyph DROPL = Z(la d. la l. la i. int_eq(i)(0)(la _. l)(la _. l(la _. NIL)(la h. la t. d(t)(sub(i)(1))))("!"))
glyph MAPL = Z(la map. la f. la l. l(la _. NIL)(la h. la t. CONS(f(h))(map(f)(t))))
glyph JOIN = Z(la j. la sep. la l. l(la _. "")(la h. la t. t(la _. h)(la h2. la t2. concat(h)(concat(sep)(j(sep)(t))))))
glyph EACHL = Z(la e. la f. la l. l(la _. "")(la h. la t. SEQ(f(h))(e(f)(t))))
glyph FILE = la n. la b. la k. k(n)(b)
glyph SHOWR = la r. r(la m. print(concat("err ")(m)))(la v. print(concat("ok ")(v)))

glyph LIN = LIN_CRYPT(concat)(str_len)(str_at)(ord)(chr)(str_to_int)(int_to_str)(add)(sub)(mul)(mod)(lt)
                     (band)(bor)(bxor)(bshl)(bshr)(bnot)(error)
glyph CFG = la f. (la w. la s. s(NTH(w)(0))(NTH(w)(1)))(WORDS(read_file(concat(f)(".txt"))))
glyph KIT = la crypt. la cfg. PKG_KIT(concat)(str_len)(str_at)(str_eq)(ord)(str_to_int)(int_to_str)
             (add)(sub)(div)(lt)(int_eq)(band)(bor)(bxor)
             (read_file)(stat)(mkdir)(rmdir)(rename)(unlink)(open)(write)
             (close)(fork)(dup2)(execv)(waitpid)(exit)(error)
             (crypt)(cfg)

glyph RUN = la w. la crypt. crypt(la sha256. la hmac. la hkdf. la seal. la open. la hex.
  KIT(crypt)(CFG(NTH(w)(0)))(la pack. la unpack. la publish. la install. la remove. la advise. la update. la rollback. la list.
  (la op. la a1. la a2. la a3. la a4.
    str_eq(op)("pack")(la _.
        (la deps. (la arc. SEQ(write_file(a1)(arc))(print(concat("ok ")(str_len(arc)))))
           (pack(a3)(a4)(deps)(NTH(w)(7))(MAPL(la f. FILE(f)(read_file(concat(a2)(concat("/")(f)))))(DROPL(w)(8)))))
        (str_eq(NTH(w)(6))("-")(la _. NIL)(la _. SPLITAT(",")(NTH(w)(6)))("!")))
    (la _. str_eq(op)("unpack")(la _.
        unpack(read_file(a1))(la m. print(concat("err ")(m)))(la r. r(la n. la v. la d. la t. la f.
          SEQ(EACHL(la x. x(la fn. la fb. write_file(concat(a2)(concat("/")(fn)))(fb)))(f))
             (print(concat("ok name=")(concat(n)(concat(" version=")(concat(v)(concat(" deps=")(concat(JOIN(",")(d))
               (concat(" test=")(concat(t)(concat(" files=")(JOIN(",")(MAPL(la x. x(la fn. la fb. concat(fn)(concat(":")(str_len(fb)))))(f))))))))))))))))
    (la _. str_eq(op)("publish")(la _. SHOWR(publish(a1)(read_file(a2))(read_file(a3))))
    (la _. str_eq(op)("install")(la _. SHOWR(install(a1)(a2)(read_file(a3))(a4)(la m. la e. la o. e(m))(la l. la e. la o. o(JOIN(",")(l)))))
    (la _. str_eq(op)("update")(la _. SHOWR(update(a1)(a2)(read_file(a3))(a4)(la m. la e. la o. e(m))(la l. la e. la o. o(JOIN(",")(l)))))
    (la _. str_eq(op)("remove")(la _. SHOWR(remove(a1)(a2)))
    (la _. str_eq(op)("rollback")(la _. SHOWR(rollback(a1)(a2)))
    (la _. str_eq(op)("advise")(la _. SHOWR(advise(a1)(a2)(read_file(a3))(la m. la e. la o. e(m))
            (la l. la e. la o. o(JOIN(";")(MAPL(la x. x(la n. la i. la v. concat(n)(concat(" ")(concat(i)(concat(" ")(v))))))(l))))))
    (la _. str_eq(op)("list")(la _. print(concat("ok ")(JOIN(";")(MAPL(la x. x(la n. la v. la i. concat(n)(concat(" ")(concat(v)(concat(" ")(i))))))(list(a1))))))
    (la _. str_eq(op)("sha")(la _. EACHL(la f. print(hex(sha256(read_file(f)))))(DROPL(w)(2)))
    (la _. str_eq(op)("unpackall")(la _. EACHL(la f. unpack(read_file(f))
                 (la m. print(concat(f)(concat(": err ")(m))))(la r. print(concat(f)(": ok"))))(DROPL(w)(2)))
    (la _. str_eq(op)("hmac")(la _. print(concat("ok ")(hex(hmac(read_file(a1))(read_file(a2))))))
    (la _. print(concat("err unknown step ")(op)))
    ("!"))("!"))("!"))("!"))("!"))("!"))("!"))("!"))("!"))("!"))("!"))("!"))
  (NTH(w)(1))(NTH(w)(2))(NTH(w)(3))(NTH(w)(4))(NTH(w)(5))))

glyph MAIN = (la w. RUN(w)(LIN))(WORDS(read_file("step.txt")))
LAEOF

cat > "$T/pkg_oracle.py" <<'PYEOF'
"""pkg_oracle.py — written by gate_logospkg.sh. The gate's independent side:
it writes the test packages, builds the archives the format says pack must
produce, makes malformed archives, and computes sha256 / HMAC with hashlib.

  gen DIR MODULE              the test package sources under DIR/src/<name>-<ver>/
  arc OUT SRCDIR NAME VER DEPS TEST FILE...   the expected archive (DEPS '-' = none)
  bad GOOD OUTDIR             malformed variants of GOOD, one file each; prints names
  sha FILE...                 hex sha256, one per line
  hmac KEY FILE               hex HMAC-SHA256
  snap DIR                    every path under DIR with its type, size and sha256
  flip FILE OFFSET            flip the low bit of byte OFFSET (negative: from the end)
  index REPO NAME VER ...     the index lines expected for these archives (file REPO/../arc/NAME-VER)
"""
import hashlib, hmac, os, sys

def W(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "wb").write(data if isinstance(data, bytes) else data.encode())

def archive(name, ver, deps, test, files):
    out = [b"logospkg1\n", b"name=" + name.encode() + b"\n", b"version=" + ver.encode() + b"\n",
           b"deps=" + ",".join(deps).encode() + b"\n", b"test=" + test.encode() + b"\n"]
    for fn, data in files:
        out.append(b"file %s %d\n" % (fn.encode(), len(data)) + data + b"\n")
    out.append(b"end\n")
    return b"".join(out)

def gen(D, module):
    D = os.path.abspath(D)
    LOG = os.path.join(D, "testlog")
    log = ('glyph LOG = la s. (la fd. (la w. close(fd))(write(fd)(s)))(open("%s")("1089"))\n' % LOG
           + 'glyph SEQ = la a. la b. b\n')
    def pkg(name, ver, files):
        for fn, data in files.items():
            W(os.path.join(D, "src", "%s-%s" % (name, ver), fn), data)
    def simple(name, ver, out, expected=None, extra=None, imports="", main=None):
        m = main or 'glyph MAIN = SEQ(LOG("%s %s\\n"))(print("%s"))\n' % (name, ver, out)
        files = {name + "_test.la": imports + log + m,
                 name + "_test.la.expected": expected if expected is not None else out + "\n"}
        files.update(extra or {})
        pkg(name, ver, files)
    for ver in ("1.0", "1.1"):
        simple("alpha", ver, None, expected="alpha says alpha-%s\n" % ver, imports='import("alpha.la")\n',
               main='glyph MAIN = SEQ(LOG("alpha %s\\n"))(print(concat("alpha says ")(ALPHA)))\n' % ver,
               extra={"alpha.la": 'export ALPHA\nglyph ALPHA = "alpha-%s"\n' % ver})
    simple("beta", "1.0", None, expected="beta says beta+alpha-1.0\n", imports='import("beta.la")\n',
           main='glyph MAIN = SEQ(LOG("beta 1.0\\n"))(print(concat("beta says ")(BETA)))\n',
           extra={"beta.la": 'import("alpha.la")\nexport BETA\nglyph BETA = concat("beta+")(ALPHA)\n'})
    blob = b"\x00\x01\xff\x80\nend\nfile x 3\nabc\n\x00" + bytes(range(256)) + b"\n"
    simple("gamma", "1.0", None, expected="gamma says gamma+beta+alpha-1.0 blob %d\n" % len(blob),
           imports='import("gamma.la")\n',
           main='glyph MAIN = SEQ(LOG("gamma 1.0\\n"))(print(concat("gamma says ")(concat(GAMMA)'
                '(concat(" blob ")(str_len(read_file("blob.bin")))))))\n',
           extra={"gamma.la": 'import("beta.la")\nexport GAMMA\nglyph GAMMA = concat("gamma+")(BETA)\n',
                  "blob.bin": blob, "empty.txt": b""})
    # epsilon is installed after alpha's update: its test sees the CURRENT alpha
    simple("epsilon", "1.0", None, expected="epsilon sees gamma+beta+alpha-1.1\n", imports='import("gamma.la")\n',
           main='glyph MAIN = SEQ(LOG("epsilon 1.0\\n"))(print(concat("epsilon sees ")(GAMMA)))\n')
    simple("okdep", "1.0", "okdep fine", extra={"okdep.la": 'export OK\nglyph OK = "ok"\n'})
    simple("bad", "1.0", "bad output", expected="bad outpuT\n")          # one byte differs
    pkg("nocompile", "1.0", {"nocompile_test.la": 'glyph MAIN = print("x"\n', "nocompile_test.la.expected": "x\n"})
    simple("exit3", "1.0", "three", main='glyph MAIN = SEQ(LOG("exit3 1.0\\n"))(SEQ(print("three"))(exit("3")))\n')
    simple("clash", "1.0", "c", extra={"alpha.la": 'export ALPHA\nglyph ALPHA = "not alpha"\n'})
    for n in ("cyca", "cycb", "orphan", "delta"):
        simple(n, "1.0", n)
    # output longer / shorter than .expected (both refused: equality, not a prefix match)
    simple("long", "1.0", None, expected="hi\n",
           main='glyph MAIN = SEQ(LOG("long 1.0\\n"))(SEQ(print("hi"))(print("EXTRA")))\n')
    simple("short", "1.0", "hi", expected="hi\nmore\n")
    # versions published out of order (1.9, 1.10, 1.2), and four versions of rr
    # (9.0 is an attacker's, planted with an unsigned index line)
    for ver in ("1.9", "1.10", "1.2"):
        simple("vv", ver, "vv " + ver)
    for ver in ("1.0", "1.1", "1.2"):
        simple("rr", ver, "rr " + ver)
    simple("rr", "9.0", "rr 9.0", extra={"evil.txt": "attacker\n"})
    # upa 1.1 needs upb, and the INSTALLED upb 1.0 needs upa: updating upa would close a cycle
    simple("upa", "1.0", "upa 1.0"); simple("upb", "1.0", "upb"); simple("upa", "1.1", "upa 1.1")
    # the package manager as a package
    src = open(module, "rb").read()
    test = r'''import("logospkg.la")
glyph NIL = la n. la c. n(n)
glyph CONS = la h. la t. la n. la c. c(h)(t)
glyph F = la n. la b. la k. k(n)(b)
glyph SEQ = la a. la b. b
glyph MAPL = la f. la l. l(la _. NIL)(la h. la t. CONS(f(h))(MAPL(f)(t)))
glyph JOIN = la l. l(la _. "")(la h. la t. concat(h)(concat(" ")(JOIN(t))))
glyph NOCRYPT = la s. s(la m. error("no sha256"))(la k. la m. error("no hmac"))
    (la a. la b. la c. la d. error("no hkdf"))(la a. la b. la c. la d. error("no seal"))
    (la a. la b. la c. la d. error("no open"))(la r. error("no hex"))
glyph MAIN = PKG_KIT(concat)(str_len)(str_at)(str_eq)(ord)(str_to_int)(int_to_str)
             (add)(sub)(div)(lt)(int_eq)(band)(bor)(bxor)
             (read_file)(stat)(mkdir)(rmdir)(rename)(unlink)(open)(write)
             (close)(fork)(dup2)(execv)(waitpid)(exit)(error)
             (NOCRYPT)(la s. s("/nonexistent/vm")("/nonexistent/compiler.bin"))
  (la pack. la unpack. la publish. la install. la remove. la advise. la update. la rollback. la list.
    (la a. SEQ(print(str_len(a)))
      (SEQ(unpack(a)(la m. print(concat("err ")(m)))(la r. r(la n. la v. la d. la t. la f.
             print(concat(n)(concat(" ")(concat(v)(concat(" ")(concat(JOIN(d))(concat(t)(concat(" ")
               (JOIN(MAPL(la x. x(la fn. la fb. concat(fn)(concat(":")(str_len(fb)))))(f)))))))))))))
      (SEQ(unpack(concat(a)("x"))(la m. print(concat("refused: ")(m)))(la r. print("ACCEPTED")))
          (install("/nonexistent-inst")("/nonexistent-repo")("key")("demo")
             (la m. print(concat("refused: ")(m)))(la l. print("INSTALLED"))))))
    (pack("demo")("2.10")(CONS("base")(NIL))("t.la")
       (CONS(F("t.la")("glyph MAIN = print(\"hi\")\n"))(CONS(F("t.la.expected")("hi\n"))(NIL)))))
'''
    demo = archive("demo", "2.10", ["base"], "t.la",
                   [("t.la", b'glyph MAIN = print("hi")\n'), ("t.la.expected", b"hi\n")])
    exp = ("%d\ndemo 2.10 base t.la t.la:25 t.la.expected:3 \nrefused: unpack: bytes after end\n"
           "refused: /nonexistent-inst is not a directory\n" % len(demo))
    broken = src.replace(b"(la _. int_eq(add(i)(C4))(n)(la _. ok(rev(acc)))", b"(la _. TT(la _. ok(rev(acc)))")
    assert broken != src, "the 1.2 mutation did not apply"
    for ver, body in (("1.0", src), ("1.1", src + b"# logospkg 1.1: the same module, one comment newer\n"),
                      ("1.2", broken)):
        pkg("logospkg", ver, {"logospkg.la": body, "logospkg_test.la": test, "logospkg_test.la.expected": exp})
    W(os.path.join(D, "key.bin"), bytes((i * 7 + 3) % 256 for i in range(32)))
    W(os.path.join(D, "badkey.bin"), bytes((i * 7 + 4) % 256 for i in range(32)))
    W(os.path.join(D, "k100.bin"), bytes(range(100)))
    import random
    r = random.Random(7)
    for n in (0, 1, 55, 56, 63, 64, 65, 119, 120, 1000):
        W(os.path.join(D, "m", "%d.bin" % n), bytes(r.randrange(256) for _ in range(n)))

def bad(good, outdir):
    g = open(good, "rb").read()
    def rep(old, new, count=1):
        assert old in g, old
        return g.replace(old, new, count)
    first = g.index(b"\nfile ") + 1
    line_end = g.index(b"\n", first)
    fname, flen = g[first + 5:line_end].split(b" ")
    v = {
        "empty": b"",
        "magic": rep(b"logospkg1\n", b"logospkg2\n"),
        "truncated": g[:-5],
        "trailing": g + b"x",
        "nolastnl": g[:-1],
        "toolong": g[:first] + b"file %s %d\n" % (fname, int(flen) + 1000) + g[line_end + 1:],
        "shortlen": g[:first] + b"file %s %d\n" % (fname, int(flen) - 1) + g[line_end + 1:],
        "zerolead": g[:first] + b"file %s 0%s\n" % (fname, flen) + g[line_end + 1:],
        "nondigit": g[:first] + b"file %s %sx\n" % (fname, flen) + g[line_end + 1:],
        "badname": rep(b"name=gamma\n", b"name=../gamma\n"),
        "dotname": rep(b"name=gamma\n", b"name=.gamma\n"),
        "badfile": g[:first] + b"file ../%s %s\n" % (fname, flen) + g[line_end + 1:],
        "hiddenfile": g[:first] + b"file .%s %s\n" % (fname, flen) + g[line_end + 1:],
        "reserved": g[:first] + b"file logos_source.la %s\n" % flen + g[line_end + 1:],
        "badver": rep(b"version=1.0\n", b"version=1.01\n"),
        "emptyver": rep(b"version=1.0\n", b"version=1..0\n"),
        "dupdep": rep(b"deps=beta,alpha\n", b"deps=beta,beta\n"),
        "emptydep": rep(b"deps=beta,alpha\n", b"deps=beta,,alpha\n"),
        "notest": rep(b"test=gamma_test.la\n", b"test=nosuch.la\n"),
        "noexpected": rep(b"file gamma_test.la.expected ", b"file gamma_test.la.expectet "),
        "dupfile": g[:-4] + g[first:line_end + 1] + g[line_end + 1:line_end + 1 + int(flen)] + b"\nend\n",
        "order": rep(b"name=gamma\nversion=1.0\n", b"version=1.0\nname=gamma\n"),
    }
    os.makedirs(outdir, exist_ok=True)
    for k, data in v.items():
        assert data != g or k == "never"
        open(os.path.join(outdir, k), "wb").write(data)
    print(" ".join(os.path.join(outdir, k) for k in v))

def snap(d):
    rows = []
    for root, dirs, files in os.walk(d):
        for x in dirs:
            rows.append("d %s" % os.path.relpath(os.path.join(root, x), d))
        for x in files:
            p = os.path.join(root, x)
            rows.append("f %s %d %s" % (os.path.relpath(p, d), os.path.getsize(p),
                                        hashlib.sha256(open(p, "rb").read()).hexdigest()))
    print("\n".join(sorted(rows)))

cmd, a = sys.argv[1], sys.argv[2:]
if cmd == "gen":
    gen(a[0], a[1])
elif cmd == "arc":
    out, srcdir, name, ver, deps, test = a[:6]
    files = [(f, open(os.path.join(srcdir, f), "rb").read()) for f in a[6:]]
    open(out, "wb").write(archive(name, ver, [] if deps == "-" else deps.split(","), test, files))
elif cmd == "bad":
    bad(a[0], a[1])
elif cmd == "sha":
    for f in a:
        print(hashlib.sha256(open(f, "rb").read()).hexdigest())
elif cmd == "hmac":
    print(hmac.new(open(a[0], "rb").read(), open(a[1], "rb").read(), hashlib.sha256).hexdigest())
elif cmd == "snap":
    snap(a[0])
elif cmd == "flip":
    p, off = a[0], int(a[1])
    b = bytearray(open(p, "rb").read()); b[off] ^= 1; open(p, "wb").write(bytes(b))
else:
    sys.exit("pkg_oracle: unknown command " + cmd)
PYEOF

O() { python3 "$T/pkg_oracle.py" "$@"; }
pass() { echo "PASS  logospkg: $1"; }
fail() { echo "FAIL  logospkg: $1"; shift; for l in "$@"; do echo "      $l"; done; ok=0; }
# expect NAME WANT: the last step's output must be exactly WANT
expect() { if [ "$R" = "$2" ]; then pass "$1"; else fail "$1" "want: $2" "got:  $R" "$(tail -2 "$T/err.txt")"; fi; }
# st DIR WORDS...: run one driver step (compiled program DIR/pkgdrv.bin) in DIR; R = its stdout
st() {
    local d=$1; shift
    echo "$*" > "$d/step.txt"; cp "$d/pkgdrv.bin" "$d/logos_program.bin"
    ( cd "$d" && timeout "$WM_VM_TIMEOUT" ./logos_secd > out.txt 2> err.txt ) || true
    cp "$d/err.txt" "$T/err.txt" 2>/dev/null; R=$(cat "$d/out.txt")
}
s() { st "$T" pkgcfg "$@"; }
now() { date +%s.%N; }
dt() { echo "$1 $2" | awk '{printf "%.1f", $2 - $1}'; }
compile() {   # compile() DIR PROG: compiler.bin compiles PROG in DIR into DIR/pkgdrv.bin
    ( cd "$1" && cp compiler.bin logos_program.bin && cp "$2" logos_source.la \
      && timeout "$WM_VM_TIMEOUT" ./logos_secd > cc.out 2> cc.err ) \
      && cp "$1/logos_program.bin" "$1/pkgdrv.bin"
}
# pk NAME VER DEPS: pack src/NAME-VER (its files in name order) and check it
# against the oracle's archive
pk() {
    local files; files=$(cd "$T/src/$1-$2" && LC_ALL=C ls)
    s pack "arc/$1-$2" "src/$1-$2" "$1" "$2" "$3" "$1_test.la" $files
    O arc "$T/arc/$1-$2.want" "$T/src/$1-$2" "$1" "$2" "$3" "$1_test.la" $files
    if [ "$R" = "ok $(stat -c %s "$T/arc/$1-$2.want")" ] && cmp -s "$T/arc/$1-$2" "$T/arc/$1-$2.want"; then
        packed="$packed $1-$2"
    else
        fail "pack $1 $2: the archive is not the format's bytes" "$R"
    fi
}
snapeq() { if O snap "$2" | cmp -s - "$3"; then pass "$1"; else fail "$1" "$(O snap "$2" | diff "$3" - | head -6)"; fi; }

cd "$T" || exit 1
O gen "$T" "$T/logospkg.la" || { echo "FAIL  logospkg: the oracle could not write the test packages"; exit 1; }
mkdir -p arc inst repo out
echo "$T/logos_secd $T/compiler.bin" > pkgcfg.txt
echo "logos_secd $T/compiler.bin" > pkgcfg_rel.txt
echo "$T/logos_secd $T/nosuch.bin" > pkgcfg_nocomp.txt

t0=$(now)
compile "$T" pkgdrv.la || { echo "FAIL  logospkg: the driver did not compile"; tail -3 "$T/cc.out" "$T/cc.err"; exit 1; }
T_COMPILE=$(dt "$t0" "$(now)")

# ── 0. the gate's crypt record against hashlib / hmac ──────────────────
M="m/0.bin m/1.bin m/55.bin m/56.bin m/63.bin m/64.bin m/65.bin m/119.bin m/120.bin m/1000.bin"
s sha $M; got=$R
want=$(O sha $M)
[ "$got" = "$want" ] && pass "gate crypt: sha256 = hashlib at 0 1 55 56 63 64 65 119 120 1000 bytes" \
                     || fail "gate crypt: sha256 differs from hashlib" "$got"
s hmac key.bin m/1000.bin; a=$R; s hmac k100.bin m/120.bin; b=$R
[ "$a $b" = "ok $(O hmac key.bin m/1000.bin) ok $(O hmac k100.bin m/120.bin)" ] \
    && pass "gate crypt: HMAC = Python hmac (a 32-byte key, and a 100-byte key hashed first)" \
    || fail "gate crypt: HMAC differs" "$a $b"

# ── 1. pack / unpack ───────────────────────────────────────────────────
packed=""
pk alpha 1.0 -; pk alpha 1.1 -; pk beta 1.0 alpha; pk gamma 1.0 beta,alpha; pk epsilon 1.0 gamma
pk okdep 1.0 -; pk bad 1.0 okdep; pk nocompile 1.0 -; pk exit3 1.0 -; pk clash 1.0 alpha
pk cyca 1.0 cycb; pk cycb 1.0 cyca; pk orphan 1.0 nosuch; pk delta 1.0 -
pk long 1.0 -; pk short 1.0 -; pk vv 1.9 -; pk vv 1.10 -; pk vv 1.2 -
pk rr 1.0 -; pk rr 1.1 -; pk rr 1.2 -; pk rr 9.0 -; pk upa 1.0 -; pk upb 1.0 upa; pk upa 1.1 upb
pk logospkg 1.0 -; pk logospkg 1.1 -; pk logospkg 1.2 -
[ "$(echo $packed | wc -w)" = 29 ] && pass "pack: 29 archives, each byte-identical to the format (incl. logospkg.la's own, $(stat -c %s arc/logospkg-1.0) bytes)"
s unpack arc/gamma-1.0 out
expect "unpack: gamma's header fields and file list" \
  "ok name=gamma version=1.0 deps=beta,alpha test=gamma_test.la files=blob.bin:$(stat -c %s src/gamma-1.0/blob.bin),empty.txt:0,gamma.la:$(stat -c %s src/gamma-1.0/gamma.la),gamma_test.la:$(stat -c %s src/gamma-1.0/gamma_test.la),gamma_test.la.expected:$(stat -c %s src/gamma-1.0/gamma_test.la.expected)"
same=1; for f in blob.bin empty.txt gamma.la gamma_test.la gamma_test.la.expected; do cmp -s "out/$f" "src/gamma-1.0/$f" || same=0; done
[ "$same" = 1 ] && pass "unpack: every file byte-identical (NUL, bytes 0x80..0xff, an embedded \"\\nend\\n\", an empty file)" \
                || fail "unpack: a file came back different"
BADS=$(O bad arc/gamma-1.0 badarc)
s unpackall $BADS
nbad=$(echo "$R" | grep -c ": err unpack: "); nall=$(echo $BADS | wc -w)
[ "$nbad" = "$nall" ] && pass "unpack: all $nall malformed archives refused (magic, truncation, trailing bytes, lengths, names, versions, deps, missing test/.expected, duplicates, reserved names, header order)" \
                      || fail "unpack: a malformed archive was accepted" "$(echo "$R" | grep -v ": err unpack: ")"

# ── 2. publish ─────────────────────────────────────────────────────────
pubok=1; : > index.want
for p in alpha-1.0 beta-1.0 gamma-1.0 epsilon-1.0 okdep-1.0 bad-1.0 long-1.0 short-1.0 nocompile-1.0 exit3-1.0 clash-1.0 cyca-1.0 cycb-1.0 orphan-1.0 delta-1.0; do
    s publish repo key.bin "arc/$p"; id=$(O sha "arc/$p")
    [ "$R" = "ok $id" ] && cmp -s "arc/$p" "repo/pkg/$id" || { pubok=0; fail "publish $p" "want: ok $id" "got:  $R"; }
    echo "${p%-*} ${p##*-} $id" >> index.want
done
[ "$pubok" = 1 ] && pass "publish: 15 archives, each id = hashlib sha256 of the archive, stored as pkg/<id>"
cmp -s repo/index index.want && [ "$(cat repo/index.sig)" = "$(O hmac key.bin repo/index)" ] \
    && pass "publish: the index lists every package and index.sig = HMAC(K_repo, index)" \
    || fail "publish: index or signature wrong" "$(diff index.want repo/index | head -3)"
O snap repo > repo.snap
s publish repo key.bin arc/alpha-1.0
expect "publish: the same name and version again is refused" "err alpha 1.0 is already in the repository"
snapeq "publish: ... and the repository is untouched" repo repo.snap
s publish repo3 key.bin badarc/trailing
[ "${R#err unpack:}" != "$R" ] && [ ! -e repo3 ] && pass "publish: a malformed archive is refused and no repository is created" \
                                                  || fail "publish: malformed archive" "$R"

# ── 3. install: order, files, records ──────────────────────────────────
: > testlog
t0=$(now); s install inst repo key.bin gamma; T_INSTALL3=$(dt "$t0" "$(now)")
expect "install gamma: alpha, beta, gamma installed, dependencies first" "ok alpha 1.0,beta 1.0,gamma 1.0"
[ "$(cat testlog)" = "$(printf 'alpha 1.0\nbeta 1.0\ngamma 1.0')" ] \
    && pass "install: the self-tests ran in topological order (their own log: alpha, beta, gamma; gamma -> beta -> alpha and gamma -> alpha)" \
    || fail "install: self-test order" "$(cat testlog)"
files_ok=1
for p in alpha-1.0 beta-1.0 gamma-1.0; do
    n=${p%-*}; v=${p##*-}
    for f in $(cd "src/$p" && ls); do cmp -s "src/$p/$f" "inst/pkgs/$n/$v/$f" || files_ok=0; done
    cmp -s "arc/$p" "inst/pkgs/$n/$v/.archive" || files_ok=0
    [ "$(cat inst/current/$n)" = "$v" ] || files_ok=0
done
[ "$files_ok" = 1 ] && [ ! -e inst/staging ] \
    && pass "install: pkgs/<name>/<version> holds every file byte for byte (and .archive), current/<name> the version, no staging/ left" \
    || fail "install: installed files or current/ wrong"
printf 'alpha 1.0 %s\nbeta 1.0 %s\ngamma 1.0 %s\n' "$(O sha arc/alpha-1.0)" "$(O sha arc/beta-1.0)" "$(O sha arc/gamma-1.0)" > inst.want
cmp -s inst/installed inst.want && pass "install: \`installed\` lists name, version and id" || fail "install: installed file" "$(cat inst/installed)"

# ── 4. install refusals: nothing changes ───────────────────────────────
O snap inst > inst.snap
refuse() {   # refuse LABEL WANT [cfg] WORDS... : the step's output and an unchanged tree
    local label=$1 want=$2; shift 2
    st "$T" "$@"
    if [ "$R" = "$want" ] && O snap inst | cmp -s - inst.snap; then pass "$label"
    else fail "$label" "want: $want" "got:  $R" "$(O snap inst | diff inst.snap - | head -4)"; fi
}
: > testlog
refuse "install refused: self-test output differs by ONE byte; the installation tree is unchanged" \
       "err bad 1.0: self-test output differs from bad_test.la.expected" pkgcfg install inst repo key.bin bad
[ "$(cat testlog)" = "$(printf 'okdep 1.0\nbad 1.0')" ] \
    && pass "install refused: ... although its dependency okdep passed its own test first, okdep is not installed" \
    || fail "install refused: bad's log" "$(cat testlog)"
refuse "install refused: a self-test that prints the expected output and then more" \
       "err long 1.0: self-test output differs from long_test.la.expected" pkgcfg install inst repo key.bin long
refuse "install refused: a self-test that prints only the start of the expected output" \
       "err short 1.0: self-test output differs from short_test.la.expected" pkgcfg install inst repo key.bin short
mkdir inst5
st "$T" pkgcfg install inst5 repo key.bin bad
if [ "$R" = "err bad 1.0: self-test output differs from bad_test.la.expected" ] && [ -z "$(O snap inst5)" ]; then
    pass "install refused on an EMPTY installation: it stays empty (no pkgs/, current/ or installed made before the tests)"
else fail "install refused on an empty installation" "$R" "$(O snap inst5 | head -4)"; fi
: > testlog
refuse "install refused: a self-test that does not compile" \
       "err nocompile 1.0: self-test did not compile (status 1)" pkgcfg install inst repo key.bin nocompile
refuse "install refused: a self-test that prints the right output but exits 3" \
       "err exit3 1.0: self-test exited with status 3" pkgcfg install inst repo key.bin exit3
refuse "install refused: a dependency cycle" "err dependency cycle: cyca -> cycb -> cyca" pkgcfg install inst repo key.bin cyca
refuse "install refused: a missing dependency" "err nosuch: not in the repository" pkgcfg install inst repo key.bin orphan
refuse "install refused: a file that is also a dependency's" \
       "err clash 1.0: a file name is in this package and a dependency" pkgcfg install inst repo key.bin clash
[ "$(cat testlog)" = "exit3 1.0" ] && pass "install refused: only exit3's test ran (no test runs for a cycle, a missing dependency or a clash)" \
                                   || fail "install refused: unexpected self-test runs" "$(cat testlog)"
did=$(O sha arc/delta-1.0); cp "repo/pkg/$did" delta.save; O flip "repo/pkg/$did" -20
refuse "install refused: a tampered archive (one bit; its sha256 is not its id)" \
       "err delta 1.0: the archive does not match its id" pkgcfg install inst repo key.bin delta
cp delta.save "repo/pkg/$did"
cp repo/index index.save; cp repo/index.sig sig.save
sed -i "s/^delta 1.0 .*/delta 1.0 $(O sha arc/okdep-1.0)/" repo/index; O hmac key.bin repo/index | tr -d '\n' > repo/index.sig
refuse "install refused: a correctly signed index entry that points at another package's archive" \
       "err delta 1.0: the archive names a different package" pkgcfg install inst repo key.bin delta
cp index.save repo/index; cp sig.save repo/index.sig
sed -i 's/^okdep 1.0 /okdep 1.2 /' repo/index
refuse "install refused: a tampered index (a version edited, not re-signed)" \
       "err the repository index fails its signature" pkgcfg install inst repo key.bin okdep
O snap repo > repo.snap
s publish repo key.bin arc/alpha-1.1
expect "publish refused: a tampered index is not re-signed" "err the repository index fails its signature"
snapeq "publish refused: ... and the repository is untouched" repo repo.snap
s advise inst repo key.bin
expect "advise refused: a tampered index" "err the repository index fails its signature"
cp index.save repo/index; O flip repo/index.sig 0
refuse "install refused: a tampered index.sig" "err the repository index fails its signature" pkgcfg install inst repo key.bin okdep
cp sig.save repo/index.sig
refuse "install refused: the wrong repository key" "err the repository index fails its signature" pkgcfg install inst repo badkey.bin okdep
rm repo/index.sig
refuse "install refused: no index.sig" "err the repository has no signed index" pkgcfg install inst repo key.bin okdep
cp sig.save repo/index.sig
refuse "install refused: gamma is already installed" "err gamma is already installed (update installs a newer version)" pkgcfg install inst repo key.bin gamma
refuse "install refused: a relative vm path" \
       "err cfg: the vm must be an absolute path to a file (the self-test runs in staging/)" pkgcfg_rel install inst repo key.bin okdep
refuse "install refused: no compiler.bin" "err no compiler at $T/nosuch.bin" pkgcfg_nocomp install inst repo key.bin okdep
mkdir inst/staging; O snap inst > inst.snap
refuse "install refused: staging/ left by an interrupted install" \
       "err inst/staging exists: an earlier install was interrupted" pkgcfg install inst repo key.bin okdep
rmdir inst/staging; O snap inst > inst.snap

# ── 5. list, remove, advise, update, rollback ──────────────────────────
s list inst
expect "list: the installed packages, current version and id" \
  "ok alpha 1.0 $(O sha arc/alpha-1.0);beta 1.0 $(O sha arc/beta-1.0);gamma 1.0 $(O sha arc/gamma-1.0)"
refuse "remove refused: alpha is needed" "err alpha is needed by beta 1.0, gamma 1.0" pkgcfg remove inst alpha
refuse "remove refused: not installed" "err nosuch is not installed" pkgcfg remove inst nosuch
s publish repo key.bin arc/alpha-1.1
[ "$R" = "ok $(O sha arc/alpha-1.1)" ] || fail "publish alpha 1.1" "$R"
O snap repo > repo.snap
refuse "advise: reports alpha 1.0 -> 1.1, and changes nothing" "ok alpha 1.0 1.1" pkgcfg advise inst repo key.bin
snapeq "advise: ... the repository is untouched too" repo repo.snap
: > testlog
s update inst repo key.bin alpha
expect "update alpha: 1.1 installed" "ok alpha 1.1"
[ "$(cat testlog)" = "alpha 1.1" ] && [ "$(cat inst/current/alpha)" = 1.1 ] && cmp -s inst/pkgs/alpha/1.0/alpha.la src/alpha-1.0/alpha.la \
  && cmp -s inst/pkgs/alpha/1.1/alpha.la src/alpha-1.1/alpha.la && [ "$(tail -1 inst/installed)" = "alpha 1.1 $(O sha arc/alpha-1.1)" ] \
    && pass "update: 1.1's self-test ran, current/alpha = 1.1, 1.0 kept in pkgs/, installed lists both" \
    || fail "update: state after the update" "$(cat testlog)" "$(cat inst/installed)"
s publish repo key.bin arc/epsilon-1.0
s install inst repo key.bin epsilon
expect "install epsilon (needs gamma): its self-test sees the CURRENT alpha, 1.1, from the installation" "ok epsilon 1.0"
O snap inst > inst.snap
refuse "advise: nothing newer" "ok " pkgcfg advise inst repo key.bin
refuse "update: already the newest is a no-op" "ok " pkgcfg update inst repo key.bin alpha
s rollback inst alpha
[ "$R" = "ok 1.0" ] && [ "$(cat inst/current/alpha)" = 1.0 ] && pass "rollback: current/alpha back to 1.0" || fail "rollback" "$R"
O snap inst > inst.snap
refuse "rollback refused: no version below 1.0" "err alpha 1.0 has no earlier version installed" pkgcfg rollback inst alpha
: > testlog
s update inst repo key.bin alpha
[ "$R" = "ok alpha 1.1" ] && [ "$(cat inst/current/alpha)" = 1.1 ] && [ ! -s testlog ] \
    && pass "update after rollback: current/ rolls forward to the installed 1.1 (no reinstall)" || fail "roll forward" "$R"
s remove inst epsilon; a=$R; s remove inst gamma; b=$R; s remove inst beta; c=$R
[ "$a $b $c" = "ok epsilon ok gamma ok beta" ] && [ ! -e inst/pkgs/gamma ] && [ ! -e inst/current/gamma ] \
    && pass "remove: epsilon, gamma, beta (each once nothing needs it): pkgs/ and current/ entries gone" || fail "remove" "$a $b $c"
s remove inst alpha
[ "$R" = "ok alpha" ] && [ ! -e inst/pkgs/alpha ] && [ ! -e inst/current/alpha ] && [ ! -s inst/installed ] \
    && pass "remove alpha: both installed versions gone; installed is empty" || fail "remove alpha" "$R"
s list inst
expect "list: empty" "ok "

# ── 5b. version order, a three-version rollback, update's signature check ─
refuse_in() {   # refuse_in INST LABEL WANT [cfg] WORDS...: as refuse, for the installation INST
    local d=$1 label=$2 want=$3; shift 3
    O snap "$d" > "$d.snap"
    st "$T" "$@"
    if [ "$R" = "$want" ] && O snap "$d" | cmp -s - "$d.snap"; then pass "$label"
    else fail "$label" "want: $want" "got:  $R" "$(O snap "$d" | diff "$d.snap" - | head -4)"; fi
}
for v in 1.9 1.10 1.2; do
    s publish repo4 key.bin "arc/vv-$v"; [ "$R" = "ok $(O sha "arc/vv-$v")" ] || fail "publish vv $v" "$R"
done
mkdir inst4
s install inst4 repo4 key.bin vv
expect "install: the newest version by dotted-decimal order (published 1.9, 1.10, 1.2: neither the last line nor the string maximum)" "ok vv 1.10"
s publish repo4 key.bin arc/rr-1.0; s install inst4 repo4 key.bin rr; a=$R
s publish repo4 key.bin arc/rr-1.1; s update inst4 repo4 key.bin rr; b=$R
s publish repo4 key.bin arc/rr-1.2; s update inst4 repo4 key.bin rr; c=$R
[ "$a|$b|$c" = "ok rr 1.0|ok rr 1.1|ok rr 1.2" ] && [ "$(cat inst4/current/rr)" = 1.2 ] \
    && pass "update: rr 1.0 -> 1.1 -> 1.2, all three versions kept in pkgs/" || fail "update rr twice" "$a|$b|$c"
s rollback inst4 rr; a="$R $(cat inst4/current/rr)"; s rollback inst4 rr; b="$R $(cat inst4/current/rr)"
[ "$a|$b" = "ok 1.1 1.1|ok 1.0 1.0" ] && pass "rollback: 1.2 -> 1.1 -> 1.0, each time to the previous version (not the lowest)" \
                                  || fail "rollback with three versions" "$a|$b"
refuse_in inst4 "rollback refused: rr 1.0 has no earlier version" "err rr 1.0 has no earlier version installed" pkgcfg rollback inst4 rr
s update inst4 repo4 key.bin rr
[ "$R" = "ok rr 1.2" ] && [ "$(cat inst4/current/rr)" = 1.2 ] \
    && pass "update after two rollbacks: current/rr rolls forward to the newest, 1.2" || fail "roll forward to 1.2" "$R"
# an attacker plants rr 9.0 (a well-formed archive under its true id) and lists it without re-signing
cp repo4/index repo4.index.save; id9=$(O sha arc/rr-9.0); cp arc/rr-9.0 "repo4/pkg/$id9"; echo "rr 9.0 $id9" >> repo4/index
refuse_in inst4 "update refused: an index line added without re-signing (its archive is well formed and matches its id)" \
       "err the repository index fails its signature" pkgcfg update inst4 repo4 key.bin rr
cp repo4.index.save repo4/index; rm "repo4/pkg/$id9"
# a cycle that closes through an INSTALLED package
s publish repo4 key.bin arc/upa-1.0; s publish repo4 key.bin arc/upb-1.0
mkdir inst3; s install inst3 repo4 key.bin upb
expect "install upb (needs upa): upa 1.0 first" "ok upa 1.0,upb 1.0"
s publish repo4 key.bin arc/upa-1.1
refuse_in inst3 "update refused: upa 1.1 needs upb, whose installed version needs upa (a cycle through an installed package)" \
       "err dependency cycle: upa -> upb -> upa" pkgcfg update inst3 repo4 key.bin upa
s remove inst3 upb; a=$R; s remove inst3 upa; b=$R
[ "$a|$b" = "ok upb|ok upa" ] && pass "remove: ... so both stay removable (upb, then upa)" || fail "remove after the refused update" "$a|$b"

# ── 6. self-application: logospkg installs and updates itself ──────────
mkdir inst2
t0=$(now); s publish repo2 key.bin arc/logospkg-1.0; T_PUB40=$(dt "$t0" "$(now)")
[ "$R" = "ok $(O sha arc/logospkg-1.0)" ] || fail "self: publish logospkg 1.0" "$R"
t0=$(now); s install inst2 repo2 key.bin logospkg; T_SELFINST=$(dt "$t0" "$(now)")
if [ "$R" = "ok logospkg 1.0" ] && cmp -s inst2/pkgs/logospkg/1.0/logospkg.la logospkg.la; then
    pass "self: logospkg.la packaged as logospkg 1.0 and installed by logospkg (its own self-test compiled and run on the VM)"
else fail "self: install logospkg 1.0" "$R" "$(tail -2 err.txt)"; fi
s publish repo2 key.bin arc/logospkg-1.1
[ "$R" = "ok $(O sha arc/logospkg-1.1)" ] || fail "self: publish logospkg 1.1" "$R"
# a program that imports ONLY the installed copy, compiled where no other logospkg.la exists
selfdrv() {
    rm -rf "$T/sa"; mkdir "$T/sa"; cp logos_secd compiler.bin gate_lincrypt.la pkgcfg.txt "$T/sa/"
    sed "s|^import(\"logospkg.la\")|import(\"../inst2/pkgs/logospkg/$1/logospkg.la\")|" pkgdrv.la > "$T/sa/selfdrv.la"
    grep -q "^import(\"../inst2/pkgs/logospkg/$1/logospkg.la\")" "$T/sa/selfdrv.la" && compile "$T/sa" selfdrv.la
}
t0=$(now); selfdrv "$(cat inst2/current/logospkg)" || fail "self: the program importing the installed copy did not compile"
T_SELFCC=$(dt "$t0" "$(now)")
st "$T/sa" pkgcfg advise ../inst2 ../repo2 ../key.bin
expect "self: the installed logospkg 1.0 advises its own update" "ok logospkg 1.0 1.1"
t0=$(now); st "$T/sa" pkgcfg update ../inst2 ../repo2 ../key.bin logospkg; T_SELFUPD=$(dt "$t0" "$(now)")
expect "self: the installed logospkg 1.0 updates itself to 1.1 (1.1's self-test compiled and run)" "ok logospkg 1.1"
[ "$(cat inst2/current/logospkg)" = 1.1 ] && cmp -s inst2/pkgs/logospkg/1.1/logospkg.la src/logospkg-1.1/logospkg.la \
  && cmp -s inst2/pkgs/logospkg/1.0/logospkg.la logospkg.la \
  && [ "$(cat inst2/installed)" = "$(printf 'logospkg 1.0 %s\nlogospkg 1.1 %s' "$(O sha arc/logospkg-1.0)" "$(O sha arc/logospkg-1.1)")" ] \
    && pass "self: current/logospkg = 1.1, the 1.0 copy that did it kept in pkgs/, installed lists both" \
    || fail "self: state after the self-update" "$(cat inst2/installed)"
# 1.2 carries a real bug; the installed 1.1, now current, must refuse it
s publish repo2 key.bin arc/logospkg-1.2
selfdrv 1.1 || fail "self: the program importing the installed 1.1 did not compile"
O snap inst2 > inst2.snap
st "$T/sa" pkgcfg update ../inst2 ../repo2 ../key.bin logospkg
expect "self: the installed 1.1 refuses 1.2, whose own self-test fails (its unpack accepts trailing bytes)" \
       "err logospkg 1.2: self-test output differs from logospkg_test.la.expected"
snapeq "self: ... and its own installation is untouched" inst2 inst2.snap

echo "      (VM times: driver compile ${T_COMPILE} s; install of 3 packages with 3 self-tests ${T_INSTALL3} s;"
echo "       publish of logospkg's 40 KB archive ${T_PUB40} s; its install with self-test ${T_SELFINST} s;"
echo "       compiling the program that imports the installed copy ${T_SELFCC} s; the self-update ${T_SELFUPD} s)"
[ "$ok" = 1 ] || exit 1
