#!/usr/bin/env bash
# LogOS kernel K5b.1a slice gate — cooperative tasks via spawn/yield.
# Compile task_pingpong.la with native_codegen3 and run the emitted binary
# LINUX-HOSTED (spawn/yield are userspace green-thread context switches — no
# ring 0, so no QEMU is needed). Assert:
#   - the two workers interleave exactly "A B A B A B" then "done" (round-robin
#     over main->A->B), proving each worker's loop counter + continuation
#     survived a real context switch on its own saved stack;
#   - a clean exit 0.
# A broken switch would drop/duplicate a task, reorder the interleave, corrupt
# a counter, or crash — any of which fails the exact-output check.
#
# Shares native_input.la with build.sh — run SEQUENTIALLY, never in parallel.
set -uo pipefail
cd "$(dirname "$0")/.."

cp kernel/task_pingpong.la native_input.la
( if [ -x native_codegen3_selfhost.bin ]; then cp native_codegen3_selfhost.bin /tmp/_ncc$$ && chmod +x /tmp/_ncc$$ && /tmp/_ncc$$; rc=$?; rm -f /tmp/_ncc$$; exit $rc; else ./tiny_host native_codegen3.la; fi; ) >/dev/null 2>&1 || { echo "FAIL  K5b.1a gate: native_codegen3 failed to compile task_pingpong.la"; exit 1; }

OUT=$(timeout 15 ./native_codegen3_out 2>/dev/null)
RC=$?

EXPECT=$'A\nB\nA\nB\nA\nB\ndone'
ok=1
if [ "$OUT" != "$EXPECT" ]; then
    echo "FAIL  K5b.1a: cooperative interleave wrong — expected 'A B A B A B done', got: $(printf '%s' "$OUT" | tr '\n' ' ')"; ok=0
fi
[ "$RC" -eq 0 ] || { echo "FAIL  K5b.1a: exit code != 0 (got $RC — a crash or hang in the context switch)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  K5b.1a slice: cooperative tasks via spawn/yield — two worker tasks interleave 'A B A B A B' through round-robin yields, each worker's loop counter + mid-loop continuation preserved across a REAL context switch on its own saved stack (spawn/yield = the 5th/6th native_codegen3 extensions, appended so Stage 4's fixed point is untouched)"
[ "$ok" -eq 1 ]
