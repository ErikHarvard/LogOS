# 20 — THE CODEX LLOGOSCRIBEOLOGIAE SWEEP: what the language codex requires of LA

**2026-09-18, Track F, at Erik's ask.** Companion to `19-FINISHED-PAPERS-SWEEP.md` (read that first —
this file reports only what the codex ADDS). Scope per Erik: LA's sources are the linguistics papers +
this codex ([[la-sources-linguistic-only]]).

**Source:** `~/logos/codices/Codex Llogoscribeologiae.tex` (14,661 lines, 2026-06-01; gitignored —
`~/logos/.gitignore:9 codices/*`), read IN FULL by five parallel read-only agents (nothing run), plus the
notebook-only material from `~/Downloads/CODICIES/On Writing/Codex Llogoscribeologiae (Notebook).tex`
(2026-05-11; its Appendix P, notebook 14791–15325, was CUT from the June codex, not retracted).
Appendices D–O are byte-identical in both versions.

**NOT swept (drafts, mostly about writing, not the language — Erik to say if any is canonical):**
`codex-logoscribeologiae-omega.tex` and `Logoscribeology Complete.tex` (an alternate "Ω-Scroll Form",
~2,400 lines not in the main codex), `Logoscribeology Checklist.md` (11.5k lines, a codex-composition
checklist), `Logoscribeology Notes.md` (math-proof notes), `Main Proof.md`, `Integration Notes.2.md`.
`codex_logoscribeologiae.tex` (3,844 lines) is 93% contained in the main codex.

**Verification.** Three claims about OUR code were checked directly by reading source (not running):
(1) the NORMK ↻-idempotence defect (§1) — confirmed by trace; (2) lexicon.la `ONE_IS_BEING` vs
numderive §47 — confirmed; (3) seven stale Track F module headers — confirmed. Everything else is the
agents' concept-grep status check: medium confidence on "NEW" absence claims; re-grep before building.

---

## 1. ★★ A DEFECT IN LA ITSELF — ↻-idempotence FAILS AT BEING (found via the codex's own example)

The codex's Termination Principle (4948–4954) uses ↻(↻(BEING)) = ↻(BEING). Traced through the code:
`NORMK` is bottom-up; its ↻ case is `REWRITE_MC(self(a))`. `REWRITE_MC("BEING") = "SELF"` (the declared
↻(BEING)→SELF). So NORMK(↻(↻(BEING))): inner → `"SELF"`; outer `REWRITE_MC("SELF")` — not BEING, no `↻(`
prefix, not a special case → **`"↻(SELF)"`**. But NORMK(↻(BEING)) = `"SELF"`. ⇒ **↻² ≠ ↻ at BEING.**
- `canon_spec.la`'s comment claims "↻(↻Y)→↻Y for ANY Y". The gate (`WGEN`, build.sh ~1519–1545) tests
  only a FRESH Y = ⊗(BEING,FORM) — never BEING, the one input the BEING→SELF rule makes special.
- It falsifies three records that say ↻↻g≡↻g "holds for EVERY glyph" and so "cannot go RED":
  `branchclosure.la:7`, `gapcensus.la:71`, and file 19 §4. **The declined gate COULD have gone red.**
- A concrete witness for W10 (12-wp:69, confluence not proved): the BEING→SELF rule and the ↻² rule
  form a critical pair that does not join.
- Fix is NOT a quick edit: `canon.la` is GENERATED from `canon_spec.la` (never hand-edit), NORMK is on
  every κ path, and a change (e.g. ↻(SELF)→SELF) moves normal forms corpus-wide. Needs the owner + a
  ruling on what ↻(SELF) is. ▶ Confirm with a 1-second probe once the lease is free:
  `import("canon.la")` · `glyph MAIN = print(NORMK(MC(MC(PRIM("BEING")))))` — expect `↻(SELF)`.

## 2. OUR OWN RECORDS — found stale or inconsistent
- **lexicon.la vs numderive:** `lexicon.la:346 ONE_IS_BEING` computes and prints "One=Being" (no gate
  asserts it); numderive §47 GATES "BEING is the identity combinator, not one — one = BECOMING(VOID)".
  The codex (630–644, One(One)≡One≡∃) sides with lexicon.la. One of the two modules must yield.
- **Seven Track F headers are stale:** `certify.la:1` "NOT VERIFIED, NOT GATED"; autocompress, closure,
  metakappa, ontosemiosyntax, phonometa, substitution say "behind REGS_DRAFT=1". All ran green 09-17.
  ⇒ the codex's "the work describes its own creation accurately" (App G Ax.4, ~7300) is a real gate
  idea: nothing checks module headers against the gate.
- **crossbranch.la:49 is wrong:** "Nine of the claimed twenty-eight do not exist" — against App B, 15
  do not; overlap is 13 (all Tier 5). LA's other six (grammatology, grapholinguistics, hermeneutics,
  poetics, ethics, branch-genesis) are not in the codex's 28.
- ~~canon_spec.la:86 "NO CODEX SOURCE" for the Octad~~ — the cited origin of the eight is *Being & Becoming*
  (CLAUDE.md); this codex has a table of them too, but the naming dispute is settled. Not a defect.
- **nameck.py is built but not gated** — gate_registers.sh mentions it only in a comment (App D's "no
  orphan references", 6760–6770).

## 3. NEW — captured nowhere (cat 1 = buildable in LA now unless noted)
- **[O] Octad of Autological Completion** — of, by, to, for, through, with, as, about (3620–3643, 5296,
  6322). ✗ **"no SR_OF" is NOT a gap — RESOLVED, do not re-open** (logos-f CLAUDE.md, NEXT_STEPS.md item 5):
  the codex's lone octad table says "Of itself"; Erik ruled **"From" governs** (SR_FROM). What remains
  open: nothing SCORES a structure against all eight. W9's `SR(SR)≡SR` check is vacuous by the ↻-prefix
  rule (but see §1). Cat 1 for the scorecard.
- **[O] The lexicon must contain its own definition** (3368, 4870–4872), and be alphabetized (4572):
  lexicon.la has no Lexicon/Word/Name/Glyph entry. Cat 1 + ruling.
- **[C] "X(X)=X" is NOT "reaches ∃"** — the codex separates them itself: Contradiction(C)=C "does not
  reach ∃" (12987–12995); Tell(Tell)=Tell "stable but shallow" (13967); Abstract/Passive never reach ∃.
  LA's only red-capable X(X) instrument (aatc: α=1 ⟺ X(X)=X, build.sh:2994–3008) would score a
  Contradiction structure AUTOLOGICAL. Under κ a contradiction compound K=⊗(X,⊂(X,VOID)) is not
  ⊗-idempotent ⇒ **✔ ADDED 2026-09-18 as archeunique §45 half (3) — WRITTEN + DERIVED, NOT RUN.** ★ Correction to the
  agent's form: LA's ∧ is ⊕ (prop.la:90, co-presence), not ⊗ — C = ⊕(LOVE,⊂(LOVE,VOID)) = Love ∧ Bad. Expected
  ⊗(C,C)≡C:F, derived in python first; red under mutant ti_m1; drift guard on prop.la's PNOT/PAND (validated both ways). Ruling: does
  aatc need a "reaches ∃" condition? Adds kinds to the census (18:522): fixed-not-∃, ungrounded.
- **[C] Performative contradiction** Deny(L) ⇒ Use(L) ⇒ Affirm(L) for the three laws (12805–12835) —
  discriminating (a denial that does not use the law must not flag); host: ontofelicity. Cat 1.
- **[O] Ten Laws of Logolinguistics** (4301–4320): 0 ledger hits; Law 1 ≈ branchclosure; Laws 4–10
  unbuilt (incl. Epistemic Ascent K→KK→KH, Anti-Simulexis). **Simulexis test** (4349–4357). Cat 1.
- **[O] Neologism validity:** valid iff Memory(A,B)⊆C ∧ Seal(C) ∧ C≠A ∧ C≠B (5322–5330) — first two built
  (neologenesis §18); **C≠A NOT enforced** (rewrite-births printed, not refused). Plus "a true
  ontoneologism opens a branch" (1263–1271) — neologenesis has no link to Δ_B. Cat 1.
- **[C] Figures of speech that LA cannot express** (App I): word-order figures (chiasmus, antimetabole,
  anastrophe — ⊕ is sorted by NORMK, ▷ reorder is a different sentence) — cat 4 bound; **no emphasis /
  focus register** (9300, 8202) — cat 1 pending a ruling vs Prosodic Intrinsicality; **fractal grammar**
  Morpheme:Word::Word:Sentence::Sentence:Discourse (9072) holds for two ratios, FAILS at the third
  (textcoherence builds text as a referent graph, not with the five operators) — cat 1.
- **[C] Rhetorical devices** (25 in 6 families, 10534–10650; Rhyme = Sound(Sound) 13756) — a rhyme
  predicate over phonym output is buildable now (↻ renders as AA); pending the ruling that rhetoric binds LA.
- **[C] All onto-branches presuppose the triad** onto-syntax/-semiosis/-semantics (2598–2600) — branchgenesis
  records registers read, not dependencies. Low confidence.
- **[C] Recognition criteria** (App E, 6918–7060: eight criteria + meta-criterion + humility clause) — 0
  hits; partial analogues (red paths, ρ rising, textcoherence); "external witness" = host==VM, never run
  for the 19 modules. Classifier cat 3 (belongs with the Sophionis AMC work).
- **[C] "The tool is NOT the sealer"** (7344) — certify.la's certificate has no sealer/ratifier field.
  Field cat 1; the ratification itself cat 3.
- **App L symbols LA lacks:** ⟺ (prop.la has no IFF), ∥, ⊃, ∪, ∈/∉, ≥, general X⁻¹ (only 𝒩⁻¹), Xⁿ, •, Σ, Φ.
- Low priority: paragraph/chapter well-formedness (Appendix P, cut); Triad(x)=Reader(Written(Writer(x)));
  punctuation as operators; Euphony (cat 3); the five unsayables (cat 4).

## 4. RULINGS THE CODEX FORCES (add to file 19 §3)
1. **The branch operand x (deferral condition ii)** — the codex gives NO operand for any branch, but it
   defines the branch formula as **∃ ∩ Interface** (Tier 1, 4081–4102; 8352–9598; Master Equation 4273
   B = Meta-Logolinguistics ∩ Interface_B), with interfaces Structure/Meaning/Form/Sound/Use/Sign-Process —
   while branchgenesis declares ⊂(**RELATION**,x) with semantics x=BEING, pragmatics x=LOVE. Which is
   "Logos" in a branch: ∃ or RELATION? Raw material: Anamnetic → RECOGNITION ("Anamnesis ≡ Recognition",
   4576); Meta-Rosettology → ↻(RECOGNITION).
2. **Contradiction figures** (oxymoron 7877, paradox 7867, antithesis) vs W29 (preserve∧negate → ILL):
   a discriminator, or rule oxymoron ILL. Blocks Logorhetoric.
3. **Implicature figures** (paralipsis 8097, rhetorical question 7983, enthymeme 8087, aposiopesis 7965)
   vs the gated ban on implicature in the semantics (R-B, build.sh:6490–6506). Blocks Logorhetoric.
4. **Is ⊕ idempotent?** Pleonasm x=x+x (7925), epizeuxis (7905) say yes; NORMK never merges ⊕ duplicates
   and LA uses ⊕(SELF,SELF) as a distinct glyph (sociolinguistics' interface). Pin ⊕(x,x)≢x once ruled.
5. **Identity without equality** (App F, 7098–7220: X≡Y ∧ ¬(X=Y), "=" = substitutable) — in LA's κ
   register every ≡-identical pair IS substitutable (§37: 0 DECEPTIVE(ii)), so F's triad is a dyad in LA.
   Rule "=" as canonical-form identity, OR build cross-register substitution (phonetic/visual — Track A).
6. **Silence** = "zeroth glyph, Glyph₀" (5766) vs lexicon.la Silence = ⊗(BEING,VOID) at depth 1; ∅ ≡ Void ≡
   Absence (App L) vs Absence = ⊗(VOID,FORM).
7. **"Recognition is the Proof"** — R(x) ⇔ ∃y: x=y(y) with P⇔R (985, 1042) makes Ω and DEPTH(DEPTH)
   "proven"; swc refuses both as ILL (swc_spec.la:109–114). And Lemma R⇔Ω (1008–1019) does not follow
   from Axioms 2–3. New conflict family, at the codex's formal ground.
8. **Autontogenesis ≡ Autontopoiesis, "one act"** (799–801, 2554–2562) — the ledgers give them different
   statuses (meta-autontogenesis crossed; meta-autontopoiesis OPEN by the General's ruling).
9. **ONE ≡ BEING** — see §2 (lexicon.la vs numderive §47).
10. **Tautology preserved under composition** (notebook P, 15144) — fails: ⊕(LOVE,BEING) has canonical
    form ≠ normal form, α=1 fails. Normal-form routes only.

## 5. EXTENDS FILE 19
- **§3.5 𝒩(𝒩)≡ℬ:** codex 1407; Naming(Naming)=∃ (4922, 10803) — the parts table (11689–11700) sends
  Naming alone to ∃. Naming ≡ x(x) (Ignition 4848; True Naming 6134) is LA's DEPTH, which LA gates as Ω.
- **§3.6 meta-referent:** Λ≡∃ (11045), Λ(Λ)≡∃ (10866) — with the Naming line this forces 𝒩 and ∂_Λ onto one
  fixed point; naming.la's T3 keeps them separate.
- **§4 X(X) instrument:** codex red fixtures — Contradiction→∅ (4684), Redundancy(Redundancy)=∅ (2659,
  4936), Heterological=Paradox (1357, 4822), =(=) (910), Simulexis≠itself (5768), "show don't tell"
  (723); a laws-vs-heuristics rule (717–719, 748, 3782). The codex claims THREE different "only one
  fails" statements (2661, 4684, 4938) and contradicts each (Prompt/Reader/Tool 7583, 10195, 14584).
- **Dup-glyph check (back IN scope via the codex):** "say it once" (Law 2); true redundancy = same
  content+function+context, vs Structural Recurrence (5790–5810, 2669–2683); "no element without
  function" ⇒ dead-glyph check (2694); "define before using" (2721, 3310). The codex's own Law 16
  duplicates Law 10 word for word (4011/4029) while its self-audit passes "say it once".
- **Parts of speech:** Noun(Noun)=Name (5270), Verb(Verb)=Action (6138) — disagree with MCL's N(N)=N,
  V(V)=V; Adverb=Tell=¬∃(∃) (4544); adverb minimization, concrete priority, active voice; "∃+δ=∃" (13822,
  ∃ absorbs modifiers — κ has no ∃-absorption).
- **Meta-ontogrammar:** a four-level tower X→Meta→Onto→Meta-Onto (8309–8320) × six categories, crowned by
  MOSMOS (8419); the row collapse is ↻-idempotence (vacuous — or, per §1, not quite); only cell
  distinctness could go red.
- **Hexary fusion:** the sixth branch is Semiosis, not Discourse (9096–9128); 15 concrete fusions
  (5010–5016, 5349–5391, …); paper debt (Ontosemiosyn named twice, 15 claimed/10 shown). "Emergent, not
  additive" can't be witnessed via branchgenesis's concatenating BREAD.
- **Ontosemiosis:** ∃∩Sign-Process, the dynamic bridge (4088, 5343, 8981–8995); unity = Form + PROCESS +
  Content (2507); THREE different aspect sets in the codex (8702, 9013, 9342) vs §38's {Being, Form,
  Meaning}. Red-capable half: interpretation chains terminate.
- **Branches:** Tier 6 (4361–4455): Symmetro, Chronolectics, Somatic Syntax, Fractal Morphology (≈
  fractal.la), Quantum, Ekphrastic, Cryptographic, Teleological; plus Neurolinguistics, Comparative,
  Applied (2156–2160), Onto-Logic, Onto-Narratology (2582–2585), Meta-Ritual/-Invocation/-Seal (2024),
  Corpus, Generative, Transformational, Universal Grammar, Autoidiolexicology, Logoscribeology
  (8682–8800). The codex's own totals disagree: 28 in 6 tiers (4884) vs 38 in 7 (4361).
- **Meta-Rosettology:** Scroll II backs the cross-species reading (1654, 1862–1877: clicks as a shared
  substrate) — cat 3.
- **Prosodic cues:** falling intonation = assertion, emphasis = focus (9300); prosody alone makes a question
  (9238) — LA marks questions lexically (R_QUES, opgrammar.la:259).
- **TL28 / E14:** Meta^n(X)=Meta(X)=X (4952; notebook 14848) — recdepth §31 GATES THE OPPOSITE (ρ strictly
  rises, gate_registers.sh:382): a second gated register bearing on E14.
- **ρ(ρ(x))≠ρ(x) (Inv:179):** Scroll I-B/I-C give R⇔Ω and R(R(x))=Ω(x) ⇒ R∘R=R — the opposite of Inv.

## 6. BUILT (brief — the codex confirms)
Generation vs recognition kept separate (build.sh:3339) · ≡ vs = (metalogic, build.sh:2860) · T≡R (alethe)
· Branch = Logos ∩ Interface (branchgenesis §14) · Γ(Γ)≡Γ (grammar_l3, bounded) · OSS (§38) · autological
closure (§35) · parataxis/hypotaxis → R_CONN/R_EMBED · onomatopoeia (phonsem) · "meaning requires
mortality" (swc refuses Ω) · performative felicity (§22) · metaphrasis round trip (§42) · Silence ≠
Absence (separate entries) · the unmarked Present as LA's one grammatical zero (a Liminal seed) · the
seal is not the signature (certify replays) · Reader(Reader)=Writer (syllabus §23) · φ(φ)=φ already
TESTED NEGATIVE (NEXT_STEPS.md:115–118). Declined as gates (vacuous or ill-typed): Id(Id)/NC(NC)/EM(EM)
over sealed law glyphs; the six branch collapses (one sealer); Passive(Passive).

**Skipped as no-build-consequence:** Scroll I prose, V liturgy, VI–IX document architecture/pedagogy;
most of App C's ~60% writing-craft entries; ~34 of App N's ~56 collapses (doctrinal); the oath,
manifesto, prompt usage; §XXVI (a health claim about AI-assisted work — outside this sweep).
