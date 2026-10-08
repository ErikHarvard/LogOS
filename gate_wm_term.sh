#!/usr/bin/env bash
# gate_wm_term.sh — the terminal model (theourgia_term.la) against an
# independent reference model, on the native VM and the C host.
#
# WHAT IT GUARDS. TERM_KIT turns a program's output bytes into lines, edits the
# input line, keeps history, soft-wraps the display and maps evdev key codes to
# characters. A slip in any of these shows up only as a subtly wrong screen,
# so every operation is checked against known answers:
#
#   THE ORACLE. A Python model of the terminal, written from the table in
#   WM_DESIGN.md (one byte at a time, the obvious way: Python strings, no
#   segments, no lazy trim), runs the same scripts and says what each must
#   print. The gate generates LA programs from those scripts (each step
#   threads the terminal value; observations print one display row per line
#   as [row], submit prints S:<line>), runs them, and compares byte for byte.
#   The rest of a script is always in tail position, (la t. rest)(step) and
#   (la _. rest)(observation), never an argument, so the C host runs a long
#   script in bounded memory.
#
#   1. write: every rule of the byte table (printable 32..126; \n; \r; \t at
#      columns 0,1,3,7,8,15,60,63,64,70 and after a tab; \b at line start and
#      across the partial line's 64-byte segment edges; CSI whole, with
#      intermediates, with finals 0x40 and 0x7E, split across writes, cut
#      right after ESC and after ESC [, swallowing bytes >= 0x80 and \n; ESC +
#      one byte; UTF-8 2/3/4-byte characters, stray continuation bytes, leads
#      0xC0/0xDF/0xFF; C0 controls and 127 ignored), long partial lines, and
#      flush (non-empty, empty, emptied by \b).
#   2. the editor: key (incl. ""), back (incl. on empty), kill_line; submit's
#      echo and result (empty input; an unfinished output line ended first);
#      hist_prev/hist_next past both ends, restoring the typed line, editing
#      a recalled line; clear (keeps input, history and an open CSI);
#      set_prompt (later echoes only).
#   3. rows: wrap at exactly cols (cols 1, 3, 9, 10, 11, 25, 26, 80), a line of
#      exactly cols bytes is one row, empty lines one row, "" padding when
#      history is short, the idle cursor line vs the busy partial line (both
#      wrapping), n = 0 / negative / 1 / larger than the content, cols < 1.
#   4. the 500-line cap at 499, 500, 501, 999, 1000, 1001, 1203 lines (the
#      module trims lazily at 1000; the visible history must be exactly the
#      newest 500 throughout), and submit/clear at the cap.
#   5. keychar for every code 0..130 and 200, 255, 1000, -1, -57, shift off
#      and on, against a Python US-layout table; the KEY_* constants.
#   6. a seeded 260-step random script mixing all operations.
#   7. the C host runs groups 2, 3, 5, the first 40 steps of 6 and a small
#      mixed script (every group with WM_TERM_HOST_ALL=1) and must match the
#      model and the VM byte for byte; and 100 cheap observations must run
#      on the host within a 256 MB address space (bounded memory).
#   8. performance on the VM (see the end): linear long lines, rows cost
#      independent of history length (with exactly 500 stored lines, where
#      rows walks the stored list itself, and with 999) and of how many
#      stored lines would wrap, and a loose per-byte bound.
#
# ISOLATION: a private temporary directory (gate_wm_common.sh); touches no
# tracked file. About 6 min on a quiet machine, most of it the host runs and
# the toolchain build.
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1

wm_setup theourgia_term.la
if ! python3 - "$T" <<'PYEOF'
# The reference model and the generator of the test programs. For each test
# group it writes $T/<g>.la (an LA program running a script of terminal
# operations and printing what it observes) and $T/<g>.exp (what the model
# says it must print).
import random
import sys

OUT = sys.argv[1]
CAP = 500

# ── the model: written from WM_DESIGN.md's table, independently of the LA ──
class Term:
    def __init__(self, prompt):
        self.lines = []          # every completed line, oldest first
        self.partial = bytearray()
        self.esc = 0             # 0 none, 1 after ESC, 2 in CSI
        self.inp = b""
        self.prompt = prompt
        self.hist = []           # newest first
        self.walk = 0            # 0 not walking; j: showing hist[j-1]
        self.saved = b""

    def write(self, data):
        for b in data:
            if self.esc == 1:
                self.esc = 2 if b == 0x5B else 0
            elif self.esc == 2:
                if 0x40 <= b <= 0x7E:
                    self.esc = 0
            elif 32 <= b <= 126:
                self.partial.append(b)
            elif b == 10:
                self.lines.append(bytes(self.partial))
                self.partial = bytearray()
            elif b == 9:
                self.partial += b" " * (8 - len(self.partial) % 8)
            elif b == 8:
                if self.partial:
                    self.partial.pop()
            elif b == 27:
                self.esc = 1
            elif b >= 0xC0:
                self.partial.append(ord("?"))
            # 13, other controls, 127 and 0x80..0xBF: nothing

    def flush(self):
        if self.partial:
            self.lines.append(bytes(self.partial))
            self.partial = bytearray()

    def submit(self):
        self.flush()
        line = self.inp
        self.lines.append(self.prompt + self.inp)
        if line:
            self.hist.insert(0, line)
        self.inp, self.walk, self.saved = b"", 0, b""
        return line

    def hist_prev(self):
        if self.walk < len(self.hist):
            if self.walk == 0:
                self.saved = self.inp
            self.inp = self.hist[self.walk]
            self.walk += 1

    def hist_next(self):
        if self.walk == 1:
            self.inp, self.walk = self.saved, 0
        elif self.walk > 1:
            self.walk -= 1
            self.inp = self.hist[self.walk - 1]

    def rows(self, cols, n, idle):
        cols = max(cols, 1)
        if n < 1:
            return []
        last = self.prompt + self.inp + b"\x7f" if idle else bytes(self.partial)
        out = []
        for x in self.lines[-CAP:] + [last]:
            out += [x[i:i + cols] for i in range(0, len(x), cols)] if x else [b""]
        out = out[-n:]
        return [b""] * (n - len(out)) + out

# keychar: the US layout, as a table of (code, plain, shifted)
KEYS = {}
for row, plain, shifted in [(2, b"1234567890-=", b"!@#$%^&*()_+"),
                            (16, b"qwertyuiop[]", b"QWERTYUIOP{}"),
                            (30, b"asdfghjkl;'`", b'ASDFGHJKL:"~'),
                            (43, b"\\zxcvbnm,./", b"|ZXCVBNM<>?")]:
    for k in range(len(plain)):
        KEYS[row + k] = (plain[k:k + 1], shifted[k:k + 1])
KEYS[57] = (b" ", b" ")

KEYCONST = dict(KEY_ESC=1, KEY_MINUS=12, KEY_EQUAL=13, KEY_BACKSPACE=14, KEY_TAB=15, KEY_Q=16,
                KEY_E=18, KEY_T=20, KEY_ENTER=28, KEY_LEFTCTRL=29, KEY_H=35, KEY_J=36, KEY_K=37,
                KEY_L=38, KEY_LEFTSHIFT=42, KEY_C=46, KEY_RIGHTSHIFT=54, KEY_LEFTALT=56,
                KEY_RIGHTCTRL=97, KEY_RIGHTALT=100, KEY_UP=103, KEY_LEFT=105, KEY_RIGHT=106,
                KEY_DOWN=108, KEY_LEFTMETA=125, KEY_RIGHTMETA=126)

# ── LA code generation ──
def lit(b):
    """an LA expression whose value is the byte string b"""
    pieces = []
    run = bytearray()
    for x in b:
        if 32 <= x <= 126:
            run.append(x)
        else:
            if run:
                pieces.append(bytes(run)); run = bytearray()
            pieces.append(x)
    if run:
        pieces.append(bytes(run))
    def one(p):
        if isinstance(p, int):
            return 'chr("%d")' % p
        return '"' + p.decode().replace("\\", "\\\\").replace('"', '\\"') + '"'
    def bal(ps):
        if not ps:
            return '""'
        if len(ps) == 1:
            return one(ps[0])
        m = len(ps) // 2
        return "concat(%s)(%s)" % (bal(ps[:m]), bal(ps[m:]))
    return bal(pieces)

def boolean(x):
    return "TRUE" if x else "FALSE"

def num(k):
    return str(k) if k >= 0 else "sub(0)(%d)" % -k

PRELUDE = '''import("theourgia_term.la")
glyph TRUE = la t. la f. t
glyph FALSE = la t. la f. f
# SHOWROWS(l): print each row as [row], one per line
glyph SHOWROWS = la l. (la r. r(r)(l))(la r. la l. l(la _. "")(la h. la t. (la _. r(r)(t))(print(concat("[")(concat(h)("]"))))))
glyph MAIN = TERM_KIT(str_at)(ord)(str_to_int)(str_len)(chr)(concat)(str_eq)(add)(sub)(mul)(div)(mod)(lt)(int_eq)
  (la new. la write. la flush. la key. la back. la kill_line. la submit.
   la hist_prev. la hist_next. la clear. la set_prompt. la rows. la keychar.
'''

def program(script):
    """script: list of ops; returns (LA source, expected output bytes)"""
    exp = bytearray()
    term = None
    markpos = 0
    code = []      # code[k] is a format string with one %s for the rest
    for op in script:
        kind = op[0]
        if kind == "new":
            term = Term(op[1])
            markpos = 0
            code.append("(la t. @REST@)(new(" + lit(op[1]) + "))")
        elif kind == "write":
            term.write(op[1])
            code.append("(la t. @REST@)(write(t)(" + lit(op[1]) + "))")
        elif kind in ("flush", "back", "kill_line", "hist_prev", "hist_next", "clear"):
            {"flush": term.flush, "back": lambda: setattr(term, "inp", term.inp[:-1]),
             "kill_line": lambda: setattr(term, "inp", b""), "hist_prev": term.hist_prev,
             "hist_next": term.hist_next,
             "clear": lambda: (setattr(term, "lines", []), setattr(term, "partial", bytearray()))}[kind]()
            code.append("(la t. @REST@)(" + kind + "(t))")
        elif kind == "key":
            term.inp += op[1]
            code.append("(la t. @REST@)(key(t)(" + lit(op[1]) + "))")
        elif kind == "prompt":
            term.prompt = op[1]
            code.append("(la t. @REST@)(set_prompt(t)(" + lit(op[1]) + "))")
        elif kind == "submit":
            line = term.submit()
            exp += b"S:" + line + b"\n"
            code.append('submit(t)(la line. la t. (la _. @REST@)(print(concat("S:")(line))))')
        elif kind == "rows":
            _, cols, n, idle = op
            for r in term.rows(cols, n, idle):
                exp += b"[" + r + b"]\n"
            code.append("(la _. @REST@)(SHOWROWS(rows(t)(%s)(%s)(%s)))" % (num(cols), num(n), boolean(idle)))
        elif kind == "view":
            # rows enough for every line since the last mark, plus one more
            _, cols, idle = op
            w_ = max(cols, 1)
            last = term.prompt + term.inp + b"\x7f" if idle else bytes(term.partial)
            seen = term.lines[markpos:] + [last]
            n = sum(max(1, -(-len(x) // w_)) for x in seen) + 1
            for r in term.rows(cols, n, idle):
                exp += b"[" + r + b"]\n"
            code.append("(la _. @REST@)(SHOWROWS(rows(t)(%s)(%s)(%s)))" % (num(cols), num(n), boolean(idle)))
        elif kind == "mark":
            markpos = len(term.lines)
            exp += op[1] + b"\n"
            code.append("(la _. @REST@)(print(" + lit(op[1]) + "))")
        else:
            raise SystemExit("bad op %r" % (op,))
    exp += b"END\n"
    body = 'print("END")'
    for c in reversed(code):
        body = c.replace("@REST@", body, 1)
    return PRELUDE + "     " + body + ")\n", bytes(exp)

def emit(name, script):
    src, exp = program(script)
    open("%s/%s.la" % (OUT, name), "w").write(src)
    open("%s/%s.exp" % (OUT, name), "wb").write(exp)

ESC = b"\x1b"

# ── 1. write: every rule of the table, and flush ──
def R(cols=40, n=3, idle=False):
    return ("rows", cols, n, idle)
w = [("new", b"$ ")]
def V(cols=80, idle=False):
    return ("view", cols, idle)
w += [("mark", b"printable"), ("write", bytes(range(32, 127))), V(200)]
w += [("mark", b"newline"), ("write", b"one\ntwo\n\nfour"), V(40)]
w += [("mark", b"cr"), ("write", b"\r\nab\rc\r\n"), V(40)]
w += [("mark", b"tabs")]
for pre in [b"", b"a", b"abc", b"abcdefg", b"abcdefgh", b"x" * 15, b"x" * 60, b"x" * 63, b"x" * 64, b"x" * 70]:
    w += [("write", pre + b"\tT\n")]
w += [("write", b"\t\t|\n"), V(100)]
w += [("mark", b"backspace")]
w += [("write", b"\x08\x08start\n"), ("write", b"abc\x08\x08d\n"), ("write", b"ab\x08\x08\x08\x08c\n"),
      ("write", b"y" * 64 + b"\x08Z\n"), ("write", b"y" * 65 + b"\x08\x08Z\n"),
      ("write", b"y" * 128 + b"\x08\n"), ("write", b"\tx\x08\x08|\n"), V(140)]
w += [("mark", b"csi"), ("write", b"a" + ESC + b"[1;31mb" + ESC + b"[0mc\n"),
      ("write", b"d" + ESC + b"[@e" + ESC + b"[~f" + ESC + b"[ !pg\n"),
      ("write", b"split" + ESC + b"[3"), ("write", b"1;4"), ("write", b"2mdone\n"),
      ("write", b"u" + ESC + b"["), ("write", b"Kv\n"),
      ("write", ESC + b"[" + bytes([0xC3, 0x7F, 0x0A]) + b"Hz\n"), V(40)]
w += [("mark", b"esc"), ("write", b"a" + ESC + b"7b" + ESC + b"(B\n"),
      ("write", b"lone" + ESC), ("write", b"[1mX\n"),
      ("write", b"lone2" + ESC), ("write", b"QY\n"),
      ("write", b"e3" + ESC), ("write", b""), ("write", b"[2Jok\n"),
      ("write", ESC + ESC + b"Z\n"), ("write", ESC + b"\n" + b"after\n"), V(40)]
w += [("mark", b"utf8"), ("write", "café €! 😀.".encode()), ("write", b"\n"),
      ("write", bytes([0x80, 0xBF, 0x41, 0xC0, 0xFF, 0xDF, 0x42]) + b"\n"),
      ("write", bytes([0xE2, 0x82])), ("write", bytes([0xAC]) + b"<\n"), V(40)]
w += [("mark", b"controls"), ("write", bytes([0, 1, 7, 11, 12, 14, 26, 28, 31, 127]) + b"k" + bytes([127]) + b"\n"),
      V(40)]
w += [("mark", b"segments"), ("write", b"s" * 63), R(80, 1), ("write", b"S"), R(80, 1), ("write", b"t"), R(80, 1),
      ("write", b"q" * 200), R(60, 6), ("write", b"\n"), R(70, 5)]
w += [("mark", b"flush"), ("write", b"partial"), R(40, 2), ("flush",), R(40, 2), ("flush",), R(40, 2),
      ("write", b"abc\x08\x08\x08"), ("flush",), R(40, 2), ("write", b"z\n"), ("flush",), R(40, 2),
      ("write", b"x" * 64), ("flush",), R(40, 3)]
emit("t_write", w)

# ── 2. the line editor, submit, history, clear, set_prompt ──
e = [("new", b"> "), R(20, 2, True)]
e += [("mark", b"editor"), ("key", b"l"), ("key", b"s"), ("key", b""), ("key", b" -l"), R(20, 1, True),
      ("back",), R(20, 1, True), ("back",), ("back",), ("back",), ("back",), ("back",), R(20, 1, True),
      ("back",), R(20, 1, True), ("key", b"echo hi"), ("kill_line",), R(20, 1, True), ("key", b"pwd"), R(20, 2, True)]
e += [("mark", b"submit"), ("submit",), R(20, 3, True), ("submit",), R(20, 3, True),
      ("write", b"output without newline"), ("key", b"ls"), ("submit",), R(30, 4, True), R(30, 4, False)]
e += [("mark", b"history"), ("hist_next",), R(20, 1, True), ("hist_prev",), R(20, 1, True), ("hist_prev",),
      R(20, 1, True), ("hist_prev",), R(20, 1, True), ("hist_prev",), R(20, 1, True),
      ("hist_next",), R(20, 1, True), ("hist_next",), R(20, 1, True), ("hist_next",), R(20, 1, True),
      ("key", b"typed"), ("hist_prev",), R(20, 1, True), ("key", b"!"), R(20, 1, True), ("hist_prev",),
      R(20, 1, True), ("hist_next",), R(20, 1, True), ("hist_next",), R(20, 1, True),
      ("hist_prev",), ("hist_prev",), ("submit",), ("hist_prev",), R(20, 1, True), ("hist_next",), R(20, 2, True)]
e += [("mark", b"clear"), ("write", b"o1\no2\npart"), ("key", b"inp"), ("clear",), R(20, 3, True), R(20, 3, False),
      ("hist_prev",), R(20, 1, True), ("write", b"x" + ESC + b"["), ("clear",), ("write", b"31mY\n"), R(20, 2)]
e += [("mark", b"prompt"), ("kill_line",), ("prompt", b"logos:/home$ "), R(30, 2, True), ("key", b"cd /"),
      ("submit",), ("prompt", b"logos:/$ "), R(30, 3, True), ("prompt", b""), ("submit",), R(30, 3, True)]
emit("t_edit", e)

# ── 3. rows: wrapping, padding, idle vs busy, n and cols edge cases ──
r = [("new", b"$ ")]
r += [("mark", b"empty"), R(10, 3, True), R(10, 3, False), R(10, 0, True), R(10, 1, False)]
r += [("write", b"abcdefghij\n" + b"abcdefghijk\n" + b"\n" + b"x" * 25 + b"\n" + b"abc\n")]
for cols in (1, 3, 9, 10, 11, 25, 26, 80):
    r += [("mark", b"cols %d" % cols), R(cols, 12, False)]
r += [("mark", b"n"), R(10, 1, False), R(10, 2, True), R(10, 7, False), R(10, 30, True), R(10, 0, False),
      R(10, -3, True)]
r += [("mark", b"cols<1"), R(0, 4, True), R(-5, 4, False)]
r += [("mark", b"idle wrap"), ("key", b"0123456789abc"), R(5, 6, True), R(15, 2, True), R(16, 2, True)]
r += [("mark", b"busy partial"), ("write", b"p" * 23), R(10, 4, False), R(10, 4, True)]
r += [("mark", b"exact"), ("new", b"#"), ("write", b"1234\n12345\n"), R(5, 5, False), R(4, 5, False)]
emit("t_rows", r)

# ── 4. the 500-line cap, across the trim points ──
c = [("new", b"$ ")]
written = 0
for target in (499, 500, 501, 999, 1000, 1001, 1203):
    data = b"".join(b"L%04d\n" % k for k in range(written, target))
    written = target
    c += [("write", data), ("mark", b"after %d" % target), R(20, 503, False)]
c += [("mark", b"submit at cap"), ("key", b"cmd"), ("submit",), R(20, 3, True), R(20, 502, True)]
c += [("clear",), ("mark", b"cleared"), R(20, 3, True)]
emit("t_cap", c)

# ── 5. a seeded random script mixing everything (interactions) ──
rnd = random.Random(20261008)
pal = [b"hello world", b"\n", b"\r\n", b"\t", b"x\ty\tz", b"\x08", b"\x08\x08\x08", ESC + b"[0m", ESC + b"[",
       b"1;32m", ESC, b"[K", b"7", "é€😀".encode(), bytes([0xE2]), bytes([0x82, 0xAC]), bytes([127, 0, 7]),
       b"q" * 70, b"0123456789" * 3, b"", b"#;|\\\"", b"]["]
rs = [("new", b"r$ ")]
for step in range(260):
    x = rnd.random()
    if x < 0.45:
        rs.append(("write", b"".join(rnd.choice(pal) for _ in range(rnd.randint(1, 4)))))
    elif x < 0.55:
        rs.append(("key", rnd.choice([b"a", b"ls", b" ", b"echo x", b"", b"~"])))
    elif x < 0.6:
        rs.append((rnd.choice(["back", "kill_line"]),))
    elif x < 0.66:
        rs.append(("submit",))
    elif x < 0.72:
        rs.append((rnd.choice(["hist_prev", "hist_next"]),))
    elif x < 0.74:
        rs.append(("flush",))
    elif x < 0.75:
        rs.append(("clear",))
    elif x < 0.76:
        rs.append(("prompt", rnd.choice([b"$ ", b"", b"long-prompt:/a/b/c$ "])))
    else:
        rs.append(("rows", rnd.randint(1, 50), rnd.randint(0, 14), rnd.random() < 0.5))
emit("t_random", rs)
emit("t_rand40", rs[:41])     # its first 40 steps, sized for the C host
# host memory: many cheap observations (see the host checks below)
emit("t_hmem", [("new", b"$ ")] + [("key", b"x"), ("rows", 10, 1, True)] * 100)

# ── 6. keychar over every code 0..130 (and a few beyond), and the KEY_* constants ──
codes = list(range(0, 131)) + [200, 255, 1000, -1, -57]
kc = []
expk = bytearray()
for k in codes:
    p, s = KEYS.get(k, (b"", b""))
    kc.append('print(concat(keychar(%s)(FALSE))(concat("|")(keychar(%s)(TRUE))))' % (num(k), num(k)))
    expk += p + b"|" + s + b"\n"
for name, v in KEYCONST.items():
    kc.append('print(concat("%s=")(int_to_str(%s)))' % (name, name))
    expk += b"%s=%d\n" % (name.encode(), v)
body = 'print("END")'
for x in reversed(kc):
    body = "(la _. %s)(%s)" % (body, x)
open(OUT + "/t_keys.la", "w").write(PRELUDE + "     " + body + ")\n")
open(OUT + "/t_keys.exp", "wb").write(bytes(expk) + b"END\n")

# ── 7. a moderate script for the host-vs-VM comparison ──
h = [("new", b"$ "), ("write", b"ab\tc" + ESC + b"[1"), ("write", b"mde\x08f\n" + "é".encode() + b"\r\n"),
     ("key", b"ls"), ("submit",), ("write", b"x" * 70 + b"\n"), ("hist_prev",), ("key", b"!"),
     R(16, 8, True), ("flush",), ("clear",), R(8, 2, False)]
emit("t_host", h)

# ── 8. the timing program: kit style, prints "label <cpu before> <cpu after>" ──
def lets(binds, body):
    """(la n1. (la n2. ... body)(v2))(v1) for binds = [(n1, v1), (n2, v2), ...]"""
    for name, val in reversed(binds):
        body = "(la %s. %s)(%s)" % (name, body, val)
    return body
def seq(items):
    body = items[-1]
    for x in reversed(items[:-1]):
        body = "SEQ(%s)(%s)" % (x, body)
    return body

MIXED = ('REP(64)(concat("total 48 drwxr-xr-x  2 user user 4096 Oct  8 16:36 ")'
         '(concat(ESC)(concat("[01;34m")(concat("wmtools")(concat(ESC)(concat("[0m")(concat(NL)'
         '(concat("-rw-r--r--\\t1 root root 10642 compiler.bin caf")(concat(chr("195"))(concat(chr("169"))'
         '(concat(chr("13"))(concat(NL)'
         '(concat("the quick brown fox jumps over the lazy dog, again and again!!")(NL))))))))))))))')
timings = ['print(concat("bytes mixed ")(str_len(mixed)))', 'print(concat("bytes ctl ")(str_len(ctl)))']
timings += ['TIME("walk")(la _. WALK(C10000))', 'TIME("nowalk")(la _. NOWALK(C10000))'] * 3
timings += ['TIME("mixed")(la _. write(new("$ "))(mixed))', 'TIME("ctl")(la _. write(new("$ "))(ctl))'] * 3
timings += ['TIME("line16k")(la _. write(new("$ "))(l16))', 'TIME("line64k")(la _. write(new("$ "))(l64))'] * 3
timings += ['TIME("rows40")(la _. rows(t40)(C80)(C40)(TRUE))', 'TIME("rows500")(la _. rows(t500)(C80)(C40)(TRUE))',
            'TIME("rows999")(la _. rows(t999)(C80)(C40)(TRUE))'] * 4
timings += ['TIME("wrap14")(la _. rows(t14w)(C80)(C40)(FALSE))', 'TIME("wrap500")(la _. rows(t500w)(C80)(C40)(FALSE))'] * 3
body = lets([("mixed", MIXED),
             ("ctl", 'REP(4096)(concat(chr("9"))(concat(chr("13"))(concat(chr("7"))(chr("1")))))'),
             ("l16", 'REP(16384)("x")'),
             ("l64", 'REP(65536)("x")'),
             ("t40", 'write(new("$ "))(REP(40)(concat(REP(60)("v"))(NL)))'),
             ("t500", 'write(new("$ "))(REP(500)(concat(REP(60)("v"))(NL)))'),
             ("t999", 'write(new("$ "))(REP(999)(concat(REP(60)("v"))(NL)))'),
             ("t14w", 'write(new("$ "))(REP(14)(concat(REP(200)("w"))(NL)))'),
             ("t500w", 'write(new("$ "))(REP(500)(concat(REP(200)("w"))(NL)))')], seq(timings))
REP = ('la n. la s. (la r. r(r)(n))(la r. la n. int_eq(n)(C0)(la _. "")'
       '(la _. (la h. int_eq(mod(n)(C2))(C0)(concat(h)(h))(concat(s)(concat(h)(h))))(r(r)(div(n)(C2))))(C0))')
# WALK(k): a loop of k turns, each naming str_head, a builtin that is not a
# parameter here, so each turn walks the whole glyph table once (WM_DESIGN.md
# rule 1); NOWALK(k): the same loop without it. Their difference is the cost
# of one walk in this program, the yardstick for the per-byte bounds.
WALK = ('la k. (la r. r(r)(k))(la r. la k. int_eq(k)(C0)(la _. C0)'
        '(la _. (la _. r(r)(sub(k)(C1)))(str_head))(C0))')
NOWALK = ('la k. (la r. r(r)(k))(la r. la k. int_eq(k)(C0)(la _. C0)'
          '(la _. (la _. r(r)(sub(k)(C1)))(C1))(C0))')
TIME = ('la label. la f. (la a. (la v. (la b. SEQ(print(concat(label)(concat(" ")(concat(a)(concat(" ")(b))))))(v))'
        '(CPU(C0)))(f(C0)))(CPU(C0))')
body = lets([("C0", "0"), ("C1", "1"), ("C2", "2"), ("C40", "40"), ("C80", "80"), ("C10000", "10000"),
             ("TRUE", "la t. la f. t"), ("FALSE", "la t. la f. f"), ("SEQ", "la a. la b. b"),
             ("NL", 'chr("10")'), ("ESC", 'chr("27")'), ("CPU", 'la _. clock_gettime("2")'),
             ("REP", REP), ("WALK", WALK), ("NOWALK", NOWALK), ("TIME", TIME)], body)
B = "str_at ord str_to_int str_len chr concat str_eq add sub mul div mod lt int_eq print clock_gettime".split()
kit = ("TERM_KIT(str_at)(ord)(str_to_int)(str_len)(chr)(concat)(str_eq)(add)(sub)(mul)(div)(mod)(lt)(int_eq)"
       "(la new. la write. la flush. la key. la back. la kill_line. la submit. la hist_prev. la hist_next."
       " la clear. la set_prompt. la rows. la keychar. %s)" % body)
main = "(%s %s)%s" % (" ".join("la %s." % b for b in B), kit, "".join("(%s)" % b for b in B))
open(OUT + "/t_perf.la", "w").write(
    'import("theourgia_term.la")\n'
    '# Kit style: every builtin the harness uses after startup is a parameter, so\n'
    '# the clock brackets time the terminal, not glyph-table walks.\n'
    'glyph MAIN = ' + main + "\n")
PYEOF
then
    echo "FAIL  term: the test generator (the model) failed"; exit 1
fi

# firstdiff EXP GOT: where two outputs part, for a FAIL line
firstdiff() {
    python3 - "$1" "$2" <<'PYEOF'
import sys
a = open(sys.argv[1], "rb").read().split(b"\n")
b = open(sys.argv[2], "rb").read().split(b"\n")
for i in range(max(len(a), len(b))):
    x = a[i] if i < len(a) else b"<none>"
    y = b[i] if i < len(b) else b"<none>"
    if x != y:
        print("line %d: expected %r, got %r" % (i + 1, x[:90], y[:90]))
        break
PYEOF
}

# vmcheck GROUP DESCRIPTION: run GROUP on the VM, compare with the model
vmcheck() {
    wm_vm "$1.la" "$T/$1.vm"
    if [ "$vrc" = 0 ] && cmp -s "$T/$1.vm" "$T/$1.exp"; then
        echo "PASS  term (VM): $2 ($(wc -l <"$T/$1.exp") lines as the model)"
    elif [ "$vrc" = 90 ]; then
        echo "FAIL  term (VM): $2: did not compile: $(head -c 200 "$T/vce")"; ok=0
    else
        echo "FAIL  term (VM): $2: rc=$vrc $(head -c 160 "$T/vre") $(firstdiff "$T/$1.exp" "$T/$1.vm")"; ok=0
    fi
}

vmcheck t_write  "write: printable, \\n, \\r, \\t at many columns, \\b (line start, segment edges), CSI (whole, split, cut at ESC), ESC+byte, UTF-8, controls, 127; flush"
vmcheck t_edit   "key/back/kill_line, submit's echo and result, history past both ends, clear, set_prompt"
vmcheck t_rows   "rows: wrap at cols, exact-width lines, empty lines, padding, idle vs busy, n and cols edge cases"
vmcheck t_cap    "the 500-line cap at 499/500/501/999/1000/1001/1203 lines"
vmcheck t_keys   "keychar over codes -57..1000 against the US table; the KEY_* constants"
vmcheck t_random "a seeded 260-step random script against the model"

# The C host runs the same programs. It is a substitution interpreter that
# copies a closure's body on every application, and the kit's closures are
# large, so each write costs it about a second: by default it runs the groups
# that fit (~4 min of CPU): t_host, t_edit, t_keys, t_rows, and t_rand40 (the
# first 40 steps of t_random). WM_TERM_HOST_ALL=1 runs every group on the
# host (t_write takes ~15 min of CPU there and t_random more than 16: raise
# WM_HOST_TIMEOUT, in seconds, to suit).
hostgroups="t_host t_edit t_keys t_rows t_rand40"
[ "${WM_TERM_HOST_ALL:-}" = 1 ] && hostgroups="$hostgroups t_write t_cap t_random"
for g in $hostgroups; do
    wm_host "$g.la" "$T/$g.host"
    [ -f "$T/$g.vm" ] || wm_vm "$g.la" "$T/$g.vm"
    if [ "$hrc" = 0 ] && cmp -s "$T/$g.host" "$T/$g.exp" && cmp -s "$T/$g.host" "$T/$g.vm"; then
        echo "PASS  term (host): $g gives the model's output, byte for byte the VM's"
    else
        echo "FAIL  term (host): $g: rc=$hrc $(head -c 160 "$T/hre") $(firstdiff "$T/$g.exp" "$T/$g.host")"; ok=0
    fi
done

# Host memory. A long script must run on the C host in bounded memory: the
# harness keeps the rest of the script in tail position. t_hmem is 100 cheap
# observations (a key, then a one-row rows), run under a 256 MB address-space
# limit; it needs ~45 MB. (With the rest of the script passed as an argument,
# SEQ(observation)(rest), every observation nested a C frame, the host's
# conservative GC kept every earlier state alive, and this run needed ~800 MB;
# the full t_random was killed at 2.4 GB.)
hmrc=0
( cd "$T" && ulimit -v 262144 && timeout "$WM_HOST_TIMEOUT" ./tiny_host t_hmem.la >"$T/t_hmem.host" 2>"$T/hmre" ) || hmrc=$?
if [ "$hmrc" = 0 ] && cmp -s "$T/t_hmem.host" "$T/t_hmem.exp"; then
    echo "PASS  term (host): t_hmem, 100 observations, gives the model's output within a 256 MB address space"
else
    echo "FAIL  term (host): t_hmem: rc=$hmrc $(head -c 160 "$T/hmre") $(firstdiff "$T/t_hmem.exp" "$T/t_hmem.host")"; ok=0
fi

# Performance, on the VM, in process CPU time. Absolute times on a shared
# machine vary several-fold, so every check is a RATIO of two times taken in
# the same run:
#   - THE YARDSTICK W: the cost of one glyph-table walk in this very program
#     (a loop naming a builtin that is not a parameter, minus the same loop
#     without; ~10 us here, and more in a bigger program). Kit-style code
#     never walks after startup (WM_DESIGN.md rule 1), so: mixed output
#     (text, tabs, colour CSIs, UTF-8) and a 16 KB printable line must cost
#     under W/2 a byte (they run at ~0.15 W; one walk per printable byte
#     makes it more than W), and bytes that are all control bytes (\t \r and
#     two ignored C0 controls) under W (they run at ~0.5 W);
#   - a 64 KB line without a newline costs ~4x a 16 KB one (linear; the
#     64-byte segments keep it from being quadratic, which would be ~16x);
#   - rows(80)(40) over 500 and over 999 stored 60-byte lines costs about
#     what it costs over 40 (it visits only the lines its n rows need;
#     walking the history would be 12x and more). 500 is the case that
#     matters: rows trims a list of more than 500 lines to its first n before
#     walking it, so the 999 case alone would not show a walk;
#   - 40 wrapped rows (200-byte lines, three rows each) cost about the same
#     over 500 stored lines as over 14 (only the lines the 40 rows come from
#     are cut into rows; wrapping the whole history would be ~35x).
wm_vm t_perf.la "$T/perf.txt"
python3 - "$T/perf.txt" "$vrc" >"$T/perf.res" <<'PYEOF'
import sys
best = {}
nbytes = {}
for line in open(sys.argv[1]):
    f = line.split()
    if len(f) == 3 and f[0] == "bytes":
        nbytes[f[1]] = int(f[2]); continue
    if len(f) == 5:
        us = ((int(f[3]) - int(f[1])) * 10**9 + int(f[4]) - int(f[2])) / 1000.0
        best[f[0]] = min(best.get(f[0], us), us)
need = ["walk", "nowalk", "mixed", "ctl", "line16k", "line64k", "rows40", "rows500", "rows999", "wrap14", "wrap500"]
missing = [k for k in need if k not in best] + [k for k in ("mixed", "ctl") if k not in nbytes]
if sys.argv[2] != "0" or missing:
    print("FAIL  term (VM perf): the timing program: rc=%s, missing %s" % (sys.argv[2], " ".join(missing) or "-"))
    sys.exit()
def check(ok, text):
    print(("PASS" if ok else "FAIL") + "  term (VM perf): " + text)
W = (best["walk"] - best["nowalk"]) / 10000
per = best["mixed"] / nbytes["mixed"]
p16 = best["line16k"] / 16384
pc = best["ctl"] / nbytes["ctl"]
lr = best["line64k"] / best["line16k"]
check(per < W / 2 and p16 < W / 2 and pc < W and lr < 8,
      "write: one glyph-table walk W = %.1f us; per byte: mixed output %.2f us (%d bytes), a 16 KB line %.2f,\n"
      "      control bytes %.2f (bounds W/2, W/2, W); 64K/16K line %.1fx (linear; bound 8)"
      % (W, per, nbytes["mixed"], p16, pc, lr))
r500 = best["rows500"] / best["rows40"]
r999 = best["rows999"] / best["rows40"]
rw = best["wrap500"] / best["wrap14"]
check(r500 < 4 and r999 < 4 and rw < 3,
      "rows 80x40: %.0f us over 40 stored lines, %.0f over 500, %.0f over 999 (ratios %.2f, %.2f; bound 4);\n"
      "      40 wrapped rows: %.0f us over 14 stored lines, %.0f over 500 (ratio %.2f; bound 3)"
      % (best["rows40"], best["rows500"], best["rows999"], r500, r999, best["wrap14"], best["wrap500"], rw))
PYEOF
cat "$T/perf.res"
grep -q '^PASS' "$T/perf.res" || { echo "FAIL  term (VM perf): no result"; ok=0; }
! grep -q '^FAIL' "$T/perf.res" || ok=0

[ "$ok" = 1 ] || exit 1
