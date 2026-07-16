bits 64
org 4194424
_start:
mov rax, 1
mov rdi, 1
mov rsi, msg
mov rdx, 15
syscall
mov rax, 60
xor rdi, rdi
syscall
msg:
