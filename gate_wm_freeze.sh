#!/usr/bin/env bash
# gate_wm_freeze.sh — a running program never freezes the window manager.
#
# WHAT IT GUARDS. WM_DESIGN.md: a command's output reaches the WM through a
# pipe "that the WM's single poll loop multiplexes with the keyboard, so a
# running command never freezes the screen or the other windows." This gate
# runs the headless WM in its async mode (input read whenever it arrives, as
# on a live VT), drives it through a FIFO with real timing, and checks that the
# WM keeps serving the keyboard while programs run:
#   flood  while one window's program prints without end (/usr/bin/yes), a
#          line typed into another window is handled within a few seconds,
#          and MOD+c stops the flood
# Each scenario runs in its own directory with a fresh WM; its log lines are
# time-stamped by the driver. The bounds are generous (the fixed WM needs a
# fraction of them), but this is a timing test on a shared machine.
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
  || { echo "FAIL  wm freeze: the WM did not compile: $(tail -3 "$T/vce")"; exit 1; }
cp "$T/logos_program.bin" "$T/wm.bin"

python3 - "$T" <<'PYEOF' || ok=0
import importlib.util, os, shutil, subprocess, sys, time
T = sys.argv[1]
def load(name):
    spec = importlib.util.spec_from_file_location(name, f"{T}/{name}.py")
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m
ws, ocr = load("wm_script"), load("wm_ocr")
GLYPHS = ocr.load_font(f"{T}/theourgia_termfont.la")
bad = 0
def check(name, cond, detail):
    global bad
    if cond: print(f"PASS  wm freeze: {name}")
    else: print(f"FAIL  wm freeze: {name}\n      {detail}"); bad = 1

class Run:
    """One headless WM in async mode, in its own directory, fed through a FIFO."""
    def __init__(self, name, files={}):
        self.dir = f"{T}/runs/{name}"; os.makedirs(f"{self.dir}/home")
        shutil.copy(f"{T}/logos_secd", self.dir); shutil.copy(f"{T}/wm.bin", f"{self.dir}/logos_program.bin")
        for rel, text in files.items(): open(f"{self.dir}/home/{rel}", "w").write(text)
        os.mkfifo(f"{self.dir}/ev.fifo")
        open(f"{self.dir}/wm_sim.cfg", "w").write(f"960 600 1 {self.dir}/home ev.fifo async\n")
        self.wm = subprocess.Popen(["./logos_secd"], cwd=self.dir,
                                   stdout=open(f"{self.dir}/wm.log", "w"), stderr=open(f"{self.dir}/wm.err", "w"))
        self.fifo = open(f"{self.dir}/ev.fifo", "wb", buffering=0)
    def send(self, script, wait=0.0):
        self.fifo.write(ws.compile_script(script.split("\n"))); time.sleep(wait)
    def log(self): return open(f"{self.dir}/wm.log", errors="replace").read()
    def wait(self, pattern, n=1, timeout=30.0):
        """seconds until pattern has appeared n times in the log, or None"""
        t = time.time()
        while time.time() - t < timeout:
            if self.log().count(pattern) >= n: return round(time.time() - t, 2)
            if self.wm.poll() is not None: return None
            time.sleep(0.05)
        return None
    def shot(self, n):
        try: data = open(f"{self.dir}/wm_shot_{n}.bin", "rb").read()
        except OSError: return None
        return ocr.ocr(ocr.Frame(data, 960, 600, 3840), GLYPHS, 1)
    def end(self, timeout=60):
        """MOD+Shift+e, close the input, wait: rc (or 'timeout', after a kill)"""
        try:
            self.send("mod Shift+E"); self.fifo.close()
        except OSError: pass
        try: rc = self.wm.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            self.wm.kill(); self.wm.wait(); rc = "timeout"
        return rc

# flood: one window prints without end; another must stay usable
r = Run("flood")
r.send("snap 1"); r.wait("wm: snap 1", timeout=60)
r.send("mod Enter"); r.wait("open window 2")
r.send("type /usr/bin/yes\\n"); r.wait("$ /usr/bin/yes"); time.sleep(1.0)
r.send("mod Left", 0.3)
r.send("type echo flooded1\\n"); lag = r.wait("$ echo flooded1", timeout=120)
check(f"flood: a line typed into an idle window while another floods is handled within 15 s ({lag} s)",
      lag is not None and lag < 15, f"took {lag} s (None: not within 120 s)")
r.send("mod Right", 0.2); r.send("mod c"); stop = r.wait("[2] done", timeout=120)
check(f"flood: MOD+c stops the flooding program within 15 s ({stop} s)", stop is not None and stop < 15, f"took {stop} s")
rc = r.end()
check("flood: the WM exits 0 on MOD+Shift+e", rc == 0 and "wm: exit" in r.log(), f"rc={rc}; log tail {r.log()[-300:]!r}")
sys.exit(bad)
PYEOF
if [ "$ok" = 1 ]; then echo "ALL PASS  gate_wm_freeze"; else echo "GATE FAILED  gate_wm_freeze"; exit 1; fi
