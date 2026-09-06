bits 64
global _start
section .text
_start:
    mov rax, b
    mov eax, b
    syscall
section .data
a: dq _start
b: dd _start
