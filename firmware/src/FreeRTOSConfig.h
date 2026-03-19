/*
 * FreeRTOSConfig.h — RV32IM SoC (Nexys Video, 100MHz)
 *
 * 이 파일을 src/ 또는 include 경로에 배치한다.
 * FreeRTOS 커널 소스가 #include "FreeRTOSConfig.h"로 찾을 수 있어야 함.
 */

#ifndef FREERTOS_CONFIG_H
#define FREERTOS_CONFIG_H

/* ── Core ── */
#define configUSE_PREEMPTION                    1
#define configUSE_PORT_OPTIMISED_TASK_SELECTION 0
#define configUSE_TICKLESS_IDLE                 0
#define configCPU_CLOCK_HZ                      100000000UL  /* 100 MHz */
#define configTICK_RATE_HZ                      1000         /* 1ms tick */
#define configMAX_PRIORITIES                    5
#define configMINIMAL_STACK_SIZE                256          /* words */
#define configMAX_TASK_NAME_LEN                 16
#define configUSE_16_BIT_TICKS                  0
#define configIDLE_SHOULD_YIELD                 1

/* ── Memory ── */
#define configTOTAL_HEAP_SIZE                   (12 * 1024)  /* 12KB */
#define configSUPPORT_STATIC_ALLOCATION         0
#define configSUPPORT_DYNAMIC_ALLOCATION        1

/* ── Features ── */
#define configUSE_MUTEXES                       1
#define configUSE_TASK_NOTIFICATIONS            1
#define configUSE_COUNTING_SEMAPHORES           0
#define configUSE_RECURSIVE_MUTEXES             0
#define configQUEUE_REGISTRY_SIZE               0
#define configUSE_TIMERS                        0
#define configUSE_CO_ROUTINES                   0

/* ── Hooks ── */
#define configUSE_IDLE_HOOK                     0
#define configUSE_TICK_HOOK                     0
#define configUSE_MALLOC_FAILED_HOOK            1
#define configCHECK_FOR_STACK_OVERFLOW          2

/* ── Stats ── */
#define configGENERATE_RUN_TIME_STATS           0
#define configUSE_TRACE_FACILITY                0

/* ── INCLUDE ── */
#define INCLUDE_vTaskPrioritySet                0
#define INCLUDE_uxTaskPriorityGet               0
#define INCLUDE_vTaskDelete                     0
#define INCLUDE_vTaskSuspend                    1
#define INCLUDE_vTaskDelayUntil                 1
#define INCLUDE_vTaskDelay                      1

/* ── RISC-V CLINT addresses (must match RTL) ── */
/*
 * FreeRTOS 공식 RISC-V port (port.c, portASM.S)가 사용하는 매크로.
 * portASM.S가 timer interrupt handler에서 이 주소로 mtimecmp를 직접 갱신.
 */
#define configMTIME_BASE_ADDRESS                ( 0x02000000UL )
#define configMTIMECMP_BASE_ADDRESS             ( 0x02000008UL )

#endif /* FREERTOS_CONFIG_H */
