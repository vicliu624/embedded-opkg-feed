#include <gnutls/gnutls.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv) {
    if (argc != 4) return 64;
    int port = atoi(argv[1]);
    if (port < 1024 || port > 65535) return 64;
    int status = 1, descriptor = -1;
    const char *step = "credentials";
    gnutls_session_t session = NULL;
    gnutls_certificate_credentials_t credentials = NULL;
    if (gnutls_global_init()) return 1;
    if (gnutls_certificate_allocate_credentials(&credentials)) goto finish;
    if (gnutls_certificate_set_x509_trust_file(credentials, argv[2], GNUTLS_X509_FMT_PEM) < 1) goto finish;
    step = "session";
    if (gnutls_init(&session, GNUTLS_CLIENT)) goto finish;
    if (gnutls_set_default_priority(session) || gnutls_credentials_set(session, GNUTLS_CRD_CERTIFICATE, credentials)) goto finish;
    if (gnutls_server_name_set(session, GNUTLS_NAME_DNS, argv[3], strlen(argv[3]))) goto finish;
    step = "socket";
    descriptor = socket(AF_INET, SOCK_STREAM, 0);
    if (descriptor < 0) goto finish;
    struct timeval timeout = {5, 0};
    if (setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout)) || setsockopt(descriptor, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout))) goto finish;
    struct sockaddr_in address = {.sin_family = AF_INET, .sin_port = htons(port), .sin_addr.s_addr = htonl(INADDR_LOOPBACK)};
    if (connect(descriptor, (struct sockaddr *)&address, sizeof(address))) goto finish;
    gnutls_transport_set_int(session, descriptor);
    gnutls_handshake_set_timeout(session, 5000);
    step = "handshake";
    int handshake = gnutls_handshake(session);
    if (handshake) { fprintf(stderr, "Handshake: %s\n", gnutls_strerror(handshake)); goto finish; }
    step = "verification";
    unsigned int verification = 0;
    if (gnutls_certificate_verify_peers3(session, argv[3], &verification) || verification) {
        printf("Target certificate rejected: status=0x%x\n", verification);
        status = 7;
        goto finish;
    }
    step = "send";
    const char request[] = "GET / HTTP/1.0\r\nHost: localhost\r\n\r\n";
    size_t sent = 0;
    while (sent < sizeof(request) - 1) {
        ssize_t count = gnutls_record_send(session, request + sent, sizeof(request) - 1 - sent);
        if (count <= 0) goto finish;
        sent += count;
    }
    step = "receive";
    char response[4096];
    size_t received = 0;
    for (int attempt = 0; attempt < 8 && received < 12; ++attempt) {
        ssize_t count = gnutls_record_recv(session, response + received, sizeof(response) - received);
        if (count == GNUTLS_E_AGAIN || count == GNUTLS_E_INTERRUPTED) continue;
        if (count <= 0) { fprintf(stderr, "Record receive: %ld\n", (long)count); goto finish; }
        received += count;
    }
    if (received < 12 || memcmp(response, "HTTP/1.0 200", 12)) { fprintf(stderr, "Response count: %lu\n", (unsigned long)received); goto finish; }
    puts("Target GnuTLS trusted certificate, hostname and encrypted HTTP response: PASS");
    status = 0;
finish:
    if (status == 1) fprintf(stderr, "TLS test failed at %s\n", step);
    if (session) gnutls_deinit(session);
    if (credentials) gnutls_certificate_free_credentials(credentials);
    if (descriptor >= 0) close(descriptor);
    gnutls_global_deinit();
    return status;
}
