#include <libssh2.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv) {
    if (argc != 3 || strlen(argv[2]) != 64) return 64;
    int port = atoi(argv[1]);
    if (port < 1024 || port > 65535) return 64;
    unsigned char expected[32];
    for (int i = 0; i < 32; ++i) {
        unsigned int value;
        if (sscanf(argv[2] + i * 2, "%2x", &value) != 1) return 64;
        expected[i] = value;
    }
    if (libssh2_init(0)) return 1;
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) return 2;
    struct timeval timeout = { 5, 0 };
    if (setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout)) ||
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout))) return 3;
    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_family = AF_INET;
    address.sin_port = htons(port);
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    if (connect(fd, (struct sockaddr *)&address, sizeof(address))) return 4;
    LIBSSH2_SESSION *session = libssh2_session_init();
    if (!session) return 5;
    libssh2_session_set_timeout(session, 5000);
    int status = libssh2_session_handshake(session, fd);
    if (status) { fprintf(stderr, "SSH handshake failed: %d\n", status); return 6; }
    const char *digest = libssh2_hostkey_hash(session, LIBSSH2_HOSTKEY_HASH_SHA256);
    if (!digest || memcmp(digest, expected, sizeof(expected))) return 7;
    puts("Target libssh2 real loopback SSH handshake and pinned host-key SHA256: PASS");
    libssh2_session_disconnect(session, "Fixture completed without authentication");
    libssh2_session_free(session);
    close(fd);
    libssh2_exit();
    return 0;
}
