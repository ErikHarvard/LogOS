#!/bin/bash
# Regenerate the self-hosted compiler reference image (native_codegen3_selfhost.bin)
# after a native_codegen3.la / native_codegen3_rt.asm change. Uses the CURRENT
# reference image (16 GiB heap) to iterate to the new byte-identical fixed point —
# runs in seconds, no tiny_host seed. The ~11h tiny_host genesis (or patch_heap.py
# on a tiny_host CC0) is only needed to create the FIRST image; thereafter the image
# bootstraps its own successor. build.sh Stage 4 checks the committed image is a
# fixed point of the source, so run this (and `git add` the image) after any change.
set -e
cd "$(dirname "$0")"
REF=native_codegen3_selfhost.bin
[ -x "$REF" ] || { echo "no $REF present — need a 16 GiB-heap seed first (genesis: tiny_host, or patch_heap.py on a CC0)"; exit 1; }
cp "$REF" /tmp/rg.bin; chmod +x /tmp/rg.bin
cp native_codegen3.la native_input.la
for i in 1 2 3 4 5; do
    rm -f native_codegen3_out
    /tmp/rg.bin >/dev/null
    [ -f native_codegen3_out ] || { echo "iter $i: compile produced no output — source error?"; exit 1; }
    if cmp -s native_codegen3_out "$REF"; then
        echo "fixed point already holds at iter $i; $REF unchanged ($(stat -c%s "$REF") bytes)"
        rm -f /tmp/rg.bin native_input.la native_codegen3_out; exit 0
    fi
    # not yet a fixed point: adopt the new image and iterate (heap/RT changes
    # propagate over one generation, like the original 16 GiB heap bump did)
    cp native_codegen3_out /tmp/rg.bin; chmod +x /tmp/rg.bin
    rm -f native_codegen3_out; /tmp/rg.bin >/dev/null
    if cmp -s native_codegen3_out /tmp/rg.bin; then
        cp /tmp/rg.bin "$REF"; chmod +x "$REF"
        echo "fixed point reached after iter $i; $REF updated ($(stat -c%s "$REF") bytes) — now: git add $REF"
        rm -f /tmp/rg.bin native_input.la native_codegen3_out; exit 0
    fi
done
echo "did not converge in 5 iterations — investigate nondeterminism in native_codegen3"; exit 1
