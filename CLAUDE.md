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

#### `SHOW_SRC` — the unparser (dual of the parser)

`SHOW_SRC(node)` turns an AST back into Lingua Adamica source text, the exact
inverse of `PARSE_PROGRAM`. Composed, they round-trip: parse-then-unparse
reproduces the original definition byte-for-byte. It parenthesises a lambda
only where the grammar needs it (a lambda in function position,
`(la x. …)(arg)`), and `ESCAPE` re-escapes string literals (`\`, `"`, newline,
tab) so the printed source re-lexes faithfully.

`SHOW_SRC` runs at the **host level**, not under `EVAL`. It must: it
destructures raw Scott-encoded AST nodes by applying them to continuations,
and AST nodes and `VAL_*` values share the same arity but different meaning —
feeding an AST to the meta-evaluator as if it were a value would silently
misinterpret it. So the round-trip lives one level down from `EVAL`, on the
real AST data the host-level parser produces.

#### `INNER` reconstructs its own source

`eval.la`'s last act reads and parses its **own source**
(`PARSE_PROGRAM(read_file("eval.la"))`), pulls out `INNER`'s own AST, and hands
it to `INNER` — whose job is now to unparse a glyph's AST back into source:

```
glyph INNER = la node. concat("glyph INNER = ")(SHOW_SRC(node))
```

Given its own parsed AST, `INNER` reconstructs its own definition verbatim — a
**reconstruction quine**: `eval.la`'s parser parses `INNER` out of `eval.la`,
and `eval.la`'s unparser writes it back exactly as it appears on disk. To prove
the reconstruction is faithful, the harness re-parses that output and
reconstructs again; `build.sh` checks the result equals the actual source line
and that `parse ∘ unparse` is a fixed point on `INNER` (`round-trip: stable`).

The reconstruction targets `INNER` rather than `MAIN`: `MAIN` evaluates
`kernel.la` and reads `eval.la`, so feeding it through the same machinery would
not bottom out. The host-level self-parse of `eval.la` takes a few seconds.

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

## Extending

- New built-ins: add to `is_builtin` and `apply_builtin` in `tiny_host.c`.
- New language forms: extend the lexer (`lex`), parser (`parse_*`), the `Node`
  AST, `eval`, and `subst` together — substitution and evaluation must agree on
  every node kind.
- The host is intentionally leak-tolerant (a short-lived bootstrap process); if
  LogOS grows long-running programs, add reference counting or an arena/GC.
