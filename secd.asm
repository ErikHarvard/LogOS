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
;            10 write_exec 11 write 12 open 13 close 14 mount 15 fork
;            16 execve 17 waitpid 18 exit
;            19 str_to_int 20 int_to_str 21 add 22 sub 23 mul 24 div
;            25 mod 26 lt 27 int_eq   (native integers: value tag 4 INT,
;            payload = the signed integer directly; no heap descriptor)
;            28 reap 29 sleep 30 error 31 pipe 32 read 33 str_len
;            34 drm_mode 35 present   (DRM/KMS dumb-buffer scanout; VM-only)
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
    dq drmbuf - $$ + drmsize     ; p_memsz: map through progbuf + 5 MiB (progbuf
                                 ; is the program-stream buffer) plus the 64 KiB
                                 ; DRM scratch above it; the rest is lazy.
                                 ; Tied to progbuf, not a fixed constant, so the
                                 ; segment tracks progbuf when the layout below
                                 ; shifts — a hardcoded size once left progbuf
                                 ; unmapped after the stacks grew, faulting every
                                 ; program at load.
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
    cmp     r10, progend         ; scanned past the mapped program (unbalanced/
    jae     _start.badstream     ; truncated body) → halt loudly, never fault
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
    cmp     r10, progend
    jae     _start.badstream
    mov     al, [r10]
    inc     r10
    test    al, al
    jnz     .skipstr
    jmp     .sb
.close:
    cmp     r10, progend
    jae     _start.badstream
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
    mov     qword [r15], 0               ; STRDESC GC fwd header
    add     r15, 8
    mov     [r15], rdx
    mov     [r15+8], rsi
    mov     qword [r12], 0
    mov     [r12+8], r15
    add     r12, 16
    add     r15, 16
    ret

; fmt_u_heap: rax = value ≥ 0 → its decimal digits written at [r15], r15
; advanced past them. Clobbers rax/rcx/rdx/r8; preserves rbp/r9/r11. Used by
; .bi_pipe to format the two fds into "<rfd> <wfd>".
fmt_u_heap:
    test    rax, rax
    jnz     .fuh_nz
    mov     byte [r15], 48       ; '0'
    inc     r15
    ret
.fuh_nz:
    mov     rcx, 10
    xor     r8, r8               ; digit count
.fuh_div:
    xor     rdx, rdx
    div     rcx
    add     dl, 48
    push    rdx
    inc     r8
    test    rax, rax
    jnz     .fuh_div
.fuh_pop:
    pop     rdx
    mov     [r15], dl
    inc     r15
    dec     r8
    jnz     .fuh_pop
    ret

_start:
    ; Self-contained binary? The bundler (bundle.la) appends the program stream
    ; at file offset `filesize` — virtual address `progembed` — and patches
    ; p_filesz so it is mapped. Its first byte is a glyph name (nonzero). When
    ; present, copy the embedded stream up into progbuf and skip the file load:
    ; this binary IS the program. An un-bundled VM has zero-fill there → fall
    ; through and open logos_program.bin exactly as before. (progembed aliases
    ; ostack's base; the copy happens before the operand stack is ever used.)
    mov     al, [progembed]
    test    al, al
    jz      .loadfile
    mov     rsi, progembed       ; embedded stream (file-backed, then zero-fill)
    mov     rdi, progbuf
    mov     rcx, progcap         ; fixed 5 MiB copy; the table-end 00 sentinel
    rep     movsb                ; bounds traversal, so no length field is needed
    jmp     .booted
.loadfile:
    mov     rax, 2
    mov     rdi, fname
    xor     rsi, rsi
    xor     rdx, rdx
    syscall
    test    rax, rax
    js      .openfail
    mov     rbp, rax             ; fd
    ; Drain the whole stream into [progbuf, progbuf+progcap) — loop until EOF, so a
    ; >1 MiB stream or a short read is no longer silently truncated. If the buffer
    ; fills before EOF the stream is too large → halt loudly (was: one 1 MiB read,
    ; return value discarded, leftover BSS = 0 = HALT → exit 0 with wrong output).
    mov     r8, progbuf          ; write cursor
.rd_loop:
    mov     rdx, progbuf
    add     rdx, progcap
    sub     rdx, r8              ; remaining capacity
    jz      .progbig             ; buffer full and not yet at EOF → stream too large
    mov     rax, 0               ; sys_read
    mov     rdi, rbp             ; fd
    mov     rsi, r8              ; into the cursor
    syscall
    test    rax, rax
    js      .readfail            ; read error
    jz      .rd_done             ; EOF
    add     r8, rax              ; advance by bytes read
    jmp     .rd_loop
.rd_done:
    mov     rax, 3               ; close(fd)
    mov     rdi, rbp
    syscall
.booted:
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
    ; GC trigger + heap-exhaustion guard. The bump heap is two semispaces:
    ; low [heap, semimid), high [semimid, progbuf). `space_end` is the end of
    ; the one r15 is in. When r15 comes within `margin` of it (margin covers
    ; the largest single allocation — read_file's 64 MiB), run a copying GC.
    ; If r15 is STILL within margin after collecting, the live set itself
    ; doesn't fit: the heap is genuinely exhausted → halt loudly.
    mov     rax, progbuf
    mov     rcx, semimid
    cmp     r15, rcx
    cmovb   rax, rcx
    sub     rax, margin
    cmp     r15, rax
    jb      .nogc
    call    gc
    mov     rax, progbuf
    mov     rcx, semimid
    cmp     r15, rcx
    cmovb   rax, rcx
    sub     rax, margin
    cmp     r15, rax
    jae     .heapfull
.nogc:
    ; Stack-overflow guard. The operand stack S [ostack, dstack) and the dump
    ; D [dstack, pathbuf) each grow at most one 16-byte frame per dispatched
    ; instruction and are NOT garbage-collected. Without tail-call optimisation
    ; a deep recursion would otherwise overrun them into the adjacent buffers,
    ; the GC worklist and the heap — silent corruption (a too-deep program would
    ; exit 0 with the wrong result). So halt loudly the moment either pointer
    ; comes within stackmargin of its region end, exactly as the heap does.
    mov     rax, dstack          ; operand stack S ends where the dump begins
    sub     rax, stackmargin
    cmp     r12, rax
    jae     .stackfull
    mov     rax, pathbuf         ; dump D ends where pathbuf begins
    sub     rax, stackmargin
    cmp     r14, rax
    jae     .stackfull
    cmp     rbx, progend         ; control pointer past the mapped program → halt loudly
    jae     .badstream
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
    mov     qword [r15], 0       ; GC fwd header (not forwarded)
    add     r15, 8
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
    mov     rsi, rbp
    mov     rdi, str_strtoint
    call    strcmp
    test    eax, eax
    je      .bi19
    mov     rsi, rbp
    mov     rdi, str_inttostr
    call    strcmp
    test    eax, eax
    je      .bi20
    mov     rsi, rbp
    mov     rdi, str_add
    call    strcmp
    test    eax, eax
    je      .bi21
    mov     rsi, rbp
    mov     rdi, str_sub
    call    strcmp
    test    eax, eax
    je      .bi22
    mov     rsi, rbp
    mov     rdi, str_mul
    call    strcmp
    test    eax, eax
    je      .bi23
    mov     rsi, rbp
    mov     rdi, str_div
    call    strcmp
    test    eax, eax
    je      .bi24
    mov     rsi, rbp
    mov     rdi, str_mod
    call    strcmp
    test    eax, eax
    je      .bi25
    mov     rsi, rbp
    mov     rdi, str_lt
    call    strcmp
    test    eax, eax
    je      .bi26
    mov     rsi, rbp
    mov     rdi, str_inteq
    call    strcmp
    test    eax, eax
    je      .bi27
    mov     rsi, rbp
    mov     rdi, str_reap
    call    strcmp
    test    eax, eax
    je      .bi28
    mov     rsi, rbp
    mov     rdi, str_sleep
    call    strcmp
    test    eax, eax
    je      .bi29
    mov     rsi, rbp
    mov     rdi, str_error
    call    strcmp
    test    eax, eax
    je      .bi30
    mov     rsi, rbp
    mov     rdi, str_pipe
    call    strcmp
    test    eax, eax
    je      .bi31
    mov     rsi, rbp
    mov     rdi, str_read
    call    strcmp
    test    eax, eax
    je      .bi32
    mov     rsi, rbp
    mov     rdi, str_strlen
    call    strcmp
    test    eax, eax
    je      .bi33
    mov     rsi, rbp
    mov     rdi, str_drmmode
    call    strcmp
    test    eax, eax
    je      .bi34
    mov     rsi, rbp
    mov     rdi, str_present
    call    strcmp
    test    eax, eax
    je      .bi35
    jmp     .unbound             ; unbound name → halt loudly (was: silent exit 0)
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
    jmp     .pushbi
.bi19:
    mov     r11, 19
    jmp     .pushbi
.bi20:
    mov     r11, 20
    jmp     .pushbi
.bi21:
    mov     r11, 21
    jmp     .pushbi
.bi22:
    mov     r11, 22
    jmp     .pushbi
.bi23:
    mov     r11, 23
    jmp     .pushbi
.bi24:
    mov     r11, 24
    jmp     .pushbi
.bi25:
    mov     r11, 25
    jmp     .pushbi
.bi26:
    mov     r11, 26
    jmp     .pushbi
.bi27:
    mov     r11, 27
    jmp     .pushbi
.bi28:
    mov     r11, 28
    jmp     .pushbi
.bi29:
    mov     r11, 29
    jmp     .pushbi
.bi30:
    mov     r11, 30
    jmp     .pushbi
.bi31:
    mov     r11, 31
    jmp     .pushbi
.bi32:
    mov     r11, 32
    jmp     .pushbi
.bi33:
    mov     r11, 33
    jmp     .pushbi
.bi34:
    mov     r11, 34
    jmp     .pushbi
.bi35:
    mov     r11, 35
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
    mov     qword [r15], 0       ; GC fwd header
    add     r15, 8
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
    ; Tail-call optimisation. An APPLY immediately followed by RET (the
    ; closure's result IS the enclosing body's result) is a tail call: instead
    ; of pushing a return frame that the closure's own RET would only pop back
    ; to *our* RET — which then pops the caller's frame anyway — we skip our
    ; push and let the closure's RET return straight to the caller. The discarded
    ; rbx pointed only at that RET, and nothing touches the operand stack between
    ; the two RETs, so the result is identical with one fewer frame. This keeps a
    ; tail-recursive loop (the LogosInit supervision loop, any Z-combinator
    ; iteration) running in BOUNDED dump depth — indefinitely, not ~1M frames.
    cmp     byte [rbx], 5        ; next opcode RET? → tail position
    je      .apply_clo_env       ; yes: reuse the current frame, no push
    mov     [r14], rbx           ; non-tail: save C (return = the byte after APPLY)
    mov     [r14+8], r13         ; save E
    add     r14, 16              ; push the return frame
.apply_clo_env:
    mov     qword [r15], 0       ; GC fwd header (env cell)
    add     r15, 8
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
    cmp     r11, 19
    je      .bi_strtoint
    cmp     r11, 20
    je      .bi_inttostr
    cmp     r11, 21
    je      .mkpa
    cmp     r11, 22
    je      .mkpa
    cmp     r11, 23
    je      .mkpa
    cmp     r11, 24
    je      .mkpa
    cmp     r11, 25
    je      .mkpa
    cmp     r11, 26
    je      .mkpa
    cmp     r11, 27
    je      .mkpa
    cmp     r11, 28
    je      .bi_reap
    cmp     r11, 29
    je      .bi_sleep
    cmp     r11, 30
    je      .bi_error
    cmp     r11, 31
    je      .bi_pipe
    cmp     r11, 32
    je      .mkpa                ; read is curried: read(fd)(maxbytes)
    cmp     r11, 33
    je      .bi_strlen
    cmp     r11, 34
    je      .bi_drmmode
    cmp     r11, 35
    je      .bi_present
    jmp     .halt
.mkpa:
    mov     qword [r15], 0       ; GC fwd header
    add     r15, 8
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
    cmp     r10, 21
    je      .bi_add2
    cmp     r10, 22
    je      .bi_sub2
    cmp     r10, 23
    je      .bi_mul2
    cmp     r10, 24
    je      .bi_div2
    cmp     r10, 25
    je      .bi_mod2
    cmp     r10, 26
    je      .bi_lt2
    cmp     r10, 27
    je      .bi_inteq2
    cmp     r10, 32
    je      .bi_read2
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

.bi_strhead:                     ; first byte, copied into a fresh DATA blob
    mov     rcx, [r9]
    mov     rsi, [r9+8]
    test    rcx, rcx
    je      .sh_zero
    mov     al, [rsi]            ; DATA blob: 1 raw byte (no header)
    mov     [r15], al
    mov     rbp, r15
    inc     r15
    mov     qword [r15], 0       ; STRDESC GC fwd header
    add     r15, 8
    mov     qword [r15], 1       ; len 1
    mov     [r15+8], rbp         ; ptr -> the fresh byte
    jmp     .sh_push
.sh_zero:
    mov     qword [r15], 0       ; STRDESC GC fwd header
    add     r15, 8
    mov     qword [r15], 0       ; len 0
    mov     [r15+8], r15         ; ptr (unused for empty)
.sh_push:
    mov     qword [r12], 0
    mov     [r12+8], r15
    add     r12, 16
    add     r15, 16
    jmp     .loop

.bi_strtail:                     ; drop first byte, copied into a fresh DATA blob
    mov     rcx, [r9]
    mov     rsi, [r9+8]
    test    rcx, rcx
    je      .st_zero
    dec     rcx                  ; new length
    inc     rsi                  ; source after first byte
    ; guard: rcx data bytes + 24-byte STRDESC must fit in the active semispace
    ; (str_tail's copy is input-proportional and otherwise unbounded — mirror
    ; concat's check so a large tail can't overrun the heap into the next region)
    mov     rax, rcx
    add     rax, r15
    add     rax, 24
    mov     r10, progbuf         ; space_end = semimid (low half) or progbuf (high)
    mov     r11, semimid
    cmp     r15, r11
    cmovb   r10, r11
    cmp     rax, r10
    jae     .heapfull
    mov     rbp, r15             ; DATA blob start
    mov     rdx, rcx             ; remember length
.st_cp:
    test    rcx, rcx
    je      .st_cpd
    mov     al, [rsi]
    mov     [r15], al
    inc     rsi
    inc     r15
    dec     rcx
    jmp     .st_cp
.st_cpd:
    mov     qword [r15], 0       ; STRDESC GC fwd header
    add     r15, 8
    mov     [r15], rdx           ; len
    mov     [r15+8], rbp         ; ptr -> fresh copy
    jmp     .st_push
.st_zero:
    mov     qword [r15], 0       ; STRDESC GC fwd header
    add     r15, 8
    mov     qword [r15], 0       ; len 0
    mov     [r15+8], r15
.st_push:
    mov     qword [r12], 0
    mov     [r12+8], r15
    add     r12, 16
    add     r15, 16
    jmp     .loop

.bi_readfile:                    ; path = r9 descriptor → NUL-term in pathbuf
    mov     rcx, [r9]
    mov     rsi, [r9+8]
    mov     rdi, pathbuf
    cmp     rcx, 4095            ; path longer than the 4 KiB buffer (− NUL)?
    ja      .pathlong            ; yes → halt; never overrun pathbuf into fsbuf/gcwork
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
    mov     qword [r15], 0       ; STRDESC GC fwd header
    add     r15, 8
    mov     [r15], rdx           ; descriptor [len][content]
    mov     [r15+8], r10
    mov     qword [r12], 0
    mov     [r12+8], r15
    add     r12, 16
    add     r15, 16
    jmp     .loop
.rf_empty:
    mov     qword [r15], 0       ; STRDESC GC fwd header
    add     r15, 8
    mov     qword [r15], 0       ; len 0
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
    mov     qword [r15], 0       ; STRDESC GC fwd header
    add     r15, 8
    mov     [r15], rdx
    mov     rax, cs_target
    mov     [r15+8], rax
    mov     qword [r12], 0
    mov     [r12+8], r15
    add     r12, 16
    add     r15, 16
    jmp     .loop

.bi_chr:                         ; r9 = decimal string descriptor → 1 byte
    test    r8, r8               ; arg must be a STR (tag 0). A non-string — e.g. an
    jnz     .strtype             ; INT (tag 4), whose payload IS the value, not a
                                 ; pointer — would deref it as a descriptor →
                                 ; SIGSEGV. Halt loudly like the C host instead.
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
    cmp     rax, 255             ; chr expects 0..255 — halt loudly out of range,
    ja      .chrrange            ; like the C host (was: silent low-byte truncation)
    mov     [r15], al            ; DATA blob: 1 raw byte (no header)
    mov     rbp, r15
    inc     r15
    mov     qword [r15], 0       ; STRDESC GC fwd header
    add     r15, 8
    mov     qword [r15], 1       ; len 1
    mov     [r15+8], rbp         ; ptr -> the byte
    mov     qword [r12], 0
    mov     [r12+8], r15
    add     r12, 16
    add     r15, 16
    jmp     .loop

.bi_ord:                         ; r9 = string descriptor → decimal of first byte
    test    r8, r8               ; STR only — a non-string deref crashes (see .bi_chr)
    jnz     .strtype
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
    mov     qword [r15], 0       ; STRDESC GC fwd header
    add     r15, 8
    mov     [r15], r11           ; descriptor [len][ptr]
    mov     [r15+8], rsi
    mov     qword [r12], 0
    mov     [r12+8], r15
    add     r12, 16
    add     r15, 16
    jmp     .loop

.bi_strlen:                      ; r9 = string descriptor → decimal of its length
    mov     rax, [r9]            ; byte length (64-bit; up to read_file's 64 MiB)
    mov     rcx, 10
    xor     r10, r10             ; digit count
.strlen_div:
    xor     edx, edx
    div     rcx                  ; rax = rax/10, rdx = rax%10
    add     dl, 48
    movzx   rdx, dl
    push    rdx
    inc     r10
    test    rax, rax
    jnz     .strlen_div          ; at least one digit (len 0 → "0")
    mov     rsi, r15             ; digits start (DATA blob, no header)
    mov     r11, r10             ; count
.strlen_pop:
    test    r10, r10
    je      .strlen_dn
    pop     rdx
    mov     [r15], dl
    inc     r15
    dec     r10
    jmp     .strlen_pop
.strlen_dn:
    mov     qword [r15], 0       ; STRDESC GC fwd header
    add     r15, 8
    mov     [r15], r11           ; descriptor [len][ptr]
    mov     [r15+8], rsi
    mov     qword [r12], 0
    mov     [r12+8], r15
    add     r12, 16
    add     r15, 16
    jmp     .loop

; ── DRM/KMS scanout (Theourgia Stage 2, native-VM only) ──────────────
; drm_mode("!") sets up a dumb-buffer scanout on /dev/dri/card0 and returns
; "<width> <height> <pitch>" (decimal, space-separated). It opens the primary
; node, enumerates the connected connector + its preferred mode, allocates and
; maps a 32-bpp (XRGB8888, depth 24) dumb framebuffer, and points the CRTC at
; it (SETCRTC). The fd, mapped pointer, buffer size, pitch and dimensions are
; held in globals for present(). Becoming DRM master needs an unobstructed VT;
; under a running compositor the kernel refuses CREATE_DUMB/SETCRTC and we halt
; loudly via .drm_fail (no display is touched). All scratch lives in drmbuf, a
; 64 KiB zero-fill region above the program buffer.
.bi_drmmode:
    mov     rax, 2                    ; open("/dev/dri/card0", O_RDWR)
    mov     rdi, drm_card
    mov     rsi, 2
    xor     rdx, rdx
    syscall
    test    rax, rax
    js      .drm_fail
    mov     [drm_fd], rax
    mov     rdi, rax                  ; best-effort SET_MASTER (ignore result)
    mov     rax, 16
    mov     rsi, 0x641e
    xor     rdx, rdx
    syscall
    ; --- GETRESOURCES: connector/crtc/encoder/fb id arrays + counts ---
    mov     rdi, drm_res
    xor     eax, eax
    mov     ecx, 8
    rep     stosq                     ; zero 64-byte card_res
    mov     rax, drm_fbs
    mov     [drm_res + 0], rax        ; fb_id_ptr
    mov     rax, drm_crtcs
    mov     [drm_res + 8], rax        ; crtc_id_ptr
    mov     rax, drm_conns
    mov     [drm_res + 16], rax       ; connector_id_ptr
    mov     rax, drm_encs
    mov     [drm_res + 24], rax       ; encoder_id_ptr
    mov     dword [drm_res + 32], 32  ; count_fbs cap
    mov     dword [drm_res + 36], 32  ; count_crtcs cap
    mov     dword [drm_res + 40], 32  ; count_connectors cap
    mov     dword [drm_res + 44], 32  ; count_encoders cap
    mov     rdi, [drm_fd]
    mov     rax, 16
    mov     rsi, 0xc04064a0           ; DRM_IOCTL_MODE_GETRESOURCES
    mov     rdx, drm_res
    syscall
    test    rax, rax
    js      .drm_fail
    mov     r9d, [drm_res + 40]       ; actual connector count
    cmp     r9d, 32
    jbe     .dm_cnt_ok
    mov     r9d, 32
.dm_cnt_ok:
    xor     r8, r8                    ; connector index
.dm_conn_loop:
    cmp     r8d, r9d
    jae     .drm_fail                 ; no connected connector with a mode → fail
    mov     rdi, drm_conn
    xor     eax, eax
    mov     ecx, 10
    rep     stosq                     ; zero 80-byte get_connector
    mov     eax, [drm_conns + r8*4]
    mov     [drm_conn + 48], eax      ; connector_id
    mov     rax, drm_modes
    mov     [drm_conn + 8], rax       ; modes_ptr
    mov     dword [drm_conn + 32], 64 ; count_modes cap (props/encoders left 0)
    mov     rdi, [drm_fd]
    mov     rax, 16
    mov     rsi, 0xc05064a7           ; DRM_IOCTL_MODE_GETCONNECTOR
    mov     rdx, drm_conn
    syscall
    test    rax, rax
    js      .dm_conn_next
    cmp     dword [drm_conn + 60], 1  ; connection == DRM_MODE_CONNECTED
    jne     .dm_conn_next
    cmp     dword [drm_conn + 32], 0  ; count_modes > 0
    jne     .dm_found
.dm_conn_next:
    inc     r8
    jmp     .dm_conn_loop
.dm_found:
    movzx   eax, word [drm_modes + 4] ; mode.hdisplay
    mov     [drm_w], rax
    movzx   eax, word [drm_modes + 14]; mode.vdisplay
    mov     [drm_h], rax
    mov     eax, [drm_conn + 48]      ; connector_id (for SETCRTC)
    mov     [drm_connid], eax
    ; --- GETENCODER → crtc_id (fall back to crtcs[0]) ---
    mov     rdi, drm_enc
    xor     eax, eax
    mov     ecx, 3
    rep     stosq                     ; zero 24 (≥20) byte get_encoder
    mov     eax, [drm_conn + 44]      ; encoder_id
    mov     [drm_enc + 0], eax
    mov     rdi, [drm_fd]
    mov     rax, 16
    mov     rsi, 0xc01464a6           ; DRM_IOCTL_MODE_GETENCODER
    mov     rdx, drm_enc
    syscall
    test    rax, rax
    js      .dm_crtc_fallback
    mov     eax, [drm_enc + 8]        ; crtc_id
    test    eax, eax
    jnz     .dm_have_crtc
.dm_crtc_fallback:
    mov     eax, [drm_crtcs + 0]      ; first crtc from resources
.dm_have_crtc:
    mov     [drm_crtcid], eax
    ; --- CREATE_DUMB (32 bpp) ---
    mov     rdi, drm_dumb
    xor     eax, eax
    mov     ecx, 4
    rep     stosq                     ; zero 32-byte create_dumb
    mov     eax, [drm_h]
    mov     [drm_dumb + 0], eax       ; height
    mov     eax, [drm_w]
    mov     [drm_dumb + 4], eax       ; width
    mov     dword [drm_dumb + 8], 32  ; bpp
    mov     rdi, [drm_fd]
    mov     rax, 16
    mov     rsi, 0xc02064b2           ; DRM_IOCTL_MODE_CREATE_DUMB
    mov     rdx, drm_dumb
    syscall
    test    rax, rax
    js      .drm_fail
    mov     eax, [drm_dumb + 20]      ; pitch
    mov     [drm_pitch], rax
    mov     rax, [drm_dumb + 24]      ; size
    mov     [drm_maps], rax
    ; --- ADDFB (depth 24, bpp 32) ---
    mov     rdi, drm_fbcmd
    xor     eax, eax
    mov     ecx, 4
    rep     stosq                     ; zero 32 (≥28) byte fb_cmd
    mov     eax, [drm_w]
    mov     [drm_fbcmd + 4], eax      ; width
    mov     eax, [drm_h]
    mov     [drm_fbcmd + 8], eax      ; height
    mov     eax, [drm_dumb + 20]
    mov     [drm_fbcmd + 12], eax     ; pitch
    mov     dword [drm_fbcmd + 16], 32; bpp
    mov     dword [drm_fbcmd + 20], 24; depth
    mov     eax, [drm_dumb + 16]
    mov     [drm_fbcmd + 24], eax     ; handle
    mov     rdi, [drm_fd]
    mov     rax, 16
    mov     rsi, 0xc01c64ae           ; DRM_IOCTL_MODE_ADDFB
    mov     rdx, drm_fbcmd
    syscall
    test    rax, rax
    js      .drm_fail
    ; --- MAP_DUMB → mmap the buffer ---
    mov     rdi, drm_map
    xor     eax, eax
    mov     ecx, 2
    rep     stosq                     ; zero 16-byte map_dumb
    mov     eax, [drm_dumb + 16]
    mov     [drm_map + 0], eax        ; handle
    mov     rdi, [drm_fd]
    mov     rax, 16
    mov     rsi, 0xc01064b3           ; DRM_IOCTL_MODE_MAP_DUMB
    mov     rdx, drm_map
    syscall
    test    rax, rax
    js      .drm_fail
    mov     r9, [drm_map + 8]         ; mmap offset (6th arg)
    xor     rdi, rdi                  ; addr = NULL
    mov     rsi, [drm_maps]           ; length = size
    mov     rdx, 3                    ; PROT_READ|PROT_WRITE
    mov     r10, 1                    ; MAP_SHARED
    mov     r8, [drm_fd]
    mov     rax, 9                    ; mmap
    syscall
    cmp     rax, -4096                ; mmap error (-errno) ?
    ja      .drm_fail
    mov     [drm_mapp], rax
    ; --- SETCRTC: point the CRTC at our fb with the chosen mode ---
    mov     rdi, drm_crtc
    xor     eax, eax
    mov     ecx, 13
    rep     stosq                     ; zero 104-byte crtc
    mov     rax, drm_connid
    mov     [drm_crtc + 0], rax       ; set_connectors_ptr
    mov     dword [drm_crtc + 8], 1   ; count_connectors
    mov     eax, [drm_crtcid]
    mov     [drm_crtc + 12], eax      ; crtc_id
    mov     eax, [drm_fbcmd + 0]
    mov     [drm_crtc + 16], eax      ; fb_id
    mov     dword [drm_crtc + 32], 1  ; mode_valid
    mov     rsi, drm_modes            ; copy chosen mode (68 bytes) into crtc.mode
    mov     rdi, drm_crtc + 36
    mov     ecx, 68
    rep     movsb
    mov     rdi, [drm_fd]
    mov     rax, 16
    mov     rsi, 0xc06864a2           ; DRM_IOCTL_MODE_SETCRTC
    mov     rdx, drm_crtc
    syscall
    test    rax, rax
    js      .drm_fail
    ; --- build the "<w> <h> <pitch>" result string on the heap ---
    mov     rbp, r15                  ; bytes start
    mov     rax, [drm_w]
    call    fmt_u_heap
    mov     byte [r15], 32
    inc     r15
    mov     rax, [drm_h]
    call    fmt_u_heap
    mov     byte [r15], 32
    inc     r15
    mov     rax, [drm_pitch]
    call    fmt_u_heap
    mov     rdx, r15
    sub     rdx, rbp                  ; length
    mov     qword [r15], 0            ; STRDESC GC fwd header
    add     r15, 8
    mov     [r15], rdx
    mov     [r15+8], rbp
    mov     qword [r12], 0
    mov     [r12+8], r15
    add     r12, 16
    add     r15, 16
    jmp     .loop

; present(pixels): blit a binary-safe string of framebuffer bytes into the
; mapped dumb buffer (clamped to its size); the scanned-out CRTC shows it. The
; pixels are expected to be height*pitch bytes of XRGB8888 (little-endian: the
; bytes of each pixel are B,G,R,X). Returns the pixel string unchanged.
.bi_present:
    mov     rax, [drm_mapp]
    test    rax, rax
    jz      .drm_fail                 ; present() before a successful drm_mode()
    mov     rcx, [r9]                 ; source length
    mov     rdx, [drm_maps]
    cmp     rcx, rdx
    jbe     .pr_len
    mov     rcx, rdx                  ; clamp to buffer size
.pr_len:
    mov     rsi, [r9+8]               ; source bytes
    mov     rdi, rax                  ; dst = mapped buffer
    rep     movsb
    mov     [r12], r8                 ; return the pixel value
    mov     [r12+8], r9
    add     r12, 16
    jmp     .loop
.drm_fail:
    mov     rax, 1
    mov     rdi, 2
    mov     rsi, drmmsg
    mov     rdx, drmmsg_len
    syscall
    mov     rax, 60
    mov     rdi, 1
    syscall

.bi_concat2:                     ; rbp = a1 desc, r9 = a2 desc
    ; guard: result is len1+len2 bytes + a 16-byte descriptor; halt if it would
    ; overrun the heap (concat is the one builtin with an unbounded single alloc)
    mov     rax, [rbp]
    add     rax, [r9]
    add     rax, r15
    add     rax, 24              ; bytes + STRDESC (8 header + 16 fields)
    mov     rcx, progbuf         ; space_end = semimid (low) or progbuf (high)
    mov     rdx, semimid
    cmp     r15, rdx
    cmovb   rcx, rdx
    cmp     rax, rcx
    jae     .heapfull
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
    mov     qword [r15], 0       ; STRDESC GC fwd header
    add     r15, 8
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
    mov     qword [r15], 0       ; GC fwd header (bool closure)
    add     r15, 8
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
    cmp     rcx, 4095
    ja      .pathlong
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
    cmp     rcx, 4095
    ja      .pathlong
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
    cmp     rcx, 4095
    ja      .pathlong
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
    cmp     rcx, 4095
    ja      .pathlong
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
    cmp     rcx, 4095
    ja      .pathlong
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
    cmp     rcx, 4095
    ja      .pathlong
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

.bi_reap:                        ; reap("!") → pid of any reaped child, or -errno
    ; wait4(-1, &status, 0, NULL): block until ANY child terminates, reap it,
    ; and return its pid. The status word is discarded — a supervisor needs the
    ; *identity* of the dead child, not its exit code. With no children left the
    ; kernel returns -ECHILD, which push_dec renders as a negative string. This
    ; is the orphan-reaping primitive for an init: as PID 1, children orphaned by
    ; an exiting parent are reparented here and reaped by the same -1 wait.
    mov     rdi, -1              ; pid = -1: any child
    mov     qword [r15], 0       ; &status (result discarded)
    mov     rsi, r15
    xor     rdx, rdx             ; options = 0 → block
    xor     r10, r10             ; rusage = NULL
    mov     rax, 61              ; wait4
    syscall
    call    push_dec             ; reaped pid, or -errno (e.g. -10 = -ECHILD)
    jmp     .loop

.bi_sleep:                       ; sleep(seconds) → 0, or -errno if interrupted
    ; nanosleep({tv_sec = seconds, tv_nsec = 0}, NULL). The timespec is built as
    ; scratch at r15 (not bump-allocated): the syscall consumes it before
    ; push_dec reuses r15 for the result. Gives an init a real backoff so a
    ; flapping shell is rate-limited instead of respawned in a tight loop.
    mov     rdi, r9              ; decimal-seconds descriptor
    call    desc_atoi
    mov     [r15], rax           ; tv_sec
    mov     qword [r15+8], 0     ; tv_nsec
    mov     rdi, r15             ; req timespec
    xor     rsi, rsi             ; rem = NULL
    mov     rax, 35              ; nanosleep
    syscall
    call    push_dec             ; 0 on full sleep, -errno (e.g. -EINTR) otherwise
    jmp     .loop

.bi_error:                       ; error(msg) ; r9 = STR descriptor — print, exit 1
    ; The abort opcode: a .la program (codegen's PARSE_PROGRAM on malformed
    ; input) fails loudly instead of degrading. Prints msg + newline to stderr
    ; and exits non-zero — the VM analogue of the host's `error` builtin, so the
    ; same Lingua Adamica source halts the same way on the native engine.
    mov     rsi, [r9+8]          ; msg bytes
    mov     rdx, [r9]            ; msg length
    mov     rax, 1
    mov     rdi, 2               ; stderr
    syscall
    mov     rax, 1
    mov     rdi, 2
    mov     rsi, newline
    mov     rdx, 1
    syscall
    mov     rax, 60
    mov     rdi, 1               ; exit 1
    syscall

.bi_pipe:                        ; pipe("!") → "<rfd> <wfd>" (two decimal fds)
    ; pipe(fds): fds[0]=read end, fds[1]=write end. Both inherited across fork,
    ; so a parent creates the channel once, forks, and the child writes the end
    ; the parent reads. The two fds are returned as one space-separated string;
    ; the IPC layer splits it. fds land in pathbuf (scratch), then are formatted
    ; into a heap string.
    mov     rdi, pathbuf
    mov     rax, 22              ; pipe(fds)
    syscall
    test    rax, rax
    js      .pipe_fail
    mov     rbp, r15             ; result bytes start
    movsxd  rax, dword [pathbuf]      ; read fd
    call    fmt_u_heap
    mov     byte [r15], 32       ; ' '
    inc     r15
    movsxd  rax, dword [pathbuf+4]    ; write fd
    call    fmt_u_heap
    mov     rdx, r15
    sub     rdx, rbp             ; length
    mov     qword [r15], 0       ; STRDESC GC fwd header
    add     r15, 8
    mov     [r15], rdx
    mov     [r15+8], rbp
    mov     qword [r12], 0
    mov     [r12+8], r15
    add     r12, 16
    add     r15, 16
    jmp     .loop
.pipe_fail:
    mov     rax, -1              ; "-1" on failure
    call    push_dec
    jmp     .loop

.bi_read2:                       ; read(fd)(maxbytes) → up to maxbytes from fd
    ; raw read(2) on a fd — the streaming counterpart of write. Blocks until
    ; data is available (a pipe RECV waits for its SEND), returns the bytes read
    ; as a binary-safe string. maxbytes is clamped to 64 MiB so the read stays
    ; within the heap margin, exactly like read_file.
    mov     rdi, rbp             ; fd descriptor
    call    desc_atoi
    mov     r11, rax             ; fd (desc_atoi clobbers r10 but not r11)
    mov     rdi, r9              ; maxbytes descriptor
    call    desc_atoi
    mov     rdx, rax             ; count
    mov     rax, 0x4000000       ; clamp to 64 MiB
    cmp     rdx, rax
    cmova   rdx, rax
    mov     rdi, r11             ; fd
    mov     rsi, r15             ; buffer = heap
    mov     rax, 0               ; read
    syscall
    test    rax, rax
    js      .read_empty          ; error/-errno → empty string
    mov     rdx, rax             ; bytes read = length
    mov     r10, r15             ; content start
    add     r15, rax             ; advance past the data
    mov     qword [r15], 0       ; STRDESC GC fwd header
    add     r15, 8
    mov     [r15], rdx
    mov     [r15+8], r10
    mov     qword [r12], 0
    mov     [r12+8], r15
    add     r12, 16
    add     r15, 16
    jmp     .loop
.read_empty:
    mov     qword [r15], 0       ; STRDESC GC fwd header
    add     r15, 8
    mov     qword [r15], 0       ; len 0
    mov     [r15+8], r15
    mov     qword [r12], 0
    mov     [r12+8], r15
    add     r12, 16
    add     r15, 16
    jmp     .loop

.bi_exit:                        ; exit(code) ; r9 = code desc
    mov     rdi, r9
    call    desc_atoi
    mov     rdi, rax
    mov     rax, 60
    syscall

; ── native integers (INT value = tag 4, payload = the signed integer) ──
.bi_strtoint:                    ; r9 = decimal STR descriptor → INT
    mov     rdi, r9
    call    desc_atoi
    mov     qword [r12], 4
    mov     [r12+8], rax
    add     r12, 16
    jmp     .loop

.bi_inttostr:                    ; r9 = INT payload → decimal STR (via push_dec)
    mov     rax, r9
    call    push_dec
    jmp     .loop

.bi_add2:                        ; rbp = a1 int, r9 = a2 int (Ontodirection ▷)
    mov     rax, rbp
    add     rax, r9
    jmp     .push_int
.bi_sub2:
    mov     rax, rbp
    sub     rax, r9
    jmp     .push_int
.bi_mul2:
    mov     rax, rbp
    imul    rax, r9
    jmp     .push_int
.bi_div2:
    test    r9, r9
    je      .int_divzero
    mov     rax, rbp
    cqo
    idiv    r9
    jmp     .push_int
.bi_mod2:
    test    r9, r9
    je      .int_divzero
    mov     rax, rbp
    cqo
    idiv    r9
    mov     rax, rdx
    jmp     .push_int
.push_int:
    mov     qword [r12], 4
    mov     [r12+8], rax
    add     r12, 16
    jmp     .loop
.int_divzero:
    mov     rax, 60              ; div/mod by zero — halt (matches the C host)
    mov     rdi, 1
    syscall

.bi_lt2:                         ; rbp < r9 (signed) → Church bool closure
    cmp     rbp, r9
    jl      .int_true
    jmp     .int_false
.bi_inteq2:
    cmp     rbp, r9
    je      .int_true
    jmp     .int_false
.int_true:
    mov     rdi, TRUE_BODY
    jmp     .int_bool
.int_false:
    mov     rdi, FALSE_BODY
.int_bool:
    mov     qword [r15], 0       ; GC fwd header (bool closure)
    add     r15, 8
    mov     rax, str_t
    mov     [r15], rax
    mov     [r15+8], rdi
    mov     qword [r15+16], 0
    mov     qword [r12], 2
    mov     [r12+8], r15
    add     r12, 16
    add     r15, 24
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

.heapfull:                       ; bump heap would overrun progbuf — halt loudly
    mov     rax, 1
    mov     rdi, 2               ; stderr
    mov     rsi, heapmsg
    mov     rdx, heapmsg_len
    syscall
    mov     rax, 60
    mov     rdi, 1
    syscall

.stackfull:                      ; operand stack or dump near its end — halt loudly
    mov     rax, 1
    mov     rdi, 2               ; stderr
    mov     rsi, stackmsg
    mov     rdx, stackmsg_len
    syscall
    mov     rax, 60
    mov     rdi, 1
    syscall

.pathlong:                       ; a path/fstype arg ≥ 4 KiB would overrun the buffer
    mov     rax, 1
    mov     rdi, 2               ; stderr
    mov     rsi, pathmsg
    mov     rdx, pathmsg_len
    syscall
    mov     rax, 60
    mov     rdi, 1
    syscall

.unbound:                        ; a name resolved as neither env, glyph, nor builtin
    mov     rax, 1               ; — halt loudly (exit 1), like the C host / eval.la /
    mov     rdi, 2               ;   RUN_BYTES / RUN_SM, instead of silently exit(0)
    mov     rsi, unboundmsg
    mov     rdx, unboundmsg_len
    syscall
    mov     rax, 60
    mov     rdi, 1
    syscall

.progbig:                        ; program stream larger than the mapped buffer
    mov     rax, 1
    mov     rdi, 2
    mov     rsi, progmsg
    mov     rdx, progmsg_len
    syscall
    mov     rax, 60
    mov     rdi, 1
    syscall

.readfail:                       ; read(2) on the program stream returned an error
    mov     rax, 1
    mov     rdi, 2
    mov     rsi, readmsg
    mov     rdx, readmsg_len
    syscall
    mov     rax, 60
    mov     rdi, 1
    syscall

.badstream:                      ; control pointer / skipbody scan ran off the program
    mov     rax, 1
    mov     rdi, 2
    mov     rsi, badstrmsg
    mov     rdx, badstrmsg_len
    syscall
    mov     rax, 60
    mov     rdi, 1
    syscall

.chrrange:                       ; chr argument outside 0..255
    mov     rax, 1
    mov     rdi, 2
    mov     rsi, chrmsg
    mov     rdx, chrmsg_len
    syscall
    mov     rax, 60
    mov     rdi, 1
    syscall

.strtype:                        ; chr/ord given a non-string (would deref a non-ptr)
    mov     rax, 1
    mov     rdi, 2
    mov     rsi, strtypemsg
    mov     rdx, strtypemsg_len
    syscall
    mov     rax, 60
    mov     rdi, 1
    syscall

; ═══════════════════════════════════════════════════════════════════
;  Copying garbage collector — two semispaces over [heap, progbuf):
;  low [heap, semimid), high [semimid, progbuf). Triggered from .loop
;  when r15 nears the active semispace's end; live data is copied into
;  the other space and r15 resumes bump-allocating there.
;
;  Roots: operand stack S [ostack, r12), env E (r13), dump D
;  [dstack, r14) (each frame's saved E). Boxed objects
;  (STRDESC/CLO/PA/ENVCELL) carry an 8-byte forwarding header (init 0);
;  raw DATA byte-buffers carry none and are copied inline (length from
;  the owning STRDESC, which owns its bytes 1:1 since str_head/str_tail/
;  chr copy rather than alias). The collector is type-directed: an
;  object's shape is known from the value tag (or kind) that reaches it,
;  so the heap needs no per-object size/type word. An explicit worklist
;  (gcwork) stands in for host recursion, so a 100k-deep env chain is
;  copied iteratively without overflowing the CPU stack.
;
;  Forwarding: once copied, an object's *fromspace* header holds
;  (newptr | 1); newptr is 8-aligned so bit 0 is an unambiguous
;  "already copied" flag, and a second reference resolves to the same
;  copy (sharing preserved, no duplication, no divergence on the DAG).
; ═══════════════════════════════════════════════════════════════════
gc:
    mov     rax, semimid         ; tospace = the semispace r15 is NOT in
    cmp     r15, rax
    jb      .to_high
    mov     rax, heap            ; r15 in high → tospace = low
    jmp     .to_set
.to_high:
    mov     rax, semimid         ; r15 in low  → tospace = high
.to_set:
    mov     [gc_tofree], rax
    mov     rax, gcwork
    mov     [gc_wktop], rax
    mov     r10, ostack          ; root: operand stack S [ostack, r12)
    ; r10 is the cursor: the forward helpers clobber rax/rcx/rdx/rsi/rdi/r8/r9
    ; but never r10, so it survives the calls without a save/restore.
.s_loop:
    cmp     r10, r12
    jae     .s_done
    mov     rdi, [r10]           ; value tag
    mov     rdx, [r10+8]         ; value payload
    call    gc_forward_value
    mov     [r10+8], rdx
    add     r10, 16
    jmp     .s_loop
.s_done:
    test    r13, r13             ; root: env E
    je      .e_done
    mov     rdi, r13
    call    gc_forward_env
    mov     r13, rax
.e_done:
    mov     r10, dstack          ; roots: dump D [dstack, r14)
.d_loop:
    cmp     r10, r14
    jae     .d_done
    mov     rdi, [r10+8]         ; saved E (saved C is a progbuf ptr — skip)
    test    rdi, rdi
    je      .d_next
    call    gc_forward_env
    mov     [r10+8], rax
.d_next:
    add     r10, 16
    jmp     .d_loop
.d_done:
.w_loop:                         ; drain worklist: [kind][tospace fields ptr]
    mov     rax, [gc_wktop]
    mov     rcx, gcwork
    cmp     rax, rcx
    jbe     .w_done
    sub     rax, 16
    mov     [gc_wktop], rax
    mov     rdi, [rax]           ; kind
    mov     rsi, [rax+8]         ; fields ptr (in tospace)
    call    gc_scan
    jmp     .w_loop
.w_done:
    mov     r15, [gc_tofree]     ; resume bump allocation in tospace
    ret

; gc_forward_value(rdi=tag, rdx=payload) → rdx = updated payload (tag kept)
gc_forward_value:
    cmp     rdi, 0
    je      .fv_str
    cmp     rdi, 2
    je      .fv_clo
    cmp     rdi, 3
    je      .fv_pa
    ret                          ; tag 1 BI / tag 4 INT: payload is not a pointer
.fv_str:
    mov     rsi, rdx
    mov     rcx, 16
    mov     r8, 0
    jmp     gc_copy_box          ; tail: returns rdx to our caller
.fv_clo:
    mov     rsi, rdx
    mov     rcx, 24
    mov     r8, 2
    jmp     gc_copy_box
.fv_pa:
    mov     rsi, rdx
    mov     rcx, 24
    mov     r8, 3
    jmp     gc_copy_box

; gc_forward_env(rdi=env fields ptr) → rax = new fields ptr
gc_forward_env:
    mov     rsi, rdi
    mov     rcx, 32
    mov     r8, 5
    call    gc_copy_box
    mov     rax, rdx
    ret

; gc_copy_box(rsi=fromspace fields ptr, rcx=size, r8=kind) → rdx = new fields ptr
gc_copy_box:
    mov     rax, [rsi-8]         ; forwarding header
    test    rax, 1
    jz      .cb_fresh
    and     rax, -8              ; already copied → recover newptr
    mov     rdx, rax
    ret
.cb_fresh:
    mov     rax, [gc_tofree]
    add     rax, 7
    and     rax, -8              ; align dst base to 8
    mov     qword [rax], 0       ; fresh (not-forwarded) header
    lea     rdx, [rax+8]         ; dst fields ptr (return value)
    mov     r9, rdx
    or      r9, 1
    mov     [rsi-8], r9          ; install forwarding in fromspace header
    mov     r9, [gc_wktop]
    mov     rax, gcwork_end
    cmp     r9, rax
    jae     _start.heapfull      ; worklist overflow → halt loudly
    mov     [r9], r8             ; enqueue (kind, dst fields)
    mov     [r9+8], rdx
    add     r9, 16
    mov     [gc_wktop], r9
    push    rdx
    mov     rdi, rdx
    rep     movsb                ; copy `rcx` bytes fromspace → tospace
    mov     [gc_tofree], rdi
    pop     rdx
    ret

; gc_scan(rdi=kind, rsi=tospace fields ptr): forward this object's pointers
gc_scan:
    cmp     rdi, 0
    je      .sc_str
    cmp     rdi, 2
    je      .sc_clo
    cmp     rdi, 3
    je      .sc_pa
    cmp     rdi, 5
    je      .sc_env
    ret
.sc_str:                         ; [len][ptr]: copy the owned DATA blob, fix ptr
    mov     rcx, [rsi]
    test    rcx, rcx
    je      .sc_ret              ; empty string: ptr unused
    mov     rdx, [rsi+8]
    mov     rax, heap
    cmp     rdx, rax
    jb      .sc_ret              ; below heap → static, leave
    mov     rax, progbuf
    cmp     rdx, rax
    jae     .sc_ret              ; in progbuf → leave (PUSHS literal)
    push    rsi
    mov     rdi, [gc_tofree]
    mov     [rsi+8], rdi         ; STRDESC.ptr := new data location
    mov     rsi, rdx
    rep     movsb
    mov     [gc_tofree], rdi
    pop     rsi
    ret
.sc_clo:                         ; [param][body][env]: param/body → progbuf
    mov     rdi, [rsi+16]
    test    rdi, rdi
    je      .sc_ret
    push    rsi
    call    gc_forward_env
    pop     rsi
    mov     [rsi+16], rax
    ret
.sc_pa:                          ; [id][a1tag][a1payload]
    mov     rdi, [rsi+8]
    mov     rdx, [rsi+16]
    push    rsi
    call    gc_forward_value
    pop     rsi
    mov     [rsi+16], rdx
    ret
.sc_env:                         ; [name][valtag][valpayload][next]
    mov     rdi, [rsi+8]
    mov     rdx, [rsi+16]
    push    rsi
    call    gc_forward_value
    pop     rsi
    mov     [rsi+16], rdx
    mov     rdi, [rsi+24]
    test    rdi, rdi
    je      .sc_ret
    push    rsi
    call    gc_forward_env
    pop     rsi
    mov     [rsi+24], rax
.sc_ret:
    ret

; ── read-only data ──
heapmsg:       db "secd: heap exhausted", 10
heapmsg_len    equ $ - heapmsg
stackmsg:      db "secd: stack overflow", 10
stackmsg_len   equ $ - stackmsg
pathmsg:       db "secd: path too long", 10
pathmsg_len    equ $ - pathmsg
unboundmsg:    db "secd: unbound variable", 10
unboundmsg_len equ $ - unboundmsg
progmsg:       db "secd: program too large", 10
progmsg_len    equ $ - progmsg
readmsg:       db "secd: read error", 10
readmsg_len    equ $ - readmsg
badstrmsg:     db "secd: malformed program", 10
badstrmsg_len  equ $ - badstrmsg
chrmsg:        db "secd: chr out of range", 10
chrmsg_len     equ $ - chrmsg
strtypemsg:    db "secd: chr/ord expects a string", 10
strtypemsg_len equ $ - strtypemsg
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
str_strtoint:  db "str_to_int", 0
str_inttostr:  db "int_to_str", 0
str_add:       db "add", 0
str_sub:       db "sub", 0
str_mul:       db "mul", 0
str_div:       db "div", 0
str_mod:       db "mod", 0
str_lt:        db "lt", 0
str_inteq:     db "int_eq", 0
str_reap:      db "reap", 0
str_sleep:     db "sleep", 0
str_error:     db "error", 0
str_pipe:      db "pipe", 0
str_read:      db "read", 0
str_strlen:    db "str_len", 0
str_drmmode:   db "drm_mode", 0
str_present:   db "present", 0
drm_card:      db "/dev/dri/card0", 0
drmmsg:        db "secd: drm error", 10
drmmsg_len     equ $ - drmmsg
TRUE_BODY:     db 3, "f", 0, 2, "t", 0, 5, 5
FALSE_BODY:    db 3, "f", 0, 2, "f", 0, 5, 5
gc_tofree:     dq 0              ; GC: bump pointer within tospace during a collect
gc_wktop:      dq 0              ; GC: worklist stack top (into gcwork)
; DRM/KMS scanout state, shared between drm_mode() and present().
drm_fd:        dq 0              ; /dev/dri/card0 fd
drm_mapp:      dq 0              ; mmap'd dumb-buffer pointer (0 until drm_mode succeeds)
drm_maps:      dq 0              ; dumb-buffer size in bytes
drm_pitch:     dq 0             ; bytes per row
drm_w:         dq 0              ; mode width  (pixels)
drm_h:         dq 0              ; mode height (pixels)
drm_crtcid:    dq 0             ; chosen CRTC id

; The operand and dump stacks scale with recursion depth — this SECD machine
; does no tail-call optimisation, so a deep (even tail-) recursion such as
; BYTES walking the VM's own ~14 KB image consumes one frame per step. 16 MiB
; each (~1M frames) gives generous headroom; all regions are lazily mapped.
filesize equ $ - $$
ostack   equ $$ + filesize
; progembed: where bundle.la appends the program stream (file offset filesize).
; Aliases ostack's base — safe because _start copies the embedded stream out to
; progbuf BEFORE the operand stack is touched, then ostack reuses the space.
progembed equ ostack
dstack   equ ostack  + 0x1000000
pathbuf  equ dstack  + 0x1000000
stackmargin equ 0x1000               ; halt this many bytes (256 frames) before
                                     ; the operand-stack / dump region end; one
                                     ; dispatch grows either by at most one frame
fsbuf    equ pathbuf + 0x1000
gcwork   equ fsbuf   + 0x1000        ; GC worklist: 16 MiB = 1 Mi (kind,ptr) entries
gcwork_end equ gcwork + 0x1000000
; The bump heap is split into two equal semispaces for a copying collector.
; Allocation bumps r15 inside the active half; at a collect the live set is
; copied into the other half (see gc). 768 MiB each — ~703 MiB usable before
; the GC/exhaustion margin: a single semispace matches the old non-GC bump
; heap's capacity, so any workload that fit before GC still fits in one half
; even with zero reclamation (compiling secd.la peaks at ~320 MiB live; the
; earlier 384 MiB split left only ~319 MiB usable and exhausted at that peak).
; All regions are lazily mapped, so the larger reservation costs nothing until
; touched.
heap     equ gcwork_end              ; semispaces: low [heap, semimid), high [semimid, progbuf)
semimid  equ heap    + 0x30000000    ; 768 MiB: boundary between the two semispaces
progbuf  equ heap    + 0x60000000    ; 1536 MiB total; program stream loads at progbuf
progcap  equ 0x500000                ; 5 MiB mapped for the program stream (matches the
                                     ; phdr p_memsz tail); the loader fills up to here
progend  equ progbuf + progcap       ; mapped end of the program region; bounds the
                                     ; control pointer rbx and skipbody's scans so a
                                     ; truncated/malformed stream halts loudly, not SIGSEGV
; DRM modeset scratch: ioctl structs + id/mode arrays. 64 KiB above the program
; buffer (zero-fill, lazily mapped); p_memsz below is extended to cover it.
drmbuf   equ progend
drm_res      equ drmbuf + 0          ; drm_mode_card_res (64)
drm_conns    equ drmbuf + 64         ; connector id array (32 × u32)
drm_crtcs    equ drmbuf + 192        ; crtc id array
drm_encs     equ drmbuf + 320        ; encoder id array
drm_fbs      equ drmbuf + 448        ; fb id array
drm_conn     equ drmbuf + 576        ; drm_mode_get_connector (80)
drm_modes    equ drmbuf + 656        ; drm_mode_modeinfo array (64 × 68)
drm_enc      equ drmbuf + 5008       ; drm_mode_get_encoder (20)
drm_dumb     equ drmbuf + 5040       ; drm_mode_create_dumb (32)
drm_map      equ drmbuf + 5072       ; drm_mode_map_dumb (16)
drm_fbcmd    equ drmbuf + 5088       ; drm_mode_fb_cmd (28)
drm_crtc     equ drmbuf + 5120       ; drm_mode_crtc (104, embeds the modeinfo)
drm_connid   equ drmbuf + 5224       ; the single connector id passed to SETCRTC (u32)
drmsize  equ 0x10000                 ; 64 KiB
margin   equ 0x4100000               ; 65 MiB: covers the largest single allocation
                                     ; (read_file's 64 MiB read + descriptor); the
                                     ; dispatch loop collects this far before a
                                     ; semispace end, and halts if still short after
