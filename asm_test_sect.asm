; Slice 7: section / global / incbin — the last three directives boot.asm uses.
bits 64
org 0x400000
global _start
section .boot32
_start:
    nop
    ret
section .la_image
    incbin "incdata.bin"
    db 0xFF
