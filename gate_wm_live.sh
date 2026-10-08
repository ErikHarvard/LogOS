#!/usr/bin/env bash
# gate_wm_live.sh — the live WM's loop, emulated headless.
#
# WHAT IT GUARDS. theourgia_wm_live.la runs WM_LOOP in its live shape: input
# read whenever it arrives (2400 bytes at a time) and a frame presented after
# every pass that changed anything; the headless sim instead writes frames only
# on request. This gate builds a copy of theourgia_wm_sim.la whose io record
# has exactly the live shape, with `present` replaced by writing the frame to
# a file and logging "wm: present <bytes>", and drives it through a FIFO:
#   1  the first frame (the welcome terminal) is presented at startup, before
#      any key is pressed: a user who has just launched the WM sees it
#   2  a typed line is presented without a frame request
#   3  MOD+Shift+e ends it cleanly
# The live entry point itself needs a bare VT and is run by hand
# (drm_bringup_wm.sh).
#
# ISOLATION: a private temporary directory (gate_wm_common.sh). VM only. A few
# minutes, mostly compiling the WM on the VM.
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1
wm_setup theourgia_tile.la theourgia_term.la theourgia_render.la logosh.la \
         theourgia_wm.la theourgia_termfont.la logoskit.la lk_settings.la lk_login.la theourgia_wm_sim.la \
         wm_script.py wm_ocr.py
IO='        (la s. s(la bytes. bytes)(WM_CONS(fd)(WM_NIL))(SYNC("24")("2400"))(SYNC)))'
LIVE='        (la s. s(la bytes. (la _. print(concat("wm: present ")(str_len(bytes))))(write_file("live_frame.bin")(bytes)))(WM_CONS(fd)(WM_NIL))("2400")(la t. la f. f)))'
grep -qxF "$IO" "$T/theourgia_wm_sim.la" || { echo "FAIL  wm live: the sim's io record is not where this gate expects it"; exit 1; }
python3 - "$T/theourgia_wm_sim.la" "$T/wm_live_emu.la" "$IO" "$LIVE" <<'PYEOF'
import sys
src, dst, io, live = sys.argv[1:5]
open(dst, "w").write(open(src).read().replace(io + "\n", live + "\n"))
PYEOF
cp "$T/compiler.bin" "$T/logos_program.bin"; cp "$T/wm_live_emu.la" "$T/logos_source.la"
( cd "$T" && timeout "$WM_VM_TIMEOUT" ./logos_secd >/dev/null 2>"$T/vce" ) \
  || { echo "FAIL  wm live: the emulation did not compile: $(tail -3 "$T/vce")"; exit 1; }

python3 - "$T" <<'PYEOF' || ok=0
import importlib.util, os, subprocess, sys, time
T = sys.argv[1]; os.chdir(T)
def load(name):
    spec = importlib.util.spec_from_file_location(name, f"{T}/{name}.py")
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m
ws, ocr = load("wm_script"), load("wm_ocr")
glyphs = ocr.load_font(f"{T}/theourgia_termfont.la")
os.makedirs("home")
os.mkfifo("ev.fifo")
open("wm_sim.cfg", "w").write(f"640 400 1 {T}/home ev.fifo\n")
wm = subprocess.Popen(["./logos_secd"], stdout=open("live.log", "w"), stderr=open("live.err", "w"))
fifo = open("ev.fifo", "wb", buffering=0)
def log(): return open("live.log", errors="replace").read()
def wait(pattern, n=1, timeout=30.0):
    t = time.time()
    while time.time() - t < timeout:
        if log().count(pattern) >= n: return round(time.time() - t, 2)
        if wm.poll() is not None: return None
        time.sleep(0.05)
    return None
def frame():
    try: return ocr.ocr(ocr.Frame(open("live_frame.bin", "rb").read(), 640, 400, 2560), glyphs, 1)
    except OSError: return None
bad = 0
def check(name, cond, detail):
    global bad
    if cond: print(f"PASS  wm live: {name}")
    else: print(f"FAIL  wm live: {name}\n      {detail}"); bad = 1
first = wait("wm: present", 1, timeout=20)
s = frame()
check(f"1 the first frame is presented at startup, before any key ({first} s)",
      first is not None and s and len(s) == 1 and s[0]["focused"]
      and any("Theourgia tiling window manager" in r for r in s[0]["rows"]),
      f"present after {first} s; frame {str(s)[:300]}; log {log()[-300:]!r}")
n = log().count("wm: present")
fifo.write(ws.compile_script(["type echo hi\\n"]))
got = wait("wm: [1] $ echo hi", timeout=20); time.sleep(1.0)
s = frame()
check("2 a typed line is presented without a frame request",
      got is not None and log().count("wm: present") > n and s and "hi" in [r.strip() for r in s[0]["rows"]],
      f"frame {str(s)[:300]}")
fifo.write(ws.compile_script(["mod Shift+E"])); fifo.close()
try: rc = wm.wait(timeout=60)
except subprocess.TimeoutExpired:
    wm.kill(); rc = "timeout"
check("3 MOD+Shift+e ends it cleanly", rc == 0 and "wm: exit" in log(), f"rc={rc}; {log()[-200:]!r}")
sys.exit(bad)
PYEOF
if [ "$ok" = 1 ]; then echo "ALL PASS  gate_wm_live"; else echo "GATE FAILED  gate_wm_live"; exit 1; fi
