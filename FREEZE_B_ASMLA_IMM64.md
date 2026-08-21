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
