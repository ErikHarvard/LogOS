; Three-segment fixture: .rodata (read-only) AND .data (writable) in one object.
;
; This is what forces the linker to emit a THIRD PT_LOAD, and the first
; WRITABLE one it has ever produced — so it is also the first real exercise of
; the W^X assertion. Until now every segment was R or R+X, and "no RWE" passed
; without the linker ever having had the chance to get it wrong.
;
; Both references are R_X86_64_64 (movabs) on purpose: it exercises a third
; section without also introducing a fourth relocation type, so a failure here
; means the SECTION handling is wrong, not the relocation handling.
bits 64

section .rodata
msg:    db "I AM THAT I AM", 10
MSGLEN  equ $ - msg

section .data
counter: dq 1

section .text
global greet

greet:
    mov rdi, counter        ; R_X86_64_64 into .data (value discarded below)
    mov eax, 1              ; write
    mov edi, 1              ; stdout
    mov rsi, msg            ; R_X86_64_64 into .rodata
    mov edx, MSGLEN
    syscall
    ret
