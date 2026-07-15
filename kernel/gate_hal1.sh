#!/usr/bin/env bash
# LogOS HAL.1 gate — the first bare-metal driver, written in Lingua Adamica.
# Boot the PCI-enumeration kernel and assert it walked real PCI config space:
#   - "pci bus0:"    — the driver ran;
#   - "8086:1237"    — the Intel 440FX host bridge (always present on -M pc);
#   - "8086:7000"    — the PIIX3 ISA bridge (always present on -M pc);
#   - "pci scan done"— it scanned all 32 slots and finished;
#   - exit code 33   — clean exit via isa-debug-exit.
# So: the new port-I/O primitives (inb/inl/outb/outl) let an LA program at
# ring 0 drive real hardware — a device driver written in the language itself,
# on a thin asm floor (the pmm.la/paging.la pattern). Skips (rc 0) if QEMU absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  HAL.1 PCI gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_hal1.sh >/dev/null 2>&1 || { echo "FAIL  HAL.1 gate: build_hal1.sh failed"; exit 1; }

OUT=$(timeout 20 qemu-system-x86_64 \
        -kernel kernel/kernel_hal1.elf -m 256 \
        -serial stdio -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown 2>/dev/null)
RC=$?
CLEAN=$(printf '%s' "$OUT" | tr -d '\0')
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 240)

ok=1
for tok in 'pci bus0:' '8086:1237' '8086:7000' 'pci scan done'; do
    printf '%s' "$CLEAN" | grep -qF "$tok" || { echo "FAIL  HAL.1: '$tok' not on serial (rc=$RC, got: $seen)"; ok=0; }
done
[ "$RC" -eq 33 ] || { echo "FAIL  HAL.1: exit code != 33 (got $RC; got: $seen)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  HAL.1: PCI bus enumeration in Lingua Adamica — the new port-I/O primitives (inb/inl/outb/outl) let an LA program at ring 0 walk real PCI config space (0xCF8/0xCFC) on the metal and report every device on bus 0 (host bridge 8086:1237 + ISA bridge 8086:7000 + more). The first bare-metal DEVICE DRIVER written in the language itself — the discovery foundation for disk/NIC/display drivers."
[ "$ok" -eq 1 ]
