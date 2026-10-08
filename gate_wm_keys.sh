#!/usr/bin/env bash
# gate_wm_keys.sh — what the WM does with held keys.
#
# WHAT IT GUARDS. The keys the WM offers, and what it does with held keys.
# A key held down sends one press (value 1), then autorepeats
# (value 2) until its release (value 0). The headless WM (theourgia_wm_sim.la,
# sync mode) is fed such raw sequences (wm_script.py's down/repeat/up) and
# every frame is read back as text (wm_ocr.py):
#   1  a held letter autorepeats in a terminal ("aaaa")
#   2  the Enter that unlocks the screen, held past the autorepeat delay, does
#      not reach the terminal: the line typed before locking stays unrun
#   3  after that Enter is released, the next Enter runs the line as usual
#   4  the welcome text offers MOD+Esc (lock the screen) when there is a lock
#      screen, and does not offer it when there is none (as in the live WM
#      until a session layer is wired in): a run of a copy of the sim with
#      its lock layer removed, where MOD+Esc changes nothing
#
# ISOLATION: a private temporary directory (gate_wm_common.sh). VM only. A few
# minutes, mostly compiling the WM on the VM.
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1
wm_setup theourgia_tile.la theourgia_term.la theourgia_render.la logosh.la \
         theourgia_wm.la theourgia_termfont.la logoskit.la lk_settings.la lk_login.la theourgia_wm_sim.la \
         wm_script.py wm_ocr.py
mkdir -p "$T/home"
echo "960 600 1 $T/home events.bin" > "$T/wm_sim.cfg"
cat > "$T/keys.txt" <<'EOF'
down A
repeat A 3
up A
snap 1
key BACKSPACE
key BACKSPACE
key BACKSPACE
key BACKSPACE
type echo pending
mod ESC
type adam
key TAB
type logos
down ENTER
repeat ENTER 3
up ENTER
snap 2
key ENTER
snap 3
mod Shift+E
EOF
python3 "$T/wm_script.py" "$T/keys.txt" "$T/events.bin" || { echo "FAIL  wm keys: wm_script.py"; exit 1; }
wm_vm theourgia_wm_sim.la "$T/log.txt"
if [ "$vrc" != 0 ]; then
    echo "FAIL  wm keys: the headless WM rc=$vrc"; tail -3 "$T/vce" "$T/vre"; tail -5 "$T/log.txt"; exit 1
fi
# the same WM without a lock screen
sed 's/(la n. la s. s(la k. k(LOGIN_APP)(SIM_SESS)(la t. la f. f)))/(la n. la s. n(n))/' \
    "$T/theourgia_wm_sim.la" > "$T/wm_nolock.la"
grep -q 'SETTINGS_APP)(la n. la s. n(n)))' "$T/wm_nolock.la" || { echo "FAIL  wm keys: could not remove the sim's lock layer"; exit 1; }
mkdir -p "$T/withlock" && mv "$T"/wm_shot_*.bin "$T/withlock/"
printf 'snap 4\nmod ESC\nsnap 5\nmod Shift+E\n' > "$T/nolock.txt"
python3 "$T/wm_script.py" "$T/nolock.txt" "$T/events.bin" || { echo "FAIL  wm keys: wm_script.py"; exit 1; }
wm_vm wm_nolock.la "$T/log_nolock.txt"
if [ "$vrc" != 0 ]; then
    echo "FAIL  wm keys: the WM without a lock screen rc=$vrc"; tail -3 "$T/vce" "$T/vre"; exit 1
fi
mv "$T"/wm_shot_*.bin "$T/withlock/"

python3 - "$T" <<'PYEOF' || ok=0
import importlib.util, json, sys
T = sys.argv[1]
spec = importlib.util.spec_from_file_location("wm_ocr", f"{T}/wm_ocr.py"); ocr = importlib.util.module_from_spec(spec); spec.loader.exec_module(ocr)
glyphs = ocr.load_font(f"{T}/theourgia_termfont.la")
def shot(n):
    try: data = open(f"{T}/withlock/wm_shot_{n}.bin", "rb").read()
    except OSError: return None
    return ocr.ocr(ocr.Frame(data, 960, 600, 3840), glyphs, 1)
log = open(f"{T}/log.txt").read()
bad = 0
def check(name, cond, detail):
    global bad
    if cond: print(f"PASS  wm keys: {name}")
    else: print(f"FAIL  wm keys: {name}\n      {detail}"); bad = 1
prompt = f"logos:{T}/home$ "
s = shot(1)
check("1 a held letter autorepeats in a terminal (press + 3 repeats = aaaa)",
      s and len(s) == 1 and any(r.endswith(prompt + "aaaa_") for r in s[0]["rows"]), json.dumps(s)[:600])
s = shot(2)
check("2 the held Enter that unlocked the screen does not run the terminal's pending line",
      s and len(s) == 1 and "wm: unlocked" in log and "$ echo pending" not in log.split("wm: unlocked")[1].split("wm: snap 2")[0]
      and any(r.endswith(prompt + "echo pending_") for r in s[0]["rows"]) and "pending" not in [r.strip() for r in s[0]["rows"]],
      json.dumps(s)[:600] + " log: " + log[-400:])
s = shot(3)
check("3 after its release, the next Enter runs the line",
      s and len(s) == 1 and "pending" in [r.strip() for r in s[0]["rows"]]
      and "wm: [1] $ echo pending" in log.split("wm: snap 2")[-1], json.dumps(s)[:600] + " log: " + log[-400:])
check("the WM exits cleanly", "wm: exit" in log, log[-300:])
LOCKLINE = "MOD+Esc      lock the screen"
s = shot(1)
check("4 with a lock screen, the welcome text offers MOD+Esc", s and any(LOCKLINE in r for r in s[0]["rows"]), json.dumps(s)[:600])
s4, s5 = shot(4), shot(5)
log2 = open(f"{T}/log_nolock.txt").read()
check("4 without one, the welcome text does not offer it (and MOD+Esc changes nothing)",
      s4 and len(s4) == 1 and any("MOD+s      settings panel" in r for r in s4[0]["rows"])
      and not any("MOD+Esc" in r for r in s4[0]["rows"])
      and s5 and s5 == s4 and "wm: locked" not in log2 and "wm: exit" in log2,
      json.dumps(s4)[:800])
sys.exit(bad)
PYEOF
if [ "$ok" = 1 ]; then echo "ALL PASS  gate_wm_keys"; else echo "GATE FAILED  gate_wm_keys"; exit 1; fi
