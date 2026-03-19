# FreeRTOS Shell Firmware - Build Guide

## Directory Structure

```
project-root/
├── FreeRTOS-Kernel/        <- git clone here (Step 1)
└── firmware/
    ├── Makefile
    ├── scripts/elf2mem.py
    └── src/
        ├── FreeRTOSConfig.h
        ├── crt0.S
        ├── hdmi_console.h
        ├── linker.ld
        ├── main.c
        └── ps2_keyboard.h
```

## Step 1: Clone FreeRTOS-Kernel (firmware/ 옆에)

    cd project-root/
    git clone --branch V11.1.0 https://github.com/FreeRTOS/FreeRTOS-Kernel.git

## Step 2: Install RISC-V Toolchain

    # Ubuntu/Debian
    sudo apt install gcc-riscv64-unknown-elf
    # 빌드 시: make CROSS=riscv64-unknown-elf-

## Step 3: Build

    cd firmware/
    make

## Step 4: Apply to Vivado

1. build/firmware.mem -> Vivado 프로젝트 디렉토리에 복사
2. Instruction_Memory.v에서 $readmemh 파일명을 firmware.mem으로 변경
3. 합성 -> 비트스트림 -> 프로그래밍

## Step 5: Test

1. USB keyboard -> J15, HDMI monitor 연결
2. BTNU 버튼으로 CPU 시작
3. 화면에 쉘 프롬프트 표시 확인
4. uptime, dhrystone, coremark, help 테스트
