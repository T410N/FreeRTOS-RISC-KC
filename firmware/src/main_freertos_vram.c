/*
 * main_freertos_vram.c — FreeRTOS + 연속 VRAM 쓰기 테스트
 *
 * 목적: FreeRTOS timer interrupt가 연속적인 VRAM 쓰기를 방해하는지 확인.
 *
 * Test A: 태스크에서 80글자 연속 쓰기 (prints 시뮬레이션)
 * Test B: 매 루프마다 한 줄씩 쓰면서 카운터 증가
 * Test C: vTaskDelay 없이 yield도 없이 무한 쓰기
 */

#include "FreeRTOS.h"
#include "task.h"
#include <stdint.h>

#define VRAM ((volatile uint8_t *)0x10020000)
#define COLS 80
#define ROWS 30

static void clear(void) {
    for (int i = 0; i < COLS * ROWS; i++) VRAM[i] = ' ';
}

static void puts_at(int row, int col, const char *s) {
    int base = row * COLS + col;
    while (*s) { VRAM[base++] = (uint8_t)*s++; }
}

static char hc(int n) { n &= 0xF; return (n < 10) ? (char)('0'+n) : (char)('A'+n-10); }

static void hex4_at(int row, int col, uint16_t v) {
    int base = row * COLS + col;
    VRAM[base+0] = hc(v>>12); VRAM[base+1] = hc(v>>8);
    VRAM[base+2] = hc(v>>4);  VRAM[base+3] = hc(v>>0);
}

/* ── Task: 연속 VRAM 쓰기 ── */
static void task_vram_stress(void *param) {
    (void)param;
    uint16_t loop = 0;

    while (1) {
        /* Row 3: 루프 카운터 */
        puts_at(3, 0, "Loop: ");
        hex4_at(3, 6, loop);

        /* Row 5-14: 80글자 연속 쓰기 (10줄) */
        for (int r = 5; r < 15; r++) {
            for (int c = 0; c < COLS; c++) {
                VRAM[r * COLS + c] = 'A' + ((loop + r + c) % 26);
            }
        }

        /* Row 16: 고정 문자열 반복 쓰기 */
        puts_at(16, 0, "========================================");
        puts_at(17, 0, "  RISC-V RV32IM SoC - FreeRTOS Shell   ");
        puts_at(18, 0, "  100MHz Nexys Video (Artix-7 XC7A200T) ");
        puts_at(19, 0, "========================================");
        puts_at(20, 0, "Commands:                               ");
        puts_at(21, 0, "  dhrystone  Run Dhrystone              ");
        puts_at(22, 0, "  coremark   Run CoreMark               ");
        puts_at(23, 0, "  uptime     System uptime              ");
        puts_at(24, 0, "  help       This message               ");

        loop++;

        /* 500ms 대기 — timer interrupt 경유 복귀 */
        //vTaskDelay(pdMS_TO_TICKS(500));
        for (volatile int d = 0; d < 2000000; d++) { }
    }
}

int main(void) {
    clear();
    puts_at(0, 0, "=== FreeRTOS VRAM Stress Test ===");
    puts_at(1, 0, "If text below is clean: RTOS+VRAM OK");
    puts_at(2, 0, "If garbled: timer IRQ corrupts writes");

    xTaskCreate(task_vram_stress, "vram", 1024, NULL, 2, NULL);
    vTaskStartScheduler();
    while(1);
    return 0;
}

void vApplicationStackOverflowHook(TaskHandle_t xTask, char *pcTaskName) {
    (void)xTask; (void)pcTaskName;
    puts_at(29, 0, "!!! STACK OVERFLOW !!!");   // ← 이 줄 추가
    while(1);
}
void vApplicationMallocFailedHook(void) { while(1); }
