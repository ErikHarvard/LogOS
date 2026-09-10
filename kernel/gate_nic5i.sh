#!/usr/bin/env bash
# LogOS HAL.5i gate — an IHL-GENERAL UDP echo responder over RTL8139, in LA.
#
# 5h answered a UDP datagram but read the UDP header at the FIXED frame offset
# 34, which is right only for a 20-byte IP header (IHL=5). Its gate could not
# see that, because the harness only ever sent IHL=5. So this gate runs the SAME
# kernel TWICE against two different header shapes:
#
#   udp     -> IHL=5, a 20-byte header  (the classic case 5h already gated)
#   udpopt  -> IHL=6, a 24-byte header with a 4-byte NOP/EOL option block,
#              so the UDP header starts at frame byte 38 instead of 34
#
# ★ THE SECOND RUN IS WHAT MAKES THIS A CHECK RATHER THAN A CEREMONY: HAL.5h's
# own kernel PASSES the first and FAILS the second. That was confirmed before
# this kernel was ever built, by emulating both transforms against the harness's
# real validator -- a check that cannot fail is not a check.
#
# Each run asserts BOTH the guest's own account (serial) and the sender's:
#   - "nic5i:" / "nic setup ok"              — the driver started + set up;
#   - "nic udp req ihl=NN proto=11 dport=0007" — ★ the ihl field is READ FROM THE
#                    PACKET, so the serial proves the kernel parsed the header
#                    rather than happening to be right; proto 17 = UDP, port 7;
#   - "nic udp reply sent" / "nic done"      — it built + transmitted the reply;
#   - sender exit 0                          — a VALID echo (addresses AND ports
#                    swapped back, PAYLOAD returned byte-for-byte) came back --
#                    the independent, end-to-end proof it was well-formed.
# Fully self-contained (the sender is the only L2 peer), deterministic.
# Needs -m 512 + python3. Skips (rc 0) if QEMU/python3 absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then echo "SKIP  HAL.5i: qemu absent"; exit 0; fi
if ! command -v python3 >/dev/null 2>&1; then echo "SKIP  HAL.5i: python3 absent"; exit 0; fi

./kernel/build_nic5i.sh >/dev/null 2>&1 || { echo "FAIL  HAL.5i gate: build_nic5i.sh failed"; exit 1; }

ok=1

# run <mode> <expected-ihl-hex> <port>
run_case() {
    local mode="$1" ihl="$2" port="$3"
    local SER PLOG
    SER=$(mktemp); PLOG=$(mktemp)
    qemu-system-x86_64 -kernel kernel/kernel_nic5i.elf -m 512 \
      -netdev socket,id=n0,listen=127.0.0.1:"$port" -device rtl8139,netdev=n0 \
      -serial file:"$SER" -display none -no-reboot -no-shutdown >/dev/null 2>&1 &
    local QP=$!
    python3 kernel/ping_harness.py "$mode" "$port" 8 >"$PLOG" 2>&1
    local PRC=$?
    sleep 0.3; kill $QP 2>/dev/null; wait 2>/dev/null

    local CLEAN seen
    CLEAN=$(tr -d '\0' < "$SER")
    seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 300)
    for tok in 'nic5i:' 'nic setup ok' "nic udp req ihl=$ihl proto=11 dport=0007" \
               'nic udp reply sent' 'nic done'; do
        printf '%s' "$CLEAN" | grep -qF "$tok" \
            || { echo "FAIL  HAL.5i [$mode]: '$tok' not on guest serial (got: $seen)"; ok=0; }
    done
    if [ "$PRC" -ne 0 ]; then
        echo "FAIL  HAL.5i [$mode]: sender got no valid UDP echo ($(tr '\n' ' ' <"$PLOG" | head -c 200))"; ok=0
    fi
    rm -f "$SER" "$PLOG"
}

run_case udp    05 12398    # IHL=5 — must not regress what 5h gated
run_case udpopt 06 12399    # IHL=6 — the new capability; 5h's kernel fails here

[ "$ok" -eq 1 ] && echo "PASS  HAL.5i: an IHL-GENERAL UDP echo responder in Lingua Adamica — the same LA kernel answered a UDP datagram behind BOTH a 20-byte and a 24-byte IPv4 header, locating the UDP header by READING the IHL nibble out of the packet (u = 14 + 4*ihl; mod and mul, no bitwise ops) instead of assuming offset 34. Each run proved twice over: the guest's serial reported the ihl it actually parsed (ihl=05 / ihl=06) with proto=11 dport=0007, and the external sender independently verified the echo — addresses and ports swapped back, payload byte-for-byte. Removes the fixed-offset assumption HAL.5h's gate could not see."

[ "$ok" -eq 1 ]
