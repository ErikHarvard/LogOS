/* link_test_script.ld — the linker-script fixture.
 *
 * Deliberately NOT the layout link.la would choose on its own: the base is
 * 0x500000, not the built-in 0x401000, so an image built at the default
 * address cannot pass the gate by accident. `ld -T` reads this same file, so
 * the addresses are neither linker's invention.
 */
ENTRY(_start)

SECTIONS {
    . = 0x500000;
    .text : { *(.text) }

    . = ALIGN(4096);
    .rodata : { *(.rodata) }
}
