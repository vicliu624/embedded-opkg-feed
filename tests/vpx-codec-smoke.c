#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <vpx/vpx_encoder.h>
#include <vpx/vpx_decoder.h>
#include <vpx/vp8cx.h>
#include <vpx/vp8dx.h>

int main(void)
{
    for (int mode = 0; mode < 4; mode++) {
        const int high = mode >= 2;
        const int depth = mode == 3 ? 12 : high ? 10 : 8;
        const int scale = 1 << (depth - 8);
        vpx_codec_iface_t *encoder_iface = mode == 0 ? vpx_codec_vp8_cx() : vpx_codec_vp9_cx();
        vpx_codec_iface_t *decoder_iface = mode == 0 ? vpx_codec_vp8_dx() : vpx_codec_vp9_dx();
        vpx_codec_enc_cfg_t config;
        assert(vpx_codec_enc_config_default(encoder_iface, &config, 0) == VPX_CODEC_OK);
        config.g_w = config.g_h = 32;
        config.g_timebase.num = 1;
        config.g_timebase.den = 30;
        config.g_threads = 1;
        config.g_lag_in_frames = 0;
        config.rc_target_bitrate = 256;
        if (high) {
            config.g_bit_depth = depth == 12 ? VPX_BITS_12 : VPX_BITS_10;
            config.g_input_bit_depth = depth;
            config.g_profile = 2;
        }
        vpx_codec_ctx_t encoder, decoder;
        assert(vpx_codec_enc_init(&encoder, encoder_iface, &config,
                                  high ? VPX_CODEC_USE_HIGHBITDEPTH : 0) == VPX_CODEC_OK);
        if (mode != 0)
            assert(vpx_codec_control(&encoder, VP9E_SET_LOSSLESS, 1) == VPX_CODEC_OK);
        vpx_image_t image;
        assert(vpx_img_alloc(&image, high ? VPX_IMG_FMT_I42016 : VPX_IMG_FMT_I420, 32, 32, 1));
        for (int plane = 0; plane < 3; plane++) {
            int extent = plane == 0 ? 32 : 16;
            for (int row = 0; row < extent; row++) {
                if (high) {
                    uint16_t *samples = (uint16_t *)(image.planes[plane] + row * image.stride[plane]);
                    for (int column = 0; column < extent; column++) samples[column] = (plane == 0 ? 80 : 128) * scale;
                } else {
                    memset(image.planes[plane] + row * image.stride[plane], plane == 0 ? 80 : 128, extent);
                }
            }
        }
        assert(vpx_codec_encode(&encoder, &image, 0, 1, 0, VPX_DL_REALTIME) == VPX_CODEC_OK);
        assert(vpx_codec_dec_init(&decoder, decoder_iface, NULL, 0) == VPX_CODEC_OK);
        vpx_codec_iter_t iterator = NULL;
        const vpx_codec_cx_pkt_t *packet;
        int frames = 0;
        while ((packet = vpx_codec_get_cx_data(&encoder, &iterator)) != NULL) {
            if (packet->kind != VPX_CODEC_CX_FRAME_PKT) continue;
            assert(vpx_codec_decode(&decoder, packet->data.frame.buf, packet->data.frame.sz, NULL, 0) == VPX_CODEC_OK);
            vpx_codec_iter_t decoded_iterator = NULL;
            vpx_image_t *decoded = vpx_codec_get_frame(&decoder, &decoded_iterator);
            assert(decoded && decoded->d_w == 32 && decoded->d_h == 32);
            assert(decoded->bit_depth == (unsigned)depth);
            for (int plane = 0; plane < 3; plane++) {
                const int extent = plane == 0 ? 32 : 16;
                const int expected = (plane == 0 ? 80 : 128) * scale;
                for (int row = 0; row < extent; row++)
                    for (int column = 0; column < extent; column++) {
                        unsigned char *samples = decoded->planes[plane] + row * decoded->stride[plane];
                        int sample = high ? ((uint16_t *)samples)[column] : samples[column];
                        assert(mode == 0 ? sample >= expected - 10 && sample <= expected + 10 : sample == expected);
                    }
            }
            frames++;
        }
        assert(frames == 1);
        const unsigned char bad[] = {0xff, 0xff, 0xff};
        assert(vpx_codec_decode(&decoder, bad, sizeof(bad), NULL, 0) != VPX_CODEC_OK);
        assert(vpx_codec_destroy(&decoder) == VPX_CODEC_OK);
        assert(vpx_codec_destroy(&encoder) == VPX_CODEC_OK);
        vpx_img_free(&image);
        printf("libvpx: PASS %s %d-bit frame encode/decode, all planes and malformed input rejection\n",
               mode == 0 ? "VP8" : "VP9", depth);
    }
    return 0;
}
