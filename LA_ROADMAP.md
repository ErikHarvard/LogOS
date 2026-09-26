# LA ROADMAP — what remains to build for Lingua Adamica, in order

**One page, replacing the scattered lists.** Reconciled 2026-09-25 item by item from `LA_COMPLETION.md` (both copies:
`F:` = this branch, `M:` = `~/logos/` kernel-k1), `LA_TOMORROW.md` (`T:`), `~/logos/ROADMAP.md` (`R:`),
`FREEZE-TRACKF.md` (`Z:`) and the linguistics papers (`MCL:` = *Metacursive Collapse of Language*, `WP:` = the LA White
Paper). A status rests on a module + a gate section, a commit, or a run log — never on a marker alone.
**Status:** OPEN · PARTIAL · BUILT (module + gate on register-stack, not merged) · ON-MAIN · CEILING · RULING.
**Keep it true:** when an item moves, change its line here in the same commit, with the evidence.

---

## 0. THE SPINE — the one collapse (Erik, 2026-09-25)

> "Every branch of linguistics should collapse as one unit thus allowing for infinite compression, both semantic,
> glyphic, and morphetic, and more. And it should be algebraic, computational, and even mathematical."

The paper's form: **B(B) = B = Λ ∩ Interface_B** (MCL §IX) and the Hexary Fusion
**Phon ⊕ Morph ⊕ Syn ⊕ Sem ⊕ Prag ⊕ Disc = Ontosemiosyntax = ∃(∃) ≡ ∃** (MCL:1301). Every item on this page is judged
by whether it serves that one operator.

**BUILT 2026-09-25 — `onecollapse.la` (8691b01).** Λ = λx.⊂(RELATION,x), with two laws as a layer over NORMK:
L1 Λ(Λx) ≡ Λx and L2 Λ(a⊕b) ≡ Λa ⊕ Λb. Run on the host: rc 0, every result T, **8/8 RED paths fire**.
- one generator: 18 of 19 declared branches ARE Λ(interface); Δ_B's ▷-branch refused by name
- all 18 collapse JOINTLY to one Λ: lossless (truth + etymology from the DAG), not vacuous, idempotent, refuses a foreign member
- compression against formulas derived in-file: semantic 14(n−1) bytes, morphetic 2(n−1) nodes, glyphic n−1 DAG nodes
- the hexary fusion collapses to ONE self-naming seal, derived rather than declared, and named by its Ren ALONE
  (R-SP1 ruled 2026-09-26: not "Ontosemiosyntax", which the codex keeps for its triad, :2507; a report may say "HEXAD")
- **unbounded iff self-similar**: tree 6·2^d−5 over DAG d+3 (ratio 379/9 at d=6, rising), while distinct content stays
  under (T+3)/2 for every n. This is the honest form of "infinite compression"; the White Paper reaches it too
  (WP:8952, "structure sharing has a Shannon floor").

**Still open on the spine:**
| # | item | status | gate (how it can go RED) | blocker |
|---|---|---|---|---|
| S0 | `onecollapse.la` wired as gate **§50** — first run PASS, 9/9 witnesses, 12/12 RED paths fire | DONE | 9 mutants | — |
| S0b | onecollapse on the SECD VM | OPEN | host==VM byte-identity | F13 codegen cost |
| S1 | **one normaliser, one κ, three renderers** — WP:3274 calls it "the first item of the roadmap"; today NORMK, NKAP, CANONIQ×2, NORMP, NORMTREE, and now OC_NF | OPEN | fuzz corpus: all normalisers agree; RED = a mutant rewrite in one | F4(c) lands first; R-NORMTREE |
| S2 | the triple bar as a biconditional: NIS ⟺ same sound ⟺ same raster | OPEN | RED = ⊕-associativity (one sound, two concepts, F:952) | S1 |
| S3 | L1 + L2 into NORMK — **RATIFIED 2026-09-25 (F44)**; ripple derived: 2 keys move, 1 collision, now DECLARED (R-SP4) | OPEN | removing either law reds (m3, m4) | after the freeze, with F4(c) |
| S4 | syntax ≡ MODE_CON under L1 — **DECLARED an identity (R-SP4, 2026-09-25)** | DONE | onecollapse (3) asserts the collision set = the declared one; RED oc_m9 | — |
| S5 | branches in Erik's list not in the 19: Lexicology, Lexicography, Stylistics (+ the deferred five) | OPEN | Δ_B admission TTTT, then onecollapse's generator count rises | R-B1, R-B2 |
| S6 | emergent (not concatenated) branch reading — BREAD is JOIN_READ today (branchgenesis.la:119) | OPEN | RED = a BREAD that is JOIN_READ | — |
| S7 | linear stored monoglyph — MONO's etym slot AS the DAG (Ren doubles per collapse, fractal.la) | PARTIAL (measured) | NODES(stored Cn)=+1; RED in G§28 | canon.la owner |
| S8 | **phonetic compression**: the phonym grows with depth under ⊕ ▷ ⊂ ↻ (unified.la:14) — the phonetic register does not yet collapse | OPEN | PDUR bounded per mode, or a ruled [B] bound | R-SP3 |
| S9 | the collapse carried into sigil + phonym (onecollapse measures κ, tree and DAG; not sound or raster yet) | OPEN | per-register saving against a derived formula | S1, S8 |

---

## 1. NOW — the order of work

> **Tomorrow (09-26): `RESUME-2026-09-26.md`** — the full host suite first (freeze exit), then the meta-architecture items.

1. **Freeze exit** (Z §5 run queue, in order): NORMK probe → full host suite (F2) → V6 clean checkout → V5 determinism →
   build.sh lexicon gate (F1 — its re-pin is derived and CONFIRMED BY RUNNING 09-25, c190968) → VM chunks (F13) → fix phase.
   Done 09-25: §33 certify PASS (F36 confirmed); §23 re-pinned to 73 WITH `derive/s23_syllabus.py` (F41). Open: §35 needs >1800 s (F42).
2. **The merge** register-stack → kernel-k1 (merge plan: verified base tag · freeze lifted · LA_COMPLETION resolved BY ITEM).
   Closes ~22 stale main-line markers (§6). E16 §A gets its superseded note (F40, ruled 09-25).
3. **F4(c) in core**, then F5's wording (canon_spec owner; five build.sh gates restated with values derived first).
4. **S1 one normaliser → S2 triple bar.**
5. **The M11 chain:** M11b (re-witness on the merged tip) → M11c → G4 → depth-directed selfopt.
6. **Rule 4's remaining gate** (alphabet, leaf, survives a reload) on 6a23dfe.
7. **The spine's Cat-1 items** after their rulings: S3 S4 S5 S6, then S9.
8. **Track A's phonetic/visual block** (§3 Cat 2), with S7 and S8.
9. **Seal 2 field (a)** after the Seal-1 ruling.
10. **In parallel when a lease allows: the memoising evaluator** — every gate is slow because tiny_host re-evaluates a glyph
    body at every reference (T:5–13). It shortens every item above; §35's timeout (F42) is this.

## 2. RULINGS OWED TO ERIK

| id | question | unblocks |
|---|---|---|
| R-SP1 | ✔ RULED 2026-09-26 (Erik; LA_RULINGS_BRIEF-2026-09-26.md): (1) the CLASSICAL six, Discourse sixth — as built; (2) the seal carries its Ren only, no English label ("HEXAD" as a plain descriptor); (3) Phon = phonetics (BASE_BRANCHES 0) — as built. Label change to onecollapse.la + its §50 pin: after runner6 | S3 |
| R-SP3 | ⏸ DEFERRED 2026-09-26 (Erik): a sealed rendering is new scope; unified.la's measured phonym growth stands as correct for ANALYTIC speech (LA.tex operator phonology) | S8 |
| R-B1 / R-B2 | the deferred branches' interface x; do Lexicology / Lexicography / Stylistics / Tier 6–7 count | S5 |
| R-B D2 · D5 | ✔ RULED 2026-09-26 (Erik): D2 **different** — Tier-5 Meta-X are X passed through Tiers 0–4, not LA's plain Logos ∩ Interface branches; D5 **cross-species** — Meta-Rosettology per the codex (:1654 :1860–1862 :4169–4173), MCL:1237 compatible | S5 |
| R-S1 | Seal 1: which type system (E3 ruled 09-09; ratification owed — unverified) | Seal 2 (a) |
| R-P1 | ⊕-associativity is phonetically invisible: a bracketing marker, or a bound | S2 |
| F28d · F10 | ✔ RULED 2026-09-26 (Erik): F28(d) **No** — a declared one-concept synonym is not an overload (§49 prints the live census); F10 **gate as report** (lexdepth NOT WITNESSED; demote its [W]) | freeze exit |
| F38(1–2) | ✔ RULED 2026-09-26 (Erik): Change (verb) YES — ▷(FORM,BECOMING) its own entry (LA.tex:5293); Speak FOLLOWS — ▷(SELF,⊂(RELATION,BEING)). Not yet built (lexicon ripple) | freeze exit |
| F37 · F38(3–6) · F9 · F30 | freeze rulings (Z §6) — still open | freeze exit |
| R-NORMTREE | NORMK goes tree-level and NORMTREE retires, or NORMTREE stays as the differential witness | S1 |
| R-α · R-𝒩 · R-meta-referent · R-empty-names | S19 §3.4–3.8 | sigil of the meta-referent |
| ✔ ruled | F4(c) · F5 · F39 (c190968) · F39b · **F40: the 09-17 re-derivation supersedes E16 §A** · **F44: L1 + L2 ratified** · **R-SP4: syntax ≡ MODE_CON declared** | — |

## 3. EVERYTHING ELSE, BY CATEGORY

**Cat 1 — self-closable, Track F.** BUILT (unmerged): κ\* (metakappa §36, irreducible) · Algebra of Naming (§37) · ρ(L_t)
(§31) · Self-Evolution bounded (§32) · Seal 2 machinery (§33) · Seal 3 (§34) · Meta-Ontosemantic Closure, closure half
(§35) · ontosemiosyntax stratum (§38) · Δ_ν (§39, fixed point definitional) · phonometa (§40) · identity glyph (§41) ·
adequacy rulings (§49) · crossbranch / divergent (§46 §48) · textcoherence · entendre · ontomorph · felicitylive · wants ·
aware · protoagent · ablateop · syllabus (structural half) · **onecollapse (2026-09-25)**.
OPEN: ontosemiosis as a stratum (T:130) · the audit operators \|G\| \|G_meta\| ς μ · ~~a duplicate/shadowed-glyph check~~ **DONE 09-25: `nameck.py --bind`, gated §51 — it found F45 (three modules silently on raw phonyms)** · lexdepth gated or reported (F10) · ν\* as reduction rules
(unclassified; touches the evaluator).

**Cat 2 — owned by another track.** Track A (phonetic/visual): ▷ acoustic signature (PARTIAL) · elision layer · phonseq
detects ▷ · ⊗ vs ▷ acoustic separation (PARTIAL) · ⊗(A,A) PCM identity (PARTIAL) · PSC_STAR raw pairing · toroidal closure
of the metaphonetic manifold · ⊗ sigil renders as juxtaposition · catalogue-wide sigil injectivity · **visual round trip
(bitmap→structure)** · meta-referent sigil · psc_spec PMODE_REC always-true · crossmodal 9th module · formant tables, one
source · compound spectral recovery. canon.la owner: one normaliser (S1) · fractal fix (S7) · F4(c). Track B: M11c
auto-registration (PARTIAL; `registry_tracker.la` is referenced at familytree.la:45 and exists nowhere) · G4. Core:
self-meta-programming (execve the adopted organ) · meta-autopoiesis (build.sh's `cmp -s` forbids a modified successor) ·
meta-autontopoiesis (open by the General's 09-10 ruling). ELENCHOS: Rule 4's remaining gate. ON-MAIN already: M11b
(04005ab, build.sh:3132) · Obscurantism (build.sh:6923) · Rule 4 slice 1 (6a23dfe, build.sh:4917).

**Cat 3 — external (the system cannot supply the input).** Acquisition, empirical half (a speaker) · trans-species second
functor · Seal 4 empirical calibration · entropy on the metal (PARTIAL, specified) · signature scheme (PARTIAL, Track E toy
params) · voice interface (its own track, not LA completeness).

**Cat 4 — ceilings: keep marked, do not chase.** Derivation closure 4/9 · constant-time [A] (T calls it a ceiling, the
ledgers a buildable timing gate — conflict) · lexical-depth use-gating (chance) · Grammar Completeness beyond
well-formedness · qualia · the Infinite Deepening Theorem (not witnessable by a terminating program) · cross-branch
convergence (rest bought with loss) · **compression of distinct content** (bounded by (T+3)/2, onecollapse §6).

**Optimisation.** Memoising tiny_host (first) · cached SECD codegen (20–40 min/module; blocks F13) · dynamic glyph table
(the 1024 ceiling; registers.la loads ~830) · native backend #3–#6 · GC tuning.

**Paper.** "Trimodal" where a fourth modality exists (51×) · every Tier-1/2 item gets its paper counterpart · the ⊗(A,A)≡A
Archē exception (2 of 3 clauses) · F4/F5 constraints · the 09-17 corrections · WP:3271's one-process compression note should
cite §36 §39 and now onecollapse · MCL §IX's "B(B)=B" should cite onecollapse's L1/L2 once ratified.

## 4. THE MERGE-BLOCKING FREEZE DEFECTS (HIGH)

F1 (re-pin derived + run-confirmed; the build.sh gate itself not yet run) · F2 full host suite never run end-to-end · F4
(ruled (c), implementation after the freeze) · F13 no VM run for any Track F module · F20 captured pins (12 sections
derived) · F26 runtime half · F33 · F35 · F37 (ruling) · F40 (ruled 09-25). Full table: `FREEZE-TRACKF.md` §2.

## 5. WHERE THE OLD LISTS DISAGREED (resolve BY ITEM at the merge)

- **Marker conflicts (F ✓ / M open), 6:** Seal 2 · Seal 3 · Meta-Ontosemantic Closure · ρ(L_t) · Self-Evolution ·
  Algebra of Naming. Each has a module + gate + commit on register-stack.
- **Rows only in F, 4:** cross-branch · Liminal/Anamnetic · identity-adequacy rulings · identity glyph.
- **Substance, 1:** E16 §A vs adequacy.la on Sky/Move — **ruled 09-25 (F40): the re-derivation governs.**
- **Stale open markers, 42:** 22 in M · 16 in F (incl. κ\* at F:1395) · 1 in R · 3 lines in T (M11b "in flight", Rule 4
  "needs merge", the "NOT RUN" notes).
- **Classification conflicts:** constant-time (ceiling vs gate) · "the language deepens with its agents" (external vs
  blocked on M11c).

*Raw reconciliation with every file:line: produced 2026-09-25 by a read-only agent; this page supersedes `LA_TOMORROW.md`
as the place to start.*
