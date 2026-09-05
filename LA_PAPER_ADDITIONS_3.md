# Lingua Adamica White Paper — Additions Brief III

## The master brief: everything the paper still owes the language

**Written 2026-08-23. For the session writing the paper in full.**

This is the current, load-bearing additions document. It supersedes nothing —
briefs I and II remain valid where they are unabsorbed — but it is the one to
work from, because it is the only one written *after* measuring what the paper
already contains.

---

## §0 — MANIFEST, AND THE STATE OF THE OTHER TWO BRIEFS

Three briefs exist. All three are in `~/logos/`.

| Brief | Covers | Status as of 2026-08-23 17:39 |
|---|---|---|
| `LA_PAPER_ADDITIONS.md` (483 ln) | stale claims, crypto, kernel, discriminating vectors | **largely ABSORBED** into the paper |
| `LA_PAPER_ADDITIONS_2.md` (294 ln) | the use branch, 4th modality, autopoiesis, denote, familytree | **PARTIALLY absorbed** — gaps listed in §2 |
| `LA_PAPER_ADDITIONS_3.md` (this) | what is *still* missing + everything built since + everything not yet built | **the working document** |

> ⚠️ **Both earlier briefs were in the trash** (`DeletionDate=2026-08-22T23:38`)
> and were recovered into the repo today. Brief I was probably deleted because
> it had been applied; brief II had not been, and deleting it was a loss. They
> are restored. **Do not delete a brief until its own checklist is green.**

### The method, and what it cannot see

Everything in §1–§2 was established by grepping
`~/Downloads/Lingua_Adamica_White_Paper.tex` (302 KB, mtime 2026-08-23 17:23)
for each module and each concept, and by reading the modules' own headers for
what they actually assert. Counts below are literal grep hits.

**The bound on that instrument, stated because this project's own rule
requires it:** a grep is *name-based*. A concept the paper describes under
different words will read as absent when it is present. So every item below is
a **candidate** carrying its evidence — verify against the section before
adding, and prefer to strengthen an existing passage over inserting a new one.
*An instrument that reports absence must prove it looked; this one looked only
for names.*

---

## §1 — MEASURED ABSENT: the highest-value gaps

Grep counts in the current `.tex`. Zero means the term never appears.

| Item | Term | Hits | Why it matters |
|---|---|---|---|
| Cross-modal concordance | `concordance` / `Kendall` / `cross-modal` | **0 / 0 / 0** | **the trimodal claim's only quantitative evidence** |
| The autopoiesis core | `self-repair` / `self-program` | **0 / 0** | the artifact rewriting itself under an adoption criterion |
| Compositionality theorem | `homomorph` | **0** | `denote.la`'s flagship: κ commutes with meaning |
| Speech → glyph | `speech-to-glyph` | **0** | the inverse map; without it the phonetic register is a loudspeaker |
| The Meta-Word | `Meta-Word` | **0** | `archroot.la` — completeness criterion 4 |
| Entropy on the metal | `RDRAND` | **0** | the crypto layer's load-bearing absence |
| The Algebra of Naming | `Algebra of Naming` | **0** (`magma` 3, `Cayley` 1) | present in fragments, not as the named result |

### 1a. Cross-modal concordance — the single biggest omission

`crossmodal.la` measures visual↔phonetic agreement by Kendall concordance
**with a rotation control that can indict it**. The paper argues the trimodal
identity throughout and never once cites the number that tests it.

> This is the difference between *asserting* that three faces are one and
> **measuring it with a statistic that can come out wrong.** The module's own
> header names its falsification condition: concordance at chance ⇒ the
> modalities are independent renderings that share only an origin — *"a real
> and publishable finding about the framework, not a bug."*

**★ And the control it REFUSED is as publishable as the one it used.** The
tempting control is to flip the sign of one distance and show concordance
inverts.

> **That control cannot fail — it is arithmetic, true of any two lists
> whatsoever, and would have been a fifth vacuous gate in a project that had
> already tallied four.** The control used instead **rotates** the acoustic
> distances by one position against the visual ones, breaking the pairing while
> preserving both distributions exactly. If the headline number is real
> structure, the rotated number must fall toward chance; if rotation changes
> nothing, the statistic is not measuring the correspondence and the headline
> means nothing. **So the control has a genuine way to indict the gate it
> guards** — which is the property the other four lacked.

**The bound must travel with it:** over *compounds*, both form and sound are
derived, so the statistic tests **derivation coherence**. Over the nine
*primitives* the sigils are transcribed, not derived — so the primitive rows
test transcription, not the thesis. Say which rows carry the claim.

### ★★ AND THEN IT WAS RUN — 2026-08-23. THE NUMBER IS AT CHANCE.

`crossmodal.la` was one of the nine modules built but never gated. Wiring it
meant running it, and running it changed what this section can claim:

| | |
|---|---|
| headline concordance (d_𝒱 ↔ d_𝒫) | **61%** (230 concordant / 145 discordant, n=8 concepts) |
| **rotated control** — pairing destroyed | **59%** |

> **Rotation changed two points.** Both numbers sit above 50, but *the control
> sits above 50 as well* — so the elevation is an artifact of the distance
> distributions, not of the cross-modal pairing, and the **2-point gap is the
> whole of the actual signal.** By the module's own falsification criterion —
> *"if rotation changes nothing, the statistic is not measuring the
> correspondence and the headline means nothing"* — **this is at chance.**

**⚠️ CORRECTION TO THE FIRST DRAFT OF THIS BRIEF.** It told the paper session to
feature this as the trimodal claim's evidence paragraph. **Do not.** On today's
measurement the trimodal identity has **no quantitative support from this
instrument.** Tag it **[A]** — argued, not gated — or report the measurement
with the control beside it, which is the more interesting move:

> *the system built the instrument that could indict its own central claim, ran
> it, and the claim did not clear its own control.*

That is publishable as a finding about the framework rather than a bug — the
module's header says so in advance, which is what makes reporting it honest
rather than embarrassing. What it is **not** is evidence for the identity.

`crossmodal.la` is now pinned in `build.sh` **as a REPORT, not a check**, so the
numbers cannot drift silently and no PASS line asserts concordance.

### 1b. The autopoiesis core

`selfprog.la` (told WHAT, writes the HOW) · `selfmod.la` (adopt-or-refuse with
full re-verification) · `selfopt.la` (**measures its own cost from its own
source, writes a cheaper self, adopts it only if cheaper AND correct**) ·
`selfrepair.la`. All shipped and gated.

**And carry the bound, which is sharper than the capability** — see §4, item
"self-meta-programming": these organs write, verify and adopt extensions that
are **never imported or executed**. The loop closes on *writing* a successor,
not on *becoming* one. **[B], not [W].**

### 1c. `denote.la` — the homomorphism

`MEANING(M(a,b)) = ⟦M⟧(MEANING a)(MEANING b)`. The flagship result is that the
homomorphism **commutes with κ**: `canon.la` proves `↻(BEING) ≡ SELF`
*structurally*, `denote.la` proves it *denotationally* — syntax-rewrite and
semantic-reduction agree.

Honest scope, which must travel with it: witnessed on the one documented
rewrite; full agreement across all κ-equivalences is undecidable. **[B]**

### 1d. Still-unabsorbed items from brief II

Re-verify each before adding; these read as absent or thin:

- **The fourth modality.** `tactile.la` exists (`tactile` 3 hits — check whether
  the paper still says "trimodal" globally). Its finding is worth more than the
  module: **the modalities are not equipotent** — ⊗ is spectral-only and cannot
  be recovered by touch, and *that non-equipotence is itself gated*, going RED
  if it stops being true. A fourth channel that carries less **strengthens** the
  trimodal thesis, because the shortfall was measured rather than papered over.
- **`familytree.la` and the DECLINED check** — the spec's ">2 parents ⇒
  violation" gate was **not built, because the datatype makes that state
  unconstructible**. *A check that cannot fail is not a check.* Declining it is
  a stronger result than passing it; it belongs beside the vacuity bet.
- **The three dissolved branches** — semiotics, historical linguistics,
  typology. Strongest-form claims, and each dissolution is itself gated.

---

## §2 — BUILT 2026-08-23: an entire layer the paper cannot know about

Everything in this section was written today, after the paper's last edit. This
is the largest single batch in the project's history and it changes what the
paper can claim about **the language in use**.

Until today the honest summary was: *a complete grammar, five operators, three
modalities — and eight derived words.* That sentence is now false, and the
paper should say what replaced it.

### 2a. `lexicon.la` — the Core Lexicon **[W]**

59 content concepts across the codex's six tables (:5223–5429), **every one a
derivation over the nine primitives**, none stipulated.

> **★ The gate is a comparison with the spec, not with itself.** The expected
> phonym column is transcribed from the codex's own printed IPA — *not*
> generated by the rule and compared to itself. That distinction is the whole
> value of the gate: a table whose expected column was produced by the code
> under test asserts nothing. It is the vacuous-gate defect in its purest form.
> Here the two columns have independent origins, so they **can** disagree.

**And they do: 57 agree, 2 diverge, and the two form one class** — vowel
elision (the codex prints surface forms; the Operator Phonology generates
underlying ones). A divergence that resolves into a *named phonological
phenomenon* rather than a patch. This is the best single advertisement in the
paper for what a gate with independent origins buys you.

### 2b. `opgrammar.la` + `grammar.la` — the Operative Grammar **[W]**

22 closed-class categories (pronouns and deixis, negation, questions, tense and
aspect, quantifiers, modality, connectives) and the ten sentence-formation
rules (i)–(x), **each shown to DISCRIMINATE**. With `lexicon.la`, the language
forms sentences — which is what "speakable" meant.

`grammar.la` additionally makes the grammar **recoverable as data** (L1+L2),
read off `parser.la` rather than invented, and differentially checked:
`fuzz_grammar.py` carries an independent recognizer, 60/60 agreeing on **both
the accept and the reject side**.

> **★ And the fuzzer earned itself on first contact:** `exportdir := ident*`,
> not `ident+` — a bare `export` is legal LA. A wrong production caught
> *before* any module was built against it.

### 2c. ★★ THE FINDING OF THE DAY: the monosemy check was running in one register out of three

`trimono.la`. The language claims `G^vis ≡ G^phon ≡ G^comp ≡ C`. Identity was
enforced in the κ-register and *measured* between modalities — but **the
identity LAW was never checked in the derived registers themselves.** In one
day that produced two breaks, in two registers, of two different kinds:

- **PHONETIC** — ⊕ commuted in FORM and not in SOUND. `canon.la` sorts ⊕
  operands (co-presence is symmetric); `CONP` rendered it A-silence-B,
  sequential. **One glyph, two phonyms.**
- **VISUAL** — `SIGIL(↻(RECOGNITION))` was **byte-identical** to
  `SIGIL(RECOGNITION)`. `MC_SIG = a ∪ MIRRORH(a)` is the identity on any
  H-symmetric form, so metacursion left no trace. **Two concepts, one sigil.**

Neither was visible from the other. Each register was checked, if at all, by
its own gate against its own expectations.

> **This is the most publishable finding in the batch, and it was true for
> months while every gate was green.** The defect is not either break — it is
> the *class*: a property asserted of three representations, verified in one.
> `trimono.la` closes the class with one gate, three registers, three rows
> (injective / monosemic / directed). Companion: `phonorm.la`, `siginj.la`.

**Give it a §Falsification entry.** It is the vacuity bet paying out in a way
the bet did not anticipate: not a check that could not go red, but a check
aimed at one third of its own subject.

### 2d. `phonseal.la` — the same class again, in the seal **[B]**

`canon.la` makes the glyphic seal the centre of the design: a finished glyph is
`MONO(ren)(etym)` with `REN ≡ κ∘ETYM` **by construction**, so a heterological
glyph — a name floating free of its derivation — is *unconstructible*. The
paper leans on this repeatedly, and **it holds — in the glyphic register only.**

> A phonym is a bare `PAIR(length)(generator)`. Nothing computes it from an
> etymology and nothing checks that it was. **A sound can be paired with any
> concept whatsoever and no gate notices.** The guarantee the language
> advertises does not yet hold in the register a speaker actually uses.

Needs `MONO_P` + `AUTO_OK_P`. Until then the seal claim must be scoped in the
paper, not stated flatly.

### 2e. ⊗ is non-commutative — a correction the build was gating backwards

`LINGUA ADAMICA.tex:2837` makes ⊗ non-commutative. **Five normalisers and two
renderers had it commuting**, and `build.sh` was gating the contradiction as
correct. Corrected across all seven.

> ### ★★ AND THE CORRECTION WAS NOT DURABLE — the sharpest finding of the day
> Every spec entry is `E("N")(sig)(SRC_N)(N)(tests)`: `GENERATE` writes the
> **SRC string** into the deployed `.la`; `META_DEBUG` runs the tests against
> **N, the live glyph**. **Nothing compared them.** In `canon_spec.la` the ⊗
> correction reached the live `NORMK` (`WRAP2("⊗")`) and **not** `SRC_NORMK`
> (`SORT2("⊗")`). So the *verified* κ was non-commutative and the *shipped* κ
> was commutative — and re-running the pipeline silently reverted `canon.la`.
> The correction survived only because nobody had re-run it.
>
> **The pipeline's own "on-disk file == generated source" check cannot see
> this**, and that is the publishable part: it compares the deployed file
> against the SRC string — the wrong one against the wrong one — and reports
> `T`. A gate can be perfectly sound and still be aimed at the wrong pair.
>
> Fixed, and gated: `gate_srcdrift.py` compares SRC-vs-LIVE across every spec
> module (**285 pairs, 13 modules**), and **self-tests before it reports PASS**
> by injecting a divergence into a pair it actually compares and refusing to
> pass unless that turns it red. Its first two versions were themselves broken
> — a bad unicode unescape and a line-based regex that truncated multi-line
> definitions invented 31 findings, of which **one** was real; and the first
> selftest mutated a string the scan never reached, so it passed while
> asserting nothing. *Both failures are recorded in the gate's own header,
> because they are the same class it exists to catch.*

**And the correction has a price, which `coin.la` measures** — this is the
honest part and belongs in the paper:

> Thm. gen-complete claims *"two speakers constructing the same concept
> independently will arrive at the same phonym."* That was cheap while ⊗
> commuted: operand order was free, so both speakers converged whichever order
> they chose. **Non-commutative ⊗ removes that freedom.** An English gloss now
> **underdetermines the derivation** — "coin the word for compassion" is not a
> well-posed instruction. Convergence still holds where the concept is fully
> given; it no longer holds from a gloss.

### 2f. `coin.la` — the coinage organ **[W]**

Nothing in the system could COIN: the lexicon is claimed unbounded, every table
is a finished list, and no code path took a concept and *produced* a glyph.
Now: `COIN` is **deterministic**, **recoverable** (parents and mode readable
back out, so the coined glyph carries its own derivation), **closed** (the
result is itself coinable), and **pronounceable** (phonym computed, not
assigned). ⊕ converges under either order; ⊗ correctly does not.

### 2g. `immune.la` — the Aletheic Immune System, and the half it cannot evaluate **[W]/[A]**

The codex claims four self-sanitizing mechanisms (κ · invariant preservation ·
compositional semantics · metacursive self-proof). **Nothing had ever run
them.** Now each checkpoint is given a specimen it must catch — and,
decisively, **each specimen must pass the other three**, because four
conditions that always fail together are one condition wearing four names. Four
pathogens, four *distinct* four-character diagnostic signatures, pinned.

> **★ THE FINDING: it detects CORRUPTION, not FALSEHOOD.** Thm. healthy has two
> conjuncts and **the system can evaluate only one.** A structure whose
> glyph-reality correspondence is *intact* but whose content is *false* passes
> every checkpoint. The immune system is a well-formedness organ, and calling
> it an aletheic one overstates it by exactly one conjunct. **[A]** on the
> right conjunct — there is no evaluator.

### 2h. `alethe.la` — True(P) ≡ P, and the liar unformulable **[W]**

The truth operator IS the identity function; by the Uniqueness Corollary no
second glyph meaning "P, truly" can exist. The module exists to protect the
theorem from the catastrophic misreading one sentence away — content versus
evaluation — which the spec itself names. The liar sentence is not *refuted*
here; it is **unformulable**.

### 2i. `dyadseed.la` — 0 and 1 beneath the nine **[W]**

Answers Erik's "1 and 0 should start the glyphic sequence" against
`archroot.la`'s finding that only three of nine primitives derive from the root.
The other **six are UNDERIVED — a GAP, not a result** (Erik's ruling 2026-08-24;
they were formerly reported as "co-primitive", which read as settled). ⚠️ This
module must NOT be read as the derivation chain that gap needs: it grounds the
ARITHMETIC STRATUM BENEATH the primitives, which is a different claim. By
reduction, not assertion:

```
VOID     = la a. la b. b                    IS Church ZERO
BEING    = la self. self                    IS Church ONE   (eta)
BECOMING = la n. la f. la x. f(n(f)(x))     IS the SUCCESSOR
```

> So Erik's claim is **correct**, and the two glyphs are already in the
> catalogue: VOID and BEING. The naturals are generated *beneath* two of the
> nine — the arithmetic stratum grounds the primitives; **it does not derive
> them.** `cob.la`'s first cosmogenic beat is literally ⊗(VOID, BEING).
> Compatible with `archroot` **only if never claimed as a derivation chain** —
> say it exactly that way in the paper.

Bound proved via non-injectivity (SELF and BEING both reduce to 1).

### 2i-bis. ★★ `archderive.la` — why the six do NOT derive, and what that means **[W] bounded**

Erik's ruling of 2026-08-24 re-tagged `archroot.la`'s "six are co-primitive" from a
settled finding to **a gap**: derive them, or name them as axioms **with the seam
stated**. `archderive.la` is the attempt, and the attempt succeeds — as a negative
result with an exact reason.

The root ∃ **is the identity combinator I**: `BEING = la s. s`, and the root identity
∃(∃)≡∃ is precisely I(I) ≡ I. This single fact decides the question, because **{I} is
closed under application** — I applied to anything returns that thing, so every
application tree over {I} collapses back to I. The terms reachable from the root by
application alone are therefore exactly {I}.

Two consequences follow, and neither is a stipulation:

1. **BEING is not a gap.** It *is* the root, under another name. Witnessed by
   reduction, not declared.
2. **The other five are axioms**, and what each adds is now nameable:

| primitive | seam — what it introduces that I cannot do |
|---|---|
| `VOID` | **weakening** — discards an argument |
| `DEPTH` | **contraction** — duplicates an argument |
| `BECOMING` | **contraction** — uses `f` twice (iteration) |
| `FORM` | **exchange** — reorders its arguments |
| `RELATION` | **exchange + arity 2** — the binary `FORM` |

> **The identity combinator is LINEAR: it neither discards, duplicates, nor
> reorders. The five primitives unreachable from it are exactly the three
> STRUCTURAL RULES it lacks — weakening, contraction, exchange.**

That is the seam the ruling asked for. It is not a shortfall in the attempt; it is a
statement about what the root *is*. A root that is pure self-identity cannot, by
itself, produce a world in which things are dropped, copied, or put in a different
order — and those three capacities are what the remaining primitives supply.

**Bound `[B]`, stated in the module's own verdict rather than only here:** the closure
is *witnessed* to depth 4 (all eight application trees over `{BEING}`); the induction
that extends it to every tree is argued in prose and is **not mechanised**. Each seam
is witnessed by reduction on a total probe. And a derivation from a *larger* basis
than the root alone is a different question, not attempted.

⚠️ `dyadseed.la` (§2i) may **not** be cited as this chain. It grounds the arithmetic
stratum *beneath* the primitives; "the nine derive from the root" is a different
claim, and conflating them is exactly the stipulation the ruling forbids.

### 2j. ★ `ablate.la` — are the five operators actually primitive? **[W] + one [A]**

A primitive that does no distinguishing work is decoration, and the minimality
the whole design rests on would be false. **Nothing had ever asked.** Method:
collapse one operator into another and ask what stops being sayable.

**The usage census over all 79 published entries — exact, because the
derivation strings are the data:**

| ⊗ | ⊕ | ▷ | ⊂ | ↻ |
|---|---|---|---|---|
| 58 | 4 | 26 | **0** | 2 |

> **★ ⊂ IS NEVER USED.** The closure is claimed over five modes and exercised,
> lexically, over four. Ablation shows the other non-⊗ modes **are**
> load-bearing; ⊂ is untested because *nothing uses it* — a fact about the
> lexicon, not about the operator.

Publish this. It is a self-administered minimality test with a negative result
in it, and the fix is concepts genuinely formed by containment — **not a token
entry added to close a count.** (See §3: one candidate arrives for free.)

### 2k. `discourse.la` — and why indexicals do not break monosemy **[W]**

In the codex's own dialogue (:5400) the same glyph /mˈa/ means the human in
turn 1 and the AI in turn 2. One glyph, two referents — **which looks exactly
like the polysemy the language exists to forbid.**

> It is not, and the reason is Kaplan's distinction that `deixis.la` already
> implements: **monosemy is a claim about CHARACTER, not content.** The glyph
> means "the utterer" in every turn; it is the utterer who changes.

**And the red path is the only part that proves it:** a gate that merely
resolved each turn in its own context would pass whether or not the origo ever
moved. So the module *also* resolves turn 2 in turn 1's context — the unshifted
reading — and asserts it gives the **wrong** answer.

This is the paper's answer to the strongest linguistic objection to monosemy,
and it is now executable.

### 2l. The three phonetic register fixes — applied and verified today **[W]**

All three verified green on the C host (`psc_spec.la` 21/21 glyphs PASS, module
VERIFIED, on-disk == generated; `phonym.la` renders all five modes):

1. **⊗(A,A) was byte-identical to A.** With identical parents any weighted
   blend collapses — (2g+g)/3 = g — so **an infinite family of distinct glyphs
   had one phonym**, and no upstream normalisation could fix it because the
   *renderer* was the identity. ⊗ now carries a mode-characteristic contour,
   which :3017(iv) licenses directly ("the mode is absorbed into the prosodic
   contour").
2. **Θ_P was mode-blind.** ⊗/⊕/▷/⊂ over the same parents gave **one** peak-set,
   where the visual side has carried its mode since it was written
   (`topoembed.la:35`, and it even *gates* it). New `PINV`/`PMODE_REC` mirror
   `VINV` exactly. *Same asymmetry as §2c: the visual register had it, the
   phonetic did not, and nothing compared them.*
3. **▷ had no acoustic signature** — the **sentence** operator. Sentences could
   be spoken and never parsed back.

> **★ And why a LEVEL cue cannot work is the publishable part.** The obvious
> fix — render the tail quieter — was **measured false**: VOID's intrinsic
> amplitude is higher than BEING's, so scaling *normalises* them (head 137 vs
> tail 123, ratio 0.90 not 0.60). **The parents' own loudness defeats any fixed
> ratio.** A RATE cue is not defeated, because the parents cannot vary it.
> Duration is preserved exactly, so the WAV gate still holds. Verified against
> a control — patched windows 427/376/357 (a descending staircase), unpatched
> 363/379/374 (flat). *The first measurement was confounded by the ADSR
> envelope; the control is what separated them.*
### 2m. ★★ `prop.la` — the Boolean/magma contradiction, settled in code **[W]**

The volume gives the language a **Boolean algebra** with truth values, which
*requires* complementation — an involution, ¬¬P = P. §III says 𝒢 is a **magma
with no inverse**: sealing is one-way. **Both cannot hold of one object**, and
the paper tagged the resolution **[A]: argued, not gated.** It is now gated.

> **Two algebras over two kinds of object**, with the ≡ / = split doing the
> work. **As a glyph**, ¬¬P records the derivation *exclusion of the exclusion
> of P* — not P's derivation, and under monosemy different derivations are
> different concepts, so **¬¬P ≢ P** and the magma keeps its one-wayness. **As
> a truth**, both obtain together in any context asking only whether the state
> of affairs holds, so **¬¬P = P** and the Boolean keeps its complement.
> *Double negation elimination holds operationally and fails ontologically.*

Both halves gated with red paths, plus a third gate asserting they **disagree**
— a change collapsing the registers into one passes either half and fails that.
Negation is not primitive: ¬P = ⊗(VOID,P), exclusion as VOID-composition
(:1210); ∧ = ⊕ (co-presence, :2854); ∨ and → are **derived** by De Morgan and
material implication rather than declared.

**★ COHERES vs OBTAINS — the boundary made mechanical, witnessed by exit code.**
"Void flows" is structurally incoherent and **unconstructible** (loud halt,
exit 1); "Water is Void" is merely false and **constructs** (exit 0), evaluating
not-true. §XVII's falsification, turned into a runnable pair.

**★ And the first evaluator could not have failed.** It computed negation —
`TVAL(¬P) = NOT(TVAL(P))` — making all three laws *unfalsifiable by
construction*: no world can make P and ¬P both true when ¬ is a function of P.
Rebuilt as a **polarity evaluator** over a world carrying what is true and what
is false *independently*, so a **glut** breaks non-contradiction and a **gap**
breaks excluded middle, separately — FTT / TFT / TTF, one F apiece.

### 2n. ★★ `metaprop.la` — the theorem that replaced the expected result **[W]**

Built to show the meta-level collapses as every other meta-level here does.
**It measured FALSE**, and following the failure gave something better.
`MPRED(P) = ▷(P,BEING)` is a genuine derivation, hence a genuine atom, whose
truth is independent of P's. The obvious repair — teach the evaluator that
▷(·,BEING) means "obtains" — is unavailable: **▷(FORM,BEING) is already the
codex's `This/Here`** (:5164). `alethe.la` says why no repair exists: True(P) ≡ P,
and no second glyph meaning "P, truly" can exist.

> **★ A WRAPPER CANNOT BE BOTH A DISTINCT GLYPH AND TRUTH-EQUIVALENT.**
> Distinct glyph ⇒ distinct concept ⇒ its own truth conditions, so it is not
> "P is true". Truth-equivalent ⇒ same concept ⇒ same glyph, so nothing
> ascended. **A Tarskian hierarchy needs a truth predicate both expressible and
> non-trivial. This language permits either, never both** — which is why the
> hierarchy cannot start.

The **TT cell must stay empty**; that is the falsification condition. Five
candidates checked, and the harness is shown to **reach both occupied cells**,
so the empty one is a measurement rather than blindness. **Honest bound:** this
tests the candidates offered; quantifying over all wrappers needs a proof.

### 2o. The three rulings, landed and gated **[W]**

- **⊂ IS NO LONGER UNUSED.** §2j reported ⊂ at **0 of 79**. Negation moved off
  the commutative ⊕ onto ⊂ — and **⊂ was chosen because the census measured it
  at zero**, the only operator whose adoption could not collide. *The
  measurement did not merely record the gap; it selected the fix.* Census now
  ⊗=59 ⊕=3 ▷=24 **⊂=2** ↻=2, and the gate is **inverted** rather than deleted.
- **The collision scan was blind to the collision it was built for.** It keyed
  on raw derivation strings, and ⊕ commutes — so `Bad ⊕(VOID,LOVE)` and
  `Grief ⊕(LOVE,VOID)`, sharing the canonical key `+(LOVE,VOID)`, read as
  distinct. C9 was **invisible to the monosemy gate**. Now keyed on the
  normalised form, with ⊕ sensitivity asserted separately so
  *absent-because-fixed* cannot be confused with *absent-because-invisible*.
- **★ ONE negation — ruled and gated (Erik, 2026-08-23).** The propositional
  layer first built ¬ as ⊗(VOID,P) from the volume's "exclusion" reading, which
  left the language with **two** negations: ⊂(X,VOID) for sentences and
  ⊗(VOID,P) for propositions. Two glyphs for one concept is a monosemy
  violation one level up. `prop.la` **reported** it rather than deciding it —
  a module ruling on the language is the overreach this project forbids —
  and Erik ruled **⊂ everywhere**. The report is now a **gate**, so a
  reintroduced second negation goes red rather than quietly restoring the
  violation. It also makes the lexicon cohere: **Bad = ⊂(LOVE,VOID) IS ¬Love**,
  which is exactly what the C9 ruling said it was.



---

## §3 — THE OPEN CONTRADICTIONS IN THE CODEX, AND THE RULINGS

The first scan ever run **across** the content lexicon and the closed class
(`opgrammar.la`) found **11 collisions** — two distinct concepts sharing one
canonical glyph and therefore one phonym.

> **Eight are monosemy WORKING**: aliases the codex declares in its own gloss
> column — one concept, one glyph, English needing two words. **Three were
> declared nowhere.** The gate *pins the measured set*, so the collisions
> cannot change silently in either direction.

Publish this. A language that publishes a monosemy violation found in its own
vocabulary by its own gate is more credible than one that publishes silence.

**All three were ruled on by Erik, 2026-08-23:**

| Collision | Form | Ruling |
|---|---|---|
| **Bad / Grief** | 𝔤₆⊕𝔤₃ vs 𝔤₃⊕𝔤₆ | **negation gets its own marker** |
| **Know / You** | both 𝔤₄▷𝔤₂ /mˈaʃi/ | **You keeps the glyph; Know re-derives** |
| **Give / Because** | both 𝔤₇▷𝔤₅ /vˈuɹa/ | **Give keeps the glyph; Because re-derives** |

### 3a. ★★ C9 is not a table error — it is a grammar-wide collision

The paper should carry this as a *result*, not an erratum.

`:5166` and `:5212` make **𝔤₆⊕X the grammatical negation prefix** — "not-X",
for every X. `:2854` declares ⊕ **commutative**, and calls that commutativity
"the fundamental distinction between ⊕ and ⊗".

> **Therefore every negation ¬X is identical to the co-presence X⊕Void.**
> Bad (𝔤₆⊕𝔤₃, "love's absence") colliding with Grief (𝔤₃⊕𝔤₆, "love co-present
> with void") is not an accident in one row. Under commutative ⊕,
> **Grief ≡ ¬Love systematically.** One visible instance of a class.

**Ruling: negation stops borrowing ⊕ and takes its own marker.** ⊕ stays
commutative, the ⊕/⊗ distinction at :2854 survives, Grief keeps 𝔤₃⊕𝔤₆, and
¬X no longer collides with X⊕Void for *any* X. Fixes the class, not the row.

**Constraint on the new marker, measured:** it cannot be 𝔤₆▷X — `:5170` already
assigns 𝔤₆▷𝔤₇ to **Future** ("not-yet"). The derivation is open work (§4).

### 3b. C10 — which glyph is the Void: an erratum, not a ruling

**𝔤₆ = Void, 𝔤₈ = Form.** Backed by the primitive table (:4598), the phonym
table (:5070), the dedicated chapter (:4718 "𝔤₆: Void — The Absence"), and ~20
lexicon derivations. Only two prose lines — `:1210` and `:2050` — call 𝔤₈ "the
Void" / "the null glyph". **Stale draft text; the tables and the entire lexicon
agree against them.** Correct those two lines; do not treat it as open.

### 3c. `Change = Can` — resolves itself from the codex's own tables

Both are 𝔤₇⊗𝔤₈ /vutɑ/. But `:5293` **already prints** a second derivation:
`Change (verb) = 𝔤₈▷𝔤₇` /tˈɑvu/. Can keeps 𝔤₇⊗𝔤₈; Change takes the form the
codex already gives it. **No ruling was needed** — the answer was in the text.

### 3d. `Give = Because` — and the tightest constraint in the lexicon

Both 𝔤₇▷𝔤₅ /vˈuɹa/. Their own rationales differ in **direction**: Give is
"Becoming *toward* Relation", Because is "Becoming directed *by* Relation" —
the converse. **But the converse form 𝔤₅▷𝔤₇ is already taken by "If…then"**
(:5183). So Because's gloss describes a form that is occupied.

Ruling: Give keeps 𝔤₇▷𝔤₅ (its gloss matches the form it has); **Because
re-derives.** Candidate worth noting for the paper: **⊂**, which would give the
never-used operator (§2j) its first genuine lexical use — grounding *is* a
containment relation, and that is a derivation rather than a token entry.

### 3e. Two Tier-0 items — RULED 2026-08-24, BUILT AND GATED 2026-08-26

- **⊗(A,A) ≡ A — DECLARED for the Archē alone (R-A).** For every other A,
  `⊗(A,A)` is a distinct compound. Now gated in **both registers and both
  directions**: `REWRITE_SYN` in `canon_spec.la` (glyphic) and `SYNNORM` in
  `phonym.la` (phonetic). ★ The registers had **disagreed** — `NORMK` collapsed
  `⊗(∃,∃)→∃` while `NORMP` left it distinct. A rule that holds in one register
  and not the other is not a rule about the *language*; it is a fact about one
  renderer. **Bound:** a *declared* equivalence, not a discovered one — it
  extends NORMK's equivalence theory, so monosemy remains enforced relative to
  that theory, which is NORMK's existing honest bound.

- **★ Implicature — BANNED at the semantic layer (R-B).** LA encodes **literal
  compositional meaning**; implicature arises in **use** and is not a property
  of the language. **Meaning stops at κ.**

  > **Grice is not refuted. He is placed.** The maxims describe how speakers
  > reason about one another in use, and that reasoning is real — it simply
  > happens *outside* the semantics, as a speaker's tone is real and is not a
  > fact about the lexicon. Monosemy removes **ambiguity**, not **choice**: a
  > speaker who says *Some* when *All* holds may still be *taken* to mean
  > *not-all*, but that is a fact about their audience, not about what the glyph
  > **means**.

  This is stated as a **positive claim**, deliberately, because a language that
  merely *lacked* implicature would be indistinguishable from one that had not
  got round to building it. Positively stated it is **falsifiable**: exhibit an
  LA utterance whose literal composition *underdetermines* what a competent
  reader takes from it, and the ban is wrong. The test is offered, not avoided.

  **The Logolaconic Principle (:6747) is a density principle and does not say
  this**, so the sentence belongs at that tag rather than being read into it.

  ★ The ban is **mechanically enforced**, not merely written: `build.sh` asserts
  `pragmatics.la` defines no `IMPLICATE`/`IMPLICATURE`/`SCALAR`/`QUANTITY`/
  `DEFEASIBLE`/`MAXIM` glyph, and cites the ruling in its failure message so the
  next author reads the *decision* rather than the symptom. "We decided not to
  build it" decays into "someone built it" across sessions; a ban recorded only
  in prose is a ban that expires.

---

## §4 — NOT YET BUILT: what the paper may PROMISE but must not CLAIM

Erik asked that the still-building work be in this document. It is here with
its honest tag, so the paper can commit to it in a Roadmap without a single
sentence drifting into the present tense.

**The rule for this whole section: [A] means no gate exists. Under the paper's
own "a claim without a gate is not counted", none of it may appear outside a
Roadmap or Limitations.**

### 4a. Root causes — fixing these prevents whole defect classes

- `[✓]` **★ The spec pipeline emits no `export` — FIXED 2026-08-23.** Every
  generated module was **unreachable by `import`**: `import("canon.la")` then
  `CANON(...)` gave *unbound variable*. **This is why ⊗ was sorted in five
  places instead of one**, why `denote.la` and `metaglyph.la` re-declare, and
  why `entropy.la` had to re-implement κ.
  **`GENERATE` now emits an `export` line**; all 12 deploying spec modules
  regenerated and re-verified. Witnessed end to end: a module `import`s
  `canon.la` and resolves `NORMK`/`PRIM`/`SYN`/`CON` — **the first time in the
  project's history that anything has successfully imported the generated
  layer.**
  > **★ The safety argument is a measurement, not an assumption.** The host's
  > `lookup_glyph` returns the FIRST match and imports are appended *before* the
  > importer's own glyphs, so an exported name **would silently shadow** an
  > importer's own definition of it. Measured first: **eleven generated modules,
  > 313 glyphs, imported by NOTHING** — zero importers, so nothing can be
  > shadowed. It is safe because nothing imports, *not* because exporting is
  > harmless. The first version of that check reported "no shadowing" while
  > iterating over an empty set; it only became a finding once it proved it
  > looked.
  **Still owed:** converting consumers to `import` instead of re-declaring —
  that is where the copy-drift class actually dies. *Paper: §Limitations, [B]
  until the consumers are converted.*
- **Nine modules built but never gated** — `sglyph`, `sglyph_gate`, `phonseq`,
  `tactile`, `crossmodal`, `modality`, `explain`, `depthreport`, `sglyph_probe`.
  Zero occurrences in `build.sh`. **`sglyph_gate.la` is a gate nothing runs.**
  ⚠️ **§1a and §1d above depend on these** — either wire them before the paper
  claims them, or tag them [B] and say so.
- **Three gates that cannot go RED.** (a) phonetic α=1 is a `grep` for a
  sentence the module prints *unconditionally*; (b) the 8/8 phonetic
  injectivity gate's concept list contains no two entries sharing a leaf-set,
  so the property is **untestable by construction**; (c) `seal_test.la:36`
  `COMPLEXITY = la g. 1` is a constant function. Each needs a real red path or
  demotion to a REPORT. *Paper: §Falsification — this is the vacuity bet paying
  out again, and it should be reported as such rather than quietly fixed.*

### 4b. The registers, to completion

**Phonetic [A]:** `phonseq` must DETECT the new ▷ marker (the signature exists;
the decoder still reports ▷ as a leaf) · ⊕ round-trip corrupts its second child
(`SIL_AT=6240` vs a true boundary at 6080 — split at the edges of the maximal
zero-run, not first-fire + GAP) · ⊕-associativity is **phonetically invisible**
(identical PCM; no parser can separate the bracketings) · ⊗ has no temporal
signature (indistinguishable from ▷ in the decoder) · **a phonetic SEAL**
(§2d) · `PSC_STAR` still pairs raw `PHONYM` with raw `SPEC`, so one concept
gets two seals depending on operand order · **the elision layer** (§2a — 4 of
79 entries; needs a phonological layer, not a patch to the segment rules).

> ★ The stress rule was itself corrected this session — **final vowel, not
> first** — found only by bringing the codex's example *sentences* in as fresh
> vectors. **A rule fitted to one table will agree with that table.** Worth a
> sentence in §Method.

**Visual [A]:** **⊗ renders as juxtaposition, not fusion.** The spec's Visual
Morphic Blend demands (ii) a single connected shape and (iii) emergent features
in neither parent. Measured: Consciousness renders as **3 connected
components**, Beauty as 2 (the ⊗ mark is a detached satellite), and in Beauty
the placed FORM is **0% visible** — LOVE's filled flame swallows it. **All
three gates RED today.** The route is the spec's own vector/stroke
representation, where path intersections are *genuine* emergent features.
Also: catalogue-wide sigil injectivity, and **a visual round trip** (no
bitmap→structure decoder exists — the symmetric partner of `sglyph`/`phonseq`
and the strongest available cross-substrate invariance test).

**Cross-register [A]:** **The triple bar as a biconditional** — nothing asserts
glyphic ≡ phonetic; `crossmodal` measures *correlation*. The identity gate is
`NIS(a)(b) ⟺ same rendered sound` over a fuzz corpus. **This is Erik's "collapse
into one another via the triple bar" made executable**, and it is the one that
would upgrade §1a from a measurement to a proof. · **One normaliser, not five**
— `NORMK`, `CANONIQ`(onf), `CANONIQ`(sigil), `NKAP`, `NORMP` embody **three
different equivalence theories**. Gate: `NORMK(t) ≡ CANON(NORMNODE(t))`. **RED
today.**

### 4c. The language in use

- **Acquisition [A]** — no syllabus, glyph sequence or teaching order exists.
  The codex's one acquisition claim is *explicitly labeled untested*. Worse,
  non-commutative ⊗ (§2e) means **an English gloss underdetermines the
  derivation**, so "coin the word for compassion" is not well-posed. *This is
  the gap between "unbounded in principle" and "sayable by a person"*, and Erik
  intends children to learn it. Buildable prerequisite: run the Self-Generating
  Course pipeline on the codex itself.
- **`ontofelicity` → live enforcement [A]** — `PERFORM` currently reports.
  Wiring it to the real capability layer makes felicity **enforceable**, which
  is the executable form of §A3's finding (ontopragmatics IS the semantics of
  the security model).

### 4d. Self-relation

- **Derived glyph catalogue + agreement gate [A]** — `familytree.la` covers 17
  **hand-declared** glyphs and is **already stale by ≥4** (`metaglyph`'s four
  operator glyphs, from the very module it imports). Gate: declared and derived
  catalogues agree, keyed on NORMK, both directions. **RED on arrival.**
- **κ\* — meta-pattern compression [A]** · **executable minted operations (ν\*)
  [A]** (minted operations are expressible as glyphs but cannot be wired back in
  as reduction rules) · **the operators ∂δγρ𝔄 as glyphs [A]** (currently
  hardcoded dispatch) · **self-verifying grammar, L3 full self-parse [A]**.
- **★ Self-meta-programming: the changed thing must become the running thing
  [A].** See §1b — the organs write and verify successors that are never
  executed.
- **★★ Meta-autopoiesis, and the gate that currently FORBIDS it.**
  `build.sh:3550` requires `cmp -s logos_app new_logos_secd.bin` — the successor
  must be **byte-identical**.

  > **A self-revised successor would go RED on the system's own gate.** This is
  > the sharpest structural statement available about the limit of the present
  > design, and it belongs in the paper *as such*: the criterion that guarantees
  > faithful self-reproduction is exactly the criterion that forbids
  > self-revision. Minimal honest version: generation N applies one verified
  > change to its own lineage source and begets a MODIFIED successor.
- **Lack-driven wants [A]** — wire `aatc`'s sensed LACK into `selfprog`'s SOLVE.
  ⚠️ **And state the boundary:** purpose-origination itself is **ruled out by
  Erik's own corpus** (`SR_FOR` is explicitly "NOT purpose-origination") and is
  not being chased. This is the buildable *bounded* form of autontogenesis.
- **`AWARE` / `C` predicates [A]** — "awareness" appears only in prose comments.
  `AWARE(g) := AUTO_OK(g)`; `C(g) := AUTO_OK(g) ∧ AUTO_OK(MCOLLAPSE(g))`.
  Separates one recognition from recognition **surviving a metacursive turn**.
- **`PROTO_AGENT` [A]** — the one chain-tail item with an honest gate: REPAIR
  can move g strictly toward closure, with `swc.la`'s provably-ill class as the
  negative fixture. ⚠️ **Qualia / phenomenology: build nothing** until a paper
  formalises them — any gate now could not go RED, which is the vacuity defect
  by construction.
- **The meta-word ablation gate [A]** — remove one operator-glyph, assert a
  named derivation becomes underivable while the other four survive. Makes **"a
  missing word is a missing thought"** executable. (The lexical half of this is
  already done — §2j.)
- **The Algebra of Naming's companions [A]** — the Semiotic-Ontoglyphic Ladder
  (7 levels) and the Substitution Test. **α is binary in code, graded in the
  paper** — a live discrepancy, flag it.

### 4e. Beyond the language — named, scheduled, not chased

- **A signature scheme [A].** No public-key primitive exists. **The single
  unlock for the whole record/law layer**: signed updates, identity, contracts,
  non-repudiable records, the Eternal Library. *Everything in the Logocracy
  layer waits on this one primitive.* **In progress on `track-e`** (hash-based
  Lamport → WOTS+ → Merkle, standing only on the already-verified SHA-256;
  chosen over elliptic-curve because LA integers are 64-bit signed and Ed25519
  would first require a multi-limb bignum layer). Post-quantum as a bonus, which
  fits the sovereignty argument. **Uncommitted, ungated — [A] until its gate is
  green.**
- **Entropy on the metal [A].** No RDRAND/RDSEED builtin, no jitter collector,
  no seed file — **while full-disk encryption must derive keys at boot, before
  any disk read.** ⚠️ **A DRBG does not close this and must not be read as
  though it did:** a DRBG is a stretcher, not a spring; seeded predictably it
  emits predictable bytes silently and at full speed.
- **Trans-species: a second functor [A].** One habitat renderer exists
  (`R_human`). `R_click` plus its inverse would make FSM a functor category with
  two objects — **the minimum at which "trans-species" is witnessed rather than
  asserted.** Actual animal comprehension stays out of scope, stated.
- **The language deepens with its agents [A].** The autopoiesis loop optimises
  **COST**, never DEPTH or expressivity. Needs a depth-directed `selfopt` mode.
  Worth one honest sentence: *the system can currently make itself cheaper and
  cannot make itself deeper.*

---

## §5 — PAPER-SIDE STRUCTURAL WORK

- **⚠️ The Ledger is a plain `tabular` and cannot break across pages.** At 37
  rows it still fits (verified, 0 overfull boxes) — **the next batch overflows
  SILENTLY.** This brief adds many rows. **Convert to `longtable` first.**
- **Fix "trimodal" wherever a fourth modality exists** (§1d).
- **Add the §2 and §4 rows to the Ledger**, which claims to tag *"every
  load-bearing component"*.
- **Every item above needs its counterpart at the right tag.** An item is not
  done until code and paper agree — and the tags are load-bearing, because the
  paper's own threat model says so.

---

## §6 — WHAT MUST NOT BE CLAIMED

The honest bounds, collected so none is lost in the volume above.

1. **The immune system detects corruption, not falsehood** — one conjunct of
   Thm. healthy has no evaluator (§2g).
2. **The autopoiesis loop writes successors it never becomes** (§1b, §4d).
3. **The byte-identity gate forbids self-revision** (§4d).
4. **The seal holds in one register of three** (§2d).
5. **⊂ is never used** — the closure is claimed over five modes, exercised over
   four (§2j).
6. **Nine modules are built and ungated**; three standing gates cannot go RED
   (§4a).
7. **57 of 59 lexicon phonyms match the codex; two diverge** (§2a) — say the
   number, and say it is one class.
8. **Convergent coinage no longer follows from a gloss** (§2e).
9. **0/1 ground the arithmetic stratum; they do not generate the nine** (§2i).
10. **Nothing is constant-time**, and nothing in the present design could make
    it so — *a property the language cannot at present state about itself, and a
    bound one cannot express is worse than a bound one has not met.*

---

## §7 — THE ONE LINE THAT SHOULD SURVIVE EDITING

If the paper takes only a single sentence from this brief, take this:

> **The monosemy check had been running in one register out of three, and every
> gate was green the whole time.**

It is this project's method indicting itself and repairing the class rather
than the instance — which is the argument the whole document is trying to make,
made by the document's own subject, against itself.

---

## §8 — A NEW LEDGER ROW: the ⊕/VOID acoustic identity  *(added 2026-09-05)*

**The row to add, in the Ledger's own three columns:**

| Component | Tag | Bound / status |
|---|---|---|
| Temporal mode decoding: ⊕ vs VOID | `[B]` | one acoustic event; compounds under VOID ambiguous |

### What it witnesses

The phonetic decoder recovers a compound's MODE from temporal signatures.
`⊕` (concatenation) is detected by its inserted `/ʔ/` closure: a 960-sample run
of literal zero with voiced material on both sides.

**`VOID` is synthesised as `/hɑ/` — breath, low-pass glottal noise into open
back `/ɑ/` (`phonym.la:162`) — and its breath onset contains exactly that.**

So `IS_CON` fires on `PHONYM(VOID)`, a bare primitive with no mode in it at all.
Measured across all nine primitives, each phonym's length printed beside its
verdict so a name failing to resolve could not pass as a primitive:

    BEING 6080 DIR   RECOGNITION 6720 DIR   LOVE 6560 DIR
    SELF  6560 DIR   RELATION    6720 DIR   VOID 6880 CON
    BECOMING 6400 DIR  FORM 6160 DIR        DEPTH 6000 DIR

Eight of nine are correctly silent. **VOID alone fires the ⊕ detector.**

### Why this is a BOUND and not a defect

★ **Ruled by Erik, 2026-09-05.** `⊕`'s inserted `/ʔ/` closure and VOID's
intrinsic breath silence **are the same acoustic event**. No temporal-silence
test can separate them, because there is nothing there to separate: the signal
is identical. This is a property of the phonology — of what VOID *sounds like* —
not a threshold that was set wrong.

The repair that suggests itself is to loosen `IS_CON` until VOID reads DIR.
That would be the worst available move: it trades a true bound for a detector
that can no longer fire, which is the vacuous-gate defect this paper repeatedly
catches in itself. **The bound is witnessed instead.**

### The consequence, stated rather than implied

Any compound whose child is VOID is **ambiguous to the temporal decoder**.
`⊕(BEING, VOID)` round-trips as `⊕(BEING, ⊕(⊥,⊥))`.

★ **This bounds the PHONETIC register only.** The written register is
unaffected: `κ` inverts, and the glyphic round trip is untouched. So the correct
statement is not "the trimodal identity fails" but that **the phonetic register
carries strictly less recoverable structure than the glyphic one, and here is
the exact input class on which it does.** That belongs beside the existing
`Invariant preservation, both registers` `[W]` row, whose bound already reads
*"up to declared invariants [B]"* — this NAMES one of those invariants for the
first time.

### How it is now gated

`phonseq.la` emits a PRIMITIVE ROW — the control the confusion matrix never had.
★ Every one of the matrix's five existing rows (`U_MC`/`U_CON`/`U_CONT`/`U_SYN`/
`U_DIR`) is a **compound**, so no detector had ever been asked to stay silent on
a signal containing no mode. The missing control was a member of the same class
in a *different idiom*, and its absence is the whole reason the matrix stayed
green while `⊕(BEING,VOID)` failed to round-trip: **the case that breaks it was
never a row.**

`build.sh` pins `DDDDDCDDD`, exactly as it pins `tactile`'s `W4=F` limit. Red
path run: forcing `IS_CON` false yields `DDDDDDDDD` and the gate fails. If the
bound ever moves, it is caught — and it is to be **examined, not absorbed** by
editing the expected string.

### For the paper's method section

This is the fourth instance in this document of one pattern, and the sharpest:
**a gate green because the breaking case was outside its corpus, not because the
property held.** The lexicon's expected column had independent origins and could
disagree; this matrix's rows did not span its own input class. The corpus is as
much a part of a gate as the assertion is.
