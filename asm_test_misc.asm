; Slice 4: the opcode tail — port I/O, MSRs, system/descriptor ops, string ops
; with the rep prefix, the o64 prefix, div/imul, rol/ror, and the FULL jcc
; condition set. This is everything boot.asm still needs that is not the
; preprocessor.
bits 64
org 0x400000

start:
; --- port I/O: 37 uses in the kernel, the largest remaining family ---
out dx, al
out dx, ax
out dx, eax
out 0x20, al
out 0xA1, al
out 0x80, eax
in  al, dx
in  eax, dx
in  al, 0x60
in  eax, 0x71

; --- MSRs and misc no-operand system instructions ---
wrmsr
rdmsr
ud2
popfq
pushfq

; --- descriptor-table / task-register ops ---
ltr ax
ltr cx
lgdt [rax]
lgdt [rbx+8]

; --- div and the three-operand imul ---
div rcx
div ebx
imul rax, rax, 64
imul rax, rax, 0x1234
imul rcx, rdx, 8

; --- rotates share the shift encoding, digits 0 and 1 ---
rol rax, 4
ror rcx, 1

; --- string ops, bare and under the rep prefix ---
movsb
stosb
rep movsb
rep stosq
rep stosb

; --- the o64 prefix forces REX.W on the following instruction ---
o64 sysret

; --- the FULL jcc condition set, short form (all targets in range) ---
back:
jo  back
jno back
jb  back
jae back
je  back
jne back
jbe back
ja  back
js  back
jns back
jl  back
jge back
jle back
jg  back
jc  back
jnc back
ret
