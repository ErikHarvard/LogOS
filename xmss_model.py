#!/usr/bin/env python3
"""
xmss_model.py -- an INDEPENDENT model of the XMSS many-time signature scheme,
written before a line of xmss.la, to generate the vectors that module must match.

WHAT THIS ADDS OVER wotsp_model.py, AND WHY IT IS THE POINT
WOTS+ is ONE-TIME: two signatures under one key leak it, so it cannot sign
software updates, which is what ROADMAP G1 actually needs.  XMSS makes it
many-time the only way a hash-based scheme can: build a Merkle tree over 2^h
independent WOTS+ key pairs, publish the ROOT as the single public key, and let
each signature carry the authentication path proving its leaf hangs under that
root.  One small public key; 2^h signatures.

★ THE DESIGN DECISION THAT KEPT wotsp.la UNTOUCHED
Every leaf needs its own WOTS+ key, and -- this is the security-critical part --
its own CHAIN DOMAIN.  If two leaves shared the (i, j) tweak that separates
chain steps, an attacker could splice chain values between leaves.  The obvious
fix is to add a leaf-index argument to WOTS+'s hashes, but that would change
every vector in wotsp.la and force a re-run of legs that cost 2 h 15 min to
witness.  Instead each leaf gets a DERIVED seed pair:

    sk_seed_L = H(4 || master_sk_seed || u32(L))
    pk_seed_L = H(5 || master_pk_seed || u32(L))

Since pk_seed_L already enters every H_F call, distinct leaves get distinct
chain domains for free, and wotsp.la is called completely unmodified.  The
verifier can derive pk_seed_L itself: master_pk_seed is public and L travels in
the signature.  Two extra hashes per leaf buys a layer with no edit below it.

WHY THE PARAMETERS ARE SMALL, STATED PLAINLY
One leaf is a full WOTS+ keygen.  At n=32 w=16 that is 1072 hashes, and the
measured rate on the native SECD VM is ~1.75 s/hash for this input size, so a
SINGLE leaf costs ~31 min and a height-2 tree ~2 h before any signing.  That is
out of reach of this substrate today.  So the witnessed parameters are n=2 w=4
h=2 -- four leaves, four signatures -- which exercises every code path (two
tree levels, both sibling directions) at a security level that is a TOY and is
not offered as anything else.  What is being witnessed is that the CONSTRUCTION
is right, not that these parameters are safe.

THE CHECKS THAT CAN ACTUALLY FAIL
The headline claim of XMSS is many-time-ness, so the headline check is that two
signatures under DIFFERENT leaves both verify against the SAME root.  A tree
that ignored its leaf index would still pass a single-signature test.  Beyond
that, each negative names a specific thing the verifier must read:
    sig(leaf 0) and sig(leaf 2) both verify   -- many-time, the whole point
    the two signatures differ                 -- leaves are independent
    wrong leaf index rejects                  -- the index is authenticated
    corrupted auth path rejects               -- the path is authenticated
    wrong message rejects                     -- the message is authenticated
    one flipped bit in the root rejects       -- the root is authenticated
"""

from wotsp_model import WOTS, u32be, hx

D_SKL, D_PKL, D_NODE = b"\x04", b"\x05", b"\x06"


class XMSS:
    def __init__(self, n, w, h):
        self.n, self.h = n, h
        self.leaves = 1 << h
        self.w = WOTS(n, w)

    def _trunc(self, b):
        import hashlib
        return hashlib.sha256(b).digest()[: self.n]

    # -- per-leaf seed derivation: the whole reason wotsp.la needs no edit ----
    def leaf_seeds(self, sk_seed, pk_seed, leaf):
        return (self._trunc(D_SKL + sk_seed + u32be(leaf)),
                self._trunc(D_PKL + pk_seed + u32be(leaf)))

    def node(self, pk_seed, height, index, left, right):
        """Hash two children into a parent.

        height and index are in the tweak so that a node cannot be replayed at
        a different position in the tree -- without them an attacker could
        present an internal node as a leaf.
        """
        return self._trunc(D_NODE + pk_seed + u32be(height) + u32be(index) + left + right)

    def leaf(self, sk_seed, pk_seed, l):
        skl, pkl = self.leaf_seeds(sk_seed, pk_seed, l)
        _, pk = self.w.keygen(skl, pkl)
        return pk

    def keygen(self, sk_seed, pk_seed):
        level = [self.leaf(sk_seed, pk_seed, l) for l in range(self.leaves)]
        tree = [level]
        for ht in range(1, self.h + 1):
            level = [self.node(pk_seed, ht, i, level[2 * i], level[2 * i + 1])
                     for i in range(len(level) // 2)]
            tree.append(level)
        return tree, level[0]          # (whole tree, root)

    def auth_path(self, tree, leaf):
        """The h siblings needed to walk `leaf` up to the root."""
        path, idx = [], leaf
        for ht in range(self.h):
            path.append(tree[ht][idx ^ 1])   # the sibling
            idx >>= 1
        return path

    def sign(self, sk_seed, pk_seed, tree, leaf, msg):
        skl, pkl = self.leaf_seeds(sk_seed, pk_seed, leaf)
        sk, _ = self.w.keygen(skl, pkl)
        return (leaf, self.w.sign(sk, pkl, msg), self.auth_path(tree, leaf))

    def root_from_sig(self, pk_seed, sig, msg):
        leaf, wsig, path = sig
        # pk_seed_L comes from the PUBLIC master seed and the leaf index that
        # travels in the signature, so a verifier derives it with no secret.
        pkl = self._trunc(D_PKL + pk_seed + u32be(leaf))
        node = self.w.pk_from_sig(wsig, pkl, msg)
        idx = leaf
        for ht in range(self.h):
            sib = path[ht]
            if idx & 1:
                node = self.node(pk_seed, ht + 1, idx >> 1, sib, node)
            else:
                node = self.node(pk_seed, ht + 1, idx >> 1, node, sib)
            idx >>= 1
        return node

    def verify(self, pk_seed, root, sig, msg):
        return self.root_from_sig(pk_seed, sig, msg) == root


SK_SEED = b"logos-xmss-sk-seed"
PK_SEED = b"logos-xmss-pk-seed"
M1 = b"the first message"
M2 = b"the second message"


def report(n, w, h):
    x = XMSS(n, w, h)
    tree, root = x.keygen(SK_SEED, PK_SEED)

    s0 = x.sign(SK_SEED, PK_SEED, tree, 0, M1)
    s2 = x.sign(SK_SEED, PK_SEED, tree, 2, M2)

    print(f"=== XMSS  n={n} w={w} h={h}  leaves={x.leaves} ===")
    print(f"  root        = {hx(root)}")
    print(f"  leaf0       = {hx(tree[0][0])}")
    print(f"  auth(0)     = {[hx(a) for a in s0[2]]}")
    print(f"  auth(2)     = {[hx(a) for a in s2[2]]}")
    per_leaf = x.w.len + x.w.len * (w - 1) + 2
    print(f"  hashes: keygen~{per_leaf * x.leaves + x.leaves - 1}  "
          f"(per leaf {per_leaf}, {x.leaves} leaves, {x.leaves-1} nodes)")

    checks = [("leaf0 sig verifies vs root", x.verify(PK_SEED, root, s0, M1) is True),
              ("leaf2 sig verifies vs SAME root", x.verify(PK_SEED, root, s2, M2) is True),
              ("the two signatures differ", s0[1] != s2[1])]

    # wrong leaf index: claim leaf 1 for a leaf-0 signature
    checks.append(("wrong leaf index rejected",
                   x.verify(PK_SEED, root, (1, s0[1], s0[2]), M1) is False))
    # corrupted auth path: flip one bit of the first sibling
    bad = list(s0[2]); bad[0] = bytes([bad[0][0] ^ 1]) + bad[0][1:]
    checks.append(("corrupt auth path rejected",
                   x.verify(PK_SEED, root, (0, s0[1], bad), M1) is False))
    checks.append(("wrong message rejected",
                   x.verify(PK_SEED, root, s0, M2) is False))
    badroot = bytes([root[0] ^ 1]) + root[1:]
    checks.append(("wrong root rejected",
                   x.verify(PK_SEED, badroot, s0, M1) is False))

    for name, got in checks:
        print(f"  [{'OK  ' if got else 'FAIL'}] {name}")
    print()
    return all(g for _, g in checks)


if __name__ == "__main__":
    ok = report(2, 4, 2)
    print("MODEL", "OK" if ok else "FAIL")
    raise SystemExit(0 if ok else 1)
