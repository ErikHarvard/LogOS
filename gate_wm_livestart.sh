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
#      one level; a FIRST RUN exactly when stat(DIR/users) is -2 (a
#      directory that exists without users/ is a first run; one with users/
#      a directory, a regular file, or not stat-able (-13) is not); and four
#      loud halts, each naming the path: a regular file, a missing parent, a
#      stat error other than "does not exist", a line holding a NUL byte
#      (named up to the NUL; nothing is made); and, in a second stub world
#      where /var/lib/logos already has users/, no logos_wm.users (or a blank
#      line) is the default directory and NOT a first run: the live WM's
#      usual second boot
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
#   9  logos_wm.users naming a regular file, or holding a NUL byte: it halts
#      naming the path and never reaches drm_mode (a loud failure leaves no
#      taken screen); for the NUL, nothing is made at the path cut there
#   10 no logos_wm.users at all, with a tmpfs over /var/lib in the namespace:
#      it makes /var/lib/logos, mode 700, and halts at drm_mode; started again
#      once /var/lib/logos/users exists, it is not a first run
#   11 the live entry past drm_mode: a copy of theourgia_wm_live.la with only
#      its two screen calls replaced (drm_mode answers 640x400, present
#      writes the frame to a file and logs it), run in the namespace with
#      /dev/input/event3 a FIFO the gate types into: the first frame it
#      presents, before any key, is the first-run screen (the lock screen
#      the live entry hands WM_BUILD, not a terminal); making the first user
#      presents the welcome terminal, which offers MOD+Esc; MOD+Esc presents
#      the login screen with the user's name
# Every run of the live entry is given a users directory in the gate's own
# directory (or a tmpfs), so the gate never makes /var/lib/logos on the host.
#
# ISOLATION: a private temporary directory (gate_wm_common.sh); checks 6-11
# need unshare -m (root) and are skipped with a NOTE without it. A few
# minutes, mostly compiling the live WM (twice) on the VM.
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1
wm_setup wm_livestart.la theourgia_tile.la theourgia_term.la theourgia_render.la logosh.la \
         theourgia_wm.la theourgia_termfont.la logoskit.la lk_settings.la theourgia_wm_live.la \
         lk_login.la lk_firstuser.la logos_realsess.la logoscrypt.la logossec.la aletheiafs.la logossession.la \
         wm_script.py wm_ocr.py

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
# regular file, /srv/acc cannot be stat'ed; /srv/uf's users is a regular file
# and /srv/ua's cannot be stat'ed; everything else does not exist.
# mkdir prints what it is asked and fails (no such parent) under /nope only.
glyph ST = la p. str_eq(p)("/srv/l")("16877 4096")(str_eq(p)("/srv/l/users")("16832 4096")(
  str_eq(p)("/srv/e")("16877 4096")(str_eq(p)("/srv/f")("33188 10")(str_eq(p)("/srv/acc")("-13")(
  str_eq(p)("/srv/uf")("16877 4096")(str_eq(p)("/srv/uf/users")("33188 0")(
  str_eq(p)("/srv/ua")("16877 4096")(str_eq(p)("/srv/ua/users")("-13")("-2")))))))))
glyph MK = la p. la m. (la _. str_eq(p)("/nope/x")("-2")("0"))(print(concat("  mkdir ")(concat(p)(concat(" ")(m)))))
glyph USERS = USERS_KIT(Z)(str_at)(str_len)(str_eq)(concat)(str_to_int)(add)(sub)(lt)(int_eq)(div)(mod)(chr)(error)(ST)(MK)
glyph CR = chr("13")
glyph SHOW = la n. la t. USERS(t)(la d. la f. print(concat(n)(concat(": dir=")(concat(d)(concat(" first=")(f("yes")("no")))))))
glyph MAIN = (la _. (la _. (la _. (la _. (la _. (la _. (la _. SHOW("new")("/srv/new\n"))
  (SHOW("uacc")("/srv/ua\n")))
  (SHOW("ufile")("/srv/uf\n")))
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
ufile: dir=/srv/uf first=no
uacc: dir=/srv/ua first=no
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
# the second stub world: the default directory already has users/
cat > "$T/users_def.la" <<'LAEOF'
import("wm_livestart.la")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph ST = la p. str_eq(p)("/var/lib/logos")("16832 4096")(str_eq(p)("/var/lib/logos/users")("16832 4096")("-2"))
glyph MK = la p. la m. (la _. "0")(print(concat("  mkdir ")(concat(p)(concat(" ")(m)))))
glyph USERS = USERS_KIT(Z)(str_at)(str_len)(str_eq)(concat)(str_to_int)(add)(sub)(lt)(int_eq)(div)(mod)(chr)(error)(ST)(MK)
glyph SHOW = la n. la t. USERS(t)(la d. la f. print(concat(n)(concat(": dir=")(concat(d)(concat(" first=")(f("yes")("no")))))))
glyph MAIN = (la _. SHOW("blank")("  \t \n"))(SHOW("missing")(""))
LAEOF
DEFEXPECT='missing: dir=/var/lib/logos first=no
blank: dir=/var/lib/logos first=no'
wm_host users_def.la "$T/udh.txt"; udh=$hrc
wm_vm users_def.la "$T/udv.txt"; udv=$vrc
# a NUL byte in the line: every syscall would see the path cut there
sed '/^glyph MAIN = /,$d' "$T/users.la" > "$T/users_nul.la"
cat >> "$T/users_nul.la" <<'LAEOF'
glyph MAIN = SHOW("nul")(concat("/srv/nu")(concat(chr("0"))("l\n")))
LAEOF
wm_host users_nul.la "$T/uh_nul.txt"; hm=$(cat "$T/hre")
wm_vm users_nul.la "$T/uv_nul.txt"; vm=$(cat "$T/vre" 2>/dev/null)
if [ "$hrc" = 1 ] && [ "$vrc" = 1 ] && [ ! -s "$T/uh_nul.txt" ] && [ ! -s "$T/uv_nul.txt" ] \
   && [[ "$hm" == *"NUL byte after /srv/nu ("* ]] && [[ "$vm" == *"NUL byte after /srv/nu ("* ]]; then
    halts="$halts nul"
else
    echo "      nul: host rc=$hrc '$hm' out '$(cat "$T/uh_nul.txt")'; VM rc=$vrc '$vm' out '$(cat "$T/uv_nul.txt")'"
fi
if [ "$uh" = 0 ] && [ "$uv" = 0 ] && [ "$(cat "$T/usersh0.txt")" = "$USERSEXPECT" ] && [ "$(cat "$T/usersv.txt")" = "$USERSEXPECT" ] \
   && [ "$halts" = " f x acc nul" ] && [ "$udh" = 0 ] && [ "$udv" = 0 ] && [ "$(cat "$T/udh.txt")" = "$DEFEXPECT" ] \
   && [ "$(cat "$T/udv.txt")" = "$DEFEXPECT" ]; then
    echo "PASS  wm livestart: 4 the users directory: first line trimmed, /var/lib/logos when missing or blank, made 0700 when missing, first run iff stat(DIR/users) is -2 (users/ a file or -13 is not); a file, a missing parent, a stat error and a NUL byte halt naming the path; the default directory with users/ is not a first run; host = VM"
else
    echo "FAIL  wm livestart: 4 the users directory: host rc=$uh VM rc=$uv, halts:$halts"
    echo "      host: $(tr '\n' '|' < "$T/usersh0.txt")"; echo "      VM:   $(tr '\n' '|' < "$T/usersv.txt")"
    echo "      default with users/: host rc=$udh $(tr '\n' '|' < "$T/udh.txt"); VM rc=$udv $(tr '\n' '|' < "$T/udv.txt")"; ok=0
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
        printf '%s\0tail\n' "$T/unul" > "$T/logos_wm.users"
        lrc=0
        ( cd "$T" && timeout 120 unshare -m --propagation private sh -c "
            mount --bind '$T/devices.txt' /proc/bus/input/devices && mount -t tmpfs none /dev \
            && mkdir /dev/input && : > /dev/input/event3 && exec ./logos_secd" >"$T/live3n.out" 2>"$T/live3n.err" ) || lrc=$?
        if [ "$lrc" = 1 ] && grep -qF "NUL byte after $T/unul (" "$T/live3n.err" && ! grep -qi "drm" "$T/live3n.err" "$T/live3n.out" \
           && [ ! -e "$T/unul" ]; then
            echo "PASS  wm livestart: 9 logos_wm.users holding a NUL byte: it halts naming the path before it, makes nothing there, and never reaches drm_mode"
        else
            echo "FAIL  wm livestart: 9 a NUL in logos_wm.users: rc=$lrc; made: $(ls -d "$T/unul" 2>&1); stdout: $(cat -v "$T/live3n.out" | head -c 200); stderr: $(head -c 300 "$T/live3n.err")"; ok=0
        fi
        rm -f "$T/logos_wm.users"
        lrc=0
        ( cd "$T" && timeout 120 unshare -m --propagation private sh -c "
            mount --bind '$T/devices.txt' /proc/bus/input/devices && mount -t tmpfs none /dev \
            && mkdir /dev/input && : > /dev/input/event3 && mount -t tmpfs none /var/lib \
            && { ./logos_secd; echo \"rc=\$?\" > '$T/live4.rc'; stat -c %a /var/lib/logos > '$T/live4.mode' 2>&1; } \
            && mkdir /var/lib/logos/users && { ./logos_secd >'$T/live5.out' 2>'$T/live5.err'; echo \"rc=\$?\" > '$T/live5.rc'; }" \
            >"$T/live4.out" 2>"$T/live4.err" ) || lrc=$?
        if [ "$(cat "$T/live4.rc" 2>/dev/null)" = rc=1 ] && [ "$(cat "$T/live4.mode" 2>/dev/null)" = 700 ] \
           && grep -qxF "wm: users in /var/lib/logos, a first run" "$T/live4.out" && grep -qi "drm" "$T/live4.err" \
           && [ "$(cat "$T/live5.rc" 2>/dev/null)" = rc=1 ] && grep -qxF "wm: users in /var/lib/logos" "$T/live5.out" \
           && ! grep -q "first run" "$T/live5.out" && grep -qi "drm" "$T/live5.err"; then
            echo "PASS  wm livestart: 10 with no logos_wm.users it makes /var/lib/logos (mode 700, in the namespace's tmpfs) and halts at drm_mode; once /var/lib/logos/users exists it is not a first run"
        else
            echo "FAIL  wm livestart: 10 no logos_wm.users: $(cat "$T/live4.rc" 2>&1) mode $(cat "$T/live4.mode" 2>&1); stdout: $(head -c 200 "$T/live4.out"); stderr: $(head -c 200 "$T/live4.err")"
            echo "      second boot: $(cat "$T/live5.rc" 2>&1); stdout: $(head -c 200 "$T/live5.out" 2>&1); stderr: $(head -c 200 "$T/live5.err" 2>&1)"; ok=0
        fi
        # 11 the live entry past drm_mode, its two screen calls replaced
        DRM='          (WM_SPLIT(B)(WM_LISTS(B))(drm_mode("!"))))'
        PRESENT='                  (la s. s(la bytes. present(bytes))(WM_CONS(fd)(WM_NIL))("2400")(FALSE)))'
        if [ "$(grep -cxF "$DRM" "$T/theourgia_wm_live.la")" = 1 ] && [ "$(grep -cxF "$PRESENT" "$T/theourgia_wm_live.la")" = 1 ]; then
            python3 - "$T/theourgia_wm_live.la" "$T/live_emu.la" "$DRM" "$PRESENT" <<'PYEOF2'
import sys
src, dst, drm, present = sys.argv[1:5]
s = open(src).read()
s = s.replace(drm + "\n", drm.replace('drm_mode("!")', '"640 400 2560"') + "\n")
s = s.replace(present + "\n", present.replace("present(bytes)",
      '(la _. print(concat("wm: present ")(str_len(bytes))))(write_file("live_frame.bin")(bytes))') + "\n")
open(dst, "w").write(s)
PYEOF2
            cp "$T/compiler.bin" "$T/logos_program.bin"; cp "$T/live_emu.la" "$T/logos_source.la"
            if ( cd "$T" && timeout "$WM_VM_TIMEOUT" ./logos_secd >/dev/null 2>"$T/vce" ); then
                echo "$T/lu2" > "$T/logos_wm.users"
                python3 - "$T" <<'PYEOF2' || ok=0
import importlib.util, os, subprocess, sys, time
T = sys.argv[1]; os.chdir(T)
def load(name):
    spec = importlib.util.spec_from_file_location(name, f"{T}/{name}.py")
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m
ws, ocr = load("wm_script"), load("wm_ocr")
glyphs = ocr.load_font(f"{T}/theourgia_termfont.la")
os.mkfifo("kbd.fifo")
PASS = "s3cret-emu"
wm = subprocess.Popen(["timeout", "180", "unshare", "-m", "--propagation", "private", "sh", "-c",
    f"mount --bind '{T}/devices.txt' /proc/bus/input/devices && mount -t tmpfs none /dev && mkdir /dev/input "
    f"&& ln -s '{T}/kbd.fifo' /dev/input/event3 && exec ./logos_secd"],
    stdout=open("emu.log", "w"), stderr=open("emu.err", "w"))
kbd = open("kbd.fifo", "wb", buffering=0)
def log(): return open("emu.log", errors="replace").read()
def wait(pattern, n=1, timeout=60.0):
    t = time.time()
    while time.time() - t < timeout:
        if log().count(pattern) >= n: return True
        if wm.poll() is not None: return False
        time.sleep(0.05)
    return False
def frame():
    try: return ocr.ocr(ocr.Frame(open("live_frame.bin", "rb").read(), 640, 400, 2560), glyphs, 1)
    except OSError: return None
def rows(s): return [r for t in (s or []) for r in t["rows"] if r.strip()]
def app(s): return bool(s) and len(s) == 1 and s[0].get("kind") == "app" and s[0]["title"].startswith(" Log in")
ok1 = wait("wm: present"); s1 = frame(); n1 = log().count("wm: present")
kbd.write(ws.compile_script([f"type adam\\n{PASS}\\n{PASS}\\n"]))
ok2 = wait("wm: unlocked", timeout=90) and wait("wm: present", n1 + 1); time.sleep(1.0); s2 = frame(); n2 = log().count("wm: present")
kbd.write(ws.compile_script(["mod ESC"]))
ok3 = wait("wm: locked") and wait("wm: present", n2 + 1); time.sleep(1.0); s3 = frame()
wm.terminate()
try: wm.wait(timeout=30)
except subprocess.TimeoutExpired: wm.kill()
good = (ok1 and app(s1) and any("Welcome. Make the first user." in r for r in rows(s1))
        and f"wm: users in {T}/lu2, a first run" in log()
        and ok2 and s2 and len(s2) == 1 and s2[0].get("kind") == "term"
        and any("MOD+Esc" in r and "lock the screen" in r for r in rows(s2))
        and ok3 and app(s3) and any("Locked: adam" in r for r in rows(s3))
        and PASS not in log() and PASS not in open("emu.err").read())
if good:
    print("PASS  wm livestart: 11 the live entry past drm_mode (screen calls stubbed): its first frame is the first-run screen, the new user gets the welcome terminal offering MOD+Esc, and MOD+Esc presents the login screen")
else:
    print("FAIL  wm livestart: 11 the live entry past drm_mode")
    for name, s in (("first frame", s1), ("after the first user", s2), ("after MOD+Esc", s3)):
        print(f"      {name}: {rows(s)[:9]}")
    print(f"      log: {log()[-400:]!r}; stderr: {open('emu.err').read()[-300:]!r}")
    sys.exit(1)
PYEOF2
            else
                echo "FAIL  wm livestart: 11 the emulated live entry did not compile: $(tail -2 "$T/vce")"; ok=0
            fi
        else
            echo "FAIL  wm livestart: 11 theourgia_wm_live.la's drm_mode or present call is not where this gate expects it"; ok=0
        fi
    else
        echo "FAIL  wm livestart: 6 theourgia_wm_live.la did not compile: $(tail -2 "$T/vce")"; ok=0
    fi
else
    echo "NOTE  wm livestart: 6-11 skipped (unshare -m is not available)"
fi
if [ "$ok" = 1 ]; then echo "ALL PASS  gate_wm_livestart"; else echo "GATE FAILED  gate_wm_livestart"; exit 1; fi
