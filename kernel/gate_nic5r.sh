#!/usr/bin/env bash
# LogOS HAL.5r gate — a SELF-REPAIRING (RX-side) ICMP responder (Tier-2b).
#
# The RX twin of HAL.5q. The kernel deliberately leaves RE (receive-enable) OFF
# after SETUP, so the first receive genuinely never completes; its BOUNDED WAITRX
# (RXFUEL=200000) times out CLEANLY — where the arc's old WAITRX(20000000) would
# recurse ~20M deep and stack-overflow (deterministic EXCEPTION 0e). It must then
# SENSE CR, DIAGNOSE ("nic rx wedged cr=XX"), re-enable RE, RETRY the receive, and
# report "nic rx recovered" before answering a later frame. The pinger sends
# several ICMP requests, so a request that arrives after RE is re-enabled is the
# one that gets received and answered.
#
# Verified 2026-08-03 (unisolated): fault manifests (`nic rx wedged cr=05`),
# repair recovers (`nic rx recovered` + pinger-verified echo, rc=0), and the
# red-path control (RX repair removed) gets no reply (rc=1). This gate encodes
# exactly those observations.
#
# THREE THINGS THIS GATE ASSERTS, in order of what they prove:
#   1. THE FAULT MANIFESTED — "nic rx wedged" MUST appear (RE-off genuinely
#      blocked receive and the bounded wait fired). Load-bearing: the check that
#      the check can fire.
#   2. THE REPAIR WORKED — "nic rx recovered" appears and the pinger gets a valid
#      echo. "nic rx dead" must NOT appear (a post-repair timeout = fuel too
#      small to span the pinger's inter-request gap).
#   3. RED-PATH — nic5r_ctrl (same fault, RX repair removed) must FAIL: it
#      diagnoses then stops, so no reply reaches the pinger.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then echo "SKIP  HAL.5r: qemu absent"; exit 0; fi
if ! command -v python3 >/dev/null 2>&1; then echo "SKIP  HAL.5r: python3 absent"; exit 0; fi

./kernel/build_nic5r.sh >/dev/null 2>&1 || { echo "FAIL  HAL.5r gate: build_nic5r.sh failed"; exit 1; }

ok=1
PORT=12487
SER=$(mktemp); PLOG=$(mktemp)
qemu-system-x86_64 -kernel kernel/kernel_nic5r.elf -m 512 \
  -netdev socket,id=n0,listen=127.0.0.1:$PORT -device rtl8139,netdev=n0 \
  -serial file:"$SER" -display none -no-reboot -no-shutdown >/dev/null 2>&1 &
QP=$!
python3 kernel/ping_harness.py ping $PORT 8 >"$PLOG" 2>&1
PRC=$?
sleep 0.3; kill $QP 2>/dev/null; wait 2>/dev/null
CLEAN=$(tr -d '\0' < "$SER")
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 400)

# ── check 1 (LOAD-BEARING): the fault manifested at all ──────────────────
if ! printf '%s' "$CLEAN" | grep -qF 'nic rx wedged'; then
    echo "FAIL  HAL.5r: 'nic rx wedged' NOT on serial — the injected RE-off fault"
    echo "      did not manifest (or WAITRX crashed instead of timing out). A green"
    echo "      here would prove nothing. Serial: $seen"
    ok=0
fi
# ── check 2: the repair succeeded and produced a real reply ──────────────
printf '%s' "$CLEAN" | grep -qF 'nic rx recovered' || { echo "FAIL  HAL.5r: 'nic rx recovered' not on serial (got: $seen)"; ok=0; }
printf '%s' "$CLEAN" | grep -qF 'nic rx dead'      && { echo "FAIL  HAL.5r: 'nic rx dead' — post-repair receive also timed out; raise RXFUEL (got: $seen)"; ok=0; }
printf '%s' "$CLEAN" | grep -qF 'nic icmp reply sent' || { echo "FAIL  HAL.5r: reply not sent after repair (got: $seen)"; ok=0; }
[ "$PRC" -eq 0 ] || { echo "FAIL  HAL.5r: pinger got no valid echo after repair ($(tr '\n' ' ' <"$PLOG" | head -c 200))"; ok=0; }
rm -f "$SER" "$PLOG"

# ── check 3: red-path against the no-repair control ──────────────────────
if [ -x ./kernel/build_nic5r_ctrl.sh ] && [ -f kernel/nic5r_ctrl.la ]; then
    ./kernel/build_nic5r_ctrl.sh >/dev/null 2>&1 || { echo "FAIL  HAL.5r: control build failed"; ok=0; }
    CSER=$(mktemp); CPLOG=$(mktemp); CPORT=12488
    qemu-system-x86_64 -kernel kernel/kernel_nic5r_ctrl.elf -m 512 \
      -netdev socket,id=n0,listen=127.0.0.1:$CPORT -device rtl8139,netdev=n0 \
      -serial file:"$CSER" -display none -no-reboot -no-shutdown >/dev/null 2>&1 &
    CQP=$!
    python3 kernel/ping_harness.py ping $CPORT 8 >"$CPLOG" 2>&1
    CPRC=$?
    sleep 0.3; kill $CQP 2>/dev/null; wait 2>/dev/null
    if [ "$CPRC" -eq 0 ]; then
        echo "FAIL  HAL.5r [red-path]: the no-repair control STILL replied — the gate"
        echo "      does not discriminate, so 5r's green does not prove the repair did anything."
        ok=0
    else
        echo "      red-path OK: no-repair control got no reply (rc=$CPRC), so 5r's repair is load-bearing."
    fi
    rm -f "$CSER" "$CPLOG"
else
    echo "      NOTE: red-path SKIPPED — kernel/nic5r_ctrl.la + build_nic5r_ctrl.sh not present."
fi

[ "$ok" -eq 1 ] && echo "PASS  HAL.5r: a SELF-REPAIRING (RX-side) ICMP responder in Lingua Adamica — receive was deliberately faulted (RE disabled), its BOUNDED RX-wait timed out cleanly (the arc's old unbounded fuel would stack-overflow on a stuck RX), it SENSED CR, DIAGNOSED the wedge ('nic rx wedged'), re-enabled RE from spec, RETRIED, and RECOVERED ('nic rx recovered') — the pinger independently verified the repaired receive path answered a real ICMP echo. AATC Sense->Diagnose->Prescribe->Retry over the NIC's RX organ, bounded so a repair that cannot succeed fails loudly ('nic rx dead'). Honest scope: a self-inflicted fault proves the mechanism, not universal fault-tolerance."

[ "$ok" -eq 1 ]
