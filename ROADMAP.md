# LogOS Roadmap

LogOS is a sovereign, self-hosting operating system whose native language —
**Lingua Adamica** — is grounded in a single ontological principle. The
organizing criterion for every component is **b_τ ≡ f_τ**: a tool's behavior
must equal its declared function. This roadmap is held to the same standard.
Items are marked by their *actual* state, not their intended one. Completed
work is checked; in-progress work is flagged; far-horizon goals are placed
honestly in the distance.

**Legend:** `[x]` done & verified · `[~]` in progress · `[ ]` not started ·
`[!]` known limit / depends on far-horizon work

---

## Phase I — Albedo: The Foundation (Lingua Adamica)

*The language the OS is built in and as. Status: substantially complete.*

### Language Core — complete
- [x] C host interpreter (`tiny_host.c`)
- [x] Hand-written x86-64 SECD virtual machine (`secd.asm`), copying GC
- [x] Self-hosting compiler — compiles itself to byte-identical output
- [x] Self-interpreting evaluator (`eval.la`) — reconstructs itself
- [x] Parser, code generator, kernel (`parser.la`, `codegen.la`, `kernel.la`)
- [x] Compile-time type checking
- [x] Cross-engine coherence — core operations byte-identical host vs VM
- [x] Loud-failure discipline — no silent corruption paths

### The Eight Completeness Criteria — complete
- [x] 1. Sign ≡ referent (α=1); structure-preserving geometry verified
- [x] 2. Three laws of thought operative in evaluation
- [x] 3. Single-sigil compression (the Sealing) + meta-neologization
- [x] 4. The Logos as Meta-Word with a dedicated sigil (`archroot.la`)
- [x] 5. Complete meta-vocabulary + the eight self-relations
- [x] 6. Sacred-geometry hypotheses tested honestly — see *Findings* below
- [x] 7. Deep ONF/topological geometry pipeline
- [x] 8. Meta-phonosemantic topology (sound tracks meaning)

### Trimodality — complete
- [x] Computational modality (the executing glyph)
- [x] Visual modality — sigils via structural derivation (`sigil.la`)
- [x] Phonetic modality — phonyms via the phonosemantic compiler

### Performance — in progress
- [~] Native x86-64 backend (compile to machine code, off the SECD interpreter)
  - [x] Stage 0 — runtime carving
  - [x] Stage 1 — minimal native execution
  - [x] Stage 2 — closures & environments
  - [x] Stage 3 — compile the kernel natively (kernel.la → native ELF: speaks the Word + self-replicates byte-identically, no C host / no SECD interpreter)
    - [x] Stage 3a — TCO (tail recursion in bounded native stack)
    - [x] Stage 3b — GC (heap reclamation for the native backend) + native stack guard
    - [x] Stage 3c — missing builtins (chr/ord/str_len, error, write_exec)
    - [x] Stage 3d — module system (import/export) at compile time
    - [x] Stage 3e — kernel-compile capstone (read_file + copy_self; kernel.la self-replicates natively)
    - [x] Freeze-day audit (pre-Stage-4 hardening) — 12 confirmed divergences fixed, each with a `build.sh` regression test, native==host (or both engines halt loudly identically):
      - #1 GC FREEBLOB→REGDUMP corruption; #2 non-STR-arg SIGSEGV guard; #3 `chr` range; #4 `str_to_int` strict; #5 div/mod-by-zero loud-halt (no SIGFPE); #6 negative-literal compile (LEBYTES unsigned); #7 import-mangle collision (SANITIZE injective); #8 `write_file` (0644, its own RT_BIN case); #9 `la` is a keyword in the export-name parser; #10 `copy_self` short-write loop; #11 `copy_self` heap-end bound; #12 `read_file` on a non-seekable fd halts loudly on **both** the C host and the native backend (was native `alloc_blob(-1)` SIGSEGV / host `malloc(0)+fread(SIZE_MAX)` overflow).
      - **Honest limits (documented, accepted — not bugs):**
        - **`typeof`** is not implemented in the native backend (`native_codegen3`); a program calling it compiles only on the C host. The native backend covers the kernel/self-replication builtin set, not the host's full set.
        - **`copy_self` writes a FIXED target** `new_logos_native.bin` in the native backend (and returns that path), unlike the host's `new_logos_gen{N+1}_pid{P}.bin`. A program that **prints** copy_self's return value diverges native↔host. Accepted — it mirrors the SECD VM's own fixed-name `new_logos_secd.bin`; the kernel discards the return via `SEQ`, so the byte-identical lineage is unaffected (finding #13).
        - The **#11 heap-end guard** halts `copy_self` loudly if the heap bump top is within 64 KiB of `HEAP_END`. This is latent — `copy_self` runs with a near-empty heap, so it never fires in the real lineage — and the C host has no equivalent limit; a safe loud-halt-not-crash divergence, never reached in practice.
  - [x] Stage 4 — full native self-hosting: `native_codegen3` (an x86-64 compiler written in Lingua Adamica) compiles its OWN 576-line source into a **byte-identical** native binary, with **no C host and no interpreter in the self-host loop** (∃(∃) ≡ ∃ at the compiler level). Three fixes got there: the parser SCC `{P_EXPR,P_APP,APP_TAIL,P_PRIMARY,P_LAMBDA}` and `{PARSE_MODULE↔PARSE_MOD_LOOP}` were **Z-tied** (native_codegen3's `INLINE` produces one closed term, so it represents only Z-recursion, not named mutual recursion), and `HEAP_SIZE` was raised 1.5 GiB→16 GiB (the self-inline working set peaks ~9.7 GB). `tiny_host` seeds the first compiler (CC0, ~11h — the irreducible bootstrap origin); native compilation is ~5000× faster (full self-compile in 7.9 s). The heap-size change propagates over one generation (CC0→CC1→**CC2**); **CC2 == CC2(CC2_source)** byte-identical, and CC2 also compiles `kernel.la` correctly (native==host). Honest limits: the first seed still needs `tiny_host`; no build.sh self-host regression test yet (the 11h seed is too slow per build). See `STAGE4_STATUS.md`.
- [~] Standard optimizations (inlining, dead-code elimination, constant folding) —
      **codegen-quality audit done 2026-07-14** (register alloc: none / stack-machine
      + universal heap-boxing; no const-fold beyond int-literal decode; glyph-level
      reachability DCE only; no strength-reduction/peephole; `INLINE` is a total
      whole-program linking device, not a speed pass; the dominant cost is the
      **allocation rate** — one 24 B env frame per reduction, 48 B/closure, 24 B per
      arithmetic result, feeding the mark-sweep). Prioritized passes (all pure codegen,
      zero autology cost): **#1 compile-time β-reduction / static-redex inlining** (the
      big win — drains the env-frame/closure garbage), #2 constant folding, #3 peephole,
      #4 uncurrying (runtime change), #5 int unboxing (runtime change), #6 register alloc
      (secondary, not the headline).
  - [x] **#1 compile-time β-reduction — DONE + self-host-verified (2026-07-14).**
        Slice 2 (`523b5f6`) extends `BETA` to LAM/thunk args (the combinator-flattening
        win: IF/AND/PAIR/FST pass thunks) — reduces when `OCCURS(x)(body) ≤ 1` (bounds
        bloat + guarantees termination, blocking Ω) AND every FREE var of the arg has
        NO_BINDER in body (capture-safe, no fresh names). Win: IF+PAIR/FST program
        12625→11737 B (−7%, 5× slice 1). Self-host fixed point holds (707569 B, still
        −17 KB net of pre-β); all V1–V5 PASS (fixed point / drift / arith / kernel /
        β-suite incl. occ=0/1/≥2, capture, IF-flatten, Z-recursion). Slice 1 below:
  - [~] **slice 1 (2026-07-14,
        `114254e`).** New pre-codegen AST pass `BETA` (zero runtime change) substitutes
        `(la x. body)(arg)` at compile time when `arg` is a syntactic VALUE, killing a
        closure alloc + env-frame alloc + indirect call per redex. **Slice 1** = VAR/STR
        args only (capture-free via NO_BINDER, bloat-free; β-value is sound under CBV —
        a value has no effects and evaluates to itself). Self-referential win: selfhost.bin
        **724318→696042 B (−28 KB / −3.9%)** net of the added glyphs. All PASS: fixed point
        (byte-identical 2-gen), drift (RT untouched), arithmetic (folds intact), kernel.la
        speaks the Word, β correctness via the new native compiler (value/var/shadow/
        capture/effect/Z-recursion). Same #2 lesson applied: BETA_SAFE gated behind a lazy
        `IF NODE_TAG=LAM`, not eager AND. **Slice 2 (LAM/thunk args = the bigger closure-
        elimination win, needs occurrence-bound + capture handling) is the next step.**
  - [x] **#2 arithmetic constant folding — DONE + self-host-verified (2026-07-14,
        `695e579`).** add/sub/mul of two int-literals fold at compile time to `mov rax,
        <k>; call rt_box_int`. Fixed a subtle bug first (CG_BIN's operands can be any
        node kind; `IS_INT_LIT`'s eager AND deref'd APP_F/APP_A on a LAM operand →
        exit 70; guarded via `INT_LIT_SAFE` with a leading `NODE_TAG="APP"` check).
        Regen'd the Stage-4 fixed point (selfhost.bin 691847→724318 B, byte-identical
        2-gen convergence), drift guard green (RT untouched), cross-engine arithmetic
        native==host, kernel.la output byte-identical (K6b unaffected).
        **★ Finding: the self-host is NOT GC/scale-fragile** — the initial crash was
        this bug, not a GC marking gap (ruled out: 64× fewer GCs crashed identically).
        So there is no GC-scale wall gating the allocation-changing passes; #1 stays open.
- [ ] GC tuning (generational allocation, reduced pause time)

### Polish (orthogonal to the OS — safe to improve in parallel)
- [x] Onset/energy fix (resolve the Beauty / Becoming-Form phonetic collision) — collision closed (8/8 injective, verified host==VM in the full audit); honest cost: concordance 0.73→0.71 (onset cues discriminate but aren't ontologically ordered — documented, not chased). **⚠ 2026-08-18: the 0.71 figure WILL MOVE.** VOID's vowel nucleus was corrected to match BEING's /ɑ/ (see the five-vowel finding below); `build.sh`'s instantiation-fidelity assertion must be recomputed from a real run, and the 8/8 injectivity re-confirmed FIRST. Edited in-tree, **not yet verified**.
- [ ] Stratified fidelity measurement (roots vs. composites)
- [ ] Fractal Monoglyph — depth recoverable by decomposition, not surface marks
- [ ] Formant-table single source of truth — the nine vowel triples are stated
      independently in `phonym.la` and `phonsem.la`. **Measured 2026-08-18: all nine
      AGREE** — not a divergence. The defect is structural: they agree by care, not
      construction, and no gate catches a future one-sided edit. `goertzel.la` already
      shows the right pattern (it *imports* phonym's oscillator as a single source of
      truth); `phonsem.la` does not import `phonym.la` at all.
- [ ] Compound spectral recovery as a build gate — the ⊗-compound recovering BOTH
      parents' formants is demonstrated but ungated (`goertzel.la` gates Love /u/ only).

---

## Phase II — Citrinitas: The Operating System

*The thirteen-layer strong-definition OS, built in and as Lingua Adamica.
Status: barely begun — this is the larger road ahead (a year-plus of work).*

- [~] 1. Bootloader *(GRUB/multiboot1 during bring-up; sovereign bootloader is K7)*
- [~] 2. Kernel — **sovereign bare-metal kernel STARTED 2026-07-04** (branch
      `kernel-k1`). This IS the Phase-III LogosKernel, begun early — no longer
      inheriting Linux. The kernel is Lingua Adamica compiled by native_codegen3
      on a thin asm HAL; it implements the `syscall` instruction itself, so the
      SAME LA binary runs on host and metal (b_τ ≡ f_τ to the metal). Staged
      K1–K7, each brick verified green before the next:
  - [x] K1 — boot: multiboot1 + 32→64-bit trampoline → the LA image runs on bare
        metal and speaks the Word over serial, no host OS. QEMU-gated. (`3fee4a0`)
  - [x] K2 — IDT + 32 exception handlers: a CPU fault is a diagnosed serial halt
        (`EXCEPTION <vec>`), not a triple-fault — loud failure at ring 0. (`479e03c`)
  - [x] K3a — physical memory manager, pure-logic core (parse the multiboot mmap →
        largest arena → bump + free-stack frame allocator); verified **host==native**
        (the strong oracle — the PMM policy is pure logic). (`8ad0007`)
  - [x] K3b — wire the REAL memory map on the metal: `MB_FLAGS|=0x2` requests the
        map, `boot.asm` threads the mbi pointer (EBX) to a fixed scratch (0x300000),
        and the new `peek(addr)` runtime builtin (first native_codegen3 extension —
        `rt_peek`, native-only) lets `pmm_metal.la` walk the loader's REAL mmap via
        `peek`: largest arena 0x100000, first frame allocated. QEMU-gated
        (`gate_k3b.sh`). Two substrate bugs fixed en route: the runtime stack guard
        assumes a Linux-sized 8 MiB stack (underflowed on the metal → LA image now
        gets a tall stack at 0x8000000); and `RTLEN` must track the runtime byte
        length (a 23-byte skew silently truncated the Linux-ELF path, invisible to
        the metal `incbin`).
  - [~] K4 — virtual memory: 4-level paging, map/unmap, W^X + NX, higher-half
        kernel, the LA heap backed by real PMM frames
    - [x] K4a — paging pure-logic core (the strong oracle, host==native, like
          K3a): `paging.la` — x86-64 4-level paging as pure arithmetic (no
          bitwise ops in LA): a canonical 48-bit vaddr decomposes into its
          PML4/PDPT/PD/PT indices + offset via `div`/`mod` against the four page
          scales; a PTE `(paddr & ~0xFFF) | flags` is assembled as
          `PAIR(low32)(high32)` (the two-dword form `boot.asm` writes and K4b
          will `poke`, so the NX bit at bit 63 needs no >2^62 host literal); and
          **W^X** is enforced by `MK_PTE`, the sole PTE constructor, which halts
          loudly (`error`) on a writable+executable request. Verified
          byte-identical host==native, and the W^X violation halts loudly on
          BOTH engines (`gate_k4a.sh`: success oracle + `paging_wxfail.la`
          loud-refusal regression).
    - [x] K4b — wire paging to the metal (QEMU-gated, like K3b). **DONE, both
          halves.** *Write half:* the `poke(addr)(byte)` runtime builtin (write-twin
          of `peek`, a 24-byte `rt_poke` appended after `rt_peek`); `paging_metal.la`
          allocates a real frame from the K3 PMM, BUILDS a K4a PTE in it via `poke`,
          and reads it back byte-identical via `peek` (`gate_k4b.sh`, QEMU).
          *Capstone — the CR3 SWITCH:* the `set_cr3(pml4_phys)` builtin (the
          load-twin of peek/poke — a 22-byte `rt_set_cr3`, `mov cr3, rax`, appended
          after `rt_poke`, so again only `RTLEN` 9666→9688 / `LITERAL_BASE`
          4204090→4204112 shift); `paging_cr3.la` builds a whole 4-level table in
          real PMM frames (identity low 1 GiB, a SUPERSET of boot.asm's map, PLUS
          `PDPT[1]→PD1→` a 2 MiB page boot does not map), loads its base into CR3,
          and reads a sentinel back through the HIGH vaddr `0x40000000` — a vaddr
          only the LA table maps — proving the CPU walked the LA-built table
          (`gate_k4b_cr3.sh`, QEMU). Paging is live on the metal.
    - [~] K4c — higher-half kernel, NX/W^X live, the LA heap backed by real PMM
          frames. **W^X-live slice DONE** (QEMU-gated, like K4b): `paging_wx_live.la`
          rebuilds the K4b-capstone table but maps the distinguishing high test
          page (vaddr 0x40000000 → phys 160 MiB) **READ-ONLY** (`PDE2M_RO` =
          P|PS, no W bit); it pokes a sentinel at that phys frame via the writable
          identity alias, switches CR3, **reads** the sentinel back through the
          high RO vaddr (`K4C WX READ 171` — the mapping is live + readable), then
          **writes** through the same RO vaddr → the CPU raises a page-protection
          `#PF` (K2's IDT diagnoses `EXCEPTION 0e`, isa-debug-exit FAIL → QEMU
          exit 35). So paging PROTECTION (not just K4b's translation) is enforced
          on the metal. The substrate is armed in `boot.asm` behind `%ifdef
          K4C_WX` (like K2's fault-injection, so every other kernel ELF's boot
          bytes stay byte-identical): **CR0.WP** (bit 16 — a ring-0 write to a W=0
          page faults instead of silently succeeding) + **EFER.NXE** (bit 11 —
          NX@bit63 honored, not a reserved-bit fault). `gate_k4c_wx.sh` asserts
          the RO-read line AND the write-fault (a regression disarming WP would
          let the write silently land → exit 33 → the gate fails); wired into
          `build.sh`. **NX-live slice DONE** (the execute-twin): a FOURTH
          native_codegen3 HAL primitive, **`exec_at(vaddr)`** (`rt_exec_at`, 24
          bytes, the execute-twin of peek/poke/set_cr3 — `call rax` into the
          vaddr; appended after `rt_set_cr3` so only `RTLEN` 9688→9712 /
          `LITERAL_BASE` 4204112→4204136 shift, the embedded `RT` blob + drift
          guard `count` + `native_codegen3_selfhost.bin` all regenerated to the
          new fixed point via `regen_selfhost.sh`). `paging_nx_live.la` maps the
          high test page **NO-EXECUTE** (`NX_HI` = bit 63) over a frame holding a
          lone `ret` (0xC3), switches CR3, peeks the ret byte back (`K4C NX ARMED
          195` — frame live), then `exec_at`s the high vaddr → the instruction
          FETCH raises `#PF` (`EXCEPTION 0e`, exit 35); the `ret` never runs and
          `K4C NX RET` never prints (it would only if NXE were disarmed →
          gate fails). `gate_k4c_nx.sh` wired into `build.sh`. So **NX/W^X is live
          on the metal**, both halves proven by a real CPU fault. **HEAP-on-PMM
          slice DONE** (QEMU-gated, like K4b): `paging_heap.la` goes one level
          DEEPER than any prior brick — every earlier slice mapped 2 MiB *leaf*
          pages, but a real heap allocator wants 4 KiB granularity, so this builds
          a full **PT (the 4th paging level)** and maps a contiguous heap window
          (`HEAP_VBASE 0x40000000` + i·4 KiB, i∈0..3) onto **distinct PMM-allocated
          frames** (`PT0[i] → frame i`, `TBL` = P|W, no PS). New folds `ALLOC_N`
          (fold-allocate N frames → `PAIR(list)(state)`), `FILL_PT`, `WRITE_HEAP`.
          After the CR3 switch it pokes `200+i` into each heap page **through the
          high vaddrs** (the MMU walks `PT0[i]` to reach frame i), then reads back:
          `K4C HEAP0 200`/`K4C HEAP3 203` (four independent 4 KiB mappings hold
          distinct values) and `K4C HPHYS0 200`/`K4C HPHYS3 203` (those same values
          at the frames' *identity* addresses → the high heap writes really landed
          in distinct real PMM frames). high-read == phys-read == written value ⟹
          the heap is genuinely backed by VMM-mapped PMM frames the CPU reaches by
          walking the LA-built table. `boot.asm` UNCHANGED (plain translation, no
          WP/NXE); reuses peek/poke/set_cr3 — **no new native_codegen3 builtin**, so
          Stage 4's fixed point is untouched (no `regen_selfhost.sh`). `gate_k4c_heap.sh`
          wired into `build.sh`. ▶ Remaining K4c slice: **higher-half kernel** (relink
          the LA image off its baked-in `0x400000` absolute addrs to a high vbase).
          **SCOPED 2026-07-09, DEFERRED to just-before-K6** (its only payoff — freeing
          the low canonical half for user processes — is a K6 concern; K5 needs none of
          it). Approach: target the **-2 GiB half `0xFFFFFFFF80000000`** (image at
          `+0x400000`), which is *exactly* the region a sign-extended `disp32` reaches —
          so **no opcode-form changes**: all addr LOADS are already `mov r64,imm64`
          (`MOV_RAX_IMM`/`CALLR`…), mem operands are `[disp32]` abs (sign-extend-safe),
          RT-internal calls are `rel32` (move for free), and `LEBYTES` already emits
          two's-complement so a high-half addr as a NEGATIVE int serializes correctly.
          The trap: `native_codegen3` is the SHARED compiler (every Linux-hosted binary +
          the Stage-4 self-host loop), so it must NOT change globally → a **kernel-only
          HH compile variant** (`native_codegen3_hh.la` + `%ifdef HIGHHALF` re-`org` of
          `native_codegen3_rt.asm` to `0xFFFFFFFF80400078`), leaving Stage 4's fixed point
          + `native_codegen3_selfhost.bin` UNTOUCHED (no `regen_selfhost.sh`). Change-set:
          (1) hh variant overrides ~8 base constants (`VADDR`/`LITERAL_BASE`/the `RT_*` +
          GC-global `*_ADDR` slots) and **decouples heap/stack base from `VADDR`** (keep
          them low-identity so only the ~few-MiB image maps high, not the 16 GiB heap);
          (2) re-org'd RT blob; (3) `kernel.ld` `AT()` (LMA `0x400000` phys / VMA high);
          (4) `boot.asm` adds a high-half mapping (`PML4[511]→PDPT[510]→PD`, a few 2 MiB
          entries over the image frames), KEEPS the low identity map live (heap/stack/
          syscall-handler stay low), `jmp` to the high `LA_ENTRY`; (5) gate: QEMU boot,
          assert `entry.inc` ≥ `0xFFFFFFFF80000000`, high-mapped image speaks the Word →
          exit 33 (K2 catches any stray low ref as `#PF`). Sharp edges to verify: nasm
          64-bit `org` + `[abs]`→`disp32` truncation; the `LEBYTES` negative round-trip.
  - [~] K5 — timer IRQ (PIC/PIT) + tasks: cooperative → preemptive scheduler
    - [x] K5a — the timer IRQ live on the metal (QEMU-gated, like K4b/K4c).
          `timer.asm` (entirely `%ifdef K5_TIMER`, so other kernel ELFs stay
          byte-identical — verified: `boot.asm` without the flag is byte-for-byte
          HEAD) remaps the 8259 PIC (IRQ0 → vector `0x20`, clear of the CPU
          exceptions), programs PIT channel 0 to ~100 Hz (mode 3, divisor 11932),
          installs `IDT[0x20]` → `timer_isr`, unmasks only IRQ0, and `boot.asm`
          `sti`s before jumping to the LA image. `timer_isr` is transparent — it
          touches only `rax` (saved) + `rflags` (restored by `iretq`): bump a
          64-bit tick counter at `TICK_ADDR` (`0x310000`, the identity-mapped
          scratch gap by `MBI_SAVE`), master-PIC EOI, `iretq`. `timer_probe.la`
          spins reading the tick's low byte via `peek()` until nonzero
          (tail-recursive → bounded stack, safety-capped so a broken timer can't
          hang) and prints `K5 TICKS n` — an ASYNCHRONOUS IRQ0 landed mid-LA-spin,
          the ISR ran, and the LA code resumed with every register intact
          (preemption *capability* proven, b_τ ≡ f_τ). `gate_k5a.sh` asserts
          `n ≥ 1` + exit 33; wired into `build.sh`. No new native_codegen3 builtin
          (reuses `peek`), so Stage 4's fixed point is untouched.
    - [~] K5b — tasks + context switch. **SCOPED 2026-07-09.** Runtime ABI: `rbx` =
          current env, `r15` = heap bump (a SHARED single heap across all tasks),
          `rbp`/`r12`–`r14` callee-saved, `STACK_BASE`/`STACK_LIMIT` globals (GC
          scan-bound + stack guard). **Pivot finding: `rt_gc` is conservative
          mark-sweep, NON-MOVING** (roots = GP regs via `REGDUMP` + `TRUE`/`FALSE`
          + a conservative scan of `[rsp, STACK_BASE)`). Non-moving ⇒ the
          multi-stack problem is **additive marking, not pointer fixup**: a
          suspended task's saved regs + stack stay valid across a GC in another
          task; the collector just has to TRACE them. Three pieces: (1) **GC root
          generalization** (foundational, ~20 lines in the root phase) — iterate a
          task table, and for each SUSPENDED task scan its TCB-saved regs +
          `[saved_rsp, stack_base)`, alongside the current task's existing path;
          (2) **two new HAL builtins** `spawn(closure)` (alloc a task stack + TCB,
          plant an initial frame entering `rt_apply(closure)` on first switch,
          register it) and `yield()` (save ctx to current TCB → next runnable →
          restore; also swap the `STACK_BASE`/`STACK_LIMIT` globals) — the FIRST
          `native_codegen3` extension since `exec_at`, so it reopens the
          `regen_selfhost` + Stage-4 fixed-point re-commit (the add-a-builtin
          recipe); (3) **per-task stacks** carved from the heap/bss (Linux) or PMM/
          identity RAM (metal); the current guard assumes 7 MiB headroom, so
          per-task stack size/guard is a parameter. **DECIDED (Erik, 2026-07-09):**
          (a) **cooperative FIRST** — K5b.1 = spawn + yield + the GC change +
          regen, **gated Linux-hosted** (spawn/yield are userspace green-thread
          switches, no ring 0 → seconds/iteration, not a QEMU boot); two LA tasks
          ping-pong, a forced GC with both stacks live exercises the root change.
          (b) **preemption = safe-point yield-flag** (K5b.2, later) — the K5a timer
          ISR just sets a yield-pending flag; LA code yields at safe points
          (`rt_apply` entry), so it NEVER preempts inside `rt_gc`/`alloc`; QEMU-
          gated. Scheduler policy = **asm round-robin** over the task table for
          now (reachable from the ISR), an LA-expressed policy is a later
          refinement.
      - [x] K5b.1 — cooperative tasks **COMPLETE** (1a context switch + 1b GC-safe).
            **K5b.1a** (append-only context switch):
            `spawn`/`yield` — the 5th/6th native_codegen3 extensions, APPENDED after
            `rt_exec_at` so ONLY `LITERAL_BASE` (4204136→4205430) + `RTLEN`
            (9712→11006) shifted (`rt_exec_at` ABS unchanged = 4204112, verified) —
            no earlier `RT_*` moved. A task = a TCB `{state, rsp, rbx/rbp/r12-r14,
            stkbase, stklimit, closure}`; `yield` saves the callee-saved set + rsp
            (NOT r15 — the heap is SHARED, one bump lineage) and round-robins over
            `TASK_TABLE`, swapping the `STACK_BASE`/`STACK_LIMIT` globals; `spawn`
            plants an initial frame so `task_trampoline` runs the closure via
            `rt_apply` on first schedule; per-task stacks carved from the top of the
            heap region. `regen_selfhost.sh` reached the new fixed point in 2 iters
            (image 682912→689956 B); Stage-4 fixed point re-verified; drift-guard
            count 9712→11006. `task_pingpong.la` interleaves `A B A B A B done`
            (each worker's loop counter preserved across a real context switch on
            its own stack), gated LINUX-HOSTED (`gate_k5b1.sh`, no QEMU), wired into
            build.sh. HONEST LIMIT: `rt_gc` still scans only the current task's
            stack — the probe is short (<< GC_INTERVAL) so no GC fires mid-suspend.
      - [x] K5b.1b — GC root generalization. **DONE.** `rt_gc`'s root phase now
            iterates `TASK_TABLE` and, for each OTHER runnable task, scans its saved
            regs (rbx/rbp/r12-r14) + its stack `[saved_rsp, stkbase)` — the
            collector is NON-MOVING, so this is purely additive marking, no
            relocation (the suspended contexts stay byte-valid). Written with only
            registers `.consider` preserves (rbp/rdi/r9/r14; r12 = threaded
            worklist ptr). The `TCB_*`/`MAXTASK` `%define`s moved above `rt_gc`
            (order-sensitive; emit no bytes). Editing `rt_gc` (early) grew it by
            **exactly 125 bytes**, shifting every post-`rt_gc` `RT_*`/`*_ADDR`
            constant by a uniform **+125** (pre-`rt_gc` constants verified
            unchanged) — 23 `.la` constants re-derived from the nasm listing,
            `regen_selfhost` (2 iters, image 689956→690527 B), Stage-4 fixed point
            re-verified, drift count 11006→11131. `task_gc.la`: task A holds a
            canary across a yield while task B churns ~400 MB (>> 64 MB
            `GC_INTERVAL`) forcing the collector to fire mid-suspend; A's canary is
            byte-intact on resume → `SURVIVED`. `gate_k5b1b.sh` (Linux-hosted),
            wired into build.sh. **Cooperative tasks are now GC-safe across
            suspension** (K5b.1 complete). *(Test strengthened in K5b.1c — see
            below: the ORIGINAL K5b.1b test was a trivial pass because the GC only
            fired at 16 GiB exhaustion, so no GC actually ran; K5b.1c's periodic GC
            makes it fire real collections while a task is suspended.)*
      - [x] K5b.1c — **periodic GC** (the collector was firing ONLY at 16 GiB
            exhaustion; the `NEXT_GC`/`GC_INTERVAL` interval trigger was dead code).
            Found while building K5b.2: any sustained LA loop allocates (a boxed
            int + an env frame per `rt_apply`), so with no periodic GC the heap
            grows unboundedly until 16 GiB — fine on Linux (lazy 16 GiB bss) but on
            metal it climbs past physical RAM and faults, AND it meant the K5b.1b
            GC test never actually fired a GC (verified: 0 collections). Fix:
            `alloc24`/`alloc_blob` now fire `rt_gc` when the bump top crosses
            `NEXT_GC` (already inited by `rt_init` to `HEAP_BASE + 64 MB`), then
            advance the threshold — the same non-moving, register-transparent
            collector the exhaustion path calls. Edits early routines → uniform
            constant shift (+70 B, 42 constants re-derived + regen). **Verified:**
            a 2.4 GB string churn stays at 806 MB RSS (bounded; was unbounded), and
            `task_gc` now fires several real collections (~320 MB churn → 263 MB
            RSS) while a task is suspended → the canary genuinely survives.
            **HONEST LIMIT:** the conservative collector reclaims *blob* garbage
            well but RETAINS tight-loop 24-byte garbage (an 80 M-int loop → 2.75 GB
            RSS) — a false-retention issue (conservative stack scan / Z-combinator
            chain) that bounds how much a metal LA program can compute. Documented,
            not yet fixed; it's what defers the K5b.2 metal demo.
      - [x] K5b.1d — **GC interior-pointer corruption fixed (object-start bitmap).**
            The real cause of K5b.2's self-host breakage, isolated and fixed. The
            conservative mark-sweep's `.consider` accepted any candidate whose
            `[rax-8]` merely LOOKED like a header (kind 1..5, small size field) and
            OR'd the mark bit INTO it — so a stale/derived INTERIOR pointer from the
            register/stack scan, whose target bytes looked header-like, got bit-8
            flipped in LIVE data. Frequency- AND payload-gated: the machine-code
            self-compile (bytes `0x01`–`0x05` everywhere) corrupts under frequent GC
            ("expected = in glyph definition" — NOT the periodic GC itself); ascii/int
            workloads do not. Isolated with a fast reproducer (an 8-byte small-int-word
            blob corrupts, an ascii blob does not; the changed byte is exactly the
            `MARKBIT` flip). **Fix:** an object-start **bitmap** (1 bit / 8-byte
            granule) — `alloc24`/`alloc_blob` record each object's start; `.consider`
            marks only candidates whose `(rax-8)` start-bit is set, rejecting
            interior/false pointers before the corrupting write (guarded on
            `BITMAP_BASE != 0`). **Metal-safe via a CPL gate** in `rt_init`: ring 3
            (Linux self-host) enables the bitmap, ring 0 (the metal kernel) leaves it
            off (the 16 GiB-high bitmap window is unmapped on metal, and `kernel.la`
            barely allocates) — no `boot.asm` change, no PROL branch, no new builtin.
            Shipped the **4 MB** GC interval with it (tight-loop RSS 2.88 GB → 757 MB),
            now safe. **Verified:** reproducer (off=corrupt / on=fixed), normal programs
            native==host, drift guard (RTLEN → 11360), the **4 MB native self-host
            reaches a byte-identical fixed point** where it previously corrupted, and
            **all 13 kernel gates green on QEMU** (incl. K5b.1b's task-GC canary firing
            real collection under the multi-task root scan). Commit `a9d46c3`.
            **Honest limit unchanged:** this is a CORRECTNESS fix, NOT a retention fix
            — it rejects INTERIOR false pointers but not stale pointers to REAL object
            starts, so K5b.1c's tight-loop over-retention is untouched; retention stays
            interval-driven (4 MB → 757 MB is the lever) + a residual O(N)-ish growth.
      - [x] K5b.2 — **preemptive tasks on the metal — DONE + gated (safe-point
            yield-flag).** Two workers that NEVER call `yield()` interleave purely
            because the K5a timer preempts them. `gate_k5b2.sh` (QEMU, `-m 1024`):
            the A/B print sequence has ≥3 runs (`ABABAB`), `done` prints, exit 33.
            **The mechanism:** the timer ISR (assembled `-dK5B2`) sets a byte
            `YIELD_PENDING` (in the LA runtime, addr drift-guarded against the rt
            listing); `rt_apply`'s safe point checks it on every reduction and, if
            set, preserves `r10`/`r11` across an `rt_yield` context switch — never
            inside `rt_gc`/`alloc`. Inert under Linux (nothing sets the flag), so it
            self-hosts. Task stacks are CPL-gated in `rt_init`: `HEAP_END` at ring 3
            (Linux, cooperative gates unchanged) / `0x38000000` at ring 0 (metal,
            mapped low RAM); MAIN gets a high stack `0x3F000000` (`%ifdef K5B2` in
            boot.asm, byte-identical when off).
            **Two real bugs found bringing it up (both now fixed):**
            (i) **`rt_gc` didn't root a fresh task's closure.** The K5b.1b per-task
            root scan covered saved regs + stack, but a spawned-but-not-yet-run task
            holds its closure ONLY in `TCB_CLOSURE` (spawn zeroes the regs). A
            preempting worker's allocations triggered a GC while the other worker was
            still fresh → its closure was collected → it faulted on first run
            (`rt_apply` "applied a non-function", exit 70 — which the kernel's
            `.sys_exit` was silently mapping to success 33, masking it). Fix: scan
            `TCB_CLOSURE` in the per-task roots. This also strengthens K5b.1b.
            (ii) **demo-design race** — MAIN's fixed drain count was smaller than the
            scheduler slices the long-SPIN workers needed, so MAIN reached `done` and
            exited first, killing the workers. Fix: `DRAIN`(=200) ≫ worker slices, and
            SPINCOUNT(=2500) tuned so a 10 ms tick reliably lands mid-worker.
            Blocker (1) (self-host breakage) was already resolved by K5b.1d's
            object-start bitmap; the safe-point + all metal edits reach a byte-identical
            Stage-4 fixed point. Files: `rt_apply` safe point + `YIELD_PENDING`/
            `TASK_STACK_TOP` slots + `rt_init` CPL gate + `rt_spawn` indirection +
            `rt_gc` closure root (native_codegen3_rt.asm, 42-const reshuffle re-derived,
            regen'd); `task_preempt.la`; `build_k5b2.sh`/`gate_k5b2.sh` (wired into
            build.sh); `timer.asm`/`boot.asm` `%ifdef K5B2`. A `%ifdef K5B2_DBG`
            diagnostic (per-tick serial marker + real exit-code print) is kept, gated
            and byte-identical when off. Details in [[logos-kernel]].
  - [~] K6 — user mode (ring 3) + a real syscall service layer. **SCOPED
        2026-07-10.** Current baseline: GDT null/kcode0x08/kdata0x10 (no ring-3
        selectors, no TSS); paging identity-maps low 1 GiB as 2 MiB supervisor
        pages (flags 0x83, NO U/S bit); syscall_entry does write/exit only and
        stays ring 0 (jmp rcx, not sysret); the LA image runs at ring 0.
        **Three hard problems shaping the staging:** (1) the CPL-gate conflation —
        rt_init keys the object-start bitmap + TASK_STACK_TOP on CPL (ring 3 =
        "Linux"), so LA at ring 3 ON METAL wrongly enables the 16 GiB-high bitmap +
        HEAP_END task stacks (unmapped → fault); fix = discriminate metal-ness by a
        BOOT-SET memory flag, not CPL (Linux is never "metal", so self-host stays
        untouched). (2) user pages need the U/S bit (current 0x83 is supervisor).
        (3) ring transitions need a TSS (RSP0) + ring-3 GDT selectors + a real
        sysret/iretq-to-ring-3 return.
        **Bricks:**
      - [x] **HH1 — higher-half — COMPLETE (2026-07-14).** The kernel runs wholly in
            the −2 GiB half; the low canonical half is freed for user processes (HH2).
            Staged HH1a (boot high, dual-mapped) → HH1b (LA image high, low map dropped).
            _(original scoping below)_ (roadmap's "just-before-K6" prereq). Relink boot +
            kernel to the −2 GiB half 0xFFFFFFFF80000000 (sign-extended disp32
            reaches it → NO opcode changes, only addresses move); map PML4[511]→…
            to the kernel's phys pages, jump high, drop the low identity map to free
            the low canonical half. The LA image's fixed RT_* move high → a
            kernel-only HH rt variant (native_codegen3_hh, base 0xFFFFFFFF80000078)
            via the derive_consts tooling with a new base; Stage-4/Linux self-host
            keeps the low-based rt. BIGGEST/RISKIEST brick (dual RT address-sets).
            Gate: kernel speaks the Word from the high half. **Staged:**
          - [x] **HH1a — the boot executes from the high half — DONE + gated
                (2026-07-14).** The 32-bit trampoline builds, ALONGSIDE the low identity
                map, a HIGH map (`PML4[511]→pdpt_high[510]→` the existing low-1-GiB `pd`),
                aliasing every low physical page P at `0xFFFFFFFF80000000+P` (the −2 GiB
                indices are 511/510/0). After long mode the boot computes the high alias
                of `hh_high` (its low link addr + `HIGH_BASE`) and `jmp`s there; running
                high, `lea [rel hh_high]` now resolves to `0xFFFFFFFF8........`, and it
                prints `HH1@` + the top nibble of its own RIP (`F` = proof). The low
                identity map is KEPT, so absolute data refs + the still-low LA image work
                — it hands off and speaks the Word. All in `%ifdef HH1` (`boot.asm` +
                `build_hh1.sh` + `gate_hh1.sh`, `-m 256`); K6C `.boot32`/`.rodata`
                byte-identical to HEAD, all K6a–K6c3b gates still PASS. `gate_hh1.sh`:
                `HH1@F` + `I AM THAT I AM` + exit 33. Proves the −2 GiB relink + high
                mapping + high execution WITHOUT the risky compiler-variant work.
          - [x] **HH1b — the kernel runs WHOLLY in the higher half — DONE + gated
                (2026-07-14). ★ HH1 COMPLETE.** A kernel-only compiler variant
                `native_codegen3_hh` (generated by `gen_hh_compiler.py`) rebases every
                address constant into the −2 GiB half by `high_signed = low − 2³¹`,
                written `sub(0)(mag)` (the constant fold collapses it to the 2's-comp
                literal — this LA has no negative literals), shrinks HEAP_SIZE to fit
                the high 1 GiB window (else `HEAP_END = HEAP_BASE+16 GiB` wraps 2⁶⁴ and
                premature-GCs), and swaps in the RT blob re-assembled at `org
                0xFFFFFFFF80400078` (via a new `RT_ORG` `%define` — the low default is
                byte-identical; disp32 sign-extends so NO opcodes change). It emits a
                high LA image (`p_vaddr`/`e_entry` = `0xffffffff80……`); boot (`%ifdef
                HH1B`) builds the high map, jumps high, re-points `LSTAR` at the high
                `syscall_entry` (syscall takes CS/SS from STAR, not the GDT, so no GDT
                reload needed), sets a high stack, drops the low map (`PML4[0]=0` + TLB
                flush), and enters the high image — which speaks the Word. **Bug caught
                on the metal:** the first pass missed rebasing `RT_INIT`, so `PROL`
                called low `0x4007b9` → #PF after the drop → triple fault; fixed by
                pattern-rebasing EVERY `RT_*`/`*_ADDR` glyph. `native_codegen3.la` /
                `selfhost.bin` UNTOUCHED (the Stage-4 self-host is a separate low build);
                low RT blob byte-identical; all K6a–K6c3b + HH1a gates still PASS.
                `gate_hh1b.sh` (`-m 256`): `I AM THAT I AM` from the −2 GiB half + exit
                33. **The low canonical half is now free for user processes (HH2).**
      - [x] **HH2 — per-process page tables (isolation proven) — DONE + gated
            (2026-07-14).** With the kernel wholly in PML4[511] (HH1), the low half is
            free per-process. A ring-0 kernel demo (`%ifdef HH2`, no LA image) builds
            TWO process PML4s that share the kernel `PML4[511]` (via `pdpt_high`) but
            hold DISTINCT low halves: each maps the same virtual page (6 MiB) to a
            different physical frame (32 MiB / 34 MiB). A CR3 round-trip proves
            isolation — under A write 0xAA, switch CR3 to B and write 0xBB to the SAME
            VA, switch back to A and read 0xAA (B's write never touched A's frame). A
            high stack (via the shared `[511]`) survives the CR3 switches; the process
            page tables are built through the still-live low identity map before the
            first switch. `gate_hh2.sh` (`-m 256`): `HH2 ISOLATED A=AA B=BB` + exit 33;
            all `%ifdef HH2`/`HH1_HIGHMAP`, other kernel ELFs byte-identical, HH1a/HH1b/
            K6 gates still PASS. **The process-model foundation.**
      - [x] **HH2b — a ring-3 LA PROCESS in its own address space — DONE + gated
            (2026-07-14).** Composes HH1 (kernel high) + HH2 (per-process PML4) + K6b
            (ring-3 LA). The kernel runs in the shared high half; a per-process PML4
            (`pml4_proc`) maps the LA image + heap + stack in its OWN user low half
            (`pd_proc[i]=i·2MiB|0x87`, U=1) and shares the kernel `[511]→pdpt_high` as
            SUPERVISOR (so ring 3 can't reach the kernel via the high alias). Boot jumps
            high, re-points LSTAR at the high `syscall_entry`, sets TSS `rsp0` to a HIGH
            kernel stack, builds `pml4_proc` (via the still-live low identity map),
            `CR3=pml4_proc`, sets METAL_FLAG, and iretq's to ring 3 at the low LA image
            — which speaks the Word through a syscall that crosses ring3-low → ring0-HIGH
            → ring3. `gate_hh2b.sh` (`-m 1024`): `I AM THAT I AM` + exit 33; all `%ifdef
            HH2B`, other kernel ELFs byte-identical, HH2/HH1b/K6b gates PASS. **An
            isolated address space per LA process — the process model, one process.**
      - [x] **HH2c — TWO isolated LA processes exchange a typed message — DONE +
            gated (2026-07-14). ★ THE FULL PROCESS + IPC MODEL.** One image template
            (`ipc_proc.la`) is copied into two offset-mapped per-process regions (A at
            phys +128 MiB, B at +256 MiB), each with its OWN low half (U=1) and the
            shared kernel `[511]` (supervisor); a role byte poked per copy makes the
            SAME image `send` under A / `recv` under B. A `send`s `"HELLO-FROM-A"` into
            the SHARED kernel channel and returns → `exit`; the kernel's `.sys_exit`
            (HH2c) switches CR3 to B, which `recv`s it and prints `B got: HELLO-FROM-A`.
            **Two metal bugs caught + fixed:** (1) the process offset-map made the GDT's
            low virtual resolve to the wrong frame → `iretq` `#GP`; fixed by loading a
            HIGH GDTR + HIGH TSS base (reachable via the shared `[511]` under any CR3).
            (2) the syscall handler read `k6c_chans`/`hh2c_stage` via LOW absolute
            addresses → the offset map sent each process's "channel" to its own region;
            fixed by RIP-relative access (`lea [rel …]`) so the high kernel hits the
            real SHARED data (works for the low-kernel K6c builds too). `gate_hh2c.sh`
            (`-m 512`): `B got: HELLO-FROM-A` + exit 33; all `%ifdef HH2C` (+ the shared
            `lea [rel k6c_chans]` — K6c/K6c2/K6c3 gates still PASS), non-IPC ELFs
            byte-identical. **Isolated ring-3 LA processes talking through the kernel's
            nervous system — the process/IPC model, realized.**
      - [x] **K6a — ring-3 privilege drop — DONE + gated (2026-07-11).** GDT += user
            code 0x20|3 / data 0x18|3 + a TSS (RSP0); ltr. STAR[63:48]=0x10 so
            sysretq lands in the ring-3 selectors. Maps ONE user 2 MiB page U=1
            (PD[128], flags 0x87) at phys 0x10000000 = 256 MiB, with U=1 forced up
            PML4[0]/PDPT[0] (U/S ANDs down the walk); copies a position-independent
            payload there and `iretq`s to it at CPL 3. The payload reads its own CS
            privilege into the message ("K6A CPL=3"), `syscall write`s it (a ring-3
            task cannot touch COM1 — the bytes on serial ARE the proof the syscall
            crossed ring3→ring0→ring3), then `syscall exit`. `gate_k6a.sh` (QEMU):
            "K6A CPL=3" + exit 33. All in `%ifdef K6A` (`boot.asm` + `build_k6a.sh`
            + `gate_k6a.sh`), other kernel ELFs byte-identical. **GOTCHA that ate a
            session:** the user page at 256 MiB needs RAM to *exist* there — the gate
            must boot QEMU `-m 512` (with `-m 256`, 0x10000000 is one byte past the
            end of RAM → every user-page/user-stack access "rejected", `ret` pops 0 →
            #UD at RIP=0 → QEMU BQL host-abort, NOT a guest fault). Proves the
            privilege machinery WITHOUT the LA-at-ring-3 caveats.
      - [x] **K6b — the real LA image at ring 3 — DONE + gated (2026-07-11).**
            `kernel.la`, compiled by native_codegen3, runs at **CPL 3 on the metal**: it
            speaks the Word (`I AM THAT I AM`) through a `write` syscall serviced
            ring3→ring0→ring3 and `exit`s (33) — `∃(∃)≡∃` from ring 3, the SAME image
            that runs at ring 0 under K1..K5 (`b_τ ≡ f_τ`). **The metal-flag
            discriminator (problem 1):** `rt_init` keyed the GC object-start bitmap +
            `TASK_STACK_TOP` on **CPL**, but CPL can no longer tell the two ring-3 cases
            apart — the LA image runs at ring 3 both under the Linux self-host AND on the
            metal here (both would take the "Linux" path ⇒ bitmap/stacks at the 16 GiB-high
            `HEAP_END`, UNMAPPED on metal ⇒ fault). Fixed by a **boot-set memory flag**.
            **Design note — deviated from the pre-spec, safely:** rather than *replacing*
            the CPL check (the planned "byte-identical 9-byte" swap), the edit *prepends*
            `cmp byte [rel METAL_FLAG],0 / jnz .metal` and KEEPS the CPL test as a
            fallback — so metal = (flag set) OR (CPL==0), and the ring-0 K1..K5 builds
            still take the metal path for free with no flag set. Honest cost: rt_init grew
            9 bytes, so every `RT_*` constant shifted +9 and `LITERAL_BASE` +17 (rt.asm's
            appended `METAL_FLAG: dq 0` adds the other 8) — all updated consistently in
            native_codegen3.la, and the **Stage-4 self-host fixed point was re-verified
            byte-identical (`selfhost.bin` 691847 B) and compiles kernel.la native==host**
            (build.sh Stage 4 + drift guard green), so the shift is sound. **boot.asm
            `%ifdef K6B`:** identity-maps the low 1 GiB USER (`0x87`, U forced up the whole
            walk), writes `1` to METAL_FLAG's absolute addr (derived per-build from the rt
            listing → `entry.inc`; this run `0x402d2f`) BEFORE entering the image, sets up
            the ring-3 GDT selectors + TSS (reuses K6a's), and `iretq`s to LA_ENTRY at
            CPL 3; the write/exit syscalls sysret back to ring 3. Heap ~68 MiB + task
            stacks at 0x38000000 (896 MiB) fit the low-1-GiB map; the 16 GiB bitmap stays
            OFF via the flag. `gate_k6b.sh` (QEMU **-m 1024** so the heap + 128 MiB stack
            is real RAM): `I AM THAT I AM` from CPL 3 + exit 33 — **PASS**. All in
            `%ifdef K6B` / `%ifdef RING3` (`boot.asm` + `build_k6b.sh` + `gate_k6b.sh`),
            other kernel ELFs byte-identical.
      - [x] **K6c — real syscall service layer — COMPLETE (2026-07-14).** Grew
            syscall_entry past write/exit into the process/IPC primitives; re-homed
            LogosIPC over in-kernel channels (the "nervous system"). Milestone gate
            (K6c.3b) GREEN: two ring-3 LA tasks exchange a typed message through a
            kernel channel. Staged K6c.1→.2→.3a→.3b, each gated:
          - [x] **K6c.1 — the kernel channel primitive, proven at ring 3 (single
                process round-trip) — DONE + gated (2026-07-14).** `syscall_entry`
                grows two LogOS-native syscalls: **`send`** (0x300) `send(chan,type,
                buf,len)` deposits a typed message into `k6c_chans[chan]` (a ring-0
                `.bss` array of 4 mailboxes, slot `[full:8][type:8][len:8][body:256]`,
                bounds-checked on chan and body-len → −1 else); **`recv`** (0x301)
                `recv(chan,outbuf,maxlen)` withdraws it, returning **two values** —
                `rax`=len copied to outbuf AND `rdx`=type (a second return the ring-3
                caller reads after sysret; both handlers touch only rax/rdx/r8/r9/r10,
                so rcx/r11 survive for sysret, like `.sys_write`). A hand-written
                ring-3 payload (K6a's philosophy — isolate the mechanics WITHOUT the
                two-process scheduler or an LA-runtime rebuild) SENDs (type 7, body
                "IAM") into channel 0, RECVs it back, and `write`s the recovered
                `K6C t7 IAM` — the channel is ring-0 memory a ring-3 task cannot touch
                directly, so those bytes prove send+recv crossed ring3→ring0(channel)→
                ring3 both ways (and that recv's rdx second-return survived sysret).
                All in `%ifdef K6C` (`boot.asm` + `build_k6c.sh` + `gate_k6c.sh`,
                `-m 512` like K6a, no native compile → fast); **every non-K6C kernel
                ELF's code/data sections (`.boot32`/`.rodata`/`.multiboot`) verified
                byte-identical** (assembled from pristine HEAD boot.asm), and the K6a
                + K6b gates still PASS. `gate_k6c.sh`: `K6C t7 IAM` + exit 33.
          - [x] **K6c.2 — two ring-3 tasks + a kernel context switch — DONE +
                gated (2026-07-14).** First time K5-style tasks and ring-3 combine
                (K5 tasks were ring-0). A cooperative **`yield`** syscall (0x302)
                drives a real kernel context switch: `.sys_yield` saves the calling
                task's FULL ring-3 context (16 GP regs, rcx=resume rip, r11=resume
                rflags, rsp=user rsp) into a 128-byte PCB (`k6c2_pcb[cur]`, freeing
                rax + a base reg via `k6c2_scratch`), flips `k6c2_cur`, and
                **`k6c2_run`** loads the other PCB and drops to ring 3 via `sysret`
                — one routine serving both the first launch (boot seeds each PCB
                with entry/rflags/stack-top) and a resume-after-yield (a fresh task
                and a suspended one are indistinguishable, the point of a context).
                Two hand-written ring-3 payloads (K6a's philosophy) share one U=1
                page (task A @0x10000000, B @0x10010000) with SEPARATE stacks: **A**
                `send`s (chan 0, type 7, "IAM") + yields → **B** (resumed) `recv`s
                chan 0, writes `K6C2 B got IAM`, `send`s the reply (chan 1, type 8,
                "YOU") + yields → **A** (RESTORED) `recv`s chan 1, writes `K6C2 A got
                YOU`, exits. A's line only appears if its context was saved AND
                restored, so it proves a genuine bidirectional switch (not a one-shot
                launch), with IPC crossing the privilege boundary both ways. All in
                `%ifdef K6C2` / `%ifdef IPC` (the channel layer now shared with K6c.1)
                (`boot.asm` + `build_k6c2.sh` + `gate_k6c2.sh`, `-m 512`, no native
                compile); non-K6C2 kernel ELF sections verified byte-identical, K6a/
                K6b/K6c gates still PASS. `gate_k6c2.sh`: both lines + exit 33.
                *Honest scope:* two ring-3 tasks in ONE shared address space (per-
                process page tables = HH2); cooperative yield (preemptive ring-3 =
                later).
          - [~] **K6c.3 — re-home the real LogosIPC typed layer.** Give
                native_codegen3's runtime `send`/`recv` builtins (emit the syscalls),
                rebuild the Stage-4 fixed point, and run two LA processes exchanging a
                real `logosipc.la` typed message through the kernel channel — the
                milestone gate. **Staged:**
            - [x] **K6c.3a — a single REAL LA process does IPC at ring 3 — DONE +
                  gated (2026-07-14).** Added metal-only `send`/`recv` builtins to the
                  LA runtime (`rt_send` binary `send(chan)(msg)` → `SYS_SEND`;
                  `rt_recv` unary `recv(chan)` → `SYS_RECV` into `recv_buf`, then
                  `rt_make_str` → boxed STR). Appended at EOF of
                  `native_codegen3_rt.asm` (safe recipe: existing RT_* unchanged, RT
                  blob 11455→11790 B, only RTLEN/LITERAL_BASE shift + new RT_SEND/
                  RT_RECV; wired into IS_BUILTIN1/2 + RT_BIN/RT_UN; `derive_consts.py`
                  labels added). The kernel channel stays byte-opaque (the TYPE lives
                  in the LA wire message — logosipc.la's `ENCODE` — so the typing layer
                  is transport-independent). Stage-4 self-host re-verified byte-identical
                  (selfhost.bin 707569→711208 B; send/recv never called by the compiler,
                  so transparent) + drift + arith/fold/β + kernel.la + IPC-compiles all
                  PASS. `boot.asm` `%ifdef K6C3` reuses K6b's ring-3 LA-image entry (via
                  a shared `LA_RING3_IMAGE` symbol) + the `%ifdef IPC` channel; the LA
                  image is `ipc_kernel.la` (`send(0)(msg)` then `print(recv(0))`).
                  `gate_k6c3.sh` (`-m 1024`): `K6C3 IPC OK` round-tripped through kernel
                  channel 0 from compiled Lingua Adamica + exit 33. All K6a/b/c/c2 gates
                  still PASS (the K6b entry re-gate is byte-neutral — a preprocessor
                  rename). Proves LA `send`/`recv` drive the kernel IPC channel.
            - [x] **K6c.3b — TWO LA tasks exchange a typed message — DONE + gated
                  (2026-07-14). ★ THE K6c MILESTONE.** `ipc2.la` (one LA image compiled
                  by native_codegen3) `spawn`s two runtime tasks: **A** `ENCODE`s the
                  logosipc wire message `"greet"<NUL>"HELLO"` and `send(0)`s it into
                  kernel channel 0, then `yield`s; the scheduler runs **B**, which
                  `recv(0)`s it and decodes `MSG_TYPE`/`MSG_BODY` (inlined BEFORE_NUL/
                  AFTER_NUL scans), printing `B rx type=greet` / `B rx body=HELLO`.
                  **No runtime change, no regen** — every ingredient was already proven:
                  send/recv (K6c.3a), spawn/yield (K5b, now shown working at ring 3 on
                  the metal for the first time), and the K6C3 ring-3 LA-image + channel
                  boot. `gate_k6c3b.sh` (`-m 1024`): both decoded lines + exit 33. The
                  typed layer travels A → kernel channel → B across a task switch, from
                  Lingua Adamica at CPL 3 — LogosIPC re-homed onto the kernel as the
                  "nervous system." **K6c COMPLETE.**
        **Ordering (recommended):** K6a first (cheap, isolates ring-3 mechanics on
        the current identity map), THEN HH1 (big reorg, now with a ring-3 target to
        validate against), then K6b/K6c. **K6a + K6b + K6c COMPLETE (through the K6c.3b
        milestone) — next is HH1 (higher-half) / HH2 (per-process page tables), then K7.**
        _(superseded ordering note below kept for history)_ **K6a + K6b + K6c.1 + K6c.2 DONE — next is
        K6c.3 (real logosipc.la typed message between two LA processes = the K6c
        milestone gate) or HH1.**
  - [x] K7 — sovereign bootloader (replaces GRUB) — **COMPLETE (2026-07-15).**
        LogOS boots itself off a raw disk with no GRUB / no multiboot loader /
        no QEMU `-kernel`. **Staged:**
      - [x] **K7a — the sovereign boot sector — DONE + gated (2026-07-14).** LogOS's
            OWN 512-byte MBR (`boot7.asm`, `nasm -f bin`, 0x55AA signature) boots from a
            raw disk image — no GRUB, no multiboot, no QEMU `-kernel`. The BIOS loads
            sector 0 at 0x7C00; it inits COM1, announces `K7 real` in 16-bit real mode,
            builds a GDT, enters 32-bit protected mode, announces `K7 pmode`, and
            exit(33)s via isa-debug-exit. `build_k7a.sh` lays it into sector 0 of a
            1 MiB raw disk; `gate_k7a.sh` boots `-drive file=k7disk.img,if=ide` (no
            `-kernel`): `K7 real` + `K7 pmode` + exit 33. Proves the sovereign boot
            chain + the real→protected transition, self-contained (no boot.asm change).
      - [x] **K7b — load the kernel image from disk + hand off — DONE + gated
            (2026-07-15).** LogOS boots itself END-TO-END. Two-stage sovereign
            loader: the 512-byte MBR (`boot7b.asm`) inits COM1, announces `K7 real`,
            reads stage 2 off disk (BIOS `int 0x13` extended/LBA read) and jumps to
            it in real mode; stage 2 (`boot7b_s2.asm`) enables A20, builds a GDT,
            enters 32-bit protected mode (`K7 pmode`), and via **32-bit ATA-PIO**
            reads the kernel image's two PT_LOAD segments off the disk into their
            physical addresses (`.boot`→0x100000, zeroing its `.bss` tail;
            `.la_image`→0x400000), synthesizes a minimal multiboot info struct
            (mem_lower/upper) and points `EBX` at it — the exact multiboot-compatible
            32-bit state `boot.asm`'s `_start` expects — announces `K7 handoff`, and
            `jmp`s to `_start`. From there the existing kernel brings up long mode +
            the syscall substrate and the LA image speaks **`I AM THAT I AM`** +
            exit(33). All geometry (LBAs, sector counts, phys addrs, bss size) is
            DERIVED from the linked ELF's program headers by `build_k7b.sh`, so the
            loader can never drift from the on-disk image. `gate_k7b.sh` boots
            `-drive file=k7bdisk.img,if=ide -m 256` (no `-kernel`) and asserts the
            whole chain on serial + exit 33. K1→K7 COMPLETE — the sovereign kernel
            boots its own bytes off its own disk with nothing external in the loop.
- [x] 3. Init system (`logosinit.la`, PID-1) *(Linux-userspace prototype; the
      native process model is re-homed onto the kernel at K5/K6)*
- [~] 4. Hardware abstraction layer *(DRM/KMS path proven on hardware as a
      Linux-userspace VM program; the kernel's own HAL begins at K1's boot.asm —
      real bare-metal drivers, display, disk, PCI are the largest remaining chunk)*
      **The kernel's own HAL — drivers written in Lingua Adamica on thin asm
      "physics", the pmm.la/paging.la pattern (pure LA logic + peek/poke). Staged:**
      - [x] **HAL.1 — port-I/O primitives + PCI enumeration — DONE + gated
            (2026-07-15).** Added `inb`/`inl`/`outb`/`outl` native_codegen3 builtins
            (the port-space twin of peek/poke — the irreducible physics every driver
            needs), appended at rt.asm EOF via the safe peek/poke recipe (existing
            RT_* unchanged; RTLEN 11790→11882, LITERAL_BASE + the four new labels;
            self-host regenerated to a fixed point). `kernel/pci.la` is the first
            bare-metal DEVICE DRIVER written in the language itself: at ring 0 it
            walks PCI config space (mechanism #1, 0xCF8/0xCFC — `outl` the address,
            `inl` the register; `|` is `+` since the bit-fields are disjoint and LA
            has no bitwise ops) and prints every device on bus 0 as vendor:device in
            hex. `gate_hal1.sh` boots it (`-kernel -m 256`) and asserts the 440FX
            host bridge 8086:1237 + PIIX3 ISA 8086:7000 + scan-complete + exit 33.
            The discovery foundation every later driver builds on. `in`/`out` are
            privileged → metal-only (like peek/poke), tested in QEMU not host==native.
      - [x] **HAL.2 — PS/2 keyboard input — DONE + gated (2026-07-15).** The
            kernel's first INPUT sense, the reciprocal of serial output. `kernel/kbd.la`
            is a polling driver in pure LA on the HAL.1 `inb` primitive (NO new
            builtin, NO regen, NO boot.asm change): at ring 0 it reads the i8042
            (status 0x64 / data 0x60), and when the output-buffer bit is set (and not
            the AUX/mouse bit — both read arithmetically, `st mod 2` / `(st div 32) mod
            2`, since LA has no bitwise ops) reads a SET-1 scancode from 0x60, decodes
            press codes (< 0x80) to ASCII via a keymap string, skips releases, and
            echoes the collected line on ENTER (scancode 28). `gate_hal2.sh` injects
            `l o g o s ⏎` via the QEMU monitor (`sendkey`), serial to a file, and
            asserts `kbd:` + `logos` + `kbd done` + exit 33. *(Interrupt-driven input —
            an IRQ1 ISR ring buffer on the K5a PIC path — remains a possible HAL.2b;
            polling was the simpler, fully-autological first cut.)*
      - [x] **HAL.3 — ATA disk read in LA — DONE + gated (2026-07-15).** The kernel
            drives real persistent storage itself. `kernel/ata.la` (pure LA on the HAL.1
            port-I/O primitives — NO new builtin, NO regen): at ring 0 it issues READ
            SECTORS (cmd 0x20) on the primary IDE bus (`outb` the LBA/count/drive to
            0x1F2–0x1F6, 0x1F7), polls the status port for BSY-clear + DRQ-set (bits read
            arithmetically), and drains the 512-byte sector as 128 **32-bit `inl` reads**
            of the data port (the 16-bit register yields two words per dword; bytes
            recovered low-first via div/mod) — the same ATA-PIO sequence K7b's bootloader
            proved, now a driver in the language. `build_hal3.sh` seeds a data disk with a
            signature at LBA 1; `gate_hal3.sh` attaches it (`-drive if=ide`), boots
            `-kernel -m 256`, and asserts the driver echoed the on-disk signature back +
            exit 33. *(Sector WRITE — cmd 0x30 + `outl` the data + cache-flush — is a
            possible HAL.3b.)*
      - [x] **HAL.4 — linear-framebuffer display via a PCI BAR — DONE + gated
            (2026-07-15).** The kernel's first pixels on its own. Two new 16-bit port-I/O
            builtins `outw`/`inw` complete the port-I/O width set (byte/word/dword),
            appended at rt.asm EOF (RTLEN 11882→11934; self-host regenerated to a fixed
            point), and `boot.asm` (`%ifdef HAL4`) identity-maps 0..4 GiB so the high VGA
            LFB BAR is reachable by `poke` (others byte-identical). `kernel/fb.la` at ring
            0: scans PCI for the std VGA (reg0 0x11111234), reads BAR0 (the linear
            framebuffer base), sets 640×480×32 + LFB via the Bochs VBE dispi registers
            (index 0x1CE / data 0x1CF, via `outw`; pitch read back via `inw`), and pokes a
            64×64 red square into the framebuffer. `gate_hal4.sh` boots `-vga std -m 512`,
            waits for the "fb drawn" marker, captures the guest display with QEMU
            `screendump`, and asserts a 640×480 PPM with the top-left 64×64 region red
            (4096/4096). *(Bulk blit / full-screen fill wants a memcpy-to-MMIO primitive;
            byte-`poke` suffices for a rectangle. Compositor/Theourgia on the metal builds
            on this.)*
      - [x] **HAL.5a — NIC discovery (RealTek RTL8139) — DONE + gated
            (2026-07-15).** The kernel's first sight of a network card. Pure port
            I/O like ata.la — no new builtin, no `boot.asm` change. `kernel/nic.la`
            at ring 0 scans PCI (0xCF8/0xCFC) for the RTL8139 (vendor 0x10EC /
            device 0x8139), reads its BAR0 (I/O base, low 2 type bits masked), and
            reads the 6-byte station address off the ID registers IDR0..5 via `inb`.
            `gate_hal5.sh` boots `-device rtl8139` (with a SLIRP `user` netdev for
            5b's wire), asserts the serial shows `nic mac=52:54:00:12:34:56` (QEMU's
            default first-NIC MAC) + clean exit 33. RTL8139 chosen over the e1000
            default because its port-I/O registers + single RX ring suit a
            bitwise-op-free LA driver (e1000 needs high-MMIO + descriptor rings).
      - [x] **HAL.5b — NIC send + receive (RTL8139), the first DMA driver — DONE
            + gated (2026-07-16).** The kernel's first packet on the wire, both
            directions. `kernel/nic5b.la` at ring 0 enables PCI bus-mastering
            (config command reg 0x04 <- 0x07), powers on + software-resets the card,
            programs an 8 KiB RX ring at physical 0x10000000 (RBSTART) and a TX
            buffer at 0x10003000 — both in identity-mapped RAM above the LA stack
            (128 MiB), so the card's DMA lands where poke/peek reach — sets RCR
            (accept broadcast/physical/promiscuous) + CAPR and enables RX+TX (CR
            TE|RE). It pokes a 42-byte broadcast ARP request (who-has 10.0.2.2),
            points TSAD0 at the TX buffer, starts the DMA via TSD0 (len 60), waits
            for TOK, then polls the RX ring and reads the reply straight out of the
            DMA buffer with `peek`: ethertype 0x0806, ARP opcode 2, the SLIRP
            gateway's sender MAC 52:55:0a:00:02:02. `gate_hal5b.sh` boots `-m 512
            -device rtl8139` on a SLIRP `user` netdev and asserts `nic tx ok` +
            `nic rx et=0806 op=02 sha=52:55...` + clean exit 33. The ARP frame is a
            flat space-separated decimal string decoded by a small Z-recursive
            `PUTBYTES` — NOT a deep nested `concat` (which is pathologically slow to
            compile on tiny_host, the font flat-literal lesson: a 41-deep nest took
            >12 min and was killed; the flat form compiles in the normal ~5 min).
            (AegisNet's crypto/onion layer sits far above this bare TX/RX.)
      - [x] **HAL.3b — ATA disk WRITE, the write-twin of HAL.3 — DONE + gated
            (2026-07-16).** The kernel now PERSISTS to its own disk. Pure LA on the
            HAL.1 port-I/O primitives — no new builtin, no regen. `kernel/ata3b.la`
            at ring 0 issues WRITE SECTORS (cmd 0x30) for a 28-bit LBA (same
            LBA/count/drive setup as the read, only the command byte differs), waits
            BSY-clear + DRQ-set, pushes one 512-byte sector as 128 little-endian
            32-bit `outl` writes to the data register 0x1F0 (the write-mirror of the
            read's 128 `inl`s), issues CACHE FLUSH (cmd 0xE7) + waits BSY, then reads
            the sector back (the proven HAL.3 read path) and echoes it. The sector is
            a printable signature + NUL padding to 512 (`ZEROS` a small Z-loop).
            `gate_hal3b.sh` boots a BLANK `-drive if=ide` disk, asserts the serial
            round-trip (`ata write done` + the echoed signature + exit 33) AND —
            independent proof — that the signature is on the disk FILE at LBA 2
            (offset 1024) though it was seeded all-zero, so the bytes came from the
            driver's write. (Sector WRITE was the last obvious HAL.3 follow-up.)
      - [x] **HAL.2b — IRQ-driven keyboard (PIC + IRQ1), the interrupt-driven twin
            of HAL.2 — DONE + gated (2026-07-16).** The kernel's first real
            interrupt-driven device. `kernel/kbdirq.asm` (`%ifdef HAL2B`, zero bytes
            otherwise — the guard verified byte-identical) mirrors K5a's `timer.asm`:
            `kbd_setup` remaps the 8259 PIC (master 0x20-0x27), installs
            IDT[0x21]->`kbd_isr`, unmasks ONLY IRQ1; `boot.asm` calls it + `sti`.
            `kbd_isr` is minimal/transparent (rax/rdx saved) — on each key event's
            IRQ1 it reads the SET-1 scancode from 0x60 into a 256-byte ring at
            0x320008, bumps a 1-byte head at 0x320000, EOIs the PIC. `kernel/kbd2.la`
            never touches the i8042: it keeps its own tail and, whenever
            `peek(0x320000)` (head) != tail, reads `peek(0x320008+tail)`, decodes via
            HAL.2's proven SET-1 keymap (releases >=0x80 fall off the table -> ""),
            until ENTER (sc 28). `gate_hal2b.sh` injects `l o g o s <enter>` via the
            QEMU monitor and asserts the echoed `logos` + `kbd done` + exit 33. So a
            real hardware interrupt path (PIC + IRQ1 + IDT gate) drives input, the LA
            program woken by the keyboard rather than polling it.
      - [x] **HAL.4b — bulk framebuffer fill + memcpy-to-MMIO, the language's
            FIRST TERNARY builtins — DONE + gated (2026-07-16).** HAL.4 drew its
            square with a poke (and a beta-reduction) per byte — 12288 for 64x64,
            and a full 640x480 screen was never attempted. HAL.4b adds the two
            bulk primitives a compositor's inner loop runs on, appended at
            `native_codegen3_rt.asm` EOF so every existing `RT_*` address is
            unchanged (verified: only `RTLEN`/`LITERAL_BASE` shift): `rt_fill`
            (`rep stosd` — `count` dwords of `value`; a pixel IS one dword at
            32bpp) and `rt_memcpy` (`rep movsb` — the backbuffer->LFB blit).
            **Both are ternary, which the compiler could not emit at all**: this
            grew `native_codegen3` a third arity — `IS_BUILTIN3`/`RT_TER`/`CG_TER`
            plus a `CG_APP` arm recognising a ternary head one `APP` level deeper
            than a binop's (guarded by `NODE_TAG(g)="APP"` BEFORE `APP_F(g)`, the
            trap `INT_LIT_SAFE` documents). `CG_TER` extends `CG_BIN`'s shape by
            one operand — push a1, push a2, evaluate a3 into rax, then `pop rsi`
            (=a2) + `pop rdi` (=a1) — the pops AFTER a3's code, so a3 clobbering
            rdi/rsi cannot corrupt the earlier operands. Safe across a collection
            because the runtime GC is conservative mark-sweep (non-moving) and
            scans the native stack from `STACK_BASE`. `kernel/fb4b.la` fills all
            307200 pixels in ONE rep stosd, fills a 64x64 red backbuffer in plain
            RAM at 0x340000 (proving fill works off-MMIO), and blits it to
            (100,100) row-by-row (rows are contiguous in RAM but pitch-strided on
            screen). `gate_hal4b.sh` asserts each primitive SEPARATELY and twice
            over — the driver's own `peek` read-back on serial (`fb4b out=128,0`
            proves fill painted where nothing else wrote; `fb4b in=0,255` proves
            memcpy landed; either alone is passable by a broken primitive) AND an
            independent screendump (4096/4096 red at (100,100), blue at 6/6
            far-flung samples). The per-pixel poke loop is retired.
      - [x] **HAL.4c — THE COMPOSITOR ON THE METAL — DONE + gated
            (2026-07-16).** What HAL.4b's bulk primitives were built for, and the
            last HAL step. A compositor is not "draw pixels" (HAL.4 did that): it
            composes a whole frame OFF-SCREEN, z-ordered, then presents it
            ATOMICALLY — the panel never sees a half-drawn scene. `kernel/comp.la`
            at ring 0: a backbuffer at 0x10000000 (256 MiB of ordinary RAM, laid
            out at the SCREEN'S OWN pitch so presenting needs no re-striding —
            `-m 512`, like HAL.5b's DMA ring); ONE `fill()` clears the desktop
            (307200 px, one rep stosd); `RECT` lays each window with one `fill()`
            PER ROW (a row is contiguous, but consecutive rows are
            pitch-strided); z-order IS paint order (the painter's algorithm), so
            window B — laid last and overlapping A — occludes it; then `PRESENT`
            moves the entire 1,228,800-byte frame to the LFB in ONE `memcpy()`.
            **Deliberately NOT `import("theourgia.la")`:** Stage-1's surface core
            has the right SEMANTICS (a z-ordered stack of rects) but its surfaces
            are lists of row strings spliced per blit — this repo's own note
            records it is "O(n²) per row and cannot scale to a real panel", which
            is why even the Linux-side live renderers build their framebuffer
            directly; and every kernel driver is flat/import-free (the
            import-mangler makes codegen of an importer pathologically slow). So
            HAL.4c keeps theourgia's semantics and drops its representation: the
            backbuffer IS the framebuffer's layout, every surface a `fill()`.
            `gate_hal4c.sh`'s load-bearing assertion is the **OVERLAP pixel** —
            it must be B's green; **if z-order were inverted it would read red and
            every other assertion would still pass** — checked on both paths: the
            driver's own `peek` read-back (`comp ov=0,255,0`) and an independent
            screendump (desktop 4/4 blue, A-only 4/4 red, B-only 4/4 green,
            overlap 4/4 green). Item 6 (Display protocol & compositor) now has a
            real metal realisation; the interactive/input-driven session on bare
            metal (Theourgia Stages 5-9's live loop, minus Linux DRM/evdev) is
            what remains → **DONE in HAL.4d.**
      - [x] **HAL.4d — THE INTERACTIVE COMPOSITOR SESSION ON THE METAL — DONE +
            gated (2026-07-17).** What HAL.4c named as "what remains": Theourgia's
            INNER LOOP driven by real keyboard input, at ring 0 — read a key → move
            a window → **re-compose** the z-ordered frame off-screen → **re-present**
            it, forever, until ENTER. `kernel/comp_session.la` fuses two proven
            metal drivers, both flat + import-free: HAL.4c's compositor (`SCENE`
            z-ordered, `PRESENT` = one `memcpy` of the whole frame to the LFB) and
            HAL.2's **polling** PS/2 reader (`inb` on 0x60/0x64) — polling, so it
            reuses HAL.4c's straight-line `-D HAL4` boot with **no IRQ/PIC setup
            added**. WASD moves window B; each keystroke recomposes + presents a NEW
            frame. `gate_comp_session.sh` injects keystrokes through the QEMU
            monitor (`sendkey d ×3`, then `ret`) and reads the SERIAL witness: the
            initial probe pixel (200,150) is B's green (`session ov=0,255,0`); after
            3× right the window has moved (`session bx=300`); and the probe is now
            window A's **red showing through** (`session ov=0,0,255`) — the
            load-bearing assertion, since **a static frame, or a loop that moved a
            variable without re-presenting, would leave it green and FAIL**; then
            `session done` + **exit 33**. So a real recomposition + present is driven
            by real input, on bare metal, with no Linux DRM/evdev. *Honest scope /
            note:* `comp_session.la`'s `native_codegen3` compile is **~13 min** (the
            backend's codegen is superlinear in program size + nesting depth — the
            known compile-blowup on larger programs); the ELF is built out of band
            (`build_comp_session.sh`) and gitignored, and the gate boots it — the
            same pattern as the heavy kernel ELFs. Item 6 (Display protocol &
            compositor) now has an *interactive* metal realisation; a movable TEXT
            window (a terminal) is the next compositor step.
- [x] 5. Inter-process communication (`logosipc.la`, typed IPC)
- [~] 6. Display protocol & compositor *(`theourgia.la` — interactive window
      with text proven on hardware)*
- [~] 7. Audio system *(phonym path exists; full audio stack pending)*
- [~] 8. Input system *(evdev/keyboard path proven)*
- [ ] 9. Permission & security model
- [ ] 10. User interface framework
- [ ] 11. Session manager
- [ ] 12. Package & update system
- [ ] 13. System services
- [ ] LogosMentor — local reasoning engine
  - [x] Symbolic reasoning core (AATC, three laws, α=1 coherence) — in Lingua Adamica
    *(`aatc.la` (`aatc_spec.la`): the AATC criterion — the four conditions
    (self-inclusion, self-application, self-validation = X(X)≡X, closure) composed
    into one verdict + AUTOLOGICAL/HETEROLOGICAL + all five Ch.6 operators
    (α index, ∂ depth, 𝒯 transformation, ρ recognition coefficient, φ fractal
    coherence); AATC(AATC)≡TRUE.
    On top of it the full CENTROPIC LOOP — Sense→Diagnose→Prescribe→Learn: SENSE
    (proprioception — map a LogOS organ/module to a STRUCT) → DIAGNOSE heterology →
    PRESCRIBE 𝒯 (honest deepening) → REPAIR to autological closure → LEARN (a
    centropy ledger accumulating the closure restored, meta-telesis). The reasoning
    core runs the whole loop on its OWN body: a healthy organ is autological, a sick
    one is diagnosed and REPAIRed back to closure, and the loop tracks the centropy
    it restores. Builds on the three laws (`metalogic.la`) and α=1 (`canon.la`); all
    host==VM byte-identical. SENSE also reads REAL module state from disk: SENSE_FILE
    (= SENSE_SRC ∘ read_file, with STARTS_WITH/CONTAINS substring search) derives an
    organ's structural facts from its actual source (defines its namesake glyph /
    non-empty / imports), and AUDIT_FILE("kernel.la")("MAIN") audits the real
    kernel.la as autological (host==VM). Remaining LogosMentor work under this parent:
    a live daemon running each module's META_DEBUG to feed full pass/fail verdicts
    (SENSE_FILE reads structure, not spec-verification) + a richer learned model; and
    the statistical seam.)*
  - [ ] Statistical model interface — local model, interfaced not rewritten *(honest substrate seam)*

---

## Phase III — Rubedo: Sovereignty (the far horizon)

*Full autological and privacy closure. Status: distant — these depend on
hardware-level work and a mature network. Honestly years out.*

- [~] Sovereign kernel (LogosKernel) — **BEGUN 2026-07-04** (branch `kernel-k1`):
      bare-metal bring-up K1–K7 (see Phase II · Kernel). No longer inherits Linux;
      K1/K2/K3a green. Pulled forward from the far horizon — the sovereign kernel
      is now under active construction, not deferred.
- [ ] Network sovereignty / AegisNet — torrent-native, self-distributing,
      layered-encryption mix network
- [ ] Encryption & meta-encryption layers (nested/onion routing, metadata privacy)
- [ ] ARM / RISC-V ports — thin HAL seam, universal autological core
- [!] **Open silicon** — the hardware seam. Full autological and privacy
      closure requires open firmware (coreboot/libreboot), ME/PSP neutralization
      or ME-free architectures (e.g. POWER9, RISC-V), and ultimately
      open-fabricated chips. Strong privacy is achievable *now* on carefully
      chosen libre hardware; the residual is the physical-silicon supply chain,
      which shrinks as open hardware matures.

*Censorship-resistance & propagation ideas for this phase — transport
undetectability (highest value), threshold/social key recovery, deniable storage,
friction-minimized node-joining, incentive-aligned seeding, onboarding bridges,
and the minimal regenerable seed — are captured (not yet designed) in
[`FUTURE_WORK.md`](FUTURE_WORK.md).*

---

## Autopoietic Closure — the map (added 2026-07-16)

*The governing definition: **"truly autopoietic" = operational closure at every
level ABOVE the hardware substrate.** Stopping there is not a failure — cells run
on chemistry they did not author. The Bootstrap Theorem already frames it
correctly: close the loop* above *the womb, and shrink the womb over time.*

**Already closed:** self-compiling ✓ · self-hosting ✓ · self-verifying
(build-time) ✓ · self-booting ✓ (K7, `5076806` — LogOS boots itself off a raw
disk; GRUB/multiboot gone, the last foreign-toolchain seam at boot closed).

### The core three (the remaining first-list items)

- [x] **Self-modification — DONE + gated (2026-07-16), `selfmod.la`.** The step
      beyond self-compilation: not merely compiling itself, but **changing**
      itself. The distinction from B3 is exact and is the point — *self-repair
      ends BYTE-IDENTICAL to what it was (restoration); self-modification ends
      DIFFERENT and still verified (becoming).* Again the principle was already
      written: `canon.la`'s neologization (*"two monoglyphs COLLAPSE into ONE new
      monoglyph whose etymology deepens"*) and `SR_FROM = ↻(VOID)` (*"Logos FROM
      itself: generation/neologization"*) — applied to its own **source**.
      `NEOLOGIZE` therefore conjures nothing: it composes two glyphs the organ
      **already has**, and the generated source **names its parents** —
      `glyph TRIPLEDEC = la x. TRIPLEN(DEC(x))` — so the etymology is IN the
      artifact, exactly as `canon.la` requires of a monoglyph (a glyph whose name
      floats free of its derivation is unconstructible). The system becomes MORE
      than it was, **made only of what it already had**. `ADOPT` re-derives the
      WHOLE organ, type-checks, and runs EVERY glyph's tests before writing, then
      **re-senses** and reports what actually happened. Gated on six properties:
      adoption; **it genuinely changed** (`changed=T` — else it would be
      self-repair); autological under its NEW derivation; the etymology is in the
      artifact; **no regression** (the parents survive); and two refusals — an
      extension failing its own test, and the stronger one, **an extension that
      BREAKS AN EXISTING capability** — both REFUSED with the organ left exactly
      as it was. A self-modification cannot regress the self it is modifying.
      **Bounded, deliberately** (Tier 3): the organ changes; specpipe, the
      compiler and this module do not change themselves in the same act. *Honest
      scope:* this closes the **mechanism** of self-change — how a system may
      alter its own verified code and adopt it soundly. **Which** extension to
      make is chosen here; deciding that autonomously is self-programming's
      problem (below), and naming that seam rather than blurring it.
- [x] **Bounded self-repair (B3) — DONE + gated (2026-07-16), `selfrepair.la`.**
      The project's own **Debugging Principle mechanized**: *"a bug is a
      heterological element — code that does not satisfy its own specification;
      debugging is the restoration of autological closure."* The criterion is not
      a checksum bolted on from outside — it is `canon.la`'s `AUTO_OK`
      (`REN ≡ CANON(ETYM)`: a thing IS its own etymology) applied to an
      **artifact**: `INTACT(path)(spec) ≡ read_file(path) == GENERATE(spec)` —
      a module's BYTES must be what its spec generates. A corrupted module is
      then literally a heterological element (its bytes have floated free of
      their derivation), and `HEAL` is the restoration of closure: `DEPLOY`
      re-derives, type-checks, runs every glyph's own tests, and writes ONLY if
      all pass. Gated on four properties: (1) **detection** — the corruption is a
      WRONG CONSTANT (3→4) that still parses and still defines its namesake, so
      `aatc.la`'s structural `SENSE_FILE` would call it healthy; only the
      byte-exact criterion catches it; (2) **repair** — regenerated from the
      verified source; (3) **the proof** — the healed organ is BYTE-IDENTICAL to
      its pre-corruption self; (4) **honest refusal** — given a spec that fails
      its own tests, `HEAL` re-senses after repairing and reports `REFUSED`
      rather than announcing success because it ran, and the corrupted file is
      left EXACTLY as it was (a failed repair never overwrites the disk with
      unverified code). Host-gated in `build.sh` like `autoloop.la` (a
      specpipe-importer costs ~160s to codegen; host==VM is a manual
      confirmation). **Bounded, deliberately** (Tier 3): the spec + specpipe +
      the compiler are the **trusted base** — something must remain
      un-self-modified to do the repairing. *Honest scope:* repairable ==
      spec-generated. An organ whose etymology is a spec can be regenerated from
      it; a hand-written module has no etymology to regenerate FROM. That is the
      real boundary of B3 — the system can restore any component whose
      derivation it still holds.
- [x] **Self-programming via the language — DONE + gated (2026-07-16),
      `selfprog.la`.** The meta-programmable / democratized-coding goal: **you say
      WHAT you want; the system writes the HOW.** The seam it closes is one
      `autoloop.la` states about itself — its GOAL hands each step
      `ENT(name)(sig)(SRC)(IMPL)(tests)`, *the implementation included*, so
      autoloop verifies and assembles but **never writes anything**:
      - `autoloop.la` : name + type + **source + impl** + tests → verify+assemble
      - `selfprog.la` : name + type + **acceptance test** → **WRITE THE PROGRAM**

      Only WHAT is wanted is supplied, never HOW. The system **searches its own
      capability space** — every composition of the glyphs it already has —
      which is the project's own **Γ/Ρ split**: `CANDIDATES` is pure GENERATION
      (propose a program), `TESTOK` is pure RECOGNITION (does it satisfy the
      want?). Told only *"a glyph `TWELVE` with `TWELVE(5) = 12`"*, it wrote
      `glyph TWELVE = la x. TRIPLEN(DEC(x))` out of its own `TRIPLEN`/`DEC`, and
      adopted it verified (the neologism carries its etymology into the artifact,
      per `selfmod.la`). **The verification is honest** because the acceptance
      test is INDEPENDENT of the implementation chosen — it came with the
      requirement, not from the candidate; a system deriving its own test from
      its own impl would pass trivially, and `aatc.la` already names that move
      (gaming the criterion is itself heterological). **Refusal is a real
      outcome**: told it wanted `HUNDRED(5) = 100` — unreachable by ANY pair it
      can form (as `{x*3, x−1, x+1}` it reaches only 45,12,18,14,3,5,16,5,7) — it
      REFUSED and wrote nothing rather than fabricate or approximate.
      **The bound is the corpus's own, not an engineering shortfall:** `canon.la`
      carries `SR_FOR = ↻(LOVE)` — *"teleology — the ACHIEVABLE form of purpose,
      a BOUNDED GOAL-DIRECTED LOOP; NOT purpose-origination"*. The system does
      not originate the want, by design. *Honest scope:* the search space is
      pairwise composition of its own glyphs; deciding **which** want to pursue
      autonomously is the open frontier (Tier 3 below), which the corpus names as
      the wrong target rather than a gap.

### Tier 1 — genuine closure (each closes a real seam)

- [ ] **Self-hosting build system.** `build.sh` is **bash** — a live seam: an
      external tool orchestrates the compilation of a self-hosting system. The
      build pipeline written in LA, driving its own compilation, closes it.
- [ ] **Runtime self-verification.** AATC verifies at **build time only**;
      nothing watches the *running* system. The criterion applied continuously to
      the live system — the system watching itself while alive — is a strictly
      deeper closure than the compile-time audit. (Open, not partial.)
- [ ] **Self-documentation / self-description** — the system generating an
      accurate account of its own structure *from* its own structure
      (philology-as-anamnesis: lineage readable from form). Connects directly to
      the etymology/`canon.la`/`glyphdag.la` work, where a form already contains
      its own derivation.
- [ ] **Self-hosting toolchain beyond the compiler** — debugger, linker,
      assembler. Each external tool is a seam. The boot-assembly linker/assembler
      is the hard edge: some of it is irreducibly machine-level.
- [ ] **Self-updating** — the system producing *and installing* a new version of
      itself from within, with no external update mechanism. Self-modification's
      shipping counterpart: not just changing its code in memory, but persisting
      a new self. Pairs with self-modification above.

### Tier 2 — autopoietic resilience (the system maintaining its own continuity)

- [~] **Self-monitoring / homeostasis** — observing its own health (resource use,
      errors, drift) and adjusting. **Begun** in LogosMentor's Sense/Learn
      (`aatc.la`'s Centropic loop + centropy ledger); extending it to the whole
      OS makes the system self-regulating.
- [ ] **Self-distribution / self-replication onto new hardware** — copying itself
      to new hardware and coming back up (the encrypted-P2P/torrent recovery,
      ledger **B5**). Autopoiesis at the *survival* level. Needs networking →
      late-stage; see AegisNet above.
- [ ] **Self-bootstrapping from a minimal seed** — a small core reconstituting
      its full self by streaming the rest (the honest version of the
      minimal-regenerable-seed idea). Late-stage.

### Tier 2b — OS-level autopoiesis (added 2026-07-17; GATED on the OS layers existing first)

The language/build autopoiesis is closed to its honest boundary (Tier 1 first-list
items done; `buildla` at 91/103 with only the irreducible seed + foreign tools left).
The **next round of autopoiesis is at the OS level** — the system maintaining not its
source but its *running self*: drivers, memory, processes, verification while alive.
Each of these is **gated on the OS layer it acts on existing first** (compositor +
core drivers → then the process/memory/service layers → then these). Recorded now so
the target is fixed; built when the substrate is there. This is *why* we build the OS
outward — it is both the usable system and the substrate the next autopoiesis needs.

- [ ] **Self-repairing drivers** — a driver that detects its own device fault
      (a wedged NIC ring, a stuck ATA channel, a lost framebuffer) and
      re-initialises itself from its own spec, the AATC repair loop applied to a
      *device* organ rather than a source organ. *Gated on:* the core drivers
      (disk · input · NIC send/recv) running on the metal.
- [ ] **Self-managing memory — the "cull unless active" principle** — the system
      reclaiming what is not in active use without an external allocator policy:
      the frame/heap manager treats every region as *cullable by default* and
      *retained only while demonstrably live* (the memory analogue of the GC's
      reachability, lifted to the whole OS's working set). *Gated on:* the kernel
      PMM/paging (K3/K4, done) grown into a live process-aware memory manager.
- [ ] **Self-healing processes** — a supervised process that crashes is diagnosed
      and respawned from its own descriptor (logosinit's respawn discipline +
      AATC's Sense→Diagnose→Prescribe on a *live* task, not a source module).
      *Gated on:* the ring-3 process/scheduler layer (K5/K6, done) grown into a
      real process/session manager.
- [ ] **Runtime self-verification — AATC while ALIVE, not just at build** — the
      autological criterion run against the *running* system continuously, so an
      organ that drifts from its spec at runtime is caught the moment it does, not
      only when `build.sh`/`buildla` re-checks at build time. *Gated on:* a
      live self-monitoring daemon (Tier-2 homeostasis) with the OS services to host it.
- [ ] **Self-updating** — the running OS producing *and installing* a new version
      of itself from within, with no external update mechanism, then rebooting
      into it (K7's sovereign boot is the install target). *Gated on:* the
      package/update layer (Citrinitas item 12) + self-distribution transport.
- [ ] **Self-distribution / self-replication onto new hardware** — (same as Tier 2's
      survival-level item; restated here as an OS capability) copying the running
      system to new hardware and coming back up. *Gated on:* networking (NIC
      send/recv done → the AegisNet transport) + self-updating.

*(The `[!]` walls below still bound all of these: hardware/firmware is the
irreducible floor, the trusted base stays trusted, goal-origination and the
learned-model seam and Gödel-total-self-verification are not closed by any of the
above. These are OS-level *resilience*, not the removal of those limits.)*

### The full seam map (added 2026-07-16)

*The autopoietic move is always the same: every place the system depends on
something outside itself is a seam — **bring the dependency inside, or name why
you cannot**. Grouped by seam, exhaustively.*

**Toolchain seams — bring every tool into LA.** *(The boot ASSEMBLY is
irreducibly machine-level; the TOOL that assembles it need not be foreign.)*

- [x] **LA assembler (`asm.la`) — assembles the kernel `boot.asm` == nasm, gated (2026-07-23).** The first
      LA-native toolchain component. The boot ASSEMBLY is irreducibly
      machine-level — but the TOOL that assembles it need not be foreign, and
      that is the seam. **Verified by byte-identity against the tool it
      replaces:** assemble the same source with `asm.la` and `nasm -f bin`, and
      diff — no room to be approximately right (the drift-guard discipline
      `secd.la` already uses). 61 bytes of a 20-instruction program matched
      exactly. **Byte-identity demands matching NASM's encoding CHOICES**, not
      merely emitting something the CPU accepts — the sharp case is
      `mov rax, 1` → `b8 01 00 00 00`, i.e. `mov eax, 1`: a 32-bit write
      ZERO-EXTENDS, so NASM drops REX.W and the 10-byte `movabs` entirely. An
      assembler emitting the "obvious" movabs would be **correct and still fail
      the diff**; the gate asserts byte 0 is `0xB8` explicitly. An instruction
      outside the subset **halts loudly** rather than emitting silent garbage.
      **LABELS + NEAR CONTROL FLOW added, also byte-identical (41-byte program).**
      Two passes: PASS1 records each label's address, PASS2 emits with `rel32`
      measured from the NEXT instruction. The hard case is the **backward jump** —
      `rel32` goes negative and must be two's complement (`jz start` @22 →
      `0f 84 e4 ff ff ff` = −28); LA's div/mod on a negative is unreliable, so it
      is folded into the unsigned 32-bit range **before** being split into bytes.
      Asserted explicitly. One clean pass suffices *because* only NEAR forms are
      emitted, so every size is fixed by mnemonic+registers, never by target
      distance — which removes the chicken-and-egg that forces real assemblers
      into multi-pass optimisation. An **undefined label halts loudly** rather
      than silently resolving to 0. *(Building this surfaced the eager-evaluation
      trap CLAUDE.md documents for Church booleans: a Scott list `l(nil)(cons)`
      evaluates the NIL branch EAGERLY, so an `error(...)` written there fired on
      every lookup, not just a miss — the failure is now raised through `IF`,
      whose branches are thunks.)*
      *Honest scope — why this is `[~]` and not `[x]`:* the covered subset is real
      and every instruction of it is byte-verified — `mov`/`add`/`sub`/`xor`
      (r64,r64), `mov` (r64,imm32), `push`/`pop` (r64), `syscall`/`ret`/`nop`,
      `r8`–`r15` via REX, labels and NEAR `jmp`/`call`/`jz`/`je`/`jnz`/`jne`
      (`elf.la`'s whole write+exit entry is inside it, as is any straight-line +
      branching routine over registers).
      **MEMORY OPERANDS added, also byte-identical (49-byte program over 12
      forms)** — `mov` in both directions over `[base]`/`[base±disp]`. The three
      quirks are HARDWARE facts, not NASM preferences (an encoder missing any
      would produce something the CPU *misreads*, not merely something NASM
      writes differently), and each is asserted **individually** so a regression
      names itself instead of surfacing as an anonymous byte diff: **rbp/r13**
      (`rm==5`) — `mod=00 rm=101` means RIP-relative, so `[rbp]` is FORCED to
      `mod=01`+`disp8=0` (`48 8b 45 00`); **rsp/r12** (`rm==4`) — `rm=100` means
      "a SIB byte follows", so `[rsp]` needs `SIB=0x24` (`48 8b 04 24`); **disp**
      — 0 → `mod=00`, fits a signed byte → `mod=01`+disp8 in two's complement
      (`[rbp-8]` → `f8`), else `mod=10`+disp32. Both quirks survive REX.B, which
      is where a naive encoder breaks (`[r12]` → `4d 89 2c 24`; `[r13]` →
      `49 8b 45 00`).
      What it is **not**: memory operands are **base+displacement only** — no
      index/scale (`[rax+rcx*4]`), no RIP-relative, and only for `mov`
      (`add`/`sub`/`xor` stay register-to-register); **short/near jump selection via a
      FIXED POINT** — the last encoding-CHOICE mismatch, now closed, which is
      what lets a bare `jmp L` (idiomatic asm) be byte-identical rather than
      requiring `near`. NASM emits the shortest jump that reaches (`eb`/`74`
      rel8, 2 bytes) and promotes to near (`e9`/`0f 84`) only when it must;
      `call` has **no** short form. A jump's size depends on its target's
      distance, which depends on the sizes between — so `asm.la` starts
      OPTIMISTIC (all short), recomputes, promotes what no longer reaches, and
      iterates. Promotion only GROWS the image, so length is monotonic and
      bounded: **length unchanged ⟺ no promotion ⟺ the fixed point** — the same
      shape as `regen_selfhost.sh` iterating the compiler image to ITS fixed
      point, one level down. Both halves gated by name: in-range targets
      shortened (`eb fd`/`74 fb`/`75 f9`, `call` stays `e8`), and a target 200
      bytes away PROMOTED (`e9`/`0f 84`, 211 bytes byte-identical).
      *(superseded note: a bare `jmp L` was emitted NEAR
      `e9` regardless — that is now fixed)*; **jcc covers `jz`/`je`/`jnz`/`jne`
      only**, not the signed/unsigned comparison set (`jl`/`jg`/`jb`/`ja`…),
      which is the same encoding plus a condition nibble and is mechanical to
      extend; no sections, no data definitions, no
      paging/GDT/IDT/segment forms. So it **cannot yet assemble
      `boot.asm` or `secd.asm`** and NASM remains in the kernel build. Closed for
      what is here, honestly open beyond it; the byte-identity gate extends to
      each increment.
      **OPERAND WIDTHS + hex literals + size keywords + immediate-to-memory
      added, byte-identical over 27 instructions / 86 bytes (2026-07-18).**
      Scoped by MEASURING the target rather than guessing: across the seven
      kernel `.asm` the sub-64-bit registers outnumber the 64-bit ones (713 uses
      to 451), hex literals run 271 against 642 decimal, and the four size
      keywords appear 181 times — so a 64-bit/decimal-only assembler reads
      almost none of the OS it is meant to build. Width is not decoration: it
      selects the opcode (**the 8-bit form is the 32-bit one MINUS ONE** —
      `mov` 89→88, `add` 01→00), the `0x66` prefix, and **whether a REX byte may
      exist at all**. The old encoder hard-coded `0x48` because every operand
      was 64-bit; REX is now emitted only when it carries information, since an
      unnecessary one is **not a no-op**. Four hardware facts are each asserted
      BY NAME so a regression identifies itself: `mov dil, 5` → `40 b7 05`, a
      **bare REX 0x40 carrying no bits**, emitted purely to reach `dil`;
      `mov ah, 0x11` → `b4 11`, where a REX is **forbidden** (`ah/ch/dh/bh` and
      `spl/bpl/sil/dil` share register numbers 4-7 and are told apart ONLY by
      whether a REX is present, so emitting one silently assembles a DIFFERENT
      register than was written — a mixed pair is now a loud halt, since it is
      unrepresentable rather than re-encodable); `mov r9w, ax` → `66 41 89 c1`,
      fixing `0x66` **before** REX; and `mov qword [rdi], 0` → `48 c7 07` + an
      imm32 the CPU **sign-extends**, never imm64. Two tokenizer gaps closed
      alongside: `;` comments (every kernel `.asm` is full of them; the earlier
      tests avoided them entirely) and bracket-aware operands, so the
      idiomatic `[rdi + 8]` no longer shreds on its spaces. **Sizing is now
      MEASURED from the encoder** (`SIZEL ≡ len(ENC1)` by construction) rather
      than computed in parallel with it — the width slice made lengths intricate
      enough (optional prefix, optional REX, optional SIB, 0/1/4-byte disp,
      1/2/4-byte imm) that a second implementation is exactly how a size/emit
      drift bug enters, and the fixed point then converges silently on a wrong
      image. **Red path verified**: four guards (unknown register, `ah`+REX,
      unspecified operation size, unterminated `[`) each exit 1 naming the
      cause, with a legal-program control proving they discriminate rather than
      reject everything; and the GATE itself was proven to go red by breaking
      the encoder deliberately — it named all three affected quirks. *(Two bugs
      were caught only by running that red path: a `grep` whose pattern `[`
      silently opened a regex character class, and a hollow test harness whose
      truncated `if` block made a syntax error read as "all green". A test that
      has never failed is not known to discriminate.)*
      **GROUP-1 ALU WITH IMMEDIATES + shifts + inc/dec + test/lea + the
      no-operand set added, byte-identical over 42 instructions / 163 bytes
      (2026-07-18).** Again scoped by profiling rather than guessing, and the
      profile overturned the obvious plan: the gap was not *which mnemonics*
      were missing but *which operand shape* — **reg+immediate dominates**
      (`or` 31 of 45 uses, `shr` 32 of 32, `cmp` 11 of 23, `and` 5 of 5,
      `test` 8 of 18) and `asm.la` could not encode it at all, its ALU being
      register-to-register only. The six group-1 ops differ only by a 3-bit
      digit (`reg,reg` = `digit*8+1`, `AL,imm` = `digit*8+4`, `eAX,imm` =
      `digit*8+5`), so one encoder serves all six rather than six encoders.
      **NASM picks the SHORTEST form and the priority is not the obvious one**,
      each rule gated by name: the sign-extended `imm8` form (`83 /digit`)
      beats the accumulator form even for `rax` — `add rax, 8` is
      `48 83 c0 08`, not `48 05 08000000` — while at width 1 the order
      **inverts**, `sub al, 9` being `2c 09` rather than `80 e8 09`, since
      there is no 8-bit sign-extension to save anything; `or ecx, 0x80` needs
      the full `imm32` because `0x80` does *not* fit a **signed** byte;
      `shl rax, 1` is the distinct by-one opcode `48 d1 e0`, not `c1` with an
      immediate of 1; and **`test` has no `imm8` form at all**, so `test rdx, 8`
      is a full `48 f7 c2 08000000` for a value that fits a byte — reusing
      group-1's shortcut there would emit something the CPU accepts and NASM
      never writes. **`boot.asm` is now 75% readable (799 of 1060 lines)**, and
      what remains is mostly the *preprocessor/directive* layer — `%ifdef` /
      `%define` / `%include` (106 lines) and `resb`/`dq`/`dd`/`align`/`section`
      (53) — rather than instructions. *(Running the gate's red path caught a
      defect in the new code, not the gate: `shl rax, rcx` — the unimplemented
      CL-count form — did halt, but with the host's `str_to_int: not a decimal
      integer` instead of an assembler diagnostic. Both shift and test now name
      the unsupported form.)*

      **DATA DEFINITION + LAYOUT added — `dw`/`dd`/`dq`, `resb`/`resq`,
      `align` — byte-identical over a 102-byte image (2026-07-18); boot.asm is
      now 80% readable (848 of 1060 lines).** Two of the `-f bin` semantics are
      NOT what they look like, and both were pinned by assembling with NASM and
      **reading the bytes back** rather than by reasoning: **`align` pads with
      `0x90` NOP, not zeros** (NASM pads a *code* section with no-ops, so
      `align 8` at 0x39 emits seven `0x90`s — zero-padding is the obvious guess
      and silently produces a different image), and **`resb`/`resq` EMIT zeros**
      rather than merely advancing the counter (NASM warns "uninitialized space
      declared in .text section: zeroing"; only a reservation at the very end is
      truncated). A label used as a data value is **org-absolute** — `dq start`
      is `0x400000` — the same rule the `movabs` form already followed.
      **★ It also closed a latent bug older than this slice: a line carrying a
      LABEL AND AN INSTRUCTION** (`w1: dw 0x1234`, how boot.asm writes nearly
      all its data) was treated as a label and *nothing else*, silently
      discarding the rest of the line — the label landed at the right address
      while its data was never emitted, so the image came out short with
      everything after it misplaced. It survived undetected because every
      earlier test program put labels on their own lines; only real kernel
      source exercises the combined form. Stripping the label and re-dispatching
      on what remains makes both forms one path, with a bare label line falling
      through to size 0 exactly as before (gated by a negative control). A
      second latent gap surfaced with it: `db` still parsed its values with
      `str_to_int`, so it could not read the hex literals the rest of the
      assembler had accepted since the width slice.

      **THE OPCODE TAIL added — port I/O, MSRs, descriptor/system ops, string
      ops with the `rep` prefix, the `o64` prefix, `div`/`imul`, rotates, and
      the FULL jcc condition set — byte-identical over 47 instructions / 109
      bytes (2026-07-18). boot.asm is now 85% readable (904 of 1060 lines), and
      everything still missing is the PREPROCESSOR plus `equ`.** `out` alone was
      37 uses, the largest remaining family, and port I/O turns out to have **no
      ModRM at all** — its operands are *implied* (always DX and the
      accumulator), so the width comes from which accumulator was named
      (`out dx, ax` = `66 EF`) and the imm8-port forms are a **different opcode**
      (`E6`/`E7`) rather than an addressing mode. Other facts gated by name:
      `ltr ax` is `0F 00 D8` with **no** `0x66` despite a 16-bit operand (the
      instruction takes r/m16 by definition, so the size needs no announcing);
      three-operand `imul` uses `6B` with an imm8 and `69` with an imm32;
      **`rep stosq` is `F3 48 AB` — the `F3` prefix precedes REX.W**; and `o64`
      is likewise just a REX.W byte prepended to what follows, which is why both
      prefixes are implemented as "emit a byte, then encode the rest of the
      line" rather than as instructions. **The jcc set became table-driven**: the
      old code hardcoded `jz`/`je`/`jnz`/`jne` as four cases, but every
      conditional jump is one opcode family plus a 4-bit condition (short
      `0x70+cc`, near `0F 80+cc`), and the ALIASES name one condition rather
      than several — `jc` ≡ `jb`, `jnc` ≡ `jae`, `jz` ≡ `je` — so they must
      encode identically, which is asserted directly. *(That alias check earns
      its place: a wrong condition code still assembles into a perfectly valid
      program that simply branches on the WRONG FLAG. Byte-identity is the only
      thing that catches it — no test of behaviour would, short of running the
      kernel.)*

      **`equ` SYMBOLIC CONSTANTS added, byte-identical over an 81-byte image
      (2026-07-18); boot.asm is now 88% readable (932 of 1060 lines) and the
      ONLY thing left is the preprocessor** (`%ifdef`/`%define`/`%include`, 121
      lines) plus 7 lines of `section`/`global`/`incbin`. **★ The slice exists
      for a DISTINCTION, not a directive: an equ symbol is a NUMBER, a label is
      an ADDRESS, the syntax at the use site is identical, and NASM encodes them
      differently** — `mov rax, SLOTSZ` is `b8` + imm32 (5 bytes) where
      `mov rax, start` is a 10-byte `movabs`. An assembler that treated equ
      symbols as labels would emit a clean-looking image with every constant
      five bytes too long and every address after it wrong. *(This also
      corrects an earlier note in this entry claiming boot.asm used `%define`
      rather than `equ`; it uses both. The profiling missed the ~25 `equ` lines
      because the first token on such a line is the SYMBOL, not the directive —
      a reminder that a measurement is only as good as what it counts.)*
      Implemented as **token substitution** between tokenizing and the passes:
      an equ value is a constant, so replacing the symbol with its literal text
      makes every downstream path — immediates, displacements, data definitions,
      `org` — work unchanged, with no table threaded through them and no risk of
      one operand position forgetting to consult it. *Honest scope:* whole-token
      matching only, so a symbol inside a bracket token (`[rdi+COM1]`) is not
      substituted — that needs expression parsing, which is the same machinery
      `idt + 0x21 * 16` requires and belongs with it.

      **THE PREPROCESSOR added — `%define` / `%ifdef` / `%ifndef` / `%else` /
      `%elifdef` / `%endif` / `%include` — byte-identical over a 58-byte image
      (2026-07-18). boot.asm is now 99.3% readable (1053 of 1060 lines); only
      `section` (5), `global` (1) and `incbin` (1) remain.** This is a DIFFERENT
      SUBSYSTEM from every slice above it: a text layer running BEFORE the
      tokenizer, deciding which lines the assembler ever sees. It matters
      because the `%ifdef` guards are how every kernel variant (K2, K5a, HAL2B,
      RING3, HH1_HIGHMAP) is selected out of ONE source file — without it
      `boot.asm` cannot be assembled at all, whatever the opcode coverage.
      Scoped by measuring first, and the measurement kept it small: **no
      function-like `%define`** (zero take arguments), most are valueless FLAGS
      existing only to be tested, conditionals nest to depth 4 and balance, and
      there are 4 `%include`s — so macro EXPANSION is not needed, only
      definition, conditional selection and file splicing. `%include` **splices**
      into the line stream and continues rather than recursing into a separate
      pass, which falls out of the design and is also what NASM does: the
      included file INHERITS the enclosing conditional state (`kbdirq.asm` sits
      entirely inside the parent's `%ifdef HAL2B`) and a `%define` it makes stays
      visible AFTER the include ends — both verified. **★ The gate's strongest
      assertions are NEGATIVE ones** — that `%else` bodies, untaken `%ifdef`
      bodies and untaken `%elifdef` branches DO NOT appear — because a
      conditional that fails to *suppress* still assembles and still runs; it
      merely carries code from a variant that was never selected, which is
      exactly how a kernel built for one configuration ends up containing
      another's instructions.

      **`section` / `global` / `incbin` added — boot.asm's SYNTAX is now 100%
      covered (1060 of 1060 lines parse and encode), 13 byte-identity gates
      (2026-07-18).** `incbin` splices a binary file verbatim (boot.asm embeds
      the LA image `native_codegen3_out` into `.la_image`, which is what makes
      the kernel and the host binary literally the same bytes); `global` emits
      nothing, since a flat image has no symbol table to export into, and only
      becomes meaningful with an object writer; `section` emits its default
      start padding — a section begins on a 4-byte boundary, zero-filled
      (measured: a `.text` of 1/5/9/17 bytes puts the next section at
      4/8/12/20). **Two measurements corrected claims written earlier in this
      very entry:** `align` pads with `0x90` NOP in `.rodata` and `.data` too,
      NOT only `.text` — the zero-fill between sections is section-START
      padding, a different mechanism, and the earlier "data sections pad with
      zeros" line was reasoning rather than measurement. And NASM raises a
      section's start alignment to the LARGEST `align` inside it, which is NOT
      implemented — named here rather than left as a silent divergence, since it
      affects multi-section `-f bin` only, never the `-f elf64` path boot.asm
      takes. *(Also settled: `-D` command-line defines and `-i` include paths
      need NO asm.la feature — `-D X` is exactly prepending `%define X`, and
      `-i` is running from that directory. Proven by the boot.asm end-to-end
      test doing precisely this. Do not build features the invocation already
      provides.)*

      **OBJECT-WRITER SCOPE, measured (2026-07-18).** Rather than wait on the
      `link` track to specify the format, the requirement was measured from
      `boot.asm`'s own `nasm -f elf64` output — the target defines the spec.
      It needs only **three relocation types**: `R_X86_64_64` (41),
      `R_X86_64_32` (21), `R_X86_64_32S` (1). **No `R_X86_64_PC32` at all** —
      intra-section jumps and calls are resolved by the assembler itself and
      cross-section references are absolute, which removes an entire class of
      work. **107 symbols** (101 `NOTYPE LOCAL` labels, 5 `SECTION`, one
      `GLOBAL` `_start`, one `FILE`) and **11 section headers** (`.multiboot`,
      `.boot32`, `.rodata`, `.la_image` PROGBITS; `.bss` NOBITS; `.shstrtab`,
      `.symtab`, `.strtab`; `.rela.boot32`, `.rela.rodata`). That is a bounded
      job comparable to the preprocessor slice — not the open-ended one the
      phrase "ELF object writer" suggests.

      **★ HONEST SCOPE CORRECTION (2026-07-18), recorded because the coverage
      number invites a wrong conclusion.** `boot.asm` is 99.3% *readable* — every
      one of those lines parses and encodes — but it is built with
      **`nasm -f elf64 -D HAL4 -i kernel/`** and linked with
      **`ld -n -T kernel/kernel.ld`**, while `asm.la` emits a FLAT `-f bin`
      image. Line coverage measures SYNTAX, not output format, so 99.3% does
      **not** mean NASM can leave the kernel build. What that actually requires,
      none of it yet built:
      **(a) an ELF64 RELOCATABLE-OBJECT writer** — section headers, a symbol
      table (`global _start`), and `.rela` relocations for every cross-section
      and absolute reference. This is the real remaining work and is comparable
      in size to the preprocessor slice. **It is also the convergence point with
      the `link` track**, which READS ELF64 objects — the two halves meet at
      this format, so the shape should be agreed rather than guessed
      (a `NEEDS` is posted on the coordination board).
      **(b) command-line defines** — variant selection is `nasm -D HAL4` /
      `-dK6C` from the BUILD SCRIPT, not from inside the source, so the
      preprocessor needs externally-supplied defines to select a variant at all.
      **(c) an include search path** (`-i kernel/`).
      **(d) `section` / `global` / `incbin`** — the last 7 lines.
      **(e) `align` padding is section-dependent**: all 12 `align`s in boot.asm
      sit in `.bss`/`.rodata`/`.multiboot` and pad with ZEROS; the current
      `0x90` NOP rule is correct only for `-f bin`'s single `.text`. This is the
      dependency flagged when `align` was built, now come due.

      *Honest cost, measured then reduced:* assembling N `mov rax, rcx` (CPU
      time under identical load) went `0.09` → `0.49` s/instruction with the
      slice — linear in program length, but a 5.5x constant — and back to
      **`0.26` s/instruction (2.9x)** after optimisation, recovering 46% of the
      added cost. **The optimisation is a methodology lesson worth more than the
      speedup:** the two changes made on the most plausible reasoning — a
      CONS register table replacing a scanned flat literal (the flat-literal
      idiom optimises the table's COMPILE time, not LOOKUP time through it), and
      hoisting redundant operand derivation — were each defensible and *neither
      moved the number*. The actual dominant cost was found only by measuring
      (stub a suspect out, re-time): **every pass re-tokenized every line from
      raw text**, so the label pass, each fixed-point length pass and the emit
      pass all re-scanned each line character-by-character for no gain.
      Tokenizing ONCE up front was worth ~2x by itself — and is the same Γ/Ρ
      discipline the rest of the project keeps (tokenizing is *generation*, done
      once; the passes only *recognize* what it produced). Two smaller wins
      came with it: the fixed point now CARRIES the previous total length rather
      than recomputing it (the old form evaluated `TOTLEN` twice per iteration,
      the first being exactly the previous iteration's second), and `PASS2`
      takes its size from the bytes it just emitted instead of re-running the
      encoder to measure. Sizing-by-encoding is the remaining ~39% and is kept
      deliberately — a second length implementation is precisely how drift
      enters. **Two wrong hypotheses in a row: a plausible cause is not a
      measured one.**
      **★ MILESTONE — the object writer is built and boot.asm assembles == nasm,
      END TO END (2026-07-23), so this item is now `[x]`.** Everything the honest-
      scope correction above lists as "none of it yet built" is now done, each
      gated by byte-identity: (a) `elfobj.la`, the ELF64 relocatable-object writer
      (section headers, a symbol table, `.rela` relocation sections) — extended by
      `extern` for the multi-object seam `link.la` consumes (SHN_UNDEF symbols +
      PLT32/PC32 cross-object relocs, `484622c`); (b) `-D` and (c) `-i` need no
      asm.la feature (a `-D X` is a prepended `%define`, `-i` is the working
      directory), proven by the end-to-end run; (d) `section`/`global`/`incbin`;
      (e) the section-dependent `align`. `asm.la` + `elfobj.la` now assemble the
      real 60 KB kernel `boot.asm` (5 sections, 106 symbols, 53 relocations,
      `%include`s + `incbin`) into an ELF64 object that **links byte-identically to
      nasm's** — `ld(ours) == ld(nasm)` (BOOTELF.md). **NASM is OUT of the kernel
      OBJECT step, end to end.** Guarded on demand by the committed `gate_bootelf.sh`
      (`8965cfc`, verified GREEN + red-pathed); the cheap per-build proxy stays
      `gate_asmelf.sh` (`asm_elf_r3..r9`).
      *This closes the ASSEMBLER + object writer only.* The boundary is unchanged
      and lives in the SEPARATE items below: the final kernel LINK still runs
      `ld -T kernel/kernel.ld` (**LA linker**, `[ ]`, Track B), the single-segment
      image layout stays **`asmelf.la`** (`[~]`), and the build **orchestrator**
      still drives foreign tools including nasm 46× elsewhere (**`buildla.la`**,
      `[~]`) — so this is a nasm-free OBJECT step, not yet a nasm+ld-free kernel.
- [~] **LA image layout (`asmelf.la`) — the assembler+layout seam closed END TO
      END, gated (2026-07-16).** `elf.la` already emitted a runnable native ELF
      from LA — but its 36 bytes of machine code were **hand-assembled into a
      literal byte blob**: a human did the assembling and LA only carried the
      result. `asmelf.la` closes that: the code is **assembled from TEXT** by
      `asm.la` and the ELF is laid out around it. **From `mov rax, 1` as source to
      a running process there is no NASM and no `ld` anywhere in the path.** The
      proof is not a diff — the OS runs it: a 172-byte static ELF64 that prints
      `I AM THAT I AM` and exits 0, gated. Needed `org` + **label-as-immediate**,
      which is the piece that makes `mov rsi, msg` resolve (and a real NASM
      distinction: a LABEL immediate is `48 be`+imm64 *movabs*, while a NUMBER is
      the 5-byte `b8`+imm32 — the address fits in 32 bits, so this is a choice
      about labels, not arithmetic).
      *Honest scope — why `[~]`, and it is NOT a linker:* one source, one segment,
      one load address; **no objects, no symbol resolution across translation
      units, no relocation sections**. `org` makes labels absolute and that is all
      the "linking" a `-f bin` image needs. A real **LA linker (ELF objects +
      relocations + linker script)** — which is what `ld -T kernel/kernel.ld`
      actually does for the kernel — remains genuinely open below.
- [ ] **LA linker** — closes the `ld` + linker-script seam. Real objects, symbol
      resolution, relocation sections. `asmelf.la` above closes only the
      single-source/single-segment image case and does not claim this.
- [ ] **LA-native debugger** — the system inspecting its own execution. Deep
      closure: the system observing itself (today: `qemu -d int` + foreign tools).
- [~] **LA build orchestrator (`buildla.la`) — FIRST REAL SLICE DONE (2026-07-16).**
      `build.sh` is bash: a foreign shell script deciding what a sovereign,
      self-hosting OS builds and whether it passed. **It was IMPOSSIBLE until the
      VM gained `execv`+`dup2` (`05ed1fe`)** — `execve` took no argv (so LA could
      not run `./tiny_host kernel.la`) and without `dup2` a forked child's stdout
      went to the parent's, so LA could not CAPTURE what a step printed, and
      build.sh's checks are **274 greps over captured stdout**. Now the whole
      cycle is expressible: *fork → `dup2` the child's stdout into a file → `execv`
      CMD ARGS → `waitpid` → `read_file` → check*. `HASSUB` is the grep.
      Verified on **48 real stages** — the whole **autopoiesis stack** (kernel
      speaks the Word · self-repair · self-modification · self-programming ·
      self-optimization · runtime self-verification · self-documentation), the
      **toolchain** (ELF emitter · assembler · the LA-native toolchain emitting a
      binary), the **spec pipeline** that builds every module spec-first
      (metadebug · specpipe · primitives · κ · the three laws · AATC · SWC ·
      glyph-DAG · PSC\* · TopoEmbed · pragmatics · deixis · strutil · evdev), the
      **module system + IPC** (import isolation · the typed bus · capability
      gating · the sealed monoglyph), the **compositor** (Theourgia 1·3·4·5·6·7·8
      — surfaces, framebuffer bridge, evdev decode, session reducer, poll
      multiplexing, multiplexed session, text), and the **trimodal language layer**
      (visual: sigil · acoustic: phonym, goertzel, phonsem · computational:
      metaglyph, denote, monosemy, onf, topoderive, cob, archroot) — **BUILD
      GREEN**. Three of them are **negative gates**, not happy paths: the type
      checker **REJECTING** an ill-typed module, capability gating **DENYING** a
      foreign realm, and archroot's **"the chain does NOT generate the nine."**
      The RED path is verified too: a step
      whose marker never appears gives **BUILD RED, exit 1**, with the other steps
      still running and reporting (a build tool that cannot fail is worthless, and
      one failure must not mask the rest).
      *What it closes:* the **ORCHESTRATION** logic — deciding what to run, running
      it, capturing it, judging it, failing the build. In LA, on the VM, no shell.
      *What it does NOT close:* the **TOOLS**. Driving `./tiny_host` still runs the
      C host; build.sh also invokes gcc, **nasm (46×)**, ld, qemu, python3 — each
      its OWN seam (assembler `[~]`, linker `[ ]`, emulator `[!]`). **"The build is
      orchestrated by LA" must never come to mean "no foreign tools in the build."**
      **A SECOND KIND OF GATE — cross-engine `b_τ ≡ f_τ` (`c7e1afd`).** build.sh's
      other big check is not a grep but an **equality**: `[ "$H" = "$V" ]` — the
      same program must print the **same bytes** on the C host and the native VM.
      The two engines are **each other's oracle**. `XSTEP` adds it (**52 stages =
      48 marker + 4 cross-engine**). Agreement alone is **not** a pass (two engines
      can be identically wrong), so a step passes iff the host output carries the
      marker **and** the engines agree.
      *★ It must not run `./logos_secd`* — that VM loads its program from the one
      fixed path `logos_program.bin`, which **during a build IS the orchestrator**:
      running it forks the build into itself (a real fork bomb — measured at
      148,121 processes). The program is given its **own vessel** instead —
      `codegen → logos_embed.bin → bundle.la → logos_app` (Albedo Stage 5), which
      carries its stream embedded and never reads `logos_program.bin`. Two verified
      safety properties: codegen **displaces** the orchestrator's stream from
      `logos_program.bin`, and the bundle is **checked before it is run**, so a
      failed bundle can never fall back into the build.
      **A THIRD KIND OF GATE — the EXIT CODE (`34c93b1`).** Marker asks *did it
      say the right thing*; cross-engine asks *do both engines say the same
      thing*; neither asks what the loud-failure discipline turns on: **did it
      FAIL, correctly, and say why?** `GSTEP` asserts an **exact exit code AND the
      specific diagnostic** (then **55 stages = 48 marker + 4 cross-engine + 3 guard**).
      **A FOURTH SLICE — the LANGUAGE CORE (`64 stages`).** The 48 marker stages
      began at the autopoiesis stack; the built-in primitives `build.sh` verifies
      *first* (28–215) — `concat`, `str_tail`, `str_head`, `str_eq`, the `Z`
      combinator, native integers (`FACT(5)` via `Z`), `read_file`/`write_file`
      and their round-trip — were not yet under the orchestrator. Nine of them are
      now, as marker stages whose **fixtures buildla GENs to `/tmp` itself** (a
      `FIX` list folded by `GENALL`, the marker-side twin of the guard block's
      GEN preamble). Each marker is the **full distinctive output**; `str_tail` /
      `str_head`-of-empty are **bracketed** (`[ello]` / `[]`) so a no-op bug
      cannot satisfy a substring (`HASSUB`) gate — the four whose honest gate is
      *exact* stdout or *byte* equality (`str_head`→"h", `str_eq`→"equal", the
      `chr`/`ord` multiline, the NUL-byte survival) are deferred rather than
      fudged into a weak marker; they want an exact-stdout gate kind, not a
      marker. Verified **BUILD GREEN, 64 stages = 57 marker + 4 cross-engine + 3
      guard**, run as its **own vessel under a distinct filename** (`logos_build`,
      not `logos_app`) so the XSTEP stages, which bundle+run a fresh `logos_app`,
      don't hit `ETXTBSY` writing the orchestrator's own live executable.
      **A FIFTH SLICE — the NAMESPACE gate (`65 stages`, `USTAGE`).** build.sh's
      init test runs a program **as PID 1 in an unprivileged PID namespace**
      (`unshare -rpf --mount-proc`) and checks **orphan reaping via reparenting**:
      a child forks a grandchild then exits, orphaning it; reparented to PID 1 it
      is reaped by the same `reap` loop — exactly **2 reaps**. Two wrinkles beyond
      a marker step, both handled: **(1)** it needs a real PID namespace, which
      build.sh **skips gracefully** where unprivileged userns is unavailable — so
      `USTAGE` **probes first** (`unshare … /bin/true`, `RUN2` rc 0?) and reports
      `PASS (skipped)` rather than turning a skippable environment into BUILD RED;
      **(2)** the program must run **as PID 1**, so it is given its **own vessel**
      exactly as a cross-engine step is (`codegen → logos_embed.bin → bundle.la →
      logos_app`), never `./logos_secd` (the fork-bomb hazard) — then `unshare …
      ./logos_app` runs the bundle as init, gated on `reaped 2`. Same two safety
      properties as XSTEP (codegen displaces the orchestrator's stream; the bundle
      is checked before it is run). Verified **BUILD GREEN, 65 stages = 57 marker
      + 4 cross-engine + 3 guard + 1 namespace**.
      **A SIXTH SLICE — the QEMU gate (`66 stages`, `QSTAGE`).** build.sh's kernel
      gates boot a real kernel ELF in QEMU and assert the Word on the serial line
      + a clean `isa-debug-exit` code. **QEMU is foreign (`[!]`)** — like nasm / ld
      / gcc / tiny_host — so buildla **orchestrates** it (probe → build the ELF →
      boot → judge marker + exit code) without pretending to replace it. **K1**:
      the LA image wrapped with the boot stub + IDT boots on bare metal, speaks
      **"I AM THAT I AM" over COM1**, and exits **33** = `(0x10<<1)|1` (the handler
      writes isa-debug-exit `0x10` on the image's own `exit(0)`, so the SAME binary
      runs on host and metal — `b_τ ≡ f_τ` carried onto the hardware); `timeout 30`
      bounds a hang (a K1 CPU fault triple-faults; `-no-reboot` → QEMU exits non-33
      → FAIL). ★ The probe must be **safe**: USTAGE could `execv` `/usr/bin/unshare`
      (always present, only the *capability* denied), but qemu may be genuinely
      **absent**, and `execv`-ing a missing binary in a forked child returns
      `-errno` and *falls through* — the child would continue AS the orchestrator (a
      fork bomb). So `QSTAGE` probes with **`stat()`** (no fork, no execv): a
      `-errno` means qemu isn't at its canonical path → `PASS (skipped)`. Verified
      **BUILD GREEN, 66 stages = 57 marker + 4 cross-engine + 3 guard + 1 namespace
      + 1 QEMU**. *Honest scope:* the kernel ELF is built by the foreign nasm/ld
      toolchain (`kernel/build_k2.sh`, the assembler/linker seam) — buildla drives
      it, as it drives tiny_host; the LA contribution is the gate.
      **A SEVENTH SLICE — QEMU K2, the fault IDT (`67 stages`, `K2STAGE`).** K1
      proved the kernel boots and speaks; **K2 proves it FAILS LOUDLY at ring 0** —
      the guard-step discipline one privilege level down, enforced by the CPU.
      `kernel_fault.elf` (the `ud2` variant `build_k2.sh` builds ALONGSIDE
      `kernel.elf`) executes an undefined instruction; vector 6 (`#UD`) traps into
      the IDT, `isr6` writes **"EXCEPTION 06 …"** to COM1 and exits **35**
      (isa-debug-exit FAIL — ≠ 33, ≠ a silent triple-fault+reboot). So a CPU fault
      **names itself and halts** — `b_τ ≡ f_τ` at ring 0. Same SAFE `stat()` probe
      as K1. It does **not rebuild**: `kernel_fault.elf` is the shared prerequisite
      QSTAGE's `build_k2.sh` already produced, and buildla's eager left-to-right
      conjunction runs QSTAGE (`e`) before K2STAGE (`f`) — exactly as build.sh runs
      `build_k2.sh` ONCE and then both `gate_k1.sh` and `gate_k2.sh`. Verified
      **BUILD GREEN, 67 stages = 57 marker + 4 cross-engine + 3 guard + 1 namespace
      + 2 QEMU (K1 boots+speaks, K2 faults loudly)**.
      **AN EIGHTH SLICE — QEMU K3b, the PMM on the metal (`68 stages`, `K3STAGE`).**
      K1/K2 proved boot + loud faults; K3b proves the physical memory manager reads
      the LOADER's **real** multiboot map (not a synthetic string) via the `peek()`
      runtime builtin: `kernel_pmm.elf` prints **"K3B ARENA 1048576"** (largest
      usable-RAM arena base = `0x100000`) and **"K3B FRAME 1048576"** (first frame
      allocated = the same base), then exits 33 — two markers AND the exit code, so
      a wrong map (right rc, wrong base) still FAILs. ★ **Fast by design — it GATES
      a pre-built ELF, it does NOT drive the build.** Unlike K1/K2 (whose
      `build_k2.sh` is seconds), `kernel_pmm.elf`'s build (`kernel/build_k3b.sh`)
      recompiles `native_codegen3` under tiny_host — **~16 min** (measured 962 s
      under load) — squarely the foreign-toolchain seam (item c). Driving it inline
      would triple buildla's wall-time, so the ELF is built **out of band** (as
      build.sh does before its gate) and buildla gates whatever is present: qemu
      absent → skip; ELF not pre-built → skip (naming `kernel/build_k3b.sh`); else
      boot + judge. K3STAGE **isolate-verified** on the VM (real boot → both markers
      + exit 33 → PASS) + codegen-clean; it is an independent leaf (no ordering
      dependency), so **68 stages = 57 marker + 4 cross-engine + 3 guard + 1
      namespace + 3 QEMU**.
      **A NINTH SLICE — QEMU K4b, paging wired to the metal (`69 stages`,
      `K4STAGE`).** K3b proved the PMM reads the loader's **real** multiboot map;
      K4b proves the language **BUILDS a real page table over that memory** — the
      write-half of paging on the metal. `kernel_paging.elf` allocates a real
      physical frame from the K3 PMM (**"K4B FRAME 1048576"** = `0x100000`, the
      arena base), then BUILDS a K4a page-table entry *in that real frame* via the
      `poke` runtime builtin and reads it back via `peek`, **byte-identical to the
      K4a host==native-assembled value**: **"K4B PTELO 2097155"** (`PTE_LO(0x200000,
      P|W) = 0x200000|3`) and **"K4B PTEHI 2147483648"** (the NX bit, high32 bit31),
      then clean exit **33** — three value markers AND the exit code, so a wrong
      poke/peek (right rc, wrong value) still FAILs. `b_τ ≡ f_τ` carried onto the
      hardware: the poked-and-read PTE equals the one K4a assembles identically on
      host and native VM. Same **fast-by-design + SAFE `stat()` probe** as K3STAGE —
      it GATES the pre-built ELF (`kernel/build_k4b.sh`, out of band), never drives
      the build; qemu absent → skip, ELF not pre-built → skip (naming the build
      script), else boot + judge. An independent leaf, no ordering dependency.
      K4STAGE **isolate-verified** (direct QEMU boot → all three markers + exit 33 →
      PASS) then full **BUILD GREEN, 69 stages = 57 marker + 4 cross-engine + 3
      guard + 1 namespace + 4 QEMU (K1 boots+speaks, K2 faults loudly, K3b PMM map,
      K4b paging on the metal)**.
      **A TENTH SLICE — QEMU K4c, W^X + NX ENFORCEMENT on the metal (`71 stages`,
      `K4CWXSTAGE` + `K4CNXSTAGE`).** K4b proved paging *translates* (build a PTE,
      read it back); K4c proves it *protects* — **the guard-step discipline enforced
      by the CPU, one privilege level down**, the metal twin of the three guard
      steps and K2's #UD. Both are exit-**35** fault gates (a page-protection #PF,
      `EXCEPTION 0e`, diagnosed by K2's IDT), not the clean 33: **W^X**
      (`kernel_wx.elf`) maps a high page READ-ONLY (`K4C FRAME 1048576` +
      `K4C WX READ 171` = sentinel read back through it), then a ring-0 WRITE faults
      because **CR0.WP** is armed; **NX** (`kernel_nx.elf`, the execute-twin) maps a
      high page NO-EXECUTE over a frame holding a lone `ret`
      (`K4C NX FRAME 1048576` + `K4C NX ARMED 195` = the ret byte read back live),
      then a FETCH through it faults because **EFER.NXE** is armed — the `ret` never
      runs. ★ The NX gate carries a **NEGATIVE marker**: `K4C NX RET` must **NOT**
      appear (it prints only if `exec_at` RETURNED, i.e. NX was *not* enforced), so
      the gate is `code=35 AND FRAME AND ARMED AND "EXCEPTION 0e" AND NOT("K4C NX
      RET")` — a regression disarming EFER.NXE fails on two counts (RET printed,
      exit 33). This added a **`NOT`** combinator (`la b. b(FALSE)(TRUE)`), the first
      negated `HASSUB` in the orchestrator. Same fast-by-design + SAFE `stat()`
      probe as K3b/K4b — both GATE pre-built ELFs (`kernel/build_k4c_wx.sh` /
      `build_k4c_nx.sh`, out of band), never drive the build. Isolate-verified (a
      scratch MAIN running just the two K4c stages → both PASS, codegen-clean, the
      `NOT` gate correct) then full **BUILD GREEN, 71 stages = 57 marker + 4
      cross-engine + 3 guard + 1 namespace + 6 QEMU (K1 boots+speaks · K2 #UD faults
      · K3b PMM map · K4b paging built · K4c-wx W^X-write faults · K4c-nx NX-fetch
      faults)**. So paging on the metal is now proven **both ways** — translation
      (K4b) and protection (K4c).
      **AN ELEVENTH SLICE — QEMU K5, the timer IRQ + PREEMPTION on the metal
      (`73 stages`, `K5STAGE` + `K5B2STAGE`).** K4 proved paging; K5 proves the
      kernel can be **interrupted** and then **scheduled** — the substrate every
      preemptive OS stands on. **K5a** (`kernel_timer.elf`): the boot stub remaps
      the PIC, programs the PIT to ~100 Hz, points IDT[0x20] at `timer_isr` and
      `sti`s; the LA image spins reading a tick counter via `peek()` until an
      asynchronous IRQ0 fires — the ISR bumps it, the reduction resumes intact and
      reads **"K5 TICKS <n>"** with n≥1, clean exit 33. ★ A **NEGATIVE gate**:
      `HASSUB("K5 TICKS ") AND NOT("K5 TICKS 0")` — not merely that the line
      printed, but that the timer *actually fired* (a dead PIC/PIT/IDT/sti leaves
      it 0), so it refuses a dead timer. **K5b.2** (`kernel_preempt.elf`, boot
      `-dK5_TIMER -dK5B2`): two workers that **never call `yield()`** are
      nonetheless **INTERLEAVED** because IRQ0 sets the LA runtime's `YIELD_PENDING`
      byte and `rt_apply`'s safe point context-switches between reductions — proof
      of *preemption*, not just interrupt capability. The gate is the interleaving:
      `HASSUB("A\nB") AND HASSUB("B\nA")` — **both** transition directions present ⇒
      ≥3 runs (`ABABABAB`) ⇒ a worker was preempted mid-block; a non-preemptive
      2-run block (`AAAABBBB`) has only one direction and **FAILs** — plus `"done"`
      and clean exit 33 (needs `-m 1024` so the high MAIN + task stacks map).
      ★ **A real source bug was found and fixed en route:** `kernel/timer.asm`'s
      hard-coded `YIELD_PENDING_ABS` (the rt data slot the ISR pokes) had **drifted**
      from `native_codegen3_rt.asm`'s actual layout (`0x4012e5` → the current
      `0x4012ee`, off by 9 bytes); `build_k5b2.sh`'s drift guard **correctly refused
      to build** a preempt ELF that would poke the wrong byte and never preempt.
      Corrected the equ, rebuilt, and the ELF now interleaves 8 runs. Both K5 stages
      GATE pre-built ELFs (`kernel/build_k5a.sh` / `build_k5b2.sh`, out of band),
      never drive the build — same SAFE `stat()` discipline. Isolate-verified
      (scratch MAIN → both PASS, codegen-clean) then full **BUILD GREEN, 73 stages =
      57 marker + 4 cross-engine + 3 guard + 1 namespace + 8 QEMU (K1 boots · K2 #UD
      faults · K3b PMM · K4b paging · K4c-wx/nx W^X+NX enforce · K5a timer fires ·
      K5b.2 preempts)**.
      **A TWELFTH SLICE — K5b.1, the COOPERATIVE scheduler in the LA-native runtime
      (`75 stages`, `K5B1STAGE` + `K5B1BSTAGE`).** K5b.2's *preemption* stands on a
      userspace foundation: `native_codegen3`'s spawn/yield green-thread runtime and
      its GC's awareness of *suspended* tasks. K5b.1 gates that foundation. These are
      **not QEMU** (no ring 0) — they RUN a native binary the LA-native backend
      emitted, which is exactly the ORCHESTRATION boundary the QEMU stages already
      hold: the foreign toolchain (`tiny_host` + `native_codegen3`) BUILDS the binary
      **out of band** (`kernel/build_k5b1.sh`; the ~78s compile is *not* driven
      inline, as K3b/K4/K5 avoid), buildla RUNS + JUDGES it. **K5b.1a**
      (`native_pingpong.bin`): two workers round-robin via `yield()`, interleaving
      exactly `A B A B A B` then `done` — each worker's loop counter + mid-loop
      continuation preserved across a REAL context switch on its own saved stack; the
      whole exact interleave is the marker, clean exit 0. **K5b.1b**
      (`native_gc.bin`): task A holds a canary live across a yield; task B churns
      ~400 MB, forcing the periodic mark-sweep to fire *while A is suspended* —
      `rt_gc`'s per-task root scan (every runnable task's saved regs +
      `[saved_rsp, stkbase)`) marks it, so it is byte-intact on resume (`SURVIVED` +
      `B-churned`); the prior rt_gc, scanning only the current task, swept it — the
      regression this gate guards. Both compile to the SHARED `native_codegen3_out`,
      so `build_k5b1.sh` copies each to a DISTINCT stable name buildla can gate.
      SAFE: running these binaries never touches `logos_program.bin` or `logos_secd`
      (no fork-bomb, no stream clobber). New out-of-band `.bin` artifacts are
      gitignored (only the `.la`/`.sh` source is committed), as the kernel ELFs are.
      Isolate-verified (scratch MAIN → both PASS, codegen-clean) then full **BUILD
      GREEN, 75 stages = 57 marker + 4 cross-engine + 3 guard + 1 namespace + 8 QEMU
      + 2 native-task**. So all of K5 (timer capability · preemption on the metal ·
      the cooperative runtime + GC-safe suspension beneath it) is now orchestrated in
      LA.
      **A THIRTEENTH SLICE — K6, RING 3 on the metal: user mode, syscalls, IPC
      (`81 stages`, six slices via a new `QGATE` helper).** K5 proved the kernel
      *schedules*; K6 proves it enforces the **privilege boundary** — a payload at
      CPL 3 that enters the kernel only through `syscall`/`sysret`, and the LogosIPC
      "nervous system" re-homed onto kernel-held channels between ring-3 tasks. Six
      exit-33 QEMU gates on pre-built ELFs (all boot-tested green first): **K6a** —
      ring-3 user mode (`K6A CPL=3`: GDT/TSS(RSP0)/iretq-to-ring3/syscall-sysret/
      user-page); **K6b** — the *real* `kernel.la` image speaks the Word at ring 3
      (`I AM THAT I AM`, the SAME image that runs at ring 0 under K1..K5); **K6c.1**
      — the kernel IPC service (`K6C t7 IAM`: a typed message send/recv'd across the
      boundary); **K6c.2** — two ring-3 tasks + a real kernel context switch (`B got
      IAM` **AND** `A got YOU` — full save/restore); **K6c.3a** — a compiled LA
      process does IPC (`K6C3 IPC OK`, `ipc_kernel.la`'s `send(0)`/`recv(0)`);
      **K6c.3b MILESTONE** — two ring-3 LA tasks exchange a **typed** message (`B rx
      type=greet` **AND** `B rx body=HELLO`, `ENCODE`d greet/HELLO decoded by the
      peer). ★ Rather than six more lambda layers, this introduced a **parameterised
      QEMU-gate helper `QGATE(elf)(cmd)(code)(chk)(label)`** — the SAFE `stat()`
      probe + `RUN2` + `exit==code AND chk(out)`, where `chk` is a *predicate* on the
      output so a slice can demand ONE marker or (the two round-trip slices) BOTH; the
      six become a flat `K6ALL` table wired into MAIN as a single var. The K1..K5
      stages keep their bespoke glyphs (exit-35 fault gates + the negative K5a/K5b.2
      markers `QGATE` doesn't model). Isolate-verified (scratch → all six PASS,
      codegen-clean, a mis-nested paren caught by a code-paren-balance check *before*
      the codegen) then full **BUILD GREEN, 81 stages = 57 marker + 4 cross-engine +
      3 guard + 1 namespace + 8 QEMU + 2 native-task + 6 ring-3 (K6)**.
      **A FOURTEENTH SLICE — K7, the SOVEREIGN BOOTLOADER: LogOS boots ITSELF
      (`83 stages`, two slices).** K1..K6 booted via QEMU's `-kernel` — a *foreign*
      loader placing the image. K7 closes that last seam: LogOS's OWN 512-byte MBR +
      stage-2 loader, off a **raw disk image** (`-drive if=ide`, NOT `-kernel`), with
      no GRUB and no multiboot loader. **K7a** — the sovereign boot sector: the MBR
      ran in real mode, built a GDT, entered 32-bit protected mode (`K7 real` +
      `K7 pmode`), exit 33. **K7b MILESTONE** — the whole chain: MBR (`K7 real`) →
      reads stage 2 off disk (`K7 stage2`) → A20+GDT+protected mode (`K7 pmode`) →
      ATA-PIO-loads the kernel's segments and hands off (`K7 handoff`) → the handed-off
      kernel brings up long mode + the syscall substrate and the LA image speaks
      `I AM THAT I AM`, exit 33. The gate demands **all five** stage-markers, so a
      chain that fell over anywhere still FAILs. `QGATE` served this unchanged — the
      disk-image path took the `stat()`/skip slot, the `-drive` command the `cmd`
      slot; the images are built out of band (`kernel/build_k7a.sh` / `build_k7b.sh`)
      and gitignored like the ELFs. Isolate-verified (scratch → both PASS,
      codegen-clean; two mis-nested parens — one in `K7ALL`, one in the 16-var AND
      fold — both caught by the code-paren-balance check *before* codegen) then full
      **BUILD GREEN, 83 stages = 57 marker + 4 cross-engine + 3 guard + 1 namespace +
      8 QEMU + 2 native-task + 6 ring-3 + 2 sovereign-boot**. **So the entire
      sovereign kernel K1..K7 — boot, faults, PMM, paging (translate + protect),
      timer, preemption, ring-3 user mode + IPC, and now LogOS booting ITSELF off its
      own disk — is orchestrated in Lingua Adamica, on the VM, no shell.**
      **A FIFTEENTH SLICE — cross-engine FILE byte-identity (`85 stages`, a new
      `XFSTEP` kind).** The `XSTEP` cross-engine gate compares **stdout** (`b_τ ≡
      f_τ` over what a program *prints*). build.sh's *other* half of cross-engine
      identity is `cmp -s canvas.ppm /tmp/canvas_host.ppm` — the same generator must
      emit a **byte-identical FILE** on the C host and the native VM. `XFSTEP` is that
      gate: run the target under `tiny_host` (it writes `outf`) and SAVE `outf`; then
      codegen+bundle the target into `logos_app` (**never `./logos_secd`** — the fork
      bomb; the bundle is the proven route `XSTEP` already uses, and the write to
      `logos_program.bin` mid-run is the documented-safe direction) and run
      `logos_app` (it rewrites `outf`, now the VM's version); pass iff the saved host
      file **`str_eq`s** the VM file (byte-exact + binary-safe — it *is* `cmp -s`)
      **AND** the host file carries a header `mark`, so two empty or
      identically-broken files can't fake a pass (the marker-AND-equality discipline
      `XSTEP` holds). Two PPM rasters from **different** generators — the surface
      compositor (`theourgia.la` → `canvas.ppm`) and the text renderer
      (`theourgia_text.la` → `text.ppm`), both gated on `P6`. Green AND **red both
      verified** — a scratch with a marker absent from the file printed
      `FAIL host!=VM`, so the gate is not vacuous. Verified full **BUILD GREEN, 85
      stages = 57 marker + 4 cross-engine (stdout) + 3 guard + 1 namespace + 8 QEMU +
      2 native-task + 6 ring-3 + 2 sovereign-boot + 2 cross-engine (FILES)**. *Honest
      scope:* the WAV (`phonym.la`) and the module-composed session/mux rasters emit
      identically too, but each host run + bundle is minutes, so they stay out of the
      hot path.
      **A SIXTEENTH SLICE — VM loud-failure guards (`89 stages`, a new `GVSTEP`
      kind).** The three `GSTEP` guards run on the C **host** (`tiny_host`) — its
      diagnostics. But the OS runs on the native SECD **VM**, and build.sh regression-
      tests a whole `secd:` guard set so no malformed input is a SILENT path on that
      engine (a disarmed guard = a silent exit 0, or a SIGSEGV walking unmapped
      memory). Those must run **on the VM** — which buildla cannot do via
      `./logos_secd` (the fork bomb). So `GVSTEP` gives each broken program its own
      vessel exactly as the cross-engine steps do: GEN it → codegen → bundle →
      `logos_app`, then `RUN2` it and assert a **non-zero exit (1) AND the specific
      `secd:` diagnostic** (RUN2 dup2s the capture fd onto both stdout and stderr, so
      the stderr diagnostic is caught). Four guards: **unbound variable**
      (`undefined_glyph_xyz`), **apply a non-function** (`"hello"("world")`), **chr
      out of range** (`chr("300")`), **argument is not a string** (`str_len(5)` — an
      INT where a descriptor is expected, which would otherwise SIGSEGV). Each
      **parses + compiles fine** (codegen is syntactic) and fails at RUN time —
      exactly where the guard must fire; the VM's `chr`/`argument-is-not-a-string`
      guards are the sovereign-engine twins of the host `chr`/`str_to_int` guards
      already covered. Green AND **red both verified** — a scratch feeding a program
      that does NOT halt (`print("ok")`, exit 0) printed `FAIL vm RED does-not-halt`.
      Verified full **BUILD GREEN, 89 stages = 57 marker + 4 cross-engine (stdout) + 3
      host-guard + 4 VM-guard + 1 namespace + 8 QEMU + 2 native-task + 6 ring-3 + 2
      sovereign-boot + 2 cross-engine (FILES)**. *Honest scope:* build.sh's
      poll-cap / program-too-large / malformed-stream guards need a 500-fd literal or
      a raw/truncated stream (they test the generic LOADER a bundle bypasses), so they
      stay in build.sh's harness.
      **A SEVENTEENTH SLICE — the TOOLCHAIN itself (`91 stages`, `elf.la` host==VM +
      the `native_codegen3` differential).** The deepest category: stages that drive
      the LA-native toolchain buildla is built on. Each was **audited** first —
      `native_codegen3.la` only writes `native_codegen3_out` (a NEW file), never
      `logos_program.bin`/`logos_secd`, so no fork bomb / no stream clobber. Two
      added: **(1)** `elf.la` (Albedo Stage 1, the hand-written LA ELF assembler)
      emits a native 171-byte ELF `logos_native` by pure generation — added to the
      `XFSTEP` set (marker `ELF`), proving it is **byte-identical host==VM** (the
      assembler is deterministic across the C host and the sovereign VM). **(2)** a
      new `NDSTEP` kind — the LA-native BACKEND (`native_codegen3.la`, Albedo Stage 3)
      lowers a program to a standalone native binary, and its stdout must equal
      `tiny_host`'s on the same program (`b_τ ≡ f_τ` for the native compiler, the
      backend and the interpreter each other's oracle). It STAGEs the target →
      `native_input.la`, drives `tiny_host native_codegen3.la` **inline** (~18s — the
      compile IS the toolchain step under test), gates the compile on its
      `emitted native_codegen3_out` line (a stale binary can't sneak through), then
      runs the emitted binary and the host and asserts byte-equal stdout + marker;
      the module-importer `greetapp.la` compiles native==host (`module-importer`).
      Green AND **red both verified** (a wrong marker → `FAIL native!=host`; a bug
      found + fixed en route — `RUN2` returns the *exit code*, `RUN` returns the
      *output*, so the native side must use `RUN`). Verified full **BUILD GREEN, 91
      stages = 57 marker + 4 cross-engine (stdout) + 3 host-guard + 4 VM-guard + 1
      namespace + 8 QEMU + 2 native-task + 6 ring-3 + 2 sovereign-boot + 3
      cross-engine (FILES, incl. the native ELF) + 1 native-backend differential**.
      *Honest scope:* the Albedo Stage-4 compiler==compiler / VM==VM fixed points
      regenerate the compiler and the VM themselves — driving them inside a running
      buildla would have it rewrite its own engine, so those stay in build.sh's
      harness (the deepest self-hosting checks, run once from the C-host seed). What
      remains of build.sh's 103 is now that irreducible seed core + the foreign-tool
      seams (nasm/ld/gcc/qemu) buildla ORCHESTRATES but does not replace.
      It unlocks the **`DEPTH(DEPTH)`** gate — whose whole content is that it must
      **not** terminate (`timeout`, rc 124), the deliberate exception in
      `primitives.la` — and opens build.sh's `secd:`/host guard regression set.
      Needed `RUN2`: the old `RUN` captured only **stdout** (diagnostics go to
      **stderr**) and **discarded** `waitpid`'s result (the code *is* the gate).
      *Verified:* `waitpid` returns the code **already decoded** (timeout→124,
      failing host→1, kernel→0), not a raw wait status.
      *★ Empty markers are allowed on a guard step*, deliberately unlike a marker
      step — the asymmetry is the point: a marker step's only discriminator is
      `HASSUB` and `""` matches everything (vacuous), whereas a guard step's is
      **exact code equality**, never vacuous. So the code is checked always, the
      marker only when given — which is what lets `DEPTH(DEPTH)`, whose output is
      empty by construction, be gated honestly rather than fudged.
      *Why `[~]`:* **68 of 103 stages.** What remains is **design- and cost-bound**,
      not typing: ~~(a) `unshare` gates~~ **DONE (`USTAGE`)**; ~~(b) QEMU~~ **K1+K2+K3b
      DONE (`QSTAGE`/`K2STAGE`/`K3STAGE`)**, K4–K7 remain (each a foreign-emulator boot
      of its own kernel variant); (c) stages driving the toolchain itself
      (`codegen.la`/`secd.la`) — the artifacts the orchestrator IS. Cross-engine is
      **cost-bound**: each XSTEP is a host run + codegen + bundle + VM run, so the
      four are cheap only because they are fast pure modules; extending to
      `sigil`/`phonym` would add serious wall-time to an ~11-minute build. Not `[x]`
      until it actually is.
- [ ] **LA-native test/verification harness** — the system testing itself in its
      own language (today: bash gates + QEMU).
- [!] **The emulator** — testing runs in QEMU (foreign). Closing it needs our own
      emulator, or testing only on real metal. Honest seam, **low priority**.

**Self-knowledge seams — the system knowing itself.**

- [~] **Self-documentation — STRUCTURAL INVENTORY DONE + gated (2026-07-16),
      `selfdoc.la`.** Every description of this system lives OUTSIDE it
      (CLAUDE.md, ROADMAP.md, the comments): hand-written, able to drift, none
      derived from the thing described — *this session caught exactly that drift
      once, a ROADMAP claiming "no memory operands" about an assembler that had
      them.* A description that **cannot** drift is one read off the form itself.
      The precedent is `aatc.la`'s `SENSE_SRC` (already derives an organ's facts
      from its source text); this carries it to the module's whole shape: every
      glyph, its arity, and the siblings it is built out of — **the dependency
      graph IS the etymology, recovered by reading the form**, exactly as
      `canon.la` requires of a monoglyph (`REN ≡ CANON(ETYM)`).
      **Autological**: run on itself it describes `DOC`/`ARITY`/`DEPS` — the very
      machinery that produced the account. A documenter that could not document
      itself would be heterological, ascribing to every other module a property it
      exempts itself from.
      *(The gate asserts SPECIFIC arities because an earlier version reported
      `arity 0` for everything — it sought the body at the first `.`, which lands
      INSIDE `la path.`. Its own output exposed it: `DOC` plainly takes a binder.)*
      *Honest scope — why `[~]`:* it reads **structure, not meaning**. It cannot
      know what a glyph is FOR; the prose in these headers is not derivable from
      the code and is not claimed to be. So it replaces the part of documentation
      that **drifts** (the structural inventory) and leaves the part that cannot
      be derived (intent) to a human. And it is textual, not a parse: `DEPS` is
      substring containment, so a name inside a longer identifier or a string
      literal is counted — a real over-approximation, named rather than hidden
      (a full parse via `parser.la` is the honest upgrade).
- [ ] **Self-description / introspection** — the RUNNING system reporting its own
      structure, state and capabilities from within: *"what am I made of?"*
      answered by itself, not by external docs.
- [ ] **Self-profiling** — measuring its own performance from within, and
      (autopoietic extension) using that to optimise itself.
- [~] **Self-metrics / self-history** — its own account of its own evolution. The
      **centropy ledger** (`aatc.la`) is the seed; extend it system-wide. The
      system that remembers its own becoming.

**Semantic / language-level closure — the autological deepening.**

- [x] **Denotational morphology — ALREADY DONE (`denote.la`).** *Recorded here
      because it is easy to re-open by mistake:* the linguistic-closure audit's
      #1 finding was that a compound's meaning was not a function of its parts'.
      `denote.la` CLOSED it — `MEANING` is the homomorphism, **compositional by
      construction** (`MEANING(M(a,b)) = ⟦M⟧(MEANING a)(MEANING b)`), and it
      **commutes with κ** on the documented rewrite (syntax-rewrite and
      semantic-reduction agree). Gated in `build.sh`, byte-identical host==VM.
      Not a frontier — a settled result.
- [ ] **Self-verifying grammar** — the grammar recoverable-as-data; it currently
      fails its own `DECOMP` standard (audit finding). Make its own rules
      expressible and checkable in itself.
- [ ] **The operators as glyphs** — `∂δγρ𝔄` are hardcoded dispatch, not
      first-class glyphs (audit finding). Full autological uniformity; the same
      move `metaglyph.la` already made for the five modes, κ and the evaluator.
- [ ] **Self-typing** — the type checker checking its own types, in itself.
- [x] **Runtime continuous self-verification — DONE + gated (2026-07-16),
      `selfwatch.la`.** The criterion applied to the LIVE system, not once at
      build time. `build.sh` **is** the autological criterion — but it runs at
      build time and then the system runs with nothing watching it; `selfrepair`
      (B3) is likewise a single act. Everything the project verified, it verified
      about a system that was **not running**. `aatc.la` already names why that
      matters: **ρ (the recognition coefficient) is 0 for an UNWITNESSED
      structure, and an unwitnessed structure "drifts toward potentiality"** — so
      build-time-only verification leaves the system unwitnessed for its entire
      life. This is B3's criterion on a **loop**: Sense (`INTACT`) → Diagnose →
      Prescribe (`HEAL`) → Learn (the ledger), continuously. **Nothing new was
      invented — it is the same criterion, running.** Verified: the organ is
      corrupted UNDERNEATH the running loop (a wrong constant that still parses,
      so a structural sense would miss it); the loop noticed on its **very next
      sense**, restored closure from the verified source, and **carried on** —
      ticks 4-5 ok, ledger `..R..`, organ correct on disk. The post-repair ticks
      are gated on purpose: without them a repair that silently failed would
      still look like a pass. *Honest scope:* a BOUNDED loop (N ticks), not a
      daemon — no scheduler, no timer, no signals, nothing else running alongside
      to be watched; it senses ONE spec-generated organ (B3's boundary unchanged:
      repairable == spec-generated). Watching the whole system on a real schedule
      concurrently with real work is the extension. And bounded in the **Gödel**
      sense too (Tier 3): it verifies a NAMED INVARIANT continuously, which is the
      only kind of self-verification there is — "the system fully verifies itself
      while alive" is neither the goal nor claimed.

**The reflexive maximum.**

- [x] **Self-optimization — DONE + gated (2026-07-16), `selfopt.la`.** The system
      improving its OWN code from within. Composes the core three rather than
      inventing anything: `selfprog`'s `SYNTH` (search my own capability space) +
      `selfmod`'s `ADOPT` (regrow, verify EVERY glyph, adopt-or-refuse) + the new
      part, **sensing its own cost**. It is `aatc.la`'s Centropic loop with SENSE
      finally pointed at **cost** rather than correctness: *sense my own
      applications → is something cheaper reachable? → SYNTH it and ADOPT only if
      cheaper AND still correct → the ledger (`CENTROPY`/`GAIN`)*.
      **How it measures itself:** LA has no step counter and there is no external
      profiler, so the system reads its cost off its **own structure** — `COST`
      counts `(` in its own source: one application, i.e. one β-reduction site,
      each. Intrinsic and structural. Verified: it sensed its own
      `la x. DEC(INC(TRIPLEN(DEC(x))))` at **4 applications**, synthesised
      `la x. TRIPLEN(DEC(x))` at **2** (gain 2), and adopted it.
      **It cannot break itself:** the candidate must satisfy the SAME acceptance
      test (not re-derived or re-fitted to the winner), and `ADOPT` re-runs EVERY
      glyph's tests — so an optimisation that made one glyph cheaper by breaking
      another is refused. It can trade cost, never correctness.
      **It is its own fixed point:** `aatc.la` states `𝒯` is *"the identity on an
      already-autological structure"*; the optimiser must match or it would churn.
      Run again on the organ it produced, it reports `ALREADY OPTIMAL` and changes
      nothing — `OPTIMIZE(OPTIMIZE(x)) = OPTIMIZE(x)`, asserted not assumed.
      *Honest scope:* application-count is the right measure for programs drawn
      from one composition family (as these are); it is **not** a general
      performance model — it cannot know `mul` costs more than `add`, nor see
      sharing or laziness. It is the measure the substrate affords, named for what
      it is rather than dressed up as profiling it cannot do. **Bounded** (Tier 3):
      the organ's glyphs are optimised; specpipe, the compiler and this module are
      not optimising themselves in the act.
- [ ] **Self-specification** — generating the SPEC for its own next version: not
      just deciding a change, but authoring the requirements. The hardest and most
      open; note it runs directly into the goal-origination wall below, so expect
      a bounded form, not a total one.

**Priority order (updated 2026-07-17 — the pivot):** the language/build autopoiesis
is now closed to its honest boundary (self-optimization, the LA-native toolchain, and
`buildla` at 91/103 all done; the rest is the irreducible seed + foreign-tool seams,
low marginal return on the already-proven core claim). **The active frontier is
building the OS OUTWARD** — compositor on the metal → core drivers (disk · keyboard ·
NIC send/recv) → the process/memory/service layers → **Tier 2b OS-level autopoiesis**
(above). *This is both the usable system and the substrate the next autopoiesis needs.*
*(When we RETURN to language depth, the deepest remaining autological language closure
is **denotational morphology in its TOTAL form** — the audit's #1 LA finding. Its
COMPOSITIONAL layer is already built (`denote.la` — a settled result, do not re-open
it), but full agreement across ALL κ-equivalences (not just the one documented rewrite)
is bounded by undecidability, and the neighbouring language-depth seams — self-verifying
grammar, the operators-`∂δγρ𝔄`-as-glyphs, self-typing — remain. Keep this on the list.)*

### Tier 3 — the honest LIMITS (named so they are never chased)

*These are not TODOs. They are the floor to build **up to**, not through.
Recording them is what keeps the framework's integrity — and what stops a future
session from quietly chasing the impossible.*

- [!] **Hardware / firmware — the irreducible floor.** Cannot be closed in
      software (the Bootstrap Theorem's womb). Open hardware is the *only* path
      to shrinking it, and it is a separate, long-term, mostly-not-software
      frontier. **Do not attempt to close it in LA — you cannot.** (See Open
      silicon, Phase III.)
- [!] **The trusted base for self-repair / self-modification.** Something must
      remain un-self-modified in order to *do* the modifying and repairing.
      Closure-from-nothing is exactly the pseudo-paradox the Codex dissolves.
      Therefore self-modification and self-repair are **bounded** — always a
      trusted core. Build the bounded version; never chase total.
- [!] **The learned-model seam.** A statistical model's capability comes from
      training and compute, not from LA. LogOS can **own, run, and orchestrate** a
      model sovereignly (the orchestration *is* closable), but the model's
      intelligence is not autopoietically generated by the language — the weights
      are learned, not authored. Honest limit; consistent with the
      intelligence-architecture split (metalogical reasoning core in LA; the
      statistical model as interface only).
- [!] **GÖDEL — the limit on TOTAL self-verification.** *The deepest honest wall,
      and a formal result rather than an engineering gap.* By Gödel's second
      incompleteness theorem a consistent formal system of sufficient strength
      **cannot prove its own consistency from within**. So *"the system fully
      proves itself"* is impossible **in principle** — not merely unbuilt.
      **Bounded self-verification is the real maximum**, and it is what the
      project already builds: `build.sh` as the autological criterion, `AUTO_OK`,
      the AATC, `INTACT`. Note this is the same shape as the bounds already
      recorded elsewhere and honoured rather than papered over — `swc.la`'s
      `UNKNOWN` class is the halting residue (Rice/Turing), and `NORMK` collapses
      only its DECLARED equivalences because full semantic equivalence is
      undecidable. Related formal floors: Shannon (the information-theoretic
      floor `glyphdag.la` records for a fully-distinct derivation tree), Rice, and
      the halting problem. **Do not attempt a total self-proof; deepen the bounded
      one.**
- [!] **Goal origination / what-to-change.** Deciding **which** change to make,
      autonomously, is the genuinely open frontier — and the corpus already rules
      on it: `canon.la`'s `SR_FOR = ↻(LOVE)` is *"teleology — the ACHIEVABLE form
      of purpose, a BOUNDED GOAL-DIRECTED LOOP; NOT purpose-origination"*. The
      **mechanism** of change is closed (`selfmod.la`), and **writing the program
      for a given want** is closed (`selfprog.la`); originating the want is named
      by the corpus as the wrong target, not as a gap to close. Expect bounded
      forms (a want derived from a sensed LACK in its own structure — `aatc.la`'s
      `T_CLOSE`, "internalize the lacked domain") rather than origination ex
      nihilo.

*Achieving Tiers 1 and 2 yields a system autopoietic in every sense a system
running on physical hardware **can** be — the true, honest maximum.*

---

## Honest Findings (recorded as the project demands)

These are settled results, kept visible because the framework's integrity
depends on recording what was found, not what was hoped.

- **Geometry is the dyad-in-a-circle**, not a classical sacred form. Tested and
  settled negative: the golden ratio (φ, 0/15 ratios), the Flower of Life, the
  Monad, the Vesica Piscis, and π (trivially present in circles, not a
  meaningful structural constant). The geometry's organizing signature is the
  binary self-relation ∃(∃) — two-as-one — derived, not imposed, and
  corroborated by the corpus's own Alignment Theory of Truth.

- **The Cycle of Being is enacted by the derived geometry** — all three
  cosmogenic beats present, with a discriminating control, observed not imposed.

- **ρ ≡ SR_ABOUT — a discovered identity** (2026-08-18). The recognition coefficient
  ρ = ↻(RECOGNITION) is the SAME canonical form as `canon.la`'s `SR_ABOUT`, the Logos
  *about* itself. Ruled INTENDED, not a collision: two names were found to name one
  meaning, which is monosemy working from two directions — not polysemy (one form, two
  meanings). The claim it commits to: *to bear a recognition coefficient IS to be the
  Logos describing itself.* To be asserted as a POSITIVE gate with a RED path, because a
  merely tolerated identity is indistinguishable from a collision nobody noticed.

- **The nine phonyms rest on a FIVE-vowel ontological base** (2026-08-18). The nine
  vowel nuclei collapse onto five grounds — opening /ɑ/ · distinction /i/ · grounding
  /u/ · wholeness /ɔ/ · relation /a/ — with the consonantal ONSET as the differentiating
  layer above. Not imposed: the build had already hit it from the other side, since the
  onset cues were introduced precisely *because* BEING/SELF/FORM collide on /ɑ/ and
  LOVE/BECOMING on /u/. This reframes the onset machinery from a patch into architecture,
  and immediately exposed one primitive (VOID, declared /hɑ/) whose nucleus deviated from
  the /ɑ/ it claims — corrected, pending verification.

- **★ A check that cannot fail is not a check — FOUR independent instances** (tallied
  2026-08-18). (1) An empty marker, contained in every output, made a build step report
  PASS unconditionally. (2) A proposed "more than two parents ⇒ violates dyadic
  recursion" gate on a state the Scott encoding makes *unconstructible* — it could never
  fire; the dyadic law is enforced by the data type, which is stronger, and must be
  reported as such rather than dressed up as a passing check. (3) A 24-byte reclamation
  gate silently voided when `HEAP_SIZE` was raised 1.5→16 GiB for an unrelated fix — it
  now passes with ZERO reclamation while its text claims "impossible without
  reclamation". (4) A gate whose *measurement step* died on an octal parse, so the
  assertion never ran and it still exited 0. **Each looked green.** The discipline that
  follows: test the RED path, and assert that you MEASURED — not merely that the
  comparison passed. This is the project's highest-yield defect class.

- **Two-register discipline.** *Alignment* (sign ≡ referent) is 1.0 by nature
  (Alignment Theory of Truth — identity, not correspondence). *Instantiation
  fidelity* — how faithfully the rendered form/sound captures that alignment —
  is measured: ~0.863 visual, ~0.73 phonetic. The gap is the lawful cost of
  compressing rich structure into finite, complexity-one forms (the third
  operator, γ). Exact at the ontological roots; bounded at the composites.

- **Two senses of entropy.** *Ontological* entropy (distortion / absence of
  self-recognition) is zero at α=1. *Physical* entropy (the substrate's energy
  and information cost) is not — the system runs on silicon. Both true; the
  first is the genuine result, the second the honest boundary.

- **The asymptote is located, not collapsed.** The finite-encoding fidelity
  bound is the information-theoretic face of differentiation (∂) itself. Run
  through the framework's own AATC, "collapsing" it is a category error.
  Recognizing it *is* the correct move.

---

## A Note on Scope

LogOS is not competing to be a faster or more widely adopted general-purpose
system. It is the only instance of a different kind of thing: an operating
system grounded in and enacting a single ontological principle, where the
language and the system share one autological ground. Measured against
mainstream systems on speed or ecosystem, it is not "better." Measured as an
instantiated ontoglyph — a system whose signs are derived from what they mean,
whose behavior equals its declaration all the way down — it is the only one of
its kind. That is the standard by which this roadmap should be read.
