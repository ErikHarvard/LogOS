#!/usr/bin/env bash
# gate_wm_bringup.sh — the live WM's launcher, drm_bringup_wm.sh, with stubs.
#
# WHAT IT GUARDS. drm_bringup_wm.sh stops the greeter to free the GPU, runs
# the VM as DRM master on the VT, and must ALWAYS give the user the greeter and
# a clean login shell back. This gate runs the real script in a pty (the VT's
# stand-in), inside a private mount namespace with its own /tmp, with stubs
# for sudo, systemctl (it only records its calls), tiny_host and the VM (it
# "compiles" once, then sleeps as the running WM), and checks:
#   1  Ctrl+Z does not suspend the session: the VM keeps running, the shell
#      does not get the terminal back with the greeter stopped; a Ctrl+C after
#      it still restarts the greeter
# Nothing here touches the real greeter, GPU or input devices.
#
# ISOLATION: a private temporary directory and mount namespace. Needs
# unshare -m (root). About a minute.
set -uo pipefail
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
ROOT=$(cd "$(dirname "$0")" && pwd)
if ! unshare -m true 2>/dev/null; then
    echo "NOTE  wm bringup: unshare -m is not available here; skipped"; exit 0
fi
B="$T/b"; mkdir -p "$B/bin" "$B/faketmp"
cp "$ROOT/drm_bringup_wm.sh" "$B/"
touch "$B/codegen.la" "$B/secd.la" "$B/theourgia_wm_live.la"; sleep 1; touch "$B/compiler.bin"
cat > "$B/bin/sudo" <<'EOF'
#!/bin/bash
exec "$@"
EOF
cat > "$B/bin/systemctl" <<EOF
#!/bin/bash
echo "systemctl \$*" >> $B/systemctl.log
EOF
printf '#!/bin/bash\nexit 0\n' > "$B/tiny_host"
cat > "$B/logos_secd" <<EOF
#!/bin/bash
# the first call "compiles"; later calls are the running WM
if [ ! -f $B/compiled ]; then touch $B/compiled; exit 0; fi
echo "wm: live (stub)"; echo "\$\$" > $B/vm.pid
exec sleep 60
EOF
chmod 755 "$B/bin/sudo" "$B/bin/systemctl" "$B/tiny_host" "$B/logos_secd" "$B/drm_bringup_wm.sh"

python3 - "$B" <<'PYEOF'
import os, pty, select, signal, sys, time, glob
B = sys.argv[1]
bad = 0
def check(name, cond, detail):
    global bad
    if cond: print(f"PASS  wm bringup: {name}")
    else: print(f"FAIL  wm bringup: {name}\n      {detail}"); bad = 1
def spawn():
    for f in ("compiled", "vm.pid", "systemctl.log"):
        try: os.remove(f"{B}/{f}")
        except OSError: pass
    for f in glob.glob(f"{B}/faketmp/logos_wm_*"): os.remove(f)
    pid, fd = pty.fork()
    if pid == 0:
        inner = f"{B}/faketmp{B[4:]}"
        os.execvp("unshare", ["unshare", "-m", "--propagation", "private", "bash", "-c",
                  f"mkdir -p {inner} && mount --bind {B} {inner} && mount --rbind {B}/faketmp /tmp && "
                  f"exec env -i HOME=/root TERM=dumb PATH={B}/bin:/usr/bin:/bin bash --norc --noprofile -i"])
    return pid, fd
def drain(fd, t=0.5):
    out = b""; end = time.time() + t
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.05)
        if r:
            try: out += os.read(fd, 65536)
            except OSError: break
    return out.decode(errors="replace")
def start(fd):
    drain(fd, 1.0)
    os.write(fd, f"cd {B}; FORCE=1 ./drm_bringup_wm.sh\n".encode())
    for _ in range(150):
        if os.path.exists(f"{B}/vm.pid"): break
        time.sleep(0.1)
    time.sleep(0.5)
    return drain(fd, 0.3)
def vmstate():
    try:
        vm = open(f"{B}/vm.pid").read().strip()
        return open(f"/proc/{vm}/stat").read().rsplit(")", 1)[1].split()[0]
    except OSError: return None
def calls():
    try: return [l.strip() for l in open(f"{B}/systemctl.log")]
    except OSError: return []
def stop(pid, fd):
    try: os.write(fd, b"exit\n")
    except OSError: pass
    time.sleep(0.3)
    try:
        vm = open(f"{B}/vm.pid").read().strip(); os.kill(int(vm), signal.SIGKILL)
    except (OSError, ValueError): pass
    # the whole pty session: killing only the shell would leave the launcher
    # running, and its hangup trap would restart the greeter later
    os.system(f"pkill -9 -s {pid} 2>/dev/null")
    try: os.kill(pid, signal.SIGKILL)
    except OSError: pass
    try: os.waitpid(pid, 0)
    except OSError: pass
    time.sleep(0.5)
GREETER = ["systemctl stop cosmic-greeter", "systemctl start cosmic-greeter"]

# 1 Ctrl+Z
pid, fd = spawn(); start(fd)
before = vmstate()
os.write(fd, b"\x1a"); time.sleep(1.5); out = drain(fd, 0.5)
st = vmstate()
check("1 Ctrl+Z does not suspend the session (the VM keeps running)",
      before in ("S", "R") and st in ("S", "R") and "Stopped" not in out, f"VM state before {before}, after {st}; pty: {out[-300:]!r}")
os.write(fd, b"\x03"); time.sleep(3.0)
check("1 a Ctrl+C after it ends the session and restarts the greeter", calls() == GREETER, f"systemctl calls: {calls()}")
stop(pid, fd)

sys.exit(bad)
PYEOF
rc=$?
if [ "$rc" = 0 ]; then echo "ALL PASS  gate_wm_bringup"; else echo "GATE FAILED  gate_wm_bringup"; exit 1; fi
