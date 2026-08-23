; asm_elf_r8 — 32-bit absolute [disp32]: no SIB byte, and the A3 moffs form.
;
; boot.asm's .boot32 is a `bits 32` section, and its opening instructions are
; absolute-address accesses. Two encodings differ from 64-bit mode:
;   - ModRM mod=00 rm=101 IS absolute disp32 in 32-bit; in 64-bit it means
;     RIP-relative, so an absolute there must detour through SIB (rm=100,
;     SIB=0x25). asm.la always emitted the SIB form: one wasted byte each.
;   - `mov [addr], eax` has a 5-byte A3 moffs form nasm always takes.
; Both are exercised here in a 32-bit section, with a 64-bit section alongside
; so the SIB form is proven still correct where it IS required.
bits 32
global _start
section .boot32
_start:
    mov [pad], ebx
    mov eax, [pad]
    mov dword [pad], 0
    mov [pad], ecx
    lgdt [desc]

bits 64
section .text
    mov [pad], rbx
    lidt [desc]

section .rodata
align 8
desc:
    dq 0

section .bss
align 4096
pad:    resb 4096
