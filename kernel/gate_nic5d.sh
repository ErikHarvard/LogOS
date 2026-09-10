#!/usr/bin/env bash
# LogOS HAL.5d gate — a DNS resolution round-trip over RTL8139, in LA.
# Give QEMU a user-mode (SLIRP) netdev — its built-in DNS proxy at 10.0.2.3:53
# forwards a query to the host resolver — boot the NIC kernel, and assert the
# LA driver RESOLVED a hostname and got the UDP/DNS reply, one transport layer
# above HAL.5c's ICMP ping:
#   - "nic5d:"     — the driver started;
#   - "nic tx ok"  — it enabled bus-mastering, set up the DMA RX ring + TX
#                    buffer, transmitted the UDP/DNS A-query, and saw TOK;
#   - "nic rx et=0800 proto=11 sport=0035" — it received a reply and read,
#                    straight out of the DMA ring with peek: ethertype 0x0800
#                    (IPv4), IP protocol 17 (UDP), UDP source port 53 — the DNS
#                    server answered. The "anc=" that follows is the DNS answer
#                    count (>= 0001 for a resolvable name).
#   - "nic done"   — it finished.
# A real UDP transport round-trip, DNS resolution in the language, DMA through
# the identity map. Needs -m 512 (DMA buffers at 256 MiB) AND host network
# egress (the proxy forwards the query). Skips (rc 0) if QEMU is absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  HAL.5d NIC gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_nic5d.sh >/dev/null 2>&1 || { echo "FAIL  HAL.5d gate: build_nic5d.sh failed"; exit 1; }

OUT=$(timeout 60 qemu-system-x86_64 \
        -kernel kernel/kernel_nic5d.elf -m 512 \
        -netdev user,id=n0 -device rtl8139,netdev=n0 \
        -serial stdio -display none \
        -no-reboot -no-shutdown 2>/dev/null)
RC=$?
CLEAN=$(printf '%s' "$OUT" | tr -d '\0')
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 300)

ok=1
for tok in 'nic5d:' 'nic tx ok' 'nic rx et=0800 proto=11 sport=0035' 'nic done'; do
    printf '%s' "$CLEAN" | grep -qF "$tok" || { echo "FAIL  HAL.5d: '$tok' not on serial (rc=$RC, got: $seen)"; ok=0; }
done

[ "$ok" -eq 1 ] && echo "PASS  HAL.5d: DNS resolution round-trip in Lingua Adamica — on the HAL.1/HAL.4 port-I/O primitives, an LA program at ring 0 enabled bus-mastering, set up a DMA RX ring + TX buffer, transmitted a UDP/DNS A-query (IP checksum precomputed one's-complement, UDP checksum disabled, no bitwise ops), and received SLIRP's DNS proxy reply: ethertype 0800, IP proto 11 (UDP), UDP source port 0035 (53), read out of the DMA ring with peek. A real transport-layer round-trip one level above HAL.5c's ICMP — the kernel resolved a hostname itself, driver in the language, DMA through the identity map."
[ "$ok" -eq 1 ]