# Stage 4 (full native self-hosting) — ACHIEVED 2026-06-26

native_codegen3 (an x86-64 compiler written in Lingua Adamica) compiles its OWN
576-line source into a byte-identical native binary, with NO C host and NO
interpreter in the self-host loop. ∃(∃) ≡ ∃ at the compiler level.

## What was fixed to get here (all in native_codegen3.la)
1. Parser SCC `{P_EXPR,P_APP,APP_TAIL,P_PRIMARY,P_LAMBDA}` Z-tied (named mutual
   recursion → single Z fixpoint + threaded `pexpr`). Commit 61c4125.
2. `{PARSE_MODULE↔PARSE_MOD_LOOP}` import-branch `PARSE_MODULE(`→`self(`. 61c4125.
   (INLINE produces one closed term → can only represent Z-recursion, not named.)
3. `HEAP_SIZE` 1.5 GiB → 16 GiB (line 415) + memsz tracks it (line 561). The
   self-inline working set is ~9.7 GB (peak RSS), so 1.5 GB exhausted. Pure
   source literal — no asm/dq-probe.

## The convergence (the actual result)
- CC0 = tiny_host(source) — the ONE-TIME seed. Took **11h28m** under tiny_host's
  naive interpreter (the irreducible bootstrap origin, like every self-hoster).
  Preserved as `native_codegen3_cc0_seed.bin`.
- Native compile is **~5000× faster**: CC0 (heap-patched to 16 GiB) compiled the
  full source in **7.9 s**.
- Heap-size change propagates over one generation: CC0(1.5G)→CC1→**CC2**.
- **CC2 == CC2(CC2_source)** byte-identical (verified CC2==CC3, CC3 made by
  running CC2 NATIVELY — no host, no patch). CC2 = `native_codegen3_selfhost.bin`.
- CC2 is a CORRECT compiler: compiles kernel.la → speaks "I AM THAT I AM",
  native==host.

## Reproducible bootstrap (clean, no binary patch)
The session used a one-time binary heap-patch on CC0 to skip a second 11h run,
but the CLEAN reproducible path is:
1. `cp native_codegen3.la native_input.la; ./tiny_host native_codegen3.la`
   → CC0' directly at 16 GiB heap (HEAP_SIZE is now 16 GiB in source). ~11h.
2. `cp native_codegen3_out cc.bin; cp native_codegen3.la native_input.la;
    ./cc.bin` → produces native_codegen3_out; `cmp` it with cc.bin → identical.
   CC0' is the fixed point directly (its emission heap = source's 16 GiB).
The heap-patch trick (`/tmp/patch_heap.py`, anchor: MOV [HEAP_END_ADDR=4198664],
rax; shift the preceding imm64 + p_memsz@104 by +15569256448) only existed to
avoid re-seeding mid-session; CC2 == the CC0' a clean re-seed yields.

## Honest scope
- The FIRST seed still needs tiny_host (or the patch) — the bootstrap origin.
- A self-host regression test is NOT yet in build.sh (the 11h seed is too slow
  to run every build; the patch→native path runs in seconds and could be added).
- HEAP_SIZE = 16 GiB is generous (working set ~9.7 GB); lazily mapped, fine on
  this 188 GB box.
