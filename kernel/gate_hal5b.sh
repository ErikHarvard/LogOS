#!/usr/bin/env bash
# LogOS HAL.5b gate — a NIC driver in Lingua Adamica sends and receives a real
# packet over the wire (and DMAs to do it). Attach an RTL8139 on a SLIRP user
# netdev (whose virtual gateway 10.0.2.2 answers ARP), boot the NIC kernel, and
# assert the LA driver did a full round-trip off the metal:
#   - "nic5b:"    — the driver started;
#   - "nic tx ok" — it enabled PCI bus-mastering, set up an RX ring + TX buffer,
#                   poked a broadcast ARP request, and the card DMA'd it out (TOK);
#   - "nic rx et=0806 op=02 sha=52:55..." — it received the gateway's ARP REPLY:
#                   ethertype 0x0806, ARP opcode 2, sender MAC read straight out
#                   of the DMA ring with peek (SLIRP's 52:55:0a:00:02:02);
#   - "nic done"  — it finished;
#   - exit 33     — clean exit via isa-debug-exit.
# So: on the HAL.1/HAL.4 port-I/O primitives, an LA program at ring 0 drove a
# real NIC through a bus-master DMA send AND receive — the kernel's first packet
# on the wire, driver in the language itself. Needs -m 512 (DMA buffers at
# 256 MiB). Skips (rc 0) if QEMU is absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  HAL.5b NIC gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_hal5b.sh >/dev/null 2>&1 || { echo "FAIL  HAL.5b gate: build_hal5b.sh failed"; exit 1; }

OUT=$(timeout 60 qemu-system-x86_64 \
        -kernel kernel/kernel_hal5b.elf -m 512 \
        -netdev user,id=n0 -device rtl8139,netdev=n0 \
        -serial stdio -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown 2>/dev/null)
RC=$?
CLEAN=$(printf '%s' "$OUT" | tr -d '\0')
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 300)

ok=1
for tok in 'nic5b:' 'nic tx ok' 'nic rx et=0806 op=02' 'sha=52:55' 'nic done'; do
    printf '%s' "$CLEAN" | grep -qF "$tok" || { echo "FAIL  HAL.5b: '$tok' not on serial (rc=$RC, got: $seen)"; ok=0; }
done
[ "$RC" -eq 33 ] || { echo "FAIL  HAL.5b: exit code != 33 (got $RC; got: $seen)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  HAL.5b: NIC send+receive in Lingua Adamica — on the HAL.1/HAL.4 port-I/O primitives, an LA program at ring 0 enabled bus-mastering, set up a DMA RX ring + TX buffer, transmitted a broadcast ARP request, and received the SLIRP gateway's ARP reply (ethertype 0806, opcode 2, sender MAC read out of the DMA ring with peek). A real network round-trip, driver in the language, DMA reached through the identity map. The kernel's first packet on the wire."
[ "$ok" -eq 1 ]
