; Slice 5: `equ` — symbolic constants. boot.asm defines ~25 of them
; (COM1 equ 0x3F8, K6C_SLOTSZ equ 288, PCB_SIZE equ 128, ...).
;
; The point of this test is the DISTINCTION: an equ symbol is a NUMBER, while a
; label is an ADDRESS, and NASM encodes them differently even though the syntax
; is identical. Getting this wrong assembles cleanly and produces a wrong image.
bits 64
org 0x400000

COM1        equ 0x3F8
SLOTSZ      equ 288
PCB_SIZE    equ 128
SMALL       equ 8

start:
    ; --- THE DISTINCTION: same syntax, different encoding ---
    mov rax, SLOTSZ         ; equ constant -> b8 + imm32   (5 bytes)
    mov rax, start          ; label        -> movabs       (10 bytes)

    ; --- equ constants flow into every operand position ---
    mov dx, COM1
    mov eax, PCB_SIZE
    add rax, SMALL
    add rax, SLOTSZ
    cmp eax, SLOTSZ
    shr rax, SMALL
    imul rax, rax, SLOTSZ
    imul rax, rax, PCB_SIZE

    ; --- and into data definitions ---
    dq SLOTSZ
    dd PCB_SIZE
    dw SMALL
    db SMALL

    ; --- a label still resolves as an address in data ---
    dq start
    ret
