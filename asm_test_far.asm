bits 32
gdt64:
.code: equ 8
long_start:
  jmp gdt64.code:long_start
