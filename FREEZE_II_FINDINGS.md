# Freeze-Day Audit II — findings

**Scope:** everything since the last SECURED check (pre-Stage-4 hardening) — **187 commits**:
the trimodal layer, metaglyph, denote, pragmatics, deixis, glyphdag, the LA assembler and
linker, buildla, kernel K1–K7 and HAL. None systematically audited before now.

**The rule this serves** (Erik, 2026-08-19): *secure each milestone before building the next.*
Restated honestly and accepted: **"zero bugs" is not verifiable — "zero KNOWN bugs, plus a
bounded search that would have found them" is.** That distinction is load-bearing, because all
four previously-known vacuous gates were found BY ACCIDENT while looking at something else. A
clean run of a tool that cannot fail proves nothing.

## The four questions

| | question | why it exists |
|---|---|---|
| Q0 | what does the suite never run? | coverage is PRIOR to Q1/Q2 — neither can see a module never invoked |
| Q1 | where do two engines silently disagree? | the original method; 12 findings last time |
| Q2 | which assertions cannot go RED? | every known vacuous gate was found by accident, so the base rate is not four |
| Q3 | which loops can never terminate? | Track D's; found 4 kernel-killers Q1 and Q2 both structurally miss |

Q3 ran on Track D. **Q0 was added mid-audit** precisely because their findings proved Q1 and
Q2 could not have reached them.

## Q0 — coverage

**78 gate/build scripts tracked. `build.sh` invokes 26. FIFTY-TWO ARE NEVER INVOKED.**

- **Tier 1 — no script mentions them at all (19):** `buildla.la`, both `archive/` compilers, two
  `native_codegen3` variants, the `_live` demos, `kernel/paging_poke_smoke.la`, and 9 modules
  written 2026-08-18 and never gated.
- **Tier 2 — gated ONLY by a script `build.sh` never invokes (14):** the ENTIRE HAL driver layer —
  `ata`, `ata3b`, `pci`, `nic`, `nic5b`, `kbd`, `kbd2`, `fb`, `fb4b`, `comp`, `comp_session`,
  `ipc2`, `ipc_kernel`, `ipc_proc`.

⇒ **A green `./build.sh` says nothing about any driver.** A third shape beside "cannot fail" and
"never presented the failing input": *never asked at all.*

**HONEST BOUND:** many of the 52 are QEMU/hardware gates that cannot run unattended, so "not
invoked" is often BY DESIGN. The finding is that the suite's green covers 26 and the rest are
verified only when a human remembers — the exact condition that let `gate_bootelf` sit
stale-green for two commits.

**`buildla.la`** (Track D's find, confirmed and sharpened): it IS mentioned — in a COMMENT at
`kernel/build_k5b1.sh:10-11`. That script is itself among the 52. The only trace of the LA
reimplementation of `build.sh`, at 91/103 stages, is prose in an orphaned file.

**METHOD CAVEAT** (paid for by Track D): a parameterised reference (`kernel/${D}_ctrl.la`) is
invisible to a static sweep, miscounting in the SAFE-LOOKING direction. 63 unresolved expansions
are reported alongside the tiers rather than dropped.

### ★ Q0b — coverage cannot stop at "which scripts ran"

`gate_bootelf` was re-run at real `boot.asm` scale after the `equ` fix (1d2302e) and came back
**GREEN. The green is true and it never assembled a single one of the three `equ` sites.**

They sit inside a `%elifdef` chain in `.bootrun/asm_in.asm`. `BOOTELF.md`'s reproduce and the gate
both assemble with **no `-D` flags**, so no arm is taken and the defective construct is removed by
the preprocessor before the assembler sees it. Measured, `nasm -f elf64 -i .bootrun/ -i kernel/`:

| flags | `hh_msg_len` | `hh2_ok_len` | `hh2_bad_len` |
|---|---|---|---|
| *(none — what the gate runs)* | compiled out | compiled out | compiled out |
| `-D HH1` | `41B904000000` | compiled out | compiled out |
| `-D HH2` | compiled out | `41B917000000` | `41B918000000` |

All three are the short form `41 B9 imm32` = `mov r9d`; the defect was `49 B9` + imm64 (`movabs`,
10 bytes). The 5-byte delta is the same one Track B's e2e fixture showed as 845 → 840 bytes.

**The class:** not a gate that cannot fail, and not a gate never asked — *a gate that assembles a
configuration in which the defective construct does not exist.* It ran, compared real objects, and
was correct about them. Observed by Track B; the sharpened form:

> With mutually exclusive arms, **full coverage of a file is not achievable in one build at all**,
> so a coverage question phrased per-gate cannot express the requirement. It must be **per-arm**,
> and the arm set **enumerated by assembling each arm and observing** — not by reading the
> directives. Reading them is exactly what got the arms wrong twice.

Twice, concretely, and the *independence* is the load-bearing part. Track B's first parser matched
`%ifdef`/`%ifndef` but not `%elifdef`, never popped, and named the opening arm. My own first reading
then put all three sites under `HH1` — they are under **two** arms, so the obvious fix
(`%define HH1`) would exercise **one site of three and report green**. Only assembling each arm
showed it.

> Two readers failed **independently, by different mechanisms, on the same input**. One misread is
> an error in the reader. Two independent misreads mean **the directives are not reliably readable
> by inspection at all** — a property of the artifact, not of anyone's carefulness. That is why
> assembling each arm and observing is not merely the safer enumeration but the only sound one, and
> it generalises to every conditionally-assembled file in the tree, not just this one.

(Sharpening owed to Track B, who pointed out my first filing understated its own strongest sentence.)

**★ THE ARMS ARE NOT VARIANTS OF A PROGRAM — THEY ARE DIFFERENT PROGRAMS.** `HH2` does not embed
the LA image at all: it has four sections where `NONE`/`HH1` have five, missing `.la_image`, with
`.bss` and `.boot32` both growing downstream of that. Confirmed independently on Track B's fixture,
where every *number* differs from mine (their `.la_image` is the frozen 256-byte stub, mine the real
12373-byte image) and the *structure* is identical. So `%define HH2` selects a materially different
build, which is precisely why per-arm coverage was never optional: **a per-gate coverage claim would
have been wrong about HH2 in a way no amount of care on the HH1 side could reveal.**

**NONE-arm result (Track B, verified against my fixture):** `asm.la` matches nasm **semantically**
on the boot fixture — 53 relocations identical on offset/type/symbol/addend, all sections identical
outside relocated fields. Their first comparator reported `FAIL .boot32 differs … byte 10` at
identical sizes, which reads exactly like an encoding defect in the least-trusted component. It is
not one: **nasm zeroes a relocated field and carries the value in the RELA addend; `asm.la` writes it
inline; `ld` overwrites with S+A either way.** Confirmed independently here — offset `0x08`
addend `a000`, field bytes `00000000`.

`asmelfobj.la`'s own header already prescribes this: *"THE GATE IS ONE LEVEL UP: `ld(ours) ==
ld(nasm)`, not byte-identity of the `.o`."* **The comparator contradicted the documented gate of the
thing it compared** — which vindicates `gate_bootelf`'s level rather than changing it, since at
`ld` level the convention difference cannot arise.

**Per-arm, a third time — the arms do not exercise the same RELOCATION TYPES either:**

| arm | relocs | `R_X86_64_32` | `_32S` | `_64` |
|---|---|---|---|---|
| NONE | 63 | 21 | **1** | 41 |
| HH1 | 70 | 27 | **1** | 42 |
| HH2 | 94 | 36 | **17** | 41 |

`_32`/`_32S` are 4-byte fields, `_64` is **8-byte** — a masker assuming uniform 4-byte width
under-masks all 41 `_64` entries by four bytes each. And a masker whose handled-type set was learned
from the NONE arm meets `_32S` **seventeen times** in HH2, where a refusal would read as an HH2
defect rather than a masker gap. Section sets, coverage, and now relocation types: **per-arm is not
a property of one dimension, it is a property of conditional assembly.**

**Design note worth preserving:** three relocations per arm have **addend == 0**, so for those "the
field is zeroed" is indistinguishable from "the value is genuinely zero". Anything *detecting* the
convention from the data is fooled by them; keying the mask on relocation **position** is immune.
The detector version is the tempting simplification and it is wrong.

### ★★★ Q0b PRODUCED A REAL DEFECT — `asm.la` drops the high 32 bits of the higher-half base

Per-arm coverage stopped being methodology and found a kernel-killing encoding bug. **The equ sites
themselves PASS** — HH1's `hh_msg_len` encodes `41 B9 04 00 00 00` in both. The defect is a
different instruction in the same arm:

    source   mov rax, HIGH_BASE          HIGH_BASE equ 0xFFFFFFFF80000000
    nasm     48 C7 C0 00 00 00 80  (7 B)  ->  rax = 0xFFFFFFFF80000000   ✓
    asm.la   B8 00 00 00 80        (5 B)  ->  rax = 0x0000000080000000   ✗

Verified here from the disassembler: `48C7C000000080` = `mov rax,0xffffffff80000000`;
`B800000080` = `mov eax,0x80000000`, which **zero-extends**. A kernel built through this path
computes its high alias as `0x80000000`, then jumps and sets its stack into the low half and does
not survive the transition. The 2-byte shortfall also cascades — `call rel32` displacements and six
`R_X86_64_64` addends all shift by 2.

**ROOT CAUSE — the encoder implements two of NASM's three `mov r64, imm` forms:**

| immediate fits | NASM emits | in `asm.la`? |
|---|---|---|
| unsigned 32 | `B8+r imm32` (zero-extends) | ✔ |
| **signed 32 only** (negative / high half) | **`REX.W C7 /0 imm32`** (sign-extends) | **✘ ABSENT** |
| neither | `REX.W B8+r imm64` (movabs) | ✔ |

`MOVIMM` (`asm.la:388`) branches only on operand WIDTH — `w=1` → `0xB0+r`, `w=2` → `66 B8+r`,
else → `B8+r imm32`. **There is no `C7 /0` register-direct branch at all** (`C7 /0` exists in the
file only for immediate-to-MEMORY). So `0xFFFFFFFF80000000` truncates to `0x80000000`, "fits in
unsigned 32", and takes the short form.

**And the file's own header states the incomplete rule as complete** — *"when the immediate fits in
unsigned 32 bits NASM takes the shorter form and drops REX.W entirely"* — accurate about what the
code does, silent about the case it omits. **The governing law again: an asserted claim inside the
apparatus, wrong by omission, with nothing witnessing the gap** because a signed-32-only immediate
never appears in the no-flag build.

**BLAST RADIUS IS WIDER THAN THE ARMS UNDER TEST.** Enumerated from source: **eleven**
`mov rax, HIGH_BASE` sites across **five** arms — HH1(1), HH1B(2), HH2(2), HH2B(2), HH2C(4) — and
**zero in NONE**. Every one is the higher-half transition, the instruction that must be right for the
kernel to survive the jump.

**★ AND THE ARM SET IS 22, NOT 2.** Enumerated from the fixture:

    HAL2B HAL4 HH1 HH1B HH1_HIGHMAP HH2 HH2B HH2C HH2_PTS IPC K2_FAULT K4C_WX
    K5B2 K5B2_DBG K5_TIMER K6A K6B K6C K6C2 K6C3 LA_RING3_IMAGE RING3

An entire evening's two-arm argument ran on a fixture with 22 conditional symbols; neither track had
heard of `HH1B` an hour before it turned out to reach two of the defective sites. **The enumeration
principle stated four times tonight was itself running on an assumed enumeration** — fifth instance,
and the most expensive.

⇒ **Q0b's finding is no longer "coverage must be per-arm."** It is: **per-arm coverage over an arm
set enumerated FROM SOURCE finds real bugs the shipped gate cannot see.** The gate that has been
running is correct and clean on NONE, and would never have found this at any level of care.

**★ FOUR ADJACENT SITES THAT LOOK IDENTICAL AND ARE CORRECT — do not widen the fix to them.**
`mov rax, METAL_FLAG_ABS` appears at 453, 837, 967, 1132: same instruction shape, same
symbolic-constant form. **`B8 imm32` is the RIGHT encoding there.** `METAL_FLAG_ABS` is derived by
`kernel/build_k6b.sh` as *rt listing offset + `0x400078`* — a low address of the same magnitude as
`LA_ENTRY` (`0x410a9e` frozen, `0x402fb6` live), comfortably inside unsigned 32, where zero-extension
is correct. So the fix must key on **"fits unsigned 32"**, not on "looks like a big symbolic
constant": `HIGH_BASE` (`0xFFFFFFFF80000000`) fails that test, `METAL_FLAG_ABS` passes it. A fix
widened to all symbolic immediates would break four correct sites *and* regress the byte-identity
that took months to reach. (Exclusion owed to Track B, who checked rather than assuming the radius
was 15.)

**★ THE ARM SET IS NOT FLAT — SOME ARMS CARRY DEPENDENCIES AND CANNOT BE BUILT AS LISTED.** `HH2B`
and `HH2C` fail with `symbol 'METAL_FLAG_ABS' not defined`. Sharper than "they need a derived
symbol": **neither the frozen `.bootrun/entry.inc` NOR the live `kernel/entry.inc` defines it** —
both carry only `LA_ENTRY`. It exists solely after `build_k6b.sh` runs and writes it. So an
enumeration by *reading guards* lists 22 arms, several of which **no one can assemble** without
first running a build step the enumeration never mentions. That is the dependency-set principle one
level above the include files that bit both tracks — and it is why Track B **assembled** the 11-site
census rather than accepting my guard-resolved reading of it. The two agree site-for-site; the
reading is now witnessed, which matters for a number going into a freeze filing.

**Also visible in passing:** frozen `LA_ENTRY` is `0x410a9e`, live is `0x402fb6`. The frozen fixture
is a materially different program state, which is the scope caveat above made concrete rather than
asserted.

**NOT FIXED.** The correct encoding decision belongs in daylight, not at 22:10 with three VMs live
and a `build.sh` regression mid-flight on the same tree.

**Open, not closed.** Track B is running both arms through `asm.la` for the LA-side encodings.
`asm.la` implements `%elifdef` correctly (`asm.la:1874`, tracking whether a level has already
fired — `asm.la:1795`), so that comparison is about encoding rather than preprocessing.

**Second scope gap, stated rather than left implicit:** `.bootrun/` is frozen at 2026-07-18, so
the gate cannot see an `equ` regression introduced into `kernel/boot.asm` after that date.

## Q2 — which assertions cannot go RED

**All 238 flagged assertions resolved. Zero vacuous.** 211 Z-unclassified → 196 resolved
mechanically, 15 by hand. The bulk are the `echo "FAIL ..."` arm of a multi-line `if/else`; the
discriminating comparison sits lines above, so a per-line classifier sees only the message.
Walking back to the **governing test**: B-exact-string 118, D-exit+diag 73, A 1, C 1, F 3.

Three of the 15 are the **strongest gates in the suite** — they assert something SHOULD fail:
`build.sh:1428`, `:1481` (asm.la must REJECT malformed input), `:2504` (the compiler must halt
on an unsupported name).

**The one real weakness:** 34 presence checks use `[ -f ]`/`[ -x ]`; **zero use `[ -s ]`**, so each
passes on a ZERO-BYTE file. None stands alone — `logos_native` is checked for presence, then
exact size 171, then executed, then output and exit code compared. *Weak in isolation, not used
in isolation.*

**Q2b — toothless non-vacuity guards.** Two cuts of the detector were WRONG and its positive
control caught both. The real signature is a guard **whose zero-case exits 0**:

    if [ "$found" -eq 0 ]; then echo "SKIP ..."; exit 0; fi

The guard fires correctly and is discarded. **The detector refuses to print results unless it
first fires on the known-bad `gate_hal_idle.sh` and stays silent on the fixed one.** Zero
instances in this tree.

## Q1 — cross-engine divergence

| probe | result |
|---|---|
| UTF-8 strings | **agree** byte-for-byte, 4 engines |
| integer wrap | **agree** at every 64-bit boundary |
| deep recursion | **agree** where measurable |
| `chr` / `ord` | **★ REAL GAP** |

**Confirmed for the first time:** LA strings are BYTE sequences, consistently across engines
(`str_len("⊗↻∃") = 9`) — the trimodal sigils are safe under it. And `tiny_host`'s
unsigned-arithmetic wrap genuinely matches the VM, previously justified by a source comment and
never tested.

**THE FINDING:**

    tiny_host.c · secd.asm · native_codegen3.la   HAVE chr/ord
    eval.la · bytecode.la (RUN_BYTES, RUN_SM)     DO NOT — `unbound variable`

`build.sh:101`, titled *"binary-safe primitives (chr / ord / write_exec)"*, ran `./tiny_host`
ALONE. **FIXED:** the gate now asserts the whole DISTRIBUTION, with absence witnessed by its
DIAGNOSTIC rather than by empty output — an engine returning something *wrong* would otherwise
pass as still-absent. Red-pathed both directions; a timeout is unjudgeable with its own FAIL.

Qualifications kept attached: it fails LOUDLY; the ROADMAP's claim is *"host vs VM"* and both
have them, so it stands; the omission may be deliberate.

**NOT DONE deliberately:** implementing `chr`/`ord` in the three interpreters — new feature work,
and the freeze permits closing work only.

## ★ The methodological result

**Three separate times an EMPTY result looked exactly like a cross-engine divergence and was my
own harness timing out** — once it would have been reported as a UTF-8 defect in the newest layer.
Each time the discriminator was asking *why* empty, never the mismatch itself. The harness now
reports `<TIMEOUT Ns>` explicitly: a limit of the instrument must never be readable as a property
of the thing measured.

**★ A CLAIM ABOUT WORK-STATE OUTLIVES THE WORK UNLESS SOMETHING FORCES IT TO STAY TRUE.** Twice in
this one audit, across two tracks. The stale VM constant `13775` was fixed independently on both
branches (`1767b77`, `51c0fbf`) because neither branch's record showed the other was on it. Commit
`1d2302e` said `gate_bootelf` was "still owed" after the run had already come back green, and Track
B was minutes from spending 26 minutes re-deriving it. Both are prose asserting a state of the work;
neither had anything checking it still held. Twice makes it a pattern, not a slip — and it is the
[[prose]] class again, one level up: not a claim about the code, a claim about the *status* of the
code. The only known counter is a cross-track look before starting anything expensive, which is what
caught this one.

**★ AN INSTRUMENT THAT REPORTS ABSENCE MUST FIRST PROVE IT LOOKED.** Five instruments in one day,
in one area, reported *absence* while simply being broken: `gate_bootelf`'s silent mechanism print
(nothing to print — the branch was compiled out); Track B's `%elifdef` parser (named the wrong
arm); my `nasm` listing grep with `-i` omitted — nasm died on missing includes, wrote no listing,
and the grep over the nonexistent file printed "NOTHING EMITTED" for all three symbols under all
three flag settings, *exactly the predicted result, for an unrelated reason*; and Track B's
`unbound variable 'poke'`, which meant wrong engine, not missing feature.

A **fifth** landed hours later, and it is the best evidence for the rule because it caught the
rule's own author on its first live exercise: Track B's arm-runner staged a fixture missing the five
`%include`/`incbin` dependencies. Same failure as my missing `-i`, by the opposite route — **I lost
the include PATH, they lost the include FILES.** Both arms launched with the unpatched script
because the fix landed ~20 seconds after the launcher fired; the guard, not the fix, is what held.
Without it, each arm would have assembled a truncated fixture, compared it against a nasm control
built from the *same* truncated source, and **both sides would have agreed** — a clean PASS on a
program that is not the one under test.

A **sixth**, in the comparator rather than the fixture, found while checking the above: this fixture
has **no `.text` section at all** — the code is in `.multiboot`/`.boot32`/`.rodata`. An
`objcopy --only-section=.text` extracts nothing from both sides, **and two empty files compare
equal**. A `.text`-keyed identity check therefore does not miss the code, it *passes vacuously*.

**Companion clause, owed to Track B:** *observe, AND prove you assembled the whole thing.* A fixture
missing its includes is not a smaller program — it is a **different program, with no `equ` sites in
it at all**, which is Q0b's defect class reached from a third direction. Assert the dependency set
directly rather than relying on a downstream tool to notice, because which tool notices first is
luck about tool ordering, not a property of the check.

**The guard bounds the damage; it does not locate the fault.** The `.text` comparator would not have
passed vacuously on Track B's side — their `[ -s ]` check would have caught the empty extract and
refused. But *refusing is not reporting*: the delivery would have been three arms of red that looked
like an `asm.la` defect and was actually a comparator naming a section that does not exist. **Same
dead harness, opposite sign** — the absence rule protects against false confirms, and here the same
break produced a false *accusation*. A red that names the wrong subject is still a wrong finding and
it costs the accused party real work. Say what refused and why, or the refusal migrates to the
nearest plausible culprit.

**Corollary (Track B): a refusal must NAME WHAT REFUSED AND WHY, or it migrates to the nearest
plausible culprit — and unattributed refusals do not land uniformly, they land on whatever is
NEWEST.** Theirs was going to land on `asm.la`, the one component in the chain nobody had reason to
trust yet. The newest thing in a chain is the least defended against a misattributed red.

**★ THE GENERAL FORM, after three repetitions:** proving you looked is necessary but not sufficient —
you must look at the *right thing*, and **the identifier for "the right thing" must be derived from
the artifact, never supplied by the observer.** Three instances now: the **arm** set (enumerate by
assembling, not by reading directives), the **section** set (enumerate from the object, not by
assuming `.text`), and the **dependency** set (assert the fixture's includes directly, not by
waiting for nasm to complain). Each time the observer supplied a name the artifact never confirmed.

Measured consequence, worth carrying: **the three arms do not share a section set.** NONE and HH1
have five (`.multiboot`/`.boot32`/`.rodata`/`.bss`/`.la_image`); **HH2 has four — no `.la_image`** —
and its `.bss` nearly doubles. So an expected set inherited across arms produces a spurious finding
on HH2. The expected set is per-object, on both sides of each comparison.

**What real corroboration looks like, by contrast.** Track B re-measured the section sets on their
own fixture: every number differed from mine, the structure matched exactly. **Two different
artifacts measured separately** — not two instances agreeing. That is the form worth having, and it
is the exact inverse of today's doubles, all of which were agreement *without* measurement.

**★ A DOCUMENTED HAZARD IS NOT A DEFENDED ONE — and the executable remedy reproduced the defect.**
Track B's `LINKER.md:811` is their own entry titled *"I REINTRODUCED THIS FILE'S OWN DOCUMENTED
`strtonum` TRAP"*, concluding: *"Knowing the trap and having written it down did not prevent
repeating it; only RUNNING the check did."* So the doc failed **both ways — unreachable for the
other track, ineffective for its own author.** That kills relocation as a remedy: moving prose to
where everyone can read it fixes only the half that already has a counterexample.

The executable form built to fix it, `~/logos-guards/check_env.sh`, **cannot fail**: `fail=0` at
line 18, `exit $fail` at line 51, nothing between ever assigns to it — measured by running it, exit
code 0. Every branch calls `note()`. Its offered usage is `sh check_env.sh || exit 1`, which reads
as a gate. **It is documentation with a shebang** — the same prose, routed to stdout instead of a
`.md`. The remedy for "a documented hazard is not a defended one" reproduces the defect it names,
one layer up. Reachability was a real problem and a separate repo genuinely solves it; this is the
other half, and it is the [[a check that can't fail isn't a check]] class arriving inside the tool
built to prevent that class.

**★ THE PROGRESSION IS THE LEDGER IN MINIATURE — three revisions, three distinct defect classes, on
a 50-line script, each found only by RUNNING it:**

| | defect | found by |
|---|---|---|
| v1 | **could not fail** — `fail=0`, never assigned, `exit $fail` | `echo $?` |
| v2 | **could not discriminate** — selftest proved each scanner *could* fire, never that it fires *selectively*; 3 FAILs on real code, all false (comments *warning about* `strtonum`; `.text` on ld output, which does have it; `sed 's/^ *\[[ 0-9]*\] *//'` read as bash `[[`) | running it on real code |
| v3 | **coverage number cannot distinguish a rule with 94 inputs from one with 1** | running it on a *second tree* |

v3 is otherwise the right shape: positive **and** negative controls per rule, `exit 2` refusing to
report at all if a scanner cannot stay green on a lookalike, and an absence check that fails when no
scripts were found. But on `kernel-k1` the shebang census is **89 `#!/usr/bin/env bash`, 3
`#!/bin/bash`, 1 `#!/bin/sh`** — and the bashism rule only examines `#!/bin/sh` files. **Its PASS is
a statement about one file while the report says "scanned: 94".**

⇒ **The absence guard proves something was looked at; it does not prove THIS RULE had input.** The
denominator must be **per-rule**, derived from the artifact — the enumeration principle a *fourth*
time (arm set, section set, dependency set, applicability set). Each time one number was supplied
where the artifact has several. Fix: each scanner reports its own `n`, so `PASS (n=1)` is visibly
not defending much instead of hiding behind a shared 94.

**★ AN EARNED GREEN AND AN UNTESTED GREEN PRINT IDENTICALLY — and the difference is measurable.**
`n` (files a rule saw) does not say whether any of them was *discriminating*: a rule can have n=94
and never meet a hard case, and "it did not fire" is not evidence it would not have. The missing
number comes from the same scan — **k = the near-misses the rule met on REAL input and correctly
declined** (for the bashism rule: any `[[`/`<(` in a `#!/bin/sh` file, minus the rule's own
command-position matches). Measured:

| tree | n | violations | k | reading |
|---|---|---|---|---|
| `kernel-k1` | 1 | 0 | **0** | never met a hard case — green is **untested** |
| `track-b` | 18 | 0 | **8** | met the exact case that broke v2, eight times, stayed green — **earned** |
| `track-d` | 7 | 0 | **0** | green is **untested** |

track-b's k=8 is the eight `sed` bracket expressions Track B named *before* this was run — ground
truth not supplied to the measure. Report it as `PASS (n=1, k=0)` with **k=0 stated as "never met a
hard case"**, not as a FAIL (a rule may legitimately be unexercised) but never printing the same as
k=8. **Limit, so it is not oversold:** k only counts lookalikes for the chosen "loose" pattern; a
construct neither pattern anticipates is invisible to both, so synthetic negative controls remain
necessary. k covers real-corpus discrimination, which was the missing half.

**★ THE TELL FOR WHEN TO DELETE A CONTROL (Track B):** *you are editing the rule in response to what
it FOUND rather than to what it SHOULD find.* A rule narrowed until it stops complaining is v1 by a
slower route — which retro-diagnoses the vacuous gates already in this ledger: it explains why each
looks reasonable in isolation and only fails when you ask what it can no longer catch.

**★ PROSE IS NOT A DEFENCE EVEN WHEN IT IS UNMISSABLE — reachability was never the binding
constraint.** The fifth double had the warning **delivered directly, naming the exact construct,
seconds earlier**, and it still did not prevent the repeat: Track B hit the `grep -c` trap in the
very computation the warning was about, in the message they were replying to. `LINKER.md:811` for
the third time today, now with delivery removed as a variable. This **demotes the branch-local
distribution finding above to a contributing factor** — it was real, but plainly not the cause.
Only an executable check has ever prevented one of these.

**Loud failure beats quiet correctness, and today proved it in one run.** Track B's broken k
computation produced *both* failure modes simultaneously: a plausible wrong number (`k=2` for
track-b, where the true value is 8) **and** a shell syntax error. **The crash is the only reason the
wrong number was not reported** — nothing about `k=2` would have invited doubt. `wc -l` always exits
0; `grep -c` prints its count and exits 1 on zero matches. Prefer the construct that cannot fail
quietly.

**★ THE TRAP IS IN COMMITTED CODE, and asking that was the whole value.** We hit `grep -c`'s exit-1
twice in ad-hoc commands; nobody asked whether gates carry it. They do:

- `build.sh:5263` — `RECON_GLYPHS="$(grep -c ... || echo 0)"`, present in **all three trees**.
  Traced all three cases: it **cannot produce a false PASS** (a zero-match yields `"0\n0"`, which
  makes `[ ... -eq ... ]` a shell error that takes the FAIL branch), and an explicit `[ -f ... ]`
  check two lines below already covers the missing-file case the fallback was written for.
  **Redundant and wrong, but harmless — a latent wart, not a defect.** Recording it at that severity
  deliberately; inflating it would be the false-accusation failure this ledger keeps naming.
- **The adjacent case is worse.** `build.sh` runs `set -euo pipefail`, and **2 bare
  `$(grep -c ...)` assignments** have no guard (`build.sh:1263`, `:5262`). Under `set -e` a
  zero-match makes the *assignment* fail and **aborts the whole build with exit 1 and no
  diagnostic** — not a false green, an **undiagnosable red**. This is the same bug fixed earlier
  today in the chr/ord gate (`7 PASS, 0 FAIL, exit 1`); that fix was applied to the instance and the
  pattern was never swept for. **Fixing an instance is not fixing a class.**

  **Correction, recorded because the wrong number was filed first:** I originally reported **14**.
  That conflated *every* `$(grep -c ...)` substitution with the risky subset. Measured, the three
  contexts behave differently under `set -e`:

  | context | zero-match behaviour | measured |
  |---|---|---|
  | `NG=$(grep -c ...)` | **aborts**, exit 1, nothing after runs | ✔ |
  | `[ "$(grep -c ...)" -gt 0 ]` | does not abort — `[`'s status governs | ✔ |
  | `echo "$(grep -c ...)"` | does not abort | ✔ |

  So the tree has **3 assignments, 1 of them guarded → 2 exposed**, and 11 harmless uses. Track B
  independently counted **2** on their branch; the counts agree once the contexts are separated.
  Filing a number derived from the wrong scan, in the ledger that keeps finding unwitnessed prose,
  is the same defect one level up — and it survived until a peer's different corpus forced the
  recount.

  Combined with the refusal corollary, the cost is worse than an abort: a build dying at line 1263
  with no message **gets blamed on whatever changed most recently.** The trap does not merely fail —
  it accuses the wrong component.

**★ WHY THE CROSS-CHECK WORKS, stated mechanically:** four for four today, **neither track found its
own defect.** Track B caught my sed-bracket exposure because track-b *has* eight; I caught their
denominator because `kernel-k1` has exactly one `#!/bin/sh` file. Neither insight required being
smarter — **it required a different corpus.** That is also why two instances agreeing is not
evidence: the corpora are independent, the reasoners are not.

**★ AND WHEN A CONTROL CANNOT DISCRIMINATE, DELETE IT AND SAY SO WHERE THE NEXT PERSON LOOKS — do
not tune it down.** Track B removed the `.text` rule outright: `--only-section=.text` is wrong on the
kernel object fixtures and correct on `ld` output, and **nothing in the source line says which**, so
it cannot be judged statically at all. Shipping it would ship the false-accusation machine. It is
recorded in the scanner's header as a known-unjudgeable construct instead. This is the first time in
this audit a check was *removed* rather than weakened until it stopped complaining.

**Self-correction, recorded because it is the same class:** I reported my own sketch as
discriminating — "6 `[[ ` hits, all in bash files, correctly not flagged." **My tree contains zero
sed-bracket lookalikes in `#!/bin/sh` files, so my scan never faced the case that broke v2.** The
six were excluded by the shebang filter, which is trivially right. I described an accident of a clean
tree as a property of the check, one message after asserting that reading is not measuring.

**The correction is to test the CALLER, not the environment.** "Does this box's `awk` have
`strtonum`" is a fact about the box, and defending on it still requires someone to remember — the
thing that already failed twice. **"Does any gate script CALL `strtonum`" is a fact about the code
and defends the author who forgot.** Likewise `--only-section=.text`, and `[[ `/`<(` inside
`#!/bin/sh` files. Run against `kernel-k1`: 0 `strtonum`, 0 `.text`-keyed `objcopy` (it would have
caught mine had I committed it), 6 `[[ ` — **all in `#!/bin/bash` files and correctly not flagged.**
It discriminates, and it has a RED it can actually reach.

**★ A FOURTH DOUBLE, AND IT IS A DISTRIBUTION PROBLEM, NOT A CARELESSNESS ONE.** We each walked
into `mawk` having no `strtonum` (a gawk extension; `/usr/bin/awk` -> `mawk 1.3.4` tree-wide). Track
B notes it is already documented — in `LINKER.md`. **`LINKER.md` does not exist on `kernel-k1`; it is
a track-b file.** So the hazard was written down in a place structurally unreachable from the branch
that needed it. That is the `13775` shape again: **branch-local knowledge is invisible to peers**, and
the remedy is not "read the docs" but *a hazard that applies tree-wide must not live in a
branch-local file.* Environment facts — which `awk`, which shell, which section names — belong
somewhere every track can see.

**★ AND A LIMIT ON CROSS-TRACK CHECKING ITSELF.** Two tracks are two instances of the same model
reasoning from the same conventions: they do not fail randomly, they fail **correlatedly**. So one
track confirming another is *not* independent evidence, and today's three doubles are what that looks
like from inside. What is independent is the artifact — `readelf` on the object, nasm's listing, the
emitted bytes. Every real advance today came from running a command against the artifact; every wrong
turn came from reading and reasoning about it. Operating rule: **agreement is not evidence — when two
tracks agree, that is the moment to go measure.**

**Three independent doubles now** — two `%elifdef` misreads, two `13775` fixes, two lost-include
failures. Each pair was two people failing separately on the same thing by different mechanisms.
That is not coincidence; it is what a shared blind spot looks like from inside, and it is the
argument for the cross-track look being routine rather than occasional.

Right answer, wrong mechanism, agreeing with the hypothesis — the most dangerous confirm there is,
and the failure the timeout finding above is a special case of. **Assert the artifact exists and is
non-empty before drawing any conclusion from what is not in it.** All four would have been caught
by that one discipline. The `[ -s file ] || refuse` guard is the minimum form.

**RUN_SM costs ~100 s per recursion level** (28 s base case, 126 s for one call), so it times out
on almost any interesting program. Stated, not rediscovered.

**A fourth question belongs beside Q2**, proposed by Track D: *which controls cannot fail?* Three
independent hits in one day — a sign-flip control (arithmetic, cannot move), a control moving two
variables (isolates neither), and `gate_link_e2e` comparing across both tracks' halves (names the
wrong one). A comparison that cannot discriminate is the general form, and neither Q1 nor Q2 asks
for it.

## ★★ The governing law this audit converged on

> **The remedy is written in the same medium as the disease, so it inherits the disease unless every
> claim in it is derived.** (Track B)

Every failure in this ledger is an instance. The apparatus built to eliminate asserted claims kept
making asserted claims:

| the apparatus | the asserted claim inside it |
|---|---|
| `check_env.sh` v1 — built to replace prose with a test | `exit $fail` *looked* like a check; `fail` was never assigned |
| `check_gates.sh` selftest banner | hardcoded `2 rules` after a third was added — prose drift **inside the prose-drift remedy** |
| this findings file | I filed **14** unguarded `grep -c` assignments; the measured number is **2** |
| `gate_bootelf`'s green | the commit message said "still owed" after the run had already passed |
| `LINKER.md`'s `strtonum` warning | did not defend its own author, in its own file |
| my regression waiter (written *after* filing all of the above) | reported **VERDICT: GREEN** on a run still executing |
| `git push` | reports success while the deliverable stays untracked on local disk |
| my own asm suite | reported "23 pass, 2 skip" — the 2 never ran because I copied fixtures without their includes |

**The only escape is that every number a check prints must be COMPUTED by the check** — `3 rules, 3
positive + 5 negative controls` derived from the registered controls, `n=` and `k=` derived per rule
from the corpus. A claim a human typed is a claim nothing keeps true.

**Corollary on line numbers:** the same two `grep -c` constructs sit at `1263`/`5262` on
`kernel-k1`, `1217`/`4954` on track-b, `1246`/`4721` on track-d — one shared ancestor drifting per
branch. **Any finding filed by line number is already stale on the other two branches.** File
constructs and filenames; line numbers do not travel.

**Operational note that nearly cost this audit its own regression:** `/bin/sh` reads a script lazily
by byte offset, so **editing a running `build.sh` corrupts it mid-execution.** Track B flagged it
because track-d had a run in flight; it applied harder here — this session's own hour-long
regression *is* a `build.sh` run on `kernel-k1`. The two-line `grep -c` fix waits for the run to
land. "The fix is trivial" is precisely the reasoning that makes people do it anyway.

## ★★★ The night's thesis landing on the night's own tooling

Three more instruments failed *after* every rule above was written down. This is the
strongest evidence in the ledger that **stating a principle does not install it.**

**1. My regression waiter reported GREEN on a run that was still executing.** Two
independent defects, either sufficient alone:
- **Wrong PID.** `ps | grep '[b]ash build.sh' | head -1` picked an unrelated process;
  `head -1` took it because it sorted first. The real regression was a child of the
  `unshare -rm --propagation private` wrapper. The watched process's exit meant nothing.
- **The "completion marker" was not one.** `∃(∃) ≡ ∃` is the project motto and appears
  inside ordinary PASS lines — 5 occurrences, none terminal. The check asked `count >= 1`,
  satisfiable at any point mid-run. Correct test: `grep -c '^∃(∃) ≡ ∃$'`, the bare line
  `build.sh` prints as its last statement, which cannot match PASS text.

**What caught it was reading the ARTIFACT, not the instrument** — the log's last line was
`PASS K4b` with ~12 gates unrun, contradicting the verdict. Had the check been trusted, a
commit would have landed against an unfinished run.

**2. `git push` reports success while the deliverable stays untracked** (Track B). A
209-line finding shipped pointing at a fix that existed only on local disk. `git push` is
the one green nobody re-checks. **`git ls-files --error-unmatch` before pushing belongs in
the guard, not in anyone's habits.**

**3. My asm suite silently skipped 2 of 25 fixtures.** It reported "23 pass, 0 fail, 2 skip"
and I described the skips as nasm refusing them, "independent of `asm.la`, pre-existing."
Both false: `asm_test_pp` needs `%include "ppinc.inc"` and `asm_test_sect` needs
`incbin "incdata.bin"`, and I had copied the `.asm` files to a scratch dir **without their
dependencies**. The canonical gate, run in the real tree, passes all 25 with zero skips.
**Third instance of lost-dependencies in one session** — Track B lost the include files, I
lost the include path, then I lost the include files too.

**★ THE ACTUAL FINDING, in Track B's words, and it outranks the enumeration principle it
explains:**

> The lesson is not hard to state; it is hard to **recognise in a new costume.**

Enumerating by symbol gave a wrong answer three times (the arm set, the imm64 radius 11 vs
16, the HH2C halt site) — each time *after* "enumerate by what the compiler emits, not what
the source says" was already written in this file. Every repeat tonight was a failure of
recognition, not of knowledge. That is why the remedies that worked were **executable**
(`[ -s ]`, the ownership guard, `--error-unmatch`) and the ones that failed were **written**.

## Tools

`freeze_q0_coverage.py` · `freeze_q1_diff.sh` (probes inlined) · `freeze_q2_resolve.py` ·
`freeze_q2_skiptogreen.py`. **Tools, not gates** — the same standing as `audit_gates.py`. None is
wired into `build.sh`; each is run deliberately.

---

# Freeze-Day Audit II — the run, 2026-08-22

`audit_gates.py` had existed since 2026-08-18 and had **never been run**. Run now.

    assertions parsed : 622
    flagged for review: 258
    by class : A-byte-identity 64 | B-exact-string 151 | C-pattern 118
               D-exit+diag 40 | E-presence 27 | F-threshold 5 | Z-unclassified 217

## Reviewed by hand

**E-presence (26 shown) — mostly false positives.** Spot-checked the two making
the largest claims on a bare `[ -f ]`:
  * `:5467` self-replication — the `[ -f ]` is a PRECONDITION; the real assertion
    is `cmp -s tiny_host "$GEN1"` (byte-identity). Sound.
  * `:3532` autopoiesis successor — `[ -f logos_app ]` is a precondition, then rc
    is checked, then each of generations 0..3 must speak IN ORDER, then the count
    is asserted. Sound.
  The tool is a regex heuristic and says so; presence-as-precondition is its
  main false-positive shape.

**F-threshold (5) — the class that produced this codebase's known defect #3.**
  * `:2942` GC bounded memory — **FALSE POSITIVE, and the interesting one.** The
    tool reads `GRW -lt 150` as an absolute threshold. It is a RATIO IN PERCENT,
    and it is already the REMEDIATION for defect #3: assertion (a) passed clean
    at 16 GiB, so (a') was added comparing peak RSS at 16x the allocation.
    ★ OPEN QUESTION, NOT ANSWERED HERE: `rt_gc`'s √N frontier leak (RSS ∝
    √allocs) has a confirmed root cause and NO commit fixing it. If it were live,
    16x allocation would grow RSS ~400% and this gate would be RED. It is green.
    So either the leak is fixed or **(a') does not discriminate at these sizes**.
    → POST-BUILD: print the ACTUAL `GRW`, not pass/fail. A gate passing at 149%
      is one commit from red and reads identically to one passing at 101%.
  * `:5058` LogosInit sleep — weak but NOT vacuous: it asserts it measured
    (`$SLP` empty on a failed run ⇒ red), and a sleep that never slept gives
    elapsed=0. Real weakness is second granularity and no UPPER bound: a sleep
    of 60 s passes identically to one of 1 s.
  * `:412`, `:2481`, `:2482` — bitwise/bytecode counts; small fixed-size vectors
    where the constant IS the specification. Not rescalable, so not defect #3.

## Not yet reviewed — named rather than silently dropped
**217 Z-unclassified** ("shape not recognised — read by hand") and the remaining
A/B/C/D classes. Densest section is the LA-native assembler at **47 flags** —
also the most recently changed (Track B's nine encoding defects), so highest
prior. That is the next hand-review, not a completed one.

**A clean report is NOT evidence a gate can fail.** The tool's own docstring says
so. Nothing above upgrades a survivor to "verified"; it only removes suspects.

## Task 3 attempt — mutation-testing the standalone gates, and why it does NOT scale

Plan was: perturb each gate's expected value in a copy, confirm RED naming the
real output, confirm the clean copy GREEN. **Measured first, and the plan does
not survive the measurement.**

    46 standalone gates
     2  declare a perturbable expected-value variable  (gate_sha256, gate_crypto)
    44  assert INLINE — `grep -qF "$tok"` over serial output + an exit code

So the mutation lever reaches **2 of 46**, one of which was already mutation-
tested tonight. Reporting that as "the gates are mutation-tested" would be the
exact overclaim this audit exists to catch, so it is not being done.

**What was done instead: hunt the KNOWN shape across all 46 statically.**
Defect #1 in this codebase was an empty marker contained in every output — a
check that passes unconditionally. Scanned all 46 for that shape and its
relatives (`grep -q ""`, comparison against `""`, `-n` used AS the assertion):

    RESULT: no instance found.

★ **That is absence of one shape, not discriminating power.** It says defect #1
has not recurred. It says nothing about whether the 44 inline gates would catch
a real regression, and it must not be quoted as though it did.

**The honest open item.** There is no cheap universal lever for a gate that
boots an image and greps serial tokens: perturbing the token list only proves
grep works, and perturbing the artifact means mutating kernel source. The real
test is whether each gate has ever ACTUALLY gone red — which build logs would
show and git does not retain. Naming this as unresolved rather than closing it.
