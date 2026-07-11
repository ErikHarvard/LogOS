#!/usr/bin/env bash
# LogOS kernel K6a slice gate — ring-3 user mode on the metal.
# Boot kernel_k6a.elf in QEMU and assert the user payload:
#   - ran at CPL 3 (it reads its own CS privilege into the message: "K6A CPL=3");
#   - reached the kernel through the `syscall` instruction and the kernel
#     SERVICED write() to COM1 then sysret'd back to ring 3 (a ring-3 task cannot
#     touch COM1 directly, so the bytes appearing on serial IS the proof the
#     syscall path worked both ways);
#   - then exit()ed cleanly (QEMU 33).
# A broken privilege drop / missing U-bit / bad sysret would #GP or triple-fault
# (exit != 33) or print nothing. Skips (rc 0) when QEMU is absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  K6a ring-3 gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_k6a.sh >/dev/null 2>&1 || { echo "FAIL  K6a gate: build_k6a.sh failed"; exit 1; }

OUT=$(timeout 20 qemu-system-x86_64 \
        -kernel kernel/kernel_k6a.elf -m 256 \
        -serial stdio -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown 2>/dev/null)
RC=$?
CLEAN=$(printf '%s' "$OUT" | tr -d '\0')
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 200)

ok=1
printf '%s' "$CLEAN" | grep -q 'K6A CPL=3' || { echo "FAIL  K6a: no 'K6A CPL=3' — the ring-3 payload never ran, ran at the wrong CPL, or the syscall service failed (rc=$RC, got: $seen)"; ok=0; }
[ "$RC" -eq 33 ] || { echo "FAIL  K6a: exit code != 33 (got $RC — a #GP/triple-fault in the privilege drop, or a bad sysret)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  K6a slice: ring-3 user mode on the metal — a payload at CPL 3 (on a U=1 page at 256 MiB) entered the kernel via syscall, which serviced write() to COM1 and sysret'd back to ring 3, then exit(0); proves ring-3 GDT selectors + TSS(RSP0) + iretq-to-ring-3 + syscall/sysret + user page mapping (b_tau == f_tau at the privilege boundary)"
[ "$ok" -eq 1 ]
