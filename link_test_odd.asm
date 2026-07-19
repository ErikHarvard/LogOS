; A section the layout genuinely cannot place.
;
; This fixture exists because the previous one stopped discriminating. The
; section-refusal gate used a gcc object, whose .data/.bss/.eh_frame were all
; unplaceable at the time — but .data and .bss later became placeable and
; .eh_frame became explicitly droppable, so that object no longer has the
; property the gate names. It began failing for an unrelated reason
; (unresolved symbol), which the gate caught only because it asserts WHICH
; diagnostic rather than merely that the link failed.
;
; `.weird` is SHF_ALLOC — it occupies memory at run time, so the layout must
; have an answer for it — and it is not a name this linker knows. That is
; precisely the case that must be refused rather than silently skipped, since
; skipping it would give any symbol inside it an address that was never
; assigned.
bits 64

section .weird progbits alloc noexec nowrite
oddball: dq 0x1234

section .text
global greet

greet:
    ret
