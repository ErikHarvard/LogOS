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
    - [ ] K5b — tasks + context switch: a task = saved register context + its own
          stack; cooperative `yield` first, then the timer ISR forces a switch
          (preemptive). The DESIGN problem: (1) how an LA program expresses a task
          — likely new `spawn`/`yield` HAL builtins (first native_codegen3
          extension since `exec_at` → reopens the `regen_selfhost` Stage-4 dance);
          (2) the copying GC scans ONE stack for roots, so multiple task stacks =
          multiple root sets the collector doesn't know about (the hard fork to
          resolve before building).
  - [ ] K6 — user mode (ring 3) + a real syscall service layer (re-home LogosIPC
        over in-kernel channels; native process model vs fork/execve)
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
