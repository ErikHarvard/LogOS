; ===================================================================
;  LogOS kernel — K5a: timer IRQ live on the metal (PIC + PIT).
;
;  %include'd into boot.asm. ENTIRELY guarded by %ifdef K5_TIMER, like
;  idt.asm's K2_FAULT and boot.asm's K4C_WX substrate — so when K5_TIMER
;  is NOT defined this file contributes ZERO bytes and every other kernel
;  ELF (K1..K4c) stays byte-identical.
;
;  timer_setup: remap the 8259 PIC so IRQ0 -> vector 0x20 (out of the way
;    of the CPU exceptions 0..31), program PIT channel 0 to ~100 Hz, zero
;    the tick cell, install IDT[0x20] -> timer_isr, unmask ONLY IRQ0.
;  timer_isr: an async hardware interrupt that can land in the MIDDLE of
;    arbitrary LA code — it must be transparent. It touches only rax (saved)
;    and rflags (restored by iretq): bump the 64-bit tick counter, send the
;    master-PIC end-of-interrupt, iretq. The interrupted LA code resumes
;    with every register intact — that transparency IS the proof of
;    preemption capability.
;
;  TICK_ADDR (0x310000, 3 MiB + 64 KiB) sits in the identity-mapped low-RAM
;  scratch gap between the boot segment (~1 MiB) and the LA image (4 MiB) —
;  the same gap MBI_SAVE (0x300000) lives in — so the LA image reads the
;  tick count with the existing peek() builtin.
; ===================================================================
%ifdef K5_TIMER

TICK_ADDR   equ 0x310000        ; 3211264 — the LA probe peek()s its low byte

%ifdef K5B2
; K5b.2 preemptive: the absolute address of the LA runtime's YIELD_PENDING byte
; (native_codegen3_rt.asm data slot). The timer ISR sets it; rt_apply's safe
; point reads+clears it and yields. This MUST match the address derived from the
; rt listing — build_k5b2.sh asserts it (a wrong address would set a random byte
; in the LA image and never preempt). It lives in the identity-mapped LA image.
YIELD_PENDING_ABS equ 0x4013dd  ; = 4199389 (derive_consts.py YIELD_PENDING_ADDR)
; Re-derived 2026-08-28: 0b031c6 (rt_init HEAP_END clamp) grew rt_init by 45 bytes
; and moved this slot 0x4013b0 -> 0x4013dd without updating the equ here. It is
; the ONE rt-derived constant derive_consts.py --validate cannot check, because
; that mode validates native_codegen3.la and this copy lives in timer.asm; the
; only check is build_k5b2.sh step [1/5], which runs only when K5b.2 runs.
%endif

section .boot32
bits 64

; timer_isr — IRQ0 handler (interrupt gate 0x8E: IF cleared on entry, so no
; nested timer reentry). Minimal footprint: only rax is clobbered/saved.
timer_isr:
    push    rax
    inc     qword [TICK_ADDR]   ; one tick (64-bit; the LA probe reads the low byte)
%ifdef K5B2
    ; K5b.2: request a safe-point yield in the LA runtime. Just a memory store —
    ; no GP register touched beyond the saved rax — so the ISR stays transparent;
    ; rt_apply consumes the flag at the next reduction (never mid-rt_gc/alloc).
    mov     byte [YIELD_PENDING_ABS], 1
%ifdef K5B2_DBG
    ; DIAGNOSTIC: emit '.' on COM1 per tick so the serial log shows ticks
    ; interleaved with the LA output. rax is saved (pushed at ISR entry); dx used.
    push    rdx
    mov     dx, 0x3F8
    mov     al, '.'
    out     dx, al
    pop     rdx
%endif
%endif
    mov     al, 0x20            ; PIC EOI
    out     0x20, al            ; -> master PIC command port
    pop     rax
    iretq

; timer_setup — remap PIC, program PIT, install the gate, unmask IRQ0.
timer_setup:
    ; --- remap the 8259 PIC: master vectors 0x20-0x27, slave 0x28-0x2F ---
    mov     al, 0x11            ; ICW1: begin init, cascade, ICW4 present
    out     0x20, al            ;   master
    out     0xA0, al            ;   slave
    mov     al, 0x20            ; ICW2 master: IRQ0..7 -> 0x20..0x27
    out     0x21, al
    mov     al, 0x28            ; ICW2 slave:  IRQ8..15 -> 0x28..0x2F
    out     0xA1, al
    mov     al, 0x04            ; ICW3 master: slave attached on IRQ2 (bit 2)
    out     0x21, al
    mov     al, 0x02            ; ICW3 slave:  cascade identity = 2
    out     0xA1, al
    mov     al, 0x01            ; ICW4: 8086/88 mode
    out     0x21, al
    out     0xA1, al
    mov     al, 0xFE            ; master mask: unmask ONLY IRQ0 (the timer)
    out     0x21, al
    mov     al, 0xFF            ; slave mask: all masked
    out     0xA1, al

    ; --- PIT channel 0, mode 3 (square wave), divisor 11932 (~100 Hz) ---
    ; 1193182 Hz / 11932 = 99.998 Hz.  11932 = 0x2E9C.
    mov     al, 0x36            ; ch0, lo+hi byte, mode 3, binary
    out     0x43, al
    mov     al, 0x9C            ; divisor low
    out     0x40, al
    mov     al, 0x2E            ; divisor high
    out     0x40, al

    ; --- zero the tick cell (identity-mapped low RAM) ---
    mov     qword [TICK_ADDR], 0

    ; --- install IDT[0x20] -> timer_isr (64-bit interrupt gate, DPL 0) ---
    ; Gate layout matches idt_install: [offlo16][sel16][ist8|type8][offmid16][offhi32][rsvd32].
    mov     rdi, idt + 0x20 * 16
    mov     rax, timer_isr
    mov     word [rdi + 0], ax
    mov     word [rdi + 2], 0x08        ; kernel code selector
    mov     word [rdi + 4], 0x8E00      ; ist=0, type=0x8E (present, 64-bit int gate)
    shr     rax, 16
    mov     word [rdi + 6], ax
    shr     rax, 16
    mov     dword [rdi + 8], eax
    mov     dword [rdi + 12], 0
    ret

%endif
