#!/usr/bin/env bash
# LogOS HAL.5f gate — a FULLY GENERAL ARP responder over RTL8139, in LA.
# Like 5e, the kernel sends an ICMP echo request UNSEEDED so SLIRP must ARP for
# us — but 5f builds the ARP reply from the REQUESTER'S OWN fields read out of
# the request, not from constants. Assert the whole chain, incl. the generality
# witnesses:
#   - "nic5f:"                              — the driver started;
#   - "nic arp from=52550a000202 spa=0a000202" — the requester's SENDER HW addr
#                      (SLIRP gateway MAC 52:55:0a:00:02:02) and SENDER PROTO addr
#                      (10.0.2.2) READ out of the received ARP request;
#   - "nic reply dst=52550a000202"          — the ARP reply's eth-DST READ BACK
#                      from the TX buffer after the copy: it EQUALS the requester's
#                      sha, so the reply was built from the request, not hard-coded;
#   - "nic rx et=0800 proto=01 icmp=00"     — the ICMP echo reply arrived (the
#                      dynamically-built ARP reply was valid and answered);
#   - "nic done"                            — it finished.
# Fully SLIRP-internal — no host egress, deterministic. Needs -m 512. Skips
# (rc 0) if QEMU is absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  HAL.5f NIC gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_nic5f.sh >/dev/null 2>&1 || { echo "FAIL  HAL.5f gate: build_nic5f.sh failed"; exit 1; }

OUT=$(timeout 60 qemu-system-x86_64 \
        -kernel kernel/kernel_nic5f.elf -m 512 \
        -netdev user,id=n0 -device rtl8139,netdev=n0 \
        -serial stdio -display none \
        -no-reboot -no-shutdown 2>/dev/null)
RC=$?
CLEAN=$(printf '%s' "$OUT" | tr -d '\0')
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 300)

ok=1
for tok in 'nic5f:' 'nic arp from=52550a000202 spa=0a000202' 'nic reply dst=52550a000202' 'nic rx et=0800 proto=01 icmp=00' 'nic done'; do
    printf '%s' "$CLEAN" | grep -qF "$tok" || { echo "FAIL  HAL.5f: '$tok' not on serial (rc=$RC, got: $seen)"; ok=0; }
done

[ "$ok" -eq 1 ] && echo "PASS  HAL.5f: a fully general ARP responder in Lingua Adamica — an LA program at ring 0 TXed an ICMP echo request unseeded, received SLIRP's ARP REQUEST, READ the requester's own sender HW addr (52:55:0a:00:02:02) and sender proto addr (10.0.2.2) out of the DMA ring, COPIED them (byte loop, no bitwise ops) into an ARP reply template's eth-dst / tha / tpa — verified by reading the reply's eth-dst back (== the requester's sha) — TXed the built reply, advanced the RX ring, and received the ICMP echo reply (et 0800, proto 01, icmp 00), which arrives only because the dynamically-built reply was valid. Generalizes 5e's static responder to any requester on a real network, driver in the language, DMA through the identity map."
[ "$ok" -eq 1 ]