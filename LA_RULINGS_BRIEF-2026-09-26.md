# R-SP1 / R-SP3 — ruling brief (2026-09-26)

A DECISION AID, NOT A RULING. Nothing here is ruled: both items stay open in `LA_ROADMAP.md` §2 until Erik rules.
Every excerpt below was extracted with `sed -n` from the source file at the stated lines — quoted, not paraphrased.
Sources: MCL = `~/Downloads/CODICIES/Papers/Metacursive_Collapse_of_Language.tex` · CODEX = `~/logos/codices/Codex Llogoscribeologiae.tex`
(the gitignored copy; `~/logos_codices_preserved/` holds another) · LA = `~/logos-f/LINGUA_ADAMICA.tex`.

## R-SP1 — the hexary fusion's sixth member

### The sources, verbatim

`MCL:1275-1277`
```tex
\begin{center}
    \itshape
    Six classical branches fuse in 57 ways.\\
```

`MCL:1301-1303`
```tex
\noindent\textbf{Hexary Fusion} (1 total):

\begin{center}\adjustbox{max width=\textwidth}{$\boxed{\text{Phon} \oplus \text{Morph} \oplus \text{Syn} \oplus \text{Sem} \oplus \text{Prag} \oplus \text{Disc} = \text{Ontosemiosyntax} = \exists(\exists) \equiv \exists.}$}\end{center}
```

`CODEX:2148-2155`
```tex
Phonology & Sound & Logos $\cap$ Sound\\
Morphology & Word-form & Logos $\cap$ Word-form\\
Syntax & Sentence & Logos $\cap$ Sentence\\
Semantics & Meaning & Logos $\cap$ Meaning\\
Pragmatics & Use & Logos $\cap$ Use\\
Discourse & Text & Logos $\cap$ Text\\
Sociolinguistics & Society & Logos $\cap$ Society\\
Psycholinguistics & Mind & Logos $\cap$ Mind\\
```

`CODEX:2505-2508`
```tex
\textbf{Ontosemiosyntax} is the complete circuit:

\tautology{\text{Ontosemiosyntax} = \text{Ontosyntax} \oplus \text{Ontosemiosis} \oplus \text{Ontosemantics}}

```

`CODEX:9100-9110`
```tex
\begin{center}
\begin{tabular}{l|cccccc}
 & \textbf{Syn} & \textbf{Sem} & \textbf{Morph} & \textbf{Phon} & \textbf{Prag} & \textbf{Semio}\\
\hline
\textbf{Ontosyntax} & --- & Ontosemiosyn & Ontosyntactomorph & Ontophonsyn & Ontopragmasyn & Ontosemiosyn\\
\textbf{Ontosemantics} & & --- & Ontomorphosem & Ontophonosem & Ontopragmasem & Ontosemiosem\\
\textbf{Ontomorphology} & & & --- & Ontophonomorph & Ontopragmamorph & Ontosemiomorph\\
\textbf{Ontophonology} & & & & --- & Ontopragmaphon & Ontosemiophon\\
\textbf{Ontopragmatics} & & & & & --- & Ontosemioprag\\
\textbf{Ontosemiosis} & & & & & & ---\\
\end{tabular}
```

`CODEX:9116-9128`
```tex
\noindent Total binary fusions: 15.\\
Total ternary fusions (three branches): 20.\\
Total quaternary fusions (four branches): 15.\\
Total quinary fusions (five branches): 6.\\
Total complete fusion (all six): 1.

\noindent The complete fusion is:

\begin{center}
\Large\textbf{Meta-Ontogrammar}
\end{center}

\tautology{\text{Meta-Ontogrammar} = \bigcap_{i} \text{OntoBranch}_i = \exists(\exists) \equiv \exists}
```

`MCL (collapse table):1335-1338`
```tex
Psycholinguistics & Mind(Mind) & Thought IS inner speech of Being \\
Historical Ling. & Time(Time) & Change IS Logos remembering \\
Computational Ling. & Code(Code) & Logos computes itself \\
Discourse & Text(Text) & Coherence IS Logos weaving \\
```

### What the excerpts show
1. **Two different six-lists, not two readings of one list.** MCL fuses "Six classical branches"; the CODEX's own
   classical table (2148–2155) has the same six, Discourse sixth. The CODEX's Semiosis six is its ONTO-branch list (§XIII–XV).
2. **The one real collision is a NAME.** MCL:1303 names the hexad "Ontosemiosyntax". CODEX:2507 uses "Ontosemiosyntax" for a
   TRIAD (Ontosyntax ⊕ Ontosemiosis ⊕ Ontosemantics) and names its hexad "Meta-Ontogrammar" (§XV). ★ Renaming the built seal
   "to what MCL calls it" does NOT remove the collision — MCL is the source that uses the colliding name. The non-colliding
   name in the corpus is the CODEX's "Meta-Ontogrammar" (though that names the ONTO-six's fusion, not the classical six's).
3. **A second collision inside the CODEX matrix:** Syn×Sem and Syn×Semio are both "Ontosemiosyn" (row Ontosyntax, 9100–9110).
4. **"Phon" is ambiguous.** MCL's collapse table gives Sound to Phonetics and Pattern to Phonology; the CODEX classical table
   gives Sound to Phonology. `onecollapse.la` OC_HEX takes branch index 0 = phonetics and skips phonology (index 1) —
   recorded nowhere in the repo. Whatever the ruling, it should be written down.
   Evidence already in the repo: the branch-rank derivation (F37, `derive/branchrank.py`, 09-18; `sweeps/21-BRANCH-
   RECONCILIATION.md` §E) finds **phonology = ↻(phonetics)** in the FORM register — phonology is DERIVED from phonetics,
   not an irreducible generator. So the build's pick (phonetics) is the generator of the pair; picking phonology would put
   a derived branch in the hexad. This supports the build's reading; it does not decide it.
   (R-B1/R-B2, the deferred branches, are already briefed in `sweeps/19-…` §3 and `sweeps/21-…` §D — not repeated here.)

### What the build does today
`onecollapse.la` builds Phon⊕Morph⊕Syn⊕Sem⊕Prag⊕Disc from `branchgenesis.la` BASE_BRANCHES indices 0 2 3 4 5 6 (phonetics
morphology syntax semantics pragmatics discourse) and names the seal ONTOSEMIOSYNTAX. Both candidates are among the 19 gated
branches: discourse = ⊗(FORM,LOVE), semiotics = ↻(FORM). Ruling Semiosis changes exactly the last term of the pinned §50 seal
(`⊗(FORM,LOVE)` → `↻(FORM)`) — by substitution in the formula, NOT RUN.

### The three questions
(1) classical six (Disc, as built) or Onto-six (Semio) · (2) which name the hexad carries · (3) Phon = phonetics or phonology.

### Outside review received (2026-09-26, pasted by Erik; ADVICE, not a ruling)
Keep Discourse (two sources agree on the classical six); rename the hexad so it no longer collides with the codex's triad
(see ★ in point 2 — the suggested "MCL's name" is the colliding one); write the Phon choice down as a ruling either way.

## R-SP3 — the phonym grows under ⊕ ▷ ⊂ ↻

### The sources, verbatim

`LA:5102-5116`
```tex
\section{Operator Phonology: How Combination Sounds}

The five combination operators determine \textit{how} component phonyms merge. Each operator has a distinct \textbf{prosodic signature}---a mode of phonetic blending that is audible to a trained listener:

\begin{center}
\begin{tabular}{l l l}
\toprule
\textbf{Operator} & \textbf{Prosodic Signature} & \textbf{Notation} \\
\midrule
$\otimes$ (Ontosynthesis) & Smooth fusion: phonyms flow into one prosodic unit & $AB$ \\
$\oplus$ (Ontoconjunction) & Glottal pause: brief /\textglotstop/ between phonyms & $A$\textperiodcentered$B$ \\
$\triangleright$ (Ontodirection) & Stress-link: first phonym stressed, second light & $\acute{A}B$ \\
$\subset$ (Ontocontainment) & Embedding: second phonym envelops first as frame & $B[A]B$ \\
$\circlearrowleft$ (Metacursion) & Reduplication: phonym repeated identically & $AA$ \\
\bottomrule
```

`LA:3018-3020`
```tex
    \item \textbf{Temporal Integration}: The duration and prosodic contour of $P(\mathfrak{g}_C)$ integrates the temporal features of both parents into a single prosodic unit.
    \item \textbf{Articulatory Path}: In the articulatory space, $P(\mathfrak{g}_C)$ traces a path from the articulatory configuration of $P(\mathfrak{g}_A)$ through the configuration of $P(\mathfrak{g}_B)$, yielding a phoneme that is kinetically intermediate.
    \item \textbf{Mode Prefix}: In analytic (unsealed) speech, the mode's own phoneme is prefixed to the blend. In sealed (fluent) speech, the mode is absorbed into the prosodic contour.
```

`LA:4233`
```tex
    \item \textbf{Temporal compression.} The duration of $\pi_C$ is no longer than the maximum of the parent durations---the blend is a \textit{fusion}, not a concatenation.
```

`LA:4120`
```tex
In fluent speech, most expressions of moderate complexity will already have been sealed into single glyphs. Serialization is for \textit{novel} combinations or \textit{analytic} discourse.
```

`LA:5132`
```tex
When combining already-derived glyphs (Level 2 and deeper), spectral interpolation compresses the result into a single syllable, as demonstrated in the worked example of \S\ref{sec:phonetic-blend}. At deeper levels, the blending preserves \textit{traces} of ancestral phonyms: the onset carries the first ancestor, the nucleus carries the second, and transitions encode the operator. A trained ear can parse the lineage from a single syllable.
```

### What the excerpts show
LA separates ANALYTIC (unsealed) speech — the Operator Phonology table, where ⊕ ▷ ⊂ ↻ serialize — from SEALED (fluent) speech,
where "the mode is absorbed into the prosodic contour" and duration is at most the parents' maximum. `phonym.la` implements
only the analytic table, so `unified.la`'s measured growth is CORRECT for analytic speech; the codex's sealed fusion is unbuilt.
Bound on the fusion option: a phonym of bounded duration and bandwidth carries finitely many distinguishable signals, so full
fusion cannot stay injective over unboundedly many concepts — the codex's Deep Blending already keeps only "traces" (5132).

### The question
Should phonym.la gain a sealed rendering (new scope), and if so, is trace-only recoverability a ruled [B] bound?

### Outside review received (2026-09-26; ADVICE, not a ruling)
Defer R-SP3: a sealed rendering is new scope, not closing existing scope, unless something blocked depends on it.
(Checked: nothing on LA_ROADMAP.md §1 depends on it except S8/S9, which are the phonetic items themselves.)
