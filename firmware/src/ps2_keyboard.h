// ============================================================================
// ps2_keyboard.h — PS/2 Keyboard MMIO Interface + Scan Code → ASCII
// ============================================================================
//
// 사용법:
//   #include "ps2_keyboard.h"
//
//   char c = kb_getchar();            // blocking: 키 입력 대기
//   int  c = kb_getchar_nonblock();   // non-blocking: 입력 없으면 -1
//
// ============================================================================

#ifndef PS2_KEYBOARD_H
#define PS2_KEYBOARD_H

#include <stdint.h>

// ============================================================================
// MMIO Registers
// ============================================================================

#define KB_DATA_REG     ((volatile uint32_t *)0x10030000)
#define KB_STATUS_REG   ((volatile uint32_t *)0x10030004)

// Status register bits
#define KB_STATUS_DATA_AVAILABLE  (1 << 0)
#define KB_STATUS_IS_BREAK        (1 << 1)
#define KB_STATUS_IS_EXTENDED     (1 << 2)

// ============================================================================
// PS/2 Set 2 Scan Code → ASCII Lookup Table
// ============================================================================
// PS/2 키보드는 "Set 2" scan code를 사용한다.
// 이 테이블은 scan code → ASCII 매핑 (Shift 없는 기본 상태).
// 0x00 = 매핑 없음 (특수 키, 무시)

static const char ps2_scancode_to_ascii[128] = {
//  0x00  0x01  0x02  0x03  0x04  0x05  0x06  0x07
    0,    0,    0,    0,    0,    0,    0,    0,     // 0x00
//  0x08  0x09  0x0A  0x0B  0x0C  0x0D  0x0E  0x0F
    0,    0,    0,    0,    0,    '\t', '`',  0,     // 0x08
//  0x10  0x11  0x12  0x13  0x14  0x15  0x16  0x17
    0,    0,    0,    0,    0,    'q',  '1',  0,     // 0x10
//  0x18  0x19  0x1A  0x1B  0x1C  0x1D  0x1E  0x1F
    0,    0,    'z',  's',  'a',  'w',  '2',  0,     // 0x18
//  0x20  0x21  0x22  0x23  0x24  0x25  0x26  0x27
    0,    'c',  'x',  'd',  'e',  '4',  '3',  0,     // 0x20
//  0x28  0x29  0x2A  0x2B  0x2C  0x2D  0x2E  0x2F
    0,    ' ',  'v',  'f',  't',  'r',  '5',  0,     // 0x28
//  0x30  0x31  0x32  0x33  0x34  0x35  0x36  0x37
    0,    'n',  'b',  'h',  'g',  'y',  '6',  0,     // 0x30
//  0x38  0x39  0x3A  0x3B  0x3C  0x3D  0x3E  0x3F
    0,    0,    'm',  'j',  'u',  '7',  '8',  0,     // 0x38
//  0x40  0x41  0x42  0x43  0x44  0x45  0x46  0x47
    0,    ',',  'k',  'i',  'o',  '0',  '9',  0,     // 0x40
//  0x48  0x49  0x4A  0x4B  0x4C  0x4D  0x4E  0x4F
    0,    '.',  '/',  'l',  ';',  'p',  '-',  0,     // 0x48
//  0x50  0x51  0x52  0x53  0x54  0x55  0x56  0x57
    0,    0,    '\'', 0,    '[',  '=',  0,    0,     // 0x50
//  0x58  0x59  0x5A  0x5B  0x5C  0x5D  0x5E  0x5F
    0,    0,    '\n', ']',  0,    '\\', 0,    0,     // 0x58  (0x5A = Enter)
//  0x60  0x61  0x62  0x63  0x64  0x65  0x66  0x67
    0,    0,    0,    0,    0,    0,    '\b', 0,     // 0x60  (0x66 = Backspace)
//  0x68  0x69  0x6A  0x6B  0x6C  0x6D  0x6E  0x6F
    0,    0,    0,    0,    0,    0,    0,    0,     // 0x68
//  0x70  0x71  0x72  0x73  0x74  0x75  0x76  0x77
    0,    0,    0,    0,    0,    0,    0,    0,     // 0x70
//  0x78  0x79  0x7A  0x7B  0x7C  0x7D  0x7E  0x7F
    0,    0,    0,    0,    0,    0,    0,    0,     // 0x78
};

// Shift 상태에서의 매핑 (주요 키만)
static const char ps2_scancode_to_ascii_shift[128] = {
    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    '\t', '~',  0,
    0,    0,    0,    0,    0,    'Q',  '!',  0,
    0,    0,    'Z',  'S',  'A',  'W',  '@',  0,
    0,    'C',  'X',  'D',  'E',  '$',  '#',  0,
    0,    ' ',  'V',  'F',  'T',  'R',  '%',  0,
    0,    'N',  'B',  'H',  'G',  'Y',  '^',  0,
    0,    0,    'M',  'J',  'U',  '&',  '*',  0,
    0,    '<',  'K',  'I',  'O',  ')',  '(',  0,
    0,    '>',  '?',  'L',  ':',  'P',  '_',  0,
    0,    0,    '"',  0,    '{',  '+',  0,    0,
    0,    0,    '\n', '}',  0,    '|',  0,    0,
    0,    0,    0,    0,    0,    0,    '\b', 0,
    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,
};

// ============================================================================
// Special scan codes
// ============================================================================

#define PS2_SC_LSHIFT    0x12
#define PS2_SC_RSHIFT    0x59
#define PS2_SC_ENTER     0x5A
#define PS2_SC_BACKSPACE 0x66
#define PS2_SC_ESCAPE    0x76
#define PS2_SC_CAPSLOCK  0x58

// ============================================================================
// Keyboard state
// ============================================================================

static int kb_shift_pressed = 0;
static int kb_caps_lock = 0;

// ============================================================================
// Low-level: read raw scan code (non-blocking)
// ============================================================================
// Returns: scan code if available, or -1 if no data.
// Also sets *is_break to 1 if this was a key release event.

static inline int kb_read_raw(int *is_break) {
    uint32_t status = *KB_STATUS_REG;

    if (!(status & KB_STATUS_DATA_AVAILABLE))
        return -1;

    uint32_t data = *KB_DATA_REG;
    *is_break = (status & KB_STATUS_IS_BREAK) ? 1 : 0;

    // Acknowledge (clear flag)
    *KB_STATUS_REG = 0;

    return (int)(data & 0xFF);
}

// ============================================================================
// High-level: get ASCII character (non-blocking)
// ============================================================================
// Returns: ASCII char if a printable key was pressed, or -1 if nothing.
// Automatically handles Shift state and ignores key release events.

static inline int kb_getchar_nonblock(void) {
    int is_break = 0;
    int scancode = kb_read_raw(&is_break);

    if (scancode < 0)
        return -1;

    // Track Shift key state
    if (scancode == PS2_SC_LSHIFT || scancode == PS2_SC_RSHIFT) {
        kb_shift_pressed = is_break ? 0 : 1;
        return -1;
    }

    // Track Caps Lock (toggle on press only)
    if (scancode == PS2_SC_CAPSLOCK && !is_break) {
        kb_caps_lock = !kb_caps_lock;
        return -1;
    }

    // Ignore key release events for other keys
    if (is_break)
        return -1;

    // Convert scan code to ASCII
    if (scancode >= 128)
        return -1;

    char c;
    if (kb_shift_pressed)
        c = ps2_scancode_to_ascii_shift[scancode];
    else
        c = ps2_scancode_to_ascii[scancode];

    // Apply Caps Lock to letters
    if (kb_caps_lock && c >= 'a' && c <= 'z')
        c = c - 'a' + 'A';
    else if (kb_caps_lock && c >= 'A' && c <= 'Z')
        c = c - 'A' + 'a';

    return (c != 0) ? (int)c : -1;
}

// ============================================================================
// Blocking: wait for a key press
// ============================================================================

static inline char kb_getchar(void) {
    int c;
    while ((c = kb_getchar_nonblock()) < 0)
        ;  // busy-wait
    return (char)c;
}

#endif // PS2_KEYBOARD_H
