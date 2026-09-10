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

### P1 — the kernel process table — **BUILT + GATED, RED WITNESSED (2026-09-08)**
Replace HH2c's two-process/one-stage-byte demo with a real PCB array the kernel
owns: pid, CR3 (its PML4 phys), state (free/runnable/blocked/dead), entry, exit
status, **and fault cause**. A scheduler over it replaces `.sys_exit`'s hardcoded
CR3 switch. *Gate:* three processes round-robin and each reports its **own** pid.

**Built 2026-09-08.** `kernel/boot.asm` `%ifdef P1`, gated by `kernel/gate_p1.sh`,
wired into `build.sh` together with its red control. The transcript:

```
P1 pid=1 val=A1
P1 pid=2 val=B2
P1 pid=3 val=C3
P1 table drained: every process exited, kernel alive
```

- **PCB, 64 bytes:** `+0 pid  +8 cr3  +16 state  +24 entry  +32 stack  +40 exit
  +48 fault`. The fault field is written `-1` and stays unread until P2 — it exists
  now so the table's shape does not change under the keystone.
- **Three address spaces.** Each process gets its own PML4 mapping ONE 2 MiB page at
  the SAME virtual address (`P1_UVA`) onto a DIFFERENT frame, sharing the kernel via
  `[511]` as supervisor. Every other PD entry is **not present**: a P1 process can
  address its own page and nothing else.
- **Identity comes from the table, not the image.** All three processes run the same
  copied bytes; each learns its pid from a new `getpid` syscall reading
  `PCB[p1_cur].pid`. A correct pid can therefore only have come from the table —
  which is also the "who is current" that P2's fault handler needs.
- **`.sys_exit` no longer ends the machine.** It records the status in the dying
  process's PCB, marks it dead, moves to the **high kernel stack** (never a process's
  own memory, which a faulting process could have corrupted), and returns to the
  scheduler. P2 reaches this same path from a fault handler, with a cause.
- **Nothing in the scheduler knows how many processes exist** — it walks the table,
  so a third costs exactly what the second costs. That is the property the
  `hh2c_stage` byte does not have.

### P2 — fault attribution and containment ★ THE KEYSTONE — **BUILT + GATED, 5 REDS WITNESSED (2026-09-08)**
K2's 32 handlers diagnose and **halt**. They must instead: identify the current
pid, record vector + error code + CR2 in its PCB, mark it **dead-by-fault**, tear
its mapping down, and **return to the scheduler**. The machine survives; the
process does not. Everything else in the ruling depends on this brick.

#### ★ MEASURED starting state (2026-09-08) — worse than §5.0's R1 assumed

Before designing the gate I measured what a fault in a P1 process actually does
today, rather than inheriting §5.0's assumption. Two runs, one variable:

| what executes `ud2` | serial output | rc |
|---|---|---|
| a **ring-3 P1 process** | **nothing at all** | **124 (timeout — the machine wedged)** |
| the same `ud2` on the **kernel's own CR3** | `EXCEPTION 06 err=0000000000000000 rip=ffffffff8010035c` | 35 |

The only variable is the address space. So **K2's loud-failure guarantee does not
extend into a process address space** — it stops being loud at exactly the point
P2 needs it, and produces *no diagnostic and no exit code*.

**Mechanism** (read from `kernel/idt.asm` + the P1 symbol map; the two rows above
are measured, the causal chain below is inferred and not separately instrumented).
A P1 process's PML4 maps only `pd_i[128]` — VA `0x10000000..0x101fffff` — plus the
kernel high half at `[511]`. Every address the fault path needs is **below 2 MiB,
in PD[0], which is not present** under a process CR3:

| dependency | address | why it is low |
|---|---|---|
| `idt` (the table itself) | `0x116150` | `idt_ptr`'s base is the **low** BSS address; the IDTR still points there after the CR3 switch |
| `isr0` / `isr6` / `isr14` | `0x10054b` / `0x100581` / `0x1005aa` | `isr_table` holds **low absolute** handler addresses, so every gate offset is low |
| `exc_msg` | `0x100782` | `isr_common` does `mov rsi, exc_msg` — a **low absolute** string reference |

(`serial_puts` / `print_hex64` are reached by `call`, which is rel32 and therefore
position-independent — those are fine.) The CPU faults reading the IDT descriptor,
that fault cannot be delivered either, → double fault → triple fault → CPU stops.
`-no-reboot` leaves QEMU alive, so a gate sees a **timeout, not an exit code**.

**BUILT.** `kernel/build_p2.sh` + `kernel/gate_p2.sh`, wired into `build.sh` with
all five red controls. Erik ruled restart to P6 (2026-09-08), so this gate stops at
attribution + containment + survival. Green transcript:

```
P1 pid=1 val=A1
FAULT pid=02 vec=06 err=0000000000000000 cr2=0000000000000000
P1 pid=3 val=C3
P1 pcb pid=01 state=03 fault=ff
P1 pcb pid=02 state=04 fault=06
P1 pcb pid=03 state=03 fault=ff
P1 table drained: every process exited, kernel alive
```
exit 33.

- **Ring-0 faults stay FATAL.** `isr_common` branches on the saved CS's CPL; only a
  ring-3 fault reaches `p2_fault`. Containment is for processes — a kernel bug that
  "recovered" is precisely the masking R3 forbids.
- **The ordering is an assertion, not a coincidence.** `P1 pid=3` must appear *after*
  the `FAULT` line: presence alone would not prove the scheduler was re-entered
  **from the handler**.
- **Announcing is not recording.** The PCB dump (`state=04 fault=06`) is asserted
  separately, because a handler can print a perfect diagnosis and store nothing while
  every transcript assertion still passes. P4 (`pwait`) reads those fields.

| red | result |
|---|---|
| `--red` R1' | `DIAGNOSED-BUT-HALTED (exit 35, 'EXCEPTION 06', siblings never ran)` |
| `--r2` attribution | pid follows the faulter: `FAULT pid=03`, `02` absent |
| `--r3` ★ masking | the compiled-in map-and-resume DOES emit `RESUMED` |
| `--r4` isolation | one shared PML4 → process 3 no longer reads `C3` |
| `--r5` vector fidelity | `vec=0e`, err non-zero, `cr2=0000000020000000` |

**★ R1' MOVED BECAUSE P2.0 LANDED, and that is the argument for separable bricks.**
Before P2.0 this control was a silent wedge (rc 124, no output); now it is
diagnosed-but-halted (rc 35). Two of §5.0.3's three predicted shapes have been
observed, in the order the spec said. A baseline that *improves* because a
prerequisite landed is worth more than one that was always going to be a timeout.

#### P2.0 — the prerequisite brick — **BUILT + GATED, RED WITNESSED (2026-09-08)**

P2's handler cannot run at all until the fault path exists in every address space.
This is a separate, separately-gateable step *before* any attribution logic:

1. IDTR base → the **high** alias of `idt`;
2. `isr_table` entries → **high** handler addresses, so the gate offsets are high;
3. `isr_common` → position-independent (`lea rsi, [rel exc_msg]`).

**P2.0's micro-gate is exact and cheap:** the same `ud2`-in-a-process probe that
today produces *nothing and rc 124* must instead produce K2's **existing**
`EXCEPTION 06` line and **exit 35**. P2.0 alone restores LOUDNESS without adding
attribution or containment — it converts the measured wedge into the diagnosed
halt that §5.0's R1 wrongly assumed already existed. Only then does P2 proper
(attribution + containment + return-to-scheduler) have anything to stand on.

**BUILT.** `kernel/build_p2_0.sh` + `kernel/gate_p2_0.sh`, wired into `build.sh`
with its red control. Green transcript — the whole of it:

```
EXCEPTION 06 err=0000000000000000 rip=0000000010000000
```
exit 35.

**`rip=0000000010000000` is the assertion that does the work.** It is `P1_UVA`,
the process's own entry VA, so the fault was taken *at ring 3 inside the process*.
A fault on the kernel's own CR3 reports `rip=ffffffff8.......` and would satisfy
every other assertion in the gate — so without this one, a build that faulted
before the CR3 switch would pass.

**All three relocations are independently load-bearing** — each was reverted alone
and the gate went red at rc 124 (wedged) every time:

| break | result |
|---|---|
| IDTR base left LOW | `FAIL … no 'EXCEPTION 06' …` rc 124 |
| gate OFFSETS left LOW | `FAIL … no 'EXCEPTION 06' …` rc 124 |
| `isr_common` strings left ABSOLUTE | `FAIL … no 'EXCEPTION 06' …` rc 124 |

The third is worth a note: with the IDT reachable, the CPU *does* dispatch — and
then `isr_common`'s first string read faults at a low address, re-enters the same
handler, and recurses until the kernel stack is exhausted. It wedges for a
*different reason* than the other two and looks identical from outside, which is
why the gate asserts the transcript rather than merely "did not exit 35".

**Byte-identity: 21 of 21 targets identical**, and this mattered more than for P1
— `idt.asm` is `%include`d by **every** kernel build, not guarded behind one
feature. All P2.0 edits are `%ifdef P2_HIGHIDT`; the message loads go through a
`LOADMSG` macro that expands to the identical `mov` when it is not defined.
`gate_p1.sh`, `gate_p1.sh --red` and `gate_k2.sh` all still pass.

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
| **R1** | ~~**Today's kernel IS the red.** The same faulting image on HEAD's K2 halts the machine and never reaches exit 33.~~ **CORRECTED 2026-09-08 — measured, and this was wrong.** A ring-3 fault today produces **no output and no exit code**: the machine wedges (rc 124 under `timeout`), because the IDT, the ISR stubs and their strings are all unmapped under a process CR3 (see P2's *measured starting state*). It never reaches 33, but it never reaches **35** either. | The red is **not free**, and it is **weak**: a timeout is also what a hang, a lost serial, or a too-short timeout produce. A gate accepting "not green" would pass for the wrong reason. R1 must therefore NAME the failure shape it saw — `wedged (rc 124, no output)` vs `diagnosed-but-halted (rc 35)` vs `unexpected` — and require the specific one. |
| **R2** | **Attribution.** Make `gamma` fault instead of `beta`; the reported pid must change. | A handler that hardcodes a pid, or misreads "current", passes assertion 1 and fails only here. |
| **R3** | **Containment vs MASKING.** `beta`'s post-fault instruction would print `beta-continued`; assert it **never appears**. | A handler that "contains" by mapping the faulting page and resuming looks identical on assertions 1–4. This is the `b_τ ≡ f_τ` check on the word *isolated*: the process must **die**, not be papered over. |
| **R4** | **Isolation has power.** Re-run with `alpha` and `beta` mapped into ONE address space; `beta`'s wild write must reach `alpha`'s canary and corrupt it. | Assertion 4 is vacuous if nothing could ever have corrupted the canary — this proves the test can fail. |
| **R5** | **Restart storm.** A service that faults instantly, every time, must be backed off and eventually given up on. Remove the backoff → the restart count in a fixed window differs. | A supervisor that restarts in a tight loop satisfies "it restarts it" while violating codex :25861. |

**R3 and R4 are the two that matter most**, and neither is obvious: R3 separates
containment from masking, and R4 stops the isolation assertion from being
vacuous. ~~R1 costs nothing because the current kernel already produces it.~~
**CORRECTED 2026-09-08 — R1 is not free** (measured; see the struck R1 row above
and P2's *measured starting state*). A ring-3 fault today produces no output and
no exit code at all, so R1 must NAME the failure shape rather than accept any
non-green. §5.0.3 restates it as R1'.

Also superseded by §5.0.3: **R5 (restart storm) and green assertion 5 (restart
under a NEW pid) move to P6's gate**, because restart after a fault means
rebuilding the PML4 from a pristine image — that is P3. Keeping them here would
make the keystone ungateable until P3 existed.

**Honest note on cost.** This gate needs P1–P4 before it can run at all; it is
the *acceptance test* for the keystone, not an early check. P1 and P2 each want
their own smaller gate first (pid round-robin; a single faulting process that
the kernel survives with no init involved), on the K-series discipline of
verifying each brick green before the next.

### 5.0.1 P1's gate — why the number is THREE

**Status 2026-09-08: the `boot.asm` half is built, the gate runs GREEN, and its red
has been witnessed four ways (§5.0.2). Both the gate and its red control are wired
into `build.sh`.**

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

### 5.0.2 The reds actually witnessed (2026-09-08), and two defects they found

`--red` is the *designed* control; the other three are the real gate driven red by
breaking the implementation, restored after each.

| # | Break | Verbatim verdict | rc |
|---|---|---|---|
| **--red** | all three PCBs on ONE PML4 (`build_p1.sh --shared`) | `PASS  P1 red control: with one shared PML4 the per-process values collapse (1/3 survived, expected <3)` | 0 |
| **1** | `P1_NPROC` 3 → 2 (the HH2c shape) | `FAIL  P1: expected exactly 3 processes, saw 2. TWO is the number a hardcoded stage byte can fake (HH2c does); three is what requires a real table and scheduler.` | 1 |
| **2** | force `P1_SHARED` into the normal build | `FAIL  P1: no 'P1 pid=2 val=B2' on serial — process 2 did not run, or read another process's memory at the shared VA` | 1 |
| **3** | silence the drained line only (rc stays 33) | `FAIL  P1: the kernel did not outlive its process table — no 'P1 table drained' line.` | 1 |

Break 2 is the one worth reading closely. Under `P1_SHARED` the transcript is
`pid=1 val=A1 / pid=2 val=A1 / pid=3 val=A1`: **the pids stay correct while the
values collapse.** The control breaks isolation and *only* isolation — identity
still comes from the table — so it is evidence about assertion 3 specifically,
rather than knocking the whole gate over.

**★ DEFECT — the gate could never have gone green.** `gate_p1.sh` as committed at
`2e8df92` called `CLEAN=$(run_variant)`. Command substitution runs the function in a
**subshell**, so the `RC=$?` it assigned died there and the caller read an unset `RC`
defaulting to 1. The exit-33 assertion saw `1` on a kernel that genuinely exited
`33`. It failed *toward red*, so nothing was ever falsely passed — but a gate that
cannot pass tests nothing, exactly as a gate that cannot fail tests nothing. Fixed by
setting `CLEAN`/`RC`/`BUILDFAIL` in the caller and never calling `run_variant` inside
`$(…)`.

**★ DEFECT — byte-identity is not implied by `%ifdef`.** §5.1 requires every other
kernel ELF stay byte-identical. The first P1 version had all its *code* inside
`%ifdef P1` but its twelve `equ` **constants outside**. Result: `.boot32`, `.rodata`,
`.bss` and `.multiboot` were byte-identical on every target, yet four targets'
objects **differed** — because a bare `equ` lands in the object's **symbol table**.
The diagnostic signature is precise: *all sections match but the objects differ →
look for unguarded constants.* Guarding them fixed it; the sweep then measured
**19 of 19 targets identical** (default, K2_FAULT, K5_TIMER, HAL2B, HAL4, K6A, K6B,
K6C, K6C2, K6C3, HH1, HH1B, HH2, HH2B, HH2C, K5B2, K5B2+K5B2_DBG, RING3, IPC).

**Sequencing hazard, recorded because it nearly bit:** `build_p1.sh` writes
`kernel/entry.inc`, which `build.sh` and `build_hal4g.sh` also write, and
`boot.asm` is read by every kernel build. Editing `boot.asm` or running
`build_p1.sh` while another kernel build is in flight silently contaminates that
build's ELF — it is not a conflict git can see, because these artifacts are
gitignored. Run kernel builds **sequentially**.

---

### 5.0.3 P2's OWN gate — one faulting process, no init (design, 2026-09-08)

§5.0 is the **acceptance test for the whole ruling** and cannot run until P1-P4
exist. §5.0 itself says P2 wants its own smaller gate first — *"a single faulting
process that the kernel survives with no init involved"*. This is that design. It
runs directly on P1's three-process table, which is built and green.

**★ SCOPE DECISION, and it is load-bearing: restart moves OUT of P2's gate.**
§5.0's assertion 5 (*`beta` is restarted under a NEW pid*) and its R5 (*restart
storm / backoff*) both belong to **P6**, not here. Restart after a fault means
tearing down the PML4 and rebuilding from a pristine image, which is **P3
(`pspawn`)**. A P2 gate asserting restart could not go green until P3 existed —
which would make the keystone **ungateable on its own** and stall the exact brick
everything depends on. P2's gate therefore stops at *attribution + containment +
survival*, and P6's gate picks up restart and backoff.

**Scenario.** P1's table, unchanged, except process 2's payload faults instead of
exiting. Two fault shapes, selected by a build flag, so the gate is not tuned to
one vector: `#UD` (`ud2`, vector 06, no error code) and `#PF` (a write to an
unmapped VA, vector 0e, error code non-zero, CR2 = the address).

**Green — seven assertions on the serial transcript plus `isa-debug-exit`:**

1. `P1 pid=1 val=A1` — process 1 completes normally. The table still works; the
   fault did not break the ordinary path.
2. `FAULT pid=2 vec=06 err=0 cr2=0000000000000000` — **the fault is attributed to
   its process.** Attribution is the entire new information over K2's bare
   `EXCEPTION 06`, which names a vector and no owner.
3. `P1 pid=3 val=C3` — **the sibling AFTER the faulting one still runs**, and runs
   *after* it in the transcript. This is containment: the scheduler was re-entered
   from the fault handler. Codex :25856, *"other organs are unaffected"*.
4. `P1 table drained: every process exited, kernel alive` — the kernel outlived
   the fault, the same line P1 already asserts.
5. `P1 pcb pid=2 state=4 fault=06` — the PCB carries **dead-by-fault** and the
   vector, dumped after the run. The table is where the death is *recorded*, not
   just where it is announced; P4 (`pwait`) reads exactly this.
6. Exit **33** — not 35 (K2's fault halt) and not a timeout. The machine survived
   and finished cleanly.
7. `P2 pid=2 resumed` **never appears** — see R3.

**Red controls — each catches a different lie:**

| # | Control | What passes without it |
|---|---|---|
| **R1'** | **The baseline, RESTATED on measurement.** Build with `-dP1` only (no P2): assert `FAULT pid=` is absent AND exit 33 is absent, **and name the shape** — `wedged (rc 124, no output)` is the measured truth today; `diagnosed-but-halted (rc 35)` means P2.0 landed but P2 did not; anything else is `unexpected` and fails. | §5.0's original R1 assumed a clean "halts without 33". Measured, it wedges with no output at all, so a gate accepting *any* non-green would pass for the wrong reason — and would keep passing if the serial broke. |
| **R2** | **Attribution.** Fault process **3** instead of process 2; the reported pid must change 2 → 3. | A handler that hardcodes a pid, or misreads "current", satisfies assertion 2 and fails only here. |
| **R3** ★ | **Containment vs MASKING.** The faulting process's next instruction would print `P2 pid=2 resumed`; assert it **never appears**. | A handler that "contains" by mapping the faulting page and *resuming* looks identical on assertions 1-6. This is the `b_τ ≡ f_τ` check on the word **isolated**: the process must **die**, not be papered over. |
| **R4** ★ | **Isolation has power.** Make process 2's fault a wild **write into another process's frame**. Isolated: it faults and process 3 still reads `C3`. Re-run with `build_p1.sh --shared` (all three PCBs on ONE PML4 — already built and witnessed for P1): the same write must **reach** and corrupt what process 3 reads. | Assertion 3 is vacuous if nothing could ever have crossed. This proves the isolation claim *could* have failed — and it reuses P1's existing, already-red-witnessed `--shared` machinery rather than inventing a second mechanism. |
| **R5** | **Vector fidelity.** Build the `#PF` variant: the reported vector must change 06 → 0e, the error code must be **non-zero**, and **CR2 must equal the address written**. | A handler that reports a constant vector, or forgets CR2, passes the `#UD` gate perfectly. §5.0 names two fault shapes for exactly this reason; this makes it a control rather than a note. |

**R3 and R4 remain the two that matter**, unchanged from §5.0's reasoning: R3
separates containment from masking, R4 stops the isolation assertion from being
vacuous. What is new is **R1'**, which was a free red in §5.0 and is not one.

**Ordering, so the gate can go green incrementally:** P2.0's micro-gate
(`EXCEPTION 06` + exit 35 from inside a process) must pass before any of the above
can even be attempted — a gate that cannot deliver an interrupt cannot observe an
attribution. P2.0 first, green; then P2, green; then the reds above.

#### Constraints on `gate_p2.sh`, before it is written

Carried from P1's own defect and from the cross-track exit-status sweep. All are
exit-status handling; none is findable by reading a gate.

1. **No `set -e` in the gate.** It kills the verdict block on the failing path, so
   the gate cannot print its own FAIL. (`gate_p1.sh` uses `set -uo pipefail`.)
2. **No EXIT trap whose first command can fail** — under `set -e` the trap aborts
   before its cleanup, and a PASS path can exit non-zero.
3. **Never assign the status the caller needs INSIDE a function you then call in
   `$( )`.** This is the defect P1's gate had.

**★ 3 is narrower than it looks, and stating it loosely is itself a defect.**
`SD="$(cmd)"; SDRC=$?` is **correct** — `$?` there is the *assignment's* own status
and it propagates fine; `build.sh:811` uses exactly that form. What broke P1's gate
was that `RC=$?` was assigned **inside the function body**, which command
substitution ran in a subshell, so the assignment died with the subshell. **The tell
is WHERE THE ASSIGNMENT HAPPENS, not where the substitution is.** A sweep that flags
every `X=$(…)` produces hundreds of false positives and finds nothing.

#### Two guards on the CONTROLS themselves (2026-09-08, both paid for)

The constraints above are about a gate's plumbing. These two are about whether a
red control is telling you anything, and both were bought with real false results
while building P2.

**1. Prove the perturbation changed the artifact, before concluding anything from
the gate's response.** An *absorbed* break — one the toolchain rounds away, or a
later stage swallows — and a working assertion are **indistinguishable from the
gate's response alone**. Concluding "vacuous gate" from an absorbed break is a
false finding against a working check. `gate_p2.sh --r3` therefore md5s the ELF
and **fails if `--mask` produced a byte-identical image**, before it looks at the
transcript at all (good `3eb4865facdf` → masked `7aca5a4b0367`).

**2. ★ A control that reports the exact failure it was built to find has told you
nothing until you have confirmed it can also report the ABSENCE of it.** P2's R3
marker string was placed between `db 10` and `p1_line_len equ $ - p1_line`, so the
*ordinary* val-line write ran 33 bytes long and emitted the R3 marker as trailing
garbage. The transcript showed `RESUMED` after processes that **never faulted** —
reading exactly like the masking failure R3 exists to catch, from a string-length
bug with nothing to do with the fault handler.

These two are siblings, one station apart: in the first **the instrument asked
nothing**; in the second **the instrument answered on its own behalf**. Both are
*the thing under test was never the thing you thought*. The second is the more
dangerous, and the asymmetry is worth stating: an absorbed perturbation produces a
false **green**, which fails toward not-knowing; this produces a false **red that
looks like the specific defect you predicted** — the most convincing possible
evidence for a wrong conclusion. What saved it was reading the green transcript
first; asserting R3 before that would have filed "the handler resumes the process"
against working code.

**3. A control that cannot BUILD is a control that is not running.** P2's R1'
control failed to assemble (the probe's constants sat inside `%ifdef P2_ATTRIB`
while `--nofix` builds the probe *without* the handler). It was caught only
because the gate reports a build failure as **FAIL** rather than SKIP. This is
Track E's `gate_srcdrift` finding from the other side — E found a gate printing
SKIP and continuing green when its own script was deleted. **A gate must never
skip its way past a missing or unbuildable control.**

#### How `build.sh` actually reads a gate — measured, because the design depends on it

Checked in this tree rather than taken on report (two line numbers quoted to me for
this were both wrong):

**★ Cite `build.sh` line numbers BRANCH-QUALIFIED.** `build.sh` has diverged far
enough across branches that a bare `build.sh:NNNN` is meaningless: `track-d`'s 812
is `kernel-k1`'s 939, and `track-d`'s 2682 is `kernel-k1`'s 2809 — a drift of ~127
lines through the early file. Two tracks checking the same claim reported different
numbers and both were right about their own branch. Write `track-d:build.sh:812`.

- **`build.sh` gates on EXIT STATUS at the P1 call sites** — `bash kernel/gate_p1.sh
  || exit 1` (`track-d:build.sh:7254`) and `… --red || exit 1` (`:7258`). No
  capture, no redirect.
  Executed both shapes against a stub that prints a FAIL and exits 1: the `|| exit 1`
  form **prints the verdict and exits 1**; the capture form `OUT="$(gate)"` under
  `set -e` prints **nothing** and also exits 1. Both exit 1, so *the exit code alone
  cannot distinguish them* — which is why a captured gate goes red **mutely**.
- **TWO sites make a printed verdict a decision input, and both match `^PASS`**:
  `track-d:build.sh:811-812` (`gate_srcdrift.py` — `SDRC -eq 0` **and** `grep -q
  "^PASS  gate_srcdrift"`) and `:2681-2682` (`fuzz_grammar.py`, same shape). Every
  other gate is read by **exit status alone** — 60-odd `|| exit 1` call sites, plus
  `if ./gate_abspath.sh; then` (`:45`) and `if ./gate_asmelf.sh >…; then` (`:2251`,
  `:2273`).

  **★ Corrected — I first counted THREE and `asm.la` was a mis-classification.**
  At `:2251` the decision is `if ./gate_asmelf.sh >.asmgate/elf64.out 2>&1; then`
  — **exit status**. The `grep -c '^PASS'` on the next line only fills a *fixture
  count* into the PASS message; had it returned 0 the line would read "0 fixtures"
  and the build would still be green. A grep on a gate's output is only a channel
  if it **decides**; a grep that formats a message is display. Track C reported two
  and was right; my third was my error, not a branch difference — so the "the set
  of grep-on-verdict sites differs per branch" reading does **not** follow from it.
  The *line-offset* divergence above is real and stands.

  So a lost **FAIL** line costs a log line, not a red; a lost **PASS** line on those
  two turns a passing gate into a failing build. They are **green-losing** channels,
  not red-losing — which inverts the severity: a gate that cannot print its FAIL is
  a logging defect, a gate that stops printing its PASS is a false red.
- Consequence for `gate_p2.sh`: **the exit status is the load-bearing channel**, and
  the verdict text is for the human reading the log — *unless* someone later wires a
  `^PASS` grep to it, at which point the PASS line becomes load-bearing too.

#### P1's four reds: confirmed gate-authored, from the artifacts

The question is not "did it go red" but **"what process was running when the FAIL
line printed."** Confirmed two ways, neither from memory:

- The P1 kernel's **entire printable vocabulary** is `"P1 table drained: every
  process exited, kernel alive"`, `"P1 pid="`, `"0"`, `" val="`, `"??"` and a
  newline. It cannot emit shell prose. The one `FAIL` in the ELF is the symbol name
  `IDT_FAIL`, an absolute in the symbol table, not printable output.
- The three verdict strings are **unique to `kernel/gate_p1.sh` repo-wide**.

So the FAIL lines could only have come from the gate, and each of the four was
produced by invoking `./kernel/gate_p1.sh` directly. (QEMU *was* also run by hand in
that session — to diagnose the subshell bug and to capture the `--shared` transcript
verbatim — but those runs are illustration, not the verdicts, and the distinction is
exactly the one that matters here.)

---

### 5.0.4 P3's gate — `pspawn`, a process created after boot (design, 2026-09-08)

P1 built its three processes **at boot**, in 32-bit-ish code writing page tables
through the low identity map, before any CR3 was a process's. P3 must do the same
work **at runtime, from ring 3, under a process's CR3** — where that identity map
is gone. That relocation is the whole brick, and it is why P3 is the largest one.

**The discriminator, and it is the hard question this design had to answer.**
P1's was easy: *"nothing hardcoded for two produces a third."* P3's is not, because
a serial line showing a fourth process is exactly what `P1_NPROC equ 4` would also
print. A gate that only asserts "a fourth process ran" **cannot tell `pspawn` from
a bigger boot table** — it would go green against a one-character change that
contains no P3 at all.

**★ The discriminator is DEPTH: a spawned process spawns.** Process 1 spawns
child 4; **child 4 then spawns child 5**. A pre-baked slot yields a fourth
process; nothing pre-baked yields a fifth *created by the fourth*. It is also the
exact property P5 needs — init spawns every other organ, and init's children must
themselves be able to — so the assertion is not a trick to defeat the null
hypothesis, it is the capability the next brick consumes.

The spawn budget rides in the child's **own address space** (a byte the kernel
stamps at creation, at `P1_VAL_VA+2`), not in the kernel. So the depth assertion
doubles as evidence the kernel wrote *per-child content* into a frame it had just
built — the same act, read back by ring 3.

**Design.** `pspawn()` is syscall **57** (Linux's `fork` number, matching this
file's convention of borrowing Linux numbers — `getpid` is 39). It returns the
**child's pid** to the calling process in `rax`, or **−1** when the table is full.
It is not `fork`: nothing of the caller is copied. It builds a process from the
**pristine image**, which is what P6's restart-after-fault will need (a faulted
address space is corrupt, so restart cannot resume — it must rebuild).

Kernel side, all of it at runtime and all of it through the **high alias**
(`HIGH_BASE + phys`, reachable under every CR3 through the shared `PML4[511]`),
because under a process's CR3 the low identity map no longer exists:

1. scan the PCB array for a `P1_ST_FREE` slot; `−1` if none;
2. pid from a **monotonic counter**, not the slot index — so a reused slot gets a
   *new* pid, which is precisely what P6's "restart under a NEW pid" requires;
3. build `PML4[0]=pdpt|7`, `pdpt[0]=pd|7`, `pd[128]=frame|0x87` (`U=1`), and
   `PML4[511]=pdpt_high|3` (**supervisor** — ring 3 cannot reach the kernel);
4. copy the pristine payload into the child's frame and stamp its value tag
   (`'A'+pid-1`, `'1'+pid-1`) and its spawn budget;
5. fill the PCB — pid, cr3, `state=RUNNABLE`, entry, stack, `fault=-1`;
6. return the pid. The scheduler enters the child when the caller exits.

**Green — seven assertions:**

1. `P1 pid=1 val=A1`, `pid=2 val=B2`, `pid=3 val=C3` — the boot-built table is
   untouched. P3 adds a path; it does not replace P1.
2. `PSPAWN pid=1 -> child 4` — **the pid reached RING 3.** The line is printed by
   the *process*, from the syscall's return value, not by the kernel. A
   kernel-printed line would prove creation but not that LA can drive it, and
   "LA-driven" is the whole title of the brick.
3. `P1 pid=4 val=D4` — the runtime-created process **ran**, and read **its own**
   tag through the same `P1_VAL_VA` every other process uses. `D4` (not `A1`) is
   the evidence that a *new address space* was built, not a second name for the
   parent's.
4. ★ `PSPAWN pid=4 -> child 5` **and** `P1 pid=5 val=E5` — **a spawned process
   spawned.** The discriminator above.
5. Ordering: each child's `P1 pid=` line appears **after** the `PSPAWN` line that
   created it. Presence alone would not prove creation preceded execution.
6. `P1 pcb pid=04 state=03 fault=ff` and `pid=05` — the children are **in the
   table**, recorded, dead-by-clean-exit. P2's lesson at the creation station:
   announcing a child is not recording one, and P4 (`pwait`) reads this field.
7. `P1 table drained` + exit **33** — five processes drained, kernel alive.

**Red controls — five, each catching a different lie:**

| # | Control | What passes without it |
|---|---|---|
| **R1** | **Baseline, and its shape is NAMED.** Build with P2 only, no P3: the unknown syscall falls through `syscall_entry`'s `xor rax,rax`, so the payload prints `child 0` and no fourth process exists. Assert `P1 pid=4` **absent** — and note the exit code is still **33**, so a gate keyed on "non-green exit" would pass this for the wrong reason. | A baseline accepting any non-green. Here the baseline is green *by exit code* and wrong *by content*, which is the sharpest possible argument for asserting content. |
| **R2** | **The address space is really built at runtime.** `--sharedcr3`: give the child the **parent's** CR3 instead of a freshly-built PML4. The child then reads `val=A1`, not `D4`. | Assertion 3 is vacuous if nothing could ever have collapsed. This is P1's `--shared` argument moved to the runtime-built table. |
| **R3** ★ | **Announcing is not creating.** `--phantom`: allocate the pid and return it, but never fill the PCB. `PSPAWN pid=1 -> child 4` still prints — and no fourth process ever runs. | A syscall that *reports* a child it did not create satisfies assertion 2 perfectly. This is P2's "announcing is not recording" one station earlier, and it is the lie most likely to be written by accident. |
| **R4** ★ | **Depth has power.** `--nodepth`: `pspawn` refuses a caller whose pid is above the boot-built range. Then `PSPAWN pid=4` and `P1 pid=5` never appear. | Assertion 4 is the discriminator; if nothing could suppress it, it measures nothing. Note this control is the *only* one that separates P3 from `P1_NPROC equ 4`. |
| **R5** | **Bounded, and loud when exhausted.** `--flood`: never decrement the budget, so every process spawns. The table must fill, `pspawn` must return −1, the payload must print `TABLE FULL`, and the machine must still drain and **exit 33**. | Unbounded creation that wedges, or silently ignores exhaustion. This is `secd: heap exhausted` at the process table: a resource limit that is *reported* rather than discovered as a hang. |

**Both guards from §5.0.3 apply, and are wired in:** every control md5s the ELF and
**fails if the perturbation produced a byte-identical image** (ABSORBED vs
UNDETECTED), and every control asserts the **specific named shape** rather than
"not green". R1 makes the second guard unavoidable rather than optional — its exit
code is 33, the same as the green run, so "not green" is not even available as a
verdict.

**Honest scope, stated before the build:** capacity is fixed at `P1_MAXPROC` (8)
and a child's frame and page tables are **slot-indexed** (`P1_PBASE + slot*2 MiB`,
`pml4_p + slot*4096`) rather than drawn from a dynamic physical allocator. That is
a real limit, not a hidden one: it is what makes R5's exhaustion path reachable
and assertable. Wiring `pspawn` to a real PMM is a later step and does not change
the syscall's contract. Nothing here reclaims a dead process's frame either —
`pwait` (P4) is where a slot becomes reusable.

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
