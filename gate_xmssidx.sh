#!/usr/bin/env bash
# The durable leaf-index register for XMSS — and the gate for the one defect
# class in this whole stack that no ordinary test can see.
#
# ── WHY THIS GATE HAD TO BE WRITTEN DIFFERENTLY ─────────────────────────────
# `gate_xmss.sh` is green on nine checks and would stay green forever with NO
# index tracking whatsoever, because nothing in a test reuses an index. Every
# signature verifies; the key is destroyed anyway. The failure is not a wrong
# answer — it is a CORRECT ANSWER GIVEN TWICE. So negative controls of the
# wotsp.la kind cannot reach it, and the checks here are of a different shape:
# they deliberately exhaust the key, deliberately kill the process, and
# deliberately remove the state.
#
#     reserve twice, indices differ    -- no reuse within a process
#     advance persisted                -- the write happens, not just in memory
#     unused slot LOST not reissued    -- ★ the write-ahead ORDERING (below)
#     a SECOND PROCESS resumes at 3    -- durability across process death
#     spent key REFUSES (nonzero)      -- exhaustion halts, does not wrap to 0
#     missing state REFUSES (nonzero)  -- never assume 0, never recreate
#
# ★ THE ORDERING CHECK IS THE SUBTLE ONE. IDX_RESERVE persists the ADVANCED
# index BEFORE returning the index to sign with, so a crash between reserving
# and signing LOSES a slot rather than reusing one. "unused slot LOST not
# reissued" is what distinguishes that from a register that advances lazily
# after signing — which passes every other check on this list and is broken.
# The asymmetry is deliberate: a lost slot costs one signature out of 2^h; a
# reused slot leaks a leaf secret.
#
# ★ AND "missing state REFUSES" IS NOT A ROBUSTNESS NICETY. A register that
# created its state file on first read would, after any loss or restore from an
# old backup, restart at 0 and reuse EVERY index in the tree. read_file halting
# on an absent path gives the safe behaviour for free, and this gate pins it so
# nobody later "fixes" it into a create-on-read convenience.
#
# ── ★ THIS GATE WAS MUTATION-TESTED, AND THE RESULT ARGUES FOR ITS SHAPE ────
# Three mutants were run against a copy (symlinked into a scratch dir so the
# `cd "$(dirname "$0")"` still resolved — a gate copied OUTSIDE the tree dies of
# a missing binary and its red proves nothing). An unmutated control was run
# first to prove the harness itself was valid.
#
#   never persists the advance        -> RED (5 of 6 checks + the resume leg)
#   writes i instead of i+1           -> RED (5 of 6 checks + the resume leg)
#   spent key WRAPS to index 0        -> RED, but ONLY on the exhaustion arm
#
# The third is the important one. The wrapping mutant passes ALL SIX of the
# register's own checks, cleanly — first=0, second=1, no reuse, advance
# persisted, third=2, unused slot lost. It is caught by nothing except the arm
# that deliberately spends the key. So the arm that looks like duplication is
# the only arm that reaches this defect, and reasoning about coverage would have
# deleted it. Do not remove the exhaustion driver as redundant.
#
# ★ AND: EVERY MUTANT NEEDS ITS OWN WITNESS THAT IT DIED OF THE INTENDED CAUSE.
# The first wrap-to-0 mutant was malformed and died with `attempt to apply a
# non-function` — a red for the WRONG REASON. Accepting it would have "proved"
# this gate catches wrap-to-0 when it did not. The mutant was rewritten until it
# RAN CLEANLY and reserved index 0 past capacity, and only then did its red mean
# anything. A mutation test that does not check WHY the mutant failed is a
# coin-flip wearing a lab coat.
#
# ── EXPECTED-STRING PROVENANCE ───────────────────────────────────────────────
# Both pinned strings were DERIVED from the modules' own concat structure, not
# captured from stdout. An expectation copied from observed output cannot detect
# a wrong observed output, because it IS that output.
#
# ── COST: SECONDS. THIS ONE SHOULD BE WIRED. ────────────────────────────────
# The register is PURE file I/O and integer arithmetic — no hashing at all — so
# the host legs run in ~15 ms and the whole gate is dominated by one codegen.
# That is deliberate: the register was kept separable from the signature scheme
# precisely so the stateful-key discipline could be gated cheaply and often,
# instead of riding along on a 2 h 41 min signature gate.
#
# ── WHAT IS STILL NOT GUARANTEED ────────────────────────────────────────────
# No fsync (no builtin on either engine): the write survives process death, not
# power loss — and after a power loss the register can go BACKWARDS, the one
# direction that breaks the key. No concurrency control: single-writer only.
# And reuse is unreachable only THROUGH this path; xmss.la's XMSS_SIGN still
# takes an explicit index. None of that is fixed by this gate, and none of it
# is hidden by it.
set -uo pipefail
cd "$(dirname "$0")"
ok=1

STATE="xmssidx_test.state"
E_IDX="xmssidx h=2: first=0 OK | second=1 OK | no reuse OK | advance persisted OK | third=2 OK | unused slot LOST not reissued OK"
E_RESUME="xmssidx resume: reserved=3 next=4"

# ── 1. the register on the C host ───────────────────────────────────────────
HOSTOUT="$(timeout 300 ./tiny_host xmssidx.la 2>&1 | head -1)"
[ "$HOSTOUT" = "$E_IDX" ] || { echo "FAIL  xmssidx C host: [$HOSTOUT]"; ok=0; }

# ── 2. DURABILITY ACROSS PROCESS DEATH ──────────────────────────────────────
# xmssidx.la left the state at 3. A second, separate process must resume there
# and hand out 3 — not 0. This is the check the first module cannot make about
# itself, because it initialises its own state.
RESUMEOUT="$(timeout 300 ./tiny_host xmssidx_resume.la 2>&1 | head -1)"
[ "$RESUMEOUT" = "$E_RESUME" ] || { echo "FAIL  xmssidx resume (durability): [$RESUMEOUT]"; ok=0; }

# ── 3. a SPENT key must refuse, not wrap ────────────────────────────────────
EXH="$(timeout 300 ./tiny_host xmssidx_exhaust.la 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL  xmssidx exhaustion: exited 0 — a spent key handed out an index"; ok=0; }
case "$EXH" in
    *"key exhausted"*) ;;
    *) echo "FAIL  xmssidx exhaustion: wrong diagnostic: [$EXH]"; ok=0 ;;
esac
case "$EXH" in
    *BUG:*) echo "FAIL  xmssidx exhaustion: reserved an index past capacity"; ok=0 ;;
esac

# ── 4. MISSING state must refuse, never assume 0 ────────────────────────────
mv "$STATE" "$STATE.gatebak" 2>/dev/null
MISS="$(timeout 300 ./tiny_host xmssidx_resume.la 2>&1)"; rc=$?
mv "$STATE.gatebak" "$STATE" 2>/dev/null
[ "$rc" -ne 0 ] || { echo "FAIL  xmssidx missing state: exited 0 — a signer invented an index with no state"; ok=0; }

# ── 5. the register on the native SECD VM, byte-identical ───────────────────
rm -f logos_secd logos_program.bin logos_source.la
./tiny_host secd.la >/dev/null 2>&1
cp xmssidx.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
VMOUT="$(timeout 900 ./logos_secd 2>&1 | head -1)"
rm -f logos_secd logos_program.bin logos_source.la
[ "$VMOUT" = "$E_IDX" ] || { echo "FAIL  xmssidx native VM: [$VMOUT]"; ok=0; }
[ "$HOSTOUT" = "$VMOUT" ] || { echo "FAIL  xmssidx: host != VM"; ok=0; }

rm -f "$STATE" xmssidx_exhaust.state

[ "$ok" -eq 1 ] && echo "PASS  xmssidx: the durable leaf-index register — the stateful half of XMSS, and the half no signature test can witness. gate_xmss.sh would stay green forever with no index tracking at all, because nothing in a test reuses an index: the failure is not a wrong answer but a correct answer given twice. So this gate exhausts the key on purpose (a spent key REFUSES with a nonzero exit rather than wrapping to 0 and leaking every leaf secret), removes the state on purpose (a missing state file REFUSES rather than restarting at 0 and reusing every index), and crosses a process boundary on purpose (a second process resumes at index 3, not 0). It also pins the write-ahead ORDERING: a reserved-but-unsigned index is LOST, never reissued, so a crash costs one signature out of 2^h instead of leaking a key. Byte-identical on the C host AND the native VM. NOT guaranteed: durability against power loss (no fsync builtin — the register can go backwards, which is the direction that breaks the key), concurrent signers (single-writer only), and reuse via xmss.la's unguarded XMSS_SIGN, which still takes an explicit index."
[ "$ok" -eq 1 ]
