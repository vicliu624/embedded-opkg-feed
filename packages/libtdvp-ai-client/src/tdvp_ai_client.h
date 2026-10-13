/* SPDX-License-Identifier: MIT */
#ifndef TDVP_AI_CLIENT_H
#define TDVP_AI_CLIENT_H
#include <stddef.h>
#include <tdvp/tdvp_ai_abi.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct tdvp_ai_client tdvp_ai_client;
/* All failures return negative errno. Serialize calls on each client.
 * The kernel owns buffers and completion acknowledgement. No /dev/mem or
 * physical addresses are accepted. Current KPU operation is pinned KWS only.
 */
int tdvp_ai_client_open(tdvp_ai_client **client, const char *device);
int tdvp_ai_client_fd(const tdvp_ai_client *client);
int tdvp_ai_client_submit(tdvp_ai_client *client, const struct tdvp_ai_request *request,
                          const void *input, size_t input_bytes);
/* A timeout leaves the request pending; wait/read it again to acknowledge.
 * There is no unsafe cancellation or automatic retry of submitted work. */
int tdvp_ai_client_wait(tdvp_ai_client *client, unsigned timeout_ms);
int tdvp_ai_client_receive(tdvp_ai_client *client, struct tdvp_ai_response *response,
                           void *output, size_t capacity);
void tdvp_ai_client_close(tdvp_ai_client *client);
unsigned tdvp_ai_client_protocol_version(void);
#ifdef __cplusplus
}
#endif
#endif
