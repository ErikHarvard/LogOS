# Lingua Adamica — the completion list

Everything still required for the language to be complete **by Erik's own stated
criteria**, ordered so that each tier unblocks the next. Assembled from: five
Fable sweeps of the codices, the phonetic/glyphic parity audit, the
meta-programming audit, the dyad/meta-sigil audit, ROADMAP's 114 open and 14
partial items, and the defects found by building.

**Every item carries the gate that would prove it, and its white-paper
counterpart.** The paper and the language must land together: an item is not
done until the code is gated AND the paper states it at the right tag.

Status key: `[ ]` unbuilt · `[~]` partial · `[✓]` done today · `[!]` needs Erik

---

## ★★★ THE GOVERNING STANDARD — read before building anything on this list

**Complexity accrues error faster than capability unless the verification layer
compounds too.** Stated as a principle before 2026-08-27; **empirically supported
after it.** Syntropy is not automatic. It is conditional on the system's capacity
to catch itself growing at least as fast as the system.

### The standard
**Before building anything new, ask: does the check for THIS actually run?**
A module with a gate that exits 0 unconditionally is **worse than a module with
no gate**, because it reports false confidence — an unwired gate looks
uncovered; a dead one looks covered. **Every gate in the arc must be able to go
RED**, and that must be demonstrated by planting the defect it claims to catch,
not argued.

### Why this is now evidence and not exhortation
One day's findings, all in the verification layer rather than the language:

| defect | count |
|---|---|
| modules marked `[✓]` in THIS FILE with no runner at all | 8 |
| gates exiting 0 without running, reported as passing, every build | 1 |
| gate invocations where deleting the gate file keeps the build green | 6 |
| comparisons that cannot fail alone (each implied by two others) | 6 |
| provenance controls defeated by an adjacent line | 1 |
| PASS messages announcing measurements that had moved | 5 |
| this document's own entries marking built work as open | 1 |
| mutation-lever entries crediting a STATIC reader for BEHAVIOURAL coverage | 1 |
| instruments that were broken when first written (mine, this session) | 3 |

Two of those deserve their own line because they generalise:

★ **The question no audit was asking.** Every audit this project has run —
Audit II's discriminating power, Audit III's cannot-fail comparisons — asks
*"can this check fail?"* of checks that **run**. None asked *"does this check
run?"* of the whole inventory. Three hits in one day, every one a by-product of
looking for something else. (Framing: track E, Freeze III.)

★ **And one level up: did the evidence come from EXECUTION?** The mutation lever
reported `selfext2b.la` CAUGHT; the mutant was killed by a *static analyser
reading the source*, and the gate never ran the organ. A static analyser and a
behavioural gate can both go red, and only one is evidence the code works.
Marker, measured: 20 CAUGHT lines, 19 carry a `% of baseline` ratio, the 1
without is the bogus one — the ratio is computed against the gate's runtime, so
it cannot exist when the gate never ran.

### The corollary for instruments — the subjects are not the only thing that rots
An instrument's `--selftest` must calibrate **coverage**, not only detection. A
tool can pass a detection control while reading half its surface — and then a
clean report means nothing. Every absence-claim in this project must be able to
show it looked.

★ **Coverage has TWO axes, and a calibration for one will not catch the other.**
* **Idiom coverage** — right files, one notation of two. (Track E's Audit IV tool
  read 51 of 96 checks and reported clean; all three calibration fixtures used
  the idiom it handled.)
* **Surface coverage** — every notation, wrong files. (`preflight_artifacts.py`
  v1 scanned `build.sh` and not the `gate_*.sh` scripts, so it **could not have
  found the bug it was written for**, and its planted controls passed.)

**The reconciliation that catches both:** a self-test must compare a count taken
**independently of the tool** against what the tool actually parsed, and refuse
to report on a mismatch. Planted controls only prove a tool sees what you built
it to see; a real-world control — revert a known fix and require the tool to find
it again — is what proves it sees what you did not.

⚠ **FOUR instrument failures in one day, all mine or track E's, none in the
subjects:** a tool that could not find its own motivating bug; a detection-only
calibration certifying a third of an input; a dependency scan matching on
**basename**, so `.bootelf_fix/asm.la` matched `asm.la` and produced 45 false
positives; and the same scan then **under-reporting**, missing eight untracked
files that were only found by acting on the result and re-checking. The
instruments need this standard at least as much as the subjects do.

---

---

## OBSCURANTISM — COINED 2026-08-27. `[~]` MODULE GREEN, GATE PENDING.

`obscurantism.la`. Erik: euphemisms and meta-euphemisms create semantic
obscurantism, and it is a term the language should coin. Nothing in the corpus
named it.

    OBSCURE(t) := SDEPTH(CANON(t)) > SDEPTH(NORMK(t))

A form is obscurantist when it carries **avoidable depth** — same referent as its
own canonical form, more structure to walk. Fires on `⊗(∃,∃)` (1→0) and
`↻(↻LOVE)` (2→1); **spares** `⊕(B,A)` (1→1), a reordering rather than an
obscuring.

★ **Why depth and not α<1, settled by measurement.** Every non-canonical form is
α<1, including `⊕(B,A)`. The naive α-based definition was red-pathed against this
module's own corpus and **fails the `spares` arm**. Defining obscurantism as "not
in normal form" would have made the term mean nothing.

**The result:** obscurantism is DETECTABLE AND REMOVABLE, NOT PREVENTABLE. The
lexical euphemism is already unconstructible — `REN ≡ κ∘ETYM` by construction, so
"collateral damage" is unmintable; the form would have to carry
`⊗(killing,civilians)` in its own body. What remains can only be avoidable depth,
and any hearer collapses it in one total pass. Obscuring is self-defeating rather
than forbidden.
**BOUNDS:** relative to κ's declared rewrite set, as monosemy is; and the
utterance level is outside the semantics **by ruling R-B**, so
misleading-by-implicature is not something LA can police.

⚠ **`[~]` AND NOT `[✓]`, DELIBERATELY.** The module is green with three measured
red paths, but **its `build.sh` gate is not yet wired** — it was written during
build 5 and lands in build 6. By this document's own governing standard it is
therefore an UNGATED module, and marking it done would make it the ninth entry in
exactly the class this session spent the day pulling out. It is `[~]` until a
build has run its gate.

---

## ITEM 5 / L3 — THE GRAMMAR PARSING ITSELF. `[✓]` BOUNDED, 2026-08-26.

`grammar_l3.la`, gated. **GPARSE — interpreting the L1 data productions — parses the
source file that DEFINES those productions**, and rejects a corrupted copy of the same
token stream.

* **The lexer is NOT re-implemented.** `TOKENIZE` drives `parser.la`'s own `NEXT_TOKEN`,
  keeping its token-type names. A lexer written for this test could be tuned until the
  self-parse passed, which is exactly the result this must not be. (L2's stated bound:
  GPARSE consumes token types; lexing is parser.la's job.)
* **Composition is by concatenation, and the order is load-bearing.**
  `import("parser.la")` binds nothing — parser.la has no `export` line — so this uses the
  pattern `build.sh` already uses for `monosemy_test`. The two modules have
  **incompatible list encodings** (parser: `NIL=PAIR(FALSE)("")`, tagged-pair CONS;
  grammar: Scott), and **redefinition takes the FIRST binding**, so grammar.la must
  precede parser.la. Safe because parser.la's *lexer region* uses PAIR and strings only —
  zero NIL/CONS references, verified. parser.la's own `MAIN` must be trimmed or it wins
  the first-binding race and parses `kernel.la` instead. The gate asserts both facts.
* **The reject arm is what makes the accept mean anything** — a GPARSE returning TRUE
  unconditionally would produce an identical accept column.

### ★★ THE BOUND IS MEASURED, NOT GUESSED — and it is a PERFORMANCE bound
`grammar.la` lexes to **1689 tokens**. Lexing is fast; **GPARSE is the cost** — `MATCH`
backtracks naively and `P_MODULE` is a STAR over an ALT, so work grows superlinearly.
Measured on prefixes cut at definition boundaries (so a slice never ends mid-definition,
which would confuse "rejected because truncated" with "rejected because broken"):

| defs | lines | tokens | accept | reject-corrupted | time |
|---|---|---|---|---|---|
| 4 | 47 | 84 | T | F | 2s |
| 8 | 51 | 145 | T | F | 5s |
| 12 | 58 | 209 | T | F | 7s |
| 16 | 62 | 333 | T | F | 15s |
| 20 | 78 | 538 | T | F | 37s |

| **all** | **144** | **1689** | **T** | **F** | **1637s (27 min)** |

★★ **THE WHOLE FILE SELF-PARSES — witnessed 2026-08-26 19:05.** accept=T, reject=F on the
complete 1689-token stream. An earlier draft of this entry said the full run "was not
witnessed to terminate"; that was true when written and is now **false**, and it is
corrected here rather than quietly dropped, because a stale bound reads as a real one.
★ **accept=T and reject=F at EVERY size** — the grammar was never what was in doubt; the
interpreter is slow. Cost grows about **n^3.3** (3.1× the tokens for 44× the time), the
signature of `MATCH` re-scanning from the same position on every failed arm of a
STAR-over-ALT.
★ **The gate still asserts the 333-token prefix — for BUILD TIME, not for evidence.**
27 minutes is ~15% on a 3-hour build for a fact already established out of band.
★ The prefix is a prefix **of the self**, not a different corpus.

**Reported PARTIAL, per Erik's 2026-08-18 scope ruling** ("L3 only after L2 green, and
reported PARTIAL if it lands bounded").
**Inherited and unrepaired:** L2's associativity blind spot — `app_tail` is
left-associative and a verdict-only differential cannot see associativity.
**Red path exercised:** a corrupted subject → RED; removing `P_PRIMARY`'s `ident` arm →
RED. Plus two structural guards (the lexer survived the 395-line trim; parser's MAIN did
not).

---

## TIER 0 — CLOSED. ALL SEVEN RULINGS MADE (Erik, 2026-08-23/24)

This tier is no longer a blocker. Three were ruled on 2026-08-23 and are landed
and gated; four were ruled 2026-08-24 and are recorded here as the decisions
that govern the work below. **A gate may pin a set; it may not decide it** — so
every item below cites the ruling rather than inferring one.

### DECIDED AND LANDED

- `[✓]` **The three undeclared collisions — RESOLVED, and a fourth with them.**
  The first scan ever run *across* the content lexicon and the closed class
  found 11 collisions; eight were aliases the codex declares in its own gloss
  column (monosemy WORKING). The rulings:
    * **`You` keeps ▷(SELF,RECOGNITION); `Know` → ⊗(SELF,RECOGNITION).** You is
      closed-class and deixis/pragmatics/discourse are already gated on it.
    * **`Give` keeps ▷(BECOMING,RELATION); `Because` → ⊂(BECOMING,RELATION).**
      Give's gloss matches the form it has; Because's gloss described the
      converse, which If…then already occupies.
    * **`Change` keeps ⊗(BECOMING,FORM); `Can` → ⊗(FORM,BECOMING)** — "form in
      the process of arriving", which is the codex's own gloss for Can.
  ★ Three of these need a free form on an operand pair that a **commuting ⊗
  would have denied**. They rest on the LA.tex:2837 correction.
  **ZERO undeclared collisions remain**; `opgrammar.la` asserts each ruled pair
  ABSENT by name, so a partial revert fails rather than leaving a plausible total.

- `[✓]` **C9 — RESOLVED by moving negation off ⊕.** The tables were not the
  defect. `:5166`/`:5212` make `𝔤₆⊕X` the grammatical negation prefix, and with
  ⊕ commutative (:2854) **every ¬X is identical to the co-presence X⊕Void** —
  Bad/Grief was one visible instance of a grammar-wide collision. Negation now
  takes **⊂**, chosen because `ablate.la`'s census measured ⊂ at exactly ZERO
  uses: the only operator whose adoption could not collide. *The measurement
  selected the fix.* ⊕ keeps its commutativity and the ⊕/⊗ distinction survives.
  Grief keeps ⊕(LOVE,VOID); **Bad = ⊂(LOVE,VOID) IS ¬Love**, which is what the
  ruling said it was. ⊂ is no longer unused: census now ⊗=59 ⊕=3 ▷=24 **⊂=2** ↻=2.

- `[✓]` **C10 — NOT a ruling, an ERRATUM. 𝔤₆=Void, 𝔤₈=Form.** Backed by the
  primitive table (:4598), the phonym table (:5070), the dedicated chapter
  (:4718 "𝔤₆: Void — The Absence") and ~20 lexicon derivations. Only two prose
  lines — `:1210` and `:2050` — call 𝔤₈ "the Void"; they are stale draft text.
  **Fix those two lines; do not treat this as open.**

### RULED 2026-08-24 — FINAL, AND EACH CREATES WORK

- `[!→]` **A. `⊗(A,A) ≡ A` HOLDS ONLY FOR THE ARCHĒ.** For every other A,
  `⊗(A,A)` is a **distinct compound**. This is a *principled choice and must be
  documented as one*, because the current behaviour is otherwise indistinguishable
  from a rendering accident: `⊗(A,A)` used to be byte-identical to `A` in sound —
  with identical parents any weighted blend collapses, (2g+g)/3 = g — so an
  infinite family of distinct glyphs shared one phonym, and the renderer, not the
  theory, was deciding.
  **WORK:** state the Archē exception explicitly in `canon.la`'s rewrite set and
  in the paper; gate it in BOTH registers (glyphic and phonetic); assert the
  general case stays distinct. A rule that holds by accident is not a rule.

- `[!→]` **B. IMPLICATURE IS BANNED AT THE SEMANTIC LAYER.** LA encodes literal
  compositional meaning. Implicature **arises in use but is not a property of the
  language**. Grice is not refuted; he is placed outside the semantics.
  **WORK:** add the pragmatics note saying exactly that — the Logolaconic
  Principle (:6747) is a density principle and does not currently say it; and
  `pragmatics.la` must not grow a defeasible quantity layer. The ban is a
  *positive* claim about where meaning stops, and it needs stating, not silence.

  ### `[✓]` **B — DONE 2026-08-26, and the ban is MECHANICAL.**
  * **The ruling, stated positively** in `pragmatics_spec.la`'s header (★ the spec —
    `pragmatics.la` says "generated by specpipe.la — do not edit" on line 1). It
    REPLACES the old note that said implicature "survives monosemy and needs a ruling".
  * **Paper:** `LA_PAPER_ADDITIONS_3.md` §3e rewritten from "still open" to the ruling,
    with the falsification test spelled out; `LA_PAPER_ADDITIONS_2.md`'s "one open item
    needing YOUR ruling" resolved in place. The Logolaconic Principle (:6747) is a
    DENSITY principle and does not say this, so the sentence belongs AT that tag rather
    than being read into it.
  * **The mechanical constraint** (`build.sh`, pragmatics section): no
    `IMPLICATE`/`IMPLICATURE`/`SCALAR`/`QUANTITY`/`DEFEASIBLE`/`MAXIM` glyph may be
    defined in `pragmatics.la`, with the ruling QUOTED in the failure message so the
    next author reads the decision rather than the symptom.
  * ★★ **It is an ABSENCE assertion, so it proves it looked** — this session's own
    highest-yield finding applied to new code. A bare grep-for-absence passes over a
    missing, empty, or wrong file while checking nothing. Two POSITIVE controls guard
    it: the file is non-empty, and it really is the pragmatics module (defines
    `PRAGMATICS`). Red path exercised on all four states:

    | state | verdict |
    |---|---|
    | the real module | GREEN |
    | a `SCALAR` glyph added | **RED** — ban fires |
    | `pragmatics.la` EMPTY | **RED** — emptiness control fires |
    | a different non-empty file (absence TRUE but meaningless) | **RED** — positive control fires |

  * **BOUND:** this bans implicature from the SEMANTICS. It does not claim speakers
    cannot implicate — it claims implicature is not a fact about the language. The
    falsifier is named rather than avoided: an LA utterance whose literal composition
    underdetermines what a competent reader takes from it.

- `[!→]` **C. ★★ GENERATE FROM THE ROOT — the six co-primitives are a GAP, not a
  result.** `archroot.la`'s settled finding was that only THREE of nine primitives
  derive from the root and six are co-primitive. **Erik's ruling reverses the
  status of that finding**: it is an incompleteness to be closed, not a fact to be
  reported. Either **derive the remaining six**, or **name them as honest axioms
  with the seam stated explicitly**. ★ **NO STIPULATION** — an axiom declared as
  an axiom is acceptable; an axiom smuggled in as a derivation is not.
  **WORK:** re-open `archroot.la`. Its current conclusion must be re-tagged from
  "settled" to "the gap". `dyadseed.la` stands as-is — VOID ≡ Church zero, BEING
  ≡ Church one by eta, BECOMING ≡ successor — but it grounds the arithmetic
  stratum *beneath* the primitives and may not be cited as the derivation chain
  this ruling asks for.

  ### `[✓]` **C.1 — THE RE-TAG. DONE 2026-08-26.**
  Not a comment change: `build.sh` gates archroot's PRINTED VERDICT on the literal
  `6 co-primitive`, so it was a coupled edit across five sites — the module header,
  the printed verdict (`6 UNDERIVED ... = THE GAP`), the gate's expected string,
  build.sh's section prose **and its PASS message** (which still ANNOUNCED "6 are
  co-primitive atoms" while the gate above it checked UNDERIVED), plus `dyadseed.la`
  and `LA_PAPER_ADDITIONS_3.md`. Red path exercised: a simulated revert to
  "co-primitive" turns the gate RED, so the status is mechanically enforced.
  host==VM byte-identical on the re-tagged module.

  ### `[✓]` **C.2 — THE ATTEMPT. DONE 2026-08-26 — `archderive.la`, gated.**
  ★★ **The outcome is AXIOMS WITH THE SEAM STATED, and the seam turned out to be
  exact.** The root ∃ **is the identity combinator I** (`BEING = la s. s`, and
  ∃(∃)≡∃ is I(I)≡I). `{I}` is **closed under application** — I applied to anything
  returns that thing — so the terms reachable from the root by application alone are
  exactly `{I}`. Therefore:
  * **BEING is not a gap at all**: it IS the root, under another name. Witnessed.
  * The other five are **AXIOMS**, and what each one ADDS is now named, not waved at:

    | primitive | seam — what it introduces that I cannot do |
    |---|---|
    | `VOID` | **WEAKENING** — discards an argument |
    | `DEPTH` | **CONTRACTION** — duplicates an argument |
    | `BECOMING` | **CONTRACTION** — uses `f` twice (iteration) |
    | `FORM` | **EXCHANGE** — reorders its arguments |
    | `RELATION` | **EXCHANGE + ARITY 2** — the binary `FORM` |

  ★ **I is LINEAR: it neither discards, duplicates, nor reorders. The five
  primitives it cannot reach are precisely the three STRUCTURAL RULES it lacks.**
  That is why the derivation fails, and it is a result rather than a shortfall.
  **BOUND, stated in the module's own verdict:** closure is witnessed to depth 4
  (all 8 application trees over `{BEING}`); the induction is argued in prose, not
  mechanised. Every seam is witnessed BY REDUCTION on a total probe.
  **Gate:** `build.sh` "Arch derive", host + native VM + `cmp -s`. Red path
  measured, not guessed — mutating each of the six reds it, in **two different
  modes**: FORM/RELATION/BECOMING/BEING print `? no` and exit 0, while VOID/DEPTH
  make `str_eq` receive a non-string and HALT (rc 1) with the output TRUNCATED.
  The gate therefore asserts rc, every witness line, the absence of `? no`, **and
  the VERDICT line** — without that last one every grep still passes on the
  truncated file, because the greps that ran were true and the ones that would
  have failed were never reached.
  **NOT DONE / next:** derivation from a LARGER basis than the root alone is a
  different question and is not attempted here; if the root is ever taken to
  include more than `∃`, this result must be re-run against that basis.

  ### `[✓]` **A — DONE 2026-08-26, gated in BOTH registers.**
  `⊗(A,A) ≡ A` for the Archē alone; every other `⊗(A,A)` stays a DISTINCT compound.
  * **Glyphic:** `REWRITE_SYN` added to `canon_spec.la` beside `REWRITE_MC`, in the
    same declared-equivalence set the ruling named. ★ It had to go in the **SPEC** —
    `canon.la` is GENERATED by `canon_spec.la` and a hand-edit to it is silently
    overwritten the next time any gate runs the spec. (It was, mid-session; caught
    only by hashing the file before and after a test run.)
  * **Phonetic:** `SYNNORM` added to `phonym.la` (hand-written, nothing deploys it).
    ★★ **The two registers DISAGREED until now** — `NORMK` collapsed `⊗(∃,∃)→∃` while
    `NORMP` left it as `⊗(∃,∃)`. A rule holding in one register and not the other is
    not a rule about the LANGUAGE, it is a fact about one renderer, which is precisely
    what R-A exists to prevent.
  * **Gated both directions, both registers** (`build.sh`, canon section): the TRUE arm
    alone would be satisfied by a rule collapsing EVERY `⊗(A,A)`; the FALSE arm is the
    one that was missing when the collapse shipped.
  * **RED PATH PROVEN, and stronger than asked:** mutating the spec to collapse the
    general case makes `REWRITE_SYN: FAIL` and
    `module REJECTED — verification failed; canon.la not written`. **The compiler
    refuses to emit** — `canon.la`'s hash is unchanged. That is condition (a′) of the
    audit framework, witnessed.
  * **No regression:** `canon_spec` VERIFIED · `monosemy_test` still reports
    `idempot ⊗: ⊗(B,B) vs B : DISTINCT` · `fuzz_canon` 60/60 · `archroot` green ·
    all 8 phonym-dependent modules green (`phonorm`: `⊗order-kept OK`).
  * **BOUND:** a DECLARED equivalence, not a discovered one. It extends NORMK's
    equivalence theory, so monosemy stays enforced RELATIVE to that theory — NORMK's
    existing honest bound, unchanged.
  * ★ **Found while doing this:** `fuzz_canon.py` had the WRONG MODEL of what it
    tests — it listed `SYN` as commutative ("-> SORT2 (order-independent)") when
    `canon.la` routes SYN through order-KEEPING `WRAP2`. It reported **9 false
    failures on every run**, and nothing noticed because **build.sh never invokes it**
    (it appears only in a comment at `:2448`) — Q0's hazard exactly. Model corrected;
    now 60/60, and re-verified able to go red (breaking CON's commutativity fails it).

- `[!→]` **D. ⊗ AND ▷ NEED A SECOND PHONETIC CUE.** An accent mark alone is
  insufficient for the two most-used operators. Measured by `phoncoll.la`: **all
  fifteen** stress-only pairs in the vocabulary are the same operand pair under
  ⊗ versus ▷ — census ⊗=59, ▷=24 — and thirteen of the fifteen are the codex's
  own entries, so the thinness is the phonology's.
  **WORK:** add **duration, stress pattern, or a consonant-cluster distinction**
  so the contrast **survives across rendering environments**. It must hold in the
  romanised register a person reads and writes, not only in PCM: ▷ already gained
  a rate-carried marker in the audio, and that is exactly the kind of cue the
  written form still lacks. Re-run `phoncoll.la` after: the pinned stress-only
  set should shrink toward empty, and `phonseq.la` must then DETECT the new cue
  rather than reporting ▷ as a leaf.

  ### `[✓]` **D — DONE 2026-08-26. All fifteen collisions are GONE; the set measures EMPTY.**
  **The cue: a tail DURATION mark `":"` on ▷**, in addition to the head stress it
  already had (`lexicon.la`'s `PH`, DIR branch — hand-written, nothing deploys it).
  ASCII on purpose: the ruling requires the cue to survive across rendering
  environments, and `":"` occurred **zero** times in the phonym alphabet before the
  change, so it cannot collide with an existing contrast.
  `phoncoll` now reports `homophones=[] stress-only=[]` — **nothing was traded for it.**

  ★ **HONEST QUALIFICATION ON THE RULING'S OWN RATIONALE.** It ranked duration first
  because "▷ already carries a rate marker in PCM, so the written form would be
  following the audio rather than inventing." Read against the code that premise is
  **inexact**: `DIRP`'s acoustic marker is a periodic **amplitude modulation** of the
  tail (4/8-5/8-6/8 at period 128), and its own comment records that **duration is
  preserved exactly** — deliberately, because a ▷ compound sits in the gated WAV output
  and a length change would move the file size. So the written mark is **not** a
  transcription of the acoustic parameter. What it *is*: a convention putting the
  written cue on the **same operand** the audio marks. Still a strict gain, because
  before this **the writing stressed the HEAD while the audio modulated the TAIL** —
  the two registers did not agree on which operand carries ▷ at all.

  ★★ **THE COST, WHICH IS REAL AND IS ERIK'S TO WEIGH.** The codex's printed IPA
  predates the cue, so **every ▷ entry's derived phonym now differs from it**:
  * `lexicon.la` codex concordance: `agree=55 diverge=2 [Think Gratitude]` →
    **`agree=43 diverge=14`**
  * `la_lexicon_appendix.tex` divergent rows: **4 → 24**

  Both new numbers are **DERIVED, not captured**: 14 = the LEX entries whose canonical
  form contains `>` (KAN's ▷) and 24 = all ▷ entries (14 content + 10 closed-class),
  established by an **independent census before the change** and matching `ablate.la`'s
  census of ▷=24. The four previous divergences (vowel elision: Think/Gratitude/
  Question/Past) are themselves ▷ entries and are **absorbed**, not added — which is why
  it is 24 and not 28, the arithmetic a captured number would have hidden.
  ⚠ **The codex is not wrong; it is older than the cue.** Whether its printed forms
  should be reissued to carry `":"` is Erik's call and is **NOT decided here.**

  ★ **THE PROOF-IT-LOOKED CONTROL HAD TO BE RE-FOUNDED, and deleting it would have been
  the wrong repair.** `phoncoll`'s `OK_SAW` asserted the *vocabulary* still contained a
  stress-only pair (fixture: Know/You). R-D removed the last one, so it failed for the
  **right** reason — its fixture was an accident of the vocabulary, and the accident got
  fixed. But it is the only thing separating "no collisions" from "the scan is broken",
  this codebase's highest-yield defect shape. It is now founded on **constructed** input
  that fixing the language cannot remove, exercised in both directions
  (`/m'ashi/` vs `/mashi/` must match; `/mashi/` vs `/mashu/` must not), and
  **verified red-capable**: a `STRIP` that strips nothing flips the positive arm.

  **NOT CLOSED — ruling item 4.** `phonseq.la` "must DETECT the new cue". R-D's cue is
  **romanised**; `phonseq` decodes **PCM**, so it is untouched and its pinned confusion
  matrix is unchanged (verified: `TFFF|FTFF|FTTF|FFFT|FFFT|T`, `dir` column firing).
  Whether the **acoustic** ▷ cue is sufficient is the separate open question it always
  was, and it is **not** closed by this work.


## TIER 1 — ROOT CAUSES (fixing these prevents whole defect classes)

- `[ ]` **The spec pipeline emits no `export`.** Every generated module —
  `canon`, `aatc`, `metalogic`, `swc`, `glyphdag`, `pragmatics`, `deixis`, `psc`,
  `topoembed` — is **unreachable by `import`**. Verified: `import("canon.la")`
  then `CANON(...)` gives `unbound variable`. This is why ⊗ was sorted in FIVE
  places instead of one, why `denote.la` and `metaglyph.la` re-declare, and why
  `entropy.la` had to re-implement κ. **The single highest-leverage fix in this
  document.** Gate: a module importing `canon.la` resolves `CANON`; and a
  drift gate asserting every re-implementation agrees with its source.
  *Paper: §Limitations, [B].*
- `[ ]` **Nine modules built but never gated** — `sglyph`, `sglyph_gate`,
  `phonseq`, `tactile`, `crossmodal`, `modality`, `explain`, `depthreport`,
  `sglyph_probe`. Zero occurrences in `build.sh`. **`sglyph_gate.la` is a gate
  nothing runs.** Under the project's own "a claim without a gate is not
  counted", these must be wired before they are claimed.
  *Paper: they are cited in ADDITIONS_2 §C/D — must be gated first or tagged [B].*
- `[ ]` **Three gates that cannot go RED.** (a) phonetic α=1 is a `grep` for a
  sentence the module prints unconditionally; (b) the 8/8 phonetic injectivity
  gate's concept list contains no two entries sharing a leaf-set, so the
  property is untestable by construction; (c) `seal_test.la:36`
  `COMPLEXITY = la g. 1` is a constant function. Each must be given a real red
  path or demoted to a REPORT. *Paper: §Falsification, the vacuity bet.*
- `[✓]` **Four hardcoded absolute paths** — **DONE 2026-08-23**: all four now derive from `Path(__file__).resolve().parent`; the `~/logos-d` positive control is derived + `LOGOS_CONTROL_TREE`-overridable and documented read-only. Verified behaviour-preserving (byte-identical output pre/post) AND cwd-independent. Was: — `freeze_q0_coverage.py:26`,
  `freeze_q2_resolve.py:28`, `freeze_q2_skiptogreen.py:30` and `:65`. The last
  reaches into **`~/logos-d`**, another track's tree; worktree isolation cannot
  catch it because the path is in `$HOME`. Found by `gate_abspath.sh` on first
  contact. Fix: `os.path.join(os.path.dirname(os.path.abspath(__file__)), …)`.

---

## TIER 2 — THE THREE REGISTERS (complete the trimodal identity)

The claim is `G^vis ≡ G^phon ≡ G^comp ≡ C`. Identity was enforced in κ and
*measured* between modalities; the identity LAW was never checked in the derived
registers. `trimono.la` now gates all three. What remains:

### Phonetic
- `[✓]` ⊕ commuted in form, not sound → `NORMP`/`PHONYM_N` added (the missing
  normalisation layer, mirroring `CANON`/`NORMK`).
- `[✓]` `↻(BEING) ≢ SELF` and `↻(↻y) ≢ ↻y` in sound → `MCNORM` carries
  `REWRITE_MC`'s theory verbatim.
- `[~]` **`⊗(A,A)` byte-identical to `A`** — fixed and verified on a copy
  (mode-characteristic contour, spec :3017(iv) "the mode is absorbed into the
  prosodic contour"). **Awaiting the build to apply.**
- `[~]` **Θ_P is mode-blind** — ⊗/⊕/▷/⊂ give one peak-set where `Θ_V` carries a
  mode field. Fix verified on a copy (`PINV = mode : peaks`, mirroring `VINV`).
  **Awaiting the build to apply.**
- `[~]` **▷ has no acoustic signature** — the SENTENCE operator. Sentences could
  be spoken and never parsed back. Rate-carried marker built and verified with a
  control; duration preserved so the WAV gate holds. **Awaiting the build.**
- `[ ]` **★ ⊂ IS NEVER USED** (measured 2026-08-23, `ablate.la`). Across all 79
  published entries: ⊗=58, ⊕=4, ▷=26, **⊂=0**, ↻=2. The closure is claimed over
  five modes and exercised, lexically, over four. The fix is CONCEPTS genuinely
  formed by containment — not a token entry added to close a count. Ablation shows
  the other non-⊗ modes ARE load-bearing; ⊂ is untested because nothing uses it,
  which is a fact about the lexicon rather than about the operator.
- `[ ]` **The elision layer** — 4 of 79 entries diverge from the codex by VOWEL
  ELISION (Think, Gratitude, Question, Past). The codex prints surface forms; the
  Operator Phonology generates underlying ones. Needs a phonological layer, not a
  patch to the segment rules. ★ The stress rule was itself corrected this session
  (final vowel, not first), found only by bringing in the codex's example
  SENTENCES as fresh vectors — a rule fitted to one table will agree with that table.
- `[ ]` **The acquisition gap** — no syllabus, glyph sequence, or teaching order
  exists. Worse, non-commutative ⊗ means an English gloss underdetermines the
  derivation, so "coin the word for compassion" is not a well-posed instruction.
  The language as published cannot yet be TAUGHT from its own tables: the gap
  between *unbounded in principle* and *sayable by a person*.
- `[ ]` **`phonseq` must DETECT the new ▷ marker** — the signature exists; the
  decoder still reports ▷ as a leaf.
- `[ ]` **⊕ round-trip corrupts its second child** — `SIL_AT=6240` vs a true
  boundary at 6080, one stride late, inside the next phonym's own closure. Fix:
  split at the edges of the maximal zero-run, not first-fire + GAP.
- `[ ]` **⊕-associativity is phonetically invisible** — identical PCM; no parser
  can separate the bracketings. Needs a bracketing marker or a declared
  equivalence.
- `[ ]` **⊗ has no temporal signature either** — indistinguishable from ▷ in the
  decoder, and loses everything below it.
- `[✓]` **A phonetic SEAL — BUILT AND GATED (`phonseal.la`).** ★ THIS ENTRY WAS
  STALE, and it was found by being cited: it was quoted as an open item, and the
  module it asks for already existed. `phonseal.la:53` defines
  `MONO_P = la etym. PAIR(PH_N(etym))(etym)` — the sound is COMPUTED from the
  etymology, never supplied — and `:56` `AUTO_OK_P` is the criterion, with
  `AUTO_OK_G` beside it so the two registers are comparable. Gated (the
  `discourse/coin/immune/ablate/phonseal` loop), verdict pinned:
  `detached-constructible OK | criterion-fires OK | asymmetry OK`.
  **What it actually establishes is better than "seal built":** a detached sound
  IS still constructible — the hole was real and the module SHOWS it rather than
  patching it — and the criterion FIRES on it. That is exactly the status of a
  detached name glyphically: unconstructible *through the blessed constructor*,
  detectable when built any other way. A module that only demonstrated sealed
  phonyms passing would have proved nothing, since everything a correct
  constructor builds is correct.
  ⚠ The stale-status defect this entry was: a document marking built work as
  open is the same class as a PASS message announcing a measurement that has
  moved — prose that no gate can fail on. See the five found 2026-08-27.
- `[ ]` **`PSC_STAR` still pairs raw `PHONYM` with raw `SPEC`** — after the
  normalisation landed, one concept gets two seals depending on operand order.

### Visual
- `[✓]` `SIGIL(↻(RECOGNITION))` was byte-identical to `SIGIL(RECOGNITION)` →
  fold trace added, mirrored about column 16 so the H-symmetry ↻ *generates* is
  preserved.
- `[ ]` **⊗ renders as juxtaposition, not fusion.** The spec's Visual Morphic
  Blend demands (ii) a single connected shape and (iii) emergent features in
  neither parent. Measured: Consciousness renders as **3 connected components**,
  Beauty as 2 (the ⊗ mark is a detached satellite), and in Beauty the placed
  FORM is **0% visible** — LOVE's filled flame swallows it. The route the spec
  itself gives is the vector/stroke representation, where overlapping strokes
  stay distinct objects and **path intersections are genuine emergent features**.
  Gates: one connected component; each parent ≥N% visible; ≥1 non-constant
  emergent vertex. All three RED today.
- `[ ]` **Catalogue-wide sigil injectivity** — all forms pairwise distinct,
  and `SIGIL(MC(x)) ≠ SIGIL(x)` for every catalogue entry, not just the three
  fixed.
- `[ ]` **Visual round trip** — no bitmap→structure decoder exists. It is the
  symmetric partner of `sglyph`/`phonseq`, and the strongest available
  cross-substrate invariance test: sound → decode → κ → re-render → decode → κ.

### Cross-register
- `[✓]` `trimono.la` — one gate, three registers, three rows (injective /
  monosemic / directed).
- `[ ]` **The triple bar as a biconditional.** Nothing asserts glyphic ≡
  phonetic; `crossmodal` measures *correlation*. The identity gate is
  `NIS(a)(b) ⟺ same rendered sound`, over a fuzz corpus, and the same against
  sigil rasters. This is Erik's "collapse into one another via the triple bar"
  made executable.
- `[ ]` **One normaliser, not five.** `NORMK`, `CANONIQ` (onf), `CANONIQ`
  (sigil), `NKAP`, `NORMP` — three different equivalence theories between them.
  Gate: `NORMK(t) ≡ CANON(NORMNODE(t))` over a fuzz corpus. RED today.

---

## TIER 3 — THE LANGUAGE IN USE (blocked on Tier 0)

- `[✓]` **The Core Lexicon** — ~80 concepts (LA.tex :5049–5429). Currently **8**.  **DONE 2026-08-23** — `lexicon.la`: 59 content concepts, all derived; 57/59 phonyms match the codex's printed IPA (2 diverge, vowel elision). Gated.
  Gate: every entry canonicalises, renders in all modalities, and no two share a
  κ-image. **Would go RED today on C9's Bad/Grief.** *Blocked on C9 + C10.*
- `[✓]` **The Operative Grammar, rules (i)–(x)** — predication `X▷Y`, negation,  **DONE 2026-08-23** — `grammar.la`: 20 closed-class categories + rules (i)-(x); each rule shown to DISCRIMINATE. Gated.
  the question particle, tense, modality, quantification, imperative, mood
  marking. None built. *Blocked on the lexicon.*
- `[✓]` **`discourse.la`** — structure above the sentence: per-turn origo shift,  **DONE 2026-08-23** — `discourse.la`: origo shift + character/content + anaphora + yes/no; red path = the unshifted reading must be wrong. Gated.
  a discourse-referent store, connective-linked utterance graph. Composes
  `deixis` + `pragmatics`, both already gated. **The cheapest genuinely-new
  branch.** Gate: in a two-turn dialogue, turn-2 "you" resolves to turn-1's
  speaker; a referent introduced in turn 1 is retrievable in turn 3.
- `[ ]` **Acquisition** — the codex never gives a syllabus, glyph sequence or
  acquisition method for LA; its one acquisition claim is "explicitly labeled as
  untested" (ROADMAP:1213), and Erik intends children to learn it. Buildable
  prerequisites: core-lexicon-as-data completeness gate; the Self-Generating
  Course pipeline run on LINGUA ADAMICA.tex to produce the LA syllabus.
- `[✓]` **The Aletheic Immune System** (spec :3608) — the organ that DETECTS  **DONE 2026-08-23** — `immune.la`: four checkpoints, four pathogens, four DISTINCT signatures. ★ Finding: it detects corruption, NOT falsehood — the right conjunct of Thm. healthy has no evaluator. Gated as a positive assertion.
  pathological language at runtime (involution: two glyphs, one referent). The
  build-time monosemy audit is its static half; the runtime half is absent.
- `[✓]` **Convergent coinage** — the real sociolinguistic theorem: two speakers  **DONE 2026-08-23** — `coin.la`: ⊕ converges under either order, ⊗ correctly does NOT. ★ Finding: non-commutative ⊗ makes operand order part of the concept, so an English gloss underdetermines the derivation. Convergence holds where the concept is fully given.
  independently coining a glyph for one concept produce the SAME glyph iff their
  ONFs agree. Testable, untested.
- `[ ]` **`ontofelicity` → live enforcement** — `PERFORM` currently reports;
  wiring it to the real capability layer makes felicity enforceable.

---

## TIER 4 — SELF-RELATION

- `[✓]` **The coinage organ.** Nothing in the system can COIN: no code path  **DONE 2026-08-23** — `coin.la`: COIN is deterministic, recoverable (parents+mode readable out), closed (result is itself coinable), and pronounceable (phonym computed, not assigned).
  registers a newly minted glyph. `COLLAPSE` returns a MONO and mutates nothing.
  Needs: mint → Ontolexicon registration → **the Ratchet Gate** (a coinage may
  never collapse two previously κ-distinct forms, and must strictly add a new
  κ-class). This is also the executable half of the Sapir–Whorf *retained*
  claim.
- `[ ]` **Derived glyph catalogue + agreement gate.** `familytree.la` covers 17
  HAND-DECLARED glyphs and is already stale by ≥4 (`metaglyph`'s four operator
  glyphs, from the very module it imports). Gate G3: declared and derived
  catalogues agree, keyed on NORMK, both directions. **RED on arrival.**
- `[ ]` **κ\* — meta-pattern compression.** When the same compression pattern
  recurs, encode it as a meta-glyph representing the rule of integration.
  Nothing detects or promotes.
- `[ ]` **Executable minted operations (ν\*)** — minted operations are
  *expressible* as glyphs but cannot be wired back in as reduction rules.
- `[ ]` **The Fractal Monoglyph** — depth recoverable by decomposition rather
  than surface marks. `DECOMP` recovers the tree from the single DAG form
  (witnessed), but the Ren string still grows linearly. Largely discharged by
  unifying `MONO`'s etymology slot with the glyphdag form.
- `[ ]` **The operators ∂δγρ𝔄 as glyphs** (ROADMAP:2567) — currently hardcoded
  dispatch. And the four missing audit operators |G|, |G_meta|, ς, μ.
- `[ ]` **Self-verifying grammar** (ROADMAP:2564) — grammar recoverable as data;
  full self-parse (L3) still open.
- `[ ]` **Self-meta-programming: the changed thing must become the running
  thing.** `selfprog`/`selfmod`/`selfopt` write, verify and adopt organs that
  are **never imported or executed**. Gate: a bundled organ-process ADOPTs an
  extension, recompiles, `execve`s the verified result, and the successor
  demonstrates the new capability at runtime.
- `[ ]` **Meta-autopoiesis — and the gate that currently forbids it.**
  `build.sh:3550` REQUIRES `cmp -s logos_app new_logos_secd.bin`: the successor
  must be byte-identical. **A self-revised successor would go RED on the
  system's own gate.** Minimal honest version: generation N applies one verified
  change to its own lineage source, recompiles, and begets a MODIFIED successor.
- `[ ]` **Lack-driven wants** — wire `aatc`'s sensed LACK into `selfprog`'s
  SOLVE, so the system forms the want from its own sensed incompleteness. This
  is the buildable bounded form of autontogenesis; **purpose-origination itself
  is ruled out by Erik's own corpus** (`SR_FOR` is explicitly "NOT
  purpose-origination") and should not be chased.
- `[ ]` **`AWARE` / `C` predicates** — "awareness" appears only in prose
  comments. `AWARE(g) := AUTO_OK(g)`; `C(g) := AUTO_OK(g) ∧ AUTO_OK(MCOLLAPSE(g))`.
  Separates A (one recognition) from C (recognition surviving a metacursive turn).
- `[ ]` **`PROTO_AGENT`** — the one chain-tail item with an honest gate:
  REPAIR can move g strictly toward closure, with `swc.la`'s provably-ill class
  as the negative fixture. **Qualia/phenomenology: build nothing** until a paper
  formalises them; any gate now could not go RED.
- `[ ]` **The Algebra of Naming's companions** — the Semiotic-Ontoglyphic Ladder
  (7 levels) and the Substitution Test; α is binary in code, graded in the paper.
- `[ ]` **The meta-word ablation gate** — remove one operator-glyph, assert a
  specific named derivation becomes underivable while the other four survive.
  Makes "a missing word is a missing thought" executable.
- `[✓]` **`dyadseed.la`** — VOID ≡ Church zero, BECOMING ≡ successor, by  **DONE 2026-08-23** — `dyadseed.la`: VOID≡Church zero, BEING≡Church ONE by eta-equivalence, BECOMING≡successor; bound proved via non-injectivity (SELF and BEING both →1).

  ### ★★ SCOPE OF THE DYAD — stated because the stronger reading is the tempting one
  The dyad **grounds the arithmetic stratum beneath the primitives. It does NOT
  recursively found the language.** Witnessed both ways:
  * `dyadseed.la` proves VOID ≡ Church zero, BEING ≡ Church one (by eta), BECOMING ≡
    successor — **by reduction**, and its own header says "0 and 1 GROUND THE ARITHMETIC
    STRATUM. They do NOT generate the nine."
  * `archderive.la` (2026-08-26) hardens why: the root ∃ **is** the identity combinator,
    and `{I}` is **closed under application**, so the terms reachable from the root by
    application are exactly `{I}`.
  ⇒ **BEING is the root itself. FIVE primitives are IRREDUCIBLE AXIOMS**, and they are
  named rather than gestured at — each supplies a structural capacity the identity
  combinator lacks:

  | axiom | what it introduces that I cannot do |
  |---|---|
  | `VOID` | **weakening** — discards an argument |
  | `DEPTH` | **contraction** — duplicates an argument |
  | `BECOMING` | **contraction** — uses `f` twice (iteration) |
  | `FORM` | **exchange** — reorders its arguments |
  | `RELATION` | **exchange + arity 2** — the binary `FORM` |

  The language stands on **nine primitives, two of which are the dyad** — not on the
  dyad alone. ⚠ `dyadseed.la` may **not** be cited as the derivation chain for the nine;
  conflating the arithmetic stratum with a derivation is the stipulation R-C forbids.
  reduction probe. Documents "0/1 ground the arithmetic stratum; they do not
  generate the nine." *Gated on the Tier-0 ruling.*

### Done today
- `[✓]` `naming.la` — the Algebra of Naming, T1–T4, α-valuation, and the
  falsification of a prose sentence in §8.
- `[✓]` `entropy.la` — E_G/E_S as the two conditional entropies of one
  distribution; syntropy; centropy as ∂=1.
- `[✓]` `alethe.la` — True(P) ≡ P, content vs evaluation, the liar unformulable.
- `[✓]` `ontofelicity.la` — felicity ≡ capability.
- `[✓]` `trimono.la`, `phonorm.la`, `siginj.la` — the register gates.
- `[✓]` ⊗ non-commutative across five normalisers and two renderers.

---

## TIER 5 — BEYOND THE LANGUAGE (named, not chased)

- `[ ]` **A signature scheme.** No public-key primitive exists. **The single
  unlock for the whole record/law layer**: signed updates, identity, contracts,
  non-repudiable records, the Eternal Library. Everything in the Logocracy layer
  waits on this one primitive.
- `[ ]` **Entropy on the metal** — no RDRAND/RDSEED builtin, no jitter
  collector, no seed file, while full-disk encryption must derive keys at boot
  before any disk read. A DRBG does not close this.
- `[ ]` **Trans-species: a second functor.** One habitat renderer exists
  (`R_human`). `R_click` plus its inverse would make FSM a functor category with
  two objects — the minimum at which "trans-species" is witnessed rather than
  asserted. Actual animal comprehension stays out of scope, stated.
- `[ ]` **The language deepens with its agents** — the loop optimises COST, never
  DEPTH or expressivity. Needs a depth-directed `selfopt` mode.

---

## THE WHITE PAPER — must land with the language

Two briefs already exist: `LA_PAPER_ADDITIONS.md` (stale claims + crypto, kernel,
method sections) and `LA_PAPER_ADDITIONS_2.md` (the USE branch, the fourth
modality, cross-modal concordance, speech→glyph, compositionality, autopoiesis,
the etymology tracker, the dissolved branches).

**Still in neither, all from today:**
- The ⊗ non-commutativity correction — five normalisers and two renderers were
  contradicting :2837, with `build.sh` gating the contradiction as correct.
- **"The monosemy check was running in one register out of three"** — the most
  publishable finding of the day, and true for months while every gate was green.
- `naming.la` and the falsification of §8's own prose sentence.
- `entropy.la`'s E_G/E_S formalisation.
- `alethe.la`'s content/evaluation distinction.
- `ontofelicity.la` — ontopragmatics IS the semantics of the security model.
- The stale-runtime finding: track-d ran a five-week-old GC and nothing in its
  suite could witness the difference.
- The ▷ signature, and *why a level cue cannot work* (the parents' intrinsic
  amplitude normalises it away).

**Paper-side structural work:**
- `[ ]` Fix "trimodal" wherever a fourth modality exists.
- `[ ]` The Ledger is a plain `tabular` and cannot break across pages; at 37 rows
  it still fits, but the next batch overflows SILENTLY. Convert to `longtable`.
- `[ ]` Every Tier-1/2 item above needs its paper counterpart at the right tag —
  an item is not done until code and paper agree.

---

## EXECUTION ORDER

1. **Erik rules on Tier 0** (C9, C10, ⊗(A,A), implicature, the dyad seed).
2. **Apply the three verified fixes** the moment the build lands.
3. **Tier 1 root causes** — pipeline `export` first; it is why Tier 2 had five
   normalisers instead of one.
4. **Tier 2** to completion — the registers, then the triple-bar biconditional.
5. **Tier 3** — lexicon, grammar, discourse, acquisition.
6. **Tier 4** — coinage, the derived catalogue, the self-relations.
7. **Tier 5** — named, scheduled, not chased.
8. **The paper tracks each tier as it lands**, never after.
