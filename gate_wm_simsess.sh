#!/usr/bin/env bash
# gate_wm_simsess.sh — the WM's lock screen in front of LogosSession itself.
#
# WHAT IT GUARDS. The other WM gates lock and unlock the headless WM through
# SIM_SESS, a stand-in session layer (adam / logos). Here the WM is run as
# theourgia_wm_simsess.la, whose lock screen (lk_login.la) calls LogosSession
# (logossession.la): the passphrase is stretched with PBKDF2 and checked
# against the user record LogosSession's own adduser wrote, the Γ-seal and the
# user's AletheiaFS store come from it, and lock drops them. Checks, every
# frame read back as text (wm_ocr.py):
#   1  adduser (LogosSession's, run on the VM) writes the user record, mode
#      0600, with neither the passphrase nor its hex in it
#   2  MOD+Esc before any login: the login panel
#   3  a wrong passphrase is refused ("Wrong user or passphrase.") and the
#      screen stays locked
#   4  the right one logs in through LogosSession: the terminal is back with
#      what it showed, the WM logs "wm: unlocked", and the user's store exists
#   5  MOD+Esc again locks the open session: the panel asks only for the
#      passphrase ("Locked.")
#   6  a wrong passphrase is refused again ("Wrong passphrase.")
#   7  the right one unlocks, the terminal as it was
#   8  the passphrases typed (right and wrong) never appear in any frame
#   9  an unknown user is refused with the same note as a wrong passphrase
#  10  theourgia_wm_simsess.la without users=DIR stops at once with a message,
#      and theourgia_wm_sim.la (the stand-in) refuses users=DIR
# LogosSession's own gate (gate_logossession.sh) checks the cryptography and
# that lock leaves no key in memory; this gate checks the WM drives it.
#
# ISOLATION: a private temporary directory (gate_wm_common.sh). VM only. A few
# minutes, mostly compiling the WM with the session layer on the VM.
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1
wm_setup theourgia_tile.la theourgia_term.la theourgia_render.la logosh.la \
         theourgia_wm.la theourgia_termfont.la logoskit.la lk_settings.la lk_login.la theourgia_wm_sim.la \
         theourgia_wm_simsess.la logoscrypt.la logossec.la aletheiafs.la logossession.la \
         wm_script.py wm_ocr.py
PASS_OK='s3cret-pass'
mkdir -p "$T/home"

# 1. a user, made by LogosSession's own adduser
cat > "$T/adduser.la" <<'LAEOF'
import("logoscrypt.la")
import("logossec.la")
import("aletheiafs.la")
import("logossession.la")
glyph MAIN = (la cr. (la sec. (la fk.
    SESSION_KIT(str_at)(ord)(str_len)(str_to_int)(int_to_str)(chr)(concat)(str_eq)(add)(sub)(mul)(div)(mod)(lt)(int_eq)
               (bor)(bxor)(error)(stat)(read_file)(open)(write)(close)(rename)(unlink)(mkdir)(chmod)(clock_gettime)
               (cr)(sec)(fk)(random)
      (la adduser. la login. la lock. la unlock. la suspend. la resume. la state. la logout.
         print(adduser("users")("adam")(read_file("pass.txt"))(la m. concat("err ")(m))(la n. concat("ok ")(n)))))
    (FS_KIT(str_at)(ord)(str_len)(str_to_int)(int_to_str)(chr)(concat)(str_eq)(add)(sub)(mul)(div)(mod)(lt)(int_eq)
           (stat)(read_file)(write_file)(rename)(unlink)(mkdir)(rmdir)(pipe)(open)(close)(read)(write)(cr)(random)))
  (SEC_KIT(str_at)(ord)(str_len)(str_to_int)(int_to_str)(chr)(concat)(str_eq)(add)(sub)(mul)(div)(lt)(int_eq)(band)(bor)(bxor)(cr)))
  (CRYPT_FAST(str_at)(ord)(str_to_int)(int_to_str)(chr)(concat)(str_len)(error)(add)(sub)(mul)(lt)(int_eq)(band)(bor)(bxor)(bshl)(bshr))
LAEOF
printf '%s' "$PASS_OK" > "$T/pass.txt"
wm_vm adduser.la "$T/adduser.out"; rm -f "$T/pass.txt"
rec="$T/users/users/adam"
if [ "$vrc" = 0 ] && [ "$(cat "$T/adduser.out")" = "ok adam" ] && [ -f "$rec" ] \
   && [ "$(stat -c %a "$rec")" = 600 ] && ! grep -qF "$PASS_OK" "$rec" \
   && ! grep -qiF "$(printf '%s' "$PASS_OK" | od -An -tx1 | tr -d ' \n')" "$rec"; then
    echo "PASS  wm simsess: 1 LogosSession's adduser wrote adam's record (mode 600, no passphrase in it, raw or hex)"
else
    echo "FAIL  wm simsess: 1 adduser: rc=$vrc out=$(head -c 200 "$T/adduser.out") $(tail -2 "$T/vre" 2>/dev/null)"; exit 1
fi

# 2-8. a session through the lock screen
cat > "$T/run.txt" <<EOF
snap 1
type echo before lock\\n
snap 2
mod ESC
snap 3
type adam
key TAB
type wrong-pass\\n
snap 4
type $PASS_OK\\n
snap 5
mod ESC
snap 6
type nope-nope\\n
snap 7
type $PASS_OK\\n
snap 8
mod Shift+E
EOF
python3 "$T/wm_script.py" "$T/run.txt" "$T/events.bin" || { echo "FAIL  wm simsess: wm_script.py"; exit 1; }
echo "960 600 1 $T/home events.bin users=$T/users" > "$T/wm_sim.cfg"
cp "$T/compiler.bin" "$T/logos_program.bin"; cp "$T/theourgia_wm_simsess.la" "$T/logos_source.la"
( cd "$T" && timeout "$WM_VM_TIMEOUT" ./logos_secd >/dev/null 2>"$T/vce" ) \
  || { echo "FAIL  wm simsess: theourgia_wm_simsess.la did not compile: $(tail -3 "$T/vce")"; exit 1; }
cp "$T/logos_program.bin" "$T/wmsess.bin"
rc=0; ( cd "$T" && timeout 600 ./logos_secd >"$T/run.log" 2>"$T/run.err" ) || rc=$?
mkdir -p "$T/frames"; mv "$T"/wm_shot_*.bin "$T/frames/" 2>/dev/null

python3 - "$T" "$rc" "$PASS_OK" <<'PYEOF' || ok=0
import importlib.util, json, os, sys
T, rc, good = sys.argv[1], sys.argv[2], sys.argv[3]
spec = importlib.util.spec_from_file_location("wm_ocr", f"{T}/wm_ocr.py"); ocr = importlib.util.module_from_spec(spec); spec.loader.exec_module(ocr)
glyphs = ocr.load_font(f"{T}/theourgia_termfont.la")
log = open(f"{T}/run.log").read()
bad = 0
def check(name, cond, detail):
    global bad
    if cond: print(f"PASS  wm simsess: {name}")
    else: print(f"FAIL  wm simsess: {name}\n      {detail}"); bad = 1
def shot(n):
    try: data = open(f"{T}/frames/wm_shot_{n}.bin", "rb").read()
    except OSError: return None
    return ocr.ocr(ocr.Frame(data, 960, 600, 3840), glyphs, 1)
def rows(t): return [r for r in t["rows"] if r.strip()]
def panel(s): return s and len(s) == 1 and s[0].get("kind") == "app" and s[0]["title"].startswith(" Log in")
def has(s, text): return any(text in r for r in rows(s[0]))
check("the WM ran the session and exited 0 on MOD+Shift+e", rc == "0" and "wm: exit" in log,
      f"rc={rc}; log {log[-300:]!r}; stderr {open(f'{T}/run.err').read()[-300:]!r}")
check("the session layer is LogosSession over the users directory", f"users in {T}/users" in log, log[:300])
s2 = shot(2)
s = shot(3)
check("2 MOD+Esc before any login: the login panel", panel(s) and has(s, "Log in to LogOS.") and has(s, "User: ["), json.dumps(s)[:800])
s = shot(4)
check("3 a wrong passphrase is refused: still locked, 'Wrong user or passphrase.'",
      panel(s) and has(s, "Wrong user or passphrase."), json.dumps(s)[:800])
s = shot(5)
term = lambda s: s and len(s) == 1 and s[0].get("kind") != "app" and "before lock" in rows(s[0])
check("4 the right passphrase logs in through LogosSession: the terminal is back as it was, and the user's store exists",
      term(s) and log.count("wm: unlocked") >= 1 and os.path.isdir(f"{T}/users/home/adam/obj")
      and s[0]["rows"] == s2[0]["rows"], json.dumps(s)[:800])
s = shot(6)
check("5 MOD+Esc again locks the open session: the panel says 'Locked.'", panel(s) and has(s, "Locked."), json.dumps(s)[:800])
s = shot(7)
check("6 a wrong passphrase is refused again: 'Wrong passphrase.'", panel(s) and has(s, "Wrong passphrase."), json.dumps(s)[:800])
s = shot(8)
check("7 the right passphrase unlocks: the terminal as it was", term(s) and s[0]["rows"] == s2[0]["rows"]
      and log.count("wm: locked") == 2 and log.count("wm: unlocked") == 2, json.dumps(s)[:800] + " " + log[-300:])
leak = []
for n in range(1, 9):
    s = shot(n)
    if s is None: leak.append(f"frame {n} missing"); continue
    text = json.dumps(s)
    for p in (good, "wrong-pass", "nope-nope"):
        if p in text: leak.append(f"{p} in frame {n}")
check("8 no passphrase typed (right or wrong) appears in any of the 8 frames", not leak, ", ".join(leak))
sys.exit(bad)
PYEOF

# 9. an unknown user is refused like a wrong passphrase
printf 'mod ESC\ntype eve\nkey TAB\ntype %s\\n\nsnap 1\n' "$PASS_OK" > "$T/eve.txt"
python3 "$T/wm_script.py" "$T/eve.txt" "$T/events.bin" || { echo "FAIL  wm simsess: wm_script.py"; exit 1; }
rm -f "$T"/wm_shot_*.bin
cp "$T/wmsess.bin" "$T/logos_program.bin"
rc=0; ( cd "$T" && timeout 300 ./logos_secd >"$T/eve.log" 2>"$T/eve.err" ) || rc=$?
python3 - "$T" "$rc" <<'PYEOF' || ok=0
import importlib.util, json, sys
T, rc = sys.argv[1], sys.argv[2]
spec = importlib.util.spec_from_file_location("wm_ocr", f"{T}/wm_ocr.py"); ocr = importlib.util.module_from_spec(spec); spec.loader.exec_module(ocr)
glyphs = ocr.load_font(f"{T}/theourgia_termfont.la")
try: s = ocr.ocr(ocr.Frame(open(f"{T}/wm_shot_1.bin", "rb").read(), 960, 600, 3840), glyphs, 1)
except OSError: s = None
log = open(f"{T}/eve.log").read()
good = rc == "0" and s and len(s) == 1 and s[0].get("kind") == "app" and any("Wrong user or passphrase." in r for r in s[0]["rows"]) \
       and "wm: unlocked" not in log
print(("PASS" if good else "FAIL") + "  wm simsess: 9 an unknown user (eve) is refused with the same note as a wrong passphrase"
      + ("" if good else f"\n      rc={rc} {json.dumps(s)[:600]} log {log[-200:]!r}"))
sys.exit(0 if good else 1)
PYEOF

# 10. the two entries refuse the wrong configuration
echo "960 600 1 $T/home events.bin" > "$T/wm_sim.cfg"
rc=0; ( cd "$T" && timeout 60 ./logos_secd >/dev/null 2>"$T/nousers.err" ) || rc=$?
cp "$T/compiler.bin" "$T/logos_program.bin"; cp "$T/theourgia_wm_sim.la" "$T/logos_source.la"
( cd "$T" && timeout "$WM_VM_TIMEOUT" ./logos_secd >/dev/null 2>"$T/vce" ) \
  || { echo "FAIL  wm simsess: theourgia_wm_sim.la did not compile: $(tail -3 "$T/vce")"; exit 1; }
echo "960 600 1 $T/home events.bin users=$T/users" > "$T/wm_sim.cfg"
rc2=0; ( cd "$T" && timeout 60 ./logos_secd >/dev/null 2>"$T/stub.err" ) || rc2=$?
if [ "$rc" = 1 ] && grep -q "needs users=DIR" "$T/nousers.err" && [ "$rc2" = 1 ] && grep -q "theourgia_wm_simsess.la" "$T/stub.err"; then
    echo "PASS  wm simsess: 10 without users=DIR the real-session entry stops at once (rc 1, says so); the stand-in entry refuses users=DIR (rc 1, names the other)"
else
    echo "FAIL  wm simsess: 10 rc=$rc '$(head -c 150 "$T/nousers.err")'; stand-in rc=$rc2 '$(head -c 150 "$T/stub.err")'"; ok=0
fi

if [ "$ok" = 1 ]; then echo "ALL PASS  gate_wm_simsess"; else echo "GATE FAILED  gate_wm_simsess"; exit 1; fi
