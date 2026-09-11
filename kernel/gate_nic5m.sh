#!/usr/bin/env bash
# LogOS HAL.5m gate — a frame-CLASSIFYING ICMP echo responder with RX-ring
# advance. Three runs of the SAME kernel:
#
#   ping         IHL=5, no noise   — regression: must behave exactly as 5j did,
#                                    and must NOT skip a frame it should answer.
#   pingopt      IHL=6, no noise   — 5j's IHL generality must survive.
#   arpthenping  ARP then the ping — ★ THE NEW CAPABILITY. An ARP broadcast
#                                    lands in the ring AHEAD of the echo
#                                    request. 5m must classify it out, advance
#                                    CAPR past it, and answer the ping behind it.
#
# ★ THE THIRD CASE WAS MEASURED AGAINST THE SHIPPED 5j BEFORE 5m EXISTED: 5j
# printed "nic icmp req ihl=00 type=00", built a reply out of the ARP frame,
# transmitted it, and never saw the ping. So this gate can fail, and the
# previous kernel is what fails it.
#
# Two-witness, like 5i/5j and unlike 5k/5l: this kernel TRANSMITS a reply, so
# the pinger independently verifies it (addresses swapped back, type 0, ICMP
# checksum summing to 0xffff) rather than the guest merely reporting itself OK.
# The serial additionally shows the DECISION ("nic skip et=0806"), not just the
# outcome — so a kernel that answered correctly BY LUCK, without classifying,
# would still fail.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then echo "SKIP  HAL.5m: qemu absent"; exit 0; fi
if ! command -v python3 >/dev/null 2>&1; then echo "SKIP  HAL.5m: python3 absent"; exit 0; fi

./kernel/build_nic5m.sh >/dev/null 2>&1 || { echo "FAIL  HAL.5m gate: build_nic5m.sh failed"; exit 1; }

ok=1
CLEAN=""

# run <mode> <port> — leaves the guest serial in $CLEAN, harness rc in $PRC
run_case() {
    local mode="$1" port="$2"
    local SER PLOG
    SER=$(mktemp); PLOG=$(mktemp)
    qemu-system-x86_64 -kernel kernel/kernel_nic5m.elf -m 512 \
      -netdev socket,id=n0,listen=127.0.0.1:"$port" -device rtl8139,netdev=n0 \
      -serial file:"$SER" -display none -no-reboot -no-shutdown >/dev/null 2>&1 &
    local QP=$!
    python3 kernel/ping_harness.py "$mode" "$port" 8 >"$PLOG" 2>&1
    PRC=$?
    sleep 0.3; kill $QP 2>/dev/null; wait 2>/dev/null
    CLEAN=$(tr -d '\0' < "$SER")
    SEEN=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 300)
    POUT=$(tr '\n' ' ' <"$PLOG" | head -c 200)
    rm -f "$SER" "$PLOG"
}

want() {  # want <case> <token>
    printf '%s' "$CLEAN" | grep -qF "$2" \
        || { echo "FAIL  HAL.5m [$1]: '$2' not on guest serial (got: $SEEN)"; ok=0; }
}
reject() {  # reject <case> <token> <why>
    printf '%s' "$CLEAN" | grep -qF "$2" \
        && { echo "FAIL  HAL.5m [$1]: '$2' WAS on the serial — $3 (got: $SEEN)"; ok=0; }
    return 0
}

# ---- case 1: no noise, IHL=5 — regression -------------------------------
run_case ping 12430
want "ping" 'nic5m:'; want "ping" 'nic setup ok'
want "ping" 'nic icmp req ihl=05 type=08 from=52550a000202'
want "ping" 'nic icmp reply sent'; want "ping" 'nic done'
# NEGATIVE: a clean ring has nothing to skip. If this fires, the classifier is
# rejecting frames it should accept — which would still "pass" the positive
# checks on a later retry, so the absence is the only place it shows.
reject "ping" 'nic skip' "the classifier discarded a frame it should have answered"
[ "$PRC" -eq 0 ] || { echo "FAIL  HAL.5m [ping]: pinger got no valid echo ($POUT)"; ok=0; }

# ---- case 2: no noise, IHL=6 — 5j's capability must survive -------------
run_case pingopt 12431
want "pingopt" 'nic icmp req ihl=06 type=08 from=52550a000202'
want "pingopt" 'nic icmp reply sent'
[ "$PRC" -eq 0 ] || { echo "FAIL  HAL.5m [pingopt]: pinger got no valid echo ($POUT)"; ok=0; }

# ---- case 3: ARP noise ahead of the ping — THE NEW CAPABILITY -----------
run_case arpthenping 12432
want "arpthenping" 'nic skip et=0806'                                  # classified the ARP OUT
want "arpthenping" 'nic icmp req ihl=05 type=08 from=52550a000202'     # then found the real one
want "arpthenping" 'nic icmp reply sent'; want "arpthenping" 'nic done'
# NEGATIVE: the ihl=00 signature of parsing the ARP as IPv4 — the exact string
# the shipped 5j printed. If this appears, 5m regressed to 5j's behaviour.
reject "arpthenping" 'ihl=00' "it parsed the ARP frame as IPv4, as 5j did"
[ "$PRC" -eq 0 ] || { echo "FAIL  HAL.5m [arpthenping]: pinger got no valid echo ($POUT)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  HAL.5m: a frame-CLASSIFYING ICMP echo responder with RX-ring advance, in Lingua Adamica — an ARP broadcast landed in the DMA ring ahead of a real ICMP echo request; the LA kernel at ring 0 classified it out on ethertype (witness 'nic skip et=0806'), advanced the RTL8139 CAPR past it (align4(o+4+len), the -0x10 quirk), found the echo request in the NEXT ring slot, and answered it — verified independently by the pinger (addresses swapped back, type 0, ICMP checksum summing to 0xffff). Also bounds ihl>=5, so an ARP frame can no longer yield L4OFF=14 pointing into the Ethernet header. HAL.5j, measured on the same input, printed 'ihl=00', replied with garbage built from the ARP, and never saw the ping. Composes 5e's ring advance with 5i/5j's responder; bounded by FUEL so a ring full of noise cannot spin it forever."

[ "$ok" -eq 1 ]
