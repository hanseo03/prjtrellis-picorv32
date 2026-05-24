@echo off
set OSS_CAD=C:\Users\khsab\Downloads\oss-cad-suite
set TRELLISDB=%OSS_CAD%\share\trellis\database
set BASECFG=%OSS_CAD%\share\trellis\misc\basecfgs\empty_lfe5u-25f.config

echo [1/3] Yosys synthesis...
yosys -p "hierarchy -top top" -p "synth_ecp5 -json picorv32.json" top.v attosoc.v picorv32.v simpleuart.v > yosys_resource.log 2>&1
if errorlevel 1 ( echo [ERROR] Yosys failed & type yosys_resource.log & exit /b 1 )

echo [2/3] nextpnr place and route (saving log)...
nextpnr-ecp5 --25k --json picorv32.json --lpf ulx3s_v20_segpdi.lpf --basecfg "%BASECFG%" --textcfg ulx3s_12f_picorv32.config > nextpnr_resource.log 2>&1
if errorlevel 1 ( echo [ERROR] nextpnr failed & exit /b 1 )

echo [3/3] ecppack bitstream...
ecppack --idcode 0x21111043 --db "%TRELLISDB%" --input ulx3s_12f_picorv32.config --bit ulx3s_12f_picorv32.bit > nul 2>&1

echo.
echo ============================================================
echo  PicoRV32 Resource Report
echo ============================================================
findstr /i "TRELLIS_SLICE\|TRELLIS_IO\|TRELLIS_RAM\|Device util\|Max freq\|Timing" nextpnr_resource.log
echo.
echo Full log: nextpnr_resource.log
echo ============================================================
pause
