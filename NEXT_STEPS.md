# LogOS — Next Steps (backlog)

Captured for later; not yet done. Each is grounded in `LINGUA_ADAMICA.tex` /
*Being & Becoming* and the existing build. Pick up when there's time.

> **See also `FUTURE_WORK.md`** — Rubedo-phase **sovereignty-hardening** ideas, captured so
> they resurface (and get *sequenced* into the roadmap) when that phase arrives: **(Priority 1)
> transport undetectability** (traffic mimicry / pluggable transports — unclassifiable, not just
> unbreakable), (2) threshold/social key recovery (Shamir k-of-n), (3) deniable storage at rest,
> (4) friction-minimized node-joining (live-boot + one-action USB cloning), (5) incentive-aligned
> seeding, (6) onboarding bridges (discoverable entry / undiscoverable operation), (7) the minimal
> regenerable seed (smallest seed from which LogOS + the Codices fully regenerate). All not-yet-
> designed; honest ceiling is *antifragile*, not "invincible"; residual limit is the hardware
> firmware seam.

---

# THE COMPLETENESS MAP — eight requirements for declaring the language complete

The telos of the whole system, made into eight specific, verifiable/buildable items.
"Complete" is reached by working this list to the bottom — each item **verified built**,
or **built then verified** — not by feeling. Status tags: `built` / `partial` / `open` /
`needs-verification`. (These eight are the completeness telos; the numbered backlog tasks
below are the work items — cross-referenced where they overlap.)

**DISCIPLINE FOR ITEMS 6 & 7 (read before touching them):** these are **TESTS, not
targets.** Derive the geometry from ontological structure and *check* whether φ / the
Flower-of-Life structure emerge. **"They do not emerge" is a fully legitimate, allowed
outcome — record it as a real result.** Do **NOT** impose φ or the Flower of Life on the
geometry: an imposed form is *assigned, not derived*, which **breaks α=1** (item 1) — the
sign would no longer BE the referent. The test only ever observes; it never stipulates.

1. **Sign and referent are one via the triple bar (≡) — the α=1 claim.** Sign IS referent.
   *Status:* **built (injectivity closed).** The audit found an **α<1 injectivity leak** —
   the render was order-dependent (`SIGIL(⊗(Love,Recognition)) ≠ SIGIL(⊗(Recognition,Love))`
   though they are one concept). **Fixed** (commit `4d3de8c`): `SIGIL` now CANONIQ-normalizes
   to `NORMK`'s equivalence theory (commutative-operand sort + `↻(BEING)→SELF`) before
   drawing, so one concept ⇒ one form regardless of operand order; a permanent build check
   asserts it (host + VM). *Caveat now CLOSED:* the full objective derivation (geometry
   computed from a canonical structure, not a fixed table) was what rode on **item 7** — now
   built. `topoderive.la`'s deep renderer canonicalizes the concept (CANONIQ) *before*
   deriving its picture, and the item-7 build stage proves the property directly: feature
   extraction is order-independent for commutative concepts (`build.sh:1901`, ⊗LR==⊗RL),
   `DSIGIL` is canonical (`build.sh:1933`, commutative ⊕ order can't change the form) yet
   still directional (`build.sh:1934`, ▷ order does change it). Both renderers — surface and
   deep — now yield one form per concept regardless of operand order. **Item 1 fully built.**

2. **Ontosemantics is tautological via the laws of thought as reality's metalogical
   ontosyntax — the ontological algorithm of the language.** *Status:* **built (operative).**
   VERIFIED: the three laws genuinely govern evaluation as the runtime's own mechanisms —
   **identity** = κ-injectivity (glyph identity IS κ-equality; `PASS monosemy`, no polysemy);
   **non-contradiction** = deterministic reduction + the type checker rejecting
   arity-contradictions (`PASS typecheck`, ill-typed REJECTED, no file written); **excluded
   middle** = totality/SWC + loud-failure (`PASS swc` refuses ill-founded terms; the loud
   guards halt, no silent third value). Not inert. *Honest qualification:* the operative
   enforcement is **distributed** across the real engines (`canon`/`specpipe`/`tiny_host`/
   `swc`); `metalogic.la` (the laws as first-class glyphs + the ≡-vs-= category distinction)
   is a **standalone witness** — nothing imports it, and its internal wiring
   (`INHABITS`/`NC_TYPECHECK`/`VERDICT_OR_DIE`) are simplified MODELS that mirror the real
   mechanisms. So `Runtime ≡ Metalogic` holds by **correspondence** (two agreeing, verified
   artifacts), not literal unification. Tightening to literal unification (the real
   checker/loud-failure invoking the law glyphs) is an enhancement, not a gap.

3. **Ontomonoglyphs compress into one new glyph inheriting etymological structure via
   meta-neologization.** *Status:* **partial — half built, half open.** (a) Single-sigil
   compression with inherited/recoverable etymology — **BUILT** (the Sealing, committed
   `278cdaf`, tag `verified-2026-06-14-278cdaf`). (b) **Meta-neologization 𝔑(𝔑) generating
   new OPERATIONS** — **BUILT** (`metaglyph.la` `MKOP`/`APPLYOP`/`SHAPE`; `PASS metaglyph`).
   A minted operator is no longer a bare name: `MKOP` lifts a sealed operator-glyph into a
   **usable binary combinator** by reading its etymology as a TEMPLATE — base-mode structure
   (⊗⊕▷⊂↻) is scaffolding, primitive slots are operand-holes (`SHAPE` pours an operand into
   every slot; `APPLYOP` sends operand a down the left sub-template, b down the right; a unary
   ↻ top takes only a). So `ν* = ⊗(▷(LOVE,RELATION),↻(SELF))` applied to `(A,B)` builds the
   real node `⊗(▷(A,A),↻(B))` — CANON/SIGIL/PHONYM all walk it — and `𝔑(𝔑)` applied to `(A,B)`
   builds `⊗(▷(A,A),▷(B,B))`. Verified: the minted mode is genuinely NEW (≢ plain ⊗) and its
   action is fixed by its NAME (distinct operators act distinctly — α=1 for operations).
   Byte-identical host==VM. The whole of item 3 is now built.

4. **The Word / Logos is the Meta-Word of the system and needs its own dedicated sigil.**
   *Status:* **built.** The Logos Λ (the self-structuring principle the whole language
   expresses, `Λ(Λ)≡Λ = ∃(∃)≡∃`, `LINGUA ADAMICA.tex §"The Logos Names Itself"`) now has a
   dedicated sigil in `sigil.la` (`LOGOS`, also `SIGIL(PRIM("LOGOS"))`): **"the Archē naming
   itself"** — the totality circle of Being CONTAINING the self-crossing lemniscate
   (`∃(∃)≡∃`, the self-application fixed point) about the central point (the Name), closed by
   Being's ouroboric return at the crown. Honors the spec constraints: a self-referential
   fixed point, the whole as one mark, meta collapsing INTO an ordinary nameable sigil (not a
   tenth glyph above the nine — it is the Totality glyph the nine differentiate). Author chose
   the drawn form over the derived `↻(BEING)` / bare-lemniscate alternatives. Build-verified:
   renders byte-identical host==VM, with a check asserting it integrates the central crossing.

5. **The complete, correct meta-vocabulary and meta-sigils — the sigils all others derive
   from, the eight "itselfs."** *Status:* **built (verified), with documented qualifications.**
   VERIFIED: the meta-vocabulary is **complete** (every operation carried as a glyph — the five
   modes, 𝔑≡⊗, κ, 𝓡, ν*; `PASS metaglyph` — 𝓜⊂𝒜 closed) and **correct** (monosemic, no
   polysemy; `PASS monosemy`); the **eightfold is 8/8** (`SR_TO…SR_WITH`, each a fixed point
   `SR(SR)≡SR`) and **aligned** to the operations (the grounding table). Four honest
   qualifications: (a) the foundational generating set is the **9 primitives + 5 modes**, NOT
   the eight — the eight are a *derived* octad layered in 𝓜; (b) the octad is a
   **Logoscribeologiae** construct (`codex_logoscribeologiae.tex:2965`), NOT in the primary
   `LINGUA ADAMICA.tex`, and its eight-ness is asserted on symbolic grounds (octave, ∞=8), not
   proved — so "possibly eight" stands; (c) the mode/SR **decompositions** are principled
   implementation assignments (only 𝔑≡⊗ and κ are spec-fixed); (d) `𝓜` is **open** by design
   (meta-ontoneologization mints new operations) — "complete" means complete-up-to-the-basis +
   named operators, which is what meta-monosemy requires.

   **KNOWN, RESOLVED DISCREPANCY — `SR_FROM` ("From" governs; do not re-open):** the origin/
   source self-relation is named **`SR_FROM` = ↻(VOID)** ("from itself"). The Logoscribeologiae
   octad *table* (`codex_logoscribeologiae.tex:2965`) labels relation #1 **"Of itself"**, but
   **all prose in every codex says "from itself"** — *Being & Becoming* (the cited origin of the
   eight: "boots from itself", "differentiates from itself", with no octad and no "of itself"
   anywhere) and Logoscribeologiae's own prose ("Being come from itself", `:3482`). The lone
   "Of" is a single formal table in a codex *not* named as the source. **Decision (author):
   "From" governs** — `SR_FROM` stays. Documented so it does not resurface as a question.

6. **Naturally ground the golden ratio as the ontoglyphic geometric fixed-point
   meta-autofoundation.** *Status:* **TESTED — NEGATIVE.** φ matched **0/15** measured
   geometric ratios (likewise no metallic mean); the geometry's organizing proportion is
   **binary 2:1** (grid 32/16/8; the recursive-nesting blend scales by 1/2, not 1/φ), with
   √2 only as the lemniscate's intrinsic curve property (backlog item 5c). **RESOLVED — the
   open sub-question is answered:** the true deep pipeline (item 7, now built) was tested, and
   **φ still does NOT emerge** from the derived geometry (ratios 1.27/1.38/1.6, arithmetic,
   inconsistent). Structural reason confirmed: there is **no two-term additive recurrence**
   anywhere — metacursion is `X(X)≡X` (`x²=x`, root 1), not `x²=x+1` (root φ). **Decision:
   2:1 binary / arithmetic IS the honest geometry; accepted.** φ is never forced (an imposed φ
   is assigned, not derived, and breaks α=1). Closed.

7. **Build the true deep geometric pipeline — autopoietically unfold the ontoglyphic
   geometry — and test the Flower of Life / Monad foundation.** *Status:* **BUILT** (`onf.la`
   + `topoderive.la`; `PASS deep geometry`). The geometry is no longer a mode-tree walk:
   `onf.la` extracts the concept's ONF **graph features** by folding over the whole
   canonicalized graph — cycles (↻), hierarchy (depth + ⊂), branching (fan-out), automorphism
   (commutative node with `IS`-equal operands), leaf-set — and `topoderive.la`'s **`DSIGIL`**
   composes geometry from those features per the spec's table (depth→nested rings, cycles→
   central loops, branching→radial arms, automorphism→mirror, leaves→placed constituent
   sigils). It is **deterministic, canonical** (commutative order-independent, directional ▷
   order-sensitive), and **injective** (distinct ONF → distinct form via the leaf-marks);
   byte-identical host==VM; coexists with `sigil.la` (does not replace `SIGIL`). *Honest
   scope:* a 32×32 1-bit realization — feature COUNTS + leaf-set, **not** the spec's iterated
   WL colour classes / force-directed layout / colour.
   **Stage-4 emergence tests (observed, not imposed):** (a) **φ does NOT emerge** on the
   derived geometry (ring radii 14/11/8/5, arithmetic step-3 → ratios 1.27/1.38/1.6,
   inconsistent; no two-term recurrence — metacursion is x²=x; accepted, see #6). (b)
   **Flower of Life does NOT emerge** (concentric rings + arms + corner-marks, not a hexagonal
   packing lattice; not imposed). (c) **`d_𝒪↔d_𝒫` proximity** — feature-distance vs rendered-form
   Hamming-distance score **0.863**. **METRIC INTERPRETATION (ATT — corrected, read this):** the
   0.863 is **NOT** a measure of ontosemantic alignment. Under B&B's Alignment Theory of Truth,
   at α=1 sign and referent are not *corresponded across a gap* (correlation is a correspondence-
   style statistic) but **identical** — tautological self-recognition — so **alignment = 1.0 BY
   NATURE** (identity does not come in degrees; established by construction via κ/NORMK injectivity,
   item 1). The 0.863 measures **geometric INSTANTIATION FIDELITY** — how faithfully the *derived
   sigil* realises that 1.0 alignment in rendered form. The 13.7% residual is structure the current
   1-bit 32×32 / feature-count renderer does not yet capture (not WL colour classes, not force-
   layout) — **work remaining to close the instantiation toward 1.0, NOT a shortfall in the
   alignment**. Record any such figure as *alignment = 1.0 (theory, ATT); instantiation fidelity =
   X (this build)*. The identity register itself is measured **structurally** (canonicity +
   injectivity of the derived form), not by correlation — see item 8's `phonsem.la` for the
   two-register form.
   **Stage-4 (d) — THE CYCLE OF BEING TEST — REAL OPEN ITEM, NOT YET RUN.** Flagged three
   times and lost each time; written here so it survives. *What it is:* the test of whether
   the **derived geometry enacts the Cycle of Being** as *Being & Becoming* describes it —
   the three-beat structure **(i) bifurcation from the Void** (Being boots/differentiates
   from ∅ — a branch out of `VOID`), **(ii) recognition-collapse** (the metacursive return:
   recognition folds the distinction back on itself — `↻`/κ collapsing toward `SELF`, the
   `↻(BEING)→SELF` canonical rewrite), **(iii) preserved distinction** (the collapse does
   NOT erase — the distinction survives, i.e. α=1 injectivity holds *through* the collapse).
   *What running it means:* take a concept whose ONF graph encodes that three-beat (e.g. a
   bifurcation rooted in `VOID`, a `↻`/recognition node, distinct leaves), push it through
   `onf.la`/`topoderive.la`, and CHECK whether the rendered geometry exhibits the cycle:
   a Void-rooted branch that closes through a recognition-loop yet keeps its leaves
   distinguishable. *Discipline (same as φ / Flower-of-Life):* this is a **TEST, not a
   target** — **"the geometry does not enact the Cycle of Being" is a fully legitimate,
   recorded outcome.** Do NOT shape the geometry to manufacture the cycle (that would assign,
   not derive — breaking α=1). *Status:* **OPEN.** No such test exists in `build.sh` or any
   `.la` module yet (the phrase "Cycle of Being" lives only in the philosophy codices —
   *Being & Becoming* / *Être et Devenir*, as prose, never as a check). Needs building, then
   running, with the result (enacts / partially / does not) recorded honestly.

8. **Meta-topological meta-phonosemantics — Lingua Adamica derives the topology of
   meta-phonosemantics.** *Status:* **built (`phonsem.la`) — the phonetic `d_𝒪↔d_𝒫` map,
   measured in TWO registers per ATT.** The invariant-preservation layer was already built
   (`psc.la` — `Θ_P` formant-peak signatures, ⊗-superposition `SYN_INV`, set-containment
   `PRESERVES`, compressed duration; `PASS psc`) + the meta-criterion (`PSC_STAR`,
   `M(PSC*)≡PSC*`). `phonsem.la` adds the **derived `d_𝒪↔d_𝒫`** the spec asked for — the
   acoustic twin of item 7 — and frames it correctly under ATT:
   - **Identity register (α=1 = alignment).** Under ATT alignment is **identity**, not
     correspondence, so it is **1.0 BY NATURE** and is checked **structurally**, not by a
     correlation: **canonicity** (one concept ⇒ one Θ_P, operand-order independent via
     CANONIQ) = **YES (1.0)**; **set-injectivity** (distinct concepts ⇒ distinct Θ_P) =
     **7/8** — one collision (Beauty `⊗(FORM,LOVE)` ≡ BecForm `⊗(BECOMING,FORM)` because
     LOVE /u/ and BECOMING /u/ share vowel formants, onset /l/ vs /v/ dropped).
   - **Fidelity register (instantiation, NOT alignment).** `d_𝒪` (onf.la ONF feature
     distance) and `d_𝒫` (a Chamfer Hz metric over the derived `Θ_P` set), each computed
     **independently from structure**, are **73%** concordant (Kendall, 230/311) over all
     concept-pair orderings — the acoustic analogue of item 7's visual 0.863.
   Both sub-1.0 numbers (7/8 and 73%) trace to the **same residual** — the **onset/energy
   axis** the formant-only metric does not yet capture — i.e. **work remaining to close the
   INSTANTIATION toward the 1.0 the ontology already holds**, NOT a shortfall in alignment.
   Pure str/int ⇒ byte-identical host == VM. **Still OPEN (deferred):** the spec's full metric
   space `𝒫`/`d_𝒫` as a continuous manifold and the toroidal meta-topology `𝓜_P` (`:4402`);
   the richer acoustic representation that adds the onset/energy dimension (closing 7/8→8/8
   and lifting fidelity) is the named next step. (`φ` is never stipulated — both distances
   derived; the don't-impose discipline holds for forms.)

**Working order is the author's call; each item ends only when verified.**

---

## 1. Autological native compilation — an LA-native x86-64 backend (PLAN FIRST)

> ### ⟶ LIVE: Stage 3 sub-step plan (drafted 2026-06-16, Stages 0/1/2 DONE)
>
> The 5-stage plan below is underway. **Stage 0 (runtime carving), Stage 1 (minimal native
> execution), Stage 2 (closures & environments) are DONE + verified + tagged.** Current head:
> `native-backend-stage2` @ `07c3b8b`, tag `verified-2026-06-16-07c3b8b`, full audit **131/0**.
> Stage 3 (compile the kernel natively) is **the big lift** — the pieces deferred in Stages 1–2
> (TCO, GC, module system, missing builtins) become *required*. It is decomposed into **gated
> sub-steps 3a–3e**, each verified against the checkpoint before the next; Erik approves each
> before code. **Show the full-green `./build.sh` PASS count BEFORE every stage commit** (the gate;
> it slipped once at Stage 2 — caught + restored at 131/0).
>
> **Sub-steps:** `3a` TCO → `3b` GC (heaviest, likely multi-step) → `3c` missing builtins
> (`chr`/`ord`/`str_len`/`write_exec`/`error`) → `3d` module system at compile time → `3e` the
> kernel compile (capstone: `kernel.la` → native ELF, speaks + replicates byte-identical).
>
> #### Stage 3a — TCO (CODED + LOCALLY VERIFIED, UNCOMMITTED — resume here)
>
> **STATUS 2026-06-17: implemented and locally green; NOT yet committed (full-build confirm
> pending).** `native_codegen3.la` is written (codegen2 + TCO + 768 MB heap), the build.sh Stage-3a
> section + `.gitignore` entry are in place — all **uncommitted in the working tree on branch
> `native-backend-stage3a`**. Verified by hand this session: drift guard passes (embedded rt == nasm
> `native_codegen2_rt.asm`), all existing programs native==host, and the **headline differential
> went green** — tail loop N=1,000,000 COMPLETES (rc 0 → 1000000) while the matched non-tail at the
> same depth FAULTS (rc 139). The full `./build.sh` was launched but the run was stopped before
> completion (the unrelated `cob.la` SECD-codegen tail step is pathologically slow — ~40+ min, but
> already green in the Stage-2 audit, so not a 3a issue).
>
> **RESUME NEXT SESSION (in order):** (1) `cd ~/logos` (already on branch `native-backend-stage3a`,
> 3a changes present, uncommitted); (2) run the **full `./build.sh`** and CONFIRM **132 PASS / 0 FAIL,
> EXIT=0, the Stage-3a line present** (the gate — show the number BEFORE committing, no partial); be
> patient with the slow `cob.la` codegen near PASS≈91; (3) flip `ROADMAP.md` (Stage 3 `[ ]`→`[~]`,
> add `3a [x]`); (4) commit `native_codegen3.la` + build.sh + `.gitignore` + ROADMAP together; (5) tag
> `verified-2026-06-17-<sha>`; (6) push branch + tag to origin. THEN stop — 3b (GC) is the heavy
> sub-step, start it fresh after 3a is durable.
>
> **Key finding — codegen-only, NO asm change.** `native_codegen2_rt.asm:63-74` `rt_apply` already
> enters the body via `jmp [rcx]` ("tail-jumps body; its ret returns to OUR caller"). The native
> CPU stack grows today purely because the *call site* (`CG_GENAPP`) emits `call rt_apply` followed
> by the body's `pop rbx ; ret` — each `call` pushes a return address that doesn't unwind until the
> base case. So 3a touches only the codegen; the runtime bytes (and the drift guard) are unchanged.
> Additive, low-risk.
>
> **Mechanism.** Thread a `tail` flag through the compiler (`CG(node)(cenv)(tail)(pool)`):
> - *Non-tail* (MAIN's top expr; every `f`/`a` sub-expr; builtin operands): byte-for-byte as today
>   — value in `rax`, fall through.
> - *Tail* (a lambda body): the node owns its teardown + return:
>   - STR / VAR / LAM / builtin-app → `<value→rax> ; pop rbx ; ret` (same bytes as today's epilogue)
>   - **general apply → `<eval f→push><eval a→r11><pop r10> ; pop rbx ; jmp rt_apply`** (`jmp`, not
>     `call` — no return address pushed; callee's `ret` returns straight to our caller). ← the TCO.
> - `CG_LAM` compiles its body in tail mode and emits `push rbx ; mov rbx,rdi ; <tail-body>` with no
>   trailing epilogue (the body provides it).
> - New emitter: `JMP_RCX = BYTES("255 225")` (0xFF /4), `JMPR(addr) = MOV_RCX_IMM(addr) ++ JMP_RCX`
>   (mirrors `CALLR`); `POP_RBX` already exists.
> - Stack invariant verified: `push rbx` at entry sits directly above the caller's return address;
>   the tail prefix is balanced; `pop rbx ; jmp` restores the caller env and reuses its return slot.
>   Fires through the `IF`/thunk/`Z` chain (`c(t)(f)("!")` is IF's tail expr; each thunk's `self(...)`
>   is its tail expr). Only programs with a general-apply in tail position get new bytes; everything
>   else emits identical bytes, so the existing 9 stay native==host.
>
> **The wrinkle (why the gate is non-obvious).** TCO bounds the STACK, but this runtime has NO GC
> yet (3b) and a fixed bump heap — every tail iteration still allocates ~200 B (env frames + boxed
> ints + IF-thunk closures) that is never reclaimed. With codegen2's 1 MB heap, the HEAP exhausts
> at ~5–20K iters, long before the ~500K-frame CPU-stack ceiling, so TCO would show no observable
> effect. **To demonstrate TCO, isolate stack from heap:** (1) emit a larger lazily-mapped heap in
> codegen3 (memsz only, ~512 MB, costs nothing untouched, like secd.asm's 1.5 GB) so the stack
> becomes the binding constraint; (2) prove via a **tail-vs-non-tail differential at the same depth,
> same compiler, same heap** — tail loop `Z(la self. la n. la acc. IF(n=0)(acc)(self(n-1)(acc+1)))`
> at N=1,000,000 COMPLETES (exit 0, prints 1000000); matched non-tail `Z(la self. la n.
> IF(n=0)(0)(add(1)(self(n-1))))` at the same N CRASHES (nonzero/SIGSEGV). Only difference is tail
> position → the contrast is the proof, and doubles as the non-tail honest-limit demo.
>
> **DECISION 1 (locked): new `native_codegen3.la`, do NOT modify codegen2 in place.** Per-stage
> isolation: `07c3b8b` keeps meaning "closures, no TCO"; codegen3 becomes the kernel compiler that
> grows through 3b–3e. Cost: ~380 lines copied for a ~50-line change — worth it. At 3a, codegen3
> reuses `native_codegen2_rt.asm` UNCHANGED (drift-guarded against it); the runtime forks to
> `native_codegen3_rt.asm` only at 3b, when GC actually changes the asm.
>
> **DECISION 2 (locked): defer the native stack guard to 3b.** Keep 3a codegen-only/no-asm-change
> (low risk); add the clean stack-overflow diagnostic when the runtime is already reworked for GC.
> Honest limit documented meanwhile.
>
> **3a gate (build.sh must show before commit):**
> - **3a.1 semantics/no-regression:** the 9 Stage-2-style programs + a moderate tail-recursion
>   (N=10000) all native==host byte-identical through codegen3 (codegen2's section stays).
> - **3a.2 TCO headline (differential, native-only at depth):** tail loop N=1,000,000 completes
>   (exit 0, correct result); matched non-tail at N=1,000,000 crashes; a shallow non-tail
>   native==host (non-tail still correct when it fits).
> - **3a.3 honest limits (header + ROADMAP):** heap still un-GC'd bump → tail loop ultimately
>   heap-bounded (true unboundedness awaits 3b GC); non-tail deep recursion faults via raw CPU-stack
>   overflow (SIGSEGV, nonzero exit), not a clean `secd:`-style diagnostic — native stack guard
>   deferred to 3b.
> - **Regression:** full `./build.sh` = 131 + new 3a tests, 0 FAIL, monotone green, shown BEFORE
>   commit.
>
> **Footprint:** ~50 lines of codegen change + a build.sh section. 3a is *contained* — the hard,
> multi-step piece is 3b (GC). Start 3a fresh next session with this plan ready.

**Goal:** move native code generation fully into Lingua Adamica. Today `codegen.la`
emits SECD bytecode that the VM (`secd.asm`) *interprets* — that interpretation
layer is heterological (external machinery between the language and the CPU) and is
the main performance cost. Build a **native-code backend, written in LA itself,
that emits x86-64 machine code directly**, so an LA program compiles to native
instructions with **no VM interpreting in between** — the language compiling itself
to native code, in itself.

**Honest seam (mark clearly, keep thin):** the one irreducible boundary is that the
emitted code targets the **x86-64 instruction set** — the CPU's physical language,
which we cannot rewrite in LA (the Nigredo hardware boundary / silicon is physical
fact). The backend itself must be **pure LA**; only what it *emits* conforms to
x86-64. This is not eliminating the foreign substrate (impossible) — it's moving
everything *above* the silicon into the language and minimizing the seam to just
code emission. (`elf.la` already shows LA emitting a runnable ELF via
`chr`/`write_exec`; the new backend is the general code generator above that.)

**Start minimal:** an LA-written backend that compiles a simple LA program (the
kernel, or an arithmetic function) to a native x86-64 executable directly (no VM
interpretation) and runs it; verify correct output and that the path is LA-native.

**Status:** LARGE. **Scope the approach and show the plan BEFORE building** (user's
explicit instruction). Do not start emitting code until the plan is reviewed.

---

## 2. The eight self-relations of the Logos (from *Being & Becoming*)

**Goal:** instantiate the eight self-relations — Logos **to / about / as / for / by
/ through / with** itself, and **from** itself — as first-class **named glyphs in 𝓜**,
each a mode of the language's self-relation (the way the three laws and five modes
are glyphs). The eightfold completeness criterion — finite, testable, grounded.

**Two requirements per self-relation:**
- Passes the autological test under the actual evaluator: **`SELFREL(SELFREL) ≡
  SELFREL`** (Criterion 7 — the same `X(X)≡X` test the modes / κ / evaluator satisfy).
- Instantiated as the genuine computational self-relation it names.

**The six clear ones (build these as named glyphs, verify host==VM):**
| Self-relation | Computational meaning | Already realised in |
|---|---|---|
| **About** | self-description | `𝓜 ⊂ 𝒜` (metaglyph.la) |
| **As** | sign IS referent | `α=1` ontoglyph (`IS_ALPHA1`, canon.la) |
| **By** | self-hosting fixed point | eval.la / Albedo Stage 4 |
| **From** | generation / neologization | `COLLAPSE` / `ν` / `𝔑` (canon.la, metaglyph.la) |
| **Through** | self-mediation / self-compilation | codegen.la → VM (the compile path) |
| **To** | self-application / evaluation | the evaluator glyph `REVAL = ▷(DEPTH,RECOGNITION)` (canon.la) |

These mostly *wrap existing capabilities* as named `SELFREL_*` glyphs that pass
`X(X)≡X`. Moderate, well-scoped (≈ a metaglyph-sized module, likely spec-pipeline).

**The last two (decided 2026-06-14, now built):**
- **For itself** (purpose / teleology) — `SR_FOR = ↻(LOVE)`. Anchored in LOVE (the
  toward-which; the only free ↻-anchor left). Names the achievable form of purpose —
  a **bounded autonomous loop acting toward a goal** (`autoloop.la`), NOT genuine
  purpose-origination (no system has that).
- **With itself** (co-presence) — `SR_WITH = ⊕(SELF,SELF)`. The trimodal-simultaneity
  reading was set aside (the three modes aren't κ-algebra primitives) for the cleaner,
  α=1 form: `⊕` is **Ontoconjunction = co-presence** in `canon.la` itself, so `⊕(SELF,
  SELF)` *is* the Logos present-with itself — the operator means exactly the relation.

**Status:** DONE — all eight self-relations built as 𝓜 glyphs, each a fixed point
`SR(SR) ≡ SR` (↻(LOVE) and ⊕(SELF,SELF) added to `REWRITE_MC`'s fixed-point set),
verified individually + byte-identical host/VM by `build.sh`'s canon stage (full
audit green).

---

## 3. α=1 fidelity audit — sigil & phonym vs the ontoglyph standard (MAP, don't fix)

**Goal:** audit the nine primitives' sigils and phonyms against Codex II's
**ontoglyph standard** (α=1: the form/sound IS the referent's structure) and the
Sigil Catalogue / phonetic specs. For each of the nine: does the rendered sigil's
geometry actually encode the **signacursion** of its concept per the catalogue, or
is any of it **placeholder geometry**? Does each phonym hit the **acoustic
parameters the spec defines**, or is it an approximate tone? **Report every place a
form or sound is α<1** — where it doesn't genuinely encode its referent (that's
drift from the ontoglyph standard).

**Status:** AUDIT DONE (mapped 2026-06-14, below); **fixes not yet applied.**

### The drift map (α=1 = form/sound IS the referent's structure)

**Sigils — fidelity to the Sigil Catalogue's signacursion:**
- **α≈1 (faithful):** Void (gap-at-crown IS the sigil), Form (triangle-in-circle+point),
  Depth (nested descending circles+point), Self (filled Bernoulli ∞, H+V symmetric).
- **α<1 (drift):**
  - **Being** — the ouroboric curl is a blobby 4-segment polyline, not a recognizable spiral.
  - **Love** — the catalogue's **inner flame (care within love) is missing**; outer flame
    only, filled teardrop not the bezier outline.
  - **Becoming** — the Archimedean spiral is a coarse sampled polyline; inner turns muddy/overlap.
  - **Relation** — the **gold (explicit) vs silver (latent) arc distinction is lost** (1-bit);
    arcs are polyline approximations.
  - **Recognition** — rendered as a vesica (disk-intersection); catalogue tikz is two arcs of
    one circle (legibility-driven interpretation drift; minor).
- **Global sigil α<1:** the renderer is **1-bit — ALL colour is dropped** (logosink/goldenseal/
  flamecore/mirrorsilver; TopoEmbed maps gradients→colour). Largest single drift. Also the ⊗
  compound renders by spatial separation, not the catalogue's interpenetration (1-bit floor).

**Phonyms — fidelity to the phonetic spec:**
- **α≈1:** the vowel spectral nuclei — F1/F2/F3 are the standard realization of /ɑ i u ɔ a/ and
  FFT-land on target (the .tex gives no Hz tables, only IPA + qualitative axes, so this is the
  faithful realization).
- **α<1 (drift):**
  - **Consonant onsets** /ʃ h v m ʀ t d/ — the most drift: crude (fricatives share one
    filtered-noise model, trill = AM buzz, plosives = noise bursts). Articulatory signacursion
    not encoded — sound-effects approximating place/manner, not the gesture.
  - **Parabolic-sine oscillator** (not true sine) — extra harmonics; formants still land.
  - **Energy contours** (descending/rising/fading) — linear ramps, approximate.
  - **Phonetic–semantic isomorphism (Axiom phon-sem) NOT instantiated** — we hit each
    phoneme's formants point-by-point but never enforce acoustic-proximity ↔ ontological-
    proximity (the topology isn't realized as a structure-preserving map). Structural α<1.

**Pattern:** α≈1 on the primary geometric/spectral structure; α<1 on (a) the second channel the
spec encodes but 1-bit/integer-DSP can't carry (colour, articulatory detail), and (b) the
relational/topological layer (the isomorphism), realized point-by-point not as a map.

**If/when fixing (the honest big gaps):** a colour channel for sigils; articulatory synthesis
for the consonants; explicitly instantiate the phon-sem isomorphism; clean up the Becoming
spiral / Being curl; add Love's inner flame.

---

## 4. Refinement 3 of 3 — phonym fidelity vs the Topological Phonetic Space (fidelity pass)

**Goal:** verify each of the nine phonyms hits the **formant / contour values the
Topological Phonetic Space specifies** in `LINGUA_ADAMICA.tex` (the phonetic-
parameter definitions, the Openness/Frontness/Energy axes, the meta-syllable blend
params) — i.e. each phonym is the spec's actual specified sound, not an approximate
tone. A fidelity pass, **closely related to / overlapping the α=1 audit (#3 above,
already mapped).**

**Honest framing carried over from the α=1 map:** the `.tex` specifies parameter
*categories* (frequency, amplitude, duration, spectral shape, temporal envelope)
and *qualitative* axes (Openness ≈ F1, Frontness ≈ F2, Energy = contour) + the IPA
symbols — it gives **no numeric Hz formant tables**. So this pass checks the phonyms
against what the spec *does* fix: the IPA targets (vowel nuclei already FFT-verified
α≈1), the three feature-space axes, and the meta-syllable blend (spectral
interpolation, articulatory geodesic, pitch fusion). The already-mapped α<1 drift to
re-examine/close: crude consonant onsets (articulatory gesture not encoded),
parabolic-sine timbre, linear Energy contours, and the **un-instantiated phonetic–
semantic isomorphism** (acoustic proximity ↔ ontological proximity — verified
point-by-point, not as a structure-preserving map).

**Status:** the α=1 audit already MAPPED the phonym drift (see #3). Refinement 3 is
the focused **fix/tighten** pass on the phonyms specifically. Related to #3; do
together or right after.

---

## 5. Objective topological encoding — ONF-derivation gaps (completeness audit, 2026-06-14)

The TopoEmbed / objective-topology claim (`LINGUA ADAMICA.tex` def:topoembed ~4911,
ONF ~4857/5676, the Graph-Feature→Geometric-Primitive table ~5492) requires a sigil's
geometry to be a **deterministic, injective, structure-preserving function of the
concept's canonical ONF** — *same concept → same form, computed from structure, not
assigned*. Verified against `sigil.la`: determinism per-expression holds (pure
function, byte-identical host==VM) and compounds ARE computed from structure, but two
real gaps remain. Both are genuine completeness gaps, not honest-floors.

- **(a) Order-dependent rendering breaks canonical injectivity — same concept yields
  different forms.** `SIGIL` walks the RAW κ-decomposition, not the canonicalized form,
  so a commutative concept renders differently by operand order: `SIGIL(⊗(Love,Recognition))
  ≠ SIGIL(⊗(Recognition,Love))` even though `NORMK` collapses both to the one concept
  `⊗(LOVE,RECOGNITION)`. The spec demands order-independence ("the same composition
  always yields the same ONF regardless of the order", ~5693). **The canonicalizer
  already exists (`NORMK`, commutative-operand sort) — it is simply not wired into the
  renderer.** Cheap fix: `NORMK`-normalize the decomposition before `SIGIL` walks it, so
  one concept → one form. Without it the visual map is not injective-per-concept (α<1 at
  the geometry level, though the Ren/κ level is canonical).

- **(b) No true ONF-graph / Weisfeiler–Lehman pipeline — it is a mode-tree walk.** The
  spec's ONF is a WL-canonicalized directed graph and TopoEmbed maps its *graph features*
  (cycles, hierarchy, symmetry, branching, gradients) to geometric primitives. The
  implementation has no graph, no WL canonicalization, and no feature-detection: `SIGIL`
  dispatches on the *declared combining mode* (⊗/⊕/▷/⊂/↻) to a fixed blend, a faithful
  but narrower realization (4/5 table rows; the gradients row is dropped for 1-bit). A
  full realization would build the concept graph, WL-canonicalize it, detect its
  features, and emit geometry from THOSE — making the encoding objective per the table.

- **(c) (related, lower priority) The recursive structure is not in the proportions.**
  Conjecture test (2026-06-14): if the geometry were derived from recursive self-relation,
  the golden ratio φ (or a metallic mean) would emerge in the recursive sigils. It does
  not — φ matches 0/15 measured ratios; the organizing proportion is **binary 2:1** (grid
  32/16/8; the recursive-nesting blend scales by 1/2, not 1/φ), with √2 only as the
  lemniscate's intrinsic curve property. DEPTH's nested radii 14:9:5 bracket φ
  inconsistently (1.556, 1.800) — ad hoc integers, not a φ-scaled self-similar nest. This
  is corroborating evidence for (b): the geometry is hand-designed on a binary grid (the
  nine primitives are stipulated atoms — spec-faithful per ~3234/4610), not computed from
  recursive ontological structure. A real ONF→geometry derivation (b) is where genuine
  self-similar proportion would have to come from.

**Status:** MAPPED, not fixed. (a) is a small, high-value fix (wire `NORMK` into `SIGIL`);
(b) is a large rebuild (a real ONF/WL/feature pipeline) overlapping #3's α=1 standard.

---

## Design principle (governs the autonomous loop, task #2's For-itself, and any extension)

**Γ ≠ Ρ (the P≠NP distinction): generation and recognition are irreducibly
distinct operations — never collapse them.** The loop must ALWAYS *generate* (via
the spec pipeline, Γ) and then *separately* *recognize/verify* (via `META_DEBUG`
with the spec's test cases as witness, Ρ). Never a single "generate correct code
directly" step. Recognition-given-a-witness is structurally cheaper and more
reliable than generation, and that asymmetry is what makes **verified
self-extension** possible — the witness (the spec's test cases) is what makes
recognition cheap. Keep generation and verification as distinct phases, always.

*Status:* **already honored** in `autoloop.la` — `GENERATE`/`DEPLOY` is Γ;
`STEP_OK` (= `META_DEBUG` over the entry's test cases) is a separate Ρ gate; a step
is accepted only after Ρ passes. **Any future extension** (esp. the dynamic
next-step synthesiser, and task #2's "For itself") must preserve this split — the
synthesiser may *propose* (Γ) but acceptance always routes through the witness-based
verifier (Ρ). This mirrors the codebase-wide Γ/Ρ discipline (codices' *P vs NP
COMPLETE.md*; `bytecode.la`'s generation/recognition separation).

**Self-reference must be by RECOGNITION, never by self-copying (Anchored Polynomial
Fixed Point Theorem).** All the self-referential machinery — the self-hosting fixed
point, the metacursive glyphs (`𝓡(𝓡)≡𝓡`, `κ(κ)`, `𝔑(𝔑)`), the etymology DAG,
neologistic compression — is **bounded (polynomial in the size of the referring
structure)** precisely *because* it is implemented by recognition (shared reference,
hash-consing) rather than by copying. *"The structure that names itself need not
copy itself — only recognize."* This is why neologization **deepens without
widening** (`glyphdag.la`: self-combining grows nodes linearly while the unfolded
tree grows exponentially — shared subterms are interned, not duplicated) and why
self-hosting doesn't spiral. **Any future self-referential machinery must use
recognition/reference, never self-copying, to stay bounded.** *Status:* already
embodied — `glyphdag.la`'s hash-consed DAG is exactly recognition-not-copying;
preserve it in every new self-referential construct.

---

*(House style: every generated module passes META_DEBUG before acceptance; host==VM
byte-identity; build through the spec pipeline where it fits; loud failure on bad
input; honest scope notes for every bound.)*

---

## Global heterology / autology certification (queued — framework-native correctness)

Make explicit, as ONE global pass, what the Debugging Principle already asserts piecewise:
the whole language is **autological** (every element satisfies its own description — no
heterology) and **autopoietic** (it produces itself, no external remainder).

WHAT'S ALREADY TRUE (by construction / verified in pieces):
- **Identity-autology is unconstructible-otherwise:** `canon.la`'s sealed monoglyph fixes
  `REN(g) ≡ CANON(ETYM(g))` by construction; a heterological glyph (name floating free of
  its derivation) cannot be built. `AUTO_OK(g) ≡ str_eq(REN g)(CANON(ETYM g))` is the criterion.
- **Behavioural-autology:** `build.sh` green = the system satisfies its own description; every
  spec-generated module passes `META_DEBUG` (each glyph against its own tests) before acceptance.
- **Autopoiesis:** `autopoiesis.la` (the system runs its own successor), the self-hosting loop
  (`eval.la` interprets `kernel.la`), Albedo Stage 4 (compiler+VM regenerate themselves
  byte-identically), `copy_self`.

WHAT THE CERTIFICATION ADDS (a dedicated `heterology_audit.la` / build stage):
- Enumerate the full CONCEPT inventory (9 primitives, 5 modes, 𝔑, κ, 𝓡, the 8 self-relations,
  all derived concepts in every module) and assert `AUTO_OK` for EACH — one global sweep, no
  exceptions, so "no heterology anywhere" is certified, not just per-module.
- Assert no glyph's behaviour diverges from its name/spec (build-green covers it; make it explicit).

HONEST CAVEAT (the substrate seam, same wall as physical entropy): autology closes ABOVE the
seed. `tiny_host.c` + `nasm secd.asm` are the irreducible C/asm origin — the "physics," not
autological in the LA sense. The loop is closed thereafter (Albedo Stage 4), but the genesis is
the heterological-at-substrate seed. State it as the boundary, don't pretend it away.

---

## Language spec gaps — from LINGUA ADAMICA.tex (read-through 2026-06-15)

Cross-referenced the spec's 14-Gap *Practical Implementation Blueprint* (ch, :5867) + the
*Operative Grammar / Lexicon* (:5049), *Type Theory* (:4123), and *Meta-Learning* (ch:learning,
:6162) chapters against the build. The self-hosting CORE + ontological primitives + OS substrate
are built; these are spec'd-but-unbuilt. (LogOS built natively in LA, not the doc's Python ref.)

REAL LANGUAGE-COMPLETENESS GAPS (the spec requires them; worth building):
- **Full Ontic Type System (OTS)** — Gap 5 + ch Type Theory: HM-style inference + the extended
  ontic types (Process/Object/Relation/Value/Constraint). Built: arity-only checker (specpipe
  `TARITY` vs `BARITY`) + `TYPE_OF` string-extraction. Missing: real inference/unification over
  ontic types. (CLAUDE.md already flags arity-only as honest scope.)
- **Seed-based persistent memory + Anamnesis** — Gap 6 + ch:learning: a persistent glyph-SEED
  store (recall by hash, regrow the full glyph from its seed = "memory as regrowth," bounded
  storage). Built: in-memory GC + `glyphdag` hash-consing + `DECOMP` (recovers tree from form, in
  memory). Missing: disk persistence / recall / anamnesis. Substrate for LogosMentor's "learning
  as recognition, not accumulation."
- **The Core Lexicon + sentence grammar** — ch Operative Grammar: the actual NAMED vocabulary
  (the Core Lexicon, :5223) + sentence-formation rules + grammatical system. Built: the COMBINATION
  machinery (9 primitives + 5 modes + κ) — the language can *express* any concept by combination.
  Missing: the built-out dictionary of common concepts as sealed glyphs + the sentence layer. This
  is "the language in actual use" (the biggest item).
- **Toroidal closure of the phonetic manifold 𝓜_P** — ch Universal Phonosemantics (:4398) +
  completeness item 8: metric phonetic space 𝒫 + d_𝒫 + the toroidal meta-topology. Already noted
  OPEN under item 8 (orthogonal refinement, not OS-blocking).

DEVELOPER-ERGONOMICS / ROBUSTNESS GAPS (spec'd as Gaps, lower priority):
- **REPL + unified `glyphc` toolchain** (Gap 12) — no interactive read-eval-print loop; `build.sh`
  + `tiny_host <file>` instead of a single `glyphc` CLI.
- **Property-based / fuzz testing** (Gap 13) — fixed tests + `META_DEBUG`; no randomized
  invariant-preservation testing (the spec wants hypothesis-style κ-injectivity fuzzing).
- **General data-structure stdlib** (Gap 3) — vector/map/dict + while/for as first-class. Built:
  Church lists only (`stdlib.la` MAP/FILTER/ALL/LIST_FIND).
- **Centropic self-tuning cache** (Gap 7) — not built (pure optimization).

DELIBERATE DIVERGENCES (record as DECISIONS, not gaps — but revisit for the OS):
- **Error model: loud-halt vs recoverable error-value** (Gap 10) — LogOS chose loud-failure-halt
  (no silent corruption) over the spec's `ErrorConcept`/`safe_eval` recoverable model. **An OS will
  likely need a recoverable Result/error-value layer ALONGSIDE loud halts** (a kernel can't halt on
  every error) — a real design decision to make before/early in the OS.
- **FFI** (Gap 11) — not built; by design. LogOS is sovereign — the syscall builtins ARE its FFI to
  the kernel; a general foreign-C FFI trades sovereignty for ecosystem-leverage. Recorded as a
  deliberate divergence (sovereignty wins unless a concrete need forces it).
- **Concurrency** (Gap 9) — LogOS has PROCESS concurrency (fork/execve/waitpid/pipe/sockets/poll),
  not the spec's THREAD/spawn/future model. Process-based is arguably right for an OS; partial by
  intent.
