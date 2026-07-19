#!/usr/bin/env bash
# LogOS HAL.4e gate — a MOVABLE TEXT WINDOW on the metal (the terminal foundation).
# Boot the metal text-compositor, capture the screen, inject keystrokes through the
# QEMU monitor, and assert from BOTH the serial line and an independent screendump
# that real glyphs were rastered into a window that then MOVED with them:
#   - "text ready"          — the compositor armed (mode set, initial frame shown);
#   - "text on=255,255,255" — probe (201,141) is 'L' row 0 col 0: a WHITE stroke,
#                             so the font really rastered;
#   - "text off=0,255,0"    — probe (222,141) is 'L' row 0 col 7: window B's GREEN
#                             showing through INSIDE the same text cell, so what
#                             drew is a GLYPH SHAPE, not a filled block. Either
#                             probe alone is passable by a broken renderer (a dead
#                             draw leaves both green; a runaway fill leaves both
#                             white) — the PAIR is what pins it;
#   - "text bx=300"         — after 3x 'd' (right, +40 each: 180->220->260->300);
#   - "text on=0,0,255"     — the window AND its text have moved off the probe, so
#                             the pixel there is now window A's RED showing through:
#                             a genuine re-compose + re-present of a NEW frame;
#   - "text done"           — ENTER ended the loop;
#   - exit 33               — MAIN returned -> exit(0) -> isa-debug-exit.
# The screendump is the INDEPENDENT witness (serial peeks the LFB; the screendump
# is what QEMU actually scans out): the initial text bounding box must hold both
# white glyph pixels AND green window pixels — text on a window, not a white bar.
#
# Boots the ALREADY-BUILT ELF and never rebuilds: comp_text.la's native_codegen3
# compile is very slow (superlinear codegen), so the ELF is an out-of-band artifact
# built by kernel/build_hal4e.sh, exactly like the heavy K6/K7 kernels.
# Skips (rc 0) if QEMU is absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  HAL.4e text-window gate: qemu-system-x86_64 not installed"
    exit 0
fi
if [ ! -f kernel/kernel_comp_text.elf ]; then
    echo "SKIP  HAL.4e text-window gate: kernel/kernel_comp_text.elf absent (build it out of band: ./kernel/build_hal4e.sh)"
    exit 0
fi

SERF=$(mktemp); SHOT=$(mktemp -u).ppm
# Boot, wait for the loop to arm, screendump the INITIAL frame (text at rest),
# then move window B right 3x and press ENTER.
{ for _ in $(seq 1 60); do grep -q 'text ready' "$SERF" 2>/dev/null && break; sleep 0.5; done
  echo "screendump $SHOT"; sleep 1.0
  for _ in 1 2 3; do echo "sendkey d"; sleep 0.6; done
  sleep 0.4; echo "sendkey ret"
  sleep 1.5
} | timeout 90 qemu-system-x86_64 \
        -kernel kernel/kernel_comp_text.elf -m 512 \
        -vga std -monitor stdio -serial "file:$SERF" -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown >/dev/null 2>&1
RC=$?
SER=$(tr -d '\0' < "$SERF"); rm -f "$SERF"
seen=$(printf '%s' "$SER" | tr '\n' ' ' | head -c 400)

ok=1
for tok in 'text ready' 'text on=255,255,255' 'text off=0,255,0' 'text bx=300' 'text on=0,0,255' 'text done'; do
    printf '%s' "$SER" | grep -qF "$tok" || { echo "FAIL  HAL.4e: '$tok' not on serial (rc=$RC, got: $seen)"; ok=0; }
done
[ "$RC" -eq 33 ] || { echo "FAIL  HAL.4e: exit code != 33 (got $RC; got: $seen)"; ok=0; }

# Independent screendump witness: the initial text bbox is x 200..320, y 140..164
# (window B at 180,120 + text origin 20,20; 5 chars x 8 px x SCALE 3 = 120 x 24).
if [ -f "$SHOT" ]; then
    python3 - "$SHOT" <<'PY' || ok=0
import sys
d=open(sys.argv[1],'rb').read()
# P6 header: magic, w h, maxval — then binary RGB
parts=d.split(b'\n',3)
w,h=map(int,parts[1].split()); px=parts[3]
def at(x,y):
    i=(y*w+x)*3; return px[i],px[i+1],px[i+2]
white=green=0
for y in range(140,164):
    for x in range(200,320):
        r,g,b=at(x,y)
        if (r,g,b)==(255,255,255): white+=1
        elif (r,g,b)==(0,255,0):   green+=1
if white<200:
    print(f"FAIL  HAL.4e: screendump text bbox has only {white} white pixels (expected >200 glyph pixels)"); sys.exit(1)
if green<200:
    print(f"FAIL  HAL.4e: screendump text bbox has only {green} green pixels (expected >200 window pixels around the glyphs — a white bar, not text)"); sys.exit(1)
print(f"      screendump: text bbox = {white} white glyph px + {green} green window px")
PY
    rm -f "$SHOT"
else
    echo "FAIL  HAL.4e: no screendump captured"; ok=0
fi

[ "$ok" -eq 1 ] && echo "PASS  HAL.4e: a MOVABLE TEXT WINDOW on the metal — the kernel rasters an 8x8 bitmap font into window B at 3x scale, and each keystroke moves the window AND its text, re-composing the z-ordered frame off-screen and re-presenting it in one memcpy. The paired probes (white ON a stroke, green OFF one, in the same text cell) prove real glyph shapes, and the screendump confirms it independently on the scanned-out panel. The foundation of a terminal, in Lingua Adamica, on bare metal."
[ "$ok" -eq 1 ]
