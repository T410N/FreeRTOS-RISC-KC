/*
 * main_freertos_min.c — FreeRTOS 최소 테스트
 *
 * 목적: FreeRTOS가 우리 CPU에서 근본적으로 동작하는지 확인.
 * 키보드 없음, 쉘 없음. 태스크 하나가 VRAM에 카운터를 증가시킴.
 *
 * 화면에 "TICK: 0001", "TICK: 0002", ... 가 증가하면 FreeRTOS 동작 확인.
 * 화면이 멈추거나 깨지면 → FreeRTOS/CPU 호환성 문제.
 */

#include "FreeRTOS.h"
#include "task.h"
#include <stdint.h>

#define VRAM ((volatile uint8_t *)0x10020000)
#define COLS 80

/* diag3에서 검증된 패턴만 사용 */

static void puts_at(int row, int col, const char *s) {
    int base = row * COLS + col;
    while (*s) { VRAM[base++] = (uint8_t)*s++; }
}

static char hc(int n) { n &= 0xF; return (n < 10) ? (char)('0'+n) : (char)('A'+n-10); }

static void hex4_at(int row, int col, uint16_t v) {
    int base = row * COLS + col;
    VRAM[base + 0] = hc(v >> 12);
    VRAM[base + 1] = hc(v >> 8);
    VRAM[base + 2] = hc(v >> 4);
    VRAM[base + 3] = hc(v >> 0);
}

static void clear(void) {
    for (int i = 0; i < COLS * 30; i++) VRAM[i] = ' ';
}

/* ── Task A: VRAM에 tick 카운터 표시 ── */
static void task_counter(void *param) {
    (void)param;
    uint16_t count = 0;

    while (1) {
        puts_at(2, 0, "TICK: ");
        hex4_at(2, 6, count);
        count++;

        vTaskDelay(pdMS_TO_TICKS(500));  /* 500ms 대기 */
    }
}

/* ── Task B: 다른 행에 다른 카운터 (멀티태스킹 확인) ── */
static void task_counter2(void *param) {
    (void)param;
    uint16_t count = 0;

    while (1) {
        puts_at(3, 0, "TASK2: ");
        hex4_at(3, 7, count);
        count++;

        vTaskDelay(pdMS_TO_TICKS(1000));  /* 1000ms 대기 */
    }
}

int main(void) {
    clear();
    puts_at(0, 0, "FreeRTOS Minimal Test");
    puts_at(1, 0, "If TICK increments, RTOS works!");

    xTaskCreate(task_counter,  "cnt1", 256, NULL, 2, NULL);
    xTaskCreate(task_counter2, "cnt2", 256, NULL, 1, NULL);

    vTaskStartScheduler();

    /* Should never reach here */
    puts_at(5, 0, "ERROR: Scheduler returned!");
    while (1);
    return 0;
}

void vApplicationStackOverflowHook(void *xTask, char *pcTaskName) {
    (void)xTask; (void)pcTaskName;
    puts_at(6, 0, "STACK OVERFLOW!");
    while (1);
}

void vApplicationMallocFailedHook(void) {
    puts_at(6, 0, "MALLOC FAILED!");
    while (1);
}
