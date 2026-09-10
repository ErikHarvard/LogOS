#!/usr/bin/env bash
# LogOS HAL.5q gate — a SELF-REPAIRING ICMP responder (Tier-2b, first instance).
#
# ★★ AUTHORED BY AN UNISOLATED SESSION (design groundwork). NOT YET RUN. The
# repair control-flow is verified in scratchpad/test_repair.py; the fault's
# manifestation in QEMU is NOT. Read SELFREPAIR_5q_DESIGN.md first.
#
# The kernel deliberately disables TE after SETUP, so its first transmit should
# wedge; it must then SENSE the TSD, DIAGNOSE ("nic tx wedged tsd=..."), re-enable
# TE, RETRY, and report "nic tx recovered" before the reply goes out. The pinger
# independently verifies the *repaired* transmit put a correct echo on the wire.
#
# THREE THINGS THIS GATE ASSERTS, in order of what they prove:
#   1. THE FAULT MANIFESTED — "nic tx wedged" MUST appear. If it does not (the
#      serial shows "nic tx ok"), QEMU ignored TE, the repair branch never fired,
#      and this gate proves NOTHING even though it may be green. This assertion
#      is FIRST and load-bearing — it is the check that the check can fire.
#   2. THE REPAIR WORKED — "nic tx recovered" appears and the pinger gets a valid
#      echo. "nic tx dead" must NOT appear.
#   3. RED-PATH — nic5q_ctrl (same fault, repair branch removed) must FAIL: it
#      diagnoses then stops, so no reply reaches the pinger. Build + run it and
#      confirm RED before believing 5q's green.
#
# ★ nic5q_ctrl.la DOES NOT EXIST YET. The isolated session creates it from
#   nic5q.la by removing the repair branch (make TXSTEP's timeout case just
#   print "nic tx wedged" and stop — no re-enable, no retry), builds it via a
#   build_nic5q_ctrl.sh, and runs the red-path block below. Until that exists,
#   this gate runs only cases 1-2 and prints a NOTE that the red-path is pending.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then echo "SKIP  HAL.5q: qemu absent"; exit 0; fi
if ! command -v python3 >/dev/null 2>&1; then echo "SKIP  HAL.5q: python3 absent"; exit 0; fi

./kernel/build_nic5q.sh >/dev/null 2>&1 || { echo "FAIL  HAL.5q gate: build_nic5q.sh failed"; exit 1; }

ok=1
PORT=12480
SER=$(mktemp); PLOG=$(mktemp)
qemu-system-x86_64 -kernel kernel/kernel_nic5q.elf -m 512 \
  -netdev socket,id=n0,listen=127.0.0.1:$PORT -device rtl8139,netdev=n0 \
  -serial file:"$SER" -display none -no-reboot -no-shutdown >/dev/null 2>&1 &
QP=$!
python3 kernel/ping_harness.py ping $PORT 8 >"$PLOG" 2>&1
PRC=$?
sleep 0.3; kill $QP 2>/dev/null; wait 2>/dev/null
CLEAN=$(tr -d '\0' < "$SER")
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 400)

# ── check 1 (LOAD-BEARING): the fault manifested at all ──────────────────
if ! printf '%s' "$CLEAN" | grep -qF 'nic tx wedged'; then
    echo "FAIL  HAL.5q: 'nic tx wedged' NOT on serial — the injected TE-off fault"
    echo "      did not manifest in QEMU, so the repair path never fired and a"
    echo "      green here would prove nothing. Redesign the fault (see the design"
    echo "      doc). Serial: $seen"
    ok=0
fi
# ── check 2: the repair succeeded and produced a real reply ──────────────
printf '%s' "$CLEAN" | grep -qF 'nic tx recovered' || { echo "FAIL  HAL.5q: 'nic tx recovered' not on serial (got: $seen)"; ok=0; }
printf '%s' "$CLEAN" | grep -qF 'nic tx dead'      && { echo "FAIL  HAL.5q: 'nic tx dead' — the bounded retry also failed (got: $seen)"; ok=0; }
printf '%s' "$CLEAN" | grep -qF 'nic icmp reply sent' || { echo "FAIL  HAL.5q: reply not sent after repair (got: $seen)"; ok=0; }
[ "$PRC" -eq 0 ] || { echo "FAIL  HAL.5q: pinger got no valid echo after repair ($(tr '\n' ' ' <"$PLOG" | head -c 200))"; ok=0; }
rm -f "$SER" "$PLOG"

# ── check 3: red-path against the no-repair control ──────────────────────
if [ -x ./kernel/build_nic5q_ctrl.sh ] && [ -f kernel/nic5q_ctrl.la ]; then
    ./kernel/build_nic5q_ctrl.sh >/dev/null 2>&1 || { echo "FAIL  HAL.5q: control build failed"; ok=0; }
    CSER=$(mktemp); CPLOG=$(mktemp); CPORT=12481
    qemu-system-x86_64 -kernel kernel/kernel_nic5q_ctrl.elf -m 512 \
      -netdev socket,id=n0,listen=127.0.0.1:$CPORT -device rtl8139,netdev=n0 \
      -serial file:"$CSER" -display none -no-reboot -no-shutdown >/dev/null 2>&1 &
    CQP=$!
    python3 kernel/ping_harness.py ping $CPORT 8 >"$CPLOG" 2>&1
    CPRC=$?
    sleep 0.3; kill $CQP 2>/dev/null; wait 2>/dev/null
    # the control must FAIL to reply — a zero exit here means the gate does not discriminate
    if [ "$CPRC" -eq 0 ]; then
        echo "FAIL  HAL.5q [red-path]: the no-repair control STILL replied — the gate"
        echo "      does not discriminate, so 5q's green does not prove the repair did anything."
        ok=0
    else
        echo "      red-path OK: no-repair control got no reply (rc=$CPRC), so 5q's repair is load-bearing."
    fi
    rm -f "$CSER" "$CPLOG"
else
    echo "      NOTE: red-path SKIPPED — kernel/nic5q_ctrl.la + build_nic5q_ctrl.sh not present."
    echo "      Create them (5q with the repair branch removed) so this gate can prove it discriminates."
fi

[ "$ok" -eq 1 ] && echo "PASS  HAL.5q: a SELF-REPAIRING ICMP responder in Lingua Adamica — the driver's transmit was deliberately faulted (TE disabled), its bounded TX-wait timed out, it SENSED the TSD register, DIAGNOSED the wedge ('nic tx wedged'), re-initialised the faulted device path from spec (re-enabled TE), RETRIED, and RECOVERED ('nic tx recovered') — the pinger independently verified the repaired transmit put a correct ICMP echo on the wire. The AATC Sense->Diagnose->Prescribe->Retry loop applied to a device organ, bounded so a repair that cannot succeed fails loudly ('nic tx dead') rather than hanging. Honest scope: a self-inflicted fault proves the mechanism, not universal fault-tolerance."

[ "$ok" -eq 1 ]
