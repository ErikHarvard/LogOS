; included file — carries its own conditional, like kbdirq.asm does
%define FROM_INCLUDE
    mov ecx, 0x11
%ifdef OUTER
    mov edx, 0x22
%endif
