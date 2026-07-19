; .bss fixture — the section that occupies MEMORY but no FILE bytes.
;
; NOBITS is the first section whose sh_offset does not point at real content:
; reading bytes there would return whatever happens to sit at that file offset.
; So this fixture exists to prove two different things at once —
;
;   1. the linker does NOT read file bytes for a NOBITS section, and
;   2. it still reserves the ADDRESS SPACE, so `buf` gets a real address and
;      the segment's p_memsz exceeds its p_filesz.
;
; A linker that forgot (1) emits garbage; one that forgot (2) hands out an
; address that overlaps whatever comes next. Both are silent at link time.
bits 64

section .rodata
msg:    db "I AM THAT I AM", 10
MSGLEN  equ $ - msg

section .bss
buf:    resb 16

section .text
global greet

greet:
    mov rdi, buf            ; R_X86_64_64 into .bss — needs a real address
    mov eax, 1              ; write
    mov edi, 1              ; stdout
    mov rsi, msg            ; R_X86_64_64 into .rodata
    mov edx, MSGLEN
    syscall
    ret
