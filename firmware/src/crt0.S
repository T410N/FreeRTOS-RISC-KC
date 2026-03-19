/*
 * crt0.S — Startup Code for RV32IM SoC
 *
 * 중요: .option norelax를 전체에 적용.
 * 이유: 링커 relaxation이 GP-relative 주소 지정으로 변환하면,
 *       GP 초기화 전에 GP를 참조하는 코드가 생겨서 crash.
 */

    .section .text.init, "ax"
    .global _start
    .type _start, @function

    .option push
    .option norelax

_start:
    /* 1. 인터럽트 비활성화 */
    csrw    mie, zero
    csrw    mstatus, zero

    /* 2. 스택 포인터 설정 */
    lui     sp, %hi(_stack_top)
    addi    sp, sp, %lo(_stack_top)

    /* 3. 글로벌 포인터 설정 */
    lui     gp, %hi(__global_pointer$)
    addi    gp, gp, %lo(__global_pointer$)

    /* 4. BSS 클리어 */
    lui     t0, %hi(_bss_start)
    addi    t0, t0, %lo(_bss_start)
    lui     t1, %hi(_bss_end)
    addi    t1, t1, %lo(_bss_end)
    bge     t0, t1, 2f
1:
    sw      zero, 0(t0)
    addi    t0, t0, 4
    blt     t0, t1, 1b
2:

    /* 5. .data ROM→RAM 복사 */
    lui     t0, %hi(_data_start)
    addi    t0, t0, %lo(_data_start)
    lui     t1, %hi(_data_end)
    addi    t1, t1, %lo(_data_end)
    lui     t2, %hi(_data_load)
    addi    t2, t2, %lo(_data_load)
    bge     t0, t1, 4f
3:
    lw      t3, 0(t2)
    sw      t3, 0(t0)
    addi    t0, t0, 4
    addi    t2, t2, 4
    blt     t0, t1, 3b
4:

    /* 6. 임시 트랩 핸들러 설정 */
    lui     t0, %hi(_trap_spin)
    addi    t0, t0, %lo(_trap_spin)
    csrw    mtvec, t0

    /* 7. main() 호출 */
    jal     ra, main

_halt:
    j       _halt

    .option pop
    .size _start, . - _start

    .align 4
    .global _trap_spin
_trap_spin:
    j       _trap_spin
