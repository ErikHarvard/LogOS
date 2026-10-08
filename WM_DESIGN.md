# Theourgia Stage 10 — a tiling window manager with terminals, in Lingua Adamica

Status: design contract for the build (2026-10-08). The modules below are
written against it; where an implementation had to depart from it, the module's
header says so.

## What it is

A full-screen tiling window manager whose windows are terminals, each running a
small shell, `logosh`, written in Lingua Adamica. It runs on the native SECD VM
(the only engine with `drm_mode`/`present`/`poll`/`fork`), on a bare VT, with
the keyboard read straight from evdev:

- `MOD+Enter` opens a terminal by splitting the focused window along its longer
  side; `MOD+q` closes it; `MOD+arrows` (or `h j k l`) moves focus between
  neighbours; `MOD+Shift+arrows` swaps with the neighbour; `MOD+t` turns the
  focused window's split from side-by-side to stacked and back;
  `MOD+-`/`MOD+=` shrink/grow it; `MOD+Tab` cycles focus; `MOD+c` interrupts
  the focused window's running command; `MOD+Shift+e` exits. `MOD` is either
  Super or Alt.
- Typing goes to the focused terminal. `Enter` hands the line to its shell.
  Shell builtins run in-process; other commands are real programs started with
  `fork` + `dup2` + `execv`, their stdout and stderr captured through a pipe
  that the WM's single `poll` loop multiplexes with the keyboard, so a running
  command never freezes the screen or the other windows.

The same loop runs headless (`theourgia_wm_sim.la`): keyboard events come from
a file of 24-byte evdev records, frames go to files instead of `present`. That
is how every part is tested here, with no screen and no keyboard.

## Modules

| File | Role | Engines |
| --- | --- | --- |
| `theourgia_termfont.la` | 96-glyph 8×8 font (codes 32..127; 127 = cursor block) | host, VM |
| `theourgia_tile.la` | the tiling layout: a binary split tree and its operations | host, VM |
| `theourgia_term.la` | the terminal model: output bytes → lines, line editor, keymap, soft wrap | host, VM |
| `theourgia_render.la` | text bands, colour styles, the frame compositor | VM (host only for tiny cases) |
| `logosh.la` | the shell: parsing, builtins, PATH search, spawning jobs | parse/paths: host, VM; the rest VM |
| `theourgia_wm.la` | WM state, key bindings, the poll loop, the tile renderer | VM |
| `theourgia_wm_live.la` | live MAIN: evdev + DRM | VM, bare VT |
| `theourgia_wm_sim.la` | headless MAIN: events from a file, frames to files | VM |
| `drm_bringup_wm.sh` | launcher from a bare VT (greeter stop/restore, tty flush) | — |

Each module except the MAINs exports one constructor, a **kit** (below), plus
any plain data glyphs.

## How fast the VM is, and the rules that follow (measured)

Measured on the kernel-k1 SECD VM with callgrind and gdb, building a 1920×1080
frame full of text:

1. **Naming a builtin scans the whole program.** `PUSHV` looks a name up in the
   environment, then walks the glyph table — and walking past each glyph means
   `skipbody` over its entire compiled body, string literals included — and only
   then the builtin list. In a program of ~100 KB every `add` or `concat`
   reached by name costs tens of microseconds. A glyph name costs a walk up to
   that glyph. In the first prototype these walks were ~70% of all
   instructions.
2. **A glyph is not a cached value.** Naming a glyph re-runs its body. A table
   held in a glyph (a font, a lookup tree) is rebuilt on every reference. The
   first prototype re-decoded its font on every pixel row and ran for 10+
   minutes; building it once and passing it as a value took that to 30 s.
3. **An integer literal is a builtin call.** `1` desugars to `str_to_int("1")`.
4. **`IF` costs far more than applying the boolean.** Same 514k-iteration loop:
   builtins by name 11.4 µs/iteration; builtins as parameters 8 µs; integer
   constants as parameters too 4.3 µs; and the Church boolean applied directly,
   `c(la _. a)(la _. b)(D)`, instead of `IF(c)(…)(…)`: **0.74 µs**.
5. **`concat` copies both operands byte by byte** (7 instructions a byte), so a
   left fold that appends to a growing string is O(n²) bytes. Join pieces with a
   balanced split (O(n log n)); repeat with doubling (`REPEAT2`).
6. **Every closure application allocates, and `CLOSE` scans the body it
   closes.** A curried lambda with many parameters rescans its body once per
   parameter. Keep per-iteration lambdas small and few-parameter.

So all code that runs after startup is written in **kit style**:

- A module exports `NAME_KIT`, a function whose parameters are the builtins and
  constants its code uses (`la concat. la add. … la C0. la C1. …`). Inside, its
  functions are let-bound — `LET(def)(la name. rest)`, top-down — so every name
  they use is found in the environment, never in the glyph table. The kit
  returns a record of its operations: `la sel. sel(op1)(op2)…`.
- The MAIN builds every kit **once** at startup and destructures the records
  once; from then on nothing names a glyph or a builtin.
- Booleans are applied directly to two thunks and a dummy. Constants are
  parameters. Joins are balanced. Tables are built once and passed as values.
- Glyphs that hold large literals (the font) go **last** in a file; a MAIN
  imports the font module last.

Checking it: the gdb trap below lists every name that reaches the glyph table;
in a kit-style program the list stops growing once startup is over.

## Shared encodings

These cross module boundaries, so every module uses exactly these forms
(written inline as lambdas in hot code, rule 1):

- **Boolean:** Church, `TRUE = la t. la f. t`. `int_eq`, `lt`, `str_eq` already
  return these.
- **List:** Scott. `NIL = la n. la c. n(n)`, `CONS(h)(t) = la n. la c. c(h)(t)`.
  Case: `l(la _. if_nil)(la h. la t. if_cons)`.
- **Pair:** `la k. k(a)(b)`. **Record:** `la k. k(f1)(f2)…(fn)`.
- **Pixel:** 4 bytes B, G, R, 0 (XRGB8888 little-endian, what `present` takes).
- **Scanline:** a string of `4·w` bytes for a span of `w` pixels.
- **Integers:** native ints, except at the VM syscall boundary, where
  integers are decimal strings (`fork`, `pipe`, `read`, `waitpid` return
  strings; `waitpid` returns the raw wait status as a decimal string).

## `theourgia_tile.la` — `TILE_KIT`

A layout is a binary tree: `EMPTY` (no windows), `LEAF(id)`, or
`SPLIT(dir)(ratio)(first)(second)` with `dir` 0 = side by side (first left), 1 =
stacked (first on top), and `ratio` the first child's share in permille.
Window ids are positive ints. The kit's record holds:

| op | meaning |
| --- | --- |
| `empty` | the empty tree |
| `insert(t)(focus)(id)(dir)` | split leaf `focus` into `SPLIT(dir)(500)(LEAF focus)(LEAF id)`; on `EMPTY`, `LEAF id` |
| `remove(t)(id)` | drop leaf `id`; its sibling takes the parent's place; the last leaf leaves `EMPTY` |
| `layout(t)(x)(y)(w)(h)(gap)` | list of `la k. k(id)(x)(y)(w)(h)`, leaves in order. Side by side: `w1 = (w-gap)·ratio/1000`, `w2 = w-gap-w1`, second at `x+w1+gap`; stacked likewise on `h`. Sizes never go negative. |
| `neighbour(t)(id)(d)(x)(y)(w)(h)(gap)` | the window next to `id` in direction `d` (0 left, 1 right, 2 up, 3 down), or `id` if none: candidates lie wholly past that edge and overlap on the other axis; nearest wins, then most overlap, then leaf order |
| `swap(t)(a)(b)` | exchange the ids of leaves `a` and `b` |
| `resize(t)(id)(delta)` | grow `id`'s share of its parent split by `delta` permille (shrink if negative), clamped to [100, 900]; no parent → unchanged |
| `toggle(t)(id)` | flip the `dir` of `id`'s parent split |
| `leaves(t)` | ids in order |
| `next(t)(id)` | the leaf after `id`, wrapping around |
| `has(t)(id)` | boolean |
| `count(t)` | number of leaves |
| `show(t)` | canonical text, e.g. `E`, `L1`, `H500(L1,V500(L2,L3))` |

Invariants a gate checks: layout rectangles are disjoint, lie inside the area,
and with the gaps tile it exactly; ids are unique; `count` = length of `leaves`.

## `theourgia_term.la` — `TERM_KIT`

A terminal is a record: completed lines (newest first, at most 500), the
current partial output line, the escape-parser state, the input line, the
prompt, and history. Operations:

| op | meaning |
| --- | --- |
| `new(prompt)` | an empty terminal |
| `write(t)(bytes)` | feed output: printable 32..126 append; `\n` ends the line; `\r` ignored; `\t` pads with spaces to the next multiple of 8; `\b` drops the last char; `ESC [` … final byte 0x40–0x7E skipped (CSI), `ESC` + one byte skipped; other controls and 127 ignored; UTF-8: a lead byte ≥ 0xC0 shows as `?`, continuation bytes 0x80–0xBF are dropped. The escape state survives across calls (a chunk can end mid-sequence). |
| `flush(t)` | if the partial line is non-empty, end it |
| `key(t)(ch)` / `back(t)` / `kill_line(t)` | edit the input line |
| `submit(t)` | `la k. k(line)(t')`: echoes prompt+input as an output line, clears input, records history |
| `hist_prev(t)` / `hist_next(t)` | walk history into the input line |
| `clear(t)` | drop all output lines |
| `set_prompt(t)(p)` | change the prompt |
| `rows(t)(cols)(n)(idle)` | the last `n` display rows, top to bottom, exactly `n` strings, soft-wrapped at `cols` (a logical line of length L > 0 takes ⌈L/cols⌉ rows; an empty line one row). When `idle` is TRUE the last logical line is prompt + input + the cursor (`chr(127)`); otherwise it is the partial output line. Short histories are padded with `""` rows at the top. |
| `keychar(code)(shift)` | evdev key code → the US-layout character, `""` if it types nothing |

## `theourgia_render.la` — `RENDER_KIT`

`RENDER_KIT(...builtins...)(font)(scale)` where `font` is `TF_DECODE`'s result
and `scale` the integer text scale (a glyph is `8·scale` pixels square):

| op | meaning |
| --- | --- |
| `px(r)(g)(b)` | one pixel |
| `run(n)(s)` | `n` copies of `s` (doubling) |
| `style(fg)(bg)` | a text style: every glyph's `8·scale` scanlines in these colours, precomputed once |
| `band(style)(s)(cols)` | list of `8·scale` scanlines, each `cols·8·scale` pixels: the first `min(len s, cols)` characters of `s`, the rest padded in the style's background. A byte outside 32..127 draws as `?`. |
| `bands(style)(cache)(texts)(cols)` | `la k. k(list of bands)(cache')`: `band` for each text, reusing any band in `cache` whose text matches; `cache'` holds exactly the texts used. The caller keeps one cache per window and passes `NIL` when `cols` or the style changes. |
| `solid(w)(h)(px)` | `h` scanlines of one colour (the same string `h` times; no copying) |
| `join(list)` | balanced concatenation |
| `compose(W)(H)(pitch)(bg)(tiles)` | the frame, `H·pitch` bytes: `tiles` is a list of `la k. k(x)(y)(w)(h)(rows)`, `rows` a list of exactly `h` scanlines of `4·w` bytes; tiles lie inside the screen and do not overlap; uncovered pixels are `bg`; each scanline is zero-padded to `pitch` |

## `logosh.la` — `SHELL_KIT` and `SHELL_PURE_KIT`

`SHELL_PURE_KIT(...)` (host and VM): `parse(line)` → list of words (split on
spaces and tabs; `"…"` groups, `\` escapes the next character) and
`normpath(cwd)(path)` → absolute path with `.`, `..` and repeated `/` resolved.

`SHELL_KIT(...builtins, including the VM-only ones...)` (VM):

| op | meaning |
| --- | --- |
| `new(cwd)` | shell state: the working directory and last exit status |
| `prompt(sh)` | e.g. `logos:/home/user$ ` |
| `run(sh)(line)` | `la k. k(sh')(output)(action)`: `output` is text for the terminal (`""` or ending in `\n`); `action` is one of four, Scott-encoded `la none. la clear. la exit. la job. …` with `job(pid)(rfd)` |
| `finish(sh)(pid)` | reap the job: `la k. k(sh')(text)` with `text` `""` on exit 0, else `[exit N]\n` (or `[signal N]\n`) |
| `interrupt(pid)` | send it SIGINT |
| `hangup(pid)` | SIGTERM, for closing a window |

Builtins: `help`, `echo`, `cd` (checked with `stat`; the shell tracks its own
working directory because the VM has no `chdir`), `pwd`, `cat`, `mkdir`,
`rmdir`, `rm`, `mv`, `pid`, `word` (prints `I AM THAT I AM`), `clear`, `exit`.
Anything else is a program: a name containing `/` is a path (relative to the
working directory), otherwise it is looked up in `/bin`, `/usr/bin`,
`/usr/local/bin`, `/sbin`, `/usr/sbin` with `stat` (a regular file with an
execute bit). It is started as `execv("/usr/bin/env")("env -C <cwd> <path>
<args…>")`, stdin `/dev/null`, stdout and stderr the pipe's write end; a failed
`execv` exits 127. Not found: `logosh: NAME: command not found`. `execv` splits
its argument string on spaces, so an argument cannot contain a space; that is
a documented limit.

## `theourgia_wm.la`

State: the tile tree, the focused id, the windows (id, terminal, shell, running
job or none, band cache), the next id, the modifier keys held, and a quit flag.
`WM_KIT` exposes `key(state)(event)` (pure: returns the new state and a list of
effects), the effect runner (VM: spawn, kill, reap), `output(state)(fd)(bytes)`,
`render(state)(dims)`, and `loop(display)(input)`, where `display` is `present`
or a frame-to-file writer and `input` is the list of fds to read events from.
A window's tile: a one-row title bar (id and the shell's directory, or the
running command), then terminal rows; the focused window's bar and border are
highlighted.

Headless mode reads input only while no command is running, so a scripted
session is deterministic; a record with type 85 and code N writes frame N.

## Testing

- One gate per module, `gate_wm_<module>.sh`, sourcing `gate_wm_common.sh`
  (private temp dir, builds the toolchain; `LOGOS_WM_TOOLS` reuses a prebuilt
  one during development).
- Pure logic is checked on the VM and the host and compared. Rendering is
  checked against an independent oracle (Python recomputing the expected pixels
  from the same font table), because the host's substitution is too slow for
  table-heavy code at any useful size.
- Each gate is shown to fail when its module is broken.

Tools for performance work (not part of any gate):

- **Which names reach the glyph table** (works on any VM build): a gdb
  breakpoint on `.pv_glyph` printing `x/s $rbp`; the offset is in a
  `nasm -f bin -l` listing of `secd.asm`.
- **Instruction profile:** callgrind needs a VM that maps its heap at startup
  (PR #5's `LOGOS_HEAP_MB`); kernel-k1's VM has a 1.6 GB `p_memsz` that
  valgrind refuses.
