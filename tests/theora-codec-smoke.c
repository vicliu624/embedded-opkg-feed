#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <theora/theoraenc.h>
#include <theora/theoradec.h>

int main(void)
{
    th_info info;
    th_info_init(&info);
    info.frame_width = info.pic_width = 32;
    info.frame_height = info.pic_height = 32;
    info.fps_numerator = 30;
    info.fps_denominator = 1;
    info.aspect_numerator = info.aspect_denominator = 1;
    info.pixel_fmt = TH_PF_420;
    info.quality = 63;
    th_enc_ctx *encoder = th_encode_alloc(&info);
    assert(encoder && th_version_number() != 0);
    th_info decoded;
    th_info_init(&decoded);
    th_comment comment, decoded_comment;
    th_comment_init(&comment);
    th_comment_init(&decoded_comment);
    th_setup_info *setup = NULL;
    ogg_packet packet;
    int headers = 0;
    while (th_encode_flushheader(encoder, &comment, &packet) > 0) {
        assert(th_decode_headerin(&decoded, &decoded_comment, &setup, &packet) > 0);
        headers++;
    }
    assert(headers == 3);
    th_dec_ctx *decoder = th_decode_alloc(&decoded, setup);
    assert(decoder);
    th_setup_free(setup);
    unsigned char y[32 * 32], u[16 * 16], v[16 * 16];
    memset(y, 80, sizeof(y));
    memset(u, 128, sizeof(u));
    memset(v, 128, sizeof(v));
    th_ycbcr_buffer frame = {{32, 32, 32, y}, {16, 16, 16, u}, {16, 16, 16, v}};
    assert(th_encode_ycbcr_in(encoder, frame) == 0);
    assert(th_encode_packetout(encoder, 1, &packet) > 0);
    ogg_int64_t granule;
    assert(th_decode_packetin(decoder, &packet, &granule) == 0);
    th_ycbcr_buffer result;
    assert(th_decode_ycbcr_out(decoder, result) == 0);
    assert(result[0].width == 32 && result[0].height == 32);
    for (int row = 0; row < 32; row++)
        for (int column = 0; column < 32; column++)
            assert(result[0].data[row * result[0].stride + column] >= 74 &&
                   result[0].data[row * result[0].stride + column] <= 86);
    th_decode_free(decoder);
    th_encode_free(encoder);
    th_info_clear(&info);
    th_info_clear(&decoded);
    th_comment_clear(&comment);
    th_comment_clear(&decoded_comment);
    th_info_init(&decoded);
    th_comment_init(&decoded_comment);
    setup = NULL;
    unsigned char bad[] = {0xff, 0, 0};
    ogg_packet invalid = {.packet = bad, .bytes = sizeof(bad), .b_o_s = 1};
    assert(th_decode_headerin(&decoded, &decoded_comment, &setup, &invalid) < 0);
    th_setup_free(setup);
    th_info_clear(&decoded);
    th_comment_clear(&decoded_comment);
    puts("Theora: PASS headers, YUV frame encode/decode and malformed header rejection");
    return 0;
}
