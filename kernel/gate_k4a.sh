#!/usr/bin/env bash
# LogOS kernel K4a gate — the paging POLICY is pure logic, so verify it the
# strong way: host==native. x86-64 4-level paging reduces to arithmetic — the
# decomposition of a virtual address into its PML4/PDPT/PD/PT indices, the
# assembly of a PTE (paddr & ~0xFFF)|flags with NX at bit 63, and the W^X
# invariant. Compile kernel/paging.la with native_codegen3 (native) and run it
# under tiny_host (host); assert byte-identical, expected output.
#
# Then the W^X loud-failure regression: kernel/paging_wxfail.la requests a
# writable+executable page, which MK_PTE (the sole PTE constructor) must REFUSE
# by halting loudly on BOTH engines (nonzero exit, no PTE printed) — the same
# discipline as the freeze-day both-engines-halt-loudly tests.
#
# Shares native_input.la / native_codegen3_out with build.sh — runs
# SEQUENTIALLY (never in parallel with a build or another kernel gate: the
# shared-file race that fakes nondeterminism).
set -uo pipefail
cd "$(dirname "$0")/.."

ok=1

# ── 1. success oracle: VA decomposition + PTE assembly + W^X verdicts ──
cp kernel/paging.la native_input.la
./tiny_host native_codegen3.la >/dev/null 2>&1 || { echo "FAIL  K4a: native_codegen3 could not compile paging.la"; exit 1; }
NAT=$(./native_codegen3_out 2>&1)
HOST=$(./tiny_host kernel/paging.la 2>&1)
# PML4=1 PDPT=2 PD=3 PT=4 offset=1656 | data-PTE lo/hi (1048576|P|W, NX) |
# code-PTE lo/hi (2097152|P, exec RO) | W^X verdicts: (W,NX)ok (RO,exec)ok (W,exec)no
EXP=$'1\n2\n3\n4\n1656\n1048579\n2147483648\n2097153\n0\n1\n1\n0'
[ "$HOST" = "$EXP" ] || { echo "FAIL  K4a: host output != expected (got: $(printf '%s' "$HOST" | tr '\n' ' '))"; ok=0; }
[ "$NAT" = "$HOST" ]  || { echo "FAIL  K4a: native != host (native: $(printf '%s' "$NAT" | tr '\n' ' '))"; ok=0; }

# ── 2. W^X loud-refusal regression: must halt loudly on BOTH engines ──
cp kernel/paging_wxfail.la native_input.la
./tiny_host native_codegen3.la >/dev/null 2>&1 || { echo "FAIL  K4a: native_codegen3 could not compile paging_wxfail.la"; exit 1; }
WNAT=$(./native_codegen3_out 2>&1); WNAT_RC=$?
WHOST=$(./tiny_host kernel/paging_wxfail.la 2>&1); WHOST_RC=$?
[ "$WHOST_RC" -ne 0 ] || { echo "FAIL  K4a: host did NOT halt on the W^X violation (rc=0, out: $WHOST)"; ok=0; }
[ "$WNAT_RC"  -ne 0 ] || { echo "FAIL  K4a: native did NOT halt on the W^X violation (rc=0, out: $WNAT)"; ok=0; }
printf '%s' "$WHOST" | grep -qF "W^X VIOLATION" || { echo "FAIL  K4a: host W^X halt not diagnosed loudly (out: $WHOST)"; ok=0; }
printf '%s' "$WNAT"  | grep -qF "W^X VIOLATION" || { echo "FAIL  K4a: native W^X halt not diagnosed loudly (out: $WNAT)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  K4a: 4-level VA decomposition + PTE assembly (NX in high32) + W^X, byte-identical host==native; W^X violation halts loudly on both engines"
[ "$ok" -eq 1 ]
