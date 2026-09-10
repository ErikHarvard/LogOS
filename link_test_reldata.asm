; Linker slice 1, object B(reldata) — the RELOCATION-OUTSIDE-.text fixture.
;
; RECONSTRUCTED 2026-07-19 from reldata.o + ref_reldata. The original source was
; written to a session /tmp scratchpad and evaporated with that tmpfs; only the
; .o survived, and only because it was gitignored rather than cleaned. This file
; exists so the gate below can never again rest on evidence that cannot be
; regenerated.
;
; WHAT IT CATCHES. `msgptr: dq msg` puts a relocation in `.data`, not `.text`.
; A linker that applies only `.rela.text` places `.data` but never patches it,
; so `msgptr` keeps its unrelocated value of 0 — and then:
;   * the link SUCCEEDS,
;   * every existing gate PASSES (none exercised `.rela.data`),
;   * the program writes from a null pointer, prints NOTHING, and exits 0.
; Silent wrongness with a green exit code. Measured against ld: ours held
; 0000000000000000 where ld's held 0x402000.
;
; THE ASSERTION THAT MATTERS: this fixture is only a gate if it checks the
; OUTPUT TEXT. `exit=0` is exactly what the bug produces — a gate that checks
; only the exit status passes on the broken linker and proves nothing.
; Link with link_test_a.asm (the caller, which supplies _start).

bits 64

section .rodata
msg:    db "I AM THAT I AM", 10
MSGLEN  equ $ - msg

section .data
msgptr: dq msg                  ; -> R_X86_64_64 against .rodata (the point)

section .text
global greet
greet:
    mov     eax, 1              ; write
    mov     edi, 1              ; stdout
    mov     rsi, [rel msgptr]   ; -> R_X86_64_PC32 against .data
    mov     edx, MSGLEN
    syscall
    ret
