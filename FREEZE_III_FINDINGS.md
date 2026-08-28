# Freeze-Day Audit III — the standalone gates

**2026-08-27.** Audit II triaged `build.sh`'s ~600 assertions by discriminating
power. It never looked at the standalone `gate_*.sh` scripts and could not have:
`audit_gates.py`'s FAIL-line regex is `echo "FAIL` and its section parser expects
`build.sh`'s `say "..."` idiom. The standalone gates use **three** failure idioms
and have no sections.

Tool: `audit_standalone_gates.py`. **16 gates, 142 assertions parsed, 90 flagged.**

## The instrument was calibrated before it was believed

`--selftest` runs eight checks and refuses to endorse a clean report without them:

* the **four known-dead** lines (`gate_sha256.sh:41`, `gate_wotsp.sh:94`,
  `gate_xmss.sh:79`, `gate_xmssidx.sh:123`) must be flagged — all four are;
* `gate_xmss_signer.sh` must **not** be flagged — it is not. This is the negative
  control and it is the hard one: that gate contains both `VMOUT = E_SIGNER` and
  `VMOUT = HOSTOUT`, in mutually exclusive arms of `if SIGNER_VM_ONLY`. A detector
  without branch awareness flags it, and a triage tool that cries wolf gets
  ignored — Audit II's first run flagged three false positives at top severity;
* all **three** failure idioms must be seen: `echo "FAIL` (13 gates),
  `printf 'FAIL` + `fail=$((fail+1))` (`gate_asmelf.sh`), `die "..."`
  (`gate_bootelf.sh`, 17 seen). Miss one and a third of the surface is silently
  uncovered while the sweep reports clean.

★ A reporting tool whose own harness is dead reports ABSENCE and is believed.
Run `--selftest` before believing anything else this file says.

---

## ★ FINDING 1 — six redundant triangles, two of them new

**18 G-implied hits = 6 triangles × 3 members.**

| gate | lines | values |
|---|---|---|
| `gate_sha256.sh` | 31, 39, 41 | HOSTOUT / VMOUT / EXPECT |
| `gate_wotsp.sh` | 86, 89, 94 | HOSTOUT / VMOUT / E_SMALL |
| `gate_xmss.sh` | 67, 75, 79 | HOSTOUT / VMOUT / E_XMSS |
| `gate_xmssidx.sh` | 89, 122, 123 | HOSTOUT / VMOUT / E_IDX |
| **`gate_selfext5.sh`** | **67, 68, 69** | **H / V / HELD_OUT** — NEW |
| **`gate_selfext6.sh`** | **46, 62, 63** | **CH / CV / HELD_OUT** — NEW |

Every one has the same shape: `X = E`, `Y = E`, `X = Y`. Three comparisons among
three values where **two carry all the information**.

★ **This corrects the way the finding was first stated.** On 2026-08-27 it was
described as "the third line is implied by the first two." That is not right — it
is a **triangle**, and each of the three is implied by the other two. So the
finding is not "the `host != VM` line is dead"; it is **one assertion per triangle
carries no information**, and *which* one you drop is a real choice.

The fix is not deletion, it is re-pointing. Compare the host to the derived
expectation and the **VM to the host**: identical total strength (both engines
wrong the same way still fails against E; the VM wrong alone still fails), every
line live, and each red names what actually broke. `gate_xmss_signer.sh` is built
that way and is why it is the negative control.

★ `gate_selfext5.sh:69` is worth reading for its own sake. Its message ends *"This
is a failure, not a note"* — a line written with conviction, that cannot fire on
its own.

**NOT FIXED HERE.** Four of the six are green gates and two are Track A's. A gate
that is dead-checked is not a fire; changing what a gate compares against without
its owner, or before `gate_wotsp.sh` has ever had a baseline run, is backwards.

**INDEPENDENTLY CONFIRMED by Track A** (2026-08-27), who verified all three of
`gate_selfext5.sh`, `gate_selfext6.sh` and `gate_sha256.sh` by hand in `~/logos`
and checked the strength argument: `H=E ∧ V=H` is equivalent to `H=E ∧ V=E`, with
both lines individually live — the first fires when both engines are wrong
identically, the second when the VM alone is wrong. No loss, no dead line.
The fix is **queued, not applied**: build 5 is mid-run and `gate_sha256.sh` has
already executed in it, so editing now would make that build test a tree that
never existed as a coherent whole — worse than the defect. All three will be
fixed after it lands and will need their own build to verify.

★ Also confirmed: my read of `gate_selfext5.sh`/`gate_selfext6.sh` was taken at
12:36, **after** Track A's 12:33/12:34 edits, so the triangles are in the current
files and not an artefact of a torn read of a live tree.

## ★ FINDING 2 — THE UNGATED SET, and why it is where defects survive

`gate_bootelf.sh` and `gate_rss.sh` appear **nowhere** in `build.sh` — confirmed
independently by Track A. Both may be deliberately manual (`gate_bootelf.sh`
wants an `ours.o` from an isolated VM cycle; `gate_rss.sh` was the GC-fix
acceptance test), but *intentionally manual* and *orphaned* look identical from
outside, and each needs one line saying which it is.

★ **This is the third instance of the same pattern in one day.** The instances and
the pattern name are **Track A's** — nine `.la` modules with no runner, eight more
marked `[✓]` in `LA_COMPLETION.md` with none at all, and the formulation *"the
ungated set is where every other defect class survives."* The generalisation below
is Track E's, and is recorded in `LA_COMPLETION.md`'s governing section as such. **The ungated set is where every other
defect class survives, because an unrun gate cannot catch anything by
construction.** Every audit in this project — Audit II's discriminating power,
this one's cannot-fail comparisons — asks *"can this check fail?"* of checks that
RUN. None of them asks *"does this check run?"* of the whole inventory. That
question has now produced three hits in a day, entirely as a by-product.

An inventory pass — every gate and every module-with-a-witness, cross-referenced
against what `build.sh` actually invokes — is cheap, static, and on today's rate
the highest-yield freeze work available.

## FINDING 3 — a gate that consumes an artifact it never builds *(Track A)*

Found and fixed by Track A on 2026-08-27, recorded here because it is a **defect
class this tool does not detect** and belongs in the freeze record.
`gate_selfext5.sh` and `gate_selfext6.sh` both ran `./logos_secd` **without ever
building it**, inheriting a VM that some earlier `build.sh` section left behind —
and the section that last touches it DELETES it. `selfext5` went red on the first
build that ever reached that line, with `No such file or directory` standing in
for a verdict. Both now build their own VM.

★ Track A's observation is the sharp one, and it is the same shape as the
triangles: *it is exactly the failure arm C exists to catch, arriving through the
door arm C does not watch.* Arm C proves the VM leg fails when the VM is
**REMOVED**; it says nothing about the VM never having been **BUILT**. A check can
be perfectly live and still leave its own precondition unwatched.

Track A has a `preflight_artifacts.py` for this surface: it walks `build.sh` and
every `gate_*.sh` for uses of an artifact the script never creates, **scanning
each gate as a fresh script with nothing guaranteed** — which is the actual
contract, since a gate may be run standalone. It found the `selfext6` defect
before it could fail. Different surface from the cannot-fail-comparison detector;
the two compose.

## ★ FINDING 4 — the presence-only pass: 23 tests, and the serious ones are GUARDS

**First, a correction to this document's own number.** It said 29 presence
assertions. The true count is **23**, and the 29 was an artefact of
`audit_standalone_gates.py` classifying on a 6-line lookback window: an assertion
whose real test is a string comparison still lands in `E-presence` if any presence
test appears above it. The same window that makes the classifier find assertions
makes it over-count classes. **17 are verdicts, 6 are guards** — and both of the
serious findings are in the 6, not the 17. A wrong verdict is loud; a wrong guard
is not.

### The 17 verdicts, classified

The discriminator is not "is this presence-only" but **did the producer get a
chance to act between the cleanup and the check?** — and, for positive checks, **is
the artifact's content asserted anywhere else in the same gate?**

| class | n | verdict |
|---|---|---|
| **★ DEFEATED — cannot fail** | **1** | `gate_selfext2b.sh:38` |
| LIVE negative control | 2 | `gate_selfext2.sh:68`, `gate_selfext6.sh:77` |
| precondition, content checked elsewhere | 10 | asmelf_extern:43 · selfext2:37,38 · selfext2b:50 · selfext4:32 · selfext5:39,43,70 · selfext6:35,57 |
| input validation (`die` on missing input) | 4 | `gate_bootelf.sh:57,58,59,61` |

**16 of 17 are sound.** That is worth stating plainly: presence-only is not a
defect per se. `gate_selfext6.sh:35` checks `[ -f sx6_organ.la ]` and line 36
greps the file for the exact glyph the search claimed to compose — existence is
the precondition, not the verdict. `gate_asmelf_extern.sh:43` rejects an empty
object and line 44 hands it to a byte-comparison. These are cheap preconditions in
front of real assertions, and rewriting them would buy nothing.

### ★ The one that is defeated

```
gate_selfext2b.sh:37   rm -f logos_app logos_program.bin logos_embed.bin logos_source.la
gate_selfext2b.sh:38   [ -e logos_app ] && { echo "FAIL  selfext2b: logos_app exists before the
                       run — its origin cannot be attributed to the organ"; ok=0; }
```

The gate's header states the property: *"BEFORE the run, ./logos_app must NOT
exist… If logos_app existed beforehand, the vessel could have been anyone's."*
That is a **provenance control**, and it is the discriminator the whole gate rests
on. **The line immediately above it deletes the evidence.** Nothing runs between
37 and 38 — the organ does not execute until later — so the assertion tests that
`rm -f` succeeded. It can fail only on a permission error or an immutable file,
never for the reason it gives.

★ The property is still *achieved* — the `rm` does guarantee the organ creates the
vessel. What is absent is the *check*. The line documents the guarantee without
testing it, and would keep passing if the `rm` were ever removed and a stale
`logos_app` left behind. This is the `wrong-PK` shape by a different mechanism:
not *implied by a neighbour* but **defeated by a neighbour**.

**The contrast is what makes it a finding rather than a style note.** The other
two negative checks have the identical `rm` … `[ -f X ] &&` shape and are both
LIVE, because the producer runs in between:

* `gate_selfext2.sh` — `rm` at 61, the organ runs at 63 in `bad` mode, check at 68.
  The organ had every opportunity to write a child and must not have.
* `gate_selfext6.sh` — `run6()` does `rm -f sx6_organ.la` *then* runs the organ;
  check at 77. Same structure, same soundness.

So the fix for `selfext2b:38` is not to delete it — it is to **move the check above
the `rm`**, where it tests what it claims, and let the `rm` follow as cleanup.

**NOT FIXED HERE** — `gate_selfext2b.sh` is Track A's, and it is already in their
queue behind build 5 along with the triangles and the silent-skip.

## ★ FINDING 5 — did the evidence come from EXECUTION, or from READING?

The `selfext2b` chase ended somewhere more general than it started, and this is
the finding most likely to outlive the specific gates.

`gate_selfext2b.sh` runs `gate_selfext2b_safety.py` at line 29 — a **static**
analyser whose `ORGANS = ['selfext2b.la']` reads the organ's source — and exits 1
if it goes RED. The prerequisite skip is at 32-34, *after* it. So the mutation
lever's chain for this organ is:

```
mutate selfext2b.la → its exec surface changes → safety analyser RED
                    → gate exits 1 at line 30 → [CAUGHT]
```

The mutant is caught **before the gate reaches the skip, let alone the organ**.
The lever records coverage; the behaviour was never exercised. Behavioural
coverage of `selfext2b.la` is **zero in every build so far**, and the mutation
score reports it as covered.

★ **A static analyser and a behavioural gate can both go RED, and only one of them
is evidence the code works.** Every audit in this project asks whether a check can
fail. This asks a prior question: *when a check did fail, did the thing that
caught it EXECUTE the subject, or merely read it?* Track A's inventory pass asks
"does this gate run?" — this is the same question one level up, and the mutation
score is exactly where it bites.

### The detector, and why it is structural rather than incidental

Measured by Track A across build3: **20 `[CAUGHT]` lines, 19 carrying
`"% of the Ns green baseline"`, 1 without** — and the single outlier is the entry
independently established as bogus. Perfect separation.

★ It works for a reason, not by luck: **the ratio is computed against the gate's
own runtime, so it cannot exist when the gate never ran.** The marker is tied to
the defect structurally rather than correlated with it, which means it will keep
working as mutants are added. A `[CAUGHT]` with no ratio is a mutant caught before
its gate executed.

Track A is folding this into the inventory pass as a second column: for every
mutant, **what caught it, and did that thing execute the subject.**

## The rest of the worklist

| class | n | what it means |
|---|---|---|
| Z-unclassified | 40 | shape not recognised — hand-read |
| G-string-eq | 39 | plain string equality; strong when the expectation is derived |
| **E-presence** | **29** | `[ -f ]`/`[ -s ]`/`[ -x ]` — a file existing is not a file being correct |
| D-exit+diag | 7 | exit code plus diagnostic |
| F-threshold | 5 | absolute threshold — a resize can void it silently; prefer a ratio |
| C-pattern / A-byte-identity | 2 / 2 | |

**E-presence is the next real pass.** Twenty-nine assertions check that a file
*exists*. `gate_selfext5.sh:43` — `[ -f sx4_organ.la ]` — passes on a zero-byte
file, and `[ -s ]` passes on one byte. The 40 Z-unclassified are mostly `case`
arms, which this tool's branch tracking does not model; they need eyes.

## What this audit does NOT establish

* **No gate was run.** This is static analysis; it says nothing about whether any
  gate currently passes.
* **`case` and `&&`-chains are not branch-tracked**, so a `case`-guarded pair can
  still false-positive. None of the six triangles is `case`-guarded — each was
  confirmed by hand.
* A clean line is not a live line. The 52 unflagged assertions were not shown to
  be able to fail; they were only not flagged. Each still needs one human line:
  **the input that would make it go red.**
* The `wrong-PK` family (defect 5, in `wotsp.la`/`wotsp_prod.la`/`xmss.la`) lives
  in `.la` witness code, not in shell. That surface is untouched by this tool and
  is the natural Audit IV.
