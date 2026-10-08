#!/usr/bin/env bash
# gate_logoskit.sh — LogosKit (logoskit.la), the UI framework: layout, the
# accessible description, focus and keys, on the native VM.
#
# WHAT IT GUARDS. A LogosKit view is an element tree generated from state, and
# three things are derived from that one tree: the painted cells, the
# accessible description, and what each key does. This gate builds a settings
# panel (a text, a field, a check box, a two-item list and two buttons in a
# row, inside a panel) and checks, against answers derived by hand from the
# layout rules in logoskit.la's header:
#   - measure: 24 x 8 cells;
#   - paint: every row's text AND its per-cell style (0 normal, 1 focused,
#     2 title, 3 dim; '.' is a cell no run covers) — the panel frame, the field
#     value drawn focused, the list's selected item dim because the list is not
#     focused;
#   - a11y: one line per element with its role, label, state and focus — so
#     an element cannot be on the screen without being described (the
#     Codex's accessibility invariant);
#   - focusables in tree order, Tab / Shift+Tab with wrap-around at both ends;
#   - the message each key makes: typing and Backspace in a field (edit),
#     Enter in a field (submit), Space on a check box (toggle to the NEW value),
#     Up/Down on a list clamped at both ends (select), Enter on a button (press).
# Rendering to pixels goes through theourgia_render.la and is checked by the
# WM's gates through OCR.
#
# ISOLATION: private temp dir (gate_wm_common.sh). About 1 minute.
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1
wm_setup logoskit.la theourgia_wm.la
cat > "$T/t.la" <<'LAEOF'
import("theourgia_wm.la")
import("logoskit.la")
glyph B = la s. s(str_at)(ord)(str_to_int)(int_to_str)(concat)(str_eq)(str_len)(add)(sub)(mul)(div)(mod)(lt)(int_eq)(band)(bor)
glyph RSTUB = la s. s(la r. la g. la b. "")(la n. la x. "")(la f. la b. "")(la st. la t. la c. WM_NIL)(la a. la b. la c. la d. "")(la w. la h. la p. WM_NIL)(la l. "")(la a. la b. la c. la d. la e. "")
glyph PAL = la s. s("n")("f")("t")("d")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph SEQ = la a. la b. b
# a row of runs -> "text|styles" at width w
glyph SHOWROW = la L. la w. la runs. L(la nil. la cons. la map. la filter. la find. la append. la nrep. la len.
  (Z(la go. la rs. la at. la txt. la sty.
     rs(la _. concat(txt)(concat(Z(la sp. la n. int_eq(n)(0)(la _. "")(la _. concat(" ")(sp(sub(n)(1))))("!"))(sub(w)(at)))
           (concat(" |")(sty))))
       (la r. la rest. r(la col. la text. la st.
          (la gap. (la tl.
             go(rest)(add(col)(tl))
               (concat(txt)(concat(Z(la sp. la n. int_eq(n)(0)(la _. "")(la _. concat(" ")(sp(sub(n)(1))))("!"))(gap))(text)))
               (concat(sty)(concat(Z(la sp. la n. int_eq(n)(0)(la _. "")(la _. concat(".")(sp(sub(n)(1))))("!"))(gap))
                  (Z(la sp. la n. int_eq(n)(0)(la _. "")(la _. concat(int_to_str(st))(sp(sub(n)(1))))("!"))(tl)))))
           (str_to_int(str_len(text))))(sub(col)(at))))))(runs)(0)("")(""))
glyph JOINL = Z(la self. la l. l(la _. "")(la h. la t. concat(h)(concat(" ")(self(t)))))
glyph PRINTALL = Z(la self. la l. l(la _. "")(la h. la t. SEQ(print(h))(self(t))))
glyph MAIN = (la L. LK_KIT(B)(L)(RSTUB)(1)(PAL)(la nodes. la measure. la paint. la a11y. la focusables. la key. la render.
  nodes(la TEXT. la BUTTON. la FIELD. la TOGGLE. la LIST. la ROW. la COL. la PANEL. la SPACE.
   L(la nil. la cons. la map. la filter. la find. la append. la nrep. la len.
    (la view. (la ui.
       measure(ui)(la w. la h.
         SEQ(print(concat("measure ")(concat(int_to_str(w))(concat("x")(int_to_str(h))))))(
         SEQ(PRINTALL(map(SHOWROW(L)(w))(paint(ui)("name"))))(
         SEQ(print("-- a11y, focus on name --"))(
         SEQ(PRINTALL(a11y(ui)("name")))(
         SEQ(print(concat("focusables: ")(JOINL(focusables(ui)))))(
         (la show. 
           SEQ(show("tab from name")(key(ui)("name")(15)(la t. la f. f)("")))(
           SEQ(show("shift-tab from name")(key(ui)("name")(15)(la t. la f. t)("")))(
           SEQ(show("shift-tab from dark")(key(ui)("dark")(15)(la t. la f. t)("")))(
           SEQ(show("tab from save")(key(ui)("save")(15)(la t. la f. f)("")))(
           SEQ(show("type x in name")(key(ui)("name")(45)(la t. la f. f)("x")))(
           SEQ(show("backspace in name")(key(ui)("name")(14)(la t. la f. f)("")))(
           SEQ(show("enter in name")(key(ui)("name")(28)(la t. la f. f)("")))(
           SEQ(show("space on dark")(key(ui)("dark")(57)(la t. la f. f)(" ")))(
           SEQ(show("down on scale")(key(ui)("scale")(108)(la t. la f. f)("")))(
           SEQ(show("down on scale at end")(key(view(1))("scale")(108)(la t. la f. f)("")))(
           SEQ(show("up on scale at 0")(key(ui)("scale")(103)(la t. la f. f)("")))(
               show("enter on save")(key(ui)("save")(28)(la t. la f. f)(""))))))))))))))
         (la label. la r. r(la f2. la m. print(concat(label)(concat(": focus=")(concat(f2)(concat(" msg=")
             (m(la _. "none")(la mm. mm(la id. la kind. la pay. concat(id)(concat("/")(concat(kind)(concat("/")(pay)))))))))))))
         )))))))
       (view(0)))
     (la sel. PANEL("LogosKit settings")(COL(cons(TEXT("Drawn by LogosKit."))(cons(FIELD("name")("Name")("alice"))
        (cons(TOGGLE("dark")("Dark theme")(la t. la f. t))(cons(LIST("scale")(cons("scale 1")(cons("scale 2")(nil)))(sel))
        (cons(ROW(cons(BUTTON("save")("Save"))(cons(BUTTON("reset")("Reset"))(nil))))(nil))))))))))))(WM_LISTS(B))
LAEOF
EXPECT='measure 24x8
+- LogosKit settings --+ |222222222222222222222222
| Drawn by LogosKit.   | |0.000000000000000000...0
| Name: [alice       ] | |0.00000011111111111111.0
| [x] Dark theme       | |0.00000000000000.......0
| > scale 1            | |0.333333333............0
|   scale 2            | |0.000000000............0
| [ Save ] [ Reset ]   | |0.00000000.000000000...0
+----------------------+ |000000000000000000000000
-- a11y, focus on name --
panel LogosKit settings
  text: Drawn by LogosKit.
  text field Name: alice, focused
  check box Dark theme: checked
  list, item 1 of 2: scale 1
  button Save
  button Reset
focusables: name dark scale save reset 
tab from name: focus=dark msg=none
shift-tab from name: focus=reset msg=none
shift-tab from dark: focus=name msg=none
tab from save: focus=reset msg=none
type x in name: focus=name msg=name/edit/alicex
backspace in name: focus=name msg=name/edit/alic
enter in name: focus=name msg=name/submit/alice
space on dark: focus=dark msg=dark/toggle/0
down on scale: focus=scale msg=scale/select/1
down on scale at end: focus=scale msg=scale/select/1
up on scale at 0: focus=scale msg=scale/select/0
enter on save: focus=save msg=save/press/'
wm_vm t.la "$T/out.txt"
if [ "$vrc" = 0 ] && [ "$(cat "$T/out.txt")" = "$EXPECT" ]; then
    echo "PASS  logoskit (VM): measure, paint (text and styles), a11y, focus order and every key's message are the expected ones"
else
    echo "FAIL  logoskit (VM): rc=$vrc"; diff <(echo "$EXPECT") "$T/out.txt" | head -20; tail -3 "$T/vce" "$T/vre" 2>/dev/null; ok=0
fi
[ "$ok" = 1 ] || exit 1
