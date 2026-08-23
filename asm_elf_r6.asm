; asm_elf_r6 — sections: NOBITS, alignment raised from inside, unknown names.
;
; All three shapes are lifted from boot.asm, not invented:
;   .multiboot  an UNKNOWN name (nasm: progbits + alloc + align 1, NOT exec)
;               whose alignment is then raised to 4 by the align inside it
;   .rodata     a KNOWN name whose default align 4 is raised to 8 the same way
;   .bss        NOBITS — takes a size but contributes no file bytes; its align
;               is raised from the default 4 all the way to 4096
; A mid-section `align` in a NON-exec section is included deliberately: asm.la
; pads align with 0x90, which is right for code and wrong here, so this fixture
; is what makes the pad-byte-by-section-flags rule load-bearing rather than
; asserted. Relocations into .bss are present because that is how boot.asm
; reaches its page tables.
bits 64
global _start

section .multiboot
align 4
    dd 0x1badb002

section .boot32
_start:
    mov eax, pml4
    mov ebx, stack_top
    mov rcx, msg
    syscall

section .rodata
align 8
msg:
    dq _start
    db "hi"
align 8
tail:
    dq msg

section .bss
align 4096
pml4:   resb 4096
stack:  resb 64
stack_top:
