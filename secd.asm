; ═══════════════════════════════════════════════════════════════════
;  secd.asm — the SECD runtime, hand-written x86-64 (Albedo Stage 2, v0)
;
;  A self-contained flat ELF image (nasm -f bin): the file IS the loadable
;  binary — a hand-built ELF64 header + one RWX PT_LOAD segment + the
;  runtime code + the compiled instruction stream. The operand stack lives
;  in the zero-filled tail of the segment (memsz > filesz, i.e. BSS).
;
;  The runtime is a data-driven dispatch loop over a compiled instruction
;  stream: an operand stack (S) and a control pointer (C). The environment
;  E and dump D arrive with the next increment (CLOSE / APPLY-of-closure +
;  heap). v0 covers PUSHS / PUSHV / APPLY-of-builtin — enough to run
;  print("I AM THAT I AM") through a real interpreter loop.
;
;  Operand-stack entry = 16 bytes: [tag(8)][payload(8)].
;    tag 0 = STR : payload = pointer to NUL-terminated bytes in the stream
;    tag 1 = BI  : payload = builtin id (0 = print)
;
;  Opcodes (1 byte): 00 HALT | 01 PUSHS <bytes> 00 | 02 PUSHV_PRINT | 03 APPLY
;
;  Build / verify:  nasm -f bin secd.asm -o secd && ./secd
; ═══════════════════════════════════════════════════════════════════

BITS 64
org 0x400000

OSTACK equ 0x1000                ; bytes of operand stack (zero-filled BSS tail)

ehdr:
    db 0x7F, "ELF", 2, 1, 1, 0   ; e_ident: magic, ELFCLASS64, LSB, version, SysV
    times 8 db 0                 ;          padding
    dw 2                         ; e_type    = ET_EXEC
    dw 0x3E                      ; e_machine = x86-64
    dd 1                         ; e_version
    dq _start                    ; e_entry
    dq phdr - $$                 ; e_phoff
    dq 0                         ; e_shoff
    dd 0                         ; e_flags
    dw 64                        ; e_ehsize
    dw 56                        ; e_phentsize
    dw 1                         ; e_phnum
    dw 0                         ; e_shentsize
    dw 0                         ; e_shnum
    dw 0                         ; e_shstrndx
phdr:
    dd 1                         ; p_type  = PT_LOAD
    dd 7                         ; p_flags = R|W|X
    dq 0                         ; p_offset
    dq 0x400000                  ; p_vaddr
    dq 0x400000                  ; p_paddr
    dq filesize                  ; p_filesz
    dq filesize + OSTACK         ; p_memsz  (extra is zero-filled = the stack)
    dq 0x1000                    ; p_align

_start:
    mov     rbx, prog            ; C — control pointer into the instruction stream
    mov     r12, ostack          ; S — operand stack, r12 = next free slot
.loop:
    movzx   rax, byte [rbx]
    inc     rbx
    cmp     al, 0
    je      .halt
    cmp     al, 1
    je      .pushs
    cmp     al, 2
    je      .pushv_print
    cmp     al, 3
    je      .apply
    jmp     .halt
.pushs:                          ; rbx points at the string bytes
    mov     qword [r12], 0       ; tag = STR
    mov     [r12+8], rbx         ; payload = pointer to the bytes
    add     r12, 16
.pushs_scan:                     ; advance C past the bytes and their NUL
    mov     al, [rbx]
    inc     rbx
    test    al, al
    jnz     .pushs_scan
    jmp     .loop
.pushv_print:
    mov     qword [r12], 1       ; tag = BI
    mov     qword [r12+8], 0     ; builtin id 0 = print
    add     r12, 16
    jmp     .loop
.apply:
    sub     r12, 16              ; pop arg
    mov     r10, [r12+8]         ; r10 = arg payload (STR pointer)
    sub     r12, 16              ; pop fn (assumed BI print in v0)
    mov     r8, r10              ; print(arg): write bytes, then a newline
    mov     r9, r10
.apply_len:
    mov     al, [r9]
    test    al, al
    je      .apply_write
    inc     r9
    jmp     .apply_len
.apply_write:
    sub     r9, r8               ; r9 = length
    mov     rax, 1               ; write(1, bytes, len)
    mov     rdi, 1
    mov     rsi, r8
    mov     rdx, r9
    syscall
    mov     rax, 1               ; write(1, "\n", 1)
    mov     rdi, 1
    mov     rsi, newline
    mov     rdx, 1
    syscall
    mov     qword [r12], 0       ; push result = arg (print returns its arg)
    mov     [r12+8], r8
    add     r12, 16
    jmp     .loop
.halt:
    mov     rax, 60              ; exit(0)
    xor     rdi, rdi
    syscall

newline: db 10

prog:                            ; compiled stream for  print("I AM THAT I AM")
    db 2                         ; PUSHV_PRINT
    db 1                         ; PUSHS
    db "I AM THAT I AM", 0       ; inline bytes + NUL
    db 3                         ; APPLY
    db 0                         ; HALT

filesize equ $ - $$
ostack   equ $$ + filesize       ; operand stack begins just past the file image
