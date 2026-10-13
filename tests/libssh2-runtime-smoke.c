#include <libssh2.h>
#include <string.h>

int main(void) {
    if (libssh2_init(0)) return 1;
    if (strcmp(libssh2_version(0), "1.11.1")) return 2;
    LIBSSH2_SESSION *session = libssh2_session_init();
    if (!session) return 3;
    libssh2_session_set_blocking(session, 0);
    if (libssh2_session_get_blocking(session)) return 4;
    libssh2_session_set_timeout(session, 1000);
    if (libssh2_session_get_timeout(session) != 1000) return 5;
    LIBSSH2_KNOWNHOSTS *hosts = libssh2_knownhost_init(session);
    if (!hosts) return 6;
    /* Synthetic bytes exercise matching only; this is not key validation. */
    const char key[] = "TDVP synthetic knownhost fixture";
    const char other[] = "TDVP different knownhost fixture";
    int type = LIBSSH2_KNOWNHOST_TYPE_PLAIN | LIBSSH2_KNOWNHOST_KEYENC_RAW | LIBSSH2_KNOWNHOST_KEY_ED25519;
    struct libssh2_knownhost *entry = NULL;
    if (libssh2_knownhost_addc(hosts, "fixture.invalid", NULL, key, sizeof(key), NULL, 0, type, &entry)) return 7;
    if (libssh2_knownhost_checkp(hosts, "fixture.invalid", 22, key, sizeof(key), type, NULL) != LIBSSH2_KNOWNHOST_CHECK_MATCH) return 8;
    if (libssh2_knownhost_checkp(hosts, "fixture.invalid", 22, other, sizeof(other), type, NULL) != LIBSSH2_KNOWNHOST_CHECK_MISMATCH) return 9;
    if (libssh2_knownhost_checkp(hosts, "unknown.invalid", 22, key, sizeof(key), type, NULL) != LIBSSH2_KNOWNHOST_CHECK_NOTFOUND) return 10;
    libssh2_knownhost_free(hosts);
    if (libssh2_session_free(session)) return 11;
    libssh2_exit();
    return 0;
}
