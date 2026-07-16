#!/usr/bin/env bash
# LogOS HAL.4b gate — the bulk framebuffer primitives (fill/memcpy), the FIRST
# ternary builtins in Lingua Adamica, drive a real display.
#
# HAL.4 poked a 64x64 square one byte at a time and never attempted a full
# screen. HAL.4b paints ALL 307200 pixels with one `rep stosd` and blits a RAM
# backbuffer onto the LFB with `rep movsb`. The gate proves each primitive
# separately and TWICE over — once from the driver's own read-back on serial,
# once from an independent screendump of the guest display:
#
#   serial : "fb4b filled"/"fb4b blitted"/"fb4b done" (the driver ran through),
#            "fb4b out=128,0" — a pixel far from the square reads B=128,R=0, so
#            fill() painted the whole screen blue (poke never touched (10,10));
#            "fb4b in=0,255"  — a pixel inside the square reads B=0,R=255, so
#            memcpy() moved the red backbuffer onto the LFB.
#            BOTH are asserted: either alone is passable by a broken primitive
#            (a fill that wrote nothing still leaves 'in' red; a memcpy that
#            wrote nothing still leaves 'out' blue).
#   display: independently, the screendump must be 640x480, mostly blue, with a
#            red 64x64 block at (100,100) — the pixels really reached the panel,
#            not just memory the driver read back.
#
# Skips (rc 0) if QEMU is absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  HAL.4b bulk-framebuffer gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_hal4b.sh >/dev/null 2>&1 || { echo "FAIL  HAL.4b gate: build_hal4b.sh failed"; exit 1; }

SERF=$(mktemp); PPM=$(mktemp --suffix=.ppm)
{
  for _ in $(seq 1 60); do grep -q 'fb4b done' "$SERF" 2>/dev/null && break; sleep 0.5; done
  echo "screendump $PPM"
  sleep 1
  echo "quit"
} | timeout 60 qemu-system-x86_64 \
        -kernel kernel/kernel_hal4b.elf -m 512 \
        -vga std -monitor stdio -serial "file:$SERF" -display none \
        >/dev/null 2>&1

SER=$(tr -d '\0' < "$SERF")
seen=$(printf '%s' "$SER" | tr '\n' ' ' | head -c 300)

ok=1
for marker in 'fb4b lfb=' 'fb4b filled' 'fb4b blitted' 'fb4b done'; do
    printf '%s' "$SER" | grep -qF "$marker" || {
        echo "FAIL  HAL.4b: '$marker' not on serial — driver did not get that far (got: $seen)"; ok=0; }
done
# fill(): a pixel nowhere near the square is blue — nothing but the whole-screen
# fill could have written it.
printf '%s' "$SER" | grep -qF 'fb4b out=128,0' || {
    echo "FAIL  HAL.4b: expected 'fb4b out=128,0' (B=128,R=0) — fill() did not paint the screen (got: $seen)"; ok=0; }
# memcpy(): a pixel inside the square is red — the RAM backbuffer reached the LFB.
printf '%s' "$SER" | grep -qF 'fb4b in=0,255' || {
    echo "FAIL  HAL.4b: expected 'fb4b in=0,255' (B=0,R=255) — memcpy() did not blit the backbuffer (got: $seen)"; ok=0; }

python3 - "$PPM" <<'PY' || ok=0
import sys
data = open(sys.argv[1], 'rb').read()
if data[:2] != b'P6':
    print("FAIL  HAL.4b: screendump is not a P6 PPM (empty/failed capture)"); sys.exit(1)
idx, vals = 2, []
while len(vals) < 3:
    while idx < len(data) and data[idx:idx+1].isspace(): idx += 1
    if data[idx:idx+1] == b'#':
        while idx < len(data) and data[idx:idx+1] != b'\n': idx += 1
        continue
    s = idx
    while idx < len(data) and not data[idx:idx+1].isspace(): idx += 1
    vals.append(int(data[s:idx]))
w, h, _mx = vals
idx += 1
pix = data[idx:]
def px(x, y):
    o = (y*w + x)*3
    return pix[o], pix[o+1], pix[o+2]
if (w, h) != (640, 480):
    print(f"FAIL  HAL.4b: display is {w}x{h}, expected 640x480 (VBE mode-set failed)"); sys.exit(1)

# memcpy landed: the 64x64 block at (100,100) is red
red = sum(1 for y in range(100, 164) for x in range(100, 164)
          if px(x, y)[0] > 200 and px(x, y)[1] < 60 and px(x, y)[2] < 60)
# fill landed: sample the screen far from the square — must be blue everywhere
pts = [(5, 5), (600, 20), (20, 450), (620, 460), (320, 300), (500, 240)]
blue = sum(1 for (x, y) in pts
           if px(x, y)[2] > 100 and px(x, y)[0] < 60 and px(x, y)[1] < 60)
print(f"      screendump {w}x{h}: red in 64x64 @(100,100) = {red}/4096 (memcpy), "
      f"blue at {blue}/{len(pts)} far-flung samples (fill)")
sys.exit(0 if (red >= 3500 and blue == len(pts)) else 1)
PY

rm -f "$SERF" "$PPM"
[ "$ok" -eq 1 ] && echo "PASS  HAL.4b: bulk framebuffer fill + memcpy in Lingua Adamica — the language's FIRST ternary builtins. An LA program at ring 0 filled all 307200 pixels of a real 640x480 display with one rep stosd, composed a 64x64 backbuffer in ordinary RAM, and blitted it onto the LFB with rep movsb — confirmed both by the driver's own peek read-back and independently by a screendump. The per-pixel poke loop is retired; the compositor's inner loop now exists on the metal."
[ "$ok" -eq 1 ]
