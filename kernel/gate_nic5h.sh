#!/usr/bin/env bash
# LogOS HAL.5h gate — a UDP echo RESPONDER over RTL8139, in LA.
# The transport sibling of 5g. SLIRP won't deliver inbound UDP either, so the
# guest runs on a QEMU `socket` netdev and kernel/ping_harness.py is the sole L2
# peer: it sends a UDP datagram to the guest's echo port and confirms the echo
# comes back. Assert BOTH the guest's own account (serial) and the sender's result:
#   - "nic5h:" / "nic setup ok"                  — the driver started + set up;
#   - "nic udp req proto=11 dport=0007"          — it received a UDP datagram
#                    (IP proto 17) to our echo port (7), read from the DMA ring;
#   - "nic udp reply sent" / "nic done"          — it built + transmitted the reply;
#   - sender exit 0 ("UDP ECHO RECEIVED")        — a VALID echo (addresses+ports
#                    swapped back, PAYLOAD returned byte-for-byte) reached the
#                    sender — the independent, end-to-end proof it was well-formed.
# Fully self-contained (no host egress, the pinger is the only peer),
# deterministic. Needs -m 512 + python3. Skips (rc 0) if QEMU/python3 absent.
set -uo pipefail
cd "$(dirname "$0")/.."
PORT=12397

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then echo "SKIP  HAL.5h: qemu absent"; exit 0; fi
if ! command -v python3 >/dev/null 2>&1; then echo "SKIP  HAL.5h: python3 absent"; exit 0; fi

./kernel/build_nic5h.sh >/dev/null 2>&1 || { echo "FAIL  HAL.5h gate: build_nic5h.sh failed"; exit 1; }

SER=$(mktemp); PLOG=$(mktemp)
qemu-system-x86_64 -kernel kernel/kernel_nic5h.elf -m 512 \
  -netdev socket,id=n0,listen=127.0.0.1:$PORT -device rtl8139,netdev=n0 \
  -serial file:"$SER" -display none -no-reboot -no-shutdown >/dev/null 2>&1 &
QP=$!
python3 kernel/ping_harness.py udp $PORT 8 >"$PLOG" 2>&1
PRC=$?
sleep 0.3; kill $QP 2>/dev/null; wait 2>/dev/null

CLEAN=$(tr -d '\0' < "$SER")
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 300)
ok=1
for tok in 'nic5h:' 'nic setup ok' 'nic udp req proto=11 dport=0007' 'nic udp reply sent' 'nic done'; do
    printf '%s' "$CLEAN" | grep -qF "$tok" || { echo "FAIL  HAL.5h: '$tok' not on guest serial (got: $seen)"; ok=0; }
done
if [ "$PRC" -ne 0 ]; then echo "FAIL  HAL.5h: sender got no valid UDP echo ($(tr '\n' ' ' <"$PLOG" | head -c 200))"; ok=0; fi
rm -f "$SER" "$PLOG"

[ "$ok" -eq 1 ] && echo "PASS  HAL.5h: a UDP echo responder in Lingua Adamica — an external agent sent a UDP datagram to the LA kernel's echo port over a QEMU socket netdev; the kernel at ring 0 received it, built the echo REPLY by copying the request and mutating it (swap eth + ip addrs, swap udp ports, zero the udp checksum, IP checksum unchanged — no bitwise ops), and transmitted it; the sender received a VALID echo back with the PAYLOAD returned byte-for-byte. The transport-layer sibling of 5g's ICMP responder, driver in the language, DMA through the identity map."
[ "$ok" -eq 1 ]