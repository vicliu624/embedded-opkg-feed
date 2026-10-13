#include <samplerate.h>
#include <math.h>

int main(void)
{
    float input[64], output[128];
    for (int i = 0; i < 64; ++i) input[i] = (float)i / 64.0f;
    SRC_DATA data = {0};
    data.data_in = input;
    data.data_out = output;
    data.input_frames = 64;
    data.output_frames = 128;
    data.src_ratio = 2.0;
    data.end_of_input = 1;
    if (src_simple(&data, SRC_LINEAR, 1) != 0) return 1;
    if (data.output_frames_gen < 100) return 2;
    for (long i = 0; i < data.output_frames_gen; ++i)
        if (!isfinite(output[i])) return 3;
    return 0;
}
