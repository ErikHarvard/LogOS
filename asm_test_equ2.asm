; Slice: address-valued equ — the kind that CANNOT be substituted as text.
; `$` means the address AT THE EQU LINE; substituting the text would evaluate
; it at each use site instead, silently producing wrong lengths.
bits 64
org 0x400000
MB_MAGIC  equ 0x1BADB002
MB_FLAGS  equ 0x00000002
MB_CHECK  equ -(MB_MAGIC + MB_FLAGS)
msg:      db "I AM THAT I AM"
msglen    equ $ - msg
gdt64:    dq 0
.code:    equ $ - gdt64
.data:    equ $ - gdt64
start:
    mov edx, msglen
    mov rax, msg
    mov ecx, MB_CHECK
    mov r8d, gdt64.code
    ret
