; ═══════════════════════════════════════════════════════════════════
;  runtime.asm — the LA-native x86-64 runtime (the marked silicon seam)
;
;  Carved from secd.asm. In the native model there is NO bytecode dispatch
;  loop: an LA program is compiled (by the pure-LA backend, ncodegen.la) to
;  native code that CALLs the rt_* entry points below. This file is the one
;  irreducible x86-64 seam — heap, copying GC, and the builtins — that the
;  emitted program links against, exactly as NEXT_STEPS frames it: "the
;  backend itself must be pure LA; only what it emits conforms to x86-64."
;
;  STAGE 0, increment 1 (this file): the print pipeline only —
;    rt_push_bi, rt_push_str, rt_apply (BI: print / exit). Proves the
;    emit→link→run spine with no interpreter. Grown toward full Stage 0
;    (rt_close, CLO apply + TCO, the 58 builtins, native Church bodies, GC,
;    the shadow E-root stack) in subsequent increments, reusing secd.asm.
;
;  ABI (the seam contract):
;    r12 = operand stack S   (push +16; value = [tag(8)][payload(8)])
;    r13 = environment E     r14 = shadow E-root stack   r15 = heap bump ptr
;    rsp = native control stack (C; the SECD dump's control half)
;    Every rt_* and builtin PRESERVES r12-r15; clobbers rax-r11. Emitted code
;    holds NO live value in rax-r11 across an rt_* call (all state on S/E/heap).
;    Value tags: 0 STR [len][ptr] | 1 BI id | 2 CLO [param][body][env] |
;                3 PA [id][a1tag][a1payload] | 4 INT (payload = the integer)
;
;  Build:  nasm -f bin runtime.asm -o runtime
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
    dd 7                         ; RWX: heap/stacks are writable, progbuf executable
    dq 0
    dq 0x400000
    dq 0x400000
    dq filesize
    dq heapend - $$             ; p_memsz: map code + S/E stacks + the (small) heap
    dq 0x1000

; ── desc_atoi(rdi = STR descriptor) → rax  (verbatim from secd.asm:134) ──
desc_atoi:
    mov     rcx, [rdi]
    mov     rsi, [rdi+8]
    xor     rax, rax
    xor     r10, r10
    test    rcx, rcx
    je      .da_done
    cmp     byte [rsi], 45              ; '-'
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

; ── _start: set up the machine registers, run the program, exit ──
;  The emitted program's entry is its first glyph block (MAIN). For this
;  increment the program is the inline PROGRAM block below; a later increment
;  loads bundled emitted code into progbuf and `call`s that instead.
_start:
    mov     r12, ostack
    xor     r13, r13
    mov     r14, dstack
    mov     r15, heap
    call    PROGRAM
    mov     rax, 60                     ; exit(0)
    xor     rdi, rdi
    syscall

; ── rt_push_str(rsi = bytes ptr, rdx = len): push a STR value ──
;  (secd.asm:.pushs, less the bytecode scan — literal bytes live in the
;  program's data section, so ptr+len arrive in registers.)
rt_push_str:
    mov     qword [r15], 0              ; GC forwarding header (not forwarded)
    add     r15, 8
    mov     [r15], rdx                  ; descriptor [len][ptr]
    mov     [r15+8], rsi
    mov     qword [r12], 0              ; tag STR
    mov     [r12+8], r15
    add     r12, 16
    add     r15, 16
    ret

; ── rt_push_bi(rdi = builtin id): push a BI value ──
;  Builtin names are resolved to ids by the backend at compile time, so no
;  runtime name lookup is needed (the secd.asm strcmp chain disappears).
rt_push_bi:
    mov     qword [r12], 1              ; tag BI
    mov     [r12+8], rdi
    add     r12, 16
    ret

; ── rt_apply: pop arg (top of S) and fn (below), dispatch ──
;  In APP(f)(a) the backend emits code(f) then code(a), so on S the function
;  is below and the argument on top (matches secd.asm:955-961 pop order).
;  This increment handles the BI case only; CLO (native call/TCO) and PA come
;  with Stage 2.
rt_apply:
    sub     r12, 16
    mov     r8, [r12]                   ; arg tag
    mov     r9, [r12+8]                 ; arg payload
    sub     r12, 16
    mov     r10, [r12]                  ; fn tag
    mov     r11, [r12+8]                ; fn payload
    cmp     r10, 1                      ; BI?
    je      .bi
    jmp     rt_notfunc                  ; CLO/PA not yet handled → loud halt
.bi:
    cmp     r11, 0                      ; print
    je      rt_bi_print
    cmp     r11, 18                     ; exit
    je      rt_bi_exit
    jmp     rt_notfunc                  ; other builtins land here until carved

; ── print (STR path; returns its argument on S, then ret to caller) ──
rt_bi_print:
    test    r8, r8                      ; STR (tag 0)?
    jnz     rt_strtype                  ; (INT coercion added with the int builtins)
    mov     rsi, [r9+8]
    mov     rdx, [r9]
    mov     rax, 1                      ; write(1, bytes, len)
    mov     rdi, 1
    syscall
    mov     rax, 1                      ; write(1, newline, 1)
    mov     rdi, 1
    mov     rsi, newline
    mov     rdx, 1
    syscall
    mov     [r12], r8                   ; print returns its argument value
    mov     [r12+8], r9
    add     r12, 16
    ret

; ── exit(code): code is a decimal STR (secd.asm:.bi_exit) ──
rt_bi_exit:
    test    r8, r8
    jnz     rt_strtype
    mov     rdi, r9
    call    desc_atoi
    mov     rdi, rax
    mov     rax, 60
    syscall

; ── loud-failure guards (non-zero exit, diagnostic on stderr) ──
rt_notfunc:
    mov     rax, 1
    mov     rdi, 2
    mov     rsi, nfmsg
    mov     rdx, nfmsg_len
    syscall
    mov     rax, 60
    mov     rdi, 1
    syscall
rt_strtype:
    mov     rax, 1
    mov     rdi, 2
    mov     rsi, stmsg
    mov     rdx, stmsg_len
    syscall
    mov     rax, 60
    mov     rdi, 1
    syscall

; ── PROGRAM: the hand-written native compilation of `print("I AM THAT I AM")`
;    — the Stage 0 liveness probe. Stage 1's ncodegen.la emits exactly this
;    shape: code(print) ; code("I AM…") ; rt_apply. ──
PROGRAM:
    mov     rdi, 0                      ; code(print): push BI 0 (the function)
    call    rt_push_bi
    mov     rsi, themsg                 ; code("I AM…"): push the STR (the argument)
    mov     rdx, themsg_len
    call    rt_push_str
    call    rt_apply                    ; apply print to the string
    ret

; ── data ──
newline:    db 10
themsg:     db "I AM THAT I AM"
themsg_len  equ $ - themsg
nfmsg:      db "secd: attempt to apply a non-function", 10
nfmsg_len   equ $ - nfmsg
stmsg:      db "secd: argument is not a string", 10
stmsg_len   equ $ - stmsg

; ── memory map (above filesize; lazily zero-filled within p_memsz) ──
filesize equ $ - $$
ostack   equ $$ + filesize            ; operand stack S
dstack   equ ostack + 0x100000        ; shadow E-root stack (1 MiB)
heap     equ dstack + 0x100000        ; heap bump region
heapend  equ heap   + 0x100000        ; (1 MiB — ample for the print probe)
