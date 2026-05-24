@echo off
set PROG=multitask
set MODE=firmware
set RISCV=C:\Users\khsab\Downloads\xpack-riscv-none-elf-gcc-15.2.0-1-win32-x64\xpack-riscv-none-elf-gcc-15.2.0-1\bin

echo =============================================
echo  Build: %PROG%  [MODE=%MODE%]
echo =============================================

if "%MODE%"=="firmware" goto build_firmware
if "%MODE%"=="user"     goto build_user

echo [ERROR] MODE must be user or firmware.
exit /b 1

:build_user
echo [1/3] Compiling (start.s + %PROG%.c)...
%RISCV%\riscv-none-elf-gcc -march=rv32i -mabi=ilp32 ^
  -Wl,-Bstatic,-T,sections_user.lds,--strip-debug ^
  -ffreestanding -nostdlib ^
  -O1 ^
  -o %PROG%.elf start.s %PROG%.c -lgcc
if errorlevel 1 ( echo [ERROR] Compile failed & exit /b 1 )

echo [2/3] Converting to SREC...
%RISCV%\riscv-none-elf-objcopy -O srec %PROG%.elf %PROG%.srec
if errorlevel 1 ( echo [ERROR] objcopy failed & exit /b 1 )

echo [3/3] Done!
dir %PROG%.elf %PROG%.srec
echo.
echo  Next: send %PROG%.srec via TeraTerm rv32^>
goto end

:build_firmware
if "%PROG%"=="multitask" (
    set STARTUP=start_multitask.s
) else (
    set STARTUP=start_timer.s
)

echo [1/4] Compiling (%STARTUP% + %PROG%.c)...
%RISCV%\riscv-none-elf-gcc -march=rv32i -mabi=ilp32 ^
  -Wl,-Bstatic,-T,sections_timer.lds,--strip-debug ^
  -ffreestanding -nostdlib ^
  -O1 ^
  -o %PROG%_fw.elf %STARTUP% %PROG%.c -lgcc
if errorlevel 1 ( echo [ERROR] Compile failed & exit /b 1 )

echo [2/4] ELF to binary...
%RISCV%\riscv-none-elf-objcopy -O binary %PROG%_fw.elf %PROG%_fw.bin
if errorlevel 1 ( echo [ERROR] objcopy failed & exit /b 1 )

echo [3/4] Binary to HEX...
python3 makehex.py %PROG%_fw.bin 8192 > firmware.hex
if errorlevel 1 ( echo [ERROR] makehex.py failed & exit /b 1 )

echo [4/4] Done!
dir %PROG%_fw.elf %PROG%_fw.bin firmware.hex
echo.
echo  Next steps:
echo    1. build_fpga_only.bat
echo    2. Replug USB
echo    3. dfu-util -a 0 -D ulx3s_12f_picorv32.bit
echo    4. dfu-util -d 1d50:614b -S 5033413336330006 -a 0 -e

:end
echo =============================================
