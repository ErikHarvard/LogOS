bits 64
start:
mov rax, 1
call near fn
jmp near done
fn:
add rax, rcx
ret
done:
xor rax, rax
jz near start
jnz near done
mov rdi, 0
syscall
