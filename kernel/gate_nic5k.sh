#!/usr/bin/env bash
# LogOS HAL.5k gate — the IHL-general ICMP echo REQUESTER (generalises HAL.5c).
#
# 5c pinged the SLIRP gateway and read the reply, but pulled the ICMP type from
# the FIXED frame offset 34 — right only for a 20-byte IP header. Its gate could
# not see that: SLIRP only ever emits IHL=5. So this gate runs the SAME kernel
# against BOTH header shapes, using two DIFFERENT netdevs, because no single one
# can produce both:
#
#   case 1  -netdev user (SLIRP)  — the REAL round-trip 5c gated, IHL=5.
#           Kept so the generalisation cannot silently cost us real-network
#           interop; this is the case that proves we still talk to a real stack.
#   case 2  -netdev socket + ping_harness.py `icmpreply6` — an INJECTED ICMP
#           echo reply behind a 24-byte header (IHL=6), which SLIRP cannot
#           produce. 5c's own kernel reports icmp=01 here (it reads the first IP
#           OPTION byte as the type); 5k reports icmp=00.
#
# ★ HONEST LIMIT — THIS GATE IS SINGLE-WITNESS, unlike HAL.5i/5j. Those kernels
# TRANSMIT a reply, so an independent external validator could confirm the parse
# from outside. 5k transmits nothing in response: the parse is observable ONLY
# on the guest's own serial. The harness confirms it saw the guest's outbound
# request (so the kernel demonstrably ran and TXed), but that does NOT
# independently corroborate the RX parse. A weaker guarantee, stated rather than
# blurred into the stronger one the 5i/5j gates earn.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then echo "SKIP  HAL.5k: qemu absent"; exit 0; fi
if ! command -v python3 >/dev/null 2>&1; then echo "SKIP  HAL.5k: python3 absent"; exit 0; fi

./kernel/build_nic5k.sh >/dev/null 2>&1 || { echo "FAIL  HAL.5k gate: build_nic5k.sh failed"; exit 1; }

ok=1

# ---- case 1: the real SLIRP round-trip (IHL=5) ----------------------------
OUT=$(timeout 60 qemu-system-x86_64 \
        -kernel kernel/kernel_nic5k.elf -m 512 \
        -netdev user,id=n0 -device rtl8139,netdev=n0 \
        -serial stdio -display none -no-reboot -no-shutdown 2>/dev/null)
CLEAN=$(printf '%s' "$OUT" | tr -d '\0')
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 300)
for tok in 'nic5k:' 'nic tx ok' 'nic rx ihl=05 et=0800 proto=01 icmp=00' 'nic done'; do
    printf '%s' "$CLEAN" | grep -qF "$tok" \
        || { echo "FAIL  HAL.5k [slirp ihl=5]: '$tok' not on serial (got: $seen)"; ok=0; }
done

# ---- case 2: an INJECTED IHL=6 echo reply --------------------------------
PORT=12404
SER=$(mktemp); PLOG=$(mktemp)
# ★ THE HARNESS LISTENS AND QEMU CONNECTS — the reverse of the responder gates,
# and not a stylistic choice. A REQUESTER kernel transmits its ARP and request
# within the first few hundred ms of boot, and QEMU drops frames transmitted
# while no peer is attached; a listen-side harness therefore sees nothing
# through no fault of the kernel. That is not hypothetical — it is exactly how
# this gate failed on its first run, with the guest's serial showing a perfectly
# correct ihl=06 parse. Starting the harness first and waiting until it is bound
# removes the race by construction rather than by timing luck.
python3 kernel/ping_harness.py icmpreply6 $PORT 8 >"$PLOG" 2>&1 &
PY=$!
for _ in $(seq 200); do grep -q "PINGER: listening" "$PLOG" && break; sleep 0.05; done
grep -q "PINGER: listening" "$PLOG" || { echo "FAIL  HAL.5k: harness never bound to $PORT"; ok=0; }
qemu-system-x86_64 -kernel kernel/kernel_nic5k.elf -m 512 \
  -netdev socket,id=n0,connect=127.0.0.1:$PORT -device rtl8139,netdev=n0 \
  -serial file:"$SER" -display none -no-reboot -no-shutdown >/dev/null 2>&1 &
QP=$!
wait $PY; PRC=$?
sleep 0.3; kill $QP 2>/dev/null; wait 2>/dev/null
CLEAN=$(tr -d '\0' < "$SER")
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 300)
for tok in 'nic5k:' 'nic tx ok' 'nic rx ihl=06 et=0800 proto=01 icmp=00' 'nic done'; do
    printf '%s' "$CLEAN" | grep -qF "$tok" \
        || { echo "FAIL  HAL.5k [inject ihl=6]: '$tok' not on serial (got: $seen)"; ok=0; }
done
# the harness's own (weaker) witness: it saw the guest transmit at all
if [ "$PRC" -ne 0 ]; then
    echo "FAIL  HAL.5k [inject ihl=6]: harness never saw a frame from the guest ($(tr '\n' ' ' <"$PLOG" | head -c 200))"; ok=0
fi
rm -f "$SER" "$PLOG"

[ "$ok" -eq 1 ] && echo "PASS  HAL.5k: an IHL-GENERAL ICMP echo requester in Lingua Adamica — the same LA kernel read the ICMP type correctly out of BOTH a real SLIRP echo reply (20-byte header) and an injected reply behind a 24-byte header, by READING the IHL nibble (u = 14 + 4*ihl; mod and mul, no bitwise ops) instead of assuming frame offset 34. HAL.5c reports icmp=01 on the second case, reading the first IP option byte as the type. Single-witness by necessity — this kernel sends no reply, so the parse is observable only on its own serial."

[ "$ok" -eq 1 ]
