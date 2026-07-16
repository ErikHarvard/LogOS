#!/usr/bin/env bash
# LogOS HAL.5a gate — a NIC-discovery driver in Lingua Adamica finds a real
# network card and reads its hardware address. Attach an RTL8139 (with a SLIRP
# user netdev, so 5b's ARP exchange has a wire), boot the NIC kernel, and assert
# the LA driver enumerated it off the metal:
#   - "nic:"                — the driver started;
#   - "nic mac=52:54:00:12:34:56" — it found vendor 0x10EC/device 0x8139 on PCI,
#                             read BAR0 (I/O base), and read IDR0..5 (the MAC);
#   - "nic done"            — it finished;
#   - exit 33               — clean exit via isa-debug-exit.
# 52:54:00:12:34:56 is QEMU's default first-NIC MAC. So: the HAL.1 port-I/O
# primitives let an LA program at ring 0 discover a real network device and read
# its station address — the kernel's first sight of the network, driver written
# in the language itself. Skips (rc 0) if QEMU is absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  HAL.5 NIC gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_hal5.sh >/dev/null 2>&1 || { echo "FAIL  HAL.5 gate: build_hal5.sh failed"; exit 1; }

OUT=$(timeout 30 qemu-system-x86_64 \
        -kernel kernel/kernel_hal5.elf -m 256 \
        -netdev user,id=n0 -device rtl8139,netdev=n0 \
        -serial stdio -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown 2>/dev/null)
RC=$?
CLEAN=$(printf '%s' "$OUT" | tr -d '\0')
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 240)

ok=1
for tok in 'nic:' 'nic mac=52:54:00:12:34:56' 'nic done'; do
    printf '%s' "$CLEAN" | grep -qF "$tok" || { echo "FAIL  HAL.5: '$tok' not on serial (rc=$RC, got: $seen)"; ok=0; }
done
[ "$RC" -eq 33 ] || { echo "FAIL  HAL.5: exit code != 33 (got $RC; got: $seen)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  HAL.5a: NIC discovery in Lingua Adamica — on the HAL.1 port-I/O primitives, an LA program at ring 0 scanned PCI for the RTL8139 (vendor 0x10EC / device 0x8139), read its BAR0 I/O base, and read the station address off IDR0..5. The kernel's first sight of a real network card, driver written in the language."
[ "$ok" -eq 1 ]
