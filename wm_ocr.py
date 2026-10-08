#!/usr/bin/env python3
"""wm_ocr.py - read a frame of the tiling WM back into text.

The WM draws text with a known 8x8 font (theourgia_termfont.la) in known
colours, so a frame can be read exactly: find each tile by its border, then
match every character cell against the font. The gates use this to check what
the WM put on the screen, and it is handy for looking at a headless session.

A tile (theourgia_wm.la, WM_TILE): BW=2 border rows/columns in the border
colour (gold when focused, grey otherwise), then a title bar of 2 + 8*scale + 2
rows, PAD=4 rows/columns of terminal background, the text rows, filler.

A tile whose text area has the terminal background is a terminal: its text is
read in the terminal's one text colour. Any other tile is a LogosKit app
(MOD+s): its text comes in several styles, so each cell is read in whichever
of its two colours makes a glyph, and its background is kept too.

Usage: wm_ocr.py FRAME.bin W H PITCH SCALE [termfont.la]
Prints JSON: a list of tiles, each {x, y, w, h, focused, title, rows, kind,
bg}; kind is "term" or "app", bg the text area's background colour. An app
tile also has theme ("light", "dark" or "?"), zoom (1 or 2: the text scale it
is drawn at, relative to SCALE) and hl: [row, text] for every run of cells
whose background is not the tile's, i.e. the focused element.
In a terminal the cursor (glyph 127, a solid block) reads as '_'; a cell that
matches no glyph reads as '~'.
"""
import json
import os
import re
import sys

DESK = (16, 14, 28)
GOLD = (212, 175, 55)
GREY = (52, 52, 72)
TEXT_FG = (214, 214, 200)
BAR_F_FG = (24, 18, 8)
BAR_U_FG = (170, 170, 186)
TERM_BG = (10, 10, 16)
APP_THEMES = {(236, 232, 220): "light", (18, 18, 28): "dark"}
BW, PAD = 2, 4


def load_font(path):
    hexs = re.search(r'glyph TF_HEX = "([A-P]*)"', open(path).read()).group(1)
    data = [((ord(hexs[2 * i]) - 65) << 4) | (ord(hexs[2 * i + 1]) - 65) for i in range(len(hexs) // 2)]
    glyphs = {}
    for g in range(len(data) // 8):
        key = tuple(data[g * 8:g * 8 + 8])
        ch = "_" if g + 32 == 127 else chr(g + 32)
        glyphs.setdefault(key, ch)
    return glyphs


class Frame:
    def __init__(self, data, w, h, pitch):
        self.d, self.w, self.h, self.pitch = data, w, h, pitch

    def px(self, x, y):
        i = y * self.pitch + 4 * x
        return (self.d[i + 2], self.d[i + 1], self.d[i])


def read_cells(fr, glyphs, x0, y0, ncols, nrows, scale, fg):
    cw = 8 * scale
    rows = []
    for r in range(nrows):
        line = []
        for c in range(ncols):
            key = []
            for gy in range(8):
                byte = 0
                for gx in range(8):
                    if fr.px(x0 + c * cw + gx * scale, y0 + r * cw + gy * scale) == fg:
                        byte |= 1 << gx
                key.append(byte)
            line.append(glyphs.get(tuple(key), "~"))
        rows.append("".join(line).rstrip())
    return rows


def read_cells_multi(fr, glyphs, x0, y0, ncols, nrows, scale, bg):
    """Read cells drawn in several styles. Returns (rows, hl): the text, and for
    each row the runs of cells whose background is not bg."""
    cw = 8 * scale
    rows, hl = [], []
    for r in range(nrows):
        line, marks = [], []
        for c in range(ncols):
            pts = [[fr.px(x0 + c * cw + gx * scale, y0 + r * cw + gy * scale) for gx in range(8)] for gy in range(8)]
            count = {}
            for row in pts:
                for p in row:
                    count[p] = count.get(p, 0) + 1
            if len(count) == 1:
                line.append(" "); marks.append(next(iter(count)) != bg); continue
            if len(count) > 2:
                line.append("~"); marks.append(False); continue
            # the background is tried first as the commoner colour, then as bg
            order = sorted(count, key=lambda col: (col != bg, -count[col]))
            got = None
            for cbg in order:
                fg = [col for col in count if col != cbg][0]
                key = tuple(sum(1 << gx for gx in range(8) if pts[gy][gx] == fg) for gy in range(8))
                if key in glyphs and key != (255,) * 8:
                    got = (glyphs[key], cbg); break
            if got is None:
                line.append("~"); marks.append(False)
            else:
                line.append(got[0]); marks.append(got[1] != bg)
        rows.append("".join(line).rstrip())
        c = 0
        while c < ncols:
            if marks[c]:
                e = c
                while e < ncols and marks[e]:
                    e += 1
                hl.append([r, "".join(line[c:e])])
                c = e
            else:
                c += 1
    return rows, hl


def find_tiles(fr):
    tiles = []
    for y in range(fr.h):
        for x in range(fr.w):
            p = fr.px(x, y)
            if p not in (GOLD, GREY):
                continue
            left = fr.px(x - 1, y) if x > 0 else DESK
            up = fr.px(x, y - 1) if y > 0 else DESK
            if left != DESK or up != DESK:
                continue
            w = 0
            while x + w < fr.w and fr.px(x + w, y) == p:
                w += 1
            h = 0
            while y + h < fr.h and fr.px(x, y + h) == p:
                h += 1
            tiles.append((x, y, w, h, p == GOLD))
    return tiles


def ocr(fr, glyphs, scale):
    cw = 8 * scale
    out = []
    for (x, y, w, h, focused) in find_tiles(fr):
        iw = w - 2 * BW
        tcols = iw // cw
        ccols = (iw - 2 * PAD) // cw
        avail = h - 2 * BW - (cw + 4) - 2 * PAD
        nrows = avail // cw if avail >= 0 else 0
        tile = {"x": x, "y": y, "w": w, "h": h, "focused": focused, "title": "", "rows": []}
        if nrows >= 1 and ccols >= 1:
            tile["title"] = read_cells(fr, glyphs, x + BW, y + BW + 2, tcols, 1, scale,
                                       BAR_F_FG if focused else BAR_U_FG)[0]
            bg = fr.px(x + BW, y + BW + cw + 4)
            tile["bg"] = list(bg)
            if bg == TERM_BG:
                tile["kind"] = "term"
                tile["rows"] = read_cells(fr, glyphs, x + BW + PAD, y + BW + cw + 4 + PAD,
                                          ccols, nrows, scale, TEXT_FG)
            else:
                tile["kind"] = "app"
                tile["theme"] = APP_THEMES.get(bg, "?")
                # an app may ask to be drawn at twice the text scale (its zoom):
                # read it both ways and keep the reading that recognises more
                best = None
                for z in (1, 2):
                    if ccols // z < 1 or nrows // z < 1:
                        continue
                    rows, hl = read_cells_multi(fr, glyphs, x + BW + PAD, y + BW + cw + 4 + PAD,
                                                ccols // z, nrows // z, scale * z, bg)
                    score = sum(ch not in " ~" for r in rows for ch in r) - 4 * sum(r.count("~") for r in rows)
                    if best is None or score > best[0]:
                        best = (score, z, rows, hl)
                _, tile["zoom"], tile["rows"], tile["hl"] = best
        out.append(tile)
    return out


def main(argv):
    if len(argv) not in (6, 7):
        raise SystemExit(__doc__)
    font = argv[6] if len(argv) == 7 else os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                                      "theourgia_termfont.la")
    w, h, pitch, scale = (int(a) for a in argv[2:6])
    fr = Frame(open(argv[1], "rb").read(), w, h, pitch)
    print(json.dumps(ocr(fr, load_font(font), scale), indent=1))


if __name__ == "__main__":
    main(sys.argv)
