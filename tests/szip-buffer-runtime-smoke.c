#include <szlib.h>
#include <stdio.h>
#include <string.h>

int main(void)
{
    unsigned char original[128], compressed[512], decoded[128];
    for (unsigned int i = 0; i < sizeof(original); ++i) original[i] = (unsigned char)(i * 11U);
    SZ_com_t parameters = {
        .options_mask = SZ_NN_OPTION_MASK | SZ_MSB_OPTION_MASK,
        .bits_per_pixel = 8,
        .pixels_per_block = 8,
        .pixels_per_scanline = 32
    };
    if (!SZ_encoder_enabled()) return 1;
    size_t compressed_size = sizeof(compressed);
    if (SZ_BufftoBuffCompress(compressed, &compressed_size, original, sizeof(original), &parameters) != SZ_OK ||
        !compressed_size || compressed_size > sizeof(compressed)) return 2;
    size_t decoded_size = sizeof(decoded);
    if (SZ_BufftoBuffDecompress(decoded, &decoded_size, compressed, compressed_size, &parameters) != SZ_OK ||
        decoded_size != sizeof(original) || memcmp(original, decoded, sizeof(original))) return 3;
    parameters.bits_per_pixel = 0;
    compressed_size = sizeof(compressed);
    if (SZ_BufftoBuffCompress(compressed, &compressed_size, original, sizeof(original), &parameters) == SZ_OK) return 4;
    puts("SZIP-compatible target buffer roundtrip and invalid bit width rejection: PASS");
    return 0;
}
