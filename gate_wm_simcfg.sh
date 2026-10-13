#!/usr/bin/env bash
# gate_wm_simcfg.sh — the headless WM refuses a bad configuration loudly.
#
# WHAT IT GUARDS. theourgia_wm_sim.la reads one line, wm_sim.cfg:
# "W H SCALE CWD EVENTS [async]". Every gate that drives the WM headless
# depends on it, so a mistake in it must stop the run at once with a message
# (rc 1), never spin, hang, or run silently in the wrong mode. Cases:
#   missing  EVENTS names no file          -> rc 1, "cannot open"
#   dir      EVENTS names a directory      -> rc 1, "is a directory"
#   scale0   SCALE 0                       -> rc 1, "SCALE"
#   scaleneg SCALE -1                      -> rc 1, "SCALE"
#   word6    a sixth word that is not async -> rc 1, "async"
#   crlf     the line ends in \r\n         -> runs (rc 0), the \r is not part of
#                                             the EVENTS name
#   tinyw    W 11                          -> rc 1, "at least 12"
#   tinyh    H 5                           -> rc 1, "at least 12"
#   zero     W and H 0                     -> rc 1, "at least 12"
#   min      12 x 12, the smallest screen  -> runs (rc 0): a frame, a second
#            with room for the WM's two       window, the lock screen
#            6-pixel gaps each way
#            (a smaller screen ran with zero-width tiles, or halted in compose
#            on its first frame or when it locked)
#   unreadable  EVENTS opens but every read of it fails (/proc/self/mem at
#            offset 0: EIO)        -> rc 0 within a few seconds, "input
#            finished" on stdout. The VM's read turns every error into "", so
#            the WM's loop takes a failing input device for the end of its
#            input: it stops polling that fd (it must never be polled again,
#            or a device that keeps reporting ready would spin the loop) and
#            ends once nothing runs. This is the same WM_LOOP the live WM runs,
#            which cannot be reached there without a GPU.
# Each case has 30 s; the bad ones must fail within a few.
#
# ISOLATION: a private temporary directory (gate_wm_common.sh). VM only. A few
# minutes, mostly compiling the WM on the VM.
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1
wm_setup theourgia_tile.la theourgia_term.la theourgia_render.la logosh.la \
         theourgia_wm.la theourgia_termfont.la logoskit.la lk_settings.la lk_login.la theourgia_wm_sim.la \
         wm_script.py wm_ocr.py
cp "$T/compiler.bin" "$T/logos_program.bin"; cp "$T/theourgia_wm_sim.la" "$T/logos_source.la"
( cd "$T" && timeout "$WM_VM_TIMEOUT" ./logos_secd >/dev/null 2>"$T/vce" ) \
  || { echo "FAIL  wm simcfg: the WM did not compile: $(tail -3 "$T/vce")"; exit 1; }
cp "$T/logos_program.bin" "$T/wm.bin"

python3 - "$T" <<'PYEOF' || ok=0
import importlib.util, os, shutil, subprocess, sys, time
T = sys.argv[1]
spec = importlib.util.spec_from_file_location("wm_script", f"{T}/wm_script.py"); ws = importlib.util.module_from_spec(spec); spec.loader.exec_module(ws)
EV = ws.compile_script(["snap 1", "mod Shift+E"])
# min: a frame, a second window, then the lock screen (which takes every key,
# so the run ends when the events do)
EVMIN = ws.compile_script(["snap 1", "mod Enter", "snap 2", "mod ESC", "snap 3"])
CASES = [("missing", "640 400 1 / nosuch.bin\n", "cannot open"),
         ("dir", "640 400 1 / home\n", "is a directory"),
         ("scale0", "640 400 0 / events.bin\n", "SCALE"),
         ("scaleneg", "640 400 -1 / events.bin\n", "SCALE"),
         ("word6", "640 400 1 / events.bin Async\n", "async"),
         ("crlf", "640 400 1 / events.bin\r\n", None),
         ("tinyw", "11 400 1 / events.bin\n", "at least 12"),
         ("tinyh", "640 5 1 / events.bin\n", "at least 12"),
         ("zero", "0 0 1 / events.bin\n", "at least 12"),
         ("min", "12 12 1 / events.bin\n", None),
         ("unreadable", "640 400 1 / /proc/self/mem\n", None)]
bad = 0
for name, cfg, want in CASES:
    d = f"{T}/case_{name}"; os.makedirs(f"{d}/home")
    shutil.copy(f"{T}/logos_secd", d); shutil.copy(f"{T}/wm.bin", f"{d}/logos_program.bin")
    open(f"{d}/events.bin", "wb").write(EVMIN if name == "min" else EV)
    open(f"{d}/wm_sim.cfg", "w", newline="").write(cfg)
    t0 = time.time()
    try:
        p = subprocess.run(["./logos_secd"], cwd=d, capture_output=True, timeout=30)
        rc, out, err = p.returncode, p.stdout.decode(errors="replace"), p.stderr.decode(errors="replace")
    except subprocess.TimeoutExpired as e:
        rc, out, err = "timeout", (e.stdout or b"").decode(errors="replace"), (e.stderr or b"").decode(errors="replace")
    dt = round(time.time() - t0, 1)
    if name == "min":
        good = rc == 0 and all(f"wm: snap {n}" in out for n in (1, 2, 3)) and "wm: locked" in out
        what = "12 x 12 runs: a frame, a second window, the lock screen (rc 0, three frames)"
    elif name == "unreadable":
        good = rc == 0 and "wm: input finished and nothing is running" in out and dt < 15
        what = "an input device whose reads fail ends the input: no spin (rc 0, 'input finished', at once)"
    elif want is None:
        good = rc == 0 and "wm: snap 1" in out and "wm: exit" in out
        what = "a \\r\\n line is read as the same configuration (rc 0, the frame written)"
    else:
        good = rc == 1 and want in err and dt < 15
        what = f"refused loudly: rc 1 and '{want}' in the message"
    if good: print(f"PASS  wm simcfg: {name}: {what} ({dt} s)")
    else:
        print(f"FAIL  wm simcfg: {name}: {what}\n      rc={rc} after {dt} s; stderr {err[-200:]!r}; stdout {out[-200:]!r}"); bad = 1
sys.exit(bad)
PYEOF
if [ "$ok" = 1 ]; then echo "ALL PASS  gate_wm_simcfg"; else echo "GATE FAILED  gate_wm_simcfg"; exit 1; fi
