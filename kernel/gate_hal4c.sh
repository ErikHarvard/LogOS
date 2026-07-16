#!/usr/bin/env bash
# LogOS HAL.4c gate — THE COMPOSITOR ON THE METAL.
#
# The claim under test is not "an LA program drew rectangles" (HAL.4 did that).
# It is: an LA program at ring 0 COMPOSED A WHOLE FRAME OFF-SCREEN, z-ordered,
# and PRESENTED it atomically in one operation.
#
# The load-bearing assertion is the OVERLAP pixel. Window B is painted after
# window A and overlaps it, so where they overlap the frame must be B's GREEN.
# That single pixel is what separates a compositor from a painter: it proves
# later surfaces occlude earlier ones IN THE BACKBUFFER, before presentation.
# If z-order were broken the overlap would read red — and every other assertion
# here would still pass. So this pixel is checked explicitly, on both paths.
#
#   serial (the driver's own peek read-back of the LFB, after presenting):
#     comp bg=128,0,0   desktop  — the one fill() that cleared the frame
#     comp a=0,0,255    A-only   — red survives where B does not reach
#     comp ov=0,255,0   OVERLAP  — GREEN: B occludes A  <-- the z-order proof
#     comp b=0,255,0    B-only   — green
#   display (independent screendump — the pixels really reached the panel, not
#     just memory the driver read back): the same four regions, sampled.
#
# Skips (rc 0) if QEMU is absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  HAL.4c compositor gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_hal4c.sh >/dev/null 2>&1 || { echo "FAIL  HAL.4c gate: build_hal4c.sh failed"; exit 1; }

SERF=$(mktemp); PPM=$(mktemp --suffix=.ppm)
# -m 512: the backbuffer lives at 0x10000000 (256 MiB), like HAL.5b's DMA ring.
{
  for _ in $(seq 1 60); do grep -q 'comp done' "$SERF" 2>/dev/null && break; sleep 0.5; done
  echo "screendump $PPM"
  sleep 1
  echo "quit"
} | timeout 60 qemu-system-x86_64 \
        -kernel kernel/kernel_hal4c.elf -m 512 \
        -vga std -monitor stdio -serial "file:$SERF" -display none \
        >/dev/null 2>&1

SER=$(tr -d '\0' < "$SERF")
seen=$(printf '%s' "$SER" | tr '\n' ' ' | head -c 300)

ok=1
for marker in 'comp lfb=' 'comp composed' 'comp presented' 'comp done'; do
    printf '%s' "$SER" | grep -qF "$marker" || {
        echo "FAIL  HAL.4c: '$marker' not on serial — compositor did not get that far (got: $seen)"; ok=0; }
done
printf '%s' "$SER" | grep -qF 'comp bg=128,0,0' || {
    echo "FAIL  HAL.4c: expected 'comp bg=128,0,0' — the desktop fill() did not clear the frame (got: $seen)"; ok=0; }
printf '%s' "$SER" | grep -qF 'comp a=0,0,255' || {
    echo "FAIL  HAL.4c: expected 'comp a=0,0,255' — window A missing (got: $seen)"; ok=0; }
printf '%s' "$SER" | grep -qF 'comp b=0,255,0' || {
    echo "FAIL  HAL.4c: expected 'comp b=0,255,0' — window B missing (got: $seen)"; ok=0; }
# THE assertion: B occludes A where they overlap.
printf '%s' "$SER" | grep -qF 'comp ov=0,255,0' || {
    echo "FAIL  HAL.4c: overlap is not B's green — Z-ORDER BROKEN (a painter, not a compositor) (got: $seen)"; ok=0; }

python3 - "$PPM" <<'PY' || ok=0
import sys
data = open(sys.argv[1], 'rb').read()
if data[:2] != b'P6':
    print("FAIL  HAL.4c: screendump is not a P6 PPM (empty/failed capture)"); sys.exit(1)
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
    return pix[o], pix[o+1], pix[o+2]          # R, G, B
if (w, h) != (640, 480):
    print(f"FAIL  HAL.4c: display is {w}x{h}, expected 640x480 (VBE mode-set failed)"); sys.exit(1)

def is_red(p):   return p[0] > 200 and p[1] < 60 and p[2] < 60
def is_green(p): return p[1] > 200 and p[0] < 60 and p[2] < 60
def is_blue(p):  return p[2] > 100 and p[0] < 60 and p[1] < 60

# A = (80,60)+200x150 -> x 80..279, y 60..209 ; B = (180,120)+200x150 -> x 180..379, y 120..269
a_only  = [(90, 70), (100, 80), (170, 110), (85, 200)]     # in A, outside B
overlap = [(200, 150), (250, 180), (190, 130), (270, 200)] # in BOTH -> must be B
b_only  = [(350, 250), (300, 260), (370, 130), (340, 220)] # in B, outside A
bg      = [(5, 5), (600, 20), (20, 450), (620, 460)]       # neither

na = sum(1 for p in a_only  if is_red(px(*p)))
no = sum(1 for p in overlap if is_green(px(*p)))
nb = sum(1 for p in b_only  if is_green(px(*p)))
ng = sum(1 for p in bg      if is_blue(px(*p)))
print(f"      screendump {w}x{h}: desktop {ng}/4 blue, A-only {na}/4 red, "
      f"B-only {nb}/4 green, OVERLAP {no}/4 green (z-order)")
bad = [p for p in overlap if is_red(px(*p))]
if bad:
    print(f"FAIL  HAL.4c: overlap pixels {bad} are RED — A occludes B, z-order inverted")
sys.exit(0 if (na == 4 and no == 4 and nb == 4 and ng == 4) else 1)
PY

rm -f "$SERF" "$PPM"
[ "$ok" -eq 1 ] && echo "PASS  HAL.4c: THE COMPOSITOR ON THE METAL — an LA program at ring 0 composed a full 640x480 frame off-screen in ordinary RAM (one fill() cleared the desktop; each window laid down one fill() per row), z-ordered by paint order so window B occludes window A where they overlap, then presented the entire 1,228,800-byte frame to the linear framebuffer in ONE memcpy — an atomic, tear-free frame. Verified by the driver's own peek read-back AND an independent screendump: the overlap is B's green, so later surfaces really do occlude earlier ones in the backbuffer. theourgia's compositor semantics, on the metal, in the language itself."
[ "$ok" -eq 1 ]
