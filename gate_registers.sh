#!/bin/sh
# ── gate_registers.sh — THE REGISTER STACK GATE (Track F, directive 2026-09-15) ────────
#  Governing law (directive §0): naming a register prevents nothing; only a check that
#  can go RED counts as built. Three legs per module:
#     1  HOST    the module runs on tiny_host and prints EXACT witnesses (an exact value
#                is what lets a gate fail); every witness below was pre-registered from a
#                green run and re-derived here, never pasted from a claim
#     2  RED     a MUTANT of the module (one rule broken by sed) must turn the witness
#                RED and NAME the offender — an instrument must prove it looked
#     3  VM      host == native SECD VM, byte for byte (REGS_VM=0 skips; it is the slow leg)
#  Plus the loop the modules cannot close themselves: every W-tagged evidential entry
#  cites a build.sh gate; the cited say-line must EXIST in build.sh.
#  Scratch lives INSIDE the worktree (never /tmp: the launcher's private tmpfs is
#  invisible across sessions and the build's /tmp paths are the collision surface).
set -u
cd "$(dirname "$0")" || exit 1
ok=1
T=$(mktemp -d ./.regs_gate_XXXXXX) || exit 1
trap 'rm -rf "$T" logos_source.la logos_program.bin' EXIT
[ -x ./tiny_host ] || gcc -O2 -Wall -Wextra -o tiny_host tiny_host.c || { echo "FAIL  registers: no tiny_host"; exit 1; }

# host(module, out) — run on the host into $T/out; rc recorded
host() { timeout 1800 ./tiny_host "$1" > "$T/$2" 2>&1; echo $? > "$T/$2.rc"; }
# want(out, token, label) — exact witness present
want() { if grep -qF -- "$2" "$T/$1"; then :; else echo "FAIL  registers/$3: missing witness [$2] — got: $(head -c 300 "$T/$1")"; ok=0; fi; }
# red(mutfile, token, label) — the mutant's output must NOT carry the green witness and must carry the red one
red() { if grep -qF -- "$2" "$T/$1"; then :; else echo "FAIL  registers/$3: the RED path did not fire — mutant still reads green: $(head -c 200 "$T/$1")"; ok=0; fi; }

# ═══ 1. lineage — the etymological register ═══════════════════════════════
host lineage.la lin
want lin "recoverable from lineage alone:T" lineage
want lin "every parent precedes its def:T" lineage
want lin "broken-parent fixture refused:T OFFENDER=⊗0.7" lineage
want lin "sharing visible (DAG<tree, 4 defs):T" lineage
want lin "Δ_E(Δ_E)≡Δ_E truth:T glyph:F" lineage
sed 's|^glyph RECOVER = la form. NORMK(DECOMP(form))|glyph RECOVER = la form. form|' lineage.la > "$T/lin_m1.la"; host "$T/lin_m1.la" lin_m1
red lin_m1 "recoverable from lineage alone:F OFFENDER=KAPPA" "lineage RED(recovery bypassed)"
sed 's|^glyph PARENT_OK = la i. la s. lt(str_to_int(s))(i)|glyph PARENT_OK = la i. la s. TRUE|' lineage.la > "$T/lin_m2.la"; host "$T/lin_m2.la" lin_m2
red lin_m2 "broken-parent fixture refused:F" "lineage RED(parent check disabled)"

# ═══ 2. prosody — the prosodic register (+ the phonym cross-check) ═════════
host prosody.la pro
want pro "segments distinct=1 prosody distinct=5 separable:T" prosody
want pro "⊕ dur=14240 | ▷ dur=13280 | ⊂ dur=20000 | ↻ dur=13120" prosody
want pro "↻↻x vs ↻x contour equal:F identity (NIS):T" prosody
want pro "Δ_P(Δ_P)≡Δ_P truth:T glyph:F" prosody
sed 's|PAIR(concat("(")(concat(FST(pb))(concat(")\[")(concat(FST(pa))(concat("](")(concat(FST(pb))(")")))))))|PAIR(concat("(")(concat(FST(pa))(concat(")·ʔ·(")(concat(FST(pb))(")")))))|' prosody.la > "$T/pro_m1.la"; host "$T/pro_m1.la" pro_m1
red pro_m1 "prosody distinct=4 separable:F" "prosody RED(⊂ contour collapsed onto ⊕)"
host prosody_xcheck.la prx
want prx "PROSODY-XCHECK phonym durations agree 14/14:T" prosody_xcheck
sed 's|(la _. 6080)|(la _. 6081)|' prosody.la > prosody_mut.la
sed 's|import("prosody.la")|import("prosody_mut.la")|' prosody_xcheck.la > "$T/prx_m1.la"; host "$T/prx_m1.la" prx_m1; rm -f prosody_mut.la
red prx_m1 "agree 14/14:F OFFENDER=BEING phonym=6080 prosody=6081" "prosody_xcheck RED(duration drift named)"

# ═══ 3. topology — the topological register ════════════════════════════════
host topology.la top
want top "every lineage computes (no ⊥):T | corrupted DAG reads ⊥:T | ⊕-order invariant:T" topology
want top "κ tree: V=3 E=2 b0=1 b1=0 depth=1 leaves=2 anchors=2 grounded=T" topology
want top "⊗(κ,κ) shared: V=4 E=4 b0=1 b1=1 depth=2 leaves=2 anchors=2 grounded=T" topology
want top "MetaTop(MetaTop)≡MetaTop truth:T glyph:F" topology
sed 's|^glyph TOPO = la form. IF(str_eq(LINEAGE_OK(form))(""))|glyph TOPO = la form. IF(TRUE)|' topology.la > "$T/top_m1.la"; host "$T/top_m1.la" top_m1
red top_m1 "corrupted DAG reads ⊥:F" "topology RED(validity skipped)"
sed 's|^glyph TOPO = la form. IF(str_eq(LINEAGE_OK(form))(""))|glyph TOPO = la form. IF(FALSE)|' topology.la > "$T/top_m2.la"; host "$T/top_m2.la" top_m2
red top_m2 "every lineage computes (no ⊥):F OFFENDER=KAPPA" "topology RED(all ⊥ named)"

# ═══ 4. evidential — the evidential register (+ the build.sh citation loop) ═
host evidential.la evd
want evd "all declared:T | all tags valid:T | one κ one tag:T | undeclared reads ⊥:T | empty-tag refused:T | bad-tag refused:T | same-κ-two-tags refused:T" evidential
want evd "reads itself as:B | Δ_Ev(Δ_Ev)≡Δ_Ev truth:T glyph:F" evidential
sed 's|CONS(EVG("W")("Metaglyph: 𝓜 ⊂ 𝒜")(SEALc(REVAL)))(|CONS(EVG("")("Metaglyph: 𝓜 ⊂ 𝒜")(SEALc(REVAL)))(|' evidential.la > "$T/evd_m1.la"; host "$T/evd_m1.la" evd_m1
red evd_m1 "all declared:F OFFENDER=▷(DEPTH,RECOGNITION)" "evidential RED(undeclared entry named)"
sed 's|CONS(EVG("A")("declared 2026-09-15; no gate")|CONS(EVG("Q")("declared 2026-09-15; no gate")|' evidential.la > "$T/evd_m2.la"; host "$T/evd_m2.la" evd_m2
red evd_m2 "all tags valid:F OFFENDER=▷(RECOGNITION,↻(SELF))" "evidential RED(bad tag named)"
# every W cites a gate that EXISTS in build.sh (checks existence, not that it asserts this glyph)
ncite=0
while IFS= read -r line; do
    cite=${line##* | }; kappa=$(printf '%s' "$line" | cut -d'|' -f2 | sed 's/^ *//; s/ *$//')
    ncite=$((ncite + 1))
    if grep -qF -- "$cite" build.sh; then :; else echo "FAIL  registers/evidential: W-tagged $kappa cites [$cite], which is not a build.sh say-line"; ok=0; fi
done <<EOF2
$(grep '^EV W ' "$T/evd")
EOF2
[ "$ncite" -ge 19 ] || { echo "FAIL  registers/evidential: expected at least 19 W citations to check, saw $ncite"; ok=0; }

# ═══ 5. texture — the affective register ════════════════════════════════════
host texture.la tex
want tex "distinct textures=5 varies:T | none ⊥:T | ⊕-order invariant:T | corrupted reads ⊥:T | κ: m=100 a=66 r=50 | ⊗(κ,κ): m=133 a=50 r=33" texture
want tex "Δ_A(Δ_A)≡Δ_A truth:T glyph:F" texture
sed 's|^glyph TEXTURE = la form. IF(str_eq(LINEAGE_OK(form))(""))(la _. TEXTURE_STR(SPLIT(";")(form)))(la _. "⊥")|glyph TEXTURE = la form. "m=100 a=50 r=50"|' texture.la > "$T/tex_m1.la"; host "$T/tex_m1.la" tex_m1
red tex_m1 "distinct textures=1 varies:F" "texture RED(constant)"

# ═══ 6. registers — the twelve-fold coherence ═══════════════════════════════
host registers.la reg
want reg "REGISTERS stack=12 [phonetic glyphic semantic morphological syntactic pragmatic operational etymological prosodic evidential affective topological]" registers
want reg "coherence per register=TTTTTTTTTTTT all:T | raw-route register refused:T | semantic distinguishes ⊗(a,b)/⊗(b,a):T | NORMTREE==NORMK probes:T catalogue:T" registers
want reg "  evidential: W" registers
want reg "  topological: V=3 E=2 b0=1 b1=0 depth=1 leaves=2 anchors=2 grounded=T" registers
sed 's|      (la a. la b. (la x. la y. IF(LE(CANON(x))(CANON(y)))(la _. CON(x)(y))(la _. CON(y)(x)))(self(a))(self(b)))|      (la a. la b. CON(self(a))(self(b)))|' registers.la > "$T/reg_m1.la"; host "$T/reg_m1.la" reg_m1
red reg_m1 "coherence per register=FFFTFTTTFTTT all:F" "registers RED(⊕-sort removed: five registers named)"
red reg_m1 "NORMTREE==NORMK probes:F" "registers RED(differential)"
sed 's|  CONSc(REG("etymological") (G_ETYM)                             (R_ETYM) (ID_ETYM))(|  CONSc(REG("etymological") (G_ETYM)                             (R_ETYM) (R_ETYM))(|' registers.la > "$T/reg_m2.la"; host "$T/reg_m2.la" reg_m2
red reg_m2 "coherence per register=TTTTTTTFTTTT all:F" "registers RED(etymological projection un-normalised: position 8)"

# ═══ 7. modegenesis — Δ_M, four sub-gates ════════════════════════════════════
host modegenesis.la mg
want mg "ν* IRR/NOV/AUT/CON=TTTT admitted:T set=6 | F1 action≡⊗ =FTTF refused:T | F2 α-copy =FFTF refused:T | F3 false ren =TTFT refused:T | F4 constant =TTTF refused:T" modegenesis
want mg "re-admit ν* verdict=FFTF Δ_M(Δ_M)≡Δ_M idempotent:T" modegenesis
want mg "ν* action on (A,B): ⊗(▷(A,A),↻(B))" modegenesis
# each sub-gate's RED path is a fixture above (one letter apiece); the operator itself:
sed 's|^glyph ADMIT = la set. la c. IF(str_eq(VERDICT(set)(c))("TTTT"))|glyph ADMIT = la set. la c. IF(TRUE)|' modegenesis.la > "$T/mg_m1.la"; host "$T/mg_m1.la" mg_m1
red mg_m1 "F1 action≡⊗ =FTTF refused:F" "modegenesis RED(admission ignores the verdict)"

# ═══ 8. regenesis — Δ_R, four sub-gates ══════════════════════════════════════
host regenesis.la rg
want rg "Δ_R register IRR/NOV/AUT/CON=TTTT admitted:T stack=13 | F1 projection=FTTT | F2 α-copy=TFTT | F3 false ren=TTFT | F4 constant=TTTF | F5 raw-route=TTFT | all five refused:T" regenesis
want rg "re-admit verdict=FFTT Δ_R(Δ_R)≡Δ_R idempotent:T" regenesis
want rg "reads κ as TTTTTTTTTTTT and ↻↻κ as TTTTTTTFTTTT" regenesis
sed 's|^glyph ADMIT_R = la stack. la c. IF(str_eq(VERDICT_R(stack)(c))("TTTT"))|glyph ADMIT_R = la stack. la c. IF(TRUE)|' regenesis.la > "$T/rg_m1.la"; host "$T/rg_m1.la" rg_m1
red rg_m1 "all five refused:F" "regenesis RED(admission ignores the verdict)"

# ═══ 9. complement + opposite — the antonym structure, four gates ═════════════
host complement.la cmp
want cmp "COMPLEMENT ¬X = ⊂(X,VOID) (ruling 2026-08-23) shape==opgrammar NEG_SHAPE:T" complement
want cmp "sealed+VOID-parent:T | ¬C≠C glyph:T truth:T | ¬¬C≠¬C glyph:T truth:T | ¬¬C≠C glyph:T ¬¬C≡C truth:T ¬¬¬C≡¬C truth:T" complement
want cmp "two registers explicit: differ on ¬¬C:T coincide on C:T | conflated system would read ¬¬C≡C as:F" complement
want cmp "G_NOT=⊂(FORM,VOID) A(A)=⊂(⊂(FORM,VOID),VOID)" complement
want cmp "A(A)≠A glyph:T | A(A)≡id truth (cancels to the hole FORM):T" complement
sed 's|^glyph TRUTH_ID = la g. NORMK(CANCEL(ETYM(g)))|glyph TRUTH_ID = la g. NORMK(ETYM(g))|' complement.la > "$T/cmp_m1.la"; host "$T/cmp_m1.la" cmp_m1
red cmp_m1 "¬¬C≡C truth:F" "complement RED(double complement not cancelled)"
sed 's|^glyph NOTG = la g. COLLAPSE(NEG_MODE)(g)(GLYPH("VOID"))|glyph NOTG = la g. COLLAPSE(NEG_MODE)(g)(GLYPH("FORM"))|' complement.la > "$T/cmp_m2.la"; host "$T/cmp_m2.la" cmp_m2
red cmp_m2 "sealed+VOID-parent:F" "complement RED(¬ without Void)"
host opposite.la opp
want opp "OPP(Past)=▷(VOID,BECOMING) ≡Future:T | involution OPP(OPP(Past))=Past:T OPP(Past)≠Past:T | refuses primitive(Being):T ⊕:T ▷(x,x):T | HAS_POLE Past:T Being:F ->T" opposite
want opp "A(A)=▷(VOID,RELATION) exists:T A(A)≠A:T A(A(A))=A:T" opposite
sed 's|glyph OPP = la g. ETYM(g) (la nm. BOT(ETYM(g))) (la a. la b. BOT(ETYM(g))) (la a. la b. BOT(ETYM(g)))|glyph OPP = la g. ETYM(g) (la nm. BOT(ETYM(g))) (la a. la b. BOT(ETYM(g))) (la a. la b. SEALo(CON(b)(a)))|' opposite.la > "$T/opp_m1.la"; host "$T/opp_m1.la" opp_m1
red opp_m1 "⊕:F" "opposite RED(⊕ given a pole)"

# ═══ 12. textcoherence — whole-text coherence (the open discourse item) ═══════
host textcoherence.la tc
want tc "TEXTCOHERENCE text(a) n=5 edges=[2-1:share 3-2:contrast:opp 4-3:share 5-2:contrast:opp 5-3:share] components=1 coherent:T maxdist=3 orphans:none" textcoherence
want tc "referents=11 mentions=14 given=3 new=11" textcoherence
want tc "components=2 coherent:F maxdist=3 orphans:OFFENDER=⊂(FORM,DEPTH)" textcoherence
want tc "each label fires alone:T" textcoherence
want tc "components order-independent:T maxdist original=3 shuffled=4" textcoherence
sed 's|^glyph TC_SHARE1 = la a. la b. str_eq(TC_T3A(a))(TC_T3A(b))|glyph TC_SHARE1 = la a. la b. FALSE|' textcoherence.la > "$T/tc_m1.la"; host "$T/tc_m1.la" tc_m1
red tc_m1 "components=3 coherent:F" "textcoherence RED(share links off: orphans named)"
sed 's|^glyph TC_OPP1   = la a. la b. str_eq(TC_T3C(a))(TC_T3A(b))|glyph TC_OPP1   = la a. la b. FALSE|' textcoherence.la > "$T/tc_m2.la"; host "$T/tc_m2.la" tc_m2
red tc_m2 "each label fires alone:F" "textcoherence RED(opposite contrast off)"
want tc "TEXTCOHERENCE score (Σ 100/link-distance) original=383 shuffled=191 | shuffled strictly lower:T" textcoherence
sed 's|add(acc)(div(100)(sub(TC_T3A(e))(TC_T3B(e))))|add(acc)(100)|' textcoherence.la > "$T/tc_m4.la"; host "$T/tc_m4.la" tc_m4
red tc_m4 "shuffled strictly lower:F" "textcoherence RED(distance-blind score reads shuffled equal)"
# ═══ 13. derive_closure — the derivation-closure composer ═════════════════════
host derive_closure.la dcl
want dcl "root→nine: root ∃(∃)≡∃:T derived=4/9:T [BEING SELF RECOGNITION LOVE] axioms=5/5:T [VOID DEPTH BECOMING FORM RELATION] seam=weakening/contraction/exchange closure{I}:T" derive_closure
want dcl "nine→lexicon: grounded=21/21:T" derive_closure
want dcl "ungrounded fixture refused:T OFFENDER=PHANTOM/GHOST" derive_closure
want dcl "dyad stratum (arithmetic beneath the nine): VOID=0:T BECOMING=succ:T naturals(ITER 5,9):T BEING=1:T bound(projection-not-injective):T" derive_closure
want dcl "DERIVATION CLOSURE VERDICT: BOUNDED" derive_closure
sed 's/^glyph DC_LEXCAT = CAT$/glyph DC_LEXCAT = DC_HAUNTED/' derive_closure.la > "$T/dcl_m1.la"; host "$T/dcl_m1.la" dcl_m1
red dcl_m1 "grounded=21/22:F OFFENDER=PHANTOM/GHOST" "derive_closure RED(ghost leaf named)"
sed 's/CONS(PAIR(AX_REL)("RELATION"))/CONS(PAIR(DC_FALSE)("RELATION"))/' derive_closure.la > "$T/dcl_m2.la"; host "$T/dcl_m2.la" dcl_m2
red dcl_m2 "axioms=4/5:F [VOID DEPTH BECOMING FORM] UNWITNESSED=RELATION" "derive_closure RED(axiom unwitnessed named)"
sed 's/^glyph DC_NDERIVED = .*/glyph DC_NDERIVED = 9/' derive_closure.la > "$T/dcl_m3.la"; host "$T/dcl_m3.la" dcl_m3
red dcl_m3 "DERIVATION CLOSURE VERDICT: CLOSED" "derive_closure RED(the CLOSED branch is live)"

# ═══ 14. branchgenesis — Δ_B, the branch-genesis operator ═════════════════════
host branchgenesis.la bg
want bg "BRANCHGENESIS base=18 distinct-κ:T | Δ_B branch IRR/NOV/AUT/CON=TTTT admitted:T set=19 | F1 permuted domain=FTTT | F2 α-copy=TFTT | F3 false ren=TTFT | F4 no register=TTTF | F5 unknown register=TTFT | F6 projection=FTTT | all six refused:T" branchgenesis
want bg "re-admit verdict=FFTT Δ_B(Δ_B)≡Δ_B idempotent:T | G_DB=▷(RECOGNITION,↻(RELATION))" branchgenesis
sed 's|^glyph ADMIT_B = la T. la c. IF(str_eq(VERDICT_B(T)(c))("TTTT"))|glyph ADMIT_B = la T. la c. IF(TRUE)|' branchgenesis.la > "$T/bg_m1.la"; host "$T/bg_m1.la" bg_m1
red bg_m1 "all six refused:F" "branchgenesis RED(admission ignores the verdict)"
sed 's|^glyph SETEQ = la a. la b. AND(ALLL(la x. MEMS(x)(b))(a))(ALLL(la x. MEMS(x)(a))(b))|glyph SETEQ = la a. la b. FALSE|' branchgenesis.la > "$T/bg_m2.la"; host "$T/bg_m2.la" bg_m2
red bg_m2 "F1 permuted domain=TTTT" "branchgenesis RED(set-equality broken: F1 admitted)"
sed 's|^glyph AUT = la c. AND(AUTO_OK(BGLYPH(c)))(ALLL(REG_EXISTS)(BREGS(c)))|glyph AUT = la c. AUTO_OK(BGLYPH(c))|' branchgenesis.la > "$T/bg_m3.la"; host "$T/bg_m3.la" bg_m3
red bg_m3 "F5 unknown register=TTTT" "branchgenesis RED(unknown register admitted)"

# ═══ 15. ontoargument — Gödel's argument as a finite S5 model check ════════════
host ontoargument.la oa
want oa "OA[M] A1 P(φ)⊻P(¬φ):T A2 P⊨-closed:T A3 P(G):T A4 P(φ)→□P(φ):T A5 P(NE):T | G fixpoint over full L:T NE stable over full L:T" ontoargument
want oa "OA[M] T1 ◇∃x G(x):T T2 G ess x ∀God-like x:T T3 □∃x G(x):T" ontoargument
want oa "collapse ∀φ∀x(φ(x)→□φ(x)):F OFFENDER=GOOD(b)@w0¬@w1" ontoargument
want oa "OA[M+λ] A1 P(φ)⊻P(¬φ):T A2 P⊨-closed:T A3 P(G):T A4 P(φ)→□P(φ):F OFFENDER=[GOOD(b)]@w0↛w1" ontoargument
want oa "OA[M♭+λ] T1 ◇∃x G(x):T T2 G ess x ∀God-like x:T T3 □∃x G(x):T God-like=a@w0 a@w1 a@w2 G=TTTFFFFFF NE=TTTTTTTTT |L|=28 | collapse ∀φ∀x(φ(x)→□φ(x)):T" ontoargument
want oa "OA GLYPHS □=⊗(BEING,FORM) ◇=⊗(BECOMING,FORM) ¬=⊂(·,VOID) ∀=⊗(BEING,DEPTH) ∃=⊗(FORM,DEPTH)" ontoargument
want oa "LAW_IDENTITY(sealed T3):T" ontoargument
sed 's/OA_PAIR("GOOD")("TTTTFFFFF")/OA_PAIR("GOOD")("TTFTFFFFF")/' ontoargument.la > "$T/oa_m1.la"; host "$T/oa_m1.la" oa_m1
red oa_m1 "A2 P⊨-closed:F OFFENDER=GOOD⊨¬G@w0" "ontoargument RED(cell flip breaks A2, named)"
red oa_m1 "T3 □∃x G(x):F" "ontoargument RED(cell flip: T3 falls)"
sed 's/OA_PAIR("GOOD")("TTT")/OA_PAIR("GOOD")("FFF")/' ontoargument.la > "$T/oa_m2.la"; host "$T/oa_m2.la" oa_m2
red oa_m2 "A1 P(φ)⊻P(¬φ):F OFFENDER=GOOD@w0" "ontoargument RED(P flip breaks A1, named)"
sed 's/OA_PAIR("NE")("TTT")/OA_PAIR("NE")("FFF")/' ontoargument.la > "$T/oa_m3.la"; host "$T/oa_m3.la" oa_m3
red oa_m3 "A5 P(NE):F OFFENDER=NE@w0" "ontoargument RED(NE not positive: A5 named)"

# ═══ 16. ontomorph — the inflectional census, gated (LA_COMPLETION.md:1187) ═════
host ontomorph.la om
want om "ONTOMORPH corpus rows=79 (LEX+RULED+GRAM+GRULED) | skeletons=10: *(·,·)=35 >(·,·)=22 +(·,·)=3 *(*(·,·),·)=9 ·=3 >(·,*(·,·))=1 >(*(·,·),*(·,·))=1 *(*(·,·),*(·,·))=1 c(·,·)=2 m(·)=2  | operator uses *=59 >=24 +=3 c=2 m=2" ontomorph
want om "ONTOMORPH combinations=71 κ-images=71 | injective (distinct combinations → distinct κ):T | fixture +36/+63 refused:T OFFENDER=+36/+63" ontomorph
want om "entry overloads (one κ, two names; the architect's to rule)=8:" ontomorph
sed 's|^glyph OM_KOF = la combo. KAN_N(OM_FST(PARSE(combo)))|glyph OM_KOF = la combo. KAN(OM_FST(PARSE(combo)))|' ontomorph.la > "$T/om_m1.la"; host "$T/om_m1.la" om_m1
red om_m1 "fixture +36/+63 refused:F" "ontomorph RED(raw canonicalisation: ⊕ commutativity ignored)"
# ═══ 17. gramcomplete — the Grammar Completeness theorem, gated in its honest form ═
host gramcomplete.la gc
want gc "GRAMCOMPLETE corpus=79 derived by R1-R3=79/79:T | rules used R1=167 R2=88 R3=2" gramcomplete
want gc "traces: Water R2(*,R2(*,R1(8),R1(1)),R1(7)) | Question R2(>,R1(2),R1(6)) | Ongoing R3(R1(7)) | Bad(ruled) R2(c,R1(3),R1(6))" gramcomplete
want gc "sealed self-naming:T Give?=⊕(▷(7,5),▷(2,6)) | primitive refused (d=0):T | unreachable fixtures refused, rule named 3/3:T [UNREACHABLE R1: 0 ∉ 𝒜 ; UNREACHABLE R2: a missing operand ; UNREACHABLE R3: no operand]" gramcomplete
sed 's|^glyph GC_ISDIG = la c. NOT(str_eq(NAM(c))(""))|glyph GC_ISDIG = la c. TRUE|' gramcomplete.la > "$T/gc_m1.la"; host "$T/gc_m1.la" gc_m1
red gc_m1 "eval error" "gramcomplete RED(validation bypassed: the parser CRASHES on an unreachable concept instead of naming the rule — the class the validator exists to prevent)"
sed 's|^glyph GC_SEAL4 = la t. IF(lt(0)(TDEPTH(t)))|glyph GC_SEAL4 = la t. IF(TRUE)|' gramcomplete.la > "$T/gc_m2.la"; host "$T/gc_m2.la" gc_m2
red gc_m2 "primitive refused (d=0):F" "gramcomplete RED(R4 precondition dropped)"
# ═══ 18. neologenesis — the birth as one compressive movement (K_unified = the seal) ═══
host neologenesis.la ng
want ng "BIRTH ⊗(κ,𝓡): born in one movement 10/12 — phonetic:T glyphic:T semantic:T morphological:T syntactic:T pragmatic:F operational(tree-law):T etymological:T prosodic:T evidential:F affective:T topological:T | form: one-seal(AUTO_OK):T nodes=6 nodes≤|A|+|B|+1:T depth=1+max:T content=TSIZE(A)+TSIZE(B)+1:T route-recoverable:T" neologenesis
want ng "BIRTH ⊕(𝓡,κ) [κ-sorted]: born in one movement 10/12" neologenesis
want ng "BIRTH ↻(κ): born in one movement 10/12" neologenesis
want ng "BIRTH ↻(SELF⊕SELF) [the seal REWRITES: a birth that is not a birth]: born in one movement 7/12 — phonetic:F glyphic:T semantic:T morphological:F syntactic:F pragmatic:T operational(tree-law):F etymological:T prosodic:F evidential:T affective:T topological:T | form: one-seal(AUTO_OK):T child≡parent(rewrite):T depth=1+d(A):T" neologenesis
sed 's|^glyph NG_CHILD = la sym. la a. la b. COLLAPSE(MKMODE(sym))(a)(b)|glyph NG_CHILD = la sym. la a. la b. COLLAPSE(MKMODE(sym))(a)(a)|' neologenesis.la > "$T/ng_m1.la"; host "$T/ng_m1.la" ng_m1
red ng_m1 "BIRTH ⊗(κ,𝓡): born in one movement 2/12" "neologenesis RED(child sealed from the wrong parents: every law but evidential fails)"
# ═══ 19. unified — the dyadic law, no glyphic entropy, syntropy/centropy, morphology-is-glyphs, onto-registry ═
host unified.la un
want un "UNIFIED dyadic law (C2..C4 = ⊗ of shared parents): one-seal+ren≠renA·renB+nodes+1+depth+1:T coupled form refused (fails AUTO_OK):T | chain d=1 S=3 nodes=3 | d=2 S=7 nodes=6 | d=3 S=15 nodes=7 | d=4 S=31 nodes=8 | d=5 S=63 nodes=9 |" unified
want un "raster SZ=32 at every depth fixed:T | phonym ⊗-chain PDUR(C4)=PDUR(C0):T | phonym per mode over (κ,𝓡): ⊗=12880 ⊕=26560 ▷=25600 ⊂=38320 ↻=25760 | sound grows under ⊕ (finding, codex Operator Phonology):T" unified
want un "UNIFIED syntropy: S=TSIZE rises:T TSIZE(Cn)=2·TSIZE(Cn-1)+1:T TSIZE≥2^depth:T" unified
want un "centropy Δ_S(Δ_S)≡Δ_S truth:T" unified
want un "UNIFIED morphology is glyphs: 5/5 modes are self-naming seals grounded in the nine:T GHOST-leaf mode refused:T" unified
sed 's|^glyph UN_COUPLED = la a. la b. MONO(concat(REN(a))(REN(b)))(SYN(ETYM(a))(ETYM(b)))|glyph UN_COUPLED = la a. la b. SEALc(SYN(ETYM(a))(ETYM(b)))|' unified.la > "$T/un_m1.la"; host "$T/un_m1.la" un_m1
red un_m1 "coupled form refused (fails AUTO_OK):F" "unified RED(a coupling that is actually a seal is not refused)"
sed 's|^glyph UN_TS = la g. TSIZE(ETYM(g))|glyph UN_TS = la g. 3|' unified.la > "$T/un_m2.la"; host "$T/un_m2.la" un_m2
red un_m2 "S=TSIZE rises:F" "unified RED(constant content: syntropy does not rise)"
# onto-registry: every row's module exists and its gate token is invoked somewhere gated
while IFS= read -r line; do
    mod=$(printf '%s' "$line" | cut -d'|' -f3 | sed 's/^ *//; s/ *$//'); tok=$(printf '%s' "$line" | cut -d'|' -f4 | sed 's/^ *//; s/ *$//')
    [ -f "$mod" ] || { echo "FAIL  registers/onto-registry: module $mod does not exist"; ok=0; }
    if grep -qF -- "$tok" build.sh gate_registers.sh; then :; else echo "FAIL  registers/onto-registry: token [$tok] for $mod is invoked by no gate"; ok=0; fi
done <<EOF2
$(grep '^ONTO ' "$T/un")
EOF2
# ═══ 20. the autological requirement (directive §7), as source gates ══════════════
#  (1) the compiler's own AST is dyadic BY TYPE: parser.la's constructors carry at most two payloads
#      (AST_APP = func,arg; AST_LAM = param,body; AST_VAR/AST_STR one). A three-payload constructor is RED.
if grep -qE '^glyph AST_[A-Z]+ = la [a-z]+\. la [a-z]+\. la [a-z]+\. la v\.' parser.la; then echo "FAIL  registers/autological: a parser.la AST constructor carries three payloads — the compiler's AST is not dyadic"; ok=0; fi
grep -qE '^glyph AST_APP = la func\. la arg\. la v\.' parser.la || { echo "FAIL  registers/autological: AST_APP is not the (func,arg) dyad"; ok=0; }
#  (2) K_unified on the compiler's own units: the house fuses VM + program into ONE ELF (bundle.la); its gate is in build.sh
grep -qF 'bundle.la' build.sh || { echo "FAIL  registers/autological: bundle.la (one fused unit) is not gated in build.sh"; ok=0; }
#  (3) ontoneologization is unified: every seal in the register modules is self-naming MONO(CANON(et))(et) — the only
#      literal rens are the declared LIE/⊥ fixtures. Any other MONO("literal") is a second neologization path: RED.
if grep -hoE 'MONO\("[^"]*"\)' lineage.la topology.la texture.la evidential.la registers.la modegenesis.la regenesis.la complement.la opposite.la branchgenesis.la neologenesis.la unified.la | grep -vE 'MONO\("(LIE|⊥[^"]*)"\)' | grep -q .; then echo "FAIL  registers/autological: a register module seals with a literal ren outside the declared fixtures — a second neologization path"; ok=0; fi
# ═══ 21. entendre — the four modes of poetic depth (LA_COMPLETION:1163) ══════════
host entendre.la en
want en "I vertical: surface=⊗(▷(RECOGNITION,FORM),▷(DEPTH,RECOGNITION)) | first depth: ▷(RECOGNITION,FORM), ▷(DEPTH,RECOGNITION) | second depth: RECOGNITION, FORM, DEPTH, RECOGNITION | third depth (operators): ⊗ ▷ ▷" entendre
want en "II horizontal: facets=6: RECOGNITION;FORM;▷0.1;DEPTH;▷3.0;⊗2.4 | III calligraphic: elements: marks=3 (⊗1 ⊕0 ▷2 ⊂0 ↻0) leaves=4 [B: census, not execution]" entendre
want en "four readings pairwise distinct, all derived from the DAG:T | primitive LOVE: I=⊥" entendre
want en "primitive has no vertical reading (red path):T" entendre
sed 's|^glyph ENTENDRE_II = la t. EN_C3("facets=")(int_to_str(LEN(SPLIT(";")(DAG(t)))))(EN_C3(": ")(DAG(t))(""))|glyph ENTENDRE_II = la t. ENTENDRE_I(t)|' entendre.la > "$T/en_m1.la"; host "$T/en_m1.la" en_m1
red en_m1 "pairwise distinct, all derived from the DAG:F" "entendre RED(two modes read the same)"
sed 's|(la _. "⊥ (a primitive has no strata below its surface)")|(la _. "surface only")|' entendre.la > "$T/en_m2.la"; host "$T/en_m2.la" en_m2
red en_m2 "no vertical reading (red path):F" "entendre RED(a primitive given a vertical reading)"
# ═══ 22. felicitylive — ontofelicity wired to the capability sealer (LA_COMPLETION "live enforcement") ═
host felicitylive.la fl
want fl "FELICITY-LIVE authorized realm: performed:open world=world +open | foreign realm: INFELICITOUS TFT refusing:open world unchanged:T" felicitylive
want fl "forged probe opens the box:F | string-caps PERFORM and live PERFORM agree on the authorized case:T | (B) is now the sealer, not a substring: T" felicitylive
sed 's|^glyph COND_B_LIVE = la u. la speaker. la box. GRANT_RECV(speaker)(box)(la held. str_eq(held)(FL_UNEED(u)))(FL_FALSE)|glyph COND_B_LIVE = la u. la speaker. la box. GRANT_RECV(REALM_A)(box)(la held. str_eq(held)(FL_UNEED(u)))(FL_FALSE)|' felicitylive.la > "$T/fl_m1.la"; host "$T/fl_m1.la" fl_m1
red fl_m1 "foreign realm: performed:open" "felicitylive RED(bypass: unsealing with the granting realm lets a foreign speaker perform)"
# ═══ 23. syllabus — acquisition: the teaching order the structure implies (LA_COMPLETION "Acquisition") ═
host syllabus.la sy
want sy "SYLLABUS lessons=79 by depth d0=3 d1=64 d2=12 d3=0 | depth non-decreasing:T | constituent-first violations=0 (0 required):T | reversed order violations=72 (red path, must be >0)" syllabus
want sy "SYLLABUS first lessons: Two One I None Ongoing Consciousness Agency Beauty Mystery Witness Grief Gratitude" syllabus
sed 's|IF(lt(L_KEY(h))(L_KEY(x)))(la _. SY_CONS(h)(self(t)))(la _. SY_CONS(x)(l))|IF(lt(L_KEY(x))(L_KEY(h)))(la _. SY_CONS(h)(self(t)))(la _. SY_CONS(x)(l))|' syllabus.la > "$T/sy_m1.la"; host "$T/sy_m1.la" sy_m1
red sy_m1 "depth non-decreasing:F" "syllabus RED(descending order: depth invariant lost)"
# ═══ 24. aware — the AWARE / C predicates (LA_COMPLETION Tier 4) ═══════════════════
host aware.la aw
want aw "AWARE/C over the catalogue: all AWARE:T all C:T | A and C coincide on every sealed glyph:T | the liar: AWARE=F C=F | two turns of κ still C:T" aware
sed 's|^glyph C_PRED = la g. AND(AUTO_OK(g))(AUTO_OK(MCOLLAPSE(g)))|glyph C_PRED = la g. AND(AUTO_OK(g))(AUTO_OK(MONO(REN(g))(MC(ETYM(g)))))|' aware.la > "$T/aw_m1.la"; host "$T/aw_m1.la" aw_m1
red aw_m1 "all C:F" "aware RED(a turn that keeps the old ren: C separates from A only for a seal that does not re-name)"
# ═══ 25. ablateop — the meta-word ablation gate (LA_COMPLETION Tier 4) ═════════════
host ablateop.la ab
want ab "ABLATEOP D1=⊗(▷(VOID,RELATION),⊂(FORM,DEPTH)) D2=⊗(⊗(BECOMING,FORM),↻(RECOGNITION)) | all five: D1:T D2:T" ablateop
want ab "ablate ∂: D1 underivable:T D2 survives:T other four survive:T | ablate γ: D2 underivable:T D1 survives:T other four survive:T | ablate 𝔄 (control): D1:T D2:T" ablateop
sed 's|^glyph AB_CONTAINS = .*|glyph AB_CONTAINS = la s. la sub. AB_TRUE|' ablateop.la > "$T/ab_m1.la"; host "$T/ab_m1.la" ab_m1
red ab_m1 "control): D1:F D2:F" "ablateop RED(containment that always says yes: the control collapses)"
# ═══ 26. wants — lack-driven wants (LA_COMPLETION Tier 4) ═════════════════════════
host wants.la wn
want wn "WANTS organ-A lacks MEMORY → want=MEMORY names the lack:T | organ-B complete → want=⊥ (⊥ required):T" wants
want wn "WANTS resolve(organ-A): lack after= closed:T centropy before=3 after=4 strictly rises:T" wants
sed 's|^glyph WANT = la s. IF(str_eq(SLACKS(s))(""))(la _. "⊥")(la _. SLACKS(s))|glyph WANT = la s. SLACKS(s)|' wants.la > "$T/wn_m1.la"; host "$T/wn_m1.la" wn_m1
red wn_m1 "(⊥ required):F" "wants RED(a want formed for a complete organ)"
# ═══ 27. protoagent — REPAIR toward closure, the ill class refused (LA_COMPLETION Tier 4) ═
host protoagent.la pa
want pa "PROTO_AGENT incomplete+WF: repaired: centropy 2→4 gain>0:T result autological:T | complete+WF: repaired: centropy 4→4 gain=0:T" protoagent
want pa "PROTO_AGENT incomplete+ILL: REFUSED: composition ORDER-VIOLATION (provably ill) — no repair moves it toward closure untouched:T | swc order verdicts WF=WELL-ORDERED ILL=ORDER-VIOLATION" protoagent
sed 's|IF(str_eq(ORDER(c))("ORDER-VIOLATION"))|IF(FALSE)|' protoagent.la > "$T/pa_m1.la"; host "$T/pa_m1.la" pa_m1
red pa_m1 "untouched:F" "protoagent RED(the ill guard dropped: an ill composition gets repaired)"
# ═══ 28. fractal — the fractal monoglyph, measured (LA_COMPLETION Tier 4) ═══════════
host fractal.la fr
want fr "FRACTAL chain: surface=49 fractal=6 | surface=104 fractal=7 | surface=214 fractal=8 | surface=434 fractal=9 | surface doubles while the fractal form grows by one:T | tree recoverable from the DAG alone at every depth:T" fractal
sed 's|^glyph FR_FRAC = la g. NODES(DAG(ETYM(g)))|glyph FR_FRAC = la g. TSIZE(ETYM(g))|' fractal.la > "$T/fr_m1.la"; host "$T/fr_m1.la" fr_m1
red fr_m1 "grows by one:F" "fractal RED(the unfolded size read where the hash-consed form is meant)"
# ═══ 29. branchclosure — are the branches dyadic and metacursive? the non-vacuous answer ═
host branchclosure.la bc
want bc "BRANCHCLOSURE branches=19 | all grounded in the nine (start from the dyad):T | ⊂(RELATION,·) dyad form: 18/19 (18 branches + Δ_B's ▷ = 1 exception, expected 18):T" branchclosure
want bc "fixtures refused: SYN-head not the ⊂ dyad:T GHOST leaf not grounded:T OFFENDER=⊂(RELATION,▷(GHOST,FORM))" branchclosure
sed 's|^glyph BC_GROUND1 = Z(la self. la t. t(la nm. BC_IS9(nm))|glyph BC_GROUND1 = Z(la self. la t. t(la nm. TRUE)|' branchclosure.la > "$T/bc_m1.la"; host "$T/bc_m1.la" bc_m1
red bc_m1 "GHOST leaf not grounded:F" "branchclosure RED(grounding disabled: an ungrounded branch passes)"
sed 's|^glyph BC_DYAD1 = la g. AND(HAS_PREFIX(CANON(g))("⊂("))(HAS_PREFIX(CANON(g))("⊂(RELATION,"))|glyph BC_DYAD1 = la g. TRUE|' branchclosure.la > "$T/bc_m2.la"; host "$T/bc_m2.la" bc_m2
red bc_m2 "SYN-head not the ⊂ dyad:F" "branchclosure RED(dyad-form check disabled: a non-dyad branch passes)"


# ═══ 30. gapcensus — the autological completion instrument (Erik, 2026-09-15) ══════
host gapcensus.la gp
want gp "GAPCENSUS instrument (gate_registers.sh) present with proven RED paths + PASS line:T | seed items=6 self-closable=3 ceiling=2 external=1 | all consistent (declared==computed):T" gapcensus
want gp "miscategorisation fixture (vacuous claim declared self-closable) caught:T OFFENDER=FIXTURE: vacuous claim mislabelled self-closable" gapcensus
sed 's|^glyph GC_DISCRIMINATES = la pred. la good. la bad. NOT(str_eq(GC_BSTR(pred(good)))(GC_BSTR(pred(bad))))|glyph GC_DISCRIMINATES = la pred. la good. la bad. TRUE|' gapcensus.la > "$T/gp_m1.la"; host "$T/gp_m1.la" gp_m1
red gp_m1 "all consistent (declared==computed):F" "gapcensus RED(discriminator always-true: the two ceilings misread as self-closable)"

# ═══ 10. the table bound (directive §8): every module's import closure fits 1024 ══
for m in lineage.la prosody.la topology.la evidential.la texture.la registers.la modegenesis.la regenesis.la complement.la opposite.la textcoherence.la derive_closure.la branchgenesis.la ontoargument.la ontomorph.la gramcomplete.la neologenesis.la unified.la gapcensus.la entendre.la felicitylive.la aware.la ablateop.la wants.la protoagent.la fractal.la branchclosure.la; do
    n=$(python3 - "$m" <<'PY'
import re,sys,os
IMP=re.compile(r'import\("([^"]+)"\)'); GLY=re.compile(r'^glyph\s+[A-Za-z0-9_]+',re.M)
def count(p,st=()):
    s=open(p,encoding='utf-8').read(); own=len(GLY.findall(s))
    code='\n'.join(l.split('#',1)[0] for l in s.splitlines()); t=own
    for m in IMP.finditer(code):
        d=m.group(1)
        if d in st: continue
        t+=count(d,st+(p,))
    return t
print(count(sys.argv[1]))
PY
)
    [ "$n" -le 1024 ] || { echo "FAIL  registers/table-bound: $m loads $n glyphs into tiny_host's 1024-entry table"; ok=0; }
done

# ═══ 11. VM leg: host == native SECD VM, byte for byte ═══════════════════════
#  REGS_VM=0 skips · 1 (default) the eight light modules · 2 adds registers.la and
#  regenesis.la, whose ~830-glyph closures make codegen take on the order of an hour
#  each under fleet load. The heavy two are a separate switch so the light leg stays runnable.
if [ "${REGS_VM:-1}" != 0 ]; then
    rm -f logos_secd logos_program.bin logos_source.la
    ./tiny_host secd.la >/dev/null 2>&1 || { echo "FAIL  registers/vm: secd.la did not emit the VM"; ok=0; }
    vmlist="lineage.la topology.la texture.la prosody.la evidential.la complement.la opposite.la modegenesis.la textcoherence.la derive_closure.la ontoargument.la ontomorph.la gramcomplete.la unified.la"
    [ "${REGS_VM:-1}" = 2 ] && vmlist="$vmlist registers.la regenesis.la branchgenesis.la neologenesis.la"
    for m in $vmlist; do
        b=${m%.la}
        cp "$m" logos_source.la
        timeout 7200 ./tiny_host codegen.la >/dev/null 2>&1 || { echo "FAIL  registers/vm: codegen failed on $m"; ok=0; continue; }
        timeout 3600 ./logos_secd > "$T/$b.vm" 2>&1
        ./tiny_host "$m" > "$T/$b.host" 2>&1
        if cmp -s "$T/$b.vm" "$T/$b.host"; then :; else echo "FAIL  registers/vm: $m host != VM"; ok=0; fi
        rm -f logos_program.bin logos_source.la
    done
    rm -f logos_secd
fi

[ "$ok" -eq 1 ] && echo "PASS  registers: the twelve-register stack — five new registers (etymological, prosodic, topological, evidential, affective) each gated with a RED path that NAMES its offender; twelve-fold coherence (all identity-projections agree on NIS-equal glyphs, NORMTREE ≡ NORMK differentially); Δ_M and Δ_R each with four sub-gates, one fixture per letter, idempotent admission; the antonym structure (¬ from Void, ¬¬C ≠ C as glyphs and ≡ C in truth, two identities explicit, the dyadic pole as a refusing involution); every W-tag cites a gate that exists in build.sh; every import closure under the 1024-glyph table" || exit 1
