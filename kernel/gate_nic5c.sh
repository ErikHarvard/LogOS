#!/usr/bin/env bash
# LogOS HAL.5c gate — an ICMP echo round-trip (ping) over RTL8139, in LA.
# Give QEMU a user-mode (SLIRP) netdev — its virtual gateway 10.0.2.2 answers
# ICMP echo to itself internally (no host privilege) — boot the NIC kernel, and
# assert the LA driver PINGED the gateway and got the echo reply, one IP layer
# above HAL.5b's ARP:
#   - "nic5c:"     — the driver started;
#   - "nic tx ok"  — it enabled bus-mastering, set up the DMA RX ring + TX
#                    buffer, transmitted the ICMP echo request, and saw TOK;
#   - "nic rx et=0800 proto=01 icmp=00" — it received a reply and read, straight
#                    out of the DMA ring with peek: ethertype 0x0800 (IPv4), IP
#                    protocol 1 (ICMP), ICMP type 0 (ECHO REPLY) — a real ping
#                    answered. Unsigned/ARP decode could not fake all three.
#   - "nic done"   — it finished;
#   - exit != crash (QEMU exits when the kernel returns; we assert on the serial
#     tokens, as HAL.5b does, since the run has no isa-debug-exit code path).
# A real IP round-trip, driver in the language, DMA through the identity map.
# Needs -m 512 (DMA buffers at 256 MiB). Skips (rc 0) if QEMU is absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  HAL.5c NIC gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_nic5c.sh >/dev/null 2>&1 || { echo "FAIL  HAL.5c gate: build_nic5c.sh failed"; exit 1; }

OUT=$(timeout 60 qemu-system-x86_64 \
        -kernel kernel/kernel_nic5c.elf -m 512 \
        -netdev user,id=n0 -device rtl8139,netdev=n0 \
        -serial stdio -display none \
        -no-reboot -no-shutdown 2>/dev/null)
RC=$?
CLEAN=$(printf '%s' "$OUT" | tr -d '\0')
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 300)

ok=1
for tok in 'nic5c:' 'nic tx ok' 'nic rx et=0800 proto=01 icmp=00' 'nic done'; do
    printf '%s' "$CLEAN" | grep -qF "$tok" || { echo "FAIL  HAL.5c: '$tok' not on serial (rc=$RC, got: $seen)"; ok=0; }
done

[ "$ok" -eq 1 ] && echo "PASS  HAL.5c: ICMP echo round-trip in Lingua Adamica — on the HAL.1/HAL.4 port-I/O primitives, an LA program at ring 0 enabled bus-mastering, set up a DMA RX ring + TX buffer, transmitted an ICMP echo REQUEST (IP + ICMP checksums precomputed one's-complement, no bitwise ops), and received the SLIRP gateway's echo REPLY: ethertype 0800, IP proto 01, ICMP type 00, read out of the DMA ring with peek. A real IP-layer round-trip one level above HAL.5b's ARP, driver in the language, DMA through the identity map."
[ "$ok" -eq 1 ]
