#!/usr/bin/env bash
# LogOS kernel K5b.2 slice gate — PREEMPTIVE tasks live on the metal.
# Boot kernel_preempt.elf in QEMU (-m 1024 so the high MAIN stack 0x3F000000 and
# the task stacks at 0x38000000 are mapped) and assert the two NON-yielding
# workers were INTERLEAVED by the timer:
#   - both A and B appear;
#   - the A/B print sequence has >= 3 runs (a maximal same-letter block boundary
#     is crossed at least twice), i.e. a B is printed before A finishes and vice
#     versa — impossible without preemption, since neither worker ever yields;
#   - "done" is printed (MAIN drained + fell through) and QEMU exits 33.
#
# NO preemption would give exactly TWO runs ("A*n then B*n then done") — each
# bounded worker still terminates and yields at the end, so the demo can't hang;
# a 2-run result fails HERE with a clear diagnostic (tune SPINCOUNT so a worker
# spans a 10 ms tick). Skips (rc 0) when QEMU is absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  K5b.2-preempt gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_k5b2.sh >/dev/null 2>&1 || { echo "FAIL  K5b.2-preempt gate: build_k5b2.sh failed"; exit 1; }

OUT=$(timeout 45 qemu-system-x86_64 \
        -kernel kernel/kernel_preempt.elf -m 1024 \
        -serial stdio -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown 2>/dev/null)
RC=$?

CLEAN=$(printf '%s' "$OUT" | tr -d '\0')
SEQ=$(printf '%s' "$CLEAN" | grep -E '^[AB]$' | tr -d '\n')     # e.g. AABBABAB
RUNS_STR=$(printf '%s' "$SEQ" | sed 's/\(.\)\1*/\1/g')          # collapse dups -> ABAB
NRUNS=${#RUNS_STR}
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 300)

ok=1
case "$SEQ" in *A*) : ;; *) echo "FAIL  K5b.2: worker A never printed (rc=$RC, got: $seen)"; ok=0 ;; esac
case "$SEQ" in *B*) : ;; *) echo "FAIL  K5b.2: worker B never printed (rc=$RC, got: $seen)"; ok=0 ;; esac
if [ "$ok" -eq 1 ] && [ "$NRUNS" -lt 3 ]; then
    echo "FAIL  K5b.2: no preemption — the A/B sequence has only $NRUNS run(s) ('$RUNS_STR'), i.e. strict blocks. The timer never preempted a running worker (K5B2 ISR/YIELD_PENDING/rt_apply safe point, or SPINCOUNT too small to span a tick). seq=$SEQ"; ok=0
fi
case "$CLEAN" in *done*) : ;; *) echo "FAIL  K5b.2: MAIN never printed 'done' — a worker hung or MAIN exited early (rc=$RC)"; ok=0 ;; esac
[ "$RC" -eq 33 ] || { echo "FAIL  K5b.2: clean-exit code != 33 (got $RC — a fault/triple-fault or hang)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  K5b.2 slice: preemptive tasks on the metal — two workers that NEVER call yield() interleaved ($NRUNS runs, '$RUNS_STR') because IRQ0 set YIELD_PENDING and rt_apply's safe point context-switched between reductions; MAIN drained and exited 33 (b_tau == f_tau; the safe-point self-hosts, verified separately)"
[ "$ok" -eq 1 ]
