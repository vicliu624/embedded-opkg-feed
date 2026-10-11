#define GST_USE_UNSTABLE_API
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <gst/gst.h>
#include <gst/codecparsers/gstvp9parser.h>
#include <vpx/vpx_encoder.h>
#include <vpx/vp8cx.h>

int main(int argc, char **argv)
{
    gst_init(&argc, &argv);
    vpx_codec_enc_cfg_t config;
    assert(vpx_codec_enc_config_default(vpx_codec_vp9_cx(), &config, 0) == VPX_CODEC_OK);
    config.g_w = config.g_h = 32;
    config.g_timebase.num = 1;
    config.g_timebase.den = 30;
    config.g_threads = 1;
    config.g_lag_in_frames = 0;
    vpx_codec_ctx_t encoder;
    assert(vpx_codec_enc_init(&encoder, vpx_codec_vp9_cx(), &config, 0) == VPX_CODEC_OK);
    vpx_image_t image;
    assert(vpx_img_alloc(&image, VPX_IMG_FMT_I420, 32, 32, 1));
    for (int plane = 0; plane < 3; plane++) {
        int extent = plane == 0 ? 32 : 16;
        for (int row = 0; row < extent; row++)
            memset(image.planes[plane] + row * image.stride[plane], plane == 0 ? 80 : 128, extent);
    }
    assert(vpx_codec_encode(&encoder, &image, 0, 1, 0, VPX_DL_REALTIME) == VPX_CODEC_OK);
    GstVp9Parser *parser = gst_vp9_parser_new();
    assert(parser);
    vpx_codec_iter_t iterator = NULL;
    const vpx_codec_cx_pkt_t *packet;
    int frames = 0;
    while ((packet = vpx_codec_get_cx_data(&encoder, &iterator)) != NULL) {
        if (packet->kind != VPX_CODEC_CX_FRAME_PKT) continue;
        GstVp9FrameHdr header;
        assert(gst_vp9_parser_parse_frame_header(parser, &header,
            packet->data.frame.buf, packet->data.frame.sz) == GST_VP9_PARSER_OK);
        assert(header.width == 32 && header.height == 32 && parser->bit_depth == 8);
        const guint header_length = header.frame_header_length_in_bytes;
        assert(header_length > 1 && header_length <= packet->data.frame.sz);
        for (guint length = 0; length < header_length; length++) {
            GstVp9Parser *fresh = gst_vp9_parser_new();
            assert(fresh);
            assert(gst_vp9_parser_parse_frame_header(fresh, &header,
                packet->data.frame.buf, length) != GST_VP9_PARSER_OK);
            gst_vp9_parser_free(fresh);
        }
        GstVp9SuperframeInfo superframe;
        assert(gst_vp9_parser_parse_superframe_info(parser, &superframe,
            packet->data.frame.buf, packet->data.frame.sz) == GST_VP9_PARSER_OK);
        assert(superframe.frames_in_superframe == 1 && superframe.frame_sizes[0] == packet->data.frame.sz);
        frames++;
    }
    assert(frames == 1);
    const guint8 bad[] = {0xff, 0xff, 0xff};
    GstVp9FrameHdr header;
    assert(gst_vp9_parser_parse_frame_header(parser, &header, bad, sizeof(bad)) != GST_VP9_PARSER_OK);
    const guint8 existing[] = {0x88};
    assert(gst_vp9_parser_parse_frame_header(parser, &header, existing, sizeof(existing)) == GST_VP9_PARSER_OK);
    assert(header.show_existing_frame && header.frame_to_show == 0);
    const guint8 short_index[] = {0xc0};
    GstVp9SuperframeInfo superframe;
    assert(gst_vp9_parser_parse_superframe_info(parser, &superframe, short_index, sizeof(short_index)) != GST_VP9_PARSER_OK);
    gst_vp9_parser_free(parser);
    vpx_img_free(&image);
    assert(vpx_codec_destroy(&encoder) == VPX_CODEC_OK);
    gst_deinit();
    puts("GStreamer VP9 parser: PASS real header, all truncated prefixes, malformed input, legal short header and superframe bounds");
    return 0;
}
