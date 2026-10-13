#include <stdio.h>
#include <string.h>

int main(void)
{
    unsigned char a[256], b[256];
    for (int i = 0; i < 256; ++i) a[i] = b[i] = (unsigned char)i;
    if (memcmp(a, b, sizeof(a)) != 0 || memcmp(a, b, 0) != 0) return 1;
    for (int i = 0; i < 255; ++i) {
        b[i] = (unsigned char)(i + 1);
        if (memcmp(a, b, sizeof(a)) >= 0 || memcmp(b, a, sizeof(a)) <= 0) return 2;
        b[i] = a[i];
    }
    b[255] = 0;
    if (memcmp(a, b, sizeof(a)) <= 0) return 3;
    puts("Target libc memcmp unsigned ordering, equality and zero length: PASS");
    return 0;
}
