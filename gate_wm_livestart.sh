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
#   4  the users directory, from logos_wm.users, on the C host and the VM with
#      the same stub stat and mkdir (identical answers): its first line,
#      trimmed as the cwd is; /var/lib/logos when the file is missing or its
#      first line is blank; a missing directory made with mode 0700 (448),
#      one level; a FIRST RUN exactly when DIR/users does not exist (a
#      directory that exists without users/ is a first run, one with users/
#      is not); and three loud halts, each naming the path: a regular file,
#      a missing parent, a stat error other than "does not exist"
#   5  the same with the VM's real stat and mkdir in the gate's directory: a
#      missing directory is created with mode 700 and is a first run, an
#      existing one with users/ is not, an empty existing one is; a regular
#      file and a missing parent halt naming the path, creating nothing
#   6  the real live entry, compiled, in a private mount namespace with that
#      kind of list bound over /proc/bus/input/devices and a /dev holding only
#      /dev/input/event3: it opens the keyboard (event3, not the mouse's
#      event5) and gets as far as drm_mode, where it halts loudly as it must
#      with no GPU (rc 1, a drm message)
#   7  the same, with no /dev/input/event3 at all: it halts saying there is no
#      such device (not that it needs root, which it already is)
#   8  check 6's run had logos_wm.users naming a directory that did not
#      exist: before drm_mode the live entry made it, mode 700, and said it
#      was a first run (so its lock screen is the first-run screen)
#   9  logos_wm.users naming a regular file: it halts naming the file and
#      never reaches drm_mode (a loud failure leaves no taken screen)
#   10 no logos_wm.users at all, with a tmpfs over /var/lib in the namespace:
#      it makes /var/lib/logos, mode 700, and halts at drm_mode
# Every run of the live entry is given a users directory in the gate's own
# directory (or a tmpfs), so the gate never makes /var/lib/logos on the host.
#
# ISOLATION: a private temporary directory (gate_wm_common.sh); checks 6-10
# need unshare -m (root) and are skipped with a NOTE without it. A few
# minutes, mostly compiling the live WM on the VM.
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1
wm_setup wm_livestart.la theourgia_tile.la theourgia_term.la theourgia_render.la logosh.la \
         theourgia_wm.la theourgia_termfont.la logoskit.la lk_settings.la theourgia_wm_live.la \
         lk_login.la lk_firstuser.la logos_realsess.la logoscrypt.la logossec.la aletheiafs.la logossession.la

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

# 4 the users directory with a stub stat and mkdir, host = VM
cat > "$T/users.la" <<'LAEOF'
import("wm_livestart.la")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
# the stub world: /srv/l has users/, /srv/e is an empty directory, /srv/f a
# regular file, /srv/acc cannot be stat'ed; everything else does not exist.
# mkdir prints what it is asked and fails (no such parent) under /nope only.
glyph ST = la p. str_eq(p)("/srv/l")("16877 4096")(str_eq(p)("/srv/l/users")("16832 4096")(
  str_eq(p)("/srv/e")("16877 4096")(str_eq(p)("/srv/f")("33188 10")(str_eq(p)("/srv/acc")("-13")("-2")))))
glyph MK = la p. la m. (la _. str_eq(p)("/nope/x")("-2")("0"))(print(concat("  mkdir ")(concat(p)(concat(" ")(m)))))
glyph USERS = USERS_KIT(Z)(str_at)(str_len)(str_eq)(concat)(str_to_int)(add)(sub)(lt)(int_eq)(div)(mod)(chr)(error)(ST)(MK)
glyph CR = chr("13")
glyph SHOW = la n. la t. USERS(t)(la d. la f. print(concat(n)(concat(": dir=")(concat(d)(concat(" first=")(f("yes")("no")))))))
glyph MAIN = (la _. (la _. (la _. (la _. (la _. SHOW("new")("/srv/new\n"))
  (SHOW("trim")(concat(" \t/srv/e  ")(concat(CR)("\n/srv/l\n")))))
  (SHOW("crlf")(concat("/srv/l")(concat(CR)("\n")))))
  (SHOW("blank")("  \t \n/srv/l\n")))
  (SHOW("missing")("")))
  ("")
LAEOF
USERSEXPECT='  mkdir /var/lib/logos 448
missing: dir=/var/lib/logos first=yes
  mkdir /var/lib/logos 448
blank: dir=/var/lib/logos first=yes
crlf: dir=/srv/l first=no
trim: dir=/srv/e first=yes
  mkdir /srv/new 448
new: dir=/srv/new first=yes'
wm_host users.la "$T/usersh.txt"; uh=$hrc; cp "$T/usersh.txt" "$T/usersh0.txt"
wm_vm users.la "$T/usersv.txt"; uv=$vrc
halts=""
# each halts with nothing printed but, for /nope/x, the stub's own mkdir line
for c in "f|/srv/f|is not a directory|" "x|/nope/x|mkdir -> -2|  mkdir /nope/x 448" "acc|/srv/acc|stat -> -13|"; do
    IFS='|' read -r tag path why out <<< "$c"
    sed "s|^glyph MAIN = .*|glyph MAIN = SHOW(\"$tag\")(\"$path\\\\n\")|; /^  (SHOW\\|^  (\"\")/d" "$T/users.la" > "$T/users_$tag.la"
    wm_host "users_$tag.la" "$T/uh_$tag.txt"; hm=$(cat "$T/hre")
    wm_vm "users_$tag.la" "$T/uv_$tag.txt"; vm=$(cat "$T/vre" 2>/dev/null)
    if [ "$hrc" = 1 ] && [ "$vrc" = 1 ] && [ "$(cat "$T/uh_$tag.txt")" = "$out" ] && [ "$(cat "$T/uv_$tag.txt")" = "$out" ] \
       && [[ "$hm" == *"$path"*"$why"* ]] && [[ "$vm" == *"$path"*"$why"* ]]; then
        halts="$halts $tag"
    else
        echo "      $tag: host rc=$hrc '$hm'; VM rc=$vrc '$vm'"
    fi
done
if [ "$uh" = 0 ] && [ "$uv" = 0 ] && [ "$(cat "$T/usersh0.txt")" = "$USERSEXPECT" ] && [ "$(cat "$T/usersv.txt")" = "$USERSEXPECT" ] \
   && [ "$halts" = " f x acc" ]; then
    echo "PASS  wm livestart: 4 the users directory: first line trimmed, /var/lib/logos when missing or blank, made 0700 when missing, first run iff DIR/users is absent; a file, a missing parent and a stat error halt naming the path; host = VM"
else
    echo "FAIL  wm livestart: 4 the users directory: host rc=$uh VM rc=$uv, halts:$halts"
    echo "      host: $(tr '\n' '|' < "$T/usersh0.txt")"; echo "      VM:   $(tr '\n' '|' < "$T/usersv.txt")"; ok=0
fi

# 5 the users directory with the VM's real stat and mkdir
mkdir -p "$T/ud/has/users" "$T/ud/empty"; : > "$T/ud/file"
cat > "$T/usersreal.la" <<LAEOF
import("wm_livestart.la")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph USERS = USERS_KIT(Z)(str_at)(str_len)(str_eq)(concat)(str_to_int)(add)(sub)(lt)(int_eq)(div)(mod)(chr)(error)(stat)(mkdir)
glyph SHOW = la n. la t. USERS(t)(la d. la f. print(concat(n)(concat(": dir=")(concat(d)(concat(" first=")(f("yes")("no")))))))
glyph MAIN = (la _. (la _. SHOW("empty")("$T/ud/empty\\n"))(SHOW("has")("$T/ud/has\\n")))(SHOW("new")("$T/ud/new\\n"))
LAEOF
wm_vm usersreal.la "$T/usersr.txt"; ur=$vrc
REALEXPECT="new: dir=$T/ud/new first=yes
has: dir=$T/ud/has first=no
empty: dir=$T/ud/empty first=yes"
rhalts=""
for c in "file|$T/ud/file|is not a directory" "x|$T/ud/nope/x|mkdir -> -2"; do
    IFS='|' read -r tag path why <<< "$c"
    sed "s|^glyph MAIN = .*|glyph MAIN = SHOW(\"$tag\")(\"$path\")|" "$T/usersreal.la" > "$T/usersreal_$tag.la"
    wm_vm "usersreal_$tag.la" "$T/ur_$tag.txt"; vm=$(cat "$T/vre" 2>/dev/null)
    if [ "$vrc" = 1 ] && [ ! -s "$T/ur_$tag.txt" ] && [[ "$vm" == *"$path"*"$why"* ]]; then rhalts="$rhalts $tag"
    else echo "      $tag: VM rc=$vrc '$vm'"; fi
done
if [ "$ur" = 0 ] && [ "$(cat "$T/usersr.txt")" = "$REALEXPECT" ] && [ -d "$T/ud/new" ] && [ "$(stat -c %a "$T/ud/new")" = 700 ] \
   && [ "$rhalts" = " file x" ] && [ -f "$T/ud/file" ] && [ ! -e "$T/ud/nope" ]; then
    echo "PASS  wm livestart: 5 the users directory on the VM's filesystem: a missing one made mode 700 (a first run), one with users/ not a first run, an empty one a first run; a file and a missing parent halt, naming the path"
else
    echo "FAIL  wm livestart: 5 the users directory on the VM: rc=$ur, halts:$rhalts, new: $(stat -c %a "$T/ud/new" 2>&1)"
    echo "      $(tr '\n' '|' < "$T/usersr.txt") $(head -c 200 "$T/vre" 2>/dev/null)"; ok=0
fi

if unshare -m true 2>/dev/null; then
    cp "$T/compiler.bin" "$T/logos_program.bin"; cp "$T/theourgia_wm_live.la" "$T/logos_source.la"
    if ( cd "$T" && timeout "$WM_VM_TIMEOUT" ./logos_secd >/dev/null 2>"$T/vce" ); then
        echo / > "$T/logos_wm.cwd"
        echo "$T/lu" > "$T/logos_wm.users"
        lrc=0
        ( cd "$T" && timeout 120 unshare -m --propagation private sh -c "
            mount --bind '$T/devices.txt' /proc/bus/input/devices && mount -t tmpfs none /dev \
            && mkdir /dev/input && : > /dev/input/event3 && exec ./logos_secd" >"$T/live.out" 2>"$T/live.err" ) || lrc=$?
        if [ "$lrc" = 1 ] && ! grep -q "cannot open" "$T/live.err" && grep -qi "drm" "$T/live.err"; then
            echo "PASS  wm livestart: 6 the live entry opens the keyboard (event3, not the mouse) and halts at drm_mode with no GPU: $(head -c 120 "$T/live.err")"
        else
            echo "FAIL  wm livestart: 6 the live entry: rc=$lrc"; echo "      stderr: $(head -c 300 "$T/live.err")"; echo "      stdout: $(head -c 200 "$T/live.out")"; ok=0
        fi
        lrc=0
        ( cd "$T" && timeout 120 unshare -m --propagation private sh -c "
            mount --bind '$T/devices.txt' /proc/bus/input/devices && mount -t tmpfs none /dev \
            && mkdir /dev/input && exec ./logos_secd" >"$T/live2.out" 2>"$T/live2.err" ) || lrc=$?
        if [ "$lrc" = 1 ] && grep -q "event3 (open -> -2): no such device" "$T/live2.err" && ! grep -q "run as root" "$T/live2.err"; then
            echo "PASS  wm livestart: 7 no device node: it says so ($(head -c 120 "$T/live2.err"))"
        else
            echo "FAIL  wm livestart: 7 no device node: rc=$lrc; stderr: $(head -c 300 "$T/live2.err")"; ok=0
        fi
        if [ -d "$T/lu" ] && [ "$(stat -c %a "$T/lu")" = 700 ] && grep -qxF "wm: users in $T/lu, a first run" "$T/live.out" \
           && grep -qi "drm" "$T/live.err"; then
            echo "PASS  wm livestart: 8 before drm_mode the live entry made the users directory from logos_wm.users (mode 700) and called it a first run"
        else
            echo "FAIL  wm livestart: 8 the users directory: $(stat -c %a "$T/lu" 2>&1); stdout: $(head -c 300 "$T/live.out")"; ok=0
        fi
        : > "$T/ufile"; echo "$T/ufile" > "$T/logos_wm.users"
        lrc=0
        ( cd "$T" && timeout 120 unshare -m --propagation private sh -c "
            mount --bind '$T/devices.txt' /proc/bus/input/devices && mount -t tmpfs none /dev \
            && mkdir /dev/input && : > /dev/input/event3 && exec ./logos_secd" >"$T/live3.out" 2>"$T/live3.err" ) || lrc=$?
        if [ "$lrc" = 1 ] && grep -qF "$T/ufile is not a directory" "$T/live3.err" && ! grep -qi "drm" "$T/live3.err" "$T/live3.out"; then
            echo "PASS  wm livestart: 9 logos_wm.users naming a file: it halts naming it, before drm_mode ($(head -c 120 "$T/live3.err"))"
        else
            echo "FAIL  wm livestart: 9 a users file: rc=$lrc; stderr: $(head -c 300 "$T/live3.err")"; ok=0
        fi
        rm -f "$T/logos_wm.users"
        lrc=0
        ( cd "$T" && timeout 120 unshare -m --propagation private sh -c "
            mount --bind '$T/devices.txt' /proc/bus/input/devices && mount -t tmpfs none /dev \
            && mkdir /dev/input && : > /dev/input/event3 && mount -t tmpfs none /var/lib \
            && { ./logos_secd; echo \"rc=\$?\" > '$T/live4.rc'; stat -c %a /var/lib/logos > '$T/live4.mode' 2>&1; }" \
            >"$T/live4.out" 2>"$T/live4.err" ) || lrc=$?
        if [ "$(cat "$T/live4.rc" 2>/dev/null)" = rc=1 ] && [ "$(cat "$T/live4.mode" 2>/dev/null)" = 700 ] \
           && grep -qxF "wm: users in /var/lib/logos, a first run" "$T/live4.out" && grep -qi "drm" "$T/live4.err"; then
            echo "PASS  wm livestart: 10 with no logos_wm.users it makes /var/lib/logos (mode 700, in the namespace's tmpfs) and halts at drm_mode"
        else
            echo "FAIL  wm livestart: 10 no logos_wm.users: $(cat "$T/live4.rc" 2>&1) mode $(cat "$T/live4.mode" 2>&1); stdout: $(head -c 200 "$T/live4.out"); stderr: $(head -c 200 "$T/live4.err")"; ok=0
        fi
    else
        echo "FAIL  wm livestart: 6 theourgia_wm_live.la did not compile: $(tail -2 "$T/vce")"; ok=0
    fi
else
    echo "NOTE  wm livestart: 6-10 skipped (unshare -m is not available)"
fi
if [ "$ok" = 1 ]; then echo "ALL PASS  gate_wm_livestart"; else echo "GATE FAILED  gate_wm_livestart"; exit 1; fi
