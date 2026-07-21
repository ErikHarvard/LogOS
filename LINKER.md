# The LA-native linker — state, and how to pick it up

Track B, `~/logos-b`, branch `track-b`. Written so a session with no memory of
building it can continue without re-deriving anything.

## What exists

N `nasm -f elf64` objects go in; one `ET_EXEC` comes out; it runs.

    link_inputs.txt --(link.la, all Lingua Adamica)--> link_out --> "I AM THAT I AM"

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
| `link_test_c.asm` | a THIRD object defining `bump`, so "N objects" is tested rather than asserted. |
| `link_test_rw.asm` | `.rodata` AND `.data` in one object — forces a third, writable segment. |
| `link_test_bss.asm` | `.bss`: memory without file bytes (`p_filesz` 0, `p_memsz` 16). |
| `link_inputs.txt` | the manifest — one object path per line, in link order. |
| `link_test_abs.asm` | `R_X86_64_32` — a 32-bit absolute (`mov esi, msg`). |
| `link_test_s32.asm` | entry for the `32S` case; links against a **real gcc** object and exits 30 = `table[2]`. |
| `link_test_start.asm` | entry for the mixed asm + C link; exits 43 = `compute(21)`. |
| `link_test_odd.asm` | `.weird`, `SHF_ALLOC` — a section the layout must REFUSE. |
| `link_test_plt.asm` | same as A but `wrt ..plt`, so nasm emits PLT32 — what real toolchains actually produce. |
| `link_test_dup.asm` | defines BOTH `_start` and `greet`, so linking it against B is a duplicate and *nothing else*. |

Run: `./gate_link.sh && ./gate_link_reloc.sh` (~3 min; both self-skip with a
SKIP line if nasm/ld/readelf/objcopy/gcc are absent). **Both are wired into
`build.sh`** as of `0184d14`, so the linker is checked by the system's own
criterion, not only when this track runs it by hand.

⚠ **A full `build.sh` needs the other tracks idle** until every terminal is
launched via `~/logos-agent`: it writes ~481 hardcoded `/tmp` paths, and no
session currently has a private `/tmp`.

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

- **N objects** from `link_inputs.txt`, one path per line; manifest order IS
  link order. **Four section kinds**: `.text`, `.rodata`, `.data`, `.bss`.
  Anything else that is `SHF_ALLOC` is **refused by name**, not ignored — which
  is why the reader can be pointed at real gcc objects without silently
  producing wrong addresses. `.eh_frame` and `.note.gnu.property` are ALLOC and
  are **deliberately DROPPED** — recorded as a decision, not ignored: `.eh_frame`
  carries its own relocation section this linker does not apply, so placing it
  would embed unrelocated unwind data. A symbol in a dropped section is refused
  BY NAME rather than resolved, so the choice cannot misplace anything silently.
  **Real gcc objects link** (verified: asm entry + two gcc objects, exit 43).
- **Per-segment permissions**: `.text` R+X, `.rodata` R, `.data`/`.bss` R+W,
  never R+W+X. `.bss` gets `p_memsz > p_filesz` and costs no file space.
- **No linker script** — the layout is hard-coded to ld's policy on these
  inputs (`.text` @ `0x401000`, `.rodata` @ `0x402000`) precisely so ld's own
  addresses can serve as the witness.
- **Static only.** PLT32 is resolved as PC32, which is correct for a
  self-contained image and **wrong for dynamic linking**; the code says so.
- **32-bit window**: ELF64 fields are 8 bytes, the low 4 are read. Fine here,
  wrong above 4 GB.
- The **reader** is general (validated on a real gcc object, 14 sections). The
  **linker** now takes N objects and four section kinds, but still only the
  section names it knows — so the asymmetry is narrower than it was, not gone.

## Next

**0. There is NO single hot spot — the cost is reduction COUNT, and this item
replaces a wrong diagnosis I committed one revision earlier.** Profiled by
stage, same fixture pair, CPU:

    read objects   0.81 s
    + plan         4.73 s   (+3.9)
    + relocations 14.97 s   (+10.2)
    + regions     17.21 s   (+2.2)
    full link     34.78 s   (+17.5 in emission)

Two plausible culprits were tested and **both were wrong**:

- **`DROP`'s O(n) walk** — asserted here previously as "the dominant cost",
  with a real measurement (26.53 → 34.78 s per link, +31%) behind it. The
  measurement was sound; the causal attribution was not. Emission dominates,
  and emission is not `DROP`.
- **`ZEROS` building padding one byte at a time** — visibly quadratic-looking,
  and track A had won 12x on exactly this shape in `asm.la` (`REPB repeats by
  doubling`). The analogy was compelling and false: **20 000 naive `concat`s
  cost 2.05 s CPU**, so the ~4000-byte `.rodata` gap costs ~0.4 s, not 17.5.
  `concat` is not quadratic here.

What is actually true: roughly **0.1 ms per LA reduction**, millions of them,
spread across relocation and emission. No function is algorithmically wrong;
the linker simply performs a great many operations.

`DROP` still matters — but as REDUCTION COUNT, not copying cost. Walking n
bytes is n reductions however cheap each one is, so a cursor threaded through a
structure walk (drop once to the section-header table, step 64 bytes per entry
carrying the tail) still removes real work. It changes `link.la`'s exported
accessor signature from `(file)(offset)` to `(tail)(relative)`, consumed by
`link_layout.la` and `link_reloc.la`.

**The 31% per-link growth is real and is not any one function.** It tracks
capability — more section names means more `FIND_SEC` calls, more plan entries,
more regions — so the curve bends upward as the linker becomes more useful, and
no single fix flattens it.

★ **Method note, because the wrong version was persuasive.** It had a number, a
mechanism, and a plausible story, which is exactly why it survived a commit
unchallenged. A measured figure was used to support an *unmeasured attribution*.
Profile by stage before optimising; a compelling analogy to another track's win
is not evidence about this one.

**✔ FIXED + GATED — RELOCATIONS OUTSIDE `.text` ARE NOW APPLIED.** The risk
above was real, not hypothetical: linking `link_test_reldata.asm` (whose
`msgptr: dq msg` puts an `R_X86_64_64` in `.data`) against the old code placed
`.data` but never patched it, so `msgptr` held `0` where `ld`'s binary held
`0x402000` — the link succeeded, every existing gate passed, and the program
wrote from a null pointer, printing nothing and exiting `0`. Silent wrongness
with a green exit code, exactly the failure `DROPPABLE`/`SYMVAL` exist to
prevent.

The fix generalises `MKPATCHED` from *one `.text` per object* to **one entry
per PLAN ENTRY** — every placed section of every object — with that section's
own relocations applied via `FIND_SEC(".rela" ++ <section name>)` (the new
`PATCHSEC`). Patched bytes are keyed by `(object, section)` (`PATCH_OF`/
`HASPATCH`), not one blob per object.

`gate_link_reloc.sh` gates it and **asserts on the OUTPUT TEXT, never the exit
status** — because `exit=0` is precisely what the bug produced. It links the
fixture, checks `link_out`'s stdout equals `ld`'s binary's, names the
empty-output-with-exit-0 signature explicitly on regression, and then reads
`msgptr` **straight out of the RW `PT_LOAD` segment** (via `readelf -l` +
`dd`/`od`, not `objcopy --only-section` — this linker emits no section headers,
so that form would silently find nothing) and asserts it equals our own
`.rodata` vaddr, not `0`. Verified GREEN, byte-identical relocations vs `ld`.

**✔ 1. `.eh_frame` placed, relocated, and merged.** It is no longer dropped:
added to `PLACEABLE` and the linker `SCRIPT`'s R segment, removed from
`DROPPABLE`. Because `MKPATCHED` walks the plan, its
`.rela.eh_frame` (a PC32 in each FDE's initial_location) is applied
automatically, so the FDEs point at the `.text` functions they describe, and a
symbol living in `.eh_frame` now RESOLVES via `SYMVAL` instead of being refused.

(After the linker-script slice `.eh_frame` moved from its own page into the
shared R segment, grouped with `.rodata` — see item 2.) Gated on the real gcc
objects: since no section headers are emitted, `.eh_frame` is located by the R
`PT_LOAD` and each FDE is found by SCANNING the placed bytes for the position
that decodes (PC-relative sdata4) to an expected function address — read off
`ld`'s decoded frames at gate time (`0x401013`, `0x401031`), never hardcoded. An
unrelocated field decodes to an address *inside* `.eh_frame`, never into
`.text`, so it fails the scan — the silent-wrongness signature named explicitly.

**✔ MERGED, byte-identical to `ld`.** The sections are no longer CONCATENATED —
they are MERGED as `ld` does: keep ONE copy of the (byte-identical) CIE, then
every FDE with its `CIE_pointer` rewritten to the kept CIE's distance and its
`initial_location` relocated at the FDE's NEW merged position. `.eh_frame` is a
sequence of length-prefixed CFI records (`len4`, then a 4-byte id — 0 = CIE,
non-zero = an FDE's backward distance to its CIE), walked in LA. The merged
table is placed as ONE plan entry (object `0`, the `EHMARK` sentinel; `ENAME`/
`ESIZE`/`ETYPE` answer for it without an object lookup, `EHMERGE` fills the
patched-map slot so `EBYTES` picks it up unchanged). Because our `.eh_frame`
base already equals `ld`'s, the result is **byte-identical to `ld`'s
`.eh_frame`** — the gate does `cmp -s` against `objcopy`'s `.eh_frame` from ld's
binary (a concatenated table would be `0x70`, ld's is `0x58`, so a length diff
alone fails), alongside the FDE-decode check. Verified GREEN.

**HONEST SCOPE, recorded:** this dedups a SINGLE shared CIE (objects built the
same way share one); a genuinely differing CIE is REFUSED loudly (`EH_CIE_OK`,
"objects have differing CIEs (unsupported)") rather than emitting a table whose
FDEs point at the wrong CIE — keeping multiple CIEs is a later refinement. No
terminator (this `ld` emits none for these fixtures, so neither do we). Still
deferred: `.eh_frame_hdr` + `PT_GNU_EH_FRAME` (the binary-search header a real
unwinder / `backtrace` uses to FIND the FDEs) — nothing here unwinds. A symbol
DEFINED in `.eh_frame` is no longer resolvable (its position is merged, so it is
not a per-object plan entry); no object defines one (the relocations reference
`.text` section symbols, which resolve fine).

**✔ 2. A linker script — packed, permission-grouped layout.** The hard-coded
one-page-per-section `BASEOF` is gone, replaced by a declarative `SCRIPT`: a
list of segments, each a `(permission, [section names])`. `MKPLAN` FOLLOWS it
with one running cursor — page-align at each segment start, then pack every
section of the segment contiguously (each aligned to its own `sh_addralign`) —
so `.rodata` + `.eh_frame` share the R segment and `.data` + `.bss` share the
R+W segment, exactly as `ld` groups them. A region is now one PT_LOAD per
non-empty segment (≤ 3), its permission taken straight from its `SEG`; W^X is
the grouping, not a name lookup. `.text`/`.rodata`/`.eh_frame` land at `ld`'s
addresses (readelf agrees), so `ld` stays the witness.

**HONEST DIFFERENCE from `ld`, recorded:** `ld` overlaps consecutive segments'
FILE pages while page-separating their vaddrs (it put `.data` at vaddr
`0x403010`, file offset `0x2010`, in `.rodata`'s page tail). Ours gives each
segment its own fresh page in BOTH file and vaddr (`.data` at `0x403000`, offset
`0x3000`) — one extra page of file per segment, but simpler and equally valid:
both satisfy `p_offset ≡ p_vaddr (mod page)`. The addresses `.text` byte-identity
depends on (`.text`, `.rodata`) still match `ld`; only later RW/segment vaddrs
can differ by a sub-page tail. `FITS32` stays guarded (this layout keeps
everything low). Matching `ld`'s file-page overlap was investigated and
DROPPED as not worth it: `ld`'s packing is heuristic, not a clean rule — across
the gcc fixtures it puts each segment on its OWN fresh page (exactly what we do,
so we already match), and only overlaps in specific cases (nasm objects, no
`.bss`). Chasing an inconsistent target for zero capability gain, when we
already match `ld` in the common case, is polish not progress.

**✔ 3. `-ffunction-sections` — merge `.text.*`/`.rodata.*`/`.data.*` into their
output sections.** `gcc -ffunction-sections -fdata-sections` (the input to
`--gc-sections` dead-code elimination) splits code into `.text.compute`,
`.text.helper` and data into `.rodata.<sym>`/`.data.<sym>`. The linker used to
REFUSE them (`CHECKSECS`: "allocatable section this layout cannot place:
.text.compute"). Now `OUTNAME` maps an input section to its output section by
prefix (`.text.*` → `.text`, and the standard name itself; `STARTSW` requires a
following `.` so a stray `.textual` would not match), `PLACEABLE`/`INSEG` compare
by output name, and `PSTEP` places EVERY non-empty section of an object whose
output name matches (not just `FIND_SEC` of one). Everything downstream was
already keyed by (object, section INDEX), so no new plumbing was needed — the
`.text.*` sections become ordinary plan entries that pack into the R+X segment,
resolve, relocate, and run. An ordinary object (one `.text`) packs identically
to before (one match), so no regression. Gate: a `-ffunction-sections` fixture
(compute+helper split into `.text.compute`/`.text.helper`) links against the asm
`_start` and RUNS — exit 43 = `helper(21)*... +1`, which only survives if BOTH
merged functions resolved and relocated correctly. `.eh_frame` stays one unified
section with multiple FDEs, which `EHMERGE` already handled. *Honest scope:*
section ORDER within an output section is our own (section-index then input
order), so a `-ffunction-sections` binary is not byte-identical to `ld` (whose
order differs) — the witness is "it runs", not a byte-diff.

**✔ 4. `--gc-sections` — drop unreferenced sections (opt-in).** A `--gc-sections`
directive line in `link_inputs.txt` turns on dead-section elimination: only
sections REACHABLE from the entry `_start` survive. `LIVESET` is the fixpoint of
a closure over the relocation graph — roots = the section defining `_start`;
a section is live if a live section relocates to a symbol DEFINED in it
(`DEFSEC` resolves a reloc's symbol to its (object, section), following an UNDEF
global to its definition). `keep` (the liveness predicate) threads through
`MKPLAN`→`SNAMES`→`PNAME`→`PSTEP`, which skips a dead section. **Opt-in is
required, not just conventional:** the 3-object test deliberately keeps an
unreferenced `bump` to match `ld`'s default, so always-on gc would regress it.
Default (no directive) keeps everything, `keep` is always TRUE, nothing changes.

**The `.eh_frame` entanglement, handled:** dropping `.text.dead` leaves its FDE
in the merged `.eh_frame` pointing at an unplaced section — the merge would fail
relocating it. So `FDE_KEPT` prunes an FDE whose target `.text` is not in the
plan (`VAOF < 0`); `EHMSIZE`/`EHMERGE` size and emit only kept FDEs. This reads
the PLAN (not a threaded liveness set) — the R+X segment is planned before the R
segment, so the .text placement is already known when `.eh_frame` is sized. With
gc off every target is placed, so nothing is pruned and `.eh_frame` is byte-for-
byte unchanged. Gate: a `dead_never_called` fixture linked WITH `--gc-sections`
drops the dead function — our R+X segment shrinks to exactly `ld --gc-sections`'s
size — and still runs (exit 43); a wrongly-dropped live section would segfault,
a wrongly-kept dead one would leave the segment too big, a mis-pruned FDE would
abort the link. Verified GREEN.

**⚠ KNOWN PERF REGRESSION — the next slice.** Pruning made `EHMSIZE` walk the
CFI records (via `SECBYTES`, whose `DROP` is O(offset·filesize)) where it used
to be `SH_SIZE` arithmetic, and it is recomputed per region — a `.eh_frame`-
bearing link went from ~40 s to ~280 s, and this hits the gc-OFF path too. The
fix is a clean follow-up: compute the merged `.eh_frame` size ONCE (or restore
the cheap `SH_SIZE` path when nothing is pruned, gated on gc-on) instead of
re-walking bytes on every `ESIZE`. Correctness is unaffected; only speed.

**5. Cross-track:** `asm.la` emitting ELF objects removes `nasm`, making the
chain LA end to end. `link.la` is a ready-made oracle — emit an object, read it
back, require agreement with `readelf` on the same file.

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
