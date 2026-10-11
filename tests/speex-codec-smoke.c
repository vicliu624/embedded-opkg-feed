/* Actual narrow/wide/ultra-wide speech encode/decode consumer. */
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <speex/speex.h>

int main(void)
{
    const SpeexMode *modes[] = {&speex_nb_mode, &speex_wb_mode, &speex_uwb_mode};
    const int sizes[] = {160, 320, 640};
    const int rates[] = {8000, 16000, 32000};
    for (int mode = 0; mode < 3; ++mode) {
        void *encoder = speex_encoder_init(modes[mode]);
        void *decoder = speex_decoder_init(modes[mode]);
        assert(encoder && decoder);
        int frame_size = 0, quality = 8;
        assert(speex_encoder_ctl(encoder, SPEEX_GET_FRAME_SIZE, &frame_size) == 0);
        assert(frame_size == sizes[mode]);
        assert(speex_encoder_ctl(encoder, SPEEX_SET_QUALITY, &quality) == 0);
        SpeexBits encoded, decoded;
        speex_bits_init(&encoded);
        speex_bits_init(&decoded);
        double energy = 0;
        for (int frame = 0; frame < 20; ++frame) {
            spx_int16_t input[640], output[640];
            char packet[4096];
            for (int i = 0; i < frame_size; ++i)
                input[i] = (spx_int16_t)(10000 * sin(2 * 3.141592653589793 * 200 *
                    (frame * frame_size + i) / rates[mode]));
            speex_bits_reset(&encoded);
            assert(speex_encode_int(encoder, input, &encoded) == 1);
            int length = speex_bits_write(&encoded, packet, sizeof(packet));
            assert(length > 0 && length < (int)sizeof(packet));
            speex_bits_read_from(&decoded, packet, length);
            assert(speex_decode_int(decoder, &decoded, output) == 0);
            if (frame == 19)
                for (int i = 0; i < frame_size; ++i)
                    energy += (double)output[i] * output[i];
        }
        assert(energy > 100000000);
        speex_bits_destroy(&encoded);
        speex_bits_destroy(&decoded);
        speex_encoder_destroy(encoder);
        speex_decoder_destroy(decoder);
        printf("Speex codec: PASS %d Hz, 20 decoded frames, non-silent output\n", rates[mode]);
    }
    return 0;
}
