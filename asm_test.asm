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
