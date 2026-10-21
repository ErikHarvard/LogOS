#!/bin/bash
# Regenerate the self-hosted compiler reference image (native_codegen3_selfhost.bin)
# after a native_codegen3.la / native_codegen3_rt.asm change. Uses the CURRENT
# reference image (16 GiB heap) to iterate to the new byte-identical fixed point,
# with no tiny_host seed. BUDGET ~25-40 MIN (measured 2026-07-16: each self-compile
# of native_codegen3.la is ~6 min, 2 per iteration, converging at iter 2). This
# comment used to claim "runs in seconds" — it does not; don't wrap it in a short
# `timeout`, which kills it at exit 143 and looks like a failure. The ~11h
# tiny_host genesis (or patch_heap.py
# on a tiny_host CC0) is only needed to create the FIRST image; thereafter the image
# bootstraps its own successor. build.sh Stage 4 checks the committed image is a
# fixed point of the source, so run this (and `git add` the image) after any change.
set -e
cd "$(dirname "$0")"
# audit2 #31: every run of the image checks its rc. Under `set -e` a bare
# `/tmp/rg.bin >/dev/null` that died (rc 139: the kernel refused to map the
# image's p_memsz on a box with less RAM+swap) killed this script with no message.
run_rg() {   # run_rg <what> : run the current image on native_input.la
    local rc=0
    "$RG" >/dev/null || rc=$?
    [ "$rc" = 0 ] && return 0
    echo "regen_selfhost: $1: $RG exited $rc — no image written."
    [ "$rc" = 139 ] && echo "  rc 139 at once is usually the exec being refused: the image's PT_LOAD p_memsz exceeds RAM+swap (see dmesg for __vm_enough_memory)."
    rm -f "$RG" native_input.la native_codegen3_out
    exit 1
}
REF=native_codegen3_selfhost.bin
[ -x "$REF" ] || { echo "no $REF present — need a 16 GiB-heap seed first (genesis: tiny_host, or patch_heap.py on a CC0)"; exit 1; }
RG=$(mktemp /tmp/rg.XXXXXX)
cp "$REF" "$RG"; chmod +x "$RG"
cp native_codegen3.la native_input.la
for i in 1 2 3 4 5; do
    rm -f native_codegen3_out
    run_rg "iter $i (compile with the current image)"
    [ -f native_codegen3_out ] || { echo "iter $i: compile produced no output — source error?"; exit 1; }
    if cmp -s native_codegen3_out "$REF"; then
        echo "fixed point already holds at iter $i; $REF unchanged ($(stat -c%s "$REF") bytes)"
        rm -f "$RG" native_input.la native_codegen3_out; exit 0
    fi
    # not yet a fixed point: adopt the new image and iterate (heap/RT changes
    # propagate over one generation, like the original 16 GiB heap bump did)
    cp native_codegen3_out "$RG"; chmod +x "$RG"
    rm -f native_codegen3_out; run_rg "iter $i (compile with the new image)"
    if cmp -s native_codegen3_out "$RG"; then
        cp "$RG" "$REF"; chmod +x "$REF"
        echo "fixed point reached after iter $i; $REF updated ($(stat -c%s "$REF") bytes) — now: git add $REF"
        rm -f "$RG" native_input.la native_codegen3_out; exit 0
    fi
done
rm -f "$RG"
echo "did not converge in 5 iterations — investigate nondeterminism in native_codegen3"; exit 1
