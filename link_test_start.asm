; Entry point for the mixed asm + C link.
;
; gcc objects define `compute`/`helper` but no `_start` — the C runtime
; normally supplies it. This provides one directly, so the linker can be
; pointed at genuine compiler output without dragging in crt0 or libc.
;
; compute(21) returns helper(21) + 1 = 43, which becomes the exit status, so
; the link is checked by a value that had to travel through BOTH C objects: a
; wrong address for either would not produce 43.
bits 64

section .text
global _start
extern compute

_start:
    mov edi, 21
    call compute wrt ..plt  ; PLT32, the relocation gcc itself emits
    mov edi, eax            ; exit status = compute(21) = 43
    mov eax, 60
    syscall
