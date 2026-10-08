#!/usr/bin/env bash
# gate_wm_jobs.sh — the tiling WM and RUNNING programs, driven with real timing.
#
# WHAT IT GUARDS. gate_wm_session.sh runs the headless WM deterministically:
# it reads input only while no command runs, so it can never press a key
# WHILE a program runs. This gate runs the same headless WM in its async mode
# (wm_sim.cfg's sixth word): input is read whenever it arrives, as on a live
# VT, and a Python driver writes the key events into a FIFO with pauses
# between them. It checks, reading every frame back as text (wm_ocr.py):
#   2  a running program shows in its window's title ("[running] ...")
#   3  MOD+c interrupts it: "[signal 2]" and the prompt come back
#   4  MOD+Enter opens a second window while a program runs in the first
#   5  MOD+q on the window whose program runs closes the window and ends the
#      program; the other window keeps the focus
#   6  a program keeps running while the screen is locked (MOD+Esc), and its
#      output is in its window after unlocking
# and that the WM exits 0 on MOD+Shift+e with none of its programs left
# running. The pauses are generous (programs here take milliseconds to
# start), but it is a timing test on a shared machine.
#
# ISOLATION: private temp dir (gate_wm_common.sh). VM only. A few minutes,
# mostly compiling the WM on the VM.
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1
wm_setup theourgia_tile.la theourgia_term.la theourgia_render.la logosh.la \
         theourgia_wm.la theourgia_termfont.la logoskit.la lk_settings.la lk_login.la theourgia_wm_sim.la \
         wm_script.py wm_ocr.py
mkdir -p "$T/home"
# a program that prints a second after it starts (an argument may not contain
# a space: the VM's execv takes the arguments as one space-separated string)
printf 'sleep 1\necho late output\n' > "$T/home/late.sh"
# compile only (the driver runs it)
cp "$T/compiler.bin" "$T/logos_program.bin"; cp "$T/theourgia_wm_sim.la" "$T/logos_source.la"
( cd "$T" && timeout "${WM_VM_TIMEOUT:-1800}" ./logos_secd >/dev/null 2>"$T/vce" ) \
  || { echo "FAIL  wm jobs: the WM did not compile: $(tail -3 "$T/vce")"; exit 1; }

python3 - "$T" <<'PYEOF' || ok=0
import importlib.util, os, subprocess, sys, time
T = sys.argv[1]; os.chdir(T)
def load(name):
    spec = importlib.util.spec_from_file_location(name, f"{T}/{name}.py")
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m
ws, ocr = load("wm_script"), load("wm_ocr")
os.mkfifo("ev.fifo")
open("wm_sim.cfg", "w").write(f"960 600 1 {T}/home ev.fifo async\n")
wm = subprocess.Popen(["./logos_secd"], stdout=open("jobs.log", "w"), stderr=open("jobs.err", "w"))
fifo = open("ev.fifo", "wb", buffering=0)
def send(script, wait):
    fifo.write(ws.compile_script(script.split("\n"))); time.sleep(wait)
send("snap 1", 1.0)
send("type /bin/sleep 37\\n", 1.5)
send("snap 2", 0.5)
send("mod c", 1.5)
send("snap 3", 0.5)
send("type /bin/sleep 37\\n", 1.5)
send("mod Enter", 0.5)
send("snap 4", 0.5)
send("mod Left", 0.5)
send("mod q", 2.0)
send("snap 5", 0.5)
send("type /bin/sh late.sh\\n", 0.3)
send("mod ESC", 2.5)
send("type adam\nkey TAB\ntype logos\\n", 1.0)
send("snap 6", 0.5)
send("mod Shift+E", 0.0)
fifo.close()
try:
    rc = wm.wait(timeout=120)
except subprocess.TimeoutExpired:
    wm.kill(); rc = "timeout"
glyphs = ocr.load_font(f"{T}/theourgia_termfont.la")
bad = 0
def check(name, cond, detail):
    global bad
    if cond: print(f"PASS  wm jobs: {name}")
    else: print(f"FAIL  wm jobs: {name}\n      {detail}"); bad = 1
def shot(n):
    try: data = open(f"wm_shot_{n}.bin", "rb").read()
    except OSError: return None
    return ocr.ocr(ocr.Frame(data, 960, 600, 3840), glyphs, 1)
def rows(t): return [r for r in t["rows"] if r.strip()]
log = open("jobs.log").read()
check("the WM ran the whole session and exited 0 on MOD+Shift+e", rc == 0 and "wm: exit" in log,
      f"rc={rc}; log tail: {log[-300:]!r}; stderr: {open('jobs.err').read()[-300:]!r}")
s = shot(2)
check("2 a running program is in its window's title", s and len(s) == 1 and "[running] /bin/sleep 37" in s[0]["title"], str(s)[:400])
s = shot(3)
check("3 MOD+c interrupts it: [signal 2], then the prompt", s and len(s) == 1 and "[signal 2]" in rows(s[0])
      and rows(s[0])[-1].endswith("$ _") and "[running]" not in s[0]["title"], str(s)[:600])
s = shot(4)
two = sorted(s or [], key=lambda t: t["x"])
check("4 MOD+Enter opens window 2 while window 1's program runs", len(two) == 2 and "[running] /bin/sleep 37" in two[0]["title"]
      and two[1]["focused"] and two[1]["title"].startswith(" 2  "), str(s)[:600])
s = shot(5)
check("5 MOD+q closes the window whose program runs; window 2 is left, focused", s and len(s) == 1
      and s[0]["focused"] and s[0]["title"].startswith(" 2  "), str(s)[:600])
s = shot(6)
check("6 a program kept running while the screen was locked; its output is there after unlocking",
      s and len(s) == 1 and "late output" in rows(s[0]) and "wm: locked" in log and "wm: unlocked" in log, str(s)[:600])
left = subprocess.run(["pgrep", "-f", "sleep 37"], capture_output=True, text=True).stdout.split()
check("none of the WM's programs is left running", not left, f"left: {left}")
for p in left:
    subprocess.run(["kill", p])
sys.exit(bad)
PYEOF
[ "$ok" = 1 ] || exit 1
