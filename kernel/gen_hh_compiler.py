#!/usr/bin/env python3
"""Generate native_codegen3_hh.la — a KERNEL-ONLY higher-half compiler variant.

It is native_codegen3.la with every ADDRESS constant rebased from the low base
(0x400000) into the −2 GiB half (0xFFFFFFFF80000000). Because a sign-extended
disp32/imm64 reaches the high half, NO opcodes change — only address values:
  high_signed(addr) = addr − 2^31         (since HIGH_BASE − 2^64 = −0x80000000)
and, since this LA has no negative literals, each is written `sub(0)(magnitude)`
(the constant fold collapses it to the 2's-complement literal at compile time).
The embedded RT blob is replaced by native_codegen3_rt.asm re-assembled at the
high org (0xFFFFFFFF80400078). HEAP_SIZE is shrunk to fit the mapped high 1 GiB
window so HEAP_END = HEAP_BASE + HEAP_SIZE neither wraps 2^64 nor leaves the map.

native_codegen3.la (the Stage-4 self-host) is NOT touched — this is a separate,
kernel-only build artifact.
"""
import re, subprocess, sys, os

HIGH = 2147483648          # 2^31
HEAP_SIZE_HH = 0x30000000  # 768 MiB — HEAP_END stays inside the high 1 GiB window
os.chdir(os.path.join(os.path.dirname(__file__), ".."))

# Rebase EVERY address glyph by pattern: a glyph named RT_* / *_ADDR / VADDR /
# LITERAL_BASE that is bound to a NUMBER. This robustly catches all of them
# (RT_INIT was easy to miss by hand) while excluding the RT_BIN/RT_UN dispatch
# lambdas (not numbers) and the size constants HEAP_SIZE/WL_SIZE/BITMAP_SIZE/RTLEN
# (names don't match the address pattern), which must NOT move.
ADDR_RE = re.compile(r'(glyph (?:RT_[A-Z0-9_]+|[A-Z0-9_]+_ADDR|VADDR|LITERAL_BASE)\s*=\s*)(\d+)\b')
src = open("native_codegen3.la").read()
def rebase(m):
    mag = HIGH - int(m.group(2))
    assert 0 < mag < HIGH, f"addr out of low range: {m.group(0)}"
    return m.group(1) + f"sub(0)({mag})"
src, n = ADDR_RE.subn(rebase, src)

# shrink HEAP_SIZE (and BITMAP_SIZE = HEAP_SIZE/64) to fit the high 1 GiB window
src = re.sub(r'(glyph HEAP_SIZE\s*=\s*)\d+', lambda m: m.group(1)+str(HEAP_SIZE_HH), src)
src = re.sub(r'(glyph BITMAP_SIZE\s*=\s*)\d+', lambda m: m.group(1)+str(HEAP_SIZE_HH//64), src)

# high RT blob: re-assemble rt.asm at the high org
subprocess.run(["nasm","-f","bin","-DRT_ORG=0xFFFFFFFF80400078",
                "native_codegen3_rt.asm","-o","/tmp/rt_hh.bin"], check=True)
hi = " ".join(str(b) for b in open("/tmp/rt_hh.bin","rb").read())
src = re.sub(r'(glyph RT\s*=\s*BYTES\(")[^"]*("\))', lambda m: m.group(1)+hi+m.group(2), src, count=1)

open("native_codegen3_hh.la","w").write(src)
print(f"native_codegen3_hh.la: rebased {n} address glyphs, HEAP_SIZE={HEAP_SIZE_HH:#x}, high RT blob")
