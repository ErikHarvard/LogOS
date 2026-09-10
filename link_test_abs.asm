; R_X86_64_32 fixture — a 32-bit ABSOLUTE address.
;
; `mov esi, msg` loads the address into a 32-bit register, so nasm emits
; R_X86_64_32 rather than the 64-bit movabs the other fixtures use. This is
; what non-PIC code does routinely, and gcc -fno-pic emits the signed twin
; (32S) for the same job — until now both were refused as unsupported types.
;
; It works only because this layout puts everything below 4 GB. A linker script
; loading high would make the value not fit, which LE4 would truncate silently;
; hence the FITS32 guard, which refuses instead.
bits 64

section .rodata
msg:    db "I AM THAT I AM", 10
MSGLEN  equ $ - msg

section .text
global greet

greet:
    mov eax, 1
    mov edi, 1
    mov esi, msg            ; R_X86_64_32 — absolute, zero-extended
    mov edx, MSGLEN
    syscall
    ret
