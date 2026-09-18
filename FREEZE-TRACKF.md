# ❄ FREEZE — TRACK F (`register-stack`), declared 2026-09-18 ~13:15 at Erik's direction

**The rule (Erik, 2026-08-19, [[logos-freeze-before-milestone]]):** secure the milestone before building the next
thing on it. "Zero bugs" is not verifiable; what is: **zero KNOWN defects, plus a bounded search that would have
found them.** The decisive question is not "did it pass?" but **"which assertions cannot go RED?"**

**While frozen:** NO new Track F building — no Category-2 items, no new modules, no new rulings implemented. Closing
work IS allowed: fixing a ledger defect (red-first), running the owed runs, correcting stale claims.

**Scope:** Track F's own work since it branched from `kernel-k1` at `801f006` (2026-09-11):
**11 commits, 51 LA modules** (48 new + `lexicon.la`/`opgrammar.la` edited + `lexdepth.la`), plus tools and docs.
Out of scope: `kernel-k1` history before `801f006` (today's full audit covers it) and tracks b/c/d/e (their owners).

**EXIT — the freeze lifts only when ALL hold, each with its evidence recorded below:**
1. the full host suite `gate_registers.sh` runs end-to-end GREEN on the frozen HEAD, output captured;
2. every `want` token found in its output, and every `red` token found in its MUTANT output AND ABSENT from the
   GREEN output — the absence half is what proves a RED path is not vacuous. The gate's `red()` now checks both
   halves on every run, and `checkwants.py`/`checkreds.py --dir` re-check a kept run offline (F16–F18, closed);
3. host == SECD VM byte-for-byte for every module in the VM list, and a WRITTEN reason for each module not in it;
4. `build.sh`'s lexicon gate (the one Track F's 09-17 edit can move) green, or re-pinned with a derivation;
5. every defect below CLOSED (fixed red-first + re-run) or explicitly RULED out of scope by Erik;
6. `freezeck.py` rc 0 — including sweep D, the standing rule (every witness declares how it turns red);
7. every module PASSED V1–V8 below, each with its run recorded (§7). ⇒ then tag `trackf-secured-<date>` on the frozen HEAD.

**★ AND THEN VERIFY BY RUNNING (Erik, 2026-09-18):** *"Nothing is proven as correct until it's actually verifiably
proven to run, and that it actually works without crashing … test runs in various methods … if anything comes up, we
should be able to pinpoint exactly where it's going wrong."* Debugging and tracking get us to "no KNOWN bugs"; the
freeze does not lift on that. It lifts when every module has PASSED every method below, each run recorded in §7:

| method | what it proves | exists? |
|---|---|---|
| **V1 host run** | each module runs on `tiny_host` and prints its exact derived witnesses | yes (`host`/`want`) |
| **V2 no crash, no hang** | every green run exits 0; a timeout is reported AS a timeout | instrument ready (F19 closed); not yet run |
| **V3 mutation** | every RED path fires in the mutant AND is absent from green (not vacuous) | yes, both halves since F18 |
| **V4 second engine** | host == SECD VM byte-for-byte, AND both exit 0 | instrument ready (F19 closed); never run (F13) |
| **V5 determinism** | the same module run twice gives byte-identical output (no hidden state, /tmp, ordering) | instrument ready: `REGS_TWICE=1` (4/4 fixture cases; the first fixture was itself wrong and was caught) |
| **V6 clean checkout** | the suite passes on a fresh export of the COMMIT, not on the dirty tree ([[committed-state-vs-working-tree]]) | procedure written (§5 step 2b); all 74 files the suite needs ARE in the commit |
| **V7 independent oracle** | the pinned values were DERIVED independently (python/tex), not captured from a run | **12 sections, 45 tokens reproduced** (§1 3 7 9 21 25 28 41 42 43 46 48); 17 captured + 17 lost to go — F20 |
| **V8 pinpoint** | any failure names module · section · witness · output snippet; outputs kept; ONE section re-runnable alone | instrument ready: `sh gate_section.sh N [N…]` (slices verbatim; stub run PASS/FAIL both ways; refusals rc 2) |

**Status right now (13:15):** exit criteria 1–4 **NOT MET — nothing has run** (the deep lease is the kernel audit's
until ~17:00, then POROS P5a, then ENTELECHEIA M11c). Criterion 6 **MET** (static). Criterion 5: 28 open items (F1–F5, F9–F15, F20–F28, F30–F35); F6–F8, F16–F19 CLOSED, F29 VERIFIED (→F31/F32); F4/F5 RULED, pending implementation. The standing rule is IN PLACE (F33) and the record is reclassified against it (F35). ★ F33: 7% of pinned tokens contain a part that cannot fail, 15% more are construction-true, and 4 of the nine 09-17 corrections rest on such witnesses. V2/V3/V4/V5/V8 instruments ready; V6 procedure written; V7 gap = F20. Verification phase V1–V8: none passed yet.

---

## 1. THE COMMITS (what each did · what verified it at the time · what is owed now)

| commit | date | what | verified then | owed now |
|---|---|---|---|---|
| `85deb99` | 09-15 | register stack: 11 modules (§1–§12) | host, standalone gate | full suite on HEAD; VM leg (10 of 11 listed; `prosody_xcheck` not) |
| `cc906b3` | 09-15 | 18 completion modules (§13–§29) | host, standalone gate | full suite; VM (8 of 18 not listed); `syllabus` export bug (fixed 1d6740f) |
| `bc08817` | 09-15 | `gapcensus.la` | host | full suite; not in VM list; census entangled with F3 |
| `86eac04` | 09-17 | Category 1 + framework, 17 modules (§31–§45) | per-module host + mutants, witnesses derived first | full suite; VM leg (never) |
| `f812d29` | 09-17 | lawroot extended | per-module | full suite; VM |
| `5f1f7ec` | 09-17 | logicsyntax, numderive | per-module | full suite; VM |
| `2b1de12` | 09-17 | divergent (§48) | per-module | full suite; VM |
| `0cab0b5` | 09-17 | adequacy (§49) | per-module | full suite; VM |
| `ec12042` | 09-17 | 8 adequacy rulings applied to lexicon/opgrammar | dependents re-checked (per RESUME) | **`build.sh` lexicon gate never run (F1)**; 5 dependents |
| `93c13f3` | 09-17 | docs + checkwants/checkreds | — | — |
| `1d6740f` | 09-18 | nameck rc, VM list +17, chunk switch, archeunique (3), headers | static + stub binaries only | **everything: nothing in it has run** |

**The single honest line:** every module ran green on the host at least once, individually; **the suite has never
run end-to-end on this HEAD, and no module has a recorded SECD VM run.**

## 2. THE MODULES (51) — counts generated by `python3 freezeck.py --table`; status columns kept by hand

| § | module | born | wants | reds | host green on HEAD | VM list | VM ever run | notes |
|---|---|---|---|---|---|---|---|---|
| 1 | `lineage.la` | 85deb99 | 5 | 2 | not run on HEAD | yes | no |  |
| 2 | `prosody.la` | 85deb99 | 4 | 1 | not run on HEAD | yes | no |  |
| 2 | `prosody_xcheck.la` | 85deb99 | 1 | 1 | not run on HEAD | **no** | no |  |
| 3 | `topology.la` | 85deb99 | 4 | 2 | not run on HEAD | yes | no |  |
| 4 | `evidential.la` | 85deb99 | 2 | 2 | not run on HEAD | yes | no |  |
| 5 | `texture.la` | 85deb99 | 2 | 1 | not run on HEAD | yes | no |  |
| 6 | `registers.la` | 85deb99 | 4 | 3 | not run on HEAD | yes | no |  |
| 7 | `modegenesis.la` | 85deb99 | 3 | 1 | not run on HEAD | yes | no |  |
| 8 | `regenesis.la` | 85deb99 | 3 | 1 | not run on HEAD | yes | no |  |
| 9 | `complement.la` | 85deb99 | 5 | 2 | not run on HEAD | yes | no |  |
| 9 | `opposite.la` | 85deb99 | 2 | 1 | not run on HEAD | yes | no |  |
| 12 | `textcoherence.la` | cc906b3 | 6 | 3 | not run on HEAD | yes | no |  |
| 13 | `derive_closure.la` | cc906b3 | 5 | 3 | not run on HEAD | yes | no |  |
| 14 | `branchgenesis.la` | cc906b3 | 2 | 3 | not run on HEAD | yes | no |  |
| 15 | `ontoargument.la` | cc906b3 | 7 | 4 | not run on HEAD | yes | no |  |
| 16 | `ontomorph.la` | cc906b3 | 3 | 1 | not run on HEAD | yes | no | depends on 09-17 lexicon edit |
| 17 | `gramcomplete.la` | cc906b3 | 3 | 2 | not run on HEAD | yes | no | depends on 09-17 lexicon edit |
| 18 | `neologenesis.la` | cc906b3 | 4 | 1 | not run on HEAD | yes | no |  |
| 19 | `unified.la` | cc906b3 | 5 | 2 | not run on HEAD | yes | no |  |
| 21 | `entendre.la` | cc906b3 | 4 | 2 | not run on HEAD | **no** | no |  |
| 22 | `felicitylive.la` | cc906b3 | 2 | 1 | not run on HEAD | **no** | no |  |
| 23 | `syllabus.la` | cc906b3 | 2 | 1 | not run on HEAD | **no** | no | changed in 1d6740f; depends on 09-17 lexicon edit |
| 24 | `aware.la` | cc906b3 | 1 | 1 | not run on HEAD | **no** | no |  |
| 25 | `ablateop.la` | cc906b3 | 2 | 1 | not run on HEAD | **no** | no |  |
| 26 | `wants.la` | cc906b3 | 2 | 1 | not run on HEAD | **no** | no |  |
| 27 | `protoagent.la` | cc906b3 | 2 | 1 | not run on HEAD | **no** | no |  |
| 28 | `fractal.la` | cc906b3 | 1 | 1 | not run on HEAD | **no** | no |  |
| 29 | `branchclosure.la` | cc906b3 | 2 | 2 | not run on HEAD | **no** | no |  |
| 30 | `gapcensus.la` | bc08817 | 2 | 1 | not run on HEAD | **no** | no | reads gate_registers.sh |
| 31 | `recdepth.la` | 86eac04 | 5 | 4 | not run on HEAD | yes | no |  |
| 32 | `selfevo.la` | 86eac04 | 3 | 4 | not run on HEAD | yes | no |  |
| 33 | `certify.la` | 86eac04 | 3 | 2 | not run on HEAD | yes | no | reads gate_registers.sh |
| 34 | `migrate.la` | 86eac04 | 5 | 2 | not run on HEAD | yes | no |  |
| 35 | `closure.la` | 86eac04 | 3 | 2 | not run on HEAD | yes | no | reads gate_registers.sh |
| 36 | `metakappa.la` | 86eac04 | 3 | 3 | not run on HEAD | yes | no |  |
| 37 | `substitution.la` | 86eac04 | 6 | 3 | not run on HEAD | yes | no |  |
| 38 | `ontosemiosyntax.la` | 86eac04 | 4 | 2 | not run on HEAD | yes | no |  |
| 39 | `autocompress.la` | 86eac04 | 3 | 2 | not run on HEAD | yes | no |  |
| 40 | `phonometa.la` | 86eac04 | 6 | 3 | not run on HEAD | yes | no |  |
| 41 | `identity.la` | 86eac04 | 4 | 2 | not run on HEAD | yes | no |  |
| 42 | `compressbound.la` | 86eac04 | 3 | 2 | not run on HEAD | yes | no |  |
| 43 | `logicsyntax.la` | 86eac04 | 5 | 4 | not run on HEAD | yes | no |  |
| 44 | `lawroot.la` | 86eac04 | 4 | 2 | not run on HEAD | yes | no |  |
| 45 | `archeunique.la` | 86eac04 | 3 | 3 | not run on HEAD | yes | no | changed in 1d6740f |
| 46 | `crossbranch.la` | 86eac04 | 4 | 2 | not run on HEAD | yes | no |  |
| 47 | `numderive.la` | 86eac04 | 5 | 3 | not run on HEAD | yes | no |  |
| 48 | `divergent.la` | 2b1de12 | 3 | 2 | not run on HEAD | yes | no |  |
| 49 | `adequacy.la` | 0cab0b5 | 2 | 2 | not run on HEAD | yes | no | depends on 09-17 lexicon edit |
| — | `lexdepth.la` | cc906b3 | 0 | 0 | NOT GATED here | **no** | no | depends on 09-17 lexicon edit |
| — | `lexicon.la` | ec12042 | 0 | 0 | NOT GATED here | **no** | no |  |
| — | `opgrammar.la` | ec12042 | 0 | 0 | NOT GATED here | **no** | no |  |

`wants`/`reds` = pinned witness lines / RED-path lines in `gate_registers.sh`. **VM list "no" = 11 gated modules**
(ablateop aware branchclosure entendre felicitylive fractal gapcensus prosody_xcheck protoagent syllabus wants) **with
no recorded reason** — each needs either adding or a written reason (F9). `canon.la` sits under 39 of the 51, so an
upstream NORMK change (F4) can move pinned values across most of this table.

## 3. THE DEFECT LEDGER — every known open item (IDs are stable; close, never delete)

| id | sev | kind | item | evidence | closes when |
|---|---|---|---|---|---|
| F1 | HIGH | SUSPECT | `build.sh:4875` lexicon gate pins `diverge=14 [… Move …]`; `ec12042` re-derived Move's phonym | pin read vs commit diff; gate not run since | run it; if RED, re-derive + re-pin (derivation first) |
| F2 | HIGH | UNRUN | the full suite has never run end-to-end on HEAD; `1d6740f` has never run at all | `.fullgate.log` = one PASS line predating §43–§49 | exit criterion 1 |
| F3 | MED | DEFECT | `branchclosure.la:7,:24` and `gapcensus.la:71` say ↻↻g≡↻g holds for every glyph (vacuous); FALSE at BEING (F4). gapcensus's pinned `ceiling=2 … consistent:T` holds only because its probe skips BEING | code trace, file 20 §1 | after F4 is ruled: fix the claim OR the probe, red-first |
| F4 | HIGH | DEFECT, **upstream** | NORMK: ↻(↻(BEING)) → `↻(SELF)` but ↻(BEING) → `SELF` — ↻² fails at BEING; `WGEN` tests only a fresh Y | code trace of `canon_spec.la` (NOT run) | RULED (c) 09-18 — pending the cross-track implementation after the freeze; the 1-s probe waits for the lease |
| F5 | MED | CONFLICT | `lexicon.la:346 ONE_IS_BEING` prints One=Being (ungated) vs numderive §47 GATES "BEING is not one" | both read | RULED 09-18 (η in the truth register only) — pending the wording alignment in lexicon.la / numderive, values derived first |
| F6 | LOW | STALE | `migrate.la:42` header "GATE (drafted …)" — ran green 09-17 | freezeck H | ✔ CLOSED 09-18: header corrected to "ran green 2026-09-17; SECD VM leg not yet run" (comment only) |
| F7 | LOW | STALE | `crossbranch.la:49` prose: "Nine of the claimed twenty-eight do not exist" — codex App B: 15 absent; and "Liminal and Anamnetic are blocked on a definition" — the codex defines them | file 20 §2 | ✔ CLOSED 09-18: prose corrected to 15 absent / overlap 13 and "definitions exist, operand x owed" (comment only; pinned BUILT=18 unchanged) |
| F8 | LOW | DEAD CODE | 10 modules define a local `Px` shadowed by `recdepth.la`'s (identical bodies; a future mutant on Px would silently not fire) | freezeck S | ✔ CLOSED 09-18: the 10 dead `Px` copies removed (behaviour-preserving: identical to the imported recdepth Px); freezeck S now reports no shadowed locals; nameck + laparen clean on all 10 |
| F9 | MED | COVERAGE | 11 gated modules in no VM list, no reason recorded | freezeck V | add each, or write why not (e.g. closure size, host-only builtin) |
| F10 | MED | COVERAGE | `lexdepth.la` not gated at all (39→44 of 78 after the lexicon edit; verdict "chance") | RESUME item 6 | gate it, or record why it is a report not a gate |
| F11 | MED | COVERAGE | `lexicon.la`/`opgrammar.la` (edited 09-17) are gated only via build.sh (F1) and indirectly via 5 dependents | dependency scan | F1 closed + dependents green on HEAD |
| F12 | MED | RISK | 6 red tokens < 10 chars (`⊕:F`, `all C:F`, `ρ(L_t)=4`, `ρ 0→0`, `refused:F`, `differs:F`) — if present in the GREEN output, their RED path passes vacuously | freezeck R | checkreds on real output shows each ABSENT from green |
| F13 | HIGH | UNRUN | no SECD VM run recorded for ANY Track F module | handoffs; old VM leg printed nothing on success, so no log could show it | exit criterion 3 (chunked: `REGS_VM_CHUNK=k/n`) |
| F14 | LOW | STALE, not ours | `prop.la` (older kernel-k1 copy in this worktree) header says ¬P=⊗(VOID,P); code is ⊂(P,VOID) | read | resolves on sync with kernel-k1; note only |
| F15 | — | OTHER TRACK | `debug_meta.la` unbound `SEQ` (Track C) | probe rc 1 | reported on BOARD 11:23; Track C's |
| F19 | HIGH | INSTRUMENT | **exit codes are never asserted.** `host()` writes `$T/<tag>.rc` (gate_registers.sh:26) and NOTHING reads it: a module that prints its witnesses and then CRASHES, or hangs to the 1800 s timeout (rc 124), PASSES. The VM leg compares outputs, never exit codes, and its host run has no timeout — an identical crash on both engines reads "host == VM" | grep: the only `.rc` reference is the writer | ✔ CLOSED 09-18 (static; validated both ways): a GREEN run must exit 0 — ANY other rc fails and is printed; WHETHER THE BUDGET STOPPED IT IS DECIDED BY THE CLOCK (elapsed ≥ budget), never by matching 124/137/143 (★ my first version did match kill codes; `logos-hexis.sh` refused the commit under the sealed class hardcoded-kill-code — rewritten, and it now also labels a module that exits 124 BY ITSELF as a crash, which the code-matching version called a timeout). Mutants' rc recorded, not asserted. VM leg asserts BOTH rcs, times out its host run, names the first differing byte. Fixtures: crash-after-witness FAILS (the OLD gate passed it), hang FAILS as STOPPED BY THE BUDGET, self-124 FAILS as a crash; VM rc 1 and identical crash on BOTH engines FAIL. hexis `check` clean on all batch files, with a positive control proving it reads the file. ⚠ A green module that exits non-zero BY DESIGN will surface on the first run — then its expected rc is declared, never waved through |
| F20 | HIGH | ORACLE (V7) | **30 of 49 sections pin values CAPTURED from a green run, with no independent derivation recorded** — §1–§9, §12, §14, §17–§30, §41–§43, §46, §48 (§10, §11 pin no module output). A bug present at capture time is pinned as the expected answer and no run can catch it ([[expected-values-derived-not-captured]]). The sections that record a derivation record it only as a comment, and the scripts are gone. ✗ CORRECTED 09-18 (triage): not 17 but **12** record one (§16, §31–§40, and §45 only for its half (3)); **§13, §15, §44, §47, §49 record NO derivation anywhere** — my first count came from a keyword grep that matched other text | gate header :5–7 ("pre-registered from a green run"); per-section comment scan 09-18 | IN PROGRESS 09-18 — mechanism built + validated (`derive/lacore.py`, `sNN_*.py`, `check.py`). **12 sections derived, 45 pinned tokens reproduced exactly, 0 mismatches: §1, §3, §7, §9, §21, §25, §28, §41, §42, §43, §46, §48.** (§7 uses metaglyph.la:91–99's WRITTEN APPLYOP rule.) TRIAGE DONE 09-18 (2 agents, 119 tokens): 85 WRITTEN, 34 PARTIAL, 0 wholly code-only — the code-only parts are F30's spec gaps; ~25 vacuous suspects (F29), of which F25–F28 verified Found on the way: F21, F23 (two vacuous witnesses) and F22 (a stale doc that the model itself first copied — caught because §48 needs ⊗ non-commutative). 17 captured sections to go, and the 17 whose derivations were lost |
| F21 | MED | VACUOUS WITNESS | §3's `⊕-order invariant:T` cannot fail on a commutativity bug: the topological reading is symmetric in a node's two children, so swapping operands under the DIRECTIONAL ▷ is invariant too (derived: `derive/s03_topology.py` NOTE). The witness proves nothing about ⊕ | found by the F20 derivation, 09-18 | replace with a reading that is NOT child-symmetric (e.g. compare κ-forms, where ▷ swap differs), derived first, red-first |
| F22 | LOW | STALE DOC, not Track F's | `CLAUDE.md` says NORMK sorts ⊗'s operands ("⊗/⊕ are symmetric") — false since the E1 / LA.tex:2837 non-commutativity ruling: only ⊕ is sorted. F20's own model copied the stale claim and was caught at §48 (SEALER ⊗(a,b) and SWAP ⊗(b,a) would have merged, 6→5) | code read (NORMK's SYN case has no sort); §48 derivation | the doc's owner corrects the κ section; lacore now models the code |
| F23 | MED | VACUOUS WITNESS | §21's "four readings pairwise distinct:T" compares the four LABELLED strings (`surface=` / `facets=` / `elements: marks=` / `contour=`) — distinct by their labels alone, whatever their content; it cannot fail | EN_DISTINCT4 read; `derive/s21_entendre.py` NOTE | compare the readings' CONTENT (strip the labels), derived first, red-first |
| F24 | LOW | LITERAL TEXT | §9 opposite.la:74 prints "HAS_POLE Past:T Being:F ->" as LITERAL text; only the trailing `->T` is computed (W_HAS_POLE). If a case flipped, the output would still print the two per-case values unchanged. (Found by F20 §9 on 09-18; this row was MISSING until the standing-rule checker refused a declaration citing it.) | derive/s09_complement.py NOTE; opposite.la:74 | print the computed per-case values |
| F25 | HIGH | VACUOUS WITNESS behind a PUBLISHED correction | §44's INDEPENDENCE witness ("all three law-verdicts IDENTICAL with the Archē rewrite present and DELETED:T") is vacuous: `LR_SIG = la g. …` NEVER USES g (lawroot.la:85), so the "DELETED" signature is computed with the rewrite still in place; the laws were never run with GROUND removed. The RED path lr_m1 only shows the COMPARISON could see a dependence threaded in by a mutant. ⇒ **09-17 correction 1 ("the Three Laws are NOT derived from the Archē") is UNWITNESSED** — it may hold by inspection (LAW_IDENTITY = AUTO_OK, lawroot.la/metalogic.la:61), but no gate shows it | read + verified 09-18 | thread GROUND into the laws' actual evaluation (or state the claim as by-inspection), derive first, red-first; paper queue item 1 marked |
| F26 | HIGH | LITERAL CLAIM behind a PUBLISHED correction | §47 prints "★ CORRECTION: BEING is the IDENTITY combinator, not one — one = BECOMING(VOID):" and then a boolean that checks ONLY one = BECOMING(VOID) (numderive.la:104–105); `ND_BEING` is defined and never used. Decoded as a numeral, BEING = λs.s gives (λs.s)(succ)(0) = 1: in TRUTH BEING IS one. ⇒ **09-17 correction 6 ("BEING is not ONE") is literal text**; correct form, per the F5 ruling: distinct in FORM (λs.s ≠ λf.λx.f x, itself ungated), equal in TRUTH | read + verified 09-18 | gate the FORM distinction and the TRUTH equality separately, derive first; paper queue item 6 corrected |
| F27 | MED | VACUOUS RED | §35 closure's "re-introduced slack" red path: RESIDUE is a fold whose SEED is the injected name, and any non-empty accumulator short-circuits — so RESIDUE(lines)("notgated.la") returns "notgated.la" without reading the suite (closure.la RESIDUE) | code read 09-18 | seed the fold with "" and inject the slack as a listed-but-unhosted entry |
| F28 | MED | VACUOUS / UNIMPLEMENTED | (a) §40 `PM_MODE_BARE = NOT(str_eq(X)(X))` compares an expression with ITSELF (phonometa.la:103) — the "bare invariants" verdict is a tautology; (b) branchclosure.la's header claims property (3) SELF-APPLICABLE as [W] — nothing computes it; its LINE3 is a literal "↻↻g≡↻g is TRUE for every…", false at BEING (F4); (c) unified.la:67 `UN_RASTER_FIXED = int_eq(SZ)(SZ)`; (d) §49 "the REAL overloads=8" is a hard-coded table's length and "resolved 8/8 → ZERO:T" is printed while ontomorph's live census reads 1 | each read + verified 09-18 | per item: compute what is printed, or print what is computed; derive first |
| F29 | MED | VACUOUS SUSPECTS (agent triage, NOT individually re-verified) | §2 distinct=1/5 and ↻↻x; §5 ⊕-order (F21's class); §6 raw-route refused; §8/§14 re-admit FF; §8 κ all-T; §12 components order-independent; §17/§18/§19 AUTO_OK-of-a-seal conjuncts; §19 ren≠renA·renB, coupled-refused, syntropy identities; §23 monotone + violations=0; §29 18/19 (reads back its own constructor); §30 "RED paths present" = two substrings; §33 forged (a) differs by construction; §34 "4→5"; §38 Being=Form 35/35; §39 base case; §40 t2/t4; §44 t4 (criterion's CANON half by construction — bears on correction 2); §45 t2; §47 t4/t5; every Δ(Δ)≡Δ token (vacuous by the house's own ruling) | two triage agents 09-18 | ✔ VERIFIED 09-18 (each against its code or stated definition): **3 NOT upheld — real checks** (§2 separable 1/5, which pro_m1 turns red on a contour collision; §12 components order-independent; §19 coupled-form refused, a negative control for AUTO_OK with its own red path). **Newly CANNOT-FAIL:** §31 'relaxation passes=4' prints the constant bound RD_PASSES and nothing checks convergence; §30 'present with PROVEN RED paths' checks two substrings. **The rest are CONSTRUCTION-TRUE** (see F32) |
| F30 | MED | SPEC GAPS — rules that exist ONLY as code (no independent derivation possible until written) | the 12 register READINGS' concrete strings (registers.la:79–110 — REGISTERS.md only names them; blocks §6/§8/§14/§18); integer flooring in texture and the tc score; syllabus's tie-break + violation-count convention; neologenesis's rewrite-case operational/prosodic laws; ontofelicity's output formats; gapcensus's item→predicate bindings; derive_closure's witness reductions + "bound"/"naturals"; ontoargument's offender order/format + λ-closure scope; ontomorph's order/render; certify/migrate/substitution labels; migrate's ratchet-on-fork; closure's STRUCT fields; metakappa's set selection; autocompress's DAG count; numderive's chain seed | two triage agents 09-18 | write each rule down (REGISTERS.md / module header), THEN derive |
| F31 | MED | CANNOT-FAIL | §31 recdepth prints "relaxation passes=4" = the constant `RD_PASSES` (recdepth.la:82); RELAX runs exactly that many passes and NOTHING checks that one more pass changes nothing — under-relaxation could not show, and "settled" (09-17) overclaims. §30 gapcensus "present with PROVEN RED paths" = two substring checks (gapcensus.la:41–43) | verified 09-18 | add a convergence check (pass k+1 == pass k), print the passes actually needed; reword §30 or check real RED lines |
| F32 | MED | CONSTRUCTION-TRUE (witnesses a constructor, not the claim) | verified: AUTO_OK of a fresh seal is always T (seal ren = CANON(etym), canon.la:77, lineage.la:49) — §17 "sealed self-naming", §18 neologenesis's one-seal(AUTO_OK) law on a COLLAPSE child, §19 modes' AUTO_OK conjunct, §24 all-A/all-C/coincide/two-turns, §38 Being=Form 35/35; §19's dyadic step (⊗(x,x)≠"xx", +1 node, +1 depth), syntropy identities, "sound grows under ⊕"; §39 Δ_ν's fixed point = the fold's base case DNU([x])=x (autocompress.la:63,69); §47 t4/t5 (the numeral IS tree size, so four one-node-two-leaf forms share 3 and a size-only seal collapses them); §44 t4 (AUTO_OK uses CANON, so it cannot consult the Archē — by definition); §32 FIXED POINT compares LENGTHS only (selfevo.la:185; sound only if steps are append-only) and the laws at a fixed point compare a state with itself; re-admission FF(…) in §7/§8/§14 (a member equals itself — including §7, which F20 itself derived as a MATCH); §23 depth-monotone + violations=0 (sorting guarantees them); §29 18/19 (reads back its own constructor); §2 ↻↻x and every Δ(Δ)≡Δ token (↻↻≡↻, true except at BEING — F4); §6 raw-route refused; §8 κ all-T; §33 "every glyph certified"; §34 "4→5"; §40 t2/t4 (union is associative and contains its operands) | verified 09-18 | not bugs — but each must be LABELLED as witnessing its constructor, and no claim may rest on one alone. ★ A MATCH in F20 does not make a witness able to fail: §7's re-admit matched and is construction-true |
| F33 | HIGH | ★ THE META-FINDING (the rate) | Over all 164 pinned tokens in gate_registers.sh (45 derived + 119 triaged), counting ONLY verified cases: **~12 tokens (7%) contain a component that CANNOT FAIL** (F21, F23–F28, F31) and **~25 more (15%) are CONSTRUCTION-TRUE** (F32). **Of the nine 09-17 corrections, four rest on such witnesses** — 1 unwitnessed (F25), 6 literal (F26), 2 and 7 definitional (F32) — **and so does the fixed-point half of the Δ_ν result written into the paper queue on 09-18.** Bound: the triage was two agents plus F20's derivations, not an exhaustive proof, so these are LOWER bounds; the 3 suspects that proved real show the triage over-flags too | this file, 09-18 | ✔ REMEDY IN PLACE 09-18 (Erik: "standard first, work second"): all 164 `want` lines carry a `#@ turns-red:` declaration; `freezeck.py` sweep D refuses a missing, unknown or dangling one (8/8 planted errors caught, control rc 0). It already caught a real gap on its first run: F24 was cited but had no ledger row. Class census: red 80 · exact 58 (12 derived) · construction 36 · fixture 9 · entailed 3 · cannot-fail 12. STAYS OPEN until the 12 known-defect witnesses (F21, F23–F28, F31) are fixed and F34's queue is drained |
| F34 | MED | WEAKLY WITNESSED (the standing queue) | 54 of 164 witnesses have NO red path, NO fixture and NO independent derivation — only `exact:captured`, `construction:` or `entailed:` (freezeck sweep D). Not proven wrong; not proven able to fail on the thing they claim | freezeck D, 09-18 | per witness: derive it (F20), add a mutant + red line, or add a refusing fixture; the count must fall to 0 before the freeze lifts |
| F35 | HIGH | ★ THE RECORD, RECLASSIFIED (Erik 2026-09-18: "the record should match the method") | Every gated Track F module header now carries a `⚖ RECLASSIFIED` line (48 modules; comment-only, verified: nameck/laparen clean, recdepth's read-back strings intact, freezeck + derive/check unchanged). Of the 164 pinned witnesses: red-proven 80 · fixture-backed 9 · exact & independently derived 23 · exact & cross-checked 1 · **exact but CAPTURED 34 → [B]** (a regression turns them red; that the value is RIGHT is unwitnessed) · **construction-true 40 → [A]** (they witness a constructor, not the claim) · **cannot-fail 12 → UNWITNESSED** (F21, F23–F28, F31) · entailed 3. (Clauses overlap: one witness may carry several.) Modules whose header [W] needed qualifying: cannot-fail parts in 12, construction-true parts in 25, captured values in 25; **only 10 of 48 modules' [W] stands unqualified** (ablateop, archeunique, complement, compressbound, divergent, fractal, identity, logicsyntax, metakappa, prosody_xcheck — neologenesis was listed clean until its one-seal law was verified construction-true). Explicit inline downgrades where a PUBLISHED claim was involved: lawroot "independence" [W→UNWITNESSED, F25]; numderive "BEING is not one" [literal, F26] + the measure horizon [A]; autocompress's fixed point [A, fold base case]. ✗ Correction to the 09-18 discussion: the captured exact values number 34, not 46 (23 witnesses — not 12 — carry a derivation; 12 was the number of SECTIONS). ⚠ `evidential.la`'s own catalogue W/B/A/I tags are NOT reclassified here: changing them moves pinned outputs — a post-freeze pass | this file + the 48 headers, 09-18 | each [B]/[A]/UNWITNESSED claim is upgraded only by deriving it (F20), adding a red path, or fixing the defect it cites |
| F16 | HIGH | INSTRUMENT | `checkreds.py` checks a red token is IN the mutant output, never that it is ABSENT from the green output (so it cannot catch F12's vacuous class); and it silently SKIPS a mutant with no captured output (`continue`) — "0 DID NOT FIRE", rc 0, over nothing | read | ✔ CLOSED 09-18 (static; validated both ways): absence-in-green half + MISSING-is-failure + no-selection-is-failure; 6/6 fixture cases right (genuine / vacuous / not fired / mutant missing / green missing / empty selection); `--dir` reads a REGS_KEEP dir |
| F17 | MED | INSTRUMENT | `checkwants.py` prints "NO OUTPUT" for an unrun module but does not count it — rc 0 with nothing checked | read | ✔ CLOSED 09-18 (static; validated both ways): NO OUTPUT now UNCHECKED and rc 1; 3/3 fixture cases right; `--dir` added |
| F18 | HIGH | INSTRUMENT | the gate's own `red()` has no absence-in-green check either; and `trap 'rm -rf "$T"' EXIT` deletes every output, so no gate run leaves anything for checkwants/checkreds (their `.mut/`, `.runout/` were filled by a manual 09-17 run) | read | ✔ CLOSED 09-18 (static; validated both ways): `red()` refuses a token present in the base tag's GREEN output, and a missing/empty green output — 5/5 cases right under dash, using the gate's own extracted definitions; `REGS_KEEP=<dir>` keeps $T (stub run: 8 files kept; none without it, no temp dir left) |

## 4. STATIC SWEEPS DONE (no lease) — each validated against a KNOWN defect before its result was trusted

| sweep | tool | result | validated both ways? |
|---|---|---|---|
| unbound names, host + VM builtin sets | `nameck.py`, `--vm` | 0 of 51 | yes (09-18: known defect + mutant) |
| paren balance per definition | `laparen.py` | 0 of 51 | (tool from 09-17) |
| every mutant actually mutates (88) | `freezeck.py` M | 88/88 change ≥1 line; 0 shadowed | yes — fixture that matches nothing is flagged |
| shadowed locals (dead under tiny_host) | `freezeck.py` S | 10 identical `Px` copies (F8); 0 divergent | yes — planted divergent NORMK is flagged |
| duplicate gate output tags | grep sweep | 0 | (known-defect sweep from 09-17) |
| header status claims | `freezeck.py` H | found F6; F3's `branchclosure.la:24` | advisory only |
| modules not in any VM list | `freezeck.py` V | 11 (F9) | — |
| short red tokens | `freezeck.py` R | 6 (F12) | needs a run to decide |
| runtime readers of gate_registers.sh | read of closure/certify/gapcensus | unaffected by 1d6740f's edits (static) | confirm on the run |

## 5. THE RUN QUEUE — needs the deep lease; in this order, each closes named items

0. ✔ **DONE 09-18: the instruments F16/F17/F18 fixed**, each validated both ways on a fixture. (Their first read of
   the stale 09-17 captures: archeunique half (3)'s witness and RED are UNWITNESSED — correct, it has never run.)
1. **NORMK probe** (1 s): `import("canon.la")` · `print(NORMK(MC(MC(PRIM("BEING")))))` → expect `↻(SELF)`. Confirms/refutes F4.
2. **Full host suite** on the frozen HEAD, keeping every output:
   `REGS_VM=0 REGS_KEEP=.freeze-out sh gate_registers.sh 2>&1 | tee .freeze-host.log`, then
   `python3 checkwants.py --dir .freeze-out` and `python3 checkreds.py --dir .freeze-out` — both must exit 0.
   Closes F2, F12 (the gate's `red()` now refuses a vacuous RED itself); re-confirms 1d6740f.
2b. **V6 clean checkout** (after committing — an export holds only what is committed):
   `C=$(git -C ~/logos-f rev-parse --short HEAD); D=$HOME/logos-verify/trackf-$C; rm -rf "$D"; mkdir -p "$D"`
   `git -C ~/logos-f archive "$C" | tar -x -C "$D" && cd "$D" && REGS_VM=0 REGS_KEEP=.freeze-out sh gate_registers.sh`
   then both checkers `--dir .freeze-out`, and `diff -r` its `.freeze-out` against the worktree run's: identical.
2c. **V5 determinism**: `REGS_VM=0 REGS_TWICE=1 sh gate_registers.sh` (doubles host time — can share a run with 2).
3. **build.sh lexicon gate** alone (≤300 s). Closes or confirms F1; with (2) closes F11.
4. **VM leg in chunks**: `REGS_VM_CHUNK=1/8 sh gate_registers.sh` first — read its TIME lines, size the rest. Closes F13.
5. Fix phase: each open defect red-first, then re-run the sections it touches. Rulings F4, F5 go to Erik.

## 6a. F4 IS A FOUR-WAY IMPOSSIBILITY, NOT A CODE BUG (worked out 2026-09-18 from the code; nothing run)

Four properties the language currently asserts cannot all hold:
- **(i)** ↻(BEING) ≡ SELF — `REWRITE_MC`'s declared rewrite; also TRUE in meaning: BEING = `la self. self` (I), SELF = BEING(BEING) = I, ⟦↻⟧ = DEPTH = `la g. g(g)`, so ⟦↻⟧(BEING) = I(I) = I (denote.la W_MC).
- **(ii)** ↻(↻Y) ≡ ↻Y for EVERY Y — the MTC, as `canon_spec.la`'s comment claims.
- **(iii)** congruence — equal parts give equal wholes. Holds BY CONSTRUCTION: NORMK is bottom-up.
- **(iv)** the ↻ operator's own glyph, **MODE_MC = ↻(SELF)** (`metaglyph.la:69`), is a DIFFERENT glyph from the primitive SELF — meta-monosemy (recdepth counts it κ-distinct in its 35/34 catalogue).

**Proof:** (i)+(iii) ⇒ ↻(↻BEING) ≡ ↻(SELF); (ii)+(i) ⇒ ↻(↻BEING) ≡ ↻(BEING) ≡ SELF; so ↻(SELF) ≡ SELF, contradicting (iv). ∎
Today's code gives up (ii) at exactly BEING — that is F4. Every fix is a choice of which property to give up:

| option | gives up | what it means | cost (to measure before deciding) |
|---|---|---|---|
| (a) ↻(SELF)→SELF | (iv) | the ↻ operator's glyph collapses into the primitive SELF — true in MEANING (SELF(SELF) = I), a meta-polysemy in FORM | recdepth's 34-distinct, archeunique's 16-set, metaglyph distinctness, every normal form with ↻(SELF) |
| (b) keep it, record it | (ii) at BEING | ↻↻g≡↻g becomes a DISCRIMINATING law, false at the one input the declared rewrite touches | branchclosure :7/:24 + gapcensus :71 corrected; gapcensus's pinned census moves |
| (c) move (i) to the truth register | (i) in the GLYPH register only | ↻(BEING) stays its own FORM; ↻(BEING) ≡ SELF lives where denote.la already proves it, in MEANING — the two-register discipline (cf. ¬¬C ≠ C as glyphs, ≡ C in truth) | the one documented glyph rewrite goes: monosemy_test's collapse, denote.la's "commutes with κ" witness, every normal form containing ↻(BEING) |
| "scoped" fold on the raw tree | (iii) | X ≡ Y would no longer give ↻X ≡ ↻Y — **worse than F4; rejected** | — |

**★ No option is free — there is a FIFTH property.** (v) **form-level monosemy**: two forms with one meaning collapse
to one glyph. That is what the rewrite (i) is FOR (`build.sh:7008` asserts "rewrite collapsed"). So (a) gives up (iv),
(b) gives up (ii) at BEING, and **(c) gives up (v) for the one pair ↻(BEING)/SELF** — a declared synonym pair in form.
**What favours (c) is PRECEDENT, not freedom:** `complement.la` already gates ¬¬C and C as DISTINCT GLYPHS that are
EQUAL IN TRUTH. Today the language is inconsistent with itself — it keeps ¬¬C/C apart in form but collapses
↻(BEING)/SELF. (c) makes the two cases one rule; (a) and (b) would each break something with no precedent.

**The reach of (c), measured statically 2026-09-18 [B — a python re-implementation of REWRITE_MC, not an LA run]:**
under (c) ↻(BEING)→↻(BEING), ↻(↻(BEING))→↻(BEING) (↻² holds), ↻(SELF) stays distinct. The rewrite can fire in 14
files, only 4 of them Track F's (registers, regenesis, lawroot, branchgenesis); the rest are core (metalogic_spec ×8,
denote, canon_spec, sigil, obscurantism, modality, explain, crosscoll, cob). **At least five build.sh gates assert the
rewrite outright** and must be restated, each with its new expected value derived first: canon W7 (:1505),
topoderive DSIGIL(↻(BEING)) = DSIGIL(SELF) (:5858), cob's control (:5877), denote's "commutes with κ" (:6436),
monosemy "rewrite collapsed" (:7008). ⇒ **(c) is a change to kernel-k1's core, owned by canon_spec's owner — not a
Track F fix, and it cannot land inside this freeze.** gate_registers.sh pins no witness naming ↻(BEING); whether any
pinned SELF value derives from the rewrite only a run can say (the suite run twice, with and without it).
After (c) lands, ↻↻g≡↻g holds for EVERY glyph again, so the three "vacuous" records become TRUE again rather than
needing correction (under (b) they must be corrected).

**What the sources say (the reflection's question 4):** the SPEC titles 𝔤₁ **"Being — The Archē"** and writes "Being (∃)"
(LINGUA_ADAMICA.tex:4616, :317); today's WHITE PAPER says "Whether BEING IS the Archē IS left open"; and `archeunique`
§45 GATES BEING as ordinary (⊗(BEING,BEING) ≢ BEING, counted among the 16). Spec, paper and gate disagree on the
very question F4 turns on. (Related, F5: BEING = I and one = BECOMING(VOID) = `λf.λx.f x`, which is η-equal to I —
lexicon.la's One=Being holds up to η, numderive's "BEING is not one" holds without η. F5 is the ruling "is η-equivalence identity in LA?")

## 6. RULINGS THIS FREEZE NEEDS FROM ERIK
- ✔ **F4 RULED by Erik 2026-09-18: (c)** — ↻(BEING) ≡ SELF moves to the TRUTH register; ↻(BEING) keeps its own form (monosemy given up for this one pair, as ¬¬C/C already is). Implemented AFTER the freeze and the kernel audit, by/with canon_spec's owner, restating the five build.sh gates (§6a) with new values derived first.
- ✔ **F5 RULED by Erik 2026-09-18: η-equivalence is identity in the TRUTH register only** — ONE and BEING are distinct forms, equal in truth under η. Both lexicon.la (One=Being) and numderive §47 ("not one") stay, with their wording aligned to say which register each speaks in; the pinned witnesses that change get new values derived first.
- **F9/F10** — accept "not on the VM" / "report, not gate" as written reasons, or require them.

**Ledger discipline:** regenerate §2's counts with `python3 freezeck.py --table` (status columns are hand-kept); add a
defect the moment it is known; close an item only with its evidence (a run log line or a commit hash).

## 7. VERIFICATION RUN LOG — one line per run, appended; nothing here is claimed without its log
| when | commit | method | scope | command | result | log/output kept at |
|---|---|---|---|---|---|---|
| — | — | — | — | *(no verification run yet — the deep lease is the kernel audit's until ~17:00)* | — | — |
