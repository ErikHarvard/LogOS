#!/usr/bin/env bash
# Theourgia Stage 10, live: the LogOS tiling window manager on a FREE GPU.
# Terminals tile the screen, each running logosh; the keyboard is read straight
# from evdev and the frames go out through drm_mode/present, as in the Stage 9
# capstone (drm_bringup_term.sh), whose safety model this script keeps: it stops
# the greeter to free the GPU and ALWAYS restarts it on exit (normal, error, or
# Ctrl+C) via a trap.
#
#   RUN THIS FROM A BARE VT, NOT FROM THE DESKTOP:
#     1. Ctrl+Alt+F3, log in
#     2. cd ~/logos && ./drm_bringup_wm.sh
#     3. one terminal fills the screen; type `help`, then try:
#          MOD+Enter        new terminal (splits the focused one)
#          MOD+arrows/hjkl  move focus        MOD+Shift+arrows  swap windows
#          MOD+t            side-by-side <-> stacked
#          MOD+- / MOD+=    shrink / grow      MOD+Tab           next window
#          MOD+c            interrupt the focused window's command
#          MOD+s            the settings panel (LogosKit; Tab moves, Space
#                           toggles; "Dark theme" redraws the panel dark)
#          MOD+q            close the window   MOD+Shift+e       exit
#        MOD is Super or Alt.
#     4. Ctrl+C also stops it at once (the VT delivers SIGINT); the greeter
#        comes back automatically.
#
# KEYSTROKES AND THE VT. The VM reads the keyboard from evdev, but the VT's own
# tty still receives every key and buffers it. Without care, a command typed
# into a WM terminal (say `rm x` + Enter) would sit in that buffer and be run by
# your login shell after the session ends. So this script turns tty echo off for
# the session and FLUSHES the tty's pending input on every exit path, before
# your shell can read it. It also turns the tty's suspend key off for the
# session: Ctrl+Z would stop the VM and this script with the greeter stopped,
# skip the restore, and hand later keystrokes to the login shell.
#
#   DRYRUN=1 ./drm_bringup_wm.sh   build and compile only (safe from anywhere)
set -u
cd "$(dirname "$0")" || exit 1
GREETER=${GREETER:-cosmic-greeter}
SRC=theourgia_wm_live.la

this_tty="$(tty 2>/dev/null || echo none)"
if [ "${DRYRUN:-0}" != "1" ] && [ "${FORCE:-0}" != "1" ]; then
  if [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] || [[ "$this_tty" != /dev/tty[0-9]* ]]; then
    echo "REFUSING: this must run from a bare VT (Ctrl+Alt+F3), not the desktop."
    echo "  tty=$this_tty  WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-}  DISPLAY=${DISPLAY:-}"
    echo "  Stopping the greeter from inside the desktop would kill this script"
    echo "  before it can restart it. Switch to a text VT and rerun."
    echo "  (Build only: DRYRUN=1 ./drm_bringup_wm.sh)"
    exit 2
  fi
fi

echo "== building the host, the VM and the compiler =="
[ -x ./tiny_host ] || cc -O2 -o tiny_host tiny_host.c || { echo "tiny_host build failed"; exit 1; }
./tiny_host secd.la >/dev/null 2>&1 && [ -x logos_secd ] || { echo "VM build failed"; exit 1; }
if [ ! -f compiler.bin ] || [ codegen.la -nt compiler.bin ]; then
  cp codegen.la logos_source.la
  ./tiny_host codegen.la >/dev/null 2>&1 || { echo "compiler build failed"; exit 1; }
  cp logos_program.bin compiler.bin
fi
pwd > logos_wm.cwd        # the directory new shells start in
echo "== compiling $SRC on the VM =="
cp compiler.bin logos_program.bin
cp "$SRC" logos_source.la
./logos_secd >/dev/null 2>/tmp/logos_wm_compile.err || { cat /tmp/logos_wm_compile.err; echo "compile failed"; exit 1; }
echo "   VM=$(stat -c%s logos_secd)B  program=$(stat -c%s logos_program.bin)B"
if [ "${DRYRUN:-0}" = "1" ]; then echo "DRYRUN: built and compiled; not taking the screen."; exit 0; fi

kbline="$(grep -iB8 'Handlers=.*event' /proc/bus/input/devices 2>/dev/null \
          | grep -i 'Name=.*keyboard' | head -1 | sed 's/^N: Name=//')"
echo "   keyboard the VM should auto-detect: ${kbline:-<none found: the VM will halt loudly>}"

saved_stty="$(stty -g 2>/dev/null || true)"
flush_tty() {
  # Discard everything typed during the session so the login shell never runs it.
  python3 -c 'import sys, termios; termios.tcflush(sys.stdin, termios.TCIFLUSH)' 2>/dev/null \
    || while read -r -t 0.2 -n 4096 _; do :; done
  [ -n "$saved_stty" ] && stty "$saved_stty" 2>/dev/null
}
restore() {
  # nothing may interrupt the restore: a second Ctrl+C here used to run the
  # INT trap's exit inside it and skip restarting the greeter
  trap '' INT TERM HUP TSTP
  [ -n "${restored:-}" ] && return
  restored=1
  flush_tty
  echo "== restarting $GREETER (you'll get the login screen back) =="
  sudo systemctl start "$GREETER" 2>/dev/null
}
trap restore EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP
trap '' TSTP

echo "== stopping $GREETER to free the GPU =="
sudo systemctl stop "$GREETER" 2>/dev/null
sleep 2

LOGF="/tmp/logos_wm_$(date +%s).log"
echo
echo "== LIVE: the LogOS tiling window manager =="
echo "   log -> $LOGF   (MOD+Shift+e or Ctrl+C to stop)"
stty -echo susp undef 2>/dev/null
sudo ./logos_secd >"$LOGF" 2>&1
echo "   VM exit=$?"
flush_tty
echo
echo "== log tail ($LOGF) =="
tail -n 40 "$LOGF" 2>/dev/null
