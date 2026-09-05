bits 16
    test ax, bx
    test eax, ebx
    div cx
    div ecx
    neg ax
    neg eax
    idiv cx
    idiv ecx
    bsr ax, bx
    bsr eax, ebx
    imul ax, bx
    imul eax, ebx
    imul ax, bx, 7
    imul eax, ebx, 7
    cmovz ax, bx
    cmovz eax, ebx
    in ax, dx
    in eax, dx
    out dx, ax
    out dx, eax
    movzx ax, bl
    movzx eax, bl
bits 32
    test ax, bx
    test eax, ebx
    div cx
    div ecx
    neg ax
    neg eax
    bsr ax, bx
    bsr eax, ebx
    imul ax, bx
    imul eax, ebx
    cmovz ax, bx
    cmovz eax, ebx
    in ax, dx
    in eax, dx
    out dx, ax
    out dx, eax
