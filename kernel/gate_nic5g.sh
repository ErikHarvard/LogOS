#!/usr/bin/env bash
# LogOS HAL.5g gate — an ICMP echo RESPONDER over RTL8139, in LA.
# The receive-side twin of 5c. SLIRP won't deliver an inbound ICMP, so the guest
# runs on a QEMU `socket` netdev and kernel/ping_harness.py is the sole L2 peer:
# it unicasts an ICMP echo REQUEST to the guest and confirms an echo REPLY comes
# back. Assert BOTH the guest's own account (serial) and the pinger's result:
#   - "nic5g:" / "nic setup ok"                  — the driver started + set up;
#   - "nic icmp req type=08 from=52550a000202"   — it received the echo REQUEST
#                    (icmp type 8) and read the pinger's MAC out of the DMA ring;
#   - "nic icmp reply sent" / "nic done"         — it built + transmitted the reply;
#   - pinger exit 0 ("ECHO REPLY RECEIVED")      — a VALID ICMP echo reply (type
#                    0, correct checksum) actually reached the pinger — the
#                    independent, end-to-end proof the response was well-formed.
# Fully self-contained (no host egress, the pinger is the only peer),
# deterministic. Needs -m 512 + python3. Skips (rc 0) if QEMU/python3 absent.
set -uo pipefail
cd "$(dirname "$0")/.."
PORT=12395

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then echo "SKIP  HAL.5g: qemu absent"; exit 0; fi
if ! command -v python3 >/dev/null 2>&1; then echo "SKIP  HAL.5g: python3 absent"; exit 0; fi

./kernel/build_nic5g.sh >/dev/null 2>&1 || { echo "FAIL  HAL.5g gate: build_nic5g.sh failed"; exit 1; }

SER=$(mktemp); PLOG=$(mktemp)
qemu-system-x86_64 -kernel kernel/kernel_nic5g.elf -m 512 \
  -netdev socket,id=n0,listen=127.0.0.1:$PORT -device rtl8139,netdev=n0 \
  -serial file:"$SER" -display none -no-reboot -no-shutdown >/dev/null 2>&1 &
QP=$!
python3 kernel/ping_harness.py ping $PORT 8 >"$PLOG" 2>&1
PRC=$?
sleep 0.3; kill $QP 2>/dev/null; wait 2>/dev/null

CLEAN=$(tr -d '\0' < "$SER")
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 300)
ok=1
for tok in 'nic5g:' 'nic setup ok' 'nic icmp req type=08 from=52550a000202' 'nic icmp reply sent' 'nic done'; do
    printf '%s' "$CLEAN" | grep -qF "$tok" || { echo "FAIL  HAL.5g: '$tok' not on guest serial (got: $seen)"; ok=0; }
done
if [ "$PRC" -ne 0 ]; then echo "FAIL  HAL.5g: pinger got no valid echo reply ($(tr '\n' ' ' <"$PLOG" | head -c 200))"; ok=0; fi
rm -f "$SER" "$PLOG"

[ "$ok" -eq 1 ] && echo "PASS  HAL.5g: an ICMP echo responder in Lingua Adamica — an external pinger unicast an ICMP echo REQUEST to the LA kernel over a QEMU socket netdev; the kernel at ring 0 received it, read the requester's MAC out of the DMA ring, built the matching ICMP echo REPLY by copying the request and mutating it (swap eth + ip addrs, type 8->0, checksum += 0x0800 with end-around carry, IP checksum unchanged — no bitwise ops), and transmitted it; the pinger received a VALID echo reply back. The receive-side twin of 5c's ping — the kernel answering the network, driver in the language, DMA through the identity map."
[ "$ok" -eq 1 ]