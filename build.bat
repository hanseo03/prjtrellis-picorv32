@echo off
echo ============================================================
echo  PicoRV32 Build Script for ULX3S 12K (Windows)
echo ============================================================

set RISCV=C:\Users\khsab\Downloads\xpack-riscv-none-elf-gcc-15.2.0-1-win32-x64\xpack-riscv-none-elf-gcc-15.2.0-1\bin
set OSS_CAD=C:\Users\khsab\Downloads\oss-cad-suite
set TRELLISDB=%OSS_CAD%\share\trellis\database
set BASECFG=%OSS_CAD%\share\trellis\misc\basecfgs\empty_lfe5u-25f.config

REM ---- 1단계: 펌웨어 컴파일 (C -> ELF) ----
echo.
echo [1/5] 펌웨어 컴파일 중...
%RISCV%\riscv-none-elf-gcc -march=rv32i -mabi=ilp32 ^
  -Wl,-Bstatic,-T,sections.lds,--strip-debug ^
  -ffreestanding -nostdlib ^
  -o firmware.elf start.s firmware.c
if errorlevel 1 ( echo 오류: 펌웨어 컴파일 실패 & exit /b 1 )

REM ---- 2단계: ELF -> BIN ----
echo [2/5] 바이너리 변환 중...
%RISCV%\riscv-none-elf-objcopy -O binary firmware.elf firmware.bin
if errorlevel 1 ( echo 오류: objcopy 실패 & exit /b 1 )

REM ---- 3단계: BIN -> HEX ----
echo [3/5] HEX 변환 중...
python3 makehex.py firmware.bin 4096 > firmware.hex
if errorlevel 1 ( echo 오류: HEX 변환 실패 & exit /b 1 )

REM ---- 4단계: Yosys 합성 ----
echo.
echo [4/5] Yosys 합성 중 (시간 좀 걸려요)...
yosys -p "hierarchy -top top" -p "synth_ecp5 -json picorv32.json" ^
  top.v attosoc.v picorv32.v simpleuart.v
if errorlevel 1 ( echo 오류: Yosys 합성 실패 & exit /b 1 )

REM ---- 5단계: nextpnr 배치배선 ----
echo.
echo [5/5] nextpnr 배치배선 중 (시간 좀 걸려요)...
nextpnr-ecp5 --25k ^
  --json picorv32.json ^
  --lpf ulx3s_v20_segpdi.lpf ^
  --basecfg "%BASECFG%" ^
  --textcfg ulx3s_12f_picorv32.config
if errorlevel 1 ( echo 오류: nextpnr 실패 & exit /b 1 )

REM ---- 6단계: ecppack 비트스트림 생성 ----
ecppack --idcode 0x21111043 ^
  --db "%TRELLISDB%" ^
  --input ulx3s_12f_picorv32.config ^
  --bit ulx3s_12f_picorv32.bit
if errorlevel 1 ( echo 오류: ecppack 실패 & exit /b 1 )

echo.
echo ============================================================
echo  완료! ulx3s_12f_picorv32.bit 생성됨
echo  업로드: dfu-util -a 0 -D ulx3s_12f_picorv32.bit
echo ============================================================