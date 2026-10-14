#!/usr/bin/env bash
# gate_logossign.sh — SIGN_KIT (logossign.la): SLH-DSA-SHA2-128s, FIPS 205, on
# the native VM, against an independent oracle and NIST's known answers.
#
# THE ORACLE comes first. slhdsa_model.py is a Python transcription of FIPS 205
# written apart from the LA module; check_acvp.py records how it was checked
# against every non-preHash case of NIST's ACVP vector files (827 of 827, all
# twelve parameter sets: those 100 MB files are not in the repository). This
# gate re-runs it on slhdsa_kat_128s.txt, the SLH-DSA-SHA2-128s subset of those
# files committed here (its header gives the source and sha256 of each file),
# and regenerates the toy vectors with make_toy_vectors.py (they are written
# at gate time, never committed). The toy record (SLH_TOY) is a code-path
# witness, not a security claim.
#
# DEFAULT ARMS (about 16 minutes on a 4-core machine, the C host's verify the
# longest part; at most two VM programs at a time, beside the host and Python):
#   1. the oracle reproduces all 35 KAT records (10 keyGen, 10 sigGen by the
#      sha256 of the signature, 15 sigVer) and writes the toy vectors;
#   2. toy: every keygen (3) and sign (48: internal deterministic, pure
#      deterministic with ctx "ctx" and with an empty ctx, pure hedged) byte for
#      byte with the model, every verify (48) TRUE, every reject record (13:
#      flipped bits in R, FORS, WOTS+ at two layers, an auth path, the last
#      byte; wrong message, pk seed, pk root, ctx; truncated, extended) FALSE;
#      keygen(random) twice from the VM's random builtin, each a key pair the
#      model derives from its seeds, the two different; a ctx of exactly 255
#      bytes signed (byte for byte with the model) and verified; and the full
#      arm's sign-then-hash-then-verify command once (on a hedged toy record);
#   3. 128s: keyGen KATs (tcId 1 and 10; all 10 in the full arm); every sigVer
#      record (2 accept, 13 reject); the model's own fresh signatures (a
#      deterministic one, and a hedged one over a random message with a random
#      addrnd, new every run) verify TRUE;
#   4. 128s negative controls on one valid signature, each FALSE and never a
#      halt: one flipped bit in R, a FORS secret value, a FORS auth path, a
#      WOTS+ signature at layer 0 and at layer 3, a hypertree auth path, the
#      last byte; a wrong message; a wrong pk seed and pk root (its last byte);
#      a wrong and an empty ctx; the pure signature as an internal one; the
#      length-byte forgery, both ways a ctx of 256 bytes could be encoded if
#      the 255 limit were not enforced (sign(c256 ++ M, ctx "") as (M, ctx
#      c256), and sign_internal(00 ++ c256 ++ M) the same way; the two
#      forgeries' genuine forms verify TRUE, so FALSE comes from the ctx rule);
#      a truncated, an extended and an empty signature; a 31- and a 33-byte pk;
#   5. misuse halts loudly (rc 1, the message, no output): a ctx of 256 bytes,
#      a 63- or 65-byte sk, a 15- or 17-byte addrnd, a 15-byte seed;
#   6. the root comparison, white box: SIGN_KIT handed a bxor that prints its
#      arguments makes exactly 16 calls per verify, the byte pairs (computed
#      root, PK.root) in order (a compare that skips a byte of PK.root cannot
#      be seen from outside, since PK.root also feeds H_msg); and
#      confine(logossign.la)(nil) is ok (logossec.la's static confinement);
#   7. position: a toy verify with a 1 MB glyph in front of the module takes
#      at most LOGOSSIGN_POS_BOUND percent (default 150) of its time without;
#   8. the C host gives the VM's answers on one toy verify (TRUE) and two
#      refusals; it needs about 15 minutes of host CPU, so it runs beside the
#      VM lanes from the start (LOGOSSIGN_HOST=0 skips it; LOGOSSIGN_HOST_TIMEOUT,
#      default 3600 s, bounds it);
#   9. timing lines: the hash under F through SHA256_PREFIX_KIT, toy keygen,
#      sign and verify, 128s keygen and verify.
# FULL ARM (LOGOSSIGN_FULL=1; announced as skipped otherwise): all 10 keyGen
# KATs; the deterministic internal sigGen KAT with the shortest message (tcId
# 276) and the hedged pure empty-ctx sigGen KAT (tcId 474), each compared by
# sha256 with the KAT, then verified by the LA verify and by the model, with
# their times (about 15 minutes each on the VM, two at a time).
# ISOLATION: private temp dir (gate_wm_common.sh). WM_VM_TIMEOUT (default
# 600 s) bounds compiles and short runs; LOGOSSIGN_TIMEOUT (default 3600 s)
# bounds each long VM run (the 128s keygens and signatures).
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1
wm_setup logossign.la logoscrypt.la logossec.la slhdsa_model.py make_toy_vectors.py check_acvp.py slhdsa_kat_128s.txt
command -v python3 >/dev/null || { echo "FAIL  logossign: python3 (the oracle) is not installed"; exit 1; }
: "${LOGOSSIGN_TIMEOUT:=3600}"
: "${LOGOSSIGN_POS_BOUND:=150}"
: "${LOGOSSIGN_HOST:=1}"
: "${LOGOSSIGN_HOST_TIMEOUT:=3600}"
FULL=${LOGOSSIGN_FULL:-0}

# ── VM helpers ────────────────────────────────────────────────────────────
# A VM process killed by SIGKILL (rc 137) was killed from outside (the OOM
# killer on a busy machine: a 128s run reaches about 1.4 GB); it is retried
# twice, after a pause, with a NOTE. Every other result counts at once.
vm_compile() {  # vm_compile PROG.la BIN: compile on the VM into $T/BIN; a failure ends the gate
    local tries=0
    cp "$T/$1" "$T/logos_source.la"
    while :; do
        cp "$T/compiler.bin" "$T/logos_program.bin"
        vrc=0; ( cd "$T" && timeout "$WM_VM_TIMEOUT" ./logos_secd >/dev/null 2>"$T/vce" ) || vrc=$?
        [ "$vrc" = 137 ] && [ "$tries" -lt 2 ] || break
        tries=$((tries + 1)); echo "NOTE  logossign: a VM compile was killed by SIGKILL; retrying"; sleep 30
    done
    [ "$vrc" = 0 ] || { echo "FAIL  logossign: $1 did not compile (rc $vrc)"; tail -3 "$T/vce"; exit 1; }
    cp "$T/logos_program.bin" "$T/$2"
}
# run_in DIR BIN CMDS TIMEOUT: run BIN in its own directory $T/DIR with
# cmds.txt = CMDS; DIR/out, DIR/err, DIR/rc
run_in() {
    local d="$T/$1" tries=0 rc
    mkdir -p "$d"; cp "$T/logos_secd" "$d/"; cp "$T/$2" "$d/logos_program.bin"; cp "$T/$3" "$d/cmds.txt"
    while :; do
        rc=0; ( cd "$d" && timeout "$4" ./logos_secd >"$d/out" 2>"$d/err" ) || rc=$?
        [ "$rc" = 137 ] && [ "$tries" -lt 2 ] || break
        tries=$((tries + 1)); echo "NOTE  logossign: a VM run ($1) was killed by SIGKILL; retrying"; sleep 30
    done
    echo "$rc" > "$d/rc"
}
rc_of() { cat "$T/$1/rc" 2>/dev/null || echo none; }
# results DIR: the result lines (timing lines dropped)
results() { grep -v '^#T ' "$T/$1/out" 2>/dev/null; }
# us_of DIR ID: the time of one command, in microseconds
us_of() { awk -v id="$2" '$1 == "#T" && $2 == id {print $3}' "$T/$1/out" 2>/dev/null; }
# median_ms DIR PREFIX: the median time of the commands whose id starts with PREFIX
median_ms() {
    awk -v p="$2" '$1 == "#T" && index($2, p) == 1 {print $3}' "$T/$1/out" 2>/dev/null | sort -n \
      | awk '{a[NR] = $1} END {if (NR) printf "%d", a[int((NR + 1) / 2)] / 1000; else print "?"}'
}

# ── the Python side ───────────────────────────────────────────────────────
cat > "$T/oracle.py" <<'PYEOF'
"""The gate's Python side, over slhdsa_model.py (run with python3 -I)."""
import hashlib, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import slhdsa_model as M
import check_acvp as A

def hx(b): return b.hex() if len(b) else "-"
def h2b(x): return b"" if x in ("", "-") else bytes.fromhex(x)
def flip(b, i, mask):
    b = bytearray(b); b[i] ^= mask; return bytes(b)
def write(path, lines):
    with open(path, "w") as f: f.write("\n".join(lines) + "\n")

cmd = sys.argv[1]
if cmd == "kat":
    # the model on every record of the committed KAT file
    tasks = A.load_kat(sys.argv[2])
    kinds, bad = {}, []
    for t in tasks:
        bucket, tc, ok, note, dt = A.run_case(t)
        kinds[t["kind"]] = kinds.get(t["kind"], 0) + 1
        if not ok: bad.append("%s %s %s" % (t["kind"], tc, note))
    print("records %d keyGen %d sigGen %d sigVer %d failed %d" % (len(tasks), kinds.get("keyGen", 0),
          kinds.get("sigGen", 0), kinds.get("sigVer", 0), len(bad)))
    for b in bad: print("FAILED " + b)

elif cmd == "toycmds":
    # the toy vectors as driver commands (cmds) and the expected lines (exp)
    src, sel, out_c, out_e = sys.argv[2:6]
    recs = [l.split() for l in open(src) if l.strip() and not l.startswith("#")]
    keys = dict((r[1], (r[5], r[6])) for r in recs if r[0] == "keygen")
    cmds, exp, n = ["params toy"], [], 0
    kcmds, kexp = [], []
    for r in recs:
        if r[0] == "keygen" and "k" in sel:
            kcmds.append("kg kg%s %s %s %s" % tuple(r[1:5])); kexp.append("kg kg%s %s %s" % (r[1], r[5], r[6]))
        elif r[0] == "sign":
            n += 1
            key, mode, ctx, addrnd, msg, sig = r[1:7]
            sk, pk = keys[key]
            iface = "i" if mode == "internal-det" else "p"
            if "s" in sel:
                if iface == "i": cmds.append("si %s-s%d %s %s -" % (mode, n, msg, sk))
                else: cmds.append("sp %s-s%d %s %s %s %s" % (mode, n, msg, ctx, sk, addrnd))
                exp.append("s%s %s-s%d %s" % (iface, mode, n, sig))
            if "v" in sel:
                if iface == "i": cmds.append("vi %s-v%d %s %s %s" % (mode, n, msg, sig, pk))
                else: cmds.append("vp %s-v%d %s %s %s %s" % (mode, n, msg, sig, ctx, pk))
                exp.append("v%s %s-v%d 1" % (iface, mode, n))
        elif r[0] == "reject" and "r" in sel:
            kind, where, iface, ctx, pk, msg, sig = r[2:9]
            if iface == "pure": cmds.append("vp %s %s %s %s %s" % (kind, msg, sig, ctx, pk)); exp.append("vp %s 0" % kind)
            else: cmds.append("vi %s %s %s %s" % (kind, msg, sig, pk)); exp.append("vi %s 0" % kind)
    # the full arm's sph command (sign, sha256 of the signature, verify of it), once, on the toy
    r = [x for x in recs if x[0] == "sign" and x[2] == "pure-hedged"][0]
    cmds.append("sph sph1 %s %s %s %s %s" % (r[5], r[3], keys[r[1]][0], r[4], keys[r[1]][1]))
    exp.append("sph sph1 %s 1" % hashlib.sha256(h2b(r[6])).hexdigest())
    # the ctx boundary: a ctx of exactly 255 bytes is signed and verifies (the model's signature)
    s = M.get("TOY-SHA2")
    c255, m33, (sk0, pk0) = bytes((3 * j + 2) % 256 for j in range(255)), h2b(r[5]) + b"boundary", keys["0"]
    sg = s.slh_sign(m33, c255, h2b(sk0))
    assert s.slh_verify(m33, sg, c255, h2b(pk0))
    cmds.append("sp ctx255-s %s %s %s -" % (hx(m33), hx(c255), sk0)); exp.append("sp ctx255-s %s" % hx(sg))
    cmds.append("vp ctx255-v %s %s %s %s" % (hx(m33), hx(sg), hx(c255), pk0)); exp.append("vp ctx255-v 1")
    # the keygens last: their times are then not taken while the Python oracle starts
    cmds += kcmds; exp += kexp
    if "R" in sel:
        cmds += ["kr kr1", "kr kr2"]
    write(out_c, cmds); write(out_e, exp + ["end"])

elif cmd == "hostprog":
    # the host program: key 0's pure deterministic signature of the 33-byte message
    src, tmpl, out = sys.argv[2:5]
    recs = [l.split() for l in open(src) if l.startswith("sign 0 pure-det 637478")]
    r = [x for x in recs if len(x[5]) == 66][0]
    pk = [l.split() for l in open(src) if l.startswith("keygen 0 ")][0][6]
    t = open(tmpl).read().replace("@M@", r[5]).replace("@SIG@", r[6]).replace("@PK@", pk)
    open(out, "w").write(t)

elif cmd == "rootprog":
    # the root-comparison program: key 0's pure deterministic signature of the
    # 33-byte message, under its pk and under the pk with PK.root's last byte flipped
    src, tmpl, out = sys.argv[2:5]
    recs = [l.split() for l in open(src) if l.startswith("sign 0 pure-det 637478")]
    r = [x for x in recs if len(x[5]) == 66][0]
    pk = [l.split() for l in open(src) if l.startswith("keygen 0 ")][0][6]
    t = open(tmpl).read().replace("@M@", r[5]).replace("@SIG@", r[6]).replace("@PK@", pk)
    t = t.replace("@PKBAD@", hx(flip(h2b(pk), 31, 0x01)))
    open(out, "w").write(t)

elif cmd == "rootcheck":
    # every bxor SIGN_KIT made during each verify: exactly the 16 byte pairs of
    # (computed root, PK.root), in order; for the valid signature they agree
    src, got = sys.argv[2:4]
    pk = h2b([l.split() for l in open(src) if l.startswith("keygen 0 ")][0][6])
    bad = flip(pk, 31, 0x01)
    lines = open(got).read().split("\n")
    assert lines[-1] == "" and lines[-2] == "end", "no end line"
    i = lines.index("valid"); j = lines.index("wrong-root")
    v, w = lines[i + 1:j], lines[j + 1:-2]
    assert v[-1] == "1" and w[-1] == "0", "verdicts %r %r" % (v[-1:], w[-1:])
    v = [x.split() for x in v[:-1]]; w = [x.split() for x in w[:-1]]
    assert len(v) == 16 and len(w) == 16, "%d and %d bxor calls, want 16 each" % (len(v), len(w))
    assert all(x[0] == "x" for x in v + w)
    assert [int(x[2]) for x in v] == list(pk[16:32]) and [int(x[1]) for x in v] == list(pk[16:32]), "valid: not (root, PK.root)"
    assert [int(x[2]) for x in w] == list(bad[16:32]), "wrong root: the second operands are not PK.root's bytes"
    assert any(x[1] != x[2] for x in w)
    print("ok")

elif cmd == "krcheck":
    # two keys from keygen(random): each the model's key pair for its seeds, the two different
    s = M.get("TOY-SHA2")
    got = [l.split() for l in open(sys.argv[2]) if l.startswith("kr ")]
    assert len(got) == 2, "want two kr lines"
    for _, kid, sk, pk in got:
        sk, pk = h2b(sk), h2b(pk)
        assert len(sk) == 64 and len(pk) == 32, "lengths"
        assert s.slh_keygen_internal(sk[0:16], sk[16:32], sk[32:48]) == (sk, pk), "not the model's key pair"
        sig = s.slh_sign(b"keygen(random)", b"", sk)
        assert s.slh_verify(b"keygen(random)", sig, b"", pk), "does not sign"
    assert got[0][2] != got[1][2], "the two keys are equal"
    print("ok")

elif cmd == "katcmds":
    # KAT records as driver commands: SEL is a comma list of kgN / sv / sgN
    src, sel, out_c, out_e = sys.argv[2:6]
    sel = sel.split(",")
    cmds, exp = ["params 128s"], []
    for line in open(src):
        if not line.strip() or line.startswith("#"): continue
        r = line.split()
        if r[0] == "keygen" and "kg" + r[1] in sel:
            cmds.append("kg kg%s %s %s %s" % tuple(r[1:5])); exp.append("kg kg%s %s %s" % (r[1], r[5], r[6]))
        elif r[0] == "sigver" and "sv" in sel:
            tc, iface, res, pk, ctx, msg, sig = r[1:8]
            if iface == "pure": cmds.append("vp sv%s %s %s %s %s" % (tc, msg, sig, ctx, pk)); exp.append("vp sv%s %s" % (tc, res))
            else: cmds.append("vi sv%s %s %s %s" % (tc, msg, sig, pk)); exp.append("vi sv%s %s" % (tc, res))
        elif r[0] == "siggen" and "sg" + r[1] in sel:
            tc, iface, det, sk, pk, addrnd, ctx, msg, h = r[1:10]
            if iface == "pure": cmds.append("sph sg%s %s %s %s %s %s" % (tc, msg, ctx, sk, addrnd, pk))
            else: cmds.append("sih sg%s %s %s %s %s" % (tc, msg, sk, addrnd, pk))
            exp.append("s%sh sg%s %s 1" % ("p" if iface == "pure" else "i", tc, h))
    write(out_c, cmds); write(out_e, exp + ["end"])

elif cmd == "sgcheck":
    # full arm: the LA signatures (hex after the expected fields) verified by the model
    s = M.get("SLH-DSA-SHA2-128s")
    kat = dict((l.split()[1], l.split()) for l in open(sys.argv[2]) if l.startswith("siggen "))
    n = 0
    for l in open(sys.argv[3]):
        f = l.split()
        if f[0] not in ("sih", "sph"): continue
        tc = f[1][2:]; r = kat[tc]
        sig = h2b(f[4]); msg, ctx, pk = h2b(r[8]), h2b(r[7]), h2b(r[5])
        okv = s.slh_verify(msg, sig, ctx, pk) if r[2] == "pure" else s.slh_verify_internal(msg, sig, pk)
        assert okv and hashlib.sha256(sig).hexdigest() == r[9], "tcId %s" % tc
        n += 1
    print("ok %d" % n)

elif cmd == "negs":
    # 128s: the model's fresh signatures and the negative controls, as driver
    # commands with the model's own verdict on each as the expected line
    out_c, out_e, out_lay = sys.argv[2:5]
    s = M.get("SLH-DSA-SHA2-128s")
    n = 16
    sk, pk = s.slh_keygen_internal(bytes(range(0x40, 0x50)), bytes(range(0x50, 0x60)), bytes(range(0x60, 0x70)))
    msg = bytes((7 * j + 33) % 256 for j in range(33)); ctx = b"logossign"
    base = s.slh_sign(msg, ctx, sk)
    lay = s.layout()
    rmsg, rnd = os.urandom(40), os.urandom(16)
    hedged = s.slh_sign(rmsg, b"", sk, rnd)
    c256 = bytes((5 * j + 1) % 256 for j in range(256))
    forge1 = s.slh_sign(c256 + msg, b"", sk)                 # M' = 00 00 c256 M: toByte(256, 1) taken mod 256
    forge2 = s.slh_sign_internal(b"\x00" + c256 + msg, sk)   # M' = 00 c256 M: toByte(256, 1) as no byte
    cases = [  # (id, iface, msg, sig, ctx, pk, expected)
        ("fresh-det", "p", msg, base, ctx, pk, 1),
        ("fresh-hedged", "p", rmsg, hedged, b"", pk, 1),
        ("flip_R", "p", msg, flip(base, lay["R"][0] + 5, 0x01), ctx, pk, 0),
        ("flip_fors_sk", "p", msg, flip(base, lay["fors"][0]["sk"][0] + 3, 0x80), ctx, pk, 0),
        ("flip_fors_auth", "p", msg, flip(base, lay["fors"][13]["auth"][0] + 5 * n + 7, 0x04), ctx, pk, 0),
        ("flip_wots_l0", "p", msg, flip(base, lay["ht"][0]["wots"][0] + 10 * n + 2, 0x10), ctx, pk, 0),
        ("flip_wots_l3", "p", msg, flip(base, lay["ht"][3]["wots"][0] + 33 * n + 15, 0x01), ctx, pk, 0),
        ("flip_ht_auth", "p", msg, flip(base, lay["ht"][0]["auth"][0] + 8 * n + 9, 0x20), ctx, pk, 0),
        ("flip_last", "p", msg, flip(base, len(base) - 1, 0x80), ctx, pk, 0),
        ("wrong_msg", "p", flip(msg, 0, 0x01), base, ctx, pk, 0),
        ("wrong_pk_seed", "p", msg, base, ctx, flip(pk, 0, 0x01), 0),
        ("wrong_pk_root", "p", msg, base, ctx, flip(pk, 2 * n - 1, 0x01), 0),
        ("wrong_ctx", "p", msg, base, flip(ctx, 2, 0x01), pk, 0),
        ("empty_ctx", "p", msg, base, b"", pk, 0),
        ("as_internal", "i", msg, base, b"", pk, 0),
        ("forge-mod256-genuine", "p", c256 + msg, forge1, b"", pk, 1),
        ("forge-mod256", "p", msg, forge1, c256, pk, 0),
        ("forge-nobyte-genuine", "i", b"\x00" + c256 + msg, forge2, b"", pk, 1),
        ("forge-nobyte", "p", msg, forge2, c256, pk, 0),
        ("ctx256", "p", msg, base, c256, pk, 0),
        ("truncated", "p", msg, base[:-1], ctx, pk, 0),
        ("extended", "p", msg, base + b"\x00", ctx, pk, 0),
        ("empty_sig", "p", msg, b"", ctx, pk, 0),
        ("pk31", "p", msg, base, ctx, pk[:31], 0),
        ("pk33", "p", msg, base, ctx, pk + b"\x00", 0),
    ]
    cmds, exp = ["params 128s"], []
    for (cid, iface, m, sg, cx, k, want) in cases:
        if iface == "p":
            got = s.slh_verify(m, sg, cx, k) if len(cx) <= 255 else False
            cmds.append("vp %s %s %s %s %s" % (cid, hx(m), hx(sg), hx(cx), hx(k)))
        else:
            got = s.slh_verify_internal(m, sg, k)
            cmds.append("vi %s %s %s %s" % (cid, hx(m), hx(sg), hx(k)))
        assert got == bool(want), cid
        exp.append("v%s %s %d" % (iface, cid, want))
    write(out_c, cmds); write(out_e, exp + ["end"])
    write(out_lay, ["%s %s" % (c[0], c[6]) for c in cases])
PYEOF

# ── the LA driver: one compiled program, a commands file per run ──────────
cat > "$T/drv.la" <<'LAEOF'
import("logoscrypt.la")
import("logossign.la")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph LET = la v. la k. k(v)
# DRV reads cmds.txt (first line "params toy" or "params 128s"), runs each
# command, and prints one result line and one "#T id microseconds" line per
# command. Fields are lowercase hex, "-" for empty.
#   kg ID SKSEED SKPRF PKSEED   -> kg ID SK PK            keygen_internal
#   kr ID                       -> kr ID SK PK            keygen(random)
#   si ID M SK ADDRND           -> si ID SIG              sign_internal
#   sp ID M CTX SK ADDRND       -> sp ID SIG              sign
#   sih ID M SK ADDRND PK       -> sih ID sha256(SIG) V SIG, V = verify_internal of SIG
#   sph ID M CTX SK ADDRND PK   -> sph ID sha256(SIG) V SIG, V = verify of SIG
#   vi ID M SIG PK              -> vi ID 1|0              verify_internal
#   vp ID M SIG CTX PK          -> vp ID 1|0              verify
glyph DRV = la str_at. la ord. la str_to_int. la int_to_str. la chr. la concat. la str_len. la error.
    la add. la sub. la mul. la lt. la int_eq. la band. la bor. la bxor. la bshl. la bshr.
    la print. la read_file. la clock_gettime. la str_eq. la div. la random.
 LET(CRYPT_FAST(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(error)(add)(sub)(mul)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr))(la crypt.
 LET(SHA256_PREFIX_KIT(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(error)(add)(sub)(mul)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr))(la pkit.
 crypt(la sha256. la hmac. la hkdf. la seal. la open. la hex.
 LET(Z)(la fix.
 LET(la s. str_to_int(str_len(s)))(la len.
 LET(la f. fix(la sp. la lo. la hi.
        lt(add(lo)(1))(hi)
          (la _. (la mid. concat(sp(lo)(mid))(sp(mid)(hi)))(bshr(add(lo)(hi))(1)))
          (la _. lt(lo)(hi)(la _. f(lo))(la _. "")("!"))
          ("!")))(la span.
 LET(str_at(span(la i. chr(int_to_str(i)))(0)(256)))(la T.
 LET(la c. (la x. lt(x)(58)(la _. sub(x)(48))(la _. sub(x)(87))("!"))(str_to_int(ord(c))))(la hv.
 LET(la s. str_eq(s)("-")(la _. "")
       (la _. (la sa. span(la q. T(add(mul(hv(sa(mul(q)(2))))(16))(hv(sa(add(mul(q)(2))(1))))))(0)(div(len(s))(2)))(str_at(s)))
       ("!"))(la unhex.
 # microseconds of CLOCK_MONOTONIC
 LET(la _. (la s. (la sa. fix(la g. la q. la acc.
        str_eq(sa(q))(" ")
          (la _. add(mul(acc)(1000000))(div(str_to_int(span(la r. sa(add(add(q)(1))(r)))(0)(sub(len(s))(add(q)(1)))))(1000)))
          (la _. g(add(q)(1))(add(mul(acc)(10))(str_to_int(sa(q)))))
          ("!"))(0)(0))(str_at(s)))(clock_gettime("1")))(la nowus.
 LET(read_file("cmds.txt"))(la src.
 LET(str_at(src))(la sa.
 LET(len(src))(la L.
 # word(i): la k. k(text)(the index after its separator)
 LET(la i. (la e. la k. k(span(la q. sa(add(i)(q)))(0)(sub(e)(i)))(add(e)(1)))
          (fix(la sc. la q. lt(q)(L)
                 (la _. (la c. str_eq(c)(" ")(la _. q)(la _. str_eq(c)("\n")(la _. q)(la _. sc(add(q)(1)))("!"))("!"))(sa(q)))
                 (la _. q)("!"))(i)))(la word.
 word(0)(la w0. la i0. word(i0)(la pname. la i1.
 SIGN_KIT(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(error)(add)(sub)(mul)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr)
   (crypt)(pkit)(str_eq(pname)("toy")(la _. SLH_TOY)(la _. SLH_128S)("!"))
 (la kgi. la sgi. la vfi. la sgp. la vfp. la kg.
 LET(la b. b(la _. "1")(la _. "0")("!"))(la b2s.
 LET(la sk. la pk. concat(concat(hex(sk))(" "))(hex(pk)))(la pair.
 # one command whose arguments start at index i: la k. k(result)(next index)
 LET(la op. la i.
   str_eq(op)("kg")(la _. word(i)(la a. la i. word(i)(la b. la i. word(i)(la c. la i. la k.
       k(kgi(unhex(a))(unhex(b))(unhex(c))(pair))(i)))))(la _.
   str_eq(op)("kr")(la _. la k. k(kg(random)(pair))(i))(la _.
   str_eq(op)("si")(la _. word(i)(la a. la i. word(i)(la b. la i. word(i)(la c. la i. la k.
       k(hex(sgi(unhex(a))(unhex(b))(unhex(c))))(i)))))(la _.
   str_eq(op)("sp")(la _. word(i)(la a. la i. word(i)(la b. la i. word(i)(la c. la i. word(i)(la e. la i. la k.
       k(hex(sgp(unhex(a))(unhex(b))(unhex(c))(unhex(e))))(i))))))(la _.
   str_eq(op)("sih")(la _. word(i)(la a. la i. word(i)(la b. la i. word(i)(la c. la i. word(i)(la pk. la i. la k.
       (la sig. k(concat(concat(concat(concat(hex(sha256(sig)))(" "))(b2s(vfi(unhex(a))(sig)(unhex(pk)))))(" "))(hex(sig))))
         (sgi(unhex(a))(unhex(b))(unhex(c)))(i))))))(la _.
   str_eq(op)("sph")(la _. word(i)(la a. la i. word(i)(la b. la i. word(i)(la c. la i. word(i)(la e. la i. word(i)(la pk. la i. la k.
       (la sig. k(concat(concat(concat(concat(hex(sha256(sig)))(" "))(b2s(vfp(unhex(a))(sig)(unhex(b))(unhex(pk)))))(" "))(hex(sig))))
         (sgp(unhex(a))(unhex(b))(unhex(c))(unhex(e)))(i)))))))(la _.
   str_eq(op)("vi")(la _. word(i)(la a. la i. word(i)(la b. la i. word(i)(la c. la i. la k.
       k(b2s(vfi(unhex(a))(unhex(b))(unhex(c))))(i)))))(la _.
   str_eq(op)("vp")(la _. word(i)(la a. la i. word(i)(la b. la i. word(i)(la c. la i. word(i)(la e. la i. la k.
       k(b2s(vfp(unhex(a))(unhex(b))(unhex(c))(unhex(e))))(i))))))(la _.
   error(concat("drv: unknown op ")(op)))
   ("!"))("!"))("!"))("!"))("!"))("!"))("!"))("!"))(la run1.
 fix(la go. la i. lt(i)(L)
    (la _. word(i)(la op. la i. word(i)(la id. la i.
        (la t0. run1(op)(i)(la res. la i.
            (la _. (la _. go(i))(print(concat(concat(concat("#T ")(id))(" "))(int_to_str(sub(nowus("!"))(t0))))))
            (print(concat(concat(concat(concat(op)(" "))(id))(" "))(res)))))
        (nowus("!")))))
    (la _. print("end"))("!"))(i1)
 ))))))))))))))))))))
glyph MAIN = DRV(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(error)(add)(sub)(mul)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr)
  (print)(read_file)(clock_gettime)(str_eq)(div)(random)
LAEOF

# ── confine ───────────────────────────────────────────────────────────────
cat > "$T/cf.la" <<'LAEOF'
import("logossec.la")
glyph NIL = la n. la c. n(n)
# a stub crypt record: confine never touches it
glyph STUB = la s. s(la m. m)(la k. la m. m)(la a. a)(la a. a)(la a. a)(la x. x)
glyph MAIN = SEC_KIT(str_at)(ord)(str_len)(str_to_int)(int_to_str)(chr)(concat)(str_eq)(add)(sub)(mul)(div)(lt)(int_eq)(band)(bor)(bxor)(STUB)
 (la mint. la attenuate. la verify. la within. la confine.
   print(confine(read_file("logossign.la"))(NIL)(la m. concat("err ")(m))(la v. "ok")))
LAEOF

# ── 1. the oracle ─────────────────────────────────────────────────────────
( cd "$T" && python3 -I oracle.py kat slhdsa_kat_128s.txt > kat_oracle.out 2>&1; echo $? > kat_oracle.rc ) &
kat_pid=$!
if ( cd "$T" && python3 -I make_toy_vectors.py toy_vectors.txt > toygen.out 2>&1 ) \
   && grep -qxF "wrote toy_vectors.txt: 3 keygen, 48 sign (all verify True), 13 reject (all verify False)" "$T/toygen.out"; then
    echo "PASS  logossign oracle: make_toy_vectors.py regenerated the toy vectors from slhdsa_model.py (3 keygen, 48 sign each verified by the model, 13 reject each refused by it)"
else
    echo "FAIL  logossign oracle: make_toy_vectors.py: $(head -c 300 "$T/toygen.out")"; exit 1
fi
( cd "$T" && python3 -I oracle.py toycmds toy_vectors.txt ksvrR toy.cmds toy.exp ) || { echo "FAIL  logossign: toy commands"; exit 1; }

# ── 8 (started now, checked at the end): the C host ────────────────────────
# One toy verify on the C host (key 0's pure deterministic signature of the
# 33-byte message), then two that are FALSE before any hashing (a ctx of 256
# bytes, a truncated signature). The host needs about a quarter of an hour of
# CPU for the verify, so it runs beside the VM lanes from here on.
cat > "$T/hostv.tmpl" <<'LAEOF'
import("logoscrypt.la")
import("logossign.la")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph SEQ = la a. la b. b
glyph SPAN = la f. la a. la b. (Z(la sp. la lo. la hi.
    lt(add(lo)(1))(hi)
      (la _. (la mid. concat(sp(lo)(mid))(sp(mid)(hi)))(div(add(lo)(hi))(2)))
      (la _. lt(lo)(hi)(la _. f(lo))(la _. "")("!"))
      ("!")))(a)(b)
glyph FROMHEX = la s. SPAN(la i. (la hv. chr(int_to_str(add(mul(hv(str_at(s)(mul(i)(2))))(16))(hv(str_at(s)(add(mul(i)(2))(1)))))))
                           (la c. (la n. lt(n)(58)(la _. sub(n)(48))(la _. sub(n)(87))("!"))(str_to_int(ord(c)))))(0)(div(str_to_int(str_len(s)))(2))
glyph B = la b. b(la _. "1")(la _. "0")("!")
glyph MAIN =
 (la crypt. la pkit.
  SIGN_KIT(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(error)(add)(sub)(mul)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr)(crypt)(pkit)(SLH_TOY)
  (la kgi. la sgi. la vfi. la sgp. la vfp. la kg.
    (la m. la sig. la pk.
      SEQ(SEQ(SEQ(print(concat("verify ")(B(vfp(m)(sig)("ctx")(pk)))))
                 (print(concat("ctx256 ")(B(vfp(m)(sig)(SPAN(la i. "c")(0)(256))(pk))))))
             (print(concat("truncated ")(B(vfp(m)(SPAN(la i. str_at(sig)(i))(0)(2047))("ctx")(pk))))))
         (print("end")))
    (FROMHEX("@M@"))(FROMHEX("@SIG@"))(FROMHEX("@PK@"))))
 (CRYPT_FAST(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(error)(add)(sub)(mul)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr))
 (SHA256_PREFIX_KIT(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(error)(add)(sub)(mul)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr))
LAEOF
if [ "$LOGOSSIGN_HOST" = 1 ]; then
    mkdir -p "$T/hostw"; cp "$T/tiny_host" "$T/logossign.la" "$T/logoscrypt.la" "$T/hostw/"
    ( cd "$T" && python3 -I oracle.py hostprog toy_vectors.txt hostv.tmpl hostw/hostv.la ) || { echo "FAIL  logossign: host program"; exit 1; }
    host_s=$(date +%s)
    ( cd "$T/hostw" && { timeout "$LOGOSSIGN_HOST_TIMEOUT" ./tiny_host hostv.la > out 2> err; echo $? > rc; date +%s > end; } ) &
    host_pid=$!
fi
# the model's 128s signatures for the negative controls (four signatures, about 20 s of Python)
( cd "$T" && python3 -I oracle.py negs neg.cmds neg.exp neg.list > negs.out 2>&1; echo $? > negs.rc ) &
negs_pid=$!
KG_DEFAULT="kg1,kg10"
( cd "$T" && python3 -I oracle.py katcmds slhdsa_kat_128s.txt "$KG_DEFAULT" kg.cmds kg.exp && python3 -I oracle.py katcmds slhdsa_kat_128s.txt sv sv.cmds sv.exp ) \
  || { echo "FAIL  logossign: KAT commands"; exit 1; }

# ── compile ───────────────────────────────────────────────────────────────
vm_compile drv.la drv.bin
vm_compile cf.la cf.bin

# the oracle's verdict on the KAT file comes before any VM result is judged
wait "$kat_pid"
if [ "$(cat "$T/kat_oracle.rc")" = 0 ] && [ "$(head -1 "$T/kat_oracle.out")" = "records 35 keyGen 10 sigGen 10 sigVer 15 failed 0" ]; then
    echo "PASS  logossign oracle: slhdsa_model.py reproduces all 35 records of slhdsa_kat_128s.txt (10 keyGen, 10 sigGen by the signature's sha256, 15 sigVer)"
else
    echo "FAIL  logossign oracle: $(head -c 400 "$T/kat_oracle.out")"; exit 1
fi

printf 'unused\n' > "$T/none.cmds"

# ── 2-4: two lanes of VM runs ─────────────────────────────────────────────
# lane A: the 128s keyGen KATs; lane B: the toy runs, then the 128s verifies
run_in kg drv.bin kg.cmds "$LOGOSSIGN_TIMEOUT" &
lane_a=$!
run_in toy drv.bin toy.cmds "$LOGOSSIGN_TIMEOUT"
wait "$negs_pid"
[ "$(cat "$T/negs.rc")" = 0 ] || { echo "FAIL  logossign: the model's negative controls: $(tail -3 "$T/negs.out")"; exit 1; }
cat "$T/sv.cmds" > "$T/v128.cmds"; tail -n +2 "$T/neg.cmds" >> "$T/v128.cmds"
run_in v128 drv.bin v128.cmds "$LOGOSSIGN_TIMEOUT"

# toy
results toy | grep -v '^kr ' | awk '{if ($1 == "sph") print $1, $2, $3, $4; else print}' > "$T/toy.got"
if [ "$(rc_of toy)" = 0 ] && cmp -s "$T/toy.got" "$T/toy.exp"; then
    nk=$(grep -c '^kg ' "$T/toy.exp"); ns=$(grep -c '^s[ip] ' "$T/toy.exp")
    nv=$(grep -c '^v[ip] .*-v[0-9]* 1$' "$T/toy.exp"); nr=$(grep -c ' 0$' "$T/toy.exp")
    echo "PASS  logossign toy (VM): $nk keygens and $ns signatures (internal deterministic, pure deterministic with ctx 'ctx' and with an empty ctx, pure hedged) byte for byte with the model; $nv verifies TRUE; $nr reject records FALSE; a 255-byte ctx signed and verified; the full arm's sign-hash-verify command once"
else
    echo "FAIL  logossign toy (VM): rc=$(rc_of toy)"; diff "$T/toy.exp" "$T/toy.got" | cut -c1-160 | head -8; tail -3 "$T/toy/err"; ok=0
fi
results toy | grep '^kr ' > "$T/kr.got"
if [ "$(rc_of toy)" = 0 ] && [ "$(cd "$T" && python3 -I oracle.py krcheck kr.got 2>&1)" = ok ]; then
    echo "PASS  logossign keygen(random) (VM): two key pairs from one random(\"48\") draw each, both the model's key pair for their seeds, signing and verifying, and different"
else
    echo "FAIL  logossign keygen(random) (VM): $(cd "$T" && python3 -I oracle.py krcheck kr.got 2>&1 | tail -1)"; ok=0
fi

# 128s sigVer and the negative controls
results v128 > "$T/v128.got"
head -n -1 "$T/sv.exp" > "$T/v128.exp"; cat "$T/neg.exp" >> "$T/v128.exp"
if [ "$(rc_of v128)" = 0 ] && cmp -s "$T/v128.got" "$T/v128.exp"; then
    na=$(grep -c '^v[ip] sv.* 1$' "$T/sv.exp"); nj=$(grep -c '^v[ip] sv.* 0$' "$T/sv.exp")
    echo "PASS  logossign 128s sigVer (VM): all $((na + nj)) KAT records ($na accept, $nj reject: modified R, SIG_FORS, SIG_HT, message; too small, too large), the NIST verdict on each"
    echo "PASS  logossign 128s fresh signatures (VM): the model's deterministic signature and its hedged one over a random message with a random addrnd (new every run) verify TRUE"
    nn=$(grep -vc -e '^fresh' -e 'genuine' "$T/neg.list")
    echo "PASS  logossign 128s negative controls (VM): all $nn FALSE, none halting: $(grep -v -e '^fresh' -e genuine "$T/neg.list" | awk '{print $1}' | tr '\n' ' ')(the two forgeries' genuine forms verify TRUE)"
else
    echo "FAIL  logossign 128s verify (VM): rc=$(rc_of v128)"; diff "$T/v128.exp" "$T/v128.got" | cut -c1-160 | head -8; tail -3 "$T/v128/err"; ok=0
fi

# ── 4b. the root comparison, white box ─────────────────────────────────────
# A comparison that skips a byte of PK.root cannot be caught from outside:
# PK.root also goes into H_msg, so a wrong root changes every byte of the
# computed one. So SIGN_KIT is handed a bxor that prints its arguments (the
# eq16 loop is its only use in a verify; CRYPT_FAST keeps the real one): each
# verify must make exactly 16 calls, the byte pairs (computed root, PK.root)
# in order, equal for the valid signature (gate_logossec.sh audits its
# signature compare the same way).
cat > "$T/rootcmp.tmpl" <<'LAEOF'
import("logoscrypt.la")
import("logossign.la")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph SEQ = la a. la b. b
glyph SPAN = la f. la a. la b. (Z(la sp. la lo. la hi.
    lt(add(lo)(1))(hi)
      (la _. (la mid. concat(sp(lo)(mid))(sp(mid)(hi)))(div(add(lo)(hi))(2)))
      (la _. lt(lo)(hi)(la _. f(lo))(la _. "")("!"))
      ("!")))(a)(b)
glyph FROMHEX = la s. SPAN(la i. (la hv. chr(int_to_str(add(mul(hv(str_at(s)(mul(i)(2))))(16))(hv(str_at(s)(add(mul(i)(2))(1)))))))
                           (la c. (la n. lt(n)(58)(la _. sub(n)(48))(la _. sub(n)(87))("!"))(str_to_int(ord(c)))))(0)(div(str_to_int(str_len(s)))(2))
glyph B = la b. b(la _. "1")(la _. "0")("!")
# W(f): f, printing "x a b" for every call f(a)(b)
glyph W = la f. la a. la b. SEQ(print(concat("x ")(concat(int_to_str(a))(concat(" ")(int_to_str(b))))))(f(a)(b))
glyph MAIN =
 (la crypt. la pkit.
  SIGN_KIT(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(error)(add)(sub)(mul)(lt)(int_eq)(band)(bor)(W(bxor))(bshl)(bshr)(crypt)(pkit)(SLH_TOY)
  (la kgi. la sgi. la vfi. la sgp. la vfp. la kg.
    (la m. la sig. la pk. la pkbad.
      SEQ(SEQ(SEQ(SEQ(print("valid"))(print(B(vfp(m)(sig)("ctx")(pk)))))
                 (print("wrong-root")))
             (print(B(vfp(m)(sig)("ctx")(pkbad)))))
         (print("end")))
    (FROMHEX("@M@"))(FROMHEX("@SIG@"))(FROMHEX("@PK@"))(FROMHEX("@PKBAD@"))))
 (CRYPT_FAST(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(error)(add)(sub)(mul)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr))
 (SHA256_PREFIX_KIT(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(error)(add)(sub)(mul)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr))
LAEOF
( cd "$T" && python3 -I oracle.py rootprog toy_vectors.txt rootcmp.tmpl rootcmp.la ) || { echo "FAIL  logossign: root program"; exit 1; }
vm_compile rootcmp.la rootcmp.bin
run_in rootcmp rootcmp.bin none.cmds "$WM_VM_TIMEOUT"
rcres=$(cd "$T" && python3 -I oracle.py rootcheck toy_vectors.txt rootcmp/out 2>&1 | tail -1)
if [ "$(rc_of rootcmp)" = 0 ] && [ "$rcres" = ok ]; then
    echo "PASS  logossign root comparison (VM): each verify XORs exactly the 16 byte pairs (computed root, PK.root) in order, all equal for a valid toy signature, PK.root's bytes on the right for a wrong root (TRUE, FALSE)"
else
    echo "FAIL  logossign root comparison (VM): rc=$(rc_of rootcmp) $rcres"; tail -2 "$T/rootcmp/err"; ok=0
fi

# ── 5. misuse halts loudly ────────────────────────────────────────────────
TSK=$(awk '$1 == "keygen" && $2 == 0 {print $6}' "$T/toy_vectors.txt")
misuse() {  # misuse LABEL MESSAGE COMMAND
    printf 'params toy\n%s\n' "$3" > "$T/mis.cmds"
    run_in mis drv.bin mis.cmds "$WM_VM_TIMEOUT"
    if [ "$(rc_of mis)" = 1 ] && grep -qxF "$2" "$T/mis/err" && [ ! -s "$T/mis/out" ]; then
        echo "PASS  logossign misuse (VM): $1 halts with '$2'"
    else
        echo "FAIL  logossign misuse (VM): $1: rc=$(rc_of mis) stdout=$(head -c 80 "$T/mis/out") stderr=$(head -c 160 "$T/mis/err")"; ok=0
    fi
}
C256=$(python3 -c "print(bytes((5 * j + 1) % 256 for j in range(256)).hex())")
misuse "sign with a ctx of 256 bytes" "logossign: sign: ctx must be at most 255 bytes" "sp m 6d $C256 $TSK -"
misuse "sign_internal with a 63-byte sk" "logossign: sign: sk must be 64 bytes" "si m 6d ${TSK:0:126} -"
misuse "sign with a 65-byte sk" "logossign: sign: sk must be 64 bytes" "sp m 6d - ${TSK}00 -"
misuse "sign with a 15-byte addrnd" "logossign: sign: addrnd must be empty or 16 bytes" "sp m 6d - $TSK a0a1a2a3a4a5a6a7a8a9aaabacadae"
misuse "sign_internal with a 17-byte addrnd" "logossign: sign: addrnd must be empty or 16 bytes" "si m 6d $TSK a0a1a2a3a4a5a6a7a8a9aaabacadaeafb0"
misuse "keygen_internal with a 15-byte SK.seed" "logossign: keygen: SK.seed, SK.prf and PK.seed must be 16 bytes each" "kg m 000102030405060708090a0b0c0d0e 101112131415161718191a1b1c1d1e1f 202122232425262728292a2b2c2d2e2f"

# ── 6. confine ────────────────────────────────────────────────────────────
mkdir -p "$T/cf" && cp "$T/logossign.la" "$T/cf/"
run_in cf cf.bin none.cmds "$WM_VM_TIMEOUT"
if [ "$(rc_of cf)" = 0 ] && [ "$(cat "$T/cf/out")" = ok ]; then
    echo "PASS  logossign confine (VM): confine(logossign.la)(nil) is ok: every name the module uses is a parameter or its own glyph; it imports nothing and names no builtin"
else
    echo "FAIL  logossign confine (VM): rc=$(rc_of cf) '$(head -c 200 "$T/cf/out")' $(tail -2 "$T/cf/err")"; ok=0
fi

wait "$lane_a"
results kg > "$T/kg.got"
if [ "$(rc_of kg)" = 0 ] && cmp -s "$T/kg.got" "$T/kg.exp"; then
    echo "PASS  logossign 128s keyGen (VM): KAT tcId $(grep '^kg ' "$T/kg.exp" | awk '{print substr($2, 3)}' | tr '\n' ' ')gives the NIST sk and pk byte for byte$( [ "$FULL" = 1 ] || echo " (all 10 in the full arm)")"
else
    echo "FAIL  logossign 128s keyGen (VM): rc=$(rc_of kg)"; diff "$T/kg.exp" "$T/kg.got" | cut -c1-160 | head -6; tail -3 "$T/kg/err"; ok=0
fi

# ── 7. position ───────────────────────────────────────────────────────────
# One timing program, compiled once, run as it is and with a 1 MB glyph in
# front of the module in the compiled stream, three times each, alternating.
# A toy verify is timed inside the program, best of 5, with clock_gettime
# bound to a parameter before the first clock read, so nothing between two
# reads names a glyph or a builtin. The hash under F is timed the same way.
POS_ARGS=$(cd "$T" && python3 -I - <<'PYEOF'
recs = [l.split() for l in open("toy_vectors.txt") if l.startswith("sign 0 pure-det 637478")]
r = [x for x in recs if len(x[5]) == 66][0]
pk = [l.split() for l in open("toy_vectors.txt") if l.startswith("keygen 0 ")][0][6]
pks = [l.split() for l in open("toy_vectors.txt") if l.startswith("keygen 0 ")][0][4]
print('(FROMHEX("%s"))(FROMHEX("%s"))(FROMHEX("%s"))(prefixed(concat(FROMHEX("%s"))(ZEROS(48))))(ZEROS(38))' % (r[5], r[6], pk, pks))
PYEOF
)
cat > "$T/pos.la" <<LAEOF
import("logoscrypt.la")
import("logossign.la")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph SEQ = la a. la b. b
glyph TSPLIT = Z(la go. la s. la acc. str_eq(str_head(s))(" ")(la _. la k. k(acc)(str_tail(s)))(la _. go(str_tail(s))(concat(acc)(str_head(s))))("!"))
glyph NS = la s. TSPLIT(s)("")(la a. la b. add(mul(str_to_int(a))(1000000000))(str_to_int(b)))
glyph KTIME = la cg. la f. (la t0. (la r. (la t1. la k. k(t0)(t1)(r))(cg("1")))(f("!")))(cg("1"))
glyph PBEST = Z(la go. la n. la cg. la f. la best. la res.
  int_eq(n)(0)(la _. la k. k(best)(res))
    (la _. KTIME(cg)(f)(la t0. la t1. la r.
             (la d. go(sub(n)(1))(cg)(f)(lt(d)(best)(la _. d)(la _. best)("!"))(r))(sub(NS(t1))(NS(t0)))))
    ("!"))
glyph SPAN = la f. la a. la b. (Z(la sp. la lo. la hi.
    lt(add(lo)(1))(hi)
      (la _. (la mid. concat(sp(lo)(mid))(sp(mid)(hi)))(div(add(lo)(hi))(2)))
      (la _. lt(lo)(hi)(la _. f(lo))(la _. "")("!"))
      ("!")))(a)(b)
glyph FROMHEX = la s. SPAN(la i. (la hv. chr(int_to_str(add(mul(hv(str_at(s)(mul(i)(2))))(16))(hv(str_at(s)(add(mul(i)(2))(1)))))))
                           (la c. (la n. lt(n)(58)(la _. sub(n)(48))(la _. sub(n)(87))("!"))(str_to_int(ord(c)))))(0)(div(str_to_int(str_len(s)))(2))
glyph ZEROS = Z(la go. la i. int_eq(i)(0)(la _. "")(la _. concat(chr("0"))(go(sub(i)(1))))("!"))
glyph MAIN =
 (la crypt. la pkit.
  SIGN_KIT(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(error)(add)(sub)(mul)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr)(crypt)(pkit)(SLH_TOY)
  (la kgi. la sgi. la vfi. la sgp. la vfp. la kg.
   pkit(la prefixed.
    (la cg. la m. la sig. la pk. la pf. la x.
      SEQ(SEQ(PBEST(5)(cg)(la _. vfp(m)(sig)("ctx")(pk)(la _. "1")(la _. "0")("!"))(999999999999999)("")(la ns. la r.
                print(concat(concat(concat("verify ")(int_to_str(div(ns)(1000))))(" "))(r))))
             (PBEST(25)(cg)(la _. pf(x))(999999999999999)("")(la ns. la r.
                print(concat("F ")(int_to_str(div(ns)(1000)))))))
         (print("end")))
    (clock_gettime)$POS_ARGS)))
 (CRYPT_FAST(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(error)(add)(sub)(mul)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr))
 (SHA256_PREFIX_KIT(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(error)(add)(sub)(mul)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr))
LAEOF
vm_compile pos.la pos.bin
python3 -c "import sys; d=open(sys.argv[1],'rb').read(); open(sys.argv[2],'wb').write(b'FILLER\x00\x01'+b'a'*1048576+b'\x00\x05'+d)" "$T/pos.bin" "$T/posf.bin"
prc=0
for i in 1 2 3; do
    run_in "pos_plain$i" pos.bin none.cmds "$WM_VM_TIMEOUT"; [ "$(rc_of pos_plain$i)" = 0 ] || prc=1
    run_in "pos_fill$i" posf.bin none.cmds "$WM_VM_TIMEOUT"; [ "$(rc_of pos_fill$i)" = 0 ] || prc=1
done
least() { cat "$T"/pos_$1[123]/out 2>/dev/null | awk -v op="$2" '$1 == op && (m == "" || $2 < m) {m = $2} END {print m}'; }
pbad=0
for d in "$T"/pos_plain[123] "$T"/pos_fill[123]; do
    [ "$(awk '$1 == "verify" {print $3} $1 == "end" {print}' "$d/out" 2>/dev/null | tr '\n' ' ')" = "1 end " ] || pbad=1
done
a=$(least plain verify); b=$(least fill verify)
if [ "$prc" = 0 ] && [ "$pbad" = 0 ] && [ -n "$a" ] && [ -n "$b" ] && [ "$a" -gt 0 ] && [ $((b * 100)) -le $((a * LOGOSSIGN_POS_BOUND)) ]; then
    echo "PASS  logossign position (VM): a toy verify takes $((b / 1000)) ms with a 1 MB glyph in front of the module and $((a / 1000)) ms without ($((b * 100 / a))%, at most ${LOGOSSIGN_POS_BOUND}%), TRUE both ways"
else
    echo "FAIL  logossign position (VM): rc=$prc wrong=$pbad without=${a:-?} us with=${b:-?} us (bound ${LOGOSSIGN_POS_BOUND}%)"; tail -2 "$T/pos_plain1/err" "$T/pos_fill1/err"; ok=0
fi
fcost=$(least plain F)

# ── 9. timing ─────────────────────────────────────────────────────────────
echo "INFO  logossign timing (VM): the hash under F (SHA256_PREFIX_KIT, one compression) ${fcost:-?} us (best of 25)"
echo "INFO  logossign timing (VM): toy keygen $(median_ms toy kg) ms, sign $(median_ms toy pure-det-s) ms (pure deterministic, median), verify $(median_ms toy pure-det-v) ms (median); the driver's times include decoding its hex arguments"
echo "INFO  logossign timing (VM): 128s keygen $(median_ms kg kg) ms (median of $(grep -c '^#T' "$T/kg/out" 2>/dev/null)), verify $(us_of v128 fresh-det | awk '{printf "%d", $1 / 1000}') ms (the fresh deterministic signature)"

# ── the full arm ──────────────────────────────────────────────────────────
if [ "$FULL" = 1 ]; then
    ( cd "$T" && python3 -I oracle.py katcmds slhdsa_kat_128s.txt kg2,kg3,kg4,kg5,sg276 fa.cmds fa.exp \
              && python3 -I oracle.py katcmds slhdsa_kat_128s.txt kg6,kg7,kg8,kg9,sg474 fb.cmds fb.exp ) || { echo "FAIL  logossign: full-arm commands"; exit 1; }
    run_in fa drv.bin fa.cmds "$LOGOSSIGN_TIMEOUT" &
    fpid=$!
    run_in fb drv.bin fb.cmds "$LOGOSSIGN_TIMEOUT"
    wait "$fpid"
    for x in fa fb; do results $x | awk '{if ($1 == "sih" || $1 == "sph") print $1, $2, $3, $4; else print}' > "$T/$x.got"; done
    if [ "$(rc_of fa)" = 0 ] && [ "$(rc_of fb)" = 0 ] && cmp -s "$T/fa.got" "$T/fa.exp" && cmp -s "$T/fb.got" "$T/fb.exp"; then
        echo "PASS  logossign full arm 128s keyGen (VM): KAT tcId 2..9 (with 1 and 10 above: all 10) give the NIST sk and pk byte for byte"
    else
        echo "FAIL  logossign full arm (VM): rc=$(rc_of fa)/$(rc_of fb)"; diff "$T/fa.exp" "$T/fa.got" | cut -c1-160 | head -4; diff "$T/fb.exp" "$T/fb.got" | cut -c1-160 | head -4; ok=0
    fi
    results fa > "$T/sg.out"; results fb >> "$T/sg.out"
    if [ "$(rc_of fa)" = 0 ] && [ "$(rc_of fb)" = 0 ] && [ "$(cd "$T" && python3 -I oracle.py sgcheck slhdsa_kat_128s.txt sg.out 2>&1)" = "ok 2" ] \
       && [ "$(awk '($1 == "sih" || $1 == "sph") {print $4}' "$T/sg.out" | tr '\n' ' ')" = "1 1 " ]; then
        echo "PASS  logossign full arm 128s sigGen (VM): KAT tcId 276 (internal, deterministic, shortest message) and 474 (pure, hedged, empty ctx) give the NIST signature (by sha256), and each verifies TRUE by the LA verify and by the model"
    else
        echo "FAIL  logossign full arm 128s sigGen (VM): $(cd "$T" && python3 -I oracle.py sgcheck slhdsa_kat_128s.txt sg.out 2>&1 | tail -1)"; ok=0
    fi
    echo "INFO  logossign timing (VM): 128s keygen $(median_ms fa kg) ms (median of tcId 2..5); sign tcId 276 $(us_of fa sg276 | awk '{printf "%d", $1 / 1000000}') s, tcId 474 $(us_of fb sg474 | awk '{printf "%d", $1 / 1000000}') s (each including the verify of the result)"
else
    echo "NOTE  logossign full arm skipped (LOGOSSIGN_FULL=1 runs the other 8 keyGen KATs and two 128s sigGen KATs, about 25 more minutes)"
fi
# ── 8. the C host (started after the oracle) ────────────────────────────────
if [ "$LOGOSSIGN_HOST" = 1 ]; then
    wait "$host_pid"
    hrc=$(cat "$T/hostw/rc" 2>/dev/null || echo none); host_e=$(cat "$T/hostw/end" 2>/dev/null || echo "$host_s")
    if [ "$hrc" = 0 ] && [ "$(cat "$T/hostw/out")" = "verify 1
ctx256 0
truncated 0
end" ]; then
        echo "PASS  logossign engines: the C host verifies a toy signature TRUE and refuses a 256-byte ctx and a truncated signature, as the VM does ($((host_e - host_s)) s of wall time on the host)"
    else
        echo "FAIL  logossign engines: host rc=$hrc '$(head -c 200 "$T/hostw/out")' $(tail -2 "$T/hostw/err" 2>/dev/null)"; ok=0
    fi
else
    echo "NOTE  logossign engines: the C host run skipped (LOGOSSIGN_HOST=0)"
fi
[ "$ok" = 1 ] || exit 1
