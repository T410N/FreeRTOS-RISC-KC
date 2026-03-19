#!/usr/bin/env python3
"""
elf2mem.py — ELF → Verilog $readmemh 변환기

사용법:
    python3 elf2mem.py firmware.bin firmware.mem [rom_size_words]

입력: riscv32-unknown-elf-objcopy로 생성한 flat binary
출력: InstructionMemory의 $readmemh가 읽을 .mem 파일

ROM은 0x0000_0000부터 시작하는 32-bit word 배열.
InstructionMemory는 8192 words (32KB).
binary 크기가 ROM보다 작으면 나머지는 00000000으로 채운다.
"""

import sys
import struct

def bin_to_mem(bin_path, mem_path, rom_words=8192):
    with open(bin_path, 'rb') as f:
        data = f.read()

    # Pad to word boundary
    while len(data) % 4 != 0:
        data += b'\x00'

    num_words = len(data) // 4
    if num_words > rom_words:
        print(f"WARNING: binary ({num_words} words) exceeds ROM ({rom_words} words)")
        print(f"         Truncating to {rom_words} words")
        num_words = rom_words

    with open(mem_path, 'w') as f:
        f.write(f"// Generated from {bin_path}\n")
        f.write(f"// {num_words} words of code, {rom_words - num_words} words padding\n\n")

        for i in range(rom_words):
            if i < num_words:
                # Little-endian binary → 32-bit word (RV32 is little-endian)
                word = struct.unpack('<I', data[i*4:(i+1)*4])[0]
            else:
                word = 0x00000000  # NOP-like padding

            f.write(f"{word:08X}\n")

    print(f"Generated {mem_path}: {num_words} code words + {rom_words - num_words} padding = {rom_words} total")
    code_kb = (num_words * 4) / 1024
    print(f"Code size: {code_kb:.1f} KB / {rom_words * 4 / 1024:.0f} KB ROM")

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: python3 elf2mem.py <input.bin> <output.mem> [rom_size_words]")
        sys.exit(1)

    bin_path = sys.argv[1]
    mem_path = sys.argv[2]
    rom_words = int(sys.argv[3]) if len(sys.argv) > 3 else 8192

    bin_to_mem(bin_path, mem_path, rom_words)
