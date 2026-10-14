"""check_acvp.py -- run slhdsa_model.py against NIST ACVP SLH-DSA vectors.

Usage (run with python3 -I; the vector files are untrusted DATA, only parsed
with json / str.split, never executed):

  python3 -I check_acvp.py ACVP_DL_DIR KAT_FILE [--jobs N] [--sets a,b,...]
                           [--counts-only]

ACVP_DL_DIR holds SLH-DSA-{keyGen,sigGen,sigVer}-FIPS205/internalProjection.json.
Every test of every group whose parameter set the model implements is run, for
the internal and external/pure interfaces; preHash groups are skipped and counted.
sigGen compares the full signature bytes; sigVer compares the accept/reject bit.
KAT_FILE is slhdsa_kat_128s.txt (format in its header).
"""

import hashlib
import json
import multiprocessing
import os
import sys
import time
from collections import OrderedDict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import slhdsa_model as M  # noqa: E402


def h2b(x):
    return bytes.fromhex(x) if x not in ("", "-") else b""


# ---------------------------------------------------------------------------
# One test case -> (bucket, tcId, ok, note).  Runs in a worker.

def run_case(task):
    kind = task["kind"]
    ps = task["ps"]
    s = M.get(ps)
    t0 = time.time()
    if kind == "keyGen":
        sk, pk = s.slh_keygen_internal(h2b(task["skSeed"]), h2b(task["skPrf"]), h2b(task["pkSeed"]))
        ok = sk == h2b(task["sk"]) and pk == h2b(task["pk"])
        note = ""
    elif kind == "sigGen":
        sk = h2b(task["sk"])
        msg = h2b(task["message"])
        ar = None if task["det"] else h2b(task["addrnd"])
        if task["iface"] == "internal":
            sig = s.slh_sign_internal(msg, sk, ar)
        else:
            sig = s.slh_sign(msg, h2b(task["context"]), sk, ar)
        if "signature" in task:
            ok = sig == h2b(task["signature"])
        else:
            ok = hashlib.sha256(sig).hexdigest() == task["sig_sha256"]
        note = "" if ok else "signature mismatch"
    elif kind == "sigVer":
        pk = h2b(task["pk"])
        msg = h2b(task["message"])
        sig = h2b(task["signature"])
        if task["iface"] == "internal":
            got = s.slh_verify_internal(msg, sig, pk)
        else:
            got = s.slh_verify(msg, sig, h2b(task["context"]), pk)
        ok = (got is True) == task["expect"]
        note = "" if ok else "verify returned %r, expected %r (%s)" % (got, task["expect"], task["reason"])
    else:
        raise ValueError(kind)
    return (task["bucket"], task["tcId"], ok, note, time.time() - t0)


def cost(task):
    """Rough relative cost, so the slow 's' signatures start first."""
    p = M.PARAMS[task["ps"]]
    if task["kind"] == "sigGen":
        return p.d * (1 << p.hp) * p.len * p.w + p.k * (1 << p.a) * 2
    if task["kind"] == "keyGen":
        return (1 << p.hp) * p.len * p.w
    return p.d * p.len * p.w


# ---------------------------------------------------------------------------

def load_acvp(dl, sets):
    tasks = []
    skipped = OrderedDict()   # (file, reason) -> [groups, tests]
    def skip(fn, why, ntests):
        e = skipped.setdefault((fn, why), [0, 0])
        e[0] += 1
        e[1] += ntests

    fn = "SLH-DSA-keyGen-FIPS205"
    j = json.load(open(os.path.join(dl, fn, "internalProjection.json")))
    for tg in j["testGroups"]:
        ps = tg["parameterSet"]
        if ps not in sets:
            skip(fn, "parameter set not selected", len(tg["tests"]))
            continue
        for t in tg["tests"]:
            tasks.append({"kind": "keyGen", "ps": ps, "bucket": ("keyGen", ps, "-", "-"),
                          "tcId": t["tcId"], "skSeed": t["skSeed"], "skPrf": t["skPrf"],
                          "pkSeed": t["pkSeed"], "sk": t["sk"], "pk": t["pk"]})

    fn = "SLH-DSA-sigGen-FIPS205"
    j = json.load(open(os.path.join(dl, fn, "internalProjection.json")))
    for tg in j["testGroups"]:
        ps = tg["parameterSet"]
        if tg["preHash"] == "preHash":
            skip(fn, "preHash (HashSLH-DSA, not implemented)", len(tg["tests"]))
            continue
        if ps not in sets:
            skip(fn, "parameter set not selected", len(tg["tests"]))
            continue
        iface = tg["signatureInterface"]
        det = tg["deterministic"]
        assert (iface, tg["preHash"]) in (("internal", "none"), ("external", "pure"))
        for t in tg["tests"]:
            tasks.append({"kind": "sigGen", "ps": ps,
                          "bucket": ("sigGen", ps, iface if iface == "internal" else "pure",
                                     "det" if det else "hedged"),
                          "tcId": t["tcId"], "iface": iface, "det": det,
                          "sk": t["sk"], "message": t["message"],
                          "context": t.get("context", ""),
                          "addrnd": t.get("additionalRandomness", ""),
                          "signature": t["signature"]})

    fn = "SLH-DSA-sigVer-FIPS205"
    j = json.load(open(os.path.join(dl, fn, "internalProjection.json")))
    for tg in j["testGroups"]:
        ps = tg["parameterSet"]
        if tg["preHash"] == "preHash":
            skip(fn, "preHash (HashSLH-DSA, not implemented)", len(tg["tests"]))
            continue
        if ps not in sets:
            skip(fn, "parameter set not selected", len(tg["tests"]))
            continue
        iface = tg["signatureInterface"]
        assert (iface, tg["preHash"]) in (("internal", "none"), ("external", "pure"))
        for t in tg["tests"]:
            tasks.append({"kind": "sigVer", "ps": ps,
                          "bucket": ("sigVer", ps, iface if iface == "internal" else "pure",
                                     "accept" if t["testPassed"] else "reject"),
                          "tcId": t["tcId"], "iface": iface, "expect": bool(t["testPassed"]),
                          "reason": t["reason"], "pk": t["pk"], "message": t["message"],
                          "context": t.get("context", ""), "signature": t["signature"]})
    return tasks, skipped


def load_kat(path):
    tasks = []
    ps = "SLH-DSA-SHA2-128s"
    for line in open(path):
        line = line.rstrip("\n")
        if not line or line.startswith("#"):
            continue
        f = line.split(" ")
        if f[0] == "keygen":
            _, tc, sks, skp, pks, sk, pk = f
            tasks.append({"kind": "keyGen", "ps": ps, "bucket": ("KAT keygen", ps, "-", "-"),
                          "tcId": int(tc), "skSeed": sks, "skPrf": skp, "pkSeed": pks,
                          "sk": sk, "pk": pk})
        elif f[0] == "siggen":
            _, tc, iface, mode, sk, pk, ar, ctx, msg, sh = f
            tasks.append({"kind": "sigGen", "ps": ps,
                          "bucket": ("KAT siggen", ps, iface, mode),
                          "tcId": int(tc), "iface": "internal" if iface == "internal" else "external",
                          "det": mode == "det", "sk": sk, "message": msg, "context": ctx,
                          "addrnd": ar, "sig_sha256": sh})
        elif f[0] == "sigver":
            _, tc, iface, exp, pk, ctx, msg, sig, reason = f
            tasks.append({"kind": "sigVer", "ps": ps,
                          "bucket": ("KAT sigver", ps, iface, "accept" if exp == "1" else "reject"),
                          "tcId": int(tc), "iface": "internal" if iface == "internal" else "external",
                          "expect": exp == "1", "reason": reason, "pk": pk, "message": msg,
                          "context": ctx, "signature": sig})
        else:
            raise ValueError("unknown KAT record: %s" % f[0])
    return tasks


# ---------------------------------------------------------------------------
# Hash-call counts and the midstate cross-check.

def count_ops(name, sk_seed, sk_prf, pk_seed, msg, ctx):
    s = M.get(name)
    s.reset_counts()
    sk, pk = s.slh_keygen_internal(sk_seed, sk_prf, pk_seed)
    kg = dict(s.counts)
    s.reset_counts()
    sig = s.slh_sign(msg, ctx, sk)
    sg = dict(s.counts)
    s.reset_counts()
    ok = s.slh_verify(msg, sig, ctx, pk)
    vf = dict(s.counts)
    return kg, sg, vf, ok, s.p


def fmt_counts(c):
    tot = sum(c.values())
    return "F=%d H=%d T_l=%d PRF=%d PRF_msg=%d H_msg=%d total=%d" % (
        c["F"], c["H"], c["T"], c["PRF"], c["PRF_msg"], c["H_msg"], tot)


def midstate_crosscheck():
    """midstate=True and midstate=False must give the same bytes."""
    out = []
    for name in ("TOY-SHA2", "SLH-DSA-SHA2-128f", "SLH-DSA-SHA2-192f", "SLH-DSA-SHA2-256f"):
        a, b = M.get(name, True), M.get(name, False)
        n = a.p.n
        seeds = (bytes(range(n)), bytes(range(n, 2 * n)), bytes(range(2 * n, 3 * n)))
        ka, kb = a.slh_keygen_internal(*seeds), b.slh_keygen_internal(*seeds)
        sa = a.slh_sign(b"midstate", b"x", ka[0])
        sb = b.slh_sign(b"midstate", b"x", kb[0])
        out.append((name, ka == kb and sa == sb and b.slh_verify(b"midstate", sa, b"x", kb[1])))
    return out


def main():
    args = sys.argv[1:]
    jobs = 4
    sets = list(M.PARAMS.keys())
    counts_only = False
    pos = []
    i = 0
    while i < len(args):
        if args[i] == "--jobs":
            jobs = int(args[i + 1]); i += 2
        elif args[i] == "--sets":
            sets = args[i + 1].split(","); i += 2
        elif args[i] == "--counts-only":
            counts_only = True; i += 1
        else:
            pos.append(args[i]); i += 1
    dl, kat = pos

    print("model: %s" % os.path.abspath(M.__file__))
    for name in sets:
        print("  %r" % M.PARAMS[name])
    print("  %r" % M.TOY_SHA2)
    p = M.TOY_SHA2
    print("toy m check: ceil(k*a/8)=%d + ceil((h-h/d)/8)=%d + ceil((h/d)/8)=%d = %d (m=%d)"
          % (p.md_bytes, p.tree_bytes, p.leaf_bytes, p.m_formula, p.m))

    print("midstate cross-check (midstate on == literal formula):")
    mid_fails = []
    for name, ok in midstate_crosscheck():
        print("  %-20s %s" % (name, "same" if ok else "DIFFERENT"))
        if not ok:
            mid_fails.append(name)

    print("hash calls per operation (keygen / pure sign, deterministic / pure verify):")
    for name, n in (("SLH-DSA-SHA2-128s", 16), ("SLH-DSA-SHA2-128f", 16), ("TOY-SHA2", 16)):
        seeds = (bytes(range(n)), bytes(range(n, 2 * n)), bytes(range(2 * n, 3 * n)))
        kg, sg, vf, ok, pp = count_ops(name, *seeds, msg=b"count", ctx=b"")
        print("  %s (msg 'count', ctx empty, seeds 00..2f), verify=%s" % (name, ok))
        print("    keygen: %s" % fmt_counts(kg))
        print("    sign:   %s" % fmt_counts(sg))
        print("    verify: %s" % fmt_counts(vf))
    if counts_only:
        return 0 if not mid_fails else 1

    t0 = time.time()
    tasks, skipped = load_acvp(dl, set(sets))
    kat_tasks = load_kat(kat)
    print("loaded %d ACVP cases + %d KAT records in %.1fs" % (len(tasks), len(kat_tasks), time.time() - t0))
    for (fn, why), (g, n) in skipped.items():
        print("  skipped %s: %d groups, %d tests (%s)" % (fn, g, n, why))

    alltasks = tasks + kat_tasks
    alltasks.sort(key=cost, reverse=True)
    results = OrderedDict()
    fails = [("midstate", name, "midstate and literal formula DIFFERENT") for name in mid_fails]
    t0 = time.time()
    with multiprocessing.Pool(jobs) as pool:
        for (bucket, tc, ok, note, dt) in pool.imap_unordered(run_case, alltasks, chunksize=1):
            r = results.setdefault(bucket, [0, 0, 0])
            r[0] += 1
            r[1 if ok else 2] += 1
            if not ok:
                fails.append((bucket, tc, note))
    print("ran %d cases in %.1fs with %d workers" % (len(alltasks), time.time() - t0, jobs))

    order = {"keyGen": 0, "sigGen": 1, "sigVer": 2, "KAT keygen": 3, "KAT siggen": 4, "KAT sigver": 5}
    print("%-11s %-20s %-9s %-7s %5s %5s %5s" % ("mode", "parameterSet", "interface", "variant", "run", "pass", "fail"))
    tot = [0, 0, 0]
    for b in sorted(results, key=lambda b: (order[b[0]], b[1], b[2], b[3])):
        r = results[b]
        print("%-11s %-20s %-9s %-7s %5d %5d %5d" % (b[0], b[1], b[2], b[3], r[0], r[1], r[2]))
        for x in range(3):
            tot[x] += r[x]
    print("TOTAL run=%d pass=%d fail=%d" % tuple(tot))
    for f in fails:
        print("FAIL", f)
    return 0 if not fails else 1


if __name__ == "__main__":
    sys.exit(main())
