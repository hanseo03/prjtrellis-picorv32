@echo off
set OSS_CAD=C:\Users\khsab\Downloads\oss-cad-suite
set TRELLISDB=%OSS_CAD%\share\trellis\database
set BASECFG=%OSS_CAD%\share\trellis\misc\basecfgs\empty_lfe5u-25f.config

echo ============================================================
echo  FPGA-only build (uses existing firmware.hex)
echo ============================================================

echo [1/3] Yosys synthesis...
yosys -p "hierarchy -top top" -p "synth_ecp5 -json picorv32.json" ^
  top.v attosoc.v picorv32.v simpleuart.v
if errorlevel 1 ( echo [ERROR] Yosys failed & exit /b 1 )

echo [2/3] nextpnr place and route...
nextpnr-ecp5 --25k ^
  --json picorv32.json ^
  --lpf ulx3s_v20_segpdi.lpf ^
  --basecfg "%BASECFG%" ^
  --textcfg ulx3s_12f_picorv32.config
if errorlevel 1 ( echo [ERROR] nextpnr failed & exit /b 1 )

echo [3/3] ecppack bitstream...
ecppack --idcode 0x21111043 ^
  --db "%TRELLISDB%" ^
  --input ulx3s_12f_picorv32.config ^
  --bit ulx3s_12f_picorv32.bit
if errorlevel 1 ( echo [ERROR] ecppack failed & exit /b 1 )

echo.
echo ============================================================
echo  Done! ulx3s_12f_picorv32.bit ready
echo  1. Replug USB
echo  2. dfu-util -a 0 -D ulx3s_12f_picorv32.bit
echo  3. dfu-util -d 1d50:614b -S 5033413336330006 -a 0 -e
echo ============================================================
