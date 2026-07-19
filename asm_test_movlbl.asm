; mov <reg>, <label> — the immediate WIDTH must follow the destination register,
; not default to 64. NASM's movabs-for-labels rule (mov rsi, msg -> 48 be +
; imm64) applies to 64-bit destinations ONLY; a 32-bit destination takes
; B8+r + imm32 with NO REX, and 16-bit takes 66 + B8+r + imm16.
;
; This was wrong in BOTH modes -- not 32-bit-mode fallout. `mov eax, 5` was
; always right (a NUMBER carries its own width), so the defect was specific to
; LABEL-valued immediates, which no gate covered.
bits 64
org 0
    mov     rsi, tgt        ; 64-bit dest -> movabs, 48 be + imm64
    mov     esp, tgt        ; 32-bit dest -> bc + imm32, no REX
    mov     eax, tgt        ; low reg, same form
    mov     r8d, tgt        ; high reg -> REX.B only (41), not REX.W
    mov     bx, tgt         ; 16-bit dest -> 66 + bb + imm16
    mov     eax, 5          ; control: numbers were already correct
tgt:
    ret
