# Scope — the unattended self-extension loop

**2026-08-24. A scoping document, not a build.** Everything in §1 was measured
against the repository today, not recalled.

The ledger calls this the most consequential `[A]` it carries, and adds that
*the temptation to declare it closed will be strong*. So this document spends
more space on **how it could look closed without being closed** (§4) than on how
to build it (§5). That ordering is deliberate: the failure modes here are all of
the shape this project keeps finding — an instrument that agrees with the
hypothesis under test.

---

## §1 — WHAT EXISTS, MEASURED

| Module | What it does | Witnessed? |
|---|---|---|
| `autoloop.la` | bounded generate→verify→iterate; verify-or-reject, loud halt, three clear terminations | **[W]** |
| `selfprog.la` | `SYNTH` — given name + type + acceptance test, **searches its own capability space** and writes the HOW | **[W]** |
| `selfmod.la` | `NEOLOGIZE` two of its own glyphs into a third; `ADOPT` regrows the organ and verifies | **[W]** |
| `selfopt.la` | `SENSE` its own cost (counts `(` = β-reduction sites) → synthesise cheaper → adopt only if cheaper **and** correct → ledger | **[W]** |
| `selfrepair.la` | `INTACT`/`HEAL` — a module's bytes must equal what its spec generates | **[W]** |
| `autopoiesis.la` | a **process lineage**: each generation `copy_self`s and `execve`s its successor | **[W]** |

**Adoption's verification is real, and stronger than the ledger implies.**
`ADOPT` calls `DEPLOY`, which type-checks the generated source, writes it,
re-reads it, and runs `META_DEBUG` — so the new glyph's **test cases are
executed**, and the on-disk bytes are compared against what the spec generates.
This is not a rubber stamp.

---

## §2 — THE GAP, STATED EXACTLY

Two halves exist and **have never touched**:

- **`autopoiesis.la` executes a successor** — but that successor is
  `copy_self` of `/proc/self/exe`, i.e. **byte-identical by construction**, and
  the program it carries was fixed at bundle time. It cannot be a *revised*
  successor.
- **`selfmod.la` produces a revised, verified artifact** (`grown.la`) — but
  measured today: **`grown.la` is only ever `grep`ped.** `build.sh:1218–1222`
  checks that the new glyph's *text* appears in the file and that the parent
  glyphs survive. It is never bundled, never compiled, never executed.

> **So the new capability is verified inside the parent process and never
> demonstrated by any successor. "The changed thing must become the running
> thing" is unwitnessed — and the system's own gate forbids the witness.**

`build.sh:3577` asserts `cmp -s logos_app new_logos_secd.bin`: the successor must be
byte-identical. **A self-revised successor goes RED on the project's own
criterion.** That is the sharpest structural statement available about the limit
of the present design, and it should be reported as such rather than removed:
*the criterion that guarantees faithful self-reproduction is exactly the
criterion that forbids self-revision.*

### The third gap, which is the one that will bite

`selfmod.la`'s demo constructs the neologism and its acceptance test **in the
same expression**:

```
glyph GREW = APPEND(BASE_SPEC)(SING2(
    NEOLOGIZE(HD2(BASE_SPEC))(HD2(TL2(BASE_SPEC)))("TRIPLEDEC")(":: a -> a")
             (SING2(TC(la g. int_to_str(g(5)))("12")))))
```

`TRIPLEDEC` and the test `TRIPLEN(DEC(5)) == 12` are written by one author, in
one glyph, at one time. **Nothing is held out.** `SYNTH` searching until an
acceptance test passes demonstrates that the search terminated, not that a
capability was gained.

---

## §3 — WHAT "SURVIVING AN UNASSISTED AUDIT" HAS TO MEAN

Four conditions. Drop any one and the claim is empty.

1. **UNATTENDED** — no human between the want and the running successor. A run
   that needs a hand to bundle, or to pick the next step, is `autoloop` with
   extra steps.
2. **GENUINELY NEW** — the extension adds a **κ-distinct** capability the parent
   did not have. Measured, not asserted: this is the ledger's **Ratchet Gate** —
   a coinage may never collapse two previously κ-distinct forms, and must
   *strictly add* a new κ-class.
3. **THE SUCCESSOR RUNS IT** — the capability is demonstrated from the **child
   process's** own output and exit code, after `execve`. Not from the parent's
   report that it adopted something.
4. **AUDITED BY SOMETHING THAT DID NOT HELP BUILD IT** — if `SYNTH`'s own
   acceptance test is the audit, the loop grades its own homework. This is the
   chacha20 shape at system scale: a computation contaminated by its own
   expectation, where every branch condition is impeccable.

---

## §4 — SEVEN WAYS IT WILL LOOK CLOSED WHEN IT IS NOT

Each with the detector that separates it from the real thing.

1. **The extension is a rename.** `SYNTH` composes glyphs it already has; a
   "new" capability α-equivalent to an existing one adds nothing.
   → **Detector:** κ-class count must **strictly increase**. Ratchet Gate.
2. **The acceptance test is the specification.** The want is stated as a test,
   the search runs until it passes.
   → **Detector:** a **held-out** test the synthesiser never saw. §2's third gap
   is this defect already present in the demo.
3. **The parent reports; the child never runs.** Printing `adopted` costs
   nothing.
   → **Detector:** the capability witnessed from the child's stdout **and** a
   non-zero exit when the capability is absent.
4. **The audit runs on the engine that built it.** A synthesis artefact and its
   auditor sharing an evaluator share its bugs.
   → **Detector:** audit on a **different engine**. This repo has five; use one
   that did not perform the synthesis. The cross-engine machinery already
   exists and is already gated.
5. **Cost improvement dressed as extension.** `selfopt` makes a successor
   **cheaper**, not deeper. The ledger is explicit: *the loop optimises COST,
   never DEPTH or expressivity.*
   → **Detector:** a cheaper successor must not satisfy the extension gate. Keep
   the two claims in separate gates with separate names.
6. **Unbounded search declared as creativity.** A search over its own
   capability space will find *something*.
   → **Detector:** state the budget and **what space was searched**, in the PASS
   line. A silent cap reads as "covered everything".
7. **The seed is the answer.** `autoloop` states this gap about itself: its
   `GOAL` hands each step the implementation. If the decomposition supplies the
   pieces, the loop **assembles** rather than extends.
   → **Detector:** the want must be a *type + held-out test only* — never a
   source, never an implementation.

---

## §5 — STAGED PLAN, EACH STAGE WITH A RED PATH

Ordered so that each stage is falsifiable before the next depends on it. **No
stage may be skipped on the grounds that the next one subsumes it** — that is
how stage 3's detector gets lost.

| # | Stage | Red path (what must go RED) | Status |
|---|---|---|---|
| 0 | **Baseline diagnostic.** Assert, as a gate, that nothing currently executes an adopted artifact. | If it passes today it must FAIL the moment stage 2 lands — so it is a *tripwire*, converted, not deleted. | **BUILT** `gate_selfext0.py`, wired. 3 adopted artifacts (`grown.la`, `opt.la`, `organ.la`) READ-ONLY across 148 sources. Self-tests with an injected execution reference. ⚠️ First run reported a FALSE fire on a substring collision (`selfopt.la` contains `opt.la`) — word-boundary matching fixed it. |
| 1 | **Split the byte-identity gate.** A **reproduction** arm and a **revision** arm. | A **corrupt** successor must still fail the revision arm. | **BUILT** `selfext1.la`, wired. 8 gates green. One successor passes revision and FAILS reproduction, so the split is load-bearing. Four conjuncts fail separately: TTTT / FTTT / TFTT / TTFT / TTTF. **Mutation-tested: all 4 conjuncts + the reproduction arm forced true → 5/5 CAUGHT.** |
| 2 | **Make the adopted artifact executable.** | An **unverified** extension must not reach execution. | **BUILT** `selfext2.la` + `gate_selfext2.sh`, wired. Discriminating pair: `sx2_child.la` (grown organ) prints 12 exit 0; `sx2_parent.la` (base organ, IDENTICAL MAIN) fails **and names the absent glyph**, so a red for the wrong reason is excluded. Refuse arm: an unverified extension writes NO child program. **Mutation-tested 2/2 CAUGHT.** ⚠️ Stage-0 tripwire FIRED as designed and was **CONVERTED to a pinned ledger**, not deleted. SCOPE: witnesses that a separate process runs the extension; NOT that the organ begets/execve's it (**stage 2b**, unbuilt). |
| 2b | **The organ begets its own successor.** | A child that runs because the *gate* compiled it is not the organ begetting anything. | **BUILT** `selfext2b.la` + `gate_selfext2b.sh` + `gate_selfext2b_safety.py`, wired. The organ writes 322 B of grown source, forks+execve's `compiler.bin`, fuses a vessel with `bundler.bin`, execve's it, and **the child prints 12 in the organ's own stream**. The gate compiles nothing and runs nothing but `./sx2b_app`; `logos_app` must not exist before the run and must exist after, so the vessel's origin is attributable. **Bomb guard:** every exec target is a LITERAL self-contained bundle, never the VM loader (CLAUDE.md rule 2 — 148,121 processes); a variable target is REFUSED because it cannot be read statically. Generation cap in `.sx2b_gen`. **Mutation-tested 1/1** (organ execs the VM loader → guard fires, statically, no vessel rebuild). ⚠️ Vessel costs ~10 min codegen; built out of band, gate SKIPs if absent. ⚠️ Stage-0 ledger converted a SECOND time (`logos_source.la` joined the exec set). |
| 3 | **Ratchet Gate.** | A **rename-only** extension must go RED. | **BUILT** `ratchet.py` + `gate_ratchet.sh`, wired. Three arms: genuine extension PASSES (κ-classes 3→4), rename-only REJECTED, collapse REJECTED. κ-class = the α-canonical form (binders numbered by appearance), and the normaliser **self-tests on 4 pairs first** — including `la x. la y. x` vs `la x. la y. y`, *same names, different binding*, which a name-stripping normaliser would call equal. **Mutation-tested 3/3**, but only after arm C was rebuilt: its first fixture collapsed a class AND dropped the count, so the strict-increase check caught it and the collapse check was never exercised — removing that check entirely left the arm green. **BOUND:** α-equivalence is decidable, behavioural equivalence is not; a non-literal restatement still passes here → stage 4. ||
| 4 | **Held-out acceptance.** | An extension that passes only its **own** test must FAIL the held-out one. | **BUILT** `selfext4.la` + `gate_selfext4.sh`, wired. Fixture is the chacha20 shape in miniature: `la x. 12` is correct at x=5 only, and **both modes report own-test-verified=T**. Five arms: honest passes held-out probes (10/100/34→27/297/99); overfit fails them; **arm C proves the overfit one CLEARS the ratchet**, so stage 3 doesn't already cover it; **arm D gates the held-out-ness** (probe inputs and answers appear in neither synthesiser nor emitted module); **arm E** re-runs the organ's own probe against the DEPLOYED module. **Mutation-tested 2/2** — but arm E exists *because* a mutant survived, exposing a `TD_IMPL`/`TD_SRC` split (tested half vs deployed half) inside the organ. ||
| 5 | **Cross-engine audit.** | Host and VM disagreeing must be a failure, not a note. | **BUILT** `gate_selfext5.sh`, wired. Synthesis on the C host; the native SECD VM independently answers the held-out probes and agrees. **Arm B** feeds the two engines DIFFERENT modules and requires refusal, so the comparison is shown to discriminate. **Arm C** removes the VM and requires the leg to FAIL rather than silently fall back — otherwise agreement is between an engine and itself. **Mutation-tested 2/2** (VM leg falling back to host; VM reusing a stale stream). ⚠️ Exposed a harness bug: the FAIL classifier substring-matched and read this gate's PASS prose ("a FAILURE, not a note") as failure; the line-start fix then missed inline `| name FAIL` and flipped 8 CAUGHT to SURVIVED — caught only by re-running every set. Now whole-word. ||
| 6 | **The unattended run.** | Budget exhaustion must be a **clean, reported** stop — never a silent partial success. | **BUILT** `selfext6.la` + `gate_selfext6.sh`, wired. Told only a name, a type and one probe, the organ searched its own space and **constructed** `la x. TRIPLEN(DEC(x))` from component names. BUDGET 4, SPACE 4, TRIED 2. Six arms: the result answers **held-out** probes (stage 4), a **second engine** agrees (stage 5), and it **strictly adds a κ-class** (stage 3) — all on an artifact nobody chose by hand. Arm E: the composition source appears nowhere literally in the synthesiser. Arm B: budget 1 stops cleanly at tried=1 with **no module emitted**. **Mutation-tested 2/2** (budget ignored; artifact emitted on exhaustion). **SCOPE, in the PASS line:** closes the item for ONE extension, under a stated budget, over a stated space of four. *'The system extends itself' does not follow.* ||

### Cost discipline, from track-e's result

**Stub before you pay.** Verify the loop's *control flow* with synthesis stubbed
out entirely — no search — and check the bundling, the `execve`, the child's
witness and the auth path standalone. Track-e found everything findable in ~10
minutes of a 124-minute leg that way, and separately proved that a mutant which
dies of the wrong cause teaches nothing. Expect the same ratio here: the
expensive part is the search, and almost none of the risk lives in it.

**And every mutant needs its own witness that it died of the intended cause.**
A stage-2 test where no child runs because the *bundle* failed is not evidence
that the verification gate worked.

---

## §6 — WHAT MUST NOT BE CLAIMED, AT ANY STAGE

- **Purpose-origination.** Ruled out by Erik's own corpus, not by engineering
  difficulty: `canon.la` carries `SR_FOR = ↻(LOVE)` as *"teleology — the
  ACHIEVABLE form of purpose, a BOUNDED GOAL-DIRECTED LOOP; NOT
  purpose-origination."* `selfprog.la`'s header already states this and calls it
  *the wrong target*. The buildable form is **lack-driven**: wire `aatc`'s
  sensed LACK into `SOLVE`, so the want is formed from sensed incompleteness.
  **That is still not origination**, and the gate must not be worded as though
  it were.
- **"The language deepens with its agents."** The loop optimises cost. Depth
  needs a depth-directed `selfopt` mode that does not exist. One honest
  sentence: *the system can currently make itself cheaper and cannot make
  itself deeper.*
- **Agency, qualia, wanting.** Build nothing until a paper formalises them; any
  gate now could not go RED, which is the vacuity defect by construction.
- **That stage 6 closes the item.** Stage 6 closes it *for one extension, under
  a stated budget, over a stated search space*. Generalising from one witnessed
  extension to "the system extends itself" is the overclaim this document
  exists to prevent.

---

## §7 — THE ONE SENTENCE TO KEEP

> The system can write a verified successor and can run an identical one; it has
> never run the successor it wrote — and the gate that guarantees the copy is
> faithful is the same gate that forbids the revision.
