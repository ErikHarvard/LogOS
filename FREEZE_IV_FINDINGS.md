# Freeze-Day Audit IV — the self-asserting Lingua Adamica witnesses

**2026-08-27.** Audit II triaged `build.sh`. Audit III triaged the standalone
`gate_*.sh`. Both are shell. The assertions inside `.la` modules were covered by
neither. Tool: `audit_la_witnesses.py`.

## The surface, and why only half of it is new

* **Externally asserted** — `canon.la`, `metalogic.la`, `aatc.la` and friends
  print a witness string that `build.sh` greps. Those assertions live in
  `build.sh` and were **already Audit II's surface**. Not re-audited.
* **Self-asserting** — 19 modules judge themselves with the `MARK` idiom and the
  gate compares the whole printed line to an expected constant. **96 checks.**

A `MARK` that goes WRONG changes the printed line and the gate goes red, so these
checks *are* wired. What no tool had asked is whether any of them **can** go
wrong.

## Result: 96 checks, 3 cannot-fail, ZERO new

The three are the already-known `wrong-PK` family — `wotsp.la:231`,
`wotsp_prod.la:70`, `xmss.la:204` — each asserting `pkA != FLIPS(pk)` while a
neighbouring `MARK` asserts `pkA == pk`, so each reduces to `pk != FLIPS(pk)`,
true by construction of `FLIPS`.

**The rest of the witness surface is clean**, and that is a real result rather
than a failure to find something. Audit III found fourteen new dead checks in
shell; the LA witnesses have one family. The detector separates them from the
honest negatives by construction: `NEQ(pkC)(pk)` — the tampered-signature
control — is the identical *shape*, but `pkC` is bound to a real recomputation
and no positive `MARK` unites it with anything, so no path exists and it is
correctly left alone. Shape alone would have condemned every negative control in
the codebase.

---

## ★ THE REAL FINDING OF THIS AUDIT IS THE INSTRUMENT

**The first version of this tool parsed 51 of 96 checks and reported CLEAN.**

Seven modules — `naming.la`, `trimono.la`, `alethe.la`, `siginj.la`,
`phonorm.la`, `entropy.la`, `ontofelicity.la`, **45 checks** — yielded *nothing*,
and the summary said `cannot-fail: 3` with no indication that almost half the
surface had never been read.

There are **two MARK idioms**, and the tool implemented one:

```
Idiom A   glyph MARK = la ok. la name. IF(ok)(concat(name)(" OK"))(…)
          called   MARK(str_eq(pkA)(pk))("genuine verifies")     -- two groups

Idiom B   glyph MARK = la c. IF(c)(la _. "OK")(la _. "FAIL")
          called   concat(" | T2 ")(MARK(T2))                    -- ONE group,
          the name is the preceding string literal and the boolean is a SYMBOL
          defined by its own `glyph`, so it must be resolved to be analysed.
```

★ **`--selftest` passed while this was true.** It verified that three known-dead
checks were flagged and that the honest negatives were not — all three fixtures
happened to use idiom A. A calibration that tests *detection* and not *coverage*
certifies a tool that reads a third of the input.

★ **And this is the same lesson twice in one day.** Audit III's tool asserts that
all three shell failure idioms are seen, precisely so a missed idiom cannot
produce a clean sweep — that check was written *because* `gate_bootelf.sh`'s
`die "…"` would otherwise have been invisible. Building that guard into one tool
and omitting it from the next, hours later, is the shape worth recording: the
lesson was learned as a fact about `gate_*.sh`, not as a property every audit
instrument needs.

**What caught it was arithmetic, not the calibration**: 96 occurrences surveyed
before the tool existed, 51 parsed after. `--selftest` now accounts for **every
`MARK(` occurrence in every `.la`** and fails if any is unparsed. It passes, and
the re-run with both idioms reads 96/96 and still finds exactly the three.

## FINDING 2 — the binding-defeated shape: detectors built, ZERO instances

Audit III found `gate_selfext2b.sh:38` asserting `[ -e logos_app ]` on the line
after `rm -f logos_app` — a check **defeated by an adjacent line** rather than
implied by a neighbouring assertion. The MARK-equality union-find cannot see the
LA analogue, because it only learns equalities that a positive `MARK` *asserts*,
never ones a `la` binding *creates*. Two detectors now close that:

* **D1 — vacuous positive.** A positive `MARK` whose operands resolve, through
  the `(la NAME. BODY)(ARG)` chain, to the **same expression**: it compares a
  value to itself and is vacuously true.
* **D2 — binding-defeated negative.** `MARK(NEQ(u)(F(w)))` where `u` and `w`
  resolve to the same expression: the `wrong-PK` shape reached through bindings
  instead of through MARKs.

**Result across all 123 modules: zero instances.** The three hits remain the
known `wrong-PK` family, all found by the original MARK-union path.

### ★ The first negative control was invalid, and it fired

Track A's rule — *planted controls only prove the tool sees what you built it to
see* — is why both detectors were planted-and-proven before the sweep was
believed. The planted positives fire; a live variant must not.

★ **The first live variant DID fire, and the fixture was the defect.** It read:

```
MARK(str_eq(a)(b))("real equality")      <- unites a and b
MARK(NEQ(b)(FLIPS(a)))("real negative")  <- therefore implied
```

The two values were bound to *different* expressions, so D1 and D2 correctly
stayed silent — but the fixture also **asserted `a == b` with a positive MARK**,
which legitimately makes the negative implied. The original detector fired, and it
was right to. A control meant to demonstrate a clean case contained the very
defect it was meant to exclude. Replaced with one where no `MARK` unites the two
operands: positive control 3 hits, negative control 0.

That is worth keeping as its own lesson. A negative control is a claim about what
*should not* happen, and it is as capable of being wrong as the assertion it
guards — here it would have been read as a false-positive rate in the tool rather
than as a bug in the fixture.

## INS-4 and INS-5 — Track A's two, same class, worse consequence

Recorded here because the INS class spans both audits and is the through-line of
the day. Both are Track A's, both from 2026-08-27, both verified before recording.

### INS-4 — a dependency scan matching on basename

A scan for untracked files that `build.sh` or a gate depends on matched
`basename $f` against the script text. `.bootelf_fix/asm.la` has basename
`asm.la`, which appears in `build.sh` referring to the **tracked** `asm.la` at repo
root. **45 false positives**, each confidently formatted with a "depended on by:"
line and a real file list.

★ The same substring trap as the ` no` scan that matched the word "NOT" inside
Track A's own archclosure gate — **third instance in one day, in three different
tools, all written after the class had already been documented that morning.**

### INS-5 — the same scan then UNDER-reported, and only acting on it revealed that

Tightened to exact-path matching, it reported **15** untracked root-level source
files. The real figure was **24**. Missing from it: `prop.la`, `opgrammar.la`,
`discourse.la`, `immune.la`, `metaprop.la`, `selfext2.la`, `selfext4.la`,
`gate_selfext0.py`, `gate_selfext4.sh` — core arc modules `build.sh` depends on.

They were found by **acting** on the scan (staging the 15) and re-checking what
remained, not by trusting it. Two further probes then contradicted each other on
whether `discourse.la` was ignored, resolved by asking `git status --porcelain`
directly rather than inferring from either.

★ **The lesson is not "tighten the regex."** It is that **a scan whose output you
are about to act on must be reconciled against an independently obtained count
BEFORE you act** — the same reconciliation that caught INS-1 (96 surveyed before
the tool existed, 51 parsed after). The instrument was available and was not
applied to the scan.

### Why these two matter beyond bookkeeping

Acting on the corrected list caught that **24 files had never been added to git at
all** — including the mutation lever and the Ratchet Gate. The prior session had
staged what it *modified* and never noticed what it *created*. The commit would
have produced a checkout that **cannot build**: `prop.la`, `opgrammar.la`,
`phonseal.la` and eight gate scripts simply absent. Staged set 23 → 50.

**Verified independently in `~/logos` before recording:** 50 files staged, and all
ten named files now tracked — so they were untracked when the report was written.

★ An under-reporting scan was **one re-check away from shipping a broken
foundation**, and what saved it was *distrusting the instrument rather than
improving it*. That is the strongest single argument the freeze produced for the
INS class being worth naming at all.

## ★ INS-6 — a completion check that only recognises success

**The subject is the MONITORING, not the build.** Build 5 behaved normally and was
killed deliberately by Track A at 18:49 after its tree was superseded by commit
`9112c18`; `cob.la`, where it stopped, is not a hazard — build 4 passed it
(`PASS  Cycle of Being … the derived geometry ENACTS B&B's cosmogenic cycle`,
followed by Meta-phonosemantics; verified in `build4_20260827_133817.log` before
recording this). **Build 5's ending is a restart, not a defect.** What the episode
exposed is how it was watched.

### Three instances, all the same door

1. **A waiter that only recognised success** *(Track A)*. `until grep -q
   BUILD_FINISHED_MARKER; do sleep 30; done`. Had the build died rather than been
   killed, it would still be waiting — on a process that no longer existed, with
   nothing to report. Replaced with a marker-OR-no-build-process condition that
   **names which ending occurred** (`ENDING=completed` vs `ENDING=DIED — no build
   process and no finish marker`) rather than falling silent.

2. **★ A progress report quoting a count without checking the count moved**
   *(Track A, and the sharper of the two)*. Build status was reported as
   "142 PASS / 0 FAIL, still running" **three times across 24 minutes** — 02:03,
   02:24, 02:27 — all three at the same section header, all three at 142. *"Still
   running"* was true. *"Progressing"* was implied and never checked. The report
   was drawn from a counter that had stopped moving, and nothing asked whether it
   had.

3. **A green-looking log for a build that never completed** *(Track E)*. Read by
   counts, build 5 is unambiguously healthy: 142 PASS, zero FAIL, not one failing
   line anywhere. It simply stops, mid-section, with no verdict under the header,
   no `BUILD_EXIT` and no finish marker. Reporting it as "142 PASS / 0 FAIL" —
   which was about to happen — states only true things and leaves a false
   impression.

### The rule, and its corollary

> **A completion check that only recognises success is silent through every other
> ending** — and silence is indistinguishable from *still running*.
>
> **Corollary:** a progress report that only quotes totals is silent through every
> stall. Quoting a count without checking the count *changed* is the same defect
> in the other tense: both mistake absence-of-bad-news for evidence.

What caught it was the waiter exiting on **either** the finish marker **or** the
build PID vanishing. Marker-only would have waited indefinitely on a dead process;
counts-only would have reported a clean build. Neither would have been false, and
both would have been wrong.

★ Track A has since been stating build status as *"N PASS / 0 FAIL, STILL RUNNING,
has not completed"* rather than as a verdict, and both commit messages say in terms
that neither is backed by a completed clean build. That phrasing is this door, not
caution for its own sake.

## ★ INS-7 — a perturbation test needs a control that the perturbation HAPPENED

The mirror of INS-1. There, a sweep reported CLEAN on input it never parsed. Here,
a *perturbation* test reports GREEN on input it never perturbed — and the honest
reading of that green is **"the gate does not catch this,"** a false negative that
reads exactly like a finding.

**How it nearly happened (Track E, 2026-08-27).** Erik asked for `NORMK` to be
perturbed so ⊗ sorts its operands, to prove the new monosemy assertion could go
red. The sed was written against `REWRITE_SYN` — the wrapper in Track A's *current*
`canon.la` — and run against Track E's checkout, which still has `WRAP2`. **It
matched nothing.** The file was copied unchanged, and the next step would have run
the unperturbed pair, seen `order ⊗ : DISTINCT`, seen the assertion GREEN, and
concluded the gate was vacuous.

What stopped it was one line:

```sh
cmp -s canon.la canon_perturbed.la && { echo "NO CHANGE APPLIED — aborting"; exit 1; }
```

**The same class from the other side (Track A).** A probe with a parse error
emitted zero rows, and `None != None` printed a confident *"red"* about a property
it never evaluated. Both are **the instrument reporting on input it did not have**
— one by failing to change it, one by failing to read it.

> **A test whose subject is a CHANGE must prove the change landed, exactly as a
> sweep must prove it looked.** `cmp` before the run; a row count before the
> verdict. Absent that, a green means "nothing was tested" and a red means
> "something else broke," and neither is distinguishable from the result.

★ It also inverts the usual polarity, which is why it is easy to miss. Everywhere
else in this freeze, the danger is a check that **cannot go red**. Here the danger
is a check that **goes green for want of a stimulus** — and green was the answer
that would have been *reported as a finding*. The failure mode wears the costume of
success in one case and of discovery in the other.

**The result, once the control was in place:** one token (`WRAP2` → `SORT2`) flips
`order ⊗` from `DISTINCT` to `COLLAPSED` and the assertion goes RED, with all five
sibling rows unmoved. Confirmed independently by Track A against their own
`REWRITE_SYN` normaliser. The `c58a133` replacement discriminates; its predecessor
(`grep '^comm ⊗'`) matched a row emitted by nothing and could only ever fail.

## What this audit does NOT establish

* **It still under-reports.** Equalities now come from positive `MARK`s *and*
  from `la` bindings, but an equality created by neither — two symbols made equal
  by a glyph-level definition chain, or by a computation the tool cannot see
  through — remains invisible. That is the safe direction for a triage tool, but
  it is a real bound.
* Binding resolution follows the `(la NAME. BODY)(ARG)` idiom to depth 8 with a
  cycle guard. A witness built some other way is not resolved.
* Expression parsing is balanced-paren, not a real LA parser.
* **A clean report is not evidence a witness can fail.** 93 checks were not shown
  to be able to fail; they were only not flagged.
