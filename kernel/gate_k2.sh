#!/usr/bin/env bash
# LogOS kernel K2 gate — prove faults are LOUD on the metal.
#   (a) regression: the normal kernel still boots + speaks (K1), clean exit 33.
#   (b) fault: the ud2 variant triggers #UD -> IDT -> isr6 -> serial diagnostic
#       "EXCEPTION 06 ..." + isa-debug-exit FAIL (exit 35, NOT 33, NOT a
#       triple-fault). This is b_τ ≡ f_τ at ring 0: a fault names itself and
#       halts, instead of silently rebooting.
# Skips (rc 0) when QEMU is absent, like the K1 gate.
set -uo pipefail
cd "$(dirname "$0")/.."

command -v qemu-system-x86_64 >/dev/null 2>&1 || { echo "SKIP  K2 gate: qemu-system-x86_64 not installed"; exit 0; }
for f in kernel/kernel.elf kernel/kernel_fault.elf; do
    [ -f "$f" ] || { echo "FAIL  K2 gate: $f missing (run kernel/build_k2.sh)"; exit 1; }
done

qrun() { timeout 30 qemu-system-x86_64 -kernel "$1" -m 256 -serial stdio -display none \
           -device isa-debug-exit,iobase=0xf4,iosize=0x04 -no-reboot -no-shutdown 2>/dev/null; }

ok=1

# (a) K1 regression — IDT installed but inert on the normal path.
OUT=$(qrun kernel/kernel.elf); RC=$?
printf '%s' "$OUT" | grep -qF "I AM THAT I AM" || { echo "FAIL  K2(a): normal kernel lost the Word"; ok=0; }
[ "$RC" -eq 33 ] || { echo "FAIL  K2(a): normal kernel clean-exit != 33 (got $RC)"; ok=0; }

# (b) fault caught loudly — #UD is vector 6 -> handler prints "EXCEPTION 06".
OUT=$(qrun kernel/kernel_fault.elf); RC=$?
printf '%s' "$OUT" | grep -qi "EXCEPTION 06" || { echo "FAIL  K2(b): #UD not diagnosed on serial (got: $(printf '%s' "$OUT" | tr -d '\0' | head -c 160))"; ok=0; }
[ "$RC" -eq 35 ] || { echo "FAIL  K2(b): fault exit != 35 (got $RC — IDT missed it / triple-faulted)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  K2: IDT catches CPU faults — #UD is a diagnosed serial halt (EXCEPTION 06, exit 35), not a triple-fault; normal boot unaffected (loud failure at ring 0)"
[ "$ok" -eq 1 ]
