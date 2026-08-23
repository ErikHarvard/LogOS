bits 64
org 0x400000
PCB_SIZE equ 128
NCHAN    equ 4
start:
    mov ecx, 2 * PCB_SIZE / 8
    ret
buf:
    resb NCHAN * PCB_SIZE
    resb 2 * PCB_SIZE
after:
    db 0x77
