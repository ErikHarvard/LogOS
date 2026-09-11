; Slice: index/scale with NO BASE register, and the label-base fold.
; 430b2a7's bits64 bug had a twin nobody had probed: `[rcx*4]` took the
; absolute-address path and emitted SIB 0x25 (index=none), silently DROPPING
; the index register and the scale, so it assembled AT THE CORRECT LENGTH as
; `mov rax,[0x0]`. Every no-base form produced those same 8 bytes.
;
; NASM's rule, measured rather than assumed: with no base register, scale 1
; folds to a plain base (`[rcx*1]` -> `[rcx]`) and scale 2 folds to base+index
; (`[rcx*2]` -> `[rcx+rcx*1]`); only scales 4 and 8 use SIB base=none+disp32.
; The label-base cases below are the SAME defect wearing a different length:
; `[FREEBLOB+r8]` is a baseless scale-1 index, 7 bytes in NASM, 8 unfolded.
;
; The last four lines are CONTROLS: forms that were already correct. A fixture
; that only carries the red case cannot tell a fix from a change that breaks
; everything, so the working neighbours are asserted in the same file.
bits 64
FREEBLOB equ 0x1000
start:
    ; --- no base, scale 4/8: SIB base=none(5) + disp32 ---
    mov rax, [rcx*4]
    mov rax, [rcx*8]
    mov rax, [rdx*4+8]
    mov rbx, [r9*4]
    mov rax, [r9*8+16]
    ; --- no base, scale 1/2: NASM folds these to a base form ---
    mov rax, [rcx*1]
    mov rax, [rcx*2]
    mov rax, [rcx*1+8]
    mov rax, [rcx*2+8]
    mov rax, [r9*2]
    ; --- a LABEL base with a register index: the same fold, one byte shorter ---
    mov rax, [FREEBLOB+r8]
    mov rax, [FREEBLOB+rcx]
    mov rax, [FREEBLOB+r8*8]
    ; --- CONTROLS: already correct before the fix, must stay correct ---
    mov rax, [rbx+rcx*4]
    mov rax, [rbx+rcx*4+8]
    mov rax, [rsi+r8]
    mov rax, [rcx]
    ret
