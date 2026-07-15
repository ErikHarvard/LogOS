#!/usr/bin/env bash
# LogOS kernel K6c.3b slice gate — THE K6c MILESTONE: two ring-3 LA tasks exchange
# a TYPED message through a kernel channel.
# Boot kernel_k6c3b.elf in QEMU. ipc2.la (compiled by native_codegen3) runs at CPL
# 3 and spawns two LA tasks via the runtime scheduler: task A ENCODEs a typed
# message ("greet"<NUL>"HELLO", the logosipc.la wire format) and send(0)s it into
# kernel channel 0, then yields; the scheduler runs task B, which recv(0)s it back
# and decodes it with MSG_TYPE / MSG_BODY, printing both. Asserts:
#   - "B rx type=greet" — task B recovered the TYPE from the wire message (the typed
#     layer travelled through the kernel channel intact);
#   - "B rx body=HELLO" — task B recovered the BODY. Since A and B are separate LA
#     tasks (own stacks) and the channel is ring-0 memory neither can touch
#     directly, these lines prove a typed message crossed A -> kernel channel -> B
#     across a task switch, from compiled Lingua Adamica;
#   - exit code 33 — the LA image's epilogue exit reached isa-debug-exit.
# Needs -m 1024 (LA heap + task stacks in the low 1 GiB must be real RAM). Skips
# (rc 0) when QEMU is absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  K6c3b milestone gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_k6c3b.sh >/dev/null 2>&1 || { echo "FAIL  K6c3b gate: build_k6c3b.sh failed"; exit 1; }

OUT=$(timeout 30 qemu-system-x86_64 \
        -kernel kernel/kernel_k6c3b.elf -m 1024 \
        -serial stdio -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown 2>/dev/null)
RC=$?
CLEAN=$(printf '%s' "$OUT" | tr -d '\0')
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 200)

ok=1
printf '%s' "$CLEAN" | grep -qF 'B rx type=greet' || { echo "FAIL  K6c3b: 'B rx type=greet' not on serial — task B did not recover the message TYPE (IPC or task switch failed) (rc=$RC, got: $seen)"; ok=0; }
printf '%s' "$CLEAN" | grep -qF 'B rx body=HELLO' || { echo "FAIL  K6c3b: 'B rx body=HELLO' not on serial — task B did not recover the BODY through the kernel channel (rc=$RC, got: $seen)"; ok=0; }
[ "$RC" -eq 33 ] || { echo "FAIL  K6c3b: exit code != 33 (got $RC — a fault in a task, the scheduler at ring 3, or the IPC syscalls)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  K6c3b MILESTONE: two ring-3 LA tasks exchanged a TYPED message through a kernel channel — task A ENCODEd 'greet'<NUL>'HELLO' and send(0)'d it into kernel channel 0 then yielded; the runtime scheduled task B, which recv(0)'d it and decoded MSG_TYPE='greet' / MSG_BODY='HELLO'; both from compiled Lingua Adamica at CPL 3. LogosIPC's typed layer now rides the kernel channel between two LA tasks — the K6c 'nervous system' gate is green."
[ "$ok" -eq 1 ]
