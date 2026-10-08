#!/usr/bin/env bash
# gate_wm_leak.sh — the window manager runs in bounded memory.
#
# WHAT IT GUARDS. On the VM a closure keeps its whole environment alive. When
# the WM built a new window or state record inline, inside a lambda that still
# had the previous record in scope, every version kept the one before it alive:
# typing "a" then Backspace over and over at 960x600 ran the VM out of heap
# after 316 frames ("secd: heap exhausted"), and after about 86 at 1920x1080.
# theourgia_wm.la now builds every stored record through the WM_MK
# constructors, which capture nothing but their fields.
#
# This gate drives the headless WM (theourgia_wm_sim.la) at 1920x1080, text
# scale 2, through every path that stores a new record, each many times:
#    A  typing into a terminal                      (touch, set_term, tile cache)
#    B  running an external program with output     (submit, the job, on_output)
#    C  typing into a LogosKit app (settings)       (app_step, the app value)
#    D  locking and unlocking the screen            (lock_now, lock_key)
# and checks that the run ends cleanly (rc 0, "wm: exit"), that every one of the
# requested frames was written, and that the last frame (read back as text with
# wm_ocr.py) is the right one: the terminal, focused, holding the programs'
# output. Before the fix it failed in part A.
#
# ISOLATION: a private temporary directory (gate_wm_common.sh). VM only. A few
# minutes, mostly compiling the WM and drawing the frames.
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1

wm_setup theourgia_tile.la theourgia_term.la theourgia_render.la logosh.la \
         theourgia_wm.la theourgia_termfont.la logoskit.la lk_settings.la lk_login.la theourgia_wm_sim.la \
         wm_script.py wm_ocr.py
W=1920; H=1080; SCALE=2
A=150; B=20; C=60; D=25
mkdir -p "$T/home"
echo "$W $H $SCALE $T/home events.bin" > "$T/wm_sim.cfg"
{
    for _ in $(seq "$A"); do printf 'type a\nsnap 1\nkey BACKSPACE\nsnap 1\n'; done
    for i in $(seq "$B"); do printf 'type /bin/echo out%s\\n\nsnap 1\n' "$i"; done
    printf 'mod s\n'
    for _ in $(seq "$C"); do printf 'type x\nsnap 1\nkey BACKSPACE\nsnap 1\n'; done
    printf 'mod q\n'
    for _ in $(seq "$D"); do printf 'mod ESC\nsnap 1\ntype adam\nkey TAB\ntype logos\\n\nsnap 1\n'; done
    printf 'snap 2\nmod Shift+E\n'
} > "$T/leak.txt"
want=$((2 * A + B + 2 * C + 2 * D + 1))
python3 "$T/wm_script.py" "$T/leak.txt" "$T/events.bin" || { echo "FAIL  leak: wm_script.py"; exit 1; }

t0=$(date +%s)
wm_vm theourgia_wm_sim.la "$T/log.txt"
t1=$(date +%s)
if [ "$vrc" = 90 ]; then
    echo "FAIL  leak: the headless WM did not compile"; tail -3 "$T/vce"; exit 1
fi
echo "      (ran in $((t1 - t0)) s, including the VM compile)"
n=$(grep -cx "wm: snap [12]" "$T/log.txt")
if [ "$vrc" = 0 ] && grep -qx "wm: exit" "$T/log.txt"; then
    echo "PASS  leak: the WM ran to a clean exit (rc 0, 'wm: exit')"
else
    echo "FAIL  leak: the WM did not end cleanly: rc=$vrc after $n of $want frames"
    echo "      run: $(tail -3 "$T/vre")"; ok=0
fi
if [ "$n" = "$want" ]; then
    echo "PASS  leak: all $want frames were drawn (A $A, B $B, C $C, D $D rounds at ${W}x${H})"
else
    echo "FAIL  leak: $n of $want frames were drawn"; ok=0
fi
if [ -f "$T/wm_shot_2.bin" ]; then
    python3 - "$T" "$W" "$H" "$SCALE" "$T/home" "$B" <<'PYEOF' || ok=0
import importlib.util, json, sys
d, W, H, S, home, nb = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), sys.argv[5], int(sys.argv[6])
spec = importlib.util.spec_from_file_location("wm_ocr", f"{d}/wm_ocr.py"); ocr = importlib.util.module_from_spec(spec); spec.loader.exec_module(ocr)
glyphs = ocr.load_font(f"{d}/theourgia_termfont.la")
s = ocr.ocr(ocr.Frame(open(f"{d}/wm_shot_2.bin", "rb").read(), W, H, 4 * W), glyphs, S)
rows = s[0]["rows"] if len(s) == 1 else []
good = (len(s) == 1 and s[0]["focused"] and s[0]["title"].startswith(" 1  logos:")
        and f"out{nb}" in rows and f"out{nb - 1}" in rows
        and any(r.endswith(f"logos:{home}$ _") for r in rows))
if good: print("PASS  leak: the last frame is the terminal, focused, holding the programs' output")
else: print("FAIL  leak: the last frame is wrong\n      " + json.dumps(s)[:800])
sys.exit(0 if good else 1)
PYEOF
else
    echo "FAIL  leak: the last frame was never written"; ok=0
fi
if [ "$ok" = 1 ]; then echo "ALL PASS  gate_wm_leak"; else echo "GATE FAILED  gate_wm_leak"; exit 1; fi
