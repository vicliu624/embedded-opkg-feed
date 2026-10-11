#include <libdeflate.h>
#include <string.h>

int main(void) {
    struct libdeflate_compressor *c = libdeflate_alloc_compressor(6);
    struct libdeflate_decompressor *d = libdeflate_alloc_decompressor();
    if (!c || !d) return 1;
    const char input[] = "TDVP deflate zlib gzip roundtrip";
    unsigned char encoded[512], decoded[512];
    for (int mode = 0; mode < 3; ++mode) {
        size_t length = mode == 0 ? libdeflate_deflate_compress(c, input, sizeof(input), encoded, sizeof(encoded)) :
            mode == 1 ? libdeflate_zlib_compress(c, input, sizeof(input), encoded, sizeof(encoded)) :
                        libdeflate_gzip_compress(c, input, sizeof(input), encoded, sizeof(encoded));
        if (!length) return 2;
        size_t actual = 0;
        enum libdeflate_result status = mode == 0 ? libdeflate_deflate_decompress(d, encoded, length, decoded, sizeof(decoded), &actual) :
            mode == 1 ? libdeflate_zlib_decompress(d, encoded, length, decoded, sizeof(decoded), &actual) :
                        libdeflate_gzip_decompress(d, encoded, length, decoded, sizeof(decoded), &actual);
        if (status != LIBDEFLATE_SUCCESS || actual != sizeof(input) || memcmp(input, decoded, actual)) return 3;
        status = mode == 0 ? libdeflate_deflate_decompress(d, encoded, length - 1, decoded, sizeof(decoded), &actual) :
            mode == 1 ? libdeflate_zlib_decompress(d, encoded, length - 1, decoded, sizeof(decoded), &actual) :
                        libdeflate_gzip_decompress(d, encoded, length - 1, decoded, sizeof(decoded), &actual);
        if (status == LIBDEFLATE_SUCCESS) return 4;
    }
    libdeflate_free_compressor(c);
    libdeflate_free_decompressor(d);
    return 0;
}
