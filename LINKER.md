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
| `link_script.la` | the LINKER-SCRIPT PARSER. `ENTRY` + `PHDRS` + `SECTIONS` (`. =`, `ALIGN`, output sections, `(NOLOAD)`, `/DISCARD/`, trailing-star patterns) → the ITEM list the cursor follows and the GROUP list that becomes the segments. Everything else is REFUSED BY NAME. |
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
| `link_test_script.ld` | a real linker script, base **0x500000** — deliberately not the built-in 0x401000, so a default-address image cannot pass by accident. |
| `link_test_kernel.ld` | `kernel/kernel.ld`'s SHAPE, reduced to something runnable: PHDRS + `FLAGS(7)`, two output sections in one segment across an `ALIGN`, `.bss (NOLOAD)`, `/DISCARD/ { *(.note*) … }`. |
| `link_test_sym.asm` | the symbol-torture object: an END-OF-SECTION marker (value == the section's exclusive end) and a HIGH-HALF ABS constant (`0xffffffff80000000`). Both crashed the symtab emitter on the real kernel object; neither is in the a/b fixtures. |
| `link_test_mb.asm` | its fixture object: `.multiboot`, `.boot32`, `.text`, `.rodata`, `.la_image`, `.bss`, and an **allocatable** `.note.mine` so `/DISCARD/` has something it must really drop. Its exit code is computed from a byte in the second segment plus a byte through `.bss`, so "it ran" proves both landed. |
| `gate_link_script.sh` | gates the script path against **`ld -T` on the same file** — twice (a plain script and the kernel-shaped one) — plus a no-script regression, 10 negative gates, and a parse of the REAL `kernel/kernel.ld`. |

Run: `./gate_link.sh && ./gate_link_reloc.sh && ./gate_link_script.sh` (all
self-skip with a SKIP line if nasm/ld/readelf/objcopy/gcc are absent). **All
three are wired into `build.sh`**, so the linker is checked by the system's own
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
- **Per-segment permissions**: DECLARED by a `PHDRS` block if there is one
  (`FLAGS(7)` really does give RWX — kernel.ld asks for it), otherwise DERIVED
  (`.text` R+X, `.rodata` R, `.data`/`.bss` R+W) and a derived segment that
  would need R+W+X is REFUSED. `.bss` gets `p_memsz > p_filesz` and costs no
  file space; so does any `(NOLOAD)` output section.
- **A linker script, in the subset items 9-10 list** — `ENTRY`, `PHDRS` with
  `PT_LOAD`+`FLAGS(n)`, `. =` / `. = ALIGN()`, output sections pulling
  `*(<sec>)` with a `:segment` assignment, `(NOLOAD)`, `/DISCARD/`, and
  trailing-star patterns. **`kernel/kernel.ld` parses in full.** Absent
  `--script=`, the built-in layout still applies (`.text` @ `0x401000`,
  `.rodata` @ `0x402000`), expressed in the *same* two structures the parser
  produces, so both travel one code path. Everything outside that subset —
  `MEMORY`, symbol assignments, expressions, non-trailing wildcards, non-
  `PT_LOAD` segment types — is refused by name.
- **Static only.** PLT32 is resolved as PC32, which is correct for a
  self-contained image and **wrong for dynamic linking**; the code says so.
- **32-bit window**: ELF64 fields are 8 bytes, the low 4 are read. Fine here,
  wrong above 4 GB.
- The **reader** is general (validated on a real gcc object, 14 sections). The
  **linker** now takes N objects and — as of `bb045e0` — ARBITRARY allocatable
  section names: the no-script default layout groups sections by SHF flags
  (exec→RX, writable→RW, else→R) exactly as ld's default does, so a name the
  linker never heard of (`.mydata`, `.weird`) is placed by its permissions, not
  refused. The known five keep their canonical slots so that case stays
  byte-identical to ld. Arbitrary-section ORDER is NOT matched to ld (its own
  convention); the gate (`gate_link_nsec.sh`) asserts placed + runs + W^X. The
  reader/linker asymmetry over section NAMES is now closed.

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

**✔ DONE — the cursor-threaded memoisation (`SECTAB`).** `DROP` copies
(`str_tail` is O(n)), and the section headers + name table live near the END of
the file, so every `SH_*`/`SECNAME`/`FIND_SEC` — each `(file)(index)` — re-DROPped
from offset 0 to a deep field: O(offset·filesize) per read, and `FIND_SEC` (a
`SECNAME` per section) O(sections²). Rather than change `link.la`'s exported
accessor signatures (which `link_layout.la` also imports), `link_reloc.la` now
builds a **`SECTAB`** per object ONCE: one deep `DROP` to `E_SHOFF`, then STEP 64
bytes/entry carrying the tail, reading each field at a SHALLOW offset within the
small remainder and the name from a once-dropped `.shstrtab` tail (3 helpers —
`DROP`/`E_SHOFF`/`SHSTR_OFF` — newly `export`ed from `link.la`). It is stored as
a 4th field of the object record; the hot readers (`SECNAME_M`/`SH_*_M`/
`FIND_SEC_M`) are plain list walks with cheap comparisons. `PSTEP`/`CHECKSECS`
fold the list, `ENAME`/`ESIZE`/`ETYPE`/`PATCHSEC` read it via `E_SECTAB`.
The `.eh_frame` `FIND_SEC` path (`FIRST_CIE`/`FDE_KEPT`/`EH_KEPTSZ`/`EH_KEPTALL`/
`EH_FDEBYTES`/`EHMERGE`/`EH_OBJ`) and the gc `SECNEIGH` were then rerouted to
`FIND_SEC_M`/`SH_*_M` too. Cumulative measurement on a `-ffunction-sections`
link under identical contention: **149 s → 89 s** (section-walk pass) **→ 41 s**
(`.eh_frame` pass) — **~3.6×**. The only structure read left slow is `SECBYTES`,
and its cost is the *inherent* deep byte read of section CONTENT (not a header
walk), so it is not memoisable the same way — reading N bytes at a deep offset
is O(offset) however you slice it, and that is the one place the whole-file
`DROP` genuinely has to happen.

**★★ 2026-07-24 — THE DOCUMENTED BOTTLENECK WAS STALE; MEASUREMENT OVERTURNED IT.**
The note above concluded `SECBYTES` (deep section-content reads) was "the one
place the whole-file `DROP` genuinely has to happen." That predated the section
table (12) and the symbol table (12b), and it was wrong about where the time now
goes. A stage profile (min-of-3, back-to-back — single runs are not comparable,
the governor is `powersave` with an 800-5284 MHz spread) on a 1560-byte gcc
object:

    read 0.7 · plan 2.9 · relocate 6.4 · regions 7.0 · placedsecs 9.4 ·
    secexts 11.5 · SYMTAB 24.3 · emit ~54   (cumulative user s)

The symbol table — 8 symbols — cost **~12 s of 54**. Stubbing localised it to
`ALLSYMS`, and the cause was NOT the count: every `SYM_*` accessor recomputed
`SYMOFF = SH_OFF + i*24`, and `SH_OFF` is an un-memoised deep `DROP` from file
start — ~6 per symbol, each O(offset). `SECTAB` had fixed exactly this shape for
section headers; the symbol reads were simply never given the same treatment.
(A first guess — that `SYM_COUNT` in the loop guard was the cost — was MEASURED
and refuted before the real cause was found. Reasoning about a bottleneck picked
the wrong glyph; stubbing found the right one.)

**The fix — `STAB`, a symbol-table memo mirroring `SECTAB`:** `DROP` to the
symtab base once, step 24 bytes/entry carrying the tail (O(1) amortised per
symbol), read each field at a shallow offset, names from a once-`DROP`ped
`.strtab` tail. `OSYMS`/`SYMREC` fold over that list instead of indexing the
per-`i` accessors. Plus `exts` now reuses the already-computed `secs` instead of
recomputing `PLACEDSECS`. Measured on the same object, back-to-back: **54 → 39 s
(~28%)**, symbols still byte-for-byte ld's. It scales with symbol count, so the
win is far larger on the real kernel object (107 symbols). *The resolution path
(`DEFINES`/`FIND_DEF`, three more `SYM_COUNT`-in-guard loops) still uses the
per-index accessors — a smaller band (relocate 3.5 s), and the same STAB could
serve it next.*

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

**✔ PERF REGRESSION FIXED.** Pruning had made `EHMSIZE` walk the CFI records
(via `SECBYTES`, whose `DROP` is O(offset·filesize)) where it used to be
`SH_SIZE` arithmetic, recomputed per region — a `.eh_frame`-bearing link went
~40 s → ~280 s, hitting the gc-OFF path too. Two changes undo it: (1) `EHMSIZE`
takes `gcon` and uses the cheap `SH_SIZE`-only `EH_FDEBYTES` when gc is OFF
(nothing is pruned, so the full size is exact) — the byte-walking `EH_KEPTALL`
runs only when gc is actually ON; (2) the merged size is computed ONCE by `PEH`
and STORED in the object-0 plan entry's section slot, so `ESIZE` reads it back
instead of recomputing per region. `gcon` threads only to `PEH`
(`MKPLAN`→`SNAMES`→`PEH`); `ESIZE` no longer needs the plan. Measured: the
gc-off `-ffunction-sections` link 281 s → 149 s (back to its pre-gc baseline;
the residual is the `-ffunction-sections` per-section `SECNAME` scan, a separate
pre-existing cost), gc-on 271 s → 160 s, and monolithic `.eh_frame` links return
to ~40 s. Correctness unchanged — gc-off keeps everything and is byte-identical,
gc-on drops the dead function to exactly `ld --gc-sections`'s size.

**✔ 5. WEAK symbols.** `__attribute__((weak))` (and the weak symbols C++ emits
for inline functions/templates) bind as `STB_WEAK`: a STRONG definition anywhere
overrides a weak one EVERYWHERE, and a weak definition satisfies a reference only
when no strong one exists. `DEFINES` (strong-only) already kept a weak+strong
pair from being a multiple-definition error, but resolution was wrong two ways:
a weak-only reference across objects errored `unresolved symbol` (a refusal of a
valid link), and a weak object's reference to its OWN weak symbol used the weak
def even when a strong one existed elsewhere (exit 53, not ld's 43). Fixed in
two places: `RESOLVE_L` now resolves a name STRONG-first then WEAK
(`FIND_DEF(DEFINES)` then `FIND_DEF(DEFINES_WEAK)`, else unresolved), and
`SYMVAL` routes BOTH undefined AND weak-defined symbols through `resolve` — so a
weak symbol always gets the global strong-override-or-weak answer rather than its
in-object address, while strong/local/section symbols still resolve locally.
(`SYM_IS_WEAK` reads `st_info >> 4 == 2` directly — `SYM_BIND` is `link.la`-
private, not exported.) Gate: a weak-only link resolves + runs (was an error),
and a weak+strong link's exit matches ld (the strong def overrides the weak
object's own reference). *(gc `DEFSEC` still traces strong defs only.)*

**✔ 5b. Undefined WEAK → 0.** The other half: an `extern __attribute__((weak))`
symbol referenced but defined NOWHERE is not an error — ld resolves it to 0 (the
`if (&opt) opt();` optional-symbol-probe idiom). `RESOLVE_L` is now NON-FATAL
(returns -1 rather than erroring), and the decision moves to where the binding is
known: `SYMVAL` turns a still-unresolved WEAK reference into 0, keeps the loud
`unresolved symbol` for a STRONG one, and the entry gets its own `ENTRYOF` guard
(`no entry symbol _start`) so a missing entry still halts. Gate (built `-fno-pic`
so `&opt` is a direct `R_X86_64_32`): the undefined-weak link succeeds and its
exit matches ld; the negative gate still confirms an unresolved STRONG symbol is
refused. *Note:* the PIC form of this idiom emits `R_X86_64_GOTPCRELX` (type 42)
for `&opt`, now handled by the GOTPCRELX relaxation (item 6) and, for the
non-relaxable GOT forms, the real `.got` synthesis (item 7) below.

**✔ 6. GOTPCRELX relaxation.** A `-fPIE`/`-fPIC` object taking an EXTERNAL
symbol's address emits `mov sym@GOTPCREL(%rip),%reg` — `48 8b 05 <disp32>` with
an `R_X86_64_REX_GOTPCRELX` (type 42) reloc, the disp32 pointing at a GOT slot.
For a static image the address is known, so no GOT is needed: `APPLYRELS`
RELAXES the instruction. `ISGOTX`/`SBYTE` were added — `SBYTE` reads the opcode
byte at `offset − 2` (the first relocation that patches BEFORE the reloc site,
not just at it); if it is `mov` (`0x8b`) it is rewritten to `lea` (`0x8d`) and
the disp32 resolved as a plain PC32 (`S + A − P`), so `mov sym@GOT(%rip),%rax`
becomes `lea sym(%rip),%rax`. A non-`mov` GOTPCRELX form (call/jmp-via-GOT) is
REFUSED, not mis-rewritten. Gate: an `-fPIE` fixture (`compute()` takes `&extfn`,
`extfn` defined elsewhere) links and RUNS with ld's exit — exit 43 only holds if
the address was loaded and called. *Different-but-valid vs ld, not a bug:* ld
relaxes to `mov $addr,%reg` (`48 c7`, absolute immediate) where we relax to `lea
addr(%rip),%reg` (`48 8d`, PC-relative) — both load the address; the `lea` form
is position-independent (also correct for a PIE image, where ld's absolute `mov`
would not be), so the witness is "it runs", not a byte-diff.

**✔ 7. Real `.got` synthesis.** GOTPCRELX (item 6) is the case ld RELAXES away —
neither linker keeps a `.got` there. Three relocation types genuinely FORCE a
GOT because they reference it as DATA / by its BASE and cannot be relaxed, and ld
synthesises a real `.got` for them: `R_X86_64_GOT64` (27) / `GOT32` (3) store a
symbol's GOT-slot OFFSET as data (`.quad sym@GOT`), and `R_X86_64_GOTPC32` (26)
is the GOT base taken PC-relatively (`lea _GLOBAL_OFFSET_TABLE_(%rip),%reg`). The
linker now builds one: it collects the distinct GOT64/GOT32 symbols (`GOTNAMES`,
scanning the got-less plan), allocates one 8-byte slot each, and places a
synthetic `.got` entry — a single plan entry under a sentinel object id
(`GOTOBJ = −2`, as the merged `.eh_frame` uses object 0) whose
`ENAME`/`ESIZE`/`ETYPE`/`EBYTES` are answered specially — in the **R
(read-only)** segment (its slots are resolved at link time and never written, so
R-only is correct and W^X-clean, and it is the RELRO ld also keeps read-only).
`GOT64` patches to `8·slotindex + addend`; `GOTPC32` folds into the PC-relative
path because the synthetic symbol `_GLOBAL_OFFSET_TABLE_` resolves (via a wrapped
`resolve`) to the GOT base, so its value `S + A − P` IS the base taken PC-rel;
each slot's bytes are the symbol's resolved absolute address. When no GOT reloc
is present the size is 0 and no `.got` is placed — every prior fixture is
untouched. *Different-but-valid vs ld, not a bug:* ld's GOT base (`_GLOBAL_OFFSET_TABLE_`)
sits PAST its slots (negative offsets), ours at the slots' start (non-negative) —
a self-consistent convention, so the witness is ld's EXIT, not a byte-diff (a
layout choice, like the segment order). Gate: `.quad val@GOT` + a GOT-base load —
which ld is PROVEN to keep a `.got` for (else the case is vacuous) — reads `val`
THROUGH the synthesised GOT and RUNS with ld's exit (41). *Honest scope:* GOT64 /
GOT32 / GOTPC32 for globals; a local-symbol GOT slot and the call/jmp-via-GOT
forms (which ld relaxes anyway in a static link) are not exercised.

**✔ 9. A REAL LINKER SCRIPT — the layout stops being the linker's choice.**
Item 2 made the layout declarative but the declaration was a `glyph` inside the
linker: the addresses were still *ours*, chosen to match ld's defaults so ld
could stay the witness. This reads the layout from a FILE. `link_script.la`
parses `ENTRY(sym)` and `SECTIONS { . = <num>; . = ALIGN(<num>); <name> : {
*(<sec>) … } }` into the segment list `MKPLAN` already folds, and a
`--script=<path>` line in `link_inputs.txt` selects it (same directive shape as
`--gc-sections`, stripped from the object list by `NODIRS`).

**The gate is the point of the slice: `ld -T <the same file>` is the witness.**
Every earlier layout check asked "did you guess what ld does?", and the honest
answer had to *exclude* ld's own choices. Handed the same declaration, the
addresses are neither linker's invention, so they are compared exactly: the
fixture names **0x500000** (not the built-in 0x401000, so a default-address
image cannot pass by accident) and our two LOAD segments match `ld -T`'s
**vaddr, file offset and flags exactly**, the entry matches ld's `_start` read
from `nm` at gate time, and the binary RUNS with ld's stdout and exit code.

**A segment now carries WHERE it starts, not just what is in it** (`SM_ABS` /
`SM_ALIGN` + a value) — which is precisely what a `. =` assignment says. The
built-in default is re-expressed in that form, so parsed and built-in scripts
are ONE structure on ONE path; the gate's no-`--script` regression is what
holds that honest.

**Three things the slice forced, each a real bug avoided:**
- **`FILEOFF` was measured from the hard-coded `TEXT_BASE`.** With a scripted
  base that constant is no longer the load address — and because both bases are
  page-aligned, `p_offset ≡ p_vaddr (mod page)` would still have HELD while the
  bytes landed 1 MB into the file. It now reads the image base off the first
  region (`IMGBASE`), so the loader's rule holds by construction for any base.
- **`PLACEABLE` was a hard-coded five-name list** that merely happened to agree
  with the built-in layout. With the layout in a file the two can disagree, and
  the disagreement is silent in the dangerous direction — a section the script
  never places would pass the check and then resolve against an unassigned
  base. It is now read off the script, so the check cannot drift from the
  layout it checks.
- **Permissions are DERIVED** for a parsed segment (R always, +X for `.text`,
  +W for `.data`/`.bss`), and a segment holding both is **REFUSED** rather than
  emitted as RWX. W^X is a property the kernel enforces on itself (K4c); a
  linker that quietly returns an RWX segment has removed a guarantee nobody
  asked it to remove. kernel.ld *does* ask for RWX — via `PHDRS FLAGS(7)`,
  which is item 10 and will be an explicit request, not an inference.

**Everything else is REFUSED BY NAME, and that is the discipline.** A linker
script's failure mode is not a parse error, it is a script that parses and is
then half-obeyed: `/DISCARD/` treated as an ordinary output section would
PLACE the sections it exists to drop; `*(.text*)` read as a literal name would
match nothing and silently omit code; a skipped `PHDRS` block would emit
segments with the wrong permissions. Each links successfully and produces a
wrong binary, so each is a halt naming the token. **7 negative gates**, each
asserting WHICH diagnostic.

**Red-path verified, both directions.** With the linker made to ignore the
parsed script, the gate goes RED on the segment and entry assertions and
**exits 1**; restored, it is GREEN and exits 0. (The "it runs" check still
PASSED in the red run — the binary is fine, just at the wrong address — which
is exactly why the address comparison had to exist.)

*Honest scope:* the output section NAME is parsed and dropped (this linker
emits no section headers, so a name has nowhere to appear); one `. =` per
segment; no `PHDRS`, `MEMORY`, `/DISCARD/`, wildcards, `(NOLOAD)`, symbol
assignments or expressions.

**10. `PHDRS` + `(NOLOAD)` + `/DISCARD/` — what `kernel/kernel.ld` needs.** That
script is the real target: `PHDRS { boot PT_LOAD FLAGS(7); la PT_LOAD FLAGS(7); }`,
`. = 0x100000`, `.boot : { *(.multiboot) *(.boot32) *(.text) *(.rodata) } :boot`,
`.bss (NOLOAD)`, `. = 0x400000`, `.la_image`, and `/DISCARD/ : { *(.comment)
*(.note*) *(.eh_frame*) }`. Each is refused by name today, so the gap is
enumerated rather than guessed: explicit segment permissions (which is also how
RWX becomes a request instead of an inference), a NOBITS output section, an
explicit discard list, and `*(.note*)` — the one wildcard that would then have
to be supported rather than refused.

**✔ 10. `PHDRS` + `(NOLOAD)` + `/DISCARD/` + trailing-star patterns — the four
constructs `kernel/kernel.ld` needs. IT PARSES THE REAL SCRIPT.**

**★ The model had to change first, and the reason is worth keeping.** A segment
used to be "one `. =` group", which was true of every script the linker had
seen. kernel.ld breaks it on sight: `.boot` and `.bss` are BOTH `:boot` with a
`. = ALIGN(4096)` between them — ONE PT_LOAD spanning both, the ordinary shape
of a kernel image (file size covers the code, memory size extends over the
bss). So placement and grouping became separate concerns, as they are in ld: an
ITEM list drives the cursor in script order, and membership is by GROUP KEY —
the `:segment` name, or a synthetic key per `. =` when no PHDRS block exists,
which is exactly the old rule. One grouping mechanism, two ways of naming the
group; the built-in default is re-expressed in both structures so it travels the
same code path.

- **`PHDRS`** — `name PT_LOAD FLAGS(n);`. The type must be `PT_LOAD` and FLAGS
  is REQUIRED: ld would infer permissions, and inferring is precisely what item
  9 did. An RWX segment is now something a script ASKS for (kernel.ld does) and
  never something the linker worked out — a derived segment that would need W+X
  is still refused.
- **`(NOLOAD)`** — memory without file bytes. Easy to think decorative, because
  `.bss` inputs are already NOBITS and would be skipped anyway; it is not, and a
  PROGBITS input in a NOLOAD section is where the difference shows.
- **`/DISCARD/`** — the drop list is the SCRIPT's now, not a private constant.
  The fixture object carries an **allocatable** `.note.mine` for this: with the
  `/DISCARD/` line removed the same link must be REFUSED by name, so the gate
  proves the discard is load-bearing rather than passing vacuously on a section
  nothing would have placed anyway.
- **Trailing-star patterns** — `*(.note*)`, `*(.eh_frame*)`. One matcher,
  exported from the parser and imported by the linker, because two copies of
  "what a pattern means" is how a parser and its consumer drift apart. Any other
  use of `*` is refused: a pattern that silently matches nothing omits code from
  a binary that still links.
- **A segment must be one CONTIGUOUS run of the plan.** A region reaches the
  loader as one `(base, filesz, memsz)` triple, so two interleaved groups cannot
  be expressed — every individual address would stay correct while the segments
  overlapped in the file. Refused by name.

**★★ THE BUG THE KERNEL SHAPE EXPOSED: file offsets were derived from
ADDRESSES.** `offset = PAGE + vaddr − image base` satisfies the loader's
`p_offset ≡ p_vaddr (mod page)` rule and had been correct for every fixture —
until a script put two segments 3 MB apart, and the output grew to **3 MB to
hold one byte of payload**. It ran. Every address was right. It was useless as a
kernel image. Offsets are now PACKED (each region after the last, then the
congruence restored by adding `vaddr mod PAGE`) — which is what ld does — and
the gate asserts the file size against ld's, the assertion that would have
caught it. *An invariant can hold while the thing it is protecting is wrong.*

**The gate:** the kernel-shaped script (`link_test_kernel.ld`) linked against
`link_test_mb.asm` matches `ld -T`'s program headers **field for field** —
vaddr, file offset, filesz, memsz and flags, including `memsz > filesz` for the
NOLOAD section and RWE on both segments — and RUNS with ld's stdout and exit
code. That exit code is computed from a byte read out of the SECOND segment plus
a byte written through `.bss`, so "it ran" cannot be true unless both landed.
**10 negative gates.** And the last check reads the REAL `kernel/kernel.ld`
(track D's file, read-only, self-skipping if absent) and asserts it parses.

**★★ AND THEN IT LINKED THE REAL KERNEL OBJECT — BYTE-IDENTICALLY.** Not the
fixture: `kernel/boot.asm` assembled `nasm -f elf64 -D HAL4 -i kernel/`, linked
with `--script=kernel/kernel.ld`, against `ld -n -T kernel/kernel.ld`:

| | entry | segment 1 | segment 2 |
|---|---|---|---|
| `ld -n -T` | `0x10000c` | `0x100000` filesz `0x53a` memsz `0xc000` RWE | `0x400000` `0x1000`/`0x1000` RWE |
| `link.la`  | `0x10000c` | `0x100000` filesz `0x53a` memsz `0xc000` RWE | `0x400000` `0x1000`/`0x1000` RWE |

and **every loadable byte of both segments is byte-identical to ld's** (`cmp`
over the extracted `p_filesz` spans) — 41 `R_X86_64_64`, 21 `_32` and one `_32S`
relocation all applied to the same values ld computed. The multiboot magic
`1BADB002` lands at the top of the image, where a boot loader looks for it. 16
minutes for an 11 KB object, which is the `DROP`-cost curve, not a wrong
algorithm.

*The one difference, and it is ld's choice not ours:* `-n` (nmagic) puts ld's
second segment at file offset `0x153a`, which is NOT congruent to its vaddr mod
page; ours sits at `0x2000` and keeps the congruence. Both are valid for an
image a boot loader reads by segment; ours is the stricter one.

**✗ THE HONEST BLOCKER, found by carrying on one step further.** The kernel
build's next line is `objcopy -O elf32-i386`, and on our image that fails:
**`the input file 'link_out' has no sections`** — this linker emits no section
header table (`e_shnum` 0; ld's has 7). Every byte the loader reads is right and
the container is still not consumable by the build's own next tool. That is item
12, and it is a real gap rather than a formality: section headers are also what
`readelf -S`, `nm` and `objdump` need to say anything about our output.

*Honest scope:* this used a STAND-IN `native_codegen3_out` and `entry.inc`
(track D's `build_hal4.sh` regenerates both through track A's compiler, and
writing into `kernel/` is not track B's to do), so the .la_image payload was
4 KB of random bytes. That changes nothing about the link — the payload is
`incbin`'d data either way — but it does mean this image was never booted.

**✔ 12. A SECTION HEADER TABLE — the container tools can read.** The linker
emitted none (`e_shnum` 0), and every gate passed, because every gate asked what
the LOADER sees — and the loader reads program headers. `objcopy -O elf32-i386`,
the kernel build's very next line, refused the image outright: *"the input file
has no sections"*. One header per OUTPUT SECTION (which is why the parser now
KEEPS the output name it used to discard), plus the mandatory NULL header and a
`.shstrtab`. `objcopy`, `readelf -S` and `objdump -h` all read the output now;
`nm` still reports no symbols, since there is no symtab yet.

**Verified on the real kernel object, not just the fixture** — name, type, flags
and size identical to `ld -n -T kernel/kernel.ld`'s, segment 1 still
byte-identical, `objcopy` accepting it, and the run completing (`RC=0`) rather
than being cut off by a timeout as the previous attempt was:

| | ours | ld |
|---|---|---|
| `.boot` | PROGBITS A 0x53a | PROGBITS A 0x53a |
| `.bss` | NOBITS WA 0xb000 | NOBITS WA 0xb000 |
| `.la_image` | PROGBITS A 0x1000 | PROGBITS A 0x1000 |

**★ A SECTION'S FLAGS COME FROM ITS INPUTS, NOT FROM ITS SEGMENT.** The first
version read them off the segment's permissions, which looks equivalent and is
not: kernel.ld declares `FLAGS(7)`, so every section came out `WAX` where ld
emits `A`/`WA`/`A`. A segment's flags say what the loader may do with the page;
a section's say what the content IS. ld ORs the inputs, and doing the same
reproduces its table exactly. **The gate would have passed the broken version** —
it compared name/address/size and used the flags column only to FILTER for
allocatable. *A field you filter on is a field you are not checking.* It
compares all four now.

**★★ THE BUG THE NEW GUARD CAUGHT ON ITS FIRST RUN.** `BODYEND` took the maximum
offset over ALL regions — including a segment that is entirely `.bss`, which has
an assigned offset but which `BODY` deliberately writes NOTHING for. So it
returned a position no byte occupies, the section table was written at an offset
the file never reached, and the table was truncated: `readelf: Error: Reading
320 bytes extends past end of file`. Any script giving `.bss` its own segment —
an ordinary layout — would have produced a corrupt table. (kernel.ld happens not
to: its `.bss` shares the `:boot` segment with `.boot`, so that region has file
bytes.) **Two places computing "where the body ends" must use ONE rule**, and the
rule is BODY's: skip empty regions. Caught by the "assert the measurement
parsed" guard written into the file-size check precisely so it could not be
vacuous.

**The file-size assertion, re-derived a second time.** It began as
`fsz < 12288` — a magic threshold track A's review correctly called brittle —
then became "the file must end exactly where its last loadable segment ends".
That held only while no section table existed. The INTENT is restated one level
up rather than loosened: the file must end exactly where the SECTION TABLE ends,
and only alignment may separate the last loadable byte from the name table. Dead
padding is still caught wherever it could hide. Each time, the tempting fix was
to raise a number until it passed, which is how a guard becomes decorative.

*Honest differences from ld, recorded:* a NOBITS section's `sh_offset` is
conventional (it owns no file bytes) — ours derives from the vaddr, ld packs it
after the previous section; `objcopy`/`objdump` read both. And there is still no
`.symtab`/`.strtab`, so `nm` on the output says "no symbols".

**★ A NOTE ON TIMING MEASUREMENTS ON THIS MACHINE.** The kernel link was 960 s
of user CPU before this slice and 1950 s after, which looked like a 2x
regression and was attributed first to another track's concurrent compiles
(refuted: `user == wall`) and then to this slice (refuted: an A/B of both
versions on the same fixture, at two sizes, is identical to within 0.2 s). The
governor is `powersave` and the per-core clock ranges **800-5284 MHz, a 6.6x
spread** — so `user` CPU time is NOT a stable unit of work here, and absolute
times from different runs are not comparable. Only back-to-back A/B in one
session is. The real cost driver is object SIZE (1 KB -> 56 s, 5.7 KB -> 165 s),
which is the known `DROP` curve.

**✔ 11. THE CHAIN WITH NO FOREIGN TOOL IN IT — for a single object.**

    e2e.asm --asm.la--> ELF64 object --link.la--> executable --> "I AM THAT I AM", exit 42

no `nasm`, no `ld`, at any step. Track A landed `elfobj.la` + `asm.la -f elf64`,
and their gate proves `ld(ours) == ld(nasm)` — which removes nasm from the OBJECT
step while keeping ld as the verifier. `gate_link_e2e.sh` is the other half: the
object is linked by `link.la`, so the last foreign tool leaves the chain. The
relocated `.text` is then compared with `ld(nasm)`'s and is **byte-identical** —
both halves agree with the reference they replaced, which is a stronger statement
than either gate makes alone.

**★ THE OWNERSHIP SPLIT IS IN THE FAILURE MODES.** `asm.la`/`elfobj.la`/
`asmelfobj.la` are track A's and live on A's branch; the gate reads them from the
shared object store (published commits, read-only — never A's worktree). If they
are absent, or A's producer REFUSES a fixture, it prints SKIP and exits 0: B does
not own that half, and an unattended B session must not go red because another
track's tool moved. If the producer emits an object and OUR side mishandles it,
that is a FAIL. The gate can only accuse the half this track is responsible for.

**★ ALL THREE PRODUCER FILES COME FROM ONE COMMIT, NEVER A MIX** — found by the
gate on its first run. Preferring a local copy per file paired THIS branch's
stale pre-`-f elf64` `asm.la` with A's new driver and died on `unbound variable
'ASM_ELF'`. Files that must agree about an interface have to be taken from one
commit; choosing each independently assembles a combination that never existed.

**✗ THE STANDING GAP: `extern`, and it is the one that matters.** `asm.la` halts
with `asm: unsupported instruction: extern`, so a source cannot declare an
UNDEFINED symbol — and resolving an undefined symbol across objects is the exact
threshold this track defined as the difference between a linker and an image
writer. **So the LA-only chain is SINGLE-OBJECT only**; the multi-object case
still needs nasm to produce the `UND` entry. What A needs to emit is small and
measured, not guessed — for `extern greet` + `call greet`, nasm produces:

    symtab:  NOTYPE GLOBAL DEFAULT UND greet      (st_shndx = 0)
    rela:    R_X86_64_PC32  greet - 4  at .text+1

The gate **asserts** this rather than remembering it: it feeds `extern` to A's
producer every run and prints which state it is in, so the day A supports it the
line changes by itself. A comment would have gone stale in silence.

**12b. Next for this track:** a `.symtab`/`.strtab` in the output (so `nm` works
on what we emit — the one gap track D was told about), and the multi-object
LA-only link the moment `extern` lands.

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

**★★ AN EXPORT CAN COLLIDE WITH THE IMPORTER'S OWN GLYPH, SILENTLY.** Exporting
a new constructor named `MKSEC` from `link_script.la` collided with
`link_reloc.la`'s existing six-argument `MKSEC` (its SECTAB record builder).
Nothing warned. What surfaced was `attempt to apply a non-function` from
`SECTAB` — a glyph in a file I had not touched, several stages away from the
export. The module system protects the importer from a module's PRIVATES (they
are alpha-renamed); it does nothing about a name the module deliberately
EXPORTS. **Before exporting a name, grep the importers for it.** Renaming them
`MKIADDR`/`MKISEC` fixed it in one line — the cost was entirely in the hunt.

**★ A GUARD MUST BE A BINDER, NOT A CONJUNCT — the same trap, a third form.**
`AND(is-a-section)(key-equals)` evaluates BOTH sides, because `AND(a)(b)` takes
b as an argument. Run over a list of mixed items it called `str_eq` on an
ADDRESS item's numeric field and died inside a host builtin. Nest the tests.

**★ AN INSTRUMENT THAT FIRES FALSELY COSTS WHAT ONE THAT CANNOT FIRE COSTS.**
The depth trace reported three missing parens in a *correct* glyph, because it
stripped comments with `split("#")` and `concat("#")` is a string containing a
comment character. Two flattening rewrites went in chasing a phantom before the
instrument itself was suspected. It now tracks string literals. Same family as
"a check that cannot fail is not a check": trust in a tool has to be earned in
both directions.

**★ `set -e` + a fixture that exits non-zero = a gate that stops early and looks
GREEN.** `out=$(./fixture)` where the fixture deliberately exits 43 made the
gate script exit — silently, with status 0 — so half the assertions never ran
and `build.sh` would have called it a pass. Every fixture run is wrapped in an
`if` (making the exit code data), and a `finished` flag plus an EXIT trap turns
any other early exit into a loud `ABORTED`.
