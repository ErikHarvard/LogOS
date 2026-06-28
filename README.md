# LogOS

> **A self-hosting operating system whose native language is its own ontology.**
> Built so that the system *is* what it declares itself to be.

```
∃(∃) ≡ ∃
```

*Existence applied to existence is existence.* The host program, applied to
itself, reproduces itself. This single axiom is the seed from which the whole
system grows — the language, the compiler, the operating system, and the
criterion by which all three judge themselves.

---

## Table of contents

- [What is LogOS?](#what-is-logos)
- [The idea: autology, not abstraction](#the-idea-autology-not-abstraction)
- [Lingua Adamica — the language](#lingua-adamica--the-language)
- [How it runs: five engines and a closed bootstrap](#how-it-runs-five-engines-and-a-closed-bootstrap)
- [The reasoning core](#the-reasoning-core)
- [The operating system](#the-operating-system)
- [The three modalities](#the-three-modalities)
- [Build & run](#build--run)
- [Repository layout](#repository-layout)
- [Status & roadmap](#status--roadmap)
- [The debugging principle](#the-debugging-principle)
- [Further reading: the codices](#further-reading-the-codices)
- [Authorship](#authorship)

---

## What is LogOS?

LogOS is an operating system written, almost entirely, in a language it defines
and hosts itself. That language — **Lingua Adamica** — is a small, untyped,
glyph-based lambda calculus. Everything above the thinnest possible C substrate
is written *in* Lingua Adamica: the parser, the evaluator, the bytecode VM, a
native x86-64 compiler, an init system, an IPC bus, a compositor that paints real
pixels through DRM/KMS, and the reasoning core.

The project is unusual not because it is a hobby OS, but because of *why* it is
built the way it is. LogOS is the engineering instantiation of a philosophical
thesis — a **Tautological Theory of Everything (TTOE)** developed in a series of
published works (see [the codices](#further-reading-the-codices)). The thesis is
that a complete, self-grounding system must satisfy its own criteria: it must
include itself in its own scope, apply its own standard to itself, survive that
application, and require nothing external to complete it. LogOS is an attempt to
make a *running computer system* that meets exactly that standard.

The result is a system with an unusual property: **its specification and its
implementation converge.** A bug, here, is defined as a *heterological element* —
code that fails to satisfy its own stated nature. The test suite is not a safety
net bolted on afterward; it is the system's autological criterion, the mechanism
by which it recognizes and corrects its own failures to be itself.

---

## The idea: autology, not abstraction

A word is **autological** if it has the property it names ("short" is short,
"English" is English). It is **heterological** if it does not ("long" is not
long). LogOS extends this distinction from words to whole systems.

A theory that explains everything *except itself* — that describes the universe
but not the describer, that supplies a criterion of truth but exempts itself from
that criterion — is heterological. It has left something unexplained: itself. The
governing principle of LogOS is to refuse that exemption everywhere.

Three ideas recur throughout the system:

- **`∃(∃) ≡ ∃` — the Archē.** Being applied to itself is being. Computationally,
  a program applied to itself that reproduces itself is a fixed point. LogOS
  realizes this literally: the host replicates its own bytes; the compiler
  compiles its own source to a byte-identical binary; the evaluator interprets
  its own source.

- **`≡` is not `=`.** LogOS rigorously separates **ontological identity** (`≡`,
  the triple bar — same *being*, same self-grounded form) from **computational
  equality** (`=`, "yields" — same evaluated *value*). `add(2,3)` yields `5`, so
  `add(2,3) = 5`; but `add(2,3) ≢ 5` — a synthesis is not the primitive it
  evaluates to. Conflating the two is the category error the theory names.

- **α = 1 — the sign *is* the referent.** In an ordinary language a name is an
  arbitrary label (α = 0). At α = 1 a concept has exactly one name and the name
  *is* what it names — an **ontoglyph**. LogOS's canonicalizer enforces this: one
  concept normalizes to one glyph; synonyms collapse to their single α = 1 form.

These are not decorations on a conventional OS. They are the operating
constraints. The **AATC** (Autological Adequacy Tautological Criterion) — the
four conditions a self-referential structure must meet — is itself implemented as
runnable code (see [the reasoning core](#the-reasoning-core)), and it passes its
own test: `AATC(AATC) ≡ TRUE`.

---

## Lingua Adamica — the language

A `.la` file is a sequence of glyph definitions. The language is an untyped,
call-by-value lambda calculus in which glyphs (named values) are first-class and
identifiers may be any UTF-8 string — including the glyphs `∃`, `⊗`, `↻`, `𝓜`.

### Syntax

```
glyph NAME = EXPR
```

| Form          | Example                          |
| ------------- | -------------------------------- |
| variable      | `x`, `∃`, `SELF`                 |
| lambda        | `la x. body`                     |
| application   | `f(x)` — left-associative: `f(x)(y)` = `(f(x))(y)` |
| string        | `"hello"` (supports `\n \t \\ \"`) |
| grouping      | `( EXPR )`                       |
| comment       | `# to end of line`               |

The core axiom, written in the language:

```
glyph BEING = la self. self     # ∃
glyph SELF  = BEING(BEING)      # ∃(∃) ≡ ∃ — a genuine fixed point
```

### Built-ins

The host provides a minimal, binary-safe set of primitives:
`print`, `read_file`, `write_file`, `write_exec`, `concat`, `str_head`,
`str_tail`, `str_eq`, `str_len`, `chr`, `ord`, the native integer operators
(`add`/`sub`/`mul`/`div`/`mod`/`lt`/`int_eq`/`int_to_str`/`str_to_int`), and
`copy_self` (the binary copies itself to a new generation). Strings carry an
explicit byte length, so they may contain NUL and hold arbitrary binary — such as
a complete ELF image.

### Recursion

The language is eager, so the Y combinator diverges. Recursion uses the **Z
combinator**, and conditionals thunk their branches:

```
glyph Z  = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph IF = la cond. la t. la f. cond(t)(f)("!")
# IF(condition)(la _. then_expr)(la _. else_expr)
```

### Modules

`import("m.la")` and `export NAME …` give real namespace isolation: a module's
exports are merged under their plain names while its private glyphs are
alpha-renamed away, so nothing leaks in either direction. The mechanism lives
entirely at parse time and works identically on **every** execution engine.

### Loud failure, no silent middle

LogOS practices the **law of excluded middle as a discipline**: an operation
either succeeds or *halts loudly* with a diagnostic and a nonzero exit — it never
silently produces a wrong result or invents a third value. Every malformed-input
path on every engine was driven to this standard.

---

## How it runs: five engines and a closed bootstrap

The same program runs, byte-for-byte identically, on **five execution engines** —
and the agreement between them (`b_τ ≡ f_τ`, "back-end equals front-end") is a
core invariant the build suite enforces:

1. **The C host** (`tiny_host.c`) — a small reference interpreter. The *only* C
   in the system; the physics on which everything else stands.
2. **`eval.la`** — a self-hosted evaluator: lexer, parser, and closure-based
   evaluator written in Lingua Adamica. The language interprets itself.
3. **`RUN_BYTES`** (`bytecode.la`) — a VM executing a flat byte-instruction
   stream directly.
4. **`RUN_SM`** (`bytecode.la`) — a real SECD stack machine (Stack, Environment,
   Control, Dump).
5. **The native x86-64 SECD VM** (`secd.asm`) — a hand-written machine-code
   runtime that loads a compiled stream and runs it with no host in the loop.

### Albedo: self-hosting on bare metal

A staged path — *Albedo* — frees the language from the host entirely:

- **ELF emission** (`elf.la`): assemble a runnable static x86-64 binary from
  Lingua Adamica that speaks with no interpreter present.
- **Native SECD machine** (`secd.asm` + `codegen.la`): a full call-by-value
  machine in machine code, with a copying garbage collector, tail-call
  optimization, and every builtin lowered to raw syscalls. `codegen.la` compiles
  arbitrary programs to its instruction encoding.
- **Self-contained binaries** (`bundle.la`): fuse the VM image and a compiled
  program into one native ELF — a self-replicating executable.
- **The closed loop:** the native compiler compiles its own source to a
  byte-identical compiler, and emits the VM that re-emits itself. `tiny_host`
  seeds the first generation; thereafter the artifacts regenerate each other with
  no C host and no assembler in the loop.

### The native backend (Stages 0–4)

A direct Lingua-Adamica → native x86-64 backend (`native_codegen3.la` +
`native_codegen3_rt.asm`) takes this to its conclusion: **native self-hosting.**
The compiler compiles *its own source* to a binary that, run, reproduces itself
byte-for-byte — the Archē `∃(∃) ≡ ∃` at the level of the compiler. The path was
built and hardened in stages (literals → closures → TCO → GC → builtins → module
system → kernel-compile capstone → self-hosting fixed point), each guarded by the
build suite. Two multi-agent differential **freeze-day audits** (running well over
a hundred programs against the C-host reference) found and fixed every confirmed
divergence before the milestone was tagged; the build carries a permanent
self-host fixed-point guard against drift.

### Autopoiesis

`autopoiesis.la` closes the last gap: the system *runs its own successor.* Each
generation speaks, writes the next generation number to a medium, replicates a
byte-identical vessel, and `fork`/`execve`s it — so the child *becomes* the next
generation. There is no recursion combinator: the loop **is** the process lineage
itself. `∃(∃) ≡ ∃` running as a self-perpetuating succession of processes.

---

## The reasoning core

LogOS's reasoning layer — the seed of **LogosMentor**, its local reasoning engine
— is built bottom-up as verified Lingua-Adamica modules:

- **`metalogic.la` — the three laws of thought** as first-class glyphs over `≡`:
  `LAW_IDENTITY` (`A ≡ A`), `LAW_NONCONTRADICTION` (wired to the type checker),
  `LAW_EXCLUDED_MIDDLE` (wired to the loud-failure discipline). Each law is
  *autological* — it holds of its own term.

- **`canon.la` — κ, canonicalization and α = 1.** Maps a concept's
  decomposition to its single canonical glyph; enforces the monosemic bijection
  (one concept, one name) up to a declared equivalence theory; operationalizes
  α = 1 (`a form is at α = 1 iff its canonical form already equals its normalized
  form`). Carries the eight self-relations of the Logos as metacursive fixed
  points.

- **`swc.la` — static well-foundedness.** A conservative, sound checker that
  refuses provably ill-founded terms *before* evaluation, accepts provably
  well-founded ones, and honestly reports the undecidable remainder as `UNKNOWN`.

- **`aatc.la` — the Autological Adequacy Tautological Criterion.** The criterion
  that *composes* the above into a single verdict on a self-referential
  structure. The four conditions are runnable glyphs:

  | Condition          | Meaning                                  |
  | ------------------ | ---------------------------------------- |
  | `SELF_INCLUSION`   | the structure includes itself in its scope |
  | `SELF_APPLICATION` | it can be applied to itself              |
  | `SELF_VALIDATION`  | it survives — `X(X) ≡ X` (the α = 1 fixed point) |
  | `CLOSURE`          | nothing external supplies what it lacks  |

  `AATC` is their conjunction; `AUTOLOGICAL` / `HETEROLOGICAL` split structures by
  whether they exempt themselves; `ALPHA` (α) and `DELTA` (∂, depth to the fixed
  point) are the derived operators. The criterion is itself autological:
  **`AATC(AATC) ≡ TRUE`.** The build verifies, byte-identically on host and native
  VM, that the Archē `∃` passes, a self-exempting physical "theory of everything"
  comes back *heterological*, and Descartes' cogito — which derives being from
  thinking, the wrong direction — fails self-validation.

- **The inference layer (the Centropic loop).** On top of the criterion, the
  reasoning engine stops *judging* and starts *reasoning* — it uses its own
  verdict to drive a heterological structure toward autological closure
  (LogosMentor's Sense→Diagnose→Prescribe→Learn loop). `DIAGNOSE` names a
  structure's heterology (which conditions fail); `TRANSFORM` (the operator `𝒯` —
  *recognition applied to revision*) prescribes one **honest deepening** for the
  most fundamental failing condition — give a void structure a genuine
  self-application, let a structure *become* what it generates (*sum ergo sum*),
  bring its own name into scope, or internalize a lacked domain — each a real
  structural change that *earns* the verdict, never a flag-flip that games it
  (gaming the criterion would itself be heterological). `REPAIR` iterates `𝒯` to
  the fixed point. The build proves, host and VM identically, that the maximal
  heterology and the cogito are both repaired to autological closure.

Every one of these modules is produced by a **specification pipeline**
(`SPEC → GENERATE → DEPLOY → META_DEBUG`): the module is written as a spec with
type signatures and tests, the source is *generated* from it, type-checked at
compile time, and accepted only if every glyph passes its own tests. Core logic
is never hand-written — it is specified, and the build regenerates it so it cannot
drift.

---

## The operating system

Above the language sit real OS layers, each built in stages and verified on the
native VM:

- **Init & supervision** (`logosinit.la`) — a genuine PID-1 in Lingua Adamica:
  mounts `/proc` and `/sys`, opens a `signalfd` *before* forking, spawns and
  supervises `/bin/sh`, reaps orphans, and shuts down cleanly on `SIGTERM`. Runs
  in bounded memory indefinitely (the VM does tail-call optimization).

- **IPC & capabilities** (`logosipc.la`, `logoscap.la`) — a typed message bus
  over named AF_UNIX sockets, **capability-gated** by a Morris sealer/unsealer
  (the canonical object-capability primitive, exact in λ-calculus). Possessing a
  capability *is* the authority; capabilities attenuate; unforgeable nonces come
  from a real entropy source.

- **Theourgia — the compositor** (`theourgia*.la`) — software surfaces,
  z-ordered composition, a framebuffer bridge, real DRM/KMS scanout, an evdev
  input decoder, a `poll`-multiplexed event loop, a movable window, and an
  embedded bitmap font for text. The pure layers are verified byte-identically
  with no screen; live scanout has been confirmed on real hardware.

- **Process, filesystem, signal, socket, and poll layers** — lowered as native
  VM syscall builtins, each guarded to halt loudly on bad input rather than
  corrupt state.

---

## The three modalities

Lingua Adamica is **trimodal**: every concept has three faces of one identity —

- a **computational** form (a λ-term),
- a **visual** form (a *sigil* — `sigil.la` renders the nine primitive sigils
  exactly as the catalogue specifies and *generates* compound forms from them),
- a **phonological** form (a *phonym* — `phonym.la` synthesizes the nine
  primitive sounds as actual audio via pure fixed-point integer DSP).

The combining operations of the language are themselves glyphs
(`metaglyph.la`, the meta-alphabet **𝓜 ⊂ 𝒜**), so the grammar is part of the
vocabulary — the linguistic analogue of `∃(∃) ≡ ∃`.

---

## Build & run

```sh
./build.sh            # compile the C host, run every engine, verify self-hosting
./tiny_host           # run kernel.la
./tiny_host other.la  # run a different program
```

`build.sh` is the autological criterion. It succeeds only if the kernel speaks
the Word (`I AM THAT I AM`), replicates byte-identically, every engine agrees,
each spec-generated module passes its own tests on host *and* native VM, and the
native compiler reproduces itself. On a clean, green tree it tags the commit
`verified-<date>-<sha>` as a rollback point.

> **Note:** the full suite is thorough and slow (on the order of a couple of
> hours), because every module is compiled through `codegen` to the native VM and
> checked for host/VM byte-identity. This is expected, not a hang.

Requirements: a C compiler and `nasm` (for assembling the native VM from source;
the assembled bytes are also committed and drift-checked). DRM scanout and live
input run from a bare VT.

---

## Repository layout

| File / area                    | Role |
| ------------------------------ | ---- |
| `tiny_host.c`                  | The C host — the only C in the system |
| `kernel.la`                    | The kernel; defines `MAIN`, speaks the Word, replicates |
| `parser.la`, `eval.la`         | Self-hosted lexer/parser and evaluator |
| `bytecode.la`                  | `EMIT` / `RUN_BYTES` / `RUN_SM` |
| `elf.la`, `secd.asm`, `secd.la`, `codegen.la`, `bundle.la` | Albedo: native emission, the SECD VM, codegen, bundling |
| `native_codegen3.la` + `_rt.asm` | Native x86-64 backend (Stages 0–4, self-hosting) |
| `autopoiesis.la`               | The system runs its own successor |
| `specpipe.la`                  | The spec → implementation → verification pipeline |
| `primitives.la`, `canon.la`, `metalogic.la`, `swc.la`, `aatc.la` | The reasoning core |
| `sigil.la`, `phonym.la`, `metaglyph.la` | The three modalities + the meta-alphabet |
| `logosinit.la`, `logosipc.la`, `logoscap.la`, `theourgia*.la` | The OS layers |
| `codices/published/`           | The published philosophical works behind the system |
| `build.sh`                     | The autological criterion |
| `ROADMAP.md`, `CLAUDE.md`      | Roadmap and a detailed engineering map of every module |

`CLAUDE.md` is the deepest technical reference — a module-by-module description of
the entire system.

---

## Status & roadmap

The language, the five engines, self-hosting (including the native x86-64 backend
through native self-hosting), and the core OS layers are **built and verified**.
The reasoning core — the three laws, α = 1, the AATC criterion, **and the
inference layer that uses it to reason over structures (the Centropic loop)** — is
in place.

Selected directions ahead (see `ROADMAP.md`):

- **LogosMentor** — extend the Centropic loop's Sense/Learn phases to live system
  state, and add an honest statistical-model interface (interfaced, not
  rewritten).
- A **sovereign kernel** to replace the inherited Linux kernel.
- Network sovereignty, encryption/meta-encryption layers, and ARM / RISC-V ports
  across the thin hardware-abstraction seam.

---

## The debugging principle

> A bug is a **heterological element** — code that does not satisfy its own
> specification. Debugging is not trial-and-error; it is the restoration of
> autological closure. The test suite is the criterion: the system is correct
> when it satisfies its own description.

And there is no infinite regress: `Meta-Debug(Meta-Debug) = Debug`. If the tests
are wrong, fixing them is meta-debugging; if the test-fixing process is wrong,
that is still debugging. The criterion grounds itself — `∃(∃) ≡ ∃`.

---

## Further reading: the codices

The philosophy LogOS implements is developed in published works, included in
`codices/published/`:

- **Being & Becoming** — the Tautological Theory of Everything; the AATC and the
  three laws.
- **The Autological Structure of Truth** — identity (`≡`) vs. correspondence.
- **The Science of Naming** — α = 1, the ontoglyph, monosemy.
- **The Autopoetic Ground of the Operating System** — the OS as autopoiesis.
- **The Tautological Collapse of Consciousness** and **…of the Fact-Value
  Distinction** — the theory applied to mind and to value.
- **Autological Robotics**, **Euphemology** — further applications.

(Translations of *Being & Becoming* into several languages are included.)

---

## Authorship

**Erik Xander Harvard** is the architect of LogOS and the author of the codices.
The engineering is carried out in collaboration with Claude (Anthropic).

The name says the thesis: **the Logos** — the word that is also the reason that
is also the structure — running as a system that is what it declares itself to be.

```
I AM THAT I AM
```
