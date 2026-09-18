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
#  ★ THE STANDING RULE (FREEZE-TRACKF.md F33, Erik 2026-09-18): EVERY `want` DECLARES HOW IT TURNS RED, as a trailing
#    `#@ turns-red: <clause>; <clause>…` — inert to sh (a comment), checked by `python3 freezeck.py` (sweep D, rc 1 on
#    any error). Clauses: red:<mutant,…> (a RED line on a mutant of THIS module) · exact:<sNN|captured|…> (a pinned exact
#    value; sNN = derived independently in derive/) · fixture:<what> (an in-file bad input the module must refuse) ·
#    construction:<constructor> (true by construction — it witnesses the constructor, NOT the claim) · entailed:<tag>.<k>
#    · cannot-fail:<Fnn> / unproven:<Fnn> (a known defect, tracked by an OPEN ledger item). Adding a witness without a
#    declaration fails the checker. Measured when the rule arrived: 7% of witnesses contained a part that could not
#    fail and 15% were construction-true — "which assertions cannot go RED?" is now asked of every line, not once.
#  Plus the loop the modules cannot close themselves: every W-tagged evidential entry
#  cites a build.sh gate; the cited say-line must EXIST in build.sh.
#  Scratch lives INSIDE the worktree (never /tmp: the launcher's private tmpfs is
#  invisible across sessions and the build's /tmp paths are the collision surface).
set -u
cd "$(dirname "$0")" || exit 1
ok=1
T=$(mktemp -d ./.regs_gate_XXXXXX) || exit 1
# REGS_KEEP=<dir> keeps every output — green, mutant, VM — for offline re-checking with `checkwants.py --dir` and
# `checkreds.py --dir` (FREEZE-TRACKF.md F18: without it the trap below deleted all evidence of a run). Keep the
# dir INSIDE the worktree (e.g. .freeze-out), for the same reason $T is.
trap 'if [ -n "${REGS_KEEP:-}" ]; then mkdir -p "$REGS_KEEP" && cp -p "$T"/* "$REGS_KEEP"/ 2>/dev/null; fi; rm -rf "$T" logos_source.la logos_program.bin' EXIT
[ -x ./tiny_host ] || gcc -O2 -Wall -Wextra -o tiny_host tiny_host.c || { echo "FAIL  registers: no tiny_host"; exit 1; }

# host(module, out) — run on the host into $T/out; rc recorded AND ASSERTED for a GREEN run (FREEZE-TRACKF.md F19:
#   until 2026-09-18 the rc was written and never read, so a module that printed its witnesses and then crashed, or
#   hung to the timeout, PASSED). A green run must exit 0; ANY other rc fails and is PRINTED. Whether the budget
#   stopped it is decided by the CLOCK (elapsed >= budget), never by matching a kill code — a budget kill surfaces
#   as different codes by invocation shape (the sealed class hardcoded-kill-code). A MUTANT (tag *_mN) may exit
#   non-zero: its rc is recorded and red() judges it. REGS_HOST_TIMEOUT overrides the 1800 s budget (tests use 2 s).
# rcsay(what, rc, elapsed, budget) — one FAIL line that says which fact happened
rcsay() { if [ "$3" -ge "$4" ]; then echo "$1 was STOPPED BY THE ${4} s BUDGET after ${3} s (rc $2) — a timeout, not a logic failure; output may be partial"; else echo "$1 exited rc $2 after ${3} s — it crashed or errored"; fi; }
host() {
    hb=${REGS_HOST_TIMEOUT:-1800}; hs=$(date +%s)
    timeout "$hb" ./tiny_host "$1" > "$T/$2" 2>&1; hrc=$?; he=$(($(date +%s) - hs)); echo "$hrc" > "$T/$2.rc"
    case "$2" in
        *_m[0-9]*) : ;;
        *) if [ "$hrc" -ne 0 ]; then echo "FAIL  registers/$2: $(rcsay "$1" "$hrc" "$he" "$hb"): $(tail -c 200 "$T/$2")"; ok=0
           # V5 DETERMINISM (FREEZE-TRACKF.md V5), opt-in because it doubles host time: REGS_TWICE=1 runs every green
           # module a second time; output AND rc must be byte-identical, or it depends on hidden state (/tmp, time,
           # file order, a stale generated module). Named with the first differing byte, so it can be pinpointed.
           elif [ "${REGS_TWICE:-0}" = 1 ]; then
               timeout "$hb" ./tiny_host "$1" > "$T/$2.twice" 2>&1; h2=$?
               if [ "$h2" -ne "$hrc" ]; then echo "FAIL  registers/$2: NONDETERMINISTIC — $1 exited rc $hrc then rc $h2"; ok=0
               elif ! cmp -s "$T/$2" "$T/$2.twice"; then echo "FAIL  registers/$2: NONDETERMINISTIC — $1 printed different output on a second run: $(cmp "$T/$2" "$T/$2.twice" 2>&1 | head -1)"; ok=0; fi
           fi ;;
    esac
}
# static(out, script, args…) — a STATIC witness (FREEZE-TRACKF.md F25): a python check over module SOURCE, no tiny_host.
#   Output in $T/out and rc recorded, exactly as host(); a GREEN static run must exit 0, a mutant's (tag *_mN) rc is
#   recorded and red() judges it. want/red read its output the same way; checkwants/checkreds/freezeck know the form.
static() {
    so=$1; shift
    python3 "$@" > "$T/$so" 2>&1; src=$?; echo "$src" > "$T/$so.rc"
    case "$so" in *_m[0-9]*) : ;; *) [ "$src" -eq 0 ] || { echo "FAIL  registers/$so: static check [$*] exited rc $src: $(tail -c 200 "$T/$so")"; ok=0; } ;; esac
}
# want(out, token, label) — exact witness present
want() { if grep -qF -- "$2" "$T/$1"; then :; else echo "FAIL  registers/$3: missing witness [$2] — got: $(head -c 300 "$T/$1")"; ok=0; fi; }
# red(mutfile, token, label) — the mutant's output must NOT carry the green witness and must carry the red one
#   … AND the token must be ABSENT from the GREEN output of the same module (base tag = the mutant tag minus _mN;
#   every red tag in this file has that form, checked by freezeck). A token already in the green output fires
#   whether or not the mutant changed anything — a VACUOUS RED (FREEZE-TRACKF.md F18). No green output is a failure.
red() {
    if grep -qF -- "$2" "$T/$1"; then :; else echo "FAIL  registers/$3: the RED path did not fire — mutant still reads green: $(head -c 200 "$T/$1")"; ok=0; fi
    rb=${1%_m[0-9]*}
    if [ "$rb" = "$1" ] || [ ! -s "$T/$rb" ]; then echo "FAIL  registers/$3: no GREEN output [$rb] to prove the RED token absent from"; ok=0
    elif grep -qF -- "$2" "$T/$rb"; then echo "FAIL  registers/$3: VACUOUS RED — the token is already in the GREEN output of $rb, so it fires whether or not the mutant changed anything: [$2]"; ok=0; fi
}

# ── the VM leg (§11), defined up here so REGS_VM_CHUNK can run it ALONE ──────────────────
#  REGS_VM=1 (default) the 33 light modules · 2 adds registers.la and regenesis.la (and two more),
#  whose ~830-glyph closures make codegen take on the order of an hour each under fleet load.
vm_list() {
    vmlist="lineage.la topology.la texture.la prosody.la evidential.la complement.la opposite.la modegenesis.la textcoherence.la derive_closure.la ontoargument.la ontomorph.la gramcomplete.la unified.la recdepth.la selfevo.la"
    # the Category-1 + framework modules (§33–§49): all 47–213-glyph closures, all pass nameck --vm.
    # Until 2026-09-18 only recdepth/selfevo were here, so REGS_VM=1 went green without touching these 17.
    vmlist="$vmlist certify.la migrate.la closure.la metakappa.la substitution.la ontosemiosyntax.la autocompress.la phonometa.la identity.la compressbound.la logicsyntax.la lawroot.la archeunique.la crossbranch.la numderive.la divergent.la adequacy.la"
    [ "${REGS_VM:-1}" = 2 ] && vmlist="$vmlist registers.la regenesis.la branchgenesis.la neologenesis.la"
    echo "$vmlist"
}
# vm_leg <module...> — host == VM byte for byte for each. Sets vm_done to the number actually COMPARED,
# so a caller can require it equals what it asked for. One TIME line per module: the leg's wall was
# never measured, and chunk sizes should be chosen from these numbers, not reasoned.
vm_leg() {
    vm_done=0
    rm -f logos_secd logos_program.bin logos_source.la
    ./tiny_host secd.la >/dev/null 2>&1 || { echo "FAIL  registers/vm: secd.la did not emit the VM"; ok=0; }
    for m in "$@"; do
        b=${m%.la}
        cp "$m" logos_source.la
        t0=$(date +%s)
        timeout 7200 ./tiny_host codegen.la >/dev/null 2>&1; crc=$?
        t1=$(date +%s)
        if [ "$crc" -ne 0 ]; then
            echo "FAIL  registers/vm: $(rcsay "codegen on $m" "$crc" "$((t1-t0))" 7200)"; ok=0; rm -f logos_program.bin logos_source.la; continue
        fi
        timeout 3600 ./logos_secd > "$T/$b.vm" 2>&1; vrc=$?; echo "$vrc" > "$T/$b.vm.rc"
        t2=$(date +%s)
        hb=${REGS_HOST_TIMEOUT:-1800}
        timeout "$hb" ./tiny_host "$m" > "$T/$b.host" 2>&1; hrc=$?; echo "$hrc" > "$T/$b.host.rc"
        t3=$(date +%s)
        echo "TIME  registers/vm: $m codegen=$((t1-t0))s vm=$((t2-t1))s host=$((t3-t2))s rc vm=$vrc host=$hrc"
        # F19: identical output is not enough — an identical CRASH on both engines used to read "host == VM".
        [ "$vrc" -eq 0 ] || { echo "FAIL  registers/vm: $(rcsay "$m on the SECD VM" "$vrc" "$((t2-t1))" 3600)"; ok=0; }
        [ "$hrc" -eq 0 ] || { echo "FAIL  registers/vm: $(rcsay "$m on the host" "$hrc" "$((t3-t2))" "$hb")"; ok=0; }
        if cmp -s "$T/$b.vm" "$T/$b.host"; then :; else echo "FAIL  registers/vm: $m host != VM — first differing byte: $(cmp "$T/$b.vm" "$T/$b.host" 2>&1 | head -1)"; ok=0; fi
        vm_done=$((vm_done+1))
        rm -f logos_program.bin logos_source.la
    done
    rm -f logos_secd
}

# ── REGS_VM_CHUNK=k/n — run ONLY the k-th of n contiguous slices of the VM list, and NOTHING ELSE:
#  §1–§10 are skipped, so a chunk fits a short deep slot. Its PASS line names the chunk and every module
#  it compared; it is NOT the gate's PASS line and must never be read as one. The n chunks together cover
#  the list exactly once. REGS_VM_PLAN=1 prints the chunk's modules and exits without running anything.
if [ -n "${REGS_VM_CHUNK:-}" ]; then
    ck=${REGS_VM_CHUNK%/*}; cn=${REGS_VM_CHUNK#*/}
    case "$REGS_VM_CHUNK" in */*) ;; *) echo "REFUSE registers/vm: REGS_VM_CHUNK=$REGS_VM_CHUNK is not k/n"; exit 2;; esac
    case "$ck:$cn" in :*|*:|*[!0-9:]*) echo "REFUSE registers/vm: REGS_VM_CHUNK=$REGS_VM_CHUNK is not k/n"; exit 2;; esac
    [ "${REGS_VM:-1}" != 0 ] || { echo "REFUSE registers/vm: REGS_VM=0 skips the leg REGS_VM_CHUNK asks to run"; exit 2; }
    cN=$(vm_list | wc -w)
    { [ "$ck" -ge 1 ] && [ "$ck" -le "$cn" ] && [ "$cn" -le "$cN" ]; } || { echo "REFUSE registers/vm: need 1 <= k <= n <= $cN, got $REGS_VM_CHUNK"; exit 2; }
    cmods=$(vm_list | awk -v k="$ck" -v n="$cn" '{for(i=1;i<=NF;i++) a[++N]=$i} END{for(i=1;i<=N;i++) if(i>int((k-1)*N/n) && i<=int(k*N/n)) printf "%s ", a[i]}')
    cwant=$(echo $cmods | wc -w)
    if [ "${REGS_VM_PLAN:-0}" = 1 ]; then echo "PLAN  registers/vm chunk $ck/$cn: $cwant of $cN: $cmods"; exit 0; fi
    vm_leg $cmods
    [ "$vm_done" -eq "$cwant" ] || { echo "FAIL  registers/vm chunk $ck/$cn: compared $vm_done of the $cwant modules it was given"; ok=0; }
    [ "$ok" -eq 1 ] && echo "PASS  registers/vm chunk $ck/$cn (REGS_VM=${REGS_VM:-1}): $vm_done of $cN modules host == VM byte for byte: $cmods— a CHUNK, not the gate: §1–§10 and the other chunks did not run here" || exit 1
    exit 0
fi

# ═══ 1. lineage — the etymological register ═══════════════════════════════
host lineage.la lin
want lin "recoverable from lineage alone:T" lineage  #@ turns-red: red:lin_m1
want lin "every parent precedes its def:T" lineage  #@ turns-red: construction:DAG builder emits children first — the BEING;⊗0.7 fixture on the next line is the real check
want lin "broken-parent fixture refused:T OFFENDER=⊗0.7" lineage  #@ turns-red: red:lin_m2
want lin "sharing visible (DAG<tree, 4 defs):T" lineage  #@ turns-red: exact:s01
want lin "Δ_E(Δ_E)≡Δ_E truth:T glyph:F" lineage  #@ turns-red: construction:↻↻≡↻, true except at BEING (F4)
sed 's|^glyph RECOVER = la form. NORMK(DECOMP(form))|glyph RECOVER = la form. form|' lineage.la > "$T/lin_m1.la"; host "$T/lin_m1.la" lin_m1
red lin_m1 "recoverable from lineage alone:F OFFENDER=KAPPA" "lineage RED(recovery bypassed)"
sed 's|^glyph PARENT_OK = la i. la s. lt(str_to_int(s))(i)|glyph PARENT_OK = la i. la s. TRUE|' lineage.la > "$T/lin_m2.la"; host "$T/lin_m2.la" lin_m2
red lin_m2 "broken-parent fixture refused:F" "lineage RED(parent check disabled)"

# ═══ 2. prosody — the prosodic register (+ the phonym cross-check) ═════════
host prosody.la pro
want pro "segments distinct=1 prosody distinct=5 separable:T" prosody  #@ turns-red: red:pro_m1
want pro "⊕ dur=14240 | ▷ dur=13280 | ⊂ dur=20000 | ↻ dur=13120" prosody  #@ turns-red: exact:captured
want pro "↻↻x vs ↻x contour equal:F identity (NIS):T" prosody  #@ turns-red: construction:↻↻≡↻ (F4) + reduplication rule
want pro "Δ_P(Δ_P)≡Δ_P truth:T glyph:F" prosody  #@ turns-red: construction:↻↻≡↻ (F4)
sed 's|PAIR(concat("(")(concat(FST(pb))(concat(")\[")(concat(FST(pa))(concat("](")(concat(FST(pb))(")")))))))|PAIR(concat("(")(concat(FST(pa))(concat(")·ʔ·(")(concat(FST(pb))(")")))))|' prosody.la > "$T/pro_m1.la"; host "$T/pro_m1.la" pro_m1
red pro_m1 "prosody distinct=4 separable:F" "prosody RED(⊂ contour collapsed onto ⊕)"
host prosody_xcheck.la prx
want prx "PROSODY-XCHECK phonym durations agree 14/14:T" prosody_xcheck  #@ turns-red: red:prx_m1
sed 's|(la _. 6080)|(la _. 6081)|' prosody.la > prosody_mut.la
sed 's|import("prosody.la")|import("prosody_mut.la")|' prosody_xcheck.la > "$T/prx_m1.la"; host "$T/prx_m1.la" prx_m1; rm -f prosody_mut.la
red prx_m1 "agree 14/14:F OFFENDER=BEING phonym=6080 prosody=6081" "prosody_xcheck RED(duration drift named)"

# ═══ 3. topology — the topological register ════════════════════════════════
host topology.la top
want top "every lineage computes (no ⊥):T | corrupted DAG reads ⊥:T | ⊕-order invariant:T" topology  #@ turns-red: red:top_m1,top_m2; cannot-fail:F21 (the ⊕-order part)
want top "κ tree: V=3 E=2 b0=1 b1=0 depth=1 leaves=2 anchors=2 grounded=T" topology  #@ turns-red: exact:s03
want top "⊗(κ,κ) shared: V=4 E=4 b0=1 b1=1 depth=2 leaves=2 anchors=2 grounded=T" topology  #@ turns-red: exact:s03
want top "MetaTop(MetaTop)≡MetaTop truth:T glyph:F" topology  #@ turns-red: construction:↻↻≡↻ (F4)
sed 's|^glyph TOPO = la form. IF(str_eq(LINEAGE_OK(form))(""))|glyph TOPO = la form. IF(TRUE)|' topology.la > "$T/top_m1.la"; host "$T/top_m1.la" top_m1
red top_m1 "corrupted DAG reads ⊥:F" "topology RED(validity skipped)"
sed 's|^glyph TOPO = la form. IF(str_eq(LINEAGE_OK(form))(""))|glyph TOPO = la form. IF(FALSE)|' topology.la > "$T/top_m2.la"; host "$T/top_m2.la" top_m2
red top_m2 "every lineage computes (no ⊥):F OFFENDER=KAPPA" "topology RED(all ⊥ named)"

# ═══ 4. evidential — the evidential register (+ the build.sh citation loop) ═
host evidential.la evd
want evd "all declared:T | all tags valid:T | one κ one tag:T | undeclared reads ⊥:T | empty-tag refused:T | bad-tag refused:T | same-κ-two-tags refused:T" evidential  #@ turns-red: red:evd_m1,evd_m2
want evd "reads itself as:B | Δ_Ev(Δ_Ev)≡Δ_Ev truth:T glyph:F" evidential  #@ turns-red: exact:captured; construction:↻↻≡↻ (F4)
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
want tex "distinct textures=5 varies:T | none ⊥:T | ⊕-order invariant:T | corrupted reads ⊥:T | κ: m=100 a=66 r=50 | ⊗(κ,κ): m=133 a=50 r=33" texture  #@ turns-red: red:tex_m1; cannot-fail:F21 (texture ⊕-order, same class)
want tex "Δ_A(Δ_A)≡Δ_A truth:T glyph:F" texture  #@ turns-red: construction:↻↻≡↻ (F4)
sed 's|^glyph TEXTURE = la form. IF(str_eq(LINEAGE_OK(form))(""))(la _. TEXTURE_STR(SPLIT(";")(form)))(la _. "⊥")|glyph TEXTURE = la form. "m=100 a=50 r=50"|' texture.la > "$T/tex_m1.la"; host "$T/tex_m1.la" tex_m1
red tex_m1 "distinct textures=1 varies:F" "texture RED(constant)"

# ═══ 6. registers — the twelve-fold coherence ═══════════════════════════════
host registers.la reg
want reg "REGISTERS stack=12 [phonetic glyphic semantic morphological syntactic pragmatic operational etymological prosodic evidential affective topological]" registers  #@ turns-red: exact:captured
want reg "coherence per register=TTTTTTTTTTTT all:T | raw-route register refused:T | semantic distinguishes ⊗(a,b)/⊗(b,a):T | NORMTREE==NORMK probes:T catalogue:T" registers  #@ turns-red: red:reg_m1,reg_m2; construction:raw-route refused: every probe pair is two routes (F32)
want reg "  evidential: W" registers  #@ turns-red: exact:captured
want reg "  topological: V=3 E=2 b0=1 b1=0 depth=1 leaves=2 anchors=2 grounded=T" registers  #@ turns-red: exact:s03
sed 's|      (la a. la b. (la x. la y. IF(LE(CANON(x))(CANON(y)))(la _. CON(x)(y))(la _. CON(y)(x)))(self(a))(self(b)))|      (la a. la b. CON(self(a))(self(b)))|' registers.la > "$T/reg_m1.la"; host "$T/reg_m1.la" reg_m1
red reg_m1 "coherence per register=FFFTFTTTFTTT all:F" "registers RED(⊕-sort removed: five registers named)"
red reg_m1 "NORMTREE==NORMK probes:F" "registers RED(differential)"
sed 's|  CONSc(REG("etymological") (G_ETYM)                             (R_ETYM) (ID_ETYM))(|  CONSc(REG("etymological") (G_ETYM)                             (R_ETYM) (R_ETYM))(|' registers.la > "$T/reg_m2.la"; host "$T/reg_m2.la" reg_m2
red reg_m2 "coherence per register=TTTTTTTFTTTT all:F" "registers RED(etymological projection un-normalised: position 8)"

# ═══ 7. modegenesis — Δ_M, four sub-gates ════════════════════════════════════
host modegenesis.la mg
want mg "ν* IRR/NOV/AUT/CON=TTTT admitted:T set=6 | F1 action≡⊗ =FTTF refused:T | F2 α-copy =FFTF refused:T | F3 false ren =TTFT refused:T | F4 constant =TTTF refused:T" modegenesis  #@ turns-red: red:mg_m1
want mg "re-admit ν* verdict=FFTF Δ_M(Δ_M)≡Δ_M idempotent:T" modegenesis  #@ turns-red: exact:s07; construction:re-admission: a member equals itself (F32)
want mg "ν* action on (A,B): ⊗(▷(A,A),↻(B))" modegenesis  #@ turns-red: exact:s07
# each sub-gate's RED path is a fixture above (one letter apiece); the operator itself:
sed 's|^glyph ADMIT = la set. la c. IF(str_eq(VERDICT(set)(c))("TTTT"))|glyph ADMIT = la set. la c. IF(TRUE)|' modegenesis.la > "$T/mg_m1.la"; host "$T/mg_m1.la" mg_m1
red mg_m1 "F1 action≡⊗ =FTTF refused:F" "modegenesis RED(admission ignores the verdict)"

# ═══ 8. regenesis — Δ_R, four sub-gates ══════════════════════════════════════
host regenesis.la rg
want rg "Δ_R register IRR/NOV/AUT/CON=TTTT admitted:T stack=13 | F1 projection=FTTT | F2 α-copy=TFTT | F3 false ren=TTFT | F4 constant=TTTF | F5 raw-route=TTFT | all five refused:T" regenesis  #@ turns-red: red:rg_m1
want rg "re-admit verdict=FFTT Δ_R(Δ_R)≡Δ_R idempotent:T" regenesis  #@ turns-red: construction:re-admission (F32)
want rg "reads κ as TTTTTTTTTTTT and ↻↻κ as TTTTTTTFTTTT" regenesis  #@ turns-red: construction:κ is its own twin (F32); exact:captured
sed 's|^glyph ADMIT_R = la stack. la c. IF(str_eq(VERDICT_R(stack)(c))("TTTT"))|glyph ADMIT_R = la stack. la c. IF(TRUE)|' regenesis.la > "$T/rg_m1.la"; host "$T/rg_m1.la" rg_m1
red rg_m1 "all five refused:F" "regenesis RED(admission ignores the verdict)"

# ═══ 9. complement + opposite — the antonym structure, four gates ═════════════
host complement.la cmp
want cmp "COMPLEMENT ¬X = ⊂(X,VOID) (ruling 2026-08-23) shape==opgrammar NEG_SHAPE:T" complement  #@ turns-red: exact:s09
want cmp "sealed+VOID-parent:T | ¬C≠C glyph:T truth:T | ¬¬C≠¬C glyph:T truth:T | ¬¬C≠C glyph:T ¬¬C≡C truth:T ¬¬¬C≡¬C truth:T" complement  #@ turns-red: red:cmp_m1,cmp_m2
want cmp "two registers explicit: differ on ¬¬C:T coincide on C:T | conflated system would read ¬¬C≡C as:F" complement  #@ turns-red: exact:s09; fixture:the conflated-register control reads F
want cmp "G_NOT=⊂(FORM,VOID) A(A)=⊂(⊂(FORM,VOID),VOID)" complement  #@ turns-red: exact:s09
want cmp "A(A)≠A glyph:T | A(A)≡id truth (cancels to the hole FORM):T" complement  #@ turns-red: exact:s09
sed 's|^glyph TRUTH_ID = la g. NORMK(CANCEL(ETYM(g)))|glyph TRUTH_ID = la g. NORMK(ETYM(g))|' complement.la > "$T/cmp_m1.la"; host "$T/cmp_m1.la" cmp_m1
red cmp_m1 "¬¬C≡C truth:F" "complement RED(double complement not cancelled)"
sed 's|^glyph NOTG = la g. COLLAPSE(NEG_MODE)(g)(GLYPH("VOID"))|glyph NOTG = la g. COLLAPSE(NEG_MODE)(g)(GLYPH("FORM"))|' complement.la > "$T/cmp_m2.la"; host "$T/cmp_m2.la" cmp_m2
red cmp_m2 "sealed+VOID-parent:F" "complement RED(¬ without Void)"
host opposite.la opp
want opp "OPP(Past)=▷(VOID,BECOMING) ≡Future:T | involution OPP(OPP(Past))=Past:T OPP(Past)≠Past:T | refuses primitive(Being):T ⊕:T ▷(x,x):T | HAS_POLE Past:T Being:F ->T" opposite  #@ turns-red: exact:s09; fixture:refuses Being / ⊕ / ▷(x,x); cannot-fail:F24 (HAS_POLE per-case values are literal text)
want opp "A(A)=▷(VOID,RELATION) exists:T A(A)≠A:T A(A(A))=A:T" opposite  #@ turns-red: exact:s09
sed 's|glyph OPP = la g. ETYM(g) (la nm. BOT(ETYM(g))) (la a. la b. BOT(ETYM(g))) (la a. la b. BOT(ETYM(g)))|glyph OPP = la g. ETYM(g) (la nm. BOT(ETYM(g))) (la a. la b. BOT(ETYM(g))) (la a. la b. SEALo(CON(b)(a)))|' opposite.la > "$T/opp_m1.la"; host "$T/opp_m1.la" opp_m1
red opp_m1 "⊕:F" "opposite RED(⊕ given a pole)"

# ═══ 12. textcoherence — whole-text coherence (the open discourse item) ═══════
host textcoherence.la tc
want tc "TEXTCOHERENCE text(a) n=5 edges=[2-1:share 3-2:contrast:opp 4-3:share 5-2:contrast:opp 5-3:share] components=1 coherent:T maxdist=3 orphans:none" textcoherence  #@ turns-red: exact:captured
want tc "referents=11 mentions=14 given=3 new=11" textcoherence  #@ turns-red: exact:captured
want tc "components=2 coherent:F maxdist=3 orphans:OFFENDER=⊂(FORM,DEPTH)" textcoherence  #@ turns-red: fixture:text(b) incoherent, offender named
want tc "each label fires alone:T" textcoherence  #@ turns-red: red:tc_m2
want tc "components order-independent:T maxdist original=3 shuffled=4" textcoherence  #@ turns-red: exact:captured
sed 's|^glyph TC_SHARE1 = la a. la b. str_eq(TC_T3A(a))(TC_T3A(b))|glyph TC_SHARE1 = la a. la b. FALSE|' textcoherence.la > "$T/tc_m1.la"; host "$T/tc_m1.la" tc_m1
red tc_m1 "components=3 coherent:F" "textcoherence RED(share links off: orphans named)"
sed 's|^glyph TC_OPP1   = la a. la b. str_eq(TC_T3C(a))(TC_T3A(b))|glyph TC_OPP1   = la a. la b. FALSE|' textcoherence.la > "$T/tc_m2.la"; host "$T/tc_m2.la" tc_m2
red tc_m2 "each label fires alone:F" "textcoherence RED(opposite contrast off)"
want tc "TEXTCOHERENCE score (Σ 100/link-distance) original=383 shuffled=191 | shuffled strictly lower:T" textcoherence  #@ turns-red: red:tc_m4
sed 's|add(acc)(div(100)(sub(TC_T3A(e))(TC_T3B(e))))|add(acc)(100)|' textcoherence.la > "$T/tc_m4.la"; host "$T/tc_m4.la" tc_m4
red tc_m4 "shuffled strictly lower:F" "textcoherence RED(distance-blind score reads shuffled equal)"
# ═══ 13. derive_closure — the derivation-closure composer ═════════════════════
host derive_closure.la dcl
want dcl "root→nine: root ∃(∃)≡∃:T derived=4/9:T [BEING SELF RECOGNITION LOVE] axioms=5/5:T [VOID DEPTH BECOMING FORM RELATION] seam=weakening/contraction/exchange closure{I}:T" derive_closure  #@ turns-red: red:dcl_m2
want dcl "nine→lexicon: grounded=21/21:T" derive_closure  #@ turns-red: exact:captured
want dcl "ungrounded fixture refused:T OFFENDER=PHANTOM/GHOST" derive_closure  #@ turns-red: red:dcl_m1
want dcl "dyad stratum (arithmetic beneath the nine): VOID=0:T BECOMING=succ:T naturals(ITER 5,9):T BEING=1:T bound(projection-not-injective):T" derive_closure  #@ turns-red: exact:captured
want dcl "DERIVATION CLOSURE VERDICT: BOUNDED" derive_closure  #@ turns-red: red:dcl_m3
sed 's/^glyph DC_LEXCAT = CAT$/glyph DC_LEXCAT = DC_HAUNTED/' derive_closure.la > "$T/dcl_m1.la"; host "$T/dcl_m1.la" dcl_m1
red dcl_m1 "grounded=21/22:F OFFENDER=PHANTOM/GHOST" "derive_closure RED(ghost leaf named)"
sed 's/CONS(PAIR(AX_REL)("RELATION"))/CONS(PAIR(DC_FALSE)("RELATION"))/' derive_closure.la > "$T/dcl_m2.la"; host "$T/dcl_m2.la" dcl_m2
red dcl_m2 "axioms=4/5:F [VOID DEPTH BECOMING FORM] UNWITNESSED=RELATION" "derive_closure RED(axiom unwitnessed named)"
sed 's/^glyph DC_NDERIVED = .*/glyph DC_NDERIVED = 9/' derive_closure.la > "$T/dcl_m3.la"; host "$T/dcl_m3.la" dcl_m3
red dcl_m3 "DERIVATION CLOSURE VERDICT: CLOSED" "derive_closure RED(the CLOSED branch is live)"

# ═══ 14. branchgenesis — Δ_B, the branch-genesis operator ═════════════════════
host branchgenesis.la bg
want bg "BRANCHGENESIS base=18 distinct-κ:T | Δ_B branch IRR/NOV/AUT/CON=TTTT admitted:T set=19 | F1 permuted domain=FTTT | F2 α-copy=TFTT | F3 false ren=TTFT | F4 no register=TTTF | F5 unknown register=TTFT | F6 projection=FTTT | all six refused:T" branchgenesis  #@ turns-red: red:bg_m1,bg_m2,bg_m3
want bg "re-admit verdict=FFTT Δ_B(Δ_B)≡Δ_B idempotent:T | G_DB=▷(RECOGNITION,↻(RELATION))" branchgenesis  #@ turns-red: construction:re-admission (F32)
sed 's|^glyph ADMIT_B = la T. la c. IF(str_eq(VERDICT_B(T)(c))("TTTT"))|glyph ADMIT_B = la T. la c. IF(TRUE)|' branchgenesis.la > "$T/bg_m1.la"; host "$T/bg_m1.la" bg_m1
red bg_m1 "all six refused:F" "branchgenesis RED(admission ignores the verdict)"
sed 's|^glyph SETEQ = la a. la b. AND(ALLL(la x. MEMS(x)(b))(a))(ALLL(la x. MEMS(x)(a))(b))|glyph SETEQ = la a. la b. FALSE|' branchgenesis.la > "$T/bg_m2.la"; host "$T/bg_m2.la" bg_m2
red bg_m2 "F1 permuted domain=TTTT" "branchgenesis RED(set-equality broken: F1 admitted)"
sed 's|^glyph AUT = la c. AND(AUTO_OK(BGLYPH(c)))(ALLL(REG_EXISTS)(BREGS(c)))|glyph AUT = la c. AUTO_OK(BGLYPH(c))|' branchgenesis.la > "$T/bg_m3.la"; host "$T/bg_m3.la" bg_m3
red bg_m3 "F5 unknown register=TTTT" "branchgenesis RED(unknown register admitted)"

# ═══ 15. ontoargument — Gödel's argument as a finite S5 model check ════════════
host ontoargument.la oa
want oa "OA[M] A1 P(φ)⊻P(¬φ):T A2 P⊨-closed:T A3 P(G):T A4 P(φ)→□P(φ):T A5 P(NE):T | G fixpoint over full L:T NE stable over full L:T" ontoargument  #@ turns-red: red:oa_m1,oa_m2,oa_m3
want oa "OA[M] T1 ◇∃x G(x):T T2 G ess x ∀God-like x:T T3 □∃x G(x):T" ontoargument  #@ turns-red: red:oa_m1
want oa "collapse ∀φ∀x(φ(x)→□φ(x)):F OFFENDER=GOOD(b)@w0¬@w1" ontoargument  #@ turns-red: fixture:collapse refused, offender named
want oa "OA[M+λ] A1 P(φ)⊻P(¬φ):T A2 P⊨-closed:T A3 P(G):T A4 P(φ)→□P(φ):F OFFENDER=[GOOD(b)]@w0↛w1" ontoargument  #@ turns-red: red:oa_m1,oa_m2
want oa "OA[M♭+λ] T1 ◇∃x G(x):T T2 G ess x ∀God-like x:T T3 □∃x G(x):T God-like=a@w0 a@w1 a@w2 G=TTTFFFFFF NE=TTTTTTTTT |L|=28 | collapse ∀φ∀x(φ(x)→□φ(x)):T" ontoargument  #@ turns-red: red:oa_m1
want oa "OA GLYPHS □=⊗(BEING,FORM) ◇=⊗(BECOMING,FORM) ¬=⊂(·,VOID) ∀=⊗(BEING,DEPTH) ∃=⊗(FORM,DEPTH)" ontoargument  #@ turns-red: exact:captured
want oa "LAW_IDENTITY(sealed T3):T" ontoargument  #@ turns-red: construction:AUTO_OK of a fresh seal (F32)
sed 's/OA_PAIR("GOOD")("TTTTFFFFF")/OA_PAIR("GOOD")("TTFTFFFFF")/' ontoargument.la > "$T/oa_m1.la"; host "$T/oa_m1.la" oa_m1
red oa_m1 "A2 P⊨-closed:F OFFENDER=GOOD⊨¬G@w0" "ontoargument RED(cell flip breaks A2, named)"
red oa_m1 "T3 □∃x G(x):F" "ontoargument RED(cell flip: T3 falls)"
sed 's/OA_PAIR("GOOD")("TTT")/OA_PAIR("GOOD")("FFF")/' ontoargument.la > "$T/oa_m2.la"; host "$T/oa_m2.la" oa_m2
red oa_m2 "A1 P(φ)⊻P(¬φ):F OFFENDER=GOOD@w0" "ontoargument RED(P flip breaks A1, named)"
sed 's/OA_PAIR("NE")("TTT")/OA_PAIR("NE")("FFF")/' ontoargument.la > "$T/oa_m3.la"; host "$T/oa_m3.la" oa_m3
red oa_m3 "A5 P(NE):F OFFENDER=NE@w0" "ontoargument RED(NE not positive: A5 named)"

#  ⚠ COUNTS MOVED 2026-09-17 when the identity-adequacy rulings (§49) were APPLIED to lexicon.la and
#    opgrammar.la: seven overloaded entries were re-derived, so combinations went 71 → 78 and three
#    skeleton counts shifted (⊗ −2, ▷ −1, ⊂ +3). Rows are unchanged at 79. Every new number was
#    re-derived by an independent python census BEFORE this line was edited.
# ═══ 16. ontomorph — the inflectional census, gated (LA_COMPLETION.md:1187) ═════
host ontomorph.la om
want om "ONTOMORPH corpus rows=79 (LEX+RULED+GRAM+GRULED) | skeletons=10: *(·,·)=33 >(·,·)=21 +(·,·)=3 *(*(·,·),·)=9 ·=3 >(·,*(·,·))=1 >(*(·,·),*(·,·))=1 *(*(·,·),*(·,·))=1 c(·,·)=5 m(·)=2  | operator uses *=57 >=23 +=3 c=5 m=2" ontomorph  #@ turns-red: exact:captured
want om "ONTOMORPH combinations=78 κ-images=78 | injective (distinct combinations → distinct κ):T | fixture +36/+63 refused:T OFFENDER=+36/+63" ontomorph  #@ turns-red: red:om_m1
want om "entry overloads (one κ, two names; the architect's to rule)=1: *(BEING,DEPTH):Totality/All/" ontomorph  #@ turns-red: exact:captured
#  ★ The overload count is 1, not 0, BY DESIGN: §49 ruled Totality = All a DECLARED IDENTITY — one
#    concept under two English words, the same status as ρ ≡ SR_ABOUT. A declared identity is kept
#    VISIBLE and annotated, never silently deduplicated. The other seven were re-derived away.
sed 's|^glyph OM_KOF = la combo. KAN_N(OM_FST(PARSE(combo)))|glyph OM_KOF = la combo. KAN(OM_FST(PARSE(combo)))|' ontomorph.la > "$T/om_m1.la"; host "$T/om_m1.la" om_m1
red om_m1 "fixture +36/+63 refused:F" "ontomorph RED(raw canonicalisation: ⊕ commutativity ignored)"
# ═══ 17. gramcomplete — the Grammar Completeness theorem, gated in its honest form ═
host gramcomplete.la gc
want gc "GRAMCOMPLETE corpus=79 derived by R1-R3=79/79:T | rules used R1=167 R2=88 R3=2" gramcomplete  #@ turns-red: exact:captured
want gc "traces: Water R2(*,R2(*,R1(8),R1(1)),R1(7)) | Question R2(>,R1(2),R1(6)) | Ongoing R3(R1(7)) | Bad(ruled) R2(c,R1(3),R1(6))" gramcomplete  #@ turns-red: exact:captured
want gc "sealed self-naming:T Give?=⊕(▷(7,5),▷(2,6)) | primitive refused (d=0):T | unreachable fixtures refused, rule named 3/3:T [UNREACHABLE R1: 0 ∉ 𝒜 ; UNREACHABLE R2: a missing operand ; UNREACHABLE R3: no operand]" gramcomplete  #@ turns-red: red:gc_m2; construction:sealed self-naming = AUTO_OK of a seal (F32)
sed 's|^glyph GC_ISDIG = la c. NOT(str_eq(NAM(c))(""))|glyph GC_ISDIG = la c. TRUE|' gramcomplete.la > "$T/gc_m1.la"; host "$T/gc_m1.la" gc_m1
red gc_m1 "eval error" "gramcomplete RED(validation bypassed: the parser CRASHES on an unreachable concept instead of naming the rule — the class the validator exists to prevent)"
sed 's|^glyph GC_SEAL4 = la t. IF(lt(0)(TDEPTH(t)))|glyph GC_SEAL4 = la t. IF(TRUE)|' gramcomplete.la > "$T/gc_m2.la"; host "$T/gc_m2.la" gc_m2
red gc_m2 "primitive refused (d=0):F" "gramcomplete RED(R4 precondition dropped)"
# ═══ 18. neologenesis — the birth as one compressive movement (K_unified = the seal) ═══
host neologenesis.la ng
want ng "BIRTH ⊗(κ,𝓡): born in one movement 10/12 — phonetic:T glyphic:T semantic:T morphological:T syntactic:T pragmatic:F operational(tree-law):T etymological:T prosodic:T evidential:F affective:T topological:T | form: one-seal(AUTO_OK):T nodes=6 nodes≤|A|+|B|+1:T depth=1+max:T content=TSIZE(A)+TSIZE(B)+1:T route-recoverable:T" neologenesis  #@ turns-red: red:ng_m1; construction:the one-seal(AUTO_OK) law on a COLLAPSE child (F32)
want ng "BIRTH ⊕(𝓡,κ) [κ-sorted]: born in one movement 10/12" neologenesis  #@ turns-red: red:ng_m1; construction:the one-seal(AUTO_OK) law on a COLLAPSE child (F32)
want ng "BIRTH ↻(κ): born in one movement 10/12" neologenesis  #@ turns-red: red:ng_m1; construction:the one-seal(AUTO_OK) law on a COLLAPSE child (F32)
want ng "BIRTH ↻(SELF⊕SELF) [the seal REWRITES: a birth that is not a birth]: born in one movement 7/12 — phonetic:F glyphic:T semantic:T morphological:F syntactic:F pragmatic:T operational(tree-law):F etymological:T prosodic:F evidential:T affective:T topological:T | form: one-seal(AUTO_OK):T child≡parent(rewrite):T depth=1+d(A):T" neologenesis  #@ turns-red: red:ng_m1; construction:the one-seal(AUTO_OK) law on a COLLAPSE child (F32)
sed 's|^glyph NG_CHILD = la sym. la a. la b. COLLAPSE(MKMODE(sym))(a)(b)|glyph NG_CHILD = la sym. la a. la b. COLLAPSE(MKMODE(sym))(a)(a)|' neologenesis.la > "$T/ng_m1.la"; host "$T/ng_m1.la" ng_m1
red ng_m1 "BIRTH ⊗(κ,𝓡): born in one movement 2/12" "neologenesis RED(child sealed from the wrong parents: every law but evidential fails)"
# ═══ 19. unified — the dyadic law, no glyphic entropy, syntropy/centropy, morphology-is-glyphs, onto-registry ═
host unified.la un
want un "UNIFIED dyadic law (C2..C4 = ⊗ of shared parents): one-seal+ren≠renA·renB+nodes+1+depth+1:T coupled form refused (fails AUTO_OK):T | chain d=1 S=3 nodes=3 | d=2 S=7 nodes=6 | d=3 S=15 nodes=7 | d=4 S=31 nodes=8 | d=5 S=63 nodes=9 |" unified  #@ turns-red: red:un_m1; construction:the dyadic step (F32)
want un "raster SZ=32 at every depth fixed:T | phonym ⊗-chain PDUR(C4)=PDUR(C0):T | phonym per mode over (κ,𝓡): ⊗=12880 ⊕=26560 ▷=25600 ⊂=38320 ↻=25760 | sound grows under ⊕ (finding, codex Operator Phonology):T" unified  #@ turns-red: cannot-fail:F28 (raster int_eq(SZ)(SZ)); exact:captured; construction:sound grows under ⊕ restates the duration law (F32)
want un "UNIFIED syntropy: S=TSIZE rises:T TSIZE(Cn)=2·TSIZE(Cn-1)+1:T TSIZE≥2^depth:T" unified  #@ turns-red: red:un_m2; construction:tree arithmetic (F32)
want un "centropy Δ_S(Δ_S)≡Δ_S truth:T" unified  #@ turns-red: construction:↻↻≡↻ (F4)
want un "UNIFIED morphology is glyphs: 5/5 modes are self-naming seals grounded in the nine:T GHOST-leaf mode refused:T" unified  #@ turns-red: construction:AUTO_OK of a seal (F32); fixture:GHOST-leaf mode refused
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
want en "I vertical: surface=⊗(▷(RECOGNITION,FORM),▷(DEPTH,RECOGNITION)) | first depth: ▷(RECOGNITION,FORM), ▷(DEPTH,RECOGNITION) | second depth: RECOGNITION, FORM, DEPTH, RECOGNITION | third depth (operators): ⊗ ▷ ▷" entendre  #@ turns-red: exact:s21
want en "II horizontal: facets=6: RECOGNITION;FORM;▷0.1;DEPTH;▷3.0;⊗2.4 | III calligraphic: elements: marks=3 (⊗1 ⊕0 ▷2 ⊂0 ↻0) leaves=4 [B: census, not execution]" entendre  #@ turns-red: exact:s21
want en "four readings pairwise distinct, all derived from the DAG:T | primitive LOVE: I=⊥" entendre  #@ turns-red: red:en_m1; cannot-fail:F23 (labelled strings)
want en "primitive has no vertical reading (red path):T" entendre  #@ turns-red: red:en_m2
sed 's|^glyph ENTENDRE_II = la t. EN_C3("facets=")(int_to_str(LEN(SPLIT(";")(DAG(t)))))(EN_C3(": ")(DAG(t))(""))|glyph ENTENDRE_II = la t. ENTENDRE_I(t)|' entendre.la > "$T/en_m1.la"; host "$T/en_m1.la" en_m1
red en_m1 "pairwise distinct, all derived from the DAG:F" "entendre RED(two modes read the same)"
sed 's|(la _. "⊥ (a primitive has no strata below its surface)")|(la _. "surface only")|' entendre.la > "$T/en_m2.la"; host "$T/en_m2.la" en_m2
red en_m2 "no vertical reading (red path):F" "entendre RED(a primitive given a vertical reading)"
# ═══ 22. felicitylive — ontofelicity wired to the capability sealer (LA_COMPLETION "live enforcement") ═
host felicitylive.la fl
want fl "FELICITY-LIVE authorized realm: performed:open world=world +open | foreign realm: INFELICITOUS TFT refusing:open world unchanged:T" felicitylive  #@ turns-red: red:fl_m1
want fl "forged probe opens the box:F | string-caps PERFORM and live PERFORM agree on the authorized case:T | (B) is now the sealer, not a substring: T" felicitylive  #@ turns-red: fixture:forged probe refused; exact:captured
sed 's|^glyph COND_B_LIVE = la u. la speaker. la box. GRANT_RECV(speaker)(box)(la held. str_eq(held)(FL_UNEED(u)))(FL_FALSE)|glyph COND_B_LIVE = la u. la speaker. la box. GRANT_RECV(REALM_A)(box)(la held. str_eq(held)(FL_UNEED(u)))(FL_FALSE)|' felicitylive.la > "$T/fl_m1.la"; host "$T/fl_m1.la" fl_m1
red fl_m1 "foreign realm: performed:open" "felicitylive RED(bypass: unsealing with the granting realm lets a foreign speaker perform)"
# ═══ 23. syllabus — acquisition: the teaching order the structure implies (LA_COMPLETION "Acquisition") ═
host syllabus.la sy
want sy "SYLLABUS lessons=79 by depth d0=3 d1=64 d2=12 d3=0 | depth non-decreasing:T | constituent-first violations=0 (0 required):T | reversed order violations=72 (red path, must be >0)" syllabus  #@ turns-red: red:sy_m1; construction:depth-monotone + violations=0 follow from the sort (F32)
want sy "SYLLABUS first lessons: Two One I None Ongoing Consciousness Agency Beauty Mystery Witness Grief Gratitude" syllabus  #@ turns-red: exact:captured
sed 's|IF(lt(L_KEY(h))(L_KEY(x)))(la _. SY_CONS(h)(self(t)))(la _. SY_CONS(x)(l))|IF(lt(L_KEY(x))(L_KEY(h)))(la _. SY_CONS(h)(self(t)))(la _. SY_CONS(x)(l))|' syllabus.la > "$T/sy_m1.la"; host "$T/sy_m1.la" sy_m1
red sy_m1 "depth non-decreasing:F" "syllabus RED(descending order: depth invariant lost)"
# ═══ 24. aware — the AWARE / C predicates (LA_COMPLETION Tier 4) ═══════════════════
host aware.la aw
want aw "AWARE/C over the catalogue: all AWARE:T all C:T | A and C coincide on every sealed glyph:T | the liar: AWARE=F C=F | two turns of κ still C:T" aware  #@ turns-red: red:aw_m1; construction:all-A / all-C / coincide = AUTO_OK of seals (F32)
sed 's|^glyph C_PRED = la g. AND(AUTO_OK(g))(AUTO_OK(MCOLLAPSE(g)))|glyph C_PRED = la g. AND(AUTO_OK(g))(AUTO_OK(MONO(REN(g))(MC(ETYM(g)))))|' aware.la > "$T/aw_m1.la"; host "$T/aw_m1.la" aw_m1
red aw_m1 "all C:F" "aware RED(a turn that keeps the old ren: C separates from A only for a seal that does not re-name)"
# ═══ 25. ablateop — the meta-word ablation gate (LA_COMPLETION Tier 4) ═════════════
host ablateop.la ab
want ab "ABLATEOP D1=⊗(▷(VOID,RELATION),⊂(FORM,DEPTH)) D2=⊗(⊗(BECOMING,FORM),↻(RECOGNITION)) | all five: D1:T D2:T" ablateop  #@ turns-red: exact:s25
want ab "ablate ∂: D1 underivable:T D2 survives:T other four survive:T | ablate γ: D2 underivable:T D1 survives:T other four survive:T | ablate 𝔄 (control): D1:T D2:T" ablateop  #@ turns-red: red:ab_m1
sed 's|^glyph AB_CONTAINS = .*|glyph AB_CONTAINS = la s. la sub. AB_TRUE|' ablateop.la > "$T/ab_m1.la"; host "$T/ab_m1.la" ab_m1
red ab_m1 "control): D1:F D2:F" "ablateop RED(containment that always says yes: the control collapses)"
# ═══ 26. wants — lack-driven wants (LA_COMPLETION Tier 4) ═════════════════════════
host wants.la wn
want wn "WANTS organ-A lacks MEMORY → want=MEMORY names the lack:T | organ-B complete → want=⊥ (⊥ required):T" wants  #@ turns-red: red:wn_m1
want wn "WANTS resolve(organ-A): lack after= closed:T centropy before=3 after=4 strictly rises:T" wants  #@ turns-red: exact:captured
sed 's|^glyph WANT = la s. IF(str_eq(SLACKS(s))(""))(la _. "⊥")(la _. SLACKS(s))|glyph WANT = la s. SLACKS(s)|' wants.la > "$T/wn_m1.la"; host "$T/wn_m1.la" wn_m1
red wn_m1 "(⊥ required):F" "wants RED(a want formed for a complete organ)"
# ═══ 27. protoagent — REPAIR toward closure, the ill class refused (LA_COMPLETION Tier 4) ═
host protoagent.la pa
want pa "PROTO_AGENT incomplete+WF: repaired: centropy 2→4 gain>0:T result autological:T | complete+WF: repaired: centropy 4→4 gain=0:T" protoagent  #@ turns-red: exact:captured
want pa "PROTO_AGENT incomplete+ILL: REFUSED: composition ORDER-VIOLATION (provably ill) — no repair moves it toward closure untouched:T | swc order verdicts WF=WELL-ORDERED ILL=ORDER-VIOLATION" protoagent  #@ turns-red: red:pa_m1
sed 's|IF(str_eq(ORDER(c))("ORDER-VIOLATION"))|IF(FALSE)|' protoagent.la > "$T/pa_m1.la"; host "$T/pa_m1.la" pa_m1
red pa_m1 "untouched:F" "protoagent RED(the ill guard dropped: an ill composition gets repaired)"
# ═══ 28. fractal — the fractal monoglyph, measured (LA_COMPLETION Tier 4) ═══════════
host fractal.la fr
want fr "FRACTAL chain: surface=49 fractal=6 | surface=104 fractal=7 | surface=214 fractal=8 | surface=434 fractal=9 | surface doubles while the fractal form grows by one:T | tree recoverable from the DAG alone at every depth:T" fractal  #@ turns-red: red:fr_m1
sed 's|^glyph FR_FRAC = la g. NODES(DAG(ETYM(g)))|glyph FR_FRAC = la g. TSIZE(ETYM(g))|' fractal.la > "$T/fr_m1.la"; host "$T/fr_m1.la" fr_m1
red fr_m1 "grows by one:F" "fractal RED(the unfolded size read where the hash-consed form is meant)"
# ═══ 29. branchclosure — are the branches dyadic and metacursive? the non-vacuous answer ═
host branchclosure.la bc
want bc "BRANCHCLOSURE branches=19 | all grounded in the nine (start from the dyad):T | ⊂(RELATION,·) dyad form: 18/19 (18 branches + Δ_B's ▷ = 1 exception, expected 18):T" branchclosure  #@ turns-red: construction:reads back its own ⊂(RELATION,x) constructor (F32); exact:captured
want bc "fixtures refused: SYN-head not the ⊂ dyad:T GHOST leaf not grounded:T OFFENDER=⊂(RELATION,▷(GHOST,FORM))" branchclosure  #@ turns-red: red:bc_m1,bc_m2
sed 's|^glyph BC_GROUND1 = Z(la self. la t. t(la nm. BC_IS9(nm))|glyph BC_GROUND1 = Z(la self. la t. t(la nm. TRUE)|' branchclosure.la > "$T/bc_m1.la"; host "$T/bc_m1.la" bc_m1
red bc_m1 "GHOST leaf not grounded:F" "branchclosure RED(grounding disabled: an ungrounded branch passes)"
sed 's|^glyph BC_DYAD1 = la g. AND(HAS_PREFIX(CANON(g))("⊂("))(HAS_PREFIX(CANON(g))("⊂(RELATION,"))|glyph BC_DYAD1 = la g. TRUE|' branchclosure.la > "$T/bc_m2.la"; host "$T/bc_m2.la" bc_m2
red bc_m2 "SYN-head not the ⊂ dyad:F" "branchclosure RED(dyad-form check disabled: a non-dyad branch passes)"


# ═══ 30. gapcensus — the autological completion instrument (Erik, 2026-09-15) ══════
host gapcensus.la gp
want gp "GAPCENSUS instrument (gate_registers.sh) present with proven RED paths + PASS line:T | seed items=6 self-closable=3 ceiling=2 external=1 | all consistent (declared==computed):T" gapcensus  #@ turns-red: red:gp_m1; cannot-fail:F31 ("proven RED paths" = two substrings)
want gp "miscategorisation fixture (vacuous claim declared self-closable) caught:T OFFENDER=FIXTURE: vacuous claim mislabelled self-closable" gapcensus  #@ turns-red: fixture:mislabelled item caught
sed 's|^glyph GC_DISCRIMINATES = la pred. la good. la bad. NOT(str_eq(GC_BSTR(pred(good)))(GC_BSTR(pred(bad))))|glyph GC_DISCRIMINATES = la pred. la good. la bad. TRUE|' gapcensus.la > "$T/gp_m1.la"; host "$T/gp_m1.la" gp_m1
red gp_m1 "all consistent (declared==computed):F" "gapcensus RED(discriminator always-true: the two ceilings misread as self-closable)"

# ═══ 31. recdepth — the Recognition Depth function ρ(L_t) (LA_COMPLETION Tier 4; tex def:rec-depth) ═══
#  Every witness below was derived independently (a python re-implementation of the tex definition over
#  the same catalogue) BEFORE this gate was written, never pasted from the module's own run.
host recdepth.la rd
want rd "RECDEPTH catalogue entries=35 κ-distinct=34 | orders n0=9 n1=20 n2=5 n3=0 | ρ(L_t)=2 | cited forms read back from their modules:T" recdepth  #@ turns-red: exact:captured
want rd "add ↻(ν*) — Δ* as an object, the tex's level 3: ρ 2→3 strictly rises:T" recdepth  #@ turns-red: red:rd_m1
want rd "add ⊕(BEING,LOVE) at an existing level: ρ→2 unmoved:T" recdepth  #@ turns-red: exact:captured
want rd "tree depth 3 with nothing catalogued inside: order=1 ρ→2 unmoved:T (ρ is NOT tree depth)" recdepth  #@ turns-red: red:rd_m2
want rd "ν* order with the five mode glyphs catalogued=2 without them=1 state-relative:T | relaxation passes=4" recdepth  #@ turns-red: red:rd_m2; cannot-fail:F31 (passes=4 is the constant bound)
#  κ-distinct=34 from 35 entries IS the ρ ≡ SR_ABOUT identity, counted once because the census is keyed
#  on the canonical form and never on the name (the standing invariant).
sed 's|^glyph SUBSTRS = la f. f(la nm. NILc).*|glyph SUBSTRS = la f. ALLSTR(f)|' recdepth.la > "$T/rd_m1.la"; host "$T/rd_m1.la" rd_m1
red rd_m1 "ρ(L_t)=4" "recdepth RED(proper-ness dropped: every glyph becomes its own sub-form, orders run away)"
red rd_m1 "strictly rises:F" "recdepth RED(proper-ness dropped: the level-3 addition no longer moves ρ)"
sed 's|^glyph ORDER_STEP = .*|glyph ORDER_STEP = la ords. la ncat. la e. TDEPTH(E_FORM(e))|; s|^glyph ORDER_IN = .*|glyph ORDER_IN = la ords. la ncat. la f. TDEPTH(f)|' recdepth.la > "$T/rd_m2.la"; host "$T/rd_m2.la" rd_m2
red rd_m2 "tree depth 3 with nothing catalogued inside: order=3 ρ→3 unmoved:F" "recdepth RED(order := tree depth: the deep unregistered probe moves ρ)"
red rd_m2 "state-relative:F" "recdepth RED(order := tree depth: ρ stops depending on the language state)"

# ═══ 32. selfevo — the Self-Evolution Equation, run to its fixed point (LA_COMPLETION Tier 4; tex def:self-evo-eq) ═══
#  Every number below was derived independently (a python re-implementation of κ, |I(g)| and the density
#  formula over the same seed and the same Ops list) BEFORE this gate was written: |L_0|=9 σ=9 D=1000;
#  |L_1|=26 σ=66 D=2538; 18 operations named, 17 κ-distinct.
host selfevo.la se
want se "SELFEVO seed |L_0|=9 ρ=0 D=1000 rules=0 | Ops named=18 κ-distinct=17 (ρ and SR_ABOUT are one κ-form: κ-keyed; a name-keyed census would read 18)" selfevo  #@ turns-red: exact:captured
want se "SELFEVO t=0→1 |L|=9→26 ρ 0→2 D 1000→2538 rules 0→5 | five laws hold:T" selfevo  #@ turns-red: red:se_m1,se_m2
want se "SELFEVO t=1→2 |L|=26→26 ρ 2→2 D 2538→2538 | five laws hold:T | FIXED POINT L_2=L_1:T nothing left unglyphed:T" selfevo  #@ turns-red: red:se_m1,se_m2; construction:fixed point compared by LENGTH, and laws at a fixed point compare a state with itself (F32)
sed 's|^glyph SE_STEP = la st. N_DISTINCT(SE_MINT(st))|glyph SE_STEP = la st. N_DISTINCT(SE_MINT(NILc))|' selfevo.la > "$T/se_m1.la"; host "$T/se_m1.la" se_m1
red se_m1 "five laws hold:F OFFENDER=DEPTH" "selfevo RED(lossy step: the union is dropped, the Fifth Law names the glyph that lost its meaning)"
sed 's|^glyph SE_MINT = la st. RD_FOLD.*|glyph SE_MINT = la st. st|' selfevo.la > "$T/se_m2.la"; host "$T/se_m2.la" se_m2
red se_m2 "five laws hold:F OFFENDER=ρ(L_t) recognition depth" "selfevo RED(mint made a no-op: the First Law names the operation left unglyphed)"
red se_m2 "ρ 0→0" "selfevo RED(mint made a no-op: ρ never leaves 0, the fixed point is reached vacuously)"
red se_m2 "nothing left unglyphed:F" "selfevo RED(mint made a no-op: the closure claim itself goes false)"

# ── Sections 33–40 were drafted before they could be run (the deep lease was with the full audit) and
#    sat behind a REGS_DRAFT guard until 2026-09-17, when every one of them ran: 33 pinned witnesses
#    present, 19 RED paths fired, none dead. The guard is removed because it has served its purpose —
#    it existed so a derived-but-unexecuted check could not join the green suite silently.
# ═══ 33. certify — Engineering Seal 2, proof-carrying glyphs (LA_COMPLETION Tier 4; tex §5020) ═══
#  ✔ RAN GREEN 2026-09-17 (first execution, after the gate-file read was threaded out of the per-entry
#  path — as a named glyph it was re-read and re-split once per catalogue entry). Witnesses derived independently: 35 catalogue entries (the same RD_CAT recdepth and
#  ontosemiosyntax census), κ's arity spine "200" (a binary node over two leaves) and its ONF.
#  ★ The checker VERIFIES rather than trusts: field (b) carries the hash-consed LINEAGE and the checker
#  REPLAYS it, instead of comparing a stored ONF string against itself.
host certify.la ce
want ce "CERTIFY catalogue=35 certificates=35 | every glyph certified:T | coverage fixture (one entry withheld from the sweep) is caught:T OFFENDER=KAPPA | all three fields verify by re-derivation:T" certify  #@ turns-red: red:ce_m2; construction:every glyph certified = mint-then-verify (F32)
want ce "CERTIFY forged (a) arity refused:T | forged (b) ONF refused:T OFFENDER=(b) ONF equivalence | forged (c) reality witness refused:T | the honest certificate verifies:T" certify  #@ turns-red: red:ce_m1
want ce "CERTIFY κ spine of ▷(RECOGNITION,FORM)=200 | replayed lineage → ONF ▷(RECOGNITION,FORM) matches NORMK:T" certify  #@ turns-red: exact:captured
sed 's|^glyph VERIFY_B = la g. la c. str_eq(RECOVER(C_LIN(c)))(NORMK(ETYM(g)))|glyph VERIFY_B = la g. la c. str_eq(C_SPINE(c))(C_SPINE(c))|' certify.la > "$T/ce_m1.la"; host "$T/ce_m1.la" ce_m1
red ce_m1 "forged (b) ONF refused:F" "certify RED(the certificate is compared against ITSELF instead of the lineage being replayed: the forged-ONF certificate passes — the exact trusting-vs-verifying failure this ledger row names)"
sed 's|^glyph COVER_BAD = la certs. .*|glyph COVER_BAD = la certs. ""|' certify.la > "$T/ce_m2.la"; host "$T/ce_m2.la" ce_m2
red ce_m2 "coverage fixture (one entry withheld from the sweep) is caught:F" "certify RED(coverage check made vacuous: the withheld glyph is no longer named, so the suite could pass by certifying a convenient subset)"
#  ★ The coverage check needed a FIXTURE to be worth anything: the sweep certifies every entry it SEES,
#  so checking its output against the same list it swept CANNOT FAIL. The first version did exactly that
#  and was a vacuous gate. It now sweeps a catalogue with one entry deliberately WITHHELD and must NAME it.

# ═══ 34. migrate — Engineering Seal 3, versioning without semantic drift (LA_COMPLETION Tier 4; tex §5024) ═══
#  ✔ RAN GREEN 2026-09-17 (first execution). Every witness below was DERIVED in a separate python re-implementation of κ/NORMK from the tex
#  BEFORE this section was written — none is captured from the module. Run it, confirm, then move the row.
host migrate.la mig
want mig "MIGRATE registry=4 | cosmetic ⊕(BEING,LOVE)→⊕(LOVE,BEING) form changed:T ONF held ⊕(BEING,LOVE) admitted:T" migrate  #@ turns-red: exact:captured
want mig "MIGRATE semantic ⊂(BEING,LOVE)→⊂(LOVE,BEING) refused:T REFUSED HOLD: invariant ONF changed ⊂(BEING,LOVE) -> ⊂(LOVE,BEING) (semantic change: fork it under a new name)" migrate  #@ turns-red: red:mig_m1
want mig "MIGRATE same change as a FORK under a new name: admitted:T additive 4→5 old form still present:T" migrate  #@ turns-red: construction:4→5 is the CONS of an admission (F32)
want mig "MIGRATE ratchet on the fork path: a new name NEWK offered on ▷(RECOGNITION,FORM) refused:T REFUSED fork: ONF already names KAPPA" migrate  #@ turns-red: red:mig_m1,mig_m2
want mig "G_MIG=⊂(BECOMING,↻(RECOGNITION)) | its cosmetic refinement ⊂(BECOMING,↻(↻(RECOGNITION))) admitted:T | its semantic revision ⊂(↻(RECOGNITION),BECOMING) refused:T" migrate  #@ turns-red: red:mig_m1
#  the admitted revisions really CHANGE THE FORM (two distinct κ routes, one ONF), so "cosmetic" is not a
#  no-op fixture that would pass with the law deleted — that is what "form changed:T" witnesses.
sed 's|^glyph ADMIT = la nm. la form. str_eq(MG_ONF(MG_LOOK(nm)))(MG_ONF(form))|glyph ADMIT = la nm. la form. TRUE|' migrate.la > "$T/mig_m1.la"; host "$T/mig_m1.la" mig_m1
red mig_m1 "refused:F" "migrate RED(invariant check disabled: a semantic revision is admitted and drift enters through revision)"
sed 's|^glyph RATCHET = la nm. la form. .*|glyph RATCHET = la nm. la form. ""|' migrate.la > "$T/mig_m2.la"; host "$T/mig_m2.la" mig_m2
red mig_m2 "offered on ▷(RECOGNITION,FORM) refused:F" "migrate RED(ratchet disabled: a fork collapses onto an existing glyph's ONF and monosemy is lost)"

# ═══ 35. closure — Meta-Ontosemantic Closure, SLACKS(x)="" for a NAMED x (LA_COMPLETION Tier 4 Ledger row) ═══
#  ✔ RAN GREEN 2026-09-17 (first execution). The aatc diagnosis FTTT and the
#  centropy values 3→2→3 were derived by an independent shell+python reading of gate_registers.sh
#  BEFORE this section was written. The listed/checked COUNTS are printed by the module but are
#  deliberately NOT pinned here: they rise as the stack grows, and pinning them would turn ordinary
#  growth into a false RED. The pinned property is examined:T + all-listed-are-checked:T.
host closure.la cl
want cl "examined:T all-listed-are-checked:T | residue=(none) | SLACKS(suite)=\"\":T CLOSURE(suite):T AATC diagnosis(incl/appl/valid/closure)=FTTT centropy=3" closure  #@ turns-red: exact:captured
want cl "CLOSURE red path (the ledger's own: a deliberately re-introduced slack entry) residue=notgated.la named:T CLOSURE goes F:T centropy falls 3→2 strictly:T" closure  #@ turns-red: cannot-fail:F27 (the fold seed short-circuits)
want cl "CLOSURE resolved by aatc's T_CLOSE: SLACKS=\"\":T CLOSURE:T centropy rises 2→3 strictly:T" closure  #@ turns-red: exact:captured
sed 's|^glyph RESIDUE = la lines. la extra. .*|glyph RESIDUE = la lines. la extra. ""|' closure.la > "$T/cl_m1.la"; host "$T/cl_m1.la" cl_m1
red cl_m1 "residue= named:F" "closure RED(residue scan made constant-empty: the re-introduced slack is no longer named and the fixture reads closed)"
sed 's|^glyph CL_FORLINE = la lines. .*|glyph CL_FORLINE = la lines. ""|' closure.la > "$T/cl_m2.la"; host "$T/cl_m2.la" cl_m2
red cl_m2 "listed=0 checked=0" "closure RED(the module list was never found: a residue scan that examined nothing would otherwise read CLOSED — an instrument must prove it looked)"

# ═══ 36. metakappa — κ*, meta-ontosemantic meta-compression (LA_COMPLETION Category 1; tex §2506) ═══
#  ✔ RAN GREEN 2026-09-17 (first execution). Pattern, multiplicities, the 8-vs-6
#  node measurement and all four irreducibility verdicts were derived by an independent python sub-form
#  census BEFORE this section was written.
#  ★ THE RESULT IS A NEGATIVE ONE and that is why the POSITIVE CONTROL is gated first: an engine that
#  reports "nothing found" is indistinguishable from an engine that cannot look.
host metakappa.la ks
want ks "METAKAPPA positive control {⊗(↻(RECOGNITION),VOID), ⊗(↻(RECOGNITION),FORM)} admitted:T pattern=↻(RECOGNITION) multiplicity=2 sealed=↻(RECOGNITION) | measured sharing: unfolded nodes=8 hash-consed=6 strictly smaller:T" metakappa  #@ turns-red: fixture:positive control (a planted recurrence must be found)
want ks "METAKAPPA negative control {⊗(↻(RECOGNITION),VOID), ⊗(↻(LOVE),VOID)} shares the LEAF VOID and is refused:T max compound multiplicity=1 (1 = coinage, not meta-compression)" metakappa  #@ turns-red: red:ks_m1
want ks "METAKAPPA the live catalogue: modes κ*-irreducible:T operators:T self-relations:T whole catalogue (35 entries):T" metakappa  #@ turns-red: red:ks_m1,ks_m2
sed 's|IF(IS_LEAF(f))(la _. NILc)(la _. KS_APP|IF(FALSE)(la _. NILc)(la _. KS_APP|' metakappa.la > "$T/ks_m1.la"; host "$T/ks_m1.la" ks_m1
red ks_m1 "modes κ*-irreducible:F" "metakappa RED(compound test dropped: leaves count, so every set 'recurs' and the criterion means nothing)"
red ks_m1 "is refused:F" "metakappa RED(compound test dropped: the leaf-sharing negative control is wrongly admitted)"
sed 's|^glyph KS_ADMIT = la S. lt(1)(KS_MAXMULT(S))|glyph KS_ADMIT = la S. lt(0)(KS_MAXMULT(S))|' metakappa.la > "$T/ks_m2.la"; host "$T/ks_m2.la" ks_m2
red ks_m2 "whole catalogue (35 entries):F" "metakappa RED(multiplicity threshold lowered to 1: κ* admits a pattern that occurs once, which is coinage, not meta-compression)"

# ═══ 37. substitution — the Substitution Test (the Algebra of Naming's missing companion; tex thm:deceptive) ═══
#  ✔ RAN GREEN 2026-09-17 (first execution). The verdicts, the probe count 39 and
#  the two search counts (7 μ-equal pairs, 0 clause-(ii) cases) were derived by an independent python
#  re-implementation BEFORE this section was written.
#  ★ Only THREE of the theorem's four verdicts are reachable. The fourth, DECEPTIVE(ii), is unreachable in
#  this language, and that IS the finding — the gate asserts the count is 0 over 7 real μ-equal pairs, so
#  it is a measured result and not a missing fixture.
host substitution.la sb
want sb "SUBSTITUTION ⊕(BEING,LOVE) := ⊕(LOVE,BEING) → ADMISSIBLE ontoetymological navigation" substitution  #@ turns-red: red:sb_m2,sb_m3
want sb "⊂(BEING,LOVE) := ⊂(LOVE,BEING) → DECEPTIVE(i) meaning differs" substitution  #@ turns-red: red:sb_m1,sb_m3
want sb "↻↻(RECOGNITION) := ↻(RECOGNITION) → ADMISSIBLE ontoetymological navigation" substitution  #@ turns-red: construction:↻↻≡↻ (F4)
want sb "⊕(BEING,LOVE) := itself → IDENTITY (no substitution)" substitution  #@ turns-red: red:sb_m2
want sb "SUBSTITUTION the three REACHABLE verdicts are pairwise distinct:T" substitution  #@ turns-red: entailed:sb.1,sb.2,sb.4
want sb "structural search over 39 probes: pairs with μ EQUAL=7 of those with invariants INCONGRUENT (clause ii alone)=0 | clause (ii) never fires independently of (i):T" substitution  #@ turns-red: exact:captured
sed 's|^glyph MU  = la f. NORMK(f)|glyph MU  = la f. ""|' substitution.la > "$T/sb_m1.la"; host "$T/sb_m1.la" sb_m1
red sb_m1 "⊂(BEING,LOVE) := ⊂(LOVE,BEING) → DECEPTIVE(ii) invariants not congruent" "substitution: clause (ii) is LIVE CODE and CAN fire — with μ disabled the invariant clause catches the deceptive substitution, so the branch is reachable, not dead"
sed 's|IF(str_eq(CANON(gR))(CANON(ge)))|IF(TRUE)|' substitution.la > "$T/sb_m2.la"; host "$T/sb_m2.la" sb_m2
red sb_m2 "⊕(BEING,LOVE) := ⊕(LOVE,BEING) → IDENTITY (no substitution)" "substitution RED(raw-form comparison dropped: a genuine navigation is misreported as IDENTITY, so the instrument stops noticing a substitution happened at all)"
# ★ m1 above is NOT a "the test broke" mutant and was RE-LABELLED after it ran: disabling μ does NOT make
#   the test unsafe, because clause (ii) catches the substitution instead. That is worth gating in its own
#   right — it proves clause (ii) is implemented and reachable rather than dead code, which is exactly the
#   doubt the module's own finding ("clause (ii) never fires independently of (i)") would otherwise invite.
#   The genuine stops-sanitizing path needs BOTH clauses disabled, which is m3:
sed -e 's|^glyph MU  = la f. NORMK(f)|glyph MU  = la f. ""|' -e 's|^glyph INV_CONG = la a. la b. .*|glyph INV_CONG = la a. la b. TRUE|' substitution.la > "$T/sb_m3.la"; host "$T/sb_m3.la" sb_m3
red sb_m3 "⊂(BEING,LOVE) := ⊂(LOVE,BEING) → ADMISSIBLE" "substitution RED(both clauses disabled: a meaning-changing substitution reads admissible and the test sanitizes nothing)"

# ═══ 38. ontosemiosyntax — the OSS stratum, gated rather than doctrinal (CODEX_ARCHE §8θ.4–§8θ.6) ═══
#  ✔ RAN GREEN 2026-09-17 (first execution). The 35/35 counts and both fixture
#  verdicts were derived by an independent python pass BEFORE this section was written.
#  ★ Erik's line was "gate each stratum as a module with a RED path, OR DEMOTE THE CLAIM". This gates it.
#  ★ Note the SECOND fixture: without it the Being=Meaning clause could be deleted and everything would
#  still pass. A conjunction whose second half never decides anything is one gate wearing two names.
host ontosemiosyntax.la os
want os "ONTOSEMIOSYNTAX catalogue=35 Being=Form 35/35 Being=Meaning 35/35 stratum holds:T" ontosemiosyntax  #@ turns-red: construction:AUTO_OK of seals: Being=Form 35/35 (F32)
want os "liar MONO(\"LIE\")(κ) refused:T clause=FORM≠BEING" ontosemiosyntax  #@ turns-red: red:os_m1
want os "non-normal ⊕(LOVE,BEING) sealed — Being=Form:T but refused:T clause=BEING≠MEANING" ontosemiosyntax  #@ turns-red: red:os_m2
want os "self-application: G_OSS=⊗(BEING,⊗(RECOGNITION,FORM)) OSS(G_OSS):T" ontosemiosyntax  #@ turns-red: exact:captured
sed 's|^glyph OSS_BF = la g. str_eq(OSS_BEING(g))(OSS_FORM(g))|glyph OSS_BF = la g. TRUE|' ontosemiosyntax.la > "$T/os_m1.la"; host "$T/os_m1.la" os_m1
red os_m1 "liar MONO(\"LIE\")(κ) refused:F" "ontosemiosyntax RED(Being=Form made constant-true: the liar passes and the stratum stops distinguishing a literal surface from a canonical one)"
sed 's|^glyph OSS_BM = la g. str_eq(OSS_BEING(g))(OSS_MEANING(g))|glyph OSS_BM = la g. TRUE|' ontosemiosyntax.la > "$T/os_m2.la"; host "$T/os_m2.la" os_m2
red os_m2 "but refused:F" "ontosemiosyntax RED(Being=Meaning made constant-true: the non-normal glyph passes, which is exactly the clause that would otherwise be decoration)"

# ═══ 39. autocompress — Δ_ν, meta-ontoneologization as one standing movement ═══
#  ✔ RAN GREEN 2026-09-17 (first execution). The run length, both directions of the
#  fixed point, and the 18→22 node law were derived by an independent python pass BEFORE this was written.
#  ★ The fixed point gated here is deliberately NOT ↻↻g≡↻g. That identity is true of EVERY glyph, so no
#  input makes it RED; branchclosure.la ruled the class vacuous and this is the third time it is declined.
#  What is gated is two-sided: the FIRST application must move the form, the SECOND must not. A law
#  asserting only the second is satisfied by an operator that does nothing, and mutant 1 is exactly that.
host autocompress.la dn
want dn "AUTOCOMPRESS Δ_ν run=5 movements → 1 | first application MOVES the form:T | second application moves NOTHING (the fixed point):T | reached after exactly ONE application:T" autocompress  #@ turns-red: red:dn_m1,dn_m2; construction:the fixed point is the fold base case (F32)
want dn "AUTOCOMPRESS a run ALREADY of length 1 is NOT moved:T" autocompress  #@ turns-red: construction:the fold base case DNU([x])=x (F32)
want dn "node cost: run DAG=18 → compressed DAG=22 delta=4 = one join per collapse:T" autocompress  #@ turns-red: exact:captured
sed 's|^glyph DNU = Z(la self. la run. .*|glyph DNU = la run. run(PRIM("VOID"))(la h. la t. h)|' autocompress.la > "$T/dn_m1.la"; host "$T/dn_m1.la" dn_m1
red dn_m1 "first application MOVES the form:F" "autocompress RED(fold returns the head: nothing is compressed, yet a one-sided fixed-point law would still have read green — this is the do-nothing operator)"
sed 's|(la h. la t. t(h)(la h2. la t2. self(CONSc(SYN(h)(h2))(t2))))|(la h. la t. t(MC(h))(la h2. la t2. self(CONSc(SYN(h)(h2))(t2))))|' autocompress.la > "$T/dn_m2.la"; host "$T/dn_m2.la" dn_m2
red dn_m2 "second application moves NOTHING (the fixed point):F" "autocompress RED(length-one base case wraps anyway: the movement never comes to a stand and there is no fixed point)"

# ═══ 40. phonometa — the metacursive phonosemantic-topology level ═══
#  ✔ RAN GREEN 2026-09-17 (first execution). All peak counts and verdicts were
#  derived by an independent python re-implementation of psc.la's list semantics BEFORE this was written.
#  ★ AND THE READING OF THE DEPENDENCY IS CROSS-CHECKED, not assumed: the module recomputes build.sh's own
#  pinned psc witness (build.sh:1583 "LRd|300,870,2240,270,2300,3000,|dur=6720|i"). If this module's
#  reading of psc.la's semantics were wrong, that line goes RED instead of passing quietly. psc.la is
#  GENERATED by specpipe.la and is READ here, never edited.
#  ★ (1) and (3) are TWO-SIDED on purpose: idempotence alone is satisfied by the identity function, so
#  "it stands" is only a law when paired with "it moved first".
host phonometa.la pm
want pm "PHONOMETA (1) Θ_P two-sided: raw peaks=6 → Θ_P peaks=3 it MOVED:T and then STANDS (idempotent):T" phonometa  #@ turns-red: red:pm_m1
want pm "(2) the level is CLOSED one step up: SYN_INV(SYN_INV(a)(b))(c) = SYN_INV(a)(SYN_INV(b)(c)):T peaks=9" phonometa  #@ turns-red: construction:union is associative (F32)
want pm "(3) METACURSIVE FIXED POINT SYN_INV(a)(a)=Θ_P(a):T" phonometa  #@ turns-red: red:pm_m1
want pm "(4) constituent law survives: LOVE⊆:T REC⊆:T non-constituent DEPTH⊆:F" phonometa  #@ turns-red: red:pm_m2; construction:constituents ⊆ their union (F32)
want pm "the mode is NOT recoverable from the phonetic invariant ALONE: with psc.la's prepended label the strings differ:T but bare invariants differ:F" phonometa  #@ turns-red: cannot-fail:F28 (PM_MODE_BARE compares X with X)
want pm "pinned witness: LRd|300,870,2240,270,2300,3000,|dur=6720|i matches:T" phonometa  #@ turns-red: exact:cross-checked against build.sh psc pin
sed 's|^glyph PM_THETA = THETA_P|glyph PM_THETA = la l. l|' phonometa.la > "$T/pm_m1.la"; host "$T/pm_m1.la" pm_m1
red pm_m1 "it MOVED:F" "phonometa RED(Θ_P made the identity: it removes nothing, so the two-sided law fails — a one-sided idempotence law would still have read green here)"
red pm_m1 "METACURSIVE FIXED POINT SYN_INV(a)(a)=Θ_P(a):F" "phonometa RED(Θ_P made the identity: the level no longer comes to a stand)"
sed 's|^glyph PM_SUB   = PRESERVES|glyph PM_SUB   = la parent. la comp. TRUE|' phonometa.la > "$T/pm_m2.la"; host "$T/pm_m2.la" pm_m2
red pm_m2 "non-constituent DEPTH⊆:T" "phonometa RED(containment made constant-true: psc.la's own non-constituent control reads as preserved and the constituent law stops discriminating)"

# ═══ 41. identity — the identity relation itself, as a glyph in 𝓜 ═══
#  ✔ RAN GREEN 2026-09-17 (first execution). Built to answer Erik's objection: if ≡ collapses sign and
#  referent at every level you get merger drift, and what you have built is a monism, not a reconciliation.
#  𝓜 had glyphs for the modes, 𝔑, κ, 𝓡 and ∂δγρ𝔄 — but none for the identity relation, and the DISTINCTION
#  side was expressible only as the negation of a positive test. Three glyphs close that, all collision-clear.
#  ★ ROW 1 IS THE WHOLE ARGUMENT: a pair IDENTICAL AT GROUND and DISTINCT AT LOCUS must EXIST. If none did,
#  the distinction would be idle and the language would be a monism in fact whatever its prose said.
#  ★★ THE TWO RED PATHS ARE THE TWO FAILURE MODES BY NAME, and the gate builds each and refuses it.
host identity.la id
want id "IDENTITY 𝓜 gains three glyphs — ≡@ground=▷(RECOGNITION,BEING) ≢@locus=▷(RECOGNITION,⊂(FORM,BEING)) | the relation ITSELF (their ⊗ dyad)=⊗(▷(RECOGNITION,BEING),▷(RECOGNITION,⊂(FORM,BEING)))" identity  #@ turns-red: exact:s41
want id "IDENTITY row1 ⊕(BEING,LOVE) vs ⊕(LOVE,BEING): ground≡:T locus≢:T → NON-SEPARATE AND NON-MERGED" identity  #@ turns-red: red:id_m1,id_m2
want id "row2 ⊕(BEING,LOVE) vs itself: ground≡:T locus≢:F → MERGED (one locus) | row3 ⊂(BEING,LOVE) vs ⊂(LOVE,BEING): ground≡:F locus≢:T → SEPARATE (two beings) | all three verdicts distinct:T" identity  #@ turns-red: red:id_m1,id_m2
want id "the two aspects do NOT collapse into each other: ground≡(≡,≢):F (must be F) | the dyad differs from both:T | and RECOVERS both as proper sub-forms (one compressive movement, parents retained):T" identity  #@ turns-red: exact:s41
sed 's|^glyph REL_LOCUS  = la a. la b. NOT(str_eq(CANON(a))(CANON(b)))|glyph REL_LOCUS  = la a. la b. FALSE|' identity.la > "$T/id_m1.la"; host "$T/id_m1.la" id_m1
red id_m1 "row1 ⊕(BEING,LOVE) vs ⊕(LOVE,BEING): ground≡:T locus≢:F → MERGED (one locus)" "identity RED(MONISM: locus distinction made constant-false — the load-bearing row collapses to MERGED, the mirror becomes the reflected)"
sed 's|^glyph REL_GROUND = la a. la b. str_eq(NORMK(a))(NORMK(b))|glyph REL_GROUND = la a. la b. str_eq(CANON(a))(CANON(b))|' identity.la > "$T/id_m2.la"; host "$T/id_m2.la" id_m2
red id_m2 "row1 ⊕(BEING,LOVE) vs ⊕(LOVE,BEING): ground≡:F locus≢:T → SEPARATE (two beings)" "identity RED(DUALISM: ground identity made canon-equality — identity holds only where the routes already match, so nothing is ever non-separate across two forms and there is no reconciliation left to make)"

# ═══ 42. compressbound — does neologization drown the etymology in noise? (Erik, 2026-09-17) ═══
#  ✔ RAN GREEN 2026-09-17. ★ The growth laws are asserted as LAWS (+1 per collapse, tree doubles) rather
#  than pinned counts, so the gate stays true if the chain is lengthened. The byte figures are computed live.
#  ★ THE ANSWER SPLITS: no noise in the computational register (DECOMP is an exact inverse of DAG, so the
#  code is uniquely decodable and recovery is EXACT at every depth — gated); the only real bound is the
#  RENDERER's channel capacity, and sigil.la walks the UNFOLDED decomposition so it inherits the exponential
#  one. ★ The Archē is the terminator: ⊗(∃,∃)→∃ makes its chain CONSTANT while every other glyph doubles.
host compressbound.la cb
want cb "COMPRESSBOUND κ chain ⊗(g,g)×5 | UNFOLDED tree: 3 7 15 31 63 127 | RETAINED hash-consed: 3 4 5 6 7 8 | tree DOUBLES:T retained grows by EXACTLY +1:T" compressbound  #@ turns-red: red:cb_m1
want cb "NO NOISE: etymology recovers EXACTLY at every depth:T | every depth κ-distinct (normalisation loses nothing either):T" compressbound  #@ turns-red: red:cb_m2
want cb "THE ARCHĒ IS THE TERMINATOR: ⊗(∃,∃)→∃ (⊗-idempotence for the Archē ALONE). meaning-string length — ∃ chain: 3 3 3 3 3 3 (constant:T) vs κ chain: 21 48 102 210 426 858 (constant:F)" compressbound  #@ turns-red: exact:s42
sed 's|^glyph CB_KEPT  = la et. NODES(CB_DAG(et))|glyph CB_KEPT  = la et. TSIZE(et)|' compressbound.la > "$T/cb_m1.la"; host "$T/cb_m1.la" cb_m1
red cb_m1 "retained grows by EXACTLY +1:F" "compressbound RED(structure sharing broken — the retained form now tracks the unfolded tree, growth stops being linear, and the compression claim is gone)"
sed 's|^glyph CB_DAG   = la et. DAG(et)|glyph CB_DAG   = la et. DAG(Px("BEING"))|' compressbound.la > "$T/cb_m2.la"; host "$T/cb_m2.la" cb_m2
red cb_m2 "recovers EXACTLY at every depth:F" "compressbound RED(the code loses the message — the channel carries a constant instead of the form, so the etymology really IS drowned and the gate says so)"
#  ⚠ The first cb_m2 (CANON vs NORMK) did NOT fire and was replaced: on this chain CANON and NORMK AGREE,
#    because ⊗-idempotence is granted to the Archē alone, so that mutant broke nothing. A mutant that does
#    not mutate is a RED path that cannot fire — it was caught by checking the mutant's actual output.

# ═══ 43. logicsyntax — the logic / algorithm / syntax collapse (Erik's Gate 1) ═══
#  ✔ RAN GREEN 2026-09-17. ★ THE RESULT SPLITS THE CLAIM: the three are PAIRWISE SEPARATE, so the strong
#  reading (logic IS algorithm IS syntax) is FALSE and this gate refuses it — but the dyad RETAINS BOTH
#  parents, so logic is not merely adjacent to them either. THE COLLAPSE IS COMPOSITIONAL, NOT
#  IDENTIFICATORY. κ and 𝓡 are CITED from canon.la, not re-declared; only LOGIC's ⊗ form is new [A].
#  ★ Erik's test, met: collapse logic→algorithm and collapse algorithm→syntax, and show what breaks. Both
#  break something, so the relation is load-bearing and the glyph is earned.
host logicsyntax.la ls
want ls "LOGICSYNTAX SYNTAX κ=▷(RECOGNITION,FORM) ALGORITHM 𝓡=▷(DEPTH,RECOGNITION) LOGIC ⊗(𝓡,κ)=⊗(▷(DEPTH,RECOGNITION),▷(RECOGNITION,FORM))" logicsyntax  #@ turns-red: exact:s43
want ls "LOGIC vs ALGORITHM: SEPARATE (two beings) | LOGIC vs SYNTAX: SEPARATE (two beings) | ALGORITHM vs SYNTAX: SEPARATE (two beings) | all three pairwise SEPARATE:T" logicsyntax  #@ turns-red: red:ls_m1,ls_m2
want ls "but the dyad RETAINS BOTH parents as proper sub-forms:T | cost of the one movement: parts 3+3 retained nodes → dyad 6" logicsyntax  #@ turns-red: red:ls_m1
want ls "VERDICT: pairwise separate AND both retained ⇒ THE COLLAPSE IS COMPOSITIONAL, NOT IDENTIFICATORY:T" logicsyntax  #@ turns-red: entailed:ls.2,ls.3; exact:s43
want ls "THE POSITIVE RELATION: §41's identity dyad is a NEOLOGIZING DYAD:T and so is LOGIC:T → SAME STRUCTURE:T | the check discriminates — a ⊂-dyad over the same parents:F a parent-dropping ⊗:F" logicsyntax  #@ turns-red: red:ls_m3
sed 's|(AND(ID_IN(NORMK(l))(ID_SUBS(f)))(ID_IN(NORMK(r))(ID_SUBS(f))))|(TRUE)|' logicsyntax.la > "$T/ls_m3.la"; host "$T/ls_m3.la" ls_m3
red ls_m3 "a parent-dropping ⊗:T" "logicsyntax RED(the RETENTION clause dropped: a dyad of one parent with itself passes as a neologizing dyad — retention is the clause that is independently load-bearing here, since a ⊂-candidate already fails on it too)"
sed 's|^glyph LS_LOGIC     = SYN(LS_ALGORITHM)(LS_SYNTAX)|glyph LS_LOGIC     = LS_ALGORITHM|' logicsyntax.la > "$T/ls_m1.la"; host "$T/ls_m1.la" ls_m1
red ls_m1 "LOGIC vs ALGORITHM: MERGED (one locus)" "logicsyntax RED(logic collapsed INTO algorithm: the pair merges)"
red ls_m1 "RETAINS BOTH parents as proper sub-forms:F" "logicsyntax RED(logic collapsed into algorithm: syntax is no longer recoverable, so the one-movement-retains-both claim fails too)"
sed 's|^glyph LS_ALGORITHM = REVAL|glyph LS_ALGORITHM = KAPPA|' logicsyntax.la > "$T/ls_m2.la"; host "$T/ls_m2.la" ls_m2
red ls_m2 "ALGORITHM vs SYNTAX: MERGED (one locus)" "logicsyntax RED(algorithm collapsed into syntax: the three-fold degenerates and pairwise separateness fails — canon.la's own 𝓡 ≢ κ meta-monosemy is what this protects)"

# ═══ 44. lawroot — are the Three Laws derived from the Archē? (Erik's Gate 2) ═══
#  ✔ RAN GREEN 2026-09-17. ★★ THE ANSWER IS NO, AND THE METHOD IS REMOVAL: if a conclusion survives the
#  deletion of its putative premise, it was never derived from it. The Archē rewrite ∃(∃)→∃ (metalogic's
#  GROUND) is replaced by the identity function and every law is recomputed — all three verdicts are
#  IDENTICAL (signature TFTT either way). ★ And the test is NOT vacuous: the CONTROL shows the rewrite IS
#  load-bearing where it applies (TRIBAR(∃(∃))(∃) is T with it, F without), so removal removes something.
#  ⇒ THE THREE LAWS ARE PRIMITIVE WITH RESPECT TO THE ARCHĒ. They are not assumed — each is falsifiable and
#  each is wired to a real mechanism (AUTO_OK, the type checker, well-formedness) — but the corpus's
#  "derived from ∃(∃)≡∃, not assumed" (OUTLINE.md §19.4) is NOT what the code does. Per Erik's ruling:
#  state it and stop tagging them as derived. Consistent with derive_closure.la (4 of 9 derive, 5 axioms).
host lawroot.la lr
want lr "LAWROOT each law is FALSIFIABLE — identity T on its witness:T F on a ren that is not its etymology:T | non-contradiction T:T F on an arity contradiction:T | excluded middle T:T F on a term with no form:T" lawroot  #@ turns-red: fixture:each law reads F on a bad term
want lr "CONTROL — the Archē rewrite ∃(∃)→∃ IS load-bearing where it applies: TRIBAR(∃(∃))(∃) with it:T without it:F → removal really removes something:T" lawroot  #@ turns-red: red:lr_m1,lr_m2
want lr "INDEPENDENCE — all three law-verdicts are IDENTICAL with the Archē rewrite present and DELETED:T signature on:TFTT off:TFTT" lawroot  #@ turns-red: red:lr_m1; construction:LR_SIG never uses its GROUND argument, so on and off agree by construction — the claim is witnessed by lrs below (F25)
#  ★ F25's REAL WITNESS (FREEZE-TRACKF.md F25, 2026-09-18). The runtime removal test above cannot remove anything: LR_SIG
#    ignores the GROUND it is handed, and the laws, defined in metalogic.la, name no GROUND parameter to rebind. What the
#    claim means in LA is a fact about the REFERENCE GRAPH — no law reaches, through any chain of glyph references, a
#    glyph that applies an Archē rewrite — and if none does, deleting the rewrite changes no law, which is the removal
#    test done where it can bite. derive/lawreach.py computes that closure over lawroot.la's whole import closure,
#    sound for absence (same-named glyphs take the UNION of their bodies). RED: two mutants of metalogic.la route a law
#    through the Archē (LAW_EXCLUDED_MIDDLE via TRIBAR; LAW_IDENTITY via GROUND), fed in with --swap, and the offender
#    must be NAMED with its path. [B] the implemented laws vs the implemented rewrites — a route the code lacks is not refuted.
static lrs derive/lawreach.py lawroot.la
want lrs "LAWREACH no law reaches an Archē rewrite:T" lawroot  #@ turns-red: red:lrs_m1,lrs_m2
want lrs "laws checked: LAW_IDENTITY LAW_NONCONTRADICTION LAW_EXCLUDED_MIDDLE" lawroot  #@ turns-red: red:lrs_m3
sed 's|^glyph LAW_EXCLUDED_MIDDLE = la term. WELLFORMED(term)$|glyph LAW_EXCLUDED_MIDDLE = la term. TRIBAR(term)(term)|' metalogic.la > "$T/lrs1_mut.la"; static lrs_m1 derive/lawreach.py lawroot.la --swap metalogic.la="$T/lrs1_mut.la"
red lrs_m1 "no law reaches an Archē rewrite:F" "lawroot RED(excluded middle made to decide through TRIBAR: the reach check sees the law now consults the Archē)"
red lrs_m1 "LAW_EXCLUDED_MIDDLE reaches GROUND via LAW_EXCLUDED_MIDDLE -> TRIBAR -> GROUND" "lawroot RED(… and NAMES the offender with its whole path, two references deep)"
sed 's|^glyph LAW_IDENTITY = la g. AUTO_OK(g)$|glyph LAW_IDENTITY = la g. str_eq(GROUND(REN(g)))(REN(g))|' metalogic.la > "$T/lrs2_mut.la"; static lrs_m2 derive/lawreach.py lawroot.la --swap metalogic.la="$T/lrs2_mut.la"
red lrs_m2 "no law reaches an Archē rewrite:F" "lawroot RED(identity made to ground its name through the Archē rewrite: the verdict flips)"
red lrs_m2 "LAW_IDENTITY reaches GROUND via LAW_IDENTITY -> GROUND" "lawroot RED(… and the offender is named, one reference deep)"
sed 's|^glyph LAW_NONCONTRADICTION = |glyph LAW_NC_RENAMED = |' metalogic.la > "$T/lrs3_mut.la"; static lrs_m3 derive/lawreach.py lawroot.la --swap metalogic.la="$T/lrs3_mut.la"
red lrs_m3 "ERROR: law(s) not defined in the import closure of lawroot.la: LAW_NONCONTRADICTION" "lawroot RED(a law vanishes from the closure: the check REFUSES instead of reporting none for the two it can still see — absence must prove it looked)"
want lr "THE CRITERION, one level down — AUTO_OK on a glyph sealed over ⊗(∃,∃): CANON-based (the real criterion):T an Archē-AWARE variant (which would require the ren to be ∃):F — they DISAGREE, so the criterion demonstrably does NOT consult the Archē:T" lawroot  #@ turns-red: construction:AUTO_OK uses CANON, so it cannot consult the Archē — by definition (F32)
#  ★★★ Erik's follow-up, answered: the AUTOLOGICAL CRITERION is CO-PRIMITIVE with the Archē too, not
#    derived from it. So the Archē, the three laws and the criterion are FOUR INDEPENDENT GROUNDS —
#    THE GROUND IS A SMALL SET, NOT A SINGLE POINT. Consistent with derive_closure.la (4 of 9 derive,
#    5 are named axioms). The framework's "one ground" should be restated as "a small ground-set".
sed 's|^glyph LR_SIG = la g. concat(|glyph LR_SIG = la g. concat(LR_B(LR_TRIBAR(g)(LR_AA)(LR_A)))(concat(|; s|(LAW_EXCLUDED_MIDDLE(TERM("∃")("v"))))))$|(LAW_EXCLUDED_MIDDLE(TERM("∃")("v")))))))|' lawroot.la > "$T/lr_m1.la"; host "$T/lr_m1.la" lr_m1
red lr_m1 "IDENTICAL with the Archē rewrite present and DELETED:F" "lawroot RED(a law MADE to depend on the Archē: independence goes F — which is what shows the test can DETECT a dependence rather than always reporting none)"
sed 's|^glyph LR_GROUND_ON  = la s. GROUND(s)|glyph LR_GROUND_ON  = la s. s|' lawroot.la > "$T/lr_m2.la"; host "$T/lr_m2.la" lr_m2
red lr_m2 "TRIBAR(∃(∃))(∃) with it:F" "lawroot RED(the control removed: the rewrite reads idle, so the whole removal test would be vacuous — this is the guard on the guard)"

# ═══ 45. archeunique — ⊗-idempotence belongs to the Archē ALONE (Erik's Gate 4) ═══
#  ✔ RAN GREEN 2026-09-17. TWO halves, because a one-sided version proves nothing: the Archē IS
#  ⊗-idempotent, AND the count of ordinary glyphs that are is ZERO of 16 (the nine primitives, κ, 𝓡, and
#  the five mode glyphs). Half (1) alone would pass if everything were idempotent; half (2) alone if
#  nothing were. This is the ruling `compressbound.la` §42 leans on when it calls ∃ the terminator.
#  ⚠ (3) ADDED 2026-09-18 — WRITTEN + DERIVED, NOT YET RUN: the codex's Contradiction(C)=C (Llogoscribeologiae
#  12987), C = Love ∧ Bad in prop.la's own ¬/∧, must NOT be ⊗-idempotent. Expected values derived in python first.
host archeunique.la ti
want ti "ARCHEUNIQUE (1) the Archē IS ⊗-idempotent — ⊗(∃,∃)≡∃:T | (2) ordinary glyphs that are ⊗-idempotent: 0 of 16 — must be ZERO:T" archeunique  #@ turns-red: red:ti_m1,ti_m2
want ti "BOTH halves together: the uniqueness is EARNED:T" archeunique  #@ turns-red: entailed:ti.1
want ti "C = p∧¬p with p=LOVE (Love ∧ Bad): ⊕(LOVE,⊂(LOVE,VOID)) | ⊗(C,C)≡C:F" archeunique  #@ turns-red: red:ti_m1
#  (3) drift guard: the fixture copies prop.la's ¬ and ∧ locally (a mutant cannot shadow an import), so the
#  gate REFUSES if prop.la's definitions move and the copy would silently test a stale logic.
grep -qxF 'glyph PNOT = la p. CONT(p)(VOIDP)' prop.la && grep -qxF 'glyph PAND = la p. la q. CON(p)(q)' prop.la || { echo "FAIL  registers/archeunique: prop.la's PNOT/PAND changed — the (3) contradiction fixture copies them and must be re-derived"; ok=0; }
sed 's|^glyph TI_IDEM = la f. str_eq(TI_NORM(SYN(f)(f)))(TI_NORM(f))|glyph TI_IDEM = la f. str_eq(TI_NORM(f))(TI_NORM(f))|' archeunique.la > "$T/ti_m1.la"; host "$T/ti_m1.la" ti_m1
red ti_m1 "ordinary glyphs that are ⊗-idempotent: 16 of 16 — must be ZERO:F" "archeunique RED(the test made to compare a form with ITSELF: every ordinary glyph reads idempotent and the Archē's uniqueness collapses)"
red ti_m1 "p=LOVE (Love ∧ Bad): ⊕(LOVE,⊂(LOVE,VOID)) | ⊗(C,C)≡C:T" "archeunique RED(the same mutant turns the contradiction line T: (3) goes through the live idempotence test, not a constant)"
sed 's|^glyph TI_ARCHE = TI_IDEM(Px("∃"))|glyph TI_ARCHE = TI_IDEM(Px("BEING"))|' archeunique.la > "$T/ti_m2.la"; host "$T/ti_m2.la" ti_m2
red ti_m2 "the Archē IS ⊗-idempotent — ⊗(∃,∃)≡∃:F" "archeunique RED(the positive half broken: the gate cannot pass merely by finding idempotence nowhere)"

# ═══ 46. crossbranch — the cross-branch compression collapse, κ_B ≡ κ_B' (Erik's cross-branch gate) ═══
#  ✔ RAN GREEN 2026-09-17, but the VERDICT IS [B], NOT [W], and two premises of the request FAILED:
#  (i) there are NOT 28 branches — branchgenesis gates base=18, set=19 with Δ_B, and the other names in
#      that file are its six REFUSAL FIXTURES. Liminal and Anamnetic (two of the six dimensions the
#      request requires) do NOT EXIST anywhere in the tree and are BLOCKED on a definition not on disk.
#  (ii) there is ONE sealer (branchgenesis.la:121 `SEALc`), so the collapse is true BY CONSTRUCTION, not
#      by convergence. Saying "all 18 agree" without saying that would be a vacuous green.
#  ★ What makes it a real gate is the two in-file FIXTURES, both firing on every run: compression by
#  CONVENTION (a stipulated ren — not canonicalizable, named) and compression by DELETION (▷ drops a
#  parent instead of ⊗ merging — κ-distinct). Without them the 153 agreeing pairs would mean nothing.
host crossbranch.la xb
want xb "CROSSBRANCH branches BUILT=18" crossbranch  #@ turns-red: exact:s46
want xb "κ-IDENTICAL pairs: 153 DIFFERING pairs: 0 | all pairs collapse:T" crossbranch  #@ turns-red: exact:s46; construction:all 18 branches are assigned ONE operation (F32)
want xb "PATH A (compression by CONVENTION — a stipulated ren, not a structural operation): extractable:F (must be F) OFFENDER=FIXTURE-convention" crossbranch  #@ turns-red: red:xb_m1
want xb "PATH B (compression by DELETION — ▷ drops a parent instead of ⊗ merging): κ form=⊗(BECOMING,RELATION) vs merging branches’ ▷(LOVE,RELATION) differs:T" crossbranch  #@ turns-red: red:xb_m2
sed 's|^glyph XB_EXTRACT = la g. IF(AUTO_OK(g))(la _. NORMK(ETYM(g)))(la _. "")|glyph XB_EXTRACT = la g. NORMK(ETYM(g))|' crossbranch.la > "$T/xb_m1.la"; host "$T/xb_m1.la" xb_m1
red xb_m1 "extractable:T (must be F)" "crossbranch RED(the canonicalizability check dropped: a branch whose compression is a mere CONVENTION is accepted as a structural operation, and Path A stops firing)"
sed 's|^glyph XB_DELETE = MONO(CANON(MODE_DIR_F))(MODE_DIR_F)|glyph XB_DELETE = MONO(CANON(MODE_SYN_F))(MODE_SYN_F)|' crossbranch.la > "$T/xb_m2.la"; host "$T/xb_m2.la" xb_m2
red xb_m2 "differs:F" "crossbranch RED(the deletion fixture made a merge: the comparison can no longer distinguish two genuinely different compression operations, and the 153 agreeing pairs become unfalsifiable)"

# ═══ 47. numderive — number from the nine, the 2^(d+2)−1 formula, the non-injectivity bound (Gate 3) ═══
#  ✔ RAN GREEN 2026-09-17. One is BECOMING(VOID): unity is DERIVED, not posited. ⚖ F26 (2026-09-18): the 09-17
#  text "BEING IS NOT ONE" was printed, not gated. By Erik's F5 ruling (η is identity in TRUTH only) the two
#  registers disagree and each is now gated: FORM — BEING = λself.self and one = nf(BECOMING(VOID)) = λf.λx.f(x)
#  are distinct β-normal terms (`lf`, derive/lamform.py over primitives.la); TRUTH — they are η-equal (`lf`), and
#  in the module BEING decodes to 1 and agrees with one on a probe (`nd`). All nd tokens derived: derive/s47.
#  ★ zero and the successor are CITED and READ BACK from primitives.la, because importing primitives
#  beside canon would COLLIDE on `DEPTH` (both export it, with different meanings).
#  ★★ THE BOUND IS EXHIBITED, NOT ASSERTED: four κ-distinct forms share one numeral, so the mode is
#  invisible to the count — size is a homomorphic image that forgets it.
host numderive.la nd
want nd "NUMDERIVE (1) zero=VOID, successor=BECOMING, both read back from primitives.la:T | numerals GENERATED by iterating the successor on zero: 0 1 2 3 4 5 — decode correctly 0..5:T" numderive  #@ turns-red: red:nd_m1; exact:s47
want nd "one = BECOMING(VOID) decodes to 1:T" numderive  #@ turns-red: red:nd_m1; exact:s47
want nd "EQUAL IN TRUTH: BEING decoded as a numeral:1 one decoded:1 equal:T | applied to (s ↦ s|) and a — BEING:a| one:a| agree:T" numderive  #@ turns-red: red:nd_m4; exact:s47
want nd "NUMDERIVE (2) the ⊗-self-collapse chain measures: 3 7 15 31 63 127 — equals 2^(d+2)−1 at depths 0..5:T" numderive  #@ turns-red: construction:tree arithmetic of a ⊗-doubling chain (F32); exact:s47
want nd "⊗(BEING,VOID) ⊕(BEING,VOID) ▷(BEING,VOID) ⊂(BEING,VOID) are pairwise κ-DISTINCT:T yet all four measure 3 — four forms, ONE numeral:T" numderive  #@ turns-red: red:nd_m2; construction:the numeral IS tree size (F32); exact:s47
want nd "THE BLINDNESS IS INHERITED — a glyph built from the NUMERAL alone collapses all four probes to ONE:T while the κ-seal of the same four keeps them FOUR:T → the loss is the NUMERAL's, not the sealing's:T" numderive  #@ turns-red: red:nd_m3; construction:a size-only seal collapses equal sizes (F32); exact:s47
sed 's|^glyph ND_NSEAL = la f. NORMK(ND_NFORM(TSIZE(f)))|glyph ND_NSEAL = la f. concat(NORMK(f))(NORMK(ND_NFORM(TSIZE(f))))|' numderive.la > "$T/nd_m3.la"; host "$T/nd_m3.la" nd_m3
red nd_m3 "collapses all four probes to ONE:F" "numderive RED(the numeric seal made to carry the form as well: the four stop collapsing, which is what shows the gate DETECTS the inherited blindness rather than always reporting it)"
#  ★ NAMED: THE MEASURE HORIZON — arithmetic's reach stops where the mode begins. Anything downstream of
#    a numeral inherits it: measure can say HOW BIG a form is and never WHICH form it is. [W] a property
#    of the projection, not a defect.
sed 's|^glyph ND_SUCC = la n. la f. la x. f(n(f)(x))|glyph ND_SUCC = la n. n|' numderive.la > "$T/nd_m1.la"; host "$T/nd_m1.la" nd_m1
red nd_m1 "iterating the successor on zero: 0 0 0 0 0 0" "numderive RED(the successor made the identity: the numerals stop counting and the derivation of number fails)"
red nd_m1 "one = BECOMING(VOID) decodes to 1:F" "numderive RED(… and one is no longer derived: BECOMING(VOID) decodes to zero)"
sed 's|^glyph ND_BEING = la self. self|glyph ND_BEING = la f. la x. f(f(x))|' numderive.la > "$T/nd_m4.la"; host "$T/nd_m4.la" nd_m4
red nd_m4 "BEING decoded as a numeral:2 one decoded:1 equal:F" "numderive RED(BEING made Church two: the truth-register equality with one breaks on the numeral decode)"
red nd_m4 "BEING:a|| one:a| agree:F" "numderive RED(… and on the extensional probe — the witness reads BEING's actual behaviour, not a label)"
#  ★ F26's FORM register, STATIC (no tiny_host): lamform.py reads BEING, VOID and BECOMING from primitives.la, COMPUTES
#    one as the β-normal form of BECOMING(VOID), and compares β-normal forms up to α (FORM) and βη-normal forms (TRUTH).
#    Worked by hand in its docstring first. It refuses (rc 2) a missing or non-λ definition and a term with no normal form.
static lf derive/lamform.py primitives.la
want lf "LAMFORM ONE = the β-normal form of BECOMING(VOID) = la f. la x. f(x)" numderive  #@ turns-red: red:lf_m2
want lf "FORM register (β-normal, up to α; η NOT applied) — BEING and ONE are the same term:F" numderive  #@ turns-red: red:lf_m1
want lf "TRUTH register (βη-normal, up to α) — BEING and ONE are the same term:T" numderive  #@ turns-red: red:lf_m2
sed 's|^glyph BEING = la self. self$|glyph BEING = la f. la x. f(x)|' primitives.la > "$T/lf1_mut.la"; static lf_m1 derive/lamform.py "$T/lf1_mut.la"
red lf_m1 "FORM register (β-normal, up to α; η NOT applied) — BEING and ONE are the same term:T" "numderive/lamform RED(BEING redefined as Church one: the FORM register must now read the two as the same term)"
sed 's|^glyph BECOMING = la n. la f. la x. f(n(f)(x))$|glyph BECOMING = la n. la f. la x. f(f(n(f)(x)))|' primitives.la > "$T/lf2_mut.la"; static lf_m2 derive/lamform.py "$T/lf2_mut.la"
red lf_m2 "TRUTH register (βη-normal, up to α) — BEING and ONE are the same term:F" "numderive/lamform RED(the successor made to add two: one is computed, not typed in, so the TRUTH equality breaks)"
red lf_m2 "ONE = the β-normal form of BECOMING(VOID) = la f. la x. f(f(x))" "numderive/lamform RED(… and the computed normal form NAMES what changed)"
sed 's|^glyph P2 = CON(Px("BEING"))(Px("VOID"))|glyph P2 = SYN(Px("BEING"))(Px("VOID"))|' numderive.la > "$T/nd_m2.la"; host "$T/nd_m2.la" nd_m2
red nd_m2 "are pairwise κ-DISTINCT:F" "numderive RED(two probes made κ-identical: the exhibit stops exhibiting — a demonstration that distinct forms share a numeral must use forms that are genuinely distinct)"

# ═══ 48. divergent — do genuinely different compressions converge on κ? NO. (Erik's cross-branch option B) ═══
#  ✔ RAN GREEN 2026-09-17. §46 found the cross-branch collapse true BY CONSTRUCTION (18 branches calling
#  one sealer); Erik chose to build the divergent branches that could earn the interesting claim instead.
#  ★★ THE ANSWER IS NEGATIVE, in three parts: six constructed compressions give SIX DISTINCT κ-outputs on
#  the same parents; under iteration FIVE OF SIX NEVER REACH A FIXED POINT; and the ONE that does is
#  DELETION, which rests only by throwing the second parent away.
#  ⇒ THE COLLAPSE IS BOUNDED TO THE SEALER, and §46's [B] is principled rather than incidental.
#  ★★★ THE DEEPER RESULT: CONVERGENCE AND RETENTION ARE IN TENSION — every operation that RETAINS both
#  parents fails to come to rest; the only one that rests DISCARDS. §42 measured why: retention costs +1
#  node per collapse, forever. Rest is bought with loss.
#  ★ The CONTROL keeps (2) from being an artefact: the sealer is NOT fixed-point-free — it rests at the
#  Archē, which §45 gates as ∃'s alone.
host divergent.la dv
want dv "DIVERGENT six constructed compressions over one parent pair — distinct κ-outputs: 6 of 6 — NO agreement at the output level:T" divergent  #@ turns-red: red:dv_m2
want dv "reach a FIXED POINT: 1 of 6 | the ONLY one that comes to rest is DELETION ★ and it rests by THROWING THE SECOND PARENT AWAY:T" divergent  #@ turns-red: red:dv_m1
want dv "CONTROL — the sealer is NOT fixed-point-free: ⊗(∃,∃)→∃ rests at the Archē:T" divergent  #@ turns-red: exact:s48
sed 's|^glyph DV_STABLE = la op. NOT(str_eq(DV_FIX(op))(""))|glyph DV_STABLE = la op. TRUE|' divergent.la > "$T/dv_m1.la"; host "$T/dv_m1.la" dv_m1
red dv_m1 "reach a FIXED POINT: 6 of 6" "divergent RED(the fixed-point detector made constant-true: everything 'stabilises' and the whole finding evaporates)"
sed 's|CONSc(PAIRc("SWAP")(la a. la b. SYN(b)(a)))|CONSc(PAIRc("SWAP")(la a. la b. SYN(a)(b)))|' divergent.la > "$T/dv_m2.la"; host "$T/dv_m2.la" dv_m2
red dv_m2 "distinct κ-outputs: 5 of 6 — NO agreement at the output level:F" "divergent RED(two operations made identical: the distinct-output count drops, which is what shows the test counts real divergence and not six names)"

# ═══ 49. adequacy — the identity-adequacy rulings: eight one-κ-two-name overloads, resolved ═══
#  ✔ RAN GREEN 2026-09-17. ★★ FIRST, A CORRECTION: the three pairs Erik named (Change=Can, Give=Because,
#  Know=You) DO NOT COLLIDE — they differ in operand order or in mode, and monosemy_test.la:31 cites
#  tex:2837 that ontosynthesis is NON-COMMUTATIVE. Ruling them identical would have DESTROYED three
#  distinctions the corpus asserts. The real overloads are eight, found by census over the published
#  vocabulary, and both names of every pair are READ BACK from source so the data is not from memory.
#  ★ One DECLARATION (Totality = All is one concept under two English words) and seven RE-DERIVATIONS,
#  each clear against the 86-form corpus (regcollide.py) and pairwise distinct. Applying all eight drives
#  the one-κ-two-name count to ZERO.
#  ★ It RULES and VERIFIES; it does NOT edit lexicon.la / opgrammar.la — the published vocabulary is the
#  architect's to apply, and this makes that application mechanical and pre-checked.
host adequacy.la ad
want ad "ADEQUACY the REAL overloads=8 | both names of every pair read back from lexicon.la + opgrammar.la:T | rulings: All=Totality Large→⊗(DEPTH,FORM) Good→⊗(BEING,LOVE) Bond→⊂(RELATION,BEING) Sky→⊂(VOID,FORM) Here→▷(FORM,RELATION) There→⊂(VOID,RELATION) Move→▷(BECOMING,FORM)" adequacy  #@ turns-red: cannot-fail:F28 (overloads=8 is a table length); exact:captured
want ad "ADEQUACY declarations=1 re-derivations=7 | every new form distinct from the others AND from all eight originals:T | resolved 8/8 — applying these drives the one-κ-two-name count to ZERO:T" adequacy  #@ turns-red: red:ad_m1
sed 's|AD_R("⊗(FORM,BEING)")("Substance")("Large")("REDERIVE")("⊗(DEPTH,FORM)")|AD_R("⊗(FORM,BEING)")("Substance")("Large")("REDERIVE")("⊗(FORM,LOVE)")|' adequacy.la > "$T/ad_m1.la"; host "$T/ad_m1.la" ad_m1
red ad_m1 "distinct from the others AND from all eight originals:F" "adequacy RED(a proposed re-derivation made to collide with an existing overloaded form: the distinctness check catches it, so a ruling cannot silently reintroduce the collision it was meant to remove)"
sed 's|AD_R("⊗(VOID,DEPTH)")("Mystery")("Sky")("REDERIVE")("⊂(VOID,FORM)")|AD_R("⊗(VOID,DEPTH)")("Mystery")("Sky")("REDERIVE")("")|' adequacy.la > "$T/ad_m2.la"; host "$T/ad_m2.la" ad_m2
red ad_m2 "resolved 7/8" "adequacy RED(a re-derivation left without a new form: the resolution count drops, so an unruled overload cannot pass as ruled)"

# ═══ 10. the table bound (directive §8): every module's import closure fits 1024 ══
for m in lineage.la prosody.la topology.la evidential.la texture.la registers.la modegenesis.la regenesis.la complement.la opposite.la textcoherence.la derive_closure.la branchgenesis.la ontoargument.la ontomorph.la gramcomplete.la neologenesis.la unified.la gapcensus.la entendre.la felicitylive.la aware.la ablateop.la wants.la protoagent.la fractal.la branchclosure.la recdepth.la selfevo.la certify.la migrate.la closure.la metakappa.la substitution.la ontosemiosyntax.la autocompress.la phonometa.la identity.la compressbound.la logicsyntax.la lawroot.la archeunique.la crossbranch.la numderive.la divergent.la adequacy.la; do
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
#  REGS_VM=0 skips · 1 (default) the 33 light modules · 2 adds the four heavy ones (list and
#  runner: vm_list / vm_leg, top of file). REGS_VM_CHUNK=k/n runs one slice ALONE — see there.
if [ "${REGS_VM:-1}" != 0 ]; then
    set -- $(vm_list)
    vm_leg "$@"
    [ "$vm_done" -eq "$#" ] || { echo "FAIL  registers/vm: compared $vm_done of the $# listed modules"; ok=0; }
fi

[ "$ok" -eq 1 ] && echo "PASS  registers: the twelve-register stack — five new registers (etymological, prosodic, topological, evidential, affective) each gated with a RED path that NAMES its offender; twelve-fold coherence (all identity-projections agree on NIS-equal glyphs, NORMTREE ≡ NORMK differentially); Δ_M and Δ_R each with four sub-gates, one fixture per letter, idempotent admission; the antonym structure (¬ from Void, ¬¬C ≠ C as glyphs and ≡ C in truth, two identities explicit, the dyadic pole as a refusing involution); every W-tag cites a gate that exists in build.sh; every import closure under the 1024-glyph table" || exit 1
