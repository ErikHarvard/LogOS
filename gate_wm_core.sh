#!/usr/bin/env bash
# gate_wm_core.sh — the tiling window manager's core (WM_CORE in
# theourgia_wm.la): state, key bindings, apps and the lock screen, with no
# renderer and no real shell, on the native VM.
#
# WHAT IT GUARDS. A scripted session of evdev records is folded through the
# WM's own handle (WM_FOLD), exactly as the poll loop does it, with the real
# tiling layout (theourgia_tile.la) and terminal model (theourgia_term.la), a
# stub shell (SHSTUB below: echo, cd, exit, clear; anything else echoed back)
# and a stub session layer (user adam, passphrase logos). At every snapshot the
# harness prints the split tree, the focus, every window's version and text
# rows (a terminal) or accessible description and theme (an app), and the lock
# screen when it shows. The expected output below was checked by hand:
#    1-2   the first window; echo
#    3     MOD+Enter splits the focused window along its longer side (H500),
#          the new window takes the focus; cd changes the stub shell's prompt
#    4-6   MOD+Left focus, MOD+Shift+Right swap, MOD+t stacked (V500)
#    7-9   MOD+q closes the focused window; exit in the last shell closes it
#          (an empty tree); MOD+Enter opens window 3
#    10-13 MOD+s opens the settings panel (window 4) focused on Name; typing
#          edits it, Tab+Space turns the dark theme on, Down selects scale 2,
#          Enter on Save counts it; MOD+q closes it
#    14    MOD+Esc locks the screen; never logged in, it asks for a login
#    15    MOD+Enter while locked opens nothing; adam / logos unlocks
#    16    MOD+Esc again: "Locked: adam", only the passphrase asked; a wrong
#          one is refused
#    17    the right one unlocks
#    18    locked again: MOD+q and Ctrl+U type nothing into the panel
#    19    unlocked; in the settings panel Ctrl+U types nothing either;
#          MOD+q closes it and MOD+Shift+e quits
#
# ISOLATION: private temp dir (gate_wm_common.sh). About a minute.
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1
wm_setup theourgia_tile.la theourgia_term.la theourgia_wm.la logoskit.la lk_settings.la lk_login.la wm_script.py
cat > "$T/session.txt" <<'EOF'
snap 1
type echo hi\n
snap 2
mod Enter
type cd /tmp\n
type pwd\n
snap 3
mod Left
snap 4
mod Shift+Right
snap 5
mod t
snap 6
mod q
snap 7
type exit\n
snap 8
mod Enter
snap 9
mod s
snap 10
type x
key TAB
key SPACE
snap 11
key TAB
key DOWN
key TAB
key ENTER
snap 12
mod q
snap 13
mod ESC
snap 14
mod Enter
type adam
key TAB
type logos\n
snap 15
mod ESC
type lugos\n
snap 16
type logos\n
snap 17
mod ESC
mod q
ctrl u
snap 18
type logos\n
mod s
ctrl u
snap 19
mod q
mod Shift+E
EOF
python3 "$T/wm_script.py" "$T/session.txt" "$T/events.bin" || { echo "FAIL  wm core: wm_script.py"; exit 1; }
cat > "$T/core.la" <<'LAEOF'
import("theourgia_tile.la")
import("theourgia_term.la")
import("theourgia_wm.la")
import("logoskit.la")
import("lk_settings.la")
import("lk_login.la")
glyph B = la s. s(str_at)(ord)(str_to_int)(int_to_str)(concat)(str_eq)(str_len)(add)(sub)(mul)(div)(mod)(lt)(int_eq)(band)(bor)
glyph X = la s. s(la a. la b. "")(la a. la b. "")(la fd. fd)(print)(write_file)(exit)
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph STARTS = Z(la self. la s. la p. str_eq(p)("")(la _. la t. la f. t)(la _. str_eq(s)("")(la _. la t. la f. f)(la _. str_eq(str_head(s))(str_head(p))(la _. self(str_tail(s))(str_tail(p)))(la _. la t. la f. f)("!"))("!"))("!"))
glyph DROPN = Z(la self. la n. la s. int_eq(n)(0)(la _. s)(la _. self(sub(n)(1))(str_tail(s)))("!"))
# a stub shell: state = cwd; echo, exit, clear, cd <dir>, anything else is echoed back.
# Its actions are encoded as logosh.la's: the selected branch, unapplied.
glyph SHSTUB = la s. s(la cwd. cwd)(la sh. concat("logos:")(concat(sh)("$ ")))
   (la sh. la line. la k.
      STARTS(line)("echo ")(la _. k(sh)(concat(DROPN(5)(line))("\n"))(la n. la c. la e. la j. n))(la _.
      str_eq(line)("exit")(la _. k(sh)("")(la n. la c. la e. la j. e))(la _.
      str_eq(line)("clear")(la _. k(sh)("")(la n. la c. la e. la j. c))(la _.
      STARTS(line)("cd ")(la _. k(DROPN(3)(line))("")(la n. la c. la e. la j. n))(la _.
      k(sh)(concat("stub: ")(concat(line)("\n")))(la n. la c. la e. la j. n))("!"))("!"))("!"))("!"))
   (la sh. la pid. la k. k(sh)(""))(la pid. pid)(la pid. pid)
glyph OK  = la x. la err. la ok. ok(x)
glyph ERR = la x. la err. la ok. err(x)
glyph SESS = la s. s
  (la name. la pass. str_eq(name)("adam")(la _. str_eq(pass)("logos")(la _. OK(concat("S:")(name)))(la _. ERR("no"))("!"))(la _. ERR("no"))("!"))
  (la sn. concat("L:")(sn))
  (la l. la pass. str_eq(pass)("logos")(la _. OK(str_tail(str_tail(l))))(la _. ERR("no"))("!"))
glyph PRINTALL = Z(la self. la l. l(la _. "")(la h. la t. (la _. self(t))(print(concat("    |")(concat(h)("|"))))))
glyph MAIN = (la L. (la TL. (la T.
  TL(la tl_empty. la tl_insert. la tl_remove. la tl_layout. la tl_nb. la tl_swap. la tl_resize. la tl_toggle. la tl_leaves. la tl_next. la tl_has. la tl_count. la tl_show.
  T(la t_new. la t_write. la t_flush. la t_key. la t_back. la t_kill. la t_submit. la t_prev. la t_next. la t_clear. la t_prompt. la t_rows. la t_keychar.
  LK_KIT(B)(L)(la s. s(0)(0)(0)(0)(0)(0)(0)(0))(1)(la s. s(0)(0)(0)(0))(la nodes. la measure. la paint. la a11y. la focusables. la key. la render.
  WM_CORE(B)(L)(X)(TL)(T)(SHSTUB)(WM_WINS(B)(L))
    (la s. s(key)(focusables)(SETTINGS_APP(B)(L)(nodes)(la init. la view. la update. la theme. la zoom. la s. s(init)(view)(update)(theme)("Settings")(zoom)))
       (la n. la s. s(la k. k(LOGIN_APP(B)(L)(nodes)(SESS))(la t. la f. f))))
    (la s. s(960)(600)(6)("/home"))
   (la empty. la open_win. la handle. la on_output. la job_fds. la shutdown. la welcome.
     (la snap.
        (la st. st(la tree. la focus. la wins. la nid. la mask. la quit. la dirty. la lock.
            print(concat("final: quit=")(quit("yes")("no")))))
        (WM_FOLD(B)(handle(snap))(read_file("events.bin"))(open_win(empty))))
     (la st. la n. st(la tree. la focus. la wins. la nid. la mask. la quit. la dirty. la lock.
        (la _. (la _. st)(Z(la each. la ws. ws(la _. "")(la w. la rest. w(la id. la term. la sh. la job. la bc. la tk. la tr. la ver. la app.
              (la _. (la _. each(rest))(app(la _. PRINTALL(t_rows(term)(40)(4)(job(la _. la t. la f. t)(la p. la r. la c. la t. la f. f))))
                                          (la a. a(la lkapp. la ast. la afocus. lkapp(la i. la v. la u. la th. la ttl. la z.
                                             (la _. PRINTALL(a11y(v(ast))(afocus)))(print(concat("    theme ")(th(ast)("dark")("light")))))))))
              (print(concat("  window ")(concat(int_to_str(id))(concat(" ver ")(int_to_str(ver)))))))))(wins)))
        ((la _. lock(la _. print("snap: no lock screen"))(la l. l(la login. la lw. la showing.
           showing(la _. lw(la id. la term. la sh. la job. la bc. la tk. la tr. la ver. la app.
                      app(la _. "")(la a. a(la lkapp. la ast. la af. lkapp(la i. la v. la u. la th. la ttl. la z.
                         (la _. PRINTALL(a11y(v(ast))(af)))(print(concat("  LOCKED, focus ")(af))))))))
                  (la _. "")("!"))))
        (print(concat("snap ")(concat(int_to_str(n))(concat(": tree ")(concat(tl_show(tree))(concat(" focus ")(int_to_str(focus))))))))))))))))
  (TERM_KIT(str_at)(ord)(str_to_int)(str_len)(chr)(concat)(str_eq)(add)(sub)(mul)(div)(mod)(lt)(int_eq)))
  (TILE_KIT(add)(sub)(mul)(div)(lt)(int_eq)(concat)(int_to_str)))(WM_LISTS(B))
LAEOF
EXPECT='wm: open window 1
snap 1: tree L1 focus 1
  window 1 ver 0
    ||
    ||
    ||
    |logos:/home$ |
wm: [1] $ echo hi
snap 2: tree L1 focus 1
  window 1 ver 8
    ||
    |logos:/home$ echo hi|
    |hi|
    |logos:/home$ |
wm: open window 2
wm: [2] $ cd /tmp
wm: [2] $ pwd
snap 3: tree H500(L1,L2) focus 2
  window 2 ver 12
    |logos:/home$ cd /tmp|
    |logos:/tmp$ pwd|
    |stub: pwd|
    |logos:/tmp$ |
  window 1 ver 8
    ||
    |logos:/home$ echo hi|
    |hi|
    |logos:/home$ |
snap 4: tree H500(L1,L2) focus 1
  window 2 ver 12
    |logos:/home$ cd /tmp|
    |logos:/tmp$ pwd|
    |stub: pwd|
    |logos:/tmp$ |
  window 1 ver 8
    ||
    |logos:/home$ echo hi|
    |hi|
    |logos:/home$ |
snap 5: tree H500(L2,L1) focus 1
  window 2 ver 12
    |logos:/home$ cd /tmp|
    |logos:/tmp$ pwd|
    |stub: pwd|
    |logos:/tmp$ |
  window 1 ver 8
    ||
    |logos:/home$ echo hi|
    |hi|
    |logos:/home$ |
snap 6: tree V500(L2,L1) focus 1
  window 2 ver 12
    |logos:/home$ cd /tmp|
    |logos:/tmp$ pwd|
    |stub: pwd|
    |logos:/tmp$ |
  window 1 ver 8
    ||
    |logos:/home$ echo hi|
    |hi|
    |logos:/home$ |
wm: close window 1
snap 7: tree L2 focus 2
  window 2 ver 12
    |logos:/home$ cd /tmp|
    |logos:/tmp$ pwd|
    |stub: pwd|
    |logos:/tmp$ |
wm: [2] $ exit
wm: close window 2
snap 8: tree E focus 0
wm: open window 3
snap 9: tree L3 focus 3
  window 3 ver 0
    ||
    ||
    ||
    |logos:/home$ |
wm: open window 4 (Settings)
snap 10: tree H500(L3,L4) focus 4
  window 4 ver 0
    theme light
    |panel LogosKit settings|
    |  text: This panel is drawn by LogosKit itself.|
    |  text field Name: sovereign, focused|
    |  check box Dark theme: not checked|
    |  list, item 1 of 2: Text scale 1|
    |  button Save|
    |  button Reset|
    |  text: Saved 0 times|
  window 3 ver 0
    ||
    ||
    ||
    |logos:/home$ |
snap 11: tree H500(L3,L4) focus 4
  window 4 ver 3
    theme dark
    |panel LogosKit settings|
    |  text: This panel is drawn by LogosKit itself.|
    |  text field Name: sovereignx|
    |  check box Dark theme: checked, focused|
    |  list, item 1 of 2: Text scale 1|
    |  button Save|
    |  button Reset|
    |  text: Saved 0 times|
  window 3 ver 0
    ||
    ||
    ||
    |logos:/home$ |
snap 12: tree H500(L3,L4) focus 4
  window 4 ver 7
    theme dark
    |panel LogosKit settings|
    |  text: This panel is drawn by LogosKit itself.|
    |  text field Name: sovereignx|
    |  check box Dark theme: checked|
    |  list, item 2 of 2: Text scale 2|
    |  button Save, focused|
    |  button Reset|
    |  text: Saved 1 time|
  window 3 ver 0
    ||
    ||
    ||
    |logos:/home$ |
wm: close window 4
snap 13: tree L3 focus 3
  window 3 ver 0
    ||
    ||
    ||
    |logos:/home$ |
wm: locked
snap 14: tree L3 focus 3
  LOCKED, focus user
    |panel LogOS|
    |  text: Log in to LogOS.|
    |  text field User: , focused|
    |  text field Passphrase: |
    |  button Log in|
    |  text: |
  window 3 ver 0
    ||
    ||
    ||
    |logos:/home$ |
wm: unlocked
snap 15: tree L3 focus 3
  window 3 ver 0
    ||
    ||
    ||
    |logos:/home$ |
wm: locked
snap 16: tree L3 focus 3
  LOCKED, focus pass
    |panel LogOS|
    |  text: Locked: adam|
    |  text field Passphrase: , focused|
    |  button Unlock|
    |  text: Wrong passphrase.|
  window 3 ver 0
    ||
    ||
    ||
    |logos:/home$ |
wm: unlocked
snap 17: tree L3 focus 3
  window 3 ver 0
    ||
    ||
    ||
    |logos:/home$ |
wm: locked
snap 18: tree L3 focus 3
  LOCKED, focus pass
    |panel LogOS|
    |  text: Locked: adam|
    |  text field Passphrase: , focused|
    |  button Unlock|
    |  text: Locked.|
  window 3 ver 0
    ||
    ||
    ||
    |logos:/home$ |
wm: unlocked
wm: open window 5 (Settings)
snap 19: tree H500(L3,L5) focus 5
  window 5 ver 0
    theme light
    |panel LogosKit settings|
    |  text: This panel is drawn by LogosKit itself.|
    |  text field Name: sovereign, focused|
    |  check box Dark theme: not checked|
    |  list, item 1 of 2: Text scale 1|
    |  button Save|
    |  button Reset|
    |  text: Saved 0 times|
  window 3 ver 0
    ||
    ||
    ||
    |logos:/home$ |
wm: close window 5
final: quit=yes'
wm_vm core.la "$T/out.txt"
if [ "$vrc" = 0 ] && [ "$(cat "$T/out.txt")" = "$EXPECT" ]; then
    echo "PASS  wm core (VM): 19 snapshots of a session: windows, focus, swap, toggle, close, exit, the settings app, lock and unlock, Ctrl/MOD keys ignored by the lock screen and apps"
else
    echo "FAIL  wm core (VM): rc=$vrc"; diff <(echo "$EXPECT") "$T/out.txt" | head -30; tail -3 "$T/vce" "$T/vre" 2>/dev/null; ok=0
fi
[ "$ok" = 1 ] || exit 1
