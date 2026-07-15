; =====================================================================
;  LogOS K7b — the sovereign boot sector, stage 1 (the MBR).
;
;  The BIOS loads this 512-byte MBR at 0x7C00 in 16-bit real mode. It
;  inits COM1, announces itself ("K7 real"), then reads stage 2 off the
;  same disk (BIOS int 0x13 extended read, LBA) into low RAM at 0x7E00
;  and jumps to it in real mode. Stage 2 (boot7b_s2.asm) does the heavy
;  lifting: protected mode + a 32-bit ATA-PIO load of the kernel image
;  from disk to its physical addresses, then hands off to boot.asm's
;  `_start`. Together they boot LogOS end-to-end with NO GRUB, NO
;  multiboot loader, NO QEMU -kernel — LogOS boots itself (K1..K7).
;
;  STAGE2_LBA / STAGE2_SECTORS are supplied by build_k7b.sh via -D so the
;  MBR reads exactly the stage-2 blob the build laid onto the disk.
; =====================================================================
BITS 16
org 0x7C00

COM1        equ 0x3F8
STAGE2_ADDR equ 0x7E00              ; where stage 2 is loaded + entered

_start:
    cli
    xor     ax, ax
    mov     ds, ax
    mov     es, ax
    mov     ss, ax
    mov     sp, 0x7C00              ; stack grows down, below the loaded MBR
    mov     [boot_drive], dl        ; BIOS passes the boot drive in DL

    ; --- init COM1 (8N1, 115200) ---
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
    call    print16                 ; "K7 real" from our own MBR

    ; --- load stage 2 from disk via int 0x13 extended read (LBA) ---
    mov     si, dap
    mov     ah, 0x42
    mov     dl, [boot_drive]
    int     0x13
    jc      disk_err

    ; --- hand control to stage 2 (still in real mode) ---
    jmp     0x0000:STAGE2_ADDR

disk_err:
    mov     si, msg_derr
    call    print16
.hang:
    hlt
    jmp     .hang

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
    test    al, 0x20
    jz      .wait
    pop     ax
    mov     dx, COM1
    out     dx, al
    pop     dx
    ret

msg_real:   db "K7 real", 13, 10, 0
msg_derr:   db "K7 diskerr", 13, 10, 0
boot_drive: db 0

; --- Disk Address Packet for int 0x13 AH=42h (read stage 2) ---
align 4
dap:
    db 0x10                         ; packet size
    db 0                            ; reserved
    dw STAGE2_SECTORS               ; sectors to read
    dw STAGE2_ADDR                  ; dest offset
    dw 0x0000                       ; dest segment
    dq STAGE2_LBA                   ; starting LBA

times 510 - ($ - $$) db 0
dw 0xAA55                            ; MBR boot signature
