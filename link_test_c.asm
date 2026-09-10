; Third object — the one that proves N is not 2.
;
; It defines `bump`, which object A does not reference, so this object exists
; purely to be a THIRD input: it must be placed, packed after the others, have
; its symbols resolved, and be checked against both siblings for duplicates.
;
; The point is that adding it requires NO code change — only a third line in
; link_inputs.txt. If the linker were still shaped for two objects and merely
; tidier about it, this is where that would surface.
bits 64

section .text
global bump

bump:
    inc rax
    ret
