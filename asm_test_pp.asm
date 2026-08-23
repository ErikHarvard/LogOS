; Slice 6: the PREPROCESSOR — the last 12% of boot.asm.
; %ifdef guards are how every kernel variant (K2, K5a, HAL2B) is selected from
; one source, so this is what unlocks assembling boot.asm at all.
bits 64
org 0x400000

%define OUTER
%define VAL 0x1234
%define SIZE 64

start:
    mov eax, VAL            ; a %define WITH a value substitutes like equ
    add rax, SIZE

%ifdef OUTER                ; taken
    mov ebx, 1
%else
    mov ebx, 2              ; must NOT be emitted
%endif

%ifdef MISSING              ; not taken
    mov ebx, 3              ; must NOT be emitted
%else
    mov ebx, 4
%endif

%ifndef MISSING             ; taken (negated)
    mov esi, 5
%endif

%ifndef OUTER               ; not taken
    mov esi, 6              ; must NOT be emitted
%endif

%ifdef MISSING
    mov edi, 7              ; must NOT be emitted
%elifdef OUTER              ; this branch taken
    mov edi, 8
%else
    mov edi, 9              ; must NOT be emitted
%endif

%ifdef OUTER                ; nesting, depth 2
    mov r8d, 10
  %ifdef MISSING
    mov r8d, 11             ; must NOT be emitted
  %else
    mov r8d, 12
  %endif
%endif

%include "ppinc.inc"        ; splices, inherits OUTER, defines FROM_INCLUDE

%ifdef FROM_INCLUDE         ; a define made INSIDE the include is visible after
    mov r9d, 13
%endif
    ret
