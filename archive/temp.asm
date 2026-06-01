
global _start
section .text
_start:
    mov rax, 2
    lea rdi, [self_path]
    mov rsi, 0
    mov rdx, 0
    syscall
    mov rbx, rax

    mov rax, 2
    lea rdi, [out_path]
    mov rsi, 0x241
    mov rdx, 0o666
    syscall
    mov rcx, rax

copy_loop:
    mov rax, 0
    mov rdi, rbx
    lea rsi, [buffer]
    mov rdx, 4096
    syscall
    test rax, rax
    jz close_files
    mov r8, rax

    mov rax, 1
    mov rdi, rcx
    lea rsi, [buffer]
    mov rdx, r8
    syscall
    jmp copy_loop

close_files:
    mov rax, 3
    mov rdi, rbx
    syscall
    mov rax, 3
    mov rdi, rcx
    syscall

    mov rax, 1
    mov rdi, 1
    lea rsi, [msg]
    mov rdx, msg_len
    syscall

    mov rax, 60
    xor rdi, rdi
    syscall

section .data
self_path: db '/proc/self/exe',0
out_path:   dd 'self_copy.bin',0
msg:        dd 'Self-replication complete: self_copy.bin created',10
msg_len equ $ - msg

section .bss
buffer: resb 4096
