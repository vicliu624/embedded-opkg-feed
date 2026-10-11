/* Independent MP2 encoding/decoding through TwoLAME and mpg123 public APIs. */
#include <assert.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <twolame.h>
#include <mpg123.h>

int main(int argc, char **argv)
{
    assert(argc == 2);
    twolame_options *encoder = twolame_init();
    assert(encoder);
    assert(twolame_set_num_channels(encoder, 2) == 0);
    assert(twolame_set_in_samplerate(encoder, 48000) == 0);
    assert(twolame_set_out_samplerate(encoder, 48000) == 0);
    assert(twolame_set_bitrate(encoder, 192) == 0);
    assert(twolame_set_mode(encoder, TWOLAME_STEREO) == 0);
    assert(twolame_init_params(encoder) == 0);
    FILE *file = fopen(argv[1], "wb");
    assert(file);
    short samples[1152 * 2];
    unsigned char packet[16384];
    size_t encoded = 0;
    for (int frame = 0; frame < 20; ++frame) {
        for (int i = 0; i < 1152; ++i) {
            double time = (frame * 1152 + i) / 48000.0;
            samples[2*i] = (short)(12000 * sin(2 * 3.141592653589793 * 440 * time));
            samples[2*i+1] = (short)(12000 * sin(2 * 3.141592653589793 * 660 * time));
        }
        int count = twolame_encode_buffer_interleaved(encoder, samples, 1152, packet, sizeof(packet));
        assert(count >= 0);
        assert(fwrite(packet, 1, count, file) == (size_t)count);
        encoded += count;
    }
    int count = twolame_encode_flush(encoder, packet, sizeof(packet));
    assert(count >= 0 && fwrite(packet, 1, count, file) == (size_t)count);
    encoded += count;
    assert(encoded > 10000 && fclose(file) == 0);
    twolame_close(&encoder);
    assert(mpg123_init() == MPG123_OK);
    int error;
    mpg123_handle *decoder = mpg123_new(NULL, &error);
    assert(decoder && error == MPG123_OK && mpg123_open(decoder, argv[1]) == MPG123_OK);
    int16_t pcm[8192];
    size_t bytes, total = 0;
    double energy[2] = {0, 0};
    int status;
    do {
        status = mpg123_read(decoder, (unsigned char *)pcm, sizeof(pcm), &bytes);
        assert(status == MPG123_OK || status == MPG123_NEW_FORMAT || status == MPG123_DONE);
        assert(bytes % 4 == 0);
        for (size_t i = 0; i < bytes / 2; ++i)
            energy[i % 2] += (double)pcm[i] * pcm[i];
        total += bytes;
    } while (status != MPG123_DONE);
    long rate;
    int channels, encoding;
    assert(mpg123_getformat(decoder, &rate, &channels, &encoding) == MPG123_OK);
    assert(rate == 48000 && channels == 2 && encoding == MPG123_ENC_SIGNED_16);
    struct mpg123_frameinfo info;
    assert(mpg123_info(decoder, &info) == MPG123_OK && info.layer == 2);
    assert(total >= 20 * 1152 * 4);
    for (int channel = 0; channel < 2; ++channel) {
        double rms = sqrt(energy[channel] / (total / 4));
        assert(rms > 6000 && rms < 11000);
    }
    mpg123_close(decoder);
    mpg123_delete(decoder);
    mpg123_exit();
    puts("TwoLAME: PASS MP2 encoding, independent mpg123 decode, 48 kHz stereo, samples and signal energy");
    return 0;
}
