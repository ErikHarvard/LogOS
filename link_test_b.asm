; Linker slice 1, object B — the CALLEE.
; Defines `greet` (referenced by A) and its own .rodata string. The string
; reference is a 64-bit ABSOLUTE relocation, so the two relocation kinds a
; minimal linker must handle are both exercised by this pair:
;   R_X86_64_PLT32 / PC32  — A's `call greet`, relative, needs both addresses
;   R_X86_64_64            — B's `mov rsi, msg`, absolute, needs the final VA
bits 64

section .rodata
msg:    db "I AM THAT I AM", 10
MSGLEN  equ $ - msg

section .text
global greet

greet:
    mov eax, 1              ; write
    mov edi, 1              ; stdout
    mov rsi, msg            ; R_X86_64_64 -> final VA of .rodata
    mov edx, MSGLEN
    syscall
    ret
