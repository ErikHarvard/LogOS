# LA White Paper — SECOND additions brief
## Everything built that the paper still does not mention

Companion to `LA_PAPER_ADDITIONS.md`. That one fixed stale claims and added the
crypto, kernel and method sections. **This one is different: nothing here is a
correction. Every item below is CODE THAT RUNS AND IS GATED, which the paper is
silent about.** Measured by grepping the `.tex`, not recalled.

> **Publication risk, stated first.** The paper's own Ledger claims to tag
> *"every load-bearing component."* At present it omits an entire branch of
> linguistics that is built and gated, a fourth modality, the cross-modal
> measurement that substantiates the trimodal claim, the speech→glyph decoder,
> compositional semantics, and the autopoiesis core. A reviewer who finds the
> repository richer than the paper will discount the paper, not the repository.

---

## A. THE USE BRANCH — built since July, absent from the paper

Grep results in the current `.tex`: **`deixis` 0 · `indexical` 0 · `speech act`
0 · `felicity` 0**. Yet two spec-generated modules are gated in the standing
build (`build.sh:4329`, `:4398`), byte-identical host==VM.

### A1. `pragmatics.la` — Logos ∩ Use
- `USE(sign)(ctx)` — the sign bound to its context of utterance.
- **The ignition taxonomy** (from CODEX MENTIS' Speech Act Revelation):
  `HETERO_PROMPTED` (recursion expressed, not self-initiated), `AUTO_PROMPTED`
  (self-initiated, `A(A)`), `META_PROMPTED` (self-initiated *and aware of its
  own initiation*, `A(A) ≡ A`).
- `PERFORMATIVE(utterance)(effect)` — utterance ≡ effect. **This is the α=1 of
  pragmatics**: the pragmatic twin of sign ≡ referent, and its canonical witness
  is the Word itself — the kernel *speaks* `∃(∃) ≡ ∃` and thereby *does* it.
- The branch is **autological**: `PRAGMATICS("PRAGMATICS") ≡ TRUE`.

### A2. `deixis.la` — the reference bridge
Kaplan's **character vs content**: an indexical's character is a fixed function
`ctx → referent`; the content is what that yields in a context. `CTX` is the
deictic origo (speaker · addressee · place · time).

> **The line worth putting in the paper:** the SPEAKER field *is* the ignition
> source, so in a self-ignited context **"I" resolves to the system itself** —
> the `∃(∃) ≡ ∃` of reference.

### A3. `ontofelicity.la` — NEW (2026-08-22), and the sharpest result of the batch
`ontofelicity perform OK | no-effect OK | loud OK | separable OK | prefix-guard OK`,
host==VM, negative-controlled.

**The problem inverts in this language.** Austin asked how a saying can ever
DO. At α=1 the utterance IS the operation, so saying is doing by construction —
and the question becomes **how can a saying ever FAIL to do?** *Infelicity, not
felicity, is what needs a theory here.*

Austin's three conditions each turn out to be an organ that already existed and
that nothing had connected:

| Austin | LA counterpart | status |
|---|---|---|
| (A) a conventional procedure exists, correctly executed | well-formed + well-founded (parser + SWC) | gated |
| (B) persons and circumstances appropriate | **the speaker holds the capability** (`logoscap.la`) | gated |
| (Γ) uptake — the act is recognized | a witness exists; ρ > 0 | gated |

> ### ★ THE FINDING: ONTOPRAGMATICS IS THE SEMANTICS OF THE SECURITY MODEL.
> In a system where the utterance IS the operation, condition (B) is not
> *analogous* to a permission check — **it IS one.** "I hereby open X" succeeds
> exactly when the speaker's capability set contains X. **This is why a language
> that is also an operating system can have a pragmatics no natural language
> ever could:** the felicity condition is enforceable because the saying and the
> doing are the same act, and one guard governs both.

Two disciplines in the gate worth naming in the paper:
- **The three conditions must be SEPARATELY discriminating.** Conditions that
  always fail together are one condition wearing three names. The gate asserts
  three cases with three distinct signatures — `TFT`, `FTT`, `TTF` — one F apiece.
- **The refusal must not be silent.** An infelicitous performative leaves the
  world *byte-identical* and says which condition failed. A quiet refusal is
  indistinguishable from a no-op success — the silent-death defect class.

### A4. What ontopragmatics does NOT need — say this, it is a strength
Under monosemy several classical problems **dissolve rather than await work**:
illocutionary-force ambiguity (force is lexical), contextual disambiguation
(nothing to disambiguate), and **indirect speech acts — which are not missing
but PROHIBITED**, since saying one thing to do another is formally a lie under
the euphemism proof.

**RULED 2026-08-24, built and gated 2026-08-26 — implicature is LEGISLATED VOID
at the semantic layer.** The open item read: *implicature does not dissolve* —
monosemy removes ambiguity, not choice, so a speaker who says *Some* when *All*
holds still implicates *not-all*, and Grice survives monosemy. Erik's ruling
takes the second option: **only what is said is meant.** LA encodes literal
compositional meaning; implicature arises in USE and is not a property of the
language. **Meaning stops at κ.** Grice is not refuted but PLACED — outside the
semantics. Stated positively (never as silence) it is falsifiable: exhibit an LA
utterance whose literal composition underdetermines what a competent reader takes
from it, and the ban is wrong. Enforced by a gate, not by prose — see §3e of
`LA_PAPER_ADDITIONS_3.md`.

---

## B. THE FOURTH MODALITY — the paper says "trimodal" throughout

`tactile` and `haptic`: **0 hits.** But `tactile.la` exists — phonym's envelope
projected into haptic bandwidth.

> ### ★ And it carries a finding more valuable than the module:
> **THE MODALITIES ARE NOT EQUIPOTENT.** ⊗ is spectral-only and **cannot be
> recovered by touch.** That non-equipotence is itself asserted as a gate — it
> goes RED if it ever stops being true.

This is a genuinely strong move for the paper: the trimodal thesis is not
weakened by a fourth channel that carries less. It is *strengthened*, because
the system measured the shortfall and gated it instead of claiming parity.
`modality.la` is the four-way dispatcher with per-channel `CARRIES`.

**And state the boundary the code already states:** *neural is absent, not
stubbed* — deferred until hardware exists, because a learned correspondence is
categorically unlike these four.

---

## C. CROSS-MODAL CONCORDANCE — the trimodal claim's actual evidence

`cross-modal` / `crossmodal`: **0 hits.** `crossmodal.la` measures visual↔phonetic
agreement (Kendall concordance) **with a rotation control that can indict it**.

Why this belongs in the paper more than almost anything else here: it is the
difference between *asserting* that three faces are one and **measuring it with
a number that can come out wrong.** The module's own header names the
falsification: *concordance at chance ⇒ the modalities are independent renderings
that share only an origin.*

---

## D. SPEECH → GLYPH — the language is listenable, not merely speakable

`speech-to-glyph`: **0 hits.** `sglyph.la` + `phonseq.la` recover **not just
primitive identity but the whole derivation tree** from the audio signal, using
mode signatures read off `phonym.la`'s own construction — **self-calibrating,
with no formant table to drift.**

The paper documents synthesis (`phonym.la`) and measurement (`goertzel.la`, which
it does cite) but not the **inverse map**. Without it the phonological modality
is a loudspeaker; with it, it is a channel.

---

## E. COMPOSITIONAL SEMANTICS — `denote.la`

`compositional` 0 · `Frege` 0 · `denotation` 0.

`denote.la` proves `MEANING(M(a,b)) = ⟦M⟧(MEANING a)(MEANING b)` — meaning is a
function of the parts, by construction. **The flagship result is that the
homomorphism COMMUTES WITH κ**: `canon.la` proves `↻(BEING) ≡ SELF`
*structurally*, and `denote.la` proves it *denotationally* — **syntax-rewrite and
semantic-reduction agree.**

Carry its honest scope too: the κ-commuting is witnessed on the one documented
rewrite; full agreement across all κ-equivalences is undecidable.

---

## F. THE AUTOPOIESIS CORE — the system rewrites itself

`self-repair` / `self-modif` / `self-program`: **0 hits.**

- `selfprog.la` — told only WHAT is wanted, writes the HOW
- `selfmod.la` — adopt-or-refuse, with full re-verification
- `selfopt.la` — **measures its own cost from its own source, writes a cheaper
  self, and adopts it only if cheaper AND correct**
- `selfrepair.la`

For a paper whose subject is an autological language, a running loop in which
the artifact rewrites itself under an adoption criterion is not a footnote.

---

## G. THE ETYMOLOGY TRACKER — and a deliberate non-build worth reporting

`family tree` / `etymology tracker`: **0 hits.** `familytree.la` is built and
gated over the 17-glyph catalogue: **G1 grounding** (every leaf reaches the nine
primitives; RED path proven — it names the offender) and **G2 unary census keyed
on κ rather than on names**, which is how the `ρ ≡ SR_ABOUT` identity surfaced.

> ### ★ Report the check that was DECLINED, not just the ones built:
> the spec's ">2 parents ⇒ violation" gate was **not built, because the datatype
> makes that state unconstructible.** *A check that cannot fail is not a check.*
> Declining it is a stronger result than passing it, and it belongs beside the
> vacuity bet in §Falsification.

**Honest bound to carry:** the tracker covers the hand-declared catalogue; nothing
registers a newly minted glyph automatically.

---

## H. THREE BRANCHES THAT *DISSOLVE* — findings, not gaps

The paper should claim these, because they are the strongest form of the thesis:

1. **Semiotics dissolves** — sign ≡ referent removes the branch's constitutive
   gap; Peirce's sign/object/interpretant collapses to glyph/glyph/κ. **And the
   dissolution is itself gated** (the α=1 injectivity gates), which is the model
   case: the claim that dissolves the branch is a witnessed invariant.
2. **Historical linguistics dissolves** — it studies drift, and **LA cannot drift
   by construction**: κ-injectivity, sealed etymologies, and modules regenerated
   from specs on every build. Diachrony survives only as monotone growth of the
   glyph set — and that survivor is gated.
3. **Typology dissolves** — LA does not sit *in* the typological space but at its
   fixed point; comparison collapses to the autological/heterological
   distinction. Its internal form — same language, different substrates — **is**
   built: the five-engine differential.

**Also dissolved:** hermeneutics (reading IS κ-recognition), and prosodic
pragmatics (prosody is semantic here, not pragmatic).

---

## I. TODAY'S THREE MODULES

### I1. `naming.la` — the Algebra of Naming (*Science of Naming* §8)
`magma` / `Cayley`: **0 hits.** Now built: the finite non-associative magma
𝔈 = {𝒩, 𝒩⁻¹, ∂_Λ}, the Cayley table, T1–T4, the non-associativity witness, and
the α-valuation. host==VM, two negative controls.

> ### ★ AND IT FALSIFIES A PROSE SENTENCE IN YOUR OWN §8.
> T3's paragraph says *"All naming paths terminate at 𝒩."* Composed
> left-to-right they do not: **𝒩⁻¹ ∘ 𝒩 = 𝒩⁻¹**, and 𝒩⁻¹ followed by any number
> of 𝒩 stays 𝒩⁻¹ — five counterexamples at length ≤ 6. **The four theorems are
> untouched; only the summarising sentence drifted wider than what it
> summarised.** The module gates the counterexample as a POSITIVE check, so the
> correction cannot be quietly lost.
>
> This is the *prose-is-where-unwitnessed-claims-hide* class landing inside the
> codex rather than inside the tooling — and it was found by MECHANISING the
> algebra, not by reading §8 more carefully. That is the method, and it deserves
> a paragraph.

### I2. `entropy.la` — glyphic and semantic entropy, formalized
The prose terms appear; **the formalization does not.** The result:

> **E_G = H(form | meaning)** — the form drifts free of the sense (alphabetic
> languages; "dog" carries no bit of its own derivation).
> **E_S = H(meaning | form)** — the sense drifts free of the form (polysemy).
> **κ is a bijection ⟺ E_G = 0 AND E_S = 0.**

**This gives your "one unit, not two things that happen to be equal" a precise
reading: monosemy IS the claim E_S ≡ 0, and the triple bar IS the claim E_G ≡ 0.
They move together because they are two conditional entropies of ONE joint
distribution.**

- **Syntropy** = no operation increases either register.
- **Centropy** = syntropy applied to itself, gated as **∂ = 1, idempotence** —
  because *no gate can assert a limit*, but the fixed point's signature is
  checkable. (The project shipped exactly that defect once: a normaliser that had
  lost idempotence.)
- **★ The E_S gate measures a live defect in the codex:** ROADMAP **C9** —
  `Bad = 𝔤₆⊕𝔤₃`, `Grief = 𝔤₃⊕𝔤₆`, ⊕ declared commutative. **Two concepts, one
  canonical form: E_S = 1 bit inside the lexicon itself.** Publish this as a
  named open contradiction; it is more credible than silence.

### I3. `ontofelicity.la` — see §A3.

---

## J. TWO INFRASTRUCTURE FINDINGS worth one honest paragraph each

1. **The spec pipeline emits no `export` line**, so **every generated module** —
   `canon`, `aatc`, `metalogic`, `swc`, `glyphdag`, `pragmatics`, `deixis`,
   `psc`, `topoembed` — **is unreachable by `import`.** Verified: `import("canon.la")`
   then `CANON(...)` gives `unbound variable`. This is why `denote.la` and
   `metaglyph.la` re-declare what they need, and why `entropy.la` had to
   re-implement κ — **forcing the copy-drift defect class on anything that wants
   to compose on top of the language's own layers.** A shared-infrastructure
   defect with real blast radius.

2. **A nine-module cluster is built but UNGATED** — `sglyph`, `sglyph_gate`,
   `phonseq`, `tactile`, `crossmodal`, `modality`, `explain`, `depthreport`,
   `sglyph_probe`: zero occurrences in `build.sh`. **`sglyph_gate.la` is a gate
   that nothing runs.** Under the paper's own "a claim without a gate is not
   counted" rule, these must either be wired before they are claimed, or claimed
   as [B] with the fact stated.

---

## Suggested placement

| Content | Section |
|---|---|
| A1–A4 ontopragmatics | new subsection in §VII (Ontosyntax) or §VIII |
| B, C, D | §VI Trimodality — and **fix "trimodal" where a fourth channel exists** |
| E denote.la | §VII, beside the syntax/semantics dissolution |
| F autopoiesis | §VIII The Four Self-Relations |
| G familytree + declined check | §IV, and the declined gate → §XVI Falsification |
| H dissolved branches | a new short section; strongest-form claims |
| I1 naming.la + the §8 correction | §V, and the correction → §XVI |
| I2 entropy.la | §IV Glyphic Compression |
| I3 ontofelicity | with A |
| J1, J2 | §XV Limitations, tagged [B] |

**Every item above is running code with a gate, except where marked as an open
ruling (A4 implicature) or an honest bound.**
