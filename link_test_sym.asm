; link_test_sym.asm — symbols the earlier fixtures never exercised:
;   * an END-OF-SECTION marker (value == one past the section, ld's Ndx = that section)
;   * a high-word ABS equ (sign bit set), which folds negative in a low-4 read
; Both crashed the symtab emitter on the real kernel object; neither appears in
; link_test_a/b, so this is the fixture that would have caught it up front.
bits 64
HIGH_ABS  equ 0xffffffff80000000
section .rodata
msg:      db "I AM THAT I AM", 10
MSGLEN    equ $ - msg
rodata_end:                       ; end-of-.rodata marker: value == .rodata + size
section .text
global _start
global rodata_end
_start:
    mov     rax, 1
    mov     rdi, 1
    mov     rsi, msg
    mov     rdx, MSGLEN
    syscall
    mov     rax, 60
    mov     rdi, 17
    syscall
text_end:                         ; end-of-.text marker
global text_end
