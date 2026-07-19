; Slice: %macro — idt.asm generates 32 ISR stubs this way.
bits 64
org 0x400000
%macro ISR_NOERR 1
isr%1:
    push    qword 0
    push    qword %1
    jmp     isr_common
%endmacro
ISR_NOERR 0
ISR_NOERR 1
isr_common:
    ret
