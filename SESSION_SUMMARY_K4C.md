# LogOS — Session Summary (K4c: NX/W^X live)

_2026-07-08 → 07-09. Untracked scratch note; authoritative status lives in `ROADMAP.md`._

## What we completed this session

**K4c "NX/W^X live" — paging protection enforced on bare metal**, both halves
proven by a real CPU page-fault under QEMU (K2's IDT diagnoses it → QEMU exit 35):

- **W^X** (`paging_wx_live.la` + `gate_k4c_wx.sh`): an LA-built 4-level page table
  in real PMM frames maps a high page **read-only**; after the CR3 switch the CPU
  serves reads but a ring-0 **write** faults (`#PF err=0x3`).
- **NX** (`paging_nx_live.la` + `gate_k4c_nx.sh`): a high page mapped **no-execute**
  (PTE bit 63) over a frame holding a `ret`; a **fetch** through it faults
  (`#PF err=0x11`, the I/D bit = the NX signature). The `ret` never runs.
- **Substrate**: `boot.asm` arms **CR0.WP** + **EFER.NXE** behind `%ifdef K4C_WX`
  (like K2's fault-injection), so every other kernel ELF's boot bytes stay
  byte-identical.
- **Toolchain**: a 4th `native_codegen3` HAL primitive, **`exec_at(vaddr)`**
  (`rt_exec_at`, 24 bytes — the execute-twin of peek/poke/set_cr3). Shifted
  `RTLEN` 9688→9712 / `LITERAL_BASE` 4204112→4204136; regenerated the embedded
  `RT` blob, the `build.sh` drift-guard count, and **`native_codegen3_selfhost.bin`**
  to the new self-hosting fixed point.
- **Verified**: `build.sh` Stage 4 fixed point + drift-guard + `kernel.la`
  native==host all green; both kernel gates PASS in QEMU. Committed (`bae00b2`)
  and pushed to `origin/kernel-k1` (rebased cleanly over the remote Pragmatics
  WIP — nothing lost, no force-push).

**Also confirmed**: the `aatc` red on the first full `build.sh` was a *transient*
`tiny_host` GC-nondeterminism flake (passed on re-run and standalone), **not** a
K4c regression.

## Where LogOS stands

**Phase I — Albedo (Lingua Adamica): essentially complete.**
Language core, self-hosting compiler (native x86-64 Stage 0–4, byte-identical
fixed point), the 8 completeness criteria, trimodality (compute/visual/phonetic).
Open: polish only (standard optimizations, GC tuning, stratified fidelity,
fractal monoglyph).

**Phase II — Citrinitas (the OS): kernel is the critical path, ~1/3 in.**

| Area | Status |
|---|---|
| Kernel K1 boot / K2 IDT / K3 PMM / K4a-b paging **translation** / **K4c NX/W^X** | ✅ done |
| Init, IPC, LogosMentor symbolic core | ✅ done (init is a Linux-userspace proto, re-homed at K5/K6) |
| HAL, compositor (Theourgia), audio, input | 🟡 partial (proven as Linux-userspace VM programs) |
| Bootloader | 🟡 GRUB for bring-up (sovereign = K7) |
| Permission/security, UI framework, session mgr, package/update, system services, LogosMentor statistical seam | ⬜ not started |

## What's left (kernel critical path)

- **K4c remainder**: higher-half kernel (needs the LA image relinked off its
  baked-in `0x400000` absolute addresses — non-trivial), and re-homing the LA
  heap onto real PMM frames.
- **K5**: timer IRQ (PIC/PIT) → cooperative → **preemptive scheduler**.
- **K6**: user mode (ring 3) + real syscall service layer; re-home LogosIPC over
  in-kernel channels; native process model.
- **K7**: sovereign bootloader (replaces GRUB).
- Then: the userspace-proven organs (HAL/display/audio/input) re-homed on the
  kernel, real hardware drivers, and OS items 9–13.

Honest read: K1–K4c were largely "follow the written recipe + gate it." K5–K7 and
real drivers are **design problems**, not transcription — the roadmap names them
but doesn't solve them.

## Known issues / friction (worth fixing before more automation)

1. **Slow feedback loop** — each `tiny_host` kernel compile ≈ 20 min; a full
   `build.sh` ≈ 2–4 h (two ~45-min codegen sections). The native self-host image
   is ~5000× faster than `tiny_host`; using it for kernel compiles where possible
   would transform iteration speed.
2. **Flaky `tiny_host` GC** — conservative-collector nondeterminism produced a
   spurious single-glyph type-check failure. A flaky gate blocks unattended runs;
   worth making deterministic.
