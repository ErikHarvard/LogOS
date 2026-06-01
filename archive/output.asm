; Generated assembly for Lingua Adamica glyphs
section .text
global _start

_start:
    call MAIN_glyph
    mov rax, 60
    xor rdi, rdi
    syscall

ID_glyph:
    ; Body: λx. x
    ; For now, just print glyph name
    mov rax, 1
    mov rdi, 1
    lea rsi, [msg_ID]
    mov rdx, msg_ID_len
    syscall
    ret

COMPILE_glyph:
    ; Body: λsrc. λout. out.write(src.read())
    ; For now, just print glyph name
    mov rax, 1
    mov rdi, 1
    lea rsi, [msg_COMPILE]
    mov rdx, msg_COMPILE_len
    syscall
    ret

MAIN_glyph:
    ; Body: COMPILE(open("compiler.la"))(open("copy.bin"))
    ; For now, just print glyph name
    mov rax, 1
    mov rdi, 1
    lea rsi, [msg_MAIN]
    mov rdx, msg_MAIN_len
    syscall
    ret

section .data
msg_ID: db 'ID glyph executed',10
msg_ID_len equ $ - msg_ID

msg_COMPILE: db 'COMPILE glyph executed',10
msg_COMPILE_len equ $ - msg_COMPILE

msg_MAIN: db 'MAIN glyph executed',10
msg_MAIN_len equ $ - msg_MAIN

