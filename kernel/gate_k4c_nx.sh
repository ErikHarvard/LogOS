#!/usr/bin/env bash
# LogOS kernel K4c (second slice) gate — NX ENFORCEMENT on the METAL.
# Boot kernel_nx.elf in QEMU and assert the LA image:
#   (1) allocates a real PMM frame for the PML4 — "K4C NX FRAME <n>";
#   (2) builds a 4-level page table in real frames with a NO-EXECUTE high test
#       page (PDPT[1]->PD1[0]->phys 160 MiB, NX@bit63) at vaddr 0x40000000 over a
#       frame holding a lone `ret` (0xC3), loads CR3, and peeks the ret byte back
#       through the identity map — the frame is live:  "K4C NX ARMED 195";
#   (3) then EXECUTES through the high NO-EXECUTE vaddr (exec_at). With EFER.NXE
#       armed the instruction FETCH raises a page-protection #PF (vector 14, err
#       bit 4 = I/D) — NX is ENFORCED, the `ret` never runs. K2's IDT diagnoses
#       it loudly:
#         "EXCEPTION 0e ..."   (fetch faulted, not a silent execute / triple-fault)
#       and isa-debug-exit FAIL -> QEMU exit 35 (NOT the clean 33);
#   (4) and "K4C NX RET" must NEVER print — it prints only if exec_at RETURNED,
#       i.e. NX was NOT enforced.
#
#   success (NX live): the ARMED line appears AND the fetch faults loudly
#            (EXCEPTION 0e, exit 35, no "K4C NX RET"). A regression that disarmed
#            EFER.NXE would let the ret execute -> "K4C NX RET 0", exit 33 -> FAIL.
#
# Builds kernel_nx.elf first (shares native_input.la with build.sh — run
# SEQUENTIALLY, never in parallel with a build). Skips (rc 0) when QEMU absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  K4c-nx gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_k4c_nx.sh >/dev/null 2>&1 || { echo "FAIL  K4c-nx gate: build_k4c_nx.sh failed"; exit 1; }

OUT=$(timeout 30 qemu-system-x86_64 \
        -kernel kernel/kernel_nx.elf -m 256 \
        -serial stdio -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown 2>/dev/null)
RC=$?

ok=1
seen=$(printf '%s' "$OUT" | tr -d '\0' | tr '\n' ' ' | head -c 200)
printf '%s' "$OUT" | grep -qF "K4C NX FRAME "     || { echo "FAIL  K4c-nx: PMM did not allocate a frame for the PML4 (rc=$RC, got: $seen)"; ok=0; }
printf '%s' "$OUT" | grep -qF "K4C NX ARMED 195"  || { echo "FAIL  K4c-nx: ret byte NOT read back through the identity map — the test frame was not live before the fetch (rc=$RC, got: $seen)"; ok=0; }
printf '%s' "$OUT" | grep -qi "EXCEPTION 0e"      || { echo "FAIL  K4c-nx: the FETCH at the NO-EXECUTE page did NOT fault — NX is NOT enforced (EFER.NXE disarmed?) (rc=$RC, got: $seen)"; ok=0; }
printf '%s' "$OUT" | grep -qF "K4C NX RET"        && { echo "FAIL  K4c-nx: exec_at RETURNED (K4C NX RET printed) — the ret executed, NX was NOT enforced (rc=$RC, got: $seen)"; ok=0; }
[ "$RC" -eq 35 ] || { echo "FAIL  K4c-nx: fault exit != 35 (got $RC — the fetch silently ran, or a triple-fault/hang)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  K4c (NX live): an LA-built page table maps a high page NO-EXECUTE; after the CR3 switch a FETCH through it raises a page-protection #PF (EXCEPTION 0e, exit 35) — the poked ret never runs, EFER.NXE armed, NX enforced on the metal (the execute-twin of the W^X-write proof)"
[ "$ok" -eq 1 ]
