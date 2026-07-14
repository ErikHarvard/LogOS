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
- [ ] Standard optimizations (inlining, dead-code elimination, constant folding)
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
      - [~] **HH1 — higher-half** (roadmap's "just-before-K6" prereq). Relink boot +
            kernel to the −2 GiB half 0xFFFFFFFF80000000 (sign-extended disp32
            reaches it → NO opcode changes, only addresses move); map PML4[511]→…
            to the kernel's phys pages, jump high, drop the low identity map to free
            the low canonical half. The LA image's fixed RT_* move high → a
            kernel-only HH rt variant (native_codegen3_hh, base 0xFFFFFFFF80000078)
            via the derive_consts tooling with a new base; Stage-4/Linux self-host
            keeps the low-based rt. BIGGEST/RISKIEST brick (dual RT address-sets).
            Gate: kernel speaks the Word from the high half.
      - [ ] **HH2** — per-process page tables (PML4[0] per proc, kernel PML4[511]
            shared into each). The process-model foundation.
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
      - [~] **K6c — real syscall service layer.** Grow syscall_entry past write/exit
            into the process/IPC primitives; re-home LogosIPC over in-kernel
            channels (the "nervous system"). Gate (milestone): two ring-3 LA
            processes exchange a typed message through a kernel channel. Effectively
            its own milestone — **staged**:
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
          - [ ] **K6c.3 — re-home the real LogosIPC typed layer.** Give
                native_codegen3's runtime `send`/`recv` builtins (emit the syscalls),
                rebuild the Stage-4 fixed point, and run two LA processes exchanging a
                real `logosipc.la` typed message through the kernel channel — the
                milestone gate.
        **Ordering (recommended):** K6a first (cheap, isolates ring-3 mechanics on
        the current identity map), THEN HH1 (big reorg, now with a ring-3 target to
        validate against), then K6b/K6c. **K6a + K6b + K6c.1 + K6c.2 DONE — next is
        K6c.3 (real logosipc.la typed message between two LA processes = the K6c
        milestone gate) or HH1.**
  - [ ] K7 — sovereign bootloader (replaces GRUB) — last
- [x] 3. Init system (`logosinit.la`, PID-1) *(Linux-userspace prototype; the
      native process model is re-homed onto the kernel at K5/K6)*
- [~] 4. Hardware abstraction layer *(DRM/KMS path proven on hardware as a
      Linux-userspace VM program; the kernel's own HAL begins at K1's boot.asm —
      real bare-metal drivers, display, disk, PCI are the largest remaining chunk)*
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
