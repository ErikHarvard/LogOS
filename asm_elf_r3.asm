bits 64
global _start
section .text
_start:
    mov rax, _start
    mov eax, _start
    mov qword [rax], _start
    syscall
section .data
a: dq _start
b: dd _start
