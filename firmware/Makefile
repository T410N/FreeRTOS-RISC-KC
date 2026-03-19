# ============================================================================
# Makefile — RV32IM SoC Firmware
# ============================================================================
# Targets:
#   make shell     → Bare-metal shell (검증 완료)
#   make freertos  → FreeRTOS shell
#   make clean     → 빌드 삭제
# ============================================================================

CROSS    ?= riscv64-unknown-elf-
CC        = $(CROSS)gcc
AS        = $(CROSS)gcc
LD        = $(CROSS)gcc
OBJCOPY   = $(CROSS)objcopy
OBJDUMP   = $(CROSS)objdump
SIZE      = $(CROSS)size

# FreeRTOS-Kernel (firmware/ 상위에 clone)
FK ?= ../FreeRTOS-Kernel
FK_PORT = $(FK)/portable/GCC/RISC-V
FK_MEM  = $(FK)/portable/MemMang
FK_CHIP = $(FK_PORT)/chip_specific_extensions/RV32I_CLINT_no_extensions

BUILD = build

ARCH = -march=rv32im_zicsr -mabi=ilp32

CFLAGS  = $(ARCH) -Os -g -Wall -Wextra -Wno-unused-parameter
CFLAGS += -ffunction-sections -fdata-sections -ffreestanding -nostdlib
CFLAGS += -Isrc -I$(FK)/include -I$(FK_PORT)

ASFLAGS = $(ARCH) -g -I$(FK_CHIP) -Isrc -I$(FK)/include

LDFLAGS = $(ARCH) -nostdlib -nostartfiles -Tsrc/linker.ld -Wl,--gc-sections

.PHONY: shell freertos clean

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Bare-metal shell (검증 완료, FreeRTOS 없음)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
shell: $(BUILD)/shell.mem
	@echo "=== Shell: $(BUILD)/shell.mem ==="

$(BUILD)/shell.elf: src/main_shell.c src/minilib.c src/crt0.S | $(BUILD)
	$(CC) $(CFLAGS) -c -o $(BUILD)/main_shell.o src/main_shell.c
	$(CC) $(CFLAGS) -c -o $(BUILD)/minilib.o src/minilib.c
	$(AS) $(ASFLAGS) -c -o $(BUILD)/crt0.o src/crt0.S
	$(LD) $(LDFLAGS) -o $@ $(BUILD)/crt0.o $(BUILD)/main_shell.o $(BUILD)/minilib.o -lgcc
	$(SIZE) $@

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# FreeRTOS shell
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
freertos: $(BUILD)/freertos.mem
	@echo "=== FreeRTOS: $(BUILD)/freertos.mem ==="

$(BUILD)/freertos.elf: src/main_freertos.c src/minilib.c src/crt0.S \
                       $(FK)/tasks.c $(FK)/queue.c $(FK)/list.c \
                       $(FK_MEM)/heap_4.c $(FK_PORT)/port.c $(FK_PORT)/portASM.S | $(BUILD)
	$(CC) $(CFLAGS) -c -o $(BUILD)/main_freertos.o src/main_freertos.c
	$(CC) $(CFLAGS) -c -o $(BUILD)/minilib.o src/minilib.c
	$(AS) $(ASFLAGS) -c -o $(BUILD)/crt0.o src/crt0.S
	$(CC) $(CFLAGS) -c -o $(BUILD)/tasks.o $(FK)/tasks.c
	$(CC) $(CFLAGS) -c -o $(BUILD)/queue.o $(FK)/queue.c
	$(CC) $(CFLAGS) -c -o $(BUILD)/list.o $(FK)/list.c
	$(CC) $(CFLAGS) -c -o $(BUILD)/heap_4.o $(FK_MEM)/heap_4.c
	$(CC) $(CFLAGS) -c -o $(BUILD)/port.o $(FK_PORT)/port.c
	$(AS) $(ASFLAGS) -c -o $(BUILD)/portASM.o $(FK_PORT)/portASM.S
	$(LD) $(LDFLAGS) -o $@ \
		$(BUILD)/crt0.o $(BUILD)/main_freertos.o $(BUILD)/minilib.o \
		$(BUILD)/tasks.o $(BUILD)/queue.o $(BUILD)/list.o \
		$(BUILD)/heap_4.o $(BUILD)/port.o $(BUILD)/portASM.o -lgcc
	$(SIZE) $@

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# FreeRTOS minimal test (no keyboard, no shell, just VRAM counter)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
freertos_min: $(BUILD)/freertos_min.mem
	@echo "=== FreeRTOS Min: $(BUILD)/freertos_min.mem ==="

$(BUILD)/freertos_min.elf: src/main_freertos_min.c src/minilib.c src/crt0.S \
                       $(FK)/tasks.c $(FK)/queue.c $(FK)/list.c \
                       $(FK_MEM)/heap_4.c $(FK_PORT)/port.c $(FK_PORT)/portASM.S | $(BUILD)
	$(CC) $(CFLAGS) -c -o $(BUILD)/main_freertos_min.o src/main_freertos_min.c
	$(CC) $(CFLAGS) -c -o $(BUILD)/minilib.o src/minilib.c
	$(AS) $(ASFLAGS) -c -o $(BUILD)/crt0.o src/crt0.S
	$(CC) $(CFLAGS) -c -o $(BUILD)/tasks.o $(FK)/tasks.c
	$(CC) $(CFLAGS) -c -o $(BUILD)/queue.o $(FK)/queue.c
	$(CC) $(CFLAGS) -c -o $(BUILD)/list.o $(FK)/list.c
	$(CC) $(CFLAGS) -c -o $(BUILD)/heap_4.o $(FK_MEM)/heap_4.c
	$(CC) $(CFLAGS) -c -o $(BUILD)/port.o $(FK_PORT)/port.c
	$(AS) $(ASFLAGS) -c -o $(BUILD)/portASM.o $(FK_PORT)/portASM.S
	$(LD) $(LDFLAGS) -o $@ \
		$(BUILD)/crt0.o $(BUILD)/main_freertos_min.o $(BUILD)/minilib.o \
		$(BUILD)/tasks.o $(BUILD)/queue.o $(BUILD)/list.o \
		$(BUILD)/heap_4.o $(BUILD)/port.o $(BUILD)/portASM.o -lgcc
	$(SIZE) $@

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# FreeRTOS phase diagnostic
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
freertos_diag: $(BUILD)/freertos_diag.mem
	@echo "=== FreeRTOS Diag: $(BUILD)/freertos_diag.mem ==="

$(BUILD)/freertos_diag.elf: src/main_freertos_diag.c src/minilib.c src/crt0.S \
                       $(FK)/tasks.c $(FK)/queue.c $(FK)/list.c \
                       $(FK_MEM)/heap_4.c $(FK_PORT)/port.c $(FK_PORT)/portASM.S | $(BUILD)
	$(CC) $(CFLAGS) -c -o $(BUILD)/main_freertos_diag.o src/main_freertos_diag.c
	$(CC) $(CFLAGS) -c -o $(BUILD)/minilib.o src/minilib.c
	$(AS) $(ASFLAGS) -c -o $(BUILD)/crt0.o src/crt0.S
	$(CC) $(CFLAGS) -c -o $(BUILD)/tasks.o $(FK)/tasks.c
	$(CC) $(CFLAGS) -c -o $(BUILD)/queue.o $(FK)/queue.c
	$(CC) $(CFLAGS) -c -o $(BUILD)/list.o $(FK)/list.c
	$(CC) $(CFLAGS) -c -o $(BUILD)/heap_4.o $(FK_MEM)/heap_4.c
	$(CC) $(CFLAGS) -c -o $(BUILD)/port.o $(FK_PORT)/port.c
	$(AS) $(ASFLAGS) -c -o $(BUILD)/portASM.o $(FK_PORT)/portASM.S
	$(LD) $(LDFLAGS) -o $@ \
		$(BUILD)/crt0.o $(BUILD)/main_freertos_diag.o $(BUILD)/minilib.o \
		$(BUILD)/tasks.o $(BUILD)/queue.o $(BUILD)/list.o \
		$(BUILD)/heap_4.o $(BUILD)/port.o $(BUILD)/portASM.o -lgcc
	$(SIZE) $@

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# FreeRTOS VRAM stress test
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
freertos_vram: $(BUILD)/freertos_vram.mem
	@echo "=== FreeRTOS VRAM: $(BUILD)/freertos_vram.mem ==="

$(BUILD)/freertos_vram.elf: src/main_freertos_vram.c src/minilib.c src/crt0.S \
                       $(FK)/tasks.c $(FK)/queue.c $(FK)/list.c \
                       $(FK_MEM)/heap_4.c $(FK_PORT)/port.c $(FK_PORT)/portASM.S | $(BUILD)
	$(CC) $(CFLAGS) -c -o $(BUILD)/main_freertos_vram.o src/main_freertos_vram.c
	$(CC) $(CFLAGS) -c -o $(BUILD)/minilib.o src/minilib.c
	$(AS) $(ASFLAGS) -c -o $(BUILD)/crt0.o src/crt0.S
	$(CC) $(CFLAGS) -c -o $(BUILD)/tasks.o $(FK)/tasks.c
	$(CC) $(CFLAGS) -c -o $(BUILD)/queue.o $(FK)/queue.c
	$(CC) $(CFLAGS) -c -o $(BUILD)/list.o $(FK)/list.c
	$(CC) $(CFLAGS) -c -o $(BUILD)/heap_4.o $(FK_MEM)/heap_4.c
	$(CC) $(CFLAGS) -c -o $(BUILD)/port.o $(FK_PORT)/port.c
	$(AS) $(ASFLAGS) -c -o $(BUILD)/portASM.o $(FK_PORT)/portASM.S
	$(LD) $(LDFLAGS) -o $@ \
		$(BUILD)/crt0.o $(BUILD)/main_freertos_vram.o $(BUILD)/minilib.o \
		$(BUILD)/tasks.o $(BUILD)/queue.o $(BUILD)/list.o \
		$(BUILD)/heap_4.o $(BUILD)/port.o $(BUILD)/portASM.o -lgcc
	$(SIZE) $@

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Common rules
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/%.bin: $(BUILD)/%.elf
	$(OBJCOPY) -O binary $< $@

$(BUILD)/%.mem: $(BUILD)/%.bin
	python3 scripts/elf2mem.py $< $@

$(BUILD)/%.dis: $(BUILD)/%.elf
	$(OBJDUMP) -d $< > $@

clean:
	rm -rf $(BUILD)
