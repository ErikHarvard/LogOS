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

## Reproduce (~26 min, native VM)

Runs a native SECD VM cycle, so do it in a scratch dir, and **never while
another session drives `logos_program.bin`** (the VM re-executes that one path).

```sh
mkdir -p .bootelf && cd .bootelf
# toolchain + the ELF-object driver
cp ../tiny_host ../secd.la ../codegen.la ../asm.la ../elfobj.la ../asmelfobj.la ../la_flatten.py .
# boot.asm + its four %includes + the incbin stub (from the frozen .bootrun set,
# which is byte-identical to kernel/ except entry.inc — regenerated per build,
# harmless here since nasm and asm.la assemble from the SAME dir)
cp ../.bootrun/boot.asm asm_in.asm
cp ../.bootrun/entry.inc ../.bootrun/idt.asm ../.bootrun/timer.asm ../.bootrun/kbdirq.asm .
cp ../.elfobjgate/native_codegen3_out .          # incbin target stub

./tiny_host secd.la                              # emit logos_secd (~30s)
python3 la_flatten.py asmelfobj.la logos_source.la asm.la:A_ elfobj.la:E_
./tiny_host codegen.la                           # ~12 min -> logos_program.bin
./logos_secd                                     # ~14 min -> elfobj_out.o

# the gate: link ours and nasm's, compare
nasm -f elf64 asm_in.asm -o ref.o
ld ref.o        -o ref.elf
ld elfobj_out.o -o ours.elf
cmp ref.elf ours.elf && echo "GREEN — ld(ours) == ld(nasm)"
```

## Cheap regression guard (in `build.sh`)

The full cycle is too slow for the audit (like the QEMU kernel gates). The
CHEAP guard is `./gate_asmelf.sh` — fixtures `asm_elf_r3..r9`, ~30s, each
exercising one mechanism `boot.asm` needs (every reloc type; `equ` symbols at
ABS with 64-bit values; NOBITS / alignment / unknown sections; re-entered
sections MERGING with symbols in source order; 32-bit absolute `[disp32]` +
moffs; memory-displacement and far-jump relocs; 64-bit bitwise constants). It is
wired into `build.sh`'s asm section, so a regression in any of those fails the
build without a 26-minute run.
