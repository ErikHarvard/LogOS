; Slice: the full expression language — C precedence, parens, shifts,
; bitwise ops, char literals. Measured from boot.asm: | x37, << x29,
; parens x29, char literals x10.
bits 64
org 0x400000
start:
    or  eax, 1 << 5
    or  eax, (1 << 8) | (1 << 0)
    or  eax, (1 << 11)
    or  eax, 1 << 31
    or  rax, (1 << 16)
    add al, '0'
    mov ecx, 1 << 4 | 1 << 2
    mov edx, (2 + 3) * 4
    mov esi, 2 + 3 * 4
    mov edi, 0xF0 & 0x3C
    mov ebx, 0xF0 ^ 0x0F
    mov r8d, 256 >> 4
    ret
