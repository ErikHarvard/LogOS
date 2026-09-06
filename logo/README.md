# The LogOS logo — Λ, the Meta-Word

Not drawn. **Derived**: the `LOGOS` glyph already defined in `sigil.la`
("Being's circle holding the ∞ + the Name") — `RING` + `LEMN_L` + `DOT` + the
Name's curl — evaluated by the language itself.

## Reproduce

    ./tiny_host logos_render.la > logos_v3_grid.txt    # the language renders it
    python3 render.py                                  # grid -> PNG

## What differs from sigil.la's LOGOS, and why

`sigil.la` fixes `SZ = 32` so ASCII rasterisation stays byte-identical host==VM —
right for a test, too coarse for a logo. Two changes, both scalings of the SAME
construction, not new geometry:

1. **Canvas ×4** (`SZ = 128`). `RING`/`DOT`/`SEG` take centre and radius as
   parameters, so they scale directly. `LEMN_L` did not — its `16`s and `9` were
   hardcoded. Under `X,Y -> kX,kY` the lemniscate `(X²+Y²)² ≤ a²(X²−Y²)` has LHS
   scaling `k⁴` against RHS `k²`, so the constant becomes `9k`.
2. **Stroked, not filled.** `LEMN_L` is an inequality, so it fills its interior.
   The stroke is a gradient-normalised band, `|F| ≤ T·(1+|X|³+|Y|³)` with `T=10`,
   where `F = (X²+Y²)² − a²(X²−Y²)`. Normalising by the dominant gradient term
   keeps the width even; differencing two lemniscates (RING's own idiom) does not
   — the curves converge at the tips and the band collapses to nothing there.

## Known flaw

The Name's curl is three straight `SEG`s, so it reads angular rather than
ouroboric. `ARC` was tried at two placements; both merged into the main ring and
read worse. Fixing it properly means changing the `LOGOS` glyph in `sigil.la`,
not the rendering.

## Not yet gated

`build.sh` verifies the nine primitives and Truth by symmetry signature.
**Nothing asserts Λ.** Before this goes into the boot path it should get its own
check, or it enters ungated — the defect class this repo already tracks.
