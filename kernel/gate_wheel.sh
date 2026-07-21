#!/usr/bin/env bash
# LogOS HAL.2e gate — the SCROLL WHEEL: an IntelliMouse (IMPS-2) driver in LA.
# Boot the wheel kernel, inject wheel motion via the QEMU monitor
# (mouse_move dx dy DZ), and assert the LA driver performed the 200/100/80
# magic knock and decoded the 4-byte packets' Z axis:
#   - "whl:"      — the driver started (aux enabled, knock sent, reporting on);
#   - "wheel 1"    — wz=1: at least one packet carried a NON-ZERO wheel delta,
#                    which can ONLY appear if the mouse switched to IntelliMouse
#                    mode (4-byte packets) — i.e. the knock landed. Without it the
#                    packets stay 3 bytes and the 4-byte read would desync, never
#                    cleanly yielding a non-zero z on a pure wheel event.
#   - exit 33.
# QEMU only queues packets after 0xF4 and only sends a Z byte after the knock,
# so a pass proves the whole bring-up ran. Skips (rc 0) if QEMU is absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  HAL.2e wheel gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_wheel.sh >/dev/null 2>&1 || { echo "FAIL  HAL.2e gate: build_wheel.sh failed"; exit 1; }

OUTF=$(mktemp)
# Wheel up, wheel down, then plain moves — > 4 events so the bounded reader
# never starves; the wheel events are what must surface a non-zero z.
{ sleep 2
  echo "mouse_move 0 0 1";  sleep 0.4
  echo "mouse_move 0 0 -1"; sleep 0.4
  echo "mouse_move 0 0 1";  sleep 0.4
  echo "mouse_move 10 0";   sleep 0.4
  echo "mouse_move -10 0";  sleep 0.4
  sleep 1
} | timeout 40 qemu-system-x86_64 \
        -kernel kernel/kernel_wheel.elf -m 256 \
        -serial "file:$OUTF" -monitor stdio -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown >/dev/null 2>&1
RC=$?
OUT=$(tr -d '\0' < "$OUTF"); rm -f "$OUTF"
seen=$(printf '%s' "$OUT" | tr '\n' ' ' | head -c 300)

ok=1
printf '%s' "$OUT" | grep -qF 'whl:' || { echo "FAIL  HAL.2e: 'whl:' not on serial (rc=$RC, got: $seen)"; ok=0; }

WL=$(printf '%s' "$OUT" | grep -E '^wheel [0-9]+$' | tail -1)
if [ -z "$WL" ]; then
    echo "FAIL  HAL.2e: no 'wheel N' summary — the reader starved or MAIN exited early (rc=$RC, got: $seen)"; ok=0
else
    WZ=$(printf '%s' "$WL" | awk '{print $2}')
    [ "$WZ" -eq 1 ] || { echo "FAIL  HAL.2e: no non-zero wheel delta (wz=$WZ) — the IntelliMouse knock did not take, packets stayed 3-byte ($WL)"; ok=0; }
fi

[ "$RC" -eq 33 ] || { echo "FAIL  HAL.2e: exit code != 33 (got $RC; $seen)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  HAL.2e: scroll wheel (IntelliMouse/IMPS-2) in Lingua Adamica — the LA driver performed the 200/100/80 sample-rate knock (0xF3 each, via 0xD4), the mouse switched to 4-byte packets, and a non-zero wheel Z delta was decoded off the fourth byte, exit 33. The pointer's scroll axis, driver written in the language itself, bounded and correct."
[ "$ok" -eq 1 ]
