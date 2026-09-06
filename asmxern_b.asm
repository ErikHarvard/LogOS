bits 64
global greet
global exiter
section .text
greet:
    ret
exiter:
    mov eax, 60
    mov edi, 0
    syscall
