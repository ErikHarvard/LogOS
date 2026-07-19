#!/usr/bin/env bash
# LogOS POLLTEST — build the bootable BARE POLL SPIN (isolation control) (polltest.la).
#   polltest.la --(native_codegen3)--> native_codegen3_out --> kernel_polltest.elf
#   Same pipeline as HAL.4e's build_hal4e.sh: boot.asm with -D HAL4
#   (identity-maps 0..4 GiB) for the high VGA LFB BAR + the 256 MiB backbuffer at
#   0x10000000. Uses HAL.4b fill/memcpy + HAL.1 inb/outl/inl/outw + peek — all
#   already regen'd into the compiler, so NO new builtin and NO regen.
#
#   OUT OF BAND, like every heavy kernel ELF: native_codegen3's codegen is
#   superlinear in program size, so expect a LONG compile. MEASURED, not quoted:
#   HAL.4f's comp_term.la took 38m01s and 41m24s on two runs. The ROADMAP's
#   "~13 min" for HAL.4d's comp_session.la is the older, smaller program — do
#   not plan against it. The gate boots the already-built ELF; it never rebuilds.
#
#   Run the cheap pre-flights FIRST — they cost seconds and this costs a quarter
#   hour:  ./tiny_host kernel/editmodel_test.la   (the scancode decode, host-side)
set -euo pipefail
cd "$(dirname "$0")/.."          # -> the worktree root

echo "[1/4] compile polltest.la via native_codegen3 (slow — superlinear codegen)"
cp kernel/polltest.la native_input.la
# Report the codegen's exit status EXPLICITLY. A first attempt (2026-07-18) died
# after ~22 min of CPU having written nothing, and because `set -e` aborts the
# script silently on a killed child the log ended mid-step with no diagnostic —
# it was not distinguishable from "still running". A SIGKILL leaves no stderr,
# so the status is the only witness there is. `date` bookends it because the
# process may be killed by something OUTSIDE this script (the machine runs
# several build sessions at once), and then WHEN is the only clue to WHO.
echo "      codegen start: $(date +%H:%M:%S)"
set +e
time ./tiny_host native_codegen3.la >/dev/null
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

echo "[4/4] link -> kernel_polltest.elf (elf64 -> elf32-i386 container)"
ld -n -T kernel/kernel.ld kernel/boot.o -o kernel/kernel_polltest_64.elf
objcopy -O elf32-i386 kernel/kernel_polltest_64.elf kernel/kernel_polltest.elf

echo "OK: kernel/kernel_polltest.elf"
echo "POLLTEST_BUILD_DONE"
