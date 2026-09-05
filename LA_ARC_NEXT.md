# The arc after Tier 0 — implementation spec

**2026-08-24. Written while `build.sh` runs**, because every module these items
touch is referenced by `build.sh` (canon 22×, phonym 12×, grammar 9×,
pragmatics 6×, archroot 4×) and editing one mid-run means the build tests a
half-finished edit. Nothing here executes. Each item is specified to the point
where it can be built the moment the build reports.

Order is Erik's: **grammar-as-data first, then laws, operators, morphology** —
with the four rulings folded in where they belong rather than queued behind.

---

## R-A — `⊗(A,A) ≡ A` HOLDS ONLY FOR THE ARCHĒ

**Ruling:** the equivalence holds for the Archē alone. For every other A,
`⊗(A,A)` is a distinct compound. Document as a principled choice.

**Why the documentation is the load-bearing half.** Today the general case is
distinct — but it only became distinct this session, and by a *renderer* fix:
`⊗(A,A)` was byte-identical to `A` in sound because with identical parents any
weighted blend collapses, `(2g+g)/3 = g`. So an infinite family of distinct
glyphs shared one phonym and the renderer, not the theory, was deciding. A rule
that currently holds by accident is not yet a rule.

**Build:**
1. `canon.la` — add the Archē case to `REWRITE_MC`'s neighbourhood as a named
   rewrite, beside `↻(BEING) → SELF` and `↻(𝓡) → 𝓡`. It belongs in the same
   declared-equivalence set, not in a special case elsewhere.
2. Gate in **both registers**, since the defect appeared in one and not the other:
   - glyphic: `NIS(⊗(Archē,Archē))(Archē)` is TRUE, and
     `NIS(⊗(LOVE,LOVE))(LOVE)` is FALSE
   - phonetic: the same pair over `PHONYM_N`
3. **Red path:** if the general case ever collapses again — a renderer change
   that reintroduces the average — the FALSE assertion goes RED. That is the
   arm that was missing when the collapse shipped.

**Bound to state:** this is a declared equivalence, not a discovered one. It
joins the rewrite set, and `NORMK`'s honest bound applies — monosemy is enforced
relative to an extensible equivalence theory, not absolutely.

---

## R-B — IMPLICATURE BANNED AT THE SEMANTIC LAYER

**Ruling:** LA encodes literal compositional meaning. Implicature arises in use
but is **not a property of the language**.

**Build:** prose, plus one constraint that has to be mechanical or it will erode.
1. `pragmatics.la` header — state the ban positively. Grice is not refuted; he is
   placed **outside the semantics**. The existing note already says implicature
   *survives* monosemy and needs a ruling; replace it with the ruling.
2. The Logolaconic Principle (`:6747`) is a density principle and does not say
   this. Paper: add the sentence, at that tag.
3. ★ **A standing constraint:** `pragmatics.la` must not grow a defeasible
   quantity layer. Worth a gate, because "we decided not to build it" decays
   into "someone built it" across sessions. Cheapest form: assert the module
   defines no `IMPLICATE`/`SCALAR`/`QUANTITY` glyph, with the ruling cited in
   the failure message so the next author reads the decision rather than the
   symptom.

**Why a positive claim, not silence:** a language that simply lacked implicature
would be indistinguishable from one that had not got round to it. The claim is
that meaning *stops* at κ, and that is falsifiable — exhibit an LA utterance
whose literal composition underdetermines what a competent reader takes from it,
and the ban is wrong.

---

## R-C — ★★ GENERATE FROM THE ROOT (the largest of the four)

**Ruling:** the six primitives that do not derive from the root are a **GAP**,
not a result. Derive them, or name them as honest axioms with the seam stated.
**No stipulation.**

**What this reverses.** `archroot.la` concluded that only THREE of nine derive
(SELF, RECOGNITION, LOVE) and six are co-primitive, and reported that as a
settled corpus-honest finding. The ruling re-tags it: an incompleteness to close,
not a fact to report. **`archroot.la`'s header must be re-tagged first** — while
it reads "settled", every downstream claim inherits the wrong status.

**Build, in order:**
1. **Re-tag** `archroot.la`: "settled finding" → "the gap, per Erik's ruling
   2026-08-24". Do this before any derivation work, so nothing cites the old
   status meanwhile.
2. **Attempt derivation** for each of the six (BEING, RELATION, VOID, BECOMING,
   FORM, DEPTH). Each attempt has exactly three honest outcomes:
   - **DERIVED** — a chain from the root, gated, with the reduction witnessed
   - **AXIOM** — named as such, with **the seam stated**: what it is not derived
     from, and why the attempt failed
   - **not yet attempted** — and said so
   ★ The middle outcome is a *result*, not a failure. What is forbidden is the
   fourth thing: a chain that looks like a derivation and is a stipulation.
3. **The discriminator that keeps this honest.** A derivation must be witnessed
   by REDUCTION, as `dyadseed.la` witnesses VOID ≡ Church zero and BECOMING ≡
   successor — not by assertion, and not by a name that merely resembles a root.
   If the reduction does not run, it is an axiom.
4. ⚠️ **`dyadseed.la` may NOT be cited as the chain this asks for.** It grounds
   the *arithmetic stratum beneath* the primitives (VOID ≡ 0, BEING ≡ 1 by eta,
   BECOMING ≡ successor). That is a different claim from "the nine derive from
   the root", and conflating them is exactly the stipulation the ruling forbids.

**Expect this to be the hardest item in the arc.** It is also the one whose
honest outcome may be "six axioms, seam stated" — which would be a real result
and must not be treated as a failed sprint.

---

## R-D — A SECOND PHONETIC CUE FOR ⊗ AND ▷

**Ruling:** an accent mark alone is insufficient for the two most-used
operators. Add duration, stress pattern, or a consonant-cluster distinction, and
it must survive across rendering environments.

**The measurement it answers** (`phoncoll.la`, 2026-08-24): **all fifteen**
stress-only pairs in the vocabulary are the same operand pair under ⊗ versus ▷.
Census ⊗=59, ▷=24. **Thirteen of the fifteen are the codex's own entries.**

**Build:**
1. Choose the cue. Ranked by what this phonology already supports:
   - **duration** — cleanest; ▷ already carries a rate marker in PCM, so the
     written form would be following the audio rather than inventing
   - **consonant cluster** — most robust to a lossy channel, most invasive to
     the existing lexicon
   - **stress pattern** (e.g. secondary stress) — least invasive, weakest
2. ★ **It must hold in the ROMANISED register**, not only in PCM. That is the
   whole point of the ruling: ▷ gained a rate-carried marker in audio this
   session and the fifteen collisions persisted, because the romanisation is
   what a person reads and writes.
3. **Re-run `phoncoll.la`.** The pinned stress-only set must SHRINK toward
   empty. It is pinned, so it cannot change silently in either direction.
4. **`phonseq.la` must then DETECT the new cue.** It currently reports ▷ as a
   leaf. A cue the decoder cannot see is a cue only the writer has.
5. **Red path:** two concepts differing only in ⊗-vs-▷ must come out distinct in
   the romanised form. Today all fifteen do not — so the fixture already exists
   and already fails, which is the ideal starting condition.

---

## THE ARC PROPER — grammar-as-data, laws, operators, morphology

### 1. GRAMMAR AS DATA (L3 — full self-parse)
`grammar.la` has **L1 + L2**: the productions are read off `parser.la` rather
than invented, and `fuzz_grammar.py` differentially checked them 60/60 on BOTH
the accept and the reject side. L3 — the grammar parsing **itself** — is open,
and the scope was decided by Erik on 2026-08-18: L3 only after L2 is green, and
**reported PARTIAL if it lands bounded**.
**Discriminator:** `GPARSE` applied to `grammar.la`'s own source must reproduce
the same verdicts `parser.la` gives, on the same corpus. Bounded self-parse is
an honest result; unbounded is the goal; a self-parse that succeeds only on a
corpus chosen after the fact is neither.

### 2. THE LAWS
The three laws already exist as glyphs over ≡ (`metalogic.la`) and now as gates
over PROPOSITIONS with separable failure (`prop.la`: FTT/TFT/TTF). What remains
is the **ladder**: the Semiotic-Ontoglyphic Ladder (7 levels) and the
Substitution Test, plus **α is binary in code and graded in the paper** — a live
discrepancy that must be resolved in one direction and stated.

### 3. THE OPERATORS
`∂ δ γ ρ 𝔄` are currently **hardcoded dispatch** and must become glyphs
(ROADMAP:2567), plus the four missing audit operators `|G|`, `|G_meta|`, `ς`,
`μ`. `metaglyph.la` already did this for the five combination modes, so the
shape is known: give each an explicit κ-decomposition, and the sigil and phonym
follow for free because `SIGIL`/`PHONYM` walk any decomposition.

### 4. MORPHOLOGY
The **elision layer** — four of 79 entries diverge from the codex by vowel
elision (Think, Gratitude, Question, Past). These are visible inline in
`la_lexicon_appendix.tex` as `codex*` rows with both values. This needs a
phonological layer, **not a patch to the segment rules**: the codex prints
surface forms and the Operator Phonology generates underlying ones.
★ The stress rule was itself corrected this session — final vowel, not first —
found only by bringing the codex's example SENTENCES in as fresh vectors. **A
rule fitted to one table will agree with that table.** The elision layer needs
its own independent vectors for the same reason.

---

## THE STANDING CONSTRAINT ON ALL OF IT

Every item above lands with a gate that can go RED, and the red path is
exercised, not asserted. Where an item's honest outcome is "this is a limit",
that is stated as a result rather than deferred — the four rulings above include
one (R-C's axioms) whose best outcome may be exactly that.
