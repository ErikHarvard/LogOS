; ===================================================================
;  LogOS kernel — K2: IDT + exception handlers (loud faults on the metal)
;
;  %include'd into boot.asm (uses its serial_putc and DBG_EXIT). Turns a
;  CPU exception from a silent triple-fault reboot into a DIAGNOSED serial
;  halt — the loud-failure discipline (b_τ ≡ f_τ) at ring 0.
;
;  Exposes idt_install (call in the trampoline before jumping to the LA
;  image). Vectors 0..31 get stubs -> isr_common -> serial diagnostic
;  "EXCEPTION <vec> err=<code> rip=<rip>" -> isa-debug-exit FAIL (0x11 ->
;  QEMU exit 35, distinct from K1 success 0x10 -> 33) -> hlt.
; ===================================================================

IDT_FAIL equ 0x11               ; fault exit code (QEMU: (0x11<<1)|1 = 35)

; ---- ISR stubs: normalize the interrupt frame ----
; CPU pushes (for these vectors) an error code: 8,10,11,12,13,14,17,21,29,30.
; The rest push none -> stub pushes a 0 placeholder so isr_common sees a
; uniform frame: [rsp]=vector, [rsp+8]=errcode, [rsp+16]=rip, +24=cs,
; +32=rflags, +40=rsp, +48=ss.
section .boot32
bits 64

%macro ISR_NOERR 1
isr%1:
    push    qword 0             ; dummy error code
    push    qword %1            ; vector
    jmp     isr_common
%endmacro

%macro ISR_ERR 1
isr%1:
    push    qword %1            ; vector (CPU already pushed the error code)
    jmp     isr_common
%endmacro

ISR_NOERR 0
ISR_NOERR 1
ISR_NOERR 2
ISR_NOERR 3
ISR_NOERR 4
ISR_NOERR 5
ISR_NOERR 6
ISR_NOERR 7
ISR_ERR   8
ISR_NOERR 9
ISR_ERR   10
ISR_ERR   11
ISR_ERR   12
ISR_ERR   13
ISR_ERR   14
ISR_NOERR 15
ISR_NOERR 16
ISR_ERR   17
ISR_NOERR 18
ISR_NOERR 19
ISR_NOERR 20
ISR_ERR   21
ISR_NOERR 22
ISR_NOERR 23
ISR_NOERR 24
ISR_NOERR 25
ISR_NOERR 26
ISR_NOERR 27
ISR_NOERR 28
ISR_ERR   29
ISR_ERR   30
ISR_NOERR 31

; ---- common handler: print the fault, then halt loudly ----
isr_common:
    mov     rsi, exc_msg        ; "EXCEPTION "
    call    serial_puts
    mov     rax, [rsp + 0]      ; vector
    call    print_hex8
    mov     rsi, err_msg        ; " err="
    call    serial_puts
    mov     rax, [rsp + 8]      ; error code
    call    print_hex64
    mov     rsi, rip_msg        ; " rip="
    call    serial_puts
    mov     rax, [rsp + 16]     ; faulting rip
    call    print_hex64
    mov     rsi, nl_msg
    call    serial_puts

    mov     al, IDT_FAIL        ; loud halt: distinct failure exit code
    mov     dx, DBG_EXIT
    out     dx, al
    cli
.hang:
    hlt
    jmp     .hang

; serial_puts(rsi = NUL-terminated string) -> serial_putc each byte
serial_puts:
    push    rax
.next:
    mov     al, [rsi]
    test    al, al
    jz      .done
    mov     dil, al
    call    serial_putc
    inc     rsi
    jmp     .next
.done:
    pop     rax
    ret

; print_hex64(rax) — 16 hex digits, high nibble first
print_hex64:
    push    rbx
    push    rcx
    mov     rbx, rax
    mov     rcx, 16
.loop:
    rol     rbx, 4              ; bring next nibble (high first) to low 4 bits
    mov     al, bl
    and     al, 0x0F
    cmp     al, 10
    jb      .digit
    add     al, 'a' - 10
    jmp     .emit
.digit:
    add     al, '0'
.emit:
    mov     dil, al
    call    serial_putc
    dec     rcx
    jnz     .loop
    pop     rcx
    pop     rbx
    ret

; print_hex8(rax) — low byte as 2 hex digits
print_hex8:
    shl     rax, 56             ; move low byte to the top so rol brings it out
    push    rbx
    push    rcx
    mov     rbx, rax
    mov     rcx, 2
.loop8:
    rol     rbx, 4
    mov     al, bl
    and     al, 0x0F
    cmp     al, 10
    jb      .d8
    add     al, 'a' - 10
    jmp     .e8
.d8:
    add     al, '0'
.e8:
    mov     dil, al
    call    serial_putc
    dec     rcx
    jnz     .loop8
    pop     rcx
    pop     rbx
    ret

; idt_install — fill IDT entries 0..31 from isr_table, then lidt.
; 64-bit gate: [offlo16][sel16][ist8|type8][offmid16][offhi32][rsvd32], 16 B.
; type 0x8E = present, DPL 0, 64-bit interrupt gate; selector 0x08 (kernel code).
idt_install:
    mov     rdi, idt            ; entry pointer
    mov     rsi, isr_table      ; handler-address table
    mov     rcx, 32             ; vectors 0..31
.fill:
    mov     rax, [rsi]          ; handler address
    mov     word [rdi + 0], ax  ; offset[15:0]
    mov     word [rdi + 2], 0x08; selector
    mov     word [rdi + 4], 0x8E00 ; ist=0, type/attr=0x8E
    shr     rax, 16
    mov     word [rdi + 6], ax  ; offset[31:16]
    shr     rax, 16
    mov     dword [rdi + 8], eax; offset[63:32]
    mov     dword [rdi + 12], 0 ; reserved
    add     rdi, 16
    add     rsi, 8
    dec     rcx
    jnz     .fill
    lidt    [idt_ptr]
    ret

section .rodata
exc_msg: db "EXCEPTION ", 0
err_msg: db " err=", 0
rip_msg: db " rip=", 0
nl_msg:  db 10, 0
align 8
isr_table:
    dq isr0,  isr1,  isr2,  isr3,  isr4,  isr5,  isr6,  isr7
    dq isr8,  isr9,  isr10, isr11, isr12, isr13, isr14, isr15
    dq isr16, isr17, isr18, isr19, isr20, isr21, isr22, isr23
    dq isr24, isr25, isr26, isr27, isr28, isr29, isr30, isr31
idt_ptr:
    dw 256 * 16 - 1             ; limit
    dq idt                     ; base

section .bss
align 16
idt:
    resb 256 * 16              ; 256 gate descriptors (0..31 filled; rest 0)
