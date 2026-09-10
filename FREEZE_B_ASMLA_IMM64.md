# asm.la: `mov r64, imm` drops the high 32 bits (found 2026-08-20, track-b)

## The defect

    source:  mov rax, HIGH_BASE          HIGH_BASE equ 0xFFFFFFFF80000000

    nasm:    48 C7 C0 00 00 00 80  (7 B)   mov rax, sign_extend32→64(0x80000000)
                                                  → rax = 0xFFFFFFFF80000000  CORRECT
    asm.la:  B8 00 00 00 80        (5 B)   mov eax, 0x80000000
                                                  → rax = 0x0000000080000000  WRONG

`asm.la` selects the short `mov eax, imm32` form for a 64-bit immediate that
requires `REX.W + C7 /0 imm32` (sign-extended). The high half is lost.

In this fixture `asm.la` emits the `48 C7 C0` form **zero times** where nasm
emits it twice — it does not appear to implement the encoding at all here.

## Impact

`HIGH_BASE` is the higher-half kernel base. A kernel assembled through this path
computes its high alias as `0x80000000` instead of `0xFFFFFFFF80000000`, and
sets a "HIGH stack for the LA image" (asm_in.asm:669) to the same wrong value.
It would not survive the transition to the higher half.

The shortfall also cascades: 2 bytes per site shifts every subsequent
`call rel32` and every `R_X86_64_64` addend after it (HH1: 0x20c→0x20a,
0x215→0x213, 0x21e→0x21c, 0x227→0x225, 0x230→0x22e, 0x239→0x237).

## Why the shipped gate cannot see it

The three `mov rax, HIGH_BASE` sites are under `%elifdef HH1` / `%elifdef HH1B`
/ `%elifdef HH2`. **The no-flag build never assembles them** — neither encoding
appears in the NONE object (nasm=0, ours=0), and NONE passes completely clean:

    PASS section set identical
    PASS relocation tables identical — 53 entries, offset/type/symbol/addend
    PASS .boot32 / .rodata / .multiboot / .la_image identical outside
         relocated fields

No amount of care reading the no-flag gate would have found this. It required
assembling a different arm.

## Root cause (track A, verified here)

`MOVIMM` (`asm.la:342` on track-b, `:388` on kernel-k1 — line numbers drift,
constructs do not) branches purely on operand WIDTH: `w=1` -> `0xB0+r`,
`w=2` -> `66 B8+r`, else -> `B8+r imm32`. **There is no `C7 /0` register-direct
branch in the function.** The only `199` (0xC7) in the file is at `:642`, the
immediate-to-MEMORY form. So `asm.la` implements two of NASM's three
`mov r64, imm` forms:

    imm fits unsigned 32     B8+r imm32         zero-extends    implemented
    imm fits SIGNED 32 only  REX.W C7 /0 imm32  sign-extends    ABSENT
    neither                  REX.W B8+r imm64   movabs          implemented

`0xFFFFFFFF80000000` truncates to `0x80000000`, satisfies "fits in unsigned 32",
and takes the short form.

`asm.la`'s own header documents the incomplete rule as complete: *"when the
immediate fits in unsigned 32 bits NASM takes the shorter form and drops REX.W
entirely."* Accurate about what the code does, silent about the case it omits --
and nothing witnessed the gap, because a signed-32-only immediate never appears
in the no-flag build.

## VERIFIED FIXED (2026-08-20 23:19, patched asm.la, boot fixture)

    arm    .boot32   relocs   HIGH_BASE  old defect form   verdict
    NONE    877 B    53 ==    0          0                 unchanged (control)
    HH1    1018 B    60 ==    1/1        0                 PASS all sections
    HH2    1311 B    84 ==    2/2        0                 PASS all sections

Every section byte-identical to nasm outside relocated fields, and the
relocation tables — which DIFFERED before the fix — now match on offset, type,
symbol AND addend. `.boot32` grew exactly +2 (HH1, one site) and +4 (HH2, two
sites), the shortfall the defect was producing. NONE is unchanged, so the fix
touches nothing it should not. A 19-case unit matrix is byte-identical to nasm.

## Blast radius: 16 sites across 9 arms — WIDER THAN FIRST FILED

The original filing said 11 sites / 5 arms, counting only `mov rax, HIGH_BASE`.
Enumerating every arm and counting `REX.W C7 /0 reg` (`(48|49) c7 c0..c7`, all
registers) finds more:

    HH1  1   HH1B 2   HH2  2   HH2B 2   HH2C 5      (higher-half transition)
    IPC  1   K6C  1   K6C2 1   K6C3 1               ← NOT in the HH family

The four outside the HH family, plus HH2C's fifth, are **`mov rax, -1`**. The
old encoder emitted `b8 ffffffff`, giving `rax = 0x00000000FFFFFFFF` instead of
all-ones — an all-bits sentinel/mask silently becoming a 32-bit one. So the
defect is not confined to the higher-half work: it reaches the IPC and K6C
paths too.

`LA_RING3_IMAGE` is UNBUILDABLE (`symbol 'k6a_tss' not defined`), joining HH2B
and HH2C as arms that cannot be assembled from committed state.

## Original count: 11 sites across 5 arms, ASSEMBLED not read

    NONE  0        HH1  1        HH1B 2
    HH2   2        HH2B 2        HH2C 4        = 11

Every one is the higher-half transition, where a wrong `rax` is unrecoverable
rather than merely incorrect.

`HH2B` and `HH2C` are NOT standalone arms: both need `METAL_FLAG_ABS`, which
`build_k6b.sh` derives and writes into `entry.inc`. Assembling them without it
fails, so an arm set enumerated by reading guards would list them as arms that
cannot be built. **Arms have dependencies; the set is not flat.**

**Two of the five defective arms are UNBUILDABLE FROM COMMITTED STATE.**
`build_k6b.sh:38` writes both `LA_ENTRY` and `METAL_FLAG_ABS` into
`kernel/entry.inc`, but every `entry.inc` that exists contains ONLY `LA_ENTRY`
(22 bytes, `LA_ENTRY equ 0x410a9e` frozen; `0x402fb6` live on kernel-k1), and no
tracked `.inc` in the repo defines `METAL_FLAG_ABS` at all. track-b has no
`kernel/entry.inc` committed whatsoever. So the checked-in file was not produced
by `build_k6b.sh` -- a different generator made it, and nothing on disk can
assemble HH2B or HH2C until a build step the arm listing never mentions has run.

An arm list read from guards therefore contains entries that are not merely
untested but **unrunnable**, and nothing in the listing distinguishes them. The
site counts for those two arms in this document were obtained by supplying
`-D METAL_FLAG_ABS=0x400078` by hand.

## SECOND, INDEPENDENT LIMITATION: `add r64, <label>` is unsupported

Assembling HH2B with the patched `asm.la` halts:

    asm: unsupported ALU operand: k6a_kstack_top

Sources — FOUR sites, TWO symbols, enumerated by CONSTRUCT (an ALU op with a
non-register operand) rather than by symbol:

    :829  add rax, k6a_kstack_top     HH2B   <- HH2B halts here
    :937  add rax, k6a_tss            HH2C   <- HH2C halts here
    :947  add rax, k6a_tss            HH2C
    :952  add rax, k6a_kstack_top     HH2C

Measured halts: HH2B `unsupported ALU operand: k6a_kstack_top`, HH2C
`unsupported ALU operand: k6a_tss`. I predicted HH2C would halt at :952 on
`k6a_kstack_top` and it did not — :829 is inside HH2B's block and inactive under
HH2C, so the first ACTIVE site is :937. **Predicting by symbol instead of by
construct, for the third time in one session** — the same error that undercounted
the imm64 radius at 11 instead of 16.
`ALUENC` accepts REGISTER-TO-REGISTER only; a label or immediate operand is an
explicit `error(...)`. nasm assembles both arms fine (nasm_ref.o is 8656 B).

This is PRE-EXISTING and unrelated to the imm64 fix: the error string is in the
unpatched `asm.la`, and the patch touches no ALU path (0 hits for "ALU").

**Consequence for the freeze: 7 of the 16 defect sites (HH2B 2 + HH2C 5) live in
arms `asm.la` CANNOT ASSEMBLE AT ALL.** The imm64 fix is verified on NONE, HH1,
HH2 and HH1B. HH2B and HH2C cannot be verified end-to-end through `asm.la` until
ALU-immediate support exists — so their sites are counted from nasm's encoding,
not from a comparison. That is a stated scope limit, not a passed test.

It also means the count of arms that cannot be built is now FIVE, by two
different causes:
    HH2B, HH2C           `METAL_FLAG_ABS` undefined in any committed state
    LA_RING3_IMAGE       `k6a_tss` not defined
    HH2B, HH2C (again)   `add r64,<label>` unsupported BY asm.la, though nasm
                         accepts them — an assembler gap, not a fixture gap

### The ALU gap is FIXED — unit-verified, boot verification IN FLIGHT

`ASMLA_ALU_LABEL_FIX.patch` (72 lines, applies on top of the imm64 patch;
`ASMLA_BOTH_FIXES.patch` is the combined 177-line form). It needed FOUR parts,
not the one the error message suggests:

1. **`G1IMM32`** — a forced-imm32 variant. `G1IMM` picks the sign-extended imm8
   short form when the value fits, and a label address like `0x2a` DOES fit, so
   routing labels into it would emit `48 83 C0 2A` where nasm emits
   `48 05 imm32`. Worse, the length would then depend on an address unknown in
   pass 1 — the SIZEL/ENC1 disagreement the hardcoded-10 MOVLBL bug already cost
   once. This form's length is value-independent, so the two cannot drift.
2. **`G1ENC`** — route a label operand there instead of halting. `LABADDR`
   errors on an unknown symbol, so a genuinely bad operand still fails loudly
   (with a better message: "undefined label" rather than "unsupported operand").
3. **`RELLINE`** — an ALU arm emitting the relocation. Without it the bytes look
   right and the linker gets a bare address with no fixup: `R_X86_64_32S` at
   `linelen-4` for a 64-bit destination, `R_X86_64_32` otherwise, matching what
   nasm does (measured: `add rax,tgt` -> 32S, `add eax,tgt` -> 32).
4. **The size path** — `LABADDR` was being called in PASS 1 and halting with
   "undefined label". `MOVSIZE` avoids this by sizing with `0`; the ALU path now
   does the same.

Unit-verified against nasm on `add/sub/cmp` with rax, rbx, rcx, rdx and eax:

    .boot32   43 B both, byte-identical outside relocated fields
    relocs    5/5 identical — offsets, types AND addends
              add rax,tgt -> 48 05 imm32      (accumulator short form)
              add rbx,tgt -> 48 81 C3 imm32
              add rax,8   -> 48 83 C0 08      (imm8 still chosen for real values)

**NOT yet verified at boot scale.** HH2B and HH2C are assembling now; until they
land, the four real ALU sites are covered only by the unit fixture. Stated as
in-flight, not as passed.

## The fix must key on "fits unsigned 32", not on "looks symbolic"

`HIGH_BASE` (0xFFFFFFFF80000000) fails that predicate; `METAL_FLAG_ABS`
(offset + 0x400078) passes it. A fix widened to "any symbolic immediate takes
`C7 /0`" would break four currently-CORRECT sites and regress byte-identity
with nasm. That discrimination is precisely the one `MOVIMM` does not make.

Checked and NOT part of this defect: the four `mov rax, METAL_FLAG_ABS` sites
(450, 836, 966, 1131). `METAL_FLAG_ABS` is a file offset + `0x400078` -- a low
address that fits unsigned 32, so the short form is correct there.

## Measured, three arms end-to-end

    arm    equ sites                          HIGH_BASE sites   .boot32 shortfall
    NONE   (none — all compiled out)          0                 0 (clean)
    HH1    hh_msg_len  41B904000000   PASS    1                 2 B
    HH2    hh2_ok_len  41B917000000   PASS    2                 4 B
           hh2_bad_len 41B918000000   PASS

**The equ-site encodings are correct.** The defect found alongside them is
unrelated to the equ question that prompted the run.

## The arm set is 22, not 2

    HAL2B HAL4 HH1 HH1B HH1_HIGHMAP HH2 HH2B HH2C HH2_PTS IPC K2_FAULT
    K4C_WX K5B2 K5B2_DBG K5_TIMER K6A K6B K6C K6C2 K6C3 LA_RING3_IMAGE RING3

`HH1B` reaches two `HIGH_BASE` sites and was not in either track's working set.
Arms are mutually exclusive, so full coverage of this file is not achievable in
one build at all — coverage must be per-arm, over a set enumerated by
assembling and observing.

## Method note

A raw byte-compare of the objects is the WRONG gate and would have accused
`asm.la` falsely on the clean arm: nasm zeroes a relocated field and carries the
value in the RELA addend, while `asm.la` writes it inline. Both are correct —
the linker writes S+A either way. `asmelfobj.la`'s own header says the gate is
`ld(ours) == ld(nasm)`, not byte-identity of the `.o`. Relocation fields are
masked by `maskrel.py` (which refuses on an unknown relocation type rather than
skipping it) before comparing, and relocation tables are compared separately as
the semantic content.

## Not fixed here

This is a finding, not a fix. The correct encoding choice for `mov r64, imm` is
a real decision (when to use `B8+r imm32`, `REX.W C7 /0 imm32`, `REX.W B8+r
imm64`) and belongs in daylight, not alongside three running VMs.


# THIRD AND FOURTH DEFECTS — exposed by fixing the ALU gap (2026-08-21)

Unblocking HH2B and HH2C made them assemblable for the first time, and they
immediately failed the nasm comparison for two NEW reasons. Both are
PRE-EXISTING and unrelated to either fix (my patches touch no memory-operand
path: 0 hits for MEMENC, MREX, MEMTAILX, P67, 0x67, MEMIDX, MEMSCALE).

## Defect 4 (worst): an INDEX REGISTER IS SILENTLY DROPPED after a displacement

    source                nasm                ours                verdict
    [r8 + 24 + r9]        43 8a 44 08 18      41 8a 40 18         INDEX DROPPED
    [r8 + r9 + 24]        43 8a 44 08 18      43 8a 44 08 18      correct
    [rsi + r9]            42 8a 04 0e         42 8a 04 0e         correct
    [rsi + 24 + r9]       42 8a 44 0e 18      8a 46 18            INDEX DROPPED

The trigger is TERM ORDER, not the registers: an index that appears AFTER a
displacement term is lost. `[base + index + disp]` encodes correctly;
`[base + disp + index]` silently reads from the wrong address.

This is the most severe class found in this audit. It is not a size difference
or a missing prefix — the instruction assembles, links and runs, and reads the
wrong memory. Live site: asm_in.asm:1072 `mov al, [r8 + 24 + r9]`, the ring-3
IPC receive path copying into the caller's buffer.

## Defect 3: missing 0x67 address-size prefix for a 32-bit memory base

    [edi]   nasm 67 8b 07   ours 8b 07

A 32-bit register used as a memory base in 64-bit mode needs the 0x67
address-size override. 10 source lines use this form. HH2B: 2 sites, HH2C: 4.

## How the shortfalls decompose, measured

    HH2B   2 B short = 2 missing 0x67 prefixes                    fully explained
    HH2C   6 B short = 4 missing 0x67 prefixes + 2 dropped indexes  fully explained

## Status of the two arms

HH2B and HH2C now ASSEMBLE (the ALU gap is fixed) and their HIGH_BASE sites are
correct (2/2 and 5/5, zero old defect forms), with .rodata, .multiboot and
.la_image all byte-identical outside relocated fields. They FAIL only on these
two new defects. So the imm64 and ALU fixes are confirmed on these arms; the
arms are not yet byte-identical for reasons neither fix addresses.


## BOTH FIXED — unit-verified, boot verification IN FLIGHT

`ASMLA_MEMOPERAND_FIX.patch` (119 lines, on top of the other two;
`ASMLA_ALL_FIXES.patch` is the 290-line pristine->all-four form).

**Defect 4** — `MEMIDXTOK` read exactly ONE term past the base
(`UPTOSIGN(AFTERPLUS(...))`), so `[r8 + 24 + r9]` inspected `24`, found no
register, and lost `r9`. Replaced by `IDXSCAN`, which walks every term for the
first register. `MEMDISP` needs no change: it EVALs the whole tail with unknown
names resolving to 0, so a register term already contributes nothing to the
displacement wherever it sits.

**Defect 3** — the `0x67` prefix cannot live inside `MEMENC`/`MEMIMM`, which
receive the base as a REGISTER NUMBER with the width already discarded. `P67` is
therefore applied at the 8 sites where the bracketed TOKEN is still in scope,
guarded by `ISREG` first because a base may be a label.

Unit-verified byte-identical to nasm on 10 cases:

    mov [edi], eax          67 89 07          prefix, memory destination
    mov dword [edi+4], 0    67 c7 47 04 ...   prefix through MEMIMM
    mov eax, [edi]          67 8b 07          prefix, memory source
    add dword [edi], 5      67 83 07 05       prefix through G1MEMIMM
    lea rbx, [edi + 8]                        prefix through LEA
    mov al, [r8 + 24 + r9]  43 8a 44 08 18    index after displacement
    mov al, [rsi + 8 + r9*4]                  scaled index after displacement
    mov [rdi], eax          89 07             NEGATIVE CONTROL: no prefix
    mov rax, [rbx + 16]     48 8b 43 10       NEGATIVE CONTROL: no prefix

The negative controls matter as much as the positives: they prove the prefix is
not applied to a 64-bit base.

**Why both survived every existing check.** A missing `0x67` makes the
instruction one byte SHORTER, so it fails only a byte-identity comparison. The
dropped index produces a same-shape instruction addressing DIFFERENT MEMORY --
identical length, valid encoding, wrong address. Neither is reachable from the
no-flag build, and both live in arms that could not be assembled at all until
the ALU gap was fixed.

**NOT yet boot-verified.** HH2B and HH2C are assembling with all four fixes; the
run will show whether these two account for the entire remaining shortfall or
whether a fifth defect sits underneath. Stated as in-flight, not as passed.


# FREEZE: REGRESSION EVIDENCE (2026-08-21)

The question that had NOT been asked until now: do these six fixes break
anything that already worked? Every verification up to this point tested the
NEW cases — which proves nothing about the old ones, and my own fixtures had
already missed a label base, a `bits 32` block, and this entire suite.

## Flat `-f bin` suite — 25 PASS / 0 FAIL / 0 SKIP

Every `asm_test*.asm` on kernel-k1, run through the pipeline `build.sh` itself
uses (`cp <t>.asm asm_in.asm; ./tiny_host asm.la` -> `asm_out.bin`, vs
`nasm -f bin`). Covers the encoders the fixes touch: `asm_test_alu` (163 B),
`asm_test_mem`, `asm_test_width`, `asm_test_promote` (211 B), `asm_test_expr2`
(775 B). `build.sh`'s sharp check also holds — byte 0 of `asm_test.asm` is
`0xB8` (mov eax,1), not `0x48` (REX.W movabs), which is precisely the `MOVIMM`
choice this work modified.

Two tests initially SKIPped for missing `ppinc.inc` and `incdata.bin`. Both were
MY staging gap, not the tests': `ppinc.inc` is tracked and was not copied;
`incdata.bin` is generated, so one was synthesised (its content cannot bias the
result — both assemblers read the same file). Both then PASSED. **A skip counted
as a pass is a vacuous green.**

## Object `-f elf64` suite — 7 PASS / 0 FAIL

Every `asm_elf_r*.asm`, using `gate_asmelf.sh`'s own bar: **`ld(ours) ==
ld(nasm)` byte-identical on the LINKED IMAGE**, not byte-identity of the `.o`
(asmelfobj.la's header states an object's internal layout is nasm convention,
not semantics). This is the ONLY path that reaches `RIPXSECRELS` and the
`cursec` threading — the flat suite cannot exercise a relocation at all — so it
is the stream that actually verifies defect 5, with the linker consuming the
relocations rather than a comparator agreeing with itself.

## A harness failure worth recording

The first regression attempt fed these fixtures to `-f elf64` through
`asmelfobj.la` and reported 6 FAIL / 13 SKIP. **Every one was the harness.**
They are FLAT-BINARY tests: `asmelfobj.la` correctly refuses a source with no
`section`, and `nasm -f elf64` correctly refuses `org`. I invented a harness
instead of reading how the tests are actually run, and got 19 results that
looked like findings and were noise.

> **An instrument reporting FAILURE must first be shown to be running the thing
> under test** — the mirror of the absence rule, and it cost a full run.

## Still open, declared not hidden

Commit `2daddbb` documented encoders still on plain `P66`, correct for the
native size in each mode and mis-encoding only a cross-size operand:
`TSTENC`, `DIVENC/G3ENC`, `IMUL2/3`, `CMOVENC`, `BSRENC`, `MOVZXENC`,
`OUTENC/INENC`, `PUSHPOP`. Not reached by any current target. They belong in the
ledger before this milestone counts as secured.


# BOOT-SCALE VERIFICATION COMPLETE — all six arms (2026-08-21 21:17)

    arm     .boot32   relocs        verdict
    NONE      877 B    53 ==        control, unchanged
    HH1      1018 B    60 ==        PASS
    HH2      1311 B    84 ==        PASS
    HH1B      997 B    60 ==        PASS
    HH2B     1257 B    83 ==        PASS
    HH2C     1735 B   103 ==        PASS

Every section byte-identical to nasm outside relocated fields, and every
relocation table identical on offset, type, symbol AND addend. HH2C went from
5 missing `R_X86_64_PC32` to 103/103 identical.

**Both arms that could not be assembled at all when this began now match nasm
exactly.** All three verification streams are clean: 25/25 flat, 7/7 object,
6/6 boot.

## The two regressions I introduced, and what caught them

Neither was found by a unit fixture — both were caught by the boot arms, and
both had the same root cause: my fixtures contained only the cases I thought of.

1. **`AND` is not a short-circuit.** LA is EAGER, so
   `AND(ISREG(bt))(int_eq(RWIDTH(bt))(4))` still called `RWIDTH` on a
   non-register, and `RWIDTH` halts by design. `[MBI_SAVE]` (a label base)
   killed the assembler. My 10-case fixture used only REGISTER bases.
   Fix: nest `IF`s so the branch is a thunk.
2. **The prefix is mode-relative.** Emitting `0x67` for any 32-bit base made
   `mov [edi], eax` two bytes LONGER than nasm inside `bits 32`, where edi IS
   the default. My fixture had no `bits 32` block.
   Fix: base width != the mode's default address width.

`REGENT` halting on an unknown name is what made (1) a loud failure at 183 s
rather than a silently corrupt kernel — its own comment records that the old
table returned 0 on a miss, so a typo assembled to a wrong-but-plausible
instruction. The loud-failure discipline paid for itself.


# DEFECTS 8 & 9 — the P66 encoders 2daddbb left open (2026-08-21)

`2daddbb` documented ten encoders still on plain `P66`: correct for the NATIVE
size in each mode, mis-encoding only a cross-size operand, and unreached by any
current target. Now fixed — `TSTENC`, `DIVENC`, `G3ENC` (neg/idiv), `CMOVENC`,
`IMUL2`, `IMUL3`, `BSRENC`, `MOVZXENC`, `OUTENC`, `INENC` all take the mode and
use `P66M(BITSMODE(labs))`, threaded from the dispatch exactly as that commit
prescribed.

## Defect 8: `TSTENC` had a HARDCODED MODE, hiding behind the P66 one

`test reg, reg` routes through `RROP(...)(64)` — a literal 64 where the mode
belongs. Threading `mode` into the encoder was NOT enough: the prefix came out
INVERTED in 16-bit mode (`66` on `test ax,bx`, none on `test eax,ebx`), which
is precisely plain-`P66` behaviour. A second, independent defect sitting behind
the first, and fixing only the visible one would have been a green-looking
change that fixed nothing.

## Defect 9 (informational): `ALUENC` is DEAD CODE

One mention in the whole file — its own definition. `G1ENC` superseded it. It
also carries a hardcoded `(64)`, so anyone auditing for that pattern will find
it and repair a function nothing calls. Recorded rather than removed.

## Verification

No `bits 16` exists in the boot fixture or in any of the 25 flat tests, so this
gap was declared but UNEXERCISED — there was no test that could fail. The fixture is
reproduced in full at the end of this document rather than committed: it belongs
to `asm_test*.asm`, which is track A's namespace, and the ownership guard
correctly refused it. 38 instructions covering `test/div/idiv/neg/bsr/imul2/
imul3/cmovz/in/out/movzx`, each in NATIVE and CROSS size, across `bits 16` and
`bits 32`. **Byte-identical to nasm, 103 B.**

Flat regression after the change: 25 PASS / 0 FAIL / 0 SKIP. This matters more
than usual because threading `mode` touched every `RROP` caller, and `RROP` is
the shared register-to-register encoder for the whole ALU family.


## The cross-size fixture (for track A to add as `asm_test_xsize.asm`)

Not committed here — `asm_test*.asm` is track A's pattern and the ownership
guard refused it, correctly. Reproduced so A can add it under its own ownership.
Verified byte-identical to `nasm -f bin`, 103 B.

```asm
bits 16
    test ax, bx
    test eax, ebx
    div cx
    div ecx
    neg ax
    neg eax
    idiv cx
    idiv ecx
    bsr ax, bx
    bsr eax, ebx
    imul ax, bx
    imul eax, ebx
    imul ax, bx, 7
    imul eax, ebx, 7
    cmovz ax, bx
    cmovz eax, ebx
    in ax, dx
    in eax, dx
    out dx, ax
    out dx, eax
    movzx ax, bl
    movzx eax, bl
bits 32
    test ax, bx
    test eax, ebx
    div cx
    div ecx
    neg ax
    neg eax
    bsr ax, bx
    bsr eax, ebx
    imul ax, bx
    imul eax, ebx
    cmovz ax, bx
    cmovz eax, ebx
    in ax, dx
    in eax, dx
    out dx, ax
    out dx, eax
```


# THE SEAM: does `link.la` still consume what `asm.la` now emits? (2026-08-22)

The nine fixes changed the assembler's OUTPUT. Defect 7 made it emit
`R_X86_64_PC32` against SECTION symbols with NEGATIVE addends — a form it had
never produced. `link.la` is what consumes those, and nothing had checked the
two halves of the LA-only toolchain still agree across the change: each was
verified alone.

**Result: they agree.** Fixture exercising four fixed defects at once
(cross-section RIP, index-after-displacement, imm64, ALU-label):

    entry point        ld 0x401005  ==  link.la 0x401005
    .rodata            byte-identical
    lea rax,[rel msg]  ld -> 0x401000 = msg    link.la -> 0x401000 = msg
    lea r8, [rel flag] ld -> 0x402034 = flag   link.la -> 0x402000 = flag

## ★★ THE OBVIOUS GATE IS THE WRONG ONE, and that is the finding

Byte-comparing `link.la`'s image against `ld`'s FAILS at `.boot32` byte 11 —
because `ld` places `.bss` at `0x402034` and `link.la` at `0x402000`, so every
RIP-relative displacement LEGITIMATELY differs. **Two correct linkers, two valid
layouts, different bytes.** Reporting that FAIL at face value would have filed a
defect against `link.la` that does not exist — the false-accusation mode, from a
check that looks rigorous *precisely because it is strict*.

The gate must be SEMANTIC: does `P_next + disp` equal the symbol's address? Both
linkers pass independently, under different layouts.

⇒ Byte-identity is the right gate for an ASSEMBLER against nasm (same layout by
construction) and the WRONG one for a LINKER against ld (layout is the linker's
own choice). The same comparison is rigorous in one place and false in the other.

## Two defects in the gate itself, fixed before committing

1. **It skipped permanently.** It looked for `asmelfobj.la` locally — track A's
   file, absent from this worktree — so it would have SKIPped forever here.
   A gate that can never run is worse than no gate, and a SKIP reads like a PASS
   at a glance. Now the producer is staged READ-ONLY from git.
2. **It did not say which assembler it tested.** A silent fallback to the
   committed `asm.la` would test the PRE-FIX code while claiming to verify the
   fix. It now prints the assembler under test and labels the fallback
   explicitly.

**Red-pathed:** flipping ONE BIT of the `lea` disp32 makes it report
`resolves 0x401001, symbol at 0x401000`. It is measuring something.


# NIGHT3: the LA-only chain, end to end (2026-08-22)

## Six boot arms re-verified against the CURRENT asm.la

The freeze was proven BEFORE the P66 work landed. "It passed before the last
change" is not a verified state, so all six arms were re-run against the
assembler as it now stands:

    HH2B   .boot32 identical outside relocs   relocation tables identical
    HH2C   .boot32 identical outside relocs   relocation tables identical

## ★★ THE FULL LA-ONLY CHAIN RAN — asm.la -> link.la, no nasm, no ld

    asm.la  ->  7072 B object      (no nasm)
    link.la ->  9528 B image       (no ld)     entry 0x401158
    ld control: 9648 B

Each half was gated separately — `asm.la` byte-identical to nasm, `link.la`
matching `ld` — but the real boot fixture had never gone through BOTH with
neither GNU tool in the chain. **The milestone claim is now demonstrated rather
than inferred from its two halves.**

## The seam, closed by construction rather than by sampling

    link.la handles:  1 2 3 4 9 10 11 26 27 42
    asm.la emits:     1 (64) · 2 (PC32) · 10 (32) · 11 (32S)

`asm.la`'s emitted set is a strict SUBSET of `link.la`'s handled set. There is no
relocation the assembler can produce that the linker cannot consume — a set
containment, not a sample of cases that happened to work.

## ★ A capability audit whose METRIC was wrong — recorded, not filed

Step 10 counted, for each `IS<CAP>` predicate in the linker, how many gate
scripts MENTION it. Every one of the 14 came back 0:

    ISABS32 ISDELIM IS_ELF ISEXEC ISGLOB ISGOT32 ISGOT64 ISGOTPC
    ISGOTSLOT ISGOTX ISOUT ISPCREL ISSP ISWRIT      all: gates-mentioning=0

**A uniform zero is the tell.** A gate exercises BEHAVIOUR, not glyph names — no
gate would ever contain the string `ISGOTX`. The metric measures nothing, and
reporting it as coverage would have filed fourteen false findings at once.

The relocation-type audit that DID work asked a different question: which types
appear in any fixture's object. That found GOT32 and GOTPC32 uncovered and
GOTPCREL unhandled. **The difference is that it looked at artifacts the gates
produce rather than at the text of the gates.**

⇒ Same lesson as the seam byte-comparison and the `0 PASS / 0 FAIL` counter: an
instrument that returns the same answer for everything is not reporting on
anything. Kept here because the next person to audit "claimed vs exercised" will
reach for the name-grep first, as I did.
