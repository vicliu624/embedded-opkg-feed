#include "tdvp_ai_client.h"
#include <stdio.h>

int main(void)
{
    tdvp_ai_client *client = NULL;
    int error = tdvp_ai_client_open(&client, NULL);
    if (error) { fprintf(stderr, "open: %d\n", error); return 1; }
    short input[128] = {0}, output[128] = {0};
    struct tdvp_ai_request request = {0};
    struct tdvp_ai_response response;
    request.magic = TDVP_AI_MAGIC;
    request.version = TDVP_AI_VERSION;
    request.bytes = sizeof(request);
    request.operation = TDVP_AI_FFT;
    request.input_bytes = request.output_capacity = sizeof(input);
    request.budget_ms = 5000;
    request.input_width = request.output_width = 64;
    request.input_height = request.output_height = 1;
    request.format = TDVP_AI_COMPLEX_I16;
    error = tdvp_ai_client_submit(client, &request, input, sizeof(input));
    if (!error) error = tdvp_ai_client_wait(client, 6000);
    if (!error) error = tdvp_ai_client_receive(client, &response, output, sizeof(output));
    tdvp_ai_client_close(client);
    if (error) { fprintf(stderr, "FFT: %d\n", error); return 2; }
    for (unsigned i = 0; i < 128; ++i) if (output[i]) return 3;
    printf("CPU1 FFT completed, result id=%llu, output=%u bytes\n",
           (unsigned long long)response.id, response.output_bytes);
    return 0;
}
