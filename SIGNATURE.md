# The signature layer — WOTS+, XMSS, and the index register

ROADMAP **G1** has carried *"**No signature scheme yet** — still the blocker for
signed updates and identity"* as the open half of KDF/MAC/signature. **G2** names
the choice: *"PQ or hash-based signatures for updates."* This layer is that half.

It is four modules and four gates:

| module | what it is | status |
|---|---|---|
| `wotsp.la` / `wotsp_prod.la` | WOTS+ — a **one-time** signature | code green on both engines at n=2 w=4; n=32 w=16 on the VM only |
| `xmss.la` | XMSS — a Merkle tree over 2^h WOTS+ keys, so **many-time** | code green on both engines at n=2 w=4 h=2 |
| `xmssidx.la` | the **durable leaf-index register** — the stateful half | code green on both engines, exhaustion + resume witnessed |
| `xmss_signer.la` | the **join**: signing with the index guard wired in | host leg green from a manual run; **host==VM UNWITNESSED**; gated only as of `gate_xmss_signer.sh`, which has not yet run for real |

This document states what the layer does **not** give you. Everything below is a
real bound, not a caveat added for modesty.

---

## 1. The vectors are not a known answer

`gate_sha256.sh` can say *"a digest is a known answer or it is nothing"* because
NIST published the answer. **This layer cannot say that.**

There is no published third-party vector for this construction — RFC 8391 §3.1
(base_w, checksum, shift, chain) with the SPHINCS+ *simple* tweakable hash, where
chain step *j* of chain *i* is domain-separated by the pair `(i,j)` rather than by
RFC 8391's per-step bitmasks. That substitution is deliberate and is stated in
`wotsp.la`, in `wotsp_model.py`, and in the gate.

So the expected values are **cross-implementation agreement** between the LA
module and an independent Python model written before it. Two implementations by
one author agreeing is **weaker than a known answer**, and no PASS line in this
layer should be read as though it were one.

What makes it more than self-consistency:

* it stands on `sha256.la`, which **is** known-answer verified against NIST
  vectors on two engines;
* the expectations are **model-derived, not captured** — `wotsp_model.py` run
  standalone prints `PK = 150b`, `sig(m1)[0] = e829` at n=2 w=4 and
  `bb4ae2…a62a` / `2ecad0…2ca9` at n=32 w=16, which are exactly the literals
  `wotsp.la` and `wotsp_prod.la` hold. A captured expectation can go red, but
  never for the bug it captured; these did not come from an LA run.

**The honest way to close this gap** is a full RFC 8391 XMSS known-answer test.
That is named here rather than implied, and it is not built.

## 2. The parameters that carry host==VM are a TOY

A SHA-256 call costs **6.5 s** on the C host and **0.31 s** on the native SECD
VM (measured 2026-08-23) — 21×. A full WOTS+ keygen at n=32 is 1073 hashes, so
the production parameter set cannot run on the host at all.

The split is therefore:

* **n=2 w=4** — C host **and** native VM, byte-identical. This is a **code-path**
  witness at **16 bits of hash**, breakable by hand. It is not a security claim.
* **n=32 w=16** — native VM only, `wotsp_prod.la`. The code is *identical*; the
  only difference is `WOTS_MKP(2)(4)` vs `WOTS_MKP(32)(16)`.

So **no parameter set has both real security and host==VM byte-identity.** The
security level and the two-engine witness are carried by different legs, and the
gate's PASS line says which one ran.

XMSS is worse: one leaf is a full WOTS+ keygen, ~31 min per leaf at n=32 on the
VM, ~2 h for a height-2 tree before anything is signed. `xmss.la` witnesses
**n=2 w=4 h=2** — four leaves, four signatures. What is witnessed is that the
**construction** is right, not that these parameters are safe.

## 3. XMSS is STATEFUL — a reused index is a broken key

Each leaf holds a one-time key. Signing twice under one leaf **leaks that leaf's
secret**, and an attacker holding two signatures from one index can forge. The
index is not bookkeeping; it is part of the private key.

★ This is the one defect class a signature gate cannot see by accident.
`gate_xmss.sh` is green on nine checks and would stay green forever with **no
index tracking at all**, because nothing in a test reuses an index. The failure
is not a wrong answer — it is a correct answer given twice.

`xmssidx.la` is the repair, and `gate_xmssidx.sh` exhausts, removes state, and
crosses a process boundary on purpose. What it still does **not** give you:

* **No fsync.** `write_file` is the only primitive on both engines, so the write
  reaches the OS but not provably the platter. A power loss can move the register
  **backwards** — the direction that breaks the key.
* **Single-writer only.** Two concurrent signers are not defended against.
* **`XMSS_SIGN` is still unguarded.** It takes an explicit index, so a caller can
  bypass the register entirely. `xmss_signer.la`'s `SIGN_GUARDED` is the safe
  path — it takes a state path and **no index** — and is now exported, so it is
  reachable by import. `XMSS_SIGN` remains exported alongside it, so the unsafe
  entry point is still available to a caller who reaches for it; the guard is the
  discipline of going through `SIGN_GUARDED`, not a type-level impossibility.
* **A missing state file halts, by design.** `read_file` on an absent path exits
  loudly, and that is correct: a register that created its file on first read
  would silently restart at 0 and reuse every index if the file were ever lost or
  restored from an old backup.

## 4. What is not witnessed, named rather than dropped

* **`gate_wotsp.sh` had never executed as a script** at the time this document
  was written. Its legs each passed on 2026-08-23 with the identical command
  sequence, and the session that ran them correctly declined to call that "the
  gate passed." **A gate that has never run is not a gate.**
* **`xmss_signer.la` host==VM is UNWITNESSED.** The host leg is green (93 min);
  the VM leg was killed mid-codegen. The green host leg does not stand in for it.
* **The n=32 w=16 arm is OFF by default** (`WOTSP_FULL=1`, ~2 h 15). The gate
  says so in its own PASS line, because a skip that is not announced reads as
  coverage.
* **★ "wrong-PK rejected" cannot fail for the reason it claims.** In `wotsp.la`,
  `wotsp_prod.la` and `xmss.la`, that control asserts `pkA != FLIPS(pk)` while a
  neighbouring check already asserts `pkA == pk`. Given the second, the first
  reduces to `pk != FLIPS(pk)` — true by construction of `FLIPS`, which XORs one
  bit. It exercises `bxor` and `str_eq`, **not** the verifier. This is structural,
  not a transcription slip: verification is deliberately kept *out* of these
  modules (`WOTS_PKFROMSIG` returns a recomputed key, and the caller compares),
  so "the verifier reads the public key" is not a property these modules can
  fail. The other negative controls — a different message signs differently, a
  wrong message rejects, a flipped signature bit rejects, a wrong leaf index
  rejects, a corrupt auth path rejects — **do** discriminate, and each depends on
  the hash actually being used. The count of genuinely discriminating negative
  controls is therefore **three** in `wotsp.la`, not four, and **four** in
  `xmss.la`, not five.
* **★ XMSS signing costs 2× what it needs to.** `XMSS_SIGN` (`xmss.la:146-149`)
  re-derives a leaf key with `FST(WOTS_KEYGEN(...))`, but the language is
  call-by-value — a fact this layer relies on elsewhere, in `xmss_signer.la`'s
  write-ahead ordering — so `PAIR(sk)(H_PK(...))` evaluates the public-key half
  before `FST` can discard it. Measured on the model, which has the identical
  shape: **66 hashes per signature against 32** for the secret chain-starts
  alone — 2.06× at n=2 w=4, ~2.8× at n=32 w=16 (~46 min versus ~16 min per
  signature on the VM). It is not a correctness defect — every vector is
  unaffected — and the fix costs no vector either: derive the chain-starts
  without the compression step. Not applied here; it touches `wotsp.la`'s export
  list, which this layer deliberately kept frozen.
* **The cost figures the models print are each low by one or two hashes.** Both
  `wotsp_model.py` and `xmss_model.py` omit the public-key compression call, and
  the sign/verify figures also omit the message hash. Measured against counted
  SHA-256 calls: WOTS+ n=2 w=4 keygen **45** not 44, sign **19** not 18, verify
  **17** not 15; n=32 w=16 keygen **1073** not 1072; XMSS n=2 w=4 h=2 keygen
  **191** not 187. The 1072 figure is the one quoted in `xmss.la`'s header and
  used to derive the ~31 min/leaf estimate that justifies the toy parameters —
  0.1% low, so **that decision is unaffected**. Recorded as an inaccurate stated
  measurement, not as a reason to revisit anything.
* **✅ FIXED — `xmss_signer.la` exported nothing, so `SIGN_GUARDED` could not be
  imported.** The module had no `export` line, and `tiny_host.c`'s
  `mangle_privates` renames every glyph of a module whose export set is empty, so
  an importer saw none of `SIGN_GUARDED`, `SIG_IDX`, `SIG_WOTS`, `SIG_AUTH`. The
  consequence inverted the layer's intent: the only importable signing entry point
  was `xmss.la`'s unguarded `XMSS_SIGN`. Nothing caught it because nothing imports
  this module — it is only ever run top-level, the one case the mangling does not
  touch, so the absence was invisible to every existing gate.
  **`export SIGN_GUARDED SIG_IDX SIG_WOTS SIG_AUTH` now leads the file**, and the
  fix cannot change what the module does: `mangle_privates` is called only from
  `do_import` (`tiny_host.c:942`), `codegen.la` applies `MANGLE_MODULE` only on
  its import arm (`codegen.la:167`) while the top level takes
  `FST(PARSE_MODULE(s))` and discards the export list (`:179`), and `export`
  emits no glyph. Witnessed rather than argued: compiling a same-shaped tiny
  module with and without an export line gives a **byte-identical**
  `logos_program.bin` (`c9554f11…`), while a one-word body change to the same
  module does differ — so the comparison is live. `E_SIGNER` is therefore
  unaffected. `gate_xmss_signer.sh` now guards it in **both** directions: the four
  API glyphs import, and the witness helper `VER` stays unbound — because a check
  that only asserted visibility would also pass if the export mechanism broke open
  and exposed everything, which is a different bug, not a fix.
* **`gate_xmss_signer.sh` now exists, and has never been run.** Until it was
  written the layer had three gates and none of them ran `xmss_signer.la`: the
  host result (all six checks OK, 5581 s, in `.signer_host.log`) was a **manual
  run**, and `.signer_vm.log` ends at `secd built`. The gate derives `E_SIGNER`
  from the module's own concat nesting, bounds and separately names each stage
  (secd emit / codegen / run) so a red cannot be attributed to the wrong one, and
  runs the VM leg first because the host cost is measured and the VM cost is not.
  **Its red paths were mutation-tested against stubs** — wrong VM output, wrong
  host output, a failed emit, a nonzero codegen, an empty `logos_program.bin`,
  and the VM-only variant each produce their own named FAIL and rc 1. That
  establishes the gate can fail; it says nothing yet about `xmss_signer.la`,
  which still awaits a real run on both engines.
* **★ The `host != VM` line in four shipped gates cannot fail.**
  `gate_sha256.sh:41`, `gate_wotsp.sh:94`, `gate_xmss.sh:79` and
  `gate_xmssidx.sh:123` each check `HOSTOUT` against an expected constant, check
  `VMOUT` against **the same** constant, and then check the two against each
  other. The third comparison is implied by the first two — if both equal `E`
  they equal each other — so it can never go red on its own, while its comment
  claims it catches "each engine wrong its own way." It cannot; that case is
  caught by the value checks. This is the same shape as the `wrong-PK` control
  above, in the gates rather than the modules. `gate_xmss_signer.sh` avoids it by
  checking the host against the derived expectation and the **VM against the
  host**, which keeps identical total strength while making every line live.
* **`sigs differ` does not witness what it is labelled.** In `xmss.la` it compares
  leaf 0/M1 against leaf 2/M2, and in `xmss_signer.la` leaf 0/M1 against leaf
  1/M2 — leaf and message vary together, so the check cannot separate them. It is
  not vacuous (a signer that ignored the message entirely would fail it, which is
  the chacha20 shape), but "the leaves are genuinely independent" is carried by
  the *other* checks — `leaf2 verifies vs SAME root` and `wrong leaf idx
  rejected` — not by this one.

## 5. Two guarantees that are stronger than they look

Both were checked against the engines rather than taken from the modules' prose.

* **The write-ahead ordering is real, not a convention.** `IDX_RESERVE` persists
  the advanced index with `SEQ(write_file(...))(i)`, and `SIGN_GUARDED` obtains
  its index as `(la idx. ...)(IDX_RESERVE(...))`. Both rest on call-by-value, and
  the evaluator does behave that way: `tiny_host.c:864-870` evaluates the operator,
  then the operand, then substitutes — so the durable write completes before any
  signing. A crash after the write **loses** a slot; it never reuses one.
* **"Missing state restarts at 0" is guarded twice.** `read_file` on an absent
  path exits 1 on the host (`tiny_host.c:597`), and — the deeper guard —
  `str_to_int("")` also exits 1 on **both** engines rather than yielding 0. On the
  native VM that is not original behaviour: `rt_str_to_int` once folded every byte
  through `(c-'0')`, so `""` became `0`, and freeze-day #4 fixed it
  (`native_codegen3_rt.asm:1596`). Had it not been, a lost state file on the VM
  would have silently restarted the register at 0 and reused every index — the
  exact catastrophe `xmssidx.la` exists to prevent, reached through a runtime
  divergence rather than through anything in this layer.

## 6. What the layer is one-time about

`wotsp.la` is a **one-time** signature and says so. The many-time construction is
`xmss.la`, and it is bounded at 2^h signatures — after that the key is spent and
`IDX_RESERVE` refuses with a nonzero exit rather than wrapping to 0 and leaking
every leaf secret. A spent key is spent; there is no rekey path in this layer.

---

*Cost, measured rather than estimated (2026-08-23): host n=2 w=4 — 1861 s;
VM n=2 w=4 — 209 s codegen + ~1 min run; VM n=32 w=16 — 1340 s codegen +
4549 s run. ★ An extrapolation from the per-hash bench predicted 13 min for the
n=32 leg. It took 76. The chain input at n=32 is 59 bytes, which pads to two
SHA-256 blocks, and `sha256.la`'s byte access is quadratic within a block. The
estimate was wrong by 6× and is recorded rather than quietly replaced.*
