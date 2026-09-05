# LA CLAIM INDEX — the 38 unbuilt items mapped to the paper's Ledger

Built 2026-09-05. **This file IS `LA_COMPLETION.md:770`**, which reads
`[ ] Every Tier-1/2 item above needs its paper counterpart at the right tag`.

## Why it was needed

`LA_COMPLETION.md` opens by claiming: *"Every item carries the gate that would
prove it, and its white-paper counterpart."* Measured: **2 of 38 unbuilt items
carry a `*Paper:*` reference** (4 occurrences of `Paper:` in the whole file).
The header was an unwitnessed claim, and it is the reason no one could say which
items serve which claims — or which would be closed by correcting a claim rather
than by writing code.

## The key, and why it can be trusted

Source: `~/Downloads/LA White Paper.pdf` (newest, 67,588 words). The Ledger is
**56 rows** across two tables. `pdftotext` splits it into three separate column
blocks, so component↔tag pairing is POSITIONAL and could silently mis-align —
the exact hazard that would make this whole index wrong.

**Pairing validated against seven independently known answers before use:**

| Ledger row | tag + bound | independently known to be |
|---|---|---|
| Bitwise operations | `[W]` six ops, byte-identical, five engines | landed `36325fc`; I re-verified the five-engine property today |
| Constant-time execution | `[A]` not held; three properties by discipline | build queue 4.2, verbatim |
| Phonetic injectivity at scale | `[A]` synthesis gated; collision test absent | build queue 0.1, verbatim |
| Privacy layer | `[B]` writable; no entropy source, no signatures | Tier 5 items 32 + 33 |
| Module reachability | `[B]` | `LA_COMPLETION.md:481` already cites *§Limitations, [B]* |
| Nine ungated modules | `[B]` | cited at `LA_COMPLETION.md:487` |
| Implicature | `[B]` | build queue 5.1 cites *Ledger row Implicature [B]* |

Counts also agree: 35 components ↔ 35 tags in table 1, 21 ↔ 21 in table 2.
Tag census over the whole paper: **[A] 74, [B] 253, [W] 192, [S] 0**; control
`[Q]` = 0, so the tag scan can report absence.

## Confidence column

`EXACT` — the paper's own text or an existing citation names this pairing.
`INFERRED` — I matched by concept; a reader should check before relying on it.

---

## THE INDEX

| # | key (derived from LA_COMPLETION.md, not hand-kept) | item | Ledger row / § | tag | effect of closing | conf |
|---|---|---|---|---|---|---|
| 1 | `the spec pipeline emits no export` | spec pipeline emits no `export` | Module reachability | `[B]` | `[B]`→`[W]` | EXACT — paper §5102 names the defect verbatim |
| 2 | `nine modules built but never gated` | nine modules built, never gated | Nine ungated modules | `[B]` | `[B]`→`[W]` | EXACT |
| 3 | `three gates that cannot go red` | three gates that cannot go RED | Gate falsifiability reach | `[B]` | widens *mutation lever reaches 2 of 46* | EXACT |
| 4 | `⊂ is never used measured 2026` | **⊂ is never used** | Five operators as glyphs; form law | `[W]` | ⚠ **CHALLENGES a [W]** | INFERRED |
| 5 | `the elision layer 4 of 79` | the elision layer | Core Lexicon size / §XVI | `[W]` | bound restated | INFERRED |
| 6 | `the acquisition gap no syllabus glyph` | the acquisition gap | §XVI.2; *"no acquisition study exists"* | `[A]` | the paper's own falsification bet | EXACT |
| 7 | `phonseq must detect the new ▷` | `phonseq` must detect ▷ | Goertzel acoustic verification | `[W]` | tightens *compound demoed [B]* | INFERRED |
| 8 | `⊕ round trip corrupts its second` | ⊕ round-trip corrupts child 2 | Invariant preservation, both registers | `[W]` | ⚠ **CHALLENGES a [W]** | INFERRED |
| 9 | `⊕ associativity is phonetically invisible identical` | ⊕-associativity phonetically invisible | Trimodal identity | `[W]` | ⚠ **CHALLENGES a [W]** | INFERRED |
| 10 | `⊗ has no temporal signature either` | ⊗ has no temporal signature | Trimodal identity | `[W]` | ⚠ **CHALLENGES a [W]** | INFERRED |
| 11 | `psc_star still pairs raw phonym with` | `PSC_STAR` pairs raw PHONYM/SPEC | Trimodal monosemy, all registers | `[W]` | ⚠ **CHALLENGES a [W]** | INFERRED |
| 12 | `⊗ renders as juxtaposition not fusion` | ⊗ renders as juxtaposition | Trimodal identity | `[W]` | ⚠ **CHALLENGES a [W]** | INFERRED |
| 13 | `catalogue wide sigil injectivity all forms` | catalogue-wide sigil injectivity | *(visual analogue of Phonetic injectivity at scale)* | **NONE** | ⚠ **PAPER GAP** — phonetic has a row, visual has none | EXACT (absence) |
| 14 | `visual round trip no bitmap structure` | visual round trip (no bitmap decoder) | Invariant preservation, both registers | `[W]` | ⚠ **CHALLENGES a [W]** | INFERRED |
| 15 | `the triple bar as a biconditional` | triple bar as biconditional | Trimodal identity | `[W]` | strengthens to ≡ | INFERRED |
| 16 | `one normaliser not five normk canoniq` | one normaliser, not five | Monosemy (κ invertible; NORMK) | `[W]` | removes *relative to declared theory [B]* | INFERRED |
| 17 | `acquisition the codex never gives a` | acquisition (Tier 3) | **duplicate of #6** | `[A]` | — | EXACT |
| 18 | `ontofelicity live enforcement perform currently reports` | `ontofelicity` → live enforcement | Ontopragmatics (3 modules) | `[W]` | report → enforcement | INFERRED |
| 19 | `derived glyph catalogue + agreement gate` | derived glyph catalogue + gate | Census verifiable from paper | `[A]` | `[A]`→`[W]` | EXACT — build queue 0.2 |
| 20 | `κ meta pattern compression when the` | κ\* meta-pattern compression | Compression floor | `[B]` | lowers Θ(distinct subterms) | INFERRED |
| 21 | `executable minted operations ν minted operations` | executable minted operations (ν\*) | Meta-sigils (operations as glyphs) | `[W]` | removes *minted; not yet executable [B]* | EXACT — bound names it |
| 22 | `the fractal monoglyph depth recoverable by` | the Fractal Monoglyph | Form constant, depth ≥ 2n | `[B]` | `[B]`→`[W]` | INFERRED |
| 23 | `the operators ∂δγρ𝔄 as glyphs roadmap` | operators ∂δγρ𝔄 as glyphs | Meta-sigils | `[W]` | extends the minted set | INFERRED |
| 24 | `self verifying grammar roadmap 2564 grammar` | **self-verifying grammar** | **Self-description (grammar as data)** | `[W]` | closes *full self-parse open* | EXACT — bound names it |
| 25 | `self meta programming the changed thing` | self-meta-programming | Self-modification loop | `[W]` | tightens | INFERRED |
| 26 | `meta autopoiesis and the gate that` | meta-autopoiesis | Meta-autontopoiesis (state) | `[A]` | closes *loop not closed unassisted* | EXACT |
| 27 | `lack driven wants wire aatc s` | lack-driven wants | Meta-autontogenesis (threshold) | `[W]` | tightens | INFERRED |
| 28 | `aware / c predicates awareness appears` | `AWARE` / `C` predicates | — | **NONE** | ⚠ **PAPER GAP** — prose only, no Ledger row | EXACT (absence) |
| 29 | `proto_agent the one chain tail item` | `PROTO_AGENT` | Self-invocation | `[A]` | *"the deepest gap"* | EXACT — build queue 3.5 |
| 30 | `the algebra of naming s companions` | Algebra of Naming's companions | — | **NONE** | ⚠ **PAPER GAP** | INFERRED |
| 31 | `the meta word ablation gate remove` | meta-word ablation gate | Gate falsifiability reach | `[B]` | widens the mutation lever | INFERRED |
| 32 | `a signature scheme no public key` | a signature scheme | Privacy layer | `[B]` | closes *no signatures* | EXACT — bound names it |
| 33 | `entropy on the metal no rdrand/rdseed` | entropy on the metal | Privacy layer | `[B]` | closes *no entropy source* | EXACT — bound names it |
| 34 | `trans species a second functor one` | trans-species: a second functor | §X trans-species | `[B]`/`[A]` | already *consent-gated by design* | EXACT |
| 35 | `the language deepens with its agents` | language deepens with its agents | — | **NONE** | ⚠ **PAPER GAP** | INFERRED |
| 36 | `fix trimodal wherever a fourth modality` | fix "trimodal" where a 4th modality exists | Trimodal identity **vs** Fourth modality (haptic) | both `[W]` | ⚠ **TWO [W] ROWS CONTRADICT** | EXACT (both rows present) |
| 37 | `the ledger is a plain tabular` | Ledger `tabular` can't break across pages | the Ledger itself | — | typesetting | EXACT |
| 38 | `every tier 1/2 item above needs` | every item needs its paper counterpart | — | — | **THIS FILE closes it** | EXACT |

---

## WHAT THE INDEX FOUND

**1. The overclaim track is near-empty.** Of the four claims reported as
overclaims, `lossless` is already bounded in its own sentence (*"Lossless over
meaning; lossy over spelling, by design [B]"*, plus *"invariant-preserving, not
lossless"* twice); `Perfect Communication` and `Completeness Commitment` appear
in NEITHER paper, and the paper explicitly disclaims the strong reading
(*"The claim is not that ambiguity is impossible in principle"*); `dolphin` has
one hit, about Khoisan clicks being producible by dolphins, not a speaker claim.
**No unbuilt item is closed by correcting any of the four.**

**2. Eight items CHALLENGE a `[W]`, they do not close an `[A]`** — #4, 8, 9, 10,
11, 12, 14, and the #36 contradiction. This is the opposite of backlog: a `[W]`
is a claim the paper says is *witnessed*, and these say the witness is
incomplete. ★ **They should be triaged before any `[A]` work**, because an
overstated `[W]` is worse than an open `[A]` — the same ruling this project
already made about gates that cannot go red.

**3. Four items have NO paper counterpart at all** — #13, 28, 30, 35. Each is
either work the paper never licensed, or a genuine paper gap. #13 is the
sharpest: **phonetic injectivity has a Ledger row and an `[A]`; visual
injectivity has neither**, though the trimodal claim asserts the registers are
identical.

**4. Only 6 of 56 Ledger rows are `[A]`** — Self-invocation, Constant-time,
Phonetic injectivity, Meta-autontopoiesis, Census verifiable, E_S in the
lexicon. The other 68 `[A]` tags in the paper are inline, not Ledger rows, so
the Ledger is NOT a complete claim index and should not be treated as one.

## HOW TO KEEP THIS TRUE

The failure this file exists to fix is a header claiming a property nothing
checked. So: **every `[ ]` item in `LA_COMPLETION.md` must appear in the table
above.** That is mechanically checkable, and until a gate checks it, this file
carries the same defect it was written to correct.
