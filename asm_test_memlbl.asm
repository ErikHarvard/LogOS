; Slice: a LABEL used as a memory ADDRESS — 136 uses in boot.asm.
bits 64
org 0x400000
start:
    mov [pml4], eax
    mov dword [pml4], 0
    mov eax, [pml4]
    mov [pdpt], rbx
    or  dword [pml4], 0x04
    lea rax, [pml4]
    ret
pml4:
    dq 0
pdpt:
    dq 0
