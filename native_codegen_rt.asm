; ═══════════════════════════════════════════════════════════════════
;  native_codegen_rt.asm — Native x86-64 backend, STAGE 1 runtime blob.
;
;  The fixed, callable runtime that `native_codegen.la`-emitted programs
;  LINK against (the accepted "physics" seed — only the runtime is asm).
;  It is the Stage-0 carve (rt_make_str / rt_print) extended with the few
;  routines minimal native execution needs: print-int, concat, int->str.
;
;  This is a RUNTIME-ONLY blob — no ELF header, no _start. `nasm -f bin`
;  emits exactly these bytes; native_codegen.la embeds them verbatim and
;  prepends an ELF header + per-program generated code. A build.sh drift
;  guard checks the embedded bytes equal this file's nasm output.
;
;  LAYOUT: org 0x400078 (immediately after a 64-byte ELF header + 56-byte
;  program header). Each routine is padded to a fixed 256-byte slot so its
;  absolute entry address is a constant the codegen can bake in:
;    rt_make_str    @ 0x400078   rt_print_str  @ 0x400178
;    rt_concat      @ 0x400278   rt_print_int  @ 0x400378
;    rt_int_to_str  @ 0x400478   data (nl/num) @ 0x400578
;
;  ABI — byte-identical to secd.asm / nativert.asm:
;    STR value flows as a pointer to a descriptor [len(8)][dataptr(8)],
;    the descriptor preceded by an 8-byte STRDESC GC-fwd header (=0).
;    INT value flows as a raw signed 64-bit integer.
;    heap = bump pointer in r15. Routines preserve r12-r15/rbp/rsp.
; ═══════════════════════════════════════════════════════════════════

BITS 64
org 0x400078

; ── rt_make_str(rsi=src, rdx=len) → r9 = descriptor ([len],[ptr]) ──
;   Verbatim from nativert.asm: a raw DATA blob then a STRDESC.
rt_make_str:
    mov     rax, r15
    xor     r10, r10
.cp:
    cmp     r10, rdx
    jae     .done
    mov     r11b, [rsi+r10]
    mov     [r15+r10], r11b
    inc     r10
    jmp     .cp
.done:
    add     r15, rdx
    mov     qword [r15], 0          ; STRDESC GC fwd header
    add     r15, 8
    mov     r9, r15                 ; r9 -> [len]
    mov     [r15], rdx
    mov     [r15+8], rax            ; -> data blob
    add     r15, 16
    ret
times 256-($-rt_make_str) db 0

; ── rt_print_str(rax=descriptor) → write bytes + newline; preserves rax ──
rt_print_str:
    push    rax
    mov     rsi, [rax+8]            ; data ptr
    mov     rdx, [rax]              ; len
    mov     rax, 1
    mov     rdi, 1
    syscall
    mov     rax, 1
    mov     rdi, 1
    mov     rsi, nlbyte
    mov     rdx, 1
    syscall
    pop     rax
    ret
times 256-($-rt_print_str) db 0

; ── rt_concat(rsi=descA, rdi=descB) → r9 = descriptor of A++B ──
rt_concat:
    mov     rax, r15               ; rax = new data blob ptr
    mov     rcx, [rsi]             ; lenA
    mov     r10, [rsi+8]           ; ptrA
    xor     r8, r8
.ca:
    cmp     r8, rcx
    jae     .ad
    mov     r11b, [r10+r8]
    mov     [r15+r8], r11b
    inc     r8
    jmp     .ca
.ad:
    add     r15, rcx               ; advance by lenA
    mov     rdx, [rdi]            ; lenB
    mov     r10, [rdi+8]         ; ptrB
    xor     r8, r8
.cb:
    cmp     r8, rdx
    jae     .bd
    mov     r11b, [r10+r8]
    mov     [r15+r8], r11b
    inc     r8
    jmp     .cb
.bd:
    add     r15, rdx               ; advance by lenB
    mov     rcx, [rsi]
    add     rcx, [rdi]             ; total len = lenA+lenB
    mov     qword [r15], 0         ; STRDESC GC fwd header
    add     r15, 8
    mov     r9, r15
    mov     [r15], rcx
    mov     [r15+8], rax
    add     r15, 16
    ret
times 256-($-rt_concat) db 0

; ── rt_print_int(rax=signed int) → write decimal + newline; preserves rax ──
rt_print_int:
    push    rax
    mov     rsi, numend            ; fill numbuf backward from the end
    mov     rbx, 10
    xor     r8, r8                 ; negative flag
    test    rax, rax
    jns     .pos
    mov     r8, 1
    neg     rax
.pos:
    test    rax, rax
    jnz     .loop
    dec     rsi
    mov     byte [rsi], '0'
    jmp     .signdone
.loop:
    test    rax, rax
    jz      .signdone
    xor     rdx, rdx
    div     rbx
    add     dl, '0'
    dec     rsi
    mov     [rsi], dl
    jmp     .loop
.signdone:
    test    r8, r8
    jz      .write
    dec     rsi
    mov     byte [rsi], '-'
.write:
    mov     rdx, numend
    sub     rdx, rsi               ; length
    mov     rax, 1
    mov     rdi, 1
    syscall
    mov     rax, 1
    mov     rdi, 1
    mov     rsi, nlbyte
    mov     rdx, 1
    syscall
    pop     rax
    ret
times 256-($-rt_print_int) db 0

; ── rt_int_to_str(rax=signed int) → r9 = descriptor of decimal string ──
rt_int_to_str:
    mov     rsi, numend
    mov     rbx, 10
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
    jmp     .signdone
.loop:
    test    rax, rax
    jz      .signdone
    xor     rdx, rdx
    div     rbx
    add     dl, '0'
    dec     rsi
    mov     [rsi], dl
    jmp     .loop
.signdone:
    test    r8, r8
    jz      .mk
    dec     rsi
    mov     byte [rsi], '-'
.mk:
    mov     rdx, numend
    sub     rdx, rsi
    call    rt_make_str            ; rsi=start, rdx=len -> r9
    ret
times 256-($-rt_int_to_str) db 0

; ── data area @ 0x400578 (RWX segment, writable scratch) ──
nlbyte: db 10
numbuf: times 32 db 0
numend: equ numbuf + 32
