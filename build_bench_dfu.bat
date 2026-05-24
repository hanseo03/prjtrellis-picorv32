@echo off
:: Run benchmark via DFU (no bootloader needed)
:: Usage: set BENCH=dhrystone or irq_latency, then run

:: set BENCH=dhrystone
set BENCH=irq_latency

set RISCV=C:\Users\khsab\Downloads\xpack-riscv-none-elf-gcc-15.2.0-1-win32-x64\xpack-riscv-none-elf-gcc-15.2.0-1\bin
set OSS_CAD=C:\Users\khsab\Downloads\oss-cad-suite
set TRELLISDB=%OSS_CAD%\share\trellis\database
set BASECFG=%OSS_CAD%\share\trellis\misc\basecfgs\empty_lfe5u-25f.config
set DFU_SERIAL=5033413336330006

echo ============================================================
echo  Building benchmark: bench_%BENCH%
echo ============================================================

echo [1/5] Compile...
%RISCV%\riscv-none-elf-gcc -march=rv32i -mabi=ilp32 ^
  -Wl,-Bstatic,-T,sections_timer.lds,--strip-debug ^
  -ffreestanding -nostdlib -O1 ^
  -o bench_%BENCH%_fw.elf start_multitask.s bench_%BENCH%.c -lgcc
if errorlevel 1 ( echo [ERROR] Compile failed & pause & exit /b 1 )

echo [2/5] ELF to binary...
%RISCV%\riscv-none-elf-objcopy -O binary bench_%BENCH%_fw.elf bench_%BENCH%_fw.bin
if errorlevel 1 ( echo [ERROR] objcopy failed & pause & exit /b 1 )

echo [3/5] Binary to firmware.hex...
python3 makehex.py bench_%BENCH%_fw.bin 8192 > firmware.hex
if errorlevel 1 ( echo [ERROR] makehex.py failed & pause & exit /b 1 )

echo [4/5] Rebuild FPGA bitstream (Yosys + nextpnr)...
yosys -q -p "hierarchy -top top" -p "synth_ecp5 -json picorv32.json" top.v attosoc.v picorv32.v simpleuart.v
if errorlevel 1 ( echo [ERROR] Yosys failed & pause & exit /b 1 )
nextpnr-ecp5 --25k --json picorv32.json --lpf ulx3s_v20_segpdi.lpf --basecfg "%BASECFG%" --textcfg ulx3s_12f_picorv32.config --quiet
if errorlevel 1 ( echo [ERROR] nextpnr failed & pause & exit /b 1 )
ecppack --idcode 0x21111043 --db "%TRELLISDB%" --input ulx3s_12f_picorv32.config --bit ulx3s_12f_picorv32.bit
if errorlevel 1 ( echo [ERROR] ecppack failed & pause & exit /b 1 )

echo [5/5] Upload via DFU...
echo   -- Replug USB now, then press any key --
pause
dfu-util -a 0 -D ulx3s_12f_picorv32.bit
dfu-util -d 1d50:614b -S %DFU_SERIAL% -a 0 -e

echo.
echo Done! Open TeraTerm (115200 baud) to see results.
pause
