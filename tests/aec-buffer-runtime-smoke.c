#include <libaec.h>
#include <stdio.h>
#include <string.h>

int main(void)
{
    unsigned char input[128], encoded[512], decoded[128];
    for (unsigned int i = 0; i < sizeof(input); ++i) input[i] = (unsigned char)(i * 7U);
    struct aec_stream encoder = {0};
    encoder.next_in = input;
    encoder.avail_in = sizeof(input);
    encoder.next_out = encoded;
    encoder.avail_out = sizeof(encoded);
    encoder.bits_per_sample = 8;
    encoder.block_size = 8;
    encoder.rsi = 4;
    encoder.flags = AEC_DATA_PREPROCESS;
    if (aec_buffer_encode(&encoder) != AEC_OK || encoder.total_in != sizeof(input) || !encoder.total_out) return 1;
    struct aec_stream decoder = {0};
    decoder.next_in = encoded;
    decoder.avail_in = encoder.total_out;
    decoder.next_out = decoded;
    decoder.avail_out = sizeof(decoded);
    decoder.bits_per_sample = encoder.bits_per_sample;
    decoder.block_size = encoder.block_size;
    decoder.rsi = encoder.rsi;
    decoder.flags = encoder.flags;
    if (aec_buffer_decode(&decoder) != AEC_OK || decoder.total_out != sizeof(input)) return 2;
    if (memcmp(input, decoded, sizeof(input))) return 3;
    puts("AEC target lossless buffer roundtrip: PASS 128 exact bytes");
    return 0;
}
