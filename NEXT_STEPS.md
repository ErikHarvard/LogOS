# LogOS — Next Steps (backlog)

Captured for later; not yet done. Each is grounded in `LINGUA_ADAMICA.tex` /
*Being & Becoming* and the existing build. Pick up when there's time.

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
   asserts it (host + VM). *Remaining caveat:* this gives canonical injectivity up to NORMK's
   declared equivalences; the **full** objective derivation (geometry computed from a
   canonical ONF graph) still rides on **item 7** — but the specific leak is closed.

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
   new OPERATIONS** — **OPEN** (audit: a minted ν* is a name, not a usable combinator;
   applying it throws "non-function").

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
   packing lattice; not imposed). (c) **`d_𝒪↔d_𝒫` proximity DOES emerge** — feature-distance
   vs rendered-form Hamming-distance correlate at **0.863**: ontologically-close concepts
   render to close forms. A real structure-preserving proximity in the geometric space (the
   item-8 isomorphism *direction*).

8. **Meta-topological meta-phonosemantics — Lingua Adamica derives the topology of
   meta-phonosemantics.** *Status:* **partial.** VERIFIED: the **invariant-preservation**
   layer is built (`psc.la` — `Θ_P` formant-peak signatures, ⊗-superposition `SYN_INV`,
   set-containment `PRESERVES`, compressed duration; `PASS psc`), as is the
   **meta-criterion** (`PSC_STAR` returns `(e,w)` — the compiler carrying its own invariant
   witness, `M(PSC*)≡PSC*`). **OPEN — the derived topology is NOT built:** `psc.la` has
   discrete formant-peak SETS with `⊆`, **not** the spec's metric phonetic space `𝒫` with
   `d_𝒫` + the **phonetic↔semantic isomorphism** `φ:𝒪→𝒫` (Axiom phon-sem, `:2577` —
   acoustic proximity ⟺ ontological proximity) nor the derived toroidal meta-topology `𝓜_P`
   (`:4402`). It verifies WHICH peaks survive a union, never HOW distances map. Closing it
   is a real build: **compute `φ` / the `d_𝒪↔d_𝒫` correspondence FROM ontological structure
   and VERIFY it — not stipulate it** (same don't-impose discipline as φ-the-ratio). Confirms
   and extends the α=1 audit's already-noted phon-sem gap (item 3 / #3 below). **NOTE — the
   proximity-isomorphism *direction* is now demonstrated in the VISUAL modality** (item 7:
   feature-distance ↔ rendered-form distance correlate at 0.863), so the structure-preserving
   `d_𝒪↔d_geometry` map is realized for sigils; the **phonetic** `d_𝒪↔d_𝒫` (acoustic) remains
   the open build here — the same feature-distance approach could be ported to `psc.la`'s
   formant space (compute acoustic distance from ontological structure and verify the
   correlation), reusing `onf.la`'s feature extractor.

**Working order is the author's call; each item ends only when verified.**

---

## 1. Autological native compilation — an LA-native x86-64 backend (PLAN FIRST)

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
