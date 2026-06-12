#!/usr/bin/env bash
# DRM scanout bring-up: run the C reference and the (clean) LogOS VM
# side-by-side on a FREE GPU. It stops cosmic-greeter to release the GPU and
# ALWAYS restarts it on exit (normal, error, or Ctrl+C) via a trap, so you can
# never get stranded at a dead console.
#
#   RUN THIS FROM A BARE VT, NOT FROM THE DESKTOP:
#     1. Ctrl+Alt+F3   (a getty login that survives stopping the greeter)
#     2. log in as your user
#     3. cd ~/logos && ./drm_bringup.sh
#     4. watch the monitor: each test should paint the WHOLE SCREEN BLUE for 4s
#   The desktop login (greeter) comes back automatically when the script ends.
set -u
cd "$(dirname "$0")" || exit 1
log=/tmp/vm_drm_strace.log
GREETER=cosmic-greeter

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
    echo "  (If you really know better: FORCE=1 ./drm_bringup.sh)"
    exit 2
  fi
fi

echo "== building host, VM, and the theourgia_drm.la stream =="
[ -x ./tiny_host ] || cc -O2 -o tiny_host tiny_host.c || { echo "tiny_host build failed"; exit 1; }
nasm -f bin secd.asm -o logos_secd || { echo "nasm failed"; exit 1; }
chmod +x logos_secd
cp theourgia_drm.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1 || { echo "codegen failed"; exit 1; }
echo "   VM=$(stat -c%s logos_secd)B  stream=$(stat -c%s logos_program.bin)B"

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
echo "== [1/2] C REFERENCE (theourgia_drmref) — screen should go BLUE for 4s =="
~/theourgia_drmref
echo "   reference exit=$?"

echo
echo "== [2/2] LogOS VM (clean) — screen should go BLUE for 4s =="
if command -v strace >/dev/null 2>&1; then
  strace -e trace=ioctl,open,openat,mmap -y ./logos_secd 2>"$log"
  echo "   VM exit=$?"
  echo "   --- per-ioctl trace (DRM calls) ----------------------------------"
  grep -E 'dri/card|DRM_IOCTL|MODE_|= -1' "$log" | sed 's/^/   /'
  echo "   ------------------------------------------------------------------"
  if grep -qE 'DRM_IOCTL_MODE_SETCRTC.*= 0' "$log"; then
    echo "RESULT: SETCRTC succeeded — VM is DRM master; scanout path confirmed."
  elif grep -qE 'DRM_IOCTL_MODE_SETCRTC.*EACCES' "$log"; then
    echo "RESULT: SETCRTC EACCES — GPU still held. Is another compositor running?"
  else
    echo "RESULT: inspect the trace above."
  fi
else
  ./logos_secd; echo "   VM exit=$? (install strace for the per-ioctl breakdown)"
fi

echo
echo "== tests done; restoring desktop =="
# (the EXIT trap restarts the greeter)
