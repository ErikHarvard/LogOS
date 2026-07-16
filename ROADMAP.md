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
- [x] Onset/energy fix (resolve the Beauty / Becoming-Form phonetic collision) — collision closed (8/8 injective, verified host==VM in the full audit); honest cost: concordance 0.73→0.71 (onset cues discriminate but aren't ontologically ordered — documented, not chased)
- [ ] Stratified fidelity measurement (roots vs. composites)
- [ ] Fractal Monoglyph — depth recoverable by decomposition, not surface marks

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
      - [ ] Then the compositor on the metal.
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

- [ ] **Self-modification** — the system extending/rewriting its own code *from
      within*: not merely compiling itself, but changing itself. Buildable
      precisely *because* the system contains its own compiler, so it can
      regenerate and extend its own components. The deeper Rubedo-horizon
      capability. **Bounded by design** — see the trusted-base limit below.
- [ ] **Bounded self-repair** — the system detecting a corrupted component and
      regenerating it from its own verified source (ledger **B3**). The
      `AUDIT_FILE`/`REPAIR` machinery in `aatc.la` is the seed of the criterion;
      the missing half is regeneration of the real artifact.
- [ ] **Self-programming via the language** — the system generating new LA
      programs from within (the meta-programmable / democratized-coding goal).
      `autoloop.la` + `specpipe.la` are the seed; the goal decomposition is still
      supplied from outside, which is the gap to close.

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
