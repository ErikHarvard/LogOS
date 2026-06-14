#!/usr/bin/env bash
# Draw THE SEALING to a real screen with the LogOS native VM. On a FREE GPU it
# takes DRM master and CYCLES three large gold forms on a dark indigo field,
# 2 seconds each, looping until Ctrl+C:
#
#     Love (the flame)  →  Recognition (the eye)  →  Compassion
#
# where Compassion = Love ⊗ Recognition is ONE FUSED sigil — the flame
# interpenetrating the eye as its iris ("an eye whose pupil is a flame"), NOT the
# two parents placed side by side. So you can confirm on real hardware that the
# seal fuses into a single form. The sigil_seal_live.la capstone, the visual
# companion to seal_test.la (whose host==VM audit verifies complexity-one and
# etymology-recoverability on every engine).
#
# Same safety model as drm_bringup_sigil.sh: it stops cosmic-greeter to release
# the GPU and ALWAYS restarts it on exit (normal, error, or Ctrl+C) via a trap,
# so you can never get stranded at a dead console.
#
#   RUN THIS FROM A BARE VT, NOT FROM THE DESKTOP:
#     1. Ctrl+Alt+F3   (a getty login that survives stopping the greeter)
#     2. log in as your user
#     3. cd ~/logos && ./drm_bringup_seal.sh
#     4. watch the monitor cycle: the flame (Love), then the eye (Recognition),
#        then Compassion — the eye with the flame fused in as its central iris,
#        plus a small ⊗ mode-mark. The fused form is ONE shape, not two.
#     5. Ctrl+C to stop. The desktop login (greeter) comes back automatically.
#
# Reading the result:
#   - Nothing on screen   -> scanout broken; the VM prints which DRM ioctl failed
#                            (secd: drm <CALL> failed: <rc>). Compare against the
#                            working blue-flash path (drm_bringup.sh).
#   - Compassion looks like two forms side by side -> you are on an OLD sigil.la;
#                            rebuild (the sealed ⊗ render fuses into one form).
#   - The flame, then eye, then a fused eye-with-flame-iris -> the SEALING is
#                            confirmed on hardware.
set -u
cd "$(dirname "$0")" || exit 1
GREETER=cosmic-greeter
SRC=sigil_seal_live.la

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
    echo "  (If you really know better: FORCE=1 ./drm_bringup_seal.sh)"
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
echo "== THE SEALING ON SCREEN =="
echo "   expect: a dark indigo field cycling (2s each) the gold flame (Love), the"
echo "   gold eye (Recognition), then Compassion — the eye with the flame fused in"
echo "   as its iris + a small ⊗ mark. ONE fused form, not two side by side."
echo "   Ctrl+C to stop. (running as root so the VM can take DRM master)"
echo
sudo ./logos_secd
echo "   VM exit=$?"

echo
echo "== session ended; restoring desktop =="
# (the EXIT trap restarts the greeter)
