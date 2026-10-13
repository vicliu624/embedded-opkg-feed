#include <speex/speex_resampler.h>
#include <speex/speex_preprocess.h>

int main(void)
{
    int error = 0;
    SpeexResamplerState *state = speex_resampler_init(1, 16000, 8000, 3, &error);
    if (!state || error) return 1;
    spx_int16_t input[320] = {0}, output[320] = {0};
    spx_uint32_t input_length = 320, output_length = 320;
    error = speex_resampler_process_int(state, 0, input, &input_length,
                                       output, &output_length);
    speex_resampler_destroy(state);
    if (error || !output_length) return 2;
    SpeexPreprocessState *preprocess = speex_preprocess_state_init(320, 16000);
    if (!preprocess) return 3;
    speex_preprocess_run(preprocess, input);
    speex_preprocess_state_destroy(preprocess);
    return 0;
}
