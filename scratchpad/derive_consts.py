#!/usr/bin/env python3
"""Re-derive native_codegen3.la RT_* / *_ADDR / RTLEN / LITERAL_BASE from a
nasm -f bin -l listing + the assembled binary.  base = org 0x400078 = 4194424.

A label's absolute address = base + (file offset of its first emitted byte).
In the nasm listing a bare `label:` line carries no offset; the address is the
offset on the next listing line that emits bytes.

Usage:
  derive_consts.py <listing> <binary>            # print derived constants
  derive_consts.py <listing> <binary> --validate <native_codegen3.la>
"""
import sys, re

BASE = 4194424  # 0x400078

# glyph name in native_codegen3.la  ->  asm label
LABELS = {
    "RT_BOX_INT": "rt_box_int", "RT_MKCLO": "rt_mkclo", "RT_APPLY": "rt_apply",
    "RT_PRINT": "rt_print", "RT_ADD": "rt_add", "RT_SUB": "rt_sub",
    "RT_MUL": "rt_mul", "RT_DIV": "rt_div", "RT_MOD": "rt_mod",
    "RT_INT_EQ": "rt_int_eq", "RT_LT": "rt_lt", "RT_STR_EQ": "rt_str_eq",
    "RT_CONCAT": "rt_concat", "RT_STR_HEAD": "rt_str_head",
    "RT_STR_TAIL": "rt_str_tail", "RT_INT_TO_STR": "rt_int_to_str",
    "RT_STR_TO_INT": "rt_str_to_int", "RT_CHR": "rt_chr", "RT_ORD": "rt_ord",
    "RT_STR_LEN": "rt_str_len", "RT_ERROR": "rt_error",
    "RT_WRITE_EXEC": "rt_write_exec", "RT_WRITE_FILE": "rt_write_file",
    "RT_READ_FILE": "rt_read_file", "RT_COPY_SELF": "rt_copy_self",
    "RT_PEEK": "rt_peek", "RT_POKE": "rt_poke", "RT_SET_CR3": "rt_set_cr3",
    "RT_EXEC_AT": "rt_exec_at", "RT_SPAWN": "rt_spawn", "RT_YIELD": "rt_yield",
    "RT_MAKE_STR": "rt_make_str", "RT_INIT": "rt_init",
    "RT_SEND": "rt_send", "RT_RECV": "rt_recv",
    "RT_STACK_OVERFLOW": "rt_stack_overflow",
    "HEAP_BASE_ADDR": "HEAP_BASE", "NEXT_GC_ADDR": "NEXT_GC",
    "STACK_BASE_ADDR": "STACK_BASE", "WORKLIST_BASE_ADDR": "WORKLIST_BASE",
    "HEAP_END_ADDR": "HEAP_END", "BITMAP_BASE_ADDR": "BITMAP_BASE",
    "STACK_LIMIT_ADDR": "STACK_LIMIT",
    # optional: emitted only if present in the edited asm
    "YIELD_PENDING_ADDR": "YIELD_PENDING",
}

# listing line: "  <lineno> <8-hex-offset> <hexbytes> <source>"  (offset+bytes optional)
LINE = re.compile(r'^\s*\d+\s+([0-9A-Fa-f]{8})\s+[0-9A-Fa-f]')
LABEL = re.compile(r'^\s*\d+\s+(?:([0-9A-Fa-f]{8})\s+[0-9A-Fa-f]+\s+)?([A-Za-z_][A-Za-z0-9_]*):')

def parse(listing):
    lines = open(listing).read().splitlines()
    # offset of each line that emits bytes
    off = [None]*len(lines)
    for i, ln in enumerate(lines):
        m = LINE.match(ln)
        if m:
            off[i] = int(m.group(1), 16)
    label_off = {}
    for i, ln in enumerate(lines):
        m = LABEL.match(ln)
        if not m:
            continue
        name = m.group(2)
        if m.group(1):                       # label shares a bytes line
            label_off[name] = int(m.group(1), 16)
        else:                                # take next bytes-emitting line
            for j in range(i+1, len(lines)):
                if off[j] is not None:
                    label_off[name] = off[j]
                    break
    return label_off

def derive(listing, binary):
    label_off = parse(listing)
    rtlen = len(open(binary, 'rb').read())
    out = {}
    for g, lab in LABELS.items():
        if lab in label_off:
            out[g] = BASE + label_off[lab]
    out["RTLEN"] = rtlen
    out["LITERAL_BASE"] = BASE + rtlen
    return out

def main():
    listing, binary = sys.argv[1], sys.argv[2]
    got = derive(listing, binary)
    if len(sys.argv) > 4 and sys.argv[3] == "--validate":
        la = open(sys.argv[4]).read()
        ok = True
        for g, v in sorted(got.items()):
            m = re.search(r'glyph %s\s*=\s*(\d+)' % re.escape(g), la)
            if not m:
                print(f"  {g:22} = {v:12}  (not in .la — new)")
                continue
            cur = int(m.group(1))
            flag = "OK" if cur == v else f"*** MISMATCH .la={cur}"
            if cur != v: ok = False
            print(f"  {g:22} = {v:12}  {flag}")
        print("VALIDATION", "PASS" if ok else "FAIL")
        sys.exit(0 if ok else 1)
    for g, v in sorted(got.items()):
        print(f"glyph {g} = {v}")

if __name__ == "__main__":
    main()
