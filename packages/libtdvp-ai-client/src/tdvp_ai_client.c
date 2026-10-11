/* SPDX-License-Identifier: MIT */
#define _POSIX_C_SOURCE 200809L
#include "tdvp_ai_client.h"
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

struct tdvp_ai_client {
    int fd, pending;
    unsigned operation, format, width, height, output_bytes;
};

unsigned tdvp_ai_client_protocol_version(void) { return TDVP_AI_VERSION; }

int tdvp_ai_client_open(tdvp_ai_client **result, const char *device)
{
    if (!result) return -EINVAL;
    *result = NULL;
    int fd = open(device ? device : "/dev/tdvp-ai", O_RDWR | O_NONBLOCK | O_CLOEXEC);
    if (fd < 0) return -errno;
    tdvp_ai_client *client = calloc(1, sizeof(*client));
    if (!client) { close(fd); return -ENOMEM; }
    client->fd = fd;
    *result = client;
    return 0;
}

int tdvp_ai_client_fd(const tdvp_ai_client *client)
{ return client ? client->fd : -EINVAL; }

int tdvp_ai_client_submit(tdvp_ai_client *client, const struct tdvp_ai_request *request,
                          const void *input, size_t input_bytes)
{
    if (!client || !request || !input || input_bytes != request->input_bytes) return -EINVAL;
    if (client->pending) return -EBUSY;
    int valid = tdvp_ai_validate_request(request);
    if (valid) return valid;
    if (input_bytes > TDVP_AI_BUFFER_BYTES) return -EMSGSIZE;
    if (request->operation == TDVP_AI_KPU && !tdvp_ai_kws_input_valid(input, input_bytes)) return -EILSEQ;
    size_t bytes = sizeof(*request) + input_bytes;
    unsigned char *packet = malloc(bytes);
    if (!packet) return -ENOMEM;
    struct tdvp_ai_request clean = *request;
    clean.owner_cookie = clean.peer_cookie = clean.client_cookie = clean.id = 0;
    memcpy(packet, &clean, sizeof(clean));
    memcpy(packet + sizeof(clean), input, input_bytes);
    ssize_t written = write(client->fd, packet, bytes);
    int error = written < 0 ? -errno : ((size_t)written != bytes ? -EPROTO : 0);
    free(packet);
    if (error) return error;
    client->pending = 1;
    client->operation = request->operation;
    client->format = request->format;
    client->width = request->output_width;
    client->height = request->output_height;
    client->output_bytes = tdvp_ai_output_bytes(request);
    return 0;
}

static int monotonic_ms(unsigned long long *result)
{
    struct timespec now;
    if (clock_gettime(CLOCK_MONOTONIC, &now)) return -errno;
    *result = (unsigned long long)now.tv_sec * 1000 + (unsigned long long)now.tv_nsec / 1000000;
    return 0;
}

int tdvp_ai_client_wait(tdvp_ai_client *client, unsigned timeout_ms)
{
    if (!client || timeout_ms > 60000) return -EINVAL;
    if (!client->pending) return -ENODATA;
    unsigned long long start, now;
    int error = monotonic_ms(&start);
    if (error) return error;
    struct pollfd fd = {client->fd, POLLIN, 0};
    for (;;) {
        error = monotonic_ms(&now);
        if (error) return error;
        unsigned long long elapsed = now - start;
        int remaining = elapsed >= timeout_ms ? 0 : (int)(timeout_ms - elapsed);
        int result = poll(&fd, 1, remaining);
        if (result < 0) { if (errno == EINTR) continue; return -errno; }
        if (!result) return -ETIMEDOUT;
        if (fd.revents & POLLNVAL) return -EBADF;
        if (fd.revents & (POLLERR | POLLHUP)) return -EIO;
        if (fd.revents & POLLIN) return 0;
    }
}

int tdvp_ai_client_receive(tdvp_ai_client *client, struct tdvp_ai_response *response,
                           void *output, size_t capacity)
{
    if (!client || !response || !output || capacity > TDVP_AI_BUFFER_BYTES) return -EINVAL;
    if (!client->pending) return -ENODATA;
    if (capacity < client->output_bytes) return -EMSGSIZE;
    unsigned char *packet = malloc(sizeof(*response) + capacity);
    if (!packet) return -ENOMEM;
    ssize_t bytes = read(client->fd, packet, sizeof(*response) + capacity);
    if (bytes < 0) { int error = -errno; free(packet); return error; }
    client->pending = 0; /* successful driver read already acknowledged completion */
    if ((size_t)bytes < sizeof(*response)) { free(packet); return -EPROTO; }
    struct tdvp_ai_response header;
    memcpy(&header, packet, sizeof(header));
    if (header.output_bytes > capacity || sizeof(header) + header.output_bytes != (size_t)bytes ||
        header.result > 0 || (header.result && header.output_bytes) ||
        header.operation != client->operation || header.format != client->format ||
        header.output_width != client->width || header.output_height != client->height ||
        (!header.result && header.output_bytes != client->output_bytes) ||
        !tdvp_ai_response_hardware_valid(&header)) { free(packet); return -EPROTO; }
    *response = header;
    memcpy(output, packet + sizeof(header), header.output_bytes);
    free(packet);
    return header.result;
}

void tdvp_ai_client_close(tdvp_ai_client *client)
{
    if (client) { close(client->fd); free(client); }
}
