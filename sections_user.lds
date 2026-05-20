/* 사용자 프로그램용 링커 스크립트
 * 부트로더가 0x000~0x3FF (1KB)를 차지하므로
 * 사용자 프로그램은 0x400부터 시작 */
MEMORY {
  RAM (xrw) : ORIGIN = 0x00000400, LENGTH = 0x007C00
}

SECTIONS {
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
    *(.bss .bss.*)
    *(COMMON)
  } > RAM

  . = ALIGN(4);
  _end = .;
}