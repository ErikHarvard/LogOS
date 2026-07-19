# The LA-native linker — state, and how to pick it up

Track B, `~/logos-b`, branch `track-b`. Written so a session with no memory of
building it can continue without re-deriving anything.

## What exists

Two `nasm -f elf64` objects go in; one `ET_EXEC` comes out; it runs.

    a.o + b.o --(link.la, all Lingua Adamica)--> link_out --> "I AM THAT I AM"

No `ld` anywhere in that chain. `nasm` is still there, because `asm.la` emits
flat `-f bin` images rather than ELF objects — closing that is the standing
cross-track request to track A, and it would make the chain LA end to end.

| file | role |
|---|---|
| `link.la` | the READER. Parses an ET_REL object: section headers, symtab, relocations. `export`s its accessors so the later passes never re-derive ELF offsets. |
| `link_layout.la` | slice 2 demo: layout + cross-object symbol resolution, printed. Imports `link.la`. |
| `link_reloc.la` | the LINKER PROPER: checks, resolves, relocates, emits `link_out`. |
| `gate_link.sh` | gates the reader against `readelf`, over the fixtures **and a real gcc object**. |
| `gate_link_reloc.sh` | gates the linker: bytes vs `ld`, W^X, page congruence, **runs the binary**, 3 negative gates. |
| `link_test_{a,b}.asm` | the fixture pair: A calls `greet` (PC32, undefined), B defines it + `.rodata` (64-bit absolute). |
| `link_test_plt.asm` | same as A but `wrt ..plt`, so nasm emits PLT32 — what real toolchains actually produce. |
| `link_test_dup.asm` | defines BOTH `_start` and `greet`, so linking it against B is a duplicate and *nothing else*. |

Run: `./gate_link.sh && ./gate_link_reloc.sh` (~2 min; both self-skip if
nasm/ld/readelf/objcopy are absent).

## The verification principle — the part worth keeping

**Where the answer is FORCED, demand byte-identity. Where it is a CHOICE, use
an independent witness. And at the end, run the thing.**

- A relocated instruction is forced: `call greet` at `0x401001` targeting
  `0x401010` has exactly one correct rel32, so it is diffed byte-for-byte
  against `ld`.
- File layout and padding are choices: `ld`'s own output carries build-id,
  section ordering and padding decisions that are ld's, so those are checked
  against `readelf`/`nm` instead of diffed.
- The alignment gap between objects is ours (`90 90` vs ld's `66 90`); the gate
  says so and deliberately does not compare it. A gate that quietly skipped a
  region would be worth nothing.
- The final check is not a diff at all: the gate **executes** `link_out` and
  compares stdout and exit code. A binary can diff correctly and segfault.

Every negative gate asserts **which** diagnostic, never merely that it failed —
most wrong implementations also exit non-zero.

## Honest scope — what it does NOT do

- **Two objects. Two sections** (`.text`, `.rodata`). Anything else that is
  `SHF_ALLOC` is **refused by name**, not ignored — refusing is why the reader
  can be pointed at real gcc objects (which carry `.data`/`.bss`/`.eh_frame`)
  without silently producing wrong addresses.
- **No `.bss`**: `p_memsz = p_filesz`, so nothing gets zero-fill beyond the file.
- **No linker script** — the layout is hard-coded to ld's policy on these
  inputs (`.text` @ `0x401000`, `.rodata` @ `0x402000`) precisely so ld's own
  addresses can serve as the witness.
- **Static only.** PLT32 is resolved as PC32, which is correct for a
  self-contained image and **wrong for dynamic linking**; the code says so.
- **32-bit window**: ELF64 fields are 8 bytes, the low 4 are read. Fine here,
  wrong above 4 GB.
- The **reader** is general (validated on a real gcc object, 14 sections). The
  **linker** is not. That asymmetry is the whole of the next slice.

## Next

1. **N objects / N sections.** The blocker for real input. Today the layout
   binds `t1sec`/`t2sec`/`r2sec` explicitly and `va1`/`va2` are per-object
   lambdas; generalising means a list of `(object, section, base)` and a lookup,
   which is a structural rewrite of `MAIN`'s binder chain — worth starting with
   fresh context rather than bolting a third section on.
2. `.bss` (`p_memsz > p_filesz`), then a real linker script.
3. Cross-track: `asm.la` emitting ELF objects removes `nasm`. `link.la` is a
   ready-made oracle for it — emit an object, read it back, require agreement
   with `readelf` on the same file.

## Two LA traps this track paid for — read before editing any `.la`

**A glyph is a MACRO, not a binding.** `glyph F = read_file(...)` re-reads the
file at *every reference*, because the table holds an AST and each reference
re-evaluates it. This fails as a **timeout**, not an error: a one-second report
did not finish in 120. Bind with `(la x. body)(value)`, once, and thread it.

**Order is STRUCTURE, not statement sequence.** A check written first in the
body still runs *after* any lambda argument, because arguments are evaluated on
application. A guard placed in the body ran after the relocations it was meant
to precede — twice, in two different forms. Put the check in a **binder** ahead
of the binder whose argument would fail.

And a tooling note: paren *balance* is not paren *nesting*. A file can balance
at delta 0 while a thunk closes in the wrong place and a glyph silently returns
a function. Use a **per-glyph depth trace** (walk the file, assert each glyph
returns to depth 0) — it names the culprit; a whole-file count cannot.
