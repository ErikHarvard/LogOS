#!/usr/bin/env bash
# gate_lk_login.sh — the login and lock screen (lk_login.la), a LogosKit app,
# on the native VM.
#
# WHAT IT GUARDS. The screen in front of LogosSession's login / lock / unlock.
# Keys go through LogosKit (key -> message), the app's update makes the next
# state, and the accessible description of each new view is checked against
# hand-derived answers. The session layer is a stub here (user adam,
# passphrase logos; a session is "S:<name>", a locked one "L:" before it), so
# this checks the screen, not the cryptography:
#   - first login: focus starts on User; a wrong passphrase is refused with a
#     note and the passphrase is cleared; the right one opens a session;
#   - lock keeps the name, drops the passphrase, asks only for the passphrase
#     (focus on it), and says "Locked.";
#   - while typing, the field and its description show one '*' per character;
#   - a wrong passphrase is refused again; logoz, Backspace, s unlocks, and the
#     session that comes back is the one the stub's unlock made from the
#     locked one (S:adam);
#   - the passphrase never appears in anything the screen draws or says;
#   - lock forgets a passphrase being typed before the first login too: after
#     adam, Tab, "logo", lock, then "s" and Enter must not log in (with the
#     passphrase kept, "logo" + "s" would).
#
# ISOLATION: private temp dir (gate_wm_common.sh). About 2 minutes.
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1
wm_setup logoskit.la theourgia_wm.la lk_login.la
cat > "$T/t.la" <<'LAEOF'
import("theourgia_wm.la")
import("logoskit.la")
import("lk_login.la")
glyph B = la s. s(str_at)(ord)(str_to_int)(int_to_str)(concat)(str_eq)(str_len)(add)(sub)(mul)(div)(mod)(lt)(int_eq)(band)(bor)
glyph RSTUB = la s. s(la r. la g. la b. "")(la n. la x. "")(la f. la b. "")(la st. la t. la c. WM_NIL)(la a. la b. la c. la d. "")(la w. la h. la p. WM_NIL)(la l. "")(la a. la b. la c. la d. la e. "")
glyph PAL = la s. s("n")("f")("t")("d")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph PRINTALL = Z(la self. la l. l(la _. "")(la h. la t. (la _. self(t))(print(h))))
# the session layer, stubbed: user adam, passphrase logos
glyph OK  = la x. la err. la ok. ok(x)
glyph ERR = la x. la err. la ok. err(x)
glyph SESS = la s. s
  (la name. la pass. str_eq(name)("adam")(la _. str_eq(pass)("logos")(la _. OK(concat("S:")(name)))(la _. ERR("no"))("!"))(la _. ERR("no"))("!"))
  (la sn. concat("L:")(sn))
  (la l. la pass. str_eq(pass)("logos")(la _. OK(str_tail(str_tail(l))))(la _. ERR("no"))("!"))
# a key press: code, shift, the character it types
glyph K = la code. la shift. la ch. la k. k(code)(shift)(ch)
glyph NOS = la t. la f. f
glyph TYPE = Z(la self. la s. str_eq(s)("")(la _. WM_NIL)(la _. WM_CONS(K(30)(NOS)(str_head(s)))(self(str_tail(s))))("!"))
glyph APPENDK = Z(la self. la a. la b. a(la _. b)(la h. la t. WM_CONS(h)(self(t)(b))))
glyph KEYS1 = APPENDK(TYPE("adam"))(WM_CONS(K(15)(NOS)(""))(APPENDK(TYPE("lugos"))(WM_CONS(K(28)(NOS)(""))(APPENDK(TYPE("logos"))(WM_CONS(K(28)(NOS)(""))(WM_NIL))))))
# locked: a wrong passphrase, then logoz, Backspace, s -> logos
glyph KEYS2 = APPENDK(TYPE("x"))(WM_CONS(K(28)(NOS)(""))(APPENDK(TYPE("logoz"))(WM_CONS(K(14)(NOS)(""))(APPENDK(TYPE("s"))(WM_CONS(K(28)(NOS)(""))(WM_NIL))))))
glyph MAIN = (la L. LK_KIT(B)(L)(RSTUB)(1)(PAL)(la nodes. la measure. la paint. la a11y. la focusables. la key. la render.
  LOGIN_APP(B)(L)(nodes)(SESS)(la init. la view. la update. la theme. la title. la done. la lock.
   L(la nil. la cons. la map. la filter. la find. la append. la nrep. la len.
    (la show. (la run.
      (la _. (la st1. (la _. (la st2. (la _. (la _. (la st3. (la _. st3(la n. la p. la ph. la no. ph(la _. print("phase fresh"))(la l. print(concat("phase locked ")(l)))(la x. print(concat("session ")(x)))))
                                                              (show("unlocked")(st3)("go")))
                                                     (run(KEYS2)(st2)("pass")))
                                            (show("typing log while locked")(run(TYPE("log"))(st2)("pass"))("pass")))
                                            (show("after lock")(st2)("pass")))
                                   (lock(st1)))
                          (show("logged in")(st1)("go")))
             (run(KEYS1)(init)("user")))
      (show("init")(init)("user")))
     # run(keys)(state)(focus) -> the final state, printing after each Enter
     (Z(la run. la keys. la st. la focus.
        keys(la _. st)
            (la kk. la rest. kk(la code. la shift. la ch.
               key(view(st))(focus)(code)(shift)(ch)(la focus2. la m.
                 (la st2. int_eq(code)(28)(la _. (la _. run(rest)(st2)(focus2))(show("enter")(st2)(focus2)))(la _. run(rest)(st2)(focus2))("!"))
                 (m(la _. st)(la mm. update(st)(mm)))))))))
    (la label. la st. la focus.
       (la _. (la _. st)(PRINTALL(a11y(view(st))(focus))))
       (print(concat("-- ")(concat(label)(concat(": done=")(concat(done(st)("yes")("no"))
          (concat(" focusables=")(Z(la j. la l. l(la _. "")(la h. la t. concat(h)(concat(",")(j(t)))))(focusables(view(st)))))))))))
   ))))(WM_LISTS(B))
LAEOF
EXPECT='-- init: done=no focusables=user,pass,go,
panel LogOS
  text: Log in to LogOS.
  text field User: , focused
  text field Passphrase: 
  button Log in
  text: 
-- enter: done=no focusables=user,pass,go,
panel LogOS
  text: Log in to LogOS.
  text field User: adam
  text field Passphrase: , focused
  button Log in
  text: Wrong user or passphrase.
-- enter: done=yes focusables=
panel LogOS
  text: Welcome, adam
-- logged in: done=yes focusables=
panel LogOS
  text: Welcome, adam
-- after lock: done=no focusables=pass,go,
panel LogOS
  text: Locked: adam
  text field Passphrase: , focused
  button Unlock
  text: Locked.
-- typing log while locked: done=no focusables=pass,go,
panel LogOS
  text: Locked: adam
  text field Passphrase: ***, focused
  button Unlock
  text: Locked.
-- enter: done=no focusables=pass,go,
panel LogOS
  text: Locked: adam
  text field Passphrase: , focused
  button Unlock
  text: Wrong passphrase.
-- enter: done=yes focusables=
panel LogOS
  text: Welcome, adam
-- unlocked: done=yes focusables=
panel LogOS
  text: Welcome, adam
session S:adam'
wm_vm t.la "$T/out.txt"
if [ "$vrc" = 0 ] && [ "$(cat "$T/out.txt")" = "$EXPECT" ]; then
    echo "PASS  lk_login (VM): login refused then accepted, lock, masked typing, unlock refused then accepted, the session handed back"
else
    echo "FAIL  lk_login (VM): rc=$vrc"; diff <(echo "$EXPECT") "$T/out.txt" | head -20; tail -3 "$T/vce" "$T/vre" 2>/dev/null; ok=0
fi
if [ "$vrc" = 0 ] && ! grep -qE 'logos|lugos|logoz|Passphrase: [^*,]' "$T/out.txt"; then
    echo "PASS  lk_login (VM): no passphrase typed in the session appears in what the screen draws or says"
else
    echo "FAIL  lk_login (VM): a passphrase appears in the screen's description"; grep -nE 'logos|lugos|logoz' "$T/out.txt" | head -5; ok=0
fi

# lock in the fresh phase, with a passphrase half typed
{ sed -n '1,/^glyph APPENDK/p' "$T/t.la"; cat <<'LAEOF'
glyph KEYS3 = APPENDK(TYPE("adam"))(WM_CONS(K(15)(NOS)(""))(TYPE("logo")))
glyph KEYS4 = APPENDK(TYPE("s"))(WM_CONS(K(28)(NOS)(""))(WM_NIL))
glyph MAIN = (la L. LK_KIT(B)(L)(RSTUB)(1)(PAL)(la nodes. la measure. la paint. la a11y. la focusables. la key. la render.
  LOGIN_APP(B)(L)(nodes)(SESS)(la init. la view. la update. la theme. la title. la done. la lock.
    (la show. (la run.
      (la st1. (la _. (la st2. (la _. (la st3. show("after s, Enter")(st3)("pass"))(run(KEYS4)(st2)("pass")))
                                 (show("after lock")(st2)("pass")))
                       (lock(st1)))
               (show("typed")(st1)("pass")))
      (run(KEYS3)(init)("user")))
     (Z(la run. la keys. la st. la focus.
        keys(la _. st)
            (la kk. la rest. kk(la code. la shift. la ch.
               key(view(st))(focus)(code)(shift)(ch)(la focus2. la m.
                 (la st2. run(rest)(st2)(focus2))
                 (m(la _. st)(la mm. update(st)(mm)))))))))
    (la label. la st. la focus.
       (la _. (la _. st)(PRINTALL(a11y(view(st))(focus))))
       (print(concat("-- ")(concat(label)(concat(": done=")(done(st)("yes")("no"))))))))))(WM_LISTS(B))
LAEOF
} > "$T/t2.la"
wm_vm t2.la "$T/out2.txt"
after_lock=$(sed -n '/^-- after lock/,/^-- /p' "$T/out2.txt")
if [ "$vrc" = 0 ] && grep -q 'Passphrase: \*\*\*\*, focused' "$T/out2.txt" \
   && echo "$after_lock" | grep -q 'text field Passphrase: , focused' \
   && grep -qx -- '-- after s, Enter: done=no' "$T/out2.txt" && ! grep -q 'Welcome' "$T/out2.txt"; then
    echo "PASS  lk_login (VM): lock before the first login forgets the half-typed passphrase (logo, lock, s + Enter stays out)"
else
    echo "FAIL  lk_login (VM): lock before the first login: rc=$vrc"; head -30 "$T/out2.txt"; tail -3 "$T/vce" "$T/vre" 2>/dev/null; ok=0
fi
[ "$ok" = 1 ] || exit 1
