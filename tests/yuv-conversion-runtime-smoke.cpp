#include <libyuv.h>
#include <cstdio>
#include <cstring>

int main()
{
    unsigned char y[64], u[16], v[16], argb[256], scaled[64];
    std::memset(u, 128, sizeof(u));
    std::memset(v, 128, sizeof(v));
    for (int color = 0; color < 2; ++color) {
        std::memset(y, color ? 235 : 16, sizeof(y));
        if (libyuv::I420ToARGB(y, 8, u, 4, v, 4, argb, 32, 8, 8)) return 1;
        for (int i = 0; i < 64; ++i) {
            for (int component = 0; component < 3; ++component)
                if (argb[i * 4 + component] != (color ? 255 : 0)) return 2;
            if (argb[i * 4 + 3] != 255) return 3;
        }
        if (libyuv::ARGBScale(argb, 32, 8, 8, scaled, 16, 4, 4, libyuv::kFilterBox)) return 4;
        for (int i = 0; i < 16; ++i)
            for (int component = 0; component < 4; ++component)
                if (scaled[i * 4 + component] != (component == 3 || color ? 255 : 0)) return 5;
    }
    unsigned char rotated_y[64], rotated_u[16], rotated_v[16];
    for (int i = 0; i < 64; ++i) y[i] = (unsigned char)i;
    if (libyuv::I420Rotate(y, 8, u, 4, v, 4, rotated_y, 8, rotated_u, 4, rotated_v, 4, 8, 8, libyuv::kRotate90)) return 6;
    for (int row = 0; row < 8; ++row)
        for (int column = 0; column < 8; ++column)
            if (rotated_y[row * 8 + column] != y[(7 - column) * 8 + row]) return 7;
    std::puts("libyuv target black/white conversion, box scaling and 90-degree rotation: PASS");
    return 0;
}
