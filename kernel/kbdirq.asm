; ===================================================================
;  LogOS kernel — HAL.2b: IRQ-driven keyboard (PIC + IRQ1).
;
;  %include'd into boot.asm, ENTIRELY guarded by %ifdef HAL2B (like K5a's
;  timer.asm / K2's K2_FAULT) — zero bytes otherwise, so every other kernel
;  ELF stays byte-identical. This is the interrupt-driven twin of HAL.2's
;  POLLING keyboard (kbd.la): there the LA program spun on the i8042 status
;  port; here a hardware IRQ1 wakes an ISR that reads the scancode, and the
;  LA driver only consumes an ISR-filled ring buffer — never touching the
;  i8042 itself.
;
;  kbd_setup: remap the 8259 PIC (master 0x20-0x27, slave 0x28-0x2F, exactly
;    as K5a's timer_setup), install IDT[0x21] -> kbd_isr, unmask ONLY IRQ1.
;    (The i8042's own IRQ1 enable is left as SeaBIOS set it — the -kernel
;    firmware enables the keyboard interrupt during its PS/2 init.)
;  kbd_isr: IRQ1 fires per key event. Minimal, transparent footprint (only
;    rax/rdx, saved/restored; iretq restores rflags) so it can land in the
;    middle of arbitrary LA code: read the SET-1 scancode from the data port
;    0x60, append it to a 256-byte ring at KBD_BUF, bump the 1-byte head
;    index, EOI the master PIC, iretq.
;
;  KBD_HEAD (0x320000) / KBD_BUF (0x320008) sit in the identity-mapped
;  low-RAM scratch gap (1 MiB..4 MiB), like K5a's TICK_ADDR (0x310000) and
;  MBI_SAVE (0x300000) — so the LA image reads them with the peek() builtin.
; ===================================================================
%ifdef HAL2B

KBD_HEAD equ 0x320000       ; 3276800 — 1-byte ring head (wraps at 256), ISR-written
KBD_BUF  equ 0x320008       ; 3276808 — 256-byte scancode ring

section .boot32
bits 64

; kbd_isr — IRQ1 handler (interrupt gate 0x8E: IF cleared on entry, no reentry).
kbd_isr:
    push    rax
    push    rdx
    xor     eax, eax
    in      al, 0x60            ; SET-1 scancode from the i8042 data port
    movzx   rdx, byte [KBD_HEAD]
    mov     [KBD_BUF + rdx], al ; ring[head] = scancode
    inc     byte [KBD_HEAD]     ; head++ (wraps at 256 — 1-byte cell)
    mov     al, 0x20            ; PIC EOI
    out     0x20, al            ;   -> master PIC command port
    pop     rdx
    pop     rax
    iretq

; kbd_setup — remap PIC, install IDT[0x21] -> kbd_isr, unmask IRQ1.
kbd_setup:
    ; --- remap the 8259 PIC: master 0x20-0x27, slave 0x28-0x2F (as K5a) ---
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
    mov     al, 0xFD            ; master mask: unmask ONLY IRQ1 (the keyboard)
    out     0x21, al
    mov     al, 0xFF            ; slave mask: all masked
    out     0xA1, al

    ; --- zero the ring head ---
    mov     byte [KBD_HEAD], 0

    ; --- install IDT[0x21] -> kbd_isr (64-bit interrupt gate, DPL 0) ---
    ; Gate layout matches idt_install/timer_setup:
    ;   [offlo16][sel16][ist8|type8][offmid16][offhi32][rsvd32].
    mov     rdi, idt + 0x21 * 16
    mov     rax, kbd_isr
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
