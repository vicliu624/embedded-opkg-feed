#define _GNU_SOURCE
#include <gif_lib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(void)
{
    char filename[] = "tdvp-gif-XXXXXX";
    int fd = mkstemp(filename), error = 0;
    if (fd < 0) return 1;
    GifColorType colors[2] = {{0, 0, 0}, {255, 255, 255}};
    ColorMapObject *map = GifMakeMapObject(2, colors);
    if (!map) return 2;
    GifFileType *writer = EGifOpenFileHandle(fd, &error);
    if (!writer) return 3;
    if (EGifPutScreenDesc(writer, 2, 2, 8, 0, map) == GIF_ERROR ||
        EGifPutImageDesc(writer, 0, 0, 2, 2, 0, NULL) == GIF_ERROR) return 4;
    GifPixelType row1[2] = {0, 1}, row2[2] = {1, 0};
    if (EGifPutLine(writer, row1, 2) == GIF_ERROR || EGifPutLine(writer, row2, 2) == GIF_ERROR ||
        EGifCloseFile(writer, &error) == GIF_ERROR) return 5;
    GifFreeMapObject(map);
    GifFileType *reader = DGifOpenFileName(filename, &error);
    if (!reader || DGifSlurp(reader) == GIF_ERROR) return 6;
    GifPixelType expected[4] = {0, 1, 1, 0};
    if (reader->ImageCount != 1 || reader->SWidth != 2 || reader->SHeight != 2 ||
        memcmp(reader->SavedImages[0].RasterBits, expected, sizeof(expected))) return 7;
    if (!reader->SColorMap || reader->SColorMap->Colors[1].Red != 255) return 8;
    if (DGifCloseFile(reader, &error) == GIF_ERROR || unlink(filename)) return 9;
    char truncated[] = "tdvp-gif-truncated-XXXXXX";
    fd = mkstemp(truncated);
    if (fd < 0 || write(fd, "GIF89a", 6) != 6 || close(fd)) return 10;
    reader = DGifOpenFileName(truncated, &error);
    if (reader) {
        if (DGifSlurp(reader) != GIF_ERROR) return 11;
        if (DGifCloseFile(reader, &error) == GIF_ERROR) return 12;
    }
    if (unlink(truncated)) return 13;
    puts("GIF target encode/decode palette and exact pixels, truncated input rejection: PASS");
    return 0;
}
