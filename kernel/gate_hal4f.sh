#!/usr/bin/env bash
# LogOS HAL.4f gate — a TYPEWRITER on the metal (typing, not just displaying).
# Boot the metal terminal, inject KEYSTROKES through the QEMU monitor, and assert
# from BOTH the serial line and an independent screendump that the typed
# characters were accumulated into a buffer and rastered as real glyphs:
#   - "term ready"           — the compositor armed (mode set, empty buffer +
#                              cursor presented);
#   - "term buf=L"           — the FIRST keystroke decoded and appended;
#   - "term buf=LOGOS"       — all five accumulated IN ORDER. This is the
#                              load-bearing assertion: a decode that dropped a
#                              key, doubled one (release codes not rejected), or
#                              reversed the append would produce a DIFFERENT
#                              string here and fail, while still "printing
#                              something" — which is why the gate matches the
#                              exact buffer, not merely a "term buf=" prefix;
#   - "term on=255,255,255"  — probe (201,141) is 'L' row 0 col 0: a WHITE
#                              stroke, so the font really rastered the typed char;
#   - "term off=0,255,0"     — probe (222,141) is 'L' row 0 col 7: window B's
#                              GREEN showing through INSIDE the same text cell,
#                              so what drew is a GLYPH SHAPE, not a filled block.
#                              Either probe alone is passable by a broken
#                              renderer (a dead draw leaves both green; a runaway
#                              fill leaves both white) — the PAIR is what pins it;
#   - "term done"            — ENTER ended the loop;
#   - exit 33                — MAIN returned -> exit(0) -> isa-debug-exit.
#
# ── TWO BOOTS, ON PURPOSE. Do not fold them back into one. ──────────────────
# HAL.4e's gate did both jobs in one boot — screendump the frame, THEN send the
# keys — and spent a day reporting its own perturbation as the subject's defect
# (measured: with a pre-key screendump 'text done' never appeared, 0/3; without
# it, 3/3; sleeping LONGER made it worse, so it is not a transient to wait out).
# See kernel/gate_hal4e.sh and commit da93d81. HAL.4f is built with that lesson
# from the start: boot 1 runs the interactive assertion with NO screendump
# touching it, and boot 2 does the capture in its own process. The mechanism was
# never pinned, which is exactly why the two measurements stay separated.
#
# Boots the ALREADY-BUILT ELF and never rebuilds: comp_term.la's native_codegen3
# compile is very slow (superlinear codegen), so the ELF is an out-of-band
# artifact built by kernel/build_hal4f.sh, exactly like the heavy K6/K7 kernels.
# Skips (rc 0) if QEMU is absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  HAL.4f typewriter gate: qemu-system-x86_64 not installed"
    exit 0
fi
if [ ! -f kernel/kernel_comp_term.elf ]; then
    echo "SKIP  HAL.4f typewriter gate: kernel/kernel_comp_term.elf absent (build it out of band: ./kernel/build_hal4f.sh)"
    exit 0
fi

ok=1

# ── Boot 1: the interactive assertion. No screendump touches this run. ──
SERF=$(mktemp)
{ for _ in $(seq 1 60); do grep -q 'term ready' "$SERF" 2>/dev/null && break; sleep 0.5; done
  for k in l o g o s; do echo "sendkey $k"; sleep 0.6; done
  sleep 0.4; echo "sendkey ret"
  sleep 1.5
} | timeout 90 qemu-system-x86_64 \
        -kernel kernel/kernel_comp_term.elf -m 512 \
        -vga std -monitor stdio -serial "file:$SERF" -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown >/dev/null 2>&1
RC=$?
SER=$(tr -d '\0' < "$SERF"); rm -f "$SERF"
seen=$(printf '%s' "$SER" | tr '\n' ' ' | head -c 400)

for tok in 'term ready' 'term buf=L' 'term buf=LOGOS' 'term on=255,255,255' 'term off=0,255,0' 'term done'; do
    printf '%s' "$SER" | grep -qF "$tok" || { echo "FAIL  HAL.4f: '$tok' not on serial (rc=$RC, got: $seen)"; ok=0; }
done
[ "$RC" -eq 33 ] || { echo "FAIL  HAL.4f: exit code != 33 (got $RC; got: $seen)"; ok=0; }

# A buffer LONGER than what was typed means release codes (make+0x80) leaked
# through the KEYCH bound and were appended as characters — the exact bug the
# 'sc < KMLEN' guard exists to stop. Caught explicitly, because "term buf=LOGOS"
# would still match as a substring of "term buf=LOGOSLOGOS".
printf '%s' "$SER" | grep -qE 'term buf=LOGOS.' && { echo "FAIL  HAL.4f: buffer grew past the typed text (release codes leaking into the append?)"; ok=0; }

# ── Boot 2: the screendump witness, alone. Type, capture, quit — no ENTER, so
#    if the capture perturbs what follows it cannot affect a verdict. ──
SERF2=$(mktemp); SHOT=$(mktemp -u).ppm
{ for _ in $(seq 1 60); do grep -q 'term ready' "$SERF2" 2>/dev/null && break; sleep 0.5; done
  for k in l o g o s; do echo "sendkey $k"; sleep 0.6; done
  sleep 0.8; echo "screendump $SHOT"; sleep 1.5
  echo "quit"
} | timeout 90 qemu-system-x86_64 \
        -kernel kernel/kernel_comp_term.elf -m 512 \
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
    print(f"FAIL  HAL.4f: screendump text bbox has only {white} white pixels (expected >200 glyph pixels — did the typed text raster?)"); sys.exit(1)
if green<200:
    print(f"FAIL  HAL.4f: screendump text bbox has only {green} green pixels (expected >200 window pixels around the glyphs — a white bar, not text)"); sys.exit(1)
print(f"      screendump: typed-text bbox = {white} white glyph px + {green} green window px")
PY
    rm -f "$SHOT"
else
    echo "FAIL  HAL.4f: no screendump captured"; ok=0
fi

[ "$ok" -eq 1 ] && echo "PASS  HAL.4f: a TYPEWRITER on the metal — the kernel decodes SET-1 scancodes into characters, accumulates them in a live buffer, and re-rasters that buffer into window B every keystroke with a cursor, re-composing the z-ordered frame off-screen and re-presenting it in one memcpy. 'LOGOS' was TYPED, not displayed from a constant. The paired probes (white ON a stroke, green OFF one, in the same cell) prove real glyph shapes, and the screendump confirms it independently on the scanned-out panel. A terminal you can type into, in Lingua Adamica, on bare metal."
[ "$ok" -eq 1 ]
