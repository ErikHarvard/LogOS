#!/usr/bin/env python3
"""Re-derive native_codegen3.la RT_* / *_ADDR / RTLEN / LITERAL_BASE from a
nasm -f bin -l listing + the assembled binary.  base = org 0x400078 = 4194424.

A label's absolute address = base + (file offset of its first emitted byte).
In the nasm listing a bare `label:` line carries no offset; the address is the
offset on the next listing line that emits bytes.

Usage:
  derive_consts.py <listing> <binary>            # print derived constants
  derive_consts.py <listing> <binary> --validate <native_codegen3.la>
  derive_consts.py --selftest                    # negative controls, no inputs

EVERY derived constant must have a declared consumer that is actually checked.
A constant consumed outside native_codegen3.la goes in EXTERNAL; one that is
genuinely consumed nowhere goes in UNCONSUMED with a reason. Anything else is
a FAIL, because the alternative is what happened on 2026-08-28: YIELD_PENDING
moved 45 bytes in 0b031c6, and this tool -- which derives it correctly -- said
"(not in .la -- new)" and exited PASS. It looked, found nothing, and reported
success. The only check on that constant was build_k5b2.sh's drift guard, which
runs only when K5b.2 runs, so the stale equ survived until a full build reached
the kernel section.
"""
import sys, re, os

BASE = 4194424  # 0x400078
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # -> ~/logos

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
    "RT_INB": "rt_inb", "RT_INL": "rt_inl",
    "RT_OUTB": "rt_outb", "RT_OUTL": "rt_outl",
    "RT_INW": "rt_inw", "RT_OUTW": "rt_outw",
    "RT_BAND": "rt_band",
    "RT_BOR": "rt_bor",
    "RT_BXOR": "rt_bxor",
    "RT_BSHL": "rt_bshl",
    "RT_BSHR": "rt_bshr",
    "RT_BNOT": "rt_bnot",
    "RT_FILL": "rt_fill", "RT_MEMCPY": "rt_memcpy",
    "RT_STACK_OVERFLOW": "rt_stack_overflow",
    "HEAP_BASE_ADDR": "HEAP_BASE", "NEXT_GC_ADDR": "NEXT_GC",
    "STACK_BASE_ADDR": "STACK_BASE", "WORKLIST_BASE_ADDR": "WORKLIST_BASE",
    "HEAP_END_ADDR": "HEAP_END", "BITMAP_BASE_ADDR": "BITMAP_BASE",
    "STACK_LIMIT_ADDR": "STACK_LIMIT",
    # consumed by kernel/timer.asm, NOT by native_codegen3.la -- see EXTERNAL
    "YIELD_PENDING_ADDR": "YIELD_PENDING",
}

# Constants whose consumer is a file OTHER than native_codegen3.la.
#   glyph -> (path relative to repo root, regex with ONE group holding the value)
# A missing file, or a regex that does not match, is a FAIL and never a skip:
# the tool must prove it looked at the thing it claims to have validated.
EXTERNAL = {
    "YIELD_PENDING_ADDR": (
        "kernel/timer.asm",
        re.compile(r'YIELD_PENDING_ABS\s+equ\s+(0x[0-9A-Fa-f]+|\d+)'),
    ),
}

# Derived but deliberately consumed nowhere. Each needs a reason. Empty today:
# every constant this tool derives is checked against a real consumer.
UNCONSUMED = {}

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

def _num(t):
    return int(t, 16) if t.lower().startswith("0x") else int(t, 10)

def check_external(g, value, read=None):
    """Validate one constant against its non-.la consumer.

    Returns (ok, detail). It can only return ok=True having actually matched a
    value out of the file: an unreadable file and an absent equ are FAILURES,
    not skips. That asymmetry is the whole point of this function.
    """
    path, rx = EXTERNAL[g]
    try:
        text = read(path) if read else open(os.path.join(ROOT, path)).read()
    except OSError as e:
        return False, f"*** UNREADABLE {path} ({e.__class__.__name__})"
    m = rx.search(text)
    if not m:
        return False, f"*** ABSENT from {path} — the site this tool claims to check is not there"
    cur = _num(m.group(1))
    if cur != value:
        return False, f"*** MISMATCH {path}={cur}"
    return True, f"OK ({path})"

def validate(got, la, read=None):
    """(ok, rows). Every derived constant must reach a consumer that was checked."""
    ok, rows = True, []
    for g, v in sorted(got.items()):
        m = re.search(r'glyph %s\s*=\s*(\d+)' % re.escape(g), la)
        if m:
            cur = int(m.group(1))
            good = (cur == v)
            rows.append((g, v, "OK" if good else f"*** MISMATCH .la={cur}"))
        elif g in EXTERNAL:
            good, detail = check_external(g, v, read)
            rows.append((g, v, detail))
        elif g in UNCONSUMED:
            good = True
            rows.append((g, v, f"unconsumed ({UNCONSUMED[g]})"))
        else:
            good = False
            rows.append((g, v, "*** UNCHECKED — absent from the .la, no EXTERNAL "
                               "consumer, not in UNCONSUMED. Declare where it is used."))
        ok = ok and good
    return ok, rows

def _boom(_):
    raise OSError("simulated missing file")

def selftest():
    """Negative controls. Each case asserts the verdict this tool MUST reach.

    Case 2 is the 2026-08-28 defect itself; case 5 is the shape that hid it (a
    derived constant nothing checks, formerly printed as "(not in .la — new)"
    and counted toward PASS). Both must be RED here forever.
    """
    good = "YIELD_PENDING_ABS equ 0x4013dd  ; = 4199389\n"
    Y = {"YIELD_PENDING_ADDR": 4199389}
    cases = [
        ("external equ agrees",                Y, "", lambda p: good, True),
        ("external equ STALE (the 08-28 bug)", Y, "", lambda p: "YIELD_PENDING_ABS equ 0x4013b0\n", False),
        ("external equ DELETED",               Y, "", lambda p: "; no equ here\n", False),
        ("external file UNREADABLE",           Y, "", _boom, False),
        ("derived, but NO consumer declared",  {"NEW_SLOT_ADDR": 123}, "", lambda p: good, False),
        (".la value agrees",                   {"RT_ADD": 7}, "glyph RT_ADD = 7\n", None, True),
        (".la value differs",                  {"RT_ADD": 7}, "glyph RT_ADD = 8\n", None, False),
        ("decimal equ accepted",               Y, "", lambda p: "YIELD_PENDING_ABS equ 4199389\n", True),
    ]
    bad = 0
    for name, got, la, read, want in cases:
        ok, rows = validate(got, la, read)
        mark = "ok " if ok == want else "BAD"
        if ok != want: bad += 1
        print(f"  [{mark}] {name:38} expected {'PASS' if want else 'FAIL'}, got {'PASS' if ok else 'FAIL'}")
        for _, _, d in rows:
            if d.startswith("***"): print(f"          {d}")
    # The registry must also be self-consistent, or a typo silently disables a check.
    for g in EXTERNAL:
        if g not in LABELS:
            print(f"  [BAD] EXTERNAL names {g}, which LABELS never derives"); bad += 1
    print("SELFTEST", "PASS" if bad == 0 else f"FAIL ({bad})")
    sys.exit(0 if bad == 0 else 1)

def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--selftest":
        selftest()
    listing, binary = sys.argv[1], sys.argv[2]
    got = derive(listing, binary)
    if len(sys.argv) > 4 and sys.argv[3] == "--validate":
        ok, rows = validate(got, open(sys.argv[4]).read())
        for g, v, detail in rows:
            print(f"  {g:22} = {v:12}  {detail}")
        print("VALIDATION", "PASS" if ok else "FAIL")
        sys.exit(0 if ok else 1)
    for g, v in sorted(got.items()):
        print(f"glyph {g} = {v}")

if __name__ == "__main__":
    main()
