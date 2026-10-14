#!/usr/bin/env bash
# gate_wm_live.sh — the live WM's loop, emulated headless.
#
# WHAT IT GUARDS. theourgia_wm_live.la runs WM_LOOP in its live shape: input
# read whenever it arrives (2400 bytes at a time) and a frame presented after
# every pass that changed anything; the headless sim instead writes frames only
# on request. The live WM also starts LOCKED, its lock screen built by
# logos_realsess.la's REAL_LOCK, which theourgia_wm_simsess.la builds the same
# way. This gate builds a copy of theourgia_wm_sim.la whose io record has
# exactly the live shape, with `present` replaced by writing the frame to a
# file and logging "wm: present <bytes>", compiles theourgia_wm_simsess.la
# over it (so the lock screen is the live one), and drives it through a FIFO:
#   1  the first frame is presented at startup, before any key is pressed,
#      and it is the lock screen: on a first run (an empty users directory)
#      the first-run screen, not a terminal
#   2  making the first user there presents the welcome terminal without a
#      frame request, and a typed line is presented without one too
#   3  keys typed while the lock screen's attempt runs (seconds of PBKDF2,
#      the lock screen still drawn) were meant for it and never reach the
#      terminal: the passphrase typed again with Enter 0.5 s after the first
#      user's submitting Enter, and again 0.3 s after an unlock's, is in no
#      presented frame and not in the log (the session log, live); a line
#      typed once the unlocked screen is shown still runs
#   4  MOD+Shift+e ends it cleanly
#   5  started again over the same users directory, the first frame
#      presented is the login screen (neither the first-run screen nor a
#      terminal)
# The live entry point itself needs a bare VT and is run by hand
# (drm_bringup_wm.sh); gate_wm_livestart.sh runs it as far as drm_mode, and
# past it with its two screen calls replaced (its check 11).
#
# ISOLATION: a private temporary directory (gate_wm_common.sh). VM only. A few
# minutes, mostly compiling the WM with the session layer on the VM.
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1
wm_setup theourgia_tile.la theourgia_term.la theourgia_render.la logosh.la \
         theourgia_wm.la theourgia_termfont.la logoskit.la lk_settings.la lk_login.la lk_firstuser.la \
         theourgia_wm_sim.la theourgia_wm_simsess.la wm_livestart.la logos_realsess.la \
         logoscrypt.la logossec.la aletheiafs.la logossession.la wm_script.py wm_ocr.py
IO='        (la s. s(la bytes. bytes)(WM_CONS(fd)(WM_NIL))(SYNC("24")("2400"))(SYNC)))'
LIVE='        (la s. s(la bytes. (la _. print(concat("wm: present ")(str_len(bytes))))(write_file("live_frame.bin")(bytes)))(WM_CONS(fd)(WM_NIL))("2400")(la t. la f. f)))'
grep -qxF "$IO" "$T/theourgia_wm_sim.la" || { echo "FAIL  wm live: the sim's io record is not where this gate expects it"; exit 1; }
python3 - "$T/theourgia_wm_sim.la" "$IO" "$LIVE" <<'PYEOF'
import sys
src, io, live = sys.argv[1:4]
s = open(src).read()
open(src, "w").write(s.replace(io + "\n", live + "\n"))
PYEOF
cp "$T/compiler.bin" "$T/logos_program.bin"; cp "$T/theourgia_wm_simsess.la" "$T/logos_source.la"
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
open("wm_sim.cfg", "w").write(f"640 400 1 {T}/home ev.fifo users={T}/users\n")
PASS = "s3cret-live"
def start(tag):
    try: os.unlink("live_frame.bin")
    except OSError: pass
    wm = subprocess.Popen(["./logos_secd"], stdout=open(f"{tag}.log", "w"), stderr=open(f"{tag}.err", "w"))
    return wm, open("ev.fifo", "wb", buffering=0)
def log(tag): return open(f"{tag}.log", errors="replace").read()
def wait(wm, tag, pattern, n=1, timeout=30.0):
    t = time.time()
    while time.time() - t < timeout:
        if log(tag).count(pattern) >= n: return round(time.time() - t, 2)
        if wm.poll() is not None: return None
        time.sleep(0.05)
    return None
def wait_after(wm, tag, marker, pattern, timeout=30.0):
    """wait for pattern in the log after the last marker"""
    t = time.time()
    while time.time() - t < timeout:
        l = log(tag)
        if marker in l and pattern in l[l.rindex(marker):]: return True
        if wm.poll() is not None: return False
        time.sleep(0.05)
    return False
def frame():
    try: return ocr.ocr(ocr.Frame(open("live_frame.bin", "rb").read(), 640, 400, 2560), glyphs, 1)
    except OSError: return None
bad = 0
def check(name, cond, detail):
    global bad
    if cond: print(f"PASS  wm live: {name}")
    else: print(f"FAIL  wm live: {name}\n      {detail}"); bad = 1
def lockscreen(s): return bool(s) and len(s) == 1 and s[0].get("kind") == "app" and s[0]["title"].startswith(" Log in")
def has(s, text): return any(text in r for r in s[0]["rows"])
wm, fifo = start("first")
first = wait(wm, "first", "wm: present", 1, timeout=60)
s = frame()
check(f"1 the first frame is presented at startup, before any key ({first} s), and it is the first-run screen, not a terminal",
      first is not None and lockscreen(s) and has(s, "Welcome. Make the first user.") and "wm: open window" not in log("first"),
      f"present after {first} s; frame {str(s)[:300]}; log {log('first')[-300:]!r}")
fifo.write(ws.compile_script([f"type adam\\n{PASS}\\n{PASS}\\n"]))
# 0.5 s later, while adduser and login run, the passphrase is typed again
time.sleep(0.5); fifo.write(ws.compile_script([f"type {PASS}\\n"]))
got = wait(wm, "first", "wm: unlocked", timeout=90)
shown = wait_after(wm, "first", "wm: unlocked", "wm: present"); time.sleep(1.0)
s = frame()
n = log("first").count("wm: present")
fifo.write(ws.compile_script(["type echo hi\\n"]))
got2 = wait(wm, "first", "wm: [1] $ echo hi", timeout=20); time.sleep(1.0)
s2 = frame()
check("2 making the first user presents the welcome terminal, and a typed line is presented, neither on request",
      got is not None and shown and s and len(s) == 1 and s[0].get("kind") == "term" and has(s, "Theourgia tiling window manager")
      and got2 is not None and log("first").count("wm: present") > n and s2 and "hi" in [r.strip() for r in s2[0]["rows"]],
      f"unlocked after {got} s; frame {str(s)[:300]}; then {str(s2)[:200]}; log {log('first')[-300:]!r}")
# lock, unlock, and the passphrase typed again 0.3 s after the unlocking Enter
fifo.write(ws.compile_script(["mod ESC"]))
locked = wait(wm, "first", "wm: locked") and wait_after(wm, "first", "wm: locked", "wm: present"); time.sleep(0.5)
fifo.write(ws.compile_script([f"type {PASS}\\n"]))
time.sleep(0.3); fifo.write(ws.compile_script([f"type {PASS}\\n"]))
got3 = wait(wm, "first", "wm: unlocked", 2, timeout=60)
shown3 = wait_after(wm, "first", "wm: unlocked", "wm: present"); time.sleep(1.0)
s3 = frame()
fifo.write(ws.compile_script(["type echo two\\n"]))
got4 = wait(wm, "first", "wm: [1] $ echo two", timeout=20); time.sleep(1.0)
s4 = frame()
def rows_with(fr, text): return [r for t in (fr or []) for r in t["rows"] if text in r]
check("3 the passphrase typed again while the attempt ran (after the first user's Enter, and after an unlock's) is in no frame and not in the log; a line typed afterwards runs",
      got is not None and shown and locked and got3 is not None and shown3 and got4 is not None
      and s3 and len(s3) == 1 and s3[0].get("kind") == "term" and s4 and "two" in [r.strip() for r in s4[0]["rows"]]
      and not any(rows_with(f, PASS) or rows_with(f, PASS[1:]) for f in (s, s2, s3, s4))
      and PASS not in log("first") and PASS not in open("first.err").read(),
      f"after the first user: {rows_with(s, PASS[1:])}; after the unlock: {rows_with(s3, PASS[1:])}; "
      f"log lines: {[l for l in log('first').splitlines() if PASS in l]}; locked {locked} got3 {got3} shown3 {shown3} got4 {got4}")
fifo.write(ws.compile_script(["mod Shift+E"])); fifo.close()
try: rc = wm.wait(timeout=60)
except subprocess.TimeoutExpired:
    wm.kill(); rc = "timeout"
check("4 MOD+Shift+e ends it cleanly", rc == 0 and "wm: exit" in log("first"), f"rc={rc}; {log('first')[-200:]!r}")
wm, fifo = start("again")
first = wait(wm, "again", "wm: present", 1, timeout=60)
s = frame()
check(f"5 started again over the same users, the first frame presented ({first} s) is the login screen",
      first is not None and lockscreen(s) and has(s, "Log in to LogOS.") and not has(s, "Make the first user"),
      f"present after {first} s; frame {str(s)[:300]}; log {log('again')[-300:]!r}")
fifo.close(); wm.terminate()
try: wm.wait(timeout=30)
except subprocess.TimeoutExpired: wm.kill()
sys.exit(bad)
PYEOF
if [ "$ok" = 1 ]; then echo "ALL PASS  gate_wm_live"; else echo "GATE FAILED  gate_wm_live"; exit 1; fi
