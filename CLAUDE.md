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
| `logosipc.la`        | LogosIPC module: a typed message bus (`SEND`/`RECV`/`MSG_TYPE`/…) over a named AF_UNIX socket (`CHANNEL`/`ACCEPT` server, `CONNECT` client); the typed layer is transport-agnostic. |
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
| `swc_spec.la` / `swc.la` | **Conservative static SWC checker** written as a `SPEC` and `GENERATE`d into `swc.la` (regenerated by `build.sh`). Two checks *before* evaluation: (a) **ill-foundedness** over lambda ASTs — **WF** (accept), **ILL** (refuse `la g. g(g)`/liar/Ω), **UNKNOWN** (the halting residue, e.g. `Z`); (b) **operator-order** (Grammar of Composition) — the `∂→δ→γ→ρ→𝔄` chain, rejecting integrate-before-bound (Pathology 3, unbounded meaning). Sound; never silently mis-classifies. Byte-identical host/VM. See the SWC section below. |
| `glyphdag_spec.la` / `glyphdag.la` | **The canonical glyph as a single compressing form** — a flat **hash-consed DAG** string `def0;def1;…;defk` (root = last def), written as a `SPEC` and `GENERATE`d into `glyphdag.la` (regenerated by `build.sh`). `DAG` interns a decomposition into the one form (deduplicating shared subterms); `DECOMP` recovers the full etymology tree *from the single form*; `DCOLLAPSE` neologizes two forms into **one** new form, sharing structure. Self-combining grows the form **linearly** while the unfolded tree grows **exponentially** — deep concepts *compress*, not concatenate. Byte-identical on host and VM. See the glyph-DAG section below. |
| `canon_spec.la` / `canon.la` | **κ — canonicalization + etymology-bearing glyphs** written as a `SPEC` (`import("specpipe.la")`) and `GENERATE`d into `canon.la` (regenerated by `build.sh`, never hand-written). κ (`CANON`) maps a *decomposition* (a primitive leaf or a combination via the five modes ⊗/⊕/▷/⊂/↻) to a deterministic canonical glyph **spec**. Identity is the **triple bar**: `IS(a)(b) ≡ str_eq(κa)(κb)` — A IS B iff they canonicalize to the *same glyph*; the **three laws of thought** are theorems over `IS` (each ≡ TRUE); `κ(κ)` is well-defined via `KAPPA`. A finished glyph is a **sealed monoglyph** `MONO(ren)(etym)` whose Ren *is* its etymology by construction (`REN ≡ κ∘ETYM`, autological); `COLLAPSE` neologizes two monoglyphs into one **deeper** monoglyph (not coupling), `DEPTH` measures it, `AUTO_OK` is the autological criterion. Byte-identical on host and VM. See the κ section below. |
| `metalogic_spec.la` / `metalogic.la` | **The three laws of thought as first-class glyphs** — the metalogical ontosyntax (Codex I; *Logos & Paradox*), written as a `SPEC` (`import("specpipe.la")`) and `GENERATE`d into `metalogic.la` (regenerated by `build.sh`). It makes the distinction `canon.la`'s `IS` only gestures at **explicit**: two relations **never conflated** (the category error the TTOE names). **≡ `TRIBAR`** — *ontological identity* over a being's self-grounded **form** (`∃(∃) ≡ ∃` via the `GROUND` rewrite); the metalogical ground, reflexive in the strong sense, not a computation. **= `YIELDS`** — *computational equality*, the operational "yields" relation over **evaluated value**. They genuinely **disagree**: `add(2,3) = 5` (same value) yet `add(2,3) ≢ 5` (different beings); `≡ ⟹ =` but `= ⇏ ≡`. The three laws are glyphs over ≡, each **autological** (holds of its own term): `LAW_IDENTITY` (`A ≡ A`), `LAW_NONCONTRADICTION` (`¬(A ∧ ¬A)` — wired to the **type checker**: `INHABITS` is the arity judgement and `DEPLOY` rejects a type-contradiction), `LAW_EXCLUDED_MIDDLE` (`A ∨ ¬A` — wired to **loud failure**: `VERDICT` is total, `VERDICT_OR_DIE` halts on an ill-formed term). Byte-identical on host and VM. See the three-laws section below. |
| `evdev_spec.la` / `evdev.la` | An evdev input module written as a `SPEC` (`import("specpipe.la")`) and the module `GENERATE`d from it. `evdev.la` is regenerated from the spec by `build.sh` (so it never drifts) and `META_DEBUG`-verified: `OPEN_INPUT`/`READ_EVENT`/`CLOSE_INPUT` (VM-only I/O), `EV_TYPE`/`EV_CODE`/`EV_VALUE` decoders, `IS_KEY_PRESS`/`IS_KEY_RELEASE`/`IS_MOUSE_MOVE` classifiers. New modules are built this way — spec first, never hand-written. |
| `theourgia.la`       | Theourgia Stage 1: the compositor's software surface core — SURFACES (pixel buffers), z-ordered COMPOSITION (blits), and serialisation to a PPM raster, all in Lingua Adamica, byte-identical on the C host and the native VM. |
| `theourgia_drm.la`   | Theourgia Stage 2: real scanout via the `drm_mode`/`present` VM builtins (DRM/KMS dumb buffer). Paints the whole screen one colour. Runs as DRM master from a bare VT; under a compositor it halts loudly without touching the display. |
| `theourgia_fb.la`    | Theourgia Stage 3: the framebuffer bridge. `import`s the Stage 1 surface core and adds `TO_FB`, converting a composed RGB scene into the XRGB8888 framebuffer image `present` scans out (R,G,B→B,G,R,0; pitch/height zero-pad). Pure generation — byte-identical on the C host and native VM. |
| `theourgia_input.la` | Theourgia Stage 4: the input layer. Decodes Linux `evdev` records (24-byte `struct input_event`: type/code/value, little-endian incl. signed deltas) with `ord` + arithmetic — pure recognition, byte-identical on the C host and native VM. A VM-only live reader (`WATCH`) opens a real `/dev/input` device via the existing `open`/`read`/`close` builtins. |
| `theourgia_session.la` | Theourgia Stage 5: the interactive session. `import`s the Stage 1 surface core and the Stage 4 decoder; `STEP` is a pure reducer folding a decoded event into scene state (a movable window's x,y), then `RENDER` recomposes and rasters. Deterministic — byte-identical on the C host and native VM. The live device→screen loop is the VM-only capstone. |
| `theourgia_poll.la` | Theourgia Stage 6: the multiplexed input loop. `import`s the Stage 4 decoder and adds the `poll`-based event loop a real compositor needs — one loop waiting on MANY input devices + a signalfd at once. `poll` speaks a space-separated decimal fd string both ways, so the testable core is the marshalling: `JOIN` (fd list → poll's request, generation) and `SPLIT` (poll's ready-set → fd list, recognition), plus `DRAIN`, a dispatch reducer parameterised by its reader. build.sh drives `DRAIN` with a pure `SIMREAD` — a poll result of two ready fds reads+decodes each through the decoder — byte-identical on host and VM. See the Stage 6 section. |
| `theourgia_poll_live.la` | Theourgia Stage 6 capstone (VM-only, run manually): the real multi-device loop. `import`s the Stage 4 decoder; `MULTIPLEX(fds)` loops `SPLIT(poll(JOIN(fds))("-1"))` then `DRAIN`s each ready fd with a real `read(fd, 24)`, so a keystroke and a mouse move are serviced from one loop, neither blocking the other. Opens two real `/dev/input` devices; run with device-read permission (`sudo`), Ctrl+C to stop. `OPEN_OR_DIE` halts loudly if `open` fails (negative fd) instead of busy-looping. Not in build.sh (needs real devices + a human + loops forever), like DRM scanout. |
| `theourgia_mux_session.la` | Theourgia Stage 7: the multiplexed live session — Stage 6's poll multiplexing wired into Stage 5's session. `import`s the Stage 1 surface core + Stage 4 decoder; the new heart is **`DRAIN_STEP`**, which folds `STEP` over every ready fd in one poll cycle, threading the scene state — so a single cycle reporting two ready devices applies BOTH their events before rendering. build.sh drives it with a pure `SIMREAD`: a poll cycle reporting fds `"5 7"` (RIGHT press + DOWN press) moves the window (4,4)→(5,5), recomposed byte-identical on host and VM. The `LIVE` loop (VM-only, manual VT) is `drm_mode` → poll/drain/`STEP`/compose/`TO_FB`/`present` forever. See the Stage 7 section. |
| `theourgia_mux_session_live.la` | Theourgia Stage 7 capstone (VM-only, run manually): the runnable live device→screen session. Carries the same verified Stage 7 machinery (`DRAIN_STEP`/`STEP`/`TO_FB`/`LIVE`) and adds a live MAIN that opens two real `/dev/input` devices (`OPEN_OR_DIE` halts loudly on a permission failure *before* taking the screen), `drm_mode`s as DRM master, and runs `LIVE` forever — poll every device → fold every ready event into the scene → recompose → `present`. Arrow keys move the window; run from a bare VT with `sudo`, Ctrl+C to stop. Not in build.sh (needs a bare VT + real devices + loops forever), like `theourgia_drm.la`. |
| `theourgia_font.la`  | Theourgia Stage 8 font: an EMBEDDED 8×8 bitmap font as pure data + lookup (no font-file parsing yet). A–Z, 0–9, space; one bit per pixel (bit 0 = leftmost); unknown chars blank. Packed as ONE flat decimal string (`FONTDATA`, 37×8 = 296 bytes) decoded by `BYTES` — the `secd.la` flat-literal form, so it compiles fast and costs nothing to drag through the import-mangler (a deeply-nested assoc-list font made codegen of any importer pathologically slow). `import`s NOTHING, so a glyphs-only consumer (the live renderer) imports just this, not Stage 1. Exports `GLYPH_ROW(c)(r)` (row-byte r of char c), `BIT(rowbyte)(col)`, `FW`/`FH`. Pure LA — byte-identical host/VM. |
| `theourgia_text.la`  | Theourgia Stage 8: text rendering onto surfaces. `import`s the font + the Stage 1 surface core and adds `DRAW_TEXT(dst)(text)(x)(y)(fg)(bg)` — builds an FH-tall ribbon (`TEXT_SURFACE`: set→fg, unset→bg) and `COMPOSE`s it onto a Stage 1 surface. Pure generation (concat / native ints), so it rasters byte-identically on the C host and native VM, verifiable with no screen. `build.sh` draws "HI" onto a 24×12 surface and checks the glyph shape (row-dependent) and the second char's advance, byte-identical on both engines. |
| `theourgia_text_live.la` | Theourgia Stage 8 capstone (VM-only, run manually): draw text to a real screen. `import`s JUST the font (`GLYPH_ROW`/`BIT` — not Stage 1, so it stays lean to compile), takes the screen with `drm_mode`, builds a full-screen XRGB8888 framebuffer DIRECTLY (a blue desktop + a red window) — only the 8 text rows are special-cased, so the frame stays O(screen), like the Stage 7 live renderer — rasters "I AM THAT I AM" into the window in white, `present`s it, and HOLDS until Ctrl+C. Run from a bare VT (`drm_bringup_text.sh`), like the other live capstones. |
| `theourgia_text_session_live.la` | Theourgia Stage 9 capstone (VM-only, run manually): a **movable text window** — the foundation for a terminal. Fuses the Stage 7 live multiplexed session and the Stage 8 font into one program: `import`s the Stage 4 decoder + the font (`GLYPH_ROW`/`BIT`), draws "I AM THAT I AM" in a red window on a blue desktop, and moves the WHOLE window (text included) 40px per arrow-key press via the verified `STEP`/`APPLY_KEY`/`DRAIN_STEP` reducer + `poll` loop. The window self-sizes to the string with a symmetric inset; the frame stays O(screen) (only the `FH` text rows are special-cased), clamped on at render time. Launch from a bare VT with `drm_bringup_term.sh` (same greeter-stop/restore trap as the other live capstones). Not in `build.sh` (needs a bare VT + real devices + loops forever); the pure render geometry (frame = `h×pitch`, desktop/window/text pixels) is verifiable host-side with no screen. |
| `sigil.la`           | **The visual modality of Lingua Adamica** (`LINGUA_ADAMICA.tex`) — the rendering layer `canon.la` deferred to "Theourgia". The **nine primitive sigils** are **DRAWN exactly as the Sigil Catalogue specifies** (Ch. "The Nine Sigils"): Being=circle+point+ouroboric curl, Recognition=the eye, Love=the flame, Self=the lemniscate (∞), Relation=two points+double arc, Void=broken circle (gap at the crown), Becoming=spiral+arrow, Form=triangle-in-circle, Depth=nested descending circles — transcribed, not invented. **DERIVED concepts are GENERATED** from them: `SIGIL` walks a κ-decomposition (the SAME Scott-encoded `PRIM`/`SYN`/`CON`/`DIR`/`CONT`/`MC` nodes `canon.la`'s `CANON` walks) and combines forms via the **five blend modes aligned to the TopoEmbed Graph-Feature→Geometric-Primitive table**: ⊗ interpenetration (cycles→closed loops), ⊕ symmetric placement, ▷ branching paths, ⊂ nested containment, ↻ self-folding. A `SIGIL` is a pure `r->c->bool` predicate over a **32×32** grid built only from integer drawing primitives (`BOXR`/`DOT`/`SEG`/`DISK`/`RING`/`ARC`/`FRAME`/`PLACE`, the lemniscate/flame as integer formulae, the spiral as a polyline), so a sigil and its ASCII rasterisation are byte-identical on the C host and native VM (form is 1-bit; the catalogue's colour layer is honestly dropped). `MAIN` renders the nine + four derived concepts (Truth/Consciousness/Beauty/Being²). `build.sh` verifies each primitive against its catalogue description by its distinctive **symmetry signature** (Self/Recognition/Relation H+V; Void/Love/Form H-only — gap/tip up; Becoming neither — chiral; Truth=↻(Recognition) H — self-fold generated), byte-identical on host and native VM. |
| `sigil_live.la`      | The sigil visual-modality capstone (VM-only, run manually): draw a `SIGIL` to a real screen. `import`s `sigil.la` (`SIGIL`/`SIG_AT`/`SZ`/`PRIM`/…), takes the screen with `drm_mode`, and rasters g1 Being (the catalogue's circle+point+curl) DIRECTLY into the XRGB8888 framebuffer — each `SZ×SZ` (32×32) cell blown up to a `SCALE×SCALE` block, the sigil centred on a dark indigo field in warm gold — then `present`s it and HOLDS until Ctrl+C. The frame is built with `REPEAT2` runs so it stays O(screen), like `theourgia_text_live.la`. Launch from a bare VT with `drm_bringup_sigil.sh` (same greeter-stop/restore trap as the other live capstones). Not in `build.sh` (needs a bare VT + DRM master + loops forever); the sigil shapes it draws are the part `sigil.la` build-verifies on every engine. |
| `phonym.la`          | **The phonological modality of Lingua Adamica** — the third mode of the trimodal language (visual=`sigil.la`, computational=`primitives.la`, phonological=here). It **SYNTHESISES the nine primitive phonyms as actual sound** (Ch. "The Phonym" / §"Nine Primitive Phonyms"): Being /ɑ/, Recognition /ʃi/, Love /lu/, Self /mɑ/, Relation /ʀa/, Void /hɑ/, Becoming /vu/, Form /tɑ/, Depth /dɔ/ — each rendered from its phonetic parameters (formant spectrum F1/F2/F3, glottal pitch f0, ADSR contour) via **pure fixed-point integer DSP**: formant synthesis (a parabolic-sine table-free oscillator, spectrally verified to place formants on target), fricative noise (a deterministic stateless hash) for /ʃ h v/, a nasal murmur for /m/, a uvular trill for /ʀ/, plosive bursts for /t d/. Samples are a pure function of index (phase = i·inc, stateless), assembled 16-bit-LE into a **byte-identical-on-host-and-VM** WAV via a divide-and-conquer O(n log n) builder (the audio analogue of `theourgia.la`'s PPM generation). **PSC\*** is the audio twin of TopoEmbed: `PHONYM` walks the SAME κ-decomposition nodes `SIGIL` walks, and a compound's phonym is GENERATED by blending its constituents via the **Operator Phonology** (⊗ smooth fusion · ⊕ glottal-pause /ʔ/ · ▷ stress-link · ⊂ `B[A]B` framing · ↻ reduplication `AA`); `PSC_STAR(node)` returns `(WAV, witness)` where the witness is the κ-spec the phonym was built from (`PSC*` "the runtime proving itself"). `MAIN` writes nine primitives + three generated phonyms (Compassion=Love⊗Recognition, Truth=↻Recognition, Recognition⊂Being). `build.sh` verifies the WAV structure + the five operator-mode witnesses, byte-identical host==VM. Hear it via `bringup_phonym.sh` (synthesises on the VM, plays with `aplay` — no VT needed). |
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

  - The VM (`secd.asm`, 13775 bytes) is a fixed binary. At startup it reads a
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
`close(fd)`, `pipe("!")` (→ `"<rfd> <wfd>"`, the read and write fds of a fresh
pipe as a space-separated string — both inherited across `fork`), and
`unlink(path)` (remove a filesystem name → `0`, or `-errno` such as `-2` =
`-ENOENT` when absent — the companion to `bind`, letting an AF_UNIX server
self-clean its stale rendezvous path via the canonical `unlink; bind`), and
`random(n)` (→ `min(n, 256)` cryptographically-random bytes via `getrandom(2)`,
flags 0 / urandom source, as a binary-safe string — a real **entropy source**,
clamped to 256 because `getrandom` fills a request that size atomically. This is
the substrate primitive an **unforgeable capability nonce** needs: `logoscap.la`'s
`BRAND` can mint `random("32")` instead of a fixed `str_eq`'d secret, closing the
"no randomness source yet" gap). Integers cross
the LA boundary as decimal strings. Each path/fstype argument is copied into a fixed 4 KiB
buffer (`pathbuf`/`fsbuf`); the copy is **bounds-checked** — a path ≥ 4096 bytes
halts loudly with `secd: path too long` rather than overrunning the buffer into
`fsbuf` and the GC worklist.

It lowers a **Tier-0 filesystem layer** (VM-only) over the same conventions —
paths as binary-safe strings (copied into `pathbuf`/`fsbuf`, bounds-checked like
the rest), integer args as decimal strings, every call returning `0`/the result
value or `-errno` as a decimal string, and a non-string argument halting loudly
with `secd: argument is not a string`: `mkdir(path)(mode)` (syscall 83),
`rmdir(path)` (84), `rename(old)(new)` (82, old in `pathbuf`, new in `fsbuf` like
`mount`'s two paths), `chmod(path)(mode)` (90), `lseek(fd)(offset)` (8, whence
fixed to `SEEK_SET` — the common case; returns the new offset), and
`stat(path)` (4), which returns `"<st_mode> <st_size>"` (two decimals, e.g.
`16895 4096` = `S_IFDIR|0777` and the size) or `-errno` (`-2` = `-ENOENT`). The
`struct stat` lands in `fsbuf`; `st_mode` is the u32 at offset 24, `st_size` the
s64 at offset 48. With them LogOS can create/remove/move/inspect/permission-set
and seek within files natively — the substrate a real filesystem-using program
(or a self-hosting build) needs.

It also lowers a **Tier-0 signal layer** (VM-only). A pure call-by-value closure
machine cannot host an *asynchronous* handler, so signals use the **synchronous,
fd-based** model: `sigprocmask(how)(mask)` (rt_sigprocmask, 14) blocks/unblocks a
signal set (`how` 0/1/2 = BLOCK/UNBLOCK/SETMASK; `mask` a 64-bit sigset as a
decimal — bit `signo-1` selects a signal, built in `pathbuf`), then
`signalfd(mask)` (signalfd4, 289, fd −1 / flags 0) returns an fd from which the
existing `read(fd)("128")` drains one 128-byte `signalfd_siginfo` per pending
signal (`ssi_signo` is the first u32, little-endian, so `ord(str_head(·))` is the
signal number for `signo < 256`). `kill(pid)(sig)` (62) sends, and `getpid("!")`
(39, arg ignored) lets a process address itself — so a process can block a
signal, arm a signalfd, signal itself, and read it back, all without an async
trampoline. This is what an init or supervisor wants: block `SIGCHLD`/`SIGTERM`,
then handle them off an fd in the normal `read` loop. `build.sh` runs exactly
this round-trip on the native VM (mkdir→…→rmdir, open/lseek/read, then block
SIGUSR1 / signalfd / kill self / read back `signo=10`), plus the loud-halt path
for a non-string argument.

It also lowers a **local-socket layer** (AF_UNIX, `SOCK_STREAM`) — the Tier-0
transport the LogosIPC bus can route over instead of a single `pipe`:
`socket("!")` (→ a fresh socket fd), `bind(fd)(path)` and `connect(fd)(path)`
(a filesystem `path` becomes the rendezvous — a `sockaddr_un` is built in
`pathbuf`, `sun_path` bounds-checked ≤ 107 bytes), `listen(fd)` (backlog 16),
`accept(fd)` (→ a fresh per-connection fd), `send(fd)(data)` (`sendto`, → bytes
sent) and `recv(fd)(maxbytes)` (`recvfrom`, → the bytes as a binary-safe string,
clamped to 64 MiB like `read`). fds cross as decimal strings; every call returns
`-errno` as a decimal string on failure (e.g. `connect` to a dead path → `-2`)
rather than halting, so a program can **recognise** a dead peer — but a
non-string fd/path/data argument halts loudly with `secd: argument is not a
string`, like the other guarded builtins. A minimal server binds + listens
**before** `fork`ing so the child's `connect` can't race ahead of `accept`;
`build.sh` runs exactly that client→server message pass on the native VM,
plus the two failure paths. *Honest limits:* AF_UNIX only (no IP/TCP yet),
pathname sockets only (no abstract namespace, so a stale socket file must be
unlinked before re-`bind` — the VM has no `unlink` builtin yet), and no
partial-send/EINTR retry loop.

It also lowers **`poll(fds)(timeout)`** (poll, 7) — the **fd-multiplexing**
primitive that ties the signal, socket, and input layers into ONE event loop. A
real event-driven process (a compositor, a supervisor) waits on MANY fds at once
— a signalfd, several `/dev/input` devices, sockets — and services whichever
becomes readable, never blocking on one while another has data. `poll` is the
syscall for that, and it is kept **stateless** to fit the functional LA model
(unlike `epoll`, whose kernel-side registered set needs a persistent epoll fd +
`epoll_ctl` registration calls): it speaks a **space-separated decimal string**
both ways. `fds` is the watched set (each watched for `POLLIN`); `timeout` is
milliseconds (`-1` blocks forever). It returns the space-separated decimals of
the fds that became ready (`revents != 0`, so a `POLLHUP`/`POLLERR` closed peer
also surfaces — the loop reads it and sees EOF), the **empty string** on a
timeout with none ready, or `-errno` on error. The pollfd array is built in
`pathbuf` (8 bytes each), **capped at 512 fds** — more halts loudly with `secd:
too many poll fds` rather than overrunning the buffer; a non-string `fds`/`timeout`
argument halts loudly with `secd: argument is not a string`, like the other
guarded builtins. `build.sh` exercises it on the native VM with two signalfds:
an idle poll times out to `""`, then after raising SIGUSR1, polling BOTH fds
returns *only* the ready one (multiplex + selectivity), plus the non-string
loud-halt path. This is what `theourgia_poll.la` (Stage 6) marshals over: `JOIN`
builds the request, `SPLIT` recognises the ready-set, `DRAIN` dispatches each.

`reap("!")` is the **orphan-reaping primitive** for an init: it is
`wait4(-1, &status, 0, NULL)` — block until *any* child terminates and return
its **pid** (a negative `-errno`, e.g. `-10 = -ECHILD`, when no children
remain). It differs from `waitpid` deliberately: a supervisor needs the
*identity* of the dead child, not its exit code, and must wait on the whole
child set, not one pid. As PID 1 a process orphaned by an exiting parent is
reparented to the init, so the same `-1` wait reaps orphans too.

`reapnb("!")` is `reap`'s **non-blocking** twin — `wait4(-1, &status, WNOHANG,
NULL)` — returning a ready child's **pid**, `"0"` when children exist but none
have terminated yet, or `-ECHILD` when there are none. It is what the
**signalfd-driven** init needs: once `SIGCHLD` is *blocked* (so it can be read
off a signalfd rather than interrupting a blocking `wait4`), and because pending
`SIGCHLD`s **coalesce** (several deaths can fold into one signal), each `SIGCHLD`
must **drain every ready child** in a `reapnb` loop — which only a non-blocking
reap allows.

`sleep(n)` is `nanosleep({n, 0}, NULL)` — block for `n` seconds (decimal
string) — the delay primitive an init needs to throttle a flapping service.

`logosinit.la` is a genuine init built from these: it mounts `/proc` and `/sys`,
**`sigprocmask`-blocks `SIGTERM`+`SIGCHLD` and opens a `signalfd` for them
*before* any fork** (so a child dying the instant it spawns can't lose its
`SIGCHLD`, and so init becomes killable by `SIGTERM` at all — the kernel
discards a signal to PID 1 with no installed handler, and the signalfd *is* the
handler), announces the session, then `fork`s + `execve`s `/bin/sh` (the child
first **un**blocks the signals so the shell gets a clean mask, and exits `127`
if `execve` fails so a failed exec never continues as a duplicate init). It then
runs a **signalfd supervision loop**: it blocks on `read(sigfd)("128")` — one
`signalfd_siginfo` per signal — and dispatches on `ssi_signo` (the first byte).
On **`SIGCHLD`** it drains *every* ready child with `reapnb` (coalesced deaths),
respawns the shell if it was among them, and silently collects reparented
orphans; a shell that keeps dying is **respawn-throttled** by a `BACKOFF`
(default 1 s) `sleep` before each restart, so a broken shell is rate-limited to
one fork per `BACKOFF` instead of a CPU-pegging fork-storm. On **`SIGTERM`** it
shuts the session down **cleanly** — announces, sends the shell `SIGTERM`, and
**exits 0**; this is the one path out of the loop. Absent a `SIGTERM` the loop
never exits. `build.sh` checks all of it: `reap` drains three forked children
deterministically then hits `ECHILD`; `reapnb` is `-ECHILD`/pid/`-ECHILD` across
an empty→ready→drained child set; under an unprivileged PID namespace
(`unshare -rpf`) the init as PID 1 reaps an orphaned *grandchild* via
reparenting (exactly 2 reaps); the real `logosinit.la` announces, spawns
`/bin/sh` (proving `execve`), stays alive supervising with no signal, and on an
explicit `SIGTERM` prints its shutdown line and **exits 0**; and a flapping
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
a module (`export CHANNEL CONNECT ACCEPT SEND RECV MSG_TYPE MSG_BODY MSG_OK
ENCODE`) with the Church/`Z`/`IF`/`SEQ` helpers private:

- a **message** is `TYPE <NUL> BODY` (binary-safe; the tag carries no NUL);
- `SEND(conn)(type)(body)` places a typed message on a connection, `RECV(conn)`
  takes it off; `MSG_TYPE` / `MSG_BODY` decode it and `MSG_OK(msg)(type)` is the
  minimal schema check (a receiver accepts only the types it expects);
- the **typing layer is independent of the transport.** Only the transport
  glyphs name the transport. The channel is now a **named AF_UNIX socket**: a
  channel name maps to a rendezvous path, `CHANNEL(name)` is the **server**
  (`socket` + `bind` + `listen` → the listening fd), `ACCEPT(srv)` blocks for a
  client and yields a per-connection fd, and `CONNECT(name)` is the **client**
  (`socket` + `connect` → its own per-connection fd). `SEND`/`RECV` then act on
  that one **bidirectional** connection fd — *simpler* than the pipe, which
  needed an `<rfd> <wfd>` split. The swap from the earlier pipe transport
  (itself from a file-backed one) touched *only* the transport lines — the
  `ENCODE` / `MSG_*` typed layer is byte-for-byte unchanged across **all three**
  transports, which is the whole point of the transport-agnostic design. Unlike
  a pipe (one fd pair shared across `fork`), a socket reaches **unrelated
  processes by name** — what the Codex's "organ A messages organ B" actually
  needs. A server must `bind`+`listen` **before** `fork`ing so a client's
  `connect` can't race ahead of `accept`. `CHANNEL` is **self-cleaning**: it
  `unlink`s the rendezvous path before `bind` (the canonical `unlink; bind`
  idiom), so a **stale socket file** from a prior run no longer blocks a re-`bind`
  — `build.sh` proves it by seeding a stale file at the path and still passing
  the message through. *Honest limit:* pathname sockets only (no abstract
  namespace).

`build.sh` exercises it two ways: (1) on the **host**, `ipc_demo.la` `import`s
the module and decodes a wire message with `MSG_TYPE`/`MSG_BODY`/`MSG_OK` (the
engine-independent typed layer — the transport glyphs come in but are never
called, so the VM-only socket builtins are never resolved on the host); (2) on
the **native VM**, the real LogosInit pattern — init (server) `CHANNEL`s
(`bind`+`listen`) **before** forking a worker (client) that `CONNECT`s and
`SEND`s a typed message and exits; init `ACCEPT`s and `RECV`s it (blocking for
the connection + message), decodes it, and reaps. (The VM has cross-engine
`import`, so this test `import`s `logosipc.la` for real — `codegen.la`, running
as `compiler.bin` on the VM, resolves the import at compile time; the importer
supplies its own `IF`/`SEQ` since the module keeps those private. See the module
system's cross-engine note.)

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
opaque (forged → denied), on both engines. The secret is a string compared by
`str_eq`, so unforgeability rests on it being unguessable: `BRAND(secret)` takes
an explicit secret (pure, cross-engine), and **`MINT("!")` brands a realm with a
fresh 32-byte random nonce** from the `random` entropy builtin — closing the
former "no randomness source" gap (two `MINT`s give independent nonces 2^256
apart, so distinct realms cannot read each other's boxes; `build.sh` runs the
random-nonce demo on the VM, where the foreign-realm `denied` *proves* the two
nonces differ). `MINT` is VM-only (`random` is a VM syscall builtin); the
sealer/unsealer mechanism stays pure and cross-engine. *Honest limits:* this
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
    scanned-out buffer (clamped to its size), then issues `DRM_IOCTL_MODE_DIRTYFB`
    to flush the write to the panel; the screen shows it. The dirty is essential
    because `present` writes *after* `drm_mode`'s `SETCRTC`, and a shadow-fb
    driver (simpledrm/EFI-GOP, virtio, …) only re-fetches the mapped buffer on a
    modeset or an explicit dirty — without it the pixels never reach the panel
    and the screen stays black though every ioctl succeeds (a direct-scanout
    driver returns `-ENOSYS`, harmlessly ignored). Returns the
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

  **Verified end-to-end on real hardware (2026-06-12).** Run from a bare VT via
  `drm_bringup.sh` (stops `cosmic-greeter` to free the GPU, restores it on any
  exit via a trap), both the C reference and the clean LogOS VM painted the full
  screen blue, then the greeter came back cleanly — two blue flashes, scanout
  path confirmed. The earlier black screen was **not a code bug**: it was GPU
  contention from the live desktop session (cosmic-comp holding DRM master). The
  fix is operational, not a patch — run from a free VT so the VM can become DRM
  master. `drm_bringup.sh` encodes that discipline (it refuses to run from inside
  the graphical session, where stopping the greeter would strand you).

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

- **Stage 6 — the multiplexed input loop (`theourgia_poll.la`).** Stages 4-5
  read a *single* input device with one blocking `read`. A real compositor has
  MANY input devices — a keyboard, a mouse, a touchpad — plus a signalfd, and it
  must service whichever is ready, never blocking on one while another has input
  waiting. That is **fd multiplexing**, and the `poll` VM builtin (added with
  this stage — see the syscall section) is the primitive. `poll` speaks a
  **space-separated decimal fd string** both ways, so the pure, testable core of
  the stage is the marshalling between an fd *list* and poll's wire form — a
  clean **Γ/Ρ split**: **`JOIN`** (fd list → poll's request, *generation*) and
  **`SPLIT`** (poll's ready-set → fd list, *recognition*), plus **`DRAIN`**, the
  dispatch reducer that services each ready fd in turn. `DRAIN` is
  **parameterised by its reader**, so the *same* loop body runs two ways: a pure
  `SIMREAD` (fd → a synthetic event) under `build.sh`, and the real
  `read(fd, 24)` in the live loop. It `import`s the Stage 4 decoder so each
  multiplexed fd's bytes decode through the same recognition layer (the module
  system composing the compositor, as Stage 5 does). Because the core is pure
  Lingua Adamica, it runs **byte-identically on the C host and the native VM**:
  `build.sh` checks `JOIN`, the `SPLIT∘JOIN` round-trip, the empty (timeout)
  ready-set, and the headline — a poll result of `"7 5"` drains BOTH devices,
  fd 7 (mouse, REL_X −3) then fd 5 (keyboard, KEY_A press), each routed through
  the decoder. The **live multi-device loop** (`theourgia_poll_live.la`,
  VM-only) is the capstone: `MULTIPLEX(fds)` loops `SPLIT(poll(JOIN(fds))("-1"))`
  then `DRAIN`s every ready fd with a real `read` — its `self(fds)` is in tail
  position and the VM does TCO, so it runs forever in bounded dump depth. It
  opens two real `/dev/input` devices and is run manually with device-read
  permission (`sudo`), exactly as DRM scanout and the Stage 4/5 readers are; the
  marshalling + dispatch it drives live is the part `build.sh` verifies on every
  engine. `OPEN_OR_DIE` halts loudly (the `error` builtin) when `open` returns a
  negative fd, so a no-permission run fails clean rather than busy-looping on the
  invalid descriptor.

- **Stage 7 — the multiplexed live session (`theourgia_mux_session.la`).** Stage
  5 reacts to *one* input device; Stage 6 made one loop wait on *many*. Stage 7
  **wires the two together**: a real compositor polls every input device, and
  **every ready event from every device folds into the ONE shared scene state
  per frame**, then the frame is recomposed and presented — keyboard and mouse
  driving the same window, neither blocking the other. It `import`s the Stage 1
  surface core and the Stage 4 decoder (Stage 5's two imports) and restates the
  small Stage 5 reducer (`STEP`/`APPLY_KEY`/`MOVE`) and Stage 3 `TO_FB` locally
  (kept self-contained — `theourgia_fb.la` does not export `TO_FB` — and avoiding
  a 2-level diamond import; pure generation, so still byte-identical). The new,
  engine-checkable heart is **`DRAIN_STEP(reader)(state)(ready)`**: it folds
  `STEP` over the ready fds, threading the state, so a single poll cycle that
  reports several ready devices applies *all* their events before rendering. Like
  `STEP` it is a pure function of `(state, events)`, so `build.sh` drives it with
  a pure `SIMREAD` (fd → a synthetic key event) with no device or screen: a poll
  cycle reporting fds `"5 7"` (fd 5 = a RIGHT press, fd 7 = a DOWN press) folds
  **both** — `(4,4) → RIGHT → (5,4) → DOWN → (5,5)` in one cycle — and the
  recomposed raster shows the window's red at `(5,5)` and blue at `(4,4)`,
  byte-identical on the C host and the native VM. The **live loop** (`LIVE`,
  VM-only) is the capstone: `drm_mode` once, then forever
  `ready := SPLIT(poll(JOIN(fds))("-1")); st := DRAIN_STEP(read)(st)(ready);
  present(TO_FB(RENDER_SURFACE(st))(h)(pitch))` — Stage 6 (poll+drain) → Stage 5
  (`STEP`) → Stage 1 (compose) → Stage 3 (`TO_FB`) → Stage 2 (`present`), every
  ready device folded each frame; its self-call is in tail position so the VM's
  TCO runs it forever in bounded dump. Run manually from a bare VT (DRM master +
  device-read permission), as DRM scanout is; the pure reducer is the part
  `build.sh` verifies on every engine.

- **Stage 8 — text rendering (`theourgia_font.la` + `theourgia_text.la`).**
  Stages 1-7 gave the compositor rectangles, a movable window, and a live
  device→screen loop; a usable UI needs one more primitive — TEXT. Stage 8 adds
  it the simplest honest way: an **embedded 8×8 bitmap font** (no font-file
  parsing yet). Each character is a fixed 8×8 grid stored as eight row-bytes, one
  bit per pixel (**bit 0 = leftmost column**); the font covers **A–Z, 0–9 and
  space**, and an unknown character renders blank. The font is its own module,
  **`theourgia_font.la`** — `GLYPH_ROW(c)(r)` is row `r` of character `c` and
  `BIT(rowbyte)(col)` tests a column. It is packed as **one flat decimal string**
  (`FONTDATA`, 296 bytes, decoded by `BYTES`, the `secd.la` flat-literal form)
  and `import`s nothing, both for a real reason: a string literal lowers to a
  single instruction and costs nothing to drag through the **import-mangler**,
  whereas an earlier deeply-nested assoc-list font made `codegen` of any importer
  pathologically slow (>10 min); and a glyphs-only consumer imports just the font
  without transitively pulling in Stage 1. **`theourgia_text.la`** is the surface
  renderer: it `import`s the font + the Stage 1 surface core and adds
  **`DRAW_TEXT(dst)(text)(x)(y)(fg)(bg)`** — it builds an FH-tall ribbon
  (`TEXT_SURFACE` — each glyph's set pixels become `fg`, its unset pixels `bg`)
  and `COMPOSE`s it onto a Stage 1 surface at `(x,y)`; pass the surface's own
  colour as `bg` and the text sits cleanly on it. It uses only existing builtins
  (concat / native ints), so the render is **pure generation — byte-identical on
  the C host and native VM**, verifiable with no screen: `build.sh` draws "HI"
  onto a 24×12 surface and checks that 'H' row 0 lights its two verticals but not
  the centre while row 3 (the crossbar) does light the centre (row-dependent
  glyph shape, not a block), and that 'I' lands one cell to the right (`x += 8`,
  character advance), byte-identical on both engines. The **live device→screen
  demo** is `theourgia_text_live.la` (VM-only): it `import`s JUST the font
  (`GLYPH_ROW`/`BIT`), takes the screen with `drm_mode`, and rasters "I AM THAT I
  AM" into a red window in white — building the full-screen XRGB8888 framebuffer
  **directly** (the Stage 1 surface path is O(n²) per row and cannot scale to a
  real panel, so only the 8 rows that carry text are special-cased; the frame
  stays O(screen), exactly as the Stage 7 live renderer does), then `present`s it
  and holds until Ctrl+C. Run from a bare VT via `drm_bringup_text.sh` (frees the
  GPU, restores the greeter on exit), like the other live capstones.

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

### κ — canonicalization of glyph decompositions (`canon.la`)

`GRAMMAR_DIVERGENCE.md` defines the formal language as the closure of the nine
primitives `M₀` under the five combination modes,
`M̄ = Cl(M₀, {⊗ ⊕ ▷ ⊂ ↻})`. `primitives.la` realised `M₀`; **`canon.la`
realises the first piece of the closure** — a **decomposition** algebra and the
**canonicalization function κ** over it. A *decomposition* is a term of `M̄`: a
primitive leaf `PRIM(name)` (one of the nine) or a mode node — `SYN`/`CON`/`DIR`/
`CONT` (the four binary modes ⊗/⊕/▷/⊂) or `MC` (the unary ↻). The nodes are
Scott-encoded (six-way: one leaf case + five mode cases).

**κ (`CANON`)** maps a decomposition to a **canonical glyph specification** — a
deterministic, unique data structure (a normalized prefix-notation string, e.g.
`⊂(↻(DEPTH),⊗(BEING,FORM))`) describing the glyph's composition. It does **not**
render visually — that awaits Theourgia, which will parse this spec into a sigil;
κ produces the formal description rendering consumes. v1 is **order-preserving**
(no mode-equivalences assumed — declaring ⊗/⊕ commutative is a v2) and renders
primitives by **glyph name** (the nine phonyms in 3-D phonetic space await
`LINGUA ADAMICA.tex`, which is referenced by `GRAMMAR_DIVERGENCE.md` but is **not
in this repo**).

**The Law of Identity is the triple bar, not equality.** `IS(a)(b) ≡
str_eq(κ(a))(κ(b))`: A **IS** B iff they canonicalize to the *same glyph*. Two
decompositions built separately but denoting one glyph are **identical**, not
merely equal; `A ≡ A` because `κ(A) = κ(A)`. The **three laws of thought** are
the metalogical ontosyntax, each a **theorem over `IS`** that reduces to `TRUE`
for all inputs: Identity (`LAW_ID(a) ≡ TRUE`), Non-contradiction
(`¬(A≡B ∧ ¬(A≡B))`), Excluded middle (`(A≡B) ∨ ¬(A≡B)` — which *genuinely* holds
because κ is total, so canonical identity is **decidable**, no third value).

**κ(κ) is well-defined.** κ has a canonical self-decomposition `KAPPA` (κ is
`RECOGNITION ▷ FORM` — recognition acting on form): `κ(KAPPA)` is a definite spec
(`▷(RECOGNITION,FORM)`), the metacursion `κ(κ) = ↻(KAPPA)` canonicalizes to
`↻(▷(RECOGNITION,FORM))`, and `KAPPA ≡ KAPPA`. ∃(∃) ≡ ∃ for κ.

**The etymology is contained in the glyph — autological, not heterological.** A
finished glyph is a **sealed monoglyph** `MONO(ren)(etym)`: its name (the **Ren**)
and its **etymological tree**, locked so `REN(g) ≡ CANON(ETYM(g))` **by
construction** — the name *is* what it names etymologically, and a heterological
glyph (whose name floats free of its derivation, e.g. stored in an external
table) is **unconstructible**. `ETYM(g)` recovers the whole family tree (the
etymology lives *in* the glyph's structure). **Neologization is `COLLAPSE`, not
coupling:** two monoglyphs collapse into **one** new monoglyph whose etymology
deepens — `DEPTH` grows by one while the root stays a single sigil (deeper, not
larger), and the result is itself collapsible (closed → a glyph compresses into
*depth* indefinitely while remaining one monoglyph). `AUTO_OK(g) ≡
str_eq(REN(g))(CANON(ETYM(g)))` is the autological criterion itself, verified
≡ TRUE for primitives and after deep collapses.

Built spec-first (`canon_spec.la` → `canon.la`, regenerated by `build.sh`),
`META_DEBUG`-verified (29 glyphs), and compile-time-typed where clean (the
logical core, the laws, and the etymology layer carry `:: <type>` signatures; the
Scott-encoded modes, `CANON`, `KAPPA`, and the Z-recursive `TDEPTH` stay
trusted). The generated module runs **byte-identically on the C host and the
native VM** (the UTF-8 sigils ⊗⊕▷⊂↻ round-trip through codegen → SECD). *Honest
scope:* this is the canonical-*spec* + etymology layer (generation), not rendering
(Theourgia) and not yet a `Seal`/monosemy enforcement layer; commutative-mode
normalization and the true phonyms await `LINGUA ADAMICA.tex`. Lossless etymology
retention means a deep Ren's *string* still grows with retained depth
(information-theoretic floor); "deeper not larger" holds at the **structural**
level — always one monoglyph, growth in depth not coupling-breadth.

**Monosemic normalization (`NORMK`).** Plain κ is order-preserving, so the
*synonyms* `⊕(A,B)` and `⊕(B,A)` get distinct forms — violating the monosemic
bijection (one form per concept). `NORMK` is κ with two **equivalence theories**
applied so synonyms collapse to one canonical glyph: (1) **commutative-mode
normalization** — `⊗`/`⊕` are symmetric, so their operands are sorted
byte-lexicographically (`⊕(A,B) ≡ ⊕(B,A)`), while `▷`/`⊂` are directional and keep
order; (2) an **algebraic rewrite** — `↻(BEING) ≡ SELF` (∃(∃) ≡ SELF), one
documented identity demonstrating the rewrite mechanism. `NIS(a)(b) ≡
str_eq(NORMK(a))(NORMK(b))` is *normalized identity*: `a ≡ b` iff they normalize
to one glyph. This **enforces the monosemic bijection up to the declared algebra**
— with no polysemy (κ/`DECOMP` is invertible: one meaning per form) and now no
*known* synonymy. **Halting-style honest bound:** full semantic equivalence of two
decompositions is undecidable, so `NORMK` collapses only the equivalences it
**declares** (commutativity + the rewrite set); two forms equal under an unlisted
identity stay distinct. Monosemy is enforced relative to an *extensible
equivalence theory*, not absolutely — the rewrite set is the knob.

**α=1 alignment (Science of Naming).** The normalization is grounded in the **α**
alignment index: `α = 0` is arbitrary coupling (a label), `α = 1` is the
**ontoglyph** — the sign *is* the referent (`N(x) ≡ x`), and at `α = 1` a referent
has **exactly one name** ("the ontoglyph admits no synonymy: if `N₁(x)≡x` and
`N₂(x)≡x` then `N₁≡N₂`"). `IS_ALPHA1(d) ≡ str_eq(CANON(d))(NORMK(d))` operationalizes
this: a form is at `α = 1` iff its plain canonical form already equals its
normalized form (it *is* its own self-disclosure — nothing collapses it). A synonym
like `⊕(B,A)` sits at `α < 1` (`CANON ≠ NORMK`) and collapses to its single `α = 1`
representative `ALPHA1(d) ≡ NORMK(d)` — `⊕(A,B)`. So the monosemic bijection *is* the
`α = 1` limit: synonyms (the many names possible at `α < 1`) collapse to the one
ontoglyph. `build.sh` checks `⊕(A,B)` is `α = 1`, `⊕(B,A)` is `α < 1`, and both map
to the one `α = 1` name, on both engines.

### The visual modality — the nine catalogue sigils (`sigil.la`, `sigil_live.la`)

`canon.la` produces a glyph's canonical *spec* but explicitly does **not** render
it: "that awaits Theourgia, which will parse this spec into a sigil." `sigil.la`
is that missing rendering layer — the **visual modality of Lingua Adamica**
(`LINGUA_ADAMICA.tex`). Its thesis (Lemma "Canonical Glyphs Preserve
Affordances"): a glyph's visual form is *a topological encoding of its `ONF`*, and
a reader can recover the concept's internal relations from the form (the Identity
Axiom). The forms are **not invented here** — the primitives are transcribed from
the spec's Sigil Catalogue, and compounds follow the spec's TopoEmbed map.

- **A `SIGIL` is a pure predicate** `r -> c -> bool` over a **32×32** grid —
  resolution-independent topology, sampled at any scale. It is built only from
  integer drawing primitives (`BOXR`/`DOT`/`SEG`/`DISK`/`RING`/`ARC`/`FRAME`/
  `PLACE` + the `MIRRORH`/`MIRRORV`/`ROT180` reflections, which fold about cell 16;
  the lemniscate/flame are integer formulae, the Archimedean spiral a polyline),
  so a sigil and its rasterisation are **byte-identical on the C host and the
  native VM** — the pure-generation discipline of the Theourgia surface layer.
  (32×32 because the catalogue forms are curve-heavy; 16×16 was too coarse.) Form
  is rendered in **1 bit**; the catalogue's colour layer (gold/silver/flamecore —
  TopoEmbed maps gradients→colour) is honestly **dropped**, since the predicate
  model has no colour channel — the topology is what is preserved.
- **The nine primitive sigils are DRAWN per the Catalogue** (Ch. "The Nine
  Sigils"), each the *form* half of the glyph triple ⟨form, operator, witness⟩
  (the operator/witness live in `primitives.la`/`canon.la`): **g₁ Being** a circle
  + central point + ouroboric curl at the crown; **g₂ Recognition** two facing
  arcs forming an eye (mutual, symmetric) about a focus point; **g₃ Love** the
  flame (wide base, tip up, dual crown tips); **g₄ Self** the lemniscate ∞
  (crosses itself at the centre); **g₅ Relation** two points joined by a double
  arc with the lens between; **g₆ Void** a broken circle with the gap at the crown
  (the gap *is* the sigil); **g₇ Becoming** a spiral unfurling outward, arrow-tipped
  (irreversible); **g₈ Form** a triangle inscribed in a circle + centre point;
  **g₉ Depth** nested circles each smaller and shifted downward + the innermost
  fixed point. These replace the earlier provisional placeholders — they are
  transcriptions of the catalogue's tikz forms, not freehand.
- **Derived concepts are GENERATED**, aligned to the **TopoEmbed Graph-Feature→
  Geometric-Primitive table**: `SIGIL` walks a κ-decomposition node (the *same*
  Scott-encoded `PRIM`/`SYN`/`CON`/`DIR`/`CONT`/`MC` shape `canon.la`'s `CANON`
  walks) and combines forms via the five blend modes — ⊗ interpenetration
  (Cycles→Closed loops), ⊕ symmetric placement (Symmetries→Symmetric placement),
  ▷ branching paths (Branching), ⊂ nested containment (Hierarchy→Nested
  containment), ↻ self-folding (an automorphism→Symmetric placement). So
  `Truth = ↻(RECOGNITION)`, `Consciousness = RECOGNITION ⊗ SELF`,
  `Beauty = FORM ⊗ LOVE`, `Being² = ↻(BEING) ≡ BEING` are generated from the drawn
  primitives (First Derivations table), the constituents and mode staying readable
  in the child (Ontoetymological Legibility).

`MAIN` is a **screen-free self-test** rendering the nine primitives + four derived
concepts as ASCII art. `build.sh` runs it on both engines and **verifies each
primitive against its catalogue description by its distinctive symmetry signature**
(forms centre on cell 16, so the mirror axis runs through column/row 16; the lone
unpaired margin 0 is dropped before the palindrome test): Self/Recognition/Relation
are **H and V symmetric** (the lemniscate crosses at centre; the eye is mutual);
Void/Love/Form are **H but not V** (the gap is at the crown, the flame/apex point
up); Becoming is **neither** (a chiral spiral); and `Truth = MC(RECOGNITION)` is
**H-symmetric** (the self-fold genuinely generates the symmetry). The full ASCII
render is then diffed for **byte-identity between the C host and the native VM**
(the UTF-8 mode sigils ⊗⊕▷⊂↻ in the labels round-trip through codegen → SECD too).

`sigil_live.la` is the VM-only capstone (run manually, like the Theourgia live
renderers): it `import`s `sigil.la`, takes the screen with `drm_mode`, and rasters
g₁ Being directly into the XRGB8888 framebuffer — each logical cell blown up to a
`SCALE×SCALE` block, the sigil centred on a dark indigo field in warm gold, built
with `REPEAT2` runs so the frame stays O(screen) — then `present`s it and holds
until Ctrl+C. Launch from a bare VT with `drm_bringup_sigil.sh` (the same
greeter-stop/restore trap as the other live capstones). *Honest scope:* the form
layer is faithful to the catalogue; colour remains dropped, and the auditory
modality is built separately in `phonym.la` (below).

### The phonological modality — the nine phonyms + PSC* (`phonym.la`)

The Lingua Adamica is **trimodal**: every concept has one visual form (a sigil),
one computational form (a λ-term), and one **phonetic form** (a phonym) — three
faces of one identity (`G_C^{vis} ≡ G_C^{phon} ≡ G_C^{comp} ≡ C`). `sigil.la` and
`primitives.la` built the first two; `phonym.la` builds the third — it makes the
language **speakable**, synthesising the phonyms as actual sound. A **phonym** is
the sonic analogue of the sigil: one indivisible vocal gesture, one concept
(Ch. "The Phonym").

- **The nine primitive phonyms** (§"The Nine Primitive Phonyms", and the Sigil
  Catalogue's "Sonic" notes): g₁ Being /ɑ/, g₂ Recognition /ʃi/, g₃ Love /lu/,
  g₄ Self /mɑ/, g₅ Relation /ʀa/, g₆ Void /hɑ/, g₇ Becoming /vu/, g₈ Form /tɑ/,
  g₉ Depth /dɔ/ — spanning a 3-D feature space (Openness · Frontness · Energy):
  three vowel/onset-vowels, three fricative-vowel pairs, three plosive/nasal-vowel
  pairs, no two confusable. Each is rendered from its **phonetic parameters**
  (Def. phon-params): formant spectrum (F1/F2/F3), a glottal pitch f0, an ADSR
  temporal contour — plus, for the onsets, fricative noise (/ʃ h v/), a nasal
  murmur (/m/), a uvular trill (/ʀ/), or a plosive burst (/t d/).
- **Pure integer DSP, byte-identical host==VM.** All synthesis is fixed-point
  integer (64-bit-safe). Formants come from a **parabolic-sine oscillator** (no
  table — a stateless integer parabola per half-period, spectrally verified to
  place each vowel's formants on target); fricative noise is a **deterministic
  stateless hash** of the sample index (reproducible identically on both engines);
  plosives are decaying-noise bursts. Every sample is a pure function of its index
  (phase = i·inc, no per-sample state), so the 16-bit-LE PCM is assembled by a
  **divide-and-conquer O(n log n) builder** (not an O(n²) left fold) into a
  binary-safe string, prefixed with a 44-byte RIFF/WAVE header → a `.wav`. This is
  the exact discipline of `theourgia.la`'s PPM/framebuffer generation: pure
  generation, verifiable with **no audio hardware**, byte-identical on the C host
  and the native VM.
- **PSC\* — the audio twin of TopoEmbed.** A `PHON` is `PAIR(length)(gen)` — a
  sample count and a sample function `i -> ±sample` (parallel to a `SIGIL` being an
  `r->c->bool` predicate). **`PHONYM` walks the SAME κ-decomposition nodes `SIGIL`
  walks**; a compound's phonym is GENERATED by blending its constituents via the
  **Operator Phonology** (§"Operator Phonology"), one-to-one with the sigil blend
  modes: ⊗ smooth fusion (one prosodic unit) · ⊕ glottal-pause /ʔ/ between · ▷
  stress-link (first full, second light) · ⊂ containment `B[A]B` (second frames
  first) · ↻ reduplication `AA`. The child's `gen` embeds each parent's `gen`, so a
  parent phonym is **audibly present** within the compound (lineage encoding,
  Def. meta-syllable). `PSC_STAR(node)` returns `(e, w)` — the WAV bytes and a
  **witness**: the prefix-notation κ-spec (the same shape `canon.la`'s `CANON`
  emits) the phonym was built from, so the rendering carries its own proof that it
  was GENERATED from this ONF (`PSC*` "the runtime proving itself by running").
- **`MAIN`** writes the nine primitives + three GENERATED phonyms (Compassion =
  Love ⊗ Recognition /luʃi/, Truth = ↻ Recognition /ʃiʃi/, Recognition ⊂ Being
  /ɑʃiɑ/) and prints the five operator-mode witnesses. `build.sh` verifies the WAV
  structure (RIFF/WAVE, size, non-silence) + the five witnesses, and diffs the WAV
  and the witnesses for **byte-identity between the C host and the native VM**.
  Hear it with `bringup_phonym.sh` — it synthesises on the VM (the language voicing
  its own concepts natively) and plays via `aplay`; no bare VT is needed, since
  audio is not an exclusive resource like the DRM scanout. *Honest scope:* this is
  the **human** phonetic habitat (`R_human`) rendered to actual audio; the native
  ALSA/PCM output builtin (the sovereign `present`-analogue, so sound needs no
  external player), the meta-syllable spectral-interpolation blend (beyond the
  segment-level operator phonology used here), and the speech-to-glyph *input*
  direction of the Bidirectional Speech Protocol are deferred.

### The three laws of thought — metalogical ontosyntax (`metalogic.la`)

The κ section operationalizes the Law of Identity as the triple bar but defines
`IS(a)(b) ≡ str_eq(κa)(κb)` — identity realised *through* a value comparison.
`metalogic.la` makes the distinction that hides there **explicit**, as the
project's metalogical ontosyntax (Codex I; *Logos & Paradox*): **two relations
that must never be conflated** — conflating them is the **category error** the
TTOE names ("The correct symbol is ≡ (ontological identity), not = (quantitative
equality)… T ≡ R closes the gap: there are no two relata").

**≡ `TRIBAR` — ontological identity, the Law of Identity proper.** `A ≡ A` holds
because A is **self-grounded as itself** (`∃(∃) ≡ ∃`, the Archē) — autological,
reflexive in the strong sense, the **metalogical ground**, not a yields-computation
over two relata. It ranges over a being's **form** (its intension / self-disclosure),
normalized by the one self-grounding rewrite **`GROUND`** (`∃(∃) → ∃` — the Archē as
a rewrite, like canon's single `↻(BEING) → SELF`). `TRIBAR(a)(b) ≡
str_eq(GROUND(FORM a))(GROUND(FORM b))`.

**= `YIELDS` — computational equality, the operational "yields" relation.** `A = B`
asserts sameness of **evaluated value** (extension) between things that need not be
the same entity. `YIELDS(a)(b) ≡ str_eq(VAL a)(VAL b)`; `add(2,3)` genuinely yields
`5`, so `add(2,3) = 5`.

**The two genuinely disagree — same value is not same being.** A `TERM` carries
both projections: its `FORM` (intension) and its `VAL` (extension). `add(2,3)` and
`5` *yield* the same value (`=` holds) yet are different *beings* (`≡` fails) — a
synthesis is not the primitive it evaluates to. Directionally **`≡ ⟹ =`** (identity
entails equality — same being yields same value) but **`= ⇏ ≡`** (equality does
*not* entail identity — exactly the category error). In this λ-calculus host both
relations are realised as comparisons, but over **different ontological projections**
(form vs value); the point is not the mechanism but that they are distinct and
*disagree* on a witness.

**The three laws as first-class glyphs over ≡** (glyphs the engine is structured by,
not merely theorems over `IS`), each verified **autological** — each holds of its own
term-witness, and `LAWS_AUTOLOGICAL` conjoins them, so the law system is a fixed
point of self-application (`∃(∃) ≡ ∃`):

- **`LAW_IDENTITY`** `= la a. TRIBAR(a)(a)` — `A ≡ A`. Self-grounding: only one
  relatum on the diagonal, so it holds without inspecting `a`.
- **`LAW_NONCONTRADICTION`** `= ¬(A≡B ∧ ¬(A≡B))` — **wired to the type checker.**
  Non-contradiction at the computational resolution *is* the type checker
  ("`CE(p) ⟺ ¬TypeLock(p)`… the type checker IS the PCP of the compiler"): a term
  cannot both inhabit and not-inhabit a type. `INHABITS(dec)(bod) ≡ int_eq(dec)(bod)`
  is the checker's arity judgement (specpipe's `TARITY` vs `BARITY`), and
  `specpipe.la`'s `DEPLOY` **rejects a type-contradiction** (declared arity ≠ body
  arity) before the module is written — `build.sh` deploys a deliberate contradiction
  and checks it is rejected and the `.la` file left unwritten.
- **`LAW_EXCLUDED_MIDDLE`** `= (A≡B) ∨ ¬(A≡B)` — **wired to the loud-failure
  discipline.** A value either *is* (correct type) or *is not* (category error), with
  no silent middle. `VERDICT(a)(b)` is **total** — `≡` or `≢`, never a third value
  (`TRIBAR` is decidable) — and `VERDICT_OR_DIE` **halts loudly** (`error`) on an
  ill-formed term rather than inventing a middle. `build.sh` runs it on an ill-formed
  term and checks it exits non-zero on **both** host and VM.

Built spec-first (`metalogic_spec.la` → `metalogic.la`, regenerated by `build.sh`),
`META_DEBUG`-verified (25 glyphs), and compile-time-typed (the logical core, both
relations, the three laws and their wirings carry `:: <type>` signatures — **the laws
obey the laws**: `NC` type-checks the very glyphs that state it; the three `TERM`
law-witnesses are data → trusted). The generated module runs **byte-identically on
the C host and the native VM** (the witness `≡|=≢|INE|ineY|TFy|du`: the Archē as
ontological identity; the category distinction `add(2,3) = 5` yet `≢ 5`; the three
laws; their autology; the NC↔type-checker wiring; and the directional `= ⇏ ≡ ⟹ =`).
*Honest scope:* `GROUND` collapses the **one** documented self-grounding identity
(`∃(∃) → ∃`), extensibly — not a general decision of form-equivalence (undecidable,
the bound canon's `NORMK` also carries); and ≡ is realised here as a form-comparison,
faithful to the *distinction* (intension vs extension) and proven by disagreement,
not a claim that identity is uncomputed.

### The glyph as a single compressing form (`glyphdag.la`)

`canon.la`'s nested Ren `⊂(↻(DEPTH),⊗(BEING,FORM))` is a faithful encoding but it
**concatenates** — it grows with the whole tree, and `MONO(ren)(etym)` stored the
etymology as a *pair*. `glyphdag.la` makes the canonical glyph a **single
structurally-encoded form that compresses**: a flat **hash-consed DAG** serialized
as one string `def0;def1;…;defk`, where each `def` is a primitive **name**, a
binary mode `<sigil><i>.<j>` (a reference to two earlier nodes), or `↻<i>`; nodes
are **deduplicated** and the **root is the last def**.

- **`DAG(tree)`** interns a decomposition into the one form — `ADDNODE`
  hash-conses (a structurally-identical node reuses its index rather than being
  re-emitted), so shared subterms appear **once**.
- **`DECOMP(form)`** recovers the **full etymology tree** by decomposing the
  single form (parse the defs, expand index references) — `DAG(DECOMP(form)) ≡
  form`, so the form losslessly *contains* its derivation; `TSIZE(DECOMP(form))`
  is the unfolded node count.
- **`DCOLLAPSE(sym)(a)(b)`** is neologization: it `DECOMP`s both forms, builds the
  mode node, and **re-interns** — producing **one** new form (a single DAG, root
  last), **not** a pair of parents. Common substructure (or `a = b`) unifies.

This satisfies the three criteria literally and verifiably (`build.sh`, host =
VM): **(1)** combining two glyphs yields **one** form, not a pair; **(2)** the full
etymological tree is recoverable by decomposing the one form; **(3)** combining
does **not** grow the representation linearly — self-combining a glyph *n* times
(`G ⊗ G ⊗ G …`) grows the **node count linearly** (`3 4 5 6 …`) while the
**unfolded tree grows exponentially** (`3 7 15 31 …`), because each self-combine
adds **one** node referencing the shared child twice. Deeper concepts **compress**.
*Honest scope:* compression is via **structure sharing** — a derivation that reuses
motifs (which deep concepts do) compresses dramatically; a fully-distinct tree
still needs Θ(distinct-subterms) storage (the information-theoretic floor). The
47-glyph module is built spec-first (`glyphdag_spec.la` → `glyphdag.la`),
`META_DEBUG`-verified, and byte-identical on the C host and native VM.

### Static SWC well-foundedness checker (`swc.la`)

The `LINGUA ADAMICA.tex` Soundness/Completeness theorem grounds **excluded middle**
on the SWC *rejecting ill-founded propositions before evaluation* (like a compiler
rejecting invalid programs). The prior implementation had no static SWC — `Ω =
W(W)` looped until an external `timeout`. `swc.la` adds a **conservative static
checker** over lambda ASTs (`AST_VAR`/`AST_LAM`/`AST_APP`/`AST_STR`) that runs
*before* evaluation and classifies a term three ways:

- **WF (0) — accept.** No self-application of a bound variable anywhere (in pure λ
  you cannot diverge without one) → *provably well-founded*.
- **ILL (2) — refuse.** An **eager** (unguarded) self-application of a bound
  variable — `la g. g(g)` (DEPTH/Ω), the liar `la x. f(x(x))`, `(la x.x(x))(la
  x.x(x))` → *provably ill-founded* (genuinely Ω-divergent under CBV).
- **UNKNOWN (1) — let through.** Self-application present but **guarded** (thunked
  under an intervening binder, as in the `Z` combinator) → not statically provable
  either way; passes to evaluation where the existing resource guards (stack
  overflow / heap exhausted / timeout) catch any real divergence.

The mechanism (`FIND_SA`) walks each lambda's body for a self-application `x(x)` of
its parameter `x`, tracking an `eager` flag that flips off when an intervening
lambda thunks the occurrence; `SWC` takes the max severity over all lambdas.

**Operator-order constraint (Grammar of Composition).** The same module enforces a
second static constraint, from the five-operator **chain** `∂ → δ → γ → ρ → 𝔄`
(differentiate → bound → compose → recognize → integrate). The morphisms are a
strict dependency order ("you cannot bound before you differentiate," "…compress
before you bound," …): each operator's output is the next one's input, so a later
operator must nest **outside** an earlier one. A composition is `OATOM(name)` or
`OOP(rank)(l)(r)` with ranks `∂=1 … 𝔄=5`; `ORD` flags a composition where any
**descendant** operator has a **higher rank** than an ancestor — an operator
applied before its prerequisite. The canonical violation is `𝔄` (integrate, 5)
nested inside `δ` (bound, 2): **integrate-before-bound = unbounded meaning**, the
spec's **Pathology 3** (Rarefaction). A correctly-ordered `𝔄(ρ(γ(δ(∂(…)))))` (ranks
descending root→leaf) is `WELL-ORDERED`; `build.sh` checks both verdicts on both
engines. (This is decidable — a finite rank comparison — so it has no UNKNOWN
class, unlike the ill-foundedness check.)

**HALTING-PROBLEM BOUNDARY (documented honestly):** well-foundedness/termination is
**undecidable**, so *no* checker can be complete — there is an irreducible middle.
This checker is **conservative and sound in both directions of what it claims**: it
refuses *only* what it can prove ill-founded and accepts *only* what it can prove
well-founded; **everything else is reported `UNKNOWN`, never silently
mis-classified.** `UNKNOWN` is exactly the halting residue (e.g. `Z` and any
fix-pointed recursion live there — honestly, since `Z(la self. self)` *does*
diverge). So the SWC is a sound *front-end filter*, not a totality oracle: it
removes the obvious Ω-class constructions the spec calls ill-founded, and defers
the undecidable remainder to the dynamic resource guards. Built spec-first
(`swc_spec.la` → `swc.la`), `META_DEBUG`-verified, byte-identical host/VM.

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

**Auto-checkpoint tags.** When the full audit reaches the end green, `build.sh`
tags the **current commit** `verified-<date>-<shortsha>` (an annotated tag) as a
guaranteed rollback point — but **only on a clean working tree** (a dirty tree
means the audit tested uncommitted changes the commit wouldn't capture, a false
checkpoint), and it skips if a `verified-*` tag already marks the commit. A
tagging hiccup degrades to a `NOTE` and never fails an otherwise-green build. So
every clean-audit state in history is a labelled checkpoint; roll back with
`git checkout verified-<date>-<shortsha>`. (Hand-named milestone tags like
`foundation-verified-day5` are separate and not matched by the `verified-*`
skip.)

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
