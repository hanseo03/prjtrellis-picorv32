# ============================================================
# prjtrellis-picorv32 Windows Build Makefile
# ULX3S 12K + OSS CAD Suite + xPack RISC-V GCC
# ============================================================

PROJECT  = picorv32
BOARD    = ulx3s
FPGA_SIZE = 12
CHIP_ID  = 0x21111043

CONSTRAINTS  = ulx3s_v20_segpdi.lpf
TOP_MODULE   = top
VERILOG_FILES = top.v attosoc.v picorv32.v simpleuart.v

OUTPUT = $(BOARD)_$(FPGA_SIZE)f_$(PROJECT)

# ---- RISC-V GCC (xPack) ------------------------------------
RISCV_PATH   = C:/Users/khsab/Downloads/xpack-riscv-none-elf-gcc-15.2.0-1-win32-x64/xpack-riscv-none-elf-gcc-15.2.0-1/bin
RISCV_GCC    = $(RISCV_PATH)/riscv-none-elf-gcc
RISCV_OBJCOPY= $(RISCV_PATH)/riscv-none-elf-objcopy

# ---- OSS CAD Suite -----------------------------------------
OSS_CAD   = C:/Users/khsab/Downloads/oss-cad-suite
TRELLISDB = $(OSS_CAD)/share/trellis/database
BASECFG   = $(OSS_CAD)/share/trellis/misc/basecfgs/empty_lfe5u-25f.config

# ============================================================
.PHONY: all clean

all: $(OUTPUT).bit

# ---- 1단계: 펌웨어 빌드 (C → hex) --------------------------
firmware.elf: sections.lds start.s firmware.c
	$(RISCV_GCC) -march=rv32i -mabi=ilp32 \
	  -Wl,-Bstatic,-T,sections.lds,--strip-debug \
	  -ffreestanding -nostdlib \
	  -o firmware.elf start.s firmware.c

firmware.bin: firmware.elf
	$(RISCV_OBJCOPY) -O binary firmware.elf firmware.bin

firmware.hex: firmware.bin
	python3 makehex.py firmware.bin 4096 > firmware.hex

# ---- 2단계: 합성 (Verilog → JSON) --------------------------
$(PROJECT).json: firmware.hex $(VERILOG_FILES)
	yosys \
	  -p "hierarchy -top $(TOP_MODULE)" \
	  -p "synth_ecp5 -json $(PROJECT).json" \
	  $(VERILOG_FILES)

# ---- 3단계: 배치·배선 (JSON → config) ----------------------
$(OUTPUT).config: $(PROJECT).json
	nextpnr-ecp5 --25k \
	  --json $(PROJECT).json \
	  --lpf $(CONSTRAINTS) \
	  --basecfg $(BASECFG) \
	  --textcfg $(OUTPUT).config

# ---- 4단계: 비트스트림 생성 (config → .bit) ----------------
$(OUTPUT).bit: $(OUTPUT).config
	ecppack --idcode $(CHIP_ID) \
	  --db $(TRELLISDB) \
	  --input $(OUTPUT).config \
	  --bit $(OUTPUT).bit

# ---- 청소 --------------------------------------------------
clean:
	del /Q firmware.elf firmware.bin firmware.hex 2>nul
	del /Q $(PROJECT).json $(OUTPUT).config $(OUTPUT).bit 2>nul