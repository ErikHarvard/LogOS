#!/usr/bin/env bash
# Live interactive Theourgia session on a FREE GPU: the LogOS native VM renders a
# red window on a blue desktop straight to the screen via the proven
# drm_mode/present scanout path (the same path the blue-flash test confirmed),
# and reads the real keyboard through the poll-based event loop — so the window
# MOVES when you press the arrow keys.
#
# Same safety model as drm_bringup.sh: it stops cosmic-greeter to release the
# GPU and ALWAYS restarts it on exit (normal, error, or Ctrl+C) via a trap, so
# you can never get stranded at a dead console.
#
#   RUN THIS FROM A BARE VT, NOT FROM THE DESKTOP:
#     1. Ctrl+Alt+F3   (a getty login that survives stopping the greeter)
#     2. log in as your user
#     3. cd ~/logos && ./drm_bringup_live.sh
#     4. watch the monitor, in order:
#        a. a GREEN field with a MAGENTA box for ~2s  (startup test pattern)
#        b. a RED window (240x160) on a BLUE desktop, near the top-left
#        c. press the ARROW KEYS — the window moves 40px per press
#     5. Ctrl+C to stop. The desktop login (greeter) comes back automatically.
#
# Reading the result:
#   - No test pattern at all      -> scanout broken; the VM prints which DRM
#                                    ioctl failed (secd: drm <CALL> failed: <rc>).
#                                    Compare against the working blue-flash path.
#   - Test pattern + window, but   -> RENDER works, INPUT does not. The VM auto-
#     no movement on arrow keys       detects the keyboard and prints it
#                                    ("mux-session: keyboard = /dev/input/eventN");
#                                    check that N is your real keyboard and that
#                                    it's being read (run needs root for that).
#   - Window moves with arrows     -> full live session confirmed end to end.
set -u
cd "$(dirname "$0")" || exit 1
GREETER=cosmic-greeter
SRC=theourgia_mux_session_live.la

# ── Safety guard: refuse to run from inside the graphical session ──────────
# If we're under cosmic (WAYLAND_DISPLAY/DISPLAY set) or not on a real VT,
# stopping the greeter would kill THIS script before the restart trap fires —
# the exact way to strand yourself. Require a bare VT (override with FORCE=1).
this_tty="$(tty 2>/dev/null || echo none)"
if [ "${FORCE:-0}" != "1" ]; then
  if [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] || [[ "$this_tty" != /dev/tty[0-9]* ]]; then
    echo "REFUSING: this must run from a bare VT (Ctrl+Alt+F3), not the desktop."
    echo "  tty=$this_tty  WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-}  DISPLAY=${DISPLAY:-}"
    echo "  Stopping the greeter from inside the desktop would kill this script"
    echo "  before it can restart it. Switch to a text VT and rerun."
    echo "  (If you really know better: FORCE=1 ./drm_bringup_live.sh)"
    exit 2
  fi
fi

echo "== building host, VM, and the $SRC stream =="
[ -x ./tiny_host ] || cc -O2 -o tiny_host tiny_host.c || { echo "tiny_host build failed"; exit 1; }
nasm -f bin secd.asm -o logos_secd || { echo "nasm failed"; exit 1; }
chmod +x logos_secd
cp "$SRC" logos_source.la
./tiny_host codegen.la >/dev/null 2>&1 || { echo "codegen failed"; exit 1; }
echo "   VM=$(stat -c%s logos_secd)B  stream=$(stat -c%s logos_program.bin)B"

# ── Preview which keyboard the VM will pick ────────────────────────────────
# The VM auto-detects from /proc/bus/input/devices (first Name with
# 'keyboard'/'Keyboard', then the first eventN in its Handlers). It prints its
# own choice at startup too; this is just a heads-up before we take the screen.
kbline="$(grep -iB8 'Handlers=.*event' /proc/bus/input/devices 2>/dev/null \
          | grep -i 'Name=.*keyboard' | head -1 | sed 's/^N: Name=//')"
echo "   keyboard the VM should auto-detect: ${kbline:-<none found — VM will halt loudly>}"

# ── Arm the restore trap BEFORE stopping anything ──────────────────────────
restore() {
  echo "== restarting $GREETER (you'll get the login screen back) =="
  sudo systemctl start "$GREETER" 2>/dev/null
}
trap restore EXIT          # runs on any exit path
trap 'exit 130' INT        # Ctrl+C -> exit -> EXIT trap -> restore
trap 'exit 143' TERM HUP

echo "== stopping $GREETER to free the GPU =="
sudo systemctl stop "$GREETER" 2>/dev/null
sleep 2                    # let cosmic-comp drop DRM master

echo
echo "== LIVE SESSION =="
echo "   expect: green/magenta test pattern (2s) -> red window on blue field."
echo "   press the ARROW KEYS to move the window 40px; Ctrl+C to stop."
echo "   (running as root so the VM can read /dev/input AND take DRM master)"
echo
# Run as root: needs device-read for /dev/input AND DRM master for scanout.
# No strace here — the session loops forever; the VM's own per-call DRM error
# reporting names any failing ioctl on stderr if scanout breaks.
sudo ./logos_secd
echo "   VM exit=$?"

echo
echo "== session ended; restoring desktop =="
# (the EXIT trap restarts the greeter)
