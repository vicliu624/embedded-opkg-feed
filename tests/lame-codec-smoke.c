#include <lame/lame.h>
#include <mpg123.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

/* Independent MP3 decoder checks the encoder's actual output, including EOF. */
int main(int argc, char **argv) {
    if (argc != 2) return 64;
    lame_t encoder = lame_init();
    if (!encoder) return 1;
    if (lame_set_in_samplerate(encoder, 48000) < 0 ||
        lame_set_num_channels(encoder, 2) < 0 ||
        lame_set_brate(encoder, 192) < 0 || lame_init_params(encoder) < 0) return 2;
    FILE *file = fopen(argv[1], "wb");
    if (!file) return 3;
    short pcm[1152 * 2];
    unsigned char encoded[16384];
    for (int frame = 0; frame < 40; frame++) {
        for (int sample = 0; sample < 1152; sample++) {
            double t = (frame * 1152 + sample) / 48000.0;
            pcm[2 * sample] = (short)(12000 * sin(2 * 3.141592653589793 * 440 * t));
            pcm[2 * sample + 1] = (short)(12000 * sin(2 * 3.141592653589793 * 660 * t));
        }
        int count = lame_encode_buffer_interleaved(encoder, pcm, 1152, encoded, sizeof(encoded));
        if (count < 0 || fwrite(encoded, 1, (size_t)count, file) != (size_t)count) return 4;
    }
    int count = lame_encode_flush(encoder, encoded, sizeof(encoded));
    if (count < 0 || fwrite(encoded, 1, (size_t)count, file) != (size_t)count) return 5;
    if (fclose(file)) return 6;
    lame_close(encoder);
    if (mpg123_init() != MPG123_OK) return 7;
    int error;
    mpg123_handle *decoder = mpg123_new(NULL, &error);
    if (!decoder || mpg123_open(decoder, argv[1]) != MPG123_OK) return 8;
    long rate;
    int channels, encoding;
    if (mpg123_getformat(decoder, &rate, &channels, &encoding) != MPG123_OK ||
        rate != 48000 || channels != 2 || encoding != MPG123_ENC_SIGNED_16) return 9;
    struct mpg123_frameinfo info;
    if (mpg123_info(decoder, &info) != MPG123_OK || info.layer != 3) return 10;
    short decoded[8192];
    size_t total = 0, done;
    double energy[2] = {0, 0};
    int result;
    do {
        result = mpg123_read(decoder, (unsigned char *)decoded, sizeof(decoded), &done);
        if (done % 4) return 11;
        for (size_t i = 0; i < done / sizeof(short); i++) energy[i % 2] += (double)decoded[i] * decoded[i];
        total += done;
    } while (result == MPG123_OK);
    if (result != MPG123_DONE || total < 40 * 1152 * 4) return 12;
    for (int channel = 0; channel < 2; channel++) {
        double rms = sqrt(energy[channel] / (total / 4));
        if (rms < 6000 || rms > 11000) return 13;
    }
    mpg123_delete(decoder);
    mpg123_exit();
    puts("LAME MP3 encode / independent mpg123 decode: PASS");
    return 0;
}
