; Slice 3: data-definition and layout directives.
; 62 of boot.asm's 261 remaining lines are these: resb 23, align 12, dq 8,
; dw 9, dd 5, resq 2. Pure generation, but the -f bin semantics of resb and
; align are subtle enough to be worth pinning byte-exactly.
bits 64
org 0x400000

start:
    mov rax, 1
    ret

; --- multi-byte data, little-endian ---
w1: dw 0x1234
w2: dw 1, 2
d1: dd 0x12345678
d2: dd 1, 0x40
q1: dq 0x1122334455667788
q2: dq 1

; --- a LABEL as a data value: absolute address, and org makes it 0x400000+ ---
q3: dq start
d3: dd w1

; --- db already worked; mixed with the new sizes ---
b1: db 0x41, 0x42
b2: db "HI", 0

; --- align: pad to a boundary (with zeros in a -f bin image) ---
align 8
a1: dq 0xdeadbeef
align 16
a2: db 0x99

; --- resb / resq: RESERVE space. In -f bin these advance the location
;     counter; trailing reservations are truncated, so something follows.
r1: resb 4
r2: resq 2
after: db 0x77
