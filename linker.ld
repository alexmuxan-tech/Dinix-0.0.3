ENTRY(_start)
OUTPUT_FORMAT(elf32-i386)
SECTIONS {
    . = 0x00100000;
    .text : { *(.multiboot) *(.text) }
    .rodata : { *(.rodata) }
    .data   : { *(.data) }
    .bss    : { *(.bss) }
}
