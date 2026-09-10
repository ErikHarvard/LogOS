; An arbitrary allocatable section the default layout must PLACE by its flags.
;
; `.weird` is SHF_ALLOC (read-only) — it occupies memory at run time, so the
; layout must have an answer for it — and it is not a name this linker knows.
; The old default layout REFUSED such a section; the default layout now groups
; allocatable sections by permission (RX / R / RW) as ld does, so `.weird` is
; placed in the R segment. Skipping it (the failure this guards against) would
; give any symbol inside it an address that was never assigned; placing it by
; flags is the fix. gate_link_reloc.sh asserts it is placed, W^X intact.
bits 64

section .weird progbits alloc noexec nowrite
oddball: dq 0x1234

section .text
global greet

greet:
    ret
