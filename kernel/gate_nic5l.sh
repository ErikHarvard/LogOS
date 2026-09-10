#!/usr/bin/env bash
# LogOS HAL.5l gate — the IHL-general DNS requester (generalises HAL.5d).
#
# 5d resolved a hostname through SLIRP's DNS proxy and read the reply, but
# pulled the UDP source port and the DNS answer count from the FIXED frame
# offsets 34/35 and 48/49 — right only for a 20-byte IP header. Its gate could
# not see that: SLIRP only ever emits IHL=5. So this gate runs the SAME kernel
# against BOTH header shapes, using two DIFFERENT netdevs, because no single one
# can produce both:
#
#   case 1  -netdev user (SLIRP)  — the REAL DNS round-trip 5d gated, IHL=5.
#           Kept so the generalisation cannot silently cost us real-network
#           interop; this is the case that proves we still talk to a real stack.
#   case 2  -netdev socket + ping_harness.py `dnsreply6` — an INJECTED DNS
#           response behind a 24-byte header (IHL=6), which SLIRP cannot
#           produce. HAL.5d's own kernel reports sport=0101 here (it reads the
#           IP OPTION bytes as the port); 5l reports sport=0035.
#
# ★ HONEST LIMIT — THIS GATE IS SINGLE-WITNESS, unlike HAL.5i/5j. Those kernels
# TRANSMIT a reply, so an independent external validator could confirm the parse
# from outside. 5l transmits nothing in response: the RX parse is observable
# ONLY on the guest's own serial. The harness confirms it saw the guest's
# outbound DNS QUERY — real external evidence that the kernel ran and
# transmitted — but that does NOT corroborate how it parsed what came back. A
# weaker guarantee, stated rather than blurred into the stronger one 5i/5j earn.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then echo "SKIP  HAL.5l: qemu absent"; exit 0; fi
if ! command -v python3 >/dev/null 2>&1; then echo "SKIP  HAL.5l: python3 absent"; exit 0; fi

./kernel/build_nic5l.sh >/dev/null 2>&1 || { echo "FAIL  HAL.5l gate: build_nic5l.sh failed"; exit 1; }

ok=1

# ---- case 1: the real SLIRP DNS round-trip (IHL=5) ------------------------
# NOTE: this case needs host egress (it is a live lookup through SLIRP's proxy),
# the same dependency HAL.5d's own gate carries.
OUT=$(timeout 60 qemu-system-x86_64 \
        -kernel kernel/kernel_nic5l.elf -m 512 \
        -netdev user,id=n0 -device rtl8139,netdev=n0 \
        -serial stdio -display none -no-reboot -no-shutdown 2>/dev/null)
CLEAN=$(printf '%s' "$OUT" | tr -d '\0')
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 300)
# NOTE: no anc= assertion here. HAL.5d's own gate deliberately asserts only
# sport, because case 1 is a LIVE DNS lookup and the number of A records
# returned is not ours to fix — pinning it would manufacture a flaky false RED
# on a perfectly good kernel. anc IS asserted in case 2, where the response is
# injected and its answer count is ours to choose.
for tok in 'nic5l:' 'nic tx ok' 'nic rx ihl=05 et=0800 proto=11 sport=0035' 'nic done'; do
    printf '%s' "$CLEAN" | grep -qF "$tok" \
        || { echo "FAIL  HAL.5l [slirp ihl=5]: '$tok' not on serial (got: $seen)"; ok=0; }
done

# ---- case 2: an INJECTED IHL=6 DNS response -------------------------------
PORT=12405
SER=$(mktemp); PLOG=$(mktemp)
# ★ THE HARNESS LISTENS AND QEMU CONNECTS — see gate_nic5k.sh for the full
# reasoning. A REQUESTER kernel transmits within the first few hundred ms of
# boot, and QEMU drops frames sent while no peer is attached, so a listen-side
# harness sees nothing through no fault of the kernel. 5k failed exactly that
# way on its first run while its serial showed a correct parse. Binding before
# QEMU starts removes the race by construction rather than by timing luck.
python3 kernel/ping_harness.py dnsreply6 $PORT 8 >"$PLOG" 2>&1 &
PY=$!
for _ in $(seq 200); do grep -q "PINGER: listening" "$PLOG" && break; sleep 0.05; done
grep -q "PINGER: listening" "$PLOG" || { echo "FAIL  HAL.5l: harness never bound to $PORT"; ok=0; }
qemu-system-x86_64 -kernel kernel/kernel_nic5l.elf -m 512 \
  -netdev socket,id=n0,connect=127.0.0.1:$PORT -device rtl8139,netdev=n0 \
  -serial file:"$SER" -display none -no-reboot -no-shutdown >/dev/null 2>&1 &
QP=$!
wait $PY; PRC=$?
sleep 0.3; kill $QP 2>/dev/null; wait 2>/dev/null
CLEAN=$(tr -d '\0' < "$SER")
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 300)
for tok in 'nic5l:' 'nic tx ok' 'nic rx ihl=06 et=0800 proto=11 sport=0035 anc=0002' 'nic done'; do
    printf '%s' "$CLEAN" | grep -qF "$tok" \
        || { echo "FAIL  HAL.5l [inject ihl=6]: '$tok' not on serial (got: $seen)"; ok=0; }
done
# the harness's own (weaker) witness: it saw the guest transmit its query
if [ "$PRC" -ne 0 ]; then
    echo "FAIL  HAL.5l [inject ihl=6]: harness never saw a frame from the guest ($(tr '\n' ' ' <"$PLOG" | head -c 200))"; ok=0
fi
rm -f "$SER" "$PLOG"

[ "$ok" -eq 1 ] && echo "PASS  HAL.5l: an IHL-GENERAL DNS requester in Lingua Adamica — the same LA kernel read the UDP source port AND the DNS answer count correctly out of BOTH a real SLIRP DNS response (20-byte header) and an injected response behind a 24-byte header, by READING the IHL nibble (u = 14 + 4*ihl; mod and mul, no bitwise ops) instead of assuming frame offsets 34/35 and 48/49. HAL.5d reports sport=0101 on the second case, reading the IP option bytes as the port. Single-witness by necessity — this kernel sends no reply, so the RX parse is observable only on its own serial."

[ "$ok" -eq 1 ]
