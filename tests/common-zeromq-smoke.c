#include <zmq.h>
#include <assert.h>
#include <string.h>
#include <stdio.h>

int main(void)
{
    assert(zmq_has("curve") == 1);
    char public_key[41], secret_key[41];
    assert(zmq_curve_keypair(public_key, secret_key) == 0);
    assert(strlen(public_key) == 40 && strlen(secret_key) == 40);
    void *context = zmq_ctx_new();
    assert(context);
    void *sender = zmq_socket(context, ZMQ_PAIR);
    void *receiver = zmq_socket(context, ZMQ_PAIR);
    assert(sender && receiver);
    int timeout = 3000;
    assert(zmq_setsockopt(receiver, ZMQ_RCVTIMEO, &timeout, sizeof(timeout)) == 0);
    assert(zmq_setsockopt(sender, ZMQ_SNDTIMEO, &timeout, sizeof(timeout)) == 0);
    assert(zmq_bind(receiver, "inproc://tdvp-library-acceptance") == 0);
    assert(zmq_connect(sender, "inproc://tdvp-library-acceptance") == 0);
    assert(zmq_send(sender, "vision", 6, ZMQ_SNDMORE) == 6);
    assert(zmq_send(sender, "result", 6, 0) == 6);
    char buffer[16];
    assert(zmq_recv(receiver, buffer, sizeof(buffer), 0) == 6);
    assert(memcmp(buffer, "vision", 6) == 0);
    int more = 0;
    size_t length = sizeof(more);
    assert(zmq_getsockopt(receiver, ZMQ_RCVMORE, &more, &length) == 0 && more == 1);
    assert(zmq_recv(receiver, buffer, sizeof(buffer), 0) == 6);
    assert(memcmp(buffer, "result", 6) == 0);
    assert(zmq_getsockopt(receiver, ZMQ_RCVMORE, &more, &length) == 0 && more == 0);
    assert(zmq_close(sender) == 0);
    assert(zmq_close(receiver) == 0);
    assert(zmq_ctx_term(context) == 0);
    puts("ZeroMQ multipart inproc messaging and CURVE key generation: PASS");
    return 0;
}
