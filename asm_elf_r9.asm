; asm_elf_r9 — the two relocation sites boot.asm has that no earlier fixture does.
;   1. [label+offset] memory operands. HASMEMLBL used to require the bracket
;      contents to BE a label, so "pml4+4" matched nothing and the relocation
;      was silently absent. nasm emits sym=.bss with the offset folded into the
;      addend, which is exactly what MEMDISP already computes.
;   2. a FAR jump, whose 4-byte offset is followed by a 2-byte SELECTOR — so its
;      relocation sits at length-6, not the length-4 every other one uses.
bits 32
global _start
section .boot32
_start:
    mov dword [pml4], 0
    mov dword [pml4+4], 0
    mov eax, [pml4+8]
    jmp gdt64.code:long_start
long_start:
    nop

section .rodata
align 8
gdt64:
    dq 0
.code:  equ $ - gdt64

section .bss
align 4096
pml4:   resb 4096
