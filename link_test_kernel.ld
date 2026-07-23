/* link_test_kernel.ld — the fixture shaped like LogOS's own kernel link.
 *
 * This is `kernel/kernel.ld` reduced to a userspace program that can actually
 * be RUN, so the gate's strongest check still applies. It exercises the four
 * constructs the real kernel script needs and nothing else could reach:
 *
 *   PHDRS + FLAGS(7)  two segments named explicitly, RWX because the script
 *                     ASKS for it -- not because the linker inferred it;
 *   :boot on two       .text and .bss are ONE segment across a `. = ALIGN()`,
 *   output sections    which is why a segment can no longer be "one `. =` group";
 *   (NOLOAD)           .bss occupies memory and no file bytes;
 *   /DISCARD/ + a      the note/comment sections a real object carries, dropped
 *   trailing wildcard  by family rather than by exact name.
 *
 * The addresses are the kernel's own (1 MiB and 4 MiB) -- both far from the
 * built-in 0x401000, so an image laid out by the default script cannot pass.
 */
ENTRY(_start)

PHDRS {
    boot PT_LOAD FLAGS(7);
    img  PT_LOAD FLAGS(7);
}

SECTIONS {
    . = 0x100000;

    .boot : {
        *(.multiboot)
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
    } :img

    /DISCARD/ : { *(.comment) *(.note*) *(.eh_frame*) }
}
