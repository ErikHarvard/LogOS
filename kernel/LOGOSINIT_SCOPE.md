# On-metal LogosInit — specification review and scope

**Track D · 2026-09-06 · SPEC ONLY — nothing built, nothing gated yet.**

Erik's standard for this work: *witnessed, not asserted. No item is done until
the code is gated AND the gate can go red.* Spec first, gate design second,
build third. This document is step one and two; it authorises no code.

---

## Part 1 — What the Codex actually specifies

### 1.1 The primary source is missing, and that matters

The white paper in this repo — `codices/published/The Autopoetic Ground of the
Operating System.tex` — is **not** the Codex Autopoieticus. It *cites* it:

> `\bibitem{autopoieticus}` Harvard, E. X. (2026). *Codex Autopoieticus: The
> LogOS Boot Sequence.* — `The Science of Naming.tex:696`

and twice defers the actual specification to it:

> "The full specification is in the *Codex Autopoieticus*; this white paper
> focuses on the architectural foundation." — line 446
>
> "The full specification is given in the *Codex Autopoieticus*." — line 928

**`Codex Autopoieticus` is not in this repository.** I searched all of
`codices/published/` — twenty-two files, none of them it. So the request to
"read the Codex Autopoieticus section on LogosInit" cannot be satisfied as
stated. What follows is what the *white paper* specifies, which is the best
available source and which I have read completely on this point.

★ **This is a finding, not an obstacle.** The document that supposedly holds the
boot-sequence specification is the one document absent from the repo. If it
exists, it should be added; if it does not yet exist, then LogosInit has no
external specification and the scope below IS the spec, which changes its
status from "implementing a spec" to "writing one." Erik should say which.

### 1.2 What the white paper does say about LogosInit — all of it

Three mentions, total. Verbatim:

1. **Line 384** — LogosInit is named among the sovereign replacements shipping
   from initial release: *"Sovereign replacements ship from initial release:
   LogosInit (systemd), LogosIPC (D-Bus), LogosKit (UI), LogosPkg (packages),
   Theourgia (compositor), Ω-Vigilance (logging), AegisNet (networking)."*

2. **Line 633** — the Nigredo roadmap, item 2 of 4:
   *"**LogosInit**: sovereign init daemon replacing systemd, running on the
   inherited Linux kernel."*

3. **Line 917** — Step 2 of the build order:
   *"**Step 2: LogosInit and LogosIPC.** Replace systemd and D-Bus. A minimal
   init daemon and an encrypted, typed IPC bus. These two components alone
   transform a Linux installation into a sovereign substrate."*

That is the entire specification. It gives a **role** (replace systemd), a
**substrate** (the inherited Linux kernel), a **size** (minimal), and a
**phase** (Nigredo, before Albedo/Citrinitas). It gives no interface, no
service model, no supervision semantics, no lifecycle.

### 1.3 The binding constraints come from elsewhere in the same document

LogosInit is thin on its own but is bound by the paper's system-wide criteria,
which are specific and testable:

- **b_τ ≡ f_τ (the Tautology of Tools)** — "every component does exactly what
  it declares, nothing more, nothing less" (line 351). For init: the declared
  service set is the actual service set. No hidden units, no implicit
  dependency activation, no socket-activated surprise. This is the criterion
  systemd most conspicuously fails, and it is the reason to replace it.
- **Auto-repair** — one of the four base properties (line 357, 966). For an
  init daemon, auto-repair *is* the supervision loop: a dead service is
  regenerated. This is the property LogosInit exists to carry.
- **Γ-seal capability delegation** — "Every operation in the system traces its
  authority to the Γ-seal" (glossary). Init is where the root of that
  delegation is held, since it is the first process.
- **Metacursive closure** — Φ(Φ) ≡ Φ. Init supervising init.

### 1.4 The phase reading, and the tension in the assignment

The paper puts LogosInit in **Nigredo**, explicitly *"running on the inherited
Linux kernel"*, and puts **LogosKernel** in Citrinitas (item 10). This repo
inverted that order: the sovereign kernel K1–K7 landed 2026-07-15, well ahead
of the roadmap's phasing. `ROADMAP.md:129` records this deliberately — *"This
IS the Phase-III LogosKernel, begun early — no longer inheriting Linux."*

So the codex's LogosInit — the Linux-hosted one — is **already built and
already gated** (see Part 2). The thing Erik's brief calls "the next layer"
must therefore be the *un*specified one: init on the sovereign kernel. The
codex does not describe it, because in the codex's ordering it does not yet
exist. **Writing that spec is the actual work in front of us**, and it is why
this document exists rather than a build.

---

## Part 2 — What is already built (do not rebuild it)

`logosinit.la` (119 lines) is a genuine Linux PID-1 running on the native SECD
VM, and it is thoroughly gated in `build.sh` (lines 6412–6560):

| Capability | Mechanism | Gate |
|---|---|---|
| Boot setup | `mount("/proc")`, `mount("/sys")` | announce line asserted |
| Signal arming before fork | `sigprocmask` + `signalfd` | round-trip gated |
| Spawn a session | `fork` + `execve("/bin/sh")` | `LOGOS_SHELL_OK` asserted |
| Supervise | `read(sigfd)` → dispatch on `ssi_signo` | stays alive 2 s |
| Reap coalesced deaths | `reapnb` drain loop | `-ECHILD`/pid/`-ECHILD` |
| Respawn throttle | `BACKOFF` sleep | flapping shell bounded in 4 s |
| Clean shutdown | SIGTERM → kill shell → `exit 0` | rc=0 asserted |

`ROADMAP.md:707` marks item 3 `[x]` with the honest qualifier: *"(Linux-userspace
prototype; the native process model is re-homed onto the kernel at K5/K6)"*.

**That qualifier is the gap.** The re-homing never happened.

---

## Part 3 — What the metal gives an init today

### 3.1 Available

**Kernel syscalls** — exactly five (`kernel/boot.asm:1047`):
`write`, `exit`, `send` (0x300), `recv` (0x301), `yield` (0x302).

**LA-visible runtime primitives** (`native_codegen3_rt.asm`):
- `spawn(closure)` — register a task; carves an 8 MiB stack, plants a
  trampoline frame, marks the TCB runnable.
- `yield("!")` — full context switch (rsp + callee-saved), round-robin.
- `send(ch)(msg)` / `recv(ch)` — kernel channel IPC, ring-3 safe.
- `print`, `exit`.

**Proven on metal:** ring-3 LA (K6b), a real syscall layer (K6c), two ring-3
tasks exchanging a typed message (K6c.3b), preemptive tasks at a safe-point
(K5b.2), isolated per-process address spaces (HH2b/HH2c), boot off own disk (K7).

### 3.2 Missing — and this is the whole of it

**An init's defining act is supervision, and supervision needs to observe
death. On the metal, nothing can.**

`spawn` has no completion notification. There is no `wait`, no exit status, no
process query. A task that finishes simply stops being scheduled.

★ **But the death record already exists.** `task_trampoline`
(`native_codegen3_rt.asm:2016`) runs the closure to completion and then:

```asm
    mov     rax, [CUR_TASK]
    mov     qword [rax + TCB_STATE], 2  ; dead
```

The runtime *knows*. It writes it down. LA cannot see it.

★ **And the slot is never reclaimed.** `rt_spawn`'s `.findfree` scans for
`TCB_STATE == 0`; dead is `2`; nothing ever writes `0` back. With
`MAXTASK = 8` (line 63), **a supervisor can respawn at most ~7 times, ever,
before `spawn` halts the machine with "too many tasks (MAXTASK)".** That is a
hard resource leak that an init — the one program designed to run forever and
restart things — is precisely the program to hit.

So one primitive closes both: an LA-visible **`reap`** that finds a dead TCB,
returns its index, and frees the slot.

#### ★ The leak is WITNESSED, not asserted (2026-09-06)

`kernel/respawn_probe.la` — a supervisor that spawns a service, yields so it
runs to completion (dies), and repeats, twelve times. Compiled by
`native_codegen3` and run Linux-hosted:

```
spawn0 svc0  spawn1 svc1  spawn2 svc2  spawn3 svc3
spawn4 svc4  spawn5 svc5  spawn6 svc6
spawn7
native: spawn: too many tasks (MAXTASK)
rc=1
```

**Seven restarts, then the machine halts.** Every service had already exited;
its slot was simply never reclaimed. An init daemon — the one program whose
entire purpose is to run forever and restart things — cannot restart anything
an eighth time. This is the defect D-INIT.1 exists to close, and this probe is
its red control: it must keep this exact behaviour on HEAD, and must run to
`ALL-12-SPAWNED` after.

### 3.3 Two hazards that must be designed for, not discovered

**(a) Reaping the stack out from under the dying task.** `task_trampoline`
sets `STATE=2` and *then* calls `rt_yield` — it is still executing on its own
stack while marked dead. K5b.2 preemption can land in that window. If another
task reaps and respawns into that index, the new task's stack is carved at the
same address and the dying task is standing on it. **Recommended design:** the
trampoline marks `STATE=3` ("dying"); `rt_yield`, *after* it has switched off
that stack, converts `3 → 2`. Then `STATE==2` provably means "off its stack."
This must be verified on the metal, not assumed.

**(b) The RT_* constant shift.** Adding to `native_codegen3_rt.asm` moves every
`RT_*` address constant, and `native_codegen3.la` hardcodes them. K6b already
paid this: rt_init grew 9 bytes, every `RT_*` shifted +9, `LITERAL_BASE` +17,
and the Stage-4 self-host fixed point had to be re-verified byte-identical
(`ROADMAP.md`, K6b note). **Mitigation:** append at EOF (the K5b.1a and K6c.3
precedent — "appended → only LITERAL_BASE shifted"), and re-verify the
self-host fixed point as an explicit gate step, not a hope.

### 3.4 Scope boundary — tasks, not isolated processes

The metal's `spawn` creates **green-thread tasks in one address space**.
HH2b/HH2c demonstrated *isolated ring-3 processes*, but as hardcoded two-stage
demos in `boot.asm` — not a process model an LA program can drive.

**Minimal on-metal LogosInit supervises TASKS, not isolated PROCESSES.** A
faulting task still halts the whole machine via K2's diagnosed serial halt, so
init cannot yet survive a service's crash — only its *voluntary* exit.
Supervising isolated, fault-contained processes needs a kernel process table
and LA-driven CR3 switching; that is a separate and much larger brick.

**This limitation must be stated in the module header and in the gate name.**
Calling it "supervision" without that qualifier would itself be a b_τ ≢ f_τ
violation — the exact failure the project exists to refuse.

---

## Part 4 — Proposed scope: five bricks

Staged smallest-first, each independently gateable, each red-able. Nothing
starts until Erik approves the shape.

### D-INIT.1 — `reap`: make task death visible to LA
Append `rt_reap` at EOF of `native_codegen3_rt.asm`; wire `reap` as a builtin
in `native_codegen3.la`. Non-blocking, mirroring the VM's `reapnb` convention:
returns a dead task's index, `"0"` when tasks live but none are dead, `"-1"`
when none remain. Frees the TCB slot (fixing the MAXTASK leak). Includes the
3.3(a) dying/dead split.
*Substrate:* pure runtime — **gateable Linux-hosted, no QEMU**, like
`task_pingpong.la`.

### D-INIT.2 — `initmetal.la`: the supervision loop
An LA init: spawn a declared service set, then loop `reap` → identify → decide.
Terminates when the declared set is complete. Structurally the sibling of
`logosinit.la`'s `DRAIN`/`SUPERVISE`, with `reap` where `reapnb` was and the
task table where the process table was.

### D-INIT.3 — respawn with a bounded restart policy
A service that exits is restarted; a service that keeps exiting is given up on
after a declared cap. The cap is *declared and enforced* — b_τ ≡ f_τ for the
restart policy itself.

### D-INIT.4 — the metal gate
D-INIT.2/3 running at ring 3 on the sovereign kernel under QEMU, transcript on
serial, `isa-debug-exit` 33. Follows `gate_k6c3b.sh`'s shape.

### D-INIT.5 — clean shutdown
Init stops its services and exits; the machine halts. On metal `exit` already
halts, so this is mostly assertion of ordering — but the ordering is the point.

**Deferred, explicitly:** fault-isolated services (needs per-task fault
attribution in K2's IDT); isolated-process supervision (needs a kernel process
table); Γ-seal capability delegation from init; service dependency ordering;
socket activation (arguably should *never* be built — it is a systemd
misfeature, and b_τ ≡ f_τ counts against it).

---

## Part 5 — Gate design (the "can go red" requirement)

Erik's standard is that a green gate proves nothing unless the same gate is
shown to go red. Each brick therefore ships **a negative control**: a
deliberate break that the gate must catch. A gate whose red has not been
witnessed is not a gate.

| Brick | Green witness | **Red control — must FAIL** |
|---|---|---|
| D-INIT.1 | spawn 2 tasks, one exits: `reap` → its index; again → `"0"` (one live); after all exit → `"-1"` | (a) stub `rt_reap` to always return `"-1"` ⇒ the "reaped its index" assertion must fail. (b) reap a **still-running** task's index ⇒ must NOT be reported dead. |
| D-INIT.1-leak | respawn **> MAXTASK (8)** times total and keep running | run the same program on **HEAD** (no `reap`) ⇒ must halt with `native: spawn: too many tasks` — this is the witness that the leak was real |
| D-INIT.1-drift | Stage-4 self-host fixed point byte-identical after the RT_* shift; `kernel.la` native==host | any `RT_*` left stale ⇒ build.sh drift guard red (the K6b failure mode, reproduced deliberately) |
| D-INIT.2 | 3 services drained in a deterministic transcript order | stub `reap` → `"-1"` ⇒ loop exits early, transcript short ⇒ FAIL |
| D-INIT.3 | flapping service restarted exactly N times, then given up, transcript exact | remove the cap ⇒ restart count ≠ N ⇒ FAIL (proves the cap is enforced, not decorative) |
| D-INIT.4 | serial transcript + QEMU exit 33 | inject a service that never exits ⇒ init must not report completion ⇒ no exit 33 |
| D-INIT.5 | shutdown line precedes halt; ordering asserted | reorder ⇒ FAIL |

Additional standing requirements, per this repo's discipline:
- Every other kernel ELF stays **byte-identical** (`%ifdef` isolation, the
  K5b/K6/HH precedent).
- All existing K1–K7 / HAL gates still PASS.
- The negative-control runs are **recorded in the commit message**, so the red
  is part of the record and not just a claim.

---

## Part 6 — Open questions for Erik (blocking the build, not the spec)

1. **Is `Codex Autopoieticus` a real document?** If it exists, it should be in
   `codices/` — it is the cited source for exactly this work. If it does not,
   then Part 4 above is the spec and should be marked as such.
2. **Tasks or processes?** §3.4 scopes this to green-thread tasks in one
   address space. Fault-isolated process supervision is the "real" init but is
   a much larger brick (kernel process table + LA-driven CR3). Confirm the
   smaller one is what "minimal" means here.
3. **Does the Linux `logosinit.la` stay?** The codex places it in Nigredo, and
   Nigredo scaffolding is meant to be burned at Rubedo. It is currently gated
   and green. Recommend: keep it, gate both, since it is the codex-specified
   artifact and the metal one is not yet specified anywhere.
4. **HAL.4e** — `CLAUDE.md` names it as Track D's work in flight. This brief
   redirects to LogosInit. Confirm HAL.4e is paused, not abandoned.
