#!/usr/bin/env bash
# gate_wm_livestart.sh — what the live WM decides before it takes the screen.
#
# WHAT IT GUARDS. theourgia_wm_live.la finds the keyboard in
# /proc/bus/input/devices with wm_livestart.la's KBD_KIT. Checks:
#   1  on synthetic device lists, on the C host and the VM (identical
#      answers): a "keyboard" with no event handler followed by a mouse gives
#      no keyboard (never the mouse); with two keyboards the first block wins;
#      the name matches in any case ("SEMICO USB KEYBOARD"); the event number
#      comes from the keyboard's own block
#   2  speed: a 12 KB list with the keyboard last is scanned on the VM in well
#      under a second of CPU (the old detector named builtins per byte:
#      about 3 ms a byte, over a minute for this list)
#   3  the directory new shells start in, from logos_wm.cwd (host with a
#      stub stat, VM with the real one): its first line only, without spaces,
#      tabs or a carriage return at either end; "/" for an empty or blank
#      file, a missing directory, or a file that is not a directory
#   4  the real live entry, compiled, in a private mount namespace with that
#      kind of list bound over /proc/bus/input/devices and a /dev holding only
#      /dev/input/event3: it opens the keyboard (event3, not the mouse's
#      event5) and gets as far as drm_mode, where it halts loudly as it must
#      with no GPU (rc 1, a drm message)
#   5  the same, with no /dev/input/event3 at all: it halts saying there is no
#      such device (not that it needs root, which it already is)
#
# ISOLATION: a private temporary directory (gate_wm_common.sh); checks 4-5 need
# unshare -m (root) and is skipped with a NOTE without it. A few minutes,
# mostly compiling the live WM on the VM.
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1
wm_setup wm_livestart.la theourgia_tile.la theourgia_term.la theourgia_render.la logosh.la \
         theourgia_wm.la theourgia_termfont.la logoskit.la lk_settings.la theourgia_wm_live.la

python3 - "$T" <<'PYEOF'
import sys
T = sys.argv[1]
def blk(name, handlers, extra=""):
    return f'I: Bus=0011 Vendor=0001 Product=0001 Version=ab41\nN: Name="{name}"\nP: Phys=isa0060/serio0/input0\n{extra}H: Handlers={handlers}\nB: EV=120013\n\n'
cases = {
    "A": blk("Virtual keyboard", "sysrq kbd leds") + blk("ImPS/2 Generic Wheel Mouse", "mouse0 event5"),
    "B": blk("Logitech USB Keyboard", "sysrq kbd leds event7") + blk("AT Translated Set 2 keyboard", "sysrq kbd leds event3"),
    "C": blk("SEMICO USB KEYBOARD", "sysrq kbd leds event14"),
    "D": blk("Power Button", "kbd event0") + blk("ImPS/2 Generic Wheel Mouse", "mouse0 event5")
         + blk("AT Translated Set 2 keyboard", "sysrq kbd leds event3"),
}
big = "".join(blk(f"Device {i}", f"event{20 + i}") for i in range(88)) + blk("Logitech USB Keyboard", "sysrq kbd leds event9")
lit = lambda s: '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'
prog = ['import("wm_livestart.la")',
        'glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))',
        'glyph KBD = KBD_KIT(Z)(str_at)(str_len)(ord)(str_to_int)(add)(sub)(lt)(int_eq)(concat)']
body = '""'
for k in reversed(sorted(cases)):
    body = f'(la _. {body})(print(concat("{k}=")(KBD({lit(cases[k])}))))'
open(f"{T}/kbd.la", "w").write("\n".join(prog + [f"glyph MAIN = {body}"]) + "\n")
open(f"{T}/kbdbig.la", "w").write("\n".join(prog + [f'glyph MAIN = print(concat("big=")(KBD(read_file("big.txt"))))']) + "\n")
open(f"{T}/big.txt", "w").write(big)
open(f"{T}/devices.txt", "w").write(cases["D"].replace("Power Button", "Virtual keyboard").replace("kbd event0", "sysrq kbd leds"))
print(f"      (the big list is {len(big)} bytes)")
PYEOF
EXPECT='A=
B=7
C=14
D=3'
wm_host kbd.la "$T/host.txt"
wm_vm kbd.la "$T/vm.txt"
if [ "$hrc" = 0 ] && [ "$vrc" = 0 ] && [ "$(cat "$T/host.txt")" = "$EXPECT" ] && [ "$(cat "$T/vm.txt")" = "$EXPECT" ]; then
    echo "PASS  wm livestart: 1 keyboard detection on four device lists, host = VM (A none, B first keyboard 7, C any case 14, D its own block 3)"
else
    echo "FAIL  wm livestart: 1 keyboard detection: host rc=$hrc VM rc=$vrc"; echo "      host: $(tr '\n' ' ' < "$T/host.txt")"; echo "      VM:   $(tr '\n' ' ' < "$T/vm.txt")"; ok=0
fi

cp "$T/compiler.bin" "$T/logos_program.bin"; cp "$T/kbdbig.la" "$T/logos_source.la"
if ( cd "$T" && timeout "$WM_VM_TIMEOUT" ./logos_secd >/dev/null 2>"$T/vce" ); then
    cpu=$( cd "$T" && python3 -c '
import os, subprocess, sys
p = subprocess.Popen(["./logos_secd"], stdout=open("big.out", "w"), stderr=open("big.err", "w"))
_, st, ru = os.wait4(p.pid, 0)
print("%.2f %d" % (ru.ru_utime + ru.ru_stime, st))' )
    read -r secs status <<< "$cpu"
    if [ "${status:-1}" = 0 ] && [ "$(cat "$T/big.out")" = "big=9" ] && python3 -c "import sys; sys.exit(0 if float('$secs') < 1.0 else 1)"; then
        echo "PASS  wm livestart: 2 the 12 KB list is scanned in $secs s of CPU on the VM (keyboard 9, the last block)"
    else
        echo "FAIL  wm livestart: 2 the 12 KB list: status ${status:-?}, $secs s of CPU, answer $(cat "$T/big.out")"; ok=0
    fi
else
    echo "FAIL  wm livestart: 2 the timing program did not compile: $(tail -2 "$T/vce")"; ok=0
fi

# 3 the cwd
cat > "$T/cwd.la" <<LAEOF
import("wm_livestart.la")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
STATDEF
glyph CWD = CWD_KIT(Z)(str_at)(str_len)(str_eq)(concat)(str_to_int)(add)(sub)(lt)(int_eq)(div)(mod)(chr)(ST)
glyph CR = chr("13")
glyph SHOW = la n. la t. print(concat(n)(concat("=")(CWD(t))))
glyph MAIN = (la _. (la _. (la _. (la _. (la _. (la _. SHOW("empty")(""))
  (SHOW("file")("/etc/passwd\n")))
  (SHOW("missing")("/nonexistent\n")))
  (SHOW("cr")(concat("/tmp")(concat(CR)("\n")))))
  (SHOW("trail")(concat(" \t/tmp  ")(concat(CR)("\n")))))
  (SHOW("blank")("   \n")))
  (SHOW("lines")("/tmp\n/home\n"))
LAEOF
sed 's|^STATDEF$|glyph ST = la p. str_eq(p)("/tmp")("16877 4096")(str_eq(p)("/etc/passwd")("33188 1000")("-2"))|' "$T/cwd.la" > "$T/cwd_host.la"
sed 's|^STATDEF$|glyph ST = la p. stat(p)|' "$T/cwd.la" > "$T/cwd_vm.la"
CWDEXPECT='lines=/tmp
blank=/
trail=/tmp
cr=/tmp
missing=/
file=/
empty=/'
wm_host cwd_host.la "$T/cwdh.txt"
wm_vm cwd_vm.la "$T/cwdv.txt"
if [ "$hrc" = 0 ] && [ "$vrc" = 0 ] && [ "$(cat "$T/cwdh.txt")" = "$CWDEXPECT" ] && [ "$(cat "$T/cwdv.txt")" = "$CWDEXPECT" ]; then
    echo "PASS  wm livestart: 3 the cwd: first line, trimmed (spaces, tabs, a carriage return), \"/\" when blank, missing or not a directory; host = VM"
else
    echo "FAIL  wm livestart: 3 the cwd: host rc=$hrc VM rc=$vrc"; echo "      host: $(tr '\n' ' ' < "$T/cwdh.txt")"; echo "      VM:   $(tr '\n' ' ' < "$T/cwdv.txt")"; ok=0
fi

if unshare -m true 2>/dev/null; then
    cp "$T/compiler.bin" "$T/logos_program.bin"; cp "$T/theourgia_wm_live.la" "$T/logos_source.la"
    if ( cd "$T" && timeout "$WM_VM_TIMEOUT" ./logos_secd >/dev/null 2>"$T/vce" ); then
        echo / > "$T/logos_wm.cwd"
        lrc=0
        ( cd "$T" && timeout 120 unshare -m --propagation private sh -c "
            mount --bind '$T/devices.txt' /proc/bus/input/devices && mount -t tmpfs none /dev \
            && mkdir /dev/input && : > /dev/input/event3 && exec ./logos_secd" >"$T/live.out" 2>"$T/live.err" ) || lrc=$?
        if [ "$lrc" = 1 ] && ! grep -q "cannot open" "$T/live.err" && grep -qi "drm" "$T/live.err"; then
            echo "PASS  wm livestart: 4 the live entry opens the keyboard (event3, not the mouse) and halts at drm_mode with no GPU: $(head -c 120 "$T/live.err")"
        else
            echo "FAIL  wm livestart: 4 the live entry: rc=$lrc"; echo "      stderr: $(head -c 300 "$T/live.err")"; echo "      stdout: $(head -c 200 "$T/live.out")"; ok=0
        fi
        lrc=0
        ( cd "$T" && timeout 120 unshare -m --propagation private sh -c "
            mount --bind '$T/devices.txt' /proc/bus/input/devices && mount -t tmpfs none /dev \
            && mkdir /dev/input && exec ./logos_secd" >"$T/live2.out" 2>"$T/live2.err" ) || lrc=$?
        if [ "$lrc" = 1 ] && grep -q "event3 (open -> -2): no such device" "$T/live2.err" && ! grep -q "run as root" "$T/live2.err"; then
            echo "PASS  wm livestart: 5 no device node: it says so ($(head -c 120 "$T/live2.err"))"
        else
            echo "FAIL  wm livestart: 5 no device node: rc=$lrc; stderr: $(head -c 300 "$T/live2.err")"; ok=0
        fi
    else
        echo "FAIL  wm livestart: 4 theourgia_wm_live.la did not compile: $(tail -2 "$T/vce")"; ok=0
    fi
else
    echo "NOTE  wm livestart: 4 skipped (unshare -m is not available)"
fi
if [ "$ok" = 1 ]; then echo "ALL PASS  gate_wm_livestart"; else echo "GATE FAILED  gate_wm_livestart"; exit 1; fi
