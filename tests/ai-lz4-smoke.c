#include <lz4.h>
#include <lz4hc.h>
#include <stdio.h>
#include <string.h>

int main(void) {
    const char input[] = "TDVP compression roundtrip TDVP compression roundtrip";
    char packed[256], restored[sizeof input];
    int n = LZ4_compress_default(input, packed, sizeof input, sizeof packed);
    if (n <= 0 || LZ4_decompress_safe(packed, restored, n, sizeof restored) != sizeof input)
        return 1;
    if (memcmp(input, restored, sizeof input)) return 2;
    n = LZ4_compress_HC(input, packed, sizeof input, sizeof packed, LZ4HC_CLEVEL_DEFAULT);
    if (n <= 0 || LZ4_decompress_safe(packed, restored, n, sizeof restored) != sizeof input)
        return 3;
    if (memcmp(input, restored, sizeof input)) return 4;
    puts("LZ4 normal and high-compression roundtrip passed");
    return 0;
}
