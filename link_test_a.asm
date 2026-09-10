; Linker slice 1, object A — the CALLER.
; This object defines _start and references `greet`, which it does NOT define.
; That undefined symbol is the whole point: resolving it against object B is
; the threshold a linker has to cross and `asmelf.la` never does.
bits 64

section .text
global _start
extern greet

_start:
    call greet              ; R_X86_64_PLT32 -> resolved to B's .text
    mov eax, 60             ; exit
    xor edi, edi
    syscall
