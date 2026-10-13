/* TLS client with an explicit test trust database; certificate checks stay on. */
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <libsoup/soup.h>

int main(int argc, char **argv)
{
    assert(argc == 3);
    GError *error = NULL;
    GTlsDatabase *database = g_tls_file_database_new(argv[2], &error);
    if (!database) {
        fprintf(stderr, "TLS database failed: %s\n", error ? error->message : "unknown");
        return 2;
    }
    SoupSession *session = soup_session_new_with_options("timeout", 10,
        "tls-database", database, "user-agent", "TDVP-TLS-Acceptance", NULL);
    SoupMessage *message = soup_message_new("GET", argv[1]);
    assert(session && message);
    GBytes *body = soup_session_send_and_read(session, message, NULL, &error);
    if (!body) {
        gboolean certificate_error = error && g_error_matches(error, G_TLS_ERROR, G_TLS_ERROR_BAD_CERTIFICATE);
        fprintf(stderr, "TLS request failed: %s\n", error ? error->message : "unknown");
        return certificate_error ? 3 : 4;
    }
    assert(!error && soup_message_get_status(message) == SOUP_STATUS_OK);
    gsize length;
    const char *bytes = g_bytes_get_data(body, &length);
    const char expected[] = "tdvp-libsoup-tls\n";
    assert(length == sizeof(expected) - 1 && memcmp(bytes, expected, length) == 0);
    g_bytes_unref(body);
    g_object_unref(message);
    g_object_unref(session);
    g_object_unref(database);
    puts("libsoup TLS: PASS verified certificate and exact HTTPS response");
    return 0;
}
