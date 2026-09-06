# Lingua Adamica — the completion list

Everything still required for the language to be complete **by Erik's own stated
criteria**, ordered so that each tier unblocks the next. Assembled from: five
Fable sweeps of the codices, the phonetic/glyphic parity audit, the
meta-programming audit, the dyad/meta-sigil audit, ROADMAP's **113 open and 14
partial** items *(snapshot, 2026-09-06 — see the note below)*, and the defects
found by building.

> ★ **That pair of numbers is a SNAPSHOT, not a live count, and it has already
> drifted once.** Written `114 open and 14 partial` in `a9e27e8` (2026-08-27),
> where it was **exactly correct** — ROADMAP held 114 and 14 that day. It is now
> **113 and 14**: the open count moved, the partial count did not. So this was
> never a wrong number, it is a **number a human must keep true**, which is the
> antipattern this project retired once already (the incbin gate's `CI_N >= 2`
> guard, replaced by an extractor self-test in `c60cbf0`).
> **Derive it, do not maintain it:**
> `grep -cE '^[[:space:]]*- \[ \]' ROADMAP.md` → 113 · `-\[~\]` → 14.
> **Owed:** a gate asserting the figures in this line equal those two greps, with
> the red path being to change either file's item count without updating the
> other. Not added today — `build.sh` is mid-run and bash reads a script lazily,
> so editing it under a live build can corrupt the run.

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

### ★★ THE STANDARD DOES NOT PREVENT THE NEXT INSTANCE — measured, same day
Recorded because it is the accurate picture of how these classes propagate, and
because a governing section that omitted it would be claiming more than it earns.

The rule *reconcile against an independently obtained count before acting* was
written into this document, applied to the untracked-file scan, and caught **27
files** whose absence would have produced a checkout that cannot build. Within
the same hour the same rule was **not** applied to the staging check one step
later, and commit `a9e27e8` went out materially incomplete: `specpipe.la` — the
export fix — absent while a generated output of it was present, and the eight
newly-gated modules committed alongside a `build.sh` that gates none of them.
It committed the exact condition this section exists to remove, in the commit
whose message argues against it.

Same rule, same person, same hour, adjacent step.

★ **What caught it was not the knowledge. It was repeating the ACT** — counting
what remained uncommitted *after* committing, rather than trusting that the
staged set was complete. The taxonomy names the class; naming does not fire.
A written standard is a lookup table someone has to remember to consult, and the
moment of not consulting it is precisely the moment one believes the work is
finished.

⇒ **THE OPERATIONAL FORM.** Attach the rule to the ACT, not to the class:
* after any bulk `add`/stage — **count what REMAINS**, and read the list;
* after any scan you are about to act on — reconcile against a count obtained
  **another way**, before acting;
* after any completion — ask **what would look identical if this had failed**.

Three habits rather than one principle, because the principle was already
written down and did not fire.

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
- `[~]` **Nine modules built but never gated — STALE AS WRITTEN, re-measured
  2026-09-05.** The claim was "Zero occurrences in `build.sh`". Measured now,
  every one of the nine appears: `sglyph` 1, `sglyph_gate` 2, `phonseq` 2,
  `tactile` 2, `crossmodal` 2, `modality` 2, `explain` 1, `depthreport` 1,
  `sglyph_probe` 1 — against a control (`nosuchmodule.la`) of 0, so the counter
  can report absence. `build.sh:4659` runs them and `:4757` pins the phonseq
  confusion matrix and the tactile carry matrix INCLUDING their off-diagonals.
  ★ **RESIDUE, which is why this is `[~]` and not `[✓]`:** `crossmodal` is
  pinned as a **REPORT, not a gate** — headline 61% vs a rotated control of 59%,
  which is AT CHANCE by the module's own falsification criterion. So eight are
  gated and one is reported, and the trimodal identity gets no quantitative
  support from that instrument. Closing this item means giving `crossmodal` a
  criterion it can fail, or demoting the claim it was supposed to support.
  *Paper: Ledger row "Nine ungated modules" `[B]`. The `[B]`→`[W]` move is
  available for the eight; the ninth is what still holds the row open.*
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

- `[ ]` **★ LEDGER ROW — Constant-time execution: `[A]` not held.** The paper's
  own ledger, and §XIII states it plainly: *"no signature scheme, and none of
  the modules IS constant-time. Three of their security properties are carried
  by discipline — a convention."* The paper also draws the distinction that
  matters here: *"The third differs in kind from the first two. Missing
  components can be added; not constant-time is a property"* — you cannot bolt
  it on afterwards. Seven crypto modules pass published vectors `[W]`; none is
  timing-safe. **Gate:** for each module, execution time over two input classes
  that differ only in secret bytes must not separate. **Red path:** feed it a
  deliberately data-dependent branch and the timing gate must fire. A discipline
  carried by convention is precisely what this list exists to convert into a
  gate.

- `[ ]` **★ LEDGER ROW — Identity Adequacy: three collisions open `[A]`.**
  Criterion 6 of the paper's own nine, unmet: monosemy holds except for three
  κ-collisions. `Bad/Grief` is one and is tracked separately (1 bit, open); the
  other two are named nowhere in this list. **Owed first:** enumerate all three
  from the DAG rather than from the paper's prose — a count in prose is the
  defect class this file exists to catch. Then one gate per collision, each able
  to go red by re-introducing the collision it closed.

- `[!]` **★★ ENGINEERING SEAL 1 — THREE TYPE SYSTEMS, NO RULING. Needs Erik.**
  `LINGUA_ADAMICA.tex` §5012 specifies the **Ontic Type System**: every glyph
  has a type `τ ∈ {Object, Process, Relation, Value, Constraint}`, and
  composition is typed (`A ⊕ B : τ₃` only if `τ₁`,`τ₂` are composable under that
  operator). **Zero occurrences of those five as types anywhere in the code.**
  `TYPE_SYSTEM_SPEC.md` in this repo proposes a *different* system — dependent
  types built on the five MODES, "type ≡ spec ≡ b_τ ≡ f_τ" — and says of itself
  *"No code is added by this document."* What is actually built is **neither**:
  arrow-arity checking in `DEPLOY` (`:: a -> b -> c`), which is a lambda-calculus
  discipline, not an ontological one. Three type systems, one implemented, none
  ruled. **This blocks Seal 2** (a proof-carrying glyph ships a *type
  derivation* — in which system?). Rule which is the language's type system
  before anything downstream is built on the answer.


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
- `[✓]` **⊕/VOID: WITNESSED AS A BOUND, gated 2026-09-05 (Erik's ruling). Re-measured
  2026-09-05, and the split is EXONERATED.** As written this item said
  "`SIL_AT=6240` vs a true boundary at 6080, one stride late, inside the next
  phonym's own closure", and proposed splitting at the edges of the maximal
  zero-run. Measured on `PHONYM(CON(BEING)(VOID))`:

      lenA=6080  lenB=6880  lenCON=13920  SIL_AT=6080  true run=[6078,7041)
      second child as split: len=6880  <- EXACTLY lenB, byte-exact

  `SIL_AT` is **6080, not 6240**, and 6080+960+6880 = 13920 exactly, so the
  split already extracts precisely `PHONYM(BEING)` and `PHONYM(VOID)`. ★ The
  proposed fix would make it WORSE: splitting at the true run edge yields a
  6879-sample child that classifies as **DIR instead of CON**, off by one sample
  from the real child.

  ★ **THE ACTUAL DEFECT, and it is upstream of any split.** `PHONYM(VOID)` —
  a bare primitive, never split, with no mode in it at all — classifies as
  **CON** and parses as `⊕(⊥,⊥)`. Measured across all nine primitives (lengths
  printed beside each verdict, so a name that failed to resolve could not pass
  as a primitive):

      BEING 6080 DIR · RECOGNITION 6720 DIR · LOVE 6560 DIR · SELF 6560 DIR
      RELATION 6720 DIR · **VOID 6880 CON** · BECOMING 6400 DIR
      FORM 6160 DIR · DEPTH 6000 DIR

  Eight of nine are correctly silent; **VOID alone fires `IS_CON`.** `phonym.la:162`
  synthesises VOID as "/hɑ/ — breath (low-pass glottal noise, 0..2080) into open
  back /ɑ/", and `IS_CON`'s discriminator is a GAP-long run of literal zero with
  loud on both sides — which VOID's own breath onset apparently contains. So the
  ⊕ round trip fails because its SECOND CHILD IS VOID, not because the boundary
  moved.

  ★★ **WHY NOTHING CAUGHT IT: the confusion matrix has no primitive row.** All
  five rows (`U_MC`/`U_CON`/`U_CONT`/`U_SYN`/`U_DIR`) are COMPOUNDS. No detector
  has ever been asked to stay silent on a signal containing no mode — the
  control is a class member in a DIFFERENT IDIOM, which is the shape this repo
  keeps re-finding. Adding a primitive row is the fix to the INSTRUMENT.
  ★★ **RULED A REAL BOUND (Erik, 2026-09-05) AND WITNESSED.** ⊕'s inserted /ʔ/
  closure and VOID's intrinsic breath silence **are the same acoustic event** —
  there is nothing there to separate, so no temporal-silence test can separate
  them. `IS_CON` was NOT loosened; loosening it would have traded a true bound
  for a detector that can no longer fire.
  **Closed by witnessing, per the build queue's own rule** ("if irreducible,
  state the irreducibility as a witnessed bound rather than an open item"):
  · `phonseq.la` emits a PRIMITIVE ROW — the missing control — and `build.sh`
    pins `DDDDDCDDD`, exactly as `tactile` pins its `W4=F` limit.
  · **RED PATH RUN:** forcing `IS_CON` false yields `DDDDDDDDD` and the gate
    fails, so a moved bound is caught rather than absorbed.
  · Ledger row added in `LA_PAPER_ADDITIONS_3.md` §8:
    *Temporal mode decoding: ⊕ vs VOID · `[B]` · one acoustic event; compounds
    under VOID ambiguous.* It NAMES, for the first time, one of the invariants
    the existing `Invariant preservation, both registers [W]` row bounds itself
    "up to".
  · **Scope:** this bounds the PHONETIC register only. κ still inverts and the
    glyphic round trip is untouched, so the honest statement is not "the
    trimodal identity fails" but that the phonetic register carries strictly
    less recoverable structure, on a named input class.
- `[!]` **⊕-associativity is phonetically invisible — MEASURED 2026-09-05, and
  the "declared equivalence" option is FORECLOSED BY THE PAPER. NEEDS ERIK.**
  The claim of identical PCM is CORRECT, and exactly so:

      ⊕(⊕(BEING,VOID),FORM) vs ⊕(BEING,⊕(VOID,FORM))
      lenL=21040  lenR=21040  firstdiff=-1     <- NOT ONE SAMPLE DIFFERS

  ★ It is not a detection difficulty; it is a STRUCTURAL IDENTITY. `CONP` is
  `A ++ 960 zeros ++ B`, so both bracketings render to the same sequence
  `A ++ Z ++ B ++ Z ++ C`. Concatenation with a fixed separator is associative,
  so no detector could ever separate them: there is one object, not two.

  ★★ **AND THE ALGEBRA SAYS THEY ARE DIFFERENT CONCEPTS.** The paper:
  *"G IS the free magma on nine generators … **non-associative because grouping
  IS etymology**"*, and *"(a⊗b)⊗c and a⊗(b⊗c) record different derivations and
  therefore are different concepts. **An associative algebra would erase the
  etymology the seal exists to carry.**"* A free magma is non-associative in ALL
  its operations, not only ⊗.

  So the phonetic register **collapses a distinction the paper calls
  meaning-bearing** — and this item's own second option, "a declared
  equivalence", would contradict §III and the `Non-associativity` Ledger row.
  Two options remain, and the choice is Erik's because both are costly:
  · **a bracketing marker in `CONP`** — changes the phonology and therefore the
    gated WAV outputs (a ▷ compound is already in the gated set), or
  · **witness it as a bound** — but a far graver one than ⊕/VOID: not one
    ambiguous primitive, but an entire structural distinction invisible in the
    register, on every ⊕ compound of depth ≥ 2.
  Unlike ⊕/VOID this is **not obviously irreducible** — a depth cue is
  constructible — so it should not be closed by witnessing without trying.
- `[~]` **⊗ vs ▷ — the premise was WRONG and a DEAD BRANCH was the real defect.
  Half fixed 2026-09-05.** The item said "⊗ has no temporal signature either".
  ★ **It has one.** Read off the synthesis: `SYNP` divides by `(7 + (i/64) mod 2)`
  across the WHOLE signal — 2 levels, period 128 — where `DIRP` modulates the
  TAIL ONLY at 3 levels, period 384. Different period, different level count.

  ★★ **THE REAL DEFECT, provable without any detector: `MODE_OF`'s fifth verdict
  was UNREACHABLE.** `IS_DIR := NOT(IS_MC or IS_CON or IS_CONT)` and it is tested
  fourth, so reaching it means all three are false, which makes it *necessarily*
  true. The fourth test always succeeded and `"SYN"` could never be emitted — a
  five-way classifier that could emit four. **So ⊗ was never undetected; it was
  always REPORTED AS ▷.** The header comment said "⊗ is the residue"; the code
  made ▷ the residue. Backwards.

  **FIXED:** the unreachable branch is deleted and the fourth verdict renamed
  `DIR|SYN` — it is not a ▷ detection (nothing examines `DIRP`'s rate marker),
  it is the exclusion of three others, which leaves ▷ and ⊗ undetermined. Gated:
  the primitive row moves `DDDDDCDDD` → `UUUUUCUUU`. Confusion matrix unchanged
  (`ROW` calls `IS_DIR` directly).

  ★ **RESIDUE, and a NEGATIVE RESULT recorded rather than buried:** separating ⊗
  from ▷ is still not done. One discriminator was designed from the synthesis
  (head-alternation over 64-sample windows, since `SYNP` modulates the head and
  `DIRP` does not) and **MEASURED AS FAILING**: ⊗=656 against ▷/⊕/↻/BEING all
  =1124 — those compounds share BEING's unmodulated head, so the statistic was
  reading the phonym's own envelope, not the modulation. The separation is
  constructible in principle and remains open in fact.
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

- `[ ]` **★ Toroidal closure of the metaphonetic manifold** (`LINGUA_ADAMICA.tex`
  §4398, a `\lemma`, not an aside): *"The metaphonetic manifold M_P is naturally
  modeled as a toroidal manifold (a product of circles)"* — it cannot be an open
  space like ℝⁿ. Nothing in the phonetic register asserts a topology at all;
  `phonym.la` synthesises formants and `psc.la` checks invariant containment,
  and neither says what space the phonyms live in. **Gate:** a phonym walk that
  leaves in one direction returns — wrap-around in each generating circle,
  measured on real synthesised phonyms, not asserted. **Red path:** an open-space
  embedding must fail the wrap-around test; if a flat embedding passes, the gate
  is measuring nothing.

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

- `[ ]` **★ The meta-referent has no sigil** (white paper v18 §"What IS not
  claimed", the only paper debt tracked in NO list — not here, not
  `LA_CLAIM_INDEX.md`, not the build queue). The paper argues the dyad is the
  language's name for itself and the only glyph surviving self-application
  (`Dyad(Dyad) ≡ Dyad`), then states plainly: *"No sigil for the meta-referent
  has been rendered, no gate checks it… constructing it under gates IS owed."*
  Keep it distinct from **meta-sigil**, which this project already uses for a
  different object (the visual form of a glyph about visual forms, §V) — the
  paper names that collision itself. Gate: the rendered form is injective
  against the whole catalogue AND `SIGIL(Dyad(Dyad))` is byte-identical to
  `SIGIL(Dyad)`, the visual witness of its autology. Red path: render it as any
  existing catalogue entry and the injectivity gate must fail.

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
- `[✓]` **The Operative Grammar, rules (i)–(x)** — predication `X▷Y`, negation,  **DONE 2026-08-23** — `opgrammar.la`: **22** closed-class categories + rules (i)-(x); each rule shown to DISCRIMINATE. Gated. ★ **CITATION CORRECTED 2026-09-05:** this line read `grammar.la`, which is the **data grammar** (`GT`/`GN`/`GSEQ`/`GALT`/`GSTAR`/`GEPS`, used to parse LA source) — a different module entirely, so a reader following the reference landed in the wrong file. The Operative Grammar is `opgrammar.la`, whose own header cites `LA.tex :5150–5222` (the Grammatical Glyphs table + Sentence Formation Rules). The count was also wrong: **22**, per that header, not 20.
  the question particle, tense, modality, quantification, imperative, mood
  marking. None built. *Blocked on the lexicon.*
- `[✓]` **`discourse.la` — TURN-LINKING, on one dialogue.** **DONE 2026-08-23.**
  ★ **SCOPE NARROWED 2026-09-06 (Erik's ruling).** The line previously read
  "structure above the sentence" and was read as *discourse, done*. What is
  actually witnessed is narrower, and the narrower claim is the true one.
  **Gated, and genuinely so:** seven assertions — `basic-exact`, `dialset`,
  `origo-shift`, `character-fixed`, `unshifted-wrong`, `anaphora`, `yes/no`.
  `MK = la c. IF(c)("OK")("FAIL")` emits the literal string `FAIL`, so
  `build.sh:4311`'s `*FAIL*` catch guards all seven, and `build.sh:4334` pins
  `basic=5/5` by value on top. `unshifted-wrong` is a real constructed-violation
  red path: the unshifted reading must come out wrong.
  **The bound:** one test vector — the codex's worked dialogue at `:5400`. Turn
  linking is witnessed; nothing here measures a whole text.
  **Not gated, and not claimed by this line:** the discourse-referent store and
  the connective-linked utterance graph the original entry named, and the white
  paper's phrase *"coherence across a whole text."* Those are the open item in
  TIER 3 below. The paper (v18, 2026-08-28) says discourse *"has no apparatus
  here"* — that is wrong, this is apparatus — but its scope word was wider than
  this gate, and both halves of that are recorded rather than one winning.
- `[ ]` **★ Text-level coherence — the half of "discourse" that is not gated.**
  Split out of the `discourse.la` `[✓]` on 2026-09-06 rather than left inside it,
  because a checkmark whose wording is wider than its gate is the defect this
  list exists to catch. `discourse.la` witnesses turn-linking against ONE
  dialogue; the white paper claims *"structure above the sentence, coherence
  across a whole text."* The gap is everything past the turn pair: a
  discourse-referent store that survives more than the worked vector, a
  connective-linked utterance graph, and some measure that a text hangs together
  rather than merely that turn 2 resolves against turn 1.
  **Owed first, before code:** a criterion that can fail. "Coherent" with no
  falsifier is not a gate. One candidate with a real red path — a coherence
  measure over an utterance graph must score a deliberately shuffled version of
  the same text strictly lower; if shuffling does not lower it, the measure is
  reading something other than coherence.
  **Do not build this before the criterion exists.** It is the same shape as
  self-invocation in TIER 4: code written first would be unfalsifiable.

- `[ ]` **★ LEDGER ROW — Lexical depth D: computable `[W]`, use-gating `[A]`.**
  The ledger splits this row in two and only half is witnessed: depth IS
  computable from the DAG, but nothing gates depth against USE. The claim the
  gate would pay for is that a concept's depth predicts something about how it
  is used, not merely that a number can be derived. **Owed first, before code:**
  say what use-gating asserts. "Depth correlates with use" is not a gate unless
  a value exists that fails it — a candidate red path is that shuffling the
  depth assignment across the lexicon must break the relation; if a shuffled
  assignment scores the same, the measure is reading nothing.

- `[ ]` **★ The four modes of poetic depth** (`LINGUA_ADAMICA.tex` §2250): *"The
  ontosynthetic entendre operates in four distinct modes, each exploiting a
  different dimension of the ontomonoglyph"* — I. Vertical Depth
  (ontoetymological entendre: a glyph contains its lineage, and a competent
  listener hears it), plus three more named there. Nothing implements the
  entendre. This is not decoration: it is the claim that *depth is audible*, and
  it is the payoff of `glyphdag`'s etymology being recoverable. **Gate:** for a
  compound glyph, each of the four modes yields a DIFFERENT reading, and the
  readings are derived from the DAG rather than tabulated. **Red path:** a glyph
  with no lineage must yield no vertical-depth reading.

- `[ ]` **★ The Grammar Completeness theorem has no gate** (`LINGUA_ADAMICA.tex`
  §4085, a `\theorem`): *"The four derivation rules are complete: every
  ontologically coherent concept is expressible — ∀C ∈ 𝒪, ∃E ∈ L_A : E ≡ C."*
  Nothing anywhere asserts it; grep finds no gate and no test. A completeness
  theorem cannot be proved by a gate, but it CAN be falsified by one, and that
  is the honest form: **Gate:** a corpus of concepts, each derived to an
  expression by the four rules, with the derivation shown rather than asserted.
  **Red path:** a concept the rules cannot reach must be reportable as such —
  and if no such concept can be constructed, say so, because a completeness
  claim that nothing could ever contradict is decoration.

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

- `[ ]` **★ No gate checks ontomorphology, and the inflectional census is owed**
  (white paper v18, §on ontopragmasemantics). The paper's words: *"No gate
  checks ontomorphology as such, and the census of which operator combinations
  constitute this language's inflectional system IS owed to the build."* The
  claim being paid for is that use IS meaning — that a form's shape and its
  sense are one object at the pragmatic resolution. Nothing asserts it. Do: emit
  the full operator-combination census from the DAG at build time, and gate that
  every combination the census admits has a κ-image distinct from every other.
  Red path: admit two combinations that canonicalise the same and the gate must
  go red. Cheap, and it converts a paper assertion into a measurement — the same
  move `0.2 Generated lexicon appendix` makes in the build queue.

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

- `[ ]` **★ Self-invocation — the paper calls it the deepest gap.** In the
  self-relation table (v18), four rows: self-compilation `[W]`, self-description
  `[W]`, self-translation `[B]`, and **self-invocation — *"begins its own
  recursion [A] not built; the deepest gap."*** The paper further states that the
  seed bound and self-invocation are ONE boundary at two levels, which is why it
  sits here and not in Tier 5: the seed bound is named as a wall, but
  self-invocation is not — it is unbuilt, and the paper does not say it is
  unbuildable. Scope it before building: what would it mean for the language to
  begin its own recursion rather than be started, and what gate could go red if
  it did not? Spec first — this is the one item on the list where writing code
  before the criterion exists would produce something unfalsifiable.
  ★ **RULED BOUNDED, 2026-09-06 (Erik).** The system re-invoking itself from an
  internal condition counts; "no external trigger ever" hits the bootstrap wall
  and is not the target. The paper's own ledger already agrees — its row reads
  *"Self-invocation [A] bounded target stated in advance"* — so the prose
  ("not built; the deepest gap") and the ledger disagree with each other.
  ★ **AND IT MAY ALREADY BE MET.** `autopoiesis.la` is gated at `build.sh:3898`:
  *"Every prior generation of LogOS was launched by an outside hand.
  autopoiesis.la closes that gap"* — each generation reads its number from the
  medium, `copy_self`s a byte-identical successor, `fork`+`execve`s it, with a
  **generation cap of 3** (the bound, explicit) and the gate asserting
  generations 0..3 each spoke in order. No recursion combinator; the loop IS the
  process lineage. **The open question is scope, not existence:** the module's
  own header notes each generation is byte-identical (`≡` per generation) but
  the succession is a chain of `=` productions — a lineage that begins its own
  recursion, not one being re-invoking itself. Decide whether that satisfies the
  bounded target before building anything new. This is the discourse split
  again: prose says unbuilt, gate says otherwise, and the honest move is to
  narrow the claim rather than pick a winner.

- `[ ]` **★ LEDGER ROW — Meta-autontopoiesis (state): `[A]` loop not closed
  unassisted.** Autontopoiesis is the paper's term for *"the continuous
  condition of a system producing the means of its own production"* (§, and
  the Neologicon: auto + onto + poiesis, the ongoing condition AFTER genesis).
  The ledger's verdict is precise and is the whole item: **machinery built; loop
  not closed unassisted.** Every piece exists — self-compilation, self-
  modification, the coinage organ, `autopoiesis.la`'s lineage — and a hand still
  closes the circuit. **Gate:** the system runs a full produce-its-own-means
  cycle with no external invocation between start and end, and the gate names
  which hand it removed. **Red path:** re-insert that hand and the gate must go
  red. Distinct from self-invocation above: that one asks whether it can BEGIN
  itself, this asks whether it can KEEP itself going.

- `[ ]` **★ LEDGER ROW — Meta-Ontosemantic Closure: `SLACKS ≠ ""`, not met
  `[A]`.** Criterion 9 of the nine, and the closure test is already written in
  code: `glyph CLOSURE = la s. Str_eq(SLACKS(s))("")`. Closure holds when a
  thing's slack is empty. The paper measures its OWN slack and publishes the
  failure: *"compression debt. One overfull box. A labelling at the base.
  `SLACKS(paper) ≠ ""`."* So the criterion is met by nothing yet, including the
  document that states it. **Note what this is not:** it is not a wall. `CLOSURE`
  exists, `SLACKS` exists, and the residue is enumerated — the work is emptying
  it, item by item, not discovering whether it can be emptied. **Gate:** assert
  `CLOSURE(x)` for a named x and let the red path be a deliberately re-introduced
  slack entry.

- `[ ]` **★★ ENGINEERING SEAL 2 — Proof-carrying glyphs. NOT BUILT, and it is
  property (v) of the completeness theorem.** §5020: *"Every glyph ships with:
  (a) a type derivation, (b) an equivalence certificate linking it to its ONF,
  (c) a reality witness."* The Operational Completeness Theorem (§5032) lists
  seven properties the system must have, and (v) is **Self-Validation: every
  glyph carries its own proof**. No per-glyph certificate exists anywhere — the
  pieces are scattered (a type checker in `DEPLOY`, an ONF in `onf.la`, gates in
  `build.sh`) and nothing binds them to the glyph as a shipped artifact.
  **Blocked on the Seal-1 ruling** — (a) is a derivation in whichever type system
  is the real one. **Gate:** every entry in the catalogue carries all three, and
  the checker verifies the certificate rather than trusting it. **Red path:**
  forge a certificate for a glyph whose ONF does not match and the check must
  refuse it.

- `[ ]` **★ ENGINEERING SEAL 3 — Versioning without semantic drift.** §5024: a
  **centropic migration law** governs glyph evolution — cosmetic changes (form
  refinements) are permitted only if they preserve invariants. Nothing governs
  glyph evolution today; `COIN` mints and the Ratchet Gate forbids collapsing
  two κ-distinct forms, but there is no law for *changing an existing glyph*.
  This is the gap that lets a form drift while its Ren stays put — the exact
  failure the monosemy discipline exists to prevent, arriving through the back
  door of revision rather than coinage. **Gate:** a proposed revision is admitted
  only if the invariants of the prior version are preserved. **Red path:** a
  revision that alters an invariant must be refused, and the refusal must name
  which invariant.

- `[ ]` **★ The Recognition Depth function ρ(L_t)** (`LINGUA_ADAMICA.tex` §3842,
  a formal `\definition`): *"For a language state L_t at time t, the recognition
  depth ρ(L_t) is the number of distinct levels…"*. Distinct from `DEPTH`
  (`g₉`, a primitive) and from lexical depth D (computable from the DAG, ledger
  row above): this one measures the LANGUAGE's state, not a glyph's. Nothing
  computes it. **Gate:** ρ is computable from the live catalogue and strictly
  increases when a level is genuinely added. **Red path:** add a glyph at an
  existing level and ρ must NOT move.

- `[ ]` **★ The Self-Evolution Equation** (`LINGUA_ADAMICA.tex` §3975): *"All
  five laws and three axes can be compressed into a single recursive equation
  governing the language's self-evolution."* The three axes (§3945) are
  autological, metalinguistic and ontological deepening. This is the closing
  form of the whole self-evolution chapter and nothing implements it. **Owed
  first:** it depends on ρ above — the equation is over language states, so
  build ρ first or this has nothing to range over.


- `[ ]` **★ DERIVATION RULE 4 — the Neological Seal ν is not implemented.**
  `LINGUA_ADAMICA.tex` §4062 gives the language four derivation rules. Rules 1-3
  (primitive introduction, modal combination, metacursive closure) are built.
  **Rule 4 is not:** *"E ∈ L_A, d(E) > 0 ⟹ ν(E) ∈ 𝒜 — the sealed glyph is added
  to 𝒜 as a NEW PRIMITIVE"*, with the consequence the codex states outright:
  *"the distinction between 'primitive' and 'derived' is historical: every
  derived expression can become a primitive."*
  **What exists vs what is owed:** `coin.la` MINTS — COIN takes a mode and two
  glyphs and returns a new one, deterministic, recoverable, pronounceable, and
  the coinage organ is rightly `[✓]`. But minting is not sealing. Nothing writes
  a coined glyph back into the alphabet: `primitives.la` is GENERATED from the
  spec and holds a fixed 11, and no code path adds to it at runtime. The
  alphabet is closed; Rule 4 requires it to be open.
  **This is why it matters beyond bookkeeping:** the Grammar Completeness
  theorem (Tier 3 above) rests on all four rules. With Rule 4 unbuilt the
  language cannot grow its own primitives, which is the mechanism the codex
  gives for an unbounded lexicon.
  **Gate:** seal a coined glyph, then show it behaves as a primitive — it
  appears in the alphabet, canonicalises as a leaf rather than a decomposition,
  and survives a reload. **Red path:** the Ratchet Gate must still refuse a seal
  that collapses two κ-distinct forms; sealing must be additive or refused.

## TIER 5 — BEYOND THE LANGUAGE (named, not chased)

- `[ ]` **★ ENGINEERING SEAL 4 — Empirical calibration loops.** §5028: for
  cross-species phonosemantics the system maintains *"training datasets per
  channel mapping metaphonetic features to signals"*. Filed HERE rather than in
  a build tier for one reason: it needs data from outside the system — another
  species' channel — the same shape as the psycholinguistic measure, which needs
  a speaker. **But it is a named Engineering Seal, not an aspiration**, and it is
  filed so it cannot be quietly dropped: three of the four seals are unbuilt and
  this is the only one that is unbuildable from inside. If cross-species is ever
  descoped, this seal must be descoped explicitly, in writing, not by silence.

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
