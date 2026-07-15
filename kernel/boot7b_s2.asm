; =====================================================================
;  LogOS K7b — the sovereign boot, stage 2 (the loader).
;
;  Entered by stage 1 (the MBR) in 16-bit real mode at 0x7E00. It:
;    (1) enables the A20 line (so physical RAM >= 1 MiB is reachable);
;    (2) builds a flat GDT and enters 32-bit protected mode ("K7 pmode");
;    (3) via 32-bit ATA-PIO, reads the kernel image's two PT_LOAD
;        segments off the disk into their physical addresses —
;        .boot -> BOOTPHYS (0x100000), .la_image -> LAPHYS (0x400000) —
;        zeroing .boot's .bss tail first (the loader's job, since the
;        segment's memsz > filesz);
;    (4) synthesizes a minimal multiboot info structure (mem_lower /
;        mem_upper) at MBI_ADDR and points EBX at it — the exact 32-bit,
;        multiboot-compatible state boot.asm's `_start` expects;
;    (5) jumps to `_start` (BOOTPHYS). From there the existing kernel
;        brings up long mode + the syscall substrate and the LA image
;        speaks "I AM THAT I AM" and exit(33)s. LogOS booted itself.
;
;  All the geometry (LBAs, sector counts, phys addrs, bss size) is
;  supplied by build_k7b.sh via -D, derived from the linked kernel ELF's
;  program headers — so this loader always matches the image on the disk.
; =====================================================================
BITS 16
org 0x7E00

COM1        equ 0x3F8

s2_start:
    cli
    ; --- enable A20 via the fast gate (port 0x92), preserving bit 0 ---
    in      al, 0x92
    or      al, 2
    and     al, 0xFE                ; never write bit 0 (that would reset)
    out     0x92, al

    mov     si, msg_s2
    call    s_print16               ; "K7 stage2" (still real mode)

    ; --- build GDT + enter 32-bit protected mode ---
    lgdt    [gdt_ptr]
    mov     eax, cr0
    or      eax, 1                  ; CR0.PE
    mov     cr0, eax
    jmp     0x08:pm32               ; far jump loads CS = 32-bit flat code

; --- 16-bit serial print: SI -> NUL-terminated string ---
s_print16:
    lodsb
    test    al, al
    jz      .done
    push    dx
    push    ax
    mov     dx, COM1 + 5
.w: in      al, dx
    test    al, 0x20
    jz      .w
    pop     ax
    mov     dx, COM1
    out     dx, al
    pop     dx
    jmp     s_print16
.done:
    ret

BITS 32
pm32:
    mov     ax, 0x10                ; 32-bit flat data selector
    mov     ds, ax
    mov     es, ax
    mov     ss, ax
    mov     esp, 0x7C00             ; a 32-bit stack (below the old MBR)

    mov     esi, msg_pmode
    call    s_print32               ; "K7 pmode"

    ; --- zero .boot's whole memsz window first (its .bss tail) ---
    mov     edi, BOOTPHYS
    mov     ecx, (BOOTMEMSZ + 3) / 4
    xor     eax, eax
    rep     stosd

    ; --- load .boot (filesz) from disk -> BOOTPHYS ---
    mov     ebx, BOOT_LBA
    mov     ecx, BOOT_SECTORS
    mov     edi, BOOTPHYS
    call    ata_lba_read

    ; --- load .la_image from disk -> LAPHYS ---
    mov     ebx, LA_LBA
    mov     ecx, LA_SECTORS
    mov     edi, LAPHYS
    call    ata_lba_read

    ; --- synthesize a minimal multiboot info structure ---
    ; flags bit 0 = mem_lower/mem_upper present. boot.asm saves EBX to
    ; MBI_SAVE; the trivial K1 image never reads it, but a real (K3b+)
    ; image peeks the map here — so hand off a well-formed mbi.
    mov     edi, MBI_ADDR
    mov     dword [edi + 0],  1             ; flags
    mov     dword [edi + 4],  640           ; mem_lower (KiB)
    mov     dword [edi + 8],  MEM_UPPER_KB  ; mem_upper (KiB)

    mov     esi, msg_hand
    call    s_print32               ; "K7 handoff"

    ; --- hand off to the kernel's multiboot entry (_start @ BOOTPHYS) ---
    mov     eax, 0x2BADB002         ; multiboot bootloader magic (EAX)
    mov     ebx, MBI_ADDR           ; EBX = mbi pointer (boot.asm reads this)
    jmp     BOOTPHYS

; --- 32-bit serial print: ESI -> NUL-terminated string ---
s_print32:
    mov     al, [esi]
    test    al, al
    jz      .done
    inc     esi
    push    edx
    push    eax
    mov     dx, COM1 + 5
.w: in      al, dx
    test    al, 0x20
    jz      .w
    pop     eax
    mov     dx, COM1
    out     dx, al
    pop     edx
    jmp     s_print32
.done:
    ret

; --- 32-bit ATA-PIO read: EBX=LBA(28-bit), ECX=count(1..255), EDI=dest ---
; Primary bus (0x1F0), master drive, READ SECTORS (0x20).
ata_lba_read:
    push    eax
    push    ecx
    push    edx
    ; select master + LBA[27:24]
    mov     edx, 0x1F6
    mov     eax, ebx
    shr     eax, 24
    and     al, 0x0F
    or      al, 0xE0
    out     dx, al
    ; ~400 ns settle: read alt status four times
    mov     edx, 0x3F6
    in      al, dx
    in      al, dx
    in      al, dx
    in      al, dx
    ; sector count
    mov     edx, 0x1F2
    mov     al, cl
    out     dx, al
    ; LBA[7:0] / [15:8] / [23:16]
    mov     edx, 0x1F3
    mov     eax, ebx
    out     dx, al
    mov     edx, 0x1F4
    mov     eax, ebx
    shr     eax, 8
    out     dx, al
    mov     edx, 0x1F5
    mov     eax, ebx
    shr     eax, 16
    out     dx, al
    ; issue READ SECTORS
    mov     edx, 0x1F7
    mov     al, 0x20
    out     dx, al
.read_sector:
    mov     edx, 0x1F7
.poll:
    in      al, dx
    test    al, 0x80                ; BSY set?
    jnz     .poll
    test    al, 0x08                ; DRQ set?
    jz      .poll
    ; transfer one sector (256 words) from data port -> EDI
    mov     edx, 0x1F0
    push    ecx
    mov     ecx, 256
    rep     insw
    pop     ecx
    dec     ecx
    jnz     .read_sector
    pop     edx
    pop     ecx
    pop     eax
    ret

; --- GDT: null, 32-bit flat code (0x08), 32-bit flat data (0x10) ---
align 8
gdt:
    dq 0
    dq 0x00CF9A000000FFFF
    dq 0x00CF92000000FFFF
gdt_ptr:
    dw gdt_ptr - gdt - 1
    dd gdt

msg_s2:     db "K7 stage2", 13, 10, 0
msg_pmode:  db "K7 pmode", 13, 10, 0
msg_hand:   db "K7 handoff", 13, 10, 0
