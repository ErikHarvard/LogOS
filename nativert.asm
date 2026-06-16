; ═══════════════════════════════════════════════════════════════════
;  nativert.asm — Native x86-64 backend, STAGE 0: the carved runtime,
;  proven independently usable OUTSIDE the SECD dispatch loop.
;
;  A self-contained `nasm -f bin` ELF (the same shape as secd.asm). The
;  runtime routines are CALLABLE (ret-terminated) — not reached by the
;  interpreter's name-dispatch. _start uses them to speak the Word, so a
;  native program runs on the runtime with no per-instruction dispatch.
;
;  ABI — byte-identical to secd.asm (so this runtime is mergeable with it):
;    value  = [tag(8)][payload(8)]
;    STR    = tag 0, payload -> descriptor [len(8)][dataptr(8)], the
;             descriptor preceded by an 8-byte STRDESC GC-fwd header (=0)
;    heap   = bump pointer in r15 (zero-filled PT_LOAD tail, memsz>filesz)
;  rt_make_str / rt_print are the .bi_print STR path + the strhead-style
;  STRDESC allocation from secd.asm, lifted verbatim into call/ret form.
;
;  Stage-0 scope: runtime + a hand-written native test using it. NOT a
;  glyph->native compiler (that is Stage 1). secd.asm is untouched, so the
;  existing 128 build checks cannot regress.
; ═══════════════════════════════════════════════════════════════════

BITS 64
org 0x400000

ehdr:
    db 0x7F, "ELF", 2, 1, 1, 0
    times 8 db 0
    dw 2                    ; ET_EXEC
    dw 0x3E                 ; x86-64
    dd 1
    dq _start               ; entry
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
    dd 1                    ; PT_LOAD
    dd 7                    ; RWX (data heap needs W; code needs X)
    dq 0
    dq 0x400000
    dq 0x400000
    dq filesize             ; p_filesz
    dq heap - $$ + 0x10000  ; p_memsz: file content + a 64 KiB zero-filled heap
    dq 0x1000

; ── rt_make_str(rsi = src ptr, rdx = len) → r8 = tag 0 (STR), r9 = descriptor ──
;   Allocates a raw DATA blob (the bytes) then a STRDESC [gc_hdr=0][len][ptr],
;   exactly as secd.asm's str builtins do. r9 points at [len]; [r9-8] is the
;   GC header. Clobbers rax, r10, r11; bumps r15.
rt_make_str:
    mov     rax, r15            ; rax = data-blob ptr
    xor     r10, r10            ; i = 0
.copy:
    cmp     r10, rdx
    jae     .blob_done
    mov     r11b, [rsi+r10]
    mov     [r15+r10], r11b
    inc     r10
    jmp     .copy
.blob_done:
    add     r15, rdx            ; advance past the data blob
    mov     qword [r15], 0      ; STRDESC GC fwd header
    add     r15, 8
    mov     r9, r15             ; r9 = descriptor (points at [len])
    mov     [r15], rdx          ; [len]
    mov     [r15+8], rax        ; [ptr] -> the data blob
    add     r15, 16
    xor     r8, r8              ; tag 0 = STR
    ret

; ── rt_print(r8 = tag, r9 = STR descriptor) → write the bytes + newline ──
;   The .bi_print STR path from secd.asm, in call/ret form. Stage-0: STR only.
rt_print:
    mov     rsi, [r9+8]         ; ptr
    mov     rdx, [r9]           ; len
    mov     rax, 1              ; write
    mov     rdi, 1              ; stdout
    syscall
    mov     rax, 1
    mov     rdi, 1
    mov     rsi, nl
    mov     rdx, 1
    syscall
    ret

; ── data (read by the runtime; sits in the R+X+W segment) ──
word_msg: db "I AM THAT I AM"
word_end:
nl:       db 10

; ── entry: build a STR value on the heap via the runtime, print it ──
_start:
    mov     r15, heap                  ; heap bump pointer
    mov     rsi, word_msg
    mov     rdx, word_end - word_msg
    call    rt_make_str                ; r8=tag, r9=descriptor for the Word
    call    rt_print
    mov     rax, 60                    ; exit
    xor     rdi, rdi
    syscall

filesize: equ $ - $$
align 16
heap:
