; N-section fixture: a custom allocatable section OUTSIDE the five known
; families (.mydata: SHF_ALLOC|SHF_WRITE, PROGBITS). ld's default layout groups
; it into the RW PT_LOAD by its SHF flags; link.la's default layout used to
; REFUSE any allocatable section it did not know by name. This proves the
; permission-grouped default layout: .mydata is placed, loaded, and readable at
; run time (the program exits with the byte it reads back from .mydata), and it
; lands in a writable, non-executable segment (W^X preserved).
section .text
global _start
_start:
    mov rax, [myval]        ; read from .mydata — resolves a reloc INTO an arbitrary section
    mov rdi, rax            ; exit code = the value we stored
    mov rax, 60
    syscall

section .mydata progbits alloc noexec write
myval: dq 42
