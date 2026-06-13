#!/usr/bin/env bash
# Draw a SIGIL to a real screen with the LogOS native VM. On a FREE GPU it takes
# DRM master, rasters g1 Being (the catalogue's circle + central point + ouroboric
# curl) — the first of the nine sigils — as a large gold form on a dark indigo
# field, and holds it until Ctrl+C. The
# sigil_live.la capstone, the visual companion to sigil.la (whose ASCII self-test
# build-verifies the same sigil shapes on every engine).
#
# Same safety model as drm_bringup_text.sh: it stops cosmic-greeter to release
# the GPU and ALWAYS restarts it on exit (normal, error, or Ctrl+C) via a trap,
# so you can never get stranded at a dead console.
#
#   RUN THIS FROM A BARE VT, NOT FROM THE DESKTOP:
#     1. Ctrl+Alt+F3   (a getty login that survives stopping the greeter)
#     2. log in as your user
#     3. cd ~/logos && ./drm_bringup_sigil.sh
#     4. watch the monitor: a dark field with a large gold Being sigil (a circle
#        with a central point and a small ouroboric curl at the crown) centred.
#     5. Ctrl+C to stop. The desktop login (greeter) comes back automatically.
#
# Reading the result:
#   - Nothing on screen   -> scanout broken; the VM prints which DRM ioctl
#                            failed (secd: drm <CALL> failed: <rc>). Compare
#                            against the working blue-flash path (drm_bringup.sh).
#   - Wrong/garbled form   -> the sigil raster mis-built; check sigil.la against
#                            build.sh's PASS (it verifies the glyph shapes).
#   - A clean gold circle  -> the visual modality is confirmed on hardware.
set -u
cd "$(dirname "$0")" || exit 1
GREETER=cosmic-greeter
SRC=sigil_live.la

# ── Safety guard: refuse to run from inside the graphical session ──────────
# Stopping the greeter from under cosmic would kill THIS script before the
# restore trap fires — the way to strand yourself. Require a bare VT (FORCE=1
# overrides).
this_tty="$(tty 2>/dev/null || echo none)"
if [ "${FORCE:-0}" != "1" ]; then
  if [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] || [[ "$this_tty" != /dev/tty[0-9]* ]]; then
    echo "REFUSING: this must run from a bare VT (Ctrl+Alt+F3), not the desktop."
    echo "  tty=$this_tty  WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-}  DISPLAY=${DISPLAY:-}"
    echo "  Stopping the greeter from inside the desktop would kill this script"
    echo "  before it can restart it. Switch to a text VT and rerun."
    echo "  (If you really know better: FORCE=1 ./drm_bringup_sigil.sh)"
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
echo "== SIGIL ON SCREEN =="
echo "   expect: a dark indigo field with a large gold Being sigil (circle+point+curl) centred."
echo "   Ctrl+C to stop. (running as root so the VM can take DRM master)"
echo
# Needs DRM master for scanout; the VM's own per-call DRM error reporting names
# any failing ioctl on stderr if scanout breaks.
sudo ./logos_secd
echo "   VM exit=$?"

echo
echo "== session ended; restoring desktop =="
# (the EXIT trap restarts the greeter)
