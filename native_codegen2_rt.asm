; ═══════════════════════════════════════════════════════════════════
;  native_codegen2_rt.asm — Native x86-64 backend, STAGE 2 runtime blob:
;  closures & environments. The callable runtime that native_codegen2.la-
;  emitted programs link against (the accepted "physics" seed).
;
;  Uniform boxed-value ABI (untyped lambda calculus needs runtime tags):
;    value = ptr to [tag(8)][payload(8)]
;      tag 0 STR : payload -> descriptor [len(8)][dataptr(8)]   (8-byte GC-fwd hdr before it)
;      tag 2 CLO : payload -> closure record [codeptr(8)][env(8)]
;      tag 4 INT : payload  = signed 64-bit integer (direct)
;    env frame = [value(8)][parent(8)]; empty env = 0
;    rbx = current env (callee-saved by every code block), r15 = heap bump,
;    rax = value result.
;
;  Code block (a compiled lambda body) calling convention:
;    enter: rdi = env (innermost frame = [arg][captured_env])
;    exit : rax = result value
;    shape: push rbx ; mov rbx,rdi ; <body -> rax> ; pop rbx ; ret
;  Builtins: binary rt_X(rsi=boxA, rax=boxB)->rax ; unary rt_X(rax=boxA)->rax.
;  Comparisons return the canonical TRUE/FALSE closure values (built by rt_init).
;
;  Tightly packed from org 0x400078 (after a 64-byte ELF header + 56-byte phdr).
;  The codegen bakes each routine's absolute entry address as a constant (the
;  addresses, derived from `nm` on the elf64 build, are the RT_* glyphs in
;  native_codegen2.la — kept in lockstep with these bytes by the build.sh drift
;  guard, which checks the embedded runtime == nasm -f bin native_codegen2_rt.asm).
;  nasm -f bin bytes are embedded verbatim in native_codegen2.la.
;  secd.asm / nativert.asm / native_codegen_rt.asm are all UNTOUCHED (additive).
; ═══════════════════════════════════════════════════════════════════

BITS 64
org 0x400078

; ── slot 0: rt_box_int(rax=int) -> rax = boxed INT ──
rt_box_int:
    mov     rdx, r15
    mov     qword [r15], 4
    mov     [r15+8], rax
    add     r15, 16
    mov     rax, rdx
    ret

; ── slot 1: rt_box_str(rsi=descriptor) -> rax = boxed STR ──
rt_box_str:
    mov     rax, r15
    mov     qword [r15], 0
    mov     [r15+8], rsi
    add     r15, 16
    ret

; ── slot 2: rt_mkclo(r10=codeaddr) -> rax = boxed CLO capturing rbx as env ──
rt_mkclo:
    mov     rdx, r15            ; clorec
    mov     [r15], r10          ; codeptr
    mov     [r15+8], rbx        ; captured env
    add     r15, 16
    mov     rax, r15            ; box
    mov     qword [r15], 2
    mov     [r15+8], rdx
    add     r15, 16
    ret

; ── slot 3: rt_apply(r10=func value, r11=arg value) -> rax (tail-jumps body) ──
rt_apply:
    cmp     qword [r10], 2
    jne     .bad
    mov     rcx, [r10+8]        ; clorec
    mov     rax, r15            ; new env frame [arg][cloenv]
    mov     [r15], r11
    mov     rdx, [rcx+8]
    mov     [r15+8], rdx
    add     r15, 16
    mov     rdi, rax
    jmp     [rcx]               ; tail into body; its ret returns to our caller
.bad:
    mov     rax, 60
    mov     rdi, 70             ; exit 70 = applied a non-function
    syscall

; ── slot 4: rt_print(rax=value) -> writes value + newline; preserves rax ──
rt_print:
    push    rax
    mov     rcx, [rax]
    test    rcx, rcx            ; tag 0 = STR
    jz      .str
    mov     rax, [rax+8]        ; INT payload
    mov     rsi, numend
    xor     r8, r8
    test    rax, rax
    jns     .pos
    mov     r8, 1
    neg     rax
.pos:
    test    rax, rax
    jnz     .loop
    dec     rsi
    mov     byte [rsi], '0'
    jmp     .sign
.loop:
    test    rax, rax
    jz      .sign
    xor     rdx, rdx
    mov     rcx, 10
    div     rcx
    add     dl, '0'
    dec     rsi
    mov     [rsi], dl
    jmp     .loop
.sign:
    test    r8, r8
    jz      .wr
    dec     rsi
    mov     byte [rsi], '-'
.wr:
    mov     rdx, numend
    sub     rdx, rsi
    mov     rax, 1
    mov     rdi, 1
    syscall
    jmp     .nl
.str:
    mov     rcx, [rax+8]        ; descriptor
    mov     rsi, [rcx+8]
    mov     rdx, [rcx]
    mov     rax, 1
    mov     rdi, 1
    syscall
.nl:
    mov     rax, 1
    mov     rdi, 1
    mov     rsi, nl
    mov     rdx, 1
    syscall
    pop     rax
    ret

; ── slot 5: rt_add(rsi=A, rax=B) -> boxed INT A+B ──
rt_add:
    mov     rcx, [rsi+8]
    add     rcx, [rax+8]
    mov     rax, rcx
    jmp     rt_box_int

; ── slot 6: rt_sub -> A-B ──
rt_sub:
    mov     rcx, [rsi+8]
    sub     rcx, [rax+8]
    mov     rax, rcx
    jmp     rt_box_int

; ── slot 7: rt_mul -> A*B ──
rt_mul:
    mov     rcx, [rsi+8]
    imul    rcx, [rax+8]
    mov     rax, rcx
    jmp     rt_box_int

; ── slot 8: rt_div -> A/B (signed) ──
rt_div:
    mov     rcx, [rax+8]        ; B
    mov     rax, [rsi+8]        ; A
    cqo
    idiv    rcx
    jmp     rt_box_int

; ── slot 9: rt_mod -> A%B (signed) ──
rt_mod:
    mov     rcx, [rax+8]
    mov     rax, [rsi+8]
    cqo
    idiv    rcx
    mov     rax, rdx
    jmp     rt_box_int

; ── slot 10: rt_int_eq(A,B) -> TRUE/FALSE value ──
rt_int_eq:
    mov     rcx, [rsi+8]
    cmp     rcx, [rax+8]
    jne     .f
    mov     rax, [TRUEVAL]
    ret
.f:
    mov     rax, [FALSEVAL]
    ret

; ── slot 11: rt_lt(A,B) -> TRUE if A<B ──
rt_lt:
    mov     rcx, [rsi+8]
    cmp     rcx, [rax+8]
    jl      .t
    mov     rax, [FALSEVAL]
    ret
.t:
    mov     rax, [TRUEVAL]
    ret

; ── slot 12: rt_str_eq(A,B) -> TRUE/FALSE value ──
rt_str_eq:
    mov     r8, [rsi+8]         ; descA
    mov     r9, [rax+8]         ; descB
    mov     rcx, [r8]           ; lenA
    cmp     rcx, [r9]
    jne     .f
    mov     r8, [r8+8]          ; ptrA
    mov     r9, [r9+8]          ; ptrB
    xor     rdx, rdx
.cmp:
    cmp     rdx, rcx
    jae     .t
    mov     al, [r8+rdx]
    cmp     al, [r9+rdx]
    jne     .f
    inc     rdx
    jmp     .cmp
.t:
    mov     rax, [TRUEVAL]
    ret
.f:
    mov     rax, [FALSEVAL]
    ret

; ── slot 13: rt_concat(A,B) -> boxed STR A++B ──
rt_concat:
    mov     r8, [rsi+8]         ; descA
    mov     r9, [rax+8]         ; descB
    mov     rax, r15            ; new blob ptr
    mov     rcx, [r8]           ; lenA
    mov     r10, [r8+8]         ; ptrA
    xor     rdx, rdx
.ca:
    cmp     rdx, rcx
    jae     .ad
    mov     r11b, [r10+rdx]
    mov     [r15+rdx], r11b
    inc     rdx
    jmp     .ca
.ad:
    add     r15, rcx
    mov     rsi, [r9]           ; lenB
    mov     r10, [r9+8]         ; ptrB
    xor     rdx, rdx
.cb:
    cmp     rdx, rsi
    jae     .bd
    mov     r11b, [r10+rdx]
    mov     [r15+rdx], r11b
    inc     rdx
    jmp     .cb
.bd:
    add     r15, rsi
    mov     rcx, [r8]
    add     rcx, [r9]           ; total len
    mov     qword [r15], 0      ; GC hdr
    add     r15, 8
    mov     rdx, r15            ; descriptor
    mov     [r15], rcx
    mov     [r15+8], rax
    add     r15, 16
    mov     rax, r15            ; box STR
    mov     qword [r15], 0
    mov     [r15+8], rdx
    add     r15, 16
    ret

; ── slot 14: rt_str_head(rax=STR) -> boxed STR (first byte or empty) ──
rt_str_head:
    mov     rcx, [rax+8]        ; desc
    mov     rdx, [rcx]          ; len
    test    rdx, rdx
    jz      .empty
    mov     rsi, [rcx+8]
    mov     rdx, 1
    jmp     rt_make_str
.empty:
    mov     rsi, rcx
    xor     rdx, rdx
    jmp     rt_make_str

; ── slot 15: rt_str_tail(rax=STR) -> boxed STR (rest or empty) ──
rt_str_tail:
    mov     rcx, [rax+8]
    mov     rdx, [rcx]
    test    rdx, rdx
    jz      .empty
    mov     rsi, [rcx+8]
    inc     rsi
    dec     rdx
    jmp     rt_make_str
.empty:
    mov     rsi, rcx
    xor     rdx, rdx
    jmp     rt_make_str

; ── slot 16: rt_int_to_str(rax=INT) -> boxed STR decimal ──
rt_int_to_str:
    mov     rax, [rax+8]
    mov     rsi, numend
    xor     r8, r8
    test    rax, rax
    jns     .pos
    mov     r8, 1
    neg     rax
.pos:
    test    rax, rax
    jnz     .loop
    dec     rsi
    mov     byte [rsi], '0'
    jmp     .sign
.loop:
    test    rax, rax
    jz      .sign
    xor     rdx, rdx
    mov     rcx, 10
    div     rcx
    add     dl, '0'
    dec     rsi
    mov     [rsi], dl
    jmp     .loop
.sign:
    test    r8, r8
    jz      .mk
    dec     rsi
    mov     byte [rsi], '-'
.mk:
    mov     rdx, numend
    sub     rdx, rsi
    jmp     rt_make_str

; ── slot 17: rt_str_to_int(rax=STR) -> boxed INT (decimal, optional '-') ──
rt_str_to_int:
    mov     rcx, [rax+8]        ; desc
    mov     rsi, [rcx+8]        ; ptr
    mov     rdx, [rcx]          ; len
    xor     rax, rax            ; acc
    xor     r8, r8              ; i
    xor     r9, r9              ; neg flag
    test    rdx, rdx
    jz      .done
    cmp     byte [rsi], '-'
    jne     .digits
    mov     r9, 1
    inc     r8
.digits:
    cmp     r8, rdx
    jae     .done
    movzx   r10, byte [rsi+r8]
    sub     r10, '0'
    imul    rax, rax, 10
    add     rax, r10
    inc     r8
    jmp     .digits
.done:
    test    r9, r9
    jz      .pos
    neg     rax
.pos:
    jmp     rt_box_int

; ── slot 18: rt_make_str(rsi=src, rdx=len) -> rax = boxed STR ──
rt_make_str:
    mov     rax, r15            ; blob
    xor     r10, r10
.cp:
    cmp     r10, rdx
    jae     .d
    mov     r11b, [rsi+r10]
    mov     [r15+r10], r11b
    inc     r10
    jmp     .cp
.d:
    add     r15, rdx
    mov     qword [r15], 0      ; GC hdr
    add     r15, 8
    mov     r8, r15             ; descriptor
    mov     [r15], rdx
    mov     [r15+8], rax
    add     r15, 16
    mov     rax, r15            ; box STR
    mov     qword [r15], 0
    mov     [r15+8], r8
    add     r15, 16
    ret

; ── slot 19: true_outer = la t. (la f. t) ──
true_outer:
    push    rbx
    mov     rbx, rdi
    mov     r10, true_inner
    call    rt_mkclo
    pop     rbx
    ret

; ── slot 20: true_inner = la f. t  (var index 1) ──
true_inner:
    push    rbx
    mov     rbx, rdi
    mov     rax, [rbx+8]
    mov     rax, [rax]
    pop     rbx
    ret

; ── slot 21: false_outer = la t. (la f. f) ──
false_outer:
    push    rbx
    mov     rbx, rdi
    mov     r10, false_inner
    call    rt_mkclo
    pop     rbx
    ret

; ── slot 22: false_inner = la f. f  (var index 0) ──
false_inner:
    push    rbx
    mov     rbx, rdi
    mov     rax, [rbx]
    pop     rbx
    ret

; ── slot 23: rt_init -> build canonical TRUE/FALSE values (empty env) ──
rt_init:
    xor     rbx, rbx
    mov     r10, true_outer
    call    rt_mkclo
    mov     [TRUEVAL], rax
    mov     r10, false_outer
    call    rt_mkclo
    mov     [FALSEVAL], rax
    ret

; ── slot 24: data area (RWX, writable) @ 0x401878 ──
TRUEVAL:  dq 0
FALSEVAL: dq 0
nl:       db 10
numbuf:   times 40 db 0
numend:   equ numbuf + 40
