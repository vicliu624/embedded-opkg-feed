#include <zmq.h>
#include <assert.h>
#include <errno.h>
#include <string.h>
#include <stdio.h>

int main(void)
{
    char server_public[41], server_secret[41], client_public[41], client_secret[41];
    char wrong_public[41], wrong_secret[41];
    assert(zmq_curve_keypair(server_public, server_secret) == 0);
    assert(zmq_curve_keypair(client_public, client_secret) == 0);
    assert(zmq_curve_keypair(wrong_public, wrong_secret) == 0);
    void *context = zmq_ctx_new();
    void *server = zmq_socket(context, ZMQ_REP);
    void *client = zmq_socket(context, ZMQ_REQ);
    void *wrong = zmq_socket(context, ZMQ_REQ);
    assert(context && server && client && wrong);
    int timeout = 3000, linger = 0, enabled = 1;
    assert(zmq_setsockopt(server, ZMQ_CURVE_SERVER, &enabled, sizeof(enabled)) == 0);
    assert(zmq_setsockopt(server, ZMQ_CURVE_SECRETKEY, server_secret, 40) == 0);
    assert(zmq_setsockopt(server, ZMQ_RCVTIMEO, &timeout, sizeof(timeout)) == 0);
    assert(zmq_setsockopt(server, ZMQ_LINGER, &linger, sizeof(linger)) == 0);
    assert(zmq_bind(server, "tcp://127.0.0.1:*") == 0);
    char endpoint[128];
    size_t length = sizeof(endpoint);
    assert(zmq_getsockopt(server, ZMQ_LAST_ENDPOINT, endpoint, &length) == 0);
    assert(zmq_setsockopt(client, ZMQ_CURVE_PUBLICKEY, client_public, 40) == 0);
    assert(zmq_setsockopt(client, ZMQ_CURVE_SECRETKEY, client_secret, 40) == 0);
    assert(zmq_setsockopt(client, ZMQ_CURVE_SERVERKEY, server_public, 40) == 0);
    assert(zmq_setsockopt(client, ZMQ_RCVTIMEO, &timeout, sizeof(timeout)) == 0);
    assert(zmq_setsockopt(client, ZMQ_LINGER, &linger, sizeof(linger)) == 0);
    assert(zmq_connect(client, endpoint) == 0);
    assert(zmq_send(client, "vision", 6, 0) == 6);
    char message[16];
    assert(zmq_recv(server, message, sizeof(message), 0) == 6);
    assert(memcmp(message, "vision", 6) == 0);
    assert(zmq_send(server, "result", 6, 0) == 6);
    assert(zmq_recv(client, message, sizeof(message), 0) == 6);
    assert(memcmp(message, "result", 6) == 0);
    assert(zmq_setsockopt(wrong, ZMQ_CURVE_PUBLICKEY, client_public, 40) == 0);
    assert(zmq_setsockopt(wrong, ZMQ_CURVE_SECRETKEY, client_secret, 40) == 0);
    assert(zmq_setsockopt(wrong, ZMQ_CURVE_SERVERKEY, wrong_public, 40) == 0);
    assert(zmq_setsockopt(wrong, ZMQ_LINGER, &linger, sizeof(linger)) == 0);
    assert(zmq_connect(wrong, endpoint) == 0);
    timeout = 750;
    assert(zmq_setsockopt(server, ZMQ_RCVTIMEO, &timeout, sizeof(timeout)) == 0);
    assert(zmq_send(wrong, "invalid", 7, 0) == 7);
    assert(zmq_recv(server, message, sizeof(message), 0) == -1 && errno == EAGAIN);
    assert(zmq_close(wrong) == 0 && zmq_close(client) == 0 && zmq_close(server) == 0);
    assert(zmq_ctx_term(context) == 0);
    puts("ZeroMQ CURVE TCP roundtrip and wrong server-key rejection: PASS");
    return 0;
}
