#!/usr/bin/env bash
# D-INIT.1 — build the three reap probes.
#
#   reap_test.la           -> kernel/native_reap_test.bin       (semantics)
#   respawn_reap_probe.la  -> kernel/native_respawn_reap.bin    (12 cycles, GREEN)
#   respawn_probe.la       -> kernel/native_respawn_noreap.bin  (RED control)
#
# The last one is the negative control and is built deliberately: the gate
# requires it to FAIL. Same loop as the green probe, minus the reap call.
#
# Linux-hosted (spawn/yield/reap are userspace green-thread operations on the
# runtime task table — no ring 0, no QEMU), exactly like build_k5b1.sh.
#
# Each compile emits the SHARED native_codegen3_out, so we copy it to a distinct
# stable name the gate can judge.
#
# Shares native_input.la with build.sh — run SEQUENTIALLY, never in parallel.
set -euo pipefail
cd "$(dirname "$0")/.."

# ── PRECONDITION: the reap primitive must be in the runtime ─────────────────
#  D-INIT.1's runtime half (rt_reap in native_codegen3_rt.asm + the RT_REAP
#  wiring in native_codegen3.la) is NOT committed: those files belong to track A
#  per ~/logos-tracks.conf, and logos-guard refuses a track-D commit that touches
#  them. The change is complete, gated and witnessed — it is parked, not pending.
#  Fail here with the reason rather than emitting probes that cannot resolve
#  `reap` and blaming the gate.
grep -q '^rt_reap:' native_codegen3_rt.asm 2>/dev/null \
  && grep -q 'glyph RT_REAP' native_codegen3.la 2>/dev/null || {
    echo "SKIP  D-INIT.1: the reap primitive is not in this tree's runtime."
    echo "      rt_reap (native_codegen3_rt.asm) + RT_REAP (native_codegen3.la) are"
    echo "      TRACK A's files; logos-guard refuses a track-D commit that touches them."
    echo "      The work is complete and witnessed — apply it with:"
    echo "          git apply ~/logos-dinit1-runtime.patch"
    echo "      then re-run this script. See kernel/LOGOSINIT_SCOPE.md and the"
    echo "      'Open cross-track requests' entry in ~/logos-status.md."
    exit 0
}

compile() {   # $1 = source .la, $2 = destination .bin
    cp "$1" native_input.la
    ( if [ -x native_codegen3_selfhost.bin ]; then
          cp native_codegen3_selfhost.bin /tmp/_ncc$$ && chmod +x /tmp/_ncc$$ && /tmp/_ncc$$; rc=$?
          rm -f /tmp/_ncc$$; exit $rc
      else ./tiny_host native_codegen3.la; fi ) >/dev/null
    cp native_codegen3_out "$2"
    echo "      -> $2"
}

echo "[1/3] compile kernel/reap_test.la (reap semantics)"
compile kernel/reap_test.la kernel/native_reap_test.bin

echo "[2/3] compile kernel/respawn_reap_probe.la (12 cycles WITH reap)"
compile kernel/respawn_reap_probe.la kernel/native_respawn_reap.bin

echo "[3/3] compile kernel/respawn_probe.la (RED control — no reap)"
compile kernel/respawn_probe.la kernel/native_respawn_noreap.bin

rm -f native_input.la native_codegen3_out
echo "D-INIT.1 probes built."
