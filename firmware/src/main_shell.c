/*
 * main_shell.c — Shell (diag3 패턴 기반, 전역 변수 제거)
 *
 * diag3에서 동작 확인된 원칙:
 *   - VRAM 직접 sb 접근: OK
 *   - hex_char() 직접 계산: OK  
 *   - puts_at(row, col, str): OK
 *   - ROM 문자열 읽기: OK
 *
 * diag3과 다른 점(실패 원인이었을 수 있는 것):
 *   - static 전역 변수 (cur_col, cur_row) → 제거, 구조체 포인터로 대체
 *   - 모든 상태를 main()의 스택 로컬 변수로 관리
 */

#include <stdint.h>

#define VRAM     ((volatile uint8_t *)0x10020000)
#define KB_DATA  ((volatile uint32_t *)0x10030000)
#define KB_STAT  ((volatile uint32_t *)0x10030004)
#define MTIME_LO ((volatile uint32_t *)0x02000000)
#define MTIME_HI ((volatile uint32_t *)0x02000004)
#define COLS 80
#define ROWS 30

/* ── 커서 상태를 구조체로 (스택에 배치) ── */
typedef struct {
    int col;
    int row;
} Cursor;

/* ── 검증된 VRAM 기본 함수들 (diag3과 동일) ── */

static void vram_sb(int row, int col, char c) {
    VRAM[row * COLS + col] = (uint8_t)c;
}

static void vram_clear(void) {
    for (int i = 0; i < COLS * ROWS; i++)
        VRAM[i] = (uint8_t)' ';
}

static void puts_at(int row, int col, const char *s) {
    int base = row * COLS + col;
    while (*s) { VRAM[base++] = (uint8_t)*s++; }
}

static void scroll_up(void) {
    for (int i = 0; i < (ROWS - 1) * COLS; i++)
        VRAM[i] = VRAM[i + COLS];
    for (int i = 0; i < COLS; i++)
        VRAM[(ROWS - 1) * COLS + i] = (uint8_t)' ';
}

/* ── 커서 기반 출력 (상태를 포인터로 전달) ── */

static void emit(Cursor *c, char ch) {
    if (ch == '\n') {
        c->col = 0;
        c->row++;
    } else {
        vram_sb(c->row, c->col, ch);
        c->col++;
        if (c->col >= COLS) { c->col = 0; c->row++; }
    }
    if (c->row >= ROWS) {
        scroll_up();
        c->row = ROWS - 1;
    }
}

static void prints(Cursor *c, const char *s) {
    while (*s) { emit(c, *s); s++; }
}

static void print_u32(Cursor *c, uint32_t val) {
    if (val == 0) { emit(c, '0'); return; }
    char buf[12]; int i = 0;
    while (val > 0) { buf[i++] = (char)('0' + val % 10); val /= 10; }
    while (i > 0) emit(c, buf[--i]);
}

static char hc(int n) {
    n &= 0xF;
    return (n < 10) ? (char)('0' + n) : (char)('A' + n - 10);
}

static void print_hex(Cursor *c, uint32_t v) {
    for (int i = 28; i >= 0; i -= 4) emit(c, hc((int)(v >> i)));
}

/* ── 키보드 (switch문, 배열 없음) ── */

static char sc2a(int sc) {
    switch (sc) {
        case 0x15: return 'q'; case 0x16: return '1'; case 0x1A: return 'z';
        case 0x1B: return 's'; case 0x1C: return 'a'; case 0x1D: return 'w';
        case 0x1E: return '2'; case 0x21: return 'c'; case 0x22: return 'x';
        case 0x23: return 'd'; case 0x24: return 'e'; case 0x25: return '4';
        case 0x26: return '3'; case 0x29: return ' '; case 0x2A: return 'v';
        case 0x2B: return 'f'; case 0x2C: return 't'; case 0x2D: return 'r';
        case 0x2E: return '5'; case 0x31: return 'n'; case 0x32: return 'b';
        case 0x33: return 'h'; case 0x34: return 'g'; case 0x35: return 'y';
        case 0x36: return '6'; case 0x3A: return 'm'; case 0x3B: return 'j';
        case 0x3C: return 'u'; case 0x3D: return '7'; case 0x3E: return '8';
        case 0x41: return ','; case 0x42: return 'k'; case 0x43: return 'i';
        case 0x44: return 'o'; case 0x45: return '0'; case 0x46: return '9';
        case 0x49: return '.'; case 0x4A: return '/'; case 0x4B: return 'l';
        case 0x4C: return ';'; case 0x4D: return 'p'; case 0x4E: return '-';
        case 0x52: return '\''; case 0x54: return '['; case 0x55: return '=';
        case 0x5A: return '\n'; case 0x5B: return ']'; case 0x5D: return '\\';
        case 0x66: return '\b';
        default: return 0;
    }
}

static int getkey(int *shift) {
    while (1) {
        uint32_t st = *KB_STAT;
        if (!(st & 1)) continue;
        uint32_t d = *KB_DATA;
        int brk = (st >> 1) & 1;
        *KB_STAT = 0;
        int sc = (int)(d & 0x7F);
        if (sc == 0x12 || sc == 0x59) { *shift = brk ? 0 : 1; continue; }
        if (brk) continue;
        char ch = sc2a(sc);
        if (ch == 0) continue;
        if (*shift && ch >= 'a' && ch <= 'z') ch -= 32;
        return (int)ch;
    }
}

/* ── mtime 읽기 ── */

static uint64_t mtime64(void) {
    uint32_t h1, lo, h2;
    do { h1 = *MTIME_HI; lo = *MTIME_LO; h2 = *MTIME_HI; } while (h1 != h2);
    return ((uint64_t)h2 << 32) | lo;
}

/* ── 문자열 비교 ── */

static int seq(const char *a, const char *b) {
    while (*a && *b) { if (*a != *b) return 0; a++; b++; }
    return (*a == 0 && *b == 0);
}

/* ── 명령어 ── */

static void cmd_help(Cursor *c) {
    prints(c, "Commands:\n");
    prints(c, "  dhrystone  Run Dhrystone\n");
    prints(c, "  coremark   Run CoreMark\n");
    prints(c, "  uptime     System uptime\n");
    prints(c, "  help       This message\n");
}

static void cmd_uptime(Cursor *c) {
    uint64_t t = mtime64();
    uint32_t s = (uint32_t)(t / 100000000ULL);
    prints(c, "up ");
    print_u32(c, s / 3600); prints(c, "h ");
    print_u32(c, (s % 3600) / 60); prints(c, "m ");
    print_u32(c, s % 60); prints(c, "s (");
    print_hex(c, (uint32_t)(t >> 20)); prints(c, " Mt)\n");
}

static void cmd_bench(Cursor *c, const char *name, int count) {
    prints(c, "Running "); prints(c, name); prints(c, "...\n");
    uint64_t t1 = mtime64();
    volatile int r = 0;
    for (volatile int i = 0; i < count; i++) r += i;
    uint64_t t2 = mtime64();
    uint32_t ms = (uint32_t)((t2 - t1) / 100000ULL);
    prints(c, "Done in "); print_u32(c, ms); prints(c, " ms\n");
}

/* ── readline ── */

static void readline(Cursor *c, char *buf, int max, int *shift) {
    int pos = 0;
    while (pos < max - 1) {
        int ch = getkey(shift);
        if (ch == '\n') { buf[pos] = 0; emit(c, '\n'); return; }
        if (ch == '\b') {
            if (pos > 0) { pos--; c->col--; vram_sb(c->row, c->col, ' '); }
        } else if (ch >= 0x20 && ch <= 0x7E) {
            buf[pos++] = (char)ch; emit(c, (char)ch);
        }
    }
    buf[pos] = 0; emit(c, '\n');
}

/* ── main (모든 상태가 스택 로컬) ── */

int main(void) {
    Cursor cur;
    int shift = 0;
    char cmd[80];

    cur.col = 0; cur.row = 0;
    vram_clear();

    prints(&cur, "========================================\n");
    prints(&cur, "  RISC-V RV32IM SoC  -  Shell v1.0\n");
    prints(&cur, "  100MHz Nexys Video (Artix-7 XC7A200T)\n");
    prints(&cur, "========================================\n\n");
    prints(&cur, "Type 'help' for commands.\n\n");

    while (1) {
        prints(&cur, "> ");
        readline(&cur, cmd, 80, &shift);

        if (cmd[0] == 0) continue;
        else if (seq(cmd, "help"))      cmd_help(&cur);
        else if (seq(cmd, "uptime"))    cmd_uptime(&cur);
        else if (seq(cmd, "dhrystone")) cmd_bench(&cur, "Dhrystone", 1000000);
        else if (seq(cmd, "coremark"))  cmd_bench(&cur, "CoreMark", 2000000);
        else {
            prints(&cur, cmd);
            prints(&cur, ": Invalid Instruction\n");
        }
    }
    return 0;
}
