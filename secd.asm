; ═══════════════════════════════════════════════════════════════════
;  secd.asm — the SECD runtime, hand-written x86-64 (Albedo Stage 2, v1)
;
;  A self-contained flat ELF image (nasm -f bin): the file IS the loadable
;  binary — hand-built ELF64 header + one RWX PT_LOAD. The zero-filled tail
;  of the segment (memsz > filesz) holds three regions: the operand stack,
;  the dump stack, and a bump-allocated heap (closures + environment cells).
;
;  Now a full call-by-value SECD machine over a compiled instruction stream:
;    S — operand stack   (r12), 16-byte entries [tag(8)][payload(8)]
;    E — environment     (r13), linked cells, 0 = empty
;    C — control pointer (rbx) into the instruction stream
;    D — dump stack      (r14), 16-byte frames [saved_C][saved_E]
;    heap pointer        (r15), bumped upward
;
;  Value tags:  0 = STR (payload → NUL-terminated bytes)
;               1 = BI  (payload = builtin id; 0 = print)
;               2 = CLO (payload → closure record [param(8)][body(8)][env(8)])
;  Env cell (32 bytes): [name(8)][val_tag(8)][val_payload(8)][next(8)]
;
;  Opcodes (1 byte):
;    0x00 HALT                       exit(0)
;    0x01 PUSHS <bytes> 00           push STR pointing at the inline bytes
;    0x02 PUSHV  <name> 00           look up name (env, then builtin) and push
;    0x03 CLOSE  <param> 00 <len:4> <body...>   push closure; skip the body
;    0x04 APPLY                      pop arg, pop fn; enter closure / run builtin
;    0x05 RET                        pop dump: restore C and E (result on S)
;
;  Build / verify:  nasm -f bin secd.asm -o secd && ./secd
; ═══════════════════════════════════════════════════════════════════

BITS 64
org 0x400000

OSTACK_BYTES equ 0x1000
DSTACK_BYTES equ 0x1000
HEAP_BYTES   equ 0x80000

ehdr:
    db 0x7F, "ELF", 2, 1, 1, 0
    times 8 db 0
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
    dw 0
    dw 0
    dw 0
phdr:
    dd 1                         ; p_type  = PT_LOAD
    dd 7                         ; p_flags = R|W|X
    dq 0                         ; p_offset
    dq 0x400000                  ; p_vaddr
    dq 0x400000                  ; p_paddr
    dq filesize                                                  ; p_filesz
    dq filesize + OSTACK_BYTES + DSTACK_BYTES + HEAP_BYTES       ; p_memsz
    dq 0x1000                    ; p_align

; ── strcmp(rsi, rdi) → eax: 0 if the NUL-terminated strings are equal ──
strcmp:
    mov     al, [rsi]
    mov     cl, [rdi]
    cmp     al, cl
    jne     .ne
    test    al, al
    je      .eq
    inc     rsi
    inc     rdi
    jmp     strcmp
.eq:
    xor     eax, eax
    ret
.ne:
    mov     eax, 1
    ret

_start:
    mov     rbx, prog            ; C
    mov     r12, ostack          ; S
    xor     r13, r13             ; E = empty
    mov     r14, dstack          ; D
    mov     r15, heap            ; heap pointer
.loop:
    movzx   rax, byte [rbx]
    inc     rbx
    cmp     al, 0
    je      .halt
    cmp     al, 1
    je      .pushs
    cmp     al, 2
    je      .pushv
    cmp     al, 3
    je      .close
    cmp     al, 4
    je      .apply
    cmp     al, 5
    je      .ret
    jmp     .halt

.pushs:                          ; rbx → string bytes
    mov     qword [r12], 0       ; STR
    mov     [r12+8], rbx
    add     r12, 16
.pushs_scan:
    mov     al, [rbx]
    inc     rbx
    test    al, al
    jnz     .pushs_scan
    jmp     .loop

.pushv:                          ; rbx → name bytes
    mov     rbp, rbx             ; rbp = name pointer
.pushv_scan:
    mov     al, [rbx]
    inc     rbx
    test    al, al
    jnz     .pushv_scan
    mov     r10, r13             ; walk the environment
.pushv_envloop:
    test    r10, r10
    je      .pushv_builtin
    mov     rsi, rbp
    mov     rdi, [r10]           ; cell.name
    call    strcmp
    test    eax, eax
    je      .pushv_found
    mov     r10, [r10+24]        ; cell.next
    jmp     .pushv_envloop
.pushv_found:
    mov     rax, [r10+8]         ; val_tag
    mov     [r12], rax
    mov     rax, [r10+16]        ; val_payload
    mov     [r12+8], rax
    add     r12, 16
    jmp     .loop
.pushv_builtin:
    mov     rsi, rbp
    mov     rdi, str_print
    call    strcmp
    test    eax, eax
    jne     .halt                ; unbound (v0: only print is a builtin)
    mov     qword [r12], 1       ; BI
    mov     qword [r12+8], 0     ; print
    add     r12, 16
    jmp     .loop

.close:                          ; rbx → param bytes
    mov     rbp, rbx             ; rbp = param pointer
.close_scan:
    mov     al, [rbx]
    inc     rbx
    test    al, al
    jnz     .close_scan
    mov     eax, [rbx]           ; body length (4-byte LE)
    add     rbx, 4
    mov     r11, rbx             ; body pointer
    mov     [r15], rbp           ; closure record: param
    mov     [r15+8], r11         ;                  body
    mov     [r15+16], r13        ;                  captured env
    mov     qword [r12], 2       ; push CLO
    mov     [r12+8], r15
    add     r12, 16
    add     r15, 24              ; bump heap past the closure record
    add     rbx, rax             ; skip the body in the defining context
    jmp     .loop

.apply:
    sub     r12, 16              ; pop arg
    mov     r8, [r12]            ; arg tag
    mov     r9, [r12+8]          ; arg payload
    sub     r12, 16              ; pop fn
    mov     r10, [r12]           ; fn tag
    mov     r11, [r12+8]         ; fn payload
    cmp     r10, 2
    je      .apply_clo
    cmp     r10, 1
    je      .apply_bi
    jmp     .halt                ; cannot apply a string
.apply_clo:                      ; r11 → closure record [param][body][env]
    mov     [r14], rbx           ; dump: saved C (instruction after APPLY)
    mov     [r14+8], r13         ;       saved E (caller's environment)
    add     r14, 16
    mov     rax, [r11]           ; new env cell: name = param
    mov     [r15], rax
    mov     [r15+8], r8          ;               bound value tag
    mov     [r15+16], r9         ;               bound value payload
    mov     rax, [r11+16]        ;               next = closure's captured env
    mov     [r15+24], rax
    mov     r13, r15             ; E = the new cell
    add     r15, 32              ; bump heap past the env cell
    mov     rbx, [r11+8]         ; C = closure body
    jmp     .loop
.apply_bi:                       ; r11 = builtin id (0 = print); arg is STR in r8/r9
    mov     rsi, r9              ; rsi = start (for write)
    mov     rcx, r9              ; rcx = cursor for length scan
    xor     rdx, rdx
.apply_len:
    mov     al, [rcx]
    test    al, al
    je      .apply_write
    inc     rcx
    inc     rdx
    jmp     .apply_len
.apply_write:
    mov     rax, 1               ; write(1, start, len)
    mov     rdi, 1
    syscall
    mov     rax, 1               ; write(1, "\n", 1)
    mov     rdi, 1
    mov     rsi, newline
    mov     rdx, 1
    syscall
    mov     [r12], r8            ; push result = arg (print returns its arg)
    mov     [r12+8], r9
    add     r12, 16
    jmp     .loop

.ret:
    sub     r14, 16              ; pop dump
    mov     rbx, [r14]           ; restore C
    mov     r13, [r14+8]         ; restore E
    jmp     .loop

.halt:
    mov     rax, 60
    xor     rdi, rdi
    syscall

newline:   db 10
str_print: db "print", 0

prog:                            ; compiled stream for  print((la x. x)("I AM THAT I AM"))
    db 2                         ; PUSHV "print"
    db "print", 0
    db 3                         ; CLOSE "x"
    db "x", 0
    dd bodyend - bodystart       ; body length
bodystart:
    db 2                         ; PUSHV "x"
    db "x", 0
    db 5                         ; RET
bodyend:
    db 1                         ; PUSHS
    db "I AM THAT I AM", 0
    db 4                         ; APPLY   (closure to the string)
    db 4                         ; APPLY   (print to the result)
    db 0                         ; HALT

filesize equ $ - $$
ostack   equ $$ + filesize
dstack   equ ostack + OSTACK_BYTES
heap     equ dstack + DSTACK_BYTES
