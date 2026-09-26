# -*- coding: utf-8 -*-
"""§2 prosody derivation (2026-09-26, F20). Recomputes the captured duration witness WITHOUT prosody.la's code, from
the RENDERER that makes the sound — phonym.la — rather than prosody's own copy (DUR9), so a prosody table that drifted
from phonym disagrees:
  primitive lengths  parsed from phonym.la PHON_PRIM (PAIR(length)(gen) per primitive); A = LOVE, B = RECOGNITION
                     (prosody.la's probe pair)
  ⊕ CONP   np + pause + nq, the pause parsed from phonym.la's CONP (the /ʔ/ closure)
  ▷ DIRP   np + nq (duration preserved exactly — phonym.la's note)
  ⊂ CONTP  nq + np + nq (q frames p: B[A]B)
  ↻ MCP    2·n (reduplication AA)
Red path run on this script: a PHON_PRIM copy with LOVE's length changed moves ⊕ ▷ ⊂ ↻ together (LA_ROOT)."""
import os, re
ROOT = os.environ.get('LA_ROOT') or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = open(os.path.join(ROOT, 'phonym.la'), encoding='utf-8').read()
body = src[src.index('glyph PHON_PRIM ='):src.index('\n\n', src.index('glyph PHON_PRIM ='))]
n = {m.group(1): int(m.group(2)) for m in re.finditer(r'str_eq\(nm\)\("([A-Z]+)"\)\)\s*\(la _\. PAIR\((\d+)\)', body)}
assert len(n) == 9, n
conp = src[src.index('glyph CONP'):src.index('glyph DIRP')]
pause = int(re.search(r'PAIR\(add\(add\(np\)\((\d+)\)\)\(nq\)\)', conp).group(1))
a, b = n["LOVE"], n["RECOGNITION"]
print("WANT pro ⊕ dur=%d | ▷ dur=%d | ⊂ dur=%d | ↻ dur=%d" % (a + pause + b, a + b, b + a + b, 2 * a))
