/* SPDX-License-Identifier: MIT */
#include <libheif/heif.h>
#include <stdio.h>
#include <stdlib.h>

#define CHECK(call) do { struct heif_error e = (call); if (e.code) { \
 fprintf(stderr, "%s: %s\n", #call, e.message); return 1; } } while (0)

int main(int argc, char **argv)
{
 if (argc != 3) return 64;
 enum heif_compression_format codec = atoi(argv[1]) == 1 ? heif_compression_HEVC : heif_compression_AV1;
 struct heif_context *writer = heif_context_alloc(), *reader = heif_context_alloc();
 struct heif_encoder *encoder = NULL;
 struct heif_image *image = NULL, *decoded = NULL;
 struct heif_image_handle *encoded = NULL, *handle = NULL;
 CHECK(heif_context_get_encoder_for_format(writer, codec, &encoder));
 CHECK(heif_encoder_set_lossless(encoder, 1));
 CHECK(heif_image_create(32, 32, heif_colorspace_YCbCr, heif_chroma_420, &image));
 enum heif_channel channels[] = {heif_channel_Y, heif_channel_Cb, heif_channel_Cr};
 for (int c = 0; c < 3; c++) {
  int n = c ? 16 : 32, stride;
  CHECK(heif_image_add_plane(image, channels[c], n, n, 8));
  unsigned char *plane = heif_image_get_plane(image, channels[c], &stride);
  if (!plane) return 2;
  for (int y = 0; y < n; y++) for (int x = 0; x < n; x++)
   plane[y * stride + x] = c ? 128 : (x * 7 + y * 3) % 256;
 }
 CHECK(heif_context_encode_image(writer, image, encoder, NULL, &encoded));
 CHECK(heif_context_write_to_file(writer, argv[2]));
 CHECK(heif_context_read_from_file(reader, argv[2], NULL));
 CHECK(heif_context_get_primary_image_handle(reader, &handle));
 CHECK(heif_decode_image(handle, &decoded, heif_colorspace_YCbCr, heif_chroma_420, NULL));
 for (int c = 0; c < 3; c++) {
  int n = c ? 16 : 32, stride;
  const unsigned char *plane = heif_image_get_plane_readonly(decoded, channels[c], &stride);
  if (!plane) return 3;
  for (int y = 0; y < n; y++) for (int x = 0; x < n; x++)
   if (plane[y * stride + x] != (c ? 128 : (x * 7 + y * 3) % 256)) return 4;
 }
 unsigned char prefix[12];
 FILE *file = fopen(argv[2], "rb");
 if (!file || fread(prefix, 1, sizeof(prefix), file) != sizeof(prefix)) return 5;
 fclose(file);
 struct heif_context *broken = heif_context_alloc();
 struct heif_error rejected = heif_context_read_from_memory_without_copy(broken, prefix, sizeof(prefix), NULL);
 heif_context_free(broken);
 if (rejected.code == heif_error_Ok) return 6;
 heif_image_release(decoded); heif_image_release(image);
 heif_image_handle_release(handle); heif_image_handle_release(encoded);
 heif_encoder_release(encoder); heif_context_free(reader); heif_context_free(writer);
 puts("HEIF codec roundtrip: PASS exact Y/Cb/Cr planes and truncated-container rejection");
 return 0;
}
