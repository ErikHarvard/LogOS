#!/usr/bin/env bash
# LogOS kernel K5b.1b slice gate — a suspended task's heap roots survive a GC.
# Compile task_gc.la and run it LINUX-HOSTED (no QEMU). Task A holds a canary
# heap string live across a yield; task B then churns ~320 MB of garbage, which
# with the K5b.1c PERIODIC GC (fires every 64 MB, not only at 16 GiB exhaustion)
# triggers several REAL collections WHILE A is suspended. When A resumes it
# checks the canary byte-for-byte:
#   - "SURVIVED"  => rt_gc's K5b.1b per-task root scan marked A's suspended
#                    regs + stack, so the canary was NOT swept (the whole point).
#   - "CORRUPTED" (or a crash) => the canary was collected/reused -> the fix is
#                    absent or wrong.
# Assert "SURVIVED" and a clean exit 0. (The prior rt_gc, scanning only the
# current task's stack, fails this — that's the regression this gate guards.)
#
# Shares native_input.la with build.sh — run SEQUENTIALLY, never in parallel.
set -uo pipefail
cd "$(dirname "$0")/.."

cp kernel/task_gc.la native_input.la
./tiny_host native_codegen3.la >/dev/null 2>&1 || { echo "FAIL  K5b.1b gate: native_codegen3 failed to compile task_gc.la"; exit 1; }

OUT=$(timeout 60 ./native_codegen3_out 2>/dev/null)
RC=$?

ok=1
printf '%s' "$OUT" | grep -qx "SURVIVED" || { echo "FAIL  K5b.1b: canary did NOT survive the forced GC — rt_gc missed the suspended task's roots (got: $(printf '%s' "$OUT" | tr '\n' ' '), rc=$RC)"; ok=0; }
printf '%s' "$OUT" | grep -qx "B-churned" || { echo "FAIL  K5b.1b: churn task did not complete (got: $(printf '%s' "$OUT" | tr '\n' ' '))"; ok=0; }
[ "$RC" -eq 0 ] || { echo "FAIL  K5b.1b: exit code != 0 (got $RC — a crash, likely a swept/corrupted canary)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  K5b.1b slice: a suspended task's heap roots survive a GC — task B forced the mark-sweep collector to fire (~400 MB churn >> 64 MB GC_INTERVAL) while task A was suspended holding a canary; rt_gc's per-task root scan (every runnable task's saved regs + [saved_rsp, stkbase)) marked it, so the canary is byte-intact on resume (non-moving collector, additive marking) -> cooperative tasks are now GC-safe across suspension"
[ "$ok" -eq 1 ]
