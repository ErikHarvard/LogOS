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

**RUN_SM costs ~100 s per recursion level** (28 s base case, 126 s for one call), so it times out
on almost any interesting program. Stated, not rediscovered.

**A fourth question belongs beside Q2**, proposed by Track D: *which controls cannot fail?* Three
independent hits in one day — a sign-flip control (arithmetic, cannot move), a control moving two
variables (isolates neither), and `gate_link_e2e` comparing across both tracks' halves (names the
wrong one). A comparison that cannot discriminate is the general form, and neither Q1 nor Q2 asks
for it.

## Tools

`freeze_q0_coverage.py` · `freeze_q1_diff.sh` (probes inlined) · `freeze_q2_resolve.py` ·
`freeze_q2_skiptogreen.py`. **Tools, not gates** — the same standing as `audit_gates.py`. None is
wired into `build.sh`; each is run deliberately.
