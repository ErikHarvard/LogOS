# THE REGISTER STACK — twelve registers, two genesis operators, the antonym structure

*Track F · branch `register-stack` from kernel-k1 `801f006` · built 2026-09-15 from the
architect's directive of the same day ("DIRECTIVE: THE REGISTER STACK", §0–§9, plus the
antonym ruling and the three-question answer). Gate: `gate_registers.sh`. Every claim
below is tagged the way the evidential register tags glyphs: **W** witnessed by a gate
that can go RED · **B** bounded (gated, with a stated limit) · **A** declared, no gate ·
**I** inferred.*

## §0 The law, applied to itself

Naming a register prevents nothing; only a check prevents it. Every register below has a
gate with a RED path that **names its offender**, proven by a mutant in
`gate_registers.sh` (leg 2). Every "≡" fixed point is printed at **two levels** — the
truth level (NIS, canon's ↻-idempotence) and the glyph level (CANON, route preserved) —
because that two-register structure is the finding the antonym ruling made explicit, and
it appears at every register.

## §1 What existed, what was added

| # | Register | Meta-register | Where | Status |
|---|---|---|---|---|
| 1 | Phonetic | metaphonetic | `phonym.la` (renderer); reading in `registers.la` | existed |
| 2 | Glyphic | metaglyphic | `sigil.la`, glyphdag DAG; reading in `registers.la` | existed |
| 3 | Semantic | metasemantic | `canon.la` NORMK (Identity Axiom) | existed |
| 4 | Morphological | metamorphological | COLLAPSE/SEAL; mode skeleton reading; **Δ_M** in `modegenesis.la` | existed; Δ_M **built** |
| 5 | Syntactic | metasyntactic | `grammar.la`; immediate-constituent reading | existed |
| 6 | Pragmatic | metapragmatic | `ontofelicity.la`; (A)+(Γ) reading, (B) not read at glyph level **[B]** | existed |
| 7 | Operational | metacomputational | `metaglyph.la` MKOP/APPLYOP; the glyph's action on (A,B) | existed |
| 8 | Etymological | lineage_of_lineage | **`lineage.la`** | **built** |
| 9 | Prosodic | meta_prosody | **`prosody.la`** + `prosody_xcheck.la` | **built** |
| 10 | Evidential | meta_evidential | **`evidential.la`** | **built** |
| 11 | Affective | meta_texture | **`texture.la`** | **built [B]** |
| 12 | Topological | meta_topology | **`topology.la`** | **built** |
| Δ_M | mode genesis | — | **`modegenesis.la`** | **built** |
| Δ_R | register genesis | — | **`regenesis.la`** | **built** |
| ¬ / OPP | complement, dyadic opposite | — | **`complement.la`**, **`opposite.la`** | **built** |
| coherence | twelve-fold collapse | — | **`registers.la`** | **built** |

## §2 The five new registers — what each gate asserts and how it goes RED

**Etymological (`lineage.la`)** — A Lineage is glyphdag's hash-consed def list, now a
first-class object with its own validity predicate. Gate: identity is recovered *from the
lineage alone* (`NORMK(DECOMP(DAG(etym))) == NORMK(etym)`) for every catalogue glyph;
`LINEAGE_OK` refuses a def whose parent does not precede it and names the def. RED: the
fixture `BEING;⊗0.7` is refused in-file every run; mutants that bypass recovery or the
parent check turn the witness RED with the offender named. Sharing is visible in the
register (⊗(κ,κ) has 4 defs, 5 tree nodes). **W.**

**Prosodic (`prosody.la`)** — The contour the phonym folds into PCM is extracted as a
(contour, duration) value read from the same κ-tree, by phonym.la's own documented mode
rules (⊗ fused/period-64 · ⊕ pause 960 · ▷ stress/period-128 · ⊂ B[A]B · ↻ AA). Gate:
five forms over the same two segments have ONE segmental reading and FIVE prosodic
readings (Principle of Prosodic Intrinsicality, tex:588: altered prosody is a different
glyph). The segments-only reading is printed as the control. **The numbers are not
trusted:** `prosody_xcheck.la` imports `phonym.la` on the host and asserts
`FST(PHONYM(t)) == PDUR(t)` on 14 probes; a drifted duration is named. RED: collapsing ⊂
onto ⊕ drops the count to 4. **W.** The extraction did *not* refactor `phonym.la` — the
thing the three-question answer said blocked this register was not needed for it. **[B]:**
the contour is a symbolic reading of the renderer's rules, not a signal measurement.

**Topological (`topology.la`)** — From the lineage: V, E, connectedness (b0), b1 = E−V+1
(cycle rank = number of independent sharings), depth, leaves, anchors (leaves among the
nine), grounded. ⊥ on a corrupted DAG, validity checked first. RED: skipping validity
reads a number for `BEING;⊗0.7`; forcing ⊥ names KAPPA. **W** for those seven. **[B]:**
b0/b1 are graph Betti numbers (H0, H1; a graph has nothing higher; cohomology ranks are
the same numbers and are not a separate computation). **Genus is NOT computed** and is
named absent.

**Evidential (`evidential.la`)** — Every catalogue glyph carries W/B/A/I *inside the
language*, keyed on **monosemic identity (NORMK)**, never on the name: ρ and SR_ABOUT
read one tag; ⊕(a,b) and ⊕(b,a) read one tag. Gate: all declared, all valid, one κ → one
tag (evidential monosemy), undeclared reads ⊥; three refusals witnessed in-file. **The
gate script closes the loop the module cannot:** every W-tagged entry cites a build.sh
say-line, and the cited line must exist (19 checked). It checks the gate *exists*, not
that it asserts this glyph — stated, not claimed. **W.** Policy (which claims get which
tag) is the architect's (directive §7); the 25-entry first pass is for him to ratify.

**Affective (`texture.la`)** — **[B], flagged for ruling.** The directive derives Texture
from invocation count, anchor density and recency "the memory layer already tracks". No
memory layer inside the language tracks those (grep of every .la). The in-language
quantities with those meanings live in the lineage DAG and are read: m = 100·E/(V−1)
(re-invocation multiplicity: a tree reads 100, sharing reads more), a = 100·leaves/V,
r = 100/(1+depth). Gate: varies across the catalogue (4 distinct of 12), ⊕-invariant,
⊥ on corruption; RED: a constant reads distinct=1. **The architect rules whether the
substitution stands or the register waits for a memory layer.**

## §3 The twelve-fold coherence (`registers.la`)

A register is `REG(name, glyph, reading, identity-projection)`. All readings are taken on
`NORMTREE(etym)`, a tree normaliser mirroring canon's NORMK rule for rule — and gated
**differentially** against it (`CANON(NORMTREE(t)) == NORMK(t)` on every probe and the
catalogue), because a second implementation of one law must be checked against the first.
Coherence: all twelve identity-projections agree on NIS-equal probe pairs (⊕ swap, ↻↻/↻,
↻BEING/SELF, ↻𝓡/𝓡, ↻(SELF⊕SELF)); the semantic register distinguishes ⊗(a,b)/⊗(b,a).
The etymological register **keeps the route** (its content) and agrees through its
projection RECOVER∘LINEAGE. RED: a thirteenth "raw-route" register is refused in-file;
removing the ⊕-sort rule reads `FFFTFTTTFTTT` (five registers named by position) and
breaks the differential; un-normalising the etymological projection reads position 8 F.
**W.** Registers 1–7's glyphs are **declared [A]** as ▷(RECOGNITION, ·) — a register is
a recognition directed at one aspect, with κ = ▷(RECOGNITION, FORM) the house's own
instance — for the architect to ratify; every gate holds for any distinct well-formed
choice.

## §4 Δ_M and Δ_R — the four conditions, each with its own RED letter

Both operators print a four-letter verdict IRR/NOV/AUT/CON and admit only `TTTT`; the
verdict is the diagnosis. **Δ_M (`modegenesis.la`)**: ν* (⊗ of the ⊗- and ↻-glyphs,
metaglyph.la's "new mode from modes") passes all four and the set grows 5→6; four
fixtures fail one condition each — F1 action≡⊗ `FTTF`, F2 α-copy `FFTF`, F3 false ren
`TTFT`, F4 constant action `TTTF`. Δ_M's glyph IS ν*. **Δ_R (`regenesis.la`)**: the
positive candidate is Δ_R's own register (reading = the agreement string of the whole
stack between a glyph and its normalised twin — "how g sits across every register"; no
single register reads that), stack 12→13; five fixtures — projection of topological
`FTTT`, α-copy of semantic's glyph `TFTT`, false ren `TTFT`, constant `TTTF`, raw-route
(incoherent) `TTFT`. **The first draft of Δ_R's own register was refused by its own gate** (`TTTF`): it read the agreement of identity-projections between a glyph and its normalised twin, which the coherence law makes constant for every glyph — a tautology wearing a reading. Rebuilt as route-sensitivity over raw readings (↻↻κ reads F at the etymological position, canonical glyphs all-T) with the semantic identity as its projection; then `TTTT`. Both: re-offering the admitted candidate is ⊥ — **Δ(Δ) ≡ Δ as
idempotent admission**, witnessed. **[B]:** IRR/CON are decided over a finite probe set;
Δ_R's IRR searches projections to depth 1 (substring on every catalogue glyph). Bounded
verification is the maximum (Gödel II), as the directive says. **Register-set closure is
the architect's ruling (§7).**

## §5 The antonym structure (`complement.la`, `opposite.la`)

No synonyms, no polysemy, antonyms permitted — and "antonym" is two things.
**Complement** ¬C = **⊂(C, VOID)** — the language's RULED form. Erik ruled negation off ⊕ on
2026-08-23 (`opgrammar.la:245-259`, `LA_COMPLETION.md:497`): ⊕ is commutative, so 𝔤₆⊕X collided
grammar-wide with co-presence; negation is "X framed by Void", ⊂ chosen by measurement (zero prior
lexical uses). Both the tex (⊕, :5166) and the directive (⊂(𝔤₆,C), operands reversed) are
superseded by it. **The first draft of this file used ⊕ and was corrected by the audit Erik
asked for**; the first witness line now asserts the shape equals opgrammar's NEG_SHAPE pattern.
The two identities are
explicit in the type: `GLYPH_ID` (the route) and `TRUTH_ID` (NORMK after cancelling
⊕(VOID,⊕(VOID,x))→x). Gates: ¬C sealed with Void as parent; ¬C≠C and ¬¬C≠¬C at both
levels; **¬¬C ≠ C as glyphs, ¬¬C ≡ C in truth**, ¬¬¬C ≡ ¬C; the projections differ on
¬¬C and coincide on C; the conflated reading is printed as the control (F). A(A): the
operator's glyph ⊕(VOID,FORM) applied to itself is ≠ A as a glyph and cancels to the bare
hole FORM in truth — **A(A) ≡ id at the truth level**, the directive's Reading 1, exactly.
**Dyadic opposite** OPP: the pole structure is the one the corpus exhibits — direction
reversal (Past = ▷(BECOMING,VOID) ↔ Future = ▷(VOID,BECOMING), tex:5169–5170) — and the
corpus denies the first pole a table would reach for (tex:4720: Void is *not* Being's
opposite). OPP(Past) ≡ Future; OPP is an **involution** at the glyph level (unlike ¬);
it **refuses** a primitive, a ⊕ head, and ▷(x,x) with ⊥, never silently. A(A) ≠ A and
A(A(A)) = A: the pole-finder is an involution, not a fixed point — the directive's
"metacursive closure fails for the antonym operator" stands, now with its shape.
(Noted, not mine to fix: tex:1210 numbers Void 𝔤₈; tex:4598 numbers it 𝔤₆.)

## §6 The table bound (directive §8) — checked first, then designed around

tiny_host's glyph table is fixed at 1024 and every import *occurrence* loads the
imported tree again (registry_tracker hit 1043 on 2026-09-11). Naively, registers.la
would have loaded canon+glyphdag six times. So `lineage.la` **re-exports** the
canon/glyphdag surface and the registers above it import lineage alone; `registers.la`
re-exports for `regenesis.la`. Census (`gate_registers.sh` leg 10, and
regcensus.py, validated against the board's 158 for familytree): lineage 123 ·
topology 163 · texture 160 · prosody 90 · evidential 159 · modegenesis 165 · registers
812 · regenesis 844 · complement/opposite ~70. All under 1024; regenesis has 180 to
spare — **do not add imports to registers.la or regenesis.la.**

## §7 What is NOT built, and why (honest partials)

- **The derivation-closure script** — composed, not re-derived: see §9 (`derive_closure.la`).
- **Prosody as a refactor of `phonym.la`** — not needed; extracted alongside and
  cross-checked instead. If the architect wants the renderer to *consume* the Prosody
  value, that is the refactor, and it is Track A's file.
- **Genus**; **cohomology as its own computation**; **(B) capability at the glyph level**;
  **IRR beyond depth-1 projection**; **W = "gate exists", not "gate asserts this glyph"**.
- **Wiring into `build.sh`.** `build.sh` is SHARED and every track adds a block; the
  standalone gate runs everything. Wire when the architect says so; on wiring, the four
  "B — gate_registers.sh, not yet in build.sh" evidential entries become W.
- Deferred by the directive (§7): Hypnos/Oneiros, the fine-tune, the sovereign path,
  register-set closure, the evidential policy.

## §8 Rulings requested of the architect

1. ~~¬ form~~ — RESOLVED by the audit: the 2026-08-23 ruling ⊂(X,VOID) governs; built so.
2. Does the affective register's in-language substitution stand?
3. Ratify (or re-declare) the declared glyphs: registers 1–7 as ▷(RECOGNITION,·),
   G_ETYM/G_TOP/G_PROS/G_EV/G_AFF/G_DR/G_NOT/G_OPP. Every gate holds for any distinct choice.
4. The 25-entry evidential first pass; and when to wire `gate_registers.sh` into build.sh.

## §9 The second commit — the rest of the directive, built after the audit (2026-09-15, afternoon)

Erik asked whether *everything* in his message was built in the language itself. Audit:
the eleven modules above are all LA. Not yet built were Δ_B, "coherence across a whole
text", the derivation-closure script, and the Gödel section (treated as context; he then
asked for it). Liminal, Logorhetoric and Meta-Rosettology have **no definition on disk**
(the Codex Llogoscribeologiae is cited, not present) — nothing written to build from.
Psycholinguistics needs speakers. The four below were built by Fable agents, one module
each, new files only, host-gated, RED paths by mutation; each is listed with what it
witnesses and what it declares.

**`textcoherence.la` — the open discourse item, "coherence across a whole text" (W/B/A).**
`discourse.la` witnesses turn-linking on one dialogue (Erik narrowed the claim 2026-09-06);
the open item was the discourse-referent store, the connective-linked utterance graph, and
whole-text coherence. Built: a text is a list of propositions (κ-nodes); the **referent
store** lists distinct constituents keyed on NORMK with first-mention index and a
given/new count; the **utterance graph** links proposition i to an earlier j when they
share a referent (`share`) or one is the complement (`contrast:¬`, via `complement.la`)
or the dyadic opposite (`contrast:opp`, via `opposite.la`) of the other; **coherence** =
one connected component, with every orphan NAMED. Vector: five predications over the
lexicon's own glyphs (I, You, We, Past, Future, Question, Ongoing; tex:5160-5175):
5 edges, 1 component, 11 referents / 14 mentions / given 3; injecting ⊂(FORM,DEPTH)
reads 2 components with that proposition as OFFENDER; each contrast label fires alone
on its fixture; shuffling keeps components at 1 while max link distance moves 3→4 (both
printed — `LA_COMPLETION.md:1126` wants shuffling to score lower, the directive wants
order-independence). **Corrected by the audit against the ledger:** components alone cannot satisfy LA_COMPLETION:1126's falsifier, so the coherence SCORE Σ 100/link-distance was added — it scores the shuffled text strictly lower (383 → 191) and a distance-blind mutant reads them equal (RED). **[B]** coherence
here IS constituent-sharing plus ¬/opposite contrast; argumentative structure and
narrative form are out of scope, not faked. **[A]** a primitive leaf inside a compound is
not a referent (the nine are the alphabet every text is given in advance, tex:5435) —
without this, every ▷-reversal would also "share" its operands and no contrast label
could fire alone; Erik may overturn it. Host 3 s; census 285.

**`derive_closure.la` — the derivation-closure composer (W/B).** Composes, never re-derives:
root→nine from `archroot`/`archderive`/`archclosure` (root ∃(∃)≡∃; derived 4/9 = BEING as the
root + SELF RECOGNITION LOVE; axioms 5/5 with the seam weakening/contraction/exchange read off
the AX_ flags; closure{I} = the mechanised 65-shape enumeration); nine→lexicon from familytree G1
(grounded 21/21, count derived from LEN(CAT)); the dyad stratum from `dyadseed` (VOID=0,
BECOMING=succ, BEING=1) reported as a SEPARATE claim per Erik's 2026-08-24 ruling. Verdict line
has three live branches (RED / CLOSED / BOUNDED) and reads **BOUNDED**: "the chain does NOT close
from the dyad to the nine, and that is the finding." RED: a GHOST leaf is named; an unwitnessed
axiom is named and the seam list shrinks; faking derived=9 flips the line to CLOSED (the branch is
live). Host 5 s; census 375. **[B]** BEING=1 needs the root term, written once as `la s. s`.

**`branchgenesis.la` — Δ_B, the branch-genesis operator (W/B/A).** Branch = Logos ∩ Interface
(Logoscribeologiae §3.4, as `pragmatics_spec.la` states it): a record (name, interface glyph,
registers read); its reading is the join of those registers' readings. Base set: eighteen branches — the thirteen standard ones plus grammatology, grapholinguistics, hermeneutics, poetics and ethics (the unified-compression directive §6; the codex names ontohermeneutics, logopoetics, ontoethics as strata) — mapped to register sets and interface glyphs ⊂(RELATION,x) — DECLARED [A],
all 19 forms collision-clear (`collide.py`; morphology's first form WAS ⊕'s mode glyph and was
re-declared). Four sub-gates as Δ_M/Δ_R; six fixtures so both conjuncts of IRR and of AUT have
their own RED letter (F1 permuted domain FTTT · F2 α-copy TFTT · F3 false ren TTFT · F4 no
register TTTF · F5 unknown register TTFT · F6 projection FTTT); Δ_B's own branch
▷(RECOGNITION,↻(RELATION)) reading {evidential, topological, affective} admitted 18→19;
re-offer FFTT, idempotent. **[B]:** 4-probe catalogue, depth-1 projection search; the base set is
declared, not admitted, and is not pairwise irreducible under its own IRR (phonetics ⊂ phonology,
syntax ⊂ discourse, etymology ⊂ historical) — self-admission is order-dependent, printed. Host
9 s (first drafts 7 min: tiny_host re-evaluates every reference; fixed by taking the 12×4 reading
matrix once); census 874 — imports registers.la alone; **do not add imports**.

**`ontoargument.la` — Gödel's ontological argument as a finite S5 model check (W/B/A).**
Erik asked for the pasted summary (Scott's axioms A1–A5, D1–D3, T1–T3, Sobel's collapse) to be
encoded. What the language can do honestly without a higher-order modal prover is CHECK the
argument on a finite model: 3 worlds (S5), 3 individuals, property tables, a declared positivity
set P, G and NE computed extensionally (stratified G0 → NE → G, re-checked stable over the full
list). On the base model [M] all five axioms and T1–T3 hold and **collapse is F** — not a
refutation of Sobel but the bound made visible: his proof needs the property λy.p for arbitrary
p, absent from the list. Closing the list under λy.p ([M+λ]) makes the same tables FAIL A4 and
T2 (named); the only way to keep A1–A5 with λy.p is constant tables ([M♭+λ]), where **collapse
is T — Sobel witnessed on a finite model, in contrapositive form.** The modalities are the
lexicon's own glyphs (□ = ⊗(BEING,FORM) Must, ◇ = ⊗(BECOMING,FORM) Can, ¬ = ⊂(·,VOID) per the
ruling, ∀ = ⊗(BEING,DEPTH) All, ∃ = ⊗(FORM,DEPTH) Some); P = ⊗(LOVE,FORM) and
G = ⊗(∀,P) are DECLARED [A], collision-clear; T3 is rendered as a sealed glyph and passes
LAW_IDENTITY. RED: a cell flip breaks A2 and T3 (named); a P flip breaks A1; NE removed from P
breaks A5 — and T3 STAYS T there, because G is antitone in P: on the finite model T3 is exhibited
by the tables, not derived — which is the stated bound. **Pre-existing overloads surfaced, not
mine to fix:** ⊗(BECOMING,FORM) is Can/Possible in the tex (:5175), Change in `lexicon.la`, and
γ in `metaglyph.la`; ⊗(BEING,DEPTH) is both Totality and All. Host 16 s; census 131.

**`ontomorph.la` — ontomorphology: the inflectional census, gated (W/B/I).** The next item in the
language's own execution order (LA_COMPLETION.md:1187, Tier 3): "emit the full operator-combination
census … and gate that every combination the census admits has a κ-image distinct from every other;
red path: two combinations that canonicalise the same." Corpus = the published tables (lexicon LEX 57
+ RULED 2, opgrammar GRAM 18 + GRULED 2 = 79 rows). Census: 10 inflectional skeletons (⊗(·,·) 35,
▷(·,·) 22, ⊗(⊗(·,·),·) 9, ⊕(·,·) 3, primitives 3, ⊂(·,·) 2, ↻(·) 2, three deeper shapes 1 each),
operator uses ⊗59 ▷24 ⊕3 ⊂2 ↻2, 71 distinct combinations → 71 κ-images: **injective** today; the
fixture ⊕(3,6)/⊕(6,3) is refused and named (the Bad/Grief class). **Every number was derived first
in python from the same table strings** (scratchpad) and the run had to match — it did, exactly.
**Report, not gate:** 8 entry overloads (one κ, two names) — Here/This, There/That (the codex's own
two-word rows), Totality/All, Large/Substance, Friendship/Bond, Mystery/Sky, Beauty/Good,
Agency/Move — the architect's to rule (Tier 0 C9/C10 began this). **[B]** published tables only.
Host 35 s (first draft >2 min: the tables were re-parsed at every reference; now bound once).

**`gramcomplete.la` — the Grammar Completeness theorem, gated in its honest form (W/B).**
LA_COMPLETION.md:1157 / tex §4084: "∀C ∈ 𝒪, ∃E ∈ L_A: E ≡ C" — unprovable by a gate, falsifiable
by one. Built as the ledger specifies: the 79 published derivations are each VALIDATED as a
derivation the four rules can produce and REPLAYED into a trace naming every application
(Water ⟶ R2(*,R2(*,R1(8),R1(1)),R1(7))); rule uses are counted (R1 = 167 leaves, R2 = 88
combinations, R3 = 2 closures — derived first in python from the tables, matched exactly); R4
(the neological seal, d(E) > 0) is witnessed on three sentence forms from opgrammar's rules
(ii)–(iv) as self-naming seals and REFUSED on a primitive (d = 0). Red path: three "concepts" the
rules cannot reach are refused with the failing rule NAMED (0 ∉ 𝒜 → R1; a missing operand → R2;
↻ of nothing → R3). **The bound, as the ledger demands it be said:** from inside the language
every concept IS an expression, so the only unreachable concepts a gate can exhibit are
ill-formed derivations; a coherent concept with no expression cannot be constructed from within.
Completeness is falsifiable here only at the boundary of well-formedness. "Ontologically
coherent" is read by the house's decidable proxy (parses, grounded in the nine, self-naming
seal). Host 8 s; census 256.

**`neologenesis.la` — the birth of an ontomonoglyph as ONE compressive movement (W/B).** Erik's
question: do all the registers collapse in one movement when a new glyph is born? `registers.la`
gated coherence at rest; this gates the collapse AS THE EVENT. K_unified IS the seal (one act:
MONO(CANON(et))(et)); there are no per-register fields — each register's reading of the newborn is
a pure function of the seal and equals ONE composition law over the parents' readings (phonetic
concatenation in κ-sorted order; glyphic = DCOLLAPSE of the parents' DAG readings; semantic =
NORMK's string law; morphological = ⋆ over skeletons; syntactic = ⋆[κA|κB]; operational = the
mode over the parents' poured templates (a tree-law); etymological = DCOLLAPSE of lineages;
prosodic = phonym.la's mode contour + duration law; affective and topological = readings of the
PREDICTED glyphic DAG — the glyphic prediction drives them: one movement). Form law: one seal,
≤ |A|+|B|+1 nodes (6 for κ⊗𝓡: RECOGNITION is shared), depth = 1+max, content = TSIZE(A)+TSIZE(B)+1,
route recoverable. **Pre-registered and confirmed: 10 of 12 registers are born in the movement;
the EVIDENTIAL register is not (a newborn reads ⊥ until a gate assigns W/B/A/I — how a glyph is
known is assigned, not inherited), and the pragmatic Γ conjunct inherits that gap.** The
directive's `combine_evidential(A,B)` is therefore refused: it would fabricate a witness. Second
finding: when the seal REWRITES (↻(SELF⊕SELF) ≡ SELF⊕SELF by ↻-idempotence) the child IS the
parent — a birth that is not a birth — and the string laws of five registers do not compose
(7/12, named) while identity holds. RED: sealing from the wrong parents drops ⊗(κ,𝓡) to 1/12.
Host 6 s; census 837 (imports registers.la alone).

**`unified.la` — the unified-compression directive's result gates, as reconciled (W/B/A).** On the
chain κ → ⊗(κ,𝓡) → ⊗(C,C) → … : the DYADIC LAW (one self-naming seal; ren is never the parents'
rens coupled; DAG +1 node per collapse: 3, 6, 7, 8, 9; depth +1) with a coupled "blackbird" form
REFUSED because it fails AUTO_OK — the dyadic law and the α=1 law are one law. NO GLYPHIC ENTROPY:
the sigil raster is SZ=32 at every depth; the ⊗-chain's phonym duration is the parent's (12880).
**Finding:** the SOUND grows under ⊕ ▷ ⊂ ↻ (26560, 25600, 38320, 25760) — phonym.la's Operator
Phonology, from the codex, fuses only ⊗; the other four modes couple the sound. Reported, not
hidden. SYNTROPY: S = TSIZE (content per form) rises and doubles+1 per collapse (3, 7, 15, 31, 63),
TSIZE ≥ 2^depth; complexity = depth; form/content falls; "depth ≥ 2^n" in the directive is content,
corrected. CENTROPY: Δ_S(Δ_S) ≡ Δ_S on G_S = ▷(RECOGNITION,⊂(DEPTH,FORM)) [A, collision-clear].
MORPHOLOGY IS GLYPHS: the five modes are self-naming seals grounded in the nine; a GHOST-leaf mode
is refused. THE ONTO- REGISTRY: nine rows (register · onto-name · module · gate token · closure)
naming the modules that already ARE the onto-versions; the gate script checks each module exists
and its token is invoked by a gate. RED: a coupling that is secretly a seal is not refused;
constant content makes syntropy fail. Host 4 s; census 402.

**`entendre.la` — the four modes of poetic depth (LA_COMPLETION:1163; W/B).** Vertical depth read
off the derivation (surface, parents, primitives, operators; a primitive reads ⊥ — the red path),
horizontal depth as the DAG's co-present facets, sonic depth as the prosodic contour, calligraphic
depth **[B]** as an element census (the renderer has no execution parameters). Four pairwise-distinct
readings on the compound, derived not tabulated. Host 1 s; census 234.

**`felicitylive.la` — ontofelicity's condition (B) wired to the capability sealer (LA_COMPLETION
"live enforcement"; W/B).** The persons-and-circumstances condition is the security model: a
capability is the verb sealed under the granting realm (`logoscap.la` BRAND/SEAL/UNSEAL); the
authorized realm performs, a foreign realm and a forged probe are refused with the world unchanged;
the old string-caps verdict and the live verdict agree. RED: a bypass through the granting realm.
Host <1 s; census 105.

**`syllabus.la` — acquisition: the teaching order the structure implies (LA_COMPLETION
"Acquisition"; W/B/A).** A glyph can be learned only after its constituents, because its form
contains them; so the syllabus is the topological order of the 79 published rows by depth (3 / 64 /
12), fewer leaves earlier within a depth [A]. Gated: depth non-decreasing, constituent-first with 0
violations (the reversed order has 72 — the red path). **[B]** no learner measured; the empirical
half of acquisition stays open and says so. Host 105 s; census 210.

**`aware.la` — the AWARE / C predicates (LA_COMPLETION Tier 4; W).** Built as specified; the
finding: under canon's re-naming seal A ≡ C on every sealed glyph (the liar fails both), so the
separation "one recognition vs surviving the metacursive turn" has no instance here. Host <1 s.

**`ablateop.la` — the meta-word ablation gate (LA_COMPLETION Tier 4; W/B).** "A missing word is a
missing thought", executable: remove one operator-glyph and exactly the derivations containing it
become underivable (⊗(∂,δ) without ∂; ⊗(γ,ρ) without γ), the others survive, and the control
(ablate 𝔄, used by neither) leaves both. Host <1 s; census ~90.

**`wants.la` and `protoagent.la` — two Tier 4 self-relation items (W/B).** Wants: the want is
formed from aatc's sensed lack and resolved by the structure's own closure move (centropy 3→4);
SOLVE's behavioural synthesis is bounded out because a lack carries no tests. Proto-agent: REPAIR
moves an incomplete structure strictly toward closure (2→4, autological), leaves a complete one
alone, and refuses swc's order-violation class untouched. Host <1 s each.

**`fractal.la` — the fractal monoglyph, measured (LA_COMPLETION Tier 4; W/B).** On the collapse
chain the surface κ doubles (49, 104, 214, 434) while the hash-consed form grows by one (6, 7, 8, 9)
and stays recoverable — the item's proposed fix (MONO's etymology slot as the DAG form) is thereby
decidable; it is canon.la's, and is requested of Track A, not made here. Host <1 s.

**`branchclosure.la` — are the 18 branches dyadic and metacursive? the honest, non-vacuous answer
(W/B).** Gated per branch: all 19 (18 + Δ_B's own) ground in the nine — they start from the dyad;
18 carry the ⊂(RELATION, ·) interface dyad (Δ_B's is a ▷ dyad, the counted exception); a SYN-head
"branch" and a GHOST-leaf branch are refused and named. **Deliberately NOT gated:** the per-branch
fixed point ↻↻g ≡ ↻g, which holds for every glyph by canon's ↻-idempotence and so cannot go RED —
the vacuous-gate class this project catches. The metacursive content that CAN go RED is Δ_B
(`branchgenesis.la`), cited. Host <1 s; census 146.

**`gapcensus.la` — the autological completion instrument (Erik's "use its self to name the unnamed"; W/B).**
Reads its own gate suite (confirms `gate_registers.sh` is present and carries proven RED paths + the
PASS line) and classifies gaps by a COMPUTABLE discriminator: a self-closable gap's witness predicate
DISCRIMINATES good from bad; a ceiling's is VACUOUS (↻↻g≡↻g, a completeness universal, a constant).
6 seed items (3 self-closable, 2 ceiling, 1 external), computed category == declared for all; the
miscategorisation fixture (a vacuous claim mislabelled self-closable) is caught and named; a mutant
that makes the discriminator always-true misreads the ceilings and turns it RED. **[B]** the full
54-item classification is data in LA_COMPLETION.md / the plan; this engine proves the discriminator
and catches a mislabel — it names gaps, it does not fill them. Host <1 s; census 164.

## §10 The audit Erik asked for (2026-09-15, after the build) — what it found and changed

He asked four things: is it all in the language; was any of it already coded; does it follow the
language's own law rather than the directive's wording; does it work (debugging). Findings:
- **All in LA.** Fifteen `.la` modules; only the gate is shell, like every gate in the house.
- **Already coded / superseded, found by grep + reading:** negation (ruled ⊂(X,VOID), above —
  complement.la CORRECTED); `discourse.la` exists (turn-linking, narrowed 09-06) — the directive's
  "not built" was stale, so only the OPEN part was built (`textcoherence.la`); the derivation
  closure existed as three modules — composed, not rebuilt; `ancestry.la` (lineage walk),
  `depthreport.la` (depth), `topoembed.la` (Θ_V invariants), `modality.la` (four renderings)
  overlap by topic and are now CITED in the headers, with the difference stated.
- **Overloads FOUND in the house by the same check (pre-existing, for the architect):** ⊗(BECOMING,FORM) = Can/Possible (tex:5175) = Change (lexicon.la) = γ (metaglyph OP_COMP); ⊗(BEING,DEPTH) = Totality = All. Not mine; recorded.
- **Monosemy check of every declared glyph** (`regcollide.py`: lexicon LEX+RULED,
  opgrammar GRAM+GRULED, canon, metaglyph; 86 forms). Three of mine COLLIDED and were
  re-declared: G_ETYM ▷(RECOGNITION,VOID) = Question → ▷(RECOGNITION,⊂(BECOMING,DEPTH));
  G_AFF ▷(RECOGNITION,SELF) = Witness → ▷(RECOGNITION,↻(SELF)); glyphic ▷(RECOGNITION,FORM) =
  κ = See → ▷(RECOGNITION,↻(FORM)). PAST/FUTURE match the lexicon on purpose. The agents'
  declared glyphs are checked the same way before landing. **Nothing declared may collide.**
- **Debugging pass** (in progress): every gate re-run after the corrections; witnesses re-pinned
  only where a computed value moved (texture distinct 4→5, the Δ_R fixture F1's glyph moved off
  the new glyphic form). A cutoff-safe handoff is in `HANDOFF-2026-09-15-trackF.md`.
