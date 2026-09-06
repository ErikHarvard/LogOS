bits 64
mov rax, 1
mov rdi, 1
mov rsi, 4096
mov rdx, 15
syscall
mov rax, 60
xor rdi, rdi
syscall
push rbp
mov rbp, rsp
add rax, rcx
sub rbx, rdx
mov r8, 7
push r12
pop r13
xor r9, r9
add r10, r11
pop rbp
ret
nop

eq_head:  db "hello, world!", 10
eq_tail:
EQ_DIRLEN equ eq_tail - eq_head
EQ_DOLLEN equ $ - eq_head
EQ_NUM    equ 5
mov rax, 15
mov rbx, eq_tail - eq_head
mov rcx, (eq_tail - eq_head)
mov rdx, EQ_NUM
mov rsi, eq_head
mov rdi, EQ_DIRLEN
mov r8, EQ_DOLLEN
mov r9, eq_head + 8
