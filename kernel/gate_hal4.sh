#!/usr/bin/env bash
# LogOS HAL.4 gate — a linear-framebuffer display driver in Lingua Adamica paints
# real pixels. Boot the framebuffer kernel, wait for it to finish drawing, capture
# the guest display with QEMU's `screendump`, and assert the red square is there:
#   - serial shows "fb lfb=..." + "fb drawn" — the LA driver found the VGA BAR,
#     set the VBE mode, and drew;
#   - the screendump PPM is 640x480 (the mode-set took) and the 64x64 top-left
#     region is red (the driver's pokes reached the linear framebuffer via the BAR).
# So: the HAL.1/HAL.4 port-I/O primitives + the 0..4 GiB identity map let an LA
# program at ring 0 drive a real display device — the kernel's first pixels, in
# the language itself. Skips (rc 0) if QEMU is absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  HAL.4 display gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_hal4.sh >/dev/null 2>&1 || { echo "FAIL  HAL.4 gate: build_hal4.sh failed"; exit 1; }

SERF=$(mktemp); PPM=$(mktemp --suffix=.ppm)
# Feed the monitor: wait (up to ~30 s) for the driver's "fb drawn" marker on the
# serial file, then screendump the guest display and quit.
{
  for _ in $(seq 1 60); do grep -q 'fb drawn' "$SERF" 2>/dev/null && break; sleep 0.5; done
  echo "screendump $PPM"
  sleep 1
  echo "quit"
} | timeout 60 qemu-system-x86_64 \
        -kernel kernel/kernel_hal4.elf -m 512 \
        -vga std -monitor stdio -serial "file:$SERF" -display none \
        >/dev/null 2>&1

SER=$(tr -d '\0' < "$SERF")
seen=$(printf '%s' "$SER" | tr '\n' ' ' | head -c 200)

ok=1
printf '%s' "$SER" | grep -qF 'fb lfb=' || { echo "FAIL  HAL.4: 'fb lfb=' not on serial — driver did not find the VGA BAR (got: $seen)"; ok=0; }
printf '%s' "$SER" | grep -qF 'fb drawn' || { echo "FAIL  HAL.4: 'fb drawn' not on serial — driver did not finish drawing (got: $seen)"; ok=0; }

python3 - "$PPM" <<'PY' || ok=0
import sys
data = open(sys.argv[1], 'rb').read()
if data[:2] != b'P6':
    print("FAIL  HAL.4: screendump is not a P6 PPM (empty/failed capture)"); sys.exit(1)
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
    print(f"FAIL  HAL.4: display is {w}x{h}, expected 640x480 (VBE mode-set failed)"); sys.exit(1)
red = sum(1 for y in range(64) for x in range(64)
          if px(x, y)[0] > 200 and px(x, y)[1] < 60 and px(x, y)[2] < 60)
print(f"      screendump {w}x{h}, red pixels in 64x64 top-left = {red}/4096")
sys.exit(0 if red >= 3500 else 1)
PY

rm -f "$SERF" "$PPM"
[ "$ok" -eq 1 ] && echo "PASS  HAL.4: linear-framebuffer display in Lingua Adamica — an LA program at ring 0 scanned PCI for the VGA, read its BAR0 (linear framebuffer), set 640x480x32 via the Bochs VBE registers (outw/inw), and poked a red square that screendump confirms on the guest display. The kernel's first pixels, driver written in the language, framebuffer reached via a PCI BAR through the 0..4 GiB identity map."
[ "$ok" -eq 1 ]
