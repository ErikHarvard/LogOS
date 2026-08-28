#!/usr/bin/env bash
# xmss_signer.la — the JOIN: XMSS signing with the leaf-index guard wired in.
#
# ── WHY THIS GATE HAD TO EXIST, AND DID NOT ─────────────────────────────────
# The layer shipped three gates — wotsp, xmss, xmssidx — and NONE of them runs
# xmss_signer.la. `gate_xmssidx.sh` proves the register is correct in isolation;
# `gate_xmss.sh` proves the signature scheme is correct in isolation. Neither
# says anything about the COMBINATION, and the combination is where the actual
# danger lives: a caller that holds a correct register and then signs with an
# index of its own choosing anyway. Two green gates over two correct modules is
# not evidence about the thing built out of them.
#
# Until this file existed, the module's only result was a MANUAL run recorded in
# .signer_host.log (all six checks OK, 5581 s, 2026-08-24). A manual run is not
# a gate: nothing re-ran it, nothing could go red, and the native-VM leg was
# killed mid-codegen and never replaced. .signer_vm.log still ends at
# "secd built".
#
# ── WHAT THE MODULE CLAIMS, AND WHICH CHECK CARRIES IT ──────────────────────
#     idx0=0, idx1=1              consecutive signs took DIFFERENT leaves and
#                                 THE CALLER NAMED NEITHER — the guard's point
#     sig0 / sig1 verify vs root  many-time-ness, through the guarded path
#     sigs differ                 the two leaves produced different signatures
#     state spent=2               the register advanced durably, twice, and at
#                                 h=1 that is the whole capacity: key spent
#
# ★ "sigs differ" is WEAKER THAN ITS NAME and this gate does not pretend
# otherwise. It varies the leaf AND the message together (leaf 0/M1 vs leaf
# 1/M2), so it cannot separate them: a signer reusing one leaf for both messages
# would still produce different signatures and still pass it. What actually
# witnesses leaf independence is `idx0=0 | idx1=1` together with both signatures
# verifying against ONE root. The check is not vacuous — a signer that ignored
# its message entirely fails it, which is the chacha20 shape this project has
# already been bitten by — but it is not the leaf-independence witness.
#
# ── EXPECTED-STRING PROVENANCE (read this before editing E_SIGNER) ──────────
# ★ E_SIGNER was DERIVED by reading xmss_signer.la's own concat nesting — the
# five concat arms in RUN, in order — NOT captured from stdout. It was only
# afterwards compared against .signer_host.log's first line, which agrees. That
# order matters and is the whole difference between a gate and a rubber stamp:
# an expectation copied from observed output cannot detect a wrong observed
# output, because it IS the observed output. If this string ever needs changing,
# DERIVE IT AGAIN from the module. Do not paste a run's output into it.
#
# ── WHY THE VM LEG RUNS FIRST — a deliberate change from the sibling gates ──
# gate_wotsp.sh and gate_xmss.sh both run the C host first. This one does not,
# and the reason is specific rather than stylistic: the host leg is MEASURED at
# 5581 s (93 min) while the VM leg has NEVER COMPLETED, so the VM leg is the one
# that can still fail in an unknown way. Running it first surfaces a codegen or
# emit problem ~90 minutes earlier than the sibling order would. Once the VM leg
# has a measured cost this ordering stops mattering and can go back.
#
# ── EACH STAGE FAILS UNDER ITS OWN NAME ─────────────────────────────────────
# ★ The sibling gates pipe codegen to /dev/null and go straight to ./logos_secd.
# If codegen dies or hangs, what runs is a STALE OR ABSENT binary, and the red
# arrives as "wrong output" or a shell error — a red that names the wrong thing.
# That is not hypothetical here: this module's own header records an accidental
# third sha256 merge pushing its codegen to 163 MINUTES. So each stage below is
# bounded, checked, and reports itself: "secd emit", "codegen", "run". A red must
# name the REAL failure or it is worse than no red at all.
#
# ── MEASURED COST, AND THE PART THAT IS HONESTLY UNKNOWN ────────────────────
#     C host        5581 s  (93 min)   MEASURED 2026-08-24
#     native VM     UNMEASURED — the only attempt was killed mid-codegen.
#                   xmss.la, the closest comparable, cost 1597 s codegen +
#                   601 s run. This module merges MORE (xmss.la + xmssidx.la),
#                   so treat that as a floor, not an estimate.
# ★ No total is given, because two thirds of one leg is not a total. The
# timeouts below are generous rather than tight for exactly that reason: a
# timeout tuned to a cost nobody has measured is a coin flip that reads as a
# verdict.
#
# ── WIRING: NOT WIRED, AND THAT IS A DECISION ───────────────────────────────
# This gate is NOT referenced by build.sh. On a ~3 h build, adding a 93-minute
# host leg plus an unmeasured VM leg is a real decision and belongs to a human
# who can see the whole build budget. SIGNER_VM_ONLY=1 runs the cheap half — the
# trade gate_xmss.sh's header names but does not implement — and when it is set,
# THE PASS LINE SAYS SO, because host==VM is the project's core discipline and a
# skip that is not announced reads as coverage.
#
#     bash gate_xmss_signer.sh                  # host + VM + byte-identity
#     SIGNER_VM_ONLY=1 bash gate_xmss_signer.sh # VM only, NO host==VM claim
set -uo pipefail
cd "$(dirname "$0")"
ok=1

E_SIGNER="xmss_signer n=2 w=4 h=1: idx0=0 OK | idx1=1 OK | sig0 verifies OK | sig1 verifies vs SAME root OK | sigs differ OK | state spent=2 OK"

# The module initialises its own state file to "0" as the first act of RUN, so
# this gate deliberately does NOT seed it — seeding would hide a module that had
# stopped initialising. It is removed at the end so nothing inherits a spent
# register: at h=1 the file is left at 2, and a later reader of a spent register
# would halt, correctly but confusingly, in some unrelated run.
rm -f xmss_signer.state

# ── the native SECD VM leg ──────────────────────────────────────────────────
rm -f logos_secd logos_program.bin logos_source.la

EMIT="$(timeout 1800 ./tiny_host secd.la 2>&1 | head -1)"
if [ "$EMIT" != "emitted logos_secd" ]; then
    echo "FAIL  xmss_signer secd emit: [$EMIT]"; ok=0
elif [ ! -x ./logos_secd ]; then
    echo "FAIL  xmss_signer secd emit: printed success but logos_secd is not executable"; ok=0
else
    cp xmss_signer.la logos_source.la
    timeout 21600 ./tiny_host codegen.la >/dev/null 2>&1
    cgrc=$?
    if [ "$cgrc" -eq 124 ]; then
        echo "FAIL  xmss_signer codegen: TIMED OUT at 21600 s — not a wrong answer, an unfinished one"; ok=0
    elif [ "$cgrc" -ne 0 ]; then
        echo "FAIL  xmss_signer codegen: exited $cgrc"; ok=0
    elif [ ! -s logos_program.bin ]; then
        echo "FAIL  xmss_signer codegen: exited 0 but logos_program.bin is missing or empty"; ok=0
    else
        VMOUT="$(timeout 21600 ./logos_secd 2>&1 | head -1)"
    fi
fi
rm -f logos_secd logos_program.bin logos_source.la

# ── the C host leg, and byte-identity ───────────────────────────────────────
# ★ THE VM IS COMPARED TO THE HOST, NOT TO E_SIGNER — and that is the whole
# reason the byte-identity line is worth having. The sibling gates check BOTH
# engines against the same expected constant and THEN check the two against each
# other, justifying the third line as catching "each engine wrong its own way".
# It cannot: if HOSTOUT = E and VMOUT = E then HOSTOUT = VMOUT necessarily, so
# that line can never go red on its own. It is a check that cannot fail — the
# exact shape this layer's own modules are written to avoid. Comparing the VM to
# the HOST instead keeps identical total strength (both engines wrong the same
# way still fails against E; the VM wrong alone still fails) while making every
# line live and pointing each red at the thing that actually broke.
if [ "${SIGNER_VM_ONLY:-0}" = "1" ]; then
    # With no host leg there is nothing to be identical TO, so here and only
    # here the VM is measured against the derived expectation directly.
    [ "$VMOUT" = "$E_SIGNER" ] || { echo "FAIL  xmss_signer native VM: [$VMOUT]"; ok=0; }
    HOSTNOTE="C host leg NOT RUN in this invocation (SIGNER_VM_ONLY=1; the host leg is 93 min). host==VM byte-identity is therefore NOT established here — only the native VM ran, against the derived expectation."
else
    HOSTOUT="$(timeout 21600 ./tiny_host xmss_signer.la 2>&1 | head -1)"
    [ "$HOSTOUT" = "$E_SIGNER" ] || { echo "FAIL  xmss_signer C host: [$HOSTOUT]"; ok=0; }

    if [ -n "${VMOUT+x}" ]; then
        [ "$VMOUT" = "$HOSTOUT" ] || { echo "FAIL  xmss_signer host != VM: host [$HOSTOUT] vs VM [$VMOUT]"; ok=0; }
    else
        echo "FAIL  xmss_signer: host==VM NOT CHECKED — the VM leg produced no output"; ok=0
    fi
    HOSTNOTE="Byte-identical on the C host AND the native VM — the VM is checked AGAINST the host, so that comparison is load-bearing rather than implied by two checks against one constant."
fi

rm -f xmss_signer.state

# ── THE EXPORT SURFACE — a regression guard on a defect that already shipped ─
# ★ This module shipped with NO `export` line. tiny_host's `mangle_privates`
# alpha-renames every glyph of a module whose export set is empty, so
# SIGN_GUARDED — the safe entry point the module exists to provide — was
# invisible to any importer, while `xmss.la` exported the UNGUARDED `XMSS_SIGN`.
# The only importable way to sign was the unsafe one. Nothing caught it because
# nothing imports this module: it is only ever run top-level, the one case the
# mangling does not touch. So the absence was invisible to every existing gate.
#
# ★ The CONTROL is what makes this a check rather than a formality. Asserting
# only that SIGN_GUARDED is visible would also pass if the export mechanism had
# broken OPEN and were exposing everything — which is a different bug, not a
# fix. So a witness-only helper (`VER`, bound to this module's N/W/H test
# constants) must STILL be unbound. Visible API + private internals, or neither
# half means anything. This arm is parse-time only: it resolves imports and
# evaluates four glyph references to closures, never applying them, so it costs
# seconds and never signs anything.
PROBE=".gate_signer_export_probe.la"
CTRL=".gate_signer_export_ctrl.la"
cat > "$PROBE" <<'PROBE_EOF'
import("xmss_signer.la")
glyph SEQ = la a. la b. b
glyph MAIN = SEQ(SIGN_GUARDED)(SEQ(SIG_IDX)(SEQ(SIG_WOTS)(SEQ(SIG_AUTH)(print("export surface ok")))))
PROBE_EOF
cat > "$CTRL" <<'CTRL_EOF'
import("xmss_signer.la")
glyph SEQ = la a. la b. b
glyph MAIN = SEQ(VER)(print("LEAKED"))
CTRL_EOF

POUT="$(timeout 600 ./tiny_host "$PROBE" 2>&1 | head -1)"
[ "$POUT" = "export surface ok" ] || { echo "FAIL  xmss_signer export surface: SIGN_GUARDED/SIG_IDX/SIG_WOTS/SIG_AUTH not all importable: [$POUT]"; ok=0; }

COUT="$(timeout 600 ./tiny_host "$CTRL" 2>&1 | head -1)"
case "$COUT" in
    *"unbound variable 'VER'"*) : ;;
    *) echo "FAIL  xmss_signer export surface: the witness helper VER is NOT private — the export list is leaking internals: [$COUT]"; ok=0 ;;
esac
rm -f "$PROBE" "$CTRL"


[ "$ok" -eq 1 ] && echo "PASS  xmss_signer: the JOIN — XMSS signing with the leaf-index register actually wired in, which neither gate_xmss.sh nor gate_xmssidx.sh witnesses. SIGN_GUARDED takes a state path and NO INDEX, so the index is an OUTPUT of signing rather than a parameter a caller can get wrong; because the language is call-by-value, IDX_RESERVE's durable write completes BEFORE any signing happens, and that ordering is inherited rather than re-implemented. Two consecutive signs took leaves 0 and 1 with the caller naming neither, both verify against the SAME root, and the register ended durably spent at 2 — which at h=1 is the entire capacity, so the run ends in the state a real signer must handle. $HOSTNOTE Parameters n=2 w=4 h=1 are a TOY security level, as in xmss.la; what is witnessed here is the WIRING. The export surface is checked in BOTH directions: the four API glyphs are importable, and a witness-only helper is NOT — a regression guard on a real defect, since this module shipped with no export line at all, which made the guarded entry point unreachable while xmss.la's unguarded XMSS_SIGN stayed exported. Exhaustion is NOT re-tested here — it lives in IDX_RESERVE and gate_xmssidx.sh exhausts it on purpose. 'sigs differ' varies leaf and message together and is not the leaf-independence witness; idx0/idx1 plus one shared root are."
[ "$ok" -eq 1 ]
