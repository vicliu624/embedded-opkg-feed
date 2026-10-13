#include <OpenEXR/ImfRgbaFile.h>
#include <OpenEXR/ImfHeader.h>
#include <OpenEXR/ImfCompression.h>
#include <cstdio>
#include <unistd.h>

int main()
{
    char name[] = "/tmp/tdvp-openexr-XXXXXX";
    int fd = mkstemp(name);
    if (fd < 0) return 1;
    close(fd);
    try {
        const Imf::Compression modes[] = {Imf::ZIP_COMPRESSION, Imf::ZSTD_COMPRESSION, Imf::HTJ2K32_COMPRESSION};
        Imf::Rgba pixels[64];
        for (int i = 0; i < 64; ++i) {
            pixels[i] = Imf::Rgba(float(i) / 64, float(i % 8) / 8, 0.5f, 1.0f);
        }
        for (auto mode : modes) {
            {
                Imf::Header header(8, 8);
                header.compression() = mode;
                Imf::RgbaOutputFile output(name, header, Imf::WRITE_RGBA);
                output.setFrameBuffer(pixels, 1, 8);
                output.writePixels(8);
            }
            Imf::Rgba decoded[64];
            {
                Imf::RgbaInputFile input(name);
                input.setFrameBuffer(decoded, 1, 8);
                input.readPixels(0, 7);
            }
            for (int i = 0; i < 64; ++i) {
                if (pixels[i].r.bits() != decoded[i].r.bits() || pixels[i].g.bits() != decoded[i].g.bits() || pixels[i].b.bits() != decoded[i].b.bits() || pixels[i].a.bits() != decoded[i].a.bits()) {
                    unlink(name);
                    return 2;
                }
            }
        }
        if (truncate(name, 12) != 0) { unlink(name); return 3; }
        bool rejected = false;
        try { Imf::RgbaInputFile invalid(name); } catch (const std::exception&) { rejected = true; }
        unlink(name);
        if (!rejected) return 4;
        std::puts("OpenEXR target ZIP/ZSTD/HTJ2K exact RGBA roundtrip and truncated-input rejection: PASS");
        return 0;
    } catch (const std::exception& error) {
        std::fprintf(stderr, "%s\n", error.what());
        unlink(name);
        return 5;
    }
}
