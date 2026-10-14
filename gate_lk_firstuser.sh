#!/usr/bin/env bash
# gate_lk_firstuser.sh — the first-run screen (lk_firstuser.la), a LogosKit
# app, on the native VM.
#
# WHAT IT GUARDS. On a first run the live WM starts at this screen: Name,
# Passphrase, Passphrase again and a button. It makes the first user with
# LogosSession's adduser and logs in, and from then on it IS the login screen
# (lk_login.la's state), so locking shows the ordinary login screen. Keys go
# through LogosKit (key -> message) and the app's update; the accessible
# description of each new view is checked against hand-derived answers. The
# session layer is a stub (adduser refuses eve.x as a bad name and taken as
# existing and prints the name and the passphrase's LENGTH it was given;
# login accepts s3cret-one, and fails for nologin as a clock error would; a
# session is "S:<name>", a locked one "L:" before it):
#   1  a whole first run: Enter moves Name -> Passphrase -> Passphrase again
#      and submits from the last field; refused, each with its note, keeping
#      the name and forgetting both passphrases: an empty name, mismatched
#      passphrases, empty passphrases (from the field and from the button), a
#      name adduser refuses (its own reason); then the right input calls
#      adduser and login once each and the user is in; lock shows the
#      ordinary login screen with the name kept, a wrong passphrase is
#      refused and the right one unlocks
#   2  no passphrase typed appears in anything the screen draws or says (one
#      '*' per character)
#   3  not a first run: the app starts as the ordinary login screen (the same
#      description as LOGIN_APP's) and logs in through it
#   4  lock during the setup forgets the half-typed passphrases, keeps the
#      name, and lets nobody in
#   5  adduser refusing an existing name is shown with its reason; a login
#      that fails after adduser made the user shows the login screen with
#      the name and the reason
#
# ISOLATION: private temp dir (gate_wm_common.sh). A few minutes.
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1
wm_setup logoskit.la theourgia_wm.la lk_login.la lk_firstuser.la
cat > "$T/t.la" <<'LAEOF'
import("theourgia_wm.la")
import("logoskit.la")
import("lk_firstuser.la")
glyph B = la s. s(str_at)(ord)(str_to_int)(int_to_str)(concat)(str_eq)(str_len)(add)(sub)(mul)(div)(mod)(lt)(int_eq)(band)(bor)
glyph RSTUB = la s. s(la r. la g. la b. "")(la n. la x. "")(la f. la b. "")(la st. la t. la c. WM_NIL)(la a. la b. la c. la d. "")(la w. la h. la p. WM_NIL)(la l. "")(la a. la b. la c. la d. la e. "")
glyph PAL = la s. s("n")("f")("t")("d")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph PRINTALL = Z(la self. la l. l(la _. "")(la h. la t. (la _. self(t))(print(h))))
glyph OK  = la x. la err. la ok. ok(x)
glyph ERR = la x. la err. la ok. err(x)
glyph TELL = la what. la name. la pass. print(concat(what)(concat(" ")(concat(name)(concat(" ")(str_len(pass))))))
# the session layer, stubbed
glyph ADDUSER = la name. la pass. (la _.
    str_eq(name)("eve.x")(la _. ERR("adduser: bad name"))(la _.
    str_eq(name)("taken")(la _. ERR("adduser: the user exists"))(la _. OK(name))("!"))("!"))
  (TELL("adduser")(name)(pass))
glyph SESS = la s. s
  (la name. la pass. (la _. str_eq(name)("nologin")(la _. ERR("login: no clock"))
      (la _. str_eq(pass)("s3cret-one")(la _. OK(concat("S:")(name)))(la _. ERR("no"))("!"))("!"))(TELL("login")(name)(pass)))
  (la sn. concat("L:")(sn))
  (la l. la pass. str_eq(pass)("s3cret-one")(la _. OK(str_tail(str_tail(l))))(la _. ERR("no"))("!"))
glyph FIRST = la s. s(la t. la f. t)(ADDUSER)(SESS)
glyph NOTFIRST = la s. s(la t. la f. f)(ADDUSER)(SESS)
# a key press: code, shift, the character it types
glyph K = la code. la shift. la ch. la k. k(code)(shift)(ch)
glyph NOS = la t. la f. f
glyph ENTER = WM_CONS(K(28)(NOS)(""))(WM_NIL)
glyph TAB = WM_CONS(K(15)(NOS)(""))(WM_NIL)
glyph BS = WM_CONS(K(14)(NOS)(""))(WM_NIL)
glyph TYPE = Z(la self. la s. str_eq(s)("")(la _. WM_NIL)(la _. WM_CONS(K(30)(NOS)(str_head(s)))(self(str_tail(s))))("!"))
glyph APPENDK = Z(la self. la a. la b. a(la _. b)(la h. la t. WM_CONS(h)(self(t)(b))))
glyph SEQK = Z(la self. la ls. ls(la _. WM_NIL)(la h. la t. APPENDK(h)(self(t))))
glyph KL = la a. la rest. WM_CONS(a)(rest)
LAEOF
# the driver: run(keys)(state)(focus)(k), printing the description after every
# Enter, then k(state)(focus)
cat > "$T/driver.la" <<'LAEOF'
glyph MAIN = (la L. LK_KIT(B)(L)(RSTUB)(1)(PAL)(la nodes. la measure. la paint. la a11y. la focusables. la key. la render.
  FIRSTUSER_APP(B)(L)(nodes)(SESSREC)(la init. la view. la update. la theme. la title. la done. la lock.
    (la show. (la run. (la _. BODY(show)(run)(init)(lock)(view))(print(concat("title ")(concat(title)(theme(init)(", dark")(", light"))))))
     (Z(la run. la keys. la st. la focus. la k.
        keys(la _. k(st)(focus))
            (la kk. la rest. kk(la code. la shift. la ch.
               key(view(st))(focus)(code)(shift)(ch)(la focus2. la m.
                 (la st2. int_eq(code)(28)(la _. (la _. run(rest)(st2)(focus2)(k))(show("enter")(st2)(focus2)))
                                         (la _. run(rest)(st2)(focus2)(k))("!"))
                 (m(la _. st)(la mm. update(st)(mm)))))))))
    (la label. la st. la focus.
       (la _. (la _. st)(PRINTALL(a11y(view(st))(focus))))
       (print(concat("-- ")(concat(label)(concat(": done=")(concat(done(st)("yes")("no"))
          (concat(" focus=")(focus)))))))))))(WM_LISTS(B))
LAEOF
# 1 a whole first run
{ cat "$T/t.la"; cat <<'LAEOF'
glyph SESSREC = FIRST
glyph KEYS1 = SEQK(KL(ENTER)(KL(TYPE("s3cret-one"))(KL(ENTER)(KL(TYPE("s3cret-one"))(KL(ENTER)(WM_NIL))))))
glyph KEYS2 = SEQK(KL(TAB)(KL(TAB)(KL(TYPE("adam"))(KL(ENTER)(KL(TYPE("s3cret-one"))(KL(ENTER)(KL(TYPE("s3cret-two"))(KL(ENTER)(WM_NIL)))))))))
glyph KEYS3 = SEQK(KL(ENTER)(KL(TAB)(KL(ENTER)(WM_NIL))))
glyph KEYS4 = SEQK(KL(TAB)(KL(BS)(KL(BS)(KL(BS)(KL(BS)(KL(TYPE("eve.x"))(KL(ENTER)(KL(TYPE("s3cret-one"))(KL(ENTER)(KL(TYPE("s3cret-one"))(KL(ENTER)(WM_NIL))))))))))))
glyph KEYS5 = SEQK(KL(TAB)(KL(TAB)(KL(BS)(KL(BS)(KL(BS)(KL(BS)(KL(BS)(KL(TYPE("adam"))(KL(ENTER)(KL(TYPE("s3cret-one"))(KL(ENTER)(KL(TYPE("s3cret-one"))(KL(ENTER)(WM_NIL))))))))))))))
glyph KEYS6 = SEQK(KL(TYPE("nope-nope"))(KL(ENTER)(KL(TYPE("s3cret-one"))(KL(ENTER)(WM_NIL)))))
glyph BODY = la show. la run. la init. la lock. la view.
  (la _. run(KEYS1)(init)("name")(la s1. la f1. run(KEYS2)(s1)(f1)(la s2. la f2. run(KEYS3)(s2)(f2)(la s3. la f3.
         run(KEYS4)(s3)(f3)(la s4. la f4. run(KEYS5)(s4)(f4)(la s5. la f5.
         (la l5. (la _. run(KEYS6)(l5)("pass")(la s6. la f6. show("unlocked")(s6)(f6)))(show("after lock")(l5)("pass")))
         (lock(s5))))))))
  (show("init")(init)("name"))
LAEOF
cat "$T/driver.la"; } > "$T/t1.la"
EXPECT1='title Log in, dark
-- init: done=no focus=name
panel LogOS
  text: Welcome. Make the first user.
  text field Name: , focused
  text field Passphrase: 
  text field Passphrase again: 
  button Make the user
  text: 
-- enter: done=no focus=pass
panel LogOS
  text: Welcome. Make the first user.
  text field Name: 
  text field Passphrase: , focused
  text field Passphrase again: 
  button Make the user
  text: 
-- enter: done=no focus=again
panel LogOS
  text: Welcome. Make the first user.
  text field Name: 
  text field Passphrase: **********
  text field Passphrase again: , focused
  button Make the user
  text: 
-- enter: done=no focus=again
panel LogOS
  text: Welcome. Make the first user.
  text field Name: 
  text field Passphrase: 
  text field Passphrase again: , focused
  button Make the user
  text: Enter a name.
-- enter: done=no focus=pass
panel LogOS
  text: Welcome. Make the first user.
  text field Name: adam
  text field Passphrase: , focused
  text field Passphrase again: 
  button Make the user
  text: Enter a name.
-- enter: done=no focus=again
panel LogOS
  text: Welcome. Make the first user.
  text field Name: adam
  text field Passphrase: **********
  text field Passphrase again: , focused
  button Make the user
  text: Enter a name.
-- enter: done=no focus=again
panel LogOS
  text: Welcome. Make the first user.
  text field Name: adam
  text field Passphrase: 
  text field Passphrase again: , focused
  button Make the user
  text: The passphrases differ.
-- enter: done=no focus=again
panel LogOS
  text: Welcome. Make the first user.
  text field Name: adam
  text field Passphrase: 
  text field Passphrase again: , focused
  button Make the user
  text: Enter a passphrase.
-- enter: done=no focus=make
panel LogOS
  text: Welcome. Make the first user.
  text field Name: adam
  text field Passphrase: 
  text field Passphrase again: 
  button Make the user, focused
  text: Enter a passphrase.
-- enter: done=no focus=pass
panel LogOS
  text: Welcome. Make the first user.
  text field Name: eve.x
  text field Passphrase: , focused
  text field Passphrase again: 
  button Make the user
  text: Enter a passphrase.
-- enter: done=no focus=again
panel LogOS
  text: Welcome. Make the first user.
  text field Name: eve.x
  text field Passphrase: **********
  text field Passphrase again: , focused
  button Make the user
  text: Enter a passphrase.
adduser eve.x 10
-- enter: done=no focus=again
panel LogOS
  text: Welcome. Make the first user.
  text field Name: eve.x
  text field Passphrase: 
  text field Passphrase again: , focused
  button Make the user
  text: adduser: bad name
-- enter: done=no focus=pass
panel LogOS
  text: Welcome. Make the first user.
  text field Name: adam
  text field Passphrase: , focused
  text field Passphrase again: 
  button Make the user
  text: adduser: bad name
-- enter: done=no focus=again
panel LogOS
  text: Welcome. Make the first user.
  text field Name: adam
  text field Passphrase: **********
  text field Passphrase again: , focused
  button Make the user
  text: adduser: bad name
adduser adam 10
login adam 10
-- enter: done=yes focus=again
panel LogOS
  text: Welcome, adam
-- after lock: done=no focus=pass
panel LogOS
  text: Locked: adam
  text field Passphrase: , focused
  button Unlock
  text: Locked.
-- enter: done=no focus=pass
panel LogOS
  text: Locked: adam
  text field Passphrase: , focused
  button Unlock
  text: Wrong passphrase.
-- enter: done=yes focus=pass
panel LogOS
  text: Welcome, adam
-- unlocked: done=yes focus=pass
panel LogOS
  text: Welcome, adam'
wm_vm t1.la "$T/out1.txt"
if [ "$vrc" = 0 ] && [ "$(cat "$T/out1.txt")" = "$EXPECT1" ]; then
    echo "PASS  lk_firstuser (VM): 1 a first run: Enter moves field to field; an empty name, mismatched and empty passphrases and a bad name refused, the name kept, both passphrases forgotten; adduser then login; lock shows the ordinary login screen, wrong refused, right unlocks"
else
    echo "FAIL  lk_firstuser (VM): 1 a first run: rc=$vrc"; diff <(echo "$EXPECT1") "$T/out1.txt" | head -30; tail -3 "$T/vce" "$T/vre" 2>/dev/null; ok=0
fi
if [ "$vrc" = 0 ] && [ -s "$T/out1.txt" ] && ! grep -qE 's3cret|nope-nope|Passphrase( again)?: [^*,]' "$T/out1.txt"; then
    echo "PASS  lk_firstuser (VM): 2 no passphrase typed appears in what the screen draws or says"
else
    echo "FAIL  lk_firstuser (VM): 2 a passphrase appears in the screen's description"; grep -nE 's3cret|nope-nope|Passphrase( again)?: [^*,]' "$T/out1.txt" | head -5; ok=0
fi

# 3 not a first run: the ordinary login screen
{ cat "$T/t.la"; cat <<'LAEOF'
glyph SESSREC = NOTFIRST
glyph KEYS1 = SEQK(KL(TYPE("adam"))(KL(ENTER)(KL(TYPE("s3cret-one"))(KL(ENTER)(WM_NIL)))))
glyph BODY = la show. la run. la init. la lock. la view.
  (la _. run(KEYS1)(init)("user")(la s1. la f1. s1))
  (show("init")(init)("user"))
LAEOF
cat "$T/driver.la"; } > "$T/t3.la"
EXPECT3='title Log in, dark
-- init: done=no focus=user
panel LogOS
  text: Log in to LogOS.
  text field User: , focused
  text field Passphrase: 
  button Log in
  text: 
-- enter: done=no focus=pass
panel LogOS
  text: Log in to LogOS.
  text field User: adam
  text field Passphrase: , focused
  button Log in
  text: 
login adam 10
-- enter: done=yes focus=pass
panel LogOS
  text: Welcome, adam'
wm_vm t3.la "$T/out3.txt"
if [ "$vrc" = 0 ] && [ "$(cat "$T/out3.txt")" = "$EXPECT3" ]; then
    echo "PASS  lk_firstuser (VM): 3 not a first run: it starts as the ordinary login screen and logs in through it"
else
    echo "FAIL  lk_firstuser (VM): 3 not a first run: rc=$vrc"; diff <(echo "$EXPECT3") "$T/out3.txt" | head -20; tail -3 "$T/vce" "$T/vre" 2>/dev/null; ok=0
fi

# 4 lock during the setup
{ cat "$T/t.la"; cat <<'LAEOF'
glyph SESSREC = FIRST
glyph KEYS1 = SEQK(KL(TYPE("adam"))(KL(ENTER)(KL(TYPE("s3cr"))(KL(ENTER)(KL(TYPE("s3"))(WM_NIL))))))
glyph KEYS2 = SEQK(KL(TYPE("cret-one"))(KL(ENTER)(WM_NIL)))
glyph BODY = la show. la run. la init. la lock. la view.
  run(KEYS1)(init)("name")(la s1. la f1. (la l1. (la _. run(KEYS2)(l1)(f1)(la s2. la f2. s2))(show("after lock")(l1)(f1)))(lock(s1)))
LAEOF
cat "$T/driver.la"; } > "$T/t4.la"
EXPECT4='title Log in, dark
-- enter: done=no focus=pass
panel LogOS
  text: Welcome. Make the first user.
  text field Name: adam
  text field Passphrase: , focused
  text field Passphrase again: 
  button Make the user
  text: 
-- enter: done=no focus=again
panel LogOS
  text: Welcome. Make the first user.
  text field Name: adam
  text field Passphrase: ****
  text field Passphrase again: , focused
  button Make the user
  text: 
-- after lock: done=no focus=again
panel LogOS
  text: Welcome. Make the first user.
  text field Name: adam
  text field Passphrase: 
  text field Passphrase again: , focused
  button Make the user
  text: 
-- enter: done=no focus=again
panel LogOS
  text: Welcome. Make the first user.
  text field Name: adam
  text field Passphrase: 
  text field Passphrase again: , focused
  button Make the user
  text: The passphrases differ.'
wm_vm t4.la "$T/out4.txt"
if [ "$vrc" = 0 ] && [ "$(cat "$T/out4.txt")" = "$EXPECT4" ]; then
    echo "PASS  lk_firstuser (VM): 4 lock during the setup forgets both half-typed passphrases and keeps the name (s3cr / s3, lock, cret-one + Enter makes no user)"
else
    echo "FAIL  lk_firstuser (VM): 4 lock during the setup: rc=$vrc"; diff <(echo "$EXPECT4") "$T/out4.txt" | head -20; tail -3 "$T/vce" "$T/vre" 2>/dev/null; ok=0
fi

# 5 adduser's other refusals, and a login that fails after adduser
{ cat "$T/t.la"; cat <<'LAEOF'
glyph SESSREC = FIRST
glyph KEYS1 = SEQK(KL(TYPE("taken"))(KL(ENTER)(KL(TYPE("s3cret-one"))(KL(ENTER)(KL(TYPE("s3cret-one"))(KL(ENTER)(WM_NIL)))))))
glyph KEYS2 = SEQK(KL(TAB)(KL(TAB)(KL(BS)(KL(BS)(KL(BS)(KL(BS)(KL(BS)(KL(TYPE("nologin"))(KL(ENTER)(KL(TYPE("s3cret-one"))(KL(ENTER)(KL(TYPE("s3cret-one"))(KL(ENTER)(WM_NIL))))))))))))))
glyph BODY = la show. la run. la init. la lock. la view.
  run(KEYS1)(init)("name")(la s1. la f1. run(KEYS2)(s1)(f1)(la s2. la f2. s2))
LAEOF
cat "$T/driver.la"; } > "$T/t5.la"
wm_vm t5.la "$T/out5.txt"
taken=$(sed -n '/^adduser taken 10$/,/^-- /{/^  text: adduser/p}' "$T/out5.txt")
nolog=$(sed -n '/^login nologin 10$/,$p' "$T/out5.txt")
NOLOG='login nologin 10
-- enter: done=no focus=again
panel LogOS
  text: Log in to LogOS.
  text field User: nologin
  text field Passphrase: 
  button Log in
  text: login: no clock'
if [ "$vrc" = 0 ] && grep -qx 'adduser taken 10' "$T/out5.txt" && grep -qx '  text: adduser: the user exists' "$T/out5.txt" \
   && [ "$nolog" = "$NOLOG" ] && grep -qx 'adduser nologin 10' "$T/out5.txt"; then
    echo "PASS  lk_firstuser (VM): 5 adduser's refusal of an existing name shown with its reason; a login failing after adduser shows the login screen with the name and the reason"
else
    echo "FAIL  lk_firstuser (VM): 5 rc=$vrc taken='$taken'"; tail -12 "$T/out5.txt"; tail -3 "$T/vce" "$T/vre" 2>/dev/null; ok=0
fi
if [ "$ok" = 1 ]; then echo "ALL PASS  gate_lk_firstuser"; else echo "GATE FAILED  gate_lk_firstuser"; exit 1; fi
