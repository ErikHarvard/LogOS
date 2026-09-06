#!/usr/bin/env bash
# LogOS HAL.4e gate — a TERMINAL WINDOW in the compositor, on the metal.
# Boot the terminal, type through the QEMU monitor, and assert from the serial
# line that each keystroke RASTERED A REAL GLYPH into a real presented frame:
#   - "term paper=32,32,32"  — the empty cell BEFORE typing reads the paper colour;
#   - "term ch=L col=0 row=0" ... col=4 — the cursor advances one cell per key;
#   - "term pix=51,204,51"   — a pixel INSIDE that character's own cell, read back
#                              out of the LFB after the present, is the TEXT colour;
#   - "term nl row=1" + "term ch=O col=0 row=1" — ENTER wrapped to a new line and
#                              the cursor returned to column 0;
#   - "term done col=2 row=1" — ESC ended the session;
#   - exit 33.
#
# ★ WHY THE PIXEL IS THE LOAD-BEARING WITNESS, and why it can go red.
# The probe reads cell-relative pixel (1,1). That bit is LIT in the font for every
# character this gate types (L O G S K — verified against FONTDATA, not assumed),
# so 51,204,51 means a stroke was rastered AND presented, while 32,32,32 means the
# cursor advanced over untouched paper. The "term paper=" line before any typing
# proves the two readings are distinguishable ON THIS RUN. A loop that moved the
# cursor without drawing, or drew into the backbuffer without presenting, leaves
# the probe at 32,32,32 and FAILS. Skips (rc 0) if QEMU is absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  HAL.4e terminal-window gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_comp_term.sh >/dev/null 2>&1 || { echo "FAIL  HAL.4e gate: build_comp_term.sh failed"; exit 1; }

SERF=$(mktemp)
{ for _ in $(seq 1 60); do grep -q 'term ready' "$SERF" 2>/dev/null && break; sleep 0.5; done
  for k in l o g o s; do echo "sendkey $k"; sleep 1.0; done
  sleep 0.3; echo "sendkey ret"; sleep 1.0
  for k in o k; do echo "sendkey $k"; sleep 1.0; done
  sleep 0.3; echo "sendkey esc"
  sleep 2.0
} | timeout 120 qemu-system-x86_64 \
        -kernel kernel/kernel_comp_term.elf -m 512 \
        -vga std -monitor stdio -serial "file:$SERF" -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown >/dev/null 2>&1
RC=$?
SER=$(tr -d '\0' < "$SERF"); rm -f "$SERF"
seen=$(printf '%s' "$SER" | tr '\n' ' ' | head -c 400)

ok=1
for tok in 'term ready' 'term paper=32,32,32' \
           'term ch=L col=0 row=0' 'term ch=S col=4 row=0' \
           'term nl row=1' 'term ch=O col=0 row=1' \
           'term done col=2 row=1'; do
    printf '%s' "$SER" | grep -qF "$tok" || { echo "FAIL  HAL.4e: '$tok' not on serial (rc=$RC, got: $seen)"; ok=0; }
done

# Every typed character must have rastered: one text-coloured probe per keystroke.
NPIX=$(printf '%s' "$SER" | grep -cF 'term pix=51,204,51')
[ "$NPIX" -eq 7 ] || { echo "FAIL  HAL.4e: $NPIX/7 keystrokes rastered a glyph (probe should read the TEXT colour for each)"; ok=0; }
# And nothing may have landed on untouched paper.
printf '%s' "$SER" | grep -qF 'term pix=32,32,32' && { echo "FAIL  HAL.4e: a keystroke advanced the cursor without rastering (probe read the PAPER colour)"; ok=0; }

[ "$RC" -eq 33 ] || { echo "FAIL  HAL.4e: exit code != 33 (got $RC; got: $seen)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  HAL.4e: a TERMINAL WINDOW in the compositor on the metal — framed, title-barred, with an 8x8 bitmap font rastered glyph by glyph at ring 0; the kernel polls the PS/2 keyboard, decodes SET-1 to characters, draws each into its cursor cell and presents, and the probe pixel read back OUT of the LFB is the text colour for all 7 keystrokes (32,32,32 paper before typing) — real glyphs in a real presented frame. ENTER wraps the cursor to a new line; ESC exits clean. LogOS's first text-bearing window, no Linux, no DRM, no evdev."
[ "$ok" -eq 1 ]
