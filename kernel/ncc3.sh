#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  ncc3.sh — compile native_input.la -> native_codegen3_out, fast path first.
#
#  WHY THIS EXISTS
#  Every kernel builder compiles its driver with native_codegen3. There are two
#  ways to run that compiler, and they differ by ~100x:
#      ./tiny_host native_codegen3.la      the compiler's SOURCE, interpreted
#      native_codegen3_selfhost.bin        the same compiler, NATIVE (committed)
#  MEASURED, from build.sh's own annotations: gate_mouse 883 s and gate_wheel
#  1255 s (slow path) against gate_comp_term_hal4e 16 s (fast path). build.sh
#  says it plainly — the cost is "dominated by the LA COMPILE, not the QEMU run".
#  So the language half was being paid for AGAIN, per gate, INSIDE the kernel
#  half: the second toll, after the ~7000-line one kernel/build_kernel_half.sh
#  removed.
#
#  ★ ONE DEFINITION, NOT SIXTY-THREE. The fast path already existed and was
#  inlined VERBATIM into 28 builders. Converting the remaining 35 by copying it
#  again would make 63 copies of one idiom — and a copied idiom is how this repo
#  drifts (a count hand-updated and never re-derived; four PS/2 gates marked
#  "DONE + gated" that nothing ran). The body below is that proven one-liner,
#  moved here unchanged, so a fix to it reaches every caller.
#
#  ★ WHY IT COPIES THE IMAGE BEFORE RUNNING IT — preserved deliberately, not
#  tidied. Some builders later write back over native_codegen3_selfhost.bin;
#  running the image in place can then hit ETXTBSY on a live executable. The
#  copy also survives a checkout that lost the +x bit. This idiom is load-bearing
#  and proven across 28 builders, so it is moved verbatim rather than improved.
#
#  ★ NOT FOR EVERY BUILDER. kernel/build_hh1b.sh compiles with
#  native_codegen3_hh.la — a DIFFERENT compiler. native_codegen3_selfhost.bin is
#  the fixed point of native_codegen3.la only, so pointing hh1b here would
#  silently build the higher-half kernel with the wrong compiler. It is excluded
#  by name, and kernel/gate_ncc3.sh asserts that exclusion still holds.
#
#  CONTRACT: reads native_input.la, writes native_codegen3_out, both in the repo
#  root; returns the compiler's exit status so a caller's `set -e` still aborts.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
cd "$(dirname "$0")/.."

if [ -x native_codegen3_selfhost.bin ]; then
    cp native_codegen3_selfhost.bin "/tmp/_ncc$$" && chmod +x "/tmp/_ncc$$" && "/tmp/_ncc$$"
    rc=$?
    rm -f "/tmp/_ncc$$"
    exit $rc
else
    # Fallback, not a skip: the slow path still produces the correct artifact,
    # it just costs ~15 min instead of ~2 s. Announced on stderr so a build that
    # silently got 100x slower is visibly different from one that did not.
    echo "NOTE  ncc3: native_codegen3_selfhost.bin absent — falling back to the SLOW tiny_host path (~15 min instead of ~2 s). It is committed to git; restore it with \`git checkout -- native_codegen3_selfhost.bin\`." >&2
    ./tiny_host native_codegen3.la
fi
