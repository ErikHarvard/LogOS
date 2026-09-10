#!/usr/bin/env bash
# ⛔ THIS GATE IS CURRENTLY RED, FOR A REAL DEFECT, AND IS DELIBERATELY NOT WIRED
#    INTO build.sh. Measured 2026-09-09, first time it had EVER been run — it was
#    committed in a2769b8 as "sources; ELF compiling, gate NOT YET RUN" and sat on
#    disk, invoked by nothing, until the kernel-only entry point made running the
#    kernel half cheap enough to notice it.
#
#    ★ THE EDIT MODEL IS NOT THE BUG. kernel/editmodel_test.la on the C HOST passes
#    every assertion this gate makes, including the two it fails on metal:
#        typed=LOGOS  after_bksp=LOGO  grown=LOGOSABCD
#        view_short=LOGOS  view_scrolled=GOSABCD  view_len=7
#    So TAKE/VIEW/BKSP/NEWBUF are CORRECT. There is no off-by-one to find.
#
#    ★ THE FAULT IS ON THE METAL, AND ITS SHAPE IS THE FINDING:
#        edit buf=LOGO / edit view=LOGO
#        EXCEPTION 0d err=0000000000000000 rip=333333003f333333
#    EXCEPTION 0d is a GP fault, and rip is ASCII — 33 33 33 00 3f 33 33 33, i.e.
#    "333\0?333". THE INSTRUCTION POINTER WAS LOADED FROM STRING DATA. Control flow
#    jumped into a value. That is a codegen/runtime defect, not compositor logic.
#    It fires after 4-6 keystrokes; exactly which one varies with sendkey timing,
#    so it is not keyed to a particular character or to MAXCH.
#
#    ⚠ REPRODUCE WITH -m 512, NOT -m 256. At 256 MB the failure changes shape
#    entirely ("native: argument is not a string", exit 33) and the probe pixels
#    read 0,0,0 instead of 255,255,255 — a different bug, or the same one wearing
#    a different mask. My first repro used 256 and sent me after the wrong thing.
#
#    NOT WIRED ON PURPOSE: build.sh's own census note records that wiring a
#    known-red gate turns the suite red and that "a census that classifies by
#    STRUCTURE will hand you a red gate to wire" (kernel/gate_hal_idle.sh is the
#    precedent). This one is tracked here and on the board instead.
#
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
# ── ★ FRESH-CHECKOUT FIX, 2026-09-08 — THIS GATE COULD PASS HAVING TESTED NOTHING
# It printed SKIP and `exit 0` when kernel/kernel_comp_edit.elf was missing. That ELF is an
# UNTRACKED build artifact (.gitignore: /kernel/kernel_*.elf), so on a fresh clone,
# or after `git clean`, this gate asserted NOTHING and said so with a success code.
# Wiring it in that state would have ADDED A FALSE GREEN to build.sh — worse than
# leaving it unwired, which is why the gate census ruled "fix the skip first".
#
# This is kernel/gate_hal_idle.sh's fix (2026-08-19) applied to the same defect:
#   ★ "I tested nothing" MUST NOT BE SPELLED THE SAME WAY AS "everything passed".
#
# WHY THE BUILD IS OPT-IN RATHER THAN AUTOMATIC, and this is measured, not assumed:
# comp_edit.la costs ~49 min (gate_hal_idle.sh:78).
# gate_hal_idle.sh auto-builds only its 41-SECOND control and records that
# auto-building THESE kernels "was rejected on cost". An unconditional build here
# would silently turn any suite that wires this gate into a multi-hour run.
# So: build on explicit opt-in, and otherwise FAIL LOUDLY. Note this is the
# opposite of the skip flag build.sh forbids — there is no way to make this gate
# report success without actually running the kernel.
# ★ ALWAYS REBUILD. This used to build ONLY when the ELF was ABSENT, because a
# rebuild cost "~49 min" — its own note above. ⇒ AN ELF THAT WAS PRESENT BUT
# STALE WAS TESTED AS THOUGH IT WERE THE SOURCE, and that is not hypothetical:
# on 2026-09-09, the first time this gate was ever run, it went RED on a leftover
# ELF built in July by an older native_codegen3. That binary GP-faulted with
# `EXCEPTION 0d rip=333333003f333333` — an instruction pointer loaded from ASCII
# string data. I diagnosed it as a live codegen fault. IT WAS NOT. A fresh build
# of the SAME UNCHANGED SOURCE is byte-reproducible and PASSES.
#
# ⇒ The gate had been fixed for the ABSENT case (it used to SKIP + exit 0, see
# above) and left open for the STALE case, which is worse: absent is loud, stale
# is a confident wrong answer. This is ENTELECHEIA's class — an instrument that
# certifies a stale artifact — and it cost a full misdiagnosis.
#
# ⇒ AND THE REASON THE HOLE EXISTED IS GONE. The 49 minutes was the interpreted
# `./tiny_host native_codegen3.la` compile. Since kernel/ncc3.sh routes every
# builder through the committed native image, THIS REBUILD TAKES 7 SECONDS
# (measured). There is no longer any economy in trusting a leftover binary, so
# the gate always builds what it tests and LOGOS_GATE_BUILD is retired.
if [ ! -x ./kernel/build_hal4g.sh ]; then
    echo "FAIL  HAL.4g editable-line gate: ./kernel/build_hal4g.sh is missing, so this gate cannot build what it tests and would otherwise test a leftover binary."
    exit 1
fi
if ! ./kernel/build_hal4g.sh >/dev/null 2>&1; then
    echo "FAIL  HAL.4g editable-line gate: ./kernel/build_hal4g.sh failed, so the kernel under test does not exist."
    exit 1
fi
if [ ! -f kernel/kernel_comp_edit.elf ]; then
    echo "FAIL  HAL.4g editable-line gate: build reported success but kernel/kernel_comp_edit.elf is absent, so this gate tested NOTHING."
    exit 1
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
