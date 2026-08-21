#!/usr/bin/env python3
"""Zero every relocation-target field in a section extract, so a comparison
tests SEMANTICS not nasm's field-init convention.

nasm zeroes a relocated field and carries the value in the RELA addend; asm.la
writes the addend inline. Both are correct -- the linker overwrites the field
with S+A either way -- so a raw byte compare of a .o accuses asm.la of a defect
it does not have. asmelfobj.la's own header states the gate is one level up."""
import re, subprocess, sys
obj, sec, inp, out = sys.argv[1:5]
W = {'R_X86_64_64': 8, 'R_X86_64_32': 4, 'R_X86_64_32S': 4,
     'R_X86_64_PC32': 4, 'R_X86_64_PLT32': 4, 'R_X86_64_16': 2, 'R_X86_64_8': 1}
txt = subprocess.run(['readelf', '-rW', obj], capture_output=True, text=True).stdout
cur, spans = None, []
for line in txt.splitlines():
    m = re.match(r"Relocation section '\.rela(\S+)'", line.strip())
    if m:
        cur = m.group(1); continue
    f = line.split()
    if cur == sec and len(f) >= 3 and re.fullmatch(r'[0-9a-f]+', f[0]):
        w = W.get(f[2])
        if w is None:
            sys.exit(f"REFUSE: unknown reloc type {f[2]} -- cannot mask safely")
        spans.append((int(f[0], 16), w))
data = bytearray(open(inp, 'rb').read())
for off, w in spans:
    if off + w > len(data):
        sys.exit(f"REFUSE: reloc at {off:#x}+{w} exceeds section {sec} ({len(data)} B)")
    data[off:off+w] = b'\0' * w
open(out, 'wb').write(data)
print(f"{len(spans)}")
