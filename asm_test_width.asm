; Slice 1: operand WIDTHS + hex literals + size keywords + immediate-to-memory.
; Every line here is an encoding family boot.asm needs and asm.la did not cover.
bits 64

; --- hex literals at each width (asm.la was decimal-only) ---
mov al, 0x20
mov ax, 0x1234
mov eax, 0x12345678
mov rax, 0x1234

; --- the REX subtleties: ah FORBIDS a REX byte, dil/sil REQUIRE one ---
mov ah, 0x11
mov dil, 5
mov sil, dil
mov cl, dl

; --- 16-bit takes a 0x66 prefix; 32-bit takes no REX.W ---
mov dx, ax
mov ecx, edx
xor eax, eax
xor al, al

; --- extended registers at sub-64 widths (REX.B with no REX.W) ---
mov r10d, eax
mov r8b, al
mov r9w, ax
xor r10d, r10d

; --- immediate to MEMORY: needs an explicit size keyword ---
mov byte [rdi], 0
mov word [rdi + 2], 0x08
mov dword [rdi + 8], 0
mov qword [rdi], 0

; --- register/memory at each width; brackets written WITH spaces ---
mov [rdi + 0], ax
mov [rdx], al
mov eax, [rcx + 4]
mov al, [rcx]

; --- the ALU ops carry width too ---
add ecx, edx
sub al, cl
ret
