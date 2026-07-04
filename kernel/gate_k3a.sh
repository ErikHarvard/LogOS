#!/usr/bin/env bash
# LogOS kernel K3a gate — the PMM policy is PURE LOGIC, so verify it the strong
# way: host==native. Compile kernel/pmm.la with native_codegen3 (native) and run
# it under tiny_host (host); assert byte-identical frame-allocation output.
#
# Shares native_input.la / native_codegen3_out with build.sh — runs SEQUENTIALLY
# (build.sh calls it; or standalone when no build is running). Do NOT run it in
# parallel with a build (the shared-file race that fakes nondeterminism).
set -uo pipefail
cd "$(dirname "$0")/.."

cp kernel/pmm.la native_input.la
./tiny_host native_codegen3.la >/dev/null 2>&1 || { echo "FAIL  K3a: native_codegen3 could not compile pmm.la"; exit 1; }
NAT=$(./native_codegen3_out 2>&1)
HOST=$(./tiny_host kernel/pmm.la 2>&1)
EXP=$'1048576\n1052672\n1056768\n1052672'   # 0x100000, +4K, +8K, then the freed +4K reused

ok=1
[ "$HOST" = "$EXP" ] || { echo "FAIL  K3a: host output != expected (got: $(printf '%s' "$HOST" | tr '\n' ' '))"; ok=0; }
[ "$NAT" = "$HOST" ] || { echo "FAIL  K3a: native != host (native: $(printf '%s' "$NAT" | tr '\n' ' '))"; ok=0; }
[ "$ok" -eq 1 ] && echo "PASS  K3a: PMM parse-mmap -> arena -> bump+free-stack alloc/free/reuse, byte-identical host==native"
[ "$ok" -eq 1 ]
