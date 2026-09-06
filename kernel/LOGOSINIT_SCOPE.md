# On-metal LogosInit — specification review and scope

> ## ★ ERIK'S RULING — 2026-09-06
>
> **LogosInit supervises FAULT-ISOLATED PROCESSES, not green-thread tasks.**
>
> This answers Part 6 Q2 and **overturns §3.4**, which scoped this work to tasks
> in one address space. What §3.4 named as out of scope — *"a kernel process
> table and LA-driven CR3 switching… a separate and much larger brick"* — **is
> the brick.** Part 4 is re-scoped accordingly.
>
> **Q1 is also answered: `Codex Autopoieticus` EXISTS**, and is now in the repo
> at `CODEX_AUTOPOIETICUS.tex` on `kernel-k1` (`e13c00c`). It was in
> `~/Downloads/CODICIES/`, outside the repo — which is why §1.1 could not find
> it. §1.1's *conclusion* was wrong; its *method* was not, and it is kept below
> with a correction rather than rewritten, because "the cited source is absent
> from the repo" was a true and useful statement about the repo at the time.
>
> **The codex is far more specific than the white paper, and it decides this.**
> Q3 and Q4 remain open and are still Erik's.

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
stated.

> **★ CORRECTED 2026-09-06 (Erik).** It exists. It lived in
> `~/Downloads/CODICIES/`, outside the repository, and is now committed at
> `CODEX_AUTOPOIETICUS.tex` on `kernel-k1` (`e13c00c`). The search above was
> exhaustive **over the repo**, and that is exactly its limit: a document can be
> absent from `codices/` and still exist. The paragraph is kept rather than
> rewritten because "the cited primary source is not in the tree" was true, was
> worth reporting, and is what got the codex committed. What follows in §1.2–1.4
> is the **white paper's** account, which was the best available source at the
> time; **§1.5 supersedes it** with the codex's own, which is more specific and
> which the ruling rests on. What follows is what the *white paper* specifies, which is the best
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

### 1.5 What the CODEX specifies — and it decides the process question

`CODEX_AUTOPOIETICUS.tex` names LogosInit **thirteen times**. Unlike the white
paper's three sentences, it specifies behaviour. Verbatim, with line numbers:

- **:18405** — *"LogosInit initialises itself (it is the first process, started
  by the kernel, and it manages **all subsequent processes** including its own
  child monitoring)."* → init is **PID 1**, started by the kernel, and the
  kernel starts **only** it; every other process is init's child.
- **:25856** — *"If an organ crashes, LogosInit restarts it. The organ restores
  state from AletheiaFS… **Other organs are unaffected (message-passing
  isolation). The crash of LogosForge does not affect LogosWrite.**"*
- **:25861** — *"LogosInit implements **supervision trees (like Erlang/OTP)**:
  crashed processes are restarted, with **exponential backoff to prevent restart
  storms**… **Process isolation (separate address spaces) prevents crash
  propagation.**"*
- **:25618** — the boot steps in order: mount `/proc`,`/sys`,`/dev`,`/run`; load
  the QRNG module; init the Autoclave; start the φ-daemon; start Theourgia;
  start the LogosIPC bus; start Ω-Vigilance; present the Γ-seal challenge.
  *"**Each step is a function call, not a service file. Dependencies are
  compile-time, not runtime. Failure at any step halts boot with a diagnostic
  message.**"*
- **:18250** — *"a minimal, sovereign init daemon that starts services and
  manages the boot-to-session transition"*; systemd's other functions go to
  other organs (logging → Ω-Vigilance, DNS/network → AegisNet, time → LogosTime).
  **This bounds the work: LogosInit is init, and nothing else.**
- **:22868** — init reads a new φ and updates the Algorithm Registry (crypto
  hot-swap), so init also owns φ-configuration reload.

**Why this settles §3.4.** "Process isolation (separate address spaces)
prevents crash propagation" and "other organs are unaffected" are not
satisfiable by green threads. Tasks in one address space share a fault: on this
kernel a faulting task takes the whole machine down through K2's diagnosed halt,
which is the exact opposite of the requirement. The codex also rules out reading
"crash" loosely — it says *crash*, contrasted with a clean exit, and the
supervision tree must tell them apart to apply backoff. **Erik's ruling follows
the text; §3.4 did not.**

**What §3.4 got right, and why it is kept.** Its account of what the metal can
do *today* is accurate and unchanged: `spawn`/`yield` are green threads, K2
halts on fault, and HH2b/HH2c's isolated processes are hardcoded `boot.asm`
demos rather than a model LA can drive. That is still the honest starting
position — it is now a **gap list** instead of a scope boundary.

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

### 3.4 ~~Scope boundary — tasks, not isolated processes~~ — **SUPERSEDED 2026-09-06**

> **★ OVERTURNED BY ERIK'S RULING (2026-09-06).** LogosInit supervises
> **fault-isolated processes**. What this section calls "a separate and much
> larger brick" **is the brick** — see §1.5 for the codex text and Part 4 for
> the re-scoped list. The section is kept, not deleted, because its description
> of *what the metal can do today* remains accurate and is now the gap list the
> new bricks close. Read it as diagnosis, not as scope.

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

## Part 4 — RE-SCOPED 2026-09-06: the process-model bricks

The five D-INIT bricks below the fold were scoped to green-thread tasks and are
**superseded** by Erik's ruling. They are kept after the new list because
D-INIT.1 is built and its findings (the identity invariant especially) carry
over — a *process* table will need the same identity discipline a task table did.

**Foundation that already exists — do not rebuild it.** The isolation mechanism
is proven; what is missing is that LA cannot drive it.

| Have | What it proved |
|---|---|
| HH1 | kernel wholly in the −2 GiB half; the low canonical half is free per-process |
| HH2 | per-process PML4s; CR3 round-trip isolation (A's write invisible to B) |
| HH2b | **one ring-3 LA process in its own address space**, syscalling to the high kernel |
| HH2c | **two isolated LA processes** exchanging a typed message via a kernel channel |
| K2 | IDT + 32 exception handlers — a fault **is** diagnosed, just fatally |
| K6c | ring-3 syscall layer (`write`/`exit`/`send`/`recv`/`yield`) |
| K5b.2 | preemption via a safe-point yield flag |

**The gap in one sentence:** HH2b/HH2c are *hardcoded `boot.asm` demos* — two
processes, a stage byte, an `iretq` written into the boot path — and K2 answers
every fault by stopping the machine. Nothing here is a model LA can drive, and
nothing survives a crash.

### P1 — the kernel process table
Replace HH2c's two-process/one-stage-byte demo with a real PCB array the kernel
owns: pid, CR3 (its PML4 phys), state (free/runnable/blocked/dead), entry, exit
status, **and fault cause**. A scheduler over it replaces `.sys_exit`'s hardcoded
CR3 switch. *Gate:* three processes round-robin and each reports its **own** pid.

### P2 — fault attribution and containment ★ THE KEYSTONE
K2's 32 handlers diagnose and **halt**. They must instead: identify the current
pid, record vector + error code + CR2 in its PCB, mark it **dead-by-fault**, tear
its mapping down, and **return to the scheduler**. The machine survives; the
process does not. Everything else in the ruling depends on this brick.

### P3 — LA-driven process creation (`pspawn`)
Today entry into a process is an `iretq` hardcoded in `boot.asm`. Init must
create children itself: a syscall that allocates a pid, builds a per-process
PML4 from a pristine image, maps it `U=1`, shares the kernel `[511]` as
supervisor, and enqueues it runnable. **The largest brick** — HH2b did all of
this once, by hand, at boot.

### P4 — process death visible to init (`pwait`)
The process-level analogue of D-INIT.1's `reap`, and it must return **more**:
`(pid, cause)`, where cause distinguishes a **clean exit** from a **fault** (and
which fault). The codex requires the distinction — a supervision tree applies
backoff to crashes, not to a service that finished its work.

### P5 — init as PID 1, in LA
Codex :18405. The kernel starts **exactly one** process — init — and init spawns
every other. This replaces `logosinit.la`'s Linux `fork`+`execve` shape with
`pspawn`, and makes init itself an ordinary ring-3 LA process.

### P6 — the supervision tree, with exponential backoff
Codex :25861, which names both. A **tree**, not a flat set: each child's death is
reported to its supervisor, restart policy lives per node, and backoff prevents
restart storms. Note what "restart" means after a fault: the address space is
corrupt, so restart = tear down the PML4 and rebuild from the pristine image
under a **new pid** — not resume.

### P7 — the declared boot sequence
Codex :25618: *"Each step is a function call, not a service file. Dependencies
are compile-time, not runtime. Failure at any step halts boot with a diagnostic
message."* Directly gateable: the declared ordered list **is** the boot, and a
failing step halts loudly rather than degrading silently. This is `b_τ ≡ f_τ`
for the boot itself, and it is the specific thing systemd fails.

**Still deferred, and now explicitly:** AletheiaFS state restore (codex has
organs resume from durable state — needs a filesystem), Γ-seal capability
delegation from init, zram snapshots, the φ-daemon and Algorithm Registry
reload, and the Attention-Graph DAG over 90+ organs.

---

<details>
<summary><b>SUPERSEDED — the original five task-level bricks (2026-09-06, pre-ruling)</b></summary>

Kept because D-INIT.1 is built, gated and witnessed, and its findings carry over.


Staged smallest-first, each independently gateable, each red-able. Nothing
starts until Erik approves the shape.

### D-INIT.1 — `reap`: make task death visible to LA — **BUILT + GATED, RUNTIME HALF PARKED**
Append `rt_reap` at EOF of `native_codegen3_rt.asm`; wire `reap` as a builtin
in `native_codegen3.la`. Non-blocking, mirroring the VM's `reapnb` convention:
returns a dead task's index, `"0"` when tasks live but none are dead, `"-1"`
when none remain. Frees the TCB slot (fixing the MAXTASK leak). Includes the
3.3(a) dying/dead split.
*Substrate:* pure runtime — **gateable Linux-hosted, no QEMU**, like
`task_pingpong.la`.

★ **The runtime half is PARKED, not pending.** `rt_reap` lives in
`native_codegen3_rt.asm` and its wiring in `native_codegen3.la` — both **track
A's** files per `~/logos-tracks.conf` (`native_codegen*.la|.asm|.bin`).
`logos-guard` refuses a track-D commit that touches them, and that refusal is
correct: matching another track's *explicit* pattern is a hard block, unlike the
catch-all `*` that merely warns on unowned files. So what is committed here is
the **kernel/-side half** — the probes, the gate, and this scope. The runtime
half is complete, gated and witnessed, and is saved outside every worktree:

```
git apply ~/logos-dinit1-runtime.patch     # rt_reap + RT_REAP + the regenerated
                                           # selfhost.bin fixed point (954094 B)
~/logos-dinit1-rt.asm.copy                 # the runtime alone, for reference
```

`kernel/build_dinit1.sh` detects its absence and SKIPs with that instruction
rather than emitting probes that cannot resolve `reap`. `gate_dinit1.sh` is
deliberately **not wired into `build.sh`**, so the shared build cannot go red on
a prerequisite that has not landed. Wiring it is one line, recorded in the
cross-track request. One more line is needed too, and could not be committed for
the same reason: `"RT_REAP": "rt_reap"` in `scratchpad/derive_consts.py`'s
`LABELS` (also track A's), without which `build.sh`'s `rtconsts` gate derives no
row for this constant and validates it against nothing — so the gate derives the
address itself and only treats `derive_consts` as a bonus.

**Built as scoped, with one design change made during the build.** §3.3(a)
proposed a dying(3)/dead(2) split converted by `rt_yield` after the stack
switch. The simpler guard is **`reap` skips `CUR_TASK`**: `rt_spawn` re-carves a
task's stack from its *index*, and the only `STATE==2` TCB that can still be
executing is the current one, so skipping it makes "reaped" imply "provably off
its stack." Same invariant, one compare, and neither the trampoline nor the
scheduler changes — so no existing path could regress. Preferred on that ground.

**Return shape** (boxed INT, not the VM's decimal strings — this engine has
native ints): `>= 1` the reaped index · `0` others live, none dead · `-1` no
other task at all. Mirrors `reapnb`'s `-ECHILD`/`"0"`/pid so the supervision
loop reads the same on both substrates.

**Witnessed** (`kernel/gate_dinit1.sh`, Linux-hosted, no QEMU):

| | result |
|---|---|
| semantics | `r0=-1  r1=0  svc-ran  r2=1  r3=-1` — exact |
| reclamation | 12 cycles > MAXTASK=8, `ALL-12-SPAWNED`, **`reaped=1` every cycle** (one slot reused, not leaked) |
| **red control** | identical loop minus `reap` **still halts at 7** with `too many tasks (MAXTASK)`, rc=1 |
| constant drift | only `RT_REAP`/`RTLEN`/`LITERAL_BASE` moved; all other `RT_*` revalidated |

The red control is the point: same runtime, same compiler, same loop, one
variable. It proves `reap` is what fixed the ceiling and not an incidental
change to `spawn`. The gate **runs the failing case and requires it to fail**,
and says so in its own failure text — if the control ever passes, the gate
demands rewriting rather than deletion.

The append invariant held exactly as §3.3(b) hoped: `RT_REAP` landed at the old
`LITERAL_BASE` (4206702), `RTLEN` 12278 → 12373, and **every other `RT_*` address
is unchanged** — so the K6b shift, which once broke the self-host fixed point,
did not recur.

### D-INIT.2 — `initmetal.la`: the supervision loop — **SUPERSEDED BY THE RULING**

> `kernel/initmetal.la` supervises **tasks**, so the ruling supersedes it as a
> design. It is committed unexecuted and says so in its own header; it is left
> in place because the **identity invariant** below survives the change of
> substrate — a process table will need the same discipline, and `pspawn`
> returning its pid is the process-level form of the `rt_spawn` recommendation.
An LA init: spawn a declared service set, then loop `reap` → identify → decide.
Terminates when the declared set is complete. Structurally the sibling of
`logosinit.la`'s `DRAIN`/`SUPERVISE`, with `reap` where `reapnb` was and the
task table where the process table was.

★ **A design problem the scope did not anticipate: `spawn` returns nothing, so
nothing tells LA which slot a service got.** `reap` hands back a TCB *index*;
without a mapping, a supervisor knows something died but not *what*. The mapping
is recoverable, but only because two allocation policies happen to compose:

- `rt_reap` returns the **lowest dead** index (it scans upward from 0);
- `rt_spawn` takes the **lowest free** index (`.findfree` scans upward from 0);
- a dead-but-unreaped slot is `STATE=2`, which is **not free**.

So reaping index *k* frees *k*, every slot below *k* is then alive or
dead-unreaped, and *k* is the lowest free slot — the very next `spawn` lands
there. Hence the discipline the loop is built on:

> **Reap one, respawn one, in that order, with nothing in between.**

Reap twice before respawning and it breaks: the second reap frees a lower slot
and the respawn lands there instead, silently rebinding one service's name to
another's task. The gate must therefore assert *identity*, not just liveness —
each restarted service printing its **own** name, so a scrambled mapping shows
up as the wrong name rather than as a still-green "something restarted".

**Recommended for track A (who owns the runtime), not required:** have
`rt_spawn` return its index. That makes the mapping explicit instead of derived
from two coupled policies a future scheduler change could silently decouple —
and a scheduler that allocated, say, round-robin rather than lowest-free would
break this invariant with no test failing anywhere else. `spawn`'s return value
is documented as ignored and every existing caller (`task_pingpong.la`,
`ipc2.la`) discards it through `SEQ`, so the change is small. Until then the
invariant is load-bearing and the gate asserts it.

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

</details>

## Part 5 — Gate design (the "can go red" requirement)

### 5.0 ★ THE FAULT GATE — what can go RED on a process that faults

The keystone gate (P2). One QEMU boot, one deliberately faulting service.

**Scenario.** Init (PID 1) spawns three services — `alpha`, `beta`, `gamma`.
`beta` faults on purpose: a write to a supervisor-only page (`#PF`, vector 0e),
with `ud2` (`#UD`, 06) as the second shape so the gate is not tuned to one
vector. `alpha` holds a canary in **its own** address space.

**Green — six assertions, all on the serial transcript plus `isa-debug-exit`:**

1. **The fault is diagnosed WITH its process.** `FAULT pid=2 vec=0e` — not just
   K2's existing "EXCEPTION 0e". Attribution is the new information.
2. **The machine does not halt.** This is the whole ruling in one line.
3. **The siblings finish.** `alpha` and `gamma` run to completion and say so —
   codex :25856, *"other organs are unaffected"*.
4. **`alpha`'s canary is intact** after `beta` faults — isolation, not just
   survival.
5. **`beta` is restarted under a NEW pid** (its address space was torn down and
   rebuilt from the pristine image — a restart, not a resume).
6. **Bounded, then quiescent:** after the declared restart budget init reports
   and exits 33.

**Red controls — each must FAIL, and each catches a different lie:**

| # | Control | What passes without it |
|---|---|---|
| **R1** | **Today's kernel IS the red.** The same faulting image on HEAD's K2 halts the machine and never reaches exit 33. | Nothing — this is the pre-existing behaviour, so the red is free and already witnessed by every K2 fault gate. It is the exact shape of D-INIT.1's no-reap loop halting at 7. |
| **R2** | **Attribution.** Make `gamma` fault instead of `beta`; the reported pid must change. | A handler that hardcodes a pid, or misreads "current", passes assertion 1 and fails only here. |
| **R3** | **Containment vs MASKING.** `beta`'s post-fault instruction would print `beta-continued`; assert it **never appears**. | A handler that "contains" by mapping the faulting page and resuming looks identical on assertions 1–4. This is the `b_τ ≡ f_τ` check on the word *isolated*: the process must **die**, not be papered over. |
| **R4** | **Isolation has power.** Re-run with `alpha` and `beta` mapped into ONE address space; `beta`'s wild write must reach `alpha`'s canary and corrupt it. | Assertion 4 is vacuous if nothing could ever have corrupted the canary — this proves the test can fail. |
| **R5** | **Restart storm.** A service that faults instantly, every time, must be backed off and eventually given up on. Remove the backoff → the restart count in a fixed window differs. | A supervisor that restarts in a tight loop satisfies "it restarts it" while violating codex :25861. |

**R3 and R4 are the two that matter most**, and neither is obvious: R3 separates
containment from masking, and R4 stops the isolation assertion from being
vacuous. R1 costs nothing because the current kernel already produces it.

**Honest note on cost.** This gate needs P1–P4 before it can run at all; it is
the *acceptance test* for the keystone, not an early check. P1 and P2 each want
their own smaller gate first (pid round-robin; a single faulting process that
the kernel survives with no init involved), on the K-series discipline of
verifying each brick green before the next.

### 5.0.1 P1's gate — why the number is THREE

`kernel/gate_p1.sh` + `kernel/build_p1.sh` are **written** (2026-09-06); the
`boot.asm` half is not, so the gate does not yet run.

**The design turns on one number.** HH2c already boots *two* isolated LA
processes and passes its gate — but it does so with a hardcoded `hh2c_stage`
byte: the first `.sys_exit` switches CR3 to B, the second halts. That is not a
process table, it is an if-statement, and **a two-process gate cannot tell the
difference.** A third process is the discriminator: nothing hardcoded for two
produces a third without a real PCB array and a real scheduler loop.

So the gate asserts **three** distinct pids, and that is the entire reason for
the number. Each process reads the **same virtual address** and must get its
**own** value (`pid=1 val=A1`, `pid=2 val=B2`, `pid=3 val=C3`) — HH2's isolation
proof, now driven from the table's CR3 rather than a hand-written round-trip.

**The red control, without which assertion 3 is vacuous:** `build_p1.sh
--shared` points all three PCBs at **one** PML4. The three then share an address
space and read the same value, and `gate_p1.sh --red` **requires** that to fail.
If it passes, no arrangement of memory could ever have failed the isolation
assertion, and the gate says so in its own output and demands rewriting rather
than deletion.

**Sequencing hazard, recorded because it nearly bit:** `build_p1.sh` writes
`kernel/entry.inc`, which `build.sh` and `build_hal4g.sh` also write, and
`boot.asm` is read by every kernel build. Editing `boot.asm` or running
`build_p1.sh` while another kernel build is in flight silently contaminates that
build's ELF — it is not a conflict git can see, because these artifacts are
gitignored. Run kernel builds **sequentially**.

---

### 5.1 The task-level gate table (D-INIT.1, built)

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

1. ~~**Is `Codex Autopoieticus` a real document?**~~ **ANSWERED 2026-09-06 — it
   exists.** Now committed at `CODEX_AUTOPOIETICUS.tex` on `kernel-k1`
   (`e13c00c`); it was in `~/Downloads/CODICIES/`, outside the repo. See §1.5:
   it names LogosInit thirteen times and is far more specific than the white
   paper. **It, not the white paper, is the spec.**
2. ~~**Tasks or processes?**~~ **ANSWERED 2026-09-06 — PROCESSES**, fault-isolated,
   separate address spaces. §3.4 superseded; Part 4 re-scoped to P1–P7.
3. **Does the Linux `logosinit.la` stay?** The codex places it in Nigredo, and
   Nigredo scaffolding is meant to be burned at Rubedo. It is currently gated
   and green. Recommend: keep it, gate both, since it is the codex-specified
   artifact and the metal one is not yet specified anywhere.
4. **HAL.4e** — `CLAUDE.md` names it as Track D's work in flight. This brief
   redirects to LogosInit. Confirm HAL.4e is paused, not abandoned.
