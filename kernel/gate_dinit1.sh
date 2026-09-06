#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════════
#  D-INIT.1 GATE — reap(): task death visible to LA, and TCB slots reclaimed.
#
#  The supervision primitive an on-metal LogosInit stands on. Three assertions,
#  the third of which is a NEGATIVE CONTROL the gate requires to FAIL — because
#  a gate whose red has never been witnessed is not a gate.
#
#  (1) SEMANTICS (native_reap_test.bin), exact output:
#        r0=-1   before any spawn        — no tasks at all
#        r1=0    after spawn, pre-yield  — the service is LIVE, not dead
#        r2=1    after it ran            — TCB[1] reaped
#        r3=-1   immediately after       — slot freed, nothing left
#      r1 is the control inside the probe: a reap that ignored TCB_STATE, or
#      returned the first non-current slot, would say 1 while the service is
#      still running, and a supervisor would "restart" a live service.
#      Part B is the case a real supervisor hits: SEVERAL services, only one
#      dead, and the LIVE one at a LOWER index than the dead one —
#        r4=2  the dead task is found PAST the live one
#        r5=0  only the live one left
#        r6=1  after it finishes too
#        r7=-1 drained
#      r4 is the assertion: a scan stopping at the first non-current slot would
#      return 1 (a LIVE service — the supervisor kills and restarts something
#      that is running), and a scan that gave up on meeting a live task would
#      return 0 (the death goes unnoticed and the dead service is never
#      restarted). Only a full scan keying on STATE==2 returns 2.
#
#  (2) RECLAMATION (native_respawn_reap.bin): 12 spawn/yield/reap cycles —
#      more than MAXTASK (8) — must all complete, ending "ALL-12-SPAWNED".
#      Every cycle must report `reaped=1`: the SAME slot handed back each time
#      is the direct evidence of reuse. A run reporting 1,2,3,... would mean
#      slots were still leaking and 12 cycles only fit by luck, so the constant
#      index is asserted, not just the completion.
#
#  (3) THE RED CONTROL (native_respawn_noreap.bin) — MUST FAIL. The identical
#      loop with the reap call removed must still halt at the 8th spawn with
#      "too many tasks (MAXTASK)" and a nonzero rc. This is what makes (2) mean
#      something: it proves reap is the variable, not an incidental change to
#      spawn. If this one ever passes, the experiment is no longer controlled
#      and THIS GATE MUST BE REWRITTEN — do not simply delete the assertion.
#
#  (4) CONSTANT DRIFT: rt_reap was appended at rt.asm EOF so every existing
#      RT_* address is unchanged and only RT_REAP/RTLEN/LITERAL_BASE move.
#      derive_consts re-derives all of them from a fresh nasm listing and
#      validates them against native_codegen3.la. This guards the K6b failure
#      mode, where a runtime edit shifted every RT_* and a stale constant
#      survived into the image.
#
#  Linux-hosted — spawn/yield/reap are green-thread operations on the runtime
#  task table, no ring 0 and no QEMU. Judges pre-built binaries; run
#  kernel/build_dinit1.sh first.
# ════════════════════════════════════════════════════════════════════════════
set -uo pipefail
cd "$(dirname "$0")/.."
ok=1

need() { [ -f "$1" ] || { echo "FAIL  D-INIT.1: $1 missing — run kernel/build_dinit1.sh first"; exit 1; }; }
need kernel/native_reap_test.bin
need kernel/native_respawn_reap.bin
need kernel/native_respawn_noreap.bin

# ── (1) semantics ───────────────────────────────────────────────────────────
OUT=$(timeout 30 ./kernel/native_reap_test.bin 2>&1); RC=$?
EXPECT=$'r0=-1\nr1=0\nsvc-ran\nr2=1\nr3=-1\ndie-ran\nr4=2\nr5=0\nlive-done\nr6=1\nr7=-1'
if [ "$OUT" != "$EXPECT" ]; then
    echo "FAIL  D-INIT.1 semantics: expected"
    echo "        A: r0=-1 r1=0 svc-ran r2=1 r3=-1"
    echo "        B: die-ran r4=2 r5=0 live-done r6=1 r7=-1"
    echo "      got: $(printf '%s' "$OUT" | tr '\n' ' ')"
    ok=0
fi
[ "$RC" -eq 0 ] || { echo "FAIL  D-INIT.1 semantics: exit $RC (expected 0)"; ok=0; }

# ── (2) reclamation: 12 cycles > MAXTASK, same slot every time ──────────────
OUT2=$(timeout 60 ./kernel/native_respawn_reap.bin 2>&1); RC2=$?
printf '%s\n' "$OUT2" | grep -qxF "ALL-12-SPAWNED" || {
    echo "FAIL  D-INIT.1 reclamation: 12 cycles did not complete — $(printf '%s' "$OUT2" | tail -1)"; ok=0; }
[ "$RC2" -eq 0 ] || { echo "FAIL  D-INIT.1 reclamation: exit $RC2 (expected 0)"; ok=0; }
NREAP=$(printf '%s\n' "$OUT2" | grep -c '^reaped=1$')
NOTHER=$(printf '%s\n' "$OUT2" | grep '^reaped=' | grep -vc '^reaped=1$')
[ "$NREAP" -eq 12 ] || { echo "FAIL  D-INIT.1 reclamation: expected 12 'reaped=1' lines, got $NREAP"; ok=0; }
[ "$NOTHER" -eq 0 ] || { echo "FAIL  D-INIT.1 reclamation: $NOTHER cycle(s) reaped an index other than 1 — slots are NOT being reused"; ok=0; }

# ── (3) the red control — MUST fail ─────────────────────────────────────────
OUT3=$(timeout 30 ./kernel/native_respawn_noreap.bin 2>&1); RC3=$?
if [ "$RC3" -eq 0 ]; then
    echo "FAIL  D-INIT.1 red control PASSED, which breaks the experiment: the"
    echo "      no-reap loop is supposed to exhaust MAXTASK and halt. Either spawn"
    echo "      now reclaims slots by itself (so reap is no longer what fixes this,"
    echo "      and assertion (2) proves nothing), or MAXTASK was raised. REWRITE"
    echo "      THIS GATE — do not delete the control."
    ok=0
else
    printf '%s\n' "$OUT3" | grep -qF "too many tasks (MAXTASK)" || {
        echo "FAIL  D-INIT.1 red control failed for the WRONG reason (rc=$RC3): expected the"
        echo "      MAXTASK halt, got: $(printf '%s' "$OUT3" | tail -1)"; ok=0; }
    NSVC=$(printf '%s\n' "$OUT3" | grep -c '^svc[0-9]')
    [ "$NSVC" -eq 7 ] || { echo "FAIL  D-INIT.1 red control: expected exactly 7 services before the halt, got $NSVC"; ok=0; }
fi

# ── (4) RT_REAP address drift ───────────────────────────────────────────────
#  DERIVED HERE, not delegated. scratchpad/derive_consts.py is gitignored, so a
#  checkout without it would derive no RT_REAP row and validate nothing while
#  still printing VALIDATION PASS — the "it looked, found nothing, reported
#  success" shape that tool's own docstring warns about. So this gate derives
#  rt_reap's address from a fresh nasm listing itself (the awk-the-listing
#  pattern build_k6b.sh uses for METAL_FLAG) and compares it to the .la. The
#  full 60-constant validation still runs when the tool IS present, as a bonus.
if command -v nasm >/dev/null 2>&1; then
    if nasm -f bin native_codegen3_rt.asm -o /tmp/dinit1_rt.bin -l /tmp/dinit1_rt.lst 2>/dev/null; then
        # a bare `label:` line carries no offset; take the next bytes-emitting line
        OFF=$(awk '/[ \t]rt_reap:[ \t]*$/{f=1;next} f && $2 ~ /^[0-9A-Fa-f]{8}$/{print $2; exit}' /tmp/dinit1_rt.lst)
        if [ -z "$OFF" ]; then
            echo "FAIL  D-INIT.1: no rt_reap label in the rt listing — the primitive is gone from native_codegen3_rt.asm"; ok=0
        else
            ABS=$(( 0x400078 + 0x$OFF ))
            LAV=$(grep -oP 'glyph RT_REAP\s*=\s*\K\d+' native_codegen3.la)
            [ "$LAV" = "$ABS" ] || { echo "FAIL  D-INIT.1 drift: rt_reap assembles at $ABS but native_codegen3.la says RT_REAP = ${LAV:-<absent>} — the compiler would CALL THE WRONG ADDRESS (the K6b failure mode)"; ok=0; }
        fi
        # bonus: the full constant set, when the (gitignored) checker is present
        if [ -f scratchpad/derive_consts.py ]; then
            python3 scratchpad/derive_consts.py /tmp/dinit1_rt.lst /tmp/dinit1_rt.bin \
                    --validate native_codegen3.la >/tmp/dinit1_val.txt 2>&1 \
                || { echo "FAIL  D-INIT.1 constant drift: derive_consts VALIDATION FAILED"
                     grep -F '***' /tmp/dinit1_val.txt | head; ok=0; }
            grep -q '^  RT_REAP ' /tmp/dinit1_val.txt \
                || echo "NOTE  D-INIT.1: derive_consts does not list RT_REAP in LABELS, so IT is not checking this constant (this gate derived it directly above, so the check still happened). Add \"RT_REAP\": \"rt_reap\" to LABELS in scratchpad/derive_consts.py."
            rm -f /tmp/dinit1_val.txt
        else
            echo "NOTE  D-INIT.1: scratchpad/derive_consts.py absent (it is gitignored) — the full 60-constant validation was skipped; RT_REAP itself was still derived and checked above"
        fi
    else
        echo "FAIL  D-INIT.1: nasm could not assemble native_codegen3_rt.asm"; ok=0
    fi
    rm -f /tmp/dinit1_rt.bin /tmp/dinit1_rt.lst
else
    echo "NOTE  D-INIT.1: nasm absent — the address-drift check was skipped (probes still judged)"
fi

[ "$ok" -eq 1 ] && echo "PASS  D-INIT.1: reap() — task death is visible to LA (-1/0/index, a LIVE service never reported dead) and dead TCB slots are reclaimed, so a supervisor ran 12 restart cycles past MAXTASK=8 reusing one slot; the identical loop WITHOUT reap still halts at 7 with 'too many tasks' (the control holds, so reap is the variable); every RT_* revalidated against a fresh nasm listing" || exit 1
