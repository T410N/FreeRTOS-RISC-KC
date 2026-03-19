// ============================================================================
// hdmi_console.h — HDMI Text Mode VRAM Interface
// ============================================================================
//
// 펌웨어에서 HDMI 화면에 글자를 쓰기 위한 API.
//
// 사용법:
//   #include "hdmi_console.h"
//
//   hdmi_clear();                     // 화면 지우기
//   hdmi_putc(0, 0, 'H');            // (0,0)에 'H' 쓰기
//   hdmi_puts(0, 0, "Hello World");  // 문자열 출력
//   hdmi_set_cursor(0, 5);           // 커서를 (col=0, row=5)로 이동
//
// ============================================================================

#ifndef HDMI_CONSOLE_H
#define HDMI_CONSOLE_H

#include <stdint.h>

// ============================================================================
// Memory Map Constants
// ============================================================================

#define VRAM_BASE       ((volatile uint8_t *)0x10020000)
#define VRAM_COLS       80
#define VRAM_ROWS       30
#define VRAM_SIZE       (VRAM_COLS * VRAM_ROWS)  // 2400

#define CURSOR_REG      ((volatile uint32_t *)0x10020960)

// ============================================================================
// Low-level VRAM write
// ============================================================================
//
// VRAM은 byte-addressable.
// 주소 0x1002_0000 + offset 에 ASCII 코드를 쓰면 해당 위치에 표시된다.
// offset = row * 80 + col

static inline void hdmi_putc(int col, int row, char c) {
    if (col < 0 || col >= VRAM_COLS) return;
    if (row < 0 || row >= VRAM_ROWS) return;

    int offset = row * VRAM_COLS + col;

    // sb (store byte)로 VRAM에 직접 쓰기
    // 컴파일러가 volatile uint8_t* 접근을 sb 명령어로 생성한다.
    VRAM_BASE[offset] = (uint8_t)c;
}

// ============================================================================
// String output
// ============================================================================

static inline void hdmi_puts(int col, int row, const char *s) {
    while (*s && col < VRAM_COLS) {
        hdmi_putc(col, row, *s);
        col++;
        s++;
    }
}

// ============================================================================
// Clear screen (fill with spaces)
// ============================================================================

static inline void hdmi_clear(void) {
    for (int i = 0; i < VRAM_SIZE; i++) {
        VRAM_BASE[i] = ' ';
    }
}

// ============================================================================
// Clear single row
// ============================================================================

static inline void hdmi_clear_row(int row) {
    if (row < 0 || row >= VRAM_ROWS) return;

    int base = row * VRAM_COLS;
    for (int i = 0; i < VRAM_COLS; i++) {
        VRAM_BASE[base + i] = ' ';
    }
}

// ============================================================================
// Cursor position
// ============================================================================
//
// cursor register: [15:8] = row, [7:0] = col
// 커서 렌더링은 추후 Text_Renderer 확장 시 구현 예정.

static inline void hdmi_set_cursor(int col, int row) {
    *CURSOR_REG = ((row & 0x1F) << 8) | (col & 0x7F);
}

// ============================================================================
// Scroll screen up by one line
// ============================================================================
//
// Row 0을 버리고, Row 1~29를 한 줄씩 위로 올린다.
// 마지막 줄(Row 29)은 공백으로 채운다.

static inline void hdmi_scroll_up(void) {
    // Row 1~29 → Row 0~28 (바이트 단위 복사)
    for (int i = 0; i < (VRAM_ROWS - 1) * VRAM_COLS; i++) {
        VRAM_BASE[i] = VRAM_BASE[i + VRAM_COLS];
    }
    // 마지막 줄 지우기
    hdmi_clear_row(VRAM_ROWS - 1);
}

// ============================================================================
// Stateful console (print at current position, auto-advance)
// ============================================================================
// 이 변수들은 펌웨어에서 전역으로 관리한다.

static int console_col = 0;
static int console_row = 0;

static inline void console_init(void) {
    hdmi_clear();
    console_col = 0;
    console_row = 0;
}

static inline void console_putchar(char c) {
    if (c == '\n') {
        console_col = 0;
        console_row++;
    } else if (c == '\r') {
        console_col = 0;
    } else {
        hdmi_putc(console_col, console_row, c);
        console_col++;

        if (console_col >= VRAM_COLS) {
            console_col = 0;
            console_row++;
        }
    }

    // 화면 넘침: 스크롤
    if (console_row >= VRAM_ROWS) {
        hdmi_scroll_up();
        console_row = VRAM_ROWS - 1;
        console_col = 0;
    }

    hdmi_set_cursor(console_col, console_row);
}

static inline void console_print(const char *s) {
    while (*s) {
        console_putchar(*s);
        s++;
    }
}

#endif // HDMI_CONSOLE_H
