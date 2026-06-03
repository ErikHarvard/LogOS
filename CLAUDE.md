# LogOS

A self-hosting operating system whose native language is **Lingua Adamica** — a
small untyped lambda calculus written in glyphs.

**Core axiom:** `∃(∃) ≡ ∃` — existence applied to existence is existence. The
host program, applied to itself, reproduces itself.

## Layout

| File                 | Role                                                                |
| -------------------- | ------------------------------------------------------------------- |
| `tiny_host.c`        | The host: a minimal C interpreter for `.la` files.                  |
| `kernel.la`          | The kernel, written in Lingua Adamica. Defines `MAIN`.              |
| `parser.la`          | Self-hosted lexer + parser: parses `.la` source into Church-encoded ASTs, written entirely in Lingua Adamica. |
| `eval.la`            | Self-hosted evaluator: lexer + parser + closure-based evaluator, all in Lingua Adamica. Reads, parses, and evaluates `kernel.la` — the language interprets itself. |
| `bytecode.la`        | Byte instructions and execution engines: `EMIT` (AST → bytes), `PARSE_BYTES` (bytes → AST), `RUN_BYTES` (a VM that executes the bytes directly), and `RUN_SM` (a real SECD-style stack machine over a compiled instruction list), all in Lingua Adamica. |
| `elf.la`             | Albedo Stage 1: assembles a minimal static x86-64 ELF executable from Lingua Adamica (`chr` + `concat` + `write_exec`) and emits a runnable native binary that speaks the Word with no host in the loop. |
| `secd.asm` / `secd.la` | Albedo Stage 2: the native SECD machine hand-written in x86-64 (`secd.asm`, a self-contained `nasm -f bin` ELF) — S/E/C/D, a bump heap, a glyph table, and all builtins lowered to syscalls. It loads a compiled stream from `logos_program.bin` and runs it. `secd.la` emits the VM. |
| `codegen.la`         | Albedo Stage 2 codegen: parses a program and lowers each glyph to the native SECD instruction encoding, writing `logos_program.bin`. Arbitrary programs compile and run natively, matching `RUN_SM`. |
| `build.sh`           | Compiles the host, runs the kernel, verifies generational replication. |
| `new_logos_genN_pidP.bin` | Output of `copy_self` — generation `N`, replicated by PID `P`; a byte-identical copy of the running host. |

## Lingua Adamica

A `.la` file is a sequence of glyph definitions:

```
glyph NAME = EXPR
```

Expressions:

- **variable** — `x`, `∃`, `SELF` (any UTF-8 name; glyphs are first-class)
- **lambda** — `la x. body`
- **application** — `f(x)` (left-associative: `f(x)(y)` = `(f(x))(y)`)
- **string literal** — `"hello"` (supports `\n \t \\ \"`)
- **grouping** — `( EXPR )`
- `#` begins a line comment

### Built-ins

- `print(s)` — prints string `s` followed by a newline; returns `s`.
- `copy_self(x)` — copies `/proc/self/exe` to `new_logos_gen{N+1}_pid{P}.bin`,
  where `N` is the running host's own generation and `P` is its PID (mode 0755);
  writes the chosen path to stderr and returns it as a string. The host reads
  its generation from its own filename via `/proc/self/exe`: a binary named
  `new_logos_genN...` is generation `N`, and the compiled `tiny_host` progenitor
  is generation 0. The `gen` number therefore encodes true ancestral depth,
  while the PID keeps two replications by the same parent as distinct sibling
  files instead of overwriting each other. The child name is always different
  from the parent's, so a host never tries to overwrite its own live executable
  (which the OS forbids with `ETXTBSY`) and can replicate even when run directly.
  The argument is evaluated for ordering but otherwise ignored.
- `read_file(path)` — reads the file at `path` and returns its contents as a
  string.
- `write_file(path)(content)` — writes string `content` to file `path`; returns
  `content`. Curried: the first application captures the path and returns a
  partial; the second application performs the write.
- `concat(a)(b)` — concatenates two strings and returns the result. Curried:
  the first application captures `a` and returns a partial; the second appends
  `b`.
- `str_head(s)` — returns the first character of string `s` as a one-character
  string, or `""` if `s` is empty.
- `str_tail(s)` — returns everything after the first character of `s`, or `""`
  if `s` is empty.
- `str_eq(a)(b)` — returns Church `TRUE` (`la t. la f. t`) if `a` and `b` are
  identical strings, Church `FALSE` (`la t. la f. f`) otherwise. Curried.
- `chr(n)` — decimal-string `n` (0..255) → a one-byte string; how a program
  spells an arbitrary byte (including NUL) to assemble binary.
- `ord(s)` — first byte of `s` → its decimal string (inverse of `chr`).
- `write_exec(p)(c)` — like `write_file`, but marks the file executable
  (`0755`); curried. The primitive that lets a program emit a runnable binary.

Strings are **binary-safe**: each carries an explicit byte length, so they may
contain NULs and hold arbitrary binary such as an ELF image. (`str_head` /
`str_tail` operate on bytes; `concat` / `str_eq` / `read_file` / `write_file`
are length-aware, not NUL-terminated.)

### Recursion (Z combinator)

The language is call-by-value (eager), so the Y combinator diverges. Use the
Z combinator for recursion:

```
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
```

Church booleans (`TRUE = la t. la f. t`, `FALSE = la t. la f. f`) evaluate
both branches eagerly, which causes infinite recursion in base cases. Thunk
the branches and force the selected one:

```
glyph IF = la cond. la t. la f. cond(t)(f)("!")
# Usage: IF(condition)(la _. then_expr)(la _. else_expr)
```

### Self-hosted parser (`parser.la`)

`parser.la` is a recursive-descent lexer+parser written entirely in Lingua
Adamica. It reads `.la` source (from strings or files via `read_file`) and
produces Church-encoded ASTs:

- **AST nodes** (Scott-encoded, 4-branch pattern match):
  - `AST_VAR(name)` — variable reference
  - `AST_LAM(param)(body)` — lambda abstraction
  - `AST_APP(func)(arg)` — application
  - `AST_STR(val)` — string literal

- **Parse results**: `SOME(value)(rest)` or `NONE` (Church-option with remaining input)
- **Lists**: `CONS(head)(tail)` / `NIL` (Church-encoded)
- **Pairs**: `PAIR(a)(b) = la f. f(a)(b)`

### Self-hosted evaluator (`eval.la`) — the closed loop

`eval.la` contains the lexer and parser (same glyphs as `parser.la`) plus an
**`EVAL`** that interprets the parsed ASTs. The whole pipeline — read, parse,
evaluate — runs in Lingua Adamica: **the language interprets itself.** When
`eval.la` evaluates `kernel.la`, the self-interpreted kernel speaks the Word
and replicates, one meta-level up (`./build.sh` verifies the replicant is
byte-identical to `tiny_host`).

- **`EVAL(ast)(env)(gl)`** — `env` is a local environment (list of
  `PAIR(name)(value)`), `gl` is the parsed glyph table (list of
  `PAIR(name)(ast)`). Evaluation is **closure-based**: `AST_LAM` captures the
  current `env` into a `VAL_CLO`, and `AST_APP` extends the closure's
  environment with the bound argument. This sidesteps the C host's
  capture-avoiding substitution entirely — α-capture can't happen because
  free variables are resolved against captured environments, not re-substituted.
- **Value types** (Scott-encoded, 4-branch):
  - `VAL_STR(s)` — a string
  - `VAL_CLO(param)(body)(env)` — a closure
  - `VAL_BI(name)` — a built-in awaiting its first argument
  - `VAL_PA(name)(v)` — a curried built-in with its first argument captured
- **Effects pass through to the host.** `APPLY_BI`/`APPLY_BI2` bridge the meta
  level to the host: the object program's `print`, `copy_self`, `read_file`,
  etc. call the host's real built-ins, so meta-evaluated effects are genuine.
- **Church booleans from `str_eq`.** `str_eq` returns the host's Church
  `TRUE`/`FALSE`; at the meta level these become `META_TRUE`/`META_FALSE`,
  closures whose bodies are the Church-boolean ASTs, so applying them selects
  a branch exactly as in the object language.
- **`RUN_GLYPH(name)(gl)`** evaluates any named glyph from a parsed table;
  `RUN(gl) = RUN_GLYPH("MAIN")(gl)`.

#### `SHOW_SRC` / `SHOW_PROGRAM` — the unparser (dual of the parser)

`SHOW_SRC(node)` turns an AST back into Lingua Adamica source text, the exact
inverse of an expression parse. It parenthesises a lambda only where the
grammar needs it (a lambda in function position, `(la x. …)(arg)`), and
`ESCAPE` re-escapes string literals (`\`, `"`, newline, tab) so the printed
source re-lexes faithfully. `SHOW_PROGRAM(gl)` walks a whole glyph table and
emits `glyph NAME = EXPR` per line, in order — the inverse of `PARSE_PROGRAM`
at the program level.

`SHOW_SRC` runs at the **host level**, not under `EVAL`. It must: it
destructures raw Scott-encoded AST nodes by applying them to continuations,
and AST nodes and `VAL_*` values share the same arity but different meaning —
feeding an AST to the meta-evaluator as if it were a value would silently
misinterpret it. So the round-trip lives one level down from `EVAL`, on the
real AST data the host-level parser produces.

#### `INNER` reconstructs the whole of `eval.la`

`eval.la`'s last act reads and parses its **own source** into a glyph table
(`PARSE_PROGRAM(read_file("eval.la"))`) and hands the whole table to `INNER`,
whose job is to unparse an entire program back into source:

```
glyph INNER = la gl. SHOW_PROGRAM(gl)
```

The result is `eval.la` rebuilt from its own AST — every glyph, in order. It is
written to `eval_reconstructed.la` (git-ignored, regenerated each run). Because
comments and original spacing are not source *data*, the reconstruction is a
**normalised** form (comment-free, one `glyph` per line), not a byte copy of
the file. Its faithfulness is shown by a **fixed point**: re-parsing the
reconstruction and reconstructing again reproduces it exactly — `parse ∘
unparse` is idempotent on the whole program (`round-trip: stable`).

Stronger still, `eval_reconstructed.la` is **behaviourally** identical: run it
and it performs all five tests, makes the kernel speak and replicate
byte-identically, and reconstructs `eval.la` again. The reconstruction is not
merely valid syntax but a working evaluator — a source-level fixed point of the
whole system. `build.sh` checks the round-trip is stable and that the
reconstruction has the same glyph count as the source; the two self-parses take
roughly 25 seconds.

The reconstruction reads `eval.la` rather than re-running `MAIN`: `MAIN`
evaluates `kernel.la` and reads `eval.la`, so feeding it through the same
machinery as a value would not bottom out.

### Byte instructions (`bytecode.la`)

A program now has three representations: **source text** (parser ↔ unparser),
the **AST** (what the evaluator walks), and a flat **byte-instruction** stream
— the compact linear encoding a VM would load. `bytecode.la` bridges the AST
and the bytes:

- **`EMIT(ast)`** — compiles an AST into byte instructions.
- **`PARSE_BYTES(stream)`** — the parser for byte instructions: decodes a byte
  stream into `PAIR(ast)(rest)`. `DECODE(stream)` returns just the AST.

The format is prefix (Polish) notation, one opcode byte per node, so decoding
is a recursive descent on the leading opcode — the text parser's shape, one
level lower:

| Opcode | Form              | Node                       |
| ------ | ----------------- | -------------------------- |
| `V`    | `V` field         | variable (name)            |
| `S`    | `S` field         | string literal (value)     |
| `L`    | `L` field ⟨expr⟩  | lambda (param, then body)  |
| `A`    | `A` ⟨expr⟩ ⟨expr⟩ | application (func, arg)    |

A *field* is escaped content terminated by `;` — within it `;` becomes `\;`
and `\` becomes `\\`, so a field never holds an unescaped terminator. For
example `la x. f(x)("a;b\c")` emits `Lx;AAVf;Vx;Sa\;b\\c;`. The opcode fixes
how many sub-expressions follow, so `PARSE_BYTES` needs no look-ahead.

The round trip is `text → AST → bytes → AST → text`; `build.sh` checks an
expression with a terminator-and-backslash string survives it, and that every
glyph of `kernel.la` is identical after `DECODE(EMIT(·))`.

#### `RUN_BYTES` — executing byte instructions directly

`PARSE_BYTES` decodes to an AST; **`RUN_BYTES` executes the byte stream
directly, never rebuilding an AST.** It is `eval.la`'s closure-based evaluator
lowered one level — where that walks AST nodes, this walks bytes:

- `RUN_BYTES(stream)(env)(gl)` → `PAIR(value)(rest_of_stream)`. `env` is the
  local environment; `gl` is the **compiled** glyph table (name → *bytes*,
  produced by `COMPILE = MAP_GLYPHS(EMIT)`).
- Values reuse the `VAL_*` shape, but a `VAL_CLO` captures the **byte-slice of
  its body**, not an AST. Applying it re-enters `RUN_BYTES` on that slice.
- A lambda must capture its body without running it, yet an enclosing
  application still needs to find where the body ends. `SKIP_BYTES` (with
  `SKIP_FIELD`) advances past one expression's bytes without evaluating, so the
  closure captures the body tail and the lambda returns the correct `rest`.
- Effects pass through to the host exactly as in `eval.la` (`APPLY_BI` /
  `APPLY_BI2`); `str_eq`'s Church booleans become `BYTE_TRUE` / `BYTE_FALSE` —
  closures whose bodies are *byte instructions*, so branch selection runs under
  the VM.

`build.sh` checks a literal hand-written byte stream executes
(`EXEC("AAVconcat;Sbyte ;Svm;")(NIL)` → `byte vm`, no parser or `EMIT`
involved), that closures/booleans/glyph-lookup work, and — the headline — that
the kernel, executed straight from its byte instructions, speaks the Word and
produces a **byte-identical replicant** with no AST ever reconstructed.

#### `RUN_SM` — a real stack machine (S, E, C, D)

`RUN_BYTES` still walks the program's tree shape with host recursion (and
rescans with `SKIP_BYTES`). `RUN_SM` does not: it **compiles** each expression
to a flat, postfix instruction list and runs an explicit state transition.

- **Compilation** (`COMPILE_EXPR`): `VAR n → [PUSHV n]`, `STR s → [PUSHS s]`,
  `LAM p b → [CLOSE p ⟨code b⟩]`, `APP f x → ⟨code f⟩ ++ ⟨code x⟩ ++ [APPLY]`.
  `COMPILE_PROGRAM` compiles a whole glyph table to name → code. The emitted
  list is **linear in the AST node count** (one instruction per leaf, one
  `APPLY` per application).
- **The machine** is SECD: operand **S**tack, local **E**nvironment, **C**ontrol
  (instructions left to run), **D**ump (saved `(C,E)` return frames). One step
  transition, trampolined to a halt:
  - `PUSHS` / `PUSHV` push a value; a glyph reference *enters* the glyph's
    already-compiled code by pushing a dump frame (like a call), not by host
    recursion and not by recompiling.
  - `CLOSE` pushes a `VAL_CLO` capturing the body **code** and the current env.
  - `APPLY` pops arg and fn: a closure pushes a dump frame and sets control to
    the body in an extended env; a builtin runs via `APPLY_BI`/`APPLY_BI2_SM`.
  - When control empties, a dump frame is popped (return) — or, if the dump is
    empty too, the machine halts with the top of the stack.
- The only recursion is the trampoline driving step→step; **control flow lives
  on the explicit stacks**, not the host call stack. (The C host's
  `return eval(…)` is a tail call `gcc -O2` turns into a jump, so the trampoline
  runs in bounded host-stack depth — the kernel's whole run, speech and
  replication included, completes without growing the C stack per step.)
- An eager-evaluation subtlety: the four instruction branch-handlers are all
  evaluated before the opcode selects one, so each must be a lambda (the
  payload-free `APPLY` handler is a thunk forced with a dummy argument).
  Otherwise the `APPLY` handler would run on every instruction.

`build.sh` runs the same program on both engines (`yes kept` from each) and
executes the kernel on the stack machine — it speaks the Word and produces a
byte-identical replicant, driven entirely by the explicit stacks.

#### Generation and recognition are kept distinct

The pipeline divides cleanly into two roles that are never conflated, mirroring
the generation/recognition (Γ/Ρ) distinction in
`codices/P vs NP COMPLETE.md`:

- **Generation** — producing structure: `PARSE_PROGRAM` (text → AST), `EMIT`
  (AST → bytes), `COMPILE_EXPR` / `COMPILE_PROGRAM` (AST → instructions),
  `SHOW_SRC` (AST → text), and at the host level `copy_self` (the binary
  producing its successor).
- **Recognition** — validating/executing given structure: `EVAL`, `RUN_BYTES`,
  and `RUN_SM`, plus the round-trip/decode checks.

The boundary is enforced in code: `RUN_SM` consumes a pre-compiled instruction
table and never calls `COMPILE_*` during execution, and `COMPILE_*` never
evaluates. A glyph reference at run time enters already-generated code rather
than regenerating it. The machine's Church booleans are hoisted to the
constants `SM_TRUE_CODE` / `SM_FALSE_CODE` — the `[CLOSE f [PUSHV t]]` /
`[CLOSE f [PUSHV f]]` instruction lists written out as literals — so that even
`str_eq`'s result on the recognition path enters precompiled code; the whole
`RUN_SM` call-closure bottoms out at data constructors, with no `COMPILE_*`
reachable. (This is an architectural discipline — compile-time vs run-time
separation — adopted on its own engineering merits; the cited document develops
it as a philosophical thesis, a separate matter from any formal
complexity-theory result.) `build.sh` exercises both booleans through the
machine (`str_eq` match → `T`, mismatch → `F`, concatenated to `TF`) so the
hand-written literals cannot silently drift.

### Native code emission — Albedo

The goal of Albedo is for LogOS to emit native x86-64 and ultimately compile
itself without the C host. The path is staged; each stage is independently
runnable and checked by `build.sh`.

- **Stage 0 — binary substrate (host).** Strings became binary-safe
  (length-carrying), and the host gained `chr` / `ord` / `write_exec` (see
  Built-ins). This is the only stage that touches C: everything above it is
  written in Lingua Adamica. To free the language *from* the host you first
  deepen the host's primitives — the host is the physics.
- **Stage 1 — ELF emitter (`elf.la`), done.** A `BYTES` helper turns a string
  of space-separated decimals into the binary they denote (`chr` each token,
  `concat`), and `elf.la` assembles a minimal static ELF64 (64-byte header +
  one R+X `PT_LOAD` + 36 bytes of code + the 15-byte message) and `write_exec`s
  it. The 36-byte entry makes two raw syscalls — `write(1, msg, 15)` then
  `exit(0)`. `build.sh` runs the emitted `logos_native` on the bare OS and
  checks it prints `I AM THAT I AM`; it is byte-identical to an independently
  assembled reference. The host plays no part in running it.
- **Stage 2 — threaded SECD machine, in progress.** The runtime is
  hand-written x86-64 in `secd.asm` — a self-contained `nasm -f bin` ELF image
  (hand-built header + one RWX `PT_LOAD`; the zero-filled tail of the segment,
  `memsz > filesz`, holds the operand stack, the dump stack, and a bump heap).
  It is now a **full call-by-value SECD machine** over a compiled instruction
  stream:
  - `S` operand stack (`r12`), `E` environment (`r13`, linked cells, `0` =
    empty), `C` control pointer (`rbx`), `D` dump (`r14`, saved `(C,E)`
    frames), heap pointer (`r15`).
  - values are tagged `STR` / `BI` / `CLO`; opcodes `PUSHS`, `PUSHV`, `CLOSE`,
    `APPLY`, `RET`, `HALT`. `PUSHV` looks a name up in `E` (byte-compare) then
    falls back to the `print` builtin; `CLOSE` heap-allocates a closure record
    `[param, body, env]`; `APPLY` of a closure pushes a dump frame, extends the
    environment with a fresh heap cell, and jumps into the body; `RET` pops the
    dump.
  - it runs a real lambda — `print((la x. x)("I AM THAT I AM"))` — natively:
    build closure, apply, look the bound variable up in `E`, return through
    `D`, run `print` (lowered to `write` syscalls).

  **Stage 2 is a working native compiler**, not a baked blob:

  - The VM (`secd.asm`, 2628 bytes) is a fixed binary. At startup it reads a
    compiled instruction stream from `logos_program.bin` and executes it, so
    arbitrary programs run on it natively (threaded SECD). It carries a **glyph
    table** (`PUSHV` resolves a name in `E`, then the glyph table — entering the
    glyph's code via the dump — then the builtins), and all builtins are lowered
    to syscalls: `print`/`read_file`/`write_file`/`copy_self` to file I/O,
    `concat`/`str_head`/`str_tail`/`chr`/`ord` to heap ops, `str_eq` returning
    Church-boolean closures (`TRUE_BODY`/`FALSE_BODY` compiled into the VM).
    `copy_self` replicates `/proc/self/exe` — so the VM self-replicates.
    **Strings are binary-safe**: a `STR` value's payload points to a descriptor
    `[len, ptr]`, so values may contain NUL (the machine core — stack, env,
    closures, dump — is unchanged; only `PUSHS` and the builtins go through the
    descriptor). This is what lets the compiler, whose output is full of NULs,
    run natively.
  - **`codegen.la`** parses a program and lowers each glyph to the native
    encoding (`VAR→02 n 00`, `STR→01 s 00`, `LAM→03 p 00 <body> 05`,
    `APP→<f><a> 04`; a glyph entry is `NAME 00 <body> 05`, table ends with `00`).
    Closure/glyph bodies are **RET-terminated and skipped by a paren-matching
    scan in the VM**, so the codegen needs no length fields and no arithmetic.
  - **Verified by diffing native output against `RUN_SM`** (`build.sh`): for
    `kernel.la` and two other programs, `codegen.la` compiles to a stream, the
    VM runs it, and the native stdout equals the `.la` stack machine on the same
    program. `kernel.la` runs natively — glyph table, `read_file`, `concat`,
    closures — speaks the Word, and the VM replicates itself.

- **Stage 4 — the compiler and VM regenerate themselves, no C host in the
  loop.** Both `codegen.la` (the compiler) and `secd.la` (which emits the VM)
  are Lingua Adamica programs, so the native compiler can compile both. The
  bootstrap closes:
  - `compiler.bin` —(run on the VM)→ compiles `codegen.la` → `compiler.bin`,
    **byte-identical** (the compiler is a fixed point of itself).
  - `compiler.bin` —(run on the VM)→ compiles `secd.la` → a stream which, run
    on the VM, `write_exec`s the VM → **byte-identical** to the VM (the VM
    re-emits itself). `write_exec` is lowered in the VM (`chmod 0755`); the
    running VM is invoked under a different name so `write_exec("logos_secd")`
    doesn't hit `ETXTBSY` on the live executable.
  - the regenerated VM runs `kernel.la` and speaks the Word.

  `tiny_host` seeds the *first* `compiler.bin` and VM once (every self-hosting
  compiler needs a seed); from there the two native artifacts regenerate each
  other and run programs with **no `tiny_host` and no `nasm`** in the loop.
  `build.sh` proves this end to end: seed once, then regenerate both and run
  `kernel.la` natively.

  The complete cycle:

  ```
  compiler.bin --(native)--> compiles codegen.la --> compiler.bin   (identical)
  compiler.bin --(native)--> compiles secd.la ----> VM emits VM     (identical)
  VM --(native)--> runs any program (kernel.la speaks + replicates)
  ```

  Honest remaining limits: the bump heap still has no GC (fine for short
  bootstrap runs, a ceiling for long-running programs); the native artifact is a
  fixed VM + per-program stream file (not a self-contained executable per
  program — that needs ELF-length patching, deliberately avoided); and the
  *first* seed still comes from `tiny_host` + `nasm` (the irreducible bootstrap
  origin — the loop is closed thereafter, not the genesis).

  *Drift guard:* `secd.la` embeds the exact `nasm -f bin secd.asm` output;
  `build.sh` checks byte-identity when `nasm` is present, so `secd.asm` stays
  the auditable source of the VM's bytes.

  *Known cross-engine divergences (audit, `b_τ ≡ f_τ`):*
  - **Native integers run on all five execution engines.** An integer literal
    `n` desugars at parse time to `str_to_int("n")` (so no new AST node is
    needed anywhere), and the int builtins (`add/sub/mul/div/mod/lt/int_eq/
    int_to_str/str_to_int`) are implemented on each engine:
    - **C host** (`tiny_host.c`): native `N_INT` value + the builtins;
    - **`eval.la`** (meta-evaluator): `VAL_INT` + the builtins;
    - **`codegen.la` → SECD VM** (`secd.asm`): value tag 4 `INT` (payload =
      the signed integer directly), builtins 19–27, reusing `desc_atoi`/
      `push_dec`;
    - **`bytecode.la`** `RUN_BYTES` and `RUN_SM`: `VAL_INT` + the builtins,
      factored into helper glyphs so the existing dispatch chains keep their
      shape.

    `build.sh` verifies all engines agree on the same arithmetic program
    (`44 / 3 / yes`). The lexers use a `str_eq`-only `IS_DIGIT` so the same
    digit-lexing rule holds everywhere, including under the native VM.
  - **`codegen.la` / `bytecode.la` / `parser.la` `PARSE_PROGRAM` silently
    truncate malformed input** (a `NONE` from `PARSE_GLYPH` is treated as
    end-of-program). `eval.la`'s `PARSE_PROGRAM` was fixed to halt via the host
    `error` builtin, but `codegen.la` runs on the VM, which has no `error`
    builtin — so it cannot halt the same way. Closing this needs an `error`/
    abort opcode in `secd.asm`.

  These are documented, not yet fixed, because each fix is a VM (assembly)
  change, deferred under the audit's no-new-features rule.

This extends the **generation** side of the Γ/Ρ split: codegen and ELF assembly
are pure generation (no evaluation); running the emitted binary is recognition
performed by the CPU and OS. `copy_self` already generates a vessel; `elf.la`
lets the system generate a *native* vessel from source.

### LogosInit & process supervision (`logosinit.la`)

The native VM lowers a set of **process/syscall builtins** (VM-only — they have
no meaning under the C host, which runs the other engines): `mount(target)(fstype)`,
`fork("!")` (→ child pid in the parent, `"0"` in the child), `execve(path)`
(replaces the image; `argv=[path]`, empty env; returns `-errno` only on
failure), `waitpid(pid)` (→ that child's exit *status*), `exit(code)`,
`write(fd)(s)`, `open(path)(flags)`, `close(fd)`. Integers cross the LA boundary
as decimal strings.

`reap("!")` is the **orphan-reaping primitive** for an init: it is
`wait4(-1, &status, 0, NULL)` — block until *any* child terminates and return
its **pid** (a negative `-errno`, e.g. `-10 = -ECHILD`, when no children
remain). It differs from `waitpid` deliberately: a supervisor needs the
*identity* of the dead child, not its exit code, and must wait on the whole
child set, not one pid. As PID 1 a process orphaned by an exiting parent is
reparented to the init, so the same `-1` wait reaps orphans too.

`logosinit.la` is a genuine init built from these: it mounts `/proc` and `/sys`
and announces the session, `fork`s + `execve`s `/bin/sh` to spawn a session
shell (exiting `127` in the child if `execve` fails, so a failed exec never
continues as a duplicate init), then runs a **supervision loop that never
exits** — `reap(-1)` in a `Z`-combinator loop, respawning the shell when it (or
nothing) is what died and silently collecting any other reaped orphan. `build.sh`
checks all three: `reap` drains three forked children deterministically then
hits `ECHILD`; under an unprivileged PID namespace (`unshare -rpf`) the init as
PID 1 reaps an orphaned *grandchild* via reparenting (exactly 2 reaps); and the
real `logosinit.la`, run under a `timeout` with the shell's stdin held open,
announces, spawns `/bin/sh` (proving `execve`), and has to be *killed* by the
timeout (rc 124) — proof the supervision loop does not exit on its own.

*Honest limit:* the supervision loop recurses through `Z` with no tail-call
optimisation, so each reaped event consumes one dump-stack frame; the loop runs
for ~1M reap events before the 16 MiB dump is exhausted. A truly unbounded init
waits on TCO or a loop opcode in the VM (a tracked future item).

### Evaluation

The host parses the file into an AST, finds the `MAIN` glyph, and reduces it.
Reduction is eager (call-by-value) with **capture-avoiding substitution**:
when a beta reduction would let a free variable of the argument be captured by
an inner binder, that binder is alpha-renamed to a fresh `_gN` name first.
Glyph names resolve against the global table; `print`/`copy_self` resolve as
built-ins if not shadowed by a glyph.

Sequencing of effects uses `SEQ = la a. la b. b`: naming `a` forces its
effects before `b` is produced, so `SEQ(print(WORD))(copy_self(SELF))` speaks
the Word and *then* replicates.

## Build & run

```sh
./build.sh            # compile, boot kernel.la, verify replication
./tiny_host           # defaults to kernel.la
./tiny_host other.la  # run a different program
```

`build.sh` succeeds only if the kernel prints `I AM THAT I AM`, `new_logos.bin`
is created and is byte-identical to `tiny_host`, and a second-generation copy
reproduces the same Word and the same bytes.

## Debugging Principle

A bug is a **heterological element** — code that does not satisfy its own
specification. Debugging is not trial-and-error; it is the restoration of
autological closure. The test suite (`build.sh`) is the autological criterion:
the system is correct when it satisfies its own description. Every fix should
restore a `PASS` that was `FAIL`.

Meta-debugging (debugging the debugging process) collapses into debugging:
`Meta-Debug(Meta-Debug) = Debug`. If the tests themselves are wrong, fix the
tests first — that is meta-debugging. If the test-fixing process is wrong, that
is still debugging. There is no infinite regress because the criterion grounds
itself: `∃(∃) ≡ ∃`.

Practically:

- Never fix code without running `build.sh` after.
- Never add a feature without adding a test.
- If a test fails, read the error, read the code, identify the heterological
  element (where code diverges from spec), and restore identity.
- If you cannot identify the bug, read the relevant codex in `codices/` to
  verify what the specification actually requires.

## Extending

- New built-ins: add to `is_builtin` and `apply_builtin` in `tiny_host.c`.
- New language forms: extend the lexer (`lex`), parser (`parse_*`), the `Node`
  AST, `eval`, and `subst` together — substitution and evaluation must agree on
  every node kind.
- The host has a **conservative mark-sweep GC** (`gc()` in `tiny_host.c`), so it
  is no longer leak-tolerant: long-running programs run in bounded memory (a
  multi-million-iteration loop holds steady at ~27 MB instead of growing without
  bound). It collects inside `new_node` at an adaptive threshold
  (`GC_MIN_THRESHOLD`), marking from the glyph table plus a conservative scan of
  the C stack + a `setjmp` register dump; values are acyclic trees so nothing is
  missed structurally, and GC-at-an-ordinary-call-boundary makes the scan
  ABI-safe. GC overhead is negligible (raising the threshold 8× left `build.sh`
  wall-time unchanged). The SECD VM (`secd.asm`) now has its own **copying
  garbage collector**, so it too gives bounded memory: the heap is two equal
  semispaces, allocation bumps `r15` inside the active half, and when `r15`
  comes within `margin` (65 MiB, covering `read_file`'s 64 MiB single read) of
  that half's end the collector copies the live set into the other half and
  resumes there. Roots are the operand stack `S`, the environment `E`, and each
  dump frame's saved env; boxed objects (STRDESC/CLO/PA/ENVCELL) carry an
  8-byte forwarding header so sharing is preserved and the DAG is not
  duplicated, while raw DATA byte-buffers carry no header and are copied inline
  by their owning STRDESC (it owns its bytes 1:1, since `str_head`/`str_tail`/
  `chr` copy rather than alias). The collector is type-directed — an object's
  shape is known from the value tag (or kind) that reaches it, so the heap needs
  no per-object size word — and an explicit worklist (`gcwork`, 16 MiB) stands
  in for host recursion, so a deep env chain is traced iteratively without
  overflowing the CPU stack. `build.sh` exercises it with a high-churn loop that
  allocates ~1 GiB of immediately-dead strings and completes in bounded memory
  (the pre-GC bump heap exhausts on the same program). Each semispace is sized
  at 768 MiB (1.5 GiB total, lazily mapped) — equal to the old single bump
  heap — so any workload that fit before the GC still fits in one half even with
  zero reclamation (compiling `secd.la` peaks at ~320 MiB genuinely-live data,
  retained by the VM's non-tail recursion). If the live set itself still doesn't
  fit after a collection, or the worklist overflows, the dispatch loop halts
  loudly with `secd: heap exhausted` rather than corrupting the program stream.
  *Honest remaining limits:* the VM does no tail-call optimisation, so deep
  object-level recursion grows the dump stack (capped at 16 MiB ≈ 1 Mi frames)
  and pins every intermediate env live — the GC reclaims true garbage but cannot
  shrink a genuinely-retained recursion chain.
