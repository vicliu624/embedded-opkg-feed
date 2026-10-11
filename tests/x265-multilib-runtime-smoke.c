#include <x265.h>
#include <stdio.h>

int main(void)
{
    const int depths[] = {8, 10, 12};
    for (unsigned i = 0; i < sizeof(depths) / sizeof(depths[0]); ++i) {
        const x265_api *api = x265_api_get(depths[i]);
        if (!api || api->bit_depth != depths[i] || api->sizeof_param != sizeof(x265_param) || api->sizeof_picture != sizeof(x265_picture)) return 1;
        x265_param *param = api->param_alloc();
        if (!param || api->param_default_preset(param, "ultrafast", "zerolatency")) return 2;
        param->sourceWidth = param->sourceHeight = 32;
        param->fpsNum = 30;
        param->fpsDenom = 1;
        param->frameNumThreads = 1;
        param->logLevel = X265_LOG_NONE;
        if (api->param_parse(param, "pools", "none") || api->param_parse(param, "lossless", "1")) return 3;
        x265_encoder *encoder = api->encoder_open(param);
        if (!encoder) return 4;
        x265_nal *headers = NULL;
        unsigned header_count = 0;
        if (api->encoder_headers(encoder, &headers, &header_count) <= 0 || !headers || header_count < 3) return 5;
        api->encoder_close(encoder);
        api->param_free(param);
    }
    puts("x265 target 8/10/12-bit API, encoder initialization and HEVC headers: PASS");
    return 0;
}
