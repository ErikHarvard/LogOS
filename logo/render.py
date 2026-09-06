#!/usr/bin/env python3
"""PNG from the grid that logos_render.la printed. Colours are the project's own
(sigil_live.la: BG=BGRX(30)(15)(25), FG=BGRX(60)(210)(255))."""
from PIL import Image, ImageDraw
import sys
src = sys.argv[1] if len(sys.argv) > 1 else 'logos_v3_grid.txt'
lines = open(src, encoding='utf-8').read().split('\n')
i = lines.index('LOGOS'); grid = lines[i+1:i+129]
assert len(grid) == 128 and all(len(r) == 128 for r in grid), "expected a 128x128 grid"
BG, FG = (25, 15, 30), (255, 210, 60)
for size in (1024, 512):
    SS = 4; pad = size//10; inner = size - 2*pad; cell = inner*SS//128
    big = Image.new('RGB', (inner*SS, inner*SS), BG); d = ImageDraw.Draw(big)
    for r in range(128):
        for c in range(128):
            if grid[r][c] == '#':
                d.rectangle([c*cell, r*cell, (c+1)*cell-1, (r+1)*cell-1], fill=FG)
    im = Image.new('RGB', (size, size), BG)
    im.paste(big.resize((inner, inner), Image.LANCZOS), (pad, pad))
    im.save(f'logos_v3_{size}.png'); print(f'wrote logos_v3_{size}.png')
