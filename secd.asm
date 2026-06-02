; ═══════════════════════════════════════════════════════════════════
;  secd.asm — the native SECD machine for LogOS (Albedo Stage 2 + 4)
;
;  A fixed flat ELF (nasm -f bin). At startup it reads a compiled
;  instruction stream from "logos_program.bin" (produced by codegen.la)
;  and executes it. Arbitrary programs compile to streams and run on it
;  natively — threaded SECD. Strings are binary-safe (length-carrying),
;  so a program that itself produces binary (e.g. the compiler, whose
;  output is full of NUL bytes) runs natively too.
;
;  State:  S operand stack (r12) | E environment (r13, 0=empty)
;          C control (rbx)       | D dump (r14) | heap (r15, bump)
;  Value entry (16): [tag(8)][payload(8)].
;    tag 0 STR : payload → descriptor [len(8)][dataptr(8)]   (binary-safe)
;    tag 1 BI  : payload = builtin id
;    tag 2 CLO : payload → [param][body][env]
;    tag 3 PA  : payload → [builtin id][a1 tag][a1 payload]
;  Env cell (32): [name][val tag][val payload][next]
;  Names (vars/params/glyph names) stay NUL-terminated in the stream;
;  only string VALUES carry a length.
;
;  Opcodes: 00 HALT | 01 PUSHS s 00 | 02 PUSHV name 00 |
;           03 CLOSE param 00 <body> 05 | 04 APPLY | 05 RET
;  Builtins: 0 print 1 concat 2 str_head 3 str_tail 4 str_eq
;            5 read_file 6 write_file 7 copy_self 8 chr 9 ord
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
    dd 1
    dd 7
    dq 0
    dq 0x400000
    dq 0x400000
    dq filesize
    dq progbuf - $$ + 0x500000   ; p_memsz: cover up to progbuf + 5 MiB program
                                 ; capacity (lazy). Derived from progbuf so the
                                 ; segment always reaches it when the layout
                                 ; below changes — a fixed constant silently
                                 ; left progbuf unmapped once the stacks grew.
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

; ── skipbody: r10 → body start; advance past the matching RET. ──
skipbody:
    mov     rcx, 1
.sb:
    movzx   rax, byte [r10]
    inc     r10
    cmp     al, 1
    je      .skipstr
    cmp     al, 2
    je      .skipstr
    cmp     al, 3
    je      .close
    cmp     al, 5
    je      .ret
    jmp     .sb
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

; ── desc_atoi(rdi = STR descriptor) → rax (signed integer) ──
; Syscall args/results (fd, flags, pid, status, errno) cross the LA boundary
; as decimal strings, since the VM has no integer value.
desc_atoi:
    mov     rcx, [rdi]
    mov     rsi, [rdi+8]
    xor     rax, rax
    xor     r10, r10
    test    rcx, rcx
    je      .da_done
    cmp     byte [rsi], 45               ; '-'
    jne     .da_loop
    mov     r10, 1
    inc     rsi
    dec     rcx
.da_loop:
    test    rcx, rcx
    je      .da_sign
    movzx   rdx, byte [rsi]
    sub     rdx, 48
    imul    rax, rax, 10
    add     rax, rdx
    inc     rsi
    dec     rcx
    jmp     .da_loop
.da_sign:
    test    r10, r10
    je      .da_done
    neg     rax
.da_done:
    ret

; ── push_dec(rax = signed integer): push its decimal STR and bump r12/r15 ──
push_dec:
    xor     r10, r10
    test    rax, rax
    jns     .pd_abs
    mov     r10, 1
    neg     rax
.pd_abs:
    mov     rcx, 10
    xor     r8, r8                       ; digit count
.pd_div:
    xor     rdx, rdx
    div     rcx
    add     dl, 48
    movzx   rdx, dl
    push    rdx
    inc     r8
    test    rax, rax
    jnz     .pd_div
    mov     rsi, r15                     ; result start
    test    r10, r10
    je      .pd_pop
    mov     byte [r15], 45               ; '-'
    inc     r15
.pd_pop:
    test    r8, r8
    je      .pd_done
    pop     rdx
    mov     [r15], dl
    inc     r15
    dec     r8
    jmp     .pd_pop
.pd_done:
    mov     rdx, r15
    sub     rdx, rsi                     ; length
    mov     [r15], rdx
    mov     [r15+8], rsi
    mov     qword [r12], 0
    mov     [r12+8], r15
    add     r12, 16
    add     r15, 16
    ret

_start:
    mov     rax, 2
    mov     rdi, fname
    xor     rsi, rsi
    xor     rdx, rdx
    syscall
    test    rax, rax
    js      .openfail
    mov     rbp, rax
    mov     rax, 0
    mov     rdi, rbp
    mov     rsi, progbuf
    mov     rdx, 0x100000
    syscall
    mov     rax, 3
    mov     rdi, rbp
    syscall
    mov     rbx, bootstrap
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

.pushs:                          ; rbx → NUL-terminated literal (NUL-free)
    mov     rsi, rbx
    xor     rdx, rdx
.ps_scan:
    cmp     byte [rbx], 0
    je      .ps_done
    inc     rbx
    inc     rdx
    jmp     .ps_scan
.ps_done:
    inc     rbx                  ; skip the terminator
    mov     [r15], rdx           ; descriptor [len][ptr]
    mov     [r15+8], rsi
    mov     qword [r12], 0
    mov     [r12+8], r15
    add     r12, 16
    add     r15, 16
    jmp     .loop

.pushv:
    mov     rbp, rbx
.pv_scan:
    mov     al, [rbx]
    inc     rbx
    test    al, al
    jnz     .pv_scan
    mov     r10, r13
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
    mov     r10, progbuf
.pv_gloop:
    cmp     byte [r10], 0
    je      .pv_builtin
    mov     rsi, rbp
    mov     rdi, r10
    call    strcmp
    test    eax, eax
    je      .pv_found_glyph
.pv_skipname:
    mov     al, [r10]
    inc     r10
    test    al, al
    jnz     .pv_skipname
    call    skipbody
    jmp     .pv_gloop
.pv_found_glyph:
    mov     al, [r10]
    inc     r10
    test    al, al
    jnz     .pv_found_glyph
    mov     [r14], rbx
    mov     [r14+8], r13
    add     r14, 16
    mov     rbx, r10
    xor     r13, r13
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
    mov     rsi, rbp
    mov     rdi, str_chr
    call    strcmp
    test    eax, eax
    je      .bi8
    mov     rsi, rbp
    mov     rdi, str_ord
    call    strcmp
    test    eax, eax
    je      .bi9
    mov     rsi, rbp
    mov     rdi, str_writeexec
    call    strcmp
    test    eax, eax
    je      .bi10
    mov     rsi, rbp
    mov     rdi, str_write
    call    strcmp
    test    eax, eax
    je      .bi11
    mov     rsi, rbp
    mov     rdi, str_open
    call    strcmp
    test    eax, eax
    je      .bi12
    mov     rsi, rbp
    mov     rdi, str_close
    call    strcmp
    test    eax, eax
    je      .bi13
    mov     rsi, rbp
    mov     rdi, str_mount
    call    strcmp
    test    eax, eax
    je      .bi14
    mov     rsi, rbp
    mov     rdi, str_fork
    call    strcmp
    test    eax, eax
    je      .bi15
    mov     rsi, rbp
    mov     rdi, str_execve
    call    strcmp
    test    eax, eax
    je      .bi16
    mov     rsi, rbp
    mov     rdi, str_waitpid
    call    strcmp
    test    eax, eax
    je      .bi17
    mov     rsi, rbp
    mov     rdi, str_exit
    call    strcmp
    test    eax, eax
    je      .bi18
    jmp     .halt
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
    jmp     .pushbi
.bi8:
    mov     r11, 8
    jmp     .pushbi
.bi9:
    mov     r11, 9
    jmp     .pushbi
.bi10:
    mov     r11, 10
    jmp     .pushbi
.bi11:
    mov     r11, 11
    jmp     .pushbi
.bi12:
    mov     r11, 12
    jmp     .pushbi
.bi13:
    mov     r11, 13
    jmp     .pushbi
.bi14:
    mov     r11, 14
    jmp     .pushbi
.bi15:
    mov     r11, 15
    jmp     .pushbi
.bi16:
    mov     r11, 16
    jmp     .pushbi
.bi17:
    mov     r11, 17
    jmp     .pushbi
.bi18:
    mov     r11, 18
.pushbi:
    mov     qword [r12], 1
    mov     [r12+8], r11
    add     r12, 16
    jmp     .loop

.close:
    mov     rbp, rbx
.cl_scan:
    mov     al, [rbx]
    inc     rbx
    test    al, al
    jnz     .cl_scan
    mov     [r15], rbp
    mov     [r15+8], rbx
    mov     [r15+16], r13
    mov     qword [r12], 2
    mov     [r12+8], r15
    add     r12, 16
    add     r15, 24
    mov     r10, rbx
    call    skipbody
    mov     rbx, r10
    jmp     .loop

.apply:
    sub     r12, 16
    mov     r8, [r12]
    mov     r9, [r12+8]
    sub     r12, 16
    mov     r10, [r12]
    mov     r11, [r12+8]
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
.apply_bi:
    cmp     r11, 1
    je      .mkpa
    cmp     r11, 4
    je      .mkpa
    cmp     r11, 6
    je      .mkpa
    cmp     r11, 10
    je      .mkpa
    cmp     r11, 11
    je      .mkpa
    cmp     r11, 12
    je      .mkpa
    cmp     r11, 14
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
    cmp     r11, 8
    je      .bi_chr
    cmp     r11, 9
    je      .bi_ord
    cmp     r11, 13
    je      .bi_close
    cmp     r11, 15
    je      .bi_fork
    cmp     r11, 16
    je      .bi_execve
    cmp     r11, 17
    je      .bi_waitpid
    cmp     r11, 18
    je      .bi_exit
    jmp     .halt
.mkpa:
    mov     [r15], r11
    mov     [r15+8], r8
    mov     [r15+16], r9
    mov     qword [r12], 3
    mov     [r12+8], r15
    add     r12, 16
    add     r15, 24
    jmp     .loop
.apply_pa:
    mov     r10, [r11]
    mov     rbp, [r11+16]
    cmp     r10, 1
    je      .bi_concat2
    cmp     r10, 4
    je      .bi_streq2
    cmp     r10, 6
    je      .bi_writefile2
    cmp     r10, 10
    je      .bi_writeexec2
    cmp     r10, 11
    je      .bi_write2
    cmp     r10, 12
    je      .bi_open2
    cmp     r10, 14
    je      .bi_mount2
    jmp     .halt

; ── builtins (string values are descriptors [len][ptr]) ──
.bi_print:                       ; r9 = STR descriptor
    mov     rsi, [r9+8]
    mov     rdx, [r9]
    mov     rax, 1
    mov     rdi, 1
    syscall
    mov     rax, 1
    mov     rdi, 1
    mov     rsi, newline
    mov     rdx, 1
    syscall
    mov     [r12], r8
    mov     [r12+8], r9
    add     r12, 16
    jmp     .loop

.bi_strhead:                     ; first byte, shares storage
    mov     rcx, [r9]
    mov     rsi, [r9+8]
    test    rcx, rcx
    je      .sh_zero
    mov     qword [r15], 1
    jmp     .sh_mk
.sh_zero:
    mov     qword [r15], 0
.sh_mk:
    mov     [r15+8], rsi
    mov     qword [r12], 0
    mov     [r12+8], r15
    add     r12, 16
    add     r15, 16
    jmp     .loop

.bi_strtail:                     ; drop first byte, shares storage
    mov     rcx, [r9]
    mov     rsi, [r9+8]
    test    rcx, rcx
    je      .st_zero
    dec     rcx
    inc     rsi
    mov     [r15], rcx
    jmp     .st_mk
.st_zero:
    mov     qword [r15], 0
.st_mk:
    mov     [r15+8], rsi
    mov     qword [r12], 0
    mov     [r12+8], r15
    add     r12, 16
    add     r15, 16
    jmp     .loop

.bi_readfile:                    ; path = r9 descriptor → NUL-term in pathbuf
    mov     rcx, [r9]
    mov     rsi, [r9+8]
    mov     rdi, pathbuf
.rf_cp:
    test    rcx, rcx
    je      .rf_cpd
    mov     al, [rsi]
    mov     [rdi], al
    inc     rsi
    inc     rdi
    dec     rcx
    jmp     .rf_cp
.rf_cpd:
    mov     byte [rdi], 0
    mov     rax, 2
    mov     rdi, pathbuf
    xor     rsi, rsi
    xor     rdx, rdx
    syscall
    test    rax, rax
    js      .rf_empty
    mov     rbp, rax
    mov     r10, r15             ; content start
    mov     rax, 0
    mov     rdi, rbp
    mov     rsi, r15
    mov     rdx, 0x4000000
    syscall
    mov     rdx, rax             ; bytes read (preserved across close)
    add     r15, rax
    mov     rax, 3
    mov     rdi, rbp
    syscall
    mov     [r15], rdx           ; descriptor [len][content]
    mov     [r15+8], r10
    mov     qword [r12], 0
    mov     [r12+8], r15
    add     r12, 16
    add     r15, 16
    jmp     .loop
.rf_empty:
    mov     qword [r15], 0
    mov     [r15+8], r15
    mov     qword [r12], 0
    mov     [r12+8], r15
    add     r12, 16
    add     r15, 16
    jmp     .loop

.bi_copyself:                    ; replicate /proc/self/exe → new_logos_secd.bin
    mov     rax, 2
    mov     rdi, proc_self_exe
    xor     rsi, rsi
    xor     rdx, rdx
    syscall
    test    rax, rax
    js      .cs_done
    mov     rbp, rax
    mov     rax, 2
    mov     rdi, cs_target
    mov     rsi, 577
    mov     rdx, 493
    syscall
    test    rax, rax
    js      .cs_closein
    mov     r10, rax
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
    mov     rax, 90
    mov     rdi, cs_target
    mov     rsi, 493
    syscall
    mov     rax, 1
    mov     rdi, 2
    mov     rsi, cs_msg
    mov     rdx, cs_msg_len
    syscall
.cs_done:
    mov     rsi, cs_target       ; result STR(cs_target) with length
    xor     rdx, rdx
.cs_len:
    cmp     byte [rsi], 0
    je      .cs_mk
    inc     rsi
    inc     rdx
    jmp     .cs_len
.cs_mk:
    mov     [r15], rdx
    mov     rax, cs_target
    mov     [r15+8], rax
    mov     qword [r12], 0
    mov     [r12+8], r15
    add     r12, 16
    add     r15, 16
    jmp     .loop

.bi_chr:                         ; r9 = decimal string descriptor → 1 byte
    mov     rsi, [r9+8]
    mov     rcx, [r9]
    xor     rax, rax
.chr_loop:
    test    rcx, rcx
    je      .chr_done
    movzx   rdx, byte [rsi]
    sub     rdx, 48
    imul    rax, rax, 10
    add     rax, rdx
    inc     rsi
    dec     rcx
    jmp     .chr_loop
.chr_done:
    mov     [r15], al            ; the byte
    mov     qword [r15+8], 1     ; descriptor [len=1][ptr=r15]
    mov     [r15+16], r15
    lea     rax, [r15+8]
    mov     qword [r12], 0
    mov     [r12+8], rax
    add     r12, 16
    add     r15, 24
    jmp     .loop

.bi_ord:                         ; r9 = string descriptor → decimal of first byte
    mov     rcx, [r9]
    mov     rsi, [r9+8]
    test    rcx, rcx
    je      .ord_zero
    movzx   eax, byte [rsi]
    jmp     .ord_fmt
.ord_zero:
    xor     eax, eax
.ord_fmt:
    mov     ecx, 10
    xor     r10, r10             ; digit count
.ord_div:
    xor     edx, edx
    div     ecx
    add     dl, 48
    movzx   rdx, dl
    push    rdx
    inc     r10
    test    eax, eax
    jnz     .ord_div
    mov     rsi, r15             ; digits start
    mov     r11, r10             ; count
.ord_pop:
    test    r10, r10
    je      .ord_dn
    pop     rdx
    mov     [r15], dl
    inc     r15
    dec     r10
    jmp     .ord_pop
.ord_dn:
    mov     [r15], r11           ; descriptor [len][ptr]
    mov     [r15+8], rsi
    mov     qword [r12], 0
    mov     [r12+8], r15
    add     r12, 16
    add     r15, 16
    jmp     .loop

.bi_concat2:                     ; rbp = a1 desc, r9 = a2 desc
    mov     rsi, [rbp+8]
    mov     rcx, [rbp]
    mov     rdi, [r9+8]
    mov     r10, [r9]
    mov     rbp, r15             ; result bytes start
.cc_a:
    test    rcx, rcx
    je      .cc_b
    mov     al, [rsi]
    mov     [r15], al
    inc     rsi
    inc     r15
    dec     rcx
    jmp     .cc_a
.cc_b:
    test    r10, r10
    je      .cc_d
    mov     al, [rdi]
    mov     [r15], al
    inc     rdi
    inc     r15
    dec     r10
    jmp     .cc_b
.cc_d:
    mov     rdx, r15
    sub     rdx, rbp             ; total length
    mov     [r15], rdx
    mov     [r15+8], rbp
    mov     qword [r12], 0
    mov     [r12+8], r15
    add     r12, 16
    add     r15, 16
    jmp     .loop

.bi_streq2:                      ; rbp = a1 desc, r9 = a2 desc → Church bool
    mov     rcx, [rbp]
    mov     rax, [r9]
    cmp     rcx, rax
    jne     .se_false
    mov     rsi, [rbp+8]
    mov     rdi, [r9+8]
.se_loop:
    test    rcx, rcx
    je      .se_true
    mov     al, [rsi]
    mov     dl, [rdi]
    cmp     al, dl
    jne     .se_false
    inc     rsi
    inc     rdi
    dec     rcx
    jmp     .se_loop
.se_true:
    mov     rdi, TRUE_BODY
    jmp     .se_make
.se_false:
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

.bi_writefile2:                  ; rbp = path desc, r9 = content desc
    mov     rcx, [rbp]
    mov     rsi, [rbp+8]
    mov     rdi, pathbuf
.wf_cp:
    test    rcx, rcx
    je      .wf_cpd
    mov     al, [rsi]
    mov     [rdi], al
    inc     rsi
    inc     rdi
    dec     rcx
    jmp     .wf_cp
.wf_cpd:
    mov     byte [rdi], 0
    mov     rax, 2
    mov     rdi, pathbuf
    mov     rsi, 577
    mov     rdx, 420
    syscall
    test    rax, rax
    js      .wf_done
    mov     r10, rax
    mov     rsi, [r9+8]
    mov     rdx, [r9]
    mov     rax, 1
    mov     rdi, r10
    syscall
    mov     rax, 3
    mov     rdi, r10
    syscall
.wf_done:
    mov     [r12], r8
    mov     [r12+8], r9
    add     r12, 16
    jmp     .loop

.bi_writeexec2:                  ; rbp = path desc, r9 = content desc; chmod 0755
    mov     rcx, [rbp]
    mov     rsi, [rbp+8]
    mov     rdi, pathbuf
.we_cp:
    test    rcx, rcx
    je      .we_cpd
    mov     al, [rsi]
    mov     [rdi], al
    inc     rsi
    inc     rdi
    dec     rcx
    jmp     .we_cp
.we_cpd:
    mov     byte [rdi], 0
    mov     rax, 2
    mov     rdi, pathbuf
    mov     rsi, 577
    mov     rdx, 493             ; 0755
    syscall
    test    rax, rax
    js      .we_done
    mov     r10, rax
    mov     rsi, [r9+8]
    mov     rdx, [r9]
    mov     rax, 1
    mov     rdi, r10
    syscall
    mov     rax, 3
    mov     rdi, r10
    syscall
    mov     rax, 90              ; chmod 0755
    mov     rdi, pathbuf
    mov     rsi, 493
    syscall
.we_done:
    mov     [r12], r8
    mov     [r12+8], r9
    add     r12, 16
    jmp     .loop

; ── Linux syscalls exposed to Lingua Adamica (ints cross as decimal STRs) ──
.bi_write2:                      ; write(fd)(s) ; rbp = fd desc, r9 = content desc
    mov     rdi, rbp
    call    desc_atoi
    mov     rdi, rax             ; fd
    mov     rsi, [r9+8]
    mov     rdx, [r9]
    mov     rax, 1
    syscall
    call    push_dec             ; bytes written
    jmp     .loop

.bi_open2:                       ; open(path)(flags) ; rbp = path, r9 = flags
    mov     rcx, [rbp]
    mov     rsi, [rbp+8]
    mov     rdi, pathbuf
.op_cp:
    test    rcx, rcx
    je      .op_d
    mov     al, [rsi]
    mov     [rdi], al
    inc     rsi
    inc     rdi
    dec     rcx
    jmp     .op_cp
.op_d:
    mov     byte [rdi], 0
    mov     rdi, r9
    call    desc_atoi
    mov     rsi, rax             ; flags
    mov     rdi, pathbuf
    mov     rdx, 420             ; mode 0644 (when O_CREAT)
    mov     rax, 2
    syscall
    call    push_dec             ; fd
    jmp     .loop

.bi_close:                       ; close(fd) ; r9 = fd desc
    mov     rdi, r9
    call    desc_atoi
    mov     rdi, rax
    mov     rax, 3
    syscall
    call    push_dec
    jmp     .loop

.bi_mount2:                      ; mount(target)(fstype) ; rbp = target, r9 = fstype
    mov     rcx, [rbp]
    mov     rsi, [rbp+8]
    mov     rdi, pathbuf
.mt_t:
    test    rcx, rcx
    je      .mt_td
    mov     al, [rsi]
    mov     [rdi], al
    inc     rsi
    inc     rdi
    dec     rcx
    jmp     .mt_t
.mt_td:
    mov     byte [rdi], 0
    mov     rcx, [r9]
    mov     rsi, [r9+8]
    mov     rdi, fsbuf
.mt_f:
    test    rcx, rcx
    je      .mt_fd
    mov     al, [rsi]
    mov     [rdi], al
    inc     rsi
    inc     rdi
    dec     rcx
    jmp     .mt_f
.mt_fd:
    mov     byte [rdi], 0
    mov     rdi, fsbuf           ; source (ignored for virtual fs, = fstype)
    mov     rsi, pathbuf         ; target
    mov     rdx, fsbuf           ; fstype
    xor     r10, r10             ; flags
    xor     r8, r8               ; data
    mov     rax, 165             ; mount
    syscall
    call    push_dec             ; 0 ok, -errno on failure (EPERM if unprivileged)
    jmp     .loop

.bi_fork:                        ; fork() ; arg ignored. both processes continue.
    mov     rax, 57
    syscall
    call    push_dec             ; child: 0, parent: child pid
    jmp     .loop

.bi_execve:                      ; execve(path) with argv=[path], envp=[] ; r9 = path
    mov     rcx, [r9]
    mov     rsi, [r9+8]
    mov     rdi, pathbuf
.ex_cp:
    test    rcx, rcx
    je      .ex_d
    mov     al, [rsi]
    mov     [rdi], al
    inc     rsi
    inc     rdi
    dec     rcx
    jmp     .ex_cp
.ex_d:
    mov     byte [rdi], 0
    mov     rax, pathbuf         ; argv = [pathbuf, NULL]
    mov     [r15], rax
    mov     qword [r15+8], 0
    mov     rsi, r15
    add     r15, 16
    mov     qword [r15], 0       ; envp = [NULL]
    mov     rdx, r15
    add     r15, 8
    mov     rdi, pathbuf
    mov     rax, 59
    syscall
    call    push_dec             ; only returns on failure: -errno
    jmp     .loop

.bi_waitpid:                     ; waitpid(pid) → child exit status ; r9 = pid desc
    mov     rdi, r9
    call    desc_atoi
    mov     rdi, rax             ; pid
    mov     qword [r15], 0       ; &status
    mov     rsi, r15
    xor     rdx, rdx
    xor     r10, r10
    mov     rax, 61              ; wait4
    syscall
    mov     rax, [r15]           ; status word
    shr     rax, 8               ; WEXITSTATUS
    and     rax, 255
    call    push_dec
    jmp     .loop

.bi_exit:                        ; exit(code) ; r9 = code desc
    mov     rdi, r9
    call    desc_atoi
    mov     rdi, rax
    mov     rax, 60
    syscall

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
bootstrap:     db 2, "MAIN", 0, 0
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
str_chr:       db "chr", 0
str_ord:       db "ord", 0
str_writeexec: db "write_exec", 0
str_write:     db "write", 0
str_open:      db "open", 0
str_close:     db "close", 0
str_mount:     db "mount", 0
str_fork:      db "fork", 0
str_execve:    db "execve", 0
str_waitpid:   db "waitpid", 0
str_exit:      db "exit", 0
TRUE_BODY:     db 3, "f", 0, 2, "t", 0, 5, 5
FALSE_BODY:    db 3, "f", 0, 2, "f", 0, 5, 5

; The operand and dump stacks scale with recursion depth — this SECD machine
; does no tail-call optimisation, so a deep (even tail-) recursion such as
; BYTES walking the VM's own ~14 KB image consumes one frame per step. 16 MiB
; each (~1M frames) gives generous headroom; all regions are lazily mapped.
filesize equ $ - $$
ostack   equ $$ + filesize
dstack   equ ostack  + 0x1000000
pathbuf  equ dstack  + 0x1000000
fsbuf    equ pathbuf + 0x1000
heap     equ fsbuf   + 0x1000
progbuf  equ heap     + 0x30000000
