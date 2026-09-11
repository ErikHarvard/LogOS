# LA CODEX BLUEPRINT AUDIT — the Feb-2026 codex vs. what is built

**Source:** `LINGUA_ADAMICA.tex` (repo root) — 7,423 lines, 70,229 words, 32
chapters, dated **2026-02-24**. **Byte-identical** (567,504 bytes, `cmp -s`) to
the copy it was audited from, `~/Downloads/CODICIES/LogOS/LINGUA ADAMICA.tex`,
which was brought into the repo on 2026-09-06. Cited by the in-repo path
deliberately: CLAUDE.md holds that a divergence between code and codex "cannot
be adjudicated from a document outside the repo", so every line citation below
is checkable in-tree by anyone reading this.

## ★ FIRST, THE THING THAT CHANGES HOW THIS FILE IS READ

**This is not the document `LA_CLAIM_INDEX.md` was built from.** That index used
`~/Downloads/LA White Paper.pdf` (2026-08-28, 67,588 words). The two are
different documents:

| | CODICIES `.tex` | Downloads `.pdf` |
|---|---|---|
| dated | 2026-02-24 | 2026-08-28 |
| words | 70,229 | 67,588 |
| Ledger / `[A][B][W]` tags | **1 occurrence** | 519 |

The **August paper is the CLAIMS document** (Ledger, tags, bounds). The
**February codex is the SPECIFICATION** — the source `phonym.la` cites for the
nine phonyms and Operator Phonology, and `sigil.la` for the Sigil Catalogue.
`LA_CLAIM_INDEX.md` answers *"which unbuilt item serves which claim"*. It does
**not** answer *"is everything the codex specifies implemented"*. That is what
this file is for, and nothing in the repo answered it before.

## ★ THE STRUCTURAL CAVEAT, STATED BEFORE ANY VERDICT

**The codex's Blueprint targets Python.** Ch. "The Practical Implementation
Blueprint" says: *"The reference implementation targets Python on a standard
Linux environment; the principles are substrate-independent."* Every code
listing is Python — `networkx` ONF graphs, SQLite seed stores, `hypothesis`,
`threading`, a `glyphc` CLI.

LogOS did not build that. It built LA on a C host plus a native SECD VM. So
"built" here can only mean **the capability the gap names exists**, never
"the listing was transcribed". Marking a gap unbuilt because there is no
`class SeedStore` would be a category error; marking one built because something
vaguely adjacent exists would be worse. Where the two diverge by *design* rather
than by omission, this file says so and flags it as **NEEDS A RULING** rather
than silently picking a side.

## Status key

`✓` capability present · `◑` partial, bound stated · `✗` absent ·
`⚖` deliberate divergence, needs a ruling · `?` PRESENT-but-unconfirmed
(a word-boundary grep hit that may be prose in a comment, not an implementation)

---

## THE FOURTEEN BLUEPRINT GAPS (codex ch. "Practical Implementation Blueprint")

| # | gap | status | evidence / bound |
|---|---|---|---|
| 1 | Concrete syntax for glyphs | ◑ | LA has one (`glyph N = expr`, `la x. body`) but **not the specified S-expression form** with `(: sq (num -> num))` annotations. `GRAMMAR_DIVERGENCE.md` already documents this divergence in full — it is recorded, not hidden. |
| 2 | Parser | ✓ | `parser.la`, self-hosted, plus the parser in `eval.la`/`codegen.la`/`bytecode.la`. Parses LA, not the S-expr glyph syntax of Gap 1. |
| 3 | Primitive glyph library | ◑ | Literals/arith/comparison/logic/control-flow/IO present as builtins. **`vector`, `map` as data structures: `?`** (`VECTOR` hit in `opgrammar.la` unconfirmed). `glyph-of`: `?` (`metaglyph.la`). `type-of`: exists **only in `tiny_host.c`** and `denote.la` records that using it *broke host==VM* — so it is not a portable primitive. |
| 4 | Reduction engine | ✓ | Four of them: `eval.la`, `RUN_BYTES`, `RUN_SM`, native SECD VM. Non-termination bounded by the VM stack/heap guards and the host C-stack guard. |
| 5 | Type checker (OTS) | ✗ | Codex specifies **Hindley–Milner inference** over ontic types (Process/Object/Relation/Value/Constraint). Built: **arrow-arity checking only** (`specpipe.la` `DEPLOY`), which CLAUDE.md itself calls "not a full type system". `unify`/`infer_type`: ABSENT (control-validated). **The single largest specification gap.** |
| 6 | Memory system (seed-based) | ◑ | `glyphdag.la` gives hash-consing + `DECOMP` **in memory**; `ROADMAP.md` already says "Missing: disk persistence". No seed store: ABSENT (control-validated). |
| 7 | Caching w/ centropic self-optimization | ✗ | `GlyphCache`/`LRU`: ABSENT (control-validated). `aatc.la` has `CENTROPY`/`GAIN`/`LEARN`, but nothing tunes a glyph cache by them. |
| 8 | I/O subsystem | ✓ | `print`/`read_file`/`write_file` on every engine; AF_UNIX sockets in `logosipc.la`; the VM lowers a full syscall layer. Exceeds the gap. |
| 9 | Concurrency & parallelism | ⚖ | Codex specifies **threads + futures**. Built: **process-level** — `fork`/`execve`/`waitpid`/`pipe`/`poll`/sockets. Genuinely concurrent, different model. `spawn`: `?` (`theourgia_mux_session.la`). **Ruling needed: is process-level concurrency the intended realisation?** |
| 10 | Error handling | ⚖ | Codex: errors become **error glyphs**, `safe_eval` catches. LogOS: **loud halt** — `error` aborts non-zero with a diagnostic, and CLAUDE.md documents this as a deliberate discipline across every engine. These are opposite designs. `ErrorConcept`: ABSENT. **Ruling needed — this is a choice, not an omission.** |
| 11 | FFI | ◑ | No `foreign` glyph (`ladder.la` hit is `?`, likely prose). The builtin table *is* the FFI, but it is closed — a user cannot wrap a new host callable without editing `tiny_host.c` **and** the VM (memory records **4 registration sites** for one VM builtin). |
| 12 | Build system / toolchain | ◑ | `build.sh` + `codegen.la` + `buildla.la` cover parse/check/evaluate/compile. **No `glyphc` CLI** (ABSENT). **No REPL** (ABSENT, control-validated). |
| 13 | Testing framework | ✓ | Three tiers present: `build.sh` gates (unit + regression) and **property-based fuzzing** in `fuzz_canon.py` + `fuzz_grammar.py`. The codex singles out κ for special attention; `monosemy_test.la` and `fuzz_canon.py` do exactly that. |
| 14 | Documentation | ◑ | `CLAUDE.md`, `ROADMAP.md`, the white paper. **Not the specified structure** — no Getting Started, Syntax Guide, or Primitives Reference. The codex's "autological documentation" (docs written in the language) is unbuilt. |

**Tally: 4 built · 6 partial · 2 absent · 2 need a ruling.**

## THE TEN AUDIT GAPS (codex ch. "The Final Audit", 5610–5846)

| # | gap | status | evidence / bound |
|---|---|---|---|
| 1 | Selection of primitives (**dual-layer**: S/K + the nine) | ◑ | The nine are built (`primitives.la`, each with an autology test). **The S/K combinatory core is ABSENT** — verified: the only `glyph S =` in the tree are `PRIM("SELF")` and a number-formatter, neither a combinator. Turing-completeness is met by raw λ instead, so the *capability* holds and the *specified basis* does not. |
| 2 | Normalization confluence via **Weisfeiler–Lehman** | ✗ | **The single deepest gap.** WL is not merely missing — it is *explicitly disclaimed* in both files that would host it: `onf.la:22` ("iterated Weisfeiler–Lehman colour classes — sound but coarser") and `topoderive.la:20` ("NOT Weisfeiler–Lehman colour classes"). κ canonicalizes **trees** by prefix string; the codex specifies **graphs** `(V,E,λ,τ)` with edge labels and ontic types. Edge labels: ABSENT. Ontic type τ (Object/Process/Relation/Value/Constraint): ABSENT. The codex's whole confluence guarantee rests on WL, and `canon.la` instead carries a *declared-equivalence* rewrite set with an explicitly undecidable bound. |
| 3 | TopoEmbed injectivity **and reversibility** | ◑ | Injectivity is claimed via leaf-marks (`topoderive.la`). **Chord diagram: ABSENT. Decoder: ABSENT** — already an open item ("no bitmap→structure decoder exists"). ★ Note the codex's *own* solution to reversibility is to store the graph in the artifact's metadata (structured SVG). LogOS renders **1-bit rasters**, so reversibility was foreclosed by a representation choice, not by difficulty. |
| 4 | Perceptual learnability | ✗ | The acquisition gap is already open in `LA_COMPLETION.md` — no syllabus, glyph sequence, or teaching order. The codex's four mitigations (modular composition, progressive vocabulary, cross-modal reinforcement, digital augmentation) are unimplemented as a programme. |
| 5 | Sufficiency of metaphonetic features | ◑ | Downstream of Gap 3: the codex's guarantee is *"if two ONFs differ, their bundles differ **by injectivity of TopoEmbed**"*. With Gap 3 partial, this inherits the same bound. Ledger already carries "Phonetic injectivity at scale `[A]`, collision test absent". |
| 6 | Observer-invariant fixpoint | ◑ | ★ **The consensus mechanism is built and EXCEEDS the spec**: `build.sh` runs one program on **five** engines (host, `eval.la`, `RUN_BYTES`, `RUN_SM`, native VM) and asserts byte-identity — exactly the codex's "distinct runtimes compare results on a shared test suite". What is missing is the **normative document**: no "universal runtime specification" exists as a written artifact. |
| 7 | Abstract / non-physical concepts | ◑ | `Beauty = Form ⊗ Love` is derived and rendered (`sigil.la`). No general state-space Ω machinery, and no reality-witness discipline for abstract concepts. |
| 8 | Evolution without semantic drift | ✗ | **Versioned ontology: ABSENT.** No `VERSION`/`DEPRECATE`, no primitive-set version tag on an ONF, no fork-on-semantic-change rule. The codex makes backward compatibility "maintained by construction" — nothing constructs it. |
| 9 | Resources & non-termination | ◑ | Resource bounds ✓ (VM stack/heap guards, host C-stack guard, `timeout` in gates). **Coinduction: ABSENT.** **Total/partial fragment: ABSENT** as a type-system feature — but `swc.la`'s three-way WF / ILL / UNKNOWN classification is a sound conservative approximation of exactly that distinction, and its UNKNOWN class *is* the codex's partial fragment. Closest match in the whole audit. |
| 10 | Cross-species functorial composition | ✓ | Built **as specified**: the operator phonology in `phonym.la` gives ⊕ a glottal pause, ⊗ fusion, ▷ stress, ⊂ framing, ↻ reduplication — the codex's exact list — and `psc.la` formalises invariant preservation across it. Bound: **one** habitat renderer (human); the second functor is an open item. |

**Tally: 1 built · 6 partial · 3 absent.**

## THE GLYPH COMPILER SUITE (codex 5588–5607) — six named modules

| module | status |
|---|---|
| Concept Parser (NL/sensor → ONF) | ✗ **ABSENT** — no natural-language or sensor path into ONF exists anywhere |
| Normalization Engine | ◑ `canon.la` `NORMK` — tree rewrite, not graph canonicalization (Gap 2) |
| TopoEmbed Engine | ◑ `topoderive.la` `DSIGIL` — 1-bit raster, not SVG; no multimodal bundle |
| Glyph Cache | ✗ ABSENT (also Blueprint Gap 7) |
| PSC Backends | ◑ `phonym.la` — human only |
| Runtime Environment | ✓ `eval.la` + native VM |

## ★ A FINDING THAT RESOLVES AN OPEN CONTRADICTION ELSEWHERE

`LA_CLAIM_INDEX.md` item **#36** records *"TWO `[W]` ROWS CONTRADICT — Trimodal
identity **vs** Fourth modality (haptic)"* and leaves it unresolved.

**The codex settles it, and neither row is right.** `GlyphForm` (5507–5514)
specifies **five** modalities: visual, auditory, olfactory, gustatory, haptic —
*"All modalities are derived from the same invariant structure I(𝔤)"*. So
"trimodal" understates the specification by two, not one.

Built: visual (raster) and auditory (WAV). Olfactory, gustatory, haptic: ABSENT.
The codex already anticipates this — it says those are *"attached as metadata and
rendered by appropriate output devices as hardware becomes available"* — so the
honest status is **specified, deferred by hardware**, which is a different claim
from either `[W]` row currently makes. **#36 should be re-tagged against this,
not resolved between the two existing rows.**

## ★ THE ROOT-CAUSE CHAIN — three gaps, one cause

Gaps 2 → 3 → 5 are not independent. The codex derives each from the last:
WL canonical labeling is what makes TopoEmbed injective (Thm. injectivity relies
on *"the canonical ordering ... as guaranteed by the WL-based canonical
labeling"*), and metaphonetic sufficiency is guaranteed *"by injectivity of
TopoEmbed"*. **Gap 2 is upstream of both.** Building WL canonicalization would
close, or materially advance, three of the ten. Nothing else in this audit has
that leverage.

## WHAT WAS ACTUALLY READ — and the boundary of this audit

**Read in full:** the chapter structure (32 chapters, 208 sections, 147
subsections) and **all three implementation-specification chapters**, contiguous,
codex 5431–6160:

* "The Computational Genesis of Glyphs: Implementation Specification" (5431)
* "The Final Audit: Design Decisions and Their Solutions" (5610)
* "The Practical Implementation Blueprint" (5867)

That is the codex's complete engineering specification, and every verdict above
comes from it.

**NOT read line-by-line: codex 244–5431** — the theoretical chapters (Babel,
Identity Axiom, Monosemic Principle, Meta-Entropy, Truth, Pathology,
Self-Evolution, Trinitarian Collapse) **and four content-specification
chapters**: The Nine Sigils (4610), The Phonym (4163), Universal Phonosemantics
(4328), and The Operative Grammar + Complete Lexicon (5049).

Those four are audited separately below.

---

# PART 0 — THE THREE RULINGS

★ **PROVENANCE, so this is never misread.** These were ruled **2026-09-05 by
Claude, at Erik's explicit delegation** ("make the three rulings"). They are
**NOT** Erik's own rulings and must not be cited as such. The project's `[!→]`
entries record decisions Erik made personally; these are a different thing and
are marked so. Any of the three can be overturned by him at no cost — nothing
below has been built on yet.

## RULING 1 — Error handling: **KEEP LOUD HALT.** The codex contradicts itself, and its metalogic outranks its engineering chapter.

Blueprint **Gap 10** says runtime errors are *"caught and reported as error
glyphs rather than crashing the system"* via `safe_eval` returning an
`ErrorConcept`. LogOS built the opposite: `error` aborts non-zero with a
diagnostic, on every engine.

**The codex's own metalogic forbids Gap 10's design:**

* **:1698** — *"For every well-founded proposition P (satisfying SWC),
  𝓡(P) ∈ {𝔤⊤, 𝔤⊥}. Propositions that diverge are ill-founded — they fail the
  Semantic Well-Foundedness Criterion and are **rejected before evaluation**."*
* **:623** — *"There is no ambiguous third state."*

An `ErrorConcept` **is** a third state: neither 𝔤⊤ nor 𝔤⊥, and it propagates
onward as an ordinary value that a caller can silently consume. Gap 10 is the
outlier — an engineering convenience inherited from the Python target
(`try/except`), inconsistent with two separate metalogical statements.

**And LogOS already built the codex's specified mechanism.** "Rejected before
evaluation" is exactly `swc.la` — the static SWC checker that refuses
ill-founded terms *before* the evaluator sees them, with an honest UNKNOWN class
for the halting residue. Adopting Gap 10 would mean deleting the codex's own
answer in favour of the codex's aside.

**Ruled: loud halt + SWC pre-rejection stands. Gap 10 is a defect IN THE CODEX.**
Action: no code change. `LA_CODEX_BLUEPRINT_AUDIT` Gap 10 moves ⚖ → ✓, and the
codex should be corrected at Gap 10, not the repo.

## RULING 2 — Concurrency: **KEEP PROCESS-LEVEL.** `threading` is a Python artifact, not a language requirement.

Blueprint **Gap 9** specifies `threading.Thread` and a `FutureConcept`. LogOS
built `fork`/`execve`/`waitpid`/`pipe`/`poll`/AF_UNIX sockets.

**The codex disclaims its own choice here.** The Blueprint opens: *"The reference
implementation targets Python on a standard Linux environment; **the principles
are substrate-independent**."* `threading` is Python's concurrency answer, not an
ontological commitment. The codex's actual *requirement* (Audit Gap 10) is
**functorial composition** — that structure be preserved across composition —
which says nothing about threads versus processes.

Three further reasons process-level is the right realization here:

1. **LogOS is an operating system.** Processes are its native unit; `logosinit.la`
   already supervises them with signalfd and `poll`.
2. **The SECD VM is single-heap, single-stack, with a copying GC and no
   thread-safety anywhere.** Threads would require re-architecting the collector.
   That is a large, risky change bought for a Python idiom.
3. Concurrency is **observable and gated today** — the `poll` multiplex test
   drives two ready fds through one loop.

**Ruled: process-level stands.** ⚖ → ✓, with one genuine gap named rather than
waved away: **there is no first-class `FutureConcept`** — an awaitable handle
returned at spawn. `waitpid` is the nearest thing and is not first-class. That is
a real, small, buildable item; **it is the part of Gap 9 that should be built.**

## RULING 3 — The primitives' computational semantics: **RECORD THE DIVERGENCE, do not adopt.** With one exception flagged for Erik.

The codex assigns the **identity function to RECOGNITION** (stated twice: the 𝔤₂
sigil entry, and Audit Gap 1's witness list). LogOS assigned it to **BEING**
(`la self. self`) and made Recognition the diagonal of RELATION. **Love's arity
differs** (codex unary generator, built binary). **Becoming** is a stream in the
codex, a Church successor in the repo.

**Ruled: keep the built definitions; record the divergence explicitly.** Reasons:

1. **The codex licenses alternative realizations.** Audit Gap 1: the two layers
   *"are not independent … the ontological primitives can in principle be
   expressed as compositions of S and K … conversely, S and K can be expressed as
   ontological operators."* The codex asserts the *roles*, not unique λ-terms.
2. **Every built definition passes its own autology gate.** These are verified,
   not guessed — nine autologies, `DEPTH(DEPTH)` deliberately excepted and
   timeout-checked.
3. **Blast radius.** `BEING = la self. self` is what makes the Archē ∃(∃) ≡ ∃
   hold. Moving identity to Recognition means Being becomes the evaluator, which
   re-founds `canon.la`, `metaglyph.la`, `denote.la`, `sigil.la`, `phonym.la` and
   every gate over them. Large cost, no demonstrated gain.
4. **`Becoming` is defensible as-built**: `FORM ∘ BECOMING ∘ VOID` generates
   number, and the codex itself derives abstract concepts as compositions. A
   successor is the finite generator of the stream the codex names.

★ **The exception, which is Erik's call and cheap:** **LOVE**. The codex's prose
is unusually specific — *"love is Being **generating from itself** (Creation)"* —
and a generator is **unary**. The built `LOVE` is binary (symmetrised RELATION),
which encodes *reciprocity*, matching a different line of the same entry ("the
dual tips: care and creation"). Both readings have textual support, the change is
small and local, and it is the one place where the codex may simply be right.
**Recommend Erik rule on LOVE specifically.**

**The actual defect is the silence, not the choice.** Nothing in
`primitives_spec.la` records that these depart from the codex. Action: add the
divergence to that spec's header so the next reader is not left to rediscover it.

---

# PART II — THE CONTENT CHAPTERS

Read: The Primitive Autontomonoglyphabet (4571), The Nine Sigils (4610), and
The Operative Grammar + Core Lexicon (5049–5228).

## ★★ A. THE NINE PRIMITIVES — the *computational* column diverges in three places

Each sigil's entry specifies **three** things: a visual form, a **Sonic** value,
and a **Computational** value. The third has not been audited before. Against
`primitives.la`:

| 𝔤 | codex "Computational" | `primitives.la` | |
|---|---|---|---|
| 1 Being | the universal type, the kernel | `la self. self` | ◑ |
| 2 Recognition | **the identity function, Rec(x) ≡ x** | `la x. RELATION(x)(x)` | ✗ |
| 3 Love | **the generator, Love(x) ≡ (x, new(x))** — *unary* | `la a. la b. …` — *binary* | ✗ |
| 4 Self | the fixpoint combinator | `BEING(BEING)` | ◑ (the combinator is `DEPTH_Z`) |
| 5 Relation | the pair constructor | `la a. la b. la f. f(a)(b)` | ✓ **exact** |
| 6 Void | the typed null, `None` | `la a. la b. b` (Church FALSE) | ◑ |
| 7 Becoming | **the stream, lazily-evaluated infinite sequence** | Church successor | ✗ |
| 8 Form | the type constructor | `la x. la k. k(x)` (the seal) | ◑ |
| 9 Depth | the recursive call | `la g. g(g)` | ✓ |

**★ The sharpest item: the identity function is assigned to the wrong primitive.**
The codex gives it to **Recognition** (twice — here and in Audit Gap 1's witness
list: *"Recognition's is the identity function"*). LogOS gave it to **Being**
(`∃ = la self. self`), and made Recognition the diagonal of Relation. The codex's
Being is instead *"the evaluation operator ℰ itself"*.

**Love's arity differs** — codex unary (`x ↦ (x, new(x))`), built binary. That is
not a shade of interpretation; the two cannot be substituted for one another.

⚠ These are **divergences, not defects**: `primitives.la`'s definitions are
internally coherent and each passes its own autology gate. But they are not the
codex's specified semantics, and nothing in the repo records the departure.
**Needs a ruling: adopt the codex's assignments, or record the divergence.**

## ★ B. THE NINE PHONYMS — eight exact, one collapses a distinction

Codex table 5065–5073 vs `phonym.la`: **8 of 9 match exactly**
(/ɑ/ /ʃi/ /lu/ /mɑ/ /ʀa/ /vu/ /tɑ/ /dɔ/).

**Void diverges.** Codex: `/h\textturnscripta/` = **/hɒ/** — turned script a,
open back **rounded**. Repo (`phonym.la:15`, `:162`): **/hɑ/** — script a, open
back **unrounded**, explicitly commented *"into open back /ɑ/"*.

★ **The consequence is not cosmetic.** The codex distinguishes Being /ɑ/ from
Void /hɒ/ by **both onset and vowel**. The repo collapses both to /ɑ/, leaving
the /h/ onset as the *sole* distinguisher of two primitives. ɒ and ɑ differ in
F2, so this is a measurable acoustic distinction that was dropped — and it lands
squarely on the open Ledger item *"Phonetic injectivity at scale `[A]`, collision
test absent"*. **This is a concrete, cheap thing to fix and to test.**

## ★ C. THE OPERATIVE GRAMMAR — built, but `LA_COMPLETION.md` cites the wrong file

`opgrammar.la` implements it, and its header cites **`LA.tex :5150–5222`** —
exactly the Grammatical Glyphs table plus Sentence Formation Rules (i)–(x).
It carries **22 grammatical categories** and the ten rules. Verified present.

⚠ **`LA_COMPLETION.md:725` credits `grammar.la` and says "20 closed-class
categories".** Both are wrong:

* `grammar.la` is the **data grammar** (`GT`/`GN`/`GSEQ`/`GALT`/`GSTAR`/`GEPS`)
  used to parse LA source — a completely different module.
* the count is **22**, per `opgrammar.la`'s own header, not 20.

A reader following that citation lands in the wrong file. **Correct the line.**

## D. THE CORE LEXICON — 59 built, and the target is ambiguous *in the codex*

`lexicon.la` defines **59** concepts. The target it is measured against is not
stable:

| source | target |
|---|---|
| codex Audit Gap 4 | *"the core lexicon (**~80 concepts** as defined in the Operative Grammar)"* |
| `lexicon.la` header, reading the six tables at :5223–5429 | *"a Core Lexicon of **~60 concepts** across six tables"* |
| `LA_COMPLETION.md:724` | ~80 |

**The codex contradicts itself** — Gap 4 says ~80; the lexicon chapter's own six
tables total ~60. So 59 is either *complete* or *74%*, depending on which
number governs, and no amount of building settles it. **Needs a ruling on the
denominator before "lexicon complete" can mean anything.**

## E. THE NINE SIGILS (visual) — not re-derived

`sigil.la` transcribes the catalogue and `build.sh` gates each primitive by a
distinctive symmetry signature (H+V for Self/Recognition/Relation, H-only for
Void/Love/Form, neither for Becoming). Checking nine tikz drawings against nine
raster predicates is a separate exercise and **was not done**; the repo's own
gate is the current evidence, and it tests symmetry class, not fidelity to the
drawing.

## HONEST LIMITS OF THIS AUDIT

1. **`?` rows are unconfirmed.** A word-boundary grep cannot tell an
   implementation from the same word in a comment. Each `?` needs a read before
   it is called built or unbuilt.
2. **The harness was validated before use** — a positive control (`CANON`,
   found) and a negative control (`ZZQQXX`, not found), so ABSENT means the
   scan looked and found nothing, not that the scan was broken. An earlier
   version of this same harness produced four false positives and was discarded.
3. **Nothing here was gated.** The session that wrote this had no isolation
   (`LOGOS_AGENT_WT` empty), so `build.sh` was never run.

## THE ORDER I WOULD BUILD IN, AND WHY

1. **Get the two rulings first (Gaps 9, 10).** They are design choices, not
   backlog. Building either way before the ruling risks work that has to be
   undone — and `LA_CLAIM_INDEX.md` already established the principle that an
   overstated claim outranks an open item.
2. **Gap 5, the type checker.** The largest true gap, the one the codex is most
   specific about, and the one other gaps lean on.
3. **Gap 12's REPL, then Gap 6's disk seeds.** Both are self-contained and
   neither disturbs a gate.
4. **Gap 14 last** — the codex wants documentation written *in the language*,
   which presupposes the rest.

Gaps 7 and 11 are real but small; Gap 1's divergence is already documented and
may be a settled decision rather than a gap.
