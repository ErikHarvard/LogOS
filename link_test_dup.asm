; Duplicate-definition fixture. Defines BOTH _start and greet, so linking it
; against link_test_b.asm (which also defines greet) is a duplicate-symbol
; error and NOTHING ELSE — _start resolves fine, so the only thing wrong is
; the double definition.
;
; That isolation is the whole point. Linking b.o against itself would also be
; a duplicate, but it is missing _start too, and then the test cannot tell
; which error it actually caught.
bits 64

section .text
global _start
global greet

_start:
    call greet
    mov eax, 60
    xor edi, edi
    syscall

greet:
    ret
