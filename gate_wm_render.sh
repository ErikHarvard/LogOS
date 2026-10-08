#!/usr/bin/env bash
# gate_wm_render.sh — the window manager's renderer (theourgia_render.la): text
# bands, styles, the band cache and the frame compositor draw exactly the bytes
# their contract (WM_DESIGN.md) says, and fail loudly on a broken contract.
#
# WHAT IT GUARDS. Every pixel the window manager shows goes through RENDER_KIT,
# and its fast paths are easy to get subtly wrong: a glyph row read from the
# wrong bit, a band block off by one character, a cache returning a stale band,
# a gap or a pitch pad one pixel short. Any of those still draws a plausible
# frame. So nothing here is compared with the module's own output: an
# independent Python model (below) decodes TF_HEX straight out of
# theourgia_termfont.la and recomputes every expected byte from the font table
# and the contract.
#
#   1. VM: px and run; band at scale 1 and 2 (and a subset at 3) for every
#      printable character in order and reversed, a line longer than cols
#      (truncated), shorter (padded), empty, one character, bytes outside
#      32..127 (drawn as '?'), cols 0 and negative, line lengths 1..300 around
#      every power of two the band's block decomposition uses, and 12 seeded
#      random lines of random bytes; the shape of each band (8*scale scanlines
#      of cols*8*scale pixels) as well as its bytes.
#   2. VM: bands with a cache: a first call from NIL, then a call whose cache
#      also holds a PLANTED entry ("delta" with a fake band) and an unused one
#      ("omega"): hits come back byte-identical, the planted fake comes back
#      (so the cache really is consulted, not recomputed), and cache' holds
#      exactly the texts of the call, in order, one entry each, with their
#      bands; duplicates within one call; a call with no texts.
#   3. VM: solid (incl. w = 0, h = 0), join (NIL, one piece, 1000 pieces,
#      empty pieces), and compose: tiles in any order at odd offsets with the
#      background in the gaps, a tile on each screen edge, pitch > 4*W, blank
#      spans between stacked tiles, no tiles, H = 0, zero-width and
#      zero-height tiles (one at the same x as a real tile, given after it),
#      three and five tiles in one row, text tiles, and 24 seeded random
#      layouts of up to six non-overlapping tiles.
#   4. VM: each contract violation halts with rc 1 and the module's message,
#      printing nothing: overlapping tiles, a tile off the screen (right,
#      bottom, negative x), a rows list shorter or longer than h, a row that is
#      not 4*w bytes, pitch < 4*W, a line longer than 4095 characters.
#   5. host: px, run, join, solid and compose (small) give the same bytes on
#      the C host and the VM, both equal to the model. band and bands are not
#      run on the host: building a style draws all 96 glyphs, and the host's
#      substitution interpreter copies the kit's closures at every step; a
#      style at scale 1 ran 11 minutes there and was killed out of memory.
#
# ISOLATION: a private temporary directory (gate_wm_common.sh); touches no
# tracked file. About 2 minutes of CPU (4 wall on a busy machine): the
# toolchain build (~35 s) and three VM compiles of the test programs (~45, 15
# and 6 s); the runs take ~10 s.
#
# PERFORMANCE (measured, not gated: the shared test machines are too noisy for
# a timing gate). Process CPU time on the native VM (clock_gettime 2), scale 2:
#   style(fg)(bg)                                     3.9 ms   (27M instructions)
#   band, one 120-character line                       1.6 ms   (9.4M)
#   bands, 67 lines of 120 columns, all misses        90 ms     (575M, 1.3 ms a line)
#   bands, the same 67 texts again, all hits           0.5 ms   (4.4M)
#   compose 1920x1080, pitch 7680, two side-by-side
#     960x1072 tiles full of text rows                96 ms     (776M)
#   the same with gaps (944-wide tiles at x 8, 968,
#     y 4: background around and between them)      106 ms     (844M)
#   one tile of solid rows covering the screen        93 ms     (695M)
#   one 960x1072 tile of solid rows, background
#     elsewhere                                     103 ms
#   solid(1920)(1080)(p)                               1.1 ms
# The minimum of 5 runs, with a load average of ~12 on 4 cores (other jobs on
# the machine); the instruction counts (callgrind on a heap-mmapped build of
# the same VM) do not depend on load. 95% of compose's instructions are
# concat's byte copying, about 11 copies of each byte: the floor for a frame
# joined by concat. (The design notes' first prototype spent 4-9 s a frame on
# per-row strip lookups; this module's first compose, a Z-recursive dynamic
# join, cost 858M / 963M / 762M instructions on the three compose cases.)
# Writing the same frame piece by piece to a tmpfs file and reading it back
# (VM-only open/write/read_file) takes 10.5 ms: the one lever left, and it is
# outside pure LA.
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1

wm_setup theourgia_render.la theourgia_termfont.la

# ── the independent model and the generator of the LA test programs ──
cat > "$T/rtgen.py" <<'PYEOF'
#!/usr/bin/env python3
"""Independent reference model of theourgia_render.la + generator of the LA test
programs. Usage:
    rtgen.py gen   FONTFILE OUTDIR      write rt.la, rterr.la, rth.la into OUTDIR
    rtgen.py check FONTFILE OUTDIR      compare the files the VM wrote with the model
The model never runs the LA code: it decodes TF_HEX itself and recomputes every
expected byte from the font table and the contract in WM_DESIGN.md."""
import re, sys, os

# ── the font, decoded independently from TF_HEX ──────────────────────
def load_font(path):
    hexs = re.search(r'glyph TF_HEX = "([A-P]*)"', open(path).read()).group(1)
    assert len(hexs) == 1536
    return bytes((ord(hexs[2*i]) - 65) * 16 + (ord(hexs[2*i+1]) - 65) for i in range(768))

def px(r, g, b): return bytes([b, g, r, 0])

def glyph_rows(font, code):
    if not 32 <= code <= 127: code = 63          # '?'
    g = code - 32
    return font[8*g:8*g+8]

def band(font, scale, fg, bg, s, cols):
    """list of 8*scale scanlines, each cols*8*scale pixels"""
    cols = max(cols, 0)
    n = min(len(s), cols)
    out = []
    for r in range(8):
        line = bytearray()
        for i in range(cols):
            if i < n:
                rb = glyph_rows(font, s[i])[r]
                for c in range(8):
                    line += (fg if (rb >> c) & 1 else bg) * scale
            else:
                line += bg * (8 * scale)
        for _ in range(scale): out.append(bytes(line))
    return out

def compose(W, H, pitch, bg, tiles):
    if H <= 0: return b""
    fb = [[bg] * W for _ in range(H)]
    for (x, y, w, h, rows) in tiles:
        assert len(rows) == h
        for j in range(h):
            assert len(rows[j]) == 4 * w
            for i in range(w):
                fb[y+j][x+i] = rows[j][4*i:4*i+4]
    return b"".join(b"".join(row) + b"\0" * (pitch - 4*W) for row in fb)

def overlap(a, b):
    return a[0] < b[0]+b[2] and b[0] < a[0]+a[2] and a[1] < b[1]+b[3] and b[1] < a[1]+a[3] \
        and a[2] > 0 and a[3] > 0 and b[2] > 0 and b[3] > 0

# ── LA source helpers ────────────────────────────────────────────────
def la_str(bs):
    """an LA expression for the byte string bs (literal runs + chr for the rest)"""
    parts, run = [], ""
    for b in bs:
        ch = chr(b)
        if 32 <= b < 127 and ch not in '"\\#':
            run += ch
        else:
            if run: parts.append('"%s"' % run); run = ""
            parts.append('chr("%d")' % b)
    if run: parts.append('"%s"' % run)
    if not parts: return '""'
    e = parts[-1]
    for p in reversed(parts[:-1]): e = 'concat(%s)(%s)' % (p, e)
    return e

def net_parens(lines):
    """( minus ) over LA source lines, string literals excluded"""
    t = re.sub(r'"(\\.|[^"\\])*"', '""', "\n".join(lines))
    return t.count('(') - t.count(')')

def la_int(n): return str(n) if n >= 0 else 'sub(0)(%d)' % -n

def la_list(items):
    e = 'NIL'
    for it in reversed(items): e = 'CONS(%s)(%s)' % (it, e)
    return e

# ── the test cases (defined once, used by the generator and the checker) ──
FG = (250, 200, 10); BG = (5, 60, 120)
PRINT = bytes(range(32, 128))
CYC = lambda n, off=0: bytes(32 + (i * 7 + off) % 95 for i in range(n))
BAND_CASES = [   # (name, text bytes, cols)
    ("all", PRINT, 96), ("allrev", PRINT[::-1], 100), ("trunc", CYC(150, 3), 37),
    ("short", b"abc", 10), ("empty", b"", 7), ("one", b"x", 1),
    ("bad", bytes([0, 10, 31, 127, 128, 200, 255, 65, 63, 9, 126, 32]), 14),
    ("c0", b"abc", 0), ("cneg", b"abc", -2), ("emptyc0", b"", 0),
] + [("n%d" % n, CYC(n, n), n) for n in (2, 3, 5, 8, 13, 64, 65, 127, 129, 255, 300)] \
  + [("p%d" % n, CYC(n, 2 * n), n + 9) for n in (1, 7, 63, 120)]

# bands: three calls, the second with a cache holding a planted entry
BT1 = [b"alpha", b"beta", b"", b"gamma", b"beta", b"long line " + CYC(40)]
BT2 = [b"gamma", b"delta", b"alpha", b"new one", b"beta", b"new one", b""]
BCOLS = 20

def grad_rows(tid, w, h):
    return [b"".join(px(tid * 10, j * 10, i * 6) for i in range(w)) for j in range(h)]
def solid_rows(w, h, p): return [p * w] * h

# compose cases: (name, W, H, pitch, bg, tiles) with tiles (x, y, w, h, kind, arg)
#   kind "g": gradient rows (id = arg); "s": solid rows of pixel arg; "t": text band rows
CBG = (9, 8, 7)
COMPOSE_CASES = [
    ("edges", 37, 23, 4*37 + 12, CBG, [
        (30, 2, 7, 6, "g", 2), (0, 0, 5, 4, "g", 1), (15, 17, 5, 6, "g", 3),
        (6, 5, 3, 9, "s", (200, 0, 100)), (13, 0, 1, 23, "s", (0, 255, 0)),
        (20, 9, 8, 8, "t", b"H")]),
    ("full", 16, 10, 64, CBG, [(0, 0, 16, 10, "g", 4)]),
    ("blankspans", 8, 40, 40, CBG, [(1, 3, 6, 3, "g", 5), (0, 30, 8, 4, "s", (1, 2, 3))]),
    ("notiles", 10, 17, 48, CBG, []),
    ("zeroH", 10, 0, 40, CBG, [(0, 0, 3, 0, "s", (1, 1, 1))]),
    ("degenerate", 12, 9, 52, CBG, [(3, 3, 0, 4, "s", (7, 7, 7)), (5, 2, 4, 0, "s", (8, 8, 8)),
                                   (6, 4, 6, 5, "g", 6)]),
    ("three", 30, 12, 120, CBG, [(20, 1, 10, 9, "g", 9), (0, 1, 10, 9, "g", 7), (10, 1, 10, 9, "g", 8)]),
    ("many", 41, 25, 41*4 + 4, CBG, [(1 + 8*k, 2 + (k % 2), 7, 10 + k, "g", 10 + k) for k in range(5)]
                                + [(1, 17, 32, 8, "t", b"Ab~")]),
    ("text2", 64, 20, 256, CBG, [(0, 2, 32, 16, "t", b"Hi!?"), (32, 2, 32, 16, "t", b"\x01lo\x7f")]),
    # a zero-width tile at the same x as a real one, given after it, and one on the right edge
    ("zerow_tie", 7, 5, 28, CBG, [(4, 0, 3, 4, "g", 1), (4, 0, 0, 4, "s", (1, 1, 1)), (0, 0, 4, 4, "g", 2),
                                  (7, 1, 0, 3, "s", (2, 2, 2))]),
]

# seeded random cases (the same every run): bands of random bytes and lengths,
# and random layouts of non-overlapping tiles (1..6 of them, some sharing rows)
def _random_cases():
    import random
    rb = random.Random(7)
    bands = [("r%d" % i, bytes(rb.randrange(256) if rb.random() < 0.15 else rb.randrange(32, 128)
                                for _ in range(rb.randrange(0, 150))), rb.randrange(0, 140)) for i in range(12)]
    rc = random.Random(11)
    comps = []
    for i in range(24):
        Wd, Hd = rc.randrange(12, 60), rc.randrange(6, 40)
        tiles = []
        for _ in range(rc.randrange(1, 7) * 4):            # attempts
            if len(tiles) == 6: break
            w, h = rc.randrange(1, Wd // 2 + 2), rc.randrange(1, Hd // 2 + 2)
            x, y = rc.randrange(0, Wd - w + 1), rc.randrange(0, Hd - h + 1)
            if any(overlap((x, y, w, h), t[:4]) for t in tiles): continue
            kind = rc.choice("gs")
            tiles.append((x, y, w, h, kind, rc.randrange(1, 20) if kind == "g" else (rc.randrange(256), rc.randrange(256), rc.randrange(256))))
        comps.append(("rand%d" % i, Wd, Hd, 4 * Wd + rc.choice((0, 4, 12)), (rc.randrange(256), 7, 9), tiles))
    return bands, comps
RANDOM_BANDS, RANDOM_COMPOSE = _random_cases()
SCALES = (1, 2, 3)                       # scale 3 runs a subset of the band cases
SCALE3 = ("all", "short", "empty", "bad", "n13", "p63", "trunc")
def band_cases(sc): return [c for c in BAND_CASES if sc < 3 or c[0] in SCALE3]
BAND_CASES += RANDOM_BANDS
COMPOSE_CASES += RANDOM_COMPOSE

def tile_rows(font, kind, w, h, arg, scale=1):
    if kind == "g": return grad_rows(arg, w, h)
    if kind == "s": return solid_rows(w, h, px(*arg))
    if kind == "t":   # band of text arg at scale 1, cols = w/8 (h must be 8, or 16 = two bands)
        cols = w // 8
        rows = []
        while len(rows) < h:
            rows += band(font, 1, px(*FG), px(*BG), arg, cols)
        return rows[:h]
    raise ValueError(kind)

ERR_CASES = [  # (id, LA expression evaluated by MAIN, expected message fragment)
    ("overlap", 'compose(10)(10)(40)(BGP)(CONS(TL(0)(0)(4)(4)(solid(4)(4)(P1)))(CONS(TL(2)(2)(4)(4)(solid(4)(4)(P1)))(NIL)))', "tiles overlap"),
    ("right", 'compose(10)(10)(40)(BGP)(CONS(TL(8)(0)(4)(2)(solid(4)(2)(P1)))(NIL))', "outside the screen"),
    ("bottom", 'compose(10)(10)(40)(BGP)(CONS(TL(0)(8)(2)(4)(solid(2)(4)(P1)))(NIL))', "outside the screen"),
    ("negx", 'compose(10)(10)(40)(BGP)(CONS(TL(sub(0)(1))(0)(2)(2)(solid(2)(2)(P1)))(NIL))', "outside the screen"),
    ("short", 'compose(10)(10)(40)(BGP)(CONS(TL(0)(0)(2)(3)(solid(2)(2)(P1)))(NIL))', "fewer rows"),
    ("long", 'compose(10)(10)(40)(BGP)(CONS(TL(0)(0)(2)(2)(solid(2)(3)(P1)))(NIL))', "more rows"),
    ("width", 'compose(10)(10)(40)(BGP)(CONS(TL(0)(0)(3)(2)(solid(2)(2)(P1)))(NIL))', "not 4*w bytes"),
    ("pitch", 'compose(10)(10)(39)(BGP)(NIL)', "pitch is less than 4*W"),
    ("line", 'join(band1(st)(run(4096)("a"))(5000))', "longer than 4095"),
]

# the style-free operations, small enough for the C host: (file, LA expression, expected bytes)
HOST_CASES = [
    ("hv_px.bin", 'px(1)(2)(3)', px(1, 2, 3)),
    ("hv_run.bin", 'run(13)("ab")', b"ab" * 13),
    ("hv_join.bin", 'join(MAP(la i. concat("s")(int_to_str(i)))(RANGE(0)(20)))', b"".join(b"s%d" % i for i in range(20))),
    ("hv_solid.bin", 'join(solid(3)(4)(px(7)(8)(9)))', px(7, 8, 9) * 12),
    ("hv_compose.bin", 'compose(9)(7)(44)(px(9)(8)(7))(CONS(TL(5)(1)(4)(3)(GRAD(px)(join)(2)(4)(3)))'
                       '(CONS(TL(0)(0)(2)(7)(solid(2)(7)(px(200)(1)(2))))(NIL)))',
     compose(9, 7, 44, px(9, 8, 7), [(5, 1, 4, 3, grad_rows(2, 4, 3)), (0, 0, 2, 7, solid_rows(2, 7, px(200, 1, 2)))])),
]

LA_PRELUDE = r'''import("theourgia_render.la")
import("theourgia_termfont.la")
glyph LET = la v. la f. f(v)
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph NIL = la n. la c. n(n)
glyph CONS = la h. la t. la n. la c. c(h)(t)
glyph TL = la x. la y. la w. la h. la rows. la k. k(x)(y)(w)(h)(rows)
# SHAPE(list): "<length of each string>," for every string of the list
glyph SHAPE = Z(la self. la l. l(la _. "")(la h. la t. concat(str_len(h))(concat(",")(self(t)))))
glyph KIT = la font. la scale. RENDER_KIT(str_at)(ord)(str_to_int)(str_len)(chr)(int_to_str)(concat)(add)(sub)(mul)(div)(int_eq)(lt)(band)(str_eq)(error)(font)(scale)
# GRAD(px)(join)(id)(w)(h): the gradient rows of a test tile
glyph RANGE = Z(la self. la i. la n. int_eq(i)(n)(la _. NIL)(la _. CONS(i)(self(add(i)(1))(n)))(0))
glyph MAP = Z(la self. la f. la l. l(la _. NIL)(la h. la t. CONS(f(h))(self(f)(t))))
glyph GRAD = la px. la join. la id. la w. la h.
  MAP(la j. join(MAP(la i. px(mul(id)(10))(mul(j)(10))(mul(i)(6)))(RANGE(0)(w))))(RANGE(0)(h))
glyph TAKE = Z(la self. la n. la l. int_eq(n)(0)(la _. NIL)(la _. l(la _. NIL)(la h. la t. CONS(h)(self(sub(n)(1))(t))))(0))
glyph APP = Z(la self. la a. la b. a(la _. b)(la h. la t. CONS(h)(self(t)(b))))
glyph CYCLE = Z(la self. la l. la n. int_eq(n)(0)(la _. NIL)(la _. APP(l)(self(l)(sub(n)(1))))(0))
glyph FONT = TF_DECODE(str_at)(ord)(str_to_int)(str_len)(chr)(int_to_str)(concat)(add)(sub)(mul)(div)(int_eq)(TF_HEX)
'''

def gen(font, outdir):
    L = []   # LET chain lines of MAIN
    def W(name, expr): L.append('LET(write_file("%s")(%s))(la _.' % (name, expr))
    L.append('LET(FONT)(la font.')
    for sc in SCALES:
        L.append('LET(KIT(font)(%d))(la kit%d.' % (sc, sc))
        L.append('kit%d(la px%d. la run%d. la style%d. la band%d. la bands%d. la solid%d. la join%d. la compose%d.' % ((sc,) * 9))
        L.append('LET(style%d(px%d(%d)(%d)(%d))(px%d(%d)(%d)(%d)))(la st%d.' % (sc, sc, *FG, sc, *BG, sc))
    L.append('LET(px1)(la px. LET(run1)(la run. LET(join1)(la join. LET(solid1)(la solid. LET(compose1)(la compose.')
    # px / run
    W("px_a.bin", 'px(1)(2)(3)'); W("px_b.bin", 'px(255)(0)(128)')
    for name, n, s in (("run0", 0, b"ab"), ("run1", 1, b"ab"), ("run5", 5, b"ab"), ("runneg", -3, b"x"),
                       ("run1000", 1000, b"xyz"), ("run_px", 13, px(1, 2, 3)), ("run_empty", 9, b"")):
        W(name + ".bin", 'run(%s)(%s)' % (la_int(n), la_str(s)))
    # band (both scales)
    for sc in SCALES:
        for name, s, cols in band_cases(sc):
            L.append('LET(band%d(st%d)(%s)(%s))(la b.' % (sc, sc, la_str(s), la_int(cols)))
            W("band_%d_%s.bin" % (sc, name), 'join%d(b)' % sc)
            W("band_%d_%s.shape" % (sc, name), 'SHAPE(b)')
    # bands (scale 2): call 1 from NIL, call 2 from cache 1 plus planted entries
    L.append('LET(bands2(st2)(NIL)(%s)(%d))(la r1. r1(la bl1. la c1.' % (la_list([la_str(t) for t in BT1]), BCOLS))
    L.append('LET(CONS(la k. k("delta")(CONS("FAKE")(NIL)))(CONS(la k. k("omega")(CONS("OMEGA")(NIL)))(c1)))(la cp.')
    L.append('LET(bands2(st2)(cp)(%s)(%d))(la r2. r2(la bl2. la c2.' % (la_list([la_str(t) for t in BT2]), BCOLS))
    L.append('LET(bands2(st2)(c2)(NIL)(%d))(la r3. r3(la bl3. la c3.' % BCOLS)
    for tag, bl, n in (("1", "bl1", len(BT1)), ("2", "bl2", len(BT2))):
        for i in range(n):
            W("bands%s_b%d.bin" % (tag, i), 'join2(NTH(%d)(%s))' % (i, bl))
    for tag, bl, c in (("1", "bl1", "c1"), ("2", "bl2", "c2"), ("3", "bl3", "c3")):
        W("bands%s_count.txt" % tag, 'int_to_str(COUNT(%s))' % bl)
        W("bands%s_ctexts.txt" % tag, 'CTEXTS(%s)' % c)
        W("bands%s_cbands.bin" % tag, 'CBANDS(join2)(%s)' % c)
        W("bands%s_bands.bin" % tag, 'LBANDS(join2)(%s)' % bl)
    # solid
    for name, w, h, p in (("s32", 3, 2, (1, 2, 3)), ("s0w", 0, 3, (4, 5, 6)), ("s0h", 5, 0, (7, 8, 9)), ("sbig", 100, 50, (10, 20, 30))):
        L.append('LET(solid(%d)(%d)(px(%d)(%d)(%d)))(la sl.' % (w, h, *p))
        W("solid_%s.bin" % name, 'join(sl)'); W("solid_%s.shape" % name, 'SHAPE(sl)')
    # join
    W("join_nil.bin", 'join(NIL)'); W("join_one.bin", 'join(CONS("only")(NIL))')
    W("join_many.bin", 'join(MAP(la i. concat("s")(int_to_str(i)))(RANGE(0)(1000)))')
    W("join_empties.bin", 'join(%s)' % la_list(['""', '"a"', '""', '""', '"bc"', '""']))
    # compose
    for name, Wd, Hd, pitch, bgc, tiles in COMPOSE_CASES:
        tl = []
        for (x, y, w, h, kind, arg) in tiles:
            if kind == "g": rows = 'GRAD(px)(join)(%d)(%d)(%d)' % (arg, w, h)
            elif kind == "s": rows = 'solid(%d)(%d)(px(%d)(%d)(%d))' % (w, h, *arg)
            else: rows = 'TAKE(%d)(CYCLE(band1(st1)(%s)(%d))(%d))' % (h, la_str(arg), w // 8, (h + 7) // 8)
            tl.append('TL(%d)(%d)(%d)(%d)(%s)' % (x, y, w, h, rows))
        W("compose_%s.bin" % name, 'compose(%d)(%d)(%d)(px(%d)(%d)(%d))(%s)' % (Wd, Hd, pitch, *bgc, la_list(tl)))
    L.append('print("rt done")')
    opens = net_parens(L)
    src = LA_PRELUDE + PRELUDE_EXTRA + 'glyph MAIN =\n  ' + '\n  '.join(L) + ')' * opens + '\n'
    open(os.path.join(outdir, "rt.la"), "w").write(src)
    # the error program: MAIN runs case read_file("errcase.txt")
    E = ['LET(FONT)(la font.', 'LET(KIT(font)(1))(la kit1.',
         'kit1(la px. la run. la style. la band1. la bands. la solid. la join. la compose.',
         'LET(style(px(1)(1)(1))(px(0)(0)(0)))(la st.', 'LET(px(1)(2)(3))(la P1.', 'LET(px(9)(9)(9))(la BGP.',
         'LET(read_file("errcase.txt"))(la case.']
    body = 'print("no such case")'
    for cid, expr, _ in reversed(ERR_CASES):
        body = 'str_eq(case)("%s")(la _. print(SHAPE(CONS(%s)(NIL))))(la _. %s)(0)' % (cid, expr, body)
    opens = net_parens(E)
    src = LA_PRELUDE + 'glyph MAIN =\n  ' + '\n  '.join(E) + '\n  ' + body + ')' * opens + '\n'
    open(os.path.join(outdir, "rterr.la"), "w").write(src)
    # the host program: the style-free operations, small
    H = ['LET(KIT("")(1))(la kit.', 'kit(la px. la run. la style. la band. la bands. la solid. la join. la compose.']
    def WH(name, expr): H.append('LET(write_file("%s")(%s))(la _.' % (name, expr))
    for name, expr, _ in HOST_CASES: WH(name, expr)
    H.append('print("rth done")')
    opens = net_parens(H)
    hsrc = LA_PRELUDE.replace('import("theourgia_termfont.la")\n', '') \
        .replace(re.search(r'glyph FONT = .*\n', LA_PRELUDE).group(0), '')
    src = hsrc + 'glyph MAIN =\n  ' + '\n  '.join(H) + ')' * opens + '\n'
    open(os.path.join(outdir, "rth.la"), "w").write(src)

PRELUDE_EXTRA = r'''glyph COUNT = Z(la self. la l. l(la _. 0)(la h. la t. add(1)(self(t))))
glyph NTHL = Z(la self. la n. la l. int_eq(n)(0)(la _. l)(la _. l(la _. NIL)(la h. la t. self(sub(n)(1))(t)))(0))
glyph NTH = la n. la l. NTHL(n)(l)(la _. NIL)(la h. la t. h)
# CTEXTS(cache): the cache's texts, each followed by "|"
glyph CTEXTS = Z(la self. la c. c(la _. "")(la e. la t. e(la tx. la b. concat(tx)(concat("|")(self(t))))))
# CBANDS(join)(cache) / LBANDS(join)(bands): every band joined, each preceded by its byte count and ":"
glyph CBANDS = la join. Z(la self. la c. c(la _. "")(la e. la t. e(la tx. la b. (la s. concat(str_len(s))(concat(":")(concat(s)(self(t)))))(join(b)))))
glyph LBANDS = la join. Z(la self. la l. l(la _. "")(la b. la t. (la s. concat(str_len(s))(concat(":")(concat(s)(self(t)))))(join(b))))
'''

# ── the checker ──────────────────────────────────────────────────────
def check(font, outdir):
    fails = 0
    def rd(name):
        p = os.path.join(outdir, name)
        return open(p, "rb").read() if os.path.exists(p) else None
    def report(group, bad, total):
        nonlocal fails
        if bad: fails += 1; print("FAIL  render %s: %d of %d differ: %s" % (group, len(bad), total, ", ".join(bad[:8])))
        else: print("PASS  render %s: %d known answers" % (group, total))
    # px + run
    bad, tot = [], 0
    for name, want in (("px_a.bin", bytes([3, 2, 1, 0])), ("px_b.bin", bytes([128, 0, 255, 0])),
                       ("run0.bin", b""), ("run1.bin", b"ab"), ("run5.bin", b"ab" * 5), ("runneg.bin", b""),
                       ("run1000.bin", b"xyz" * 1000), ("run_px.bin", px(1, 2, 3) * 13), ("run_empty.bin", b"")):
        tot += 1
        if rd(name) != want: bad.append(name)
    report("px/run", bad, tot)
    # band
    bad, tot = [], 0
    fg, bg = px(*FG), px(*BG)
    for sc in SCALES:
        for name, s, cols in band_cases(sc):
            tot += 1
            want = band(font, sc, fg, bg, s, cols)
            got, shape = rd("band_%d_%s.bin" % (sc, name)), rd("band_%d_%s.shape" % (sc, name))
            wshape = "".join("%d," % len(x) for x in want).encode()
            if got != b"".join(want) or shape != wshape: bad.append("%s@%d" % (name, sc))
    report("band (scale 1, 2 and 3: every printable char, truncation, padding, empty, bytes outside 32..127, cols<=0, block sizes)", bad, tot)
    # bands
    bad, tot = [], 0
    def wantband(t): return b"".join(band(font, 2, fg, bg, t, BCOLS))
    def lb(bs): return b"".join(b"%d:" % len(b) + b for b in bs)
    w1 = [wantband(t) for t in BT1]
    w2 = [b"FAKE" if t == b"delta" else wantband(t) for t in BT2]
    checks = [
        ("call 1 bands", rd("bands1_bands.bin"), lb(w1)),
        ("call 1 count", rd("bands1_count.txt"), b"%d" % len(BT1)),
        ("call 1 cache texts = texts", rd("bands1_ctexts.txt"), b"".join(t + b"|" for t in BT1)),
        ("call 1 cache bands = bands", rd("bands1_cbands.bin"), lb(w1)),
        ("call 2 bands (planted delta reused)", rd("bands2_bands.bin"), lb(w2)),
        ("call 2 cache texts = texts (omega dropped)", rd("bands2_ctexts.txt"), b"".join(t + b"|" for t in BT2)),
        ("call 2 cache bands = bands", rd("bands2_cbands.bin"), lb(w2)),
        ("call 3 (no texts) bands", rd("bands3_bands.bin"), b""),
        ("call 3 cache empty", rd("bands3_ctexts.txt"), b""),
        ("call 3 count", rd("bands3_count.txt"), b"0"),
    ]
    for i in range(len(BT1)): checks.append(("call 1 band %d" % i, rd("bands1_b%d.bin" % i), w1[i]))
    for i in range(len(BT2)): checks.append(("call 2 band %d" % i, rd("bands2_b%d.bin" % i), w2[i]))
    for name, got, want in checks:
        tot += 1
        if got != want: bad.append(name)
    report("bands (cache hits, planted entry reused, cache' = exactly the texts used, duplicates)", bad, tot)
    # solid
    bad, tot = [], 0
    for name, w, h, p in (("s32", 3, 2, (1, 2, 3)), ("s0w", 0, 3, (4, 5, 6)), ("s0h", 5, 0, (7, 8, 9)), ("sbig", 100, 50, (10, 20, 30))):
        tot += 1
        rows = solid_rows(w, h, px(*p))
        if rd("solid_%s.bin" % name) != b"".join(rows) or rd("solid_%s.shape" % name) != "".join("%d," % len(r) for r in rows).encode():
            bad.append(name)
    report("solid", bad, tot)
    # join
    bad, tot = [], 0
    for name, want in (("join_nil.bin", b""), ("join_one.bin", b"only"),
                       ("join_many.bin", b"".join(b"s%d" % i for i in range(1000))), ("join_empties.bin", b"abc")):
        tot += 1
        if rd(name) != want: bad.append(name)
    report("join", bad, tot)
    # compose
    bad, tot = [], 0
    for name, Wd, Hd, pitch, bgc, tiles in COMPOSE_CASES:
        tot += 1
        rects = [(x, y, w, h) for (x, y, w, h, _, _) in tiles]
        for i in range(len(rects)):
            for j in range(i):
                assert not overlap(rects[i], rects[j]), (name, i, j)
        tl = [(x, y, w, h, tile_rows(font, kind, w, h, arg)) for (x, y, w, h, kind, arg) in tiles]
        want = compose(Wd, Hd, pitch, px(*bgc), tl)
        got = rd("compose_%s.bin" % name)
        if got != want: bad.append(name + ("(missing)" if got is None else "(%d vs %d bytes)" % (len(got), len(want))))
    report("compose (odd offsets, gaps, every screen edge, pitch padding, blank spans, unsorted, zero sizes, 3+ tiles in a row, text tiles)", bad, tot)
    return fails

if __name__ == "__main__":
    mode, fontfile, outdir = sys.argv[1:4]
    font = load_font(fontfile)
    if mode == "gen": gen(font, outdir)
    elif mode == "check": sys.exit(1 if check(font, outdir) else 0)
    elif mode == "errcases":
        for cid, _, msg in ERR_CASES: print(cid + "\t" + msg)
    elif mode == "hostcheck":     # the files of rth.la in outdir, against the model
        bad = [n for n, _, want in HOST_CASES
               if not os.path.exists(os.path.join(outdir, n)) or open(os.path.join(outdir, n), "rb").read() != want]
        print(" ".join(bad) if bad else "-")
PYEOF

python3 -I "$T/rtgen.py" gen "$T/theourgia_termfont.la" "$T" \
    || { echo "FAIL  render: the test generator did not run"; exit 1; }

# 1-2. every operation on the VM, compared byte for byte with the model
wm_vm rt.la "$T/rt.out"
if [ "$vrc" = 0 ] && grep -q '^rt done$' "$T/rt.out"; then
    echo "PASS  render (VM): the test program ran ($(ls "$T" | grep -c '\.bin$') output files)"
    python3 -I "$T/rtgen.py" check "$T/theourgia_termfont.la" "$T" || ok=0
else
    echo "FAIL  render (VM): the test program did not finish (rc=$vrc): $(cat "$T/vce" "$T/vre" 2>/dev/null | head -c 300)"; ok=0
fi

# 3. contract violations halt loudly: rc 1, the module's message, nothing printed
cp "$T/rterr.la" "$T/logos_source.la"
cp "$T/compiler.bin" "$T/logos_program.bin"
if ( cd "$T" && timeout "$WM_VM_TIMEOUT" ./logos_secd >/dev/null 2>"$T/vce" ); then
    bad=""; n=0
    while IFS=$'\t' read -r cid msg; do
        n=$((n + 1))
        printf '%s' "$cid" > "$T/errcase.txt"
        erc=0; ( cd "$T" && timeout "$WM_VM_TIMEOUT" ./logos_secd >"$T/eout" 2>"$T/eerr" ) || erc=$?
        if [ "$erc" != 1 ] || ! grep -qF "render: " "$T/eerr" || ! grep -qF "$msg" "$T/eerr" || [ -s "$T/eout" ]; then
            bad="$bad $cid(rc=$erc: $(head -c 80 "$T/eerr"))"
        fi
    done < <(python3 -I "$T/rtgen.py" errcases "$T/theourgia_termfont.la" "$T")
    if [ -z "$bad" ] && [ "$n" -gt 0 ]; then
        echo "PASS  render (VM): $n contract violations halt loudly (overlap, off screen x/y/negative, rows short/long, row width, pitch, line > 4095)"
    else
        echo "FAIL  render (VM): violations that did not halt loudly:$bad"; ok=0
    fi
else
    echo "FAIL  render (VM): the violation program did not compile: $(head -c 300 "$T/vce")"; ok=0
fi

# 4. the C host and the VM agree on the operations the host can run in time
wm_host rth.la "$T/rth_host.out"
mkdir -p "$T/host"
for f in "$T"/hv_*.bin; do [ -e "$f" ] && mv "$f" "$T/host/"; done
wm_vm rth.la "$T/rth_vm.out"
mkdir -p "$T/vm"
for f in "$T"/hv_*.bin; do [ -e "$f" ] && mv "$f" "$T/vm/"; done
hbad=$(python3 -I "$T/rtgen.py" hostcheck "$T/theourgia_termfont.la" "$T/host")
vbad=$(python3 -I "$T/rtgen.py" hostcheck "$T/theourgia_termfont.la" "$T/vm")
if [ "$hrc" = 0 ] && [ "$vrc" = 0 ] && [ "$hbad" = "-" ] && [ "$vbad" = "-" ] \
   && diff -r "$T/host" "$T/vm" >/dev/null; then
    echo "PASS  render (host): px, run, join, solid and compose give the same bytes on the C host and the VM, and both match the model"
else
    echo "FAIL  render (host): host rc=$hrc vm rc=$vrc, differing from the model: host [$hbad] vm [$vbad]"; ok=0
fi

[ "$ok" = 1 ] || exit 1
