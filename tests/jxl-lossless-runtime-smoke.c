/* SPDX-License-Identifier: MIT */
#include <jxl/encode.h>
#include <jxl/decode.h>
#include <jxl/color_encoding.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(void)
{
 unsigned char input[16 * 16 * 4], output[sizeof(input)];
 for (int y = 0; y < 16; y++) for (int x = 0; x < 16; x++) {
  unsigned char *p = input + (y * 16 + x) * 4;
  p[0] = x * 15; p[1] = y * 15; p[2] = (x + y) * 7; p[3] = 31 + (x + y) * 7;
 }
 JxlEncoder *encoder = JxlEncoderCreate(NULL);
 if (!encoder) return 1;
 JxlBasicInfo info;
 JxlEncoderInitBasicInfo(&info);
 info.xsize = info.ysize = 16; info.bits_per_sample = 8;
 info.num_color_channels = 3; info.num_extra_channels = 1; info.alpha_bits = 8;
 info.uses_original_profile = JXL_TRUE;
 if (JxlEncoderSetBasicInfo(encoder, &info) != JXL_ENC_SUCCESS) return 2;
 JxlColorEncoding color;
 JxlColorEncodingSetToSRGB(&color, JXL_FALSE);
 if (JxlEncoderSetColorEncoding(encoder, &color) != JXL_ENC_SUCCESS) return 3;
 JxlEncoderFrameSettings *settings = JxlEncoderFrameSettingsCreate(encoder, NULL);
 if (!settings || JxlEncoderSetFrameLossless(settings, JXL_TRUE) != JXL_ENC_SUCCESS) return 4;
 if (JxlEncoderFrameSettingsSetOption(settings, JXL_ENC_FRAME_SETTING_EFFORT, 1) != JXL_ENC_SUCCESS) return 5;
 JxlPixelFormat format = {4, JXL_TYPE_UINT8, JXL_NATIVE_ENDIAN, 0};
 if (JxlEncoderAddImageFrame(settings, &format, input, sizeof(input)) != JXL_ENC_SUCCESS) return 6;
 JxlEncoderCloseInput(encoder);
 size_t capacity = 1024 * 1024, available = capacity;
 unsigned char *encoded = malloc(capacity), *next = encoded;
 if (!encoded) return 7;
 if (JxlEncoderProcessOutput(encoder, &next, &available) != JXL_ENC_SUCCESS) return 8;
 size_t size = capacity - available;
 JxlDecoder *decoder = JxlDecoderCreate(NULL);
 if (!decoder || JxlDecoderSubscribeEvents(decoder, JXL_DEC_BASIC_INFO | JXL_DEC_FULL_IMAGE) != JXL_DEC_SUCCESS) return 9;
 JxlDecoderSetInput(decoder, encoded, size); JxlDecoderCloseInput(decoder);
 int frames = 0;
 for (;;) {
  JxlDecoderStatus status = JxlDecoderProcessInput(decoder);
  if (status == JXL_DEC_BASIC_INFO) {
   JxlBasicInfo decoded;
   if (JxlDecoderGetBasicInfo(decoder, &decoded) != JXL_DEC_SUCCESS ||
       decoded.xsize != 16 || decoded.ysize != 16 || decoded.alpha_bits != 8) return 10;
  } else if (status == JXL_DEC_NEED_IMAGE_OUT_BUFFER) {
   size_t needed;
   if (JxlDecoderImageOutBufferSize(decoder, &format, &needed) != JXL_DEC_SUCCESS || needed != sizeof(output)) return 11;
   if (JxlDecoderSetImageOutBuffer(decoder, &format, output, sizeof(output)) != JXL_DEC_SUCCESS) return 12;
  } else if (status == JXL_DEC_FULL_IMAGE) frames++;
  else if (status == JXL_DEC_SUCCESS) break;
  else return 13;
 }
 if (frames != 1 || memcmp(input, output, sizeof(input))) return 14;
 JxlDecoderDestroy(decoder);
 decoder = JxlDecoderCreate(NULL);
 JxlDecoderSetInput(decoder, encoded, 3); JxlDecoderCloseInput(decoder);
 if (JxlDecoderProcessInput(decoder) != JXL_DEC_ERROR) return 15;
 JxlDecoderDestroy(decoder); JxlEncoderDestroy(encoder); free(encoded);
 puts("JPEG XL target: PASS exact lossless RGBA/alpha and truncated-stream rejection");
 return 0;
}
