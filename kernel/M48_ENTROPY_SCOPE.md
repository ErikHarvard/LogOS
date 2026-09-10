# M48 — ENTROPY ON THE METAL — **SPECIFIED 2026-09-10, not yet built**

Master list `:283` / ROADMAP "CSPRNG and an entropy source ON THE METAL". Specified by POROS
(Track D) at the General's direction, the way P4 was: verify the absence first, then state what
it must provide, its gate, its pre-registered reds, and the cross-track seam. **No code tonight.**

## 0. Verification — no on-metal entropy source exists at HEAD (kernel-k1 `fcaaa23`)

**Measured, not assumed.** `git grep -icE` over `kernel/*.asm`, `kernel/*.la`, the current runtime
`native_codegen3_rt.asm`, and `nativert.asm`, for `rdrand|rdseed|rdtsc|getrandom|getentropy|rng|
hwrng|jitter|entropy|prng|drbg|chacha`: **0 hits of an entropy path.** `boot.asm` specifically:
**0** RDRAND/RDSEED/RDTSC/getrandom. *(traced)*

**Corroborated by the subject's own documentation** — so this is not a grep-absence that a synonym
could hide. `hmacdrbg.la:12` states it: *"kernel K1-K7 has NO entropy source whatsoever — no
RDRAND/RDSEED builtin, no jitter collector, no seed file — and full-disk encryption must derive keys
at boot."* The DRBG's own header names the gap M48 fills. *(traced)*

**What EXISTS, and why none of it is an on-metal source:**
- **`hmacdrbg.la`** (Track A) — a NIST SP 800-90A HMAC-DRBG/SHA-256. *"A DRBG is a stretcher, not a
  spring"* (`:9`). It is seeded today only by a **fixed NIST test vector** (`ENTROPY`, `:95`). A
  fixed seed is not a source. M48 is the spring; this is the stretcher, already built.
- **`chacha20.la`** (Track A) — a stream cipher; an expander, not a source.
- **`secd.asm:2820` `random` → `getrandom(2)`** — a **HOST Linux syscall**. The SECD VM has it; the
  **metal does not** (no Linux under boot.asm/the K-stages).
- **False positives ruled out:** `entropy.la` is *semantic/glyphic* entropy (monosemy H(form|meaning)),
  not randomness; `dyadseed.la` is the glyph dyad (0 and 1 beneath the primitives); the `seed`
  hits in `native_codegen*_rt.asm` are the comment *"the accepted 'physics' seed"* (the runtime
  bootstrap); `noise` is NIC packet noise in the HAL.5 gates.

**What this verification would MISS (honest bound):** an entropy path named by a word outside the
searched vocabulary; a source in an `.la` I did not open (I opened `entropy`/`hmacdrbg`/`dyadseed`);
and — the one that matters — **a hardcoded seed constant masquerading as a source.** A fixed seed is
NOT a source, and M48's gate must actively reject it (see R1/R6). The DRBG's own stated dependency
on a missing source makes the negative robust rather than merely unsearched.

## 1. What M48 must provide — the SPRING that seeds the stretcher

1. **A hardware-entropy primitive** returning N bytes on x86-64: RDRAND / RDSEED, **gated by CPUID**
   (RDRAND = leaf 1 ECX bit 30; RDSEED = leaf 7 EBX bit 18). It MUST test CPUID before issuing the
   instruction — executing RDRAND on a CPU without it is `#UD`.
2. **The failure discipline RDRAND requires:** RDRAND sets CF=0 on failure and leaves the destination
   undefined. Retry up to a bound (Intel's guidance: 10 for RDRAND); if still failing, that is a hard
   fault — **halt loudly, never return the undefined register or a zero.**
3. **A labelled fallback** when the CPU has no RDRAND (older/virtual CPUs): an RDTSC-jitter collector.
   It is weaker and must be **labelled as such** — never silently substituted for hardware RNG. A
   caller must know which quality it received.
4. **It feeds `hmacdrbg.la`'s `INSTANTIATE`** — replacing the fixed `ENTROPY` test vector with a real
   seed. M48 is the source; the DRBG is the consumer. The two together are the CSPRNG.
5. **Loud failure is mandatory.** If no source is available (no RDRAND, no RDSEED, jitter
   insufficient), the kernel **halts with a named diagnostic and a non-33 exit** — it must NEVER
   return a fixed or zero seed. A silent weak seed makes every FDE key forgeable while the system
   looks healthy; that is strictly worse than a halt.

## 2. The gate — `kernel/gate_m48.sh`

Build a kernel ELF that draws entropy on the metal (QEMU) and prints it; assert on CONTENT and exit:
1. **CPUID is checked before RDRAND** — the instruction is not issued on a CPU lacking it (no `#UD`).
2. **Two successive draws DIFFER** — the minimal non-vacuity. A fixed/zero seed fails this.
3. **The draw is non-trivial** — not all-zero, not a single repeated byte (a coarse health check).
4. **On a no-RDRAND CPU** (`qemu -cpu` without the rdrand flag) the jitter fallback engages **and is
   labelled**, or the kernel halts loudly — never a silent zero.
5. **End-to-end:** the seed reaches the DRBG — `hmacdrbg` INSTANTIATE'd with the M48 seed yields
   output that DIFFERS across two boots (source → stretcher, wired).
6. **Exit discipline:** success 33; a distinct non-33 code for "no entropy source".

★ Each control md5s its ELF and FAILs if the perturbation was absorbed, as P3/P4 do.

## 3. Pre-registered reds (six)

| red | perturbation | expected shape |
|---|---|---|
| **R1 BASELINE** | the primitive returns a FIXED buffer | step 2 (two draws differ) FAILs — green-by-exit-code, wrong by content, the P3/P4 R1 pattern |
| **R2 CPUID-BLIND** | skip the CPUID check, issue RDRAND on a no-RDRAND CPU | `#UD` fault — the gate catches the fault, not a silent value; step 1 falsifiable |
| **R3 NO-RETRY** | RDRAND without the CF-failure retry loop | on CF=0 it returns an undefined/zero buffer → step 3 FAILs |
| **R4 SILENT-FALLBACK** | jitter substituted for hardware RNG WITHOUT the label | the gate cannot tell hardware from jitter → step 4 FAILs; the label is load-bearing |
| **R5 SEED-NOT-WIRED** | M48 draws, but the DRBG still uses its fixed `ENTROPY` vector | step 5 FAILs — DRBG output identical across two boots; proves the seam |
| **R6 ★ WEAK-SEED-SILENT** | no source, but return a zero/fixed seed and exit 33 instead of halting | the loud-failure discipline: the gate asserts a non-33 exit + named diagnostic. **The catastrophic case for FDE — a weak seed that looks healthy.** |

## 4. The cross-track seam — named, not built

- **If the primitive is an LA runtime BUILTIN** (`entropy(n)` callable from a `.la` program), it lives
  in **`native_codegen3_rt.asm` — TRACK A's file** (`~/logos-tracks.conf:64`). Track D cannot add it;
  Track D posts a **NEEDS** and Track A implements it, the way the VM's `random`/getrandom builtin was
  added to `secd.asm`.
- **If it is a kernel-resident routine** that seeds FDE at boot in inline asm (no LA program calls it),
  it lives in `boot.asm` / a K-stage ELF — **Track D's**, and M48 builds it here.
- **The scope call** (which of the two) is the General's/Lieutenant's: "entropy on the metal for FDE
  key derivation" leans kernel-inline (Track D); "an LA program needs `entropy(n)`" is the Track-A
  builtin seam. **The consumer `hmacdrbg.la` is Track A's regardless**, so wiring M48's seed into
  `INSTANTIATE` is a NEEDS, not a Track-D edit.

**Honest scope:** RDRAND/RDSEED are a CPU-vendor RNG; a purist wants an independent physical source or
a jitter-mixed pool. This spec targets *a real seed on the metal, loudly-failing rather than silently
weak* — the FDE-blocking gap — not a certified TRNG. The reds enforce exactly that boundary.
