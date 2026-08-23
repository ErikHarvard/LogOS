; asm_elf_r5 — equ symbols: ABS binding, source-order interleaving, 64-bit values.
;
; Every shape here is taken from boot.asm rather than invented:
;   - preamble numeric equs (COM1, MB_MAGIC) — SUBALL erases these for -f bin,
;     so they are the ones an object file most easily loses
;   - equ values that arrive as NEGATIVE LA integers (HIGH_BASE, MB_CHECK are
;     verbatim boot.asm values) and so exercise the 64-bit vlo/vhi split
;   - an equ derived from other equs (MB_CHECK), which is address-valued by
;     asm.la's test and therefore travels the other equ path
;   - an in-section, label-scoped equ (gdt64.code) that must land BETWEEN two
;     label symbols in source order, not appended after them
;   - a real relocation alongside, so the symbol-table growth is shown not to
;     disturb the reloc indices (relocs target SECTION symbols, which precede
;     every label and equ)
bits 64
global _start
COM1        equ 0x3f8
MB_MAGIC    equ 0x1badb002
MB_FLAGS    equ 0x2
MB_CHECK    equ -(MB_MAGIC + MB_FLAGS)
HIGH_BASE   equ 0xffffffff80000000

section .text
_start:
    mov dx, COM1
    mov rax, gdt64
    syscall

section .data
gdt64:
    dq 0
.code:  equ $ - gdt64
.ptr:
    dq gdt64
