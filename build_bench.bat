@echo off
set RISCV=C:\Users\khsab\Downloads\xpack-riscv-none-elf-gcc-15.2.0-1-win32-x64\xpack-riscv-none-elf-gcc-15.2.0-1\bin
set GCC=%RISCV%\riscv-none-elf-gcc
set OBJCOPY=%RISCV%\riscv-none-elf-objcopy
set SIZE=%RISCV%\riscv-none-elf-size
set CFLAGS=-march=rv32i -mabi=ilp32 -Wl,-Bstatic,-T,sections_timer.lds,--strip-debug -ffreestanding -nostdlib -O1
set STARTUP=start_multitask.s

echo ============================================================
echo  [1/2] Building bench_dhrystone
echo ============================================================
%GCC% %CFLAGS% -o bench_dhrystone_fw.elf %STARTUP% bench_dhrystone.c -lgcc
if errorlevel 1 ( echo [ERROR] Dhrystone compile failed & pause & exit /b 1 )
%OBJCOPY% -O srec bench_dhrystone_fw.elf bench_dhrystone.srec
%SIZE% bench_dhrystone_fw.elf
echo  -> bench_dhrystone.srec ready
echo.

echo ============================================================
echo  [2/2] Building bench_irq_latency
echo ============================================================
%GCC% %CFLAGS% -o bench_irq_latency_fw.elf %STARTUP% bench_irq_latency.c -lgcc
if errorlevel 1 ( echo [ERROR] IRQ latency compile failed & pause & exit /b 1 )
%OBJCOPY% -O srec bench_irq_latency_fw.elf bench_irq_latency.srec
%SIZE% bench_irq_latency_fw.elf
echo  -> bench_irq_latency.srec ready
echo.

echo ============================================================
echo  Build done!
echo  1. Connect TeraTerm (115200 baud), wait for rv32^> prompt
echo  2. File -^> Send File -^> bench_dhrystone.srec
echo  3. After results, replug USB to reset
echo  4. File -^> Send File -^> bench_irq_latency.srec
echo ============================================================
pause
