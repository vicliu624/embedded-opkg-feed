#include "tdvp_ai_client.h"
#include <assert.h>
#include <errno.h>
#include <string.h>

int main(void)
{
    tdvp_ai_client *client = NULL;
    assert(tdvp_ai_client_protocol_version() == TDVP_AI_VERSION);
    assert(tdvp_ai_client_open(NULL, NULL) == -EINVAL);
    assert(tdvp_ai_client_fd(NULL) == -EINVAL);
    assert(tdvp_ai_client_open(&client, "/tdvp-nonexistent-test-device") == -ENOENT);
    assert(client == NULL);
    assert(tdvp_ai_client_open(&client, "/dev/null") == 0);
    unsigned char input[256] = {0}, output[256] = {0};
    struct tdvp_ai_response response;
    assert(tdvp_ai_client_receive(client, &response, output, sizeof(output)) == -ENODATA);
    assert(tdvp_ai_client_wait(client, 1) == -ENODATA);
    struct tdvp_ai_request request = {0};
    request.magic = TDVP_AI_MAGIC;
    request.version = TDVP_AI_VERSION;
    request.bytes = sizeof(request);
    request.operation = TDVP_AI_FFT;
    request.input_bytes = request.output_capacity = sizeof(input);
    request.budget_ms = 1000;
    request.input_width = request.output_width = 64;
    request.input_height = request.output_height = 1;
    request.format = TDVP_AI_COMPLEX_I16;
    request.flags = 0x80000000U;
    assert(tdvp_ai_client_submit(client, &request, input, sizeof(input)) == -EINVAL);
    request.flags = 0;
    assert(tdvp_ai_client_submit(client, &request, input, sizeof(input)-1) == -EINVAL);
    assert(tdvp_ai_client_submit(client, &request, input, sizeof(input)) == 0);
    assert(tdvp_ai_client_submit(client, &request, input, sizeof(input)) == -EBUSY);
    assert(tdvp_ai_client_receive(client, &response, output, sizeof(output)-1) == -EMSGSIZE);
    assert(tdvp_ai_client_receive(client, &response, output, sizeof(output)) == -EPROTO);
    assert(tdvp_ai_client_receive(client, &response, output, sizeof(output)) == -ENODATA);
    tdvp_ai_client_close(client);
    tdvp_ai_client_close(NULL);
    return 0;
}
