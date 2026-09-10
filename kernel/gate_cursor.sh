#!/usr/bin/env bash
# LogOS HAL.4h gate — a MOUSE CURSOR SPRITE on the framebuffer: input x display.
# Boot the fused framebuffer+mouse kernel, inject rightward motion via the QEMU
# monitor, and assert the LA driver brought up BOTH devices, drove a cursor from
# the mouse, drew a sprite AT that cursor on the real LFB, and read it back:
#   - "fb lfb=..."  — the framebuffer came up (PCI-scanned VGA, VBE mode set);
#   - "cur X Y"      — the cursor accumulated from mouse packets; X>100 proves the
#                      injected RIGHTWARD motion actually moved it off the origin,
#                      and 72<=X<=180 / 72<=Y<=180 proves the clamp held;
#   - "sp 255"       — the RED byte read BACK from the sprite's centre pixel is
#                      255: the 8x8 sprite was really drawn AT the cursor on the
#                      LFB (peek-verified, no screendump);
#   - "off 0"        — the RED byte at a fixed far control pixel stayed 0: the
#                      sprite is localised, not a runaway fill;
#   - exit 33.
# So mouse input -> a clamped cursor -> a sprite painted at that cursor on real
# framebuffer memory, all in Lingua Adamica at ring 0, verified by peek-back.
# BUILD IS SLOW (~11 min: native_codegen3 on the fused program). Skips if QEMU
# is absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  HAL.4h cursor gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_cursor.sh >/dev/null 2>&1 || { echo "FAIL  HAL.4h gate: build_cursor.sh failed"; exit 1; }

OUTF=$(mktemp)
# Net rightward motion across the 4 read packets so the cursor lands well right
# of the 100 origin; the click gives two more packets so the bounded reader
# never starves.
{ sleep 2
  echo "mouse_move 40 0"; sleep 0.4
  echo "mouse_move 30 0"; sleep 0.4
  echo "mouse_button 1";  sleep 0.4
  echo "mouse_button 0";  sleep 0.4
  echo "mouse_move 10 0"; sleep 0.4
  sleep 1
} | timeout 45 qemu-system-x86_64 \
        -kernel kernel/kernel_cursor.elf -m 512 \
        -serial "file:$OUTF" -monitor stdio -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown >/dev/null 2>&1
RC=$?
OUT=$(tr -d '\0' < "$OUTF"); rm -f "$OUTF"
seen=$(printf '%s' "$OUT" | tr '\n' ' ' | head -c 300)

ok=1
printf '%s' "$OUT" | grep -qE '^fb lfb=' || { echo "FAIL  HAL.4h: framebuffer never came up ('fb lfb=' absent) (rc=$RC, got: $seen)"; ok=0; }

CUR=$(printf '%s' "$OUT" | grep -E '^cur -?[0-9]+ -?[0-9]+$' | tail -1)
if [ -z "$CUR" ]; then
    echo "FAIL  HAL.4h: no 'cur X Y' line — a packet starved or MAIN exited early (rc=$RC, got: $seen)"; ok=0
else
    CX=$(printf '%s' "$CUR" | awk '{print $2}')
    CY=$(printf '%s' "$CUR" | awk '{print $3}')
    [ "$CX" -gt 100 ] || { echo "FAIL  HAL.4h: cursor did not move right of origin (x=$CX) — input never reached the cursor ($CUR)"; ok=0; }
    if [ "$CX" -lt 72 ] || [ "$CX" -gt 180 ] || [ "$CY" -lt 72 ] || [ "$CY" -gt 180 ]; then
        echo "FAIL  HAL.4h: cursor escaped the [72,180] clamp ($CUR)"; ok=0
    fi
fi

SP=$(printf '%s' "$OUT" | grep -E '^sp [0-9]+$' | tail -1 | awk '{print $2}')
[ "${SP:-x}" = "255" ] || { echo "FAIL  HAL.4h: sprite pixel read back $SP, not 255 — the sprite was not drawn at the cursor ($seen)"; ok=0; }

OFF=$(printf '%s' "$OUT" | grep -E '^off [0-9]+$' | tail -1 | awk '{print $2}')
[ "${OFF:-x}" = "0" ] || { echo "FAIL  HAL.4h: control pixel read back $OFF, not 0 — sprite bled to a far pixel (runaway fill) ($seen)"; ok=0; }

[ "$RC" -eq 33 ] || { echo "FAIL  HAL.4h: exit code != 33 (got $RC; $seen)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  HAL.4h: mouse cursor sprite on the framebuffer in Lingua Adamica — an LA program at ring 0 brought up BOTH the LFB (PCI+VBE) and the PS/2 mouse, drove a clamped cursor from mouse packets (moved to x=$CX off the 100 origin), drew an 8x8 sprite AT the cursor (centre pixel reads back RED=255), and a far control pixel stayed 0 (localised), exit 33. The first input x display slice, bounded and peek-verified."
[ "$ok" -eq 1 ]
