; Slice 2: ALU with IMMEDIATES + shifts + inc/dec + test/lea + the no-operand set.
; Shapes chosen by profiling the kernel .asm: reg+imm dominates (or 31/45,
; shr 32/32, cmp 11/23, test 8/18, and 5/5, shl 5/5), which asm.la could not
; encode at all — its ALU was register-to-register only.
bits 64

; --- group-1 ALU, imm8 sign-extended form (83 /digit ib) ---
add rax, 8
or  rcx, 1
and rdx, 15
sub rbx, 16
xor rsi, 3
cmp rdi, 4

; --- the ACCUMULATOR short forms: NASM drops the ModRM byte for rax/eax/al ---
add rax, 0x12345678
or  rax, 0x1000
and eax, 0x4000
cmp eax, 0x2000
sub al, 9
cmp al, 0x7f

; --- general register + imm32 (81 /digit id) — no accumulator shortcut ---
add rcx, 0x12345678
or  rdx, 0x1000
cmp rbx, 0x2000
and r10, 0x40

; --- widths carry through the immediate forms ---
or  ecx, 0x80
and dx, 0x300
cmp cl, 5
or  r8d, 0x40

; --- shifts: C1 /digit ib, and the by-one D1 /digit special case ---
shr rax, 16
shl rcx, 3
shr edx, 12
sar rbx, 2
shl rax, 1
shr rcx, 1

; --- inc / dec (FF /0, FF /1 in 64-bit mode) ---
inc rax
dec rcx
inc r10
dec edx

; --- test (85 /r) and its immediate form (F7 /0, A9 accumulator) ---
test rax, rbx
test rcx, rcx
test eax, 0x100
test rdx, 8

; --- lea: reg + memory, all 26 uses in the kernel are this shape ---
lea rax, [rcx+8]
lea rdi, [rbp-16]
lea r8, [rsp+32]

; --- no-operand instructions ---
cli
sti
hlt
cld
iretq
ret
