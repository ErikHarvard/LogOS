bits 64
global _start
extern greet
extern exiter
section .text
_start:
    call greet
    mov rax, greet
    mov rax, [rel greet]
    jmp exiter
section .data
gp: dq greet
