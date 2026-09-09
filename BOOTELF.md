# boot.asm through asm.la — the nasm-free object step

`asm.la` assembles the real kernel `boot.asm` into an ELF64 relocatable object
that links **byte-identically to nasm's** (`ld(ours) == ld(nasm)`). This closes
the NASM seam for the OBJECT step of the kernel build. Verified GREEN
2026-07-23.

## What is proven, and what is not

- **Proven:** `asm.la` (assembly) + `elfobj.la` (the ELF64 object writer) produce
  an object semantically identical to `nasm -f elf64 boot.asm` — every section
  header, all 106 symbols, all 53 relocations, and the linked image itself.
- **Not this:** the kernel still invokes `ld` for the final link. That seam is
  the LA linker (`link.la`, Track B). So this is "nasm-free object step," not yet
  "nasm+ld-free kernel."
- **The standard is one level up from `.o` byte-identity.** An object's internal
  layout — section order, padding, the bytes in a field a relocation will
  overwrite — is nasm convention, not semantics. What an object *means* is what
  it links to, so the gate is `ld(ours) == ld(nasm)`, not `cmp` of the objects.

## Why it needs the native VM (not `./tiny_host`)

The C host (`tiny_host`) **walls at ~15 min** on `boot.asm` — but not where the
old note guessed. The wall is `codegen.la`'s **import mangler**: compiling
`asmelfobj.la` (which `import`s `asm.la`, ~2400 lines) sat at 11.8 GB for 36 min
of CPU without finishing. Resolving the imports OFFLINE first gives ~12 min and
~5 GB for a **verified byte-identical** result — so `la_flatten.py` is not an
optimisation, it is what makes the VM path viable.

`la_flatten.py` must rename each module's PRIVATE glyphs: `asm.la` and
`elfobj.la` collide on 15 names, and `CONS`/`NIL` are **Scott-encoded in one and
fold-encoded in the other** — same spelling, different functions. It reproduces
the module system's isolation exactly (exports keep their spelling, privates are
prefixed), and is verified byte-identical to the real `import` build on every
`asm_elf_*` fixture.

## Reproduce (native VM — see "Measured cost" below; the old "~26 min" is not what this machine does)

Runs a native SECD VM cycle, so do it in a scratch dir, and **never while
another session drives `logos_program.bin`** (the VM re-executes that one path).

```sh
mkdir -p .bootelf && cd .bootelf
# toolchain + the ELF-object driver
cp ../tiny_host ../secd.la ../codegen.la ../asm.la ../elfobj.la ../asmelfobj.la ../la_flatten.py .
# boot.asm + its four %includes + the incbin stub (from the frozen .bootrun set,
# which is byte-identical to kernel/ except entry.inc — regenerated per build,
# harmless here since nasm and asm.la assemble from the SAME dir)
cp ../.bootrun/boot.asm boot_base.asm
cp ../.bootrun/entry.inc ../.bootrun/idt.asm ../.bootrun/timer.asm ../.bootrun/kbdirq.asm .
cp ../.elfobjgate/native_codegen3_out .          # incbin target stub

./tiny_host secd.la                              # emit logos_secd (~30s)
python3 la_flatten.py asmelfobj.la logos_source.la asm.la:A_ elfobj.la:E_
./tiny_host codegen.la                           # ~12 min -> logos_program.bin

# ONE OBJECT PER ARM. boot.asm's three equ sites live in MUTUALLY EXCLUSIVE
# arms of an %elifdef chain, so a single un-armed build assembles NONE of them
# — the hollow green this cycle used to produce (FREEZE_II_FINDINGS.md Q0b).
# The arm is selected by a %define PREPENDED TO THE SOURCE, never by a -D on
# one side only: nasm and asm.la must read the identical file.
mkdir -p obj
for ARM in NONE HH1 HH2; do
    if [ "$ARM" = NONE ]; then cp boot_base.asm asm_in.asm
    else { printf '%%define %s\n' "$ARM"; cat boot_base.asm; } > asm_in.asm; fi
    ./logos_secd                                 # ~14 min each -> elfobj_out.o
    cp elfobj_out.o "obj/ours_$ARM.o"
done

# the gate: per arm, link ours and nasm's and compare — and assert each arm
# actually CARRIES the equ sites it exists to cover.
../gate_bootelf.sh . obj
```

## Verdict, 2026-09-09 — the per-arm cycle was run, and it is GREEN

The first time this gate has ever been run against real `asm.la` objects on the arms it exists to
cover. All three produced objects (`rc=0`) and all three link byte-identically to nasm's:

| arm | ours.o | symbols | relocs | equ sites in BOTH objects | `ld(ours)==ld(nasm)` |
|---|---|---|---|---|---|
| NONE | 6,820 B | 104 | 53 | none — the control | **GREEN** |
| HH1  | 7,378 B | 111 | 60 | `hh_msg_len` | **GREEN** |
| HH2  | 8,337 B | 116 | 84 | `hh2_ok_len`, `hh2_bad_len` | **GREEN** |

Arm-set union: all three sites covered. **`asm.la` assembles the HH1 and HH2 arms of the real
kernel `boot.asm` correctly** — never previously tested, because the un-armed build compiled the
construct away before the assembler saw it.

★ **The green was red-tested on these same objects, not merely asserted.** Planting the defect
class in the real `ours_HH1.o` — `hh_msg_len`'s imm32 `4 -> 5`, i.e. `asm.la` computing the equ
one byte long — turns HH1 **RED** (`differ: byte 4754`) while NONE and HH2 stay GREEN. Note the
site sits at file offset `0x183` in `asm.la`'s object against `0x447` in nasm's: different layout,
identical semantics, which is exactly why the standard is `ld(ours)==ld(nasm)` and not `.o`
byte-identity.

## Measured cost, 2026-09-09 — the documented figures do not reproduce

The `~12 min` / `~5 GB` above is the 2026-07-23 figure and it was never re-derived.
Re-run end to end on this machine (24 cores, load/core 0.36 by `~/logos-hw.sh`,
156 GB free — i.e. *not* contended), the whole cycle is:

| phase | measured |
|---|---|
| `tiny_host secd.la` → `logos_secd` | 47 s |
| `la_flatten` + `tiny_host codegen.la` → `logos_program.bin` | **~22 min, ~9.4 GB peak** |
| `logos_secd` per arm → `elfobj_out.o` | **NONE 26 min · HH1 30 min · HH2 39 min** (run in parallel) |

★ **The obvious explanation is wrong, and the control is what showed it.** `asm.la` has grown
since July, so the natural hypothesis is that the cost grew with it. Tested by re-running phase 2
against the **July** `asm.la`/`elfobj.la` (`430b2a7`) on the same machine:

| phase-2 input | wall | peak RSS |
|---|---|---|
| documented, 2026-07-23 | ~12:00 | ~5 GB |
| **July `asm.la`, 155,700 B** | **18:12** | **8.52 GB** |
| current `asm.la`, 185,477 B | ~22:00 | ~9.4 GB |

The July code takes **18:12 and 8.5 GB here too**. So growth explains the *delta between the two
versions* (1.19× input → 1.21× time, near-proportional) and explains **none** of the gap to the
documented figure. Whatever `~12 min / ~5 GB` measured, this hardware does not reproduce it for
either version — so plan against the table above, not against the July line.

⚠ A caution the numbers themselves cannot carry: the per-arm figures are for **three VMs running
concurrently**, and phase 2's `~22 min` was read off polling rather than `/usr/bin/time` (the
18:12 control *is* precisely measured). Treat the arm times as an upper bound for one arm alone.

## Cheap regression guard (in `build.sh`)

The full cycle is too slow for the audit (like the QEMU kernel gates). The
CHEAP guard is `./gate_asmelf.sh` — fixtures `asm_elf_r3..r9`, ~30s, each
exercising one mechanism `boot.asm` needs (every reloc type; `equ` symbols at
ABS with 64-bit values; NOBITS / alignment / unknown sections; re-entered
sections MERGING with symbols in source order; 32-bit absolute `[disp32]` +
moffs; memory-displacement and far-jump relocs; 64-bit bitwise constants). It is
wired into `build.sh`'s asm section, so a regression in any of those fails the
build without a 26-minute run.

**The cheap guard does not subsume the scale gate, and neither one subsumes
per-arm coverage.** `gate_asmelf.sh` runs synthetic fixtures; `gate_bootelf.sh`
runs the real 60 KB file — but only over the arms named in its `ARMS` list
(`NONE HH1 HH2`), which are the arms carrying the three `equ` sites. `boot.asm`
has **51** conditional arms (`grep -cE '^[[:space:]]*%(ifdef|ifndef|elifdef)'`),
so **49 are covered by neither gate** — and a coverage claim phrased per-gate
cannot even express that gap. See `FREEZE_II_FINDINGS.md` Q0b.
