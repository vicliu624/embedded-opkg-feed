#include <opus/opus.h>

int main(void)
{
    int error = 0;
    OpusEncoder *encoder = opus_encoder_create(16000, 1, OPUS_APPLICATION_VOIP, &error);
    if (!encoder || error) return 1;
    OpusDecoder *decoder = opus_decoder_create(16000, 1, &error);
    if (!decoder || error) { opus_encoder_destroy(encoder); return 2; }
    opus_int16 input[320] = {0}, output[320];
    unsigned char packet[512];
    int bytes = opus_encode(encoder, input, 320, packet, sizeof(packet));
    int frames = bytes > 0 ? opus_decode(decoder, packet, bytes, output, 320, 0) : -1;
    opus_decoder_destroy(decoder);
    opus_encoder_destroy(encoder);
    return frames == 320 ? 0 : 3;
}
