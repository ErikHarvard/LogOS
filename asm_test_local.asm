; Slice: LOCAL LABEL REFERENCES — `je .done` inside a scope.
bits 64
org 0x400000
section .text
outer:
    cmp eax, 1
    je  .done
    nop
.done:
    ret
second:
    cmp eax, 2
    jne .done
    nop
.done:
    ret
