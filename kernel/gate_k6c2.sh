#!/usr/bin/env bash
# LogOS kernel K6c.2 slice gate — two ring-3 tasks exchange a typed message
# through kernel channels, with a real kernel context switch.
# Boot kernel_k6c2.elf in QEMU and assert BOTH tasks ran at ring 3 and the
# round-trip completed:
#   - "K6C2 B got IAM" — task B, resumed by the kernel after task A yielded,
#     RECV'd from channel 0 the message A deposited BEFORE the switch (the channel
#     is ring-0 memory neither task can touch directly, so this proves the switch
#     A->B carried the message through kernel-held state);
#   - "K6C2 A got YOU" — task A, RESTORED by the kernel after task B yielded back,
#     RECV'd B's reply from channel 1 and announced it. This line only appears if
#     A's full ring-3 context (stack + regs + resume rip) was correctly SAVED at
#     its yield and RESTORED — i.e. a genuine bidirectional context switch, not a
#     one-shot launch;
#   - exit code 33 — task A's exit() syscall reached isa-debug-exit.
# A broken context save/restore, a bad PCB seed, or a clobbered rcx/r11 across the
# switch would drop a line or #GP/triple-fault (exit != 33). -m 512 (one user page
# at 256 MiB), like K6a/K6c. Skips (rc 0) when QEMU is absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  K6c2 two-task IPC gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_k6c2.sh >/dev/null 2>&1 || { echo "FAIL  K6c2 gate: build_k6c2.sh failed"; exit 1; }

OUT=$(timeout 20 qemu-system-x86_64 \
        -kernel kernel/kernel_k6c2.elf -m 512 \
        -serial stdio -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown 2>/dev/null)
RC=$?
CLEAN=$(printf '%s' "$OUT" | tr -d '\0')
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 200)

ok=1
printf '%s' "$CLEAN" | grep -qF 'K6C2 B got IAM' || { echo "FAIL  K6c2: 'K6C2 B got IAM' not on serial — task B never ran or the A->B switch lost the channel message (rc=$RC, got: $seen)"; ok=0; }
printf '%s' "$CLEAN" | grep -qF 'K6C2 A got YOU' || { echo "FAIL  K6c2: 'K6C2 A got YOU' not on serial — task A was not restored after its yield, or the B->A reply was lost (context save/restore broken) (rc=$RC, got: $seen)"; ok=0; }
[ "$RC" -eq 33 ] || { echo "FAIL  K6c2: exit code != 33 (got $RC — a #GP/triple-fault in the context switch, a bad PCB seed, or a clobbered rcx/r11 broke sysret)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  K6c2 slice: two ring-3 tasks exchanged a typed message through kernel channels with a real kernel context switch — A sent + yielded, the kernel SAVED A and switched to B (which recv'd A's message from channel 0 and replied on channel 1), then the kernel RESTORED A (which recv'd the reply); both ran at CPL 3, IPC crossed the privilege boundary both ways, and A's resume proves full context save/restore (the seed of a real ring-3 process/IPC layer)"
[ "$ok" -eq 1 ]
