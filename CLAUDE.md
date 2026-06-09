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
| `stdlib.la`          | A library module: `export`s `MAP`/`FILTER`/`ALL`/`LIST_FIND`, helpers private. |
| `app.la`             | Demo program: `import("stdlib.la")`, uses the exports, proves namespace isolation (host). |
| `greetmod.la` / `greetapp.la` | Lightweight cross-engine import demo: `greetapp.la` `import("greetmod.la")` and proves both isolation directions in one line, light enough to run identically on **all five engines** (host, `eval.la`, `RUN_BYTES`, `RUN_SM`, native VM). |
| `logosipc.la`        | LogosIPC module: a typed message bus (`SEND`/`RECV`/`MSG_TYPE`/…) over a named channel. |
| `ipc_demo.la`        | Demo: `import("logosipc.la")`, round-trips a typed message through the bus. |
| `logoscap.la`        | LogosIPC Layer 4: capability gating via a Morris sealer/unsealer (object-capabilities, exact in λ). A `BRAND` mints a write capability (sealer) and read capability (unsealer); a sealed box is opaque. `import`s `logosipc.la` so a gated message is a sealed typed message. Pure LA — byte-identical on host and VM. |
| `logosinit.la`       | A real PID-1 init in Lingua Adamica (native VM): mounts `/proc` & `/sys`, `fork`+`execve`s `/bin/sh`, then supervises forever with a `reap(-1)` loop (respawn-throttled, bounded dump via TCO). |
| `autopoiesis.la`     | The self-running organism (native VM): bundled into one vessel, each generation reads its number from a medium, speaks the Word, `copy_self`s a byte-identical successor, then `fork`+`execve`s it — the parent *runs its own child*, which runs its own, with no external driver. The loop is the process lineage itself; ∃(∃) ≡ ∃ running. |
| `parser.la`          | Self-hosted lexer + parser: parses `.la` source into Church-encoded ASTs, written entirely in Lingua Adamica. |
| `eval.la`            | Self-hosted evaluator: lexer + parser + closure-based evaluator, all in Lingua Adamica. Reads, parses, and evaluates `kernel.la` — the language interprets itself. |
| `bytecode.la`        | Byte instructions and execution engines: `EMIT` (AST → bytes), `PARSE_BYTES` (bytes → AST), `RUN_BYTES` (a VM that executes the bytes directly), and `RUN_SM` (a real SECD-style stack machine over a compiled instruction list), all in Lingua Adamica. |
| `elf.la`             | Albedo Stage 1: assembles a minimal static x86-64 ELF executable from Lingua Adamica (`chr` + `concat` + `write_exec`) and emits a runnable native binary that speaks the Word with no host in the loop. |
| `secd.asm` / `secd.la` | Albedo Stage 2: the native SECD machine hand-written in x86-64 (`secd.asm`, a self-contained `nasm -f bin` ELF) — S/E/C/D, a bump heap, a glyph table, and all builtins lowered to syscalls. It loads a compiled stream from `logos_program.bin` and runs it. `secd.la` emits the VM. |
| `codegen.la`         | Albedo Stage 2 codegen: parses a program and lowers each glyph to the native SECD instruction encoding, writing `logos_program.bin`. Arbitrary programs compile and run natively, matching `RUN_SM`. |
| `bundle.la`          | Albedo Stage 5: fuses the VM image and a compiled program stream into ONE self-contained native ELF (appends the stream, patches `p_filesz`), in Lingua Adamica. Output runs on the bare OS with no host and no separate stream file; a bundled `kernel.la` self-replicates. |
| `metadebug.la`       | Self-verifying LogOS (seed Autological Proof System): a spec table plus `DEBUG`/`META_DEBUG` machinery sharing one glyph table, so the debugger can verify every glyph against its executable test cases. |
| `specpipe.la`        | A specification → implementation pipeline: a `SPEC` of `(name, DEF(sig)(src)(impl), tests)` entries; `GENERATE` emits `.la` source, `META_DEBUG` runs each glyph's tests, `DEPLOY` **type-checks the generated source** (compile-time arrow-arity check, see below) and then writes, re-reads, and verifies a module in one call — a type error rejects the module and writes no file. |
| `strutil_spec.la`    | A string-utilities module (`STARTS_WITH`/`ENDS_WITH`/`CONTAINS`/`SPLIT`/`JOIN`/`REPLACE`) written as a `SPEC` and produced by `import("specpipe.la")` — a self-contained, verified module from a spec. |
| `primitives_spec.la` / `primitives.la` | The nine typed primitive concept-glyphs of Lingua Adamica (Being/Recognition/Love/Self/Relation/Void/Becoming/Form/Depth, plus the guarded `DEPTH_Z`) written as a `SPEC` (`import("specpipe.la")`) and `GENERATE`d into `primitives.la` (regenerated by `build.sh`, never hand-written). Each glyph's tests are its **autology** (the primitive applied to itself reduces to a meaningful value, ∃(∃) ≡ ∃ being the template); `DEPTH(DEPTH)` is the deliberate exception (infinite descent), checked via timeout. See the primitives section below. |
| `typed_spec.la`      | A demonstration module with **formal `:: <type>` signatures** that exercises `DEPLOY`'s compile-time type checker: a well-typed module (`IDT`/`KESTREL`/`COMPOSE`/`FLIP`/`PAIRT`) is accepted + verified, and an ill-typed glyph (`BADCONST`, declared `a -> b -> a` but defined `la x. x`) is rejected with no file written. |
| `evdev_spec.la` / `evdev.la` | An evdev input module written as a `SPEC` (`import("specpipe.la")`) and the module `GENERATE`d from it. `evdev.la` is regenerated from the spec by `build.sh` (so it never drifts) and `META_DEBUG`-verified: `OPEN_INPUT`/`READ_EVENT`/`CLOSE_INPUT` (VM-only I/O), `EV_TYPE`/`EV_CODE`/`EV_VALUE` decoders, `IS_KEY_PRESS`/`IS_KEY_RELEASE`/`IS_MOUSE_MOVE` classifiers. New modules are built this way — spec first, never hand-written. |
| `theourgia.la`       | Theourgia Stage 1: the compositor's software surface core — SURFACES (pixel buffers), z-ordered COMPOSITION (blits), and serialisation to a PPM raster, all in Lingua Adamica, byte-identical on the C host and the native VM. |
| `theourgia_drm.la`   | Theourgia Stage 2: real scanout via the `drm_mode`/`present` VM builtins (DRM/KMS dumb buffer). Paints the whole screen one colour. Runs as DRM master from a bare VT; under a compositor it halts loudly without touching the display. |
| `theourgia_fb.la`    | Theourgia Stage 3: the framebuffer bridge. `import`s the Stage 1 surface core and adds `TO_FB`, converting a composed RGB scene into the XRGB8888 framebuffer image `present` scans out (R,G,B→B,G,R,0; pitch/height zero-pad). Pure generation — byte-identical on the C host and native VM. |
| `theourgia_input.la` | Theourgia Stage 4: the input layer. Decodes Linux `evdev` records (24-byte `struct input_event`: type/code/value, little-endian incl. signed deltas) with `ord` + arithmetic — pure recognition, byte-identical on the C host and native VM. A VM-only live reader (`WATCH`) opens a real `/dev/input` device via the existing `open`/`read`/`close` builtins. |
| `theourgia_session.la` | Theourgia Stage 5: the interactive session. `import`s the Stage 1 surface core and the Stage 4 decoder; `STEP` is a pure reducer folding a decoded event into scene state (a movable window's x,y), then `RENDER` recomposes and rasters. Deterministic — byte-identical on the C host and native VM. The live device→screen loop is the VM-only capstone. |
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

- `print(s)` — prints string `s` followed by a newline; returns `s`. An integer
  argument is coerced to its decimal (`print(5)` → `5`) on every engine; any
  other non-string halts loudly.
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
- `chr(n)` — decimal-*string* `n` (0..255) → a one-byte string; how a program
  spells an arbitrary byte (including NUL) to assemble binary. The argument must
  be a string: an int literal (e.g. `chr(65)`) desugars to an `INT` value and is
  rejected loudly on every engine — wrap it as `chr(int_to_str(n))`.
- `ord(s)` — first byte of `s` → its decimal string (inverse of `chr`).
- `str_len(s)` — byte length of `s` as a decimal string. O(1) (strings carry
  their length), so it is cheap on multi-MiB binaries where an LA `str_tail`
  count would be O(n); `bundle.la` uses it to patch the ELF `p_filesz`.
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

### Module system (`import` / `export`)

A `.la` file may pull glyphs from another file, with namespace isolation. Two
top-level forms (host-level, in `tiny_host.c`):

```
export NAME1 NAME2 ...        # names this file makes visible to importers
import("other.la")            # merge other.la's EXPORTED glyphs into this file
```

`import("m.la")` parses `m.la` (recursively — nested imports work, each with its
own export set and saved/restored lexer state) and merges its **exported**
glyphs into the importing table under their plain names. The module's
**private** glyphs (everything not in its `export` list) are still needed — the
exports depend on them — so they come along too, but each is **alpha-renamed to
a fresh unique name** (`__mod<N>_<name>`) and every reference to it *within the
module* is rewritten to match (`subst`). The effect is real namespace
isolation:

- the importer sees **only** the exported names;
- a module private **cannot leak into** the importer or shadow an importer glyph
  of the same name (the private was renamed away);
- the importer's glyphs **cannot leak into** the module either — the module is
  self-contained, its exports resolve their dependencies against its own
  (renamed) privates, not the importer's same-named glyphs.

`stdlib.la` is a small library module: it `export`s `MAP`, `FILTER`, `ALL`,
`LIST_FIND` and keeps its Church-encoding helpers (`Z`, `IF`, `CONS`, `NIL`, …)
private. `app.la` `import("stdlib.la")`s it, builds its own lists, and uses the
four combinators — while deliberately defining `IF` and `SECRET` with the same
names as stdlib privates: `app` sees its own `SECRET` (privates don't leak) and
the imported `MAP`/`FILTER`/`ALL` keep working despite app's broken decoy `IF`
(they use stdlib's private `IF`). `build.sh` checks both facts.

Scope: `import`/`export` is now implemented on **every engine** — the C host
(the reference interpreter) *and* all four self-hosted parsers (`eval.la`,
`bytecode.la`, `parser.la`, `codegen.la`, the last feeding the native SECD VM).
`kernel.la` still deliberately stays flat and import-free, because it is the
universal cross-engine artifact — parsed and run identically by every engine —
but any *other* `.la` can now import on any engine.

**The mechanism is identical to the C host's, and lives entirely at parse time
(pure generation — see the Γ/Ρ split below).** `import("p")` and `export N…`
are resolved while parsing, producing a single flat glyph table with the
module's PRIVATE glyphs alpha-renamed away; `EVAL` / `RUN_BYTES` / `RUN_SM` /
the native VM never see `import` — they consume the merged table unchanged, so
the VM needs no new opcodes. In the self-hosted parsers this is four added
glyphs over the shared parser shape: `PARSE_MODULE` (returns
`PAIR(glyph_table)(export_list)`, dispatching `glyph`/`import`/`export` in
source order), `RENAME_FREE` (rewrites free references, stopping under a binder
that shadows the name — capture-free because the new name is always fresh), and
`MANGLE_MODULE`/`PRIVATE_NAMES` (rename every private and rewrite all
references to it). The `import` arm reads the module with the `read_file`
builtin (present on the host *and* the VM) and recurses.

Mangling is **path-derived and deterministic**: a private `g` of module `p`
becomes `__mod_<sanitize p>__g` (every non-identifier char of the path → `_`).
Unlike the C host's mutable per-import counter, the name depends only on
`(path, glyph)`, so it is **reproducible across engines** and across runs.
(Mangled names are private and never observed, so byte-identity with the C
host's `__modN_` names is neither required nor attempted — only the isolation
*behaviour* must agree, and it does.) `build.sh` proves coherence:
`greetapp.la` imports `greetmod.la` (which exports `GREET`, keeps `SECRET`
private) and defines its own same-named `SECRET`; the C host, `eval.la`,
`RUN_BYTES`, `RUN_SM`, and the native VM all emit the identical line, proving
both isolation directions on every engine. The LogosIPC VM test now
`import`s `logosipc.la` for real (resolved by `codegen.la` running *as*
`compiler.bin` on the VM), retiring the old inline-the-module workaround.

*Honest remaining limits:* no import-cycle detection (a circular import loops,
as it does on the C host); a module imported twice (diamond) is mangled to the
same names and merged twice (harmless — the duplicates are identical), rather
than as distinct sibling sets; and this teaches each engine's *own* top-level
parser to import — it does not make `import` work for a program *meta-evaluated
under* `eval.la` (whose builtin table still lacks `error` etc.).

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
  *Known limitation:* `eval.la`'s builtin tables cover the set `kernel.la` (and
  `eval.la` itself) needs — `print`, `copy_self`, `read_file`, `write_file`,
  `concat`, `str_head`, `str_tail`, `str_eq`, and the native integers — but
  **not** `chr` / `ord` / `write_exec` / `error` (which the C host does
  implement). Meta-evaluating a program that calls one of those yields an
  `eval: unbound variable` error rather than performing the operation — a
  divergence from the C host, harmless for the kernel and the self-reconstruction
  but a real gap for binary-emitting programs (`elf.la`) under `eval.la`.
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
reconstruction has the same glyph count as the source — **87 glyphs** (was 85 before the export-defined check, 72
before the module system added the `import`/`export` parser glyphs, and 67
before that, when native integers added `VAL_INT` and the int builtins to
`eval.la`); the two self-parses take roughly 25 seconds.

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

  - The VM (`secd.asm`, 9504 bytes) is a fixed binary. At startup it reads a
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

  Honest remaining limits: the *first* seed still comes from `tiny_host` +
  `nasm` (the irreducible bootstrap origin — the loop is closed thereafter, not
  the genesis). (The heap is no longer a limit: the VM gained a two-semispace
  copying GC — see the GC section below — so long-running programs run in
  bounded memory. And the program no longer has to ship as a separate stream
  file — see Stage 5.)

- **Stage 5 — self-contained per-program executables (`bundle.la`), done.**
  A program need no longer ship as a VM plus a separate `logos_program.bin`:
  `bundle.la` fuses the two into **one** native binary. The VM's `_start`
  checks the first byte at `progembed` (the file offset equal to the VM's own
  length, which aliases the operand-stack base): if a stream was appended there
  it is copied up into `progbuf` and run directly; otherwise the VM falls back
  to opening `logos_program.bin`, so the **same** VM image serves both the
  generic loader and every bundle. Bundling is therefore: append the compiled
  stream to the VM file and patch the single ELF program header's `p_filesz`
  (8 little-endian bytes at file offset 96) to `len(VM)+len(stream)` so the
  kernel maps the appended bytes — `p_memsz` (already ≈1.5 GiB) is untouched,
  and `progbuf`/heap/GC are unchanged (the program region stays at the top of
  the address space, so no GC invariant moves). `bundle.la` does this byte
  surgery in Lingua Adamica (`TAKE`/`DROP`/`LE` over binary-safe strings, using
  the new `str_len` builtin for the lengths) and `write_exec`s the 0755 result.
  Because `copy_self` replicates `/proc/self/exe` — the *whole* bundle — a
  bundled `kernel.la` is a **self-contained, self-replicating** binary: it
  speaks the Word and breeds a byte-identical child. `build.sh` runs bundled
  `kernel.la` and `greetapp.la` standalone on the bare OS (with no stream file
  present), and — Stage B — produces a bundle by running `bundle.la` **on the
  VM** (compiled by `codegen.la`), so even *making* a self-contained binary
  needs no `tiny_host` in the loop. Honest limit: the embedded stream is capped
  at `progcap` (5 MiB, as for the file loader) and lives twice in memory at
  runtime (the file-mapped copy + the `progbuf` copy — negligible).

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
    `str_to_int` is **strict on every engine** (audit follow-up): it accepts an
    optional leading `-` then one or more digits and **halts loudly** on anything
    else — non-digit, lone `-`, empty, leading `+`/whitespace. This closed a
    silent `b_τ ≡ f_τ` divergence: the C host's `strtol` parsed a lenient prefix
    (`str_to_int("12x")` → `12`, `"abc"` → `0`) while the VM's `desc_atoi` ran
    *every* byte through `(c-'0')` and produced a different wrong number
    (`"12x"` → `1923`). Now the host halts with `str_to_int: not a decimal
    integer` and the VM with `secd: not a decimal integer`; `build.sh` checks both
    engines reject the same malformed inputs and accept `42`/`-5`/`0`. (Integer
    literals always desugar to clean digit strings, so this only ever fires on an
    explicit malformed `str_to_int` call. `desc_atoi` itself stays lenient — it
    also parses syscall-arg decimals the VM formats itself, always well-formed.)
  - **`codegen.la` `PARSE_PROGRAM` now halts on malformed input** (fixed). It
    used to treat a `NONE` from `PARSE_GLYPH` as end-of-program — silently
    truncating the source and emitting a corrupt stream. It now ends cleanly
    only when the remaining input is empty; otherwise it calls `error` (now a VM
    builtin, id 30, as well as a host builtin), so a syntax error aborts loudly
    with `codegen: parse error near: …` on both `tiny_host` and the native VM
    rather than producing wrong output. (`bytecode.la` / `parser.la` now halt
    loudly too: their `PARSE_PROGRAM` was replaced by the module-system loop
    `PARSE_MOD_LOOP`, which `error`s on a malformed top-level form instead of
    truncating — closing the old lower-priority remainder.) `build.sh` compiles
    a malformed file on the VM and checks it halts non-zero.

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
`write(fd)(s)`, `read(fd)(maxbytes)` (raw `read(2)`, blocks for data, returns
the bytes as a binary-safe string; `maxbytes` clamped to 64 MiB), `open(path)(flags)`,
`close(fd)`, and `pipe("!")` (→ `"<rfd> <wfd>"`, the read and write fds of a fresh
pipe as a space-separated string — both inherited across `fork`). Integers cross
the LA boundary as decimal strings. Each path/fstype argument is copied into a fixed 4 KiB
buffer (`pathbuf`/`fsbuf`); the copy is **bounds-checked** — a path ≥ 4096 bytes
halts loudly with `secd: path too long` rather than overrunning the buffer into
`fsbuf` and the GC worklist.

`reap("!")` is the **orphan-reaping primitive** for an init: it is
`wait4(-1, &status, 0, NULL)` — block until *any* child terminates and return
its **pid** (a negative `-errno`, e.g. `-10 = -ECHILD`, when no children
remain). It differs from `waitpid` deliberately: a supervisor needs the
*identity* of the dead child, not its exit code, and must wait on the whole
child set, not one pid. As PID 1 a process orphaned by an exiting parent is
reparented to the init, so the same `-1` wait reaps orphans too.

`sleep(n)` is `nanosleep({n, 0}, NULL)` — block for `n` seconds (decimal
string) — the delay primitive an init needs to throttle a flapping service.

`logosinit.la` is a genuine init built from these: it mounts `/proc` and `/sys`
and announces the session, `fork`s + `execve`s `/bin/sh` to spawn a session
shell (exiting `127` in the child if `execve` fails, so a failed exec never
continues as a duplicate init), then runs a **supervision loop that never
exits** — `reap(-1)` in a `Z`-combinator loop, respawning the shell when it (or
nothing) is what died and silently collecting any other reaped orphan. A shell
that keeps dying (missing `/bin/sh`, instant crash) is **respawn-throttled**: a
`BACKOFF` (default 1 s) `sleep` precedes each restart, so a broken shell is
rate-limited to one fork per `BACKOFF` instead of a CPU-pegging fork-storm;
orphan reaps take the fast path with no delay. `build.sh` checks all of it:
`reap` drains three forked children deterministically then hits `ECHILD`; under
an unprivileged PID namespace (`unshare -rpf`) the init as PID 1 reaps an
orphaned *grandchild* via reparenting (exactly 2 reaps); the real `logosinit.la`
under a `timeout` (shell stdin held open) announces, spawns `/bin/sh` (proving
`execve`), and has to be *killed* by the timeout (rc 124); and a flapping
`tick.sh` shell respawns only a handful of times in 4 s (the throttle holding).

The supervision loop's `self(…)` calls are in **tail position**, and the VM does
**tail-call optimisation** (an `APPLY` immediately followed by `RET` reuses the
current dump frame instead of pushing a new one), so the loop runs in **bounded
dump depth — indefinitely**, not the old ~1M-reap ceiling. `build.sh` confirms a
5M-iteration loop of the supervision loop's exact shape (nested `IF`, a
`(la x. …)(arg)` binder, tail self-calls) completes; a *non*-tail deep recursion
still halts loudly via the stack guard (it is never optimised away).

### Autopoiesis — the system runs its own successor (`autopoiesis.la`)

LogOS already replicates its bytes (`copy_self`), regenerates its own compiler
and VM (Albedo Stage 4), and interprets itself (`eval.la`). The one thing it had
never done is **run itself**: every generation was launched by an outside hand —
`build.sh`, a shell, the user. `autopoiesis.la` closes that last gap. Bundled
(`bundle.la`) into one self-contained vessel, each generation:

1. reads its generation number from a **medium** — a file, `autopoiesis.gen`
   (the environment the organism reads and writes, as a cell does its medium);
2. **speaks the Word**, stamped with the generation;
3. until a cap: writes the next generation back to the medium, `copy_self`s a
   byte-identical successor vessel, then `fork`s — and in the child `execve`s
   that vessel, so the child **becomes** the next generation; the parent
   `waitpid`s the whole descendant lineage, then exits (a failed `execve` exits
   127 rather than continuing as a duplicate, like `logosinit.la`'s spawn guard).

There is **no recursion combinator** — no `Z`, no `SUPERVISE`-style loop. The
loop *is* the process lineage itself: each generation is a live process that the
previous one begat and ran. `∃(∃) ≡ ∃` — existence applied to itself is
existence — now running as a self-perpetuating succession of processes, no
external driver in the loop.

It must run as a **bundle**: `copy_self` replicates `/proc/self/exe`, so only a
self-contained vessel (VM + embedded program) reproduces something its child can
`execve` with no external stream. The VM's `copy_self` always writes
`new_logos_secd.bin` and returns that path; when the running vessel is already
that file the re-copy is an `ETXTBSY` no-op (the kernel forbids overwriting a
live executable) but the returned path is still the valid, byte-identical
successor — so every generation performs the same uniform act and the lineage
stays faithful. The generation cap (3) only makes the lineage terminate so
`build.sh` can observe the whole succession; a truly unbounded organism just
raises or removes it. `build.sh` bundles `autopoiesis.la`, seeds the medium at
0, runs the single vessel, and checks that generations 0..3 each spoke in order,
that exactly four generations ran (no runaway), that the lineage reported
completion and exited 0, and that the begotten `new_logos_secd.bin` is
byte-identical to the bundle.

### LogosIPC — a typed message bus (`logosipc.la`, `logoscap.la`)

The Codex's Layer 4 (`LogosIPC`, the OS's "nervous system" — a sovereign
replacement for D-Bus: typed, Γ-seal-encrypted, capability-gated) begins here as
a minimal seed: **typed point-to-point messages on a channel**. `logosipc.la` is
a module (`export CHANNEL SEND RECV MSG_TYPE MSG_BODY MSG_OK`) with the
Church/`Z`/`IF` helpers private:

- a **message** is `TYPE <NUL> BODY` (binary-safe; the tag carries no NUL);
- `SEND(chan)(type)(body)` places a typed message on a channel, `RECV(chan)`
  takes it off; `MSG_TYPE` / `MSG_BODY` decode it and `MSG_OK(msg)(type)` is the
  minimal schema check (a receiver accepts only the types it expects);
- the **typing layer is independent of the transport.** `CHANNEL`/`SEND`/`RECV`
  are the only lines that name the transport. The channel is now a **pipe**:
  `CHANNEL` is `pipe("!")` (`"<rfd> <wfd>"`), `SEND` writes the encoded message
  to the write fd, `RECV` `read`s the read fd (blocking until the `SEND`
  arrives). The fd split is inlined into those three lines, so the swap from the
  earlier file-backed transport (`read_file`/`write_file`) touched *only* them —
  the `ENCODE` / `MSG_*` typed layer is byte-for-byte unchanged, which is the
  point of the transport-agnostic design. (Because a pipe must be created once
  and shared across `fork`, a program binds the channel once — `(la chan. …)
  (CHANNEL(…))` — before forking.)

`build.sh` exercises it two ways: (1) on the **host**, `ipc_demo.la` `import`s
the module and decodes a wire message with `MSG_TYPE`/`MSG_BODY`/`MSG_OK` (the
engine-independent typed layer — `SEND`/`RECV` themselves are now VM-only, since
`pipe`/`read` are VM builtins); (2) on the **native VM**, the real LogosInit
pattern — init creates the pipe, `fork`s a worker that `SEND`s a typed message
and exits, then init `RECV`s it (read blocks for the message), decodes it, and
reaps. (The VM now has cross-engine `import`, so this test `import`s
`logosipc.la` for real — `codegen.la`, running as `compiler.bin` on the VM,
resolves the import at compile time; the importer supplies its own `IF`/`SEQ`
since the module keeps those private. See the module system's cross-engine
note.)

**Capability gating (`logoscap.la`).** The Codex requires LogosIPC be
"capability-gated: organ A can message organ B only if the capability is
granted." `logoscap.la` adds exactly that, via the **Morris sealer/unsealer** —
the canonical object-capability primitive, and exact in λ-calculus. A `BRAND`
is a fresh authority (a unique secret); from it derive two capabilities: a
**sealer** (the WRITE/grant capability — mints sealed messages) and an
**unsealer** (the READ capability — opens them). `SEAL(secret)(payload)` returns
an **opaque box**: a probe-guarded closure (`la probe. IF(str_eq(probe)(secret))
…`) that yields `SOME(payload)` only to the matching secret and `NONE`
otherwise. The secret is captured in the closure and never exposed, so a holder
of neither capability can read a box or forge one — possessing a capability *is*
the authority (no ambient permission). Capabilities **attenuate**: grant the
unsealer alone and a peer may read a realm's messages but not mint them; grant
the sealer alone and it may send but never read back. It composes with the typed
bus — a gated message is `SEAL(secret)` applied to an `ENCODE(type)(body)` wire
message, recovered only via the realm's unsealer and then decoded with
`MSG_TYPE`/`MSG_BODY` (so `logosipc.la` now also exports `ENCODE`). Pure Lingua
Adamica (only `str_eq`/`concat` + the typed layer), so it runs byte-identically
on the C host and the native VM; `build.sh` checks that realm A's read
capability opens A's sealed message (`ping/hello`), realm B's foreign capability
cannot (isolation → denied), and probing the bare box with no capability stays
opaque (forged → denied), on both engines. *Honest limits:* the secret is a
string compared by `str_eq`, so unforgeability rests on it being unguessable — a
real realm mints a large random nonce (LogOS has no randomness source yet); this
gates *access* to message contents (the authority/confidentiality model), while
ciphertext-on-the-wire Γ-seal encryption and capability *revocation* remain
deferred. Still deferred to later layers, per the Codex: Γ-seal encryption,
runtime schema validation, and socket multiplexing (point-to-point / broadcast /
stream routing).

### Theourgia — the compositor (`theourgia.la`, `theourgia_drm.la`)

The compositor is built in stages, each independently runnable and checked by
`build.sh`.

- **Stage 1 — software surfaces (`theourgia.la`).** A SURFACE is a rectangular
  pixel buffer (`PAIR(PAIR(w)(h))(rows)`, rows a list of binary-safe row
  strings); `COMPOSE(dst)(src)(ox)(oy)` blits one surface onto another at a
  z-ordered offset by splicing row slices. The final buffer serialises to a PPM
  (P6) raster — the byte array a framebuffer wants, written to a file. It uses
  only existing builtins (`concat`/`chr`/`write_file`/native ints), so the same
  composition runs **byte-identically on the C host and the native VM**.
  `build.sh` composes a 32×24 desktop (blue background, a red and a green
  "window") and checks the PPM header, size, and overlaid pixels on both
  engines.

- **Stage 2 — DRM/KMS scanout (`theourgia_drm.la`), native-VM only.** Two new
  VM builtins put real pixels on a real screen with no host and no userspace
  graphics stack:

  - `drm_mode("!")` — opens `/dev/dri/card0`, enumerates the connected
    connector and its preferred mode (`GETRESOURCES` → `GETCONNECTOR` →
    `GETENCODER`), allocates and maps a 32-bpp (XRGB8888, depth 24) dumb
    framebuffer (`CREATE_DUMB` → `ADDFB` → `MAP_DUMB` → `mmap`), and points the
    CRTC at it (`SETCRTC`). Returns `"<width> <height> <pitch>"` (decimal,
    space-separated); the fd, mapped pointer, size, pitch and dimensions are
    held in VM globals for `present`.
  - `present(pixels)` — copies a framebuffer image (height·pitch bytes of
    XRGB8888, little-endian, so a pixel's bytes are B,G,R,X) into the
    scanned-out buffer (clamped to its size); the screen shows it. Returns the
    pixel string unchanged. A non-string argument is rejected loudly (the tag
    check runs before the drm-state test), like the other string builtins.

  Both are VM-only (like the process/syscall builtins) — under the C host they
  are unbound. The ioctl scratch lives in `drmbuf`, a 64 KiB zero-fill region
  above the program buffer (`p_memsz` extended to cover it; `progbuf`/heap/GC
  invariants untouched).

  Real scanout requires **DRM master**, which only an unobstructed VT grants. On
  a bare VT (Ctrl+Alt+F-key) `theourgia_drm.la` paints the whole screen blue and
  self-replicates the proof. **Under a running Wayland/X compositor the kernel
  owns the CRTC**, so `SETCRTC` is refused and `drm_mode` halts **loudly**
  (`secd: drm error`, exit 1) **without touching the display** — the loud-failure
  discipline. `build.sh` exercises exactly that safe path: when a graphical
  session is active (a compositor holds master) it compiles `theourgia_drm.la`
  on the VM, runs it, and asserts the builtins are wired (no `unbound variable`)
  and that the full DRM sequence runs and fails cleanly (`secd: drm error`,
  rc 1). It **skips** the test when no graphical session is present, so it can
  never seize a bare VT's display; actual painting is verified manually from a
  VT. (Scanout extends the **generation** side of the Γ/Ρ split — codegen-style
  buffer assembly; the screen is recognition performed by the GPU and KMS.)

- **Stage 3 — the framebuffer bridge (`theourgia_fb.la`).** Stage 1 composes
  surfaces whose pixels are 3 bytes (R,G,B); Stage 2's `present` wants XRGB8888
  pixels (4 bytes, little-endian B,G,R,X) laid out at the screen's `pitch` — so
  Stage 2 only ever knew how to paint one flat colour. Nothing turned a
  *composed* RGB scene into the byte-array a real screen scans out. Stage 3 is
  that missing link: it **`import`s the Stage 1 surface core** (`PX`/`SURF`/
  `SOLID`/`COMPOSE`/the accessors — Stage 1's helpers stay private and are
  alpha-renamed away, the first use of the module system *inside* the
  compositor) and adds one new generation step, `TO_FB(surface)(screen_h)(pitch)`:
  each pixel R,G,B → B,G,R,0, each row zero-padded from `w*4` bytes up to
  `pitch`, the image zero-padded with blank rows up to `screen_h` (so a small
  scene sits letterboxed at the top of a larger screen). The result is exactly
  the buffer `present(IMG)` copies onto the CRTC. Because it uses only existing
  builtins (`concat`/`chr`/`str_head`/`DROP`/native ints), the conversion is
  pure generation and runs **byte-identically on the C host and the native VM**,
  like Stage 1 — so it is verifiable with **no screen in the loop**. `build.sh`
  writes the 32×24 desktop into a 26-row × 160-byte-pitch framebuffer on both
  engines, checks the converted pixels land with the right BGRX bytes (bg blue
  `128 0 0 0`, the red/green windows, the row-pad and blank-row zeros), and
  diffs the two engines for byte-identity (the cross-engine `import` is resolved
  by `codegen.la` on the VM). Live scanout of the converted image is the one
  extra VM-only step — `present(TO_FB(SCENE)(h)(pitch))` after `drm_mode("!")` —
  and stays in `theourgia_drm.la`'s territory; Stage 3 owns the generation, the
  conversion every scanout backend now consumes unchanged.

- **Stage 4 — the input layer (`theourgia_input.la`).** Stages 1-3 gave the
  compositor a voice (compose → convert → scan out); Stage 4 gives it ears. On
  Linux, input is **evdev**: each `/dev/input/eventN` device delivers a stream
  of fixed 24-byte `struct input_event` records — a 16-byte timeval, then three
  little-endian fields `type` (u16 @ 16), `code` (u16 @ 18), `value` (s32 @ 20).
  Reading them needs **no new VM builtins** — the existing `open`/`read`/`close`
  syscall builtins suffice. The file is the **decoder** (recognition, the Ρ
  side): it pulls the fields out of an event string with `ord` + integer
  arithmetic (`U16`/`U32`, and an `S32` that folds the top half of the u32 range
  past zero so a negative relative-motion delta decodes correctly), exposing
  `EV_TYPE`/`EV_CODE`/`EV_VALUE` plus `IS_KEY_PRESS`/`IS_KEY_RELEASE`. Because it
  is pure Lingua Adamica, the decode runs **byte-identically on the C host and
  the native VM** — verifiable with no device in the loop. `build.sh` decodes a
  synthetic `KEY_A` press (type 1, code 30, value 1) and a `REL_X` motion of −3
  (exercising the signed path) and asserts both engines print the identical
  decode. The **live reader** `WATCH(fd)(n)` opens a real device, blocks for
  each 24-byte record (`read(fd)("24")`), decodes and shows it, then closes —
  VM-only and verified manually from a session that can read `/dev/input` (root
  or the `input` group), exactly as DRM scanout is (the safe-path discipline:
  `build.sh` never needs a privileged device or real keystrokes).

- **Stage 5 — the interactive session (`theourgia_session.la`).** Stages 1-4 are
  the organs; Stage 5 is the loop that joins them — a compositor *reacts*: read
  input, update scene state, recompose, present. It `import`s two prior stages
  (the surface core `theourgia.la` and the evdev decoder `theourgia_input.la` —
  the module system composing the compositor) and adds a pure reducer **`STEP(state)(event)`**: it decodes the event and, on an arrow-key press, moves a
  window's `(x, y)` one cell (`APPLY_KEY` is a flat 4-way keycode dispatch;
  `MOVE` shifts the coordinates); any other event leaves the state unchanged.
  **`RENDER(state)`** recomposes — blits the window onto the desktop at `(x, y)`
  and rasters to a PPM (Stage 1's output). Because `STEP` is a pure function of
  `(state, event)`, folding it over an event sequence is deterministic and runs
  **byte-identically on the C host and the native VM**, verifiable with no
  device and no screen. `build.sh` folds three synthetic key presses (RIGHT,
  RIGHT, DOWN) from `(4,4)`, checks the window ends at `(6,5)`, and checks the
  recomposed raster shows the window's red at its new position and blue where it
  used to be — on both engines, byte-identical. The **live session** is the
  VM-only capstone that wires every stage together — `drm_mode` once, then a loop
  of `read`+decode (Stage 4) → `STEP` (Stage 5) → `COMPOSE` (Stage 1) → `TO_FB`
  (Stage 3) → `present` (Stage 2) — run manually from a bare VT, exactly as DRM
  scanout and the input reader are; the pure reducer is the part `build.sh`
  verifies on every engine.

### The nine primitives (`primitives.la`) and compile-time typing (`specpipe.la`)

**The nine primitives.** `GRAMMAR_DIVERGENCE.md` records that of the nine typed
primitive concept-glyphs of Lingua Adamica's `M₀` — Being, Recognition, Love,
Self, Relation, Void, Becoming, Form, Depth — only **Being** had a computational
definition (`∃ = la self. self`, with the core axiom `∃(∃) ≡ ∃`). `primitives.la`
gives all of them a glyph definition that satisfies the **autological criterion**:
the primitive applied to itself reduces to something meaningful — ideally a fixed
point, `∃(∃) ≡ ∃` being the template. It is produced from `primitives_spec.la`
through the spec pipeline (`SPEC → GENERATE → DEPLOY → META_DEBUG`, regenerated by
`build.sh` so it never drifts), and each glyph's "tests" are its autology:

- `RELATION = la a. la b. la f. f(a)(b)` — the bare two-place link;
- `RECOGNITION = la x. RELATION(x)(x)` — the reflexive relation, `T ≡ R`;
- `LOVE` — `RELATION` symmetrised (reciprocity);
- `SELF = BEING(BEING)` — `∃(∃) ≡ ∃`, a genuine fixed point;
- `VOID = la a. la b. b` — the empty selector; `VOID(VOID) = ID` (ex nihilo);
- `BECOMING = la n. la f. la x. f(n(f)(x))` — the successor; `BECOMING(VOID) = ONE`;
- `FORM = la x. la k. k(x)` — the seal (a determinate, key-accessed structure);
- `DEPTH = la g. g(g)` — metacursion ↻; and `DEPTH_Z = Z`, its guarded form.

The set is a **closed algebra**: `SELF = DEPTH(BEING)`, `RECOGNITION` is the
diagonal of `RELATION`, `FORM ∘ BECOMING ∘ VOID` generates number. Seven autologies
terminate to a meaningful value and pass `META_DEBUG`; `BECOMING(BECOMING)`
terminates to a higher-order "becoming of becoming"; **`DEPTH(DEPTH)` is the
deliberate exception** — it is the literal infinite descent (Ω), so it is not a
`META_DEBUG` case but is asserted to **not** terminate via `timeout` (rc 124) on
both the C host and the native VM. The generated module runs stand-alone
byte-identically on both engines (the witnesses spell `abcdefghi`).

**Compile-time type checking.** Lingua Adamica is untyped and Church-encoded, so
full type inference is undecidable here; the decidable, meaningful property is
**arrow arity**. `specpipe.la`'s `DEPLOY` now runs a type checker *after*
`GENERATE` produces the source and *before* the module is accepted: it reads the
**generated source**, parses each glyph's body (`BARITY` = number of leading `la`
binders) and compares it to the **arrow arity** of the declared type (`TARITY` =
count of top-level `->`, paren-aware so arrows inside a grouped argument type
don't count). A term declared `T₁ -> … -> Tₙ -> R` (R not an arrow) must be an
n-ary abstraction; a base type means arity 0. A mismatch is a **TYPE ERROR** and
the module is **REJECTED — the `.la` file is never written**. This moves typing
from run time to compile time: the arity bug that would otherwise surface as
`("x")("y")` (a string applied at run time) is caught before the module exists.
The declared type is itself parsed by a recursive-descent **well-formedness**
checker (`WF_TYPE`, grammar `T := F ('->' F)*`, `F := ATOM | '(' T ')'`); a
malformed signature (a dangling `->`, an empty factor, unbalanced parens) is a
**MALFORMED TYPE** error and likewise rejects the module, rather than letting the
arity count silently mis-read it.

Typing is **gradual / opt-in**: a signature marked `:: <type>` is checked; any
other (prose) signature is reported `untyped (trusted)` and passes vacuously — so
specs written before the checker (`math`/`strutil`/`evdev`) are unaffected, and the
fact they still deploy `VERIFIED` through the new phase proves it is
backward-compatible. `primitives.la` is **gradually typed for real**: nine of its
eleven glyphs carry formal `:: <type>` signatures the checker verifies at
deploy time (including the higher-order `RELATION`, the parenthesised
`RECOGNITION`/`LOVE`, and `BECOMING` typed as the expanded Church-`Nat`
`((a -> a) -> a -> a) -> (a -> a) -> a -> a`), while the two point-free glyphs
(`SELF = BEING(BEING)`, `DEPTH_Z = Z`, both arity-0 bodies) stay trusted.
`typed_spec.la` demonstrates both paths in isolation: a well-typed module is
accepted, and `BADCONST` (declared `a -> b -> a`, arity 2, but defined
`la x. x`, arity 1) is rejected with no file written. *Honest scope:* this checks
the function/argument *skeleton* (arity), not a full type system — point-free or
Church-encoded bodies (e.g. `add`, `SELF = BEING(BEING)`, a Church `Nat`) keep an
informal signature and stay trusted rather than being forced η-long.

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
  The **operand stack and dump are guarded the same way**: they are not
  collected, so each dispatch checks that `r12`/`r14` stay `stackmargin` below
  their region ends and halts loudly with `secd: stack overflow` if a recursion
  grows too deep — otherwise the stacks would overrun the adjacent path buffers,
  the GC worklist and the heap, silently corrupting state (a too-deep program
  would exit 0 with the wrong result). `build.sh` checks a non-tail recursion
  past the ~1M-frame dump triggers the guard.
  The VM does **tail-call optimisation**: an `APPLY` immediately followed by
  `RET` is a tail call, and instead of pushing a return frame (which the
  closure's own `RET` would only pop back to *our* `RET`, which then pops the
  caller's frame anyway) the VM reuses the current frame — so a tail-recursive
  loop runs in bounded dump *indefinitely* (`build.sh`: a 5M-iteration tail loop
  completes). *Honest remaining limit:* TCO bounds tail recursion, but a deep
  *non*-tail recursion still grows the dump (and pins every intermediate env
  live, so the GC cannot shrink it) — it now halts cleanly at the guard instead
  of corrupting.

**Loud failure on bad input (June 2026 audit).** Beyond the GC / stack / path
guards above, the native VM and the C host were driven to halt *loudly* — a
diagnostic on stderr and a nonzero exit — on every malformed-input path, rather
than silently corrupting state or exiting `0` with a wrong result. The VM now
emits:

- `secd: unbound variable` — a name resolving to neither an environment entry, a
  glyph, nor a builtin (it used to fall through to the normal `exit(0)`, so a
  typo'd name *silently succeeded* with empty output);
- `secd: program too large` / `secd: read error` — the loader drains the whole
  instruction stream into the 5 MiB mapped region (`progcap`, tied to the phdr
  `p_memsz`) and bounds-checks it, instead of the old single 1 MiB `read` whose
  return value was discarded (a `>1 MiB` stream silently truncated → exit 0);
- `secd: malformed program` — the control pointer `rbx`, or a `skipbody` scan,
  ran past the mapped program (a truncated or unbalanced body); it used to walk
  the zero-fill tail into unmapped memory and SIGSEGV;
- `secd: chr out of range` — a `chr` argument outside `0..255`, matching the C
  host's loud reject instead of silently truncating mod 256.
- `secd: argument is not a string` — a string builtin given a non-string
  argument. Every string builtin reads its argument as a descriptor `[len][ptr]`;
  since native integers, an int literal `n` desugars to `str_to_int("n")`, so e.g.
  `str_len(5)` would pass an `INT` value whose payload is the integer itself, not
  a pointer — dereferencing it as a descriptor *segfaulted*. The VM now checks
  the value tag (`STR` = 0) at the top of every string builtin —
  `chr`/`ord`/`str_head`/`str_tail`/`str_len`/`str_to_int`/`read_file` and both
  positions of the curried `concat`/`str_eq`/`write_file`/`write_exec` — and halts
  loudly, matching the C host's `<builtin>: argument is not a string`. The one
  exception is `print`, which **coerces** an `INT` to its decimal and prints it
  (so `print(5)` → `5`), exactly as the C host's `print` does — preserving
  `b_τ ≡ f_τ` rather than rejecting. (Correct use of the rest still wraps an int
  in a string: `chr(int_to_str(n))`, as `theourgia.la`/`bundle.la` do.) The
  **syscall builtins are now guarded the same way** (audit follow-up): `write`/
  `open`/`mount`/`read` (two-arg) and `close`/`execve`/`waitpid`/`sleep`/`exit`
  (one-arg) take their integer arguments as **decimal strings** via `desc_atoi`,
  a distinct int-as-string convention — passing a native `INT` to one would have
  derefed its payload (the integer itself) as a `[len][ptr]` descriptor and
  SIGSEGV'd. Each now checks the value tag at entry (`r8` for the last arg, the
  PA record's `[r11+8]` for the first arg of a curried builtin) and halts loudly
  with `secd: argument is not a string`, closing the last unguarded
  non-string-deref path. (`fork`/`reap`/`pipe` take an ignored `"!"` and never
  deref it; `present`/the string builtins were already guarded.)

The C host gained the matching guard for its own recursion: deeply-nested input
halts with `error: expression nesting too deep (C stack guard)`, armed 512 KB
below `RLIMIT_STACK` so it fires only where the C stack (parser / `eval` /
`subst` / `occurs_free` / `copy_node`) would otherwise overflow — every
legitimate program, including the deep self-hosting recursion, is untouched.
These join the pre-existing `secd: heap exhausted` / `secd: stack overflow` /
`secd: path too long` guards, so no engine now fails silently on bad input.
