#!/usr/bin/env bash
# LogOS HAL.4f — build the bootable TYPEWRITER (comp_term_hal4f.la).
#   comp_term_hal4f.la --(native_codegen3)--> native_codegen3_out --> kernel_comp_term_hal4f.elf
#   Same pipeline as HAL.4e's build_hal4e.sh: boot.asm with -D HAL4
#   (identity-maps 0..4 GiB) for the high VGA LFB BAR + the 256 MiB backbuffer at
#   0x10000000. Uses HAL.4b fill/memcpy + HAL.1 inb/outl/inl/outw + peek — all
#   already regen'd into the compiler, so NO new builtin and NO regen.
#
# ★ 2026-09-10 — THIS BUILT THE WRONG PROGRAM FOR FIVE DAYS. It compiled
#   kernel/comp_term.la into kernel_comp_term.elf. The merge e5cefe7 (2026-09-05)
#   brought kernel-k1's comp_term.la — the terminal window kernel/build_comp_term.sh
#   builds, a DIFFERENT program — over HAL.4f's typewriter under the same name, and
#   both builders wrote the same ELF. So gate_hal4f.sh booted the terminal window
#   and judged it against the typewriter's serial protocol: it never printed
#   "term buf=LOGOS", its ENTER newlines instead of ending the loop, and the 90 s
#   timeout fired. I reported that (da04585) as "a real HAL.4f regression". It was
#   not: the subject had been replaced. The typewriter is restored byte-for-byte
#   from 5b60997 as kernel/comp_term_hal4f.la and builds to its OWN ELF name, so no
#   other builder can overwrite what this gate boots.
#
#   The compile goes through kernel/ncc3.sh — the committed native compiler — so it
#   takes seconds, not the ~40 minutes the interpreted path cost in July.
#
#   Cheap pre-flight, host-side:  ./tiny_host kernel/keymap_test.la  (scancode decode)
set -euo pipefail
cd "$(dirname "$0")/.."          # -> the worktree root

echo "[1/4] compile comp_term_hal4f.la via native_codegen3 (kernel/ncc3.sh)"
cp kernel/comp_term_hal4f.la native_input.la
rm -f native_codegen3_out        # a stale output must not pass for this compile's
# Report the codegen's exit status EXPLICITLY. A first attempt (2026-07-18) died
# after ~22 min of CPU having written nothing, and because `set -e` aborts the
# script silently on a killed child the log ended mid-step with no diagnostic —
# it was not distinguishable from "still running". A SIGKILL leaves no stderr,
# so the status is the only witness there is. `date` bookends it because the
# process may be killed by something OUTSIDE this script (the machine runs
# several build sessions at once), and then WHEN is the only clue to WHO.
echo "      codegen start: $(date +%H:%M:%S)"
set +e
time bash kernel/ncc3.sh >/dev/null
CGRC=$?
set -e
echo "      codegen end:   $(date +%H:%M:%S)  exit=$CGRC"
if [ "$CGRC" -ne 0 ]; then
    echo "FAIL: native_codegen3 exited $CGRC (137=SIGKILL, 143=SIGTERM — killed from outside, not a compile error)"
    exit "$CGRC"
fi
[ -f native_codegen3_out ] || { echo "FAIL: codegen exited 0 but wrote no native_codegen3_out"; exit 1; }
ENTRY=$(readelf -h native_codegen3_out | awk '/Entry point/{print $NF}')
echo "      e_entry (LA prol) = $ENTRY"

echo "[2/4] generate entry.inc"
printf 'LA_ENTRY equ %s\n' "$ENTRY" > kernel/entry.inc

echo "[3/4] assemble boot.asm (-D HAL4: identity-map 0..4 GiB)"
nasm -f elf64 -D HAL4 -i kernel/ kernel/boot.asm -o kernel/boot.o

echo "[4/4] link -> kernel_comp_term_hal4f.elf (elf64 -> elf32-i386 container)"
ld -n -T kernel/kernel.ld kernel/boot.o -o kernel/kernel_comp_term_hal4f_64.elf
objcopy -O elf32-i386 kernel/kernel_comp_term_hal4f_64.elf kernel/kernel_comp_term_hal4f.elf

echo "OK: kernel/kernel_comp_term_hal4f.elf"
echo "HAL4F_BUILD_DONE"
