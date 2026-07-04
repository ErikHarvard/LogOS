/* LogOS kernel — K1 link layout.
 *
 * Two loadable segments:
 *   boot  @ 0x100000 (1 MiB) — multiboot header (first in file), 32->64
 *          trampoline, GDT, syscall handler, serial, page tables (bss).
 *   la    @ 0x400000 (4 MiB) — the native_codegen3 image, incbin'd, run
 *          UNMODIFIED. Its code uses absolute addresses anchored at
 *          0x400000, so this segment MUST load exactly there.
 *
 * The LA heap (worklist ~4 MiB, heap base ~68 MiB) is neither segment —
 * it is just identity-mapped RAM the boot page tables expose. K1's rt_init
 * touches the heap base, so the gate runs QEMU with >=256 MiB.
 */
ENTRY(_start)

PHDRS {
    boot PT_LOAD FLAGS(7);   /* RWX */
    la   PT_LOAD FLAGS(7);   /* RWX */
}

SECTIONS {
    . = 0x100000;

    .boot : {
        *(.multiboot)        /* keep the multiboot header first in the file */
        *(.boot32)
        *(.text)
        *(.rodata)
    } :boot

    . = ALIGN(4096);
    .bss (NOLOAD) : {
        *(.bss)
    } :boot

    . = 0x400000;
    .la_image : {
        *(.la_image)
    } :la

    /DISCARD/ : { *(.comment) *(.note*) *(.eh_frame*) }
}
