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
  producing wrong addresses.

  ⚠ **CORRECTED 2026-09-08 — this paragraph was STALE and understated the
  linker.** It described `.eh_frame` as deliberately dropped and a symbol in it
  as refused by name. Both stopped being true at `e1643cb`: `.eh_frame` is
  **placed, relocated and CIE-merged** (see item 1 under *Next*), `DEFR` puts it
  in the R segment beside `.rodata`, and a symbol living in it **resolves** via
  `SYMVAL`. `DROPPABLE` now carries only `.note.gnu.property` plus whatever a
  script's `/DISCARD/` names. The stale text mattered beyond tidiness: track A is
  building `asm.la` object emission against this document, and a limitation that
  no longer exists is something another track designs around for nothing.
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
  and **REFUSED above 4 GB rather than silently wrong** as of 2026-09-08 — a
  symbol whose `st_value` high word is non-zero halts with `link: symbol value
  above 4 GB (32-bit window): <name>` on both the `link_reloc.la` and
  `link_layout.la` paths. Gated by `gate_link_hiaddr.sh` (wired). See slice 16.
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

**✔ 12b. DONE — `.symtab`/`.strtab` in the output (`9b34d65`), and the
multi-object LA-only link (`f4ff53f`, slice 13).** `nm` reads what we emit, and
`gate_link_script.sh` asserts every symbol sits at **ld's own address and
binding** across three layouts (4/6/6 symbols), plus `readelf` validating
`sh_link`/`sh_info`. Both halves of this line are closed.

**★ THIS LINE SAID "NEXT" FOR THREE WEEKS AFTER IT WAS DONE, AND IT MISLED A
SESSION INTO RE-STARTING IT (2026-08-18).** `9b34d65` landed the symbol table and
gated it; nobody edited this paragraph, so the file that calls itself THE LIVE
STATE advertised finished work as the frontier. I read it, believed it, wrote
"12b is still open" into my own slice-13 entry below and onto the shared board,
and only caught it by running `nm` on the artifact — which took one command and
should have come first. *The lesson is not "update your docs": it is that a
prose NEXT line has nothing forcing it to be true, while a gate's PASS line
cannot survive the thing it describes being false. Trust the gate output over
any prose in this file, including this sentence — and when a doc and an artifact
disagree, the artifact is the state.*

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

## Slice 13 — THE CROSS-OBJECT LA-ONLY LINK (2026-08-18)

**★★ THE THRESHOLD THIS TRACK DEFINED ITSELF BY IS CROSSED IN A CHAIN WITH NO
FOREIGN TOOL IN IT.** Two `.asm` sources → track A's `asm.la -f elf64` +
`elfobj.la` → two ET_REL objects → `link.la` → one image that RUNS, where
`_start` in object A calls a `greet` **defined in object B** and declared
`extern`. No nasm, no ld anywhere in the chain under test. `gate_link_e2e.sh`
steps 6a/6b/6c.

This was blocked since 07-23 on one thing: `asm.la` halted on `extern`, so an
UNDEFINED symbol could not be expressed, so the chain was single-object only.
The gate carried a **probe** rather than a comment — it fed `extern` to A's
producer every run and printed which state the world was in. A landed `extern`
in `484622c` and the probe flipped by itself. That is the whole argument for
probes over comments: a comment would have gone stale in silence.

**What the three assertions are, and why each exists:**
- **6a** — `x_a.o` must carry `greet` as `UND`. Without this the step could pass
  on two self-contained objects that never needed a linker at all.
- **6b** — it runs: `TWO OBJECTS, ONE IMAGE`, exit 17. The behavioural witness.
- **6c** — the relocated `.text` vs `ld` **over the same two objects**.

**★ HONEST SCOPE, MEASURED: we match ld except in ALIGNMENT FILL.** ld encodes
inter-object padding as multi-byte NOPs (`66 2e 0f 1f 84 …`); we emit `0x90`
runs. Same length, same layout, same instruction bytes — the `call greet`
displacement `e8 1b 00 00 00` is identical. That is ld's encoding convention,
not semantics, so 6c asserts it rather than matching it.

**★★ AND "EVERY DIFFERING BYTE IS 0x90" IS NOT A SUFFICIENT ASSERTION.** A
mis-relocation that happened to write `0x90` over an instruction satisfies it.
6c therefore derives the fill region's BOUNDARIES from the reference at gate
time (gap starts at the end of `x_a.o`'s `.text`, ends where `nm` says ld put
`greet` → `[17,32)`) and requires every differing byte to be `0x90` **and**
inside it. Red-pathed by writing `0x90` over a real instruction at offset 0:
value test accepts it, range test catches it — 1 of 16 bytes flagged, gate RED,
exit 1. It also refuses to judge at all if the measurement did not parse, and
fails an empty region, so it cannot go vacuous.

**★★ I REINTRODUCED THIS FILE'S OWN DOCUMENTED `strtonum` TRAP.** The first cut
of 6c parsed hex with awk's `strtonum` — which **mawk does not have**. This file
already records that exact failure from the slice-4 alignment assertion: awk
errors to stderr, the pipeline emits nothing, and the gate prints PASS,
decorative for a whole run. Knowing the trap and having written it down did not
prevent repeating it; only RUNNING the check did. Hex is now parsed with
`printf`, and every derived number is asserted to have parsed before it judges
anything. *The lesson that survives: a documented hazard is not a defended one.*

**★ CORRECTION to what this entry first said.** It claimed "12b is still open —
no `.symtab`/`.strtab` in our output" and named it the next slice. **That was
wrong**: `9b34d65` landed the symbol table weeks ago and `gate_link_script.sh`
gates it. I took it from the stale `12b. Next` paragraph above instead of running
`nm`, and repeated it onto the shared board. 6c reads `greet` off **ld's** image
for a different and still-good reason — the reference should be independent of
the thing under test — not because ours lacks symbols. Ours has them.

## Slice 14 — THE KERNEL SEAM: ld REMOVED FROM A REAL KERNEL BUILD (2026-08-18)

**★★ THE LA-LINKED KERNEL BOOTS.** `link.la` is a drop-in for
`ld -n -T kernel/kernel.ld` on track D's real `boot.o`: `objcopy -O elf32-i386`
accepts the container, the entry point is `0x10000c` like ld's, **all 33,340
loadable bytes across both segments are byte-identical to ld's**, and the image
boots in QEMU with the **same serial output and the same clean exit 33** as the
ld-built control. `gate_link_kernel.sh`.

**★ THIS IS THE STEP EVERY PREVIOUS CLAIM STOPPED SHORT OF.** On 07-23 this
track linked the real kernel object byte-identically to ld and that looked like
complete success — the build's very next line (`objcopy`) then refused the image
for having no sections. Item 12 fixed that, and the claim moved to "the
container is acceptable", which is still one step short of the only thing anyone
wants to know. Carrying it to QEMU is what makes it a result rather than a
property. *Reproduce the real consumer's next step, not your own criterion.*

**ONE VARIABLE MOVES:** the SAME `boot.o` goes into both linkers, so anything
the comparison finds is the linker's — the discipline from `gate_link_e2e` 4b.

**The one difference, and it is ld's choice:** `-n` (nmagic) packs segment 2 at
file offset `0x14ca`, not congruent to its vaddr mod page; ours sits at `0x2000`
and keeps the congruence. Both load at `0x400000` and both boot. This is why the
gate compares segment CONTENT, not file offsets.

**Cost: ~36 minutes** for the 39 KB object (32 KB of it the incbin'd
`.la_image`) — the known `DROP` curve, not a wrong algorithm. **On-demand only;
do NOT wire this into `build.sh`.**

**★ HONEST LIMITS, all three real:**
1. `boot.o` is an **uncommitted build artifact in D's worktree**, so the gate
   tests whatever kernel D last built (it records the sha256 it tested —
   `d22f2609…`, a `nic5s_probe` kernel). A reproducible version would assemble
   `boot.asm` here, which needs A's compiler for the incbin payload.
2. The object came from **nasm**, not `asm.la`. This closes the LINKER seam, not
   the whole LA-only kernel chain. Combining both halves is a separate step, and
   A's `92a29ad` equ regression is an open question for `boot.asm` specifically.
3. QEMU has no NIC attached, so the kernel reports "nic not found". Both images
   are identical so the comparison is sound, but the kernel exercises little.

**★ THREE HARNESS BUGS CAUGHT IN MY OWN GATE — the checks, not the linker:**
- **`readelf | while read` runs in a SUBSHELL**, so an `ok=0` set inside it is
  lost and the verdict prints GREEN over a failed segment. Redirect from a file.
- **mtime is the wrong freshness basis for inputs the checker itself rewrites.**
  The first cut cached on `-nt`, but the gate `cp`s `boot.o` and regenerates
  `kernel.ld` every run, so they are always newer by construction and the cache
  could never hit. Freshness is now a **content hash** of every input, stored
  beside the artifact. *A cached artifact is a false-green waiting to happen, so
  the staleness test has to be about content, not timestamps.*
- **The reuse message described the mtime check after it became a hash check.**
  In this project the PASS/NOTE string IS the claim; a line that misdescribes
  its own check is a real defect, not cosmetics.

**★★ AND ONE THAT COST THE 36 MINUTES: DO NOT EDIT A SHELL SCRIPT WHILE IT IS
RUNNING.** `/bin/sh` reads a script lazily by file offset. I patched
`gate_link_kernel.sh` while a background instance was mid-link; rewriting the
file shifts every later byte, so the shell would have resumed into the middle of
a different line. The run had to be killed and its 36 minutes discarded — the
output could not be trusted either way. Edit a COPY, or wait.

**Red-pathed:** one flipped byte in the LA-linked image is caught by BOTH the
byte comparison (segment 1 differs) and the boot (`EXCEPTION 06`, exit 35 vs
33) — gate RED, exit 1. The control is deterministic across 3 boots, and the
gate SKIPs rather than passing if ld's own control fails to boot or boots to
silence (a silent control would make "same serial" true and meaningless).


## Red path: `gate_link_layout.sh` — the one gate that had never been shown to fail

A red-path audit over the eight gates this track owns reported all eight as
having NO documented red path. **That was the instrument, not the gates.** It
grepped the `.sh` files — where red-path evidence never lives. Six of the eight
have it in this file or in commit messages; the audit could not see either.

⇒ Same failure as the `IS<CAP>` capability audit that returned a uniform zero
for fourteen predicates: **an instrument aimed at the wrong surface returns the
same answer for everything, and uniformity is the tell.**

Corrected, exactly one gate had no evidence anywhere — script, this file, or any
commit: **`gate_link_layout.sh`**. It does now.

**The perturbation was one byte**, chosen as the smallest change that could
possibly matter: `link_layout.la:65`, `TEXT_BASE 4198400 -> 4198401`.

    baseline    PASS  link_layout.la: layout + cross-object resolution agree
                      with ld (3 addresses, 1 negative gate)
    perturbed   FAIL  link_layout.la: _start should be 4198400
                      (ld says 0x0000000000401000); got: obj1 _start = 4198401
    restored    PASS  (link_layout.la byte-identical to HEAD, verified by hash)

It discriminates at single-byte resolution AND names the offending address
rather than merely failing — the difference between a gate that says "wrong" and
one that says WHAT is wrong.

**The restore-and-reprove is the third leg and it is not optional.** A red path
that leaves the tree perturbed is how a deliberate break ships by accident. The
hash check against HEAD is what makes "restored" a measurement instead of a
belief — this session has already produced one case where I said "reverted",
had not, and reported results from the un-reverted build for an hour.

**Still weak:** `gate_link_nsec.sh` — one mention in this file, no red-path
commit, no in-script evidence. Not proven vacuous, merely unproven.


## Red path: `gate_link_nsec.sh` — and a red path that was itself invalid

The second of the two gates with no red-path evidence. It now has one, and the
FIRST ATTEMPT FAILED IN A WAY WORTH RECORDING.

**Attempt 1 — invalid.** Perturbed `RODATA_FILEOFF 8192 -> 8193` in
`link_reloc.la`. The gate stayed GREEN, which reads exactly like "this gate is
decorative". **It is not: `link_out` came out BYTE-IDENTICAL** (sha
`03cd693882630901` both ways). `ALIGNUP` — which appears 8 times in that file —
rounds 8193 straight back. **The perturbation was a no-op, and the gate was never
asked anything.**

⇒ Had that been reported, it would have been a false finding against a working
gate, and might have prompted rewriting one that was fine.

★ **SO A RED PATH NEEDS ITS OWN PRECONDITION CHECK: prove the perturbation
CHANGED THE ARTIFACT before drawing any conclusion from the gate's response.**
Hashing `link_out` is what separated ABSORBED from UNDETECTED. This is the
absence rule one level in — *an instrument reporting no-change must first prove
something changed.*

**Attempt 2 — valid.** Perturbed `F_RW 6 -> 5`, flipping the read-write segment
flags to read-execute. `link_out` sha `03cd693882630901 -> 7ae5216905977dd2`,
so the artifact genuinely moved.

    PASS  runs and reads .mydata back (exit 42 == ld's 42)
    PASS  .mydata emitted as an allocatable writable section (WA), not refused
    PASS  W^X holds — no writable+executable LOAD segment
    FAIL  no RW (read+write, non-exec) LOAD segment in the image
          link_nsec gate RED

**Only the assertion the perturbation breaks fails; the other three still hold.**
That is better than a blanket red — the gate LOCALISES the defect. And note it
correctly reports `W^X holds`: flipping RW to RX made the segment non-writable,
so W^X really is still satisfied. A cruder gate would have fired that too.

Restored; `link_reloc.la` byte-identical to HEAD, verified by hash.

**Both previously-unverified gates now have real red paths.** All eight gates
this track owns have evidence: six pre-existing in this file or in commits, and
these two added.

## Slice 15 — the gate that had a red path and no runner (2026-09-08)

The section above ends *"all eight gates this track owns have evidence."* True,
and it turned out to be the wrong question. **`gate_link_layout.sh` had a
documented, single-byte red path — and nothing anywhere ran it.**

**Measured, not inferred** — though the first version of this section reached
the right conclusion by an unsound route, corrected below in
*"the instrument was wrong too"*. The sound measurement is a direct presence
scan over every historical revision of `build.sh`, on every branch:

    for c in $(git rev-list --all -- build.sh); do
      git show "$c:build.sh" | grep -q '^\./gate_link_layout.sh' && echo "$c"
    done

**One revision out of 236** — the commit that wired it. It was never wired, so
there is no decision to recover and no comment explaining an exclusion.
`run_link_regress.sh` omitted it too — including in the copy committed that same
morning, by me.

**★ AND IT IS THE ONLY BUILD-REACHABLE COVER FOR `link_layout.la`.** Nothing
`import`s the module, so its only cover is what a gate runs. Exactly two gates
exercise it: this one, and `gate_link_kernel.sh` (deliberately on-demand,
~36 min, documented). So a committed 9 KB module had **zero enforcement in the
build**: a regression in it would have landed silently, green, and no gate would
have moved.

*Do not read a bare `grep -l link_layout.la *.sh` as contradicting that.* It
returns four scripts, and the other two are **not cover**:
`gate_seam_asm_link.sh:25` and `night3.sh:52` merely name the file in a `cp`
staging loop — they copy it into a scratch directory and never assert anything
about it — and neither is wired into `build.sh` either. Checked 2026-09-08 by
reading both call sites, not by counting grep hits.

⇒ This is the mirror of the failures this file already records. A gate that
cannot fail tests nothing; a gate that fails toward red can never pass; and a
gate nobody runs tests nothing either — but it is *worse than both*, because the
red-path evidence in this file reads as coverage. **Evidence that a gate
discriminates is not evidence that it runs**, and the audit that produced the
"all eight have evidence" line asked only the first question.

**Red path re-verified here rather than inherited from the record above** — the
same discipline this file demands of a bottleneck attribution:

    baseline    PASS  link_layout.la: layout + cross-object resolution agree
                      with ld (3 addresses, 1 negative gate)          [38 s]
    perturbed   FAIL  link_layout.la: _start should be 4198400
                      (ld says 0x0000000000401000); got:
                        obj1 _start = 4198401
    restored    blob 14b97468… == HEAD, verified by `git hash-object`

`link_layout.la:65`, `TEXT_BASE 4198400 -> 4198401`. One byte; the gate names the
offending address rather than merely failing.

**Wired** into `build.sh` after `gate_link_e2e.sh`, and added to
`run_link_regress.sh` (second, since it is cheap and fails fast). 23 s measured
alone, 38 s under two concurrent builds — negligible against a multi-hour build
either way, which is why no cost argument justified leaving it out.

**⚠ `gate_link_kernel.sh` stays UNWIRED and that is deliberate** — ~36 min per
link, documented on the board as on-demand. It is excluded for a stated reason;
`gate_link_layout.sh` was excluded for none. Those are different situations and
only one of them was a defect.

### ⬥ The instrument was wrong too (same day, caught before it spread far)

The first draft of this slice settled "was it ever wired" with
`git log -S'<gate>' -- build.sh` returning nothing, and I recommended that test
to every other track on the board. **It is the wrong instrument and it produces
false NEVERs.** Two reasons, both load-bearing:

1. `-S` reports only commits where the **occurrence count changes**. A line
   moved or rewritten without changing the count is invisible.
2. `-S` **does not examine merge diffs** unless asked (`-m` / `--diff-merges`).

Both linker gates that this repo has actually been running for weeks were wired
**inside a merge** — `0184d14 "Merge kernel-k1 into track-b, and wire the linker
gates into build.sh"`. So:

    git log -S'gate_link.sh'       -- build.sh   -> NOTHING   (it IS wired)
    git log -S'gate_link_reloc.sh' -- build.sh   -> NOTHING   (it IS wired)
    git log -S'gate_link_e2e.sh'   -- build.sh   -> 80e9224   (found: not a merge)

The third line is why it looked trustworthy: it works for gates wired by an
ordinary commit, which is most of them. **A detector that is right on the cases
you spot-check and wrong on the case you are deciding is worse than no detector**
— it launders a guess into a measurement. The conclusion about
`gate_link_layout.sh` survived only because the presence scan independently
confirms it (1 of 236). Had it not, I would have committed a false finding with
a proof attached.

⇒ This is the pattern of the slice itself, one turn deeper. The slice says
*evidence a gate discriminates is not evidence it runs*. The instrument says
**evidence a method works on the cases you tested is not evidence it answers the
case you are asking.** Red-test the instrument against a case whose answer you
already know — here, a gate you KNOW is wired must not come back NEVER.

### ⬥ And the sweep glob missed a third dead gate

The same day I wrote *"all eight gates this track owns"*, the sweep behind it
globbed `gate_link*.sh`. **`gate_seam_asm_link.sh` does not match that prefix**,
and it is invoked by **nothing** — not `build.sh`, not `run_link_regress.sh`, not
any tracked script — with no comment anywhere explaining the exclusion. A cross-
tree sweep run from the hub the same afternoon reported this tree as *2 dead, 0
undocumented*; the true figure was **3 dead, 1 undocumented**, and the gap is the
glob. Enumerate `gate_*.sh`, never a narrower prefix that happens to match the
gates you were thinking about.

Resolved not by wiring it into `build.sh` but by **stating the exclusion**: it is
green (68 s), but its producer half is track A's `asm.la` — it stages
`kernel-k1:asm.la` read-only and **fails rather than skips** if that half
regresses, so wiring it would turn B's unattended build red on another track's
move (the reason `gate_link_e2e.sh` documents its own SKIP fallback). It now runs
from `run_link_regress.sh`, on demand, alongside `gate_link_kernel.sh`. An
excluded gate needs a runner and a stated reason; this one now has both.

## Slice 16 — the 32-bit window was DECLARED, not enforced (2026-09-08)

`link.la`'s header has said since the beginning that the high word of each
8-byte ELF64 field is *"checked where it costs nothing so the failure is loud
rather than silent."* **It was not checked anywhere.** `SYM_VHIGH` — the
accessor written for exactly that job — was defined, **exported**, and called by
NOTHING; `link_reloc.la`'s `STAB` record captured `ST_VHI` and never read it.
Four occurrences in the whole tree: a comment, an export, a definition, and
`HIGH4` behind it. No call site.

So a symbol at or above 4 GB had its high word **discarded** and linked to its
low word.

**★ AND THE READ-SIDE HOLE DEFEATED THE WRITE-SIDE GUARD.** `link_reloc.la` has
`FITS32`, which refuses a value too large to write into a 4-byte field, and it
*is* wired. It cannot help: a `st_value` of `0x1_0000_0000` **reads** as `0`,
and `0` fits, so `FITS32` waves it through. The two are the same limit
approached from opposite directions — writing a value too big, and reading one
whose size was already thrown away — and only both together close it. A guard on
the write is worthless while the read silently truncates.

**Measured red path** (the pre-guard linker, this exact fixture):

    rc=0
      obj2 greet = 4198416
      resolved greet -> 4198416

`greet` genuinely sits at `0x100000000`; it linked to `0x401010`. Plausible,
wrong, and **green** — the silent-wrongness class this track exists to refuse.
After: `link: symbol value above 4 GB (32-bit window): greet`, exit 1.

**Fixed at both address sites**, since two independent paths compute a symbol's
address: `STADDR` in `link_reloc.la` (guarding the `STAB`/`RSTAB` path) and
`SYMADDR` in `link_layout.la` (which finally gives the exported `SYM_VHIGH` a
caller). Both refuse by name.

**`gate_link_hiaddr.sh`, wired into `build.sh` AND `run_link_regress.sh` the same
day it was written** — this morning's finding was a gate nobody ran, and leaving
this one unwired would have been that finding in a different costume. It costs
15 s. Two properties, deliberately:

- **the red case** — a `st_value` high word patched to 1 must be refused BY NAME;
- **a CONTROL** — an ordinary sub-4 GB link must NOT be refused. A guard that
  fires on everything and a guard that fires on nothing are indistinguishable
  from the red case alone.

The gate then verified against the pre-guard linker: **FAIL**, printing the wrong
address it accepted. Against the guarded one: **PASS**. The symtab offset and
symbol index are **derived at gate time** via a name-relative `readelf` scan —
`readelf` prints `[ 4]` as two fields and `[12]` as one, so any fixed `$N` breaks
silently once a section index reaches double digits, patching the wrong byte and
going green having tested nothing.

**Latent, not hypothetical.** This layout sits near `0x401000` and
`kernel/kernel.ld` at `0x100000`, so nothing trips it today.

⚠ **CORRECTED same day — the kernel justification I first gave was wrong, on two
grounds I measured after track D pushed back.** (1) **`link.la` cannot reach the
kernel at all**: the string `link.la` does not occur anywhere under `kernel/`
(0 of 76 `kernel/*.sh` **in this tree**); every kernel build links with
`ld -T kernel/kernel.ld`. (2) **The kernel is ALREADY higher-half**, and has been
since HH1: `HIGH_BASE equ 0xFFFFFFFF80000000` at `kernel/boot.asm:141` **in this
tree**, mapped
`PML4[511] -> pdpt_high` at `boot.asm:238-244`. But that is a **runtime
page-table alias**, not a link-time base — `kernel.ld` still links at `0x100000`
and the ELF loads low, so **no >4 GB address is ever presented to a linker**. I
inferred a direction from a plausible trajectory instead of reading the tree; the
guard is right, the motivation I published for it was not.

**⚠ EVERY NUMBER ABOVE IS TREE-LOCAL — AND ONE IS ALSO COMMIT-LOCAL.** The relay
carrying D's correction quoted 77 scripts and `boot.asm:332`; I measured 76 and
`:141` and called the relay's figures wrong. **They were not.** Different glob,
different tree: 76 is `kernel/*.sh` **here**, 77 was `kernel/build_*.sh` **on
track-d** (79 by re-measure — D has been committing), and `kernel/boot.asm` is
1555 lines here against 2192 there, which is why `HIGH_BASE` sits at `:141` in
this tree and far lower in D's. Neither report was wrong about a fact; they were
about different trees, and the tree got stripped off in transit. The substantive
claim is unanimous and holds in every tree: `link.la` occurs nowhere under
`kernel/`.

★ **An agreeing count is not a reconciled count unless the tree AND the glob are
pinned.** This was offered to me with a striking instance attached — that **76**
is both this tree's `kernel/*.sh` count *and* the count of D's kernel scripts
invoking `ld -T`, two unrelated quantities in two trees landing on one number,
so that agreement would have read as corroboration and ended the check.

⚠ **I amplified that instance before measuring it, and it does not survive —
there was never a collision.** On committed state D has **75** such scripts, not
76, and the literal pattern `ld -T` matches **zero** of them (the actual form is
`ld -n -T kernel/kernel.ld …`).

**The 76 is now fully explained, and it is a glob defect**, not an uncommitted
working copy as I first supposed:

    git grep -l 'ld .*-T' track-d -- 'kernel/*.sh'   ->  75
    git grep -l 'ld .*-T' track-d -- kernel/         ->  76
    the extra match: kernel/SELFREPAIR_5s_DESIGN.md  ->  a PROSE DESIGN DOCUMENT

A markdown file was counted as a linker invocation. So the number that made the
coincidence was never measuring linker invocations at all — which is the
**mention-vs-invocation** distinction this file already turns on, and the reason
`gate_seam_asm_link.sh:25` and `night3.sh:52` had to be read rather than counted
(slice 15). Prose is where an unwitnessed claim hides, in both directions: it
inflates a count here, and it asserted an absent guard in slice 16.

**The rule stands without it.** It is carried by the four instances below, each
measured, and did not need a coincidence to support it. A vivid instance is the
part of a claim most likely to be repeated and least likely to be checked — this
one arrived pre-formed, fitted the argument exactly, and I passed it on. That is
the same reflex as accepting a relayed number, one level up.

★★ **A line number needs a third pin — the commit.** Checking `:332` against
track-d's *committed* `boot.asm` (`git show track-d:kernel/boot.asm` — reading a
blob, not reaching into another worktree) puts `HIGH_BASE` at **278**, not 332;
the likely reading is that `:332` came from D's uncommitted working copy. So a
count crossing a track boundary is malformed without **tree + glob**, and a line
number without **tree + commit**.

**Confirmed, and the mechanism is worse than drift.** The `:332` reading did come
from an uncommitted working copy (2529 lines there against the commit's 2192).
But it was not a stale reading of one artifact — it was a **composite of two**:
a line COUNT taken from `git show <ref>:file` (the commit) paired with a line
NUMBER from `git grep` **without** a commit-ish, which reads the WORKING TREE.
That row described no artifact that exists, which is why pinning the tree did not
rescue it. So beneath the pins sits a simpler rule: **pin the artifact, then read
it once.** Mixing `git show <ref>:` with a bare `git grep` in one report silently
selects two different objects.

*Checked against my own row before stating this:* `2192` and `:278` both
re-derive from a single `git show track-d:kernel/boot.asm`, and the script counts
came from `git ls-tree`/`git grep <rev>`, which are commit-pinned. Coherent — but
I verified it rather than assumed it, having just published a coincidence I had
not verified.
⇒ Same shape as slice 15, one layer down. There the evidence that a gate
discriminates was mistaken for evidence it runs. Here a **comment asserting a
guard** was mistaken for the guard. In both cases the artifact that would have
told the truth — the call sites, the runner list — was never consulted, because
the prose read like it already had been.

### ⬥ And the fix itself was incomplete — a THIRD address site (same day)

Slice 16 found two places that compute a symbol's address, guarded both, and
stopped. **There was a third, and it is the one that matters most: `SYMVAL`, the
RELOCATION-APPLICATION path — the code that actually patches bytes.**

A symbol **defined in the object that references it** never reaches the
cross-object resolver, so `STADDR`'s guard never sees it. `SYMVAL`'s
defined-symbol branch did `add(base)(SYM_VALUE(f)(ss)(i))` with no high-word
check.

**Measured against the commit that added the first two guards** (`6fde83d`): it
links a GAS object whose global `greet` sits at `0x100000010` with **rc=0**,
truncating silently. With the third guard: refused by name.

**★ Reachable with ordinary compiler output, which is the whole point.** `nasm`
always relocates against **SECTION symbols** (`.text + 0`, `.rodata + 0`), whose
`st_value` is structurally `0` — so with nasm fixtures this case is
*unconstructible*, and the existing gate could never have found it. `gcc`/GAS
relocate against a **defined global by name** (`movq $greet, %rax` →
`R_X86_64_32S` against `greet`; `gcc -c` on ordinary C gives `R_X86_64_32`
against `gfun`). The gate's third case therefore uses **GAS, deliberately**.

**⚠ And my first attempt to demonstrate this hole was an invalid test — recorded
because it nearly became the finding.** I patched `msg` (a local in `.rodata`),
saw the link succeed, and concluded `SYMVAL` had truncated it. It had not:
`readelf -r` shows nasm relocated against `.rodata + 0`, so **`msg`'s value was
never read at all** and the green run proved nothing. The rule this file already
states for gates applies to a probe just as hard: *check what the instrument
actually touches before believing what it reports.* One `readelf -r` would have —
and eventually did — settle it.

⇒ **This is slice 16's own thesis, turned on slice 16.** There, `FITS32` was
wired and correct, and its correctness ended the audit before it reached the
read-side hole. Here, `STADDR` and `SYMADDR` were real fixes at real sites, and
**finding two ended the search before it reached the third**. The lesson is not
"look harder": it is *grep for every reader of the field, and never for whether
a guard exists* — the second question has an affirmative answer long before the
field is actually safe.

*Coverage, stated exactly:* a **global** symbol at or above 4 GB is refused on
all three paths. A bare nasm `equ` above 4 GB becomes a **LOCAL `ABS`** symbol
(`HIGH_L equ 0xFFFFFFFF80000000` → `LOCAL ABS`) — it is not refused, and it is
not an address the linker ever uses; declaring it `global` makes it a real
definition and it *is* refused. That asymmetry is deliberate and measured, not an
oversight.

## Slice 17 — the kernel seam gate certified a stale artifact (2026-09-08)

Ran `gate_link_kernel.sh` on demand. **The link failed and the gate did not
notice**, then reported the failure as something else.

    15:41:53  .kseam/link.log:  error: expression nesting too deep (C stack guard)

`link.la` ran **1h55m** on track D's current `boot.o` (86,656 bytes, sha
`440822eb…`) and hit the C host's recursion guard. It produced **no image**. The
substantive result is therefore: *`link.la` cannot currently link that object* —
the ~36-minute figure was measured on a 39 KB object, this one is 2.2× larger,
and the guard fires before the DROP curve completes. Not a timeout; the 7200 s
cap never came near firing.

**★ THE GATE READ IT AS A LAYOUT DEFECT.** Its freshness guard was
`[ -s "$K/link_out" ]`, which cannot distinguish *"this link produced an image"*
from *"an image from some previous run is lying around"*. An **Aug 22**
`link_out` (58,200 bytes) satisfied it, so the `link.la produced no image` branch
never fired and checks 1-3 ran against a two-week-old image:

    PASS  link_kernel 1: objcopy accepts the LA-linked image
    PASS  link_kernel 2: entry point 0x10000c == ld's
    FAIL  link_kernel 3: segment 2 filesz 46067 != ld's 79298
    link_kernel gate RED   (rc=1)

The gate went red, which looks like the system working — **and that is the trap**.
The FAIL is real but **misattributed**: 46067 vs 79298 is an image built from a
53 KB `boot.o` compared against a control built from today's 86 KB one. Nothing
in the output says the linker produced nothing. A reader would have gone hunting
for a segment-sizing bug that does not exist.

**★★ AND IT CERTIFIED THE STALE ARTIFACT AS FRESH.** After the failed link it
wrote `link_out.inputs` with the *current* input hash. Verified: the recomputed
hash `07c643cb…` matched the stamp, so the **next** run would have skipped the
link entirely and printed *"reusing link_out — the sha256 … is unchanged since it
was produced."* False: it was not produced from those inputs. This is exactly what
the gate's own header warns of — *"a cached artifact is a false-green waiting to
happen, so freshness is CHECKED, not assumed"* — with the check having a hole the
comment's confidence concealed. Same shape as slice 16's `SYM_VHIGH`: **prose
asserting a protection that the code did not implement.**

**The fix, at both independent failure modes.** `rm -f link_out link_out.inputs`
*before* linking, so the existence test means what it says; and capture the
link's **exit status** (`lrc`), failing loudly and naming `124` as timeout —
because a linker can die leaving a stale file (caught by the `rm`) or exit
non-zero having written a partial one (caught by the status). The stamp is
written only after both pass.

**Red-tested against the real script**, with the link replaced by a failing stub
and a stale `link_out` pre-seeded — the exact scenario:

    OLD: no failure reported; ran checks 1-2 on the stale file; WROTE THE STAMP
    NEW: FAIL link_kernel: link.la exited 1 — no image produced: error:
         expression nesting too deep (C stack guard)     (stale removed, no stamp)

*Honest limit:* the fix prevents future poisoning; it does **not** detect a stamp
already poisoned by an earlier run, since that path takes the reuse branch and
never reaches the new code. The live `.kseam/link_out.inputs` was therefore
deleted by hand. A stamp recording the *output* hash as well as the inputs would
close that; not built.

**Separately, check 4 could not run at all**: `SKIP — ld's own image did not boot
cleanly here (rc=124)`. The **control** does not boot in this environment, so the
boot comparison has no baseline regardless of the linker. That is not track B's
to fix, but it means the gate's strongest assertion is currently inert.

⚠ **Method note — the monitor lied, twice, the same way.** Progress checks used
`pgrep -f 'tiny_host link_reloc'`, which matched **my own `bash -c` wrapper**
containing that string, so "still linking" was reported at 15:13, 15:17 and 15:58
for a process that died at 15:41. The same self-match then made `pkill -f` kill
the shell issuing it. `pgrep`/`pkill -f` match the *whole command line of every
process, including the one asking* — check `pgrep -x <name>`, or a path that
cannot appear in the query itself. Fifth instance today of an instrument
answering honestly about a different object than the one held.

## Slice 18 — the stack guard was OPERATIONAL, not structural (2026-09-08)

Slice 17 left the real question open: `link.la` died on D's 86 KB `boot.o` with
`error: expression nesting too deep (C stack guard)`. I had assumed depth scales
with input and that bounding the recursion was the fix. **Measurement says
otherwise — the whole failure was an inherited 8 MB `ulimit -s`.**

**The guard is not a depth counter.** It is a live stack-address probe armed
relative to `RLIMIT_STACK` (`tiny_host.c:992`):

    stack_floor = gc_stack_base - (usable - 512u * 1024);

so **the ceiling moves with `ulimit -s`**. Measured on well-formed deep programs
(`I(I(…("a")…))`):

    8 MB    depth  50 000 ok · 100 000 GUARD
    256 MB  depth 100 000 ok · 300 000 ok · 600 000 ok

**★★ AND `unlimited` IS THE WRONG LEVER — IT TIGHTENS THE GUARD.**
`tiny_host.c:994` keeps its 8 MB fallback when `rlim_cur == RLIM_INFINITY`, so
the limit is computed as if the stack were 8 MB no matter how large it really is.
Verified: depth 100 000 **fails** under `ulimit -s unlimited` and **passes** under
`262144`. Anyone reaching for the obvious remedy makes it worse and gets the same
error message either way.

**The controlled run — one variable moved.** D rebuilt `boot.o` to 39,936 bytes
mid-investigation (the size the gate was tuned for), so simply re-running would
have moved *two* variables and passed for the wrong reason. The failing run had
copied the original into `.kseam`, so the experiment used **that preserved
86,656-byte object** (`440822eb…`) with only the stack limit changed:

    stack limit in effect: 262144 KB
    linked 1 objects into 2 segments, entry 1048588
    rc=0   link_out 91,432 bytes   16:40:03 -> 19:21:58  (2h42m)

**And the image is CORRECT, not merely produced** — checked against `ld` on the
same object:

    entry          ld 0x10000c   ours 0x10000c
    LOAD 1 filesz  ld 0x53a      ours 0x53a
    LOAD 2 filesz  ld 0x135c2    ours 0x135c2
    objcopy -O elf32-i386        accepted   (the 07-23 blocker)

`0x135c2` is **79298** — the exact number slice 17's stale run quoted as *ld's*,
against "ours 46067". `link.la` matches `ld` on this object; that FAIL was the
stale artifact from end to end.

**★ A SECOND LATENT DEFECT, found only because the first was fixed.** The gate
capped the link at `timeout 7200` (2 h). The successful link takes **2h42m**. So
raising the stack alone would have left the gate failing — at the cap this time,
with a *different* misleading message. Two independent limits, both below what
the work needs, and the first one hid the second. Cap raised to `14400`.

**Fixed in the gate**: it raises its own `ulimit -s` to a large **finite** value
before linking and prints the limit that actually applied, so a future failure can
be attributed instead of guessed at. *A gate must not inherit a limit that decides
its verdict* — the ambient shell's 8 MB was silently part of the assertion.

*Honest scope:* the fix is verified at the link + image level (above), **not** by a
full end-to-end gate re-run, which is another ~3 h. The QEMU boot check also stays
blocked for an unrelated reason recorded in slice 17: `ld`'s own control image does
not boot in this environment.

*Recorded for later, not acted on:* the link peaked at **12.4 GB RSS** for an 86 KB
input (~150 000×). Not a leak — the host has a GC, so that is live data — and no
risk on this machine (188 GB, 143 free), but it is the next constraint to bind if
object sizes grow.

## Slice 19 — the 12.4 GB is NOT a size effect, and the model fails its own control (2026-09-09)

Slice 18 recorded *"the link peaked at 12.4 GB RSS for an 86 KB input (~150,000×)
… the next constraint to bind if object sizes grow"* and filed it for later.
Measured now, and **the framing was wrong**.

`link_reloc.la`, peak RSS and wall time vs object size, 3 repeats per size:

| object | RSS median | spread | time median | spread |
|---|---|---|---|---|
| 1,184 B | **36,444 KB** | 1.004× | 13.24 s | 1.035× |
| 2,864 B | **41,348 KB** | 1.007× | 82.31 s | 1.043× |

**RSS and TIME are not the same curve.** Size ×2.42 gives RSS ×1.13 — exponent
**k = 0.14, nearly flat** — and time ×6.22 — **k = 2.07, quadratic**. Slice 18
reported the 2h42m and the 12.4 GB in one sentence, which implied one cause.
There are two.

★ **AND THE CONTROL FAILS BY 193×.** Extrapolating RSS at k=0.14 to the recorded
86 KB case predicts **0.06 GB**; the record says **12.4 GB**. ⇒ **The 150,000× is
not a smooth scaling effect.** Small objects do not exercise whatever produces it:
it is a **threshold or structural** effect — plausibly relocation count, section
count, or a specific construct in `kernel/boot.o`. **Making inputs bigger will not
find it. The next probe must vary object SHAPE, not object SIZE.**

⚠ **This is a refutation, not a diagnosis.** It establishes what the cause is not.
Two points cannot name it, and fitting a cause from two points is the exact
two-point extrapolation retracted earlier the same day.

⚠ **Sizes 512 and 2048 abandoned as infeasible** — at k=2.07 they project to ~10 h
and ~163 h, and would have spent ~3 h recording `rc=124`. The two completed sizes
answer the question that was asked.

**Method, because the harness failed four times before yielding a single row, and
every failure was in the instrument rather than the linker:**
`pkill -f` killed the job it was launching (exit 144), taking the guard fix with
it · the guard counted *shells* not binaries · `pgrep -c` prints `0` **and** exits
1, so `|| echo 0` produced `"0\n0"` and the arithmetic died · and
`/usr/bin/time`'s own stderr was redirected into `/dev/null`, so **the link
succeeded and the row came back empty** — which would have landed as fifteen rows
of blanks that look like data. Only a smoke test at the smallest size caught it.
★ **RSS was the metric to trust under load** (spread 1.004×) because peak RSS is
per-process; the time column was taken with a live front and underpins no claim.

## Slice 20 — shape is not the cause either; a REAL object still misses by 18× (2026-09-09)

Slice 19 excluded size and concluded *"the next probe must vary object SHAPE, not
object SIZE."* Done, and shape does not explain it either.

`kernel/boot.asm` assembled **locally** — `nasm -f elf64 -i .bootfix2_HH2B/` —
which also retires `gate_link_kernel.sh`'s own stated honest limit, that a
reproducible version *"would assemble boot.asm here"* rather than read Track D's
uncommitted artifact.

| object | shape | peak RSS | time |
|---|---|---|---|
| 2,864 B synthetic | 32 relocs, ~5 sections | 40 MB | 82 s |
| **7,104 B real** | **53 relocs (41× `R_X86_64_64`), 12 sections, 98 syms** | **86 MB** | **423 s** |

**RSS exponent k = 0.84 — still SUBLINEAR** even on a real object with real
relocation types. Extrapolated to 86 KB: **0.70 GB**. Recorded: **12.4 GB**.
⇒ **Still 18× short.** Time k = 1.81, quadratic, consistent with slice 19.

⇒ **Four shape dimensions now exercised at realistic values — relocation count,
relocation TYPE, section count, symbol count — and RSS stays sublinear in all of
them.** Combined with slice 19's exclusion of size, the 150,000× belongs to
neither.

⚠ **A second refutation, not a diagnosis.** What is excluded is now large and what
is identified is still nothing. **The honest next step needs Track D's ACTUAL
86 KB boot.o** — mine assembles to 7,104 B, so theirs is a different build
(different includes/config, or a `--script` layout path a plain link never takes).
That artifact is in their worktree; filed as a cross-track question rather than
read.

## Slice 21 — RSS and TIME have different drivers; the blob axis is real but partial (2026-09-09)

Slices 19 and 20 excluded size and four shape dimensions, and left an 18× shortfall
against the recorded 12.4 GB. POROS and METANOĒ pointed out what every fixture so
far had in common: **they were all code-shaped.** POROS's real `boot.o` carries an
`incbin`'d LA image — a large opaque data section — which **my fixtures could not
have varied.** That is the fixture-cannot-exercise-the-mechanism class, and it was
mine this time.

| object | bytes | relocs | RSS | time | KB RSS/byte | s/reloc |
|---|---|---|---|---|---|---|
| synthetic code | 2,864 | 32 | 40 MB | 82 s | 14.3 | 2.6 |
| real stub code | 7,104 | 53 | 86 MB | 423 s | 12.4 | 8.0 |
| code control | 11,792 | 95 | 218 MB | 1107 s | 18.9 | 11.7 |
| **blob** | **6,960** | **1** | **236 MB** | **18.5 s** | **34.7** | — |

★ **THE TWO CURVES HAVE DIFFERENT INDEPENDENT VARIABLES.**
- **TIME is driven by RELOCATIONS.** One relocation links in **18.5 s**; ninety-five
  take **1107 s** — 60× the time for 1.7× the bytes.
- **RSS is driven by BYTES**, with blob data ~**2.4×** heavier per byte than code
  (34.7 vs 12–19 KB/byte).
⇒ Slice 19 observed RSS (k=0.14) and time (k=2.07) diverging and could not say why.
**This is why.** They are not one phenomenon measured badly; they are two phenomena
that happen to be reported in one sentence.

⚠ **IT DOES NOT CLOSE THE GAP.** At 34.7 KB/byte the recorded 86 KB case
extrapolates to **2.9 GB** against **12.4 GB** recorded. The blob narrows the
shortfall from 18× to ~4×; it does not explain it. **Recorded as partial, because a
partial explanation reported as a complete one is how three claims went wrong on
this same day.**

⚠ **A DEFECT IN MY OWN FIXTURE.** The two objects were designed to be the SAME SIZE
and are not — 6,960 B vs 11,792 B. nasm's output did not match the intent and **I
did not check before spending 19 minutes linking them.** Per-byte normalisation is
what rescues the comparison; a same-size pair would have been the cleaner test.

⚠ **THE X-AXIS IS NOT A CONSTANT.** POROS's `boot.o` is **46,352 B at this writing,
not 86 KB** — it tracks the embedded LA image and moves whenever that image is
rebuilt. Any future measurement must record WHICH image was embedded, or it is a
count without its file-time. Build line, for reproducibility:
`nasm -f elf64 -i kernel/ kernel/boot.asm -o kernel/boot.o` (`kernel/build_k1.sh:21`).

**Still unexplained: ~4×.** Not excluded — superlinearity in blob size (mine was
6 KB, POROS's ~40 KB), or the `--script` layout path, which no probe here has taken.

## Slice 22 — FOUND IT: RSS is superlinear in the incbin'd DATA, k≈1.67 (2026-09-09)

Slices 19–21 excluded size, four code-shape dimensions, and left ~4×. Two more
candidates remained. **One is refuted and the other is the cause.**

### Refuted first: the `--script` layout path and the LOAD ADDRESS
Same 560 B object, three scripts differing only in load address:

| script | peak RSS | time | link_out |
|---|---|---|---|
| `. = 0x1000` | 34 MB | 1.2 s | 4,528 B |
| `. = 0x100000` | 34 MB | 1.2 s | 4,528 B |
| `. = 0x400000` | 34 MB | 1.3 s | 4,528 B |

**Identical in all three.** `link.la` uses file offsets correctly and does **not**
materialise the gap between load address and file start. ⇒ Neither `--script` nor
the high `0x400000` load address of `kernel.ld` contributes anything.

### ★★ THE CAUSE: RSS grows SUPERLINEARLY IN THE BLOB, and the per-byte cost RISES

Held at **exactly one relocation** throughout; only the `incbin`'d data grows:

| object bytes | RSS | KB RSS/byte | pairwise k |
|---|---|---|---|
| 6,960 | 236 MB | 34.7 | — |
| 13,104 | 616 MB | 48.1 | 1.52 |
| 25,392 | 1,870 MB | 75.4 | 1.68 |
| 49,968 | **6,347 MB** | 130.1 | **1.81** |

**Overall k = 1.67, and rising** — the same steepening shape the codegen curve
showed. **Per-byte cost nearly quadruples across one decade of blob size.**

### ★★★ AND IT PREDICTS THE CONTROL, WHICH NOTHING ELSE DID
Extrapolated to the recorded 86 KB case: **16.0 GB** against **12.4 GB** recorded —
**within 1.29×.**
Slice 20's code-shaped model predicted **0.70 GB**: 18× short. **The control is now
reproduced from the other side**, on the axis the earlier fixtures could not vary.

⇒ **The 150,000× is a DATA-SECTION effect, superlinear in blob bytes.** It is not
size (slice 19), not relocation count or type or section or symbol count (slice 20),
not the linker script and not the load address (above). **The `boot.o` that blew up
is ~90% one `incbin`'d LA image, and that is the whole of it.**

⚠ **Honest bounds.** Four points over one decade with a *rising* local exponent, so
1.67 is an average across a curve that steepens — the same caveat that made slice 19's
endpoint fit an artifact. Predicting 16.0 GB against a recorded 12.4 GB is agreement
in ORDER and shape, not a fitted constant. And the recorded 86 KB is itself not a
fixed number: `boot.o` tracks the embedded image and was 46,352 B when POROS measured.

**Consequence for the linker:** the constraint that binds as the kernel grows is the
**embedded image**, not the code. A kernel with twice the LA image costs ~3× the
link memory, not 2×.

⚠ **CORRECTED 2026-09-09 by POROS, and my framing was too relaxed.** I wrote
*"nothing to act on today … before the image doubles"*, which reads as further off
than it is. Track D measured where the kernel actually sits on this curve:

| artifact | bytes | on my curve |
|---|---|---|
| `kernel/boot.o` today (image 27,347 B) | 34,208 | **~3.0 GB** |
| my largest MEASURED point | 49,968 | 6.2 GB ← measured |
| `kernel_comp_edit.elf` / HAL.4g image | 86,128 | **~15.4 GB — past every point I measured** |

⇒ **The plain kernel is ALREADY between my 25 KB and 50 KB points, and HAL.4g is
past my largest measured point entirely.** This is not a future constraint that
arrives when the image doubles; **the kernel is already on the steep part.**
★ And it is self-consistent: 86,128 B predicts ~15.4 GB against the **12.4 GB
originally recorded** — the same neighbourhood, from the other direction.
Still harmless on a 188 GB machine; the compositor images are the largest LA
programs in the tree and are the ones that grow. Track D owns the curve.

