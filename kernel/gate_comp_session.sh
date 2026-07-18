#!/usr/bin/env bash
# LogOS HAL.4d gate — the INTERACTIVE compositor session on the metal.
# Boot the metal compositor loop, inject keystrokes through the QEMU monitor, and
# assert from the serial line that each keypress drove a real recomposition +
# present of a NEW frame (Theourgia's inner loop, on bare metal, no Linux DRM/evdev):
#   - "session ready"       — the compositor armed (mode set, initial frame shown);
#   - "session ov=0,255,0"  — the INITIAL probe pixel (200,150) is B's green
#                             (window B overlaps the probe at its start position);
#   - "session bx=300"      — after 3× 'd' (right, +40 each: 180->220->260->300),
#                             window B has moved: each keystroke was polled off the
#                             i8042, decoded, and moved the window;
#   - "session ov=0,0,255"  — after B moved off the probe, the pixel there is now
#                             window A's red showing THROUGH — i.e. the frame was
#                             genuinely re-composed (z-ordered) and re-presented,
#                             not a static scene or a bare counter;
#   - "session done"        — ENTER ended the loop;
#   - exit 33               — MAIN returned -> exit(0) -> isa-debug-exit.
# The probe transition green->red is the load-bearing witness: a static frame, or a
# loop that moved a variable without re-presenting, would leave it green and FAIL.
# Polling keyboard (no IRQ) on HAL.4c's straight-line boot. Skips (rc 0) if QEMU absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  HAL.4d compositor-session gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_comp_session.sh >/dev/null 2>&1 || { echo "FAIL  HAL.4d gate: build_comp_session.sh failed"; exit 1; }

SERF=$(mktemp)
# Boot, wait for the loop to arm, then move window B right 3× and press ENTER.
{ for _ in $(seq 1 60); do grep -q 'session ready' "$SERF" 2>/dev/null && break; sleep 0.5; done
  for _ in 1 2 3; do echo "sendkey d"; sleep 0.6; done
  sleep 0.4; echo "sendkey ret"
  sleep 1.5
} | timeout 60 qemu-system-x86_64 \
        -kernel kernel/kernel_comp_session.elf -m 512 \
        -vga std -monitor stdio -serial "file:$SERF" -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown >/dev/null 2>&1
RC=$?
SER=$(tr -d '\0' < "$SERF"); rm -f "$SERF"
seen=$(printf '%s' "$SER" | tr '\n' ' ' | head -c 320)

ok=1
for tok in 'session ready' 'session ov=0,255,0' 'session bx=300' 'session ov=0,0,255' 'session done'; do
    printf '%s' "$SER" | grep -qF "$tok" || { echo "FAIL  HAL.4d: '$tok' not on serial (rc=$RC, got: $seen)"; ok=0; }
done
[ "$RC" -eq 33 ] || { echo "FAIL  HAL.4d: exit code != 33 (got $RC; got: $seen)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  HAL.4d: the interactive compositor session on the metal — the kernel polls the PS/2 keyboard, and each keystroke moves window B, RE-COMPOSES the z-ordered frame off-screen, and RE-PRESENTS it in one memcpy; the fixed probe pixel goes green->red as B slides off it (window A showing through — a real re-composite, not a static scene), and ENTER exits clean. Theourgia's inner loop, driven by real input, on bare metal — no Linux DRM/evdev."
[ "$ok" -eq 1 ]
