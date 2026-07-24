#!/usr/bin/env bash
# LogOS HAL.5j gate — an IHL-GENERAL ICMP echo responder over RTL8139, in LA.
#
# The ICMP twin of gate_nic5i.sh. HAL.5g answered a ping sent TO us but wrote
# the reply's ICMP fields at the FIXED frame offsets 34/36/37, right only for a
# 20-byte IP header (IHL=5) -- and its gate could not see that, because the
# harness only ever sent IHL=5. So this gate runs the SAME kernel TWICE:
#
#   ping     -> IHL=5, a 20-byte header  (the case 5g already gated)
#   pingopt  -> IHL=6, a 24-byte header with a 4-byte NOP/EOL option block,
#               so the ICMP header starts at frame byte 38 instead of 34
#
# ★ THE SECOND RUN IS WHAT MAKES THIS A CHECK: HAL.5g's own kernel passes the
# first and FAILS the second. Confirmed before this kernel was built, by
# emulating both transforms against the harness's real validator.
#
# Each run asserts BOTH the guest's account and the sender's:
#   - "nic5j:" / "nic setup ok"                    — driver started + set up;
#   - "nic icmp req ihl=NN type=08 from=<mac>"     — ★ ihl is READ FROM THE
#                  PACKET, so the serial proves the header was parsed, not
#                  guessed; type 8 = echo request; MAC read out of the DMA ring;
#   - "nic icmp reply sent" / "nic done"           — reply built + transmitted;
#   - sender exit 0                                — the pinger independently
#                  verified the reply IN FULL: IPv4/ICMP, addresses swapped
#                  back, type 0, and the ICMP CHECKSUM SUMS TO 0xffff -- so the
#                  delta-with-end-around-carry math is proven, not just offsets.
# Fully self-contained (the pinger is the only L2 peer), deterministic.
# Needs -m 512 + python3. Skips (rc 0) if QEMU/python3 absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then echo "SKIP  HAL.5j: qemu absent"; exit 0; fi
if ! command -v python3 >/dev/null 2>&1; then echo "SKIP  HAL.5j: python3 absent"; exit 0; fi

./kernel/build_nic5j.sh >/dev/null 2>&1 || { echo "FAIL  HAL.5j gate: build_nic5j.sh failed"; exit 1; }

ok=1

# run <mode> <expected-ihl-hex> <port>
run_case() {
    local mode="$1" ihl="$2" port="$3"
    local SER PLOG
    SER=$(mktemp); PLOG=$(mktemp)
    qemu-system-x86_64 -kernel kernel/kernel_nic5j.elf -m 512 \
      -netdev socket,id=n0,listen=127.0.0.1:"$port" -device rtl8139,netdev=n0 \
      -serial file:"$SER" -display none -no-reboot -no-shutdown >/dev/null 2>&1 &
    local QP=$!
    python3 kernel/ping_harness.py "$mode" "$port" 8 >"$PLOG" 2>&1
    local PRC=$?
    sleep 0.3; kill $QP 2>/dev/null; wait 2>/dev/null

    local CLEAN seen
    CLEAN=$(tr -d '\0' < "$SER")
    seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 300)
    for tok in 'nic5j:' 'nic setup ok' "nic icmp req ihl=$ihl type=08 from=52550a000202" \
               'nic icmp reply sent' 'nic done'; do
        printf '%s' "$CLEAN" | grep -qF "$tok" \
            || { echo "FAIL  HAL.5j [$mode]: '$tok' not on guest serial (got: $seen)"; ok=0; }
    done
    if [ "$PRC" -ne 0 ]; then
        echo "FAIL  HAL.5j [$mode]: pinger got no valid echo reply ($(tr '\n' ' ' <"$PLOG" | head -c 200))"; ok=0
    fi
    rm -f "$SER" "$PLOG"
}

run_case ping    05 12402    # IHL=5 — must not regress what 5g gated
run_case pingopt 06 12403    # IHL=6 — the new capability; 5g's kernel fails here

[ "$ok" -eq 1 ] && echo "PASS  HAL.5j: an IHL-GENERAL ICMP echo responder in Lingua Adamica — the same LA kernel answered a ping behind BOTH a 20-byte and a 24-byte IPv4 header, locating the ICMP header by READING the IHL nibble out of the packet (u = 14 + 4*ihl; mod and mul, no bitwise ops) instead of assuming offset 34. Each run proved twice over: the guest's serial reported the ihl it actually parsed (ihl=05 / ihl=06) with type=08 and the requester's MAC read from the DMA ring, and the pinger independently verified the reply in full — addresses swapped back, type 0, and the ICMP checksum summing to 0xffff, so the delta-with-end-around-carry math holds at both header lengths. The ICMP twin of HAL.5i."

[ "$ok" -eq 1 ]
