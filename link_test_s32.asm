; Entry for the 32S case: calls pick(2), which indexes a static table via
; R_X86_64_32S — the signed absolute gcc emits for non-PIC static data.
; pick(2) returns 30, so 30 is the exit status: a wrong table address gives a
; segfault or a different number, never 30.
bits 64
section .text
global _start
extern pick
_start:
    mov edi, 2
    call pick wrt ..plt
    mov edi, eax
    mov eax, 60
    syscall
