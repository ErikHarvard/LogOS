#!/bin/sh
# gate_link_nsec.sh — the DEFAULT layout places an ARBITRARY allocatable section
# by its SHF flags, not by a hard-coded name list.
#
# The known five families (.text/.rodata/.eh_frame/.data/.bss) are gated
# byte-identically vs ld by gate_link_reloc/_script/_e2e — that is the
# regression. THIS gate covers the new capability: a section whose name is none
# of those (.mydata, SHF_ALLOC|SHF_WRITE) must be PLACED, not refused, and must
# be loadable at run time.
#
# Per the agreed gate scope (CLAUDE.md: independent witness where the answer is
# ld's CHOICE): arbitrary-section ORDER is ld's own convention, so this does NOT
# demand link.la match ld's address for .mydata. It demands the stronger,
# semantic facts: (1) it RUNS and reads the right value back from .mydata — the
# proof the section was placed at a real, mapped, readable address and its
# relocation resolved; (2) .mydata is emitted writable-alloc; (3) W^X holds (no
# W+X segment); (4) a read+write, non-exec LOAD segment exists to hold it.
set -e
cd "$(dirname "$0")"
ok=1

command -v nasm    >/dev/null 2>&1 || { echo "SKIP  link_nsec gate: nasm absent";    exit 0; }
command -v ld       >/dev/null 2>&1 || { echo "SKIP  link_nsec gate: ld absent";      exit 0; }
command -v readelf >/dev/null 2>&1 || { echo "SKIP  link_nsec gate: readelf absent"; exit 0; }

nasm -f elf64 link_test_nsec.asm -o link_test_nsec.o

# ── ld is the witness for the EXPECTED runtime behaviour ────────────────────
ld -o link_nsec_ref link_test_nsec.o
if ./link_nsec_ref; then WANT=0; else WANT=$?; fi   # program exits with myval (42)

# ── link.la, default layout, on the same object ─────────────────────────────
printf 'link_test_nsec.o\n' > link_inputs.txt
if OUT=$(timeout 240 ./tiny_host link_reloc.la 2>&1); then :; else
    echo "FAIL  link_nsec: link.la errored (the old default layout REFUSED .mydata):"
    echo "$OUT" | tail -3
    ok=0
fi

if [ ! -x link_out ]; then
    echo "FAIL  link_nsec: no link_out emitted (.mydata was refused, not placed)"
    ok=0
else
    # (1) it RUNS and reads .mydata back — proof of correct placement + load + reloc
    if ./link_out; then GOT=0; else GOT=$?; fi
    if [ "$GOT" = "$WANT" ]; then
        echo "PASS  link_nsec: runs and reads .mydata back (exit $GOT == ld's $WANT) — the arbitrary section is placed, mapped, readable, its reloc resolved"
    else
        echo "FAIL  link_nsec: link_out exit $GOT != ld's $WANT (arbitrary section mis-placed or not loaded)"
        ok=0
    fi

    # (2) .mydata emitted writable-alloc (placed, not dropped)
    if readelf -SW link_out | grep -E '\.mydata' | grep -q 'WA'; then
        echo "PASS  link_nsec: .mydata emitted as an allocatable writable section (WA), not refused"
    else
        echo "FAIL  link_nsec: .mydata missing or not WA in the output section table"
        ok=0
    fi

    # (3) W^X — no segment is both writable and executable
    if readelf -lW link_out | grep -E 'LOAD' | grep -qE 'RWE|RWX'; then
        echo "FAIL  link_nsec: a W+X LOAD segment exists (W^X violated)"
        ok=0
    else
        echo "PASS  link_nsec: W^X holds — no writable+executable LOAD segment"
    fi

    # (4) a read+write, non-exec LOAD segment exists to carry .mydata
    if readelf -lW link_out | grep -E 'LOAD' | grep -qw 'RW'; then
        echo "PASS  link_nsec: a read+write non-exec LOAD segment exists (the RW group .mydata joins)"
    else
        echo "FAIL  link_nsec: no RW (read+write, non-exec) LOAD segment in the image"
        ok=0
    fi
fi

[ "$ok" = 1 ] && echo "link_nsec gate GREEN" || { echo "link_nsec gate RED"; exit 1; }
