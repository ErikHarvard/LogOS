; asm_elf_r7 — re-entered sections must MERGE, not duplicate.
;
; boot.asm's shape: the file declares its sections once, but %included files
; re-enter them (idt.asm re-enters .boot32/.rodata/.bss; timer.asm and
; kbdirq.asm each re-enter .boot32). nasm appends to the existing section;
; emitting one section per DIRECTIVE gave 16 sections against nasm's 11.
;
; Three things are checked here, and the last two are the ones that stay wrong
; if merging is done as naive concatenation without threading the offset:
;   1. section COUNT — .text and .data appear three and two times, one each out
;   2. `align` inside a CONTINUATION pads from the MERGED offset. Measured:
;      3 bytes present + `align 16` pads 13, not 0. A fragment restarting at
;      offset 0 rounds against the wrong base and the section comes out short.
;   3. a LABEL defined in a continuation gets its MERGED offset, so a reloc
;      against it carries the right addend. `tail` below is only correct if the
;      third .text fragment knows the two before it exist.
bits 64
global _start

section .text
_start:
    nop

section .data
    db 1,2,3

section .text
    nop
    nop

section .data
align 8
val:
    dq _start

section .text
align 16
tail:
    mov rax, tail
    mov ebx, val
    syscall
