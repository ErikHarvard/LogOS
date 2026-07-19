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

%include "entry.inc"          ; defines LA_ENTRY  (the LA image's e_entry);
                              ; build_k6b.sh also defines METAL_FLAG_ABS here.

; K6a (ring-3 payload) and K6b (ring-3 LA image) share the ring-3 machinery —
; the user GDT selectors, the TSS(RSP0), and the sysret return path. RING3 is
; defined for either, so those blocks assemble once. Non-ring-3 builds
; (K1..K5) define neither, so their boot bytes stay byte-identical.
%ifdef K6A
  %define RING3
%endif
%ifdef K6B
  %define RING3
  %define LA_RING3_IMAGE
%endif
; K6c3: a REAL LA image (compiled by native_codegen3 with send/recv builtins) runs
; at ring 3 and round-trips a message through the kernel IPC channel — the same
; ring-3 LA-image entry as K6b (LA_RING3_IMAGE) PLUS the IPC channel layer.
%ifdef K6C3
  %define RING3
  %define IPC
  %define LA_RING3_IMAGE
%endif
; HH1a (boot high, LA image low, low map kept) and HH1b (run wholly high, drop the
; low map) both need the high map built in the 32-bit trampoline.
%ifdef HH1
  %define HH1_HIGHMAP
%endif
%ifdef HH1B
  %define HH1_HIGHMAP
%endif
; HH2: per-process page tables. Runs the kernel high (needs the high map), then
; builds two process PML4s sharing the kernel PML4[511] and proves address-space
; isolation with a CR3 switch. A ring-0 kernel demo (no LA image).
%ifdef HH2
  %define HH1_HIGHMAP
  %define HH2_PTS
%endif
; HH2b: a real ring-3 LA process in its OWN per-process PML4, kernel in the high
; half. Composes HH1 (kernel high) + HH2 (per-process page tables) + K6b (ring-3 LA
; image): needs the high map, the RING3 machinery (user selectors + TSS), and the
; LA image.
%ifdef HH2B
  %define HH1_HIGHMAP
  %define RING3
%endif
; HH2c: TWO isolated ring-3 LA processes exchange a typed message. One image
; template is copied into two offset-mapped per-process regions (own low half
; each), the kernel pokes a role byte, and IPC flows through the SHARED kernel
; channel. Needs the high map, RING3 machinery, IPC channel, and the LA image.
%ifdef HH2C
  %define HH1_HIGHMAP
  %define RING3
  %define IPC
  %define HH2_PTS
%endif
; K6c (single-process IPC round-trip) and K6c2 (two ring-3 processes) both need
; the RING3 machinery and the IPC channel layer (send/recv + the mailbox array).
; IPC is defined for either, so the channel storage + send/recv dispatch assemble
; once; K6c2 additionally pulls in the yield/context-switch scheduler.
%ifdef K6C
  %define RING3
  %define IPC
%endif
%ifdef K6C2
  %define RING3
  %define IPC
%endif

COM1        equ 0x3F8
DBG_EXIT    equ 0xF4          ; QEMU isa-debug-exit port
DBG_OK      equ 0x10          ; -> QEMU exit code (0x10<<1)|1 = 33 = success

; K6c: LogOS-native IPC syscall numbers. Chosen well above the Linux write(1)/
; exit(60) range the LA image uses, so a "native" IPC call is unambiguous. A
; kernel CHANNEL is a typed mailbox held in ring-0 .bss: send(chan,type,buf,len)
; deposits a typed message, recv(chan,buf,max) withdraws it — the OS servicing
; IPC across the privilege boundary (the seed of the "nervous system", LogosIPC
; re-homed onto the kernel). A slot is [full:8][type:8][len:8][body:256] = 280,
; padded to 288 for 8-byte alignment of the next slot.
SYS_SEND    equ 0x300
SYS_RECV    equ 0x301
K6C_NCHAN   equ 4
K6C_BODYCAP equ 256
K6C_SLOTSZ  equ 288
; K6c2: cooperative yield -> a kernel-mediated context switch between two ring-3
; tasks. Each task's full ring-3 register context (16 GP regs, with rcx=resume rip
; and r11=resume rflags for the sysret resume) lives in a 128-byte PCB; k6c2_cur
; selects the running one.
SYS_YIELD   equ 0x302
PCB_SIZE    equ 128

; K3b: the LA image's stack top. The native_codegen3 runtime arms a soft stack
; guard at STACK_LIMIT = STACK_BASE - 7 MiB (STACK_BASE = the rsp it starts
; with), sized for the Linux 8 MiB stack. On the metal we must give it an
; equally-tall stack whose base is > 7 MiB, or that subtraction underflows and
; the guard misfires immediately. 0x8000000 (128 MiB) is identity-mapped RAM
; above the LA image (4 MiB), its GC worklist (~4-68 MiB) and heap use, giving
; a full 7 MiB stack with no underflow. (Requires QEMU -m >= 160 or so; the
; gates use 256 — gate_hal4e.sh uses 512.) The 32-bit trampoline still uses the
; small boot_stack.
;
; ── WHAT IS *NOT* GUARDED HERE (measured 2026-07-18, from the built ELF's own
;    PROL, not inferred from source — disassembled at LA_ENTRY) ──────────────
;   worklist base 0x410be0 (4.06 MiB) | heap base r15 0x4410be0 (68.0 MiB)
;   HEAP_END      0x404410be0 (16.07 GiB!) | STACK_LIMIT 0x7900000 (121 MiB)
;
; The stack guard is ONE-DIRECTIONAL. `cmp rsp,[STACK_LIMIT]` stops the STACK
; growing DOWN into the heap. NOTHING stops the HEAP growing UP into the stack:
; alloc24's only bound is `cmp rcx,[HEAP_END]`, and PROL sets HEAP_END to
; hb + HEAP_SIZE where HEAP_SIZE is 16 GiB — sized for Linux, where it is lazily
; mapped address space. On the metal that bound sits ~300x beyond the top of a
; 512 MiB machine, so it is UNREACHABLE and cannot fire.
;
; Concretely, as the heap bumps up from 68 MiB it will:
;   at 121 MiB (STACK_LIMIT) start overwriting the LA stack — SILENTLY;
;   at 128 MiB pass the stack top;
;   at 512 MiB leave physical RAM entirely;
; and `native: heap exhausted` is never reached in any of those cases. The
; failure mode is a clobbered return address -> control transfers into stack
; bytes -> whatever they decode to. There is ~53 MiB of real headroom
; (68 -> 121 MiB), so this is latent, not immediate — HAL.4e never got near it
; (that RED was the gate's own screendump; see kernel/gate_hal4e.sh).
;
; The FIX belongs in rt_init, not here: it already discriminates metal from
; Linux (METAL_FLAG / CPL) and already computes STACK_LIMIT, so it is the one
; place that can clamp HEAP_END to STACK_LIMIT on the metal path and turn a
; silent overrun into the loud halt the discipline requires. That file is
; native_codegen3_rt.asm — TRACK A's, not this track's — so this comment states
; the hazard where a kernel reader will hit it, and the request is on the board.
; Do not "fix" it here by shrinking the stack; that hides it without closing it.
LA_STACK_TOP equ 0x8000000

; HH1: the higher-half kernel base — the top −2 GiB of the 64-bit canonical space,
; 0xFFFFFFFF80000000. Its paging indices are PML4[511] / PDPT[510] / PD[0], so a
; single high PDPT pointing PDPT[510] at the existing low-1-GiB PD aliases every
; low physical page P at 0xFFFFFFFF80000000+P. A high address is reachable by a
; sign-extended disp32 (0x80000000 → 0xFFFFFFFF80000000), so once the LA image is
; rebased here (HH1b) no opcodes change — only addresses. HH1a proves the boot
; executes from the high half; the low identity map is KEPT so the still-low LA
; image and absolute data refs keep working.
HIGH_BASE equ 0xFFFFFFFF80000000

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

%ifdef HAL4
    ; HAL.4: also identity-map 1..4 GiB (PDPT[1..3] -> pd_hi1..3), so high MMIO
    ; BARs (the VGA linear framebuffer ~0xFD000000) are reachable. Each PD entry
    ; j of table k maps phys (k*1 GiB + j*2 MiB); pd_hi1..3 are contiguous, so
    ; one loop fills all 1536 entries. All phys < 4 GiB -> high dword 0.
    mov     eax, pd_hi1
    or      eax, 0x03
    mov     [pdpt + 1*8], eax
    mov     dword [pdpt + 1*8 + 4], 0
    mov     eax, pd_hi2
    or      eax, 0x03
    mov     [pdpt + 2*8], eax
    mov     dword [pdpt + 2*8 + 4], 0
    mov     eax, pd_hi3
    or      eax, 0x03
    mov     [pdpt + 3*8], eax
    mov     dword [pdpt + 3*8 + 4], 0
    mov     ecx, 0                  ; entry index 0..1535
    mov     edi, pd_hi1
    mov     eax, 0x40000000         ; phys base = 1 GiB
.fill_hi:
    mov     ebx, eax
    or      ebx, 0x83               ; present | writable | PS (2 MiB page)
    mov     [edi], ebx
    mov     dword [edi+4], 0
    add     edi, 8
    add     eax, 0x200000           ; += 2 MiB
    inc     ecx
    cmp     ecx, 1536
    jne     .fill_hi
%endif

%ifdef HH1_HIGHMAP
    ; HH1: ALSO map the higher half −2 GiB. PML4[511] -> pdpt_high; pdpt_high[510]
    ; -> the SAME low-1-GiB pd. So 0xFFFFFFFF80000000+P aliases physical page P,
    ; and the whole kernel (loaded low) becomes reachable at its high alias too.
    ; The low identity map above is left in place (HH1a keeps the LA image low).
    mov     eax, pdpt_high
    or      eax, 0x03
    mov     [pml4 + 511*8], eax
    mov     dword [pml4 + 511*8 + 4], 0
    mov     eax, pd
    or      eax, 0x03
    mov     [pdpt_high + 510*8], eax
    mov     dword [pdpt_high + 510*8 + 4], 0
%endif

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

%ifdef HAL2B
    ; HAL.2b: remap the PIC, install IDT[0x21] -> kbd_isr, unmask IRQ1, then
    ; enable external interrupts. Guarded (like K5_TIMER) so every other kernel
    ; ELF's boot bytes stay identical. IRQ1 then fires ASYNCHRONOUSLY on each
    ; key event during the LA image's execution; the ISR fills a ring the LA
    ; driver (kbd2.la) consumes with peek — genuinely interrupt-driven input.
    call    kbd_setup
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
    mov     dword [pd + 128*8], 0x10000000 | 0x87
    mov     dword [pd + 128*8 + 4], 0
    mov     rax, cr3
    mov     cr3, rax                    ; flush TLB (PML4/PDPT/PD entries changed)

    ; Copy the payload blob to the user page at 0x10000000.
    cld                                 ; forward copy (DF is not guaranteed clear at boot)
    mov     rsi, k6a_payload
    mov     edi, 0x10000000
    mov     ecx, k6a_blob_len
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

    ; iretq frame -> ring 3 at the copied payload on the user page. iretq pops
    ; RIP, CS, RFLAGS, RSP, SS.
    push    qword 0x18 | 3              ; SS = user data, RPL 3
    push    qword 0x101F0000           ; user RSP (top of stack in the user page)
    push    qword 0x202                ; RFLAGS (IF set, reserved bit 1)
    push    qword 0x20 | 3             ; CS = user code, RPL 3
    push    qword 0x10000000           ; RIP = the copied payload on the U=1 page
    iretq
%elifdef LA_RING3_IMAGE
    ; ===== K6b / K6c3: run the REAL LA image at ring 3 on the metal =====
    ; (K6b image = kernel.la speaks the Word; K6c3 image = an IPC program that
    ;  send/recv's through the kernel channel. Same boot entry either way.)
    ; STAR[63:48]=0x10 so sysretq returns the LA image's write/exit syscalls to
    ; CS=0x20|3 / SS=0x18|3 (ring 3), exactly as K6a.
    mov     ecx, 0xC0000081             ; IA32_STAR
    xor     eax, eax
    mov     edx, (0x10 << 16) | 0x08    ; [47:32]=0x08 (syscall CS), [63:48]=0x10 (sysret)
    wrmsr

    ; Make the identity-mapped low 1 GiB USER-accessible (U=1) so the ring-3 LA
    ; image can execute its code (@0x400000), grow its heap and use its stack.
    ; U/S ANDs down the walk, so PML4[0] and PDPT[0] must carry U=1 too; EVERY PD
    ; entry (all 512 2 MiB pages, 0..1 GiB) gets U=1 — unlike K6a's single page.
    or      dword [pml4], 0x04
    or      dword [pdpt], 0x04
    mov     rdi, pd
    mov     ecx, 512
.k6b_user:
    or      dword [rdi], 0x04
    add     rdi, 8
    dec     ecx
    jnz     .k6b_user
    mov     rax, cr3
    mov     cr3, rax                    ; flush TLB (PML4/PDPT/PD entries changed)

    ; Tell the LA runtime we are on the metal (rt_init: object-start bitmap OFF,
    ; task stacks in low RAM) via the boot-set flag, BEFORE entering the image.
    ; METAL_FLAG_ABS is the runtime data slot's absolute vaddr, derived by
    ; build_k6b.sh into entry.inc (its file offset + 0x400078).
    mov     rax, METAL_FLAG_ABS
    mov     byte [rax], 1

    ; Fill the TSS descriptor + rsp0 (ring-0 stack for any ring-3 trap) + LTR —
    ; same as K6a; a ring-3 fault must land on a valid kernel stack.
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
    mov     rax, k6a_kstack_top
    mov     [k6a_tss + 4], rax
    mov     word [k6a_tss + 102], 104
    mov     ax, gdt64.tss
    ltr     ax

    ; iretq -> ring 3 at LA_ENTRY (the LA image's prol). IF clear (no timer in the
    ; K6b gate; the image only prints + exits), reserved bit 1 set. The user RSP is
    ; the same tall stack the ring-0 image uses (0x8000000 = 128 MiB, inside the
    ; user-mapped low 1 GiB, above the 7 MiB stack-guard window).
    push    qword 0x18 | 3              ; SS = user data, RPL 3
    push    qword LA_STACK_TOP          ; user RSP
    push    qword 0x002                ; RFLAGS (IF clear, reserved bit 1)
    push    qword 0x20 | 3             ; CS = user code, RPL 3
    push    qword LA_ENTRY             ; RIP = the LA image prol (now user-mapped)
    iretq
%elifdef K6C
    ; ===== K6c: ring-3 payload that round-trips a typed message through a =====
    ; ===== kernel channel (send -> recv) — the IPC syscall service layer.  =====
    ; Same ring-3 machinery as K6a (one U=1 page at 256 MiB, TSS, iretq); the
    ; payload additionally exercises the new send/recv syscalls, so the message
    ; it prints came BACK OUT of a kernel-held channel it deposited it into — the
    ; bytes on serial prove IPC crossed ring3->ring0(channel)->ring3 both ways.
    ; STAR[63:48]=0x10 so sysretq returns to CS=0x20|3 / SS=0x18|3 (ring 3).
    mov     ecx, 0xC0000081             ; IA32_STAR
    xor     eax, eax
    mov     edx, (0x10 << 16) | 0x08    ; [47:32]=0x08 (syscall), [63:48]=0x10 (sysret)
    wrmsr

    ; Map the 256 MiB 2 MiB-page (PD[128]) USER (0x87), U=1 down PML4[0]/PDPT[0]
    ; too — exactly as K6a. The kernel channel lives in ring-0 .bss (supervisor),
    ; touched only by the syscall handlers, so it needs no user mapping.
    or      dword [pml4], 0x04
    or      dword [pdpt], 0x04
    mov     dword [pd + 128*8], 0x10000000 | 0x87
    mov     dword [pd + 128*8 + 4], 0
    mov     rax, cr3
    mov     cr3, rax                    ; flush TLB

    cld
    mov     rsi, k6c_payload
    mov     edi, 0x10000000
    mov     ecx, k6c_blob_len
    rep     movsb

    ; Fill the TSS descriptor + rsp0 + LTR (identical to K6a).
    mov     rax, k6a_tss
    mov     word [gdt64 + gdt64.tss], 103
    mov     word [gdt64 + gdt64.tss + 2], ax
    shr     rax, 16
    mov     byte [gdt64 + gdt64.tss + 4], al
    mov     byte [gdt64 + gdt64.tss + 5], 0x89
    mov     byte [gdt64 + gdt64.tss + 6], 0
    shr     rax, 8
    mov     byte [gdt64 + gdt64.tss + 7], al
    mov     rax, k6a_tss
    shr     rax, 32
    mov     dword [gdt64 + gdt64.tss + 8], eax
    mov     dword [gdt64 + gdt64.tss + 12], 0
    mov     rax, k6a_kstack_top
    mov     [k6a_tss + 4], rax
    mov     word [k6a_tss + 102], 104
    mov     ax, gdt64.tss
    ltr     ax

    ; iretq -> ring 3 at the copied payload on the user page.
    push    qword 0x18 | 3              ; SS = user data, RPL 3
    push    qword 0x101F0000           ; user RSP (top of stack in the user page)
    push    qword 0x202                ; RFLAGS (IF set, reserved bit 1)
    push    qword 0x20 | 3             ; CS = user code, RPL 3
    push    qword 0x10000000           ; RIP = the copied payload
    iretq
%elifdef K6C2
    ; ===== K6c2: TWO ring-3 tasks exchange a typed message through kernel  =====
    ; ===== channels, with a real kernel context switch (cooperative yield). =====
    ; Same ring-3 machinery as K6a/K6c (one U=1 page at 256 MiB, TSS). Both tasks
    ; share that page but have SEPARATE stacks + SEPARATE saved contexts (PCBs), so
    ; the kernel switching between them is a genuine ring-3 context switch. (True
    ; per-process address spaces are HH2; this is two ring-3 tasks, shared page.)
    mov     ecx, 0xC0000081             ; IA32_STAR
    xor     eax, eax
    mov     edx, (0x10 << 16) | 0x08    ; [47:32]=0x08 (syscall CS), [63:48]=0x10 (sysret)
    wrmsr

    ; Map the 256 MiB 2 MiB-page USER (0x87), U=1 down PML4[0]/PDPT[0] (as K6a).
    or      dword [pml4], 0x04
    or      dword [pdpt], 0x04
    mov     dword [pd + 128*8], 0x10000000 | 0x87
    mov     dword [pd + 128*8 + 4], 0
    mov     rax, cr3
    mov     cr3, rax                    ; flush TLB

    ; Copy task A's payload to 0x10000000 and task B's to 0x10010000 (both inside
    ; the one 2 MiB user page; 64 KiB apart is ample for A's code).
    cld
    mov     rsi, k6c2_pa
    mov     edi, 0x10000000
    mov     ecx, k6c2_pa_len
    rep     movsb
    mov     rsi, k6c2_pb
    mov     edi, 0x10010000
    mov     ecx, k6c2_pb_len
    rep     movsb

    ; Fill the TSS descriptor + rsp0 + LTR (identical to K6a).
    mov     rax, k6a_tss
    mov     word [gdt64 + gdt64.tss], 103
    mov     word [gdt64 + gdt64.tss + 2], ax
    shr     rax, 16
    mov     byte [gdt64 + gdt64.tss + 4], al
    mov     byte [gdt64 + gdt64.tss + 5], 0x89
    mov     byte [gdt64 + gdt64.tss + 6], 0
    shr     rax, 8
    mov     byte [gdt64 + gdt64.tss + 7], al
    mov     rax, k6a_tss
    shr     rax, 32
    mov     dword [gdt64 + gdt64.tss + 8], eax
    mov     dword [gdt64 + gdt64.tss + 12], 0
    mov     rax, k6a_kstack_top
    mov     [k6a_tss + 4], rax
    mov     word [k6a_tss + 102], 104
    mov     ax, gdt64.tss
    ltr     ax

    ; Zero both PCBs (2 * 128 bytes = 32 qwords), then seed each with its entry
    ; rip (rcx slot +16), rflags (r11 slot +88; IF clear — cooperative, no IRQs),
    ; and stack top (rsp slot +56). k6c2_run then launches task 0 via sysret.
    mov     rdi, k6c2_pcb
    xor     rax, rax
    mov     ecx, 2 * PCB_SIZE / 8
    rep     stosq
    mov     r8, k6c2_pcb
    mov     qword [r8 + 16], 0x10000000     ; A: entry rip
    mov     qword [r8 + 88], 0x002          ; A: rflags (IF clear)
    mov     qword [r8 + 56], 0x10100000     ; A: stack top (grows down)
    mov     qword [r8 + PCB_SIZE + 16], 0x10010000  ; B: entry rip
    mov     qword [r8 + PCB_SIZE + 88], 0x002       ; B: rflags
    mov     qword [r8 + PCB_SIZE + 56], 0x101F0000  ; B: stack top
    mov     qword [k6c2_cur], 0             ; start with task A
    jmp     k6c2_run
%elifdef HH1
    ; ===== HH1a: enter the higher half, prove we execute there, then hand off =====
    ; Compute the high alias of hh_high (its low link addr + HIGH_BASE) and jmp
    ; there. From hh_high on, RIP is in the −2 GiB half. Absolute data refs still
    ; resolve LOW (the identity map is kept), so serial + the low LA image work.
    mov     rax, HIGH_BASE
    lea     rbx, [rel hh_high]
    add     rax, rbx
    jmp     rax
hh_high:
    ; emit "HH1@" then the top nibble of our own (now-high) RIP as a hex digit —
    ; 'F' proves RIP is 0xFFFFFFFF8........, i.e. we really are running high.
    mov     r8, hh_msg
    mov     r9, hh_msg_len
.hh_emit:
    test    r9, r9
    jz      .hh_nib
    mov     dil, [r8]
    call    serial_putc              ; preserves r8/r9 (as .sys_write relies on)
    inc     r8
    dec     r9
    jmp     .hh_emit
.hh_nib:
    lea     rax, [rel hh_high]       ; RIP-relative -> the HIGH address now
    shr     rax, 60                  ; top nibble
    add     al, '0'
    cmp     al, '9'
    jbe     .hh_pr
    add     al, 7                    ; 0xA..0xF -> 'A'..'F'
.hh_pr:
    mov     dil, al
    call    serial_putc
    mov     dil, 10                  ; newline
    call    serial_putc
    ; hand off to the (still-low, dual-mapped) LA image — it speaks the Word.
    mov     rax, LA_ENTRY
    jmp     rax
hh_msg:     db "HH1@"
hh_msg_len  equ $ - hh_msg
%elifdef HH1B
    ; ===== HH1b: run WHOLLY in the higher half — drop the low identity map =====
    ; Jump to the high alias of hh1b_high; there, re-point LSTAR at the HIGH
    ; syscall_entry (so the LA image's write/exit work after the drop), set a HIGH
    ; stack, drop the low map (PML4[0]=0 + TLB flush), and enter the HIGH LA image
    ; (compiled by native_codegen3_hh — VADDR/RT_*/heap all at 0xFFFFFFFF80......).
    ; From then on NOTHING low is mapped: the kernel runs entirely from the −2 GiB
    ; half. (syscall takes CS/SS from the STAR MSR, not the GDT, so no GDT reload is
    ; needed for kernel.la's print+exit; there are no interrupts to need the IDT.)
    mov     rax, HIGH_BASE
    lea     rbx, [rel hh1b_high]
    add     rax, rbx
    jmp     rax
hh1b_high:
    mov     ecx, 0xC0000082             ; IA32_LSTAR
    lea     rax, [rel syscall_entry]    ; RIP-relative -> the HIGH syscall_entry now
    mov     rdx, rax
    shr     rdx, 32
    wrmsr
    mov     rax, HIGH_BASE              ; a HIGH stack for the LA image
    add     rax, LA_STACK_TOP
    mov     rsp, rax
    mov     qword [pml4], 0            ; drop the low half (pml4 written via the
    mov     rax, cr3                   ;   still-live low map), then flush the TLB —
    mov     cr3, rax                   ;   RIP/rsp are high, so execution continues
    mov     rax, LA_ENTRY              ; the HH image's HIGH e_entry
    jmp     rax
%elifdef HH2
    ; ===== HH2: per-process page tables — prove address-space ISOLATION =====
    ; Jump high (kernel runs from the shared PML4[511]), build TWO process PML4s
    ; that share the kernel high half but map the SAME low virtual page to DIFFERENT
    ; physical frames, then switch CR3 between them: a write under one process is
    ; invisible to the other. That is isolated address spaces — the process-model
    ; foundation HH1 unlocked (kernel high, low half free per-process).
    mov     rax, HIGH_BASE
    lea     rbx, [rel hh2_high]
    add     rax, rbx
    jmp     rax
hh2_high:
    ; build PML4_A: [511]=kernel(pdpt_high) shared, [0]=pdpt_A->pd_A->pd_A[3]=FRAME_A
    ; (written through the low identity map, still live before the first CR3 switch)
    mov     eax, pdpt_high
    or      eax, 0x03
    mov     [pml4_A + 511*8], eax
    mov     dword [pml4_A + 511*8 + 4], 0
    mov     eax, pdpt_A
    or      eax, 0x03
    mov     [pml4_A], eax
    mov     dword [pml4_A + 4], 0
    mov     eax, pd_A
    or      eax, 0x03
    mov     [pdpt_A], eax
    mov     dword [pdpt_A + 4], 0
    mov     dword [pd_A + 3*8], 0x2000000 | 0x83    ; VA 6 MiB -> phys 32 MiB (A)
    mov     dword [pd_A + 3*8 + 4], 0
    ; build PML4_B: same shape, pd_B[3] = FRAME_B (34 MiB)
    mov     eax, pdpt_high
    or      eax, 0x03
    mov     [pml4_B + 511*8], eax
    mov     dword [pml4_B + 511*8 + 4], 0
    mov     eax, pdpt_B
    or      eax, 0x03
    mov     [pml4_B], eax
    mov     dword [pml4_B + 4], 0
    mov     eax, pd_B
    or      eax, 0x03
    mov     [pdpt_B], eax
    mov     dword [pdpt_B + 4], 0
    mov     dword [pd_B + 3*8], 0x2200000 | 0x83    ; VA 6 MiB -> phys 34 MiB (B)
    mov     dword [pd_B + 3*8 + 4], 0
    ; a HIGH stack — mapped via the shared [511] under EITHER process PML4
    mov     rax, HIGH_BASE
    add     rax, LA_STACK_TOP
    mov     rsp, rax
    ; --- the isolation test (r10 = the shared test virtual address) ---
    mov     r10, 0x600000
    mov     eax, pml4_A
    mov     cr3, rax                    ; enter process A's address space
    mov     byte [r10], 0xAA           ; A writes ITS frame at VA 6 MiB
    mov     eax, pml4_B
    mov     cr3, rax                    ; enter process B — same VA, its OWN frame
    mov     byte [r10], 0xBB
    mov     bl, [r10]                   ; bl = B's value (0xBB)
    mov     eax, pml4_A
    mov     cr3, rax                    ; back to A
    mov     al, [r10]                   ; al = A's value — 0xAA iff B could not touch it
    cmp     al, 0xAA
    jne     .hh2_fail
    cmp     bl, 0xBB
    jne     .hh2_fail
    lea     r8, [rel hh2_ok]            ; RIP-relative -> HIGH addr (via shared [511])
    mov     r9, hh2_ok_len
    jmp     .hh2_emit
.hh2_fail:
    lea     r8, [rel hh2_bad]
    mov     r9, hh2_bad_len
.hh2_emit:
    test    r9, r9
    jz      .hh2_done
    mov     dil, [r8]
    call    serial_putc
    inc     r8
    dec     r9
    jmp     .hh2_emit
.hh2_done:
    mov     al, DBG_OK
    mov     dx, DBG_EXIT
    out     dx, al                      ; QEMU exit 33
    cli
.hh2_hang:
    hlt
    jmp     .hh2_hang
hh2_ok:      db "HH2 ISOLATED A=AA B=BB", 10
hh2_ok_len   equ $ - hh2_ok
hh2_bad:     db "HH2 LEAK (not isolated)", 10
hh2_bad_len  equ $ - hh2_bad
%elifdef HH2B
    ; ===== per-process LA PROCESS: a ring-3 LA image in its OWN PML4, kernel high ==
    ; The real process model, one process: the kernel runs in the shared high half
    ; (PML4[511]); the process has its OWN PML4 whose LOW half (U=1) holds the LA
    ; image + heap + stack and whose HIGH half shares the kernel (supervisor). CR3 =
    ; the process; the LA image runs at ring 3, its syscalls entering the HIGH kernel.
    ; STAR[63:48]=0x10 so the LA image's write/exit sysret to ring 3 (as K6b).
    mov     ecx, 0xC0000081
    xor     eax, eax
    mov     edx, (0x10 << 16) | 0x08
    wrmsr
    mov     rax, HIGH_BASE              ; run the kernel from the high half
    lea     rbx, [rel hh2b_high]
    add     rax, rbx
    jmp     rax
hh2b_high:
    mov     ecx, 0xC0000082             ; LSTAR -> the HIGH syscall_entry
    lea     rax, [rel syscall_entry]
    mov     rdx, rax
    shr     rdx, 32
    wrmsr
    ; build the PROCESS page tables via the still-live low identity map:
    ;   PML4_proc[0]=pdpt_proc|7 (USER low half), PML4_proc[511]=pdpt_high|3 (kernel,
    ;   SUPERVISOR — so ring 3 cannot reach the kernel via the high alias);
    ;   pdpt_proc[0]=pd_proc|7 ; pd_proc[i]=i*2MiB|0x87 (low 1 GiB, U=1)
    mov     eax, pdpt_proc
    or      eax, 0x07
    mov     [pml4_proc], eax
    mov     dword [pml4_proc + 4], 0
    mov     eax, pdpt_high
    or      eax, 0x03
    mov     [pml4_proc + 511*8], eax
    mov     dword [pml4_proc + 511*8 + 4], 0
    mov     eax, pd_proc
    or      eax, 0x07
    mov     [pdpt_proc], eax
    mov     dword [pdpt_proc + 4], 0
    xor     ecx, ecx
    mov     edi, pd_proc
.hh2b_fill:
    mov     eax, ecx
    shl     eax, 21
    or      eax, 0x87                   ; present|writable|user|PS (2 MiB)
    mov     [edi], eax
    mov     dword [edi + 4], 0
    add     edi, 8
    inc     ecx
    cmp     ecx, 512
    jne     .hh2b_fill
    ; TSS: rsp0 = a HIGH kernel stack (a ring-3 trap must land in the high kernel)
    mov     rax, k6a_tss
    mov     word [gdt64 + gdt64.tss], 103
    mov     word [gdt64 + gdt64.tss + 2], ax
    shr     rax, 16
    mov     byte [gdt64 + gdt64.tss + 4], al
    mov     byte [gdt64 + gdt64.tss + 5], 0x89
    mov     byte [gdt64 + gdt64.tss + 6], 0
    shr     rax, 8
    mov     byte [gdt64 + gdt64.tss + 7], al
    mov     rax, k6a_tss
    shr     rax, 32
    mov     dword [gdt64 + gdt64.tss + 8], eax
    mov     dword [gdt64 + gdt64.tss + 12], 0
    mov     rax, HIGH_BASE
    add     rax, k6a_kstack_top
    mov     [k6a_tss + 4], rax
    mov     word [k6a_tss + 102], 104
    mov     ax, gdt64.tss
    ltr     ax
    mov     eax, pml4_proc              ; enter the process address space
    mov     cr3, rax
    mov     rax, METAL_FLAG_ABS         ; LA runtime metal path (now mapped via [0])
    mov     byte [rax], 1
    push    qword 0x18 | 3              ; iretq -> ring 3 at the LA image (low, U=1)
    push    qword LA_STACK_TOP
    push    qword 0x002
    push    qword 0x20 | 3
    push    qword LA_ENTRY
    iretq
%elifdef HH2C
    ; ===== TWO isolated LA processes exchange a typed message via the channel =====
    ; One image template (@0x400000) is copied into two offset-mapped per-process
    ; regions: A at phys +128 MiB, B at phys +256 MiB. Each process's PML4 maps its
    ; OWN region into the low half (U=1) and shares the kernel [511] (supervisor),
    ; so A cannot see B's memory. A role byte (poked per copy) makes the SAME image
    ; send under A / recv under B; the message crosses through the SHARED kernel
    ; channel. A returns -> exit; the kernel's .sys_exit switches CR3 to B.
    mov     ecx, 0xC0000081             ; STAR: sysret -> ring 3 (as K6b)
    xor     eax, eax
    mov     edx, (0x10 << 16) | 0x08
    wrmsr
    mov     rax, HIGH_BASE              ; run the kernel from the high half
    lea     rbx, [rel hh2c_high]
    add     rax, rbx
    jmp     rax
hh2c_high:
    mov     ecx, 0xC0000082             ; LSTAR -> high syscall_entry
    lea     rax, [rel syscall_entry]
    mov     rdx, rax
    shr     rdx, 32
    wrmsr
    ; build PML4_A: [0]=pdpt_A->pd_A (offset +128 MiB, U=1), [511]=kernel supervisor
    mov     eax, pdpt_A
    or      eax, 0x07
    mov     [pml4_A], eax
    mov     dword [pml4_A + 4], 0
    mov     eax, pdpt_high
    or      eax, 0x03
    mov     [pml4_A + 511*8], eax
    mov     dword [pml4_A + 511*8 + 4], 0
    mov     eax, pd_A
    or      eax, 0x07
    mov     [pdpt_A], eax
    mov     dword [pdpt_A + 4], 0
    xor     ecx, ecx
    mov     edi, pd_A
.hh2c_pda:
    mov     eax, ecx
    shl     eax, 21
    add     eax, 0x8000000              ; AOFF = 128 MiB
    or      eax, 0x87
    mov     [edi], eax
    mov     dword [edi + 4], 0
    add     edi, 8
    inc     ecx
    cmp     ecx, 64                     ; map virtual 0..128 MiB
    jne     .hh2c_pda
    ; build PML4_B: same, offset +256 MiB
    mov     eax, pdpt_B
    or      eax, 0x07
    mov     [pml4_B], eax
    mov     dword [pml4_B + 4], 0
    mov     eax, pdpt_high
    or      eax, 0x03
    mov     [pml4_B + 511*8], eax
    mov     dword [pml4_B + 511*8 + 4], 0
    mov     eax, pd_B
    or      eax, 0x07
    mov     [pdpt_B], eax
    mov     dword [pdpt_B + 4], 0
    xor     ecx, ecx
    mov     edi, pd_B
.hh2c_pdb:
    mov     eax, ecx
    shl     eax, 21
    add     eax, 0x10000000            ; BOFF = 256 MiB
    or      eax, 0x87
    mov     [edi], eax
    mov     dword [edi + 4], 0
    add     edi, 8
    inc     ecx
    cmp     ecx, 64
    jne     .hh2c_pdb
    ; copy the image template into A's and B's image slots (via the low identity map)
    cld
    mov     esi, 0x400000
    mov     edi, 0x8400000             ; AOFF + 0x400000 = 132 MiB
    mov     ecx, IMAGE_LEN
    rep     movsb
    mov     esi, 0x400000
    mov     edi, 0x10400000           ; BOFF + 0x400000 = 260 MiB
    mov     ecx, IMAGE_LEN
    rep     movsb
    mov     byte [0x8380000], 0       ; role: A = sender
    mov     byte [0x10380000], 1      ; role: B = receiver
    ; The per-process low half is OFFSET-mapped, so the GDT/TSS at their LOW virtual
    ; addresses would resolve to the wrong frame under a process CR3. Put them in the
    ; HIGH half instead (reachable via the shared [511] under EITHER process): build
    ; the TSS descriptor with a HIGH base, and load a HIGH GDTR (persists across the
    ; CR3 switches, so both A's and B's iretq read a valid GDT). Written into the low
    ; GDT via the still-live low identity map; read back via the high alias.
    mov     rax, HIGH_BASE
    add     rax, k6a_tss                ; TSS base = high alias
    mov     word [gdt64 + gdt64.tss], 103
    mov     word [gdt64 + gdt64.tss + 2], ax
    shr     rax, 16
    mov     byte [gdt64 + gdt64.tss + 4], al
    mov     byte [gdt64 + gdt64.tss + 5], 0x89
    mov     byte [gdt64 + gdt64.tss + 6], 0
    shr     rax, 8
    mov     byte [gdt64 + gdt64.tss + 7], al
    mov     rax, HIGH_BASE
    add     rax, k6a_tss
    shr     rax, 32
    mov     dword [gdt64 + gdt64.tss + 8], eax
    mov     dword [gdt64 + gdt64.tss + 12], 0
    mov     rax, HIGH_BASE
    add     rax, k6a_kstack_top
    mov     [k6a_tss + 4], rax          ; rsp0 = high kernel stack
    mov     word [k6a_tss + 102], 104
    mov     ax, [gdt64.ptr]             ; GDT limit
    mov     [hh2c_gdtr], ax
    lea     rax, [rel gdt64]            ; RIP-relative -> HIGH gdt64
    mov     [hh2c_gdtr + 2], rax
    lgdt    [hh2c_gdtr]                 ; GDTR base now HIGH (survives CR3 switches)
    mov     ax, gdt64.tss
    ltr     ax
    ; enter process A (its send()s land in the shared channel; on return -> exit,
    ; and .sys_exit switches CR3 to process B — see the HH2C branch there)
    mov     eax, pml4_A
    mov     cr3, rax
    mov     rax, METAL_FLAG_ABS
    mov     byte [rax], 1
    push    qword 0x18 | 3
    push    qword LA_STACK_TOP
    push    qword 0x002
    push    qword 0x20 | 3
    push    qword LA_ENTRY
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
%ifdef IPC
    cmp     rax, SYS_SEND
    je      .sys_send
    cmp     rax, SYS_RECV
    je      .sys_recv
%endif
%ifdef K6C2
    cmp     rax, SYS_YIELD
    je      .sys_yield
%endif
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
%ifdef IPC
.sys_send:
    ; send(rdi=chan, rsi=type, rdx=buf, r10=len) -> deposit a typed message into
    ; kernel channel[chan]. Returns len, or -1 on a bad chan / oversized body.
    ; Uses only rax/rdx/r8/r9/r10/al — preserves rcx (return rip) and r11 (rflags)
    ; for sysret, exactly as .sys_write does. (r10 is the syscall ABI's 4th arg.)
    cmp     rdi, K6C_NCHAN
    jae     .ipc_err
    cmp     r10, K6C_BODYCAP
    ja      .ipc_err
    mov     rax, rdi
    imul    rax, rax, K6C_SLOTSZ
    lea     r8, [rel k6c_chans]
    add     r8, rax                     ; r8 = &channel[chan]
    mov     [r8 + 8], rsi               ; type
    mov     [r8 + 16], r10              ; len
    xor     r9, r9
.send_cp:
    cmp     r9, r10
    jae     .send_done
    mov     al, [rdx + r9]              ; copy from the caller's (ring-3) buffer
    mov     [r8 + 24 + r9], al
    inc     r9
    jmp     .send_cp
.send_done:
    mov     qword [r8], 1               ; full = 1 (message present)
    mov     rax, r10                    ; return len
    jmp     .ret
.sys_recv:
    ; recv(rdi=chan, rsi=outbuf, rdx=maxlen) -> withdraw the message. Returns
    ; rax = len (bytes copied to outbuf) AND rdx = type (a SECOND return value the
    ; ring-3 caller reads after sysret — sysret preserves rdx); -1 if the chan is
    ; bad or empty. Marks the slot empty (consume-once).
    cmp     rdi, K6C_NCHAN
    jae     .ipc_err
    mov     rax, rdi
    imul    rax, rax, K6C_SLOTSZ
    lea     r8, [rel k6c_chans]
    add     r8, rax                     ; r8 = &channel[chan]
    cmp     qword [r8], 0               ; full?
    je      .ipc_err                    ; empty -> -1
    mov     r10, [r8 + 16]              ; stored len
    cmp     r10, rdx                    ; clamp to caller's maxlen
    jbe     .recv_len_ok
    mov     r10, rdx
.recv_len_ok:
    xor     r9, r9
.recv_cp:
    cmp     r9, r10
    jae     .recv_done
    mov     al, [r8 + 24 + r9]
    mov     [rsi + r9], al              ; copy into the caller's (ring-3) buffer
    inc     r9
    jmp     .recv_cp
.recv_done:
    mov     qword [r8], 0               ; consumed -> empty
    mov     rdx, [r8 + 8]               ; type -> second return value
    mov     rax, r10                    ; len -> primary return value
    jmp     .ret
.ipc_err:
    mov     rax, -1
    jmp     .ret
%endif
%ifdef K6C2
.sys_yield:
    ; yield() -> save the calling ring-3 task's FULL context into PCB[cur], flip
    ; k6c2_cur, and resume the other task (k6c2_run). On entry (a ring-3 `syscall`):
    ; rcx = resume rip, r11 = resume rflags, rsp = the task's user rsp (syscall does
    ; NOT switch rsp), all other GP regs = the task's live values. We need rax + one
    ; base register free to address the PCB, so we stash them in k6c2_scratch first
    ; and copy them into the PCB from there — every register is saved exactly.
    mov     [k6c2_scratch], r8          ; stash r8 (base scratch)
    mov     [k6c2_scratch + 8], rax     ; stash rax (index math scratch)
    mov     r8, k6c2_pcb
    mov     rax, [k6c2_cur]
    imul    rax, rax, PCB_SIZE
    add     r8, rax                     ; r8 = &PCB[cur]
    mov     rax, [k6c2_scratch + 8]     ; original rax
    mov     [r8 + 0], rax
    mov     rax, [k6c2_scratch]         ; original r8
    mov     [r8 + 64], rax
    mov     [r8 + 8], rbx
    mov     [r8 + 16], rcx              ; resume rip (sysret target)
    mov     [r8 + 24], rdx
    mov     [r8 + 32], rsi
    mov     [r8 + 40], rdi
    mov     [r8 + 48], rbp
    mov     [r8 + 56], rsp              ; user rsp (never disturbed above)
    mov     [r8 + 72], r9
    mov     [r8 + 80], r10
    mov     [r8 + 88], r11              ; resume rflags (sysret restores)
    mov     [r8 + 96], r12
    mov     [r8 + 104], r13
    mov     [r8 + 112], r14
    mov     [r8 + 120], r15
    mov     rax, [k6c2_cur]             ; flip current task 0<->1
    xor     rax, 1
    mov     [k6c2_cur], rax
    jmp     k6c2_run
%endif
.sys_exit:
%ifdef HH2C
    ; HH2c process scheduler: the FIRST exit is process A finishing (it has already
    ; send()'d into the shared channel) -> switch CR3 to process B and enter it; the
    ; SECOND exit is B finishing -> fall through to the real halt/QEMU-exit. B's
    ; recv() withdraws A's message from the same shared kernel channel.
    cmp     byte [rel hh2c_stage], 0
    jne     .hh2c_halt
    mov     byte [rel hh2c_stage], 1
    mov     eax, pml4_B
    mov     cr3, rax
    mov     rax, METAL_FLAG_ABS
    mov     byte [rax], 1
    push    qword 0x18 | 3
    push    qword LA_STACK_TOP
    push    qword 0x002
    push    qword 0x20 | 3
    push    qword LA_ENTRY
    iretq
.hh2c_halt:
%endif
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
%ifdef RING3
    ; Ring-3 caller (K6a payload / K6b LA image) reached us via `syscall`; return
    ; with sysretq (CS/SS from STAR[63:48] -> ring 3, RIP=rcx, RFLAGS=r11, both
    ; preserved by .sys_write / serial_putc). RSP is unchanged (syscall never
    ; switched it).
    o64 sysret
%else
    push    r11
    popfq                           ; restore caller rflags
    jmp     rcx                      ; return to instruction after `syscall`
%endif

%ifdef K6C2
; ---------------------------------------------------------------------
;  k6c2_run — resume (or first-launch) the task selected by k6c2_cur. Loads its
;  full ring-3 context from PCB[cur] and drops to ring 3 via sysret (rip<-rcx,
;  rflags<-r11, CS/SS<-ring 3 from STAR[63:48]=0x10, rsp already loaded). One
;  routine serves BOTH the initial launch (the boot code seeds a PCB with
;  rcx=entry, r11=rflags, rsp=stack-top) and a resume after yield (the .sys_yield
;  handler saved the live context) — a fresh task and a suspended one are
;  indistinguishable here, which is the whole point of a context. r8 is the base
;  pointer throughout; its saved value is loaded LAST, right before sysret.
; ---------------------------------------------------------------------
k6c2_run:
    mov     r8, k6c2_pcb
    mov     rax, [k6c2_cur]
    imul    rax, rax, PCB_SIZE
    add     r8, rax                     ; r8 = &PCB[cur]
    mov     rsp, [r8 + 56]              ; user rsp
    mov     rcx, [r8 + 16]              ; resume rip -> sysret target
    mov     rax, [r8 + 0]
    mov     rbx, [r8 + 8]
    mov     rdx, [r8 + 24]
    mov     rsi, [r8 + 32]
    mov     rdi, [r8 + 40]
    mov     rbp, [r8 + 48]
    mov     r9,  [r8 + 72]
    mov     r10, [r8 + 80]
    mov     r11, [r8 + 88]              ; resume rflags -> sysret restores
    mov     r12, [r8 + 96]
    mov     r13, [r8 + 104]
    mov     r14, [r8 + 112]
    mov     r15, [r8 + 120]
    mov     r8,  [r8 + 64]              ; r8 last (base pointer overwritten)
    o64     sysret
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

%ifdef K6C
; ---------------------------------------------------------------------
;  K6c ring-3 user payload (in .boot32 = identity-mapped low RAM). Copied to the
;  user page 0x10000000 and run at ring 3 (position-independent: all data refs
;  are RIP-relative). It DEPOSITS a typed message ("IAM", type 7) into kernel
;  channel 0 with the send syscall, then WITHDRAWS it with recv, then writes the
;  recovered (type, body) to serial. The kernel channel is ring-0 memory a ring-3
;  task cannot touch directly, so the bytes on serial prove the message crossed
;  ring3->ring0(channel)->ring3 both ways — IPC serviced by the kernel.
; ---------------------------------------------------------------------
k6c_payload:
    ; send(chan=0, type=7, buf="IAM", len=3)  (r10 = syscall ABI's 4th arg)
    mov     eax, SYS_SEND
    xor     edi, edi
    mov     esi, 7
    lea     rdx, [rel k6c_body]
    mov     r10d, 3
    syscall
    ; recv(chan=0, outbuf=&k6c_bodyout, maxlen=3) -> rax=len, rdx=type
    mov     eax, SYS_RECV
    xor     edi, edi
    lea     rsi, [rel k6c_bodyout]      ; recv writes the body straight into the line
    mov     edx, 3
    syscall
    add     dl, '0'                     ; patch the recovered type digit
    lea     rbx, [rel k6c_tdigit]
    mov     [rbx], dl
    ; write(1, k6c_line, k6c_line_len) — the round-tripped message
    mov     eax, 1
    mov     edi, 1
    lea     rsi, [rel k6c_line]
    mov     edx, k6c_line_len
    syscall
    ; exit(0)
    mov     eax, 60
    xor     edi, edi
    syscall
k6c_body:     db "IAM"                  ; body handed to send
k6c_line:     db "K6C t"                ; printed after the round-trip
k6c_tdigit:   db "0"                    ; <- recovered type
              db " "
k6c_bodyout:  db "___"                  ; <- recv writes the recovered body (3 bytes)
              db 10
k6c_line_len  equ $ - k6c_line
k6c_blob_len  equ $ - k6c_payload
%endif

%ifdef K6C2
; ---------------------------------------------------------------------
;  K6c2 ring-3 task payloads (in .boot32; copied to the user page and run at ring
;  3, so position-independent — all data refs RIP-relative). Task A sends a typed
;  message and yields; the kernel switches to task B, which receives it (proving
;  the message survived the ring-0 channel across the switch), announces it, sends
;  a reply, and yields BACK; the kernel restores A, which receives the reply and
;  announces it. Two serial lines from two ring-3 contexts, IPC both ways, and
;  A's line only appears if its context was correctly SAVED and RESTORED.
; ---------------------------------------------------------------------
k6c2_pa:                                ; task A
    ; send(chan=0, type=7, "IAM", 3)
    mov     eax, SYS_SEND
    xor     edi, edi
    mov     esi, 7
    lea     rdx, [rel k6c2_a_body]
    mov     r10d, 3
    syscall
    ; yield -> kernel saves A, switches to B
    mov     eax, SYS_YIELD
    syscall
    ; (resumed here after B yields back) recv(chan=1, &k6c2_a_out, 3) -> the reply
    mov     eax, SYS_RECV
    mov     edi, 1
    lea     rsi, [rel k6c2_a_out]        ; recv writes the reply body into the line
    mov     edx, 3
    syscall
    ; write "K6C2 A got YOU\n"
    mov     eax, 1
    mov     edi, 1
    lea     rsi, [rel k6c2_a_line]
    mov     edx, k6c2_a_line_len
    syscall
    ; exit -> halts the machine (B's tail below is then unreached)
    mov     eax, 60
    xor     edi, edi
    syscall
k6c2_a_body:  db "IAM"
k6c2_a_line:  db "K6C2 A got "
k6c2_a_out:   db "___"
              db 10
k6c2_a_line_len equ $ - k6c2_a_line
k6c2_pa_len   equ $ - k6c2_pa

k6c2_pb:                                ; task B
    ; recv(chan=0, &k6c2_b_out, 3) -> A's message
    mov     eax, SYS_RECV
    xor     edi, edi
    lea     rsi, [rel k6c2_b_out]
    mov     edx, 3
    syscall
    ; write "K6C2 B got IAM\n"
    mov     eax, 1
    mov     edi, 1
    lea     rsi, [rel k6c2_b_line]
    mov     edx, k6c2_b_line_len
    syscall
    ; send(chan=1, type=8, "YOU", 3) — the reply back to A
    mov     eax, SYS_SEND
    mov     edi, 1
    mov     esi, 8
    lea     rdx, [rel k6c2_b_reply]
    mov     r10d, 3
    syscall
    ; yield -> kernel restores A
    mov     eax, SYS_YIELD
    syscall
    ; (unreached: A exits the machine before yielding again)
    mov     eax, 60
    xor     edi, edi
    syscall
k6c2_b_line:  db "K6C2 B got "
k6c2_b_out:   db "___"
              db 10
k6c2_b_reply: db "YOU"
k6c2_b_line_len equ $ - k6c2_b_line
k6c2_pb_len   equ $ - k6c2_pb
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
%ifdef RING3
; Ring-3 selectors (K6a payload + K6b LA image). Ordered for SYSRET: with
; STAR[63:48]=0x10, sysretq loads CS = 0x10+16 = 0x20 (user code) and
; SS = 0x10+8 = 0x18 (user data), both RPL 3.
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
%ifdef HAL4
; HAL.4: three more PD tables to identity-map 1..4 GiB (PDPT[1..3]), so high
; MMIO BARs — the VGA linear framebuffer QEMU maps near ~0xFD000000 — are
; reachable by the LA image's poke. Contiguous so the fill loop treats them as
; one 1536-entry array. Guarded, so non-HAL4 kernels are byte-identical.
pd_hi1: resb 4096
pd_hi2: resb 4096
pd_hi3: resb 4096
%endif
%ifdef HH1_HIGHMAP
align 4096
pdpt_high: resb 4096                    ; HH1: PML4[511] -> here -> [510] -> pd
%endif
%ifdef HH2_PTS
align 4096
pml4_A:  resb 4096                      ; HH2/HH2c: process A's page tables (own low half)
pdpt_A:  resb 4096
pd_A:    resb 4096
pml4_B:  resb 4096                      ; process B (own low half)
pdpt_B:  resb 4096
pd_B:    resb 4096
%endif
%ifdef HH2C
hh2c_stage: resb 1                      ; 0 = A running, 1 = B (the exit-driven switch)
align 8
hh2c_gdtr:  resb 10                     ; a HIGH-based GDTR (limit:2 + base:8)
%endif
%ifdef HH2B
align 4096
pml4_proc: resb 4096                    ; HH2b: the process's own PML4 ([0]=user low,
pdpt_proc: resb 4096                    ;   [511]=kernel high shared); low 1 GiB U=1
pd_proc:   resb 4096
%endif
align 16
boot_stack:
        resb 16384
boot_stack_top:
%ifdef RING3
align 16
k6a_tss:                                ; 104-byte 64-bit TSS (rsp0 at +4, iomap base at +102)
        resb 104
align 16
k6a_kstack:                             ; ring-0 stack the CPU switches to on a ring-3 trap (TSS.rsp0)
        resb 16384
k6a_kstack_top:
%endif
%ifdef IPC
align 16
k6c_chans:                              ; K6C_NCHAN typed mailboxes, ring-0 only
        resb K6C_NCHAN * K6C_SLOTSZ
%endif
%ifdef K6C2
align 16
k6c2_pcb:                               ; two 128-byte task contexts (PCB[0], PCB[1])
        resb 2 * PCB_SIZE
k6c2_cur:                               ; index of the currently running task
        resq 1
k6c2_scratch:                           ; 2 qwords: frees rax + a base reg in .sys_yield
        resq 2
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
; HAL.2b: IRQ-driven keyboard substrate (PIC + IRQ1). Entirely %ifdef HAL2B —
; zero bytes unless assembled with -dHAL2B, so other kernel ELFs stay identical.
%include "kbdirq.asm"

; K6a/K6c/K6c2 are payload-based ring-3 probes and HH2 is a ring-0 page-table demo
; — none jump to the LA image, so the incbin is skipped for them, keeping those
; builds self-contained.
%ifndef K6A
%ifndef K6C
%ifndef K6C2
%ifndef HH2
section .la_image
la_image_start:
incbin "native_codegen3_out"
la_image_end:
IMAGE_LEN equ la_image_end - la_image_start   ; HH2c copies this many bytes per process
%endif
%endif
%endif
%endif
