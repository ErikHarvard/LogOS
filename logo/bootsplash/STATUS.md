# Boot splash — WORK IN PROGRESS, NOT APPLIED TO THE REPO

`fb_logo.la` is a modified `kernel/fb.la` that draws the LOGOS sigil instead of
HAL.4's 64x64 red square. It was developed in an isolated copy (`/tmp/logosplash`)
and **never written into the repo**, because `kernel/gate_hal4.sh` (build.sh:5669)
consumes `kernel/fb.la` and a build was running.

## State: UNVERIFIED

It has NEVER been compiled successfully or booted. No QEMU screendump exists.
Do not claim the kernel boots its own sigil until one does.

- The **artwork** IS verified: the 927-char RLE literal in `fb_logo.la` decodes to
  16384 cells / 2479 lit and round-trips IDENTICAL to sigil.la's own grid.
  `splash_preview.png` is that literal decoded and upscaled — what it WILL draw.
- The **kernel path** is NOT verified. Compile was killed at ~14 min.

## The blocker, measured

`native_codegen3` appears roughly QUADRATIC in source length:

    pristine kernel/fb.la   3457 bytes  ->  211 s   (rc=0, control run)
    fb_logo.la              6390 bytes  ->  >861 s  (killed, unfinished)

1.85x the source for >4x the time. The 211 s control is the baseline nobody had
measured — codegen is slow here BEFORE any change.

## Next step

Shrink the source, not the cleverness: re-render the sigil at 64x64 (K=2) instead
of 128x128. That cuts the RLE literal to roughly a quarter and should bring the
compile back near the 211 s control. Upscale x6 on screen (64*6 = 384) instead of
x3. The band constant scales with k: T = 10*K/4, so T=5 at K=2.

## Also unresolved

`build.sh` does not verify Λ. It checks the nine primitives and Truth by symmetry
signature; NOTHING asserts LOGOS. Before this enters the repo or the boot path it
should get its own assertion, or it goes in ungated.
