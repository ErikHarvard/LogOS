#!/usr/bin/env bash
# LogOS HAL idle-survival gate — DOES A METAL COMPOSITOR SURVIVE DOING NOTHING?
#
# ── WHY THIS EXISTS ─────────────────────────────────────────────────────────
# Every other HAL gate drives a ~20 second interactive session and then exits.
# None of them asserts that the kernel is still ALIVE afterwards, so none of
# them could ever witness a failure that takes a minute — and there is one:
#
#   MEASURED 2026-07-18, three ELFs, ZERO keystrokes, left alone for 90 s:
#     comp_text (HAL.4e)  EXCEPTION 0e  rip=0x04454db8  <- 346 KB INTO THE HEAP
#     comp_term (HAL.4f)  EXCEPTION 06  rip=0x07ffff21  <- 223 B below stack top
#     comp_edit (HAL.4g)  EXCEPTION 06  rip=0x07fffca3  <- 861 B below stack top
#
# The LA heap grows UP from 68.0 MiB and nothing bounds it below 16.07 GiB
# (`alloc24` only tests `HEAP_END`, which PROL sets to hb + 16 GiB — a size that
# makes sense on Linux as lazily-mapped address space and none at all on a
# 512 MiB machine). `POLL` boxes an int on EVERY spin iteration, so an IDLE
# compositor allocates hard. The runtime does TCO, so the loop's live frames are
# the top few hundred bytes below LA_STACK_TOP — the heap crosses the unused gap
# harmlessly and destroys those. A return address becomes a heap pointer and
# control lands in garbage. comp_text's rip sitting INSIDE the heap is the
# direct evidence; the differing exception vectors (00/06/0e) are only what the
# garbage decoded to, which is why the vector was never the signal.
#
# ── THIS GATE IS EXPECTED TO BE RED ─────────────────────────────────────────
# It is committed RED on purpose. The defect is in the SUBSTRATE
# (native_codegen3_rt.asm / rt_init — track A's file), not in any comp_*.la, so
# track D cannot fix it and will not paper over it. A red gate that names a real
# defect is worth more than a suite that runs for 20 s and calls it green.
#
# It reports TIME-TO-DEATH per ELF rather than a bare pass/fail, so it produces
# a NUMBER that tracks progress: when the heap bound is clamped the failure
# should turn into a LOUD HALT (`native: heap exhausted`) instead of an
# exception, and this gate distinguishes those two outcomes explicitly — a loud
# halt is a CORRECT failure and is reported as such, not lumped in with
# corruption.
#
# Usage: kernel/gate_hal_idle.sh [idle_seconds]   (default 90)
# Skips (rc 0) if QEMU is absent or no compositor ELF has been built.
set -uo pipefail
cd "$(dirname "$0")/.."

BUDGET="${1:-90}"

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  HAL idle-survival gate: qemu-system-x86_64 not installed"
    exit 0
fi

ok=1
found=0

for pair in "kernel_comp_text.elf:text:HAL.4e" \
            "kernel_comp_term.elf:term:HAL.4f" \
            "kernel_comp_edit.elf:edit:HAL.4g"; do
    elf="kernel/${pair%%:*}"; rest="${pair#*:}"; tag="${rest%%:*}"; name="${rest##*:}"
    [ -f "$elf" ] || continue
    found=1

    SERF=$(mktemp)
    # NO MONITOR, NO STDIN. The idle test sends nothing, so it needs no monitor
    # at all — and dropping it is what makes the timing HONEST. A first version
    # piped a `sleep $BUDGET` into `-monitor stdio`; the shell then waited for
    # BOTH ends of the pipe, so the elapsed time was always ~$BUDGET no matter
    # when the guest actually died. It reported "~91s" for a kernel that died at
    # 60 — a number that could not discriminate, which is the exact defect this
    # suite keeps finding elsewhere. Timing QEMU DIRECTLY fixes it: with nothing
    # writing to it, QEMU exits precisely when the guest faults, and `timeout`
    # kills it at the budget only if it survived.
    START=$(date +%s)
    timeout "$BUDGET" qemu-system-x86_64 \
            -kernel "$elf" -m 512 \
            -vga std -monitor none -serial "file:$SERF" -display none \
            -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
            -no-reboot -no-shutdown < /dev/null >/dev/null 2>&1
    RC=$?
    END=$(date +%s)
    LIVED=$((END - START))
    SER=$(tr -d '\0' < "$SERF"); rm -f "$SERF"

    EXC=$(printf '%s' "$SER" | grep -a -o 'EXCEPTION [0-9a-f]* err=[0-9a-f]* rip=[0-9a-f]*' | head -1)
    HALT=$(printf '%s' "$SER" | grep -a -o 'native: [a-z ]*' | head -1)

    if printf '%s' "$SER" | grep -q "$tag ready"; then :; else
        echo "FAIL  idle/$name: never armed ('$tag ready' absent) — cannot judge survival"; ok=0; continue
    fi

    if [ -n "$EXC" ]; then
        # Corruption: control reached garbage. The worst outcome.
        echo "FAIL  idle/$name: DIED after ~${LIVED}s idle — $EXC"
        echo "        (control transferred into garbage: the heap overwrote the live stack frames)"
        ok=0
    elif [ -n "$HALT" ]; then
        # A loud halt is a CORRECT failure — the guard fired instead of the heap
        # silently eating the stack. Still not survival, but it is the outcome
        # the clamp is supposed to produce, so it is reported apart from FAIL.
        echo "GUARD idle/$name: halted loudly after ~${LIVED}s idle — '$HALT'"
        echo "        (this is the CORRECT failure mode: a diagnostic, not corruption)"
        ok=0
    elif [ "$RC" -eq 124 ]; then
        # timeout killed a still-running guest: it survived the whole budget.
        echo "  ok  idle/$name: survived ${BUDGET}s idle with no exception"
    else
        echo "FAIL  idle/$name: exited rc=$RC after ~${LIVED}s idle with no exception and no halt (unexplained)"; ok=0
    fi
done

if [ "$found" -eq 0 ]; then
    echo "SKIP  HAL idle-survival gate: no compositor ELF built (see kernel/build_hal4[efg].sh)"
    exit 0
fi

if [ "$ok" -eq 1 ]; then
    echo "PASS  HAL idle-survival: every built compositor survived ${BUDGET}s of doing nothing."
else
    echo "FAIL  HAL idle-survival: a metal compositor does not survive being left alone."
    echo "      This is a SUBSTRATE defect, not a compositor one — the LA heap is unbounded"
    echo "      below HEAP_END=16.07 GiB while the stack sits at 128 MiB, and POLL boxes an"
    echo "      int per spin so an idle kernel allocates hard. The fix is in rt_init"
    echo "      (native_codegen3_rt.asm, track A). See ~/logos-status.md."
fi
[ "$ok" -eq 1 ]
