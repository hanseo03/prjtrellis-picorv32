@echo off
REM ============================================================
REM  이름만 바꾸면 됨
set PROG=button_demo
REM ============================================================

set RISCV=C:\Users\khsab\Downloads\xpack-riscv-none-elf-gcc-15.2.0-1-win32-x64\xpack-riscv-none-elf-gcc-15.2.0-1\bin

echo === %PROG% 빌드 ===

echo [1/3] 컴파일 중...
%RISCV%\riscv-none-elf-gcc -march=rv32i -mabi=ilp32 ^
  -Wl,-Bstatic,-T,sections_user.lds,--strip-debug ^
  -ffreestanding -nostdlib ^
  -o %PROG%.elf start.s %PROG%.c
if errorlevel 1 ( echo 오류: 컴파일 실패 & exit /b 1 )

echo [2/3] SREC 변환 중...
%RISCV%\riscv-none-elf-objcopy -O srec %PROG%.elf %PROG%.srec
if errorlevel 1 ( echo 오류: SREC 변환 실패 & exit /b 1 )

echo [3/3] 완료!
dir %PROG%.elf %PROG%.srec
echo.
echo 다음 단계: TeraTerm rv32^> 에서 %PROG%.srec 전송