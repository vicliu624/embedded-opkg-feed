#include <aom/aom_encoder.h>
#include <aom/aom_decoder.h>
#include <aom/aomcx.h>
#include <aom/aomdx.h>
#include <stdio.h>
#include <string.h>

static unsigned sample(const aom_image_t *image, int plane, int x, int y)
{
    const unsigned char *row = image->planes[plane] + y * image->stride[plane];
    if (image->fmt & AOM_IMG_FMT_HIGHBITDEPTH) return ((const uint16_t *)row)[x];
    return row[x];
}

int main(void)
{
    aom_codec_ctx_t encoder = {0}, decoder = {0};
    aom_codec_enc_cfg_t config;
    aom_codec_err_t status = aom_codec_enc_config_default(aom_codec_av1_cx(), &config, AOM_USAGE_REALTIME);
    if (status) {
        fprintf(stderr, "AOM %s encoder %s usage %u default config: %s\n", aom_codec_version_str(), aom_codec_iface_name(aom_codec_av1_cx()), AOM_USAGE_REALTIME, aom_codec_err_to_string(status));
        return 1;
    }
    config.g_w = config.g_h = 16;
    config.g_threads = 1;
    config.g_timebase.num = 1;
    config.g_timebase.den = 30;
    config.g_lag_in_frames = 0;
    config.rc_min_quantizer = config.rc_max_quantizer = 0;
    if (aom_codec_enc_init(&encoder, aom_codec_av1_cx(), &config, 0)) return 2;
    if (aom_codec_control(&encoder, AOME_SET_CPUUSED, 8) || aom_codec_control(&encoder, AV1E_SET_LOSSLESS, 1)) return 3;
    aom_image_t *image = aom_img_alloc(NULL, AOM_IMG_FMT_I420, 16, 16, 1);
    if (!image) return 4;
    for (int y = 0; y < 16; ++y)
        for (int x = 0; x < 16; ++x) image->planes[0][y * image->stride[0] + x] = (unsigned char)(y * 16 + x);
    for (int plane = 1; plane < 3; ++plane)
        for (int y = 0; y < 8; ++y) memset(image->planes[plane] + y * image->stride[plane], 128, 8);
    if (aom_codec_encode(&encoder, image, 0, 1, 0)) return 5;
    aom_codec_iter_t iterator = NULL;
    const aom_codec_cx_pkt_t *packet;
    const aom_codec_cx_pkt_t *frame = NULL;
    while ((packet = aom_codec_get_cx_data(&encoder, &iterator)))
        if (packet->kind == AOM_CODEC_CX_FRAME_PKT) frame = packet;
    if (!frame || frame->data.frame.sz < 8) return 6;
    aom_codec_dec_cfg_t decode_config = {1, 0, 0, 0};
    if (aom_codec_dec_init(&decoder, aom_codec_av1_dx(), &decode_config, 0)) return 7;
    if (aom_codec_decode(&decoder, frame->data.frame.buf, frame->data.frame.sz, NULL)) return 8;
    iterator = NULL;
    aom_image_t *output = aom_codec_get_frame(&decoder, &iterator);
    if (!output || output->d_w != 16 || output->d_h != 16 || output->bit_depth != 8) return 9;
    for (int y = 0; y < 16; ++y)
        for (int x = 0; x < 16; ++x)
            if (sample(output, 0, x, y) != (unsigned char)(y * 16 + x)) return 10;
    for (int plane = 1; plane < 3; ++plane)
        for (int y = 0; y < 8; ++y)
            for (int x = 0; x < 8; ++x)
                if (sample(output, plane, x, y) != 128) return 11;
    aom_codec_destroy(&decoder);
    memset(&decoder, 0, sizeof(decoder));
    if (aom_codec_dec_init(&decoder, aom_codec_av1_dx(), &decode_config, 0)) return 12;
    if (aom_codec_decode(&decoder, frame->data.frame.buf, 3, NULL) == AOM_CODEC_OK) return 13;
    aom_codec_destroy(&decoder);
    aom_img_free(image);
    aom_codec_destroy(&encoder);
    puts("AOM target lossless AV1 exact YUV pixels and truncated-stream rejection: PASS");
    return 0;
}
