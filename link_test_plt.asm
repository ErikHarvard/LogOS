; PLT32 fixture — identical to link_test_a.asm except that the call goes
; through `wrt ..plt`, which makes nasm emit R_X86_64_PLT32 (type 4) instead
; of R_X86_64_PC32 (type 2).
;
; This is not an exotic case. PLT32 is what nasm and gcc emit for a call to a
; global function in the ordinary path, so a linker that handles only PC32
; fails on most real objects while looking fine on a hand-made fixture. That
; is exactly why it gets its own fixture rather than being assumed equivalent.
;
; Statically, the two ARE equivalent — the callee is in the image being
; emitted, so there is nothing to indirect through — and the gate proves it by
; requiring this pair to link byte-identically to what ld produces from the
; same inputs.
bits 64

section .text
global _start
extern greet

_start:
    call greet wrt ..plt    ; R_X86_64_PLT32
    mov eax, 60
    xor edi, edi
    syscall
