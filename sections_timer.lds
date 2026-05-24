/* sections_timer.lds
 * 스탠드얼론 타이머 펌웨어용 링커 스크립트
 * 0x0000 부터 시작 (부트로더 없음)
 * RAM 크기: 32KB (MEM_WORDS=8192 × 4바이트)
 */

MEMORY {
    RAM (xrw) : ORIGIN = 0x00000000, LENGTH = 32K
}

SECTIONS {
    /* .text.init 이 가장 먼저 — start_timer.s 의 리셋/IRQ 벡터 포함 */
    .text : {
        *(.text.init)
        *(.text .text.*)
    } > RAM

    .rodata : {
        *(.rodata .rodata.*)
    } > RAM

    .data : {
        *(.data .data.*)
    } > RAM

    .bss : {
        _bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        _bss_end = .;
    } > RAM

    . = ALIGN(4);
    _end = .;
}
