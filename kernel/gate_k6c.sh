#!/usr/bin/env bash
# LogOS kernel K6c slice gate (K6c.1) — the kernel IPC syscall service layer.
# Boot kernel_k6c.elf in QEMU and assert the ring-3 payload round-tripped a typed
# message through a KERNEL CHANNEL:
#   - "K6C t7 IAM" on serial — the payload SENT (type 7, body "IAM") into kernel
#     channel 0, then RECV'd it back; both the recovered TYPE (t7) and BODY (IAM)
#     appear, so both survived the ring-0 channel. The channel is ring-0 memory a
#     ring-3 task cannot touch directly, so these bytes ARE the proof that send()
#     and recv() were serviced ring3->ring0->ring3 (and that recv's SECOND return
#     value, the type in rdx, survived sysret);
#   - exit code 33 — the payload's exit() syscall reached isa-debug-exit.
# A broken channel copy, a bad chan bounds-check, a clobbered rcx/r11 across the
# handler (bad sysret), or a lost rdx second-return would print the wrong line or
# #GP/triple-fault (exit != 33). Same -m 512 as K6a (one user page at 256 MiB).
# Skips (rc 0) when QEMU is absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  K6c IPC gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_k6c.sh >/dev/null 2>&1 || { echo "FAIL  K6c gate: build_k6c.sh failed"; exit 1; }

OUT=$(timeout 20 qemu-system-x86_64 \
        -kernel kernel/kernel_k6c.elf -m 512 \
        -serial stdio -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown 2>/dev/null)
RC=$?
CLEAN=$(printf '%s' "$OUT" | tr -d '\0')
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 200)

ok=1
printf '%s' "$CLEAN" | grep -qF 'K6C t7 IAM' || { echo "FAIL  K6c: 'K6C t7 IAM' not on serial — the send/recv round-trip failed (bad channel copy, bounds-check, or lost type/body) (rc=$RC, got: $seen)"; ok=0; }
[ "$RC" -eq 33 ] || { echo "FAIL  K6c: exit code != 33 (got $RC — a #GP/triple-fault in the privilege drop, or a clobbered rcx/r11 across the IPC handler broke sysret)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  K6c.1 slice: the kernel IPC service layer — a ring-3 payload SENT a typed message (type 7, body 'IAM') into kernel channel 0 and RECV'd it back, both serviced ring3->ring0(channel)->ring3, then exit(0); proves send/recv syscalls carry a typed message through kernel-held channel state across the privilege boundary (the seed of LogosIPC re-homed onto the kernel)"
[ "$ok" -eq 1 ]
