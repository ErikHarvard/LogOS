; Slice: expression evaluation in operands — PRECEDENCE is the point.
; `511*8` must bind tighter than the `+`, or the address is (pml4+511)*8.
bits 64
org 0x400000
SLOT equ 288
start:
    mov [pml4 + 511*8], eax
    mov dword [pml4 + 511*8 + 4], 0
    mov eax, [pml4 + 8]
    mov [rdi + SLOT + 16], rax
    mov rbx, [rdi + 2*8]
    mov ecx, [pml4 + 4*4 - 8]
    ret
pml4:
    dq 0
