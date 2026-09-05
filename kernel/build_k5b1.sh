#!/usr/bin/env bash
# LogOS kernel K5b.1 slice — build the COOPERATIVE-task probe binaries.
#   task_pingpong.la --(native_codegen3, spawn/yield)--> native_pingpong.bin
#     two workers round-robin via yield() -> "A B A B A B done".
#   task_gc.la       --(native_codegen3, spawn/yield + rt_gc)--> native_gc.bin
#     a suspended task's canary survives ~400 MB of churn -> "SURVIVED".
#
# These are Linux-hosted (spawn/yield are userspace green-thread context
# switches — no ring 0, no QEMU). Each compile emits the SHARED native_codegen3_out,
# so we copy it to a DISTINCT stable name the buildla orchestrator can gate
# (buildla RUNS + judges the pre-built binary; it does NOT drive this ~78s
# native_codegen3 compile inline, exactly as it gates pre-built kernel_*.elf).
#
# Shares native_input.la with build.sh — run SEQUENTIALLY, never in parallel.
set -euo pipefail
cd "$(dirname "$0")/.."          # -> ~/logos

echo "[1/2] compile task_pingpong.la via native_codegen3 (spawn/yield)"
cp kernel/task_pingpong.la native_input.la
( if [ -x native_codegen3_selfhost.bin ]; then cp native_codegen3_selfhost.bin /tmp/_ncc$$ && chmod +x /tmp/_ncc$$ && /tmp/_ncc$$; rc=$?; rm -f /tmp/_ncc$$; exit $rc; else ./tiny_host native_codegen3.la; fi; ) >/dev/null
cp native_codegen3_out kernel/native_pingpong.bin
echo "      -> kernel/native_pingpong.bin"

echo "[2/2] compile task_gc.la via native_codegen3 (spawn/yield + rt_gc)"
cp kernel/task_gc.la native_input.la
( if [ -x native_codegen3_selfhost.bin ]; then cp native_codegen3_selfhost.bin /tmp/_ncc$$ && chmod +x /tmp/_ncc$$ && /tmp/_ncc$$; rc=$?; rm -f /tmp/_ncc$$; exit $rc; else ./tiny_host native_codegen3.la; fi; ) >/dev/null
cp native_codegen3_out kernel/native_gc.bin
echo "      -> kernel/native_gc.bin"

echo "OK: kernel/native_pingpong.bin + kernel/native_gc.bin"
