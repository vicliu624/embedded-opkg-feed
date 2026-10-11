#define GST_USE_UNSTABLE_API
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#include <gst/gst.h>
#include <gst/codecparsers/gstvp9parser.h>
#include <vpx/vpx_encoder.h>
#include <vpx/vp8cx.h>

int main(int argc, char **argv)
{
    gst_init(&argc, &argv);
    long page_size = sysconf(_SC_PAGESIZE);
    assert(page_size > 0);
    guint8 *memory = mmap(NULL, 2 * page_size, PROT_READ | PROT_WRITE,
                          MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    assert(memory != MAP_FAILED);
    assert(mprotect(memory + page_size, page_size, PROT_NONE) == 0);
    vpx_codec_enc_cfg_t config;
    assert(vpx_codec_enc_config_default(vpx_codec_vp9_cx(), &config, 0) == VPX_CODEC_OK);
    config.g_w = config.g_h = 32;
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
    vpx_codec_iter_t iterator = NULL;
    const vpx_codec_cx_pkt_t *packet;
    guint checked = 0;
    while ((packet = vpx_codec_get_cx_data(&encoder, &iterator)) != NULL) {
        if (packet->kind != VPX_CODEC_CX_FRAME_PKT) continue;
        assert(packet->data.frame.sz < (size_t)page_size);
        GstVp9Parser *parser = gst_vp9_parser_new();
        GstVp9FrameHdr header;
        guint8 *data = memory + page_size - packet->data.frame.sz;
        memcpy(data, packet->data.frame.buf, packet->data.frame.sz);
        assert(gst_vp9_parser_parse_frame_header(parser, &header, data, packet->data.frame.sz) == GST_VP9_PARSER_OK);
        guint header_length = header.frame_header_length_in_bytes;
        gst_vp9_parser_free(parser);
        for (guint length = 0; length < header_length; length++) {
            data = memory + page_size - length;
            if (length) memcpy(data, packet->data.frame.buf, length);
            parser = gst_vp9_parser_new();
            assert(gst_vp9_parser_parse_frame_header(parser, &header, data, length) != GST_VP9_PARSER_OK);
            gst_vp9_parser_free(parser);
            checked++;
        }
    }
    assert(checked > 1);
    guint8 *last = memory + page_size - 1;
    *last = 0x88;
    GstVp9Parser *parser = gst_vp9_parser_new();
    GstVp9FrameHdr header;
    assert(gst_vp9_parser_parse_frame_header(parser, &header, last, 1) == GST_VP9_PARSER_OK);
    assert(header.show_existing_frame);
    *last = 0xc0;
    GstVp9SuperframeInfo superframe;
    assert(gst_vp9_parser_parse_superframe_info(parser, &superframe, last, 1) != GST_VP9_PARSER_OK);
    gst_vp9_parser_free(parser);
    assert(munmap(memory, 2 * page_size) == 0);
    vpx_img_free(&image);
    assert(vpx_codec_destroy(&encoder) == VPX_CODEC_OK);
    gst_deinit();
    printf("VP9 guard pages: PASS %u truncated prefixes, complete frame, legal short header and short index\n", checked);
    return 0;
}
