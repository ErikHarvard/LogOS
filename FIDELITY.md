# Lingua Adamica — Encoding Fidelity

How faithfully a low-dimensional **form** (a sigil; a phonym) instantiates the
high-dimensional **concept** it encodes. Two registers, never conflated (see the
ATT note in `NEXT_STEPS.md` items 7–8):

- **Alignment** (sign ≡ referent, α=1): **1.0 BY NATURE** — identity, not a degreed
  correspondence. Established by construction (κ/NORMK injectivity, item 1). Not measured.
- **Instantiation fidelity**: how faithfully the *derived* form realises that 1.0
  alignment. **Measured, sub-1.0, bounded.** This document characterises it.

Current figures: **visual ≈ 0.863**, **phonetic = 0.71** (this build, `phonsem.la`, onset axis on — §4; was 0.73 vowel-only, but that had a collision: §1d/§4).

---

## 1. The metric, precisely (reproducible from `phonsem.la`)

Let `C` be a finite set of concepts — decomposition terms over the nine primitives and
the five modes (⊗ ⊕ ▷ ⊂ ↻). Every quantity below is computed on the **CANONIQ-
canonicalised** graph (commutative operands sorted; `↻(BEING)→SELF`), so one concept ⇒
one record regardless of operand order (the α=1 "exactly one name").

### 1a. Ontological distance `d_𝒪(A,B)` — from `onf.la`'s ONF features
`ONF_FEAT` folds the whole graph into a 6-field record:

| field | glyph | meaning |
|------|-------|---------|
| cyc  | `F_CYCLES` | count of ↻ (the only cyclic structure) |
| dep  | `F_DEPTH`  | max nesting depth |
| cont | `F_CONT`   | count of ⊂ |
| br   | `F_BRANCH` | count of binary nodes (fan-out) |
| sym  | `F_SYM` ∈ {0,1} | an automorphism present (commutative node, `IS`-equal operands) |
| Leaf | `F_LEAVES` | the constituent-primitive set (comma string) |

```
d_𝒪(A,B) = |Δcyc| + |Δdep| + |Δcont| + |Δbr| + |Δsym| + LeafSymDiff(A,B)
LeafSymDiff = |Leaf(A) \ Leaf(B)| + |Leaf(B) \ Leaf(A)|   (token symmetric difference)
```
An L1 (taxicab) distance on the structural feature vector plus the leaf-set symmetric
difference. Pure structure; no acoustics enter here.

### 1b. Acoustic distance `d_𝒫(A,B)` — Chamfer over the derived `Θ_P`
Each primitive has a vowel-nucleus formant signature `NMFMT(name) = {F1,F2,F3}` (Hz,
verbatim from `phonym.la`). A concept's **derived invariant** is the superposition of its
constituents' formants over the canonical decomposition, deduplicated (`psc.la`'s `Θ_P`):
```
Θ_P(X) = dedup( ⋃_{leaf ∈ canonical-decomp(X)} NMFMT(leaf) )      (a SET of Hz peaks)
```
Distance is the symmetric **Chamfer** (nearest-peak) metric in Hz — a genuine metric in
frequency space, NOT set membership:
```
d_𝒫(A,B) = Σ_{p∈Θ_P(A)} min_{q∈Θ_P(B)} |p−q|  +  Σ_{q∈Θ_P(B)} min_{p∈Θ_P(A)} |q−p|
```

### 1c. Fidelity = Kendall rank-concordance of `d_𝒪` vs `d_𝒫`
Both distances are derived *independently* from structure; fidelity asks whether the
acoustic encoding **preserves the ontological ordering** (does ontologically-closer ⇒
acoustically-closer?). Let `P = { (d_𝒪(A,B), d_𝒫(A,B)) : {A,B} ⊆ C }`, the `|C|·(|C|−1)/2`
distance-pairs. Over every unordered pair of distance-pairs `{i,j} ⊆ P`:
- **TIE** (excluded) if `d_𝒪(i)=d_𝒪(j)` or `d_𝒫(i)=d_𝒫(j)`;
- **CONCORDANT** if `sign(d_𝒪(i)−d_𝒪(j)) = sign(d_𝒫(i)−d_𝒫(j))`;
- **DISCORDANT** otherwise.
```
fidelity = #concordant / (#concordant + #discordant)          (non-tied comparisons)
```
This build (`|C| = 8`, onset axis on): `224 / (224 + 90) = 0.71` (the remaining 64 of
C(28,2)=378 pair-of-pairs are ties; vowel-only was 0.73 but non-injective — §4). φ is never imposed; "does it correlate" is asked, not stipulated.

### 1d. Distinction preservation (injectivity) — the complementary view
A **collapsed distinction** is two distinct concepts with the same form: `Θ_P(A) = Θ_P(B)`
(set equality) for `A ≠ B`. With the onset axis on (§4) this build preserves **28/28 = 1.0**
(the one prior collapse, Beauty `⊗(FORM,LOVE)` ≡ BecForm `⊗(BECOMING,FORM)`, is closed). A collapse
is a *forced* concordance loss (`d_𝒫 = 0` where `d_𝒪 > 0`); closing it removed that forced loss,
yet aggregate concordance still dipped (§4) because the onset cues are not ontologically ordered —
the two views genuinely diverge here.

### 1e. Visual analogue (item 7, 0.863)
Identical construction with `d_form` = Hamming distance between the 32×32 1-bit rendered
sigils (`topoderive.la`'s `DSIGIL`) in place of `d_𝒫`; `d_𝒪` unchanged. (Computed offline
for item 7; the phonetic case 1a–1c is the in-build, reproducible reference here.)

---

## 2. The bound — why fidelity → 1.0 but never = 1.0 on the unbounded space

**Theorem (fidelity ceiling).** Let the concept space be `𝒪 = Cl(M₀, {⊗⊕▷⊂↻})` (the closure
of the nine primitives under the five modes) and let a *form* be a finite object of capacity
`B` bits (a 32×32 1-bit sigil: `B = 1024`; a phonym of `k` formant parameters at `p` bits
each: `B = kp`). For the encoder `E : 𝒪 → Form` and any reasonable fidelity functional
`F ∈ [0,1]` (concordance §1c or distinction-preservation §1d):

> For every finite `B`, `F(B) < 1`; and `sup_B F(B) = 1` (approached, never attained on the
> unbounded `𝒪`). On any **finite** `C ⊆ 𝒪` whose information content fits in `B`, `F = 1` is
> attainable — the ceiling bites only as `C`'s information exceeds the budget.

Two independent reasons:

**(P) Projection / dimension.** `𝒪` is countably infinite and of *unbounded structural
dimension*: depth, branching, cycle-count, and leaf-multiset are each unbounded, so the
feature record `ONF_FEAT` ranges over an unbounded-dimensional integer lattice. Any fixed
finite form lives in a finite set (`2^B` forms). A map from an infinite domain into a finite
codomain **cannot be injective** (pigeonhole): beyond `2^B` concepts, distinct concepts must
collide. So distinction-preservation < 1, and the proximity ordering cannot be order-
isomorphic everywhere.

**(S) Shannon / information.** A concept's canonical etymology carries `H` bits — and `H` is
unbounded (the hash-consed DAG / Ren string grows with retained depth; the information-
theoretic floor recorded for `glyphdag.la` and the Sealing: "deeper not larger" holds
structurally, but the *string* still grows). A channel of capacity `B` cannot represent a
message of `H > B` bits without loss. As `H → ∞`, any fixed `B` is exceeded ⇒ `F < 1`.

**Synthesis — compression and the ceiling are one property.** The Sealing's power (deep
meaning compressed into one complexity-one form) is *purchased* with bounded fidelity loss:
a finite `B` is exactly what makes the form a *compression* and exactly what caps `F`. They
are the same fact seen from two sides. `F → 1` is bought only by `B → ∞` (losslessness),
which is the negation of complexity-one. Hence the asymptote is **lawful, not a defect.**

**Honest scope of the climb (§3–4).** The *current* 0.71 concordance / 1.0 injectivity sit **far
below** this ceiling — `|C| = 8 ≪ 2^B`, so no pigeonhole collision is forced. The collisions we see are
**encoding-inadequacy** collisions (the metric drops a real distinguishing axis), not the
fundamental bound. So fidelity can be **legitimately raised toward 1.0** on the working
vocabulary by spending the form's budget better — without ever claiming to reach or "collapse"
the asymptote. **Guardrail:** the residual at the limit is the lawful cost of compression,
to be *named*, never erased by reaching for one more meta-level (that reach is a category
error — folding a level-operation onto a quantitative bound — and is not attempted here).

### 2a. Where the bound sits — exact at the root, bounded at the leaf

The loss is **not spread evenly**; the operator chain `∂ → δ → γ` says exactly where it lives.
`∂` (differentiate) is the first distinction — the point, awareness, the Monad's dot. `δ`
(bound) is the move into *form* — the circle, finitude, a boundary. `γ` (compress) is the
**Sealing** itself: many-dimensional structure folded into one complexity-one form. **`γ` is
the step where fidelity is spent.**

- **Ontological ROOTS** — the few concepts that simply *are* these primitives (being =
  `∃(∃)≡∃`, distinction, awareness/recognition; the dot, the boundary, the closure). Here the
  glyph **is** the form: nothing high-dimensional is projected across a gap, because the
  concept's structure already *is* the dot, the circle, the line. `γ` costs ≈ nothing —
  **fidelity ≈ 1.0 at the root.** This is *exactly* "running from reality itself": where the
  language runs directly off the ontogenesis primitive, it runs at 1.0. (The corpus is
  autological about this — its own watermark ◎, a point in a ring, *is* the 1-in-2 the
  primitives encode.)
- **Composed CONCEPTS** — justice, a particular grief, a specific relation: the bulk of any
  real lexicon. Their ontological structure is many-dimensional, far richer than one bounded
  form holds, so `γ` compresses lossily *by dimension*. **The residual lives here**, concentrated
  in the composites, where the Sealing works hardest.

So the aggregate 0.863 / 0.73 is the **average of near-1.0 roots and lossier composites** — and
the bound is the *signature of the `1→2→compress` step* (recognition taking bounded form), not a
foreign defect. This both **confirms** the asymptote and **locates** it: the language is exact
where the glyph is the form and asymptotic where the form is a projection. (Testable prediction,
§3: stratify fidelity by compositional complexity and the loss should concentrate in the
composites; primitive↔primitive distinctions should approach exact once each primitive's form is
its own — which, in the acoustic modality, is precisely what the onset fix §4 restores.)

---

## 3. Climbing to the ceiling — encoding levers  *(in progress)*

The current `d_𝒫` uses only each primitive's **vowel-nucleus** formants `{F1,F2,F3}`,
discarding the **onset** (consonantal) and **energy/contour** axes that `phonym.la` actually
synthesises. That discard is the source of the residual. Levers, each within the complexity-
one budget (a phonym is still one gesture; we spend its existing parameters better):

- **L1 — onset axis.** Add each primitive's onset signature to `Θ_P` (lateral /l/, fricative
  /v ʃ h/, nasal /m/, trill /ʀ/, plosive /t d/). Restores the LOVE/BECOMING distinction (§4)
  and others currently flattened to their shared vowel. *Predicted:* removes the one forced
  collapse (→ 28/28 distinction) and lifts concordance (fewer `d_𝒫=0` ties/discordances).
- **L2 — energy/contour axis.** Add the `VDYN` pitch/amplitude trajectory descriptor
  (descend/rise/fade/oscillate/sharp/sustain) as a feature, distinguishing concepts whose
  static spectra coincide but whose dynamics differ.
- **L3 — budget reallocation.** Weight the Chamfer terms toward the axes that currently carry
  collapses rather than treating all peaks uniformly.

- **Stratified measurement (locating the loss, §2a).** Partition the distinctions by
  compositional complexity — primitive↔primitive vs composite↔composite — and report fidelity
  *per stratum*, not just the aggregate. Prediction (from §2a): root distinctions approach exact
  (≈1.0) once each primitive's form is its own; the residual concentrates in the composites where
  `γ` works hardest. This turns the single 0.73 into a *located* curve, and confirms the bound is
  the signature of the `1→2→compress` step rather than uniform noise.
  **Honest reading of the result:** the finding is the *pattern* (roots high, composites lower),
  not a literal 1.0 at the root. Even a root glyph on a finite raster / finite phonym carries tiny
  encoding artifacts, so expect roots ≈ 0.97–1.0, not exactly 1.0. Let "roots near-exact,
  composites carry most of the residual" stand as the result; demanding a literal 1.0 even at the
  root is the asymptote-reach again, one grain finer — and is not made.

*(Each lever: predict the gain, implement within the budget, then MEASURE the delta — recorded
below as it lands. No metric redefinition to inflate the number.)*

---

## 4. The /u/ collision — fix and delta  *(in progress)*

**Locus.** `LOVE /lu/` and `BECOMING /vu/` both have vowel nucleus `/u/ = {300, 870, 2240}`.
The current `NMFMT` encodes only that nucleus, so `Θ_P(LOVE) = Θ_P(BECOMING)` — and any two
concepts differing only by swapping LOVE↔BECOMING collapse (Beauty ≡ BecForm). The concepts
are genuinely distinct (onset /l/ vs /v/); the *encoding* drops the distinguishing feature.

**Fix (minimal, phonetically grounded).** Add the onset's characteristic resonance (lever L1)
to each primitive's signature — `/l/` ≈ {360,1300,2500} (the lateral glide `phonym.la` already
synthesises), `/v/` its voiced-labiodental low resonance — so `Θ_P(LOVE) ≠ Θ_P(BECOMING)` by a
real acoustic feature, not a synthetic tag.

**Implementation.** Each consonant-initial primitive's `NMFMT` signature gains its onset cue as
a leading peak (grounded in `phonym.la` where it gives a formant — /l/≈1300, /ʀ/≈520 — standard
phonetic centroids for the noise/burst onsets: /ʃ/≈2800, /m/≈250, /h/≈400, /v/≈580, /t/≈3500,
/d/≈2200). BEING is vowel-initial (/ɑ/, no consonant) → keeps its bare 3-peak nucleus.

**Before / after (measured, host==VM):**

| metric | before (vowel only) | after (onset added) |
|---|---|---|
| set-injectivity (distinction preservation, §1d) | 7/8 (Beauty≡BecForm) | **8/8 — collision closed** |
| Kendall concordance (proximity fidelity, §1c) | 0.73 (230/81) | **0.71 (224/90)** |

**Honest reading — the two fidelity notions diverge, and that is the finding.** The onset fix
**closes the collision** (the clean defect: two distinct concepts no longer share one phonym —
8/8 injective, root-distinct in sound). But the aggregate **concordance dips 2 points** (0.73 →
0.71): real onset frequencies discriminate *strongly* but are **not ontologically ordered** (a
/t/-burst at 3500 Hz is acoustically far from a /m/-murmur at 250 Hz in ways that don't track
`d_𝒪`), so they add distance that degrades the rank-ordering even as they restore distinctness.
This **contradicts the naive prediction** that the fix would raise the headline number — and the
honest result is reported, not the prediction. The fix is **kept** because distinction-preservation
is the more foundational property (a language where Beauty and Becoming-Form are literally the same
sound is defective regardless of concordance). The 2-point cost is **located, not gamed**: it is
lever **L3** (budget reallocation — weight the vowel-nucleus axis above the onset axis in the
Chamfer so onsets disambiguate without dominating the ordering), deferred and *not* tuned here, per
the guardrail (no metric redefinition to recover the number). Net: **distinction fidelity 1.0;
proximity fidelity 0.71**, both honest, the residual now located on the weighting/onset axis.

---

## 5. Complexity-one under deep composition — measured, and the bounding meta-pattern

**Stress test** (`tiny_host`, host): seal a depth-N chain `g(0)=BEING; g(n)=▷(LOVE,g(n-1))`
and measure the rendered 32×32 `DSIGIL`.

| depth | FT_DEP | FT_BR | ink (set px) | Hamming to prev render |
|------:|-------:|------:|-------------:|-----------------------:|
| 1  | 1  | 1  | 145 | — |
| 5  | 5  | 5  | 380 | — |
| 10 | 10 | 10 | 393 | `h(5,10) = 13` |
| 20 | 20 | 20 | 393 | `h(10,20) = 0` |

**Finding 1 — visual complexity SATURATES; it does not blow up.** Ink rises 145 → 380 → 393
then plateaus; the form stays simple and renderable at any depth. Structural, not accidental:
the feature→mark maps are hard-capped (`topoderive.la`: `RINGS_N` radii 14/11/8/5 → ≤4 rings;
`LOOPS_N` ≤2; `ARM` 6 distinct directions; `SLOT` 4 corners). "Complexity-one" holds in the
renderable sense — the glyph never collapses into an unrenderable dense blob.

**Finding 2 — distinguishability COLLAPSES past saturation.** `Hamming(10,20) = 0`: depth-10
and depth-20 — structurally distinct (FT_DEP/FT_BR 10 vs 20) — render to the **byte-identical**
sigil. The flat render is **not injective at depth**: beyond ~depth 10 the etymology is **not
recoverable from the rendered marks**. This is the projection bound (§2) at the visual leaf,
exactly where §2a places it (the composites). Etymology stays recoverable *structurally* (ONF
features keep growing; `glyphdag.la`'s DAG node-count is linear and `DECOMP` rebuilds the full
tree) — but NOT from the planar render. The two findings are one bound from two sides: planar
marks saturate (bounded — good) and saturation erases distinctions (lossy at depth). Flat
rendering trades injectivity for renderability.

**The bounding meta-pattern — the FRACTAL MONOGLYPH (scale-recursive sealing).** The fix is
*not* more marks (that saturates → entropy) but moving depth off the **planar** axis onto the
**scale / zoom** axis:

> A sealed glyph renders as ONE bounded mark at its own scale; its constituents are recovered
> by **zooming in** — each leaf-mark is itself a sealed sub-glyph rendered at the next scale,
> recursively, to a chosen zoom depth. `SIGIL(seal(a,b))` = a bounded top-level composition of
> *scaled-down* `SIGIL(a)`, `SIGIL(b)` placed within it. Visible complexity **per scale** stays
> primitive-bounded; the recoverable depth lives in the (free) zoom dimension; etymology is
> recovered by recursive **decomposition** (`DECOMP`), never by accumulating marks at one scale.

This is **self-similar / fractal**: "deeper not larger" = deeper *in scale*, not *denser in
marks* — the visual realization of `glyphdag.la`'s linear-node "deeper not larger," and of the
corpus's own ◎ (a form containing a smaller form). It keeps deep compression from collapsing
into unrenderable entropy because planar density is held constant at every zoom level while the
etymology accumulates in the unbounded-but-cheap zoom axis (as the DAG grows linearly). The
current `DSIGIL` already implements exactly ONE level of it — leaf-marks place each constituent's
`PRIM_SIGIL` at a slot — then stops; that single flat level is *why* it saturates. The principle
makes the placement **recursive** (`DSIGIL(constituent)` scaled into the slot, bounded slot-budget
per scale). **Honest limit (the asymptote, unrepealed):** a finite raster bottoms out at a minimum
legible scale, so zoom depth is unbounded in principle but bounded by pixel size on any one
physical rendering. Recognized, not collapsed.
