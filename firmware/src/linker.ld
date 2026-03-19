/*
 * linker.ld — RV32IM SoC Memory Layout
 *
 * Memory Map (RTL 매칭):
 *   Instruction ROM: 0x0000_0000, 32KB (InstructionMemory [0:8191] × 4B)
 *   Data RAM:        0x1000_0000, 32KB (DataMemory [0:8191] × 4B)
 *   MMIO:            0x1001_xxxx ~ 0x1003_xxxx
 *   CLINT:           0x0200_0000 ~ 0x0200_000F
 *
 * $readmemh 방식이므로:
 *   - .text + .rodata → ROM 영역으로 빌드
 *   - .data + .bss    → RAM 영역으로 빌드
 *   - .data 초기값은 ROM에 복사본을 두고 crt0에서 RAM으로 복사
 */

OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 32K
    RAM (rwx) : ORIGIN = 0x10000000, LENGTH = 32K
}

_stack_top = ORIGIN(RAM) + LENGTH(RAM);

SECTIONS
{
    /* ── Code (ROM) ── */
    .text :
    {
        *(.text.init)           /* _start must be at address 0 */
        *(.text .text.*)
        . = ALIGN(4);
    } > ROM

    /* ── Read-only data (ROM) ── */
    .rodata :
    {
        *(.rodata .rodata.*)
        *(.srodata .srodata.*)
        . = ALIGN(4);
    } > ROM

    /* ── End of ROM content ── */
    _data_load = .;             /* LMA: .data 초기값이 ROM에 저장되는 위치 */

    /* ── Initialized data (RAM, 초기값은 ROM에서 복사) ── */
    .data : AT(_data_load)
    {
        _data_start = .;
        *(.data .data.*)
        *(.sdata .sdata.*)
        . = ALIGN(4);
        _data_end = .;
    } > RAM

    /* ── BSS (RAM, 0으로 초기화) ── */
    .bss :
    {
        . = ALIGN(4);
        _bss_start = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
        . = ALIGN(4);
        _bss_end = .;
    } > RAM

    /* ── Heap (FreeRTOS heap_4.c가 사용) ── */
    _heap_start = _bss_end;

    /* Global pointer for linker relaxation (middle of RAM) */
    __global_pointer$ = ORIGIN(RAM) + 0x800;
}
