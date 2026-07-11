#!/usr/bin/env python3
"""Patch native_codegen3.la in place: RT_*/*_ADDR/RTLEN/LITERAL_BASE from the
derived constants + regenerate the `glyph RT = BYTES("...")` runtime blob from
the freshly assembled binary.  Idempotent-ish: only rewrites the listed glyphs."""
import re, sys
sys.path.insert(0, "scratchpad")
import derive_consts as dc

LA = "native_codegen3.la"
listing, binary = "/tmp/rt_fix.lst", "/tmp/rt_fix.bin"

consts = dc.derive(listing, binary)
# don't inject YIELD_PENDING_ADDR unless the .la already references it
src = open(LA).read()
if "YIELD_PENDING_ADDR" not in src:
    consts.pop("YIELD_PENDING_ADDR", None)

rt_bytes = " ".join(str(b) for b in open(binary, "rb").read())

n = 0
for g, v in consts.items():
    pat = re.compile(r'(glyph %s\s*=\s*)\d+' % re.escape(g))
    src, k = pat.subn(lambda m: m.group(1) + str(v), src)
    if k != 1:
        print(f"WARN: glyph {g} matched {k} times")
    n += k

# replace the RT blob: glyph RT = BYTES("....")
rt_pat = re.compile(r'(glyph RT\s*=\s*BYTES\(")[^"]*("\))')
src, k = rt_pat.subn(lambda m: m.group(1) + rt_bytes + m.group(2), src)
assert k == 1, f"RT blob matched {k} times"

open(LA, "w").write(src)
print(f"patched {n} constant glyphs + RT blob (RTLEN={consts['RTLEN']}, "
      f"LITERAL_BASE={consts['LITERAL_BASE']}, RT bytes={len(rt_bytes.split())})")
