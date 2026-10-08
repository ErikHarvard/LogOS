#!/usr/bin/env bash
# gate_wm_session.sh — the whole tiling window manager, end to end, headless.
#
# WHAT IT GUARDS. theourgia_wm_sim.la runs the real window manager — WM_BUILD,
# the poll loop, logosh, real child processes — with the keyboard replaced by a
# file of evdev records and the screen by frame files. This gate types a scripted
# session into it and reads every requested frame back as TEXT (wm_ocr.py finds
# each tile by its border colour and matches every character cell against the
# font), then checks what is on the screen:
#    1  the first window: the welcome text and the prompt with its cursor
#    2  a shell builtin's output (echo)
#    3  MOD+Enter: two windows side by side, the new one focused; cd + pwd
#    4  an external program found on PATH, started with fork/dup2/execv, its
#       output read through the pipe by the poll loop
#    5  MOD+Left moves the focus;  6  MOD+Shift+Right swaps the two windows
#    7  MOD+t: side by side becomes stacked
#    8  MOD+q closes the focused window; the other fills the screen
#    9  `exit` in the last shell closes it: an empty desktop
#   10  MOD+Enter again (window 3) and a command that does not exist
#   11  MOD+s: LogosKit's settings panel in window 4, light, focus on Name
#   12  typing edits the field; Tab+Space turns on the dark theme, and the
#       panel holding the switch is redrawn dark (LogosKit drawing itself)
#   13  Tab, Down: "Text scale 2" — the panel holding the setting is redrawn
#       at twice the text scale (zoom 2), still dark
#   14  MOD+Esc: the screen is locked — only the login panel, centred
#   15  logging in (the simulator's stand-in session: adam / logos) unlocks,
#       and the two windows are back as they were
# and that MOD+Shift+e ends the session cleanly (rc 0, "wm: exit").
# DETERMINISM: the session is run twice; every frame must be byte-identical.
#
# ISOLATION: a private temporary directory (gate_wm_common.sh). VM only: the
# window manager needs poll/fork/execv, which only the VM has. Several minutes,
# mostly compiling the WM on the VM.
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1

wm_setup theourgia_tile.la theourgia_term.la theourgia_render.la logosh.la \
         theourgia_wm.la theourgia_termfont.la logoskit.la lk_settings.la lk_login.la theourgia_wm_sim.la \
         wm_script.py wm_ocr.py
W=960; H=600; SCALE=1
mkdir -p "$T/home/sub"
echo "$W $H $SCALE $T/home events.bin" > "$T/wm_sim.cfg"
cat > "$T/session.txt" <<'EOF'
snap 1
type echo hello world\n
snap 2
mod Enter
type cd sub\n
type pwd\n
snap 3
type /bin/echo external\n
snap 4
mod Left
snap 5
mod Shift+Right
snap 6
mod t
snap 7
mod q
snap 8
type exit\n
snap 9
mod Enter
type nosuchcommand\n
snap 10
mod s
snap 11
type x
key TAB
key SPACE
snap 12
key TAB
key DOWN
snap 13
mod ESC
snap 14
type adam
key TAB
type logos\n
snap 15
mod Shift+E
EOF
python3 "$T/wm_script.py" "$T/session.txt" "$T/events.bin" || { echo "FAIL  session: wm_script.py"; exit 1; }

run_session() {   # $1 = output dir for the frames
    mkdir -p "$1"; rm -f "$T"/wm_shot_*.bin
    wm_vm theourgia_wm_sim.la "$1/log.txt"
    cp "$T"/wm_shot_*.bin "$1/" 2>/dev/null
}
t0=$(date +%s)
run_session "$T/run1"
t1=$(date +%s)
if [ "$vrc" != 0 ]; then
    echo "FAIL  session: the headless WM rc=$vrc"
    echo "      compile: $(tail -3 "$T/vce")"; echo "      run: $(tail -3 "$T/vre")"; tail -5 "$T/run1/log.txt"; exit 1
fi
echo "      (session ran in $((t1 - t0)) s, including the VM compile)"
grep -qx "wm: exit" "$T/run1/log.txt" || { echo "FAIL  session: no clean 'wm: exit' in the log"; ok=0; }

python3 - "$T/run1" "$W" "$H" "$SCALE" "$T/theourgia_termfont.la" "$T/wm_ocr.py" "$T/home" <<'PYEOF' || ok=0
import importlib.util, json, sys
d, W, H, S, font, ocrpath, home = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), sys.argv[5], sys.argv[6], sys.argv[7]
spec = importlib.util.spec_from_file_location("wm_ocr", ocrpath); ocr = importlib.util.module_from_spec(spec); spec.loader.exec_module(ocr)
glyphs = ocr.load_font(font)
def shot(n):
    data = open(f"{d}/wm_shot_{n}.bin", "rb").read()
    return ocr.ocr(ocr.Frame(data, W, H, 4 * W), glyphs, S)
bad = 0
def check(name, cond, detail):
    global bad
    if cond: print(f"PASS  session: {name}")
    else: print(f"FAIL  session: {name}\n      {detail}"); bad = 1
def text(t): return "\n".join(t["rows"])
def focused(ts): return [t for t in ts if t["focused"]]
prompt = f"logos:{home}$ "

s = shot(1)
check("1 one window, focused, welcome text and prompt with cursor",
      len(s) == 1 and s[0]["focused"] and "Theourgia tiling window manager" in text(s[0])
      and any(r.endswith(prompt + "_") or r.endswith(prompt.rstrip() + " _") for r in s[0]["rows"])
      and s[0]["title"].startswith(" 1  logos:"),
      json.dumps(s)[:600])
s = shot(2)
check("2 echo's output and the echoed command line",
      len(s) == 1 and "hello world" in s[0]["rows"] and any(r.endswith("$ echo hello world") for r in s[0]["rows"]),
      json.dumps(s)[:600])
s = shot(3)
two = sorted(s, key=lambda t: t["x"])
check("3 MOD+Enter: two side-by-side windows, the new (right) one focused, cd + pwd in it",
      len(s) == 2 and two[0]["y"] == two[1]["y"] and two[1]["focused"] and not two[0]["focused"]
      and two[1]["title"].startswith(" 2  ") and f"{home}/sub" in two[1]["rows"],
      json.dumps(s)[:800])
s = shot(4)
f = focused(s)
check("4 an external program (/bin/echo) runs and its output arrives through the pipe",
      len(f) == 1 and "external" in f[0]["rows"], json.dumps(s)[:800])
s = shot(5)
two = sorted(s, key=lambda t: t["x"])
check("5 MOD+Left: the focus moves to the left window",
      len(s) == 2 and two[0]["focused"] and two[0]["title"].startswith(" 1  "), json.dumps(s)[:800])
s = shot(6)
two = sorted(s, key=lambda t: t["x"])
check("6 MOD+Shift+Right: window 1 swaps to the right and keeps the focus",
      len(s) == 2 and two[1]["focused"] and two[1]["title"].startswith(" 1  ") and two[0]["title"].startswith(" 2  "),
      json.dumps(s)[:800])
s = shot(7)
two = sorted(s, key=lambda t: t["y"])
check("7 MOD+t: the two windows are stacked", len(s) == 2 and two[0]["x"] == two[1]["x"] and two[0]["y"] < two[1]["y"],
      json.dumps(s)[:800])
s = shot(8)
check("8 MOD+q: window 1 is gone, window 2 fills the screen and has the focus",
      len(s) == 1 and s[0]["focused"] and s[0]["title"].startswith(" 2  ") and s[0]["w"] > W - 40,
      json.dumps(s)[:800])
s = shot(9)
check("9 exit in the last shell: an empty desktop", len(s) == 0, json.dumps(s)[:400])
s = shot(10)
check("10 MOD+Enter again opens window 3; a missing command says so",
      len(s) == 1 and s[0]["title"].startswith(" 3  ")
      and "logosh: nosuchcommand: command not found" in s[0]["rows"], json.dumps(s)[:800])
s = shot(11)
app = [t for t in s if t.get("kind") == "app"]
check("11 MOD+s: the settings panel in window 4, light, focused on the Name field",
      len(s) == 2 and len(app) == 1 and app[0]["focused"] and app[0]["title"].startswith(" 4  Settings")
      and app[0]["theme"] == "light" and any("LogosKit settings" in r for r in app[0]["rows"])
      and any("Name: [sovereign" in r for r in app[0]["rows"])
      and any(h.strip().startswith("[sovereign") for _, h in app[0]["hl"]),
      json.dumps(s)[:1200])
s = shot(12)
app = [t for t in s if t.get("kind") == "app"]
check("12 the dark theme switch redraws its own panel dark; the field kept the typed x",
      len(app) == 1 and app[0]["theme"] == "dark" and any("Name: [sovereignx" in r for r in app[0]["rows"])
      and any(h.strip() == "[x] Dark theme" for _, h in app[0]["hl"]),
      json.dumps(s)[:1200])
s = shot(13)
app = [t for t in s if t.get("kind") == "app"]
check("13 Text scale 2: the panel is redrawn at twice the text scale, still dark",
      len(app) == 1 and app[0]["zoom"] == 2 and app[0]["theme"] == "dark"
      and any(h.strip() == "> Text scale 2" for _, h in app[0]["hl"]) and any("Name: [sovereignx" in r for r in app[0]["rows"]),
      json.dumps(s)[:1200])
before = s
s = shot(14)
check("14 MOD+Esc: only the login panel, centred, focused on User",
      len(s) == 1 and s[0].get("kind") == "app" and s[0]["title"].startswith(" Log in")
      and abs((s[0]["x"] + s[0]["w"] / 2) - W / 2) <= 1 and abs((s[0]["y"] + s[0]["h"] / 2) - H / 2) <= 1
      and any("Log in to LogOS." in r for r in s[0]["rows"])
      and any(h.strip().startswith("[") and "User" not in h for _, h in s[0]["hl"])
      and any("User: [" in r for r in s[0]["rows"]),
      json.dumps(s)[:1200])
s = shot(15)
check("15 logging in unlocks: the two windows are back as they were",
      len(s) == 2 and [t["title"] for t in sorted(s, key=lambda t: t["x"])] == [t["title"] for t in sorted(before, key=lambda t: t["x"])],
      json.dumps(s)[:1200])
sys.exit(bad)
PYEOF

run_session "$T/run2"
same=1
for f in "$T"/run1/wm_shot_*.bin; do cmp -s "$f" "$T/run2/$(basename "$f")" || same=0; done
n=$(ls "$T"/run1/wm_shot_*.bin 2>/dev/null | wc -l)
if [ "$vrc" = 0 ] && [ "$same" = 1 ] && [ "$n" = 15 ]; then
    echo "PASS  session: a second run gives byte-identical frames ($n frames)"
else
    echo "FAIL  session: second run rc=$vrc, identical=$same, frames=$n"; ok=0
fi

[ "$ok" = 1 ] || exit 1
