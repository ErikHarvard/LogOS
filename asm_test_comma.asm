; a52cf39 regression: a comma is a TOKEN, and operands are comma-delimited
; GROUPS — not whitespace. The discriminating case is a data directive whose
; value is a SPACED expression versus a comma-separated list:
;
;   dw gdt_end - gdt64 - 1    is ONE word  (a GDT limit, = 15)
;   dw 1, 2                   is TWO words (01 00 02 00)
;
; The pre-a52cf39 tokenizer treated ',' as whitespace, so both produced the same
; flat token list and the data directive split the EXPRESSION at its spaces —
; `dw gdt_end - gdt64 - 1` emitted two words, the second being -gdt64-1 = -1.
; asm_test_data covers `dw 1, 2` and `dq start`, but nothing carried a spaced
; expression inside a data directive, so a %macro-style coverage hole hid this
; behaviour. This fixture fails byte-identity on the old tokenizer.
bits 64
org 0

gdt64:
    dq 0x0000000000000000
    dq 0x00209a0000000000
gdt_end:

; the classic GDT-limit form — ONE word from a spaced label expression
    dw gdt_end - gdt64 - 1

; a comma LIST in the same directive kind — TWO words
    dw 1, 2

; comma-separated dword list, one carrying an expression
    dd 0x11223344, 1 + 2

; a comma between an instruction's operands, the second an expression
    mov ecx, 2 * 8 / 4
