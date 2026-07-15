#!/usr/bin/env bash
# LogOS kernel K6c.3a slice gate — a REAL LA process does IPC at ring 3.
# Boot kernel_k6c3.elf in QEMU and assert that the LA image (ipc_kernel.la),
# running at CPL 3, round-tripped a message through the kernel channel:
#   - "K6C3 IPC OK" on serial — the LA program's send(0)("K6C3 IPC OK") lowered to
#     a SYS_SEND syscall that deposited the bytes into kernel channel 0, and its
#     recv(0) lowered to SYS_RECV and withdrew them; print() then wrote the
#     recovered string to COM1. A ring-3 task cannot touch the ring-0 channel or
#     COM1 directly, so these bytes prove the LA->kernel IPC path worked end to end
#     (send + recv serviced ring3->ring0(channel)->ring3, then a real string built
#     by rt_recv from the channel bytes);
#   - exit code 33 — the LA image's epilogue exit reached isa-debug-exit.
# Needs -m 1024 (the LA heap + 128 MiB stack in the low 1 GiB must be real RAM),
# like K6b. Skips (rc 0) when QEMU is absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  K6c3 ring-3 LA-IPC gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_k6c3.sh >/dev/null 2>&1 || { echo "FAIL  K6c3 gate: build_k6c3.sh failed"; exit 1; }

OUT=$(timeout 30 qemu-system-x86_64 \
        -kernel kernel/kernel_k6c3.elf -m 1024 \
        -serial stdio -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown 2>/dev/null)
RC=$?
CLEAN=$(printf '%s' "$OUT" | tr -d '\0')
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 200)

ok=1
printf '%s' "$CLEAN" | grep -qF 'K6C3 IPC OK' || { echo "FAIL  K6c3: 'K6C3 IPC OK' not on serial — the LA send/recv round-trip through the kernel channel failed (rc=$RC, got: $seen)"; ok=0; }
[ "$RC" -eq 33 ] || { echo "FAIL  K6c3: exit code != 33 (got $RC — a fault in the LA image, the privilege drop, or the IPC syscalls)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  K6c3a slice: a REAL LA process at ring 3 did IPC — ipc_kernel.la's send(0)(msg) deposited a message into kernel channel 0 and recv(0) withdrew it (both serviced ring3->ring0->ring3), then print()'d the recovered 'K6C3 IPC OK' and exit(0)'d; proves native_codegen3's send/recv builtins drive the kernel IPC channel from a compiled LA program (LogosIPC's transport re-homed onto the kernel, called from Lingua Adamica)"
[ "$ok" -eq 1 ]
