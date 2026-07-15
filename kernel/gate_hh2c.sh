#!/usr/bin/env bash
# LogOS kernel HH2c slice gate — TWO isolated LA processes exchange a typed message.
# Boot kernel_hh2c.elf in QEMU and assert:
#   - "B got: HELLO-FROM-A" on serial — the kernel copied ONE image template into
#     two offset-mapped per-process regions (A at +128 MiB, B at +256 MiB), each
#     with its OWN low half and the shared kernel high half; poked a role byte so
#     the same image sends under A and receives under B. Process A send()'d
#     "HELLO-FROM-A" into the SHARED kernel channel and returned; the kernel's
#     .sys_exit switched CR3 to process B, which recv()'d it and printed it. Two
#     ISOLATED address spaces exchanging a typed message through the kernel channel;
#   - exit code 33 — process B's exit reached isa-debug-exit.
# Needs -m 512 (A's region ends ~256 MiB, B's ~384 MiB must be real RAM). A bad
# per-process map / lost channel / bad CR3 switch would #PF/triple-fault or print
# nothing. Skips (rc 0) if QEMU absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  HH2c two-process-IPC gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_hh2c.sh >/dev/null 2>&1 || { echo "FAIL  HH2c gate: build_hh2c.sh failed"; exit 1; }

OUT=$(timeout 30 qemu-system-x86_64 \
        -kernel kernel/kernel_hh2c.elf -m 512 \
        -serial stdio -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown 2>/dev/null)
RC=$?
CLEAN=$(printf '%s' "$OUT" | tr -d '\0')
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 200)

ok=1
printf '%s' "$CLEAN" | grep -qF 'B got: HELLO-FROM-A' || { echo "FAIL  HH2c: 'B got: HELLO-FROM-A' not on serial — the two-process IPC failed (bad per-process map, CR3 switch, or channel) (rc=$RC, got: $seen)"; ok=0; }
[ "$RC" -eq 33 ] || { echo "FAIL  HH2c: exit code != 33 (got $RC — a fault in a process, the exit-driven switch, or the high-kernel syscall path)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  HH2c slice: TWO ISOLATED LA PROCESSES exchanged a typed message through the kernel channel — one image template was copied into two offset-mapped per-process address spaces (own low half each, shared high-half kernel), role-poked to send under A / recv under B; A send()'d 'HELLO-FROM-A' into the SHARED channel and exited, the kernel switched CR3 to B, and B recv()'d + printed it. The full process + IPC model: isolated ring-3 LA processes talking through the kernel's nervous system."
[ "$ok" -eq 1 ]
