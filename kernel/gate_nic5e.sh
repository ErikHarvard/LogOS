#!/usr/bin/env bash
# LogOS HAL.5e gate — a real ARP responder + RX-ring advance over RTL8139, in LA.
# Give QEMU a user-mode (SLIRP) netdev. Unlike 5c/5d (which pre-seeded SLIRP's
# ARP cache to dodge answering), 5e sends an ICMP echo request UNSEEDED, so SLIRP
# must ARP for us first — and the kernel ANSWERS that ARP, advances the RX ring,
# then reads the echo reply as the second packet. Assert the whole reactive chain:
#   - "nic5e:"       — the driver started;
#   - "nic arp req oper=0001 tpa=0a00020f" — it received SLIRP's ARP REQUEST and
#                      decoded it out of the DMA ring: oper 1 (request), target
#                      protocol address 10.0.2.15 (0a 00 02 0f) — SLIRP is asking
#                      for OUR IP. A proactive/seeded run never sees this packet.
#   - "nic rx et=0800 proto=01 icmp=00" — AFTER we transmitted the ARP reply and
#                      advanced CAPR past the request, the ICMP ECHO REPLY arrived
#                      as the second ring packet: IPv4 / IP-proto ICMP / type 0.
#                      It arrives ONLY because we answered the ARP (no seed).
#   - "nic done"     — it finished.
# Fully SLIRP-internal (the gateway answers ICMP to itself) — NO host egress
# needed, deterministic. Needs -m 512 (DMA buffers at 256 MiB). Skips (rc 0) if
# QEMU is absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  HAL.5e NIC gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_nic5e.sh >/dev/null 2>&1 || { echo "FAIL  HAL.5e gate: build_nic5e.sh failed"; exit 1; }

OUT=$(timeout 60 qemu-system-x86_64 \
        -kernel kernel/kernel_nic5e.elf -m 512 \
        -netdev user,id=n0 -device rtl8139,netdev=n0 \
        -serial stdio -display none \
        -no-reboot -no-shutdown 2>/dev/null)
RC=$?
CLEAN=$(printf '%s' "$OUT" | tr -d '\0')
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 300)

ok=1
for tok in 'nic5e:' 'nic arp req oper=0001 tpa=0a00020f' 'nic rx et=0800 proto=01 icmp=00' 'nic done'; do
    printf '%s' "$CLEAN" | grep -qF "$tok" || { echo "FAIL  HAL.5e: '$tok' not on serial (rc=$RC, got: $seen)"; ok=0; }
done

[ "$ok" -eq 1 ] && echo "PASS  HAL.5e: a real ARP responder + RX-ring advance in Lingua Adamica — with NO gratuitous-ARP seed, an LA program at ring 0 transmitted an ICMP echo request, RECEIVED SLIRP's ARP REQUEST for 10.0.2.15 and decoded it (oper 1, tpa 0a00020f) out of the DMA ring, TRANSMITTED an ARP REPLY in answer, ADVANCED the RTL8139 CAPR past the consumed packet, and then read the ICMP ECHO REPLY as the second ring packet (et 0800, proto 01, icmp 00) — a reply that arrives ONLY because the ARP was answered. Closes 5c/5d's flagged gap (responder + ring advance), driver in the language, DMA through the identity map."
[ "$ok" -eq 1 ]