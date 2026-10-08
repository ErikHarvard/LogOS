#!/usr/bin/env python3
"""wm_script.py - turn a readable session script into evdev records.

The headless window manager (theourgia_wm_sim.la) reads its "keyboard" from a
file of 24-byte Linux input_event records, exactly what a real /dev/input/eventN
delivers: a 16-byte timeval (zero here), then type (u16), code (u16) and value
(s32), little-endian. This script writes such a file from a script of lines:

    type <text>        type the text; \\n is Enter, \\t Tab, \\\\ a backslash;
                       uppercase and shifted symbols get LEFTSHIFT around them
    key <NAME>         press and release one key: ENTER BACKSPACE TAB ESC UP
                       DOWN LEFT RIGHT, or a letter/digit name (A, 7, MINUS ...)
    ctrl <NAME>        the key with LEFTCTRL held
    mod <NAME>         the key with LEFTMETA (Super) held; "mod Shift+E" holds
                       LEFTSHIFT too
    snap <N>           ask the simulator to write frame N (type 85, code N)
    # comment          ignored, as are blank lines

Usage: wm_script.py SCRIPT OUT.bin   (SCRIPT may be - for stdin)

The US layout below must agree with theourgia_term.la's keychar; the WM gates
check that end to end (typed text appears on the screen).
"""
import struct
import sys

EV_SYN, EV_KEY, EV_SNAP = 0, 1, 85

# key code -> (unshifted, shifted), US layout, evdev codes
ROWS = {
    2: "1!", 3: "2@", 4: "3#", 5: "4$", 6: "5%", 7: "6^", 8: "7&", 9: "8*",
    10: "9(", 11: "0)", 12: "-_", 13: "=+",
    16: "qQ", 17: "wW", 18: "eE", 19: "rR", 20: "tT", 21: "yY", 22: "uU",
    23: "iI", 24: "oO", 25: "pP", 26: "[{", 27: "]}",
    30: "aA", 31: "sS", 32: "dD", 33: "fF", 34: "gG", 35: "hH", 36: "jJ",
    37: "kK", 38: "lL", 39: ";:", 40: "'\"", 41: "`~", 43: "\\|",
    44: "zZ", 45: "xX", 46: "cC", 47: "vV", 48: "bB", 49: "nN", 50: "mM",
    51: ",<", 52: ".>", 53: "/?", 57: "  ",
}
CHAR = {}
for code, pair in ROWS.items():
    CHAR.setdefault(pair[0], (code, False))
    CHAR.setdefault(pair[1], (code, pair[1] != pair[0]))

NAMED = {"ENTER": 28, "BACKSPACE": 14, "TAB": 15, "ESC": 1, "UP": 103,
         "DOWN": 108, "LEFT": 105, "RIGHT": 106, "MINUS": 12, "EQUAL": 13,
         "SPACE": 57}
LEFTSHIFT, LEFTCTRL, LEFTMETA = 42, 29, 125


def rec(typ, code, value):
    return b"\0" * 16 + struct.pack("<HHi", typ, code, value)


def tap(code):
    return rec(EV_KEY, code, 1) + rec(EV_SYN, 0, 0) + rec(EV_KEY, code, 0) + rec(EV_SYN, 0, 0)


def held(mods, code):
    out = b"".join(rec(EV_KEY, m, 1) for m in mods)
    out += tap(code)
    out += b"".join(rec(EV_KEY, m, 0) for m in reversed(mods))
    return out


def keycode(name):
    up = name.upper()
    if up in NAMED:
        return NAMED[up]
    if len(name) == 1 and name.lower() in CHAR:
        return CHAR[name.lower()][0]
    raise SystemExit(f"wm_script: unknown key {name!r}")


def unescape(text):
    out, i = [], 0
    while i < len(text):
        if text[i] == "\\" and i + 1 < len(text):
            out.append({"n": "\n", "t": "\t", "\\": "\\"}.get(text[i + 1], text[i + 1]))
            i += 2
        else:
            out.append(text[i])
            i += 1
    return "".join(out)


def compile_script(lines):
    out = b""
    for n, raw in enumerate(lines, 1):
        line = raw.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        cmd, _, arg = line.partition(" ")
        if cmd == "type":
            for ch in unescape(arg):
                if ch == "\n":
                    out += tap(NAMED["ENTER"])
                elif ch == "\t":
                    out += tap(NAMED["TAB"])
                elif ch in CHAR:
                    code, shift = CHAR[ch]
                    out += held([LEFTSHIFT], code) if shift else tap(code)
                else:
                    raise SystemExit(f"wm_script: line {n}: cannot type {ch!r}")
        elif cmd == "key":
            out += tap(keycode(arg.strip()))
        elif cmd == "ctrl":
            out += held([LEFTCTRL], keycode(arg.strip()))
        elif cmd == "mod":
            mods, name = [LEFTMETA], arg.strip()
            if name.lower().startswith("shift+"):
                mods, name = [LEFTMETA, LEFTSHIFT], name[6:]
            out += held(mods, keycode(name))
        elif cmd == "snap":
            out += rec(EV_SNAP, int(arg), 0)
        else:
            raise SystemExit(f"wm_script: line {n}: unknown command {cmd!r}")
    return out


def main(argv):
    if len(argv) != 3:
        raise SystemExit(__doc__)
    src = sys.stdin if argv[1] == "-" else open(argv[1])
    data = compile_script(src.readlines())
    with open(argv[2], "wb") as f:
        f.write(data)


if __name__ == "__main__":
    main(sys.argv)
