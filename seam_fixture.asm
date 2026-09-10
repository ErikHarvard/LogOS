bits 64
global _start
section .boot32
_start:
    lea rax, [rel msg]
    lea r8,  [rel flag]
    cmp byte [rel flag], 0
    mov byte [rel flag], 1
    mov al, [r8 + 24 + r9]
    add rax, HIGH
    mov rbx, HIGH
    ret
HIGH equ 0xFFFFFFFF80000000
section .rodata
msg: db "seam",0
section .bss
flag: resb 8
