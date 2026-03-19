/*
 * minilib.c — FreeRTOS가 필요로 하는 최소 C 라이브러리 함수
 *
 * -nostdlib로 빌드하면 libc가 링크되지 않으므로,
 * FreeRTOS 커널이 사용하는 memset/memcpy/memcmp를 직접 제공해야 한다.
 */

#include <stddef.h>
#include <stdint.h>

void *memset(void *s, int c, size_t n) {
    unsigned char *p = (unsigned char *)s;
    while (n--) *p++ = (unsigned char)c;
    return s;
}

void *memcpy(void *dest, const void *src, size_t n) {
    unsigned char *d = (unsigned char *)dest;
    const unsigned char *s = (const unsigned char *)src;
    while (n--) *d++ = *s++;
    return dest;
}

int memcmp(const void *s1, const void *s2, size_t n) {
    const unsigned char *a = (const unsigned char *)s1;
    const unsigned char *b = (const unsigned char *)s2;
    while (n--) {
        if (*a != *b) return *a - *b;
        a++; b++;
    }
    return 0;
}
