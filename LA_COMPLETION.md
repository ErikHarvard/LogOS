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

### A THIRD ROT: a module's comment claiming another file is canonical — 2026-09-08
The two axes above are about instruments reading their subjects. This one is a
subject **asserting its own provenance** and being believed.

`denote.la`'s primitive block is headed *"the nine primitive MEANINGS (the closed
algebra; **canonical in primitives.la**)"*. That comment is a claim of
derivation — this copy tracks that file — and **nothing checked it**. It had
drifted: after LOVE was ruled back to the codex's unary generator
`Love(x) ≡ (x, new(x))`, `denote.la:41` still defined the retracted **binary**
symmetrisation, and `:78 LOOKUP` maps the *name* `"LOVE"` to it. So `denote.la`
was **denoting a concept the rest of the arc had retracted** — code disagreeing
with code, inside a single change, with no gate on either side of it.

★ **IT WAS FOUND BY RED-PATHING, NOT BY READING — and only because one planted
defect refused to go red.** Five `D_CON` defects were planted. Four crash the
module, so they prove nothing about coverage. The fifth, `D_CON = LOVE(a)(b)`
(the pre-realignment spelling), left all three witnesses **byte-identical** with
a clean exit. **It was silent because it was still TRUE:** that spelling was
still literally the old symmetrisation, sitting at line 41. A silent red path is
not a weak test result — it is a pointer at the thing the test cannot see.

★★ **THE MEASURED CHAIN, and the middle step is the load-bearing one:**

| witnesses | on the silent defect |
|---|---|
| 3 (⊗, ↻, nested-⊗) | **GREEN** |
| 4 (`W_CON` added — ⊕'s own denotation) | **STILL GREEN** |
| 5 (`W_LOVE` + the realignment) | **RED** |

**`W_CON` alone would not have caught it.** Recorded explicitly because the
obvious reading — "the changed line was uncovered, so cover the changed line" —
produces `W_CON` and stops, and `W_CON` does not close this. What closes it is
`W_LOVE`, which re-asks `primitives_spec.la`'s **own three LOVE tests** of
`denote.la`'s `LOOKUP`: the two modules can no longer disagree without a gate
going red. A copy that declares itself canonical-elsewhere must be **tested
against that elsewhere**, not merely annotated with it.

⚠ **The rule this yields:** a comment naming another file as the source of truth
is an **absence-claim about drift**, and by this document's own standard it must
be able to show it looked. Grep the corpus for such claims; each one either gets
a differential against the file it names, or the comment is a decoration.
(Audited the same day: `denote.la` was the only module binding the retracted
form — `dyadseed.la` and `archderive.la` copy the primitive block but define no
`LOVE`.)

★★ **THE RULE FOUND A SECOND INSTANCE THE SAME HOUR — measured, not suspected.**
Grepping the corpus for source-of-truth claims returned two more:

* `phonym.la:355` — *"THE REWRITES, IN VERBATIM PARITY WITH canon.la's
  REWRITE_MC"*. **HOLDS**: `NORMP` and `NORMK` agree on all 15 probes.
* `onf.la:46` — *"κ + canonicalization (verbatim parity with canon.la NORMK /
  sigil.la CANONIQ)"*. **HALF FALSE.** Parity with `sigil.la`'s `CANONIQ` holds
  (identical on all 15). Parity with `canon.la`'s `NORMK` **does not**, on the
  whole metacursion-fixed-point family.

  > ⚠⚠ **READ THIS BEFORE TOUCHING ITEM 2. `canon.la` IS THE FILE THAT IS
  > WRONG HERE, NOT THE OTHER FOUR.** The obvious execution — *"canon.la is
  > canonical, make the others match"* — pushes an **over-collapse** into the
  > visual and acoustic registers, which currently have the codex's behaviour
  > RIGHT. `onf.la`/`sigil.la` are not behind; `NORMK` is not ahead. Anyone
  > working from a one-line summary of this item would do the wrong thing at
  > speed, and it would look like progress. Build the one normaliser **arm by
  > arm from the declared theory, each arm carrying its citation** — see the
  > attribution below.
  >
  > ⚠⚠ **AND THE MECHANISM ITSELF IS A SEPARATE, LARGER DIVERGENCE** — only one
  > of the two is about `↻`. "Assemble the normaliser arm by arm from the
  > declared theory" is the right execution only if **a rewrite set is the right
  > mechanism, and the codex says it is not** (*The mechanism divergence*,
  > below). That makes the naive execution worse, not better: hand-declaring
  > more equivalences moves further from the spec, however well each is cited.

  | probe | `canon.la` NORMK | `onf.la` CANONIQ |
  |---|---|---|
  | `↻(↻(LOVE))` | `↻(LOVE)` | `↻(↻(LOVE))` |
  | `↻(▷(DEPTH,RECOGNITION))` = ↻(𝓡) | `▷(DEPTH,RECOGNITION)` | `↻(▷(DEPTH,RECOGNITION))` |
  | `↻(⊕(SELF,SELF))` | `⊕(SELF,SELF)` | `↻(⊕(SELF,SELF))` |
  | `↻(↻(↻(VOID)))` | `↻(VOID)` | `↻(↻(↻(VOID)))` |

  `NORMK`'s `REWRITE_MC` carries three fixed points (`↻`-prefix idempotence,
  `↻(𝓡) → 𝓡`, `⊕(SELF,SELF)`) that `onf.la` and `sigil.la` never had. So κ and
  the phonology call `↻(↻(LOVE))` and `↻(LOVE)` **one concept**, while the
  visual register renders them as **two different sigils** — two forms, one
  concept. That is polysemy through the visual door: **the identical failure
  `onf.la`'s own R-A comment records having been caught once already for
  `⊗(A,A)`, one rewrite family later.**

  Closing it is **item 2 (One normaliser, not five)**, not this change; recorded
  here with the measurement so the item starts from a witnessed divergence
  rather than from the claim that one exists. `NKAP` (`entropy.la`) is a third
  theory again — no Archē `⊗` collapse and no `↻(BEING) → SELF` at all.

★★ **AND THE CODEX SETTLES WHICH SIDE IS WRONG — AGAINST THE ONE NAMED
"CANONICAL".** Checked against `LINGUA_ADAMICA.tex` itself, not against the
comment claiming parity with it:

* **`:4810`** — `↻(g_∃) ≡ Being² ≡ Being`, and the phonym is **unchanged**:
  *"The pronunciation does not change: /ɑ/ spoken once is the same as /ɑ/ spoken
  to itself."* So `↻(Being)` genuinely collapses, in both registers.
* **But every OTHER `↻` entry the codex spells out REDUPLICATES**, and is a
  distinct concept with a distinct name: `↻(g_Rec)` = **Truth** = `/ʃiʃi/`
  (`:4810`); `↻(g_7)` = **Ongoing** = `/vuvu/`; `↻(g_6)` = **No/None** =
  `/hɒhɒ/` (`:5176`).
  *Transcription, because it survives into a formant target and thence into
  `goertzel.la`'s spectral oracle:* Void's macro is `\textturnscripta` = **ɒ**,
  open back **rounded** (`:4728`, `:5070`, `:5176`; the prose says "open back
  vowel"), so Void is `/hɒ/` and None `/hɒhɒ/` — **not** `ɐ`. Being's is
  `\textscripta` = **ɑ**, open back **unrounded** (`:4271`, `:5065`). ⚠ The
  codex is internally inconsistent about Being: `:4628` calls the same `/ɑ/`
  "open central" where `:4271`/`:5065` call it "open back unrounded". Recorded,
  not resolved.
* **`↻(↻(…))` appears ZERO times in the whole 7,423-line codex** (control: the
  single-`↻` forms above are found by the same grep, so the file reads and the
  absence is real). General metacursion idempotence is **never stated**. The
  idempotence the codex does assert is about *identity* (Lem. Idempotence of
  Identity, `:1788`), about the *runtime* `𝓡(𝓡) ≡ 𝓡` (`:1334`), and about the
  meta-process fixed point Δ\* (`:3476`) — not about `↻` in general.

`NORMK`'s `REWRITE_MC` has four arms. Arm 1 (`↻(BEING) → SELF`) is `:4810`. Arm 3
(`↻(𝓡) → 𝓡`) is `:1334`. **Arm 2 — `HAS_PREFIX(x)("↻(")`, i.e. `↻(↻(y)) → ↻(y)`
for EVERY y — has no primary source, and it is the arm the whole divergence
rides on** (probes 08 and 15). Under it `↻(↻(VOID))` collapses to `↻(VOID)` =
**None**, asserting an identity the codex never grants for a family it
deliberately spells out as reduplicating.

⚠ **SO ITEM 2 MUST NOT SIMPLY PROPAGATE `NORMK` OUTWARD.** The obvious execution
— "canon.la is canonical, make the other four match it" — would push an
**over-collapse** into the visual and acoustic registers, which currently have
the codex's behaviour right for the reduplicating family. The single normaliser
has to be built from the *declared* theory, arm by arm, with each arm carrying
its citation; `onf.la`/`sigil.la` are not simply behind, and `NORMK` is not
simply ahead. **Per this repo's own rule, that is a code↔codex divergence to
RECORD, not to resolve in either direction** — Erik's ruling, as the LOVE and
discourse entries were.

⚠ **`LINGUA_ADAMICA.tex` IS NOT ON `track-b`.** It exists only on `kernel-k1`;
`CLAUDE.md` states it is at repo root, and on this branch it is not. The
citations above were read from the shared object store
(`git show kernel-k1:LINGUA_ADAMICA.tex`), never from another worktree. Anyone
adjudicating κ from `track-b` alone cannot open the authority — which is the
exact condition `CLAUDE.md` records the LOVE ruling having been made under, and
the reason the file was brought into the repo in the first place.

#### The mechanism divergence — κ is a rewrite set where the codex specifies none

Separate from arm 2, and larger. `LINGUA_ADAMICA.tex` §*Gap 2: Normalization
Confluence and Termination* (`:5635`):

* **`:5652`** — *"**Rather than relying on a rewrite system with potential
  confluence issues**, we **directly compute a unique canonical form** for any
  concept graph using a deterministic algorithm. The method is the
  **Weisfeiler–Lehman (WL) algorithm** (color refinement), adapted for labeled,
  directed, typed graphs."*
* **`:5672`** — *"Confluence is **trivial** because we are not using a rewrite
  system with multiple possible reduction paths… a **deterministic function**
  that maps each graph to exactly one canonical form… confluence is guaranteed
  by construction."* Termination unconditional, `O(|V|·|E|)`.
* **`:5676` `def:onf-alg`** — `ONF(C) = Canonicalize(Graph(C))`, Canonicalize
  being WL.

★ **AND `:5652` IS THE CODEX REPAIRING ITSELF, WHICH IS THE PART THAT SETTLES
IT.** `:5464` §*The Normalization Engine* does sketch *"a set of equivalence
rules (commutativity, associativity, idempotence, etc.) until a fixed point is
reached — **a rewrite system in the classical sense**"*, and that is the passage
our implementation matches. But it is precisely what the section **titled
"Gap 2"** exists to replace: the codex poses the rewrite engine, names its
confluence and termination gap, and resolves it by specifying WL instead. So
this is **not** two inconsistent passages to choose between — **`canon.la`
implements the version the codex itself flagged as the gap, and never received
the repair.**

**Four central results rest on the repaired version**, so it is load-bearing,
not an appendix: Non-Contradiction (`:1697`, *"the confluence of the
normalization algorithm (Definition def:onf-alg)"*), completeness over
well-founded propositions (`:1722`), the uniqueness half of Unique Canonical
Glyph (`:3346`, *"`Norm(FG(C))` is unique (by confluence, Definition
def:onf-alg)"*), and canonical labeling (`:5740`).

★ **This EXPLAINS arm 2 rather than merely accompanying it.** Under a rewrite
set every equivalence must be **declared by hand**, and each declaration is an
assertion someone has to author — which is exactly how an unsourced
`↻(↻(y)) → ↻(y)` gets written. Under WL canonicalisation **nobody can author
one**, because equivalence is *computed from graph structure* rather than
asserted. Arm 2 is a symptom of the mechanism, not an isolated slip.

**What this does NOT settle:** what `↻(↻(VOID))` actually canonicalises to. That
falls out of the graph, and computing it needs the WL machinery **nobody has
built** — `onf.la` extracts graph *features* but performs no colour refinement.
So item 2's true shape may be far larger than reconciling five normalisers: it
may be that four registers are hand-rolling equivalences the specified mechanism
would decide. **Recorded, not ruled on** — Erik's, with the citations above.

★ **And the self-correction, since it is the same failure one level up:** a
`build.sh` comment written earlier *in this very change* claimed the fourth
witness was what caught the ⊗ cases. Measurement showed those cases crash the
module, so the three-witness gate went red on them anyway. The comment was
rewritten to what was measured. **A comment that survives its own disproof is
the quietest kind of unwitnessed claim** — it is the `denote.la:41` failure in
miniature, and it appeared while fixing `denote.la:41`.

### A FOURTH: the gate that could not SPEAK — same day, found the same way
The rot above is a defect a gate **could not see**. Its mirror is a gate that
sees fine and **cannot say so**, and this file's own sections had it.

`build.sh` runs `set -euo pipefail`. Under it, `VAR="$(cmd)"` **aborts the
script** when `cmd` exits non-zero — so every `FAIL` line below the capture is
**dead code on exactly the path it exists to report**. Measured: `denote.la`
with a defect planted in its `LOVE` leaf exits `rc=1`, and the denote section
died at its capture having printed **no `FAIL  denote:` line at all**. The build
still went red, but **mutely** — a consumer grepping `^FAIL` saw nothing.

★ **AND IT INVALIDATED THE RED-PATH EVIDENCE COLLECTED FOR THIS VERY CHANGE.**
The four planted `D_CON` defects were all reported RED — but those verdicts were
obtained by running `./tiny_host` directly and grepping, **not by running the
gate section**. So what had been verified was that the *assertion* goes red,
never that the *gate* says so. The right question is not "does it pass?" but
**"what does it print when it fails, and have I watched it print that?"** — and
the wrong process had been watched printing.

Guarded (`|| true`) at 10 capture sites in the five sections this change
touches, so the assertion does the reporting; the build still exits 1, the gate
merely names what failed. One of the ten was the bare-command form
`cmd > out 2>&1; RC=$?`, where `set -e` kills the script before `RC` is ever
assigned — the return code is dead on the failing path.

⚠ **Scope, stated because it is a real gap:** `build.sh` has ~239 such captures
across every track's sections and only these five were guarded. The tell is
`VAR="$(...)"`, or a bare `cmd > out`, on a line whose failure a later assertion
is supposed to report. **Three gates on three tracks carried an exit-status
defect the same day** — one that could never go green (`gate_p1.sh`), one that
could never report a red (`gate_rss.sh`), and these, which went red without
saying why. A gate that cannot SPEAK tests about as much as one that cannot
FAIL, and neither is visible from reading the assertion.

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

- `[~]` **A. `⊗(A,A) ≡ A` HOLDS ONLY FOR THE ARCHĒ.** For every other A,
  `⊗(A,A)` is a **distinct compound**. This is a *principled choice and must be
  documented as one*, because the current behaviour is otherwise indistinguishable
  from a rendering accident: `⊗(A,A)` used to be byte-identical to `A` in sound —
  with identical parents any weighted blend collapses, (2g+g)/3 = g — so an
  infinite family of distinct glyphs shared one phonym, and the renderer, not the
  theory, was deciding.
  **WORK:** state the Archē exception explicitly in `canon.la`'s rewrite set and
  in the paper; gate it in BOTH registers (glyphic and phonetic); assert the
  general case stays distinct. A rule that holds by accident is not a rule.
  ◐ **PARTIAL 2026-09-11: two of the WORK's three clauses are witnessed (canon's rewrite set; the gates,
  with the general case asserted distinct). The paper clause is not (P17). The row reaches `[✓]` only
  when the paper states the exception (The Lieutenant, ask `1789086184`).**
  A's DONE record is below ("A — DONE 2026-08-26"). build.sh now gates R-A in THREE registers, not the
  two that record's heading names. **Glyphic:** canon.la's REWRITE_SYN, with `RA general-set : YES` over 9
  non-Archē witnesses (build.sh :1400). **Phonetic:** phonym.la's SYNNORM, with `RAP general-set: DISTINCT`
  over the same 9 (:1432). **Visual:** sigil.la's CANONIQ, with `RAV general: DIFFERENT` on LOVE only
  (:1474). Each visual witness costs a full SIGIL render, so widening it is a cost decision left open.
  Until this commit the general case was witnessed on LOVE alone in every register, so a rewrite that
  collapsed ⊗(A,A) only for compound A passed every arm. ELENCHOS's run (board :23020) shows that
  mutant MISSED by the old gate and CAUGHT by the widened one, both glyphic (Mc) and phonetic (Mcp).
  ⊗(BEING,BEING) is deliberately not a witness: whether PRIM("BEING") IS the Archē is unsettled.
  **The paper:** the WORK asks for the exception to be stated "in the paper", and the white paper (sha256
  `98beeff4ee45`) does not state it. METANOĒ and The Lieutenant searched it on 2026-09-10, independently and
  across line breaks. Of the 14 lines naming the Archē (`Arch[eē]`, `Arch\=e`), none is within 3 lines of
  ⊗ or `\otimes`. No ∃⊗∃, ⊗(A,A) or A⊗A form appears, and no line says "distinct compound". No
  idempotence line is within 3 lines of an Archē line, and the 3 near a ⊗ (:2897, :9278, :9362) concern κ
  and ↻. Blind spots: the Archē named only by glyph or number, and ⊗ written in words. That clause is P17 in the master list.

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

- `[✓]` **The spec pipeline emits no `export` — RETIRED AS WRITTEN, re-measured
  2026-09-09.** The defect was real and is **fixed**; this entry outlived it by
  long enough to dispatch a track onto retired work, which is why it is corrected
  here rather than deleted.
  **Measured:** all nine modules emit an export line today — `canon` 49 names,
  `aatc` 47, `metalogic` 51, `swc` 20, `glyphdag` 47, `pragmatics` 15, `deixis`
  15, `psc` 21, `topoembed` 19. **The stated symptom does not reproduce**:
  `import("canon.la")` then `CANON(SR_ABOUT)` returns `↻(RECOGNITION)`, rc=0 —
  with a **negative control in the same probe** printing `unbound variable
  'NO_SUCH_GLYPH'`, so the test can fail and did not. The generator emits it at
  `specpipe.la:74`; fixed in **`9112c18`**, and `specpipe.la`'s own comment now
  records the symptom in the **past tense**.
  **Both gates this item asked for now exist:** (a) a module importing `canon.la`
  resolving `CANON` — `build.sh:1203`, a live execution not a grep; (b) the drift
  gate — `gate_normdrift.sh`, landed **`7a4e76d`**, behavioural (runs each
  normaliser and compares OUTPUT, since a source diff is a static analyser).
  ★ **THE CAUSAL ARGUMENT ABOVE STILL HOLDS AND STILL NAMES OPEN WORK.** The fix
  was *"inert until a consumer is converted"* (`specpipe.la`) — eleven generated
  modules, 313 glyphs, imported by **nothing** — and **the conversion never
  happened**. Measured 2026-09-09: **14 distinct sites** still re-declare canon's
  κ machinery (`m76_kappa_census.sh`, filed **M76**). So ⊗-sorted-in-five-places
  is still true; its **cause** is fixed and its **debris** is not.
  ⚠ Conversion is **priced and deferred**, not forgotten: importing `canon.la`
  costs codegen ~quadratically-and-steepening in glyph count, **per build**
  (pilot on `denote.la`: +121.79 s, +45%, and it is codegen'd twice per build).
  The obstacle is **name collision**, not cost — canon exports 49 names and 5
  collided with denote's own. **A gated copy and no copy are equivalent with
  respect to drift**; (b) removes the exposure at zero recurring cost.
  *Paper: §Limitations, [B] — the paper still asserts this and owes the same edit.*
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
  ⚑ **Verified 2026-09-10 — PARTIAL** (METANOĒ, against kernel-k1 `fcaaa23`): crossmodal is still pinned as a REPORT, not a result (build.sh's CROSSMODAL block); the other eight run. The residue is unchanged.
- `[ ]` **Three gates that cannot go RED.** (a) phonetic α=1 is a `grep` for a
  sentence the module prints unconditionally; (b) the 8/8 phonetic injectivity
  gate's concept list contains no two entries sharing a leaf-set, so the
  property is untestable by construction; (c) `seal_test.la:36`
  `COMPLEXITY = la g. 1` is a constant function. Each must be given a real red
  path or demoted to a REPORT. *Paper: §Falsification, the vacuity bet.*
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): part (c) is unchanged: `seal_test.la:41` (the item's :36) is still `COMPLEXITY = la g. 1`, a constant.
  ⚑ **2026-09-15, Track F — part (c) is RESOLVED BY DEMOTION, and the claim now has a real red path
  elsewhere.** `seal_test.la`'s own header marks COMPLEXITY `[S]` structural — "build.sh reports this
  line; it gates nothing" (build.sh:7044-7059 prints it as a report) — so it is no longer a gate that
  cannot go RED; it is a report. The claim it stood for (complexity-one) is now GATED with a red path
  in `unified.la`: a COUPLED form (ren = renA·renB, the "blackbird") is REFUSED because it fails
  AUTO_OK; nodes grow by exactly one per shared collapse; the mutant that seals the coupling instead
  reads F. Parts (a) and (b) are phonym-side (Track A) and remain open. One unresolved part keeps the item open; (a) and (b) were not re-measured.
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
  it on afterwards. **Six** crypto modules pass published vectors `[W]` — corrected
  2026-09-09, the count was one too many: `sha256` (`gate_sha256.sh`) and
  `hmac`/`hkdf`/`chacha20`/`poly1305`/`aead` (`gate_crypto.sh:68-72`) are witnessed;
  `hmacdrbg.la` is `[B]`, carrying a NIST SP 800-90A known-answer vector that no
  script had ever run. None of the six is timing-safe. **Gate:** for each module, execution time over two input classes
  that differ only in secret bytes must not separate. **Red path:** feed it a
  deliberately data-dependent branch and the timing gate must fire. A discipline
  carried by convention is precisely what this list exists to convert into a
  gate.
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): no timing gate exists in any tracked script, and no module asserts secret-independent execution time.

- `[ ]` **★ LEDGER ROW — Identity Adequacy: three collisions open `[A]`.**
  Criterion 6 of the paper's own nine, unmet: monosemy holds except for three
  κ-collisions. `Bad/Grief` is one and is tracked separately (1 bit, open); the
  other two are named nowhere in this list. **Owed first:** enumerate all three
  from the DAG rather than from the paper's prose — a count in prose is the
  defect class this file exists to catch. Then one gate per collision, each able
  to go red by re-introducing the collision it closed.
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): open on kernel-k1. The cross-population gate (`crosscoll.la`, M22) exists on track-c only (`7f22958`). Since this item was written, E16 §A declared Sky = Mystery and Move = Agency (`a9fb1b3`), and E16 §B ruled Death ≠ Past, a pair that stays open until Death is re-derived (`65e5431`).

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
  ⚑ **Verified 2026-09-10 — PARTIAL** (METANOĒ, against kernel-k1 `fcaaa23`): the spec register is gated both ways: build.sh's phonetic R-A block requires `SPEC_N(⊗(LOVE,LOVE))` to stay distinct and `SPEC_N(⊗(∃,∃))` to be ∃. No gate compares the synthesised PCM of ⊗(A,A) with A's, which is what this item names.
- `[✓]` **Θ_P is mode-blind** — ⊗/⊕/▷/⊂ give one peak-set where `Θ_V` carries a
  mode field. Fix verified on a copy (`PINV = mode : peaks`, mirroring `VINV`).
  **Awaiting the build to apply.**
  ✔ **Verified 2026-09-10 — DONE** (METANOĒ, against kernel-k1 `fcaaa23`): done in `9112c18` (08-27), one minute after this item landed. `psc_spec.la` defines `PINV` (mode : peaks) and `PMODE_REC`, with a META_DEBUG test at `psc_spec.la:124–125`, and build.sh's PSC* gate requires every glyph to PASS and "module VERIFIED". A mode-blind Θ_P would fail that test *(derived; not run)*.
- `[~]` **▷ has no acoustic signature** — the SENTENCE operator. Sentences could
  be spoken and never parsed back. Rate-carried marker built and verified with a
  control; duration preserved so the WAV gate holds. **Awaiting the build.**
  ⚑ **Verified 2026-09-10 — PARTIAL** (METANOĒ, against kernel-k1 `fcaaa23`): the marker exists: phonym.la's `DIRP` modulates the tail, and build.sh's R-D note records it as a periodic amplitude modulation with duration preserved. No gate fails if it is removed, and phonseq cannot detect it (see the `phonseq` item below).
- `[✓]` **★ ⊂ IS NEVER USED** (measured 2026-08-23, `ablate.la`). Across all 79
  published entries: ⊗=58, ⊕=4, ▷=26, **⊂=0**, ↻=2. The closure is claimed over
  five modes and exercised, lexically, over four. The fix is CONCEPTS genuinely
  formed by containment — not a token entry added to close a count. Ablation shows
  the other non-⊗ modes ARE load-bearing; ⊂ is untested because nothing uses it,
  which is a fact about the lexicon rather than about the operator.
  ✔ **Verified 2026-09-10 — RETIRED AS WRITTEN** (METANOĒ, against kernel-k1 `fcaaa23`): stale when it landed. `a9e27e8`, the commit that carried this item, also set Bad = `c36` (⊂). At HEAD ⊂ is used twice (Bad `c36`, Because `c75`), and build.sh pins `⊂=2` and `⊂-now-used OK` (the ablate step), as buildla.la does.
- `[ ]` **The elision layer** — 4 of 79 entries diverge from the codex by VOWEL
  ELISION (Think, Gratitude, Question, Past). The codex prints surface forms; the
  Operator Phonology generates underlying ones. Needs a phonological layer, not a
  patch to the segment rules. ★ The stress rule was itself corrected this session
  (final vowel, not first), found only by bringing in the codex's example
  SENTENCES as fresh vectors — a rule fitted to one table will agree with that table.
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): no module has an elision layer. Since R-D (08-26) the four elision divergences sit inside the 14 ▷ divergences the lexicon gate pins, so no gate sees them separately.
- `[ ]` **The acquisition gap** — no syllabus, glyph sequence, or teaching order
  exists. Worse, non-commutative ⊗ means an English gloss underdetermines the
  derivation, so "coin the word for compassion" is not a well-posed instruction.
  The language as published cannot yet be TAUGHT from its own tables: the gap
  between *unbounded in principle* and *sayable by a person*.
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): no module has a syllabus, glyph sequence or teaching order.
- `[ ]` **`phonseq` must DETECT the new ▷ marker** — the signature exists; the
  decoder still reports ▷ as a leaf.
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): phonseq.la's `IS_DIR` is still the exclusion of three modes (verdict `DIR|SYN`), and nothing reads DIRP's marker.
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
  ⚑ **Verified 2026-09-10 — PARTIAL** (METANOĒ, against kernel-k1 `fcaaa23`): the dead branch is fixed and gated (phonseq emits `DIR|SYN`). Separating ⊗ from ▷ acoustically is still not done.
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
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): `phonym.la:424` is still `PSC_STAR = PAIR(WAVE(RENDER(PHONYM(node))))(SPEC(node))`, raw on both sides.

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
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): no module names a toroidal or wrap-around topology.

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
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): build.sh has no gate for connected components, parent visibility or emergent vertices.
- `[ ]` **Catalogue-wide sigil injectivity** — all forms pairwise distinct,
  and `SIGIL(MC(x)) ≠ SIGIL(x)` for every catalogue entry, not just the three
  fixed.
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): `siginj` is gated (build.sh `run_eight siginj`), but only on three ↻ traces (REC, SELF, BEING) plus `distinct`. Neither pairwise distinctness across the whole catalogue nor MC(x) ≠ x for every entry is gated.
- `[ ]` **Visual round trip** — no bitmap→structure decoder exists. It is the
  symmetric partner of `sglyph`/`phonseq`, and the strongest available
  cross-substrate invariance test: sound → decode → κ → re-render → decode → κ.
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): no module has a bitmap→structure decoder.

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
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): neither sigil.la nor any dyad module has a Dyad or meta-referent sigil glyph.

- `[✓]` **★★ The identity RELATION now has a glyph in 𝓜** (built 2026-09-17 answering Erik's
  ground/locus objection; `identity.la`, gated `gate_registers.sh` §41). 𝓜 carried glyphs for the five
  modes, 𝔑, κ, 𝓡 and ∂δγρ𝔄 — but **not for the identity relation the whole language rests on**, and the
  DISTINCTION side was expressible only as the negation of a positive test. Three glyphs, all checked clear
  by `regcollide.py`: **`G_GROUND = ▷(RECOGNITION,BEING)`** (≡ at ground — two routes, one being; the
  deliberate parallel to κ = ▷(RECOGNITION,FORM), which recognises form where this recognises the being
  beneath it); **`G_LOCUS = ▷(RECOGNITION,⊂(FORM,BEING))`** (≢ at locus — one being, two forms, stated
  POSITIVELY as an operator that asserts non-merger); and **`G_IDENT = ⊗(G_GROUND,G_LOCUS)`**, the relation
  ITSELF — their 𝔑-dyad, one compressive movement with both aspects recoverable as proper sub-forms (gated).
  **★ The load-bearing witness is row 1:** a pair IDENTICAL AT GROUND and DISTINCT AT LOCUS must exist
  (⊕(BEING,LOVE) vs ⊕(LOVE,BEING) — one meaning by ⊕-commutativity, two κ routes). **If no such pair
  existed the distinction would be idle and LA would be a monism in fact whatever its prose said.** Rows 2
  and 3 give MERGED and SEPARATE, and all three verdicts are distinct.
  **★★ The two RED paths ARE the two failure modes by name, and each is built and refused:** MONISM (locus
  made constant-false — row 1 collapses to MERGED, the mirror becomes the reflected) and DUALISM (ground
  made CANON-equality — row 1 collapses to SEPARATE, nothing is ever non-separate across two forms and
  there is no reconciliation left to make). Both fire.
  **[B] This NAMES and GATES the distinction; it does not prove the metaphysics.** The three predicates
  already existed in `canon.la` as `IS`/`NIS`/`IS_ALPHA1` and were already witnessed to disagree — in
  `lineage.la` ("truth:T glyph:F"), `complement.la`'s ¬¬, `substitution.la`'s navigation verdict,
  `migrate.la`'s cosmetic revision, `ontosemiosyntax.la`'s two clauses. What was missing was the NAME, and
  𝓜 ⊂ 𝒜 requires a name for every operation of the language.

- `[B]` **★★ Cross-branch compression collapse — BOUNDED TO THE SEALER, and the bound is PRINCIPLED**
  (`crossbranch.la` §46 + `divergent.la` §48, 2026-09-17). Two premises of the original claim failed and
  are recorded rather than built around: **there are 19 branches, not 28** (branchgenesis gates base=18,
  set=19 with Δ_B; the rest of that file is its six refusal fixtures), and **Liminal and Anamnetic do not
  exist anywhere in the tree**, blocked on a definition not on disk. And **there is ONE sealer**
  (`branchgenesis.la:121`), so κ_B ≡ κ_B' across the built branches is true BY CONSTRUCTION — 18 branches
  calling one function, not 28 independent operations agreeing. Measured: 153 κ-identical pairs, 0
  differing, with two in-file fixtures (compression by CONVENTION, compression by DELETION) firing every
  run so the green is a real comparison.
  **★★ Erik then chose to BUILD THE DIVERGENT BRANCHES rather than accept the design reading, and the
  answer is NEGATIVE.** Six constructed compressions over one parent pair give **six distinct κ-outputs**;
  under iteration **five of the six never reach a fixed point**; and the one that does is **DELETION**,
  which rests only by discarding the second parent. **The divergent operations do NOT converge on κ.**
  The control keeps that honest: the sealer is not fixed-point-free — it rests at the Archē, which §45
  gates as ∃'s alone.
  **★★★ THE DEEPER RESULT: CONVERGENCE AND RETENTION ARE IN TENSION.** Every operation that RETAINS both
  parents fails to come to rest; the only one that rests DISCARDS. §42 measured why — retention costs +1
  node per collapse, forever. **Rest is bought with loss.** So "one movement" is a fact about this
  system's single sealer, not a convergence theorem about compression in general.
  **[B] The bound:** the collapse holds for the 18 BUILT branches, by construction; alternatives do not
  come back together even in the limit; the iteration search is bounded at 8 steps, so "never" is
  witnessed as "not within 8 while growing monotonically".

- `[deferred]` **★ Liminal and Anamnetic — EXPLICITLY DEFERRED, with the condition stated** (2026-09-17).
  Both are TTOE branches NAMED in the corpus and absent from the tree: **zero occurrences anywhere**, and
  `branchgenesis.la` gates base=18 / set=19 without them. They were previously recorded as "blocked on a
  definition not on disk", which is an unstable state — it reads like work in progress when no work can
  begin. **They are now DEFERRED, not blocked.**
  **THE CONDITION under which they become definable, stated so the deferral can end mechanically:** a
  branch enters `branchgenesis` only with (i) a DEFINITION of what the branch studies, and (ii) an
  INTERFACE MAPPING — the operand `x` of its dyad `⊂(RELATION, x)`, since all 18 built branches ground in
  that interface form. Supplying (i) and (ii), or putting the Codex Llogoscribeologiae on disk, ends the
  deferral. Until then **the branch count is NINETEEN and every cross-branch claim is bounded to it**
  (`crossbranch.la` §46). The same applies to Logorhetoric, Meta-Rosettology and Adamic.
  ⚠ **Do not invent the mapping.** Erik's standing instruction, and inventing it would put an unearned
  branch into a census that other gates count.

- `[✓]` **★★ The identity-adequacy rulings — ALL EIGHT RESOLVED** (`adequacy.la`, gated §49, 2026-09-17).
  **★ First, a correction: the three pairs named in the request (Change=Can, Give=Because, Know=You) DO
  NOT COLLIDE.** Measured: Change ⊗(BECOMING,FORM) vs Can ⊗(FORM,BECOMING) differ in OPERAND ORDER; the
  other two differ in MODE. `monosemy_test.la:31` cites `LINGUA_ADAMICA.tex:2837` — ontosynthesis is
  **NON-COMMUTATIVE**, *"direction matters in Being"* — and NORMK correctly sorts only ⊕. **Ruling those
  three identical would have destroyed three distinctions the corpus asserts.**
  The real overloads are EIGHT, by census over the published vocabulary (79 rows → 71 distinct κ), with
  both names of every pair read back from source. **ONE declaration and SEVEN re-derivations**, every
  proposal clear against the 86-form corpus and pairwise distinct; applying all eight drives the
  one-κ-two-name count to **ZERO**:
  | shared form | keeps it | ruling |
  |---|---|---|
  | ⊗(BEING,DEPTH) | Totality | **All = Totality — DECLARED ONE CONCEPT** (two English words, one sense) |
  | ⊗(FORM,BEING) | Substance | Large → ⊗(DEPTH,FORM) |
  | ⊗(FORM,LOVE) | Beauty *(sigil.la attests it)* | Good → ⊗(BEING,LOVE) |
  | ⊗(LOVE,RELATION) | Friendship | Bond → ⊂(RELATION,BEING) |
  | ⊗(VOID,DEPTH) | Mystery | Sky → ⊂(VOID,FORM) |
  | ▷(FORM,BEING) | This | Here → ▷(FORM,RELATION) |
  | ▷(FORM,VOID) | That | There → ⊂(VOID,RELATION) |
  | ▷(SELF,BECOMING) | Agency | Move → ▷(BECOMING,FORM) |
  **The principle throughout:** the member whose sense the form actually encodes KEEPS it.
  ⚠ **The module RULES and VERIFIES; it does NOT edit `lexicon.la` / `opgrammar.la`.** The published
  vocabulary is the architect's to apply — this makes the application mechanical and pre-checked rather
  than a judgement call at the keyboard. [A] each ruling is one line to reverse, with its reason beside it.

### Cross-register
- `[✓]` `trimono.la` — one gate, three registers, three rows (injective /
  monosemic / directed).
- `[ ]` **The triple bar as a biconditional.** Nothing asserts glyphic ≡
  phonetic; `crossmodal` measures *correlation*. The identity gate is
  `NIS(a)(b) ⟺ same rendered sound`, over a fuzz corpus, and the same against
  sigil rasters. This is Erik's "collapse into one another via the triple bar"
  made executable.
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): no gate asserts NIS ⟺ same rendered sound; crossmodal is still a correlation report.
  ⚑ **2026-09-15, Track F — RELATED, NOT CLOSED:** `registers.la` gates that all twelve register
  IDENTITY-PROJECTIONS agree on NIS-equal glyphs (the twelve-fold collapse at the identity level).
  It does not assert NIS ⟺ same rendered sound / same raster; that remains this entry's gap.
- `[ ]` **One normaliser, not five.** `NORMK`, `CANONIQ` (onf), `CANONIQ`
  (sigil), `NKAP`, `NORMP` — three different equivalence theories between them.
  Gate: `NORMK(t) ≡ CANON(NORMNODE(t))` over a fuzz corpus. RED today.
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): all five still exist: `NORMK` (canon.la), `NKAP` (entropy.la), `CANONIQ` (onf.la and sigil.la, plus a copy in logo/logos
  ⚑ **2026-09-15, Track F — the gate this entry names now EXISTS, and a SIXTH normaliser with it.**
  `registers.la` defines `NORMTREE` (tree-level, mirrors NORMK rule for rule) and gates
  `NORMK(t) ≡ CANON(NORMTREE(t))` over its probe pairs and LIN_CAT — the exact form asked for
  here, over a probe set rather than a fuzz corpus (that widening is owed). It is honest to say
  this ADDS a normaliser; the reconciliation this entry wants (one normaliser) is for the
  architect: either NORMK becomes tree-level and NORMTREE is retired into it, or NORMTREE stays
  as the differential witness. Recorded in REGISTERS.md §10._render.la) and `NORMP` (phonym.la). There is no NORMNODE gate.

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
  ⚑ **BUILT 2026-09-15, Track F — `[~]` pending the register-stack landing.** `textcoherence.la`:
  a referent store keyed on NORMK with first-mention indices (11 referents / 14 mentions / given 3
  on the 5-proposition vector), a connective-linked utterance graph (share · contrast:¬ via
  `complement.la` · contrast:opp via `opposite.la`), components with orphans NAMED (an injected
  ⊂(FORM,DEPTH) reads components=2), and THE CRITERION THIS ENTRY DEMANDED: the coherence score
  Σ 100/link-distance scores the shuffled text strictly lower (383 → 191); a distance-blind
  mutant reads them equal and turns RED. Bound: sharing + ¬/opposite contrast only; no
  argumentative or narrative structure; one vector. `gate_registers.sh` §12.
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): there is no coherence gate, and the item's own order puts the criterion first.

- `[ ]` **★ LEDGER ROW — Lexical depth D: computable `[W]`, use-gating `[A]`.**
  The ledger splits this row in two and only half is witnessed: depth IS
  computable from the DAG, but nothing gates depth against USE. The claim the
  gate would pay for is that a concept's depth predicts something about how it
  is used, not merely that a number can be derived. **Owed first, before code:**
  say what use-gating asserts. "Depth correlates with use" is not a gate unless
  a value exists that fails it — a candidate red path is that shuffling the
  depth assignment across the lexicon must break the relation; if a shuffled
  assignment scores the same, the measure is reading nothing.
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): build.sh pins depths as a measurement; nothing gates them against use.

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
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): no module implements the entendre.
  ⚑ **BUILT 2026-09-15, Track F — `[~]` pending landing.** `entendre.la`: I vertical (surface /
  parents / primitives / operators, read off the tree — a primitive reads ⊥: the red path), II
  horizontal (the co-present facets = the hash-consed DAG's defs), III calligraphic **[B]** (the
  element census the calligrapher would execute — the renderer has no execution parameters, so
  modulation is not claimed), IV sonic (the prosodic contour, per Prosodic Intrinsicality). On the
  compound ⊗(κ,𝓡) the four readings are pairwise distinct and derived, not tabulated. Mutants: two
  modes reading the same → RED; a primitive given a vertical reading → RED. `gate_registers.sh` §21.

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
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): no gate or test names grammar completeness.
  ⚑ **BUILT 2026-09-15, Track F — `[~]` pending landing.** `gramcomplete.la`: the 79 published
  derivations validated and replayed as rule traces (R1=167 R2=88 R3=2, derived independently
  first); R4 witnessed on three sentence forms and refused at d=0; three unreachable fixtures
  refused with the failing rule named. Bound stated in-file: falsifiable only at the boundary of
  well-formedness — a coherent concept with no expression cannot be constructed from within.

- `[ ]` **Acquisition** — the codex never gives a syllabus, glyph sequence or
  acquisition method for LA; its one acquisition claim is "explicitly labeled as
  untested" (ROADMAP:1213), and Erik intends children to learn it. Buildable
  prerequisites: core-lexicon-as-data completeness gate; the Self-Generating
  Course pipeline run on LINGUA ADAMICA.tex to produce the LA syllabus.
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): as for the acquisition gap above: no module has a syllabus or sequence.
  ⚑ **BUILT 2026-09-15, Track F — `[~]` pending landing; the EMPIRICAL half stays open.**
  `syllabus.la` derives the teaching order from the 79 published rows: primitives first, then by
  derivation depth (d0=3 d1=64 d2=12 — derived independently first), fewer leaves earlier. Gated:
  depth non-decreasing; constituent-first (every sub-derivation that is itself an entry precedes
  its compound: 0 violations; the REVERSED order has 72 — the red path); a mutant sorting by leaves
  alone loses depth order. Bound stated in-file: the order the STRUCTURE implies; no learner
  measured. `gate_registers.sh` §23.
- `[✓]` **The Aletheic Immune System** (spec :3608) — the organ that DETECTS  **DONE 2026-08-23** — `immune.la`: four checkpoints, four pathogens, four DISTINCT signatures. ★ Finding: it detects corruption, NOT falsehood — the right conjunct of Thm. healthy has no evaluator. Gated as a positive assertion.
  pathological language at runtime (involution: two glyphs, one referent). The
  build-time monosemy audit is its static half; the runtime half is absent.
- `[✓]` **Convergent coinage** — the real sociolinguistic theorem: two speakers  **DONE 2026-08-23** — `coin.la`: ⊕ converges under either order, ⊗ correctly does NOT. ★ Finding: non-commutative ⊗ makes operand order part of the concept, so an English gloss underdetermines the derivation. Convergence holds where the concept is fully given.
  independently coining a glyph for one concept produce the SAME glyph iff their
  ONFs agree. Testable, untested.
- `[ ]` **`ontofelicity` → live enforcement** — `PERFORM` currently reports;
  wiring it to the real capability layer makes felicity enforceable.
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): ontofelicity.la imports nothing. Its capability sets are string data, not wired to a capability layer.
  ⚑ **BUILT 2026-09-15, Track F — `[~]` pending landing.** `felicitylive.la` imports `logoscap.la`
  and `ontofelicity.la`: condition (B) is now the Morris sealer — a capability is the needed verb
  sealed under the granting realm; the speaker holds it iff its UNSEAL opens the box. Authorized
  realm performs; foreign realm refused (TFT, world byte-identical); forged probe refused; the string
  PERFORM and the live PERFORM agree on the authorized case. RED: a bypass that unseals with the
  granting realm lets the foreign speaker perform. `gate_registers.sh` §22. [B] one verb, two realms.

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
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): no module names ontomorphology or an inflectional census.
  ⚑ **BUILT 2026-09-15, Track F — `[~]` pending landing.** `ontomorph.la`: census over the 79
  published rows (10 skeletons, operator uses ⊗59 ▷24 ⊕3 ⊂2 ↻2), 71 combinations → 71 κ-images
  INJECTIVE, the ⊕(3,6)/⊕(6,3) fixture refused and named; numbers derived independently first.
  Reports (does not gate) the 8 one-κ-two-names overloads for the architect. `gate_registers.sh` §16.

## TIER 4 — SELF-RELATION

- `[✓]` **The coinage organ.** Nothing in the system can COIN: no code path  **DONE 2026-08-23** — `coin.la`: COIN is deterministic, recoverable (parents+mode readable out), closed (result is itself coinable), and pronounceable (phonym computed, not assigned).
  registers a newly minted glyph. `COLLAPSE` returns a MONO and mutates nothing.
  Needs: mint → Ontolexicon registration → **the Ratchet Gate** (a coinage may
  never collapse two previously κ-distinct forms, and must strictly add a new
  κ-class). This is also the executable half of the Sapir–Whorf *retained*
  claim.
- `[✓]` **M11a — the catalogue IMPORTS what it catalogues.** **DONE 2026-09-08
  (`4bcdb07`).** `familytree.la`'s `CAT` hand-transcribed seventeen glyph bodies,
  and the note above it said why: *"canon.la has no export line, so its glyphs
  cannot be imported."* True when written, **false at HEAD** — `canon.la:100`
  exports 49 names including all ten self-relations. Sixteen of seventeen entries
  are now the **source glyphs**; `NU_STAR` stays local because `metaglyph.la` does
  not export it (named, not hidden).
  ★ **Output is BYTE-IDENTICAL to the pin** (`catalogue=17 | G1:T | G2=8:T |
  maxdepth=2`), and that identity IS the drift test: had the transcription
  drifted, the refactor would have moved the line. It did not — so the copies
  were faithful, and now they cannot stop being.
  Measured before editing, not assumed: importing `canon.la` beside
  `metaglyph.la` raises no collision (both export `CANON` and `KAPPA`
  **token-identically** — 387 tokens, sha `cc39f4373cc3e648`); a local
  constructor after an import rebinds cleanly; an imported node interoperates
  with a local destructor, because the six-continuation Scott encoding makes
  nodes **behavioural, not nominal**.
- `[✓]` **M11a residue — the catalogue is INCOMPLETE, and now cheap to complete.**
  Re-measured 2026-09-08: the old item's *"stale by ≥4"* is **4 of 4 confirmed** —
  `OP_DIFF`, `OP_BOUND`, `OP_COMP`, `OP_INTEG` are all exported by `metaglyph.la`
  and all absent from `CAT`; only `OP_RECOG` is present (as `OP_RHO`). Since M11a
  the fix is one line each. ⚠ It is a **behaviour change, not a refactor**:
  `catalogue=17` becomes `21`. G2 is unaffected (none is unary ↻, so the count
  stays 8) and `MAXD` is unaffected (all are depth 1, `NU_STAR` still 2), and
  `build.sh` pins G1 and G2 but not the catalogue count — verified.
  ✔ **Verified 2026-09-10 — DONE** (METANOĒ, against kernel-k1 `fcaaa23`): `1f9429b` (09-09) added OP_DIFF/OP_BOUND/OP_COMP/OP_INTEG to CAT (17→21), plus G3. build.sh pins `FAMILYTREE catalogue=21 ` and `G3 … TTTTT`, and the landing recorded GREEN 21/TTTTT with a RED of 17/FFFTF. familytree.la, its two imports and the gate block are byte-identical from `1f9429b` to HEAD. buildla.la's companion marker, left at 17, is fixed as `fcaaa23`.
- `[ ]` **M11b — the ancestry walk.** `ANCESTRY(g)`: any glyph's complete line back
  through every COLLAPSE to the nine primitives and the dyad, *as a computation
  rather than an archive* (WP `§sec:compression:3150`). **Both pieces already
  exist** — `DECOMP` (`glyphdag.la`) recovers the tree, `DEPTHOF`
  (`familytree.la:138`) measures it. **Depends on: M11a (done).**
  ⚠ Scope correction: the paper calls this *"the query over the standing DAG"*.
  **There is no standing DAG.** `glyphdag.la` hash-conses **one form at a time**;
  the only registry is `CAT`. M11b is the walk; M11c is what makes it a registry.
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): no module has an ANCESTRY glyph.
- `[ ]` **M11c — auto-registration.** The paper's own stated bound: *"nothing yet
  registers a newly minted glyph automatically."* A mint must enter the registry
  without a hand edit. **Depends on: M11b.** Pairs with the coinage organ's owed
  **Ratchet Gate** (a coinage may never collapse two κ-distinct forms and must
  strictly add a κ-class) — same joint, approached from the two sides.
  ★★ **The depth-directed `selfopt` mode is BLOCKED ON M11c**, and this is why:
  𝔇 computed over a hand-listed catalogue measures **the list, not the language**.
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): nothing registers a minted glyph.
- `[ ]` **Gate G4 — declared and derived catalogues agree**, keyed on NORMK, both
  directions. **RED on arrival.** Depends on M11c (there is no derived catalogue
  until mints self-register).
  *(named G3 until 2026-09-10; 1f9429b gave G3 to operator coverage in code)*
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): it depends on M11c, and no derived catalogue exists.
- `[ ]` **κ\* — meta-pattern compression.** When the same compression pattern
  recurs, encode it as a meta-glyph representing the rule of integration.
  Nothing detects or promotes.
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): nothing detects or promotes a recurring compression pattern.
- `[ ]` **Executable minted operations (ν\*)** — minted operations are
  *expressible* as glyphs but cannot be wired back in as reduction rules.
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): `NU_STAR` is data only (metaglyph.la, familytree.la). No evaluator admits a minted operation as a reduction rule.
- `[ ]` **The Fractal Monoglyph** — depth recoverable by decomposition rather
  than surface marks. `DECOMP` recovers the tree from the single DAG form
  (witnessed), but the Ren string still grows linearly. Largely discharged by
  unifying `MONO`'s etymology slot with the glyphdag form.
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): `MONO` is still a plain pair (canon.la:63, canon_spec.la, archroot.la), and its etymology slot is not the glyphdag form.
  ⚑ **MEASURED 2026-09-15, Track F — the fix is Track A's and is REQUESTED.** `fractal.la` on the
  collapse chain: the Ren (surface κ) is 49 → 104 → 214 → 434 (it DOUBLES, not linear — ⊗(C,C)
  writes C twice) while the hash-consed DAG form is 6 → 7 → 8 → 9 (+1 per collapse) and the tree is
  recoverable from the DAG alone at every depth. So MONO's etymology slot AS the DAG form makes the
  stored monoglyph linear in depth: decidable now, canon.la's to change. `gate_registers.sh` §28.
- `[~]` **The operators ∂δγρ𝔄 as glyphs** (ROADMAP:2567) — currently hardcoded
  dispatch. And the four missing audit operators |G|, |G_meta|, ς, μ.
  ⚑ **Verified 2026-09-10 — PARTIAL** (METANOĒ, against kernel-k1 `fcaaa23`): the glyph half was false when written. OP_DIFF…OP_INTEG and `RANKOF` (rank read from the glyph) have been in metaglyph.la since `4e9449b` (08-20), and this item was written 08-27. build.sh's item-2 block gates them, and ENTELECHEIA's W2 ran that block ok=1 on `3c1c16c`. Still open: the four audit operators |G|, |G_meta|, ς and μ exist nowhere.
- `[✓]` **Self-verifying grammar** (ROADMAP:2564) — grammar recoverable as data;
  full self-parse (L3) still open.
  ✔ **Verified 2026-09-10 — RETIRED AS WRITTEN** (METANOĒ, against kernel-k1 `fcaaa23`): false when it landed. `grammar_l3.la` and its build.sh gate (item 5, L3) arrived in `a9e27e8`, the same commit as this item, and this file marks L3 `[✓]` BOUNDED (ITEM 5 / L3, above).
- `[ ]` **Self-meta-programming: the changed thing must become the running
  thing.** `selfprog`/`selfmod`/`selfopt` write, verify and adopt organs that
  are **never imported or executed**. Gate: a bundled organ-process ADOPTs an
  extension, recompiles, `execve`s the verified result, and the successor
  demonstrates the new capability at runtime.
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): selfprog, selfmod and selfopt all ADOPT, and none of them execve the adopted result.
- `[ ]` **Meta-autopoiesis — and the gate that currently forbids it.**
  `build.sh:3550` REQUIRES `cmp -s logos_app new_logos_secd.bin`: the successor
  must be byte-identical. **A self-revised successor would go RED on the
  system's own gate.** Minimal honest version: generation N applies one verified
  change to its own lineage source, recompiles, and begets a MODIFIED successor.
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): build.sh still requires `cmp -s logos_app new_logos_secd.bin` (now :4383; the item says :3550), so a modified successor still fails the system's own gate.
- `[ ]` **Lack-driven wants** — wire `aatc`'s sensed LACK into `selfprog`'s
  SOLVE, so the system forms the want from its own sensed incompleteness. This
  is the buildable bounded form of autontogenesis; **purpose-origination itself
  is ruled out by Erik's own corpus** (`SR_FOR` is explicitly "NOT
  purpose-origination") and should not be chased.
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): selfprog.la does not read aatc's LACK.
  ⚑ **BUILT 2026-09-15, Track F — `[~]` pending landing, bounded.** `wants.la`: the want is FORMED from
  aatc's sensed lack (organ-A lacks MEMORY → want=MEMORY; a complete organ → ⊥) and RESOLVED by the
  structure's own closure move (SLACKS empties, CENTROPY 3→4). Handed to SOLVE as data; the
  behavioural synthesis is NOT done, because a lack carries no tests — stated. RED: a want for a
  complete organ. `gate_registers.sh` §26.
- `[ ]` **`AWARE` / `C` predicates** — "awareness" appears only in prose
  comments. `AWARE(g) := AUTO_OK(g)`; `C(g) := AUTO_OK(g) ∧ AUTO_OK(MCOLLAPSE(g))`.
  Separates A (one recognition) from C (recognition surviving a metacursive turn).
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): no module has an AWARE glyph, and the only glyph named C (phonassoc.la) is unrelated.
  ⚑ **BUILT 2026-09-15, Track F — `[~]` pending landing, with a finding.** `aware.la` defines
  AWARE and C exactly as written and gates them over the catalogue: A ≡ C on EVERY sealed glyph,
  because MCOLLAPSE re-seals with CANON and so the metacursive turn always names itself truly; the
  only glyph failing C already fails A (the liar). The separation the item wants has no instance
  under canon's seal — reported. RED: a turn that keeps the old ren makes C fail on true glyphs.
- `[ ]` **`PROTO_AGENT`** — the one chain-tail item with an honest gate:
  REPAIR can move g strictly toward closure, with `swc.la`'s provably-ill class
  as the negative fixture. **Qualia/phenomenology: build nothing** until a paper
  formalises them; any gate now could not go RED.
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): no module has a PROTO_AGENT glyph.
  ⚑ **BUILT 2026-09-15, Track F — `[~]` pending landing.** `protoagent.la`: on an incomplete structure
  with a well-ordered composition REPAIR raises centropy 2→4 and the result is autological; on a
  complete one the gain is 0; on swc's ORDER-VIOLATION (the provably-ill class) the agent REFUSES and
  the structure is untouched. Nothing built for qualia. RED: the ill guard dropped. §27.
- `[✓]` **The Algebra of Naming's companions** — the Semiotic-Ontoglyphic Ladder
  (7 levels) and the Substitution Test; α is binary in code, graded in the paper.
  ⚑ **Verified 2026-09-10 — PARTIAL** (METANOĒ, against kernel-k1 `fcaaa23`): the Ladder is built and gated: ladder.la (L0–L7), build.sh's ladder block, and buildla's "LADDER VERDICT ? YES". The Substitution Test does not exist (0 mentions in ladder.la). Graded α was not verified.
  ⚑ **2026-09-17 — THE SUBSTITUTION TEST IS WRITTEN AND DERIVED, NOT YET RUN, ROW NOT MOVED.
  `substitution.la` (Track F), gate drafted at `gate_registers.sh` §37 behind `REGS_DRAFT=1`.** It builds
  the missing companion from `LINGUA_ADAMICA.tex` thm:deceptive (Deceptive Substitution): μ and I are
  computed separately, and a substitution is classified IDENTITY / DECEPTIVE(i) / DECEPTIVE(ii) /
  ADMISSIBLE ontoetymological navigation.
  **★ THE FINDING: clause (ii) NEVER FIRES INDEPENDENTLY OF (i) IN THIS LANGUAGE.** Over 39 probes — the
  live catalogue plus four constructed near-synonyms — there are **7 pairs whose μ is equal and ZERO whose
  invariants are incongruent.** The reason is structural: in Lingua Adamica μ(g) IS the κ-congruence class
  of g's invariants, so "same meaning" and "congruent invariants" are one predicate spelled twice. The
  theorem's clauses are independent in general; here they collapse, and the language is self-sanitizing by
  **monosemy alone**. That the search finds 7 μ-equal pairs and not 0 is what makes this a finding rather
  than a vacuous pass. **Only THREE of the four verdicts are reachable, and the module says so** rather
  than leaving a reader to find a missing fixture and assume an oversight.
  **[B] The scope:** this holds for the COMPUTATIONAL register, the only one κ sees. The phonetic and
  visual registers carry invariants NORMK does not — that is what trimodality asserts — so a substitution
  congruent computationally but divergent phonetically or visually is exactly where clause (ii) would earn
  its independence. Those are `phonym.la`/`sigil.la`, Track A's, and are NOT checked here.
  **On graded α: no change, and none needed.** `ladder.la` already handles it correctly — it stores the
  ORDINAL RANK and gates `DECIMALS_NOT_INJECTIVE` (levels 0 and 1 share α≈0), which is the whole ordinal
  argument. The 09-10 note "graded α was not verified" is satisfied by that existing gate.
  ✔ **RAN GREEN 2026-09-17 — gated §37.** The finding held on execution: **39 probes, 7 pairs with μ EQUAL,
  0 with incongruent invariants.** Clause (ii) never fires independently of (i) because μ IS the κ-congruence
  class of the invariants — the language is self-sanitizing by MONOSEMY ALONE. ★ **Clause (ii) is NOT dead
  code:** a mutant proves the branch is reachable — disabling μ does not make the test unsafe, because (ii)
  catches the substitution itself. That mutant was RE-LABELLED after it ran (my expected token was wrong and
  the real behaviour was better), and a third mutant disabling BOTH clauses is the genuine unsafe path.
- `[ ]` **The meta-word ablation gate** — remove one operator-glyph, assert a
  specific named derivation becomes underivable while the other four survive.
  Makes "a missing word is a missing thought" executable.
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): there is no glyph or gate for it. ablate.la's gated verdict concerns modes, not operator-glyphs.
  ⚑ **BUILT 2026-09-15, Track F — `[~]` pending landing.** `ablateop.la`: derivability from an
  operator set read off κ containment; ablate ∂ → ⊗(∂,δ) underivable while ⊗(γ,ρ) and the other
  four survive; ablate γ → the mirror; ablate 𝔄 (the control) → both survive. RED: a containment
  that always says yes collapses the control. `gate_registers.sh` §25.
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

- `[✓]` **★ Self-invocation — the paper calls it the deepest gap.** In the
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
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): it awaits a scope ruling, not a build. autopoiesis.la is gated at build.sh:4344 (the item's :3898); the item's own open question is whether that lineage meets the bounded target ruled on 09-06.
  ✔ **DONE 2026-09-10: RULED BY THE GENERAL, the gated lineage IS the bounded form** (recorded by
  METANOĒ at The Lieutenant's instruction). The General's words, as The Lieutenant recorded them on the board
  (`logos-status.md:20963`): *"Autopoiesis.la's gated lineage is the bounded form… the external gate
  starts it, the lineage continues itself. That is precisely the bound."* The Lieutenant's message to
  METANOĒ relays one more sentence: *"Gate it as the bounded implementation and move on."* So the
  General's ruling answers the open question above: the lineage meets the bounded target ruled on
  09-06. Nothing is built for this item.
  **The gate** is build.sh's block `say "Autopoiesis: the system runs its own successor …"`, at
  :4432–4479 on kernel-k1 `a1fd736` (build.sh blob `a299d9a`). It was :4343–4390 at `fcaaa23` (blob
  `7a1e216`); the merges moved it 89 lines, so cite it by the `say` line. It asserts that the lineage
  exits 0, that generations 0..3 each speak in order, that exactly 4 speak, that the lineage reports
  completion, and that the begotten successor is byte-identical to the bundle.
  **The bound, stated plainly (The Lieutenant's flag):** the internal condition that ends the lineage
  is a generation counter. Each generation reads its number from the medium (`autopoiesis.gen`), and
  the lineage stops at the cap of 3. It is not a sensed condition. The General re-rules only if a
  sensed condition was meant.
  **Not closed by this:** the meta-autontopoiesis Ledger row below. This file calls it distinct
  ("KEEP itself going", not BEGIN), while the white paper calls the two *"one referent under two
  names"* (WP:5787–5788, in the copy at `~/Downloads/CODICIES/On Writing/Lingua Adamica White
  Paper.tex`, sha256 `98beeff4ee45`). That disagreement is asked of The Lieutenant (ask `1789083624`),
  not settled here. The paper still grades self-invocation `[A]` at WP:4998 and WP:7456: those rows,
  and the identity passage WP:5780–5792, are P13–P15 in the master list.
  ↳ **Ruled the same evening.** The General, in The Lieutenant's session: *"Self-invocation only.
  Meta-autontopoiesis stays open."* This item stays `[✓]`. The meta-autontopoiesis Ledger row below is
  `[ ]` again, and its stamp carries the General's reasons. The paper rows: P13–P14 re-grade this item,
  P15 narrows the identity passage (WP:5787–5790), and P16 keeps the Ledger row at `[A]`.

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
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): the loop is still not closed unassisted: no organ executes what it adopts (self-meta-programming, above), and the successor must be byte-identical (meta-autopoiesis, above).
  ✖ **RULED 2026-09-10: STAYS OPEN.** The General typed it in The Lieutenant's session, and it was
  relayed to METANOĒ: *"Self-invocation only. Meta-autontopoiesis stays open."* The General's reasons,
  verbatim: *"The hand is present, and it is named — tiny_host. It is not removed."* *"The row's gate
  requires naming the removed hand and a red path. Neither exists. The hand is not removed, and the red
  path cannot be constructed — you cannot make a gate go RED on a bound that is genuinely present.
  Granting the row would make the gate vacuous. That violates the first law."* *"Self-invocation closes
  at the bound already ruled. Meta-autontopoiesis stays open, as a future build: a lineage that forges
  its bundle rather than re-invoking from one that was forged for it. That build is real. It is not
  done now."*
  **The named hand is `tiny_host`.** It emits the VM, compiles the stream and fuses the bundle inside
  the gate, before the lineage starts (build.sh :4447–4451 at `a1fd736`). Nothing was built tonight that
  this row lacked this morning. The self-invocation item above stays `[✓]` (`7d5982c`). The paper's
  identity claim (WP:5787–5790) no longer holds as written, and P15 narrows it.
  *(History: `bfd83d8` set this row `[✓]` on The Lieutenant's first answer to ask `1789083624`, and
  `e359fc7` set it `[~]` after the two flags below. The BEGIN/KEEP reading marked in `a42f437` is
  removed, because the ruling rejects it. The General's ruling returns the row to `[ ]`.)*
  ⚑ **The two flags** (METANOĒ; The Lieutenant invited flags and verified their lines), kept as the ruling's reasons. Two
  parts of this row say more than the gate witnesses. (1) *"producing the means of its own production"* (this row; WP:5785). The
  lineage COPIES its vessel. `autopoiesis.la` (blob `fcde785`) calls `execve` (:56), `fork` (:58) and
  `copy_self` (:67), and a search for codegen, compile, write_exec, tiny_host, secd.la and bundle
  finds nothing outside comments. The means (the VM, the compiled stream, the bundle) are made by
  `tiny_host` inside the gate, before the lineage starts (build.sh :4447–4451 at `a1fd736`). (2) This
  row's own gate, *"a full produce-its-own-means cycle … the gate names which hand it removed"*, and its
  red path, *"re-insert that hand and the gate must go red"*. The autopoiesis gate names no removed hand
  and has no such red path. The General ruled on them; see above.

- `[✓]` **★ LEDGER ROW — Meta-Ontosemantic Closure: `SLACKS ≠ ""`, not met
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
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): `CLOSURE` and `SLACKS` exist (aatc.la:23, :31), but no gate asserts a closure is met.
  ⚑ **2026-09-17 — MODULE WRITTEN AND DERIVED, NOT YET RUN, ROW NOT MOVED. `closure.la` (Track F),
  gate drafted at `gate_registers.sh` §35 behind `REGS_DRAFT=1`.** The row asks for `CLOSURE(x)` asserted
  for a NAMED x with a re-introduced slack entry as the red path. **The subject is named, real and SENSED,
  not stipulated** — that is the whole difficulty of this row, and it is why `wants.la` did not close it:
  its complete organ is `MODULE("organ-B")(TRUE)(TRUE)("")`, a fixture whose emptiness was DECLARED in its
  own constructor, and asserting closure of a structure you defined to be closed witnesses nothing. Here x
  is **the register stack's own gate suite**, read from disk, and its slack is COMPUTED:
  `SLACKS(suite) = a module the suite LISTS but does not CHECK`. The property is at genuine risk, because
  listing and checking are edited in different places. The ledger's own red path is exercised in-file, and
  `T_CLOSE` then resolves it with CENTROPY rising strictly.
  **★ The counts are printed but NOT pinned in the gate:** `listed` rises whenever a module joins the stack,
  so pinning it would turn ordinary growth into a false RED and teach the next person to edit the expected
  number instead of reading it. What is pinned is `examined:T` (the scan found a non-empty list — an
  instrument must prove it looked) and `all-listed-are-checked:T`.
  **★ WHAT IS NOT CLAIMED:** closure holds for THIS artifact under THIS residue criterion. NOT for the
  language, and NOT for the paper, whose own slack the paper publishes and which stands.
  ✔ **RAN GREEN 2026-09-17 — gated §35.** `SLACKS(gate_registers.sh) = ""` for a NAMED, SENSED subject with
  a COMPUTED residue; the ledger's own red path names `notgated.la` and drops centropy 3→2; `T_CLOSE` restores
  it. ★ **Not pinning the counts was vindicated by the run:** `listed` read 37, not the 30 derived hours
  earlier, because modules were added in between — a gate pinning the number would have gone falsely RED. The
  pinned property held. Both RED paths fire.
  ⚠ **This closes the CLOSURE half only. Meta-autontopoiesis stays `[ ]`** per the General's 09-10 ruling.

- `[✓]` **★★ ENGINEERING SEAL 2 — Proof-carrying glyphs. NOT BUILT, and it is
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
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): no module has a per-glyph certificate.
  ⚑ **2026-09-17 — MODULE WRITTEN, NOT VERIFIED, ROW NOT MOVED. `certify.la` (Track F).** A certificate
  is (a) an arity spine, (b) the hash-consed LINEAGE — a derivation the checker REPLAYS, deliberately not
  a stored ONF string it would compare to itself — and (c) a gate token that must occur as a line prefix
  in the gate suite; plus a coverage check over the whole catalogue and three in-file forgeries that must
  each be refused BY NAME. **It has never been run:** its first host run exceeded 550 s, the hot path was
  then threaded, and the deep-job lease went to the FULL AUDIT. It is NOT in `gate_registers.sh`.
  **★ Field (a) is genuinely blocked on the SEAL-1 ruling above and this module does NOT rule it** — (a)
  carries the one discipline that exists in code (a structural arity derivation), in a slot shaped so the
  ontic τ lands there the day Erik rules.
  ✔ **RAN GREEN 2026-09-17 — gated §33.** 35 entries, 35 certificates, all three fields verify BY
  RE-DERIVATION, all three forgeries refused by name. ★ **The coverage check needed a FIXTURE to be worth
  anything:** the sweep certifies every entry it SEES, so checking its output against the same list it swept
  CANNOT FAIL — the first version was a vacuous gate. It now sweeps a catalogue with one entry WITHHELD and
  must NAME it (`OFFENDER=KAPPA`). Both RED paths fire. ⚠ **Field (a) still carries only the arity discipline
  and the SEAL-1 RULING IS STILL OWED** — this row is `[✓]` for the certificate MACHINERY, which is what it
  asks for; the type system it will carry is Seal 1's row.

- `[✓]` **★ ENGINEERING SEAL 3 — Versioning without semantic drift.** §5024: a
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
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): no module has a migration or supersession law. E17 ruled U/Δ supersession, but it is not built.
  ⚑ **2026-09-17 — MODULE WRITTEN AND DERIVED, NOT YET RUN, ROW NOT MOVED. `migrate.la` (Track F),
  gate drafted at `gate_registers.sh` §34 behind `REGS_DRAFT=1`.** A registry of versioned glyphs plus one
  admission law: a revision is admitted iff the new form's ONF equals the old, so a form refinement passes
  and a SEMANTIC change is refused with BOTH ONFs printed; the same change offered as a FORK under a new
  name is admitted and is ADDITIVE; and the law is applied TO ITS OWN GLYPH both ways, which is the tex's
  "the migration law is itself a glyph". **The admitted revisions really change the form** (⊕ commuted,
  ↻↻→↻ — two κ routes, one ONF), so "cosmetic" is not a no-op fixture that would pass with the law deleted.
  **★ A VACUOUS GATE WAS CAUGHT AND REMOVED BEFORE IT SHIPPED:** the first draft also ran the Ratchet on the
  REVISION path, where it cannot fire — a revision that preserves the ONF has, by definition, the ONF it
  already had, which in a monosemic registry belongs to no other name. The ratchet moved to the FORK path,
  where a new name CAN collapse onto an existing form, and the header states why rather than leaving a dead
  check in to look thorough. Every witness was derived in python from the tex before the gate was written.
  ✔ **RAN GREEN 2026-09-17 — gated §34.** First execution matched every derived witness. Both RED paths
  fire: disabling the invariant check admits a semantic revision; disabling the ratchet lets a fork collapse
  onto an existing glyph's ONF.

- `[✓]` **★ The Recognition Depth function ρ(L_t)** (`LINGUA_ADAMICA.tex` §3842,
  a formal `\definition`): *"For a language state L_t at time t, the recognition
  depth ρ(L_t) is the number of distinct levels…"*. Distinct from `DEPTH`
  (`g₉`, a primitive) and from lexical depth D (computable from the DAG, ledger
  row above): this one measures the LANGUAGE's state, not a glyph's. Nothing
  computes it. **Gate:** ρ is computable from the live catalogue and strictly
  increases when a level is genuinely added. **Red path:** add a glyph at an
  existing level and ρ must NOT move.
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): no module has a recognition-depth function.
  ✔ **DONE 2026-09-17 — `recdepth.la` (Track F, branch `register-stack`), gated at
  `gate_registers.sh` §31.** ρ is COMPUTED from the live catalogue, not declared: a glyph's ORDER is
  catalogue-relative (0 for a primitive leaf; otherwise 1 + the max order of any catalogued glyph whose
  κ-form is a PROPER sub-form of it), and ρ(L_t) is the max order over the state. Orders settle by four
  passes of bounded relaxation and the pass count is printed, so an under-relaxed run is visible rather
  than silently low. **Measured: catalogue 35 entries, 34 κ-distinct, orders n0=9 n1=20 n2=5 n3=0, ρ(L_t)=2.**
  Every one of those numbers was derived independently from the tex definition in python before the gate
  was written. **The ledger's own red path is witnessed:** adding ⊕(BEING,LOVE) at an existing level
  leaves ρ at 2; adding ↻(ν*) — Δ* viewed as an object, the tex's level 3 — raises it 2→3.
  **ρ is shown NOT to be tree depth** (the row's own requirement that it be distinct from `DEPTH` g₉ and
  from lexical depth D): a form of tree depth 3 with nothing catalogued inside reads order 1 and does not
  move ρ; and ν* reads order 2 with the five mode glyphs catalogued, order 1 without them — ρ measures
  the LANGUAGE STATE, not a glyph's shape. **The κ-distinct count is the ρ ≡ SR_ABOUT identity being
  enforced, not assumed:** 35 entries collapse to 34 on exactly one κ-form, ↻(RECOGNITION).
  **Two RED paths, both exercised:** dropping proper-ness makes every glyph its own sub-form, orders run
  away and ρ reads 4; replacing order with tree depth makes the deep unregistered probe move ρ (order=3,
  ρ→3, `unmoved:F`). Forms owned by other modules are CITED and their declaration lines are read back
  from those files each run, so source drift turns the witness RED. **[B]** the catalogue is the register
  stack's published surface, not every glyph in every module; ρ over a larger catalogue can only be ≥ 2.

- `[✓]` **★ The Self-Evolution Equation** (`LINGUA_ADAMICA.tex` §3975): *"All
  five laws and three axes can be compressed into a single recursive equation
  governing the language's self-evolution."* The three axes (§3945) are
  autological, metalinguistic and ontological deepening. This is the closing
  form of the whole self-evolution chapter and nothing implements it. **Owed
  first:** it depends on ρ above — the equation is over language states, so
  build ρ first or this has nothing to range over.
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): nothing implements it.
  ✔ **DONE 2026-09-17 — `selfevo.la` (Track F), gated at `gate_registers.sh` §32.** The row's "owed
  first" is satisfied: ρ exists now (`recdepth.la` above), so the equation has states to range over, and
  this module imports it. The equation L_{t+1} = κ(Δ(L_t ∪ {g_X : X ∈ Ops(L_t) \ G_t})) is EXECUTED from
  a seed L_0 = the nine primitives alone (a language that names only reality, ρ=0) and iterated to its
  fixed point. `Ops(L_t)` is not invented: it is the operations the register stack actually implements,
  each carrying the κ-form its own module declares — the five modes, the five operators ∂δγρ𝔄, κ and 𝓡,
  Δ_E Δ_M Δ_R Δ_B, and ρ(L_t) itself. **Measured: 18 operations named, 17 κ-distinct** — ρ and SR_ABOUT
  are two names the modules really use and they mint ONE glyph, so the κ-keyed invariant is exercised
  rather than asserted (a name-keyed census would have read 18). **The run: |L| 9→26, ρ 0→2, density
  D 1000→2538, admissible rules 0→5, then a FIXED POINT at t=2 with nothing left unglyphed.**
  |L_0|=9 σ=9 D=1000 and |L_1|=26 σ=66 D=2538 were all derived independently in python first.
  **All five ontological laws are checked across every consecutive pair and each can fail:**
  Neologization (every unglyphed op gets its glyph), Compression (density never falls, σ = Σ|I(g)| with
  |I(g)| the count of distinct κ-sub-forms), Reflexive Ascent (ρ non-decreasing — the law that needed ρ),
  Autopoietic Deepening (the rule set never contracts), Centropic Irreversibility (every κ-string
  survives with its invariant set unchanged). **Two RED paths, both exercised and both NAMING the
  offender:** a lossy step that drops the union turns the Fifth Law F with `OFFENDER=DEPTH`; a mint made
  a no-op turns the First Law F with `OFFENDER=ρ(L_t) recognition depth`, ρ never leaves 0 and
  `nothing left unglyphed:F`.
  **★ THE BOUND, stated not blurred [B]:** this is ONE BOUNDED RUN over a FINITE, ENUMERATED Ops set —
  the operations this system has actually built. The tex's Infinite Deepening Theorem is NOT witnessed
  and is not witnessable by a terminating program. What is witnessed: the equation is executable, it
  closes on the operations that exist, and the five laws hold along the way.


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
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): there is no non-comment implementation. ELENCHOS's M58 build plan is a handoff (2026-09-10), and E17 ruled Rule 4 next.

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
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): it needs data from outside the system, as the item says.

- `[ ]` **A signature scheme.** No public-key primitive exists. **The single
  unlock for the whole record/law layer**: signed updates, identity, contracts,
  non-repudiable records, the Eternal Library. Everything in the Logocracy layer
  waits on this one primitive.
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): open on kernel-k1: no xmss or wotsp module or gate exists there (build.sh has 0 mentions). track-e carries the WOTS+/XMSS stack (15 files), unmerged.
- `[ ]` **Entropy on the metal** — no RDRAND/RDSEED builtin, no jitter
  collector, no seed file, while full-disk encryption must derive keys at boot
  before any disk read. A DRBG does not close this.
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): RDRAND/RDSEED appear 0 times in secd.asm, in the merged kernel's asm and in asm.la's mnemonics (control: `syscall` finds 115 in secd.asm).
- `[ ]` **Trans-species: a second functor.** One habitat renderer exists
  (`R_human`). `R_click` plus its inverse would make FSM a functor category with
  two objects — the minimum at which "trans-species" is witnessed rather than
  asserted. Actual animal comprehension stays out of scope, stated.
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): no module has an `R_click`.
- `[ ]` **The language deepens with its agents** — the loop optimises COST, never
  DEPTH or expressivity. Needs a depth-directed `selfopt` mode.
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): selfopt.la has no depth mode (blocked on M11c, above).

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

**Owed by the paper — the Track F freeze write-up, 2026-09-18.** Evidence tags: **[W]** a gate witnessed it on
tiny_host (per-module, 09-17) · **[B]** bounded or reasoned from the code, not run · none of it has run on the SECD VM
or in a full suite on HEAD yet (FREEZE-TRACKF.md). Each item says exactly how far it reaches — no further.

*Today's results:*
- **F4 — five properties the language asserted cannot all hold** [B, proven from the code; the confirming run waits for
  the lease]: (i) ↻(BEING) ≡ SELF, (ii) ↻(↻Y) ≡ ↻Y for every Y, (iii) congruence, (iv) the ↻ operator's glyph
  ↻(SELF) ≠ SELF, (v) form-level monosemy. (i)+(iii) and (ii)+(i) force ↻(SELF) ≡ SELF, against (iv). The code gave up
  (ii) at BEING — ↻(↻(BEING)) normalised to ↻(SELF), not SELF — while three records called ↻↻g≡↻g "true of every
  glyph". **Ruled (Erik, 2026-09-18): (c)** — ↻(BEING) ≡ SELF moves to the TRUTH register (it was always true in
  meaning: BEING = I, SELF = I(I) = I, ⟦↻⟧ = λg.g(g)), and ↻(BEING) keeps its own form; this gives up (v) for one
  pair, exactly as ¬¬C/C already does. Pending implementation in core after the freeze. **The paper must not say ↻² holds
  everywhere until that lands, and must say which register every identity it states lives in.**
- **F5 — η-equivalence is identity in the TRUTH register only** (ruled 2026-09-18). ONE = BECOMING(VOID) = λf.λx.f x is
  η-equal to BEING = λx.x: equal in truth, distinct in form. This REFINES the 09-17 correction "BEING is not one"
  (below): it is not one IN FORM; it is one IN TRUTH under η.
- **κ\* finds nothing to compress** [W, §36]: the live catalogue — modes, operators, self-relations, all 35 entries —
  is κ\*-irreducible (no compound sub-form recurs across two glyphs). A POSITIVE CONTROL proves the instrument can
  look (a planted recurring ↻(RECOGNITION) is found and sealed). A result about THIS catalogue, not about the operator;
  a larger catalogue could change it.
- **Δ_ν folds, and the fold costs structure** [W, §39]: a run of 5 movements folds to 1. ⚠ **"the second application moves
  nothing" is DEFINITIONAL (F32, 09-18)** — Δ_ν is a left fold, and a fold of a one-element list returns it (autocompress.la:63);
  do NOT present the fixed point as a finding. Node count RISES 18 → 22, one join per collapse. It compresses the NUMBER OF
  MOVEMENTS, not the size of the form. With §48 below: rest is bought with loss.
- **The gate could pass what it was built to catch** [B, method finding — the kin of "the monosemy check was running
  in one register out of three"]: exit codes were written and never read, so a module that printed its witnesses and
  then crashed PASSED; an identical crash on host and VM read "host == VM"; no check proved a RED token absent from
  the green output; and 30 of 49 sections pin values captured from a run rather than derived. Fixed in 6f16740 except
  the last (F20, open).

*The nine corrections from 2026-09-17, carried here from RESUME-2026-09-18.md so the paper track can see them* [W, each gated]:
1. ⚠ **UNWITNESSED (F25, 09-18):** "The Three Laws are NOT derived from the Archē" — §44's removal test is VACUOUS (its
   signature function never uses the GROUND it is handed, so nothing was removed). May hold by inspection; not yet shown.
2. ⚠ **DEFINITIONAL (F32, 09-18):** AUTO_OK compares a ren with CANON, which applies no rewrite — so it cannot consult the
   Archē BY DEFINITION; §44 t4's "they DISAGREE" is guaranteed by the fixture. True, but by inspection, not a discovery.
   The criterion is CO-PRIMITIVE with the Archē too (§44) — the ground is a SMALL SET of four, not a point;
   consistent with derive_closure's 4 of 9.
3. Divergent compressions do NOT converge on κ (§48): six compressions, six outputs, five never rest; only deletion
   rests, by discarding — CONVERGENCE AND RETENTION ARE IN TENSION.
4. The cross-branch collapse holds BY CONSTRUCTION (one sealer), not convergence (§46) — over 19 branches, not 28.
5. Logic, algorithm and syntax are pairwise SEPARATE (§43); the true relation is the neologizing dyad.
6. ⚠ **CORRECTED (F26, 09-18):** §47 witnesses only one = BECOMING(VOID); "BEING is not one" is PRINTED TEXT (ND_BEING unused).
   Decoded as a numeral BEING IS one. Per the F5 ruling: BEING and ONE are distinct FORMS (ungated as yet) and EQUAL IN TRUTH.
7. ⚠ **DEFINITIONAL (F32, 09-18):** the measure horizon (§47): four κ-distinct forms share one numeral — true because the
   numeral is DEFINED as tree size, which cannot see a mode label. Bound it to "measure = node count"; not a discovery.
8. No Shannon noise in the computational register (§42); the real bound is the RENDERER's (sigil.la walks the unfolded
   form — a DAG renderer would survive ~40× deeper).
9. The three collisions named on 09-17 do not exist (§49).

*Paper-vs-gate conflicts found in the finished papers and the Codex Llogoscribeologiae* — every paper swept repeats at
least one claim the gates refute (one axiom as the ground, convergence on the Archē, 28 branches, associativity,
"encryption impossible", g(g)=g for every glyph): the full list with line numbers is `sweeps/19-FINISHED-PAPERS-SWEEP.md` §4
and `sweeps/20-LLOGOSCRIBEOLOGIAE-SWEEP.md` §4–§5.

**Paper-side structural work:**
- `[ ]` Fix "trimodal" wherever a fourth modality exists.
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): the white paper (sha256 `98beeff4ee45…`) says "trimodal" 51 times and names a fourth (tactile) modality 3 times; tactile.la exists.
- `[✓]` The Ledger is a plain `tabular` and cannot break across pages; at 37 rows
  it still fits, but the next batch overflows SILENTLY. Convert to `longtable`.
  ✔ **Verified 2026-09-10 — DONE** (METANOĒ, against kernel-k1 `fcaaa23`): the white paper (sha256 `98beeff4ee45…`) sets §The Ledger in a `longtable` (:7422). No gate can see it, because the paper is outside the repo, so the change is not dated.
- `[ ]` Every Tier-1/2 item above needs its paper counterpart at the right tag —
  an item is not done until code and paper agree.
  ⚑ **Verified 2026-09-10 — OPEN** (METANOĒ, against kernel-k1 `fcaaa23`): this is a standing rule, and it closes only when every Tier-1/2 item is done in both code and paper.

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
