; link_test_mb.asm — the fixture for link_test_kernel.ld.
;
; Shaped like the LogOS kernel's own object: a multiboot header that must come
; FIRST in the file, a 32-bit trampoline section, code, rodata, a .bss the
; script marks (NOLOAD), a separate .la_image blob loaded at a second address,
; and the .comment/.note sections a real toolchain emits and the script
; discards.
;
; It is a RUNNABLE userspace program, so the gate's strongest check — execute
; it and compare with ld's binary — still applies. It PROVES the layout rather
; than asserting it: the exit code is computed from a byte read out of
; .la_image (which only has the right value if that section landed at the
; second segment's address) plus a byte written to and read back from .bss
; (which only works if .bss got memory without file bytes).

section .multiboot progbits alloc noexec nowrite
    dd 0x1BADB002                       ; the magic a boot loader looks for
    dd 0x00000000
    dd -(0x1BADB002 + 0x00000000)

section .boot32 progbits alloc exec nowrite
trampoline:
    nop                                 ; stands in for the 32->64 trampoline

section .rodata
msg:    db "I AM THAT I AM", 10
MSGLEN  equ $ - msg

section .la_image progbits alloc noexec nowrite
image:  db 41                           ; the "image" payload: one byte

section .bss nobits alloc noexec write
scratch: resb 8

; An ALLOCATABLE note, so /DISCARD/ has something it must actually drop. A
; non-alloc .comment would not test anything: the linker already ignores
; sections the loader never sees, so the discard would pass vacuously. This one
; the layout CANNOT place, so without the /DISCARD/ line the link is refused by
; name — which is what makes the positive gate mean something.
section .note.mine progbits alloc noexec nowrite
    db 0, 0, 0, 0

section .text
global _start
_start:
    mov     rax, 1                      ; write(1, msg, MSGLEN)
    mov     rdi, 1
    mov     rsi, msg
    mov     rdx, MSGLEN
    syscall

    mov     al, [image]                 ; 41, and only if .la_image is placed
    mov     [scratch], al               ; .bss must be writable memory
    mov     bl, [scratch]
    add     bl, 2                       ; 43 — the exit code the gate expects

    mov     rax, 60                     ; exit(43)
    movzx   rdi, bl
    syscall
