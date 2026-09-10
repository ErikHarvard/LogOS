; Fixture for the two relocation types link.la CLAIMS to handle and no test
; ever produced: R_X86_64_GOT32 (3) and R_X86_64_GOTPCREL (26).
;
; ★ WHY IT EXISTS. ISGOT32 and ISGOTPC are implemented in link_reloc.la and
;   were exercised by nothing — not one link_test*.asm, not one line of
;   gate_link_reloc.sh. Two of nine handled types could have been entirely
;   broken and every suite would have stayed green. A documented capability
;   with no fixture is indistinguishable from a working one.
;
; The nasm spellings are not obvious and are worth recording:
;   [rel s wrt ..gotpc]      -> R_X86_64_GOTPCREL (26)
;   dword [s wrt ..got]      -> R_X86_64_GOT32    (3)
;   qword s wrt ..got        -> R_X86_64_GOT64    (27, already covered)
bits 64
global _start
global gotdata
section .text
_start:
    mov rax, [rel gotdata wrt ..gotpc]   ; GOTPCREL (26)
    mov ebx, dword [gotdata wrt ..got]   ; GOT32    (3)
    mov rcx, qword gotdata wrt ..got     ; GOT64    (27)
    xor eax, eax
    ret
section .data
gotdata: dq 0x5A5A5A5A
