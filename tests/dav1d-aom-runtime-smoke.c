/* SPDX-License-Identifier: MIT */
#include <aom/aom_encoder.h>
#include <aom/aomcx.h>
#include <dav1d/dav1d.h>
#include <stdio.h>
#include <string.h>

int main(void)
{
 aom_codec_ctx_t encoder = {0};
 aom_codec_enc_cfg_t cfg;
 if (aom_codec_enc_config_default(aom_codec_av1_cx(), &cfg, AOM_USAGE_REALTIME)) return 1;
 cfg.g_w = cfg.g_h = 16; cfg.g_threads = 1; cfg.g_lag_in_frames = 0;
 cfg.g_timebase.num = 1; cfg.g_timebase.den = 30;
 cfg.rc_min_quantizer = cfg.rc_max_quantizer = 0;
 if (aom_codec_enc_init(&encoder, aom_codec_av1_cx(), &cfg, 0)) return 2;
 if (aom_codec_control(&encoder, AOME_SET_CPUUSED, 8) ||
     aom_codec_control(&encoder, AV1E_SET_LOSSLESS, 1)) return 3;
 aom_image_t *image = aom_img_alloc(NULL, AOM_IMG_FMT_I420, 16, 16, 1);
 if (!image) return 4;
 for (int c = 0; c < 3; c++) {
  int n = c ? 8 : 16;
  for (int y = 0; y < n; y++) for (int x = 0; x < n; x++)
   image->planes[c][y * image->stride[c] + x] = c ? 128 : y * 16 + x;
 }
 if (aom_codec_encode(&encoder, image, 0, 1, 0)) return 5;
 aom_codec_iter_t iter = NULL;
 const aom_codec_cx_pkt_t *packet, *frame = NULL;
 while ((packet = aom_codec_get_cx_data(&encoder, &iter)))
  if (packet->kind == AOM_CODEC_CX_FRAME_PKT) frame = packet;
 if (!frame || frame->data.frame.sz < 8) return 6;
 Dav1dSettings settings;
 dav1d_default_settings(&settings);
 settings.n_threads = 1; settings.max_frame_delay = 1;
 Dav1dContext *decoder = NULL;
 if (dav1d_open(&decoder, &settings)) return 7;
 Dav1dData data = {0};
 unsigned char *bytes = dav1d_data_create(&data, frame->data.frame.sz);
 if (!bytes) return 8;
 memcpy(bytes, frame->data.frame.buf, frame->data.frame.sz);
 if (dav1d_send_data(decoder, &data)) return 9;
 Dav1dPicture picture = {0};
 if (dav1d_get_picture(decoder, &picture)) return 10;
 if (picture.p.w != 16 || picture.p.h != 16 || picture.p.bpc != 8 ||
     picture.p.layout != DAV1D_PIXEL_LAYOUT_I420) return 11;
 for (int c = 0; c < 3; c++) {
  int n = c ? 8 : 16;
  const unsigned char *plane = picture.data[c];
  for (int y = 0; y < n; y++) for (int x = 0; x < n; x++)
   if (plane[y * picture.stride[c ? 1 : 0] + x] != (c ? 128 : y * 16 + x)) return 12;
 }
 dav1d_picture_unref(&picture);
 dav1d_data_unref(&data);
 dav1d_close(&decoder);
 Dav1dSequenceHeader header;
 if (dav1d_parse_sequence_header(&header, frame->data.frame.buf, 3) == 0) return 13;
 aom_img_free(image); aom_codec_destroy(&encoder);
 puts("dav1d AV1 target: PASS AOM-encoded exact YUV pixels and truncated-header rejection");
 return 0;
}
