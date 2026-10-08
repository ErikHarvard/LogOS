#!/usr/bin/env bash
# gate_wm_fieldcost.sh — a keystroke in a LogosKit text field costs the same
# however long the field is.
#
# WHAT IT GUARDS. WM_DESIGN.md: after startup "nothing names a glyph or a
# builtin" (on the VM each such name walks the whole program). LogosKit's
# Backspace in a field and the login screen's passphrase field did, once per
# character of the field, so a keystroke's cost grew with the field's length
# and editing a long value grew with its square. This gate runs the headless
# WM (sync mode) three times with the same 300 keys: N characters typed and
# then N Backspaces,
#   base  into a terminal (whose cost is known to be flat),
#   name  into the settings panel's Name field (MOD+s),
#   pass  into the lock screen's passphrase field (MOD+Esc, adam, Tab),
# and compares the CPU time each run used beyond the terminal run. It also
# reads the last frame back (wm_ocr.py): the field is back where it started.
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
  || { echo "FAIL  wm fieldcost: the WM did not compile: $(tail -3 "$T/vce")"; exit 1; }
cp "$T/logos_program.bin" "$T/wm.bin"

python3 - "$T" <<'PYEOF' || ok=0
import importlib.util, os, shutil, subprocess, sys, time
T = sys.argv[1]
def load(name):
    spec = importlib.util.spec_from_file_location(name, f"{T}/{name}.py")
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m
ws, ocr = load("wm_script"), load("wm_ocr")
glyphs = ocr.load_font(f"{T}/theourgia_termfont.la")
N, LIMIT = 150, 3.0
keys = ["type " + "x" * N] + ["key BACKSPACE"] * N + ["snap 1"]
runs = {"base": keys, "name": ["mod s"] + keys, "pass": ["mod ESC", "type adam", "key TAB"] + keys}
cpu, shot = {}, {}
for name, script in runs.items():
    d = f"{T}/run_{name}"; os.makedirs(f"{d}/home")
    shutil.copy(f"{T}/logos_secd", d); shutil.copy(f"{T}/wm.bin", f"{d}/logos_program.bin")
    open(f"{d}/events.bin", "wb").write(ws.compile_script(script))
    open(f"{d}/wm_sim.cfg", "w").write(f"960 600 1 {d}/home events.bin\n")
    p = subprocess.Popen(["./logos_secd"], cwd=d, stdout=open(f"{d}/log.txt", "w"), stderr=open(f"{d}/err.txt", "w"))
    _, status, ru = os.wait4(p.pid, 0)
    cpu[name] = ru.ru_utime + ru.ru_stime
    try: shot[name] = ocr.ocr(ocr.Frame(open(f"{d}/wm_shot_1.bin", "rb").read(), 960, 600, 3840), glyphs, 1)
    except OSError: shot[name] = None
    if status != 0: print(f"      ({name}: exit status {status}: {open(f'{d}/err.txt').read()[-200:]!r})")
bad = 0
def check(nm, cond, detail):
    global bad
    if cond: print(f"PASS  wm fieldcost: {nm}")
    else: print(f"FAIL  wm fieldcost: {nm}\n      {detail}"); bad = 1
print(f"      CPU for {N} characters typed and {N} Backspaces: terminal {cpu['base']:.2f} s, "
      f"settings Name {cpu['name']:.2f} s, passphrase {cpu['pass']:.2f} s")
def rows(s): return [r for t in (s or []) for r in t["rows"]]
check(f"the settings Name field costs at most {LIMIT} s more than a terminal ({cpu['name'] - cpu['base']:.2f} s)",
      cpu["name"] - cpu["base"] < LIMIT, f"{cpu}")
check(f"the passphrase field costs at most {LIMIT} s more than a terminal ({cpu['pass'] - cpu['base']:.2f} s)",
      cpu["pass"] - cpu["base"] < LIMIT, f"{cpu}")
check("after the Backspaces the Name field is back to its value (sovereign)",
      any("Name: [sovereign" in r and "x" not in r.split("Name: [")[1][:12] for r in rows(shot["name"])), str(shot["name"])[:500])
check("after the Backspaces the passphrase field is empty",
      any("Passphrase: [ " in r or r.rstrip().endswith("Passphrase: [") for r in rows(shot["pass"]))
      and not any("*" in r for r in rows(shot["pass"])), str(shot["pass"])[:500])
sys.exit(bad)
PYEOF
if [ "$ok" = 1 ]; then echo "ALL PASS  gate_wm_fieldcost"; else echo "GATE FAILED  gate_wm_fieldcost"; exit 1; fi
