/* Lossless stereo PCM roundtrip through the public WavPack file API. */
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <wavpack/wavpack.h>

static int write_block(void *id, void *data, int32_t count)
{
    return count >= 0 && fwrite(data, 1, (size_t)count, id) == (size_t)count;
}

int main(int argc, char **argv)
{
    assert(argc == 2);
    int32_t input[4096 * 2], output[4096 * 2];
    for (int i = 0; i < 4096; ++i) {
        input[2*i] = (i * 37 % 65536) - 32768;
        input[2*i+1] = 32767 - (i * 71 % 65536);
    }
    FILE *file = fopen(argv[1], "wb");
    assert(file);
    WavpackContext *encoder = WavpackOpenFileOutput(write_block, file, NULL);
    assert(encoder);
    WavpackConfig config = {0};
    config.bits_per_sample = 16;
    config.bytes_per_sample = 2;
    config.num_channels = 2;
    config.channel_mask = 3;
    config.sample_rate = 48000;
    config.flags = CONFIG_HIGH_FLAG;
    assert(WavpackSetConfiguration64(encoder, &config, 4096, NULL));
    assert(WavpackPackInit(encoder));
    int32_t original[4096 * 2];
    memcpy(original, input, sizeof(input));
    assert(WavpackPackSamples(encoder, input, 4096));
    assert(WavpackFlushSamples(encoder));
    WavpackCloseFile(encoder);
    assert(fclose(file) == 0);
    char error[128] = {0};
    WavpackContext *decoder = WavpackOpenFileInput(argv[1], error, 0, 0);
    assert(decoder);
    assert(WavpackGetNumChannels(decoder) == 2);
    assert(WavpackGetSampleRate(decoder) == 48000);
    assert(WavpackGetBitsPerSample(decoder) == 16);
    assert(WavpackGetNumSamples64(decoder) == 4096);
    assert(WavpackUnpackSamples(decoder, output, 4096) == 4096);
    assert(memcmp(original, output, sizeof(output)) == 0);
    assert(WavpackUnpackSamples(decoder, output, 1) == 0);
    assert(WavpackGetNumErrors(decoder) == 0);
    WavpackCloseFile(decoder);
    puts("WavPack codec: PASS 4096 stereo samples, exact PCM, metadata and EOF");
    return 0;
}
