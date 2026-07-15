; =====================================================================
;  LogOS K7a — the sovereign boot sector (replaces GRUB/multiboot).
;
;  A 512-byte MBR the BIOS loads at 0x7C00 in 16-bit real mode. It inits
;  COM1, announces itself, builds a GDT, enters 32-bit protected mode, and
;  announces again from there — proving LogOS boots from its OWN boot sector
;  with no GRUB in the loop. (K7b will load the kernel image from disk and
;  hand off in the multiboot-compatible 32-bit state boot.asm's _start
;  expects; this slice proves the boot chain + the real->protected mode
;  transition.) Assembled `nasm -f bin`, written to sector 0 of a raw disk.
; =====================================================================
BITS 16
org 0x7C00

COM1        equ 0x3F8
DBG_EXIT    equ 0xF4
DBG_OK      equ 0x10

_start:
    cli
    xor     ax, ax
    mov     ds, ax
    mov     es, ax
    mov     ss, ax
    mov     sp, 0x7C00              ; stack grows down, below the loaded MBR

    ; --- init COM1 (8N1, 115200) --- (16-bit, same regs as the kernel's serial)
    mov     dx, COM1 + 1
    xor     al, al
    out     dx, al                  ; IER: no interrupts
    mov     dx, COM1 + 3
    mov     al, 0x80
    out     dx, al                  ; LCR: DLAB on
    mov     dx, COM1 + 0
    mov     al, 0x01
    out     dx, al                  ; divisor low = 1 (115200)
    mov     dx, COM1 + 1
    xor     al, al
    out     dx, al                  ; divisor high = 0
    mov     dx, COM1 + 3
    mov     al, 0x03
    out     dx, al                  ; LCR: 8N1, DLAB off
    mov     dx, COM1 + 2
    mov     al, 0xC7
    out     dx, al                  ; FIFO on
    mov     dx, COM1 + 4
    mov     al, 0x0B
    out     dx, al                  ; MCR: DTR/RTS/OUT2

    mov     si, msg_real
    call    print16                 ; "K7 real" from real mode

    ; --- enter 32-bit protected mode ---
    lgdt    [gdt_ptr]
    mov     eax, cr0
    or      eax, 1                  ; CR0.PE
    mov     cr0, eax
    jmp     0x08:pmode              ; far jump loads CS = 32-bit code selector

; --- 16-bit serial print: SI -> NUL-terminated string ---
print16:
    lodsb
    test    al, al
    jz      .done
    call    putc16
    jmp     print16
.done:
    ret
putc16:
    push    dx
    push    ax
    mov     dx, COM1 + 5
.wait:
    in      al, dx
    test    al, 0x20                ; THR empty?
    jz      .wait
    pop     ax
    mov     dx, COM1
    out     dx, al
    pop     dx
    ret

BITS 32
pmode:
    mov     ax, 0x10                ; 32-bit data selector
    mov     ds, ax
    mov     es, ax
    mov     ss, ax
    mov     esp, 0x7C00

    mov     esi, msg_pmode
    call    print32                 ; "K7 pmode" from 32-bit protected mode

    ; success -> QEMU isa-debug-exit (exit 33), then halt
    mov     al, DBG_OK
    mov     dx, DBG_EXIT
    out     dx, al
    cli
.hang:
    hlt
    jmp     .hang

; --- 32-bit serial print: ESI -> NUL-terminated string ---
print32:
    mov     al, [esi]
    test    al, al
    jz      .done
    inc     esi
    call    putc32
    jmp     print32
.done:
    ret
putc32:
    push    edx
    push    eax
    mov     dx, COM1 + 5
.wait:
    in      al, dx
    test    al, 0x20
    jz      .wait
    pop     eax
    mov     dx, COM1
    out     dx, al
    pop     edx
    ret

msg_real:   db "K7 real", 13, 10, 0
msg_pmode:  db "K7 pmode", 13, 10, 0

; --- GDT: null, 32-bit code (0x08), 32-bit data (0x10) ---
align 8
gdt:
    dq 0
    dq 0x00CF9A000000FFFF           ; code: base 0, limit 4G, 32-bit, exec/read
    dq 0x00CF92000000FFFF           ; data: base 0, limit 4G, 32-bit, read/write
gdt_ptr:
    dw gdt_ptr - gdt - 1
    dd gdt

times 510 - ($ - $$) db 0
dw 0xAA55                            ; MBR boot signature
