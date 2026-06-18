; ═══════════════════════════════════════════════════════════════════
;  native_codegen3_rt.asm — Native x86-64 backend, STAGE 3b runtime blob:
;  GC-ready heap. Forked from native_codegen2_rt.asm; the ONLY change in
;  sub-step 3b.1 is that every heap object now carries an 8-byte OBJECT
;  HEADER immediately before its body (the body layout — and therefore every
;  value/env/descriptor dereference — is byte-for-byte unchanged). This lays
;  the parseable-heap foundation the conservative mark-sweep collector
;  (3b.2/3b.3) walks; NO collector, NO ensure_heap yet — allocation is still a
;  pure r15 bump, so 3b.1 is behaviourally transparent (native==host).
;
;  Object header (one qword, sits at [body-8]):
;    bits  0..7  = KIND : 1 BOX  2 CLOREC  3 ENVFRAME  4 DESCRIPTOR  5 BLOB
;    bits  8..15 = MARK (0 = unmarked; the collector sets it)
;    bits 16..   = body byte SIZE (so a linear heap walk can step object→object;
;                  fixed kinds are 16, a BLOB carries its true length)
;  The returned pointer always points at the BODY (post-header), so the body
;  layouts are unchanged:
;    value = ptr to [tag(8)][payload(8)]
;      tag 0 STR : payload -> descriptor body [len(8)][dataptr(8)]
;      tag 2 CLO : payload -> closure record body [codeptr(8)][env(8)]
;      tag 4 INT : payload  = signed 64-bit integer (direct)
;    env frame body = [value(8)][parent(8)]; empty env = 0
;    rbx = current env (callee-saved), r15 = heap bump, rax = value result.
;
;  Code block calling convention, builtins, and every non-allocating routine
;  are IDENTICAL to native_codegen2_rt.asm — only the six allocators
;  (rt_box_int / rt_box_str / rt_mkclo / rt_apply env-frame / rt_make_str /
;  rt_concat) lay down a header. Inter-routine call/jmp are rel32 and the
;  data-global refs are label-derived, so reassembly self-adjusts; the codegen
;  re-derives the RT_* entry addresses + RTLEN + LITERAL_BASE from this file.
;
;  Tightly packed from org 0x400078. nasm -f bin bytes embedded verbatim in
;  native_codegen3.la; build.sh drift-guards embedded == nasm -f bin of THIS
;  file. secd.asm / nativert.asm / native_codegen_rt.asm / native_codegen2_rt.asm
;  are all UNTOUCHED (additive fork).
; ═══════════════════════════════════════════════════════════════════

BITS 64
org 0x400078

; header constants (kind | size<<16 ; mark bit 8 starts clear)
%define H_BOX    (1 | (16 << 16))
%define H_CLOREC (2 | (16 << 16))
%define H_ENV    (3 | (16 << 16))
%define H_DESC   (4 | (16 << 16))
%define K_BLOB   5
; 3b.2 dry-run GC: fires each GC_INTERVAL bytes of allocation (rt_apply trigger).
%define GC_INTERVAL 0x4000000   ; 64 MB
%define WL_SIZE     0x4000000   ; 64 MB worklist, carved from the front of the heap region
%define MARKBIT     0x100       ; header bit 8 (= byte 1) is the mark

; ── slot 0: rt_box_int(rax=int) -> rax = boxed INT ──
rt_box_int:
    mov     qword [r15], H_BOX  ; object header
    add     r15, 8
    mov     rdx, r15            ; body (the value)
    mov     qword [r15], 4
    mov     [r15+8], rax
    add     r15, 16
    mov     rax, rdx
    ret

; ── slot 1: rt_box_str(rsi=descriptor) -> rax = boxed STR ──
rt_box_str:
    mov     qword [r15], H_BOX
    add     r15, 8
    mov     rax, r15
    mov     qword [r15], 0
    mov     [r15+8], rsi
    add     r15, 16
    ret

; ── slot 2: rt_mkclo(r10=codeaddr) -> rax = boxed CLO capturing rbx as env ──
rt_mkclo:
    mov     qword [r15], H_CLOREC
    add     r15, 8
    mov     rdx, r15            ; clorec body
    mov     [r15], r10          ; codeptr
    mov     [r15+8], rbx        ; captured env
    add     r15, 16
    mov     qword [r15], H_BOX
    add     r15, 8
    mov     rax, r15            ; box body
    mov     qword [r15], 2
    mov     [r15+8], rdx
    add     r15, 16
    ret

; ── slot 3: rt_apply(r10=func value, r11=arg value) -> rax (tail-jumps body) ──
rt_apply:
    cmp     r15, [NEXT_GC]      ; 3b.2 dry-run GC trigger (periodic)
    jb      .nogc
    call    rt_gc
    mov     rax, [NEXT_GC]
    add     rax, GC_INTERVAL
    mov     [NEXT_GC], rax
.nogc:
    cmp     qword [r10], 2
    jne     .bad
    mov     rcx, [r10+8]        ; clorec body
    mov     qword [r15], H_ENV  ; env-frame header
    add     r15, 8
    mov     rax, r15            ; env body [arg][cloenv]
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
    mov     rcx, [r8]           ; lenA
    add     rcx, [r9]           ; total len = lenA+lenB
    mov     rdx, rcx            ; blob header = K_BLOB | len<<16
    shl     rdx, 16
    or      rdx, K_BLOB
    mov     [r15], rdx
    add     r15, 8
    mov     rax, r15            ; blob body ptr
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
    mov     qword [r15], H_DESC ; descriptor header
    add     r15, 8
    mov     rdx, r15            ; descriptor body
    mov     [r15], rcx
    mov     [r15+8], rax        ; -> blob body
    add     r15, 16
    mov     qword [r15], H_BOX  ; box header
    add     r15, 8
    mov     rax, r15            ; box body
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
    mov     r8, rdx             ; blob header = K_BLOB | len<<16
    shl     r8, 16
    or      r8, K_BLOB
    mov     [r15], r8
    add     r15, 8
    mov     rax, r15            ; blob body
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
    mov     qword [r15], H_DESC ; descriptor header
    add     r15, 8
    mov     r8, r15             ; descriptor body
    mov     [r15], rdx
    mov     [r15+8], rax
    add     r15, 16
    mov     qword [r15], H_BOX  ; box header
    add     r15, 8
    mov     rax, r15            ; box body
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

; ── rt_gc: 3b.2b DRY-RUN collection — conservative MARK + heap-walk (no reclaim).
;   Roots (the verified set): every GP register (saved to REGDUMP), TRUEVAL/
;   FALSEVAL, and the stack [rsp, STACK_BASE). A candidate counts as a root iff
;   it points into [HEAP_BASE+8, r15) at a valid object header (kind 1..5, body
;   within the frontier). .consider marks (header bit 8) + pushes to the
;   worklist; the drain loop traces children PRECISELY by kind (no native
;   recursion). Then a heap-walk counts the live (marked) set, clears the marks,
;   and verifies the frontier. Register-transparent (REGDUMP save/restore), so
;   the rt_apply trigger leaves func/arg (r10/r11) and env (rbx) intact.
rt_gc:
    mov     [REGDUMP+0],   rax
    mov     [REGDUMP+8],   rbx
    mov     [REGDUMP+16],  rcx
    mov     [REGDUMP+24],  rdx
    mov     [REGDUMP+32],  rsi
    mov     [REGDUMP+40],  rdi
    mov     [REGDUMP+48],  rbp
    mov     [REGDUMP+56],  r8
    mov     [REGDUMP+64],  r9
    mov     [REGDUMP+72],  r10
    mov     [REGDUMP+80],  r11
    mov     [REGDUMP+88],  r12
    mov     [REGDUMP+96],  r13
    mov     [REGDUMP+104], r14
    mov     [REGDUMP+112], r15
    mov     rbp, rsp                ; stack-scan lower bound (entry rsp)
    mov     r12, [WORKLIST_BASE]    ; wp
    ; --- root: GP registers (REGDUMP[0..14]) ---
    xor     r9, r9
.rgl:
    cmp     r9, 15
    jae     .rgd
    mov     rax, [REGDUMP + r9*8]
    call    .consider
    inc     r9
    jmp     .rgl
.rgd:
    ; --- root: canonical TRUE/FALSE ---
    mov     rax, [TRUEVAL]
    call    .consider
    mov     rax, [FALSEVAL]
    call    .consider
    ; --- root: stack [rbp, STACK_BASE) ---
.skl:
    cmp     rbp, [STACK_BASE]
    jae     .skd
    mov     rax, [rbp]
    call    .consider
    add     rbp, 8
    jmp     .skl
.skd:
    ; --- drain worklist: trace children by kind ---
.drain:
    cmp     r12, [WORKLIST_BASE]
    jbe     .drained
    sub     r12, 8
    mov     rdi, [r12]              ; popped body ptr
    mov     rdx, [rdi-8]
    and     rdx, 0xff              ; kind
    cmp     rdx, 1
    je      .tbox
    cmp     rdx, 2
    je      .tclo
    cmp     rdx, 3
    je      .tenv
    cmp     rdx, 4
    je      .tdesc
    jmp     .drain                 ; kind 5 BLOB: no children
.tbox:
    mov     rcx, [rdi]            ; box tag
    cmp     rcx, 4
    je      .drain                ; INT: payload is data, no children
    mov     rax, [rdi+8]          ; STR->desc / CLO->clorec
    call    .consider
    jmp     .drain
.tclo:
    mov     rax, [rdi+8]          ; env (codeptr at [rdi] is non-heap, skip)
    call    .consider
    jmp     .drain
.tenv:
    mov     rax, [rdi]            ; value
    call    .consider
    mov     rax, [rdi+8]          ; parent env
    call    .consider
    jmp     .drain
.tdesc:
    mov     rax, [rdi+8]          ; dataptr -> blob
    call    .consider
    jmp     .drain
.drained:
    ; --- heap-walk: count live (marked), clear marks, verify frontier ---
    mov     rsi, [HEAP_BASE]
    xor     r13, r13              ; live count
.walk:
    cmp     rsi, r15
    jae     .walked
    mov     rax, [rsi]            ; header
    test    rax, MARKBIT
    jz      .wsz
    inc     r13
    mov     byte [rsi+1], 0       ; clear mark
.wsz:
    shr     rax, 16               ; body size
    test    rax, rax
    jz      .desync
    lea     rsi, [rsi+rax+8]
    jmp     .walk
.walked:
    cmp     rsi, r15
    jne     .desync
    ; --- print live count + newline to stderr (fd 2) ---
    mov     rax, r13
    mov     rsi, numend
    dec     rsi
    mov     byte [rsi], 10
    test    rax, rax
    jnz     .lp
    dec     rsi
    mov     byte [rsi], '0'
    jmp     .pr
.lp:
    test    rax, rax
    jz      .pr
    xor     rdx, rdx
    mov     rcx, 10
    div     rcx
    add     dl, '0'
    dec     rsi
    mov     [rsi], dl
    jmp     .lp
.pr:
    mov     rdx, numend
    sub     rdx, rsi
    mov     rax, 1
    mov     rdi, 2
    syscall
    ; --- restore registers (transparent: no object moved, r15 unchanged) ---
    mov     rax, [REGDUMP+0]
    mov     rbx, [REGDUMP+8]
    mov     rcx, [REGDUMP+16]
    mov     rdx, [REGDUMP+24]
    mov     rsi, [REGDUMP+32]
    mov     rdi, [REGDUMP+40]
    mov     rbp, [REGDUMP+48]
    mov     r8,  [REGDUMP+56]
    mov     r9,  [REGDUMP+64]
    mov     r10, [REGDUMP+72]
    mov     r11, [REGDUMP+80]
    mov     r12, [REGDUMP+88]
    mov     r13, [REGDUMP+96]
    mov     r14, [REGDUMP+104]
    mov     r15, [REGDUMP+112]
    ret
; .consider(rax=candidate) -> mark+push if a valid unmarked object; clobbers rcx,rdx,r8,r12
.consider:
    mov     rcx, [HEAP_BASE]
    add     rcx, 8
    cmp     rax, rcx
    jb      .cret                 ; below HEAP_BASE+8
    cmp     rax, r15
    jae     .cret                 ; at/after the frontier
    mov     rdx, [rax-8]          ; header
    mov     rcx, rdx
    and     rcx, 0xff             ; kind
    test    rcx, rcx
    jz      .cret
    cmp     rcx, 5
    ja      .cret                 ; kind not in 1..5
    test    rdx, MARKBIT
    jnz     .cret                 ; already marked
    mov     rcx, rdx
    shr     rcx, 16               ; body size
    mov     r8, rax
    add     r8, rcx
    cmp     r8, r15
    ja      .cret                 ; body would exceed the frontier
    or      rdx, MARKBIT
    mov     [rax-8], rdx          ; set mark
    mov     rcx, [WORKLIST_BASE]
    add     rcx, WL_SIZE
    cmp     r12, rcx
    jae     .wlof                 ; worklist full
    mov     [r12], rax
    add     r12, 8
.cret:
    ret
.wlof:
    mov     rax, 1
    mov     rdi, 2
    mov     rsi, gcwl
    mov     rdx, gcwllen
    syscall
    mov     rax, 60
    mov     rdi, 72
    syscall
.desync:
    mov     rax, 1
    mov     rdi, 2
    mov     rsi, gcdesync
    mov     rdx, gcdesynclen
    syscall
    mov     rax, 60
    mov     rdi, 71
    syscall

; ── slot 24: data area (RWX, writable) ──
TRUEVAL:  dq 0
FALSEVAL: dq 0
HEAP_BASE: dq 0
NEXT_GC:   dq 0
STACK_BASE: dq 0
WORKLIST_BASE: dq 0
REGDUMP:  times 16 dq 0
nl:       db 10
gcdesync: db "native: heap walk desync", 10
gcdesynclen: equ $ - gcdesync
gcwl:     db "native: gc worklist overflow", 10
gcwllen:  equ $ - gcwl
numbuf:   times 40 db 0
numend:   equ numbuf + 40
