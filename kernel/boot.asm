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
;        under Linux runs here UNMODIFIED. The real identity is here: the
;        incbin'd image IS byte-for-byte the host binary — one being on two
;        substrates (host_image ≡ metal_image, ⊕(SELF,SELF), the eighth
;        self-relation). The syscall SERVICE, by contrast, earns only b_τ = f_τ
;        over the write+exit subset the image uses (fd ignored, exit code
;        discarded, unknown syscalls return 0) — a YIELDS-equivalence, NOT a
;        blanket ≡. (WITH_OK in build.sh witnesses both — see gate_with_ok.sh.)
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

; K3b: the LA image's stack top. The native_codegen3 runtime arms a soft stack
; guard at STACK_LIMIT = STACK_BASE - 7 MiB (STACK_BASE = the rsp it starts
; with), sized for the Linux 8 MiB stack. On the metal we must give it an
; equally-tall stack whose base is > 7 MiB, or that subtraction underflows and
; the guard misfires immediately. 0x8000000 (128 MiB) is identity-mapped RAM
; above the LA image (4 MiB), its GC worklist (~4-68 MiB) and heap use, giving
; a full 7 MiB stack with no underflow. (Requires QEMU -m >= 160 or so; the
; gates use 256.) The 32-bit trampoline still uses the small boot_stack.
LA_STACK_TOP equ 0x8000000

; ---- Multiboot1 header (must live in the first 8 KiB of the file) ----
; K3b: flag bit 1 (0x2) = "the loader must pass memory information" (mem_* +
; the full mmap) in the multiboot info structure. We then thread that mbi
; pointer to the LA image so pmm_metal.la reads the REAL map via peek().
MB_MAGIC    equ 0x1BADB002
MB_FLAGS    equ 0x00000002
MB_CHECK    equ -(MB_MAGIC + MB_FLAGS)

; K3b: fixed, reserved scratch word for the threaded mbi pointer. 0x300000
; (3 MiB) is identity-mapped low RAM in the unused gap between the boot segment
; (~1 MiB) and the LA image (4 MiB) — the loader never lands the mbi/mmap here.
; boot.asm writes EBX here; the LA image peeks it (MBI_SAVE = 3145728).
MBI_SAVE    equ 0x300000

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
    ; K3b: the multiboot loader hands us EBX = physical addr of the multiboot
    ; info structure. Save it to the fixed scratch BEFORE anything can clobber
    ; it. Paging is off here, so this is a plain physical write to RAM; once the
    ; identity map is live the LA image peeks the same physical byte.
    mov     [MBI_SAVE], ebx
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
%ifdef K4C_WX
    ; K4c: NXE (no-execute enable, bit 11) — arm the NX half of the W^X
    ; substrate, so a PTE's NX@bit63 is honored as no-execute instead of
    ; triggering a reserved-bit page fault. Guarded like K2_FAULT so every
    ; other kernel ELF's boot bytes stay identical.
    or      eax, (1 << 11)
%endif
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
%ifdef K5B2
    ; K5b.2: MAIN gets a HIGH stack (0x3F000000 = 1008 MiB) so it sits ABOVE the
    ; preemptive task stacks (TASK_STACK_TOP=0x38000000=896 MiB, carved down by
    ; rt_spawn) and leaves the LA heap room to grow up from ~68 MiB without either
    ; the heap or a task stack colliding with MAIN's. Needs QEMU -m 1024 (1008 MiB
    ; must be mapped). Byte-identical to the K3b path when K5B2 is not defined.
    mov     rsp, 0x3F000000
%else
    mov     rsp, LA_STACK_TOP       ; K3b: tall stack for the LA image's guard
%endif

%ifdef K4C_WX
    ; K4c: CR0.WP (write-protect, bit 16) — enforce W^X in ring 0. Without it a
    ; supervisor (ring-0) write to a read-only (W=0) page silently SUCCEEDS; with
    ; it, that write raises #PF. This is the switch that makes page-table write
    ; permissions real for the kernel itself. Guarded like K2_FAULT / NXE above.
    mov     rax, cr0
    or      rax, (1 << 16)
    mov     cr0, rax
%endif

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
    call    idt_install             ; K2: exceptions -> diagnosed serial halt

%ifdef K5_TIMER
    ; K5a: remap the PIC, program the PIT (~100 Hz), install IDT[0x20] ->
    ; timer_isr, unmask IRQ0, then enable external interrupts. Guarded (like
    ; K2_FAULT / K4C_WX) so every other kernel ELF's boot bytes stay identical.
    ; The timer then fires ASYNCHRONOUSLY during the LA image's execution.
    call    timer_setup
    sti
%endif

%ifdef K2_FAULT
    ; K2 gate fault-injection: raise #UD (vector 6) to prove the IDT catches
    ; it loudly (serial "EXCEPTION 06", isa-debug-exit 35) instead of a
    ; triple-fault. Only assembled with `nasm -dK2_FAULT` (kernel_fault.elf).
    ud2
%endif

%ifdef K6A
    ; ===== K6a: drop to ring 3 and run a user payload that syscalls back =====
    ; STAR[63:48] = 0x10 so sysretq returns to CS=0x20|3 / SS=0x18|3 (ring 3).
    mov     ecx, 0xC0000081             ; IA32_STAR
    xor     eax, eax
    mov     edx, (0x10 << 16) | 0x08    ; [47:32]=0x08 (syscall), [63:48]=0x10 (sysret)
    wrmsr

    ; Map the 256 MiB 2 MiB-page (PD[128]) as USER: present|writable|user|PS = 0x87.
    ; This one page holds the copied payload + its message + the user stack.
    ; U/S is ANDed down the whole walk, so PML4[0] and PDPT[0] must ALSO carry U=1
    ; (they were 0x03 = supervisor); the other PD entries stay 0x83 (supervisor),
    ; so ONLY PD[128] becomes user-accessible.
    or      dword [pml4], 0x04          ; PML4[0] |= user
    or      dword [pdpt], 0x04          ; PDPT[0] |= user
    or      dword [pd + 0*8], 0x04       ; DBG: PD[0] (0-2MiB) |= user — run payload in place
    mov     dword [pd + 128*8], 0x10000000 | 0x87
    mov     dword [pd + 128*8 + 4], 0
    mov     rax, cr3
    mov     cr3, rax                    ; flush TLB (PML4/PDPT/PD entries changed)

    ; Copy the payload blob to the user page at 0x10000000.
    cld                                 ; forward copy (DF is not guaranteed clear at boot)
    mov     rsi, k6a_payload
    mov     edi, 0x10000000
    mov     ecx, k6a_blob_len
    ; DBG: dump rsi[31:0] and rdi[31:0], preserving rsi/rdi/rcx (serial_putc trashes dil)
    push    rsi
    push    rdi
    push    rcx
    mov     rbx, rsi
    mov     al, bh
    call    dbg_hex
    mov     al, bl
    call    dbg_hex
    mov     dil, '<'
    call    serial_putc
    pop     rcx
    pop     rdi
    pop     rsi
    rep     movsb

    ; Fill the TSS descriptor (gdt64.tss) with k6a_tss base/limit, then LTR.
    ; .rodata is writable here (identity map W=1, no CR0.WP in the K6a build).
    mov     rax, k6a_tss
    mov     word [gdt64 + gdt64.tss], 103
    mov     word [gdt64 + gdt64.tss + 2], ax
    shr     rax, 16
    mov     byte [gdt64 + gdt64.tss + 4], al
    mov     byte [gdt64 + gdt64.tss + 5], 0x89   ; present, available 64-bit TSS
    mov     byte [gdt64 + gdt64.tss + 6], 0
    shr     rax, 8
    mov     byte [gdt64 + gdt64.tss + 7], al
    mov     rax, k6a_tss
    shr     rax, 32
    mov     dword [gdt64 + gdt64.tss + 8], eax
    mov     dword [gdt64 + gdt64.tss + 12], 0
    ; TSS.rsp0 (offset 4) = a ring-0 stack for ring-3 traps; iomap base (102) beyond limit.
    mov     rax, k6a_kstack_top
    mov     [k6a_tss + 4], rax
    mov     word [k6a_tss + 102], 104
    mov     ax, gdt64.tss
    ltr     ax

    ; DBG: source payload first 4 bytes (want 66 8c c8 .. = mov ax,cs) ...
    mov     al, [k6a_payload + 0]
    call    dbg_hex
    mov     al, [k6a_payload + 1]
    call    dbg_hex
    mov     al, [k6a_payload + 2]
    call    dbg_hex
    mov     dil, '>'
    call    serial_putc
    ; ... and the DEST bytes at 0x10000000 (did the copy land?)
    mov     al, [0x10000000 + 0]
    call    dbg_hex
    mov     al, [0x10000000 + 1]
    call    dbg_hex
    mov     al, [0x10000000 + 2]
    call    dbg_hex
    mov     dil, 10
    call    serial_putc

    ; iretq frame -> ring 3 at the payload. iretq pops RIP,CS,RFLAGS,RSP,SS.
    push    qword 0x18 | 3              ; SS = user data, RPL 3
    push    qword 0x101F0000           ; user RSP (top of stack in the user page)
    push    qword 0x202                ; RFLAGS (IF set, reserved bit 1)
    push    qword 0x20 | 3             ; CS = user code, RPL 3
    push    qword k6a_payload          ; DBG RIP = payload IN PLACE (bypass the copy)
    iretq
%else
    ; --- hand off to the Lingua-Adamica kernel image (its prol) ---
    mov     rax, LA_ENTRY
    jmp     rax
%endif

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
%ifdef K5B2_DBG
    ; DEBUG: emit "=<code>;" on COM1 so an ERROR exit (70/71/72/73/134/1) is
    ; visible instead of being masked as success. Saves the regs it uses.
    push    rax
    push    rbx
    push    rcx
    push    rdx
    push    rdi
    mov     dil, '='
    call    serial_putc
    pop     rax                     ; the exit code
    xor     rcx, rcx
    mov     rbx, 10
.k5dbg_div:
    xor     rdx, rdx
    div     rbx
    push    rdx
    inc     rcx
    test    rax, rax
    jnz     .k5dbg_div
.k5dbg_emit:
    pop     rdx
    mov     dil, dl
    add     dil, '0'
    call    serial_putc
    dec     rcx
    jnz     .k5dbg_emit
    mov     dil, ';'
    call    serial_putc
    pop     rdx
    pop     rcx
    pop     rbx
    pop     rax
%endif
    ; exit(rdi=code) -> QEMU isa-debug-exit success, then hard halt.
    mov     al, DBG_OK
    mov     dx, DBG_EXIT
    out     dx, al
    cli
.hang:
    hlt
    jmp     .hang
.ret:
%ifdef K6A
    ; K6a: the caller is ring-3 user code reached via `syscall`; return with sysretq
    ; (CS/SS from STAR[63:48] -> ring 3, RIP=rcx, RFLAGS=r11, both preserved by
    ; .sys_write / serial_putc). RSP is unchanged (syscall never switched it).
    o64 sysret
%else
    push    r11
    popfq                           ; restore caller rflags
    jmp     rcx                      ; return to instruction after `syscall`
%endif

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

%ifdef K6A
; ---------------------------------------------------------------------
;  K6a ring-3 user payload (in .boot32 = identity-mapped low RAM, so k6a_payload
;  is a valid physical copy source). It is COPIED to the user page 0x10000000 and
;  runs there at ring 3, so it must be position-independent: message references
;  are RIP-relative (the rel offset is preserved by the copy). It proves ring 3 by
;  reading its own CS privilege level into the message, and proves the syscall
;  SERVICE from ring 3 by writing that message (a ring-3 task cannot touch COM1
;  directly — the bytes only reach serial through the kernel's write syscall).
; ---------------------------------------------------------------------
; dbg_hex(al) — print al as two hex chars + space on COM1 (clobbers nothing caller-visible)
dbg_hex:
    push    rax
    push    rbx
    movzx   ebx, al
    shr     al, 4
    call    .nib
    mov     al, bl
    and     al, 0x0F
    call    .nib
    mov     dil, ' '
    call    serial_putc
    pop     rbx
    pop     rax
    ret
.nib:
    and     al, 0x0F
    cmp     al, 10
    jb      .dig
    add     al, 'a' - 10
    jmp     .put
.dig:
    add     al, '0'
.put:
    mov     dil, al
    call    serial_putc
    ret

k6a_payload:
    mov     ax, cs
    and     ax, 3                       ; CPL (3 = ring 3)
    add     al, '0'
    lea     rbx, [rel k6a_cpldigit]
    mov     [rbx], al                   ; patch the digit into the message
    mov     eax, 1                      ; write(fd=1, buf, len)
    mov     edi, 1
    lea     rsi, [rel k6a_msg]
    mov     edx, k6a_msg_len
    syscall                             ; -> kernel (ring 0) -> COM1 -> sysret back
    mov     eax, 60                     ; exit(0)
    xor     edi, edi
    syscall
k6a_msg:      db "K6A CPL="
k6a_cpldigit: db "0"
              db 10
k6a_msg_len   equ $ - k6a_msg
k6a_blob_len  equ $ - k6a_payload
%endif

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
%ifdef K6A
; K6a ring-3 selectors. Ordered for SYSRET: with STAR[63:48]=0x10, sysretq loads
; CS = 0x10+16 = 0x20 (user code) and SS = 0x10+8 = 0x18 (user data), both RPL 3.
.udata: equ $ - gdt64                           ; 0x18
    dq (1<<41)|(1<<44)|(1<<47)|(3<<45)          ; user data: writable|S|present|DPL3
.ucode: equ $ - gdt64                           ; 0x20
    dq (1<<43)|(1<<44)|(1<<47)|(1<<53)|(3<<45)  ; user code: exec|S|present|long|DPL3
.tss: equ $ - gdt64                             ; 0x28 (16-byte system desc, filled at runtime)
    dq 0
    dq 0
%endif
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
%ifdef K6A
align 16
k6a_tss:                                ; 104-byte 64-bit TSS (rsp0 at +4, iomap base at +102)
        resb 104
align 16
k6a_kstack:                             ; ring-0 stack the CPU switches to on a ring-3 trap (TSS.rsp0)
        resb 16384
k6a_kstack_top:
%endif

; ---------------------------------------------------------------------
;  The Lingua-Adamica kernel image, placed by kernel.ld at 0x400000.
;  native_codegen3 emitted it; we run it unmodified.
; ---------------------------------------------------------------------
; K2: IDT + exception handlers (its own .boot32/.rodata/.bss sections).
%include "idt.asm"
; K5a: timer IRQ substrate (PIC + PIT). Entirely %ifdef K5_TIMER — zero bytes
; unless assembled with -dK5_TIMER, so other kernel ELFs stay byte-identical.
%include "timer.asm"

%ifndef K6A
section .la_image
incbin "native_codegen3_out"
%endif
