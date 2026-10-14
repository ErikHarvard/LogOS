#!/usr/bin/env bash
# gate_wm_simsess.sh — the WM's lock screen in front of LogosSession itself,
# on the path the live WM takes.
#
# WHAT IT GUARDS. The other WM gates lock and unlock the headless WM through
# SIM_SESS, a stand-in session layer (adam / logos). Here the WM is run as
# theourgia_wm_simsess.la, which builds its lock screen exactly as the live
# WM does (logos_realsess.la's REAL_LOCK): the users directory through
# wm_livestart.la's USERS_KIT, LogosSession (logossession.la) over it, and
# lk_firstuser.la's app, the WM starting LOCKED: at the first-run screen when
# no user has ever been made there, at the login screen otherwise. The
# passphrase is stretched with PBKDF2 and checked against the record
# LogosSession's adduser wrote, the Γ-seal and the user's AletheiaFS store
# come from it, and lock drops them. Every frame is read back as text
# (wm_ocr.py). Checks:
#   A  a first run, users=DIR a directory that does not exist yet:
#      1   DIR is made, mode 700; the WM says it is a first run
#      2   it starts at the first-run screen (not a terminal), focused on Name
#      3   an empty name is refused ("Enter a name."), both passphrases gone
#      4   mismatched passphrases are refused, the name kept
#      5   empty passphrases are refused
#      6   a name LogosSession refuses is refused with its reason
#      7   the right input makes the user (record mode 0600, holding the
#          passphrase neither raw nor in hex) and logs in: the terminal
#          opens with the welcome text, which offers MOD+Esc; the user's
#          store exists
#      8   MOD+Esc shows the ORDINARY login screen, the name kept, the
#          focus on the passphrase
#      9   a wrong passphrase is refused ("Wrong passphrase.")
#      10  the new passphrase unlocks: the terminal as it was
#   B  the same directory again (users/ exists now):
#      11  it starts at the login screen, not the first-run screen
#      12  Enter in the User field moves the focus to the Passphrase field
#          (read back from the frame's focused run)
#      13  an unknown user is refused like a wrong passphrase ("Wrong user
#          or passphrase."), and so is a wrong passphrase
#      14  the right one logs in: the welcome terminal
#   15 a frame taken while the first-run screen's two passphrase fields hold
#      typed text (no Enter yet), and one while the login screen's does:
#      one '*' per character (every other frame comes after an Enter, which
#      empties them)
#   16 no passphrase typed (right or wrong) appears in any frame of either
#      run, those two included, nor in the WM's stdout or stderr
#   17 users=DIR a regular file, or under a missing directory: the WM halts
#      at once (rc 1) naming the path, and draws nothing
#   18 theourgia_wm_simsess.la without users=DIR stops at once with a
#      message, and theourgia_wm_sim.la (the stand-in) refuses users=DIR
# LogosSession's own gate (gate_logossession.sh) checks the cryptography and
# that lock leaves no key in memory; this gate checks the WM drives it.
#
# ISOLATION: a private temporary directory (gate_wm_common.sh). VM only. A few
# minutes, mostly compiling the WM with the session layer on the VM.
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1
wm_setup theourgia_tile.la theourgia_term.la theourgia_render.la logosh.la \
         theourgia_wm.la theourgia_termfont.la logoskit.la lk_settings.la lk_login.la lk_firstuser.la \
         theourgia_wm_sim.la theourgia_wm_simsess.la wm_livestart.la logos_realsess.la \
         logoscrypt.la logossec.la aletheiafs.la logossession.la wm_script.py wm_ocr.py
PASS_OK='s3cret-pass'
mkdir -p "$T/home"

cp "$T/compiler.bin" "$T/logos_program.bin"; cp "$T/theourgia_wm_simsess.la" "$T/logos_source.la"
( cd "$T" && timeout "$WM_VM_TIMEOUT" ./logos_secd >/dev/null 2>"$T/vce" ) \
  || { echo "FAIL  wm simsess: theourgia_wm_simsess.la did not compile: $(tail -3 "$T/vce")"; exit 1; }
cp "$T/logos_program.bin" "$T/wmsess.bin"

# run NAME SCRIPT: the headless WM over users=$T/users, frames to $T/NAME/
run() {
    python3 "$T/wm_script.py" "$2" "$T/events.bin" || { echo "FAIL  wm simsess: wm_script.py $2"; exit 1; }
    echo "960 600 1 $T/home events.bin users=$T/users" > "$T/wm_sim.cfg"
    rm -f "$T"/wm_shot_*.bin; cp "$T/wmsess.bin" "$T/logos_program.bin"
    rrc=0; ( cd "$T" && timeout 600 ./logos_secd >"$T/$1.log" 2>"$T/$1.err" ) || rrc=$?
    mkdir -p "$T/$1"; mv "$T"/wm_shot_*.bin "$T/$1/" 2>/dev/null; echo "$rrc" > "$T/$1.rc"
}

# A. a first run: the users directory does not exist yet
cat > "$T/first.txt" <<EOF
snap 1
key ENTER
type $PASS_OK
key ENTER
type $PASS_OK\\n
snap 2
key TAB
key TAB
type adam
key ENTER
type one-pass-1
key ENTER
type two-pass-2
snap 11
key ENTER
snap 3
key ENTER
snap 4
key TAB
key TAB
key BACKSPACE
key BACKSPACE
key BACKSPACE
key BACKSPACE
type eve.x
key ENTER
type $PASS_OK
key ENTER
type $PASS_OK\\n
snap 5
key TAB
key TAB
key BACKSPACE
key BACKSPACE
key BACKSPACE
key BACKSPACE
key BACKSPACE
type adam
key ENTER
type $PASS_OK
key ENTER
type $PASS_OK\\n
snap 6
type echo after login\\n
snap 7
mod ESC
snap 8
type nope-nope\\n
snap 9
type $PASS_OK\\n
snap 10
mod Shift+E
EOF
run first "$T/first.txt"
umode=$(stat -c %a "$T/users" 2>/dev/null)

# B. the same directory again: not a first run
cat > "$T/again.txt" <<EOF
snap 1
type eve
key ENTER
snap 2
type $PASS_OK\\n
snap 3
key TAB
key TAB
key BACKSPACE
key BACKSPACE
key BACKSPACE
type adam
key ENTER
type wrong-pass
snap 6
key ENTER
snap 4
type $PASS_OK\\n
snap 5
mod Shift+E
EOF
run again "$T/again.txt"

python3 - "$T" "$PASS_OK" "$umode" <<'PYEOF' || ok=0
import importlib.util, json, os, sys
T, good, umode = sys.argv[1], sys.argv[2], sys.argv[3]
spec = importlib.util.spec_from_file_location("wm_ocr", f"{T}/wm_ocr.py"); ocr = importlib.util.module_from_spec(spec); spec.loader.exec_module(ocr)
glyphs = ocr.load_font(f"{T}/theourgia_termfont.la")
bad = 0
def check(name, cond, detail):
    global bad
    if cond: print(f"PASS  wm simsess: {name}")
    else: print(f"FAIL  wm simsess: {name}\n      {detail}"); bad = 1
def shot(run, n):
    try: data = open(f"{T}/{run}/wm_shot_{n}.bin", "rb").read()
    except OSError: return None
    return ocr.ocr(ocr.Frame(data, 960, 600, 3840), glyphs, 1)
def rows(s): return [r for r in s[0]["rows"] if r.strip()]
def panel(s): return bool(s) and len(s) == 1 and s[0].get("kind") == "app" and s[0]["title"].startswith(" Log in")
def has(s, text): return any(text in r for r in rows(s))
def term(s): return bool(s) and len(s) == 1 and s[0].get("kind") == "term"
# the focused element's row: the row of the highlighted run
def focus_row(s):
    hl = s[0].get("hl") or []
    return s[0]["rows"][hl[0][0]] if len(hl) == 1 else None
def field(s, label):
    return next((r for r in s[0]["rows"] if label + ": [" in r), None)
def blank_pw(s):
    return all(r is not None and "*" not in r for r in (field(s, "Passphrase"), field(s, "Passphrase again")))
det = lambda s: json.dumps(s)[:700]
log1, err1, rc1 = (open(f"{T}/first.{x}").read() for x in ("log", "err", "rc"))
log2, err2, rc2 = (open(f"{T}/again.{x}").read() for x in ("log", "err", "rc"))
check("A the first run ended 0 on MOD+Shift+e", rc1.strip() == "0" and "wm: exit" in log1, f"rc={rc1.strip()} log {log1[-300:]!r} err {err1[-300:]!r}")
check("1 the users directory was made, mode 700, and the WM says it is a first run",
      umode == "700" and f"wm: users in {T}/users, a first run" in log1, f"mode {umode!r}; log {log1[:400]!r}")
s = shot("first", 1)
check("2 it starts locked at the first-run screen (no terminal), focused on Name",
      panel(s) and has(s, "Welcome. Make the first user.") and (focus_row(s) or "").lstrip("| ").startswith("Name: ["), det(s))
s = shot("first", 2)
check("3 an empty name is refused ('Enter a name.'), both passphrases forgotten",
      panel(s) and has(s, "Enter a name.") and blank_pw(s) and has(s, "Name: [            ]"), det(s))
s = shot("first", 3)
check("4 mismatched passphrases are refused ('The passphrases differ.'), the name kept, both forgotten",
      panel(s) and has(s, "The passphrases differ.") and has(s, "Name: [adam") and blank_pw(s), det(s))
s = shot("first", 4)
check("5 empty passphrases are refused ('Enter a passphrase.')", panel(s) and has(s, "Enter a passphrase."), det(s))
s = shot("first", 5)
check("6 a name LogosSession refuses is refused with its own reason ('adduser: bad name'), the name kept",
      panel(s) and has(s, "adduser: bad name") and has(s, "Name: [eve.x") and blank_pw(s), det(s))
s = shot("first", 6)
rec = f"{T}/users/users/adam"
hexpw = good.encode().hex()
recok = os.path.isfile(rec) and oct(os.stat(rec).st_mode & 0o777) == "0o600" \
        and good.encode() not in open(rec, "rb").read() and hexpw not in open(rec).read().lower()
check("7 the right input makes the user (record mode 600, no passphrase raw or hex) and logs in: the welcome terminal, which offers MOD+Esc; the store exists",
      term(s) and any("Theourgia tiling window manager" in r for r in rows(s)) and any("MOD+Esc" in r and "lock the screen" in r for r in rows(s))
      and recok and os.path.isdir(f"{T}/users/home/adam/obj") and log1.count("wm: unlocked") >= 1, det(s) + f" record ok: {recok}")
s7 = shot("first", 7)
s = shot("first", 8)
check("8 MOD+Esc shows the ordinary login screen: 'Locked: adam', the focus on the passphrase, 'Locked.'",
      panel(s) and has(s, "Locked: adam") and has(s, "Locked.") and has(s, "[ Unlock ]") and not has(s, "Make the first user")
      and (focus_row(s) or "").lstrip("| ").startswith("Passphrase: ["), det(s))
s = shot("first", 9)
check("9 a wrong passphrase is refused: 'Wrong passphrase.'", panel(s) and has(s, "Wrong passphrase."), det(s))
s = shot("first", 10)
check("10 the new passphrase unlocks: the terminal as it was",
      term(s) and term(s7) and any("after login" in r for r in rows(s7)) and s[0]["rows"] == s7[0]["rows"]
      and log1.count("wm: locked") == 1 and log1.count("wm: unlocked") == 2, det(s) + " " + log1[-300:])
check("B the second run ended 0 on MOD+Shift+e, and is not a first run",
      rc2.strip() == "0" and "wm: exit" in log2 and f"wm: users in {T}/users" in log2 and "a first run" not in log2,
      f"rc={rc2.strip()} log {log2[-300:]!r} err {err2[-300:]!r}")
s = shot("again", 1)
check("11 with users/ there it starts at the login screen, not the first-run screen, focused on User",
      panel(s) and has(s, "Log in to LogOS.") and not has(s, "Make the first user")
      and (focus_row(s) or "").lstrip("| ").startswith("User: ["), det(s))
s = shot("again", 2)
check("12 Enter in the User field moves the focus to the Passphrase field",
      panel(s) and has(s, "User: [eve") and (focus_row(s) or "").lstrip("| ").startswith("Passphrase: ["), det(s))
s3, s4 = shot("again", 3), shot("again", 4)
check("13 an unknown user (eve) and a wrong passphrase are both refused: 'Wrong user or passphrase.'",
      panel(s3) and has(s3, "Wrong user or passphrase.") and panel(s4) and has(s4, "Wrong user or passphrase.")
      and has(s4, "User: [adam"), det(s3) + " " + det(s4))
s = shot("again", 5)
check("14 the right passphrase logs in: the welcome terminal",
      term(s) and any("Theourgia tiling window manager" in r for r in rows(s)) and log2.count("wm: unlocked") == 1, det(s))
# the frames taken while the passphrase fields hold typed text
def stars(s, label, n):
    r = field(s, label)
    return r is not None and r.split(label + ": [", 1)[1].startswith("*" * n + " " * (12 - n) + "]")
s = shot("first", 11); s2 = shot("again", 6)
check("15 while the passphrase fields hold typed text (no Enter yet) they show one '*' per character: both of the first-run screen's, and the login screen's",
      panel(s) and has(s, "Make the first user") and stars(s, "Passphrase", 10) and stars(s, "Passphrase again", 10)
      and panel(s2) and has(s2, "Log in to LogOS.") and stars(s2, "Passphrase", 10), det(s) + " " + det(s2))
leak = []
for run, n in [("first", k) for k in range(1, 12)] + [("again", k) for k in range(1, 7)]:
    s = shot(run, n)
    if s is None: leak.append(f"{run} frame {n} missing"); continue
    text = json.dumps(s)
    for p in (good, "one-pass-1", "two-pass-2", "nope-nope", "wrong-pass"):
        if p in text: leak.append(f"{p} in {run} frame {n}")
for name, text in (("first stdout", log1), ("first stderr", err1), ("again stdout", log2), ("again stderr", err2)):
    for p in (good, "one-pass-1", "two-pass-2", "nope-nope", "wrong-pass"):
        if p in text: leak.append(f"{p} in {name}")
check("16 no passphrase typed (right or wrong) appears in any of the 17 frames, nor in the WM's stdout or stderr", not leak, ", ".join(leak))
sys.exit(bad)
PYEOF

# 17. a users= path that is not a directory, or under a missing one
: > "$T/plainfile"; rm -f "$T"/wm_shot_*.bin
printf 'snap 1\n' | python3 "$T/wm_script.py" - "$T/events.bin" || { echo "FAIL  wm simsess: wm_script.py"; exit 1; }
echo "960 600 1 $T/home events.bin users=$T/plainfile" > "$T/wm_sim.cfg"
frc=0; ( cd "$T" && timeout 60 ./logos_secd >"$T/file.log" 2>"$T/file.err" ) || frc=$?
echo "960 600 1 $T/home events.bin users=$T/nodir/users" > "$T/wm_sim.cfg"
mrc=0; ( cd "$T" && timeout 60 ./logos_secd >"$T/miss.log" 2>"$T/miss.err" ) || mrc=$?
if [ "$frc" = 1 ] && grep -qF "$T/plainfile is not a directory" "$T/file.err" && [ "$mrc" = 1 ] \
   && grep -qF "$T/nodir/users (mkdir -> -2)" "$T/miss.err" && [ ! -e "$T/nodir" ] && [ -f "$T/plainfile" ] \
   && ! ls "$T"/wm_shot_*.bin >/dev/null 2>&1 && ! grep -q "wm: headless" "$T/file.log" "$T/miss.log"; then
    echo "PASS  wm simsess: 17 users=DIR a regular file, or under a missing directory, halts at once naming it, before the WM starts: $(head -c 100 "$T/file.err")"
else
    echo "FAIL  wm simsess: 17 file rc=$frc '$(head -c 200 "$T/file.err")'; missing parent rc=$mrc '$(head -c 200 "$T/miss.err")'"; ok=0
fi

# 18. the two entries refuse the wrong configuration
echo "960 600 1 $T/home events.bin" > "$T/wm_sim.cfg"
rc=0; ( cd "$T" && timeout 60 ./logos_secd >/dev/null 2>"$T/nousers.err" ) || rc=$?
cp "$T/compiler.bin" "$T/logos_program.bin"; cp "$T/theourgia_wm_sim.la" "$T/logos_source.la"
( cd "$T" && timeout "$WM_VM_TIMEOUT" ./logos_secd >/dev/null 2>"$T/vce" ) \
  || { echo "FAIL  wm simsess: theourgia_wm_sim.la did not compile: $(tail -3 "$T/vce")"; exit 1; }
echo "960 600 1 $T/home events.bin users=$T/users" > "$T/wm_sim.cfg"
rc2=0; ( cd "$T" && timeout 60 ./logos_secd >/dev/null 2>"$T/stub.err" ) || rc2=$?
if [ "$rc" = 1 ] && grep -q "needs users=DIR" "$T/nousers.err" && [ "$rc2" = 1 ] && grep -q "theourgia_wm_simsess.la" "$T/stub.err"; then
    echo "PASS  wm simsess: 18 without users=DIR the real-session entry stops at once (rc 1, says so); the stand-in entry refuses users=DIR (rc 1, names the other)"
else
    echo "FAIL  wm simsess: 18 rc=$rc '$(head -c 150 "$T/nousers.err")'; stand-in rc=$rc2 '$(head -c 150 "$T/stub.err")'"; ok=0
fi

if [ "$ok" = 1 ]; then echo "ALL PASS  gate_wm_simsess"; else echo "GATE FAILED  gate_wm_simsess"; exit 1; fi
