/*
 * main_freertos_diag.c — FreeRTOS 단계별 진단
 *
 * Phase 1: xTaskCreate (힙 할당만) → "P1 OK"
 * Phase 2: vTaskStartScheduler → 태스크 시작 → "P2 OK"
 * Phase 3: vTaskDelay → timer interrupt 복귀 → "P3 OK"
 *
 * 각 phase에서 멈추면 그 단계가 문제.
 */

#include "FreeRTOS.h"
#include "task.h"
#include <stdint.h>

#define VRAM ((volatile uint8_t *)0x10020000)
#define COLS 80

static void puts_at(int row, int col, const char *s) {
    int base = row * COLS + col;
    while (*s) { VRAM[base++] = (uint8_t)*s++; }
}

static char hc(int n) { n &= 0xF; return (n < 10) ? (char)('0'+n) : (char)('A'+n-10); }

static void hex8_at(int row, int col, uint32_t v) {
    int base = row * COLS + col;
    for (int i = 7; i >= 0; i--)
        VRAM[base + (7-i)] = hc((int)(v >> (i*4)));
}

static void hex4_at(int row, int col, uint16_t v) {
    int base = row * COLS + col;
    VRAM[base+0] = hc(v>>12); VRAM[base+1] = hc(v>>8);
    VRAM[base+2] = hc(v>>4);  VRAM[base+3] = hc(v>>0);
}

static void clear(void) {
    for (int i = 0; i < COLS * 30; i++) VRAM[i] = ' ';
}

/* ── Phase 2-3 task: 태스크 진입 확인 + vTaskDelay 테스트 ── */
static volatile int task_entered = 0;
static volatile int task_resumed = 0;

static void test_task(void *param) {
    (void)param;

    /* Phase 2: 여기 도달하면 스케줄러 시작 + 태스크 디스패치 성공 */
    task_entered = 1;
    puts_at(4, 0, "P2: Task entered OK!");

    /* Phase 2b: mcause와 mtvec 확인 */
    uint32_t mtvec_val, mstatus_val, mie_val;
    __asm__ volatile ("csrr %0, mtvec" : "=r"(mtvec_val));
    __asm__ volatile ("csrr %0, mstatus" : "=r"(mstatus_val));
    __asm__ volatile ("csrr %0, mie" : "=r"(mie_val));

    puts_at(6, 0, "mtvec:   "); hex8_at(6, 9, mtvec_val);
    puts_at(7, 0, "mstatus: "); hex8_at(7, 9, mstatus_val);
    puts_at(8, 0, "mie:     "); hex8_at(8, 9, mie_val);
    puts_at(9, 0, "MIE bit: "); VRAM[9*COLS+9] = (mstatus_val & 0x8) ? '1' : '0';
    puts_at(9,12, "MTIE bit: "); VRAM[9*COLS+22] = (mie_val & 0x80) ? '1' : '0';

    /* Phase 3: vTaskDelay 호출 — timer interrupt 필요 */
    puts_at(11, 0, "P3: Calling vTaskDelay(500)...");

    uint16_t count = 0;
    while (1) {
        puts_at(12, 0, "TICK: ");
        hex4_at(12, 6, count);
        count++;

        /* 이 줄이 문제의 핵심: vTaskDelay는 timer interrupt가 필요 */
        vTaskDelay(pdMS_TO_TICKS(500));

        /* 여기 도달하면 timer interrupt가 작동한다는 증거 */
        task_resumed = 1;
        puts_at(13, 0, "P3: Task resumed! Timer IRQ works!");
    }
}

int main(void) {
    clear();
    puts_at(0, 0, "=== FreeRTOS Phase Diagnostic ===");

    /* ── Phase 1: xTaskCreate (힙 할당) ── */
    puts_at(2, 0, "P1: Creating task...");

    BaseType_t ret = xTaskCreate(test_task, "test", 512, NULL, 2, NULL);

    if (ret == pdPASS) {
        puts_at(2, 21, "OK (heap works)");
    } else {
        puts_at(2, 21, "FAILED!");
        puts_at(3, 0, "xTaskCreate returned: ");
        hex8_at(3, 21, (uint32_t)ret);
        while(1);
    }

    /* ── Phase 2: Start scheduler ── */
    puts_at(3, 0, "P1b: Starting scheduler...");

    /* 이 함수는 반환하지 않아야 함 */
    vTaskStartScheduler();

    /* 여기 도달하면 스케줄러 시작 실패 */
    puts_at(15, 0, "ERROR: vTaskStartScheduler returned!");
    while(1);
    return 0;
}

void vApplicationStackOverflowHook(void *xTask, char *pcTaskName) {
    (void)xTask; (void)pcTaskName;
    puts_at(16, 0, "!!! STACK OVERFLOW !!!");
    while(1);
}

void vApplicationMallocFailedHook(void) {
    puts_at(16, 0, "!!! MALLOC FAILED !!!");
    while(1);
}

/* Idle hook — idle 태스크가 실행되고 있다는 표시 */
void vApplicationIdleHook(void) {
    static uint16_t idle_count = 0;
    idle_count++;
    puts_at(14, 0, "IDLE: ");
    hex4_at(14, 6, idle_count);
}
