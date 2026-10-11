/* Verify HTTP/2 negotiation while keeping certificate validation enabled. */
#include <stdio.h>
#include <string.h>
#include <libsoup/soup.h>

int main(int argc, char **argv) {
    if(argc != 3) return 64;
    GError *error = NULL;
    GTlsDatabase *database = g_tls_file_database_new(argv[2], &error);
    if(!database) return 2;
    SoupSession *session = soup_session_new_with_options("timeout", 10,
        "tls-database", database, "user-agent", "TDVP-H2-Acceptance", NULL);
    SoupMessage *message = soup_message_new("GET", argv[1]);
    GBytes *body = soup_session_send_and_read(session, message, NULL, &error);
    if(!body) {
        fprintf(stderr, "HTTP/2 request failed: %s\n", error ? error->message : "unknown");
        return error && g_error_matches(error, G_TLS_ERROR, G_TLS_ERROR_BAD_CERTIFICATE) ? 3 : 4;
    }
    if(error || soup_message_get_status(message) != SOUP_STATUS_OK ||
       soup_message_get_http_version(message) != SOUP_HTTP_2_0) return 5;
    gsize length;
    const char *bytes = g_bytes_get_data(body, &length);
    const char expected[] = "tdvp-libsoup-http2\n";
    if(length != sizeof(expected)-1 || memcmp(bytes, expected, length)) return 6;
    g_bytes_unref(body);
    g_object_unref(message);
    g_object_unref(session);
    g_object_unref(database);
    puts("libsoup HTTP/2: PASS TLS trust, ALPN h2, negotiated version and exact response");
    return 0;
}
