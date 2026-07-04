; ===================================================================
;  LogOS kernel — K1 boot stub (bare metal, no host OS)
;
;  The bridge from GRUB/QEMU-multiboot (which hands off in 32-bit
;  protected mode, paging OFF) to the 64-bit Lingua-Adamica kernel image
;  that native_codegen3 already emits.
;
;  It does the irreducible "physics" only:
;    (1) Multiboot1 header so a multiboot loader will load us.
;    (2) 32-bit entry -> build identity page tables -> enable long mode.
;    (3) 64-bit: set up the SYSCALL substrate (EFER.SCE + STAR/LSTAR)
;        so the LA image's own `syscall` instructions (write, exit) are
;        serviced by THIS kernel — write(1,...)->COM1 serial,
;        exit(n)->isa-debug-exit + halt. So the SAME LA binary that runs
;        under Linux runs here UNMODIFIED. ("The OS proper services
;        syscalls" made literal — b_τ ≡ f_τ across host and metal.)
;    (4) init COM1, then jump into the LA image entry (its `prol`).
;
;  LA_ENTRY (the prol vaddr) is generated per-build from the ELF's
;  e_entry by build_k1.sh into entry.inc. The LA image itself is placed
;  at 0x400000 by kernel.ld (incbin of native_codegen3_out).
;
;  K1 has NO IDT yet: a CPU fault triple-faults (QEMU -no-reboot makes
;  the gate fail loudly). K2 adds the IDT + loud fault handlers.
; ===================================================================

%include "entry.inc"          ; defines LA_ENTRY  (the LA image's e_entry)

COM1        equ 0x3F8
DBG_EXIT    equ 0xF4          ; QEMU isa-debug-exit port
DBG_OK      equ 0x10          ; -> QEMU exit code (0x10<<1)|1 = 33 = success

; ---- Multiboot1 header (must live in the first 8 KiB of the file) ----
MB_MAGIC    equ 0x1BADB002
MB_FLAGS    equ 0x00000000
MB_CHECK    equ -(MB_MAGIC + MB_FLAGS)

section .multiboot
align 4
    dd MB_MAGIC
    dd MB_FLAGS
    dd MB_CHECK

; =====================================================================
;  32-bit entry — the multiboot loader lands here (protected mode, PG=0)
; =====================================================================
section .boot32
bits 32
global _start
_start:
    cli
    mov     esp, boot_stack_top     ; a real stack for the 32-bit phase

    ; --- build 4-level page tables: identity-map the low 1 GiB ---
    ; PML4[0] -> PDPT ; PDPT[0] -> PD ; PD[0..511] = 2 MiB pages (0..1 GiB)
    mov     eax, pdpt
    or      eax, 0x03               ; present | writable
    mov     [pml4], eax
    mov     dword [pml4+4], 0

    mov     eax, pd
    or      eax, 0x03
    mov     [pdpt], eax
    mov     dword [pdpt+4], 0

    ; fill 512 PD entries, each a 2 MiB page: phys = i*0x200000, flags 0x83
    ; (present | writable | PS=huge)
    mov     ecx, 0                  ; i
    mov     edi, pd
.fill_pd:
    mov     eax, ecx
    shl     eax, 21                 ; i * 2 MiB  (low 32 bits of phys)
    or      eax, 0x83
    mov     [edi], eax
    mov     dword [edi+4], 0        ; high 32 bits = 0
    add     edi, 8
    inc     ecx
    cmp     ecx, 512
    jne     .fill_pd

    ; --- load CR3 ---
    mov     eax, pml4
    mov     cr3, eax

    ; --- enable PAE (CR4.PAE = bit 5) ---
    mov     eax, cr4
    or      eax, 1 << 5
    mov     cr4, eax

    ; --- EFER: LME (long mode enable, bit 8) + SCE (syscall enable, bit 0) ---
    mov     ecx, 0xC0000080         ; IA32_EFER
    rdmsr
    or      eax, (1 << 8) | (1 << 0)
    wrmsr

    ; --- enable paging (CR0.PG = bit 31); PE already set by loader ---
    mov     eax, cr0
    or      eax, 1 << 31
    mov     cr0, eax

    ; --- load the 64-bit GDT and far-jump into 64-bit code ---
    lgdt    [gdt64.ptr]
    jmp     gdt64.code:long_start

; =====================================================================
;  64-bit entry
; =====================================================================
bits 64
long_start:
    mov     ax, gdt64.data
    mov     ss, ax
    mov     ds, ax
    mov     es, ax
    mov     fs, ax
    mov     gs, ax
    mov     rsp, boot_stack_top

    ; --- SYSCALL substrate ---
    ; STAR[47:32] = kernel CS base for syscall: CS=sel, SS=sel+8.
    ; gdt64.code=0x08, gdt64.data=0x10 -> sel = 0x08 gives CS=0x08, SS=0x10.
    ; STAR[63:48] = sysret user base (unused; we return via jmp rcx). Set 0x08.
    mov     ecx, 0xC0000081         ; IA32_STAR
    xor     eax, eax                ; STAR[31:0] (32-bit syscall target EIP) unused
    mov     edx, (0x08 << 16) | 0x08
    wrmsr

    mov     ecx, 0xC0000082         ; IA32_LSTAR = 64-bit syscall entry
    mov     rax, syscall_entry
    mov     rdx, rax
    shr     rdx, 32                 ; edx:eax = handler address
    wrmsr

    mov     ecx, 0xC0000084         ; IA32_FMASK
    mov     eax, 0x200              ; mask IF on entry (no IDT yet)
    xor     edx, edx
    wrmsr

    call    serial_init

    ; --- hand off to the Lingua-Adamica kernel image (its prol) ---
    mov     rax, LA_ENTRY
    jmp     rax

; ---------------------------------------------------------------------
;  syscall_entry — services the LA image's syscalls.
;  On entry: rcx = return rip, r11 = saved rflags, rax = syscall number,
;  rdi/rsi/rdx = args. We stay in ring 0, so we do NOT sysret (which would
;  force ring 3); we restore rflags from r11 and `jmp rcx`.
; ---------------------------------------------------------------------
syscall_entry:
    cmp     rax, 1
    je      .sys_write
    cmp     rax, 60
    je      .sys_exit
    ; unknown syscall: return 0, keep going
    xor     rax, rax
    jmp     .ret
.sys_write:
    ; write(rdi=fd, rsi=buf, rdx=len) -> COM1 (fd ignored). returns len.
    mov     r8, rsi                 ; cursor
    mov     r9, rdx                 ; remaining
    mov     r10, rdx                ; saved len (return value)
.w_loop:
    test    r9, r9
    jz      .w_done
    mov     dil, [r8]               ; next byte
    call    serial_putc
    inc     r8
    dec     r9
    jmp     .w_loop
.w_done:
    mov     rax, r10
    jmp     .ret
.sys_exit:
    ; exit(rdi=code) -> QEMU isa-debug-exit success, then hard halt.
    mov     al, DBG_OK
    mov     dx, DBG_EXIT
    out     dx, al
    cli
.hang:
    hlt
    jmp     .hang
.ret:
    push    r11
    popfq                           ; restore caller rflags
    jmp     rcx                      ; return to instruction after `syscall`

; ---------------------------------------------------------------------
;  Serial (COM1, 8N1, 115200) — the K1 console / test oracle.
; ---------------------------------------------------------------------
serial_init:
    mov     dx, COM1 + 1            ; IER: disable interrupts
    mov     al, 0x00
    out     dx, al
    mov     dx, COM1 + 3            ; LCR: DLAB on
    mov     al, 0x80
    out     dx, al
    mov     dx, COM1 + 0            ; divisor low = 1 (115200)
    mov     al, 0x01
    out     dx, al
    mov     dx, COM1 + 1            ; divisor high = 0
    mov     al, 0x00
    out     dx, al
    mov     dx, COM1 + 3            ; LCR: 8N1, DLAB off
    mov     al, 0x03
    out     dx, al
    mov     dx, COM1 + 2            ; FCR: enable+clear FIFO, 14-byte threshold
    mov     al, 0xC7
    out     dx, al
    mov     dx, COM1 + 4            ; MCR: DTR|RTS|OUT2
    mov     al, 0x0B
    out     dx, al
    ret

; serial_putc(dil = byte) — wait for THR empty, then transmit.
serial_putc:
    push    rax
    push    rdx
.wait:
    mov     dx, COM1 + 5            ; LSR
    in      al, dx
    test    al, 0x20               ; THR empty?
    jz      .wait
    mov     dx, COM1 + 0
    mov     al, dil
    out     dx, al
    pop     rdx
    pop     rax
    ret

; ---------------------------------------------------------------------
;  64-bit GDT: null, kernel code (0x08), kernel data (0x10)
; ---------------------------------------------------------------------
section .rodata
align 8
gdt64:
    dq 0                                        ; null
.code: equ $ - gdt64
    dq (1<<43)|(1<<44)|(1<<47)|(1<<53)          ; code: type|S|present|long
.data: equ $ - gdt64
    dq (1<<41)|(1<<44)|(1<<47)                  ; data: writable|S|present
.ptr:
    dw $ - gdt64 - 1
    dq gdt64

; ---------------------------------------------------------------------
;  Page tables + boot stack (BSS, identity-mapped low RAM)
; ---------------------------------------------------------------------
section .bss
align 4096
pml4:   resb 4096
pdpt:   resb 4096
pd:     resb 4096
align 16
boot_stack:
        resb 16384
boot_stack_top:

; ---------------------------------------------------------------------
;  The Lingua-Adamica kernel image, placed by kernel.ld at 0x400000.
;  native_codegen3 emitted it; we run it unmodified.
; ---------------------------------------------------------------------
section .la_image
incbin "native_codegen3_out"
