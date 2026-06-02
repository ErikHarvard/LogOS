; ═══════════════════════════════════════════════════════════════════
;  secd.asm — the native SECD machine for LogOS (Albedo Stage 2)
;
;  A fixed flat ELF (nasm -f bin). At startup it reads a compiled
;  instruction stream from "logos_program.bin" (produced by codegen.la)
;  and executes it. So the runtime is built once; arbitrary programs are
;  compiled to streams and run on it natively — threaded SECD.
;
;  State:  S operand stack (r12) | E environment (r13, 0=empty)
;          C control (rbx)       | D dump (r14) | heap (r15, bump)
;  Value tags: 0 STR (payload→NUL-terminated bytes)
;              1 BI  (payload = builtin id)
;              2 CLO (payload→[param][body][env])
;              3 PA  (payload→[builtin id][a1 tag][a1 payload])
;  Env cell (32): [name][val tag][val payload][next]
;
;  Stream (the "glyph table"): for each glyph  NAME 00 <body> 05(RET) ,
;  then a 00 end sentinel. The body of a glyph / closure ends in RET; a
;  RET-matching scan (skipbody) finds its end — so no length fields, and
;  the codegen needs no arithmetic.
;
;  Opcodes: 00 HALT | 01 PUSHS s 00 | 02 PUSHV name 00 |
;           03 CLOSE param 00 <body> 05 | 04 APPLY | 05 RET
;  Builtins: 0 print 1 concat 2 str_head 3 str_tail 4 str_eq
;            5 read_file 6 write_file 7 copy_self
;
;  Build:  nasm -f bin secd.asm -o secd
; ═══════════════════════════════════════════════════════════════════

BITS 64
org 0x400000

ehdr:
    db 0x7F, "ELF", 2, 1, 1, 0
    times 8 db 0
    dw 2
    dw 0x3E
    dd 1
    dq _start
    dq phdr - $$
    dq 0
    dd 0
    dw 64
    dw 56
    dw 1
    dw 0
    dw 0
    dw 0
phdr:
    dd 1                         ; PT_LOAD
    dd 7                         ; RWX
    dq 0
    dq 0x400000
    dq 0x400000
    dq filesize                                  ; p_filesz
    dq filesize + 0x700000                       ; p_memsz (7 MiB working memory)
    dq 0x1000

; ── strcmp(rsi, rdi) → eax 0 if equal ──
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

; ── skipbody: r10 → start of a RET-terminated body; advance r10 past
;    the matching RET. Clobbers rax, rcx; r10 in/out. ──
skipbody:
    mov     rcx, 1               ; nesting depth
.sb:
    movzx   rax, byte [r10]
    inc     r10
    cmp     al, 1                ; PUSHS — skip the inline string
    je      .skipstr
    cmp     al, 2                ; PUSHV — skip the name
    je      .skipstr
    cmp     al, 3                ; CLOSE — skip param, then expect one more RET
    je      .close
    cmp     al, 5                ; RET
    je      .ret
    jmp     .sb                  ; APPLY / HALT — no operand
.skipstr:
    mov     al, [r10]
    inc     r10
    test    al, al
    jnz     .skipstr
    jmp     .sb
.close:
    mov     al, [r10]
    inc     r10
    test    al, al
    jnz     .close
    inc     rcx
    jmp     .sb
.ret:
    dec     rcx
    test    rcx, rcx
    jnz     .sb
    ret

_start:
    mov     rax, 2               ; open("logos_program.bin", O_RDONLY)
    mov     rdi, fname
    xor     rsi, rsi
    xor     rdx, rdx
    syscall
    test    rax, rax
    js      .openfail
    mov     rbp, rax             ; fd
    mov     rax, 0               ; read into progbuf
    mov     rdi, rbp
    mov     rsi, progbuf
    mov     rdx, 0x100000
    syscall
    mov     rax, 3               ; close
    mov     rdi, rbp
    syscall
    mov     rbx, bootstrap       ; C = [PUSHV "MAIN"; HALT]
    mov     r12, ostack
    xor     r13, r13
    mov     r14, dstack
    mov     r15, heap
    jmp     .loop
.openfail:
    mov     rax, 60
    mov     rdi, 1
    syscall

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

.pushs:
    mov     qword [r12], 0
    mov     [r12+8], rbx
    add     r12, 16
.pushs_scan:
    mov     al, [rbx]
    inc     rbx
    test    al, al
    jnz     .pushs_scan
    jmp     .loop

.pushv:
    mov     rbp, rbx             ; name pointer
.pv_scan:
    mov     al, [rbx]
    inc     rbx
    test    al, al
    jnz     .pv_scan
    mov     r10, r13             ; walk environment
.pv_env:
    test    r10, r10
    je      .pv_glyph
    mov     rsi, rbp
    mov     rdi, [r10]
    call    strcmp
    test    eax, eax
    je      .pv_found_env
    mov     r10, [r10+24]
    jmp     .pv_env
.pv_found_env:
    mov     rax, [r10+8]
    mov     [r12], rax
    mov     rax, [r10+16]
    mov     [r12+8], rax
    add     r12, 16
    jmp     .loop
.pv_glyph:
    mov     r10, progbuf         ; scan the glyph table
.pv_gloop:
    cmp     byte [r10], 0        ; empty name = end of table
    je      .pv_builtin
    mov     rsi, rbp
    mov     rdi, r10
    call    strcmp
    test    eax, eax
    je      .pv_found_glyph
.pv_skipname:
    mov     al, [r10]            ; skip this entry's name
    inc     r10
    test    al, al
    jnz     .pv_skipname
    call    skipbody             ; skip this entry's body
    jmp     .pv_gloop
.pv_found_glyph:
    mov     al, [r10]            ; skip the matched name to reach the body
    inc     r10
    test    al, al
    jnz     .pv_found_glyph
    mov     [r14], rbx           ; dump: return C, caller's E
    mov     [r14+8], r13
    add     r14, 16
    mov     rbx, r10             ; C = glyph body
    xor     r13, r13             ; glyph runs in empty environment
    jmp     .loop
.pv_builtin:
    mov     rsi, rbp
    mov     rdi, str_print
    call    strcmp
    test    eax, eax
    je      .bi0
    mov     rsi, rbp
    mov     rdi, str_concat
    call    strcmp
    test    eax, eax
    je      .bi1
    mov     rsi, rbp
    mov     rdi, str_strhead
    call    strcmp
    test    eax, eax
    je      .bi2
    mov     rsi, rbp
    mov     rdi, str_strtail
    call    strcmp
    test    eax, eax
    je      .bi3
    mov     rsi, rbp
    mov     rdi, str_streq
    call    strcmp
    test    eax, eax
    je      .bi4
    mov     rsi, rbp
    mov     rdi, str_readfile
    call    strcmp
    test    eax, eax
    je      .bi5
    mov     rsi, rbp
    mov     rdi, str_writefile
    call    strcmp
    test    eax, eax
    je      .bi6
    mov     rsi, rbp
    mov     rdi, str_copyself
    call    strcmp
    test    eax, eax
    je      .bi7
    jmp     .halt                ; unbound variable
.bi0:
    mov     r11, 0
    jmp     .pushbi
.bi1:
    mov     r11, 1
    jmp     .pushbi
.bi2:
    mov     r11, 2
    jmp     .pushbi
.bi3:
    mov     r11, 3
    jmp     .pushbi
.bi4:
    mov     r11, 4
    jmp     .pushbi
.bi5:
    mov     r11, 5
    jmp     .pushbi
.bi6:
    mov     r11, 6
    jmp     .pushbi
.bi7:
    mov     r11, 7
.pushbi:
    mov     qword [r12], 1
    mov     [r12+8], r11
    add     r12, 16
    jmp     .loop

.close:
    mov     rbp, rbx             ; param pointer
.cl_scan:
    mov     al, [rbx]
    inc     rbx
    test    al, al
    jnz     .cl_scan
    mov     [r15], rbp           ; closure record: [param][body][env]
    mov     [r15+8], rbx
    mov     [r15+16], r13
    mov     qword [r12], 2
    mov     [r12+8], r15
    add     r12, 16
    add     r15, 24
    mov     r10, rbx             ; skip the body in the defining context
    call    skipbody
    mov     rbx, r10
    jmp     .loop

.apply:
    sub     r12, 16
    mov     r8, [r12]            ; arg tag
    mov     r9, [r12+8]          ; arg payload
    sub     r12, 16
    mov     r10, [r12]           ; fn tag
    mov     r11, [r12+8]         ; fn payload
    cmp     r10, 2
    je      .apply_clo
    cmp     r10, 1
    je      .apply_bi
    cmp     r10, 3
    je      .apply_pa
    jmp     .halt
.apply_clo:
    mov     [r14], rbx
    mov     [r14+8], r13
    add     r14, 16
    mov     rax, [r11]
    mov     [r15], rax
    mov     [r15+8], r8
    mov     [r15+16], r9
    mov     rax, [r11+16]
    mov     [r15+24], rax
    mov     r13, r15
    add     r15, 32
    mov     rbx, [r11+8]
    jmp     .loop
.apply_bi:                       ; r11 = builtin id
    cmp     r11, 1               ; 2-ary builtins become partials
    je      .mkpa
    cmp     r11, 4
    je      .mkpa
    cmp     r11, 6
    je      .mkpa
    cmp     r11, 0
    je      .bi_print
    cmp     r11, 2
    je      .bi_strhead
    cmp     r11, 3
    je      .bi_strtail
    cmp     r11, 5
    je      .bi_readfile
    cmp     r11, 7
    je      .bi_copyself
    jmp     .halt
.mkpa:
    mov     [r15], r11           ; PA record: [id][a1 tag][a1 payload]
    mov     [r15+8], r8
    mov     [r15+16], r9
    mov     qword [r12], 3
    mov     [r12+8], r15
    add     r12, 16
    add     r15, 24
    jmp     .loop
.apply_pa:                       ; r11 = PA record; arg2 = (r8,r9)
    mov     r10, [r11]           ; builtin id
    mov     rbp, [r11+16]        ; a1 payload
    cmp     r10, 1
    je      .bi_concat2
    cmp     r10, 4
    je      .bi_streq2
    cmp     r10, 6
    je      .bi_writefile2
    jmp     .halt

.bi_print:                       ; arg STR in r9
    mov     rsi, r9
    mov     rcx, r9
    xor     rdx, rdx
.bp_len:
    cmp     byte [rcx], 0
    je      .bp_w
    inc     rcx
    inc     rdx
    jmp     .bp_len
.bp_w:
    mov     rax, 1
    mov     rdi, 1
    syscall
    mov     rax, 1
    mov     rdi, 1
    mov     rsi, newline
    mov     rdx, 1
    syscall
    mov     qword [r12], 0
    mov     [r12+8], r9
    add     r12, 16
    jmp     .loop

.bi_strhead:                     ; first byte of r9, NUL-terminated, on the heap
    cmp     byte [r9], 0
    je      .sh_empty
    mov     al, [r9]
    mov     [r15], al
    mov     byte [r15+1], 0
    mov     qword [r12], 0
    mov     [r12+8], r15
    add     r12, 16
    add     r15, 2
    jmp     .loop
.sh_empty:
    mov     byte [r15], 0
    mov     qword [r12], 0
    mov     [r12+8], r15
    add     r12, 16
    inc     r15
    jmp     .loop

.bi_strtail:                     ; r9+1 (still NUL-terminated), or the NUL itself
    cmp     byte [r9], 0
    je      .st_empty
    lea     rax, [r9+1]
    mov     qword [r12], 0
    mov     [r12+8], rax
    add     r12, 16
    jmp     .loop
.st_empty:
    mov     qword [r12], 0
    mov     [r12+8], r9
    add     r12, 16
    jmp     .loop

.bi_readfile:                    ; open(r9), read into heap, NUL-terminate
    mov     rax, 2
    mov     rdi, r9
    xor     rsi, rsi
    xor     rdx, rdx
    syscall
    test    rax, rax
    js      .rf_empty
    mov     rbp, rax             ; fd
    mov     r10, r15             ; content start
    mov     rax, 0
    mov     rdi, rbp
    mov     rsi, r15
    mov     rdx, 0x80000
    syscall
    add     r15, rax
    mov     byte [r15], 0
    inc     r15
    mov     rax, 3
    mov     rdi, rbp
    syscall
    mov     qword [r12], 0
    mov     [r12+8], r10
    add     r12, 16
    jmp     .loop
.rf_empty:
    mov     byte [r15], 0
    mov     qword [r12], 0
    mov     [r12+8], r15
    add     r12, 16
    inc     r15
    jmp     .loop

.bi_copyself:                    ; replicate /proc/self/exe → new_logos_secd.bin
    mov     rax, 2
    mov     rdi, proc_self_exe
    xor     rsi, rsi
    xor     rdx, rdx
    syscall
    test    rax, rax
    js      .cs_done
    mov     rbp, rax             ; in fd
    mov     rax, 2
    mov     rdi, cs_target
    mov     rsi, 577             ; O_WRONLY|O_CREAT|O_TRUNC
    mov     rdx, 493             ; 0755
    syscall
    test    rax, rax
    js      .cs_closein
    mov     r10, rax             ; out fd
.cs_loop:
    mov     rax, 0
    mov     rdi, rbp
    mov     rsi, r15
    mov     rdx, 65536
    syscall
    test    rax, rax
    jle     .cs_eof
    mov     rdx, rax
    mov     rax, 1
    mov     rdi, r10
    mov     rsi, r15
    syscall
    jmp     .cs_loop
.cs_eof:
    mov     rax, 3
    mov     rdi, r10
    syscall
.cs_closein:
    mov     rax, 3
    mov     rdi, rbp
    syscall
    mov     rax, 90              ; chmod 0755
    mov     rdi, cs_target
    mov     rsi, 493
    syscall
    mov     rax, 1               ; announce on stderr
    mov     rdi, 2
    mov     rsi, cs_msg
    mov     rdx, cs_msg_len
    syscall
.cs_done:
    mov     qword [r12], 0
    mov     qword [r12+8], cs_target
    add     r12, 16
    jmp     .loop

.bi_concat2:                     ; rbp = a1 ptr, r9 = a2 ptr → heap string
    mov     rsi, rbp
    mov     rdi, r9
    mov     rbp, r15             ; result start (rbp free now)
.cc1:
    mov     al, [rsi]
    test    al, al
    je      .cc2
    mov     [r15], al
    inc     rsi
    inc     r15
    jmp     .cc1
.cc2:
    mov     al, [rdi]
    test    al, al
    je      .cc3
    mov     [r15], al
    inc     rdi
    inc     r15
    jmp     .cc2
.cc3:
    mov     byte [r15], 0
    inc     r15
    mov     qword [r12], 0
    mov     [r12+8], rbp
    add     r12, 16
    jmp     .loop

.bi_streq2:                      ; rbp = a1 ptr, r9 = a2 ptr → Church bool closure
    mov     rsi, rbp
    mov     rdi, r9
    call    strcmp
    mov     rdi, TRUE_BODY
    test    eax, eax
    je      .se_make
    mov     rdi, FALSE_BODY
.se_make:
    mov     rax, str_t
    mov     [r15], rax
    mov     [r15+8], rdi
    mov     qword [r15+16], 0
    mov     qword [r12], 2
    mov     [r12+8], r15
    add     r12, 16
    add     r15, 24
    jmp     .loop

.bi_writefile2:                  ; rbp = path, r9 = content
    mov     rax, 2
    mov     rdi, rbp
    mov     rsi, 577
    mov     rdx, 420             ; 0644
    syscall
    test    rax, rax
    js      .wf_done
    mov     r10, rax             ; fd
    mov     rcx, r9
    xor     rdx, rdx
.wf_len:
    cmp     byte [rcx], 0
    je      .wf_w
    inc     rcx
    inc     rdx
    jmp     .wf_len
.wf_w:
    mov     rax, 1
    mov     rdi, r10
    mov     rsi, r9
    syscall
    mov     rax, 3
    mov     rdi, r10
    syscall
.wf_done:
    mov     qword [r12], 0
    mov     [r12+8], r9
    add     r12, 16
    jmp     .loop

.ret:
    sub     r14, 16
    mov     rbx, [r14]
    mov     r13, [r14+8]
    jmp     .loop

.halt:
    mov     rax, 60
    xor     rdi, rdi
    syscall

; ── read-only data ──
bootstrap:     db 2, "MAIN", 0, 0          ; PUSHV "MAIN"; HALT
fname:         db "logos_program.bin", 0
proc_self_exe: db "/proc/self/exe", 0
cs_target:     db "new_logos_secd.bin", 0
cs_msg:        db "copy_self: replicated -> new_logos_secd.bin", 10
cs_msg_len     equ $ - cs_msg
newline:       db 10
str_t:         db "t", 0
str_print:     db "print", 0
str_concat:    db "concat", 0
str_strhead:   db "str_head", 0
str_strtail:   db "str_tail", 0
str_streq:     db "str_eq", 0
str_readfile:  db "read_file", 0
str_writefile: db "write_file", 0
str_copyself:  db "copy_self", 0
TRUE_BODY:     db 3, "f", 0, 2, "t", 0, 5, 5   ; compiled (la f. t) ++ RET
FALSE_BODY:    db 3, "f", 0, 2, "f", 0, 5, 5   ; compiled (la f. f) ++ RET

filesize equ $ - $$
ostack   equ $$ + filesize
dstack   equ ostack + 0x100000
heap     equ dstack + 0x100000
progbuf  equ heap   + 0x400000
