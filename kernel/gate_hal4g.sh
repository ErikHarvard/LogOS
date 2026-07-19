#!/usr/bin/env bash
# LogOS HAL.4g gate — an EDITABLE, SCROLLING LINE on the metal.
# HAL.4f could type but not un-type, and silently DISCARDED input past 7 chars.
# This gate proves both of those are gone, by typing a line, DELETING from it,
# and then overflowing it:
#   - "edit ready"            — armed (mode set, empty line + cursor presented);
#   - "edit buf=LOGOS"        — five keystrokes accumulated in order;
#   - "edit buf=LOGO"         — BACKSPACE removed the last character. This is an
#                               EXACT-LINE match (grep -x), and it has to be:
#                               "edit buf=LOGO" is a SUBSTRING of the earlier
#                               "edit buf=LOGOS" line, so a substring match would
#                               pass WITHOUT backspace ever working;
#   - "edit buf=LOGOSABCD"    — the buffer grew to NINE characters, past MAXCH=7.
#                               Under HAL.4f those last two keys were discarded;
#   - "edit view=GOSABCD"     — and what is ON SCREEN is the LAST SEVEN of them.
#                               This is the scrolling assertion: buf and view
#                               have DIVERGED. A build that ignored overflow
#                               would show view==LOGOSAB (the first seven) or
#                               refuse the keys entirely;
#   - "edit on=255,255,255"   — probe (201,141) white: a real glyph stroke;
#   - "edit off=0,255,0"      — probe (222,141) green: window B through the SAME
#                               cell, so it is a GLYPH SHAPE not a filled block.
#                               (Both probes are substring matches: they need to
#                               hold on the frames where the first cell is 'L',
#                               not on every frame — once the view scrolls, cell
#                               0 is 'G', whose row 0 leaves column 0 CLEAR.);
#   - "edit done"             — ENTER ended the loop;
#   - exit 33                 — MAIN returned -> exit(0) -> isa-debug-exit.
#
# ── TWO BOOTS, ON PURPOSE. Do not fold them back into one. ──────────────────
# HAL.4e's gate did both jobs in one boot — screendump, THEN keys — and spent a
# day reporting its own perturbation as the subject's defect (measured: with a
# pre-key screendump the loop never finished, 0/3; without it, 3/3; sleeping
# LONGER made it worse). See kernel/gate_hal4e.sh and commit da93d81. Boot 1
# here runs the interactive assertion with NO screendump touching it; boot 2
# does the capture in its own process and quits without ENTER, so if the capture
# perturbs what follows it cannot reach a verdict.
#
# Boots the ALREADY-BUILT ELF and never rebuilds: comp_edit.la's compile is
# ~40 minutes (MEASURED on HAL.4f: 38m01s and 41m24s), so the ELF is an
# out-of-band artifact built by kernel/build_hal4g.sh.
# Skips (rc 0) if QEMU is absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  HAL.4g editable-line gate: qemu-system-x86_64 not installed"
    exit 0
fi
if [ ! -f kernel/kernel_comp_edit.elf ]; then
    echo "SKIP  HAL.4g editable-line gate: kernel/kernel_comp_edit.elf absent (build it out of band: ./kernel/build_hal4g.sh)"
    exit 0
fi

ok=1

# ── Boot 1: the interactive assertion. No screendump touches this run. ──
# Type LOGOS, backspace to LOGO, then SABCD -> LOGOSABCD (9 chars, view scrolls).
SERF=$(mktemp)
{ for _ in $(seq 1 60); do grep -q 'edit ready' "$SERF" 2>/dev/null && break; sleep 0.5; done
  for k in l o g o s backspace s a b c d; do echo "sendkey $k"; sleep 0.6; done
  sleep 0.4; echo "sendkey ret"
  sleep 1.5
} | timeout 120 qemu-system-x86_64 \
        -kernel kernel/kernel_comp_edit.elf -m 512 \
        -vga std -monitor stdio -serial "file:$SERF" -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown >/dev/null 2>&1
RC=$?
SER=$(tr -d '\0' < "$SERF"); rm -f "$SERF"
seen=$(printf '%s' "$SER" | tr '\n' ' ' | head -c 500)

# EXACT-LINE assertions. Every one of these is a prefix of another line that the
# run also produces, so substring matching would make the gate unable to fail.
for tok in 'edit buf=LOGOS' 'edit buf=LOGO' 'edit buf=LOGOSABCD' 'edit view=GOSABCD'; do
    printf '%s\n' "$SER" | grep -qx "$tok" || { echo "FAIL  HAL.4g: no exact line '$tok' (rc=$RC, got: $seen)"; ok=0; }
done
# Substring assertions: these need to hold on SOME frame, not every one.
for tok in 'edit ready' 'edit on=255,255,255' 'edit off=0,255,0' 'edit done'; do
    printf '%s' "$SER" | grep -qF "$tok" || { echo "FAIL  HAL.4g: '$tok' not on serial (rc=$RC, got: $seen)"; ok=0; }
done
[ "$RC" -eq 33 ] || { echo "FAIL  HAL.4g: exit code != 33 (got $RC; got: $seen)"; ok=0; }

# The view must never exceed the display width, however long the buffer grows.
LONGVIEW=$(printf '%s\n' "$SER" | sed -n 's/^edit view=//p' | awk '{ if (length($0) > 7) print length($0) }' | head -1)
[ -z "$LONGVIEW" ] || { echo "FAIL  HAL.4g: a view line was $LONGVIEW chars, past the 7-cell display width"; ok=0; }

# ── Boot 2: the screendump witness, alone. Type LOGOS only (5 chars, so the
#    bbox below is the same one HAL.4e/4f use), capture, quit — no ENTER. ──
SERF2=$(mktemp); SHOT=$(mktemp -u).ppm
{ for _ in $(seq 1 60); do grep -q 'edit ready' "$SERF2" 2>/dev/null && break; sleep 0.5; done
  for k in l o g o s; do echo "sendkey $k"; sleep 0.6; done
  sleep 0.8; echo "screendump $SHOT"; sleep 1.5
  echo "quit"
} | timeout 120 qemu-system-x86_64 \
        -kernel kernel/kernel_comp_edit.elf -m 512 \
        -vga std -monitor stdio -serial "file:$SERF2" -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown >/dev/null 2>&1
rm -f "$SERF2"

# Independent screendump witness: the typed text bbox is x 200..320, y 140..164
# (window B at 180,120 + text origin 20,20; 5 chars x 8 px x SCALE 3 = 120 x 24).
if [ -f "$SHOT" ]; then
    python3 - "$SHOT" <<'PY' || ok=0
import sys
d=open(sys.argv[1],'rb').read()
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
    print(f"FAIL  HAL.4g: screendump text bbox has only {white} white pixels (expected >200 glyph pixels — did the typed text raster?)"); sys.exit(1)
if green<200:
    print(f"FAIL  HAL.4g: screendump text bbox has only {green} green pixels (expected >200 window pixels around the glyphs — a white bar, not text)"); sys.exit(1)
print(f"      screendump: typed-text bbox = {white} white glyph px + {green} green window px")
PY
    rm -f "$SHOT"
else
    echo "FAIL  HAL.4g: no screendump captured"; ok=0
fi

[ "$ok" -eq 1 ] && echo "PASS  HAL.4g: an EDITABLE, SCROLLING LINE on the metal — the kernel decodes SET-1 scancodes into a live buffer, BACKSPACE removes the last character, and the buffer grows without limit while the window shows the last 7 characters of it (buf=LOGOSABCD, view=GOSABCD — they have diverged, which is scrolling). The edit model is a pure function of (scancode, buffer), verified host-side before ever reaching the metal. A line you can type, correct, and overrun, in Lingua Adamica, on bare metal."
[ "$ok" -eq 1 ]
