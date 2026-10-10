#include <avif/avif.h>
#include <stdio.h>

int main(void)
{
    avifImage *image = avifImageCreate(16, 16, 8, AVIF_PIXEL_FORMAT_YUV444);
    if (!image) return 1;
    image->yuvRange = AVIF_RANGE_FULL;
    image->matrixCoefficients = AVIF_MATRIX_COEFFICIENTS_IDENTITY;
    if (avifImageAllocatePlanes(image, AVIF_PLANES_ALL) != AVIF_RESULT_OK) return 2;
    for (int y = 0; y < 16; ++y)
        for (int x = 0; x < 16; ++x) {
            image->yuvPlanes[0][y * image->yuvRowBytes[0] + x] = (unsigned char)(y * 16 + x);
            image->yuvPlanes[1][y * image->yuvRowBytes[1] + x] = 113;
            image->yuvPlanes[2][y * image->yuvRowBytes[2] + x] = 197;
            image->alphaPlane[y * image->alphaRowBytes + x] = (unsigned char)((x + y) * 7);
        }
    avifEncoder *encoder = avifEncoderCreate();
    avifDecoder *decoder = avifDecoderCreate();
    avifImage *decoded = avifImageCreateEmpty();
    if (!encoder || !decoder || !decoded) return 3;
    encoder->codecChoice = AVIF_CODEC_CHOICE_AOM;
    encoder->quality = encoder->qualityAlpha = AVIF_QUALITY_LOSSLESS;
    encoder->speed = AVIF_SPEED_FASTEST;
    encoder->maxThreads = 1;
    avifRWData data = AVIF_DATA_EMPTY;
    avifResult result = avifEncoderWrite(encoder, image, &data);
    if (result != AVIF_RESULT_OK) { fprintf(stderr, "AVIF encode: %s\n", avifResultToString(result)); return 4; }
    result = avifDecoderReadMemory(decoder, decoded, data.data, data.size);
    if (result != AVIF_RESULT_OK) { fprintf(stderr, "AVIF decode: %s\n", avifResultToString(result)); return 5; }
    if (decoded->width != 16 || decoded->height != 16 || decoded->depth != 8 || !decoded->alphaPlane) return 6;
    for (int y = 0; y < 16; ++y)
        for (int x = 0; x < 16; ++x) {
            if (decoded->yuvPlanes[0][y * decoded->yuvRowBytes[0] + x] != (unsigned char)(y * 16 + x) ||
                decoded->yuvPlanes[1][y * decoded->yuvRowBytes[1] + x] != 113 ||
                decoded->yuvPlanes[2][y * decoded->yuvRowBytes[2] + x] != 197 ||
                decoded->alphaPlane[y * decoded->alphaRowBytes + x] != (unsigned char)((x + y) * 7)) return 7;
        }
    avifRGBImage rgb;
    avifRGBImageSetDefaults(&rgb, decoded);
    rgb.format = AVIF_RGB_FORMAT_RGBA;
    if (avifRGBImageAllocatePixels(&rgb) != AVIF_RESULT_OK || avifImageYUVToRGB(decoded, &rgb) != AVIF_RESULT_OK) return 8;
    for (int y = 0; y < 16; ++y)
        for (int x = 0; x < 16; ++x) {
            unsigned char *pixel = rgb.pixels + y * rgb.rowBytes + x * 4;
            if (pixel[0] != 197 || pixel[1] != (unsigned char)(y * 16 + x) || pixel[2] != 113 || pixel[3] != (unsigned char)((x + y) * 7)) return 9;
        }
    avifRGBImageFreePixels(&rgb);
    avifDecoderDestroy(decoder);
    decoder = avifDecoderCreate();
    if (!decoder || avifDecoderReadMemory(decoder, decoded, data.data, 12) == AVIF_RESULT_OK) return 10;
    avifRWDataFree(&data);
    avifEncoderDestroy(encoder);
    avifDecoderDestroy(decoder);
    avifImageDestroy(decoded);
    avifImageDestroy(image);
    puts("AVIF target lossless YUV/alpha, RGBA conversion and truncated-container rejection: PASS");
    return 0;
}
